#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;

my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->single(1);
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

my $reLangLink;
{
	local $" = "|";
	my @prefixes = map { quotemeta( $_->{prefix} ) } grep { exists $_->{language} } $api->getInterwikiMap;
	$reLangLink = qr/\[\[(?:@prefixes):.+?\]\]/i;
}

my $data = $api->query(
	'action'       => 'query',
	'generator'    => 'search',
	'gsrsearch'    => 'ciekawostki',
	'gsrnamespace' => 0,
	'gsrwhat'      => 'text',
	'gsrlimit'     => 'max',
	'prop'         => 'revisions|info',
	'rvprop'       => 'content',
);

#print Dumper $data;

my %pages;
foreach my $page ( values %{ $data->{query}->{pages} } ) {
	next if exists $page->{missing};
	$pages{ $page->{title} } = $page;
}

my $text = "Ostatnia aktualizacja: ~~~~~\n";
foreach my $title ( sort keys %pages ) {
	my $page = $pages{$title};
	$text .= "== [[$title]] ==\n";
	my ($revision) = values %{ $page->{revisions} };
	my $content = $revision->{'*'};

	if ( defined $content && $content =~ m/\n={1,5}\s*ciekawostk[ai]\s*={1,5}\s*(.+?)(?:\n=|$)/si ) {
		$content = $1;

		# Usuń kategorie
		$content =~ s/\[\[(?:Kategoria|Category):(.+?)\]\]//gi;

		# Usuń komentarze
		$content =~ s/<!--(.+?)-->//sg;

		# Usuń interwiki
		$content =~ s/$reLangLink//g;

		# Popraw linki
		$content =~ s/\{\{/{{s|/g;
		$content =~ s/\[\[/[[:/g;

		# Usuń puste linie
		$content =~ s/\s*\n\s*/\n/g;

		$text .= "$content\n";
	}
	else {
		$text .= "nie udało się skopiować sekcji z ciekawostkami\n";
	}
}

writeFile( "var/trivia.txt", $text );

exit(0)
  if $pretend;

$api->edit(
	title    => 'User:mastiBot/listy/ciekawostki',
	text     => $text,
	bot      => 1,
	summary  => "aktualizacja listy",
	notminor => 1,
);

# perltidy -et=8 -l=0 -i=8
