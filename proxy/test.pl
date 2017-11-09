#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use FindBin qw($RealBin);
use ProxyDatabase;
use LWP::UserAgent;
use IO::Handle;
use Storable qw(freeze thaw);
use File::Spec;
use Log::Any;
use Log::Any::Adapter;

binmode STDIN;
binmode STDOUT;
STDOUT->autoflush(1);

my $db      = "$RealBin/../var/proxy.sqlite";
my $testUrl = 'http://tools.wikimedia.pl/~beau/cgi-bin/verify.pl?id=$sessionId';
my $agent   = 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.7) Gecko/2009021910 Firefox/3.0.7';

# Send all logs to Log::Log4perl
use Log::Log4perl;
Log::Log4perl->init( File::Spec->join( $RealBin, 'log4perl.conf' ) );
Log::Any::Adapter->set('Log4perl');

my $logger = Log::Any->get_logger;
$logger->info("Worker is being staterd");

my $dbh = ProxyDatabase->new( 'file' => $db );

my $address = $dbh->getSessionAddress('gS0Miu40UOhqU4nt4grzRjBiHE48z877');
print $address;
