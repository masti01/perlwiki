#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;

my $reason     = '';
my $sleep      = 10;
my $noredirect = 0;

my $bot = new Bot4;
$bot->addOption( "reason|summary=s", \$reason, "Move summary" );
$bot->addOption( "sleep=i",          \$sleep,  "Move interval" );

$bot->addOption( "noredirect|suppressredirect", \$noredirect, "Performs page move without leaving the redirect behind" );

$bot->setup;

my $logger = Log::Any::get_logger;

utf8::decode($reason);

my $api = $bot->getApi;
$api->checkAccount;

sub move {
	my ( $oldtitle, $newtitle ) = @_;

	$logger->info("Moving '$oldtitle' -> '$newtitle'");

	eval {
		my %request = (    #
			'from' => $oldtitle,
			'to'   => $newtitle,
		);
		$request{noredirect} = 1       if $noredirect;
		$request{summary}    = $reason if $reason ne '';

		$api->move(%request);
	};
	if ($@) {
		$logger->error("Unable to move '$oldtitle' -> '$newtitle': $@");
	}
}

while (<>) {
	utf8::decode($_);
	s/\s+$//g;
	next if $_ eq '';

	unless (/\[\[:?(.+?)\]\] -> \[\[:?(.+?)\]\]/) {
		die "Unable to parse: $_\n";
	}
	if ( $1 eq $2 ) {
		$logger->warn("Ignoring move from '$1' to itself");
		next;
	}
	move( $1, $2 );
	sleep($sleep) if $sleep;
}

# perltidy -et=8 -l=0 -i=8
