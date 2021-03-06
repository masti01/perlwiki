#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Text::Diff;
use Data::Dumper;
use MediaWiki::Gadgets;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $logger = Log::Any->get_logger;
$logger->info("Start");

sub fetchPages {
	my $api = shift;

	my $iterator = $api->getIterator(
		'list'        => 'allpages',
		'aplimit'     => 'max',
		'apnamespace' => NS_MEDIAWIKI,
	);

	my %pages;
	while ( my $page = $iterator->next ) {
		next if $page->{ns} != NS_MEDIAWIKI;
		$pages{ $page->{title} } = $page;
	}
	return %pages;
}

my @projects = (    #
	{           #
		'family' => 'wikipedia',
		'lang'   => 'pl',
		'prefix' => '',
	},
	{           #
		'family' => 'wikisource',
		'lang'   => 'pl',
		'prefix' => 's',
	},
	{           #
		'family' => 'wikibooks',
		'lang'   => 'pl',
		'prefix' => 'b',
	},
	{           #
		'family' => 'wiktionary',
		'lang'   => 'pl',
		'prefix' => 'wikt',
	},
	{           #
		'family' => 'wikinews',
		'lang'   => 'pl',
		'prefix' => 'n',
	},
	{           #
		'family' => 'wikiquote',
		'lang'   => 'pl',
		'prefix' => 'q',
	},
);

my %pages;

foreach my $project (@projects) {
	$logger->info("Pobieranie listy z $project->{lang}.$project->{family}...");

	my $api = $bot->getApi( $project->{family}, $project->{lang} );
	$api->checkAccount;

	my %list = fetchPages($api);
	while ( my ( $title, $page ) = each %list ) {
		$pages{$title}{$project} = $page;
	}
}

my $report = "{| class=\"wikitable\"\n";
$report .= "! nazwa\n";
foreach my $project (@projects) {
	$report .= "! $project->{lang}.$project->{family}\n";
}

foreach my $title ( sort keys %pages ) {
	$report .= "|-\n";

	my $shortTitle = $title;
	$shortTitle =~ s/^[^:]+://;
	$report .= "| $shortTitle\n";

	foreach my $project (@projects) {
		if ( $pages{$title}{$project} ) {
			$report .= "| [[$project->{prefix}:$title|link]]\n";
		}
		else {
			$report .= "| [[$project->{prefix}:$title|<span style=\"color: #BA0000\">brak</span>]]\n";
		}
	}
}
$report .= "|}\n";

print $report;
