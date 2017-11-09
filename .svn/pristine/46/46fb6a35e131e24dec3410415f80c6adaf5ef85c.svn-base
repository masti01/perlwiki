#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use DBI;
use Env;
use DateTime;
use DateTime::Format::Strptime;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $dbh = DBI->connect(    #
	"DBI:mysql:mysql_read_default_group=wikibot;mysql_read_default_file=$ENV{HOME}/.my.cnf",
	undef,
	undef,
	{ RaiseError => 1, 'mysql_enable_utf8' => 1 }
) or die "Can't connect to database...\n";

my $db_insert = $dbh->prepare('REPLACE INTO logevents VALUES (?, ?, ?, ?, ?, ?)');
my $db_purge  = $dbh->prepare('DELETE FROM logevents WHERE timestamp < ?');
my $db_getmax = $dbh->prepare('SELECT MAX(timestamp) FROM logevents WHERE action IN (?, ?)');

my $df = new DateTime::Format::Strptime(
	pattern   => '%Y-%m-%dT%TZ',
	time_zone => 'UTC',
	on_error  => 'croak',
);

my $oldest_entry = $df->format_datetime( DateTime->now( time_zone => 'UTC' ) - DateTime::Duration->new( 'months' => 1 ) );
$db_purge->execute($oldest_entry);

my $api = $bot->getApi( "wikipedia", "pl" );

{
	$bot->status("Pobieranie listy blokad");

	$db_getmax->execute( 'block', 'unblock' );
	my ($last_block) = $db_getmax->fetchrow_array;

	my $iterator = $api->getIterator(
		'list'    => 'logevents',
		'letype'  => 'block',
		'lelimit' => 'max',
		'ledir'   => 'newer',
		'lestart' => $last_block ? $last_block : $oldest_entry,
		'leprop'  => 'ids|title|type|user|timestamp|comment',
		'maxlag'  => 20,
	);

	while ( my $entry = $iterator->next ) {
		next unless defined $entry->{title};
		$entry->{title} =~ s/^Wikipedysta://;
		$entry->{action} = 'block' if $entry->{action} eq 'reblock';
		$db_insert->execute( $entry->{logid}, $entry->{timestamp}, $entry->{action}, $entry->{user}, $entry->{title}, $entry->{comment} );
	}
}

{
	$bot->status("Pobieranie listy usunięć");

	$db_getmax->execute( 'delete', 'restore' );
	my ($last_delete) = $db_getmax->fetchrow_array();

	my $iterator = $api->getIterator(
		'list'    => 'logevents',
		'letype'  => 'delete',
		'lelimit' => 'max',
		'ledir'   => 'newer',
		'lestart' => $last_delete ? $last_delete : $oldest_entry,
		'leprop'  => 'ids|title|type|user|timestamp|comment',
		'maxlag'  => 20,
	);

	while ( my $entry = $iterator->next ) {
		next unless defined $entry->{title};
		$db_insert->execute( $entry->{logid}, $entry->{timestamp}, $entry->{action}, $entry->{user}, $entry->{title}, $entry->{comment} );
	}
}

{
	$bot->status("Pobieranie listy przejrzeń");

	$db_getmax->execute( 'approve', 'approve-i' );
	my ($last_review) = $db_getmax->fetchrow_array();

	my $iterator = $api->getIterator(
		'list'    => 'logevents',
		'letype'  => 'review',
		'lelimit' => 'max',
		'ledir'   => 'newer',
		'lestart' => $last_review ? $last_review : $oldest_entry,
		'leprop'  => 'ids|title|type|user|timestamp|comment',
		'maxlag'  => 20,
	);

	while ( my $entry = $iterator->next ) {
		next unless defined $entry->{title};
		next unless $entry->{action} eq 'approve' or $entry->{action} eq 'approve-i';
		$db_insert->execute( $entry->{logid}, $entry->{timestamp}, $entry->{action}, $entry->{user}, $entry->{title}, $entry->{comment} );
	}
}

# perltidy -et=8 -l=0 -i=8
