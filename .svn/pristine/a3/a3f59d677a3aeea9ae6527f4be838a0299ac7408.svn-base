#!/usr/bin/perl -w

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use Bot4;
use ProxyDatabase;
use WWW::Mechanize;
use HTML::Entities qw(decode_entities);

my $db  = "$RealBin/../var/proxy.sqlite";
my $bot = new Bot4;

$bot->single(1);
$bot->addOption( "database=s", \$db, "Changes path to a database" );
$bot->setup( 'root' => "$RealBin/.." );

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $dbh = ProxyDatabase->new( 'file' => $db );
my $mech = new WWW::Mechanize;
$mech->agent_alias('Windows Mozilla');

$mech->get('http://mrhinkydink.com/proxies.htm');

sub extractLinks {
	my @links = $mech->content =~ m{<td>(\d+\.\d+\.\d+\.\d+)(?:<sup>\*</sup>)?</td>\s*<td>(\d+)</td>}g;
	die "Unable to find links\n"
	  unless @links;

	$dbh->begin;
	while (@links) {
		my ( $address, $port ) = splice @links, 0, 2;
		my $link = "$address:$port";
		$logger->info("Enqueueing $link for scan");
		$dbh->insertOrIgnoreProxy( $link, $mech->uri->as_string );
	}
	$dbh->commit;
}

die "Unable to find pager\n"
  unless $mech->content =~ m{<a href="proxies(\d+)\.htm">\[\d+\]</a>&nbsp;\s*</td>}s;

my $count = $1;

die "Number of pages is too high ($count)\n"
  if $count > 100;

extractLinks;

for ( my $i = 2 ; $i < $count ; $i++ ) {
	sleep( int( rand(10) ) + 5 );
	$logger->info("Checking page $i of $count");
	$mech->get("http://mrhinkydink.com/proxies$i.htm");
	extractLinks;
}
