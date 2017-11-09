package IRC::Engine::AnyEvent;
use strict;
use AnyEvent::Handle;
use base 'IRC::EventSource';

sub connect {
	my $this   = shift;
	my $server = shift;

	unless ( $server =~ /^(.+):(\d+)$/ ) {
		die "Invalid server name: $server\n";
	}

	$this->{handle} = new AnyEvent::Handle
	  connect    => [ $1, $2 ],
	  on_connect => sub {
		$this->invokeHandler( 'event' => 'connected' );
	  },
	  on_read => sub {
		my $handle = shift;
		$this->invokeHandler( 'event' => 'data', 'buffer' => $handle->rbuf );
		$handle->rbuf = "";
	  },
	  on_error => sub {
		my ( $handle, $fatal, $msg ) = @_;
		$handle->destroy;
		$this->{handle} = undef;
		$this->invokeHandler( 'event' => 'error', 'message' => $msg );
	  },
	  on_eof => sub {
		my $handle = shift;
		$handle->destroy;
		$this->{handle} = undef;
		$this->invokeHandler( 'event' => 'disconnected' );
	  },
	  on_rtimeout => sub {
		$this->invokeHandler( 'event' => 'data', 'buffer' => '' );
	  },
	  rtimeout => 30;
}

sub disconnect {
	my $this = shift;
	return
	  unless defined $this->{handle};

	$this->{handle}->push_shutdown
	  if $this->{handle}->fh;
	$this->{handle} = undef;

	$this->invokeHandler( 'event' => 'disconnected' );
}

sub handle {
	die "Not implemented\n";
}

sub send {
	my ( $this, $data ) = @_;
	die "Socket is not connected\n"
	  unless defined $this->{handle};

	$this->{handle}->push_write($data);
}

1;

# perltidy -et=8 -l=0 -i=8
