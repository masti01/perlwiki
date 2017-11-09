#!/usr/bin/perl -w

use strict;
use Bot4;
use utf8;
use Text::Diff;
use Data::Dumper;
use DBI;
use POSIX;

my $logger = Log::Any::get_logger;

my $bot = new Bot4;
$bot->single(1);
$bot->setProject( "wiktionary", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

$logger->info("Pobieranie strony ze statystykami");

my $response = $api->query(
	'action'  => 'query',
	'prop'    => 'revisions|info',
	'titles'  => 'Wikisłownik:Importy',
	'rvprop'  => 'content|timestamp',
);

my ($page) = values %{ $response->{query}->{pages} };
die "Nie istnieje strona $page->{title}\n" unless $page->{revisions};
my ($revision) = values %{ $page->{revisions} };
my $content = $revision->{'*'};

my @templates = $content =~ m/\{\{Wikisłownik:Importy\/pozycja\|[^|]*?\|[^|]*?\|([^|]+?)\|\d+/g;

$logger->info("Pobieranie danych z bazy");

my $dbh = DBI->connect( "DBI:mysql:database=plwiktionary_p;host=plwiktionary-p.db.toolserver.org;mysql_read_default_group=client;mysql_read_default_file=/home/beau/.my.cnf", undef, undef, { RaiseError => 1, 'mysql_enable_utf8' => 0 } )
  or die "Can't connect to database...\n";

local $" = ', ';
my @qm = map { '?' } @templates;
my $query = $dbh->prepare( "
    SELECT tl_title AS title, COUNT(*) AS count
    FROM templatelinks
    WHERE tl_title IN (@qm)
    GROUP BY title
" );

$query->execute(@templates);

my %values;
while ( my $row = $query->fetchrow_hashref ) {
	$values{ $row->{title} } = $row->{count};
}

$content =~ s/(\{\{Wikisłownik:Importy\/pozycja\|[^|]*?\|[^|]*?\|([^|]+?)\|)\d+\|/$1$values{$2}|/g;
my $t = strftime( "%d.%m.%Y", localtime );
$content =~ s/stan na \d{2}\.\d{2}\.\d{4}/stan na $t/i;

$logger->info( "Zmiany, które zostaną wprowadzone:\n" . diff( \$revision->{'*'}, \$content ) );

$api->edit(
	title          => $page->{title},
	starttimestamp => $page->{touched},
	basetimestamp  => $revision->{timestamp},
	text           => $content,
	summary        => "aktualizacja",
);

# perltidy -et=8 -l=0 -i=8
