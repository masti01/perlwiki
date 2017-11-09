#!/usr/bin/perl -w

use strict;
use utf8;
use Log::Any;
use Bot4;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $logger = Log::Any->get_logger;
$logger->info("Start");

my @projects = (
	{    #
		'family'   => 'wikipedia',
		'language' => 'pl',
		'titles'   => [ 'Strona główna', 'Wikipedia:Przyznawanie uprawnień', 'Wikipedia:Tablica ogłoszeń', 'Wikipedia:TO' ],
	},
	{    #
		'family'   => 'wikisource',
		'language' => 'pl',
		'titles'   => ['Wikiźródła:Strona główna'],
	},
);

foreach my $project (@projects) {
	eval {
		my $api = $bot->getApi( $project->{family}, $project->{language} );
		$api->checkAccount;
		my $response = $api->query(    #
			'action' => 'purge',
			'titles' => join( "|", @{ $project->{titles} } ),
		);
	};
	if ($@) {
		$logger->error($@);
	}

}
$logger->info("Finished");

# perltidy -et=8 -l=0 -i=8
