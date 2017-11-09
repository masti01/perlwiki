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

sub getSubjectPageName($) {
	my $talkname = shift;
	return $talkname if $talkname =~ s/^Dyskusja://i;
	return $talkname if $talkname =~ s/^Dyskusja wikipedyst(?:y|ki):/Wikipedysta:/i;
	return $talkname if $talkname =~ s/^Dyskusja kategorii:/Kategoria:/i;
	return $talkname if $talkname =~ s/^Dyskusja Wikipedii:/Wikipedia:/i;
	return $talkname if $talkname =~ s/^Dyskusja grafiki:/Grafika:/i;
	return $talkname if $talkname =~ s/^Dyskusja MediaWiki:/MediaWiki:/i;
	return $talkname if $talkname =~ s/^Dyskusja szablonu:/Szablon:/i;
	return $talkname if $talkname =~ s/^Dyskusja pomocy:/Pomoc:/i;
	return $talkname if $talkname =~ s/^Dyskusja portalu:/Portal:/i;
	return $talkname if $talkname =~ s/^Dyskusja Wikiprojektu:/Wikiprojekt:/i;
	return undef;
}

foreach my $ns ( 1, 5, 9, 11, 13, 15, 101, 103 ) {

	$bot->status("Sprawdzanie przestrzeni $ns");

	my $iterator = $api->getIterator(
		'list'          => 'allpages',
		'aplimit'       => 'max',
		'apfilterredir' => 'redirects',
		'apnamespace'   => $ns,
	);

	while ( my $talkpage = $iterator->next ) {
		print "* [[$talkpage->{title}]]\n";
		my $name = getSubjectPageName( $talkpage->{title} );
		die "** ERROR: nieprawidłowa nazwa strony dyskusji\n" unless defined $name;

		my $talkdata = $api->query(
			'titles'  => $talkpage->{title},
			'prop'    => 'revisions|info',
			'rvprop'  => 'size|ids|content|flags',
			'rvlimit' => 10,
			'list'    => 'backlinks',
			'bltitle' => $talkpage->{title},
			'maxlag'  => 20,
		);

		die "** ERROR: brak informacji nt. linkujących\n" unless exists $talkdata->{query}->{backlinks};

		($talkpage) = values %{ $talkdata->{query}->{pages} };
		die "** ERROR: API nie rozpoznaje tej strony jako przekierowanie\n" unless exists $talkpage->{redirect};

		my $backlinks = scalar( values %{ $talkdata->{query}->{backlinks} } );
		my $revisions = scalar( values %{ $talkpage->{revisions} } );

		if ($backlinks) {
			print "** SKIP: backlinks: $backlinks\n";
			next;
		}
		else {
			print "** OK: backlinks: $backlinks\n";
		}

		if ( $revisions > 1 ) {
			print "** SKIP: revisions: $revisions\n";
			next;
		}
		else {
			print "** OK: revisions: $revisions\n";
		}

		my ($talkrevision) = values %{ $talkpage->{revisions} };
		unless ( $talkrevision->{'*'} =~ /#(?:REDIRECT|TAM|PRZEKIERUJ|PATRZ)\s*\[\[(.+?)\]\]/i ) {
			print "** SKIP: regexp failed\n";
			next;
		}

		my $data = $api->query(
			'titles'  => $name,
			'prop'    => 'info|categories',
			'cllimit' => 'max',
		);

		my ($page) = values %{ $data->{query}->{pages} };

		my $disambig = 0;
		if ( $page->{categories} ) {
			my $categories = { map { $_->{title} => 1 } values %{ $page->{categories} } };
			$disambig = exists $categories->{'Kategoria:Strony ujednoznaczniające'};
		}

		if ( exists $page->{missing} ) {
			print "** OK: hasło właściwe '$page->{title}' nie istnieje\n";
		}
		elsif ( exists $page->{redirect} ) {
			print "** OK: hasło właściwe '$page->{title}' jest przekierowaniem\n";
		}
		elsif ($disambig) {
			print "** OK: hasło właściwe '$page->{title}' jest stroną ujednoznaczniającą\n";
		}
		else {
			print "** SKIP: hasło właściwe '$page->{title}' jest artykułem\n";
			next;
		}

		print "** DELETE: kasowanie z powodem 'strona dyskusji przeniesiona do [[$1]]'\n";
		$api->delete(
			'title'  => $talkpage->{title},
			'reason' => "strona dyskusji przeniesiona do [[$1]]",
		);
	}
}

# perltidy -et=8 -l=0 -i=8
