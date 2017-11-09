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

$mech->get('http://prx.centrump2p.com/');

sub extractLinks {
	my @links = $mech->content =~ /<td class="a1"><a href="([^"]+)/g;
	die "Unable to find links\n"
	  unless @links;

	$dbh->begin;
	foreach my $link (@links) {
		$link = decode_entities($link);
		$logger->info("Enqueueing $link for scan");
		$dbh->insertOrIgnoreProxy( $link, $mech->uri->as_string );

	}
	$dbh->commit;
}

die "Unable to find pager\n"
  unless $mech->content =~ m{<div id="pager">.+<a href="/(\d+)">\d+</a>\s*</div>}s;

my $count = $1;

die "Number of pages is too high ($count)\n"
  if $count > 100;

extractLinks;

for ( my $i = 2 ; $i < $count ; $i++ ) {
	sleep( int( rand(10) ) + 5 );
	$logger->info("Checking page $i of $count");
	$mech->get("http://prx.centrump2p.com/$i");
	extractLinks;
}
