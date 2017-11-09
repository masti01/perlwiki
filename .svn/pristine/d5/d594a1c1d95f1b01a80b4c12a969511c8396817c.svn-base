#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use Bot4;
use ProxyDatabase;

my $db  = "$RealBin/../var/proxy.sqlite";
my $bot = new Bot4;

$bot->single(1);
$bot->addOption( "database=s", \$db, "Changes path to a database" );
$bot->setProject( 'wikipedia', 'pl', 'sysop' );
$bot->setup( 'root' => "$RealBin/.." );

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $dbh = ProxyDatabase->new( 'file' => $db );

my $api = $bot->getApi;
$api->checkAccount;

while ( my @list = $dbh->fetchBlocks ) {
	foreach my $block (@list) {
		$logger->info("Processing block request of $block->{address}");

		my $blocked = 0;
		{
			my $iterator = $api->getIterator(
				'action' => 'query',
				'list'   => 'blocks',
				'bkip'   => $block->{address},
			);

			while ( my $entry = $iterator->next ) {
				$blocked++;
				$logger->info( "Active blocks of $block->{address}:\n" . Dumper($entry) )
				  if $logger->is_info;
			}
		}
		{
			my $iterator = $api->getIterator(
				'action' => 'query',
				'list'   => 'globalblocks',
				'bgip'   => $block->{address},
			);

			while ( my $entry = $iterator->next ) {
				$blocked++;
				$logger->info( "Active global blocks of $block->{address}:\n" . Dumper($entry) )
				  if $logger->is_info;
			}
		}
		if ($blocked) {
			$logger->info("$block->{address} is already blocked");
		}
		else {
			$logger->info("Blocking $block->{address} with expiry $block->{expiry}");
			$api->block(
				'anononly' => 1,
				'nocreate' => 1,
				'user'     => $block->{address},
				'reason'   => '[[WP:OP|open proxy]]',
				'expiry'   => $block->{expiry},
			);

		}
		$dbh->removeBlock( $block->{id} );
	}
}
