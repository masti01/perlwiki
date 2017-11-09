#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use DateTime;
use DateTime::Format::Strptime;

my $timestamp;
my $rcid;

my $bot = new Bot4;
$bot->single(1);
$bot->addOption( "timestamp=s" => \$timestamp );
$bot->addOption( "rcid=i"      => \$rcid );

$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any->get_logger;
$logger->info("Start");

my $api = $bot->getApi;
$api->checkAccount;

# tools.wikimedia.pl ma rozsynchronizowany zegar
# funkcja pobiera czas z serwerów wikipedii
my $currentTime = $api->expandtemplates( 'text' => '{{#time:U}}' );
die "Nie mogę pobrać czasu z serwerów WMF\n"
  unless defined $currentTime;

my $storable = $bot->retrieveData();

my $rcend = to_wiki_timestamp( $currentTime - 15 * 60 );
$timestamp = $storable->{timestamp}
  unless defined $timestamp;
$rcid = $storable->{rcid}
  unless defined $rcid;
$rcid ||= 0;

my $baseRcid = $rcid;

$logger->info( "Aktualny czas na wiki: " . to_wiki_timestamp($currentTime) );
$logger->info("Sprawdzanie nowych od $timestamp do $rcend");

my $dateFormat = new DateTime::Format::Strptime(
	pattern   => '%Y-%m',
	time_zone => 'UTC',
	locale    => 'pl_PL.utf8',
	on_error  => 'croak',
);

sub createTemplateInvocation {
	my $noInclude = shift @_;
	my @templates = @_;

	my $date = DateTime->from_epoch( epoch => $currentTime );
	my $dateSuffix = $dateFormat->format_datetime($date);

	my @templatesWithDates = map { "$_=$dateSuffix" } @templates;

	my $text = "{{Dopracować|" . join( "|", @templatesWithDates ) . "}}";

	if ($noInclude) {
		$text = "<noinclude>$text</noinclude>";
	}

	return $text;
}

my $iterator = $api->getIterator(
	'list'        => 'recentchanges',
	'rctype'      => 'new',
	'rcnamespace' => '0',               # '0|4|12|14|100|102',
	'rclimit'     => 'max',
	'rcdir'       => 'newer',
	'rcstart'     => $timestamp,
	'rcend'       => $rcend,
);

while ( my $item = $iterator->next ) {
	next if $item->{rcid} <= $baseRcid;
	next if $item->{timestamp} gt $rcend;

	$timestamp = $item->{timestamp}
	  if $timestamp lt $item->{timestamp};

	$rcid = $item->{rcid}
	  if $rcid < $item->{rcid};

	$logger->info("Sprawdzanie [[$item->{title}]]");
	$bot->status("Sprawdzanie [[$item->{title}]]");

	my $data = $api->query(
		'prop'        => 'revisions|info',
		#'namespaces' => 0,
		'titles'      => $item->{title},
		'rvlimit'     => 1,
		'rvdir'       => 'older',
		'rvprop'      => 'content|timestamp|ids',
		'maxlag'      => 20,
	);

	delete $data->{'query-continue'}{'revisions'}
	  if exists $data->{'query-continue'}{'revisions'};

	my ($page) = values %{ $data->{query}->{pages} };

	my ($revision) = values %{ $page->{revisions} };
	my $content = $revision->{"*"};

	if ( !defined $content or $content eq '' ) {
		$logger->info("* pusta strona?");
		next;
	}

	if ( exists $page->{redirect} ) {
		$logger->info("* jest przekierowaniem");
		next;
	}

	if ( $content =~ /^#REDIRECT/i ) {
		$logger->info("* jest przekierowaniem?!?");
		next;
	}

	my %categories;
	my $categories = 0;

	$data = $api->query(
		'action' => 'parse',
		'oldid'  => $revision->{revid},
		'prop'   => 'categories|links|templates',
	);

	if ( $data->{parse}->{categories} ) {
		foreach my $category ( values %{ $data->{parse}->{categories} } ) {
			my $title = "Kategoria:" . $category->{'*'};
			$title =~ tr/_/ /;
			$categories{$title}++;
		}
		delete $categories{"Kategoria:Automatyczne wykrywanie NPA"};
		foreach my $title ( keys %categories ) {
			delete $categories{$title} if $title =~ /^Kategoria:(?:Urodzeni|Zmarli) w \d+$/;
		}

		$categories = scalar keys %categories;
	}

	if ( exists $categories{"Kategoria:Ekspresowe kasowanie"} ) {
		$logger->info("* do ekspresowego kasowania");
		next;
	}

	my $templates = $data->{parse}->{templates} ? scalar keys %{ $data->{parse}->{templates} } : 0;
	my $links     = $data->{parse}->{links}     ? scalar keys %{ $data->{parse}->{links} }     : 0;

	$logger->info("* kategorii: $categories");
	$logger->info("* szablonów: $templates");
	$logger->info("* linków: $links");

	$links++ if exists $categories{"Kategoria:Linki wewnętrzne do dodania"};
	$links++ unless $page->{ns} == 0;

	if ( $categories and $links ) {
		$logger->info("* nic do roboty!");
		next;
	}

	my @templates;
	my @summary;
	my $noInclude = 0;
	unless ($categories) {
		if ( $page->{ns} != NS_MAIN and $page->{ns} != NS_CATEGORY ) {
			$noInclude = 1;
		}
		push @templates, "kategoria";
		push @summary,   "kategorie";
	}
	unless ($links) {
		push @templates, "linki";
		push @summary,   "linki";
	}
	my $text = createTemplateInvocation( $noInclude, @templates );

	$bot->status("Oznaczanie [[$item->{title}]]");

	local $" = ', ';
	$logger->info("* dodaję: $text");
	my $summary = "Sprawdzanie nowych stron, w artykule należy dopracować: @summary";
	$api->edit(
		'title'          => $page->{title},
		'starttimestamp' => $page->{touched},
		'summary'        => $summary,
		'minor'          => 1,
		'bot'            => 1,
		'nocreate'       => 1,
		'prependtext'    => $text . "\n",
	);
}

$storable->{timestamp} = $timestamp;
$storable->{rcid}      = $rcid;

$bot->storeData($storable);

# perltidy -et=8 -l=0 -i=8
