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

my $logger = Log::Any->get_logger;

my $api = $bot->getApi;

my $iterator = $api->getIterator(
	'action'         => 'query',
	'generator'      => 'allpages',
	'gaplimit'       => 'max',
	'gapfilterredir' => 'redirects',
	'prop'           => 'revisions',
	'rvprop'         => 'content',
);

my %list;
my $magicWord = $api->getMagicWords('redirect');
my @aliases = map { quotemeta } values %{ $magicWord->{aliases} };
local $" = '|';
my $redirect = qr/^(i?:@aliases)\s*\[\[.+?\]\]\s*$/i;

$logger->debug("Regular expression for redirects: $redirect");

while ( my $page = $iterator->next ) {
	$logger->info("Checking page [[$page->{title}]]");
	my ($revision) = values %{ $page->{revisions} };
	my $content = $revision->{'*'};
	next if $content =~ /$redirect/i;
	$list{ $page->{title} } = $content;
}

my $text = "Ostatnia aktualizacja: ~~~~~\n";
foreach my $title ( sort keys %list ) {
	my $content = $list{$title};

	$text .= "== [[$title]] ==\n";
	$text .= "<pre><nowiki>$content</nowiki></pre>\n";
}

writeFile( "var/redirects.txt", $text );

exit(0)
  if $pretend;

$api->edit(
	title    => 'User:mastiBot/listy/przekierowania',
	text     => $text,
	bot      => 1,
	summary  => "aktualizacja listy",
	notminor => 1,
);

# perltidy -et=8 -l=0 -i=8
