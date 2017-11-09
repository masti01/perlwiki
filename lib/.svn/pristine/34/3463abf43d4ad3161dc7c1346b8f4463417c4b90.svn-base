package MediaWiki::Unserializer;

use strict;
use warnings;
use utf8;
use Tie::IxHash;

=head1 ORIGINAL AUTHOR INFORMATION

 PHP::Serialization
 Copyright (c) 2003 Jesse Brown <jbrown@cpan.org>. All rights reserved.
 This program is free software; you can redistribute it and/or modify it
 under the same terms as Perl itself.

=cut

sub new {
	my $self = bless( {}, shift );
	return $self;
}

sub decode {
	my $self   = shift;
	my $string = shift;

	use Carp qw(croak confess);
	my $cursor = 0;
	$$self{'string'} = \$string;
	$$self{'cursor'} = \$cursor;
	$$self{'strlen'} = length($string);

	# Ok, start parsing...
	my @values = $self->_parse();

	# Ok, we SHOULD only have one value..
	if ( $#values == -1 ) {

		# Oops, none...
		return;
	}
	elsif ( $#values == 0 ) {

		# Ok, return our one value..
		return $values[0];
	}
	else {

		# Ok, return a reference to the list.
		return \@values;
	}

}    # End of decode sub.

my %type_table = (
	's' => \&_parsescalar,
	'a' => \&_parsearray,
	'i' => \&_parsenum,
	'd' => \&_parsenum,
	'b' => \&_parseboolean,
	'N' => \&_parseundef,
);

sub _parse {
	my $self   = shift;
	my $cursor = $$self{'cursor'};
	my $string = $$self{'string'};
	my $strlen = $$self{'strlen'};

	use Carp qw(croak confess);

	my @elems;
	while ( $$cursor < $strlen ) {

		# Ok, decode the type...
		my $type = $self->_readchar();

		# Ok, see if 'type' is a start/end brace...
		if ( $type eq '{' ) { next; }
		if ( $type eq '}' ) {
			last;
		}

		if ( !exists $type_table{$type} ) {
			confess "Unknown type '$type'! at $$cursor";
		}
		$self->_skipchar();    # Toss the seperator

		# Ok, do per type processing..
		my $handler = $type_table{$type};

		if ( defined $handler ) {
			push @elems, &$handler( $self, $type );
		}
		else {
			confess "Unknown element type '$type' found! (cursor $$cursor)";
		}
	}    # End of while.

	# Ok, return our elements list...
	return @elems;

}    # End of decode.

sub _parsearray {
	my $self = shift;

	# Ok, our sub elements...
	$self->_skipchar();    # Toss the seperator
	my $elemcount = $self->_readnum();
	$self->_skipchar();    # Toss the seperator
	tie( my %hash, 'Tie::IxHash', $self->_parse() );
	return \%hash;
}

sub _parsescalar {
	my $self = shift;

	# Ok, get our string size count...
	my $strlen = $self->_readnum();

	$self->_skipchar();    # Toss the seperator
	$self->_skipchar();    # Toss the seperator

	my $string = $self->_readstr($strlen);

	$self->_skipchar();    # Toss the seperator
	$self->_skipchar();    # Toss the seperator

	return $string;
}

sub _parsenum {
	my $self = shift;
	my $type = shift;

	# Ok, read the value..
	my $val = $self->_readnum();
	if ( $type eq 'i' ) { $val = int($val); }
	$self->_skipchar();    # Toss the seperator
	return $val;
}

sub _parseboolean {
	my $self = shift;

	# Ok, read our boolen value..
	my $bool = $self->_readchar();
	$self->_skipchar();    # Toss the seperator
	return $bool;
}

sub _parseundef {

	# Ok, undef value..
	return undef;
}

sub _readstr {
	my $self   = shift;
	my $string = $$self{'string'};
	my $cursor = $$self{'cursor'};
	my $length = shift;

	my $str = substr( $$string, $$cursor, $length );
	$$cursor += $length;

	utf8::decode($str);
	return $str;
}    # End of readstr.

sub _readchar {
	my $self = shift;
	return $self->_readstr(1);
}    # End of readstr.

sub _readnum {

	# Reads in a character at a time until we run out of numbers to read...
	my $self   = shift;
	my $cursor = $$self{'cursor'};

	my $string;
	while (1) {
		my $char = $self->_readchar();
		if ( $char !~ /^[-\d\.]+$/ ) {
			$$cursor--;
			last;
		}
		$string .= $char;
	}    # End of while.

	return $string;
}    # End of readnum

sub _skipchar {
	my $self = shift;
	${ $$self{'cursor'} }++;
}    # Move our cursor one bytes ahead...

1;

# perltidy -et=8 -l=0 -i=8
