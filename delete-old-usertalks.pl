#!/usr/bin/perl -w

use strict;
use utf8;
use Date::Parse;
use Bot4;
use POSIX qw(mktime);
use Socket;

my $logger = Log::Any->get_logger;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my @projects = (    #
	{
		'family'  => 'wikipedia',
		'lang'    => 'pl',
		'tag'     => 'sysop',
		'ignored' => [              # Adresy IP, których strony dyskusji nie są kasowane
			'77.112.179.85',
			'212.14.56.38',
			'159.205.121.230',
		],
		'action' => 'delete',
	},
	{
		'family'  => 'wikisource',
		'lang'    => 'pl',
		'ignored' => [               # Adresy IP, których strony dyskusji nie są kasowane
		],
		'action' => 'tag',
	},
);

my $dnsCache = $bot->retrieveData();

sub isOld($) {
	my $time = mktime( strptime( $_[0] ) );
	return unless $time;

	my $diff = time() - $time;
	$diff /= 3600;
	return ( $diff > 24 );
}

sub isVeryOld($) {
	my $time = mktime( strptime( $_[0] ) );
	return unless $time;

	my $diff = time() - $time;
	$diff /= ( 3600 * 24 );
	return ( $diff > 182.5 );
}

sub getName($) {
	return $dnsCache->{ $_[0] }
	  if exists $dnsCache->{ $_[0] };

	my $iaddr = inet_aton( $_[0] );                 # or whatever address
	my $value = gethostbyaddr( $iaddr, AF_INET );
	$dnsCache->{ $_[0] } = $value;
	return $value;
}

sub isDynamic($) {
	$_ = shift;
	return 0 unless defined;
	return 1 if /(?:ppp|adsl)\.tpnet\.pl$/;
	return 1 if /^(?:dial|dynamic)-.+\.dialog\.net\.pl$/;
	#return 1 if /\.dynamic\.t-mobile\.pl$/;
	return 1 if /^user-\d+-\d+-\d+-\d+\.play-internet\.pl$/;
	return 1 if /\.adsl\.inetia\.pl$/;
	return 1 if /\.gprs.*\.plus(?:gsm)?\.pl$/;
	return 1 if /-gprs.+\.centertel\.pl$/;
	return 1 if /\.dip\.t-dialin\.net$/;

	return 0;
}

sub deletePage {
	my ( $api, $page, $reason ) = @_;

	$logger->trace("Deleting $page->{title}");
	$api->delete(
		'title'  => $page->{title},
		'reason' => $reason,
	);
}

sub tagPage {
	my ( $api, $page, $reason ) = @_;

	$logger->trace("Tagging $page->{title}");
	return;    # FIXME: wielokrotne dodawanie tagów
	$api->edit(
		'title'          => $page->{title},
		'starttimestamp' => $page->{touched},
		'summary'        => "{{[[Template:Ek|ek]]}}, $reason",
		'minor'          => 1,
		'nocreate'       => 1,
		'bot'            => 1,
		'prependtext'    => "{{ek|$reason}}",
	);
}

my @list;

sub listPage {
	my ( $api, $page, $reason ) = @_;
	push @list, $page->{title};
}

foreach my $project (@projects) {
	$logger->info( "Checking user talk pages on $project->{family}" . ( defined $project->{lang} ? " ($project->{lang})" : "" ) );

	my $api = $bot->getApi( $project->{family}, $project->{lang}, $project->{tag} );
	$api->checkAccount;

	my %query = (
		'generator'    => 'allpages',
		'gapnamespace' => NS_USERTALK,
		'gaplimit'     => 50,
		'prop'         => 'info|revisions',
		'gapfrom'      => '0',
		'rvprop'       => 'timestamp',
		'maxlag'       => 20,
	);

	my $action;

	if ( $project->{action} eq 'delete' ) {
		$action = \&deletePage;
	}
	elsif ( $project->{action} eq 'tag' ) {
		$action = \&tagPage;
	}
	elsif ( $project->{action} eq 'none' ) {
		$action = sub { };
	}
	else {
		$logger->error("Unknown action $project->{action}");
		next;
	}

	my %ignored = map { $_ => 1 } @{ $project->{ignored} };

	my $iterator = $api->getIterator(%query);

	while ( my $page = $iterator->next ) {
		$logger->trace("Checking $page->{title}");
		last unless $page->{title} =~ /^Dyskusja (?:wikipedysty|wikipedystki|wikiskryby):\d/;
		next unless $page->{title} =~ /^Dyskusja (?:wikipedysty|wikipedystki|wikiskryby):(\d+\.\d+\.\d+\.\d+)$/;

		my $ip = $1;
		my ($revision) = values %{ $page->{revisions} };

		if ( $ignored{$ip} ) {
			$logger->info("Page $page->{title} ($revision->{timestamp}) is ignored");
			next;
		}

		if ( isVeryOld( $revision->{timestamp} ) ) {
			$logger->info("Page $page->{title} is very old ($revision->{timestamp}), deleting");
			&$action( $api, $page, 'strona dyskusji anonimowego użytkownika - ostatnia wiadomość starsza niż 6 miesięcy' );
		}
		elsif ( isOld( $revision->{timestamp} ) ) {
			my $name = getName($ip);

			$name = "" unless defined $name;
			if ( isDynamic($name) ) {
				$logger->info( "Page $page->{title} is old ($revision->{timestamp}), deleting" . ( $name eq '' ? '' : " ($name)" ) );
				&$action( $api, $page, 'stara strona dyskusji anonimowego użytkownika o dynamicznym adresie IP' );
			}
			else {
				$logger->info( "Page $page->{title} is old ($revision->{timestamp}), leaving" . ( $name eq '' ? '' : " ($name)" ) );
			}
		}
		else {
			$logger->info("Page $page->{title} is too recent ($revision->{timestamp})");
		}
	}

}

$bot->storeData($dnsCache);

# perltidy -et=8 -l=0 -i=8
