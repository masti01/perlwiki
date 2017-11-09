#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $bot = new Bot4;
$bot->single(1);
$bot->setProject( "wikipedia", "pl", "sysop" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

while (<>) {
	next unless /^\| (.+?)\s+\|\s+$/;
	my $title = "Talk:$1";
	utf8::decode($title);

	$logger->info("[[$title]] Sprawdzanie strony");

	my $response = $api->query(
		'titles'  => $title,
		'prop'    => 'revisions|info',
		'rvprop'  => 'content|user',
		'rvlimit' => 10,
	);

	my ($page) = values %{ $response->{query}->{pages} };
	if ( exists $page->{missing} ) {
		$logger->info("[[$title]] Strona nie istnieje");
		next;
	}
	my @revisions = values %{ $page->{revisions} };

	my $last = $revisions[0];

	if ( $last->{'*'} ne '' ) {
		$logger->info("[[$title]] Strona nie jest pusta");
		next;
	}
	if ( scalar @revisions > 8 ) {
		$logger->info("[[$title]] Strona ma za dużo wersji");
		next;
	}

	foreach my $revision (@revisions) {
		my $content = $revision->{'*'};

		if ( $content eq '' ) {
			$revision->{delete} = 1;
			$revision->{reason} = 'pusta';
		}
		elsif ( $content =~ /^(?:\s*\{\{[Bb]ez infoboksu[^{}]+\}\})+$/ ) {
			$revision->{delete} = 1;
			$revision->{reason} = 'bez infoboksu';
		}
		elsif ( $content =~ /^(?:\s*\{\{[Mm]artwy link dyskusja[^{}]+\}\})+$/ ) {
			$revision->{delete} = 1;
			$revision->{reason} = 'martwy link';
		}
	}

	my $delete = 1;
	$logger->info("[[$title]] Lista edycji");
	foreach my $revision (@revisions) {
		$delete &&= $revision->{delete};
		my $verdict = $revision->{delete} ? 'tak' : 'nie';
		my $reason = defined $revision->{reason} ? $revision->{reason} : 'brak';
		$logger->info("[[$title]] Usunąć: $verdict, autor: $revision->{user}, powód: $reason");
	}
	next unless $delete;

	$logger->info("[[$title]] Usuwanie strony");
	$api->delete(
		'title'  => $page->{title},
		'reason' => "pusta strona",
	);
}

# perltidy -et=8 -l=0 -i=8
