#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use File::Spec;
use File::Path qw(make_path);
use autodie;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my @projects = (    #
	{           #
		'family' => 'wikipedia',
		'lang'   => 'pl',
		'list'   => [              #
			'Wikipedysta:ToSter/wpsk user.js',
			'Wikipedysta:Malarz pl/wp sk.js',
			'Wikipedysta:Nux/wp sk.js',
			'Wikipedysta:Nux/sel t.js',
			'Wikipedysta:Nux/nuxedtoolkit.js',
			'Wikipedysta:Nux/SearchBox.js',
			'Wikipedysta:Nux/SearchBox.css',
			'Wikipedysta:Nux/hideSidebar.js',
		],
	},
	{                                  #
		'family' => 'wiktionary',
		'lang'   => 'pl',
	},
	{                                  #
		'family' => 'wikibooks',
		'lang'   => 'pl',
	},
	{                                  #
		'family' => 'wikinews',
		'lang'   => 'pl',
	},
	{                                  #
		'family' => 'wikiquote',
		'lang'   => 'pl',
	},
	{                                  #
		'family' => 'wikisource',
		'lang'   => 'pl',
	},
	{                                  #
		'family' => 'wikipedia',
		'lang'   => 'en',
	},
	{                                  #
		'family' => 'wikipedia',
		'lang'   => 'de',
	},
);

foreach my $project (@projects) {
	$logger->info("Pobieranie skryptów z $project->{lang}.$project->{family}...");

	my $api = $bot->getApi( $project->{family}, $project->{lang} );
	$api->checkAccount;

	my $iterator = $api->getIterator(
		'list'        => 'allpages',
		'aplimit'     => 'max',
		'apnamespace' => NS_MEDIAWIKI,
	);

	my @titles;
	while ( my $page = $iterator->next ) {
		next unless $page->{ns} == NS_MEDIAWIKI;
		next unless $page->{title} =~ /\.(?:js|css)/i;
		push @titles, $page->{title};
	}

	push @titles, @{ $project->{list} }
	  if defined $project->{list};

	my $path = File::Spec->catdir( "var", "scripts", "$project->{lang}.$project->{family}" );
	make_path($path);

	while (@titles) {
		$iterator = $api->getIterator(
			'titles' => [ splice @titles, 0, 50 ],
			'prop'   => 'revisions',
			'rvprop' => 'content',
		);

		while ( my $page = $iterator->next ) {
			$page->{title} =~ tr/\//-/;
			my ($revision) = values %{ $page->{revisions} };
			open( my $fh, '>', File::Spec->catfile( $path, $page->{title} ) );
			binmode $fh, 'utf8';
			print $fh $revision->{'*'};
			close($fh);
		}
	}
}
