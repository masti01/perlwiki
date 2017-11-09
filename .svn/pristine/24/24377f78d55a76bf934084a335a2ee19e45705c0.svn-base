#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;

my $reason = '';
my $sleep  = 10;

my $bot = new Bot4;
$bot->addOption( "reason|summary=s", \$reason, "Delete summary" );
$bot->addOption( "sleep=i",          \$sleep,  "Delete interval" );

$bot->setup;

my $logger = Log::Any::get_logger;

my $api = $bot->getApi;
$api->checkAccount;

utf8::decode($reason);

while (<>) {
	utf8::decode($_);
	s/\s+$//g;
	next if $_ eq '';

	$logger->info("Deleting '$_'.");
	eval {
		$api->delete( 'title' => $_, 'reason' => $reason, );
		sleep($sleep) if $sleep;
	};
	if ($@) {
		$logger->error("Unable to delete '$_': $@");
	}
}

# perltidy -et=8 -l=0 -i=8
