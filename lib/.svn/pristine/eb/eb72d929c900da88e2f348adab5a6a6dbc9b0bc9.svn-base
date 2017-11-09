package Wiki::RcBot;
use strict;
use base 'IRC::Connection::Client';
use IRC::Connection::Client;
use Log::Any;
use AnyEvent;
use Data::Dumper;

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = $class->SUPER::new(
		'nick'     => 'rcbot',
		'username' => 'rcbot',
		'realname' => 'rcbot',
		'server'   => 'irc.wikimedia.org:6667',
		'engine'   => 'IRC::Engine::AnyEvent',
		'projects' => [],
		@_
	);

	bless $this, $class;

	$this->registerHandler( '001',             \&m_welcome );
	$this->registerHandler( '433',             \&m_nicknameinuse );
	$this->registerHandler( 'channel privmsg', \&m_channel_privmsg );

	return $this;
}

sub m_welcome {
	my $this = shift;

	$logger->info("Connected, joining channels");

	if ( @{ $this->{projects} } ) {
		$this->join( join( ",", @{ $this->{projects} } ) );
	}
}

sub m_nicknameinuse {
	my $this = shift;
	$this->send( "NICK $this->{nick}" . int( rand(10) ) );
}

sub m_channel_privmsg {
	my ( $this, $data ) = @_;

	utf8::decode( $data->{content} );

	my %args = (    #
		'channel' => $data->{channel}->{name},
	);
	if ( @args{ 'title', 'action', 'diff', 'user', 'size', 'summary' } = $data->{content} =~ m{^\x0314\[\[\x0307(.+?)\x0314\]\]\x034 (.*?)\x0310 \x0302(.*?)\x03 \x035\*\x03 \x0303(.+?)\x03 \x035\*\x03 \(?\x02?\+?(.*?)\x02?\)? \x0310(.*?)\x03?$} ) {

		if ( $args{diff} ne '' ) {

			$args{flags}{bot}   = 1 if $args{action} =~ s/B//;
			$args{flags}{new}   = 1 if $args{action} =~ s/N//;
			$args{flags}{minor} = 1 if $args{action} =~ s/M//;

			$args{approved} = $args{action} =~ s/!// ? 0 : 1;

			$logger->warn("Unknown flags: $args{action}") unless $args{action} eq '';

			$args{action} = 'edit';
		}

		$logger->debug( "Received notification\n" . Dumper( \%args ) )
		  if $logger->is_debug;
		$args{event} = "rc $args{action}";
		$this->invokeHandler(%args);
	}
	elsif ( @args{ 'title', 'project', 'url', 'user' } = $data->{content} =~ m{^\x0314\[\[\x0307(.+?)\x0314\]\]\x034\@(.*?)\x0310 \x0302(.*?)\x03 \x035\*\x03 \x0303(.+?)\x03 \x035\*\x03$} ) {
		$args{action} = 'create';
		$logger->debug( "Received notification\n" . Dumper( \%args ) )
		  if $logger->is_debug;
		$args{event} = "rc $args{action}";
		$this->invokeHandler(%args);
	}
	else {
		$logger->warn("Unable to parse message from $data->{prefix} to $data->{target}: $data->{content}");
	}
}

sub loop {
	my $this = shift;
	my $quit;

	$this->registerHandler(
		'disconnected',
		sub {
			$logger->info("Client has been disconnected");
			$quit->send;
		}
	);
	$this->registerHandler(
		'error',
		sub {
			my ( undef, $data ) = @_;

			if ( $data->{message} ) {
				$logger->info("Client has reported an error: $data->{message}");
			}
			else {
				$logger->info("Client has reported an unknown error");
			}
			$quit->send;
		}
	);

	while (1) {
		$quit = AnyEvent->condvar;
		eval {    #
			$logger->debug("Connecting");
			$this->connect;
			$logger->debug("Entering event loop");
			$quit->recv;
		};
		if ($@) {
			$logger->error($@);
		}
		sleep(10);
	}
}

1;

__END__

Actions:
  delete
  restore
  create
  block
  reblock
  unblock
  move
  move_redir
  overwrite
  edit
  unknown
  protect
  unprotect
  upload
  modify
  renameuser
  usergroups
  rights
  lockandhid
  lock
  hide
  create2
  gblock
  revision
  event
  approve
  approve-i
  approve-a
  approve-ia
  unapprove
  patrol
  autocreate
  autopromote
