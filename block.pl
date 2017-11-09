#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;

my $reason  = '';
my $expiry  = 'never';
my $cascade = 0;
my $sleep   = 10;
our $anononly  = 0;
our $nocreate  = 0;
our $autoblock = 0;
our $noemail   = 0;

my $bot = new Bot4;
$bot->addOption( "reason|summary=s" => \$reason, "Block summary" );
$bot->addOption( "sleep=i"          => \$sleep,  "Block interval" );
$bot->addOption( "expiry=s"         => \$expiry, );
$bot->addOption( 'anononly'         => \$anononly, );
$bot->addOption( 'nocreate'         => \$nocreate, );
$bot->addOption( 'autoblock'        => \$autoblock, );
$bot->addOption( 'noemail'          => \$noemail, );

$bot->setup;

my $logger = Log::Any->get_logger();

utf8::decode($expiry);
utf8::decode($reason);

my $api = $bot->getApi;
$api->checkAccount;

while (<>) {
	utf8::decode($_);
	s/\s+$//g;
	next if $_ eq '';

	my %query = (
		'user'   => $_,
		'expiry' => $expiry,
		'reason' => $reason,
	);
	foreach my $arg ( 'anononly', 'nocreate', 'autoblock', 'noemail' ) {
		no strict 'refs';
		$query{$arg} = 1 if $$arg;
	}
	$logger->info("Blocking '$_'.");
	eval {
		$api->block(%query);
		sleep($sleep) if $sleep;
	};
	if ($@) {
		$logger->error("Unable to block '$_': $@");
	}
}

# perltidy -et=8 -l=0 -i=8
