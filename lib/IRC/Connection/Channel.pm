package IRC::Connection::Channel;
use strict;
use Log::Any;

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'name'      => undef,
		'topic'     => undef,
		'users'     => {},
		'modes'     => {},
		'timestamp' => undef,
		@_
	};

	bless $this, $class;
	$logger->trace("Channel $this->{name} has been created");
	return $this;
}

sub getUsers {
	my $this = shift;
	return values %{ $this->{users} };
}

sub getChannelData {
	my $this = shift;
	return $this->{users}->{ $_[0] };
}

sub getName {
	my $this = shift;
	return $this->{name};
}

sub DESTROY {
	my $this = shift;

	if ( $logger->is_trace ) {
		$logger->trace("Channel $this->{name} is being destroyed");
	}
}

1;

# perltidy -et=8 -l=0 -i=8
