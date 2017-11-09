package MediaWiki::Utils;
require Exporter;

use strict;
use warnings;
use utf8;
use Time::Local qw(timegm);
use POSIX qw(strftime);

our @ISA       = qw(Exporter);
our @EXPORT    = qw(to_wiki_timestamp from_wiki_timestamp isAnonymous);
our @EXPORT_OK = qw();
our $VERSION   = 20091204;

sub to_wiki_timestamp($) {
	return strftime( "%Y-%m-%dT%H:%M:%SZ", gmtime( $_[0] ) );
}

sub from_wiki_timestamp($) {
	die "Errorneus timestamp: $_[0]\n" unless $_[0] =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/;
	return timegm( $6, $5, $4, $3, $2 - 1, $1 - 1900 );
}

# FIXME: sprawdzać także adresy IPv6
sub isAnonymous($) {
	my $user = shift;
	return 0 unless $user =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/;
	return 0 unless $1 < 256;
	return 0 unless $2 < 256;
	return 0 unless $3 < 256;
	return 0 unless $4 < 256;
	return 1;
}

1;
