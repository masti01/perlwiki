#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;

my $logger = Log::Any->get_logger;
$logger->info("Start");

my $bot = new Bot4;
$bot->single(1);
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

$logger->info("Sprawdzanie nowych plików");
$bot->status("Sprawdzanie nowych plików");

my $iterator = $api->getIterator(
	'list'    => 'logevents',
	'letype'  => 'upload',
	'lelimit' => 1000,
	'maxlag'  => 20,
);
$iterator->continue = 0;

my %entries;
while ( my $entry = $iterator->next ) {
	next unless $entry->{pageid};
	next if exists $entries{ $entry->{title} };
	$entries{ $entry->{title} } = $entry;
}
my @entries = values %entries;

while (@entries) {
	my $data = $api->query(
		'titles'  => join( '|', map { $_->{title} } splice( @entries, 0, 20 ) ),
		'prop'    => 'categories|revisions|info',
		'rvprop'  => 'user|timestamp',
		'cllimit' => 'max',
	);
	die Dumper( $data->{'query-continue'} ) if exists $data->{'query-continue'};

	foreach my $page ( values %{ $data->{query}->{pages} } ) {
		next if exists $page->{missing};
		next if exists $page->{redirect};
		next if $page->{categories};

		my ($revision) = values %{ $page->{revisions} };

		my $entry = $entries{ $page->{title} };
		$logger->info("[[$page->{title}]] - nie ma kategorii, wrzucał [[User:$entry->{user}]], ostatnio edytował [[User:$revision->{user}]]");
		next unless $revision->{user} eq $entry->{user};

		eval {
			$api->edit(
				'title'          => $page->{title},
				'starttimestamp' => $page->{touched},
				'basetimestamp'  => $revision->{timestamp},
				'summary'        => "automatyczne oznaczenie pliku bez podanej licencji",
				'minor'          => 1,
				'bot'            => 1,
				'nocreate'       => 1,
				'appendtext'     => "\n{{subst:bl}}",
			);
			$logger->info("[[$page->{title}]] - wstawiono {{subst:bl}}");
			$api->sendMessage( $entry->{user}, "[[:$page->{title}]]", '{{Dodaj licencję}}<span style="font-size:90%">Ten komunikat został wysłany automatycznie przez bota ~~~~</span>' );
			$logger->info("[[User talk:$entry->{user}]] - wstawiono {{Dodaj licencję}}");
		};
		if ($@) {
			$logger->error($@);
		}
	}
}

# perltidy -et=8 -l=0 -i=8
