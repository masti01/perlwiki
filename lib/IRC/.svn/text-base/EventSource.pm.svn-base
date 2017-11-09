package IRC::EventSource;
use strict;
use Log::Any;

use constant EVENT_HANDLED => "!EVENT_HANDLED";

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'handlers' => {},
		@_,
	};

	bless $this, $class;
	return $this;
}

sub invokeHandler {
	my $this = shift;
	my %data = @_;

	my $handlers = $this->{handlers}->{ $data{event} };
	return unless defined $handlers;

	foreach my $handler ( @{$handlers} ) {
		eval {
			my $r = &$handler( $this, \%data );
			return $r if defined $r and $r eq EVENT_HANDLED;
		};
		if ($@) {
			$logger->error( "The handler has thrown an exception: " . $@ );
		}
	}
}

*registerHandler = *registerHandlerLast;

sub registerHandlerLast {
	my ( $this, $name, @handlers ) = @_;

	push @{ $this->{handlers}->{$name} }, @handlers;
}

sub registerHandlerFirst {
	my ( $this, $name, @handlers ) = @_;

	unshift @{ $this->{handlers}->{$name} }, @handlers;
}

sub unregisterHandler {
	my ( $this, $name, @handlers ) = @_;
	my %handlers = map { $_ => 1 } @handlers;

	$this->{handlers}->{$name} = [ grep { !exists $handlers{$_} } @{ $this->{handlers}->{$name} } ];
}

1;

# perltidy -et=8 -l=0 -i=8
