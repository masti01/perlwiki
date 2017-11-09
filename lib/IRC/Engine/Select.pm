package IRC::Engine::Select;
use strict;
use IO::Select;
use base 'IRC::EventSource';

my $socketPackage;

BEGIN {
	my $ipv6 = eval 'use IO::Socket::INET6; 1;';
	if ($ipv6) {
		require IO::Socket::INET6;
		$socketPackage = 'IO::Socket::INET6';
	}
	else {
		require IO::Socket::INET;
		$socketPackage = 'IO::Socket::INET';
	}
}

sub socket {
	my $this = shift;
	$this->{socket};
}

sub _createSocket {
	my $this   = shift;
	my $server = shift;

	$this->{socket} = $socketPackage->new(
		'PeerAddr' => $server,
		'Proto'    => 'tcp',
	);

	unless ( $this->{socket} ) {
		my $error = $!;
		$this->_invokeError( "Unable to establish a connection: $error", 'connect' );
		die "$error\n";
	}
}

sub connect {
	my $this   = shift;
	my $server = shift;

	$this->_createSocket($server)
	  unless defined $this->{socket};

	$this->{select} = IO::Select->new( $this->{socket} )
	  unless defined $this->{select};

	$this->{socket}->autoflush(1);

	$this->invokeHandler( 'event' => 'connected' );
}

sub disconnect {
	my $this = shift;
	return
	  unless defined $this->{socket};

	close( $this->{socket} );
	$this->{socket} = undef;
	$this->{select} = undef;

	$this->invokeHandler( 'event' => 'disconnected' );
}

sub handle {
	my $this    = shift;
	my $timeout = shift;
	$timeout |= 0;

	die "Socket is not connected\n"
	  unless defined $this->{socket};

	if ( $this->{select}->can_read($timeout) ) {
		my $buf;
		my $r = $this->{socket}->recv( $buf, 5120 );
		if ( !defined $r ) {
			$this->_invokeError( "Read error: $!", 'read' );
			return;
		}
		if ( !defined $buf or $buf eq '' ) {
			$this->_invokeError( "Read error, empty buffer: $!", 'read' );
			return;
		}

		$this->invokeHandler( 'event' => 'data', 'buffer' => $buf );
	}
	else {
		$this->invokeHandler( 'event' => 'data', 'buffer' => '' );
	}

	return 1;
}

sub send {
	my ( $this, $data ) = @_;
	die "Socket is not connected\n"
	  unless defined $this->{socket};

	$this->{socket}->send($data);
}

sub _invokeError {
	my ( $this, $message, $type ) = @_;
	$this->invokeHandler( 'event' => 'error', 'message' => $message, 'type' => $type );
	$this->disconnect;
}

1;

# perltidy -et=8 -l=0 -i=8
