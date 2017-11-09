package MediaWiki::API::Iterator;

use strict;
use warnings;
use utf8;

sub new {
	my $caller = shift;
	my $class  = ref($caller) || $caller;
	my $this   = {
		'owner'    => shift,
		'queue'    => [],
		'finished' => 0,
		'continue' => 1,
		'field'    => undef,
	};
	$this->{query} = {@_};

	bless $this, $class;
	return $this;
}

sub continue : lvalue {
	my $this = shift;
	$this->{continue} = shift(@_) ? 1 : 0 if @_;
	$this->{continue};
}

sub field : lvalue {
	my $this = shift;
	$this->{field} = shift(@_) ? 1 : 0 if @_;
	$this->{field};
}

sub next {
	my $this = shift;

	unless ( scalar @{ $this->{queue} } ) {
		return if $this->{finished};
		$this->_fetch;
	}

	if ( scalar @{ $this->{queue} } ) {
		return shift @{ $this->{queue} };
	}
}

sub _fetch {
	my $this = shift;

	$this->{query}->{rawcontinue} = 1;
	my $response = $this->{owner}->query( %{ $this->{query} } );
	my $result;
	if ( defined $this->{field} ) {
		$result = $response->{query}->{ $this->{field} };
	}
	else {
		delete $response->{query}->{normalized};
		die "Multiple responses!" if scalar keys %{ $response->{query} } > 1;
		($result) = values %{ $response->{query} };
	}

	push @{ $this->{queue} }, values %{$result};

	if ( $response->{'query-continue'} and $this->{continue} ) {
		die "Multiple query-continue options!" if scalar keys %{ $response->{'query-continue'} } > 1;
		my ($cnt) = values %{ $response->{'query-continue'} };
		foreach my $field ( keys %{$cnt} ) {
			$this->{query}->{$field} = $cnt->{$field};
		}
	}
	else {
		$this->{finished} = 1;
	}
}

1;

# perltidy -et=8 -l=0 -i=8
