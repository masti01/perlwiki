package IRC::Connection::User;
use strict;
use Log::Any;

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'nick'     => undef,
		'ident'    => undef,
		'host'     => undef,
		'channels' => {},
		@_
	};

	bless $this, $class;
	$logger->trace("User $this->{nick} has been created");
	return $this;
}

sub getChannels {
	my $this = shift;
	return values %{ $this->{channels} };
}

sub getChannelData {
	my $this = shift;
	return $this->{channels}->{ $_[0] };
}

sub getName {
	my $this = shift;
	return $this->{nick};
}

sub getFullHost {
	my $this = shift;
	return $this->{nick} unless defined $this->{ident};
	return $this->{nick} . '!' . $this->{ident} . '@' . $this->{host};
}

sub DESTROY {
	my $this = shift;

	if ( $logger->is_trace ) {
		$logger->trace("User $this->{nick} is being destroyed");
	}
}

1;

# perltidy -et=8 -l=0 -i=8
