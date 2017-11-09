package IRC::Socket;
use strict;
use base 'IRC::EventSource';
use Log::Any;

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = $class->SUPER::new(
		'pingFreq' => 60,
		'engine'   => 'IRC::Engine::Select',
		@_
	);

	bless $this, $class;
	$this->registerHandler( 'raw',   \&_raw );
	$this->registerHandler( 'PING',  \&_ping );
	$this->registerHandler( 'PONG',  \&_pong );
	$this->registerHandler( 'ERROR', \&_error );
	return $this;
}

sub connect {
	my $this = shift;
	my $server = shift || $this->{server};
	$this->{server} = $server;

	die "No server specified\n"
	  unless defined $server;

	$this->{buffer}   = '';
	$this->{nextPing} = time + $this->{pingFreq};
	$this->{pingSent} = 0;

	my $engineObj;
	if ( ref $this->{engine} ne '' ) {
		$engineObj = $this->{engine};
	}
	else {
		eval "require $this->{engine}";
		$engineObj = new $this->{engine};
	}
	$this->{engineObj} = $engineObj;

	$engineObj->registerHandler(
		'connected',
		sub {
			$logger->debug("Engine connected");
			$this->invokeHandler( 'event' => 'connected' );
		}
	);
	$engineObj->registerHandler(
		'disconnected',
		sub {
			$logger->debug("Engine disconnected");
			$this->{engineObj} = undef;
			$this->invokeHandler( 'event' => 'disconnected' );
		}
	);
	$engineObj->registerHandler(
		'data',
		sub {
			my ( $sender, $data ) = @_;
			$this->_processData( $data->{buffer} );
		}
	);
	$engineObj->registerHandler(
		'error',
		sub {
			my ( $sender, $data ) = @_;
			if ( $data->{message} ) {
				$logger->debug("Engine error: $data->{message}");
			}
			else {
				$logger->debug("Engine error");
			}
			$this->invokeHandler( %{$data} );
			$this->disconnect;
		}
	);
	return $engineObj->connect($server);
}

sub disconnect {
	my $this = shift;

	my $engineObj = $this->{engineObj};
	return unless defined $engineObj;

	$this->{engineObj} = undef;
	$engineObj->disconnect;
}

sub connected {
	my $this = shift;
	return ( defined $this->{engineObj} ? 1 : 0 );
}

sub handle {
	my $this = shift;
	return $this->{engineObj}->handle(@_);
}

sub _processData {
	my ( $this, $data ) = @_;

	$this->{buffer} .= $data;

	while ( $this->{buffer} =~ m/^(.*?)\r\n(.*)$/s ) {
		my $line = $1;
		$this->{buffer} = $2;

		next if $line eq '';

		$this->invokeHandler(
			'event'   => 'raw',
			'content' => $line,
		);
		if ( $line =~ m/^(?::(\S+)\s)?(\S+)(?:\s(.+))?$/ ) {

			# prefix, cmd, args
			$this->invokeHandler(
				'event'   => $2,
				'prefix'  => $1,
				'content' => $3,
			);
		}
	}

	# check pings
	my $time = time;
	if ( $this->{nextPing} < $time ) {
		if ( $this->{pingSent} ) {
			$logger->info("Ping timeout");
			$this->disconnect;
			return;
		}
		else {
			$this->send( "PING :" . $time );
			$this->{pingSent} = $time;
			$this->{nextPing} = $time + $this->{pingFreq};
		}
	}
}

sub send {
	my $this = shift;
	return unless $this->connected;

	foreach my $line (@_) {
		my $tmp = $line . "\r\n";
		utf8::encode($tmp) if utf8::is_utf8 $tmp;
		$logger->trace("SEND $line");
		$this->{engineObj}->send($tmp);
	}
}

# Event handlers

sub _ping {
	my ( $this, $data ) = @_;
	$this->send("PONG $data->{content}");
}

sub _pong {
	my $this = shift;

	$this->{nextPing} = time() + $this->{pingFreq};
	$this->{pingSent} = 0;
}

sub _error {
	my ( $this, $data ) = @_;
	$this->disconnect;
}

sub _raw {
	my ( $this, $data ) = @_;
	$logger->trace("RECV $data->{content}");
}

sub DESTROY {
	my $this = shift;

	# Disconnect client to free resources allocated for connection.
	$this->disconnect
	  if $this->connected;
}

1;

# perltidy -et=8 -l=0 -i=8
