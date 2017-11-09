#!/usr/bin/perl -w

use strict;
use LWP::UserAgent;
use Data::Dumper;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use Storable qw(freeze thaw);
use Bot4;
use AnyEvent;
use IPC::Open2;
use ProxyDatabase;
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

my $maxWorkers = 10;

my $db  = "$RealBin/../var/proxy.sqlite";
my $bot = new Bot4;
$bot->single(1);
$bot->addOption( "database=s", \$db, "Changes path to a database" );
$bot->setup( 'root' => "$RealBin/.." );

my $logger = Log::Any->get_logger;
$logger->info("Start");

my $dbh = ProxyDatabase->new( 'file' => $db );

my %workers;      # pid => $worker
my %jobsTaken;    # proxy_id => $worker
my @jobsQueue;    # list of { proxy_id, proxy_address }
my $lastJobsFetched = clock_gettime(CLOCK_MONOTONIC) - 60;    # timestamp, when last jobs were fetched

sub sendMessage {
	my $child   = shift;
	my $message = shift;

	if ( $logger->is_debug ) {
		$logger->debug( "Sending a message to a worker $child->{pid}:\n" . Dumper($message) );
	}

	my $data = freeze($message);
	$child->{in}->print( bytes::length($data) . "\n" . $data )
	  or die "Unable to send a message to a worker $child->{pid}: $!\n";
}

sub readMessage {
	my $child = shift;

	my $size = readline( $child->{out} );

	die "Unable to read from a worker $child->{pid}: $!\n"
	  unless defined $size;

	chomp($size);

	my $buffer;
	my $len = read( $child->{out}, $buffer, $size );

	if ( $len < $size ) {
		die "Received a corrupted message from a worker $child->{pid}: expected $len bytes instead of $size bytes\n";
	}
	my $message = thaw $buffer;
	if ( $logger->is_debug ) {
		$logger->debug( "Received a message from a worker $child->{pid}:\n" . Dumper($message) );
	}
	return $message;
}

sub killWorker {
	my $child = shift;
	$logger->info("Killing worker $child->{pid}");
	unassignJob($child);
	undef $child->{childWatcher};
	undef $child->{ioWatcher};
	kill 'KILL', $child->{pid}
	  unless defined $child->{dead};
	close( $child->{in} );
	close( $child->{out} );
	delete $workers{ $child->{pid} };
}

sub spawnWorker {
	my $child = {
		'pid' => undef,
		'in'  => undef,
		'out' => undef,
	};
	$child->{pid} = open2( $child->{out}, $child->{in}, 'perl', 'proxy-check-worker.pl' );
	binmode $child->{out}
	  if $child->{out};
	binmode $child->{in}
	  if $child->{in};

	$child->{childWatcher} = AnyEvent->child(
		pid => $child->{pid},
		cb  => sub {
			my ( $pid, $status ) = @_;
			$logger->info("Worker $child->{pid} has exited with status: $status");
			$child->{dead} = $status;
			killWorker($child);
		},
	);

	$child->{ioWatcher} = AnyEvent->io(
		'fh'   => $child->{out},
		'poll' => 'r',
		'cb'   => sub {
			eval {
				my $message = readMessage($child);
				processMessage( $child, $message );
			};
			if ($@) {
				$@ =~ s/\s+$//;
				$logger->error($@);
				killWorker($child);
				return;
			}
		}
	);

	$workers{ $child->{pid} } = $child;
	return $child;
}

sub fetchJobs {
	my $time = clock_gettime(CLOCK_MONOTONIC);
	return if $time - $lastJobsFetched < 59;
	$logger->debug("Fetching proxies to check");
	my $dt = DateTime->now;
	$dt -= DateTime::Duration->new( 'months' => 1 );
	@jobsQueue = grep { !exists $jobsTaken{ $_->{proxy_id} } } $dbh->fetchProxiesToCheck( $dt, 200 );
	$lastJobsFetched = $time;
}

sub sendJob {
	my $worker = shift;

	fetchJobs unless @jobsQueue;
	my $job = shift @jobsQueue;
	return unless $job;

	eval {
		sendMessage(
			$worker,
			{
				'command' => 'CHECK',
				'proxy'   => $job->{proxy_id},
				'address' => $job->{proxy_address},
			}
		);

		$worker->{job}      = $job;
		$worker->{jobStart} = clock_gettime(CLOCK_MONOTONIC);

		$jobsTaken{ $job->{proxy_id} } = $worker;
	};
	my $error = $@;
	if ($error) {
		unshift @jobsQueue, $job;
		$logger->error("Unable to send a job to a worker $worker->{pid}: $error");
		killWorker($worker);
	}
}

sub unassignJob {
	my $worker = shift;

	my $job = $worker->{job};
	return unless defined $job;

	$worker->{job}     = undef;
	$worker->{jobTime} = undef;
	delete $jobsTaken{ $job->{proxy_id} };
}

sub processMessage {
	my $worker  = shift;
	my $message = shift;

	die "Invalid message\n"
	  unless ref($message) eq 'HASH' and defined $message->{command};

	if ( $message->{command} eq 'CHECKRESULT' ) {
		if ( $message->{proxy} != $worker->{job}->{proxy_id} ) {
			die "Invalid job id, got: $message->{proxy}, expected: $worker->{job}->{proxy_id}\n";
		}
		unassignJob($worker);

		$dbh->insertCheckResult( @{$message}{ 'proxy', 'status', 'type', 'address' } );

		# If the address qualifies for blocking append block request to the queue
		if ( defined $message->{block} ) {
			$dbh->insertOrIgnoreBlock( $message->{address}, DateTime->now(), $message->{block} );
		}
		sendJob($worker);
	}
	else {
		die "Unsupported command '$message->{command}'\n";
	}
}

sub min ($$) {
	return $_[ $_[0] > $_[1] ];
}

my $quit = AnyEvent->condvar;

my $jobs = AnyEvent->timer(
	after    => 0,
	interval => 60,
	cb       => sub {
		unless (@jobsQueue) {

			# Empty job queue, fetch more
			fetchJobs;
		}

		# Spawn workers if needed
		my $currentWorkers = scalar keys %workers;
		my $workersToSpawn = min( $maxWorkers - $currentWorkers, scalar @jobsQueue );

		if ( $workersToSpawn > 0 ) {
			$logger->info("Spawning workers: $workersToSpawn");
			for ( my $i = 0 ; $i < $workersToSpawn ; $i++ ) {
				spawnWorker;
			}
		}
		my $time = clock_gettime(CLOCK_MONOTONIC);
		foreach my $worker ( values %workers ) {
			if ( $worker->{job} ) {

				# Check job time
				if ( $time - $worker->{jobStart} > 3600 ) {
					killWorker($worker);
				}
			}
			else {

				# Assign job to worker
				sendJob($worker);
			}
		}
	},
);

eval {    #
	$quit->recv;
};
if ($@) {
	$@ =~ s/\s+$//;
	$logger->fatal($@);
}
