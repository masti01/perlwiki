package IRC::Utils;
require Exporter;

use strict;
use utf8;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(hasFormatting stripFormatting);
our @EXPORT_OK = qw();
our $VERSION   = 20100708;

sub hasFormatting {
	return 1 if $_[0] =~ /[\002\037\026\017\003]/;
}

sub stripFormatting {
	my $text = shift;
	$text =~ tr/\002\037\026\017//d;
	$text =~ s/\003\d{0,2}(?:,\d{1,2})?//g;
	return $text;
}

1;
