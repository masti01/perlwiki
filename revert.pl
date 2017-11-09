#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;

my $reason;
my $sleep = 10;
my $start;
my $stop;
my $user;

my $bot = new Bot4;
$bot->addOption( "reason|summary=s" => \$reason, "Revert summary" );
$bot->addOption( "sleep=i"          => \$sleep,  "Revert interval" );
$bot->addOption( "user=s"           => \$user, );
$bot->addOption( "start=s"          => \$start, );
$bot->addOption( "stop=s"           => \$stop, );

$bot->setup;

my $logger = Log::Any->get_logger();

utf8::decode($user);
utf8::decode($reason);

my $api = $bot->getApi;
$api->checkAccount;

die "No user specified\n" unless defined $user;

my %request = (
	'list'    => 'usercontribs',
	'ucprop'  => 'title|comment|timestamp|ids',
	'ucuser'  => $user,
	'uclimit' => 'max',
);

$request{ucstart} = $start if defined $start;
$request{ucend}   = $stop  if defined $stop;

my $iterator = $api->getIterator(%request);

while ( my $entry = $iterator->next ) {
	eval {                                   #
		$logger->info("Reverting revision $entry->{revid} on page $entry->{title}");
		$api->edit(
			'title' => $entry->{title},
			'undo'  => $entry->{revid},
			'bot'   => 1,
		);
	};
	if ($@) {
		$logger->error($@);
	}
	sleep($sleep) if $sleep;
}

# perltidy -et=8 -l=0 -i=8
