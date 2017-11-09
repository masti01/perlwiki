#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;

my $logger = Log::Any::get_logger;

my $bot = new Bot4;
$bot->setup;

my $api = $bot->getApi( "wiktionary", "pl" );
$api->checkAccount;

my $iterator = $api->getIterator(
	'generator' => 'embeddedin',
	'prop'      => 'revisions|info',
	'rvprop'    => 'content|timestamp',
	'geititle'  => 'Szablon:a tergo/kategoria',
	'geilimit'  => 10,
);

while ( my $page = $iterator->next ) {
	$logger->info("Null-editing page: $page->{title}");
	my ($revision) = values %{ $page->{revisions} };
	eval {    #
		$api->edit(
			title          => $page->{title},
			starttimestamp => $page->{touched},
			text           => $revision->{'*'},
			#bot            => 1,
			minor          => 1,
			summary        => "",
			basetimestamp  => $revision->{timestamp},
			nocreate       => 1,
		);
	};
	if ($@) {
		$logger->error($@);
	}
}

# perltidy -et=8 -l=0 -i=8
