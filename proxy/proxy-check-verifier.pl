#!/usr/bin/perl

use strict;
use utf8;
use CGI;
use ProxyDatabase;
use Env;
use FindBin qw($RealBin);

binmode STDOUT, ":utf8";

my $db         = "$RealBin/../var/proxy.sqlite";
my $sessionId  = CGI::param('id');
my $remoteAddr = $ENV{REMOTE_ADDR};

sub error {
	print "Content-type: text/html; charset=utf-8\n\nERROR";
	exit(0);
}

error()
  unless defined $sessionId and defined $remoteAddr;

my $dbh = ProxyDatabase->new( 'file' => $db );

error()
  unless $dbh->setSessionAddress( $sessionId, $remoteAddr );

print "Content-type: text/html; charset=utf-8\n\nSUCCESS";
