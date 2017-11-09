#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;

my $reason     = '';
my $expiry     = 'never';
my $cascade    = 0;
my $protection = 'edit=sysop|move=sysop';
my $sleep      = 10;

my $bot = new Bot4;
$bot->addOption( "reason|summary=s" => \$reason,     "Protect summary" );
$bot->addOption( "sleep=i"          => \$sleep,      "Protect interval" );
$bot->addOption( "expiry=s"         => \$expiry,     "Expiration time of protection" );
$bot->addOption( "protection=s"     => \$protection, "Type of protection" );
#$bot->addOption( "cascade"          => \$cascade,    "" );

$bot->setup;

my $logger = Log::Any::get_logger;

my $api = $bot->getApi;
$api->checkAccount;

utf8::decode($expiry);
utf8::decode($reason);
utf8::decode($protection);

while (<>) {
	utf8::decode($_);
	s/\s+$//g;
	next if $_ eq '';

	$logger->info("Protecting '$_'.");
	eval {    #
		$api->protect(
			title       => $_,
			expiry      => $expiry,
			reason      => $reason,
			protections => $protection,
		);
		sleep($sleep) if $sleep;
	};
	if ($@) {
		$logger->error("Unable to protect '$_': $@");
	}
}

# perltidy -et=8 -l=0 -i=8
