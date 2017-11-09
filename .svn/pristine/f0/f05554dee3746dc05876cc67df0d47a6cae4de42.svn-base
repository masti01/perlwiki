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

#$mech->proxy( [ 'http', 'https' ] => '' );

my %links;
my @pages = (    #
	'http://www.xeronet-proxy-list.net/type/other_proxy',
	'http://www.xeronet-proxy-list.net/type/glype_proxy',
	'http://www.xeronet-proxy-list.net',
	#'http://www.proxywebsitelist.in',
	#'http://freeproxylistings.com',
);

foreach my $page (@pages) {
	eval {
		$logger->info("Checking $page");
		$mech->get($page);

		my $content = $mech->content;
		my $count   = 0;

		foreach my $link ( $content =~ m{<A href="[^">]+out\.php?[^">]+"[^>]*>\s*(http://[^>]+?)\s*</A>}isg ) {
			$links{$link}++;
			$count++;
		}
		if ($count) {
			$logger->info("Fetched $count links");
		}
		else {
			$logger->error("No links found on $page");
		}
	};
	if ($@) {
		$@ =~ s/\s+$//;
		$logger->error("Unable to fetch page $page: $@");
	}

}

die "Unable to find links\n"
  unless keys %links;

$dbh->begin;
foreach my $link ( keys %links ) {
	$link = decode_entities($link);
	$link = "http://$link"
	  unless $link =~ '://';

	$logger->info("Enqueueing $link for scan");
	$dbh->insertOrIgnoreProxy( $link, $mech->uri->as_string );
}
$dbh->commit;
