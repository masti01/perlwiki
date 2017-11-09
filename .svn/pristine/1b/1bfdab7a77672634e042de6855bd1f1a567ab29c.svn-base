#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;
use Data::Dumper;
use DBI;
use RevisionCache;

# Jak pobrać informacje o tym, czy wersja została przejrzana?

my $all = 0;
my $bot = new Bot4;
$bot->single(1);
$bot->addOption( "all", \$all, "Imports all changes" );
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my @projects = (    #
	{           #
		'family' => 'wikipedia',
		'lang'   => 'pl',
	},
	{           #
		'family' => 'wikisource',
		'lang'   => 'pl',
	},
	{           #
		'family' => 'wikibooks',
		'lang'   => 'pl',
	},
	{           #
		'family' => 'wiktionary',
		'lang'   => 'pl',
	},
	{           #
		'family' => 'wikinews',
		'lang'   => 'pl',
	},
	{           #
		'family' => 'wikiquote',
		'lang'   => 'pl',
	},
);

foreach my $project (@projects) {
	$logger->info("Downloading pages from $project->{lang}.$project->{family}...");

	my $api = $bot->getApi( $project->{family}, $project->{lang} );
	$api->checkAccount;

	my $cache = new RevisionCache( 'project' => "$project->{lang}.$project->{family}" );

	my $selectLastRevid = $cache->dbh->prepare('SELECT MAX(rev_id) FROM revisions WHERE rev_project = ?');
	$selectLastRevid->execute( $cache->{projectId} );
	my ($lastRevid) = $selectLastRevid->fetchrow_array;
	$lastRevid ||= 0;

	my $iterator = $api->getIterator(
		'action'  => 'query',
		'list'    => 'recentchanges',
		'rcshow'  => 'anon',
		'rctype'  => 'edit',
		'rcprop'  => 'user|userid|timestamp|ids|title|comment',    # sizes
		'rclimit' => $all ? 'max' : '100',
	);

	$cache->begin_work;
	while ( my $entry = $iterator->next ) {
		if ( $logger->is_debug ) {
			$logger->debug( Dumper($entry) );
		}
		last
		  if !$all and $entry->{revid} <= $lastRevid;

		$cache->storeRevision(
			'id'        => $entry->{revid},
			'page'      => $entry->{title},
			'parentId'  => $entry->{old_revid},
			'userText'  => $entry->{user},
			'userId'    => $entry->{userid},
			'timestamp' => $entry->{timestamp},
			'comment'   => $entry->{comment},
		);
	}
	$cache->commit;
}
