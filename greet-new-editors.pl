#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;

my $timestamp;
my $logid;

my $bot = new Bot4;
$bot->single(1);
$bot->addOption( "timestamp=s" => \$timestamp );
$bot->addOption( "logid=i"     => \$logid );

$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $api = $bot->getApi;
$api->checkAccount;

# tools.wikimedia.pl ma rozsynchronizowany zegar
# funkcja pobiera czas z serwerów wikipedii
my $currentTime = $api->expandtemplates( 'text' => '{{#time:U}}' );
die "Nie mogę pobrać czasu z serwerów WMF\n"
  unless defined $currentTime;

my $storable = $bot->retrieveData();

my $leend = to_wiki_timestamp( $currentTime - 5 * 60 );
$timestamp = $storable->{timestamp}
  unless defined $timestamp;
$logid = $storable->{logid}
  unless defined $logid;
$logid ||= 0;

my $baseLogid = $logid;

$logger->info( "Aktualny czas na wiki: " . to_wiki_timestamp($currentTime) );
$logger->info("Sprawdzanie nowych od $timestamp do $leend");

my $iterator = $api->getIterator(
	'list'    => 'logevents',
	'letype'  => 'rights',
	'lestart' => $timestamp,
	'leend'   => $leend,
	'ledir'   => 'newer',
	'lelimit' => 200,
	'maxlag'  => 20,
);

my %done;

while ( my $entry = $iterator->next ) {
	if ( $logger->is_info ) {
		$logger->info( Dumper($entry) );
	}
	
	next if $entry->{logid} <= $baseLogid;
	next if $entry->{timestamp} gt $leend;

	$timestamp = $entry->{timestamp}
	  if $timestamp lt $entry->{timestamp};

	$logid = $entry->{logid}
	  if $logid < $entry->{logid};

	next if exists $done{ $entry->{title} };

	next if grep { $_ eq 'editor' } values %{ $entry->{params}->{oldgroups} };
	next unless grep { $_ eq 'editor' } values %{ $entry->{params}->{newgroups} };

	$bot->status("Sprawdzanie $entry->{title}");

	# Sprawdź czy dalej jest redaktorem
	my $data = $api->query(
		'action'  => 'query',
		'list'    => 'users',
		'ususers' => $entry->{title},
		'usprop'  => 'groups',
	);

	foreach my $user ( values %{ $data->{query}->{users} } ) {
		my %groups = map { $_ => 1 } values %{ $user->{groups} };
		next unless $groups{editor};
		my $name = $user->{name};

		if ( $groups{bot} ) {
			$logger->info("$name jest botem, pomijam");
			next;
		}

		$logger->info("$name jest nowym redaktorem");

		# Sprawdź czy ma witaja na stronie
		my $data2 = $api->query(
			'action'  => 'query',
			'prop'    => 'revisions|info',
			'titles'  => "User talk:$name",
			'rvlimit' => 1,
			'rvdir'   => 'older',
			'rvprop'  => 'content|timestamp',
		);

		my $content = '';
		my ($page) = values %{ $data2->{query}->{pages} };
		if ( exists $page->{missing} ) {
			$logger->info("$name nie ma strony dyskusji, pomijam");
			next;
		}
		if ( exists $page->{redirect} ) {
			$logger->info("$name ma przekierowanie zamiast strony dyskusji");
			next;
		}
		my ($revision) = values %{ $page->{revisions} };
		if ($revision) {
			$content = $revision->{'*'};

			if (       $content =~ /<!-- Szablon:Witaj redaktorze -->/
				or $content =~ /\{\{(?:Szablon:|Template:)?Witaj redaktorze\}\}/i
				or $content =~ /Wikipedia:Redaktorzy/
				or $content =~ /Wikipedia:Przeglądanie artykułów/ )
			{
				$logger->info("$name ma już witaja");
				next;
			}
		}

		$bot->status("Witanie $name");
		$logger->info("$name otrzymuje powitanie na stronie dyskusji");

		# Dodaj witaja
		my $greet = "\n{{subst:Witaj redaktorze}}\n" . '<span style="font-size:90%">Ten komunikat został wysłany automatycznie przez bota ~~~~</span>';
		$api->edit(
			'title'          => $page->{title},
			'starttimestamp' => $page->{touched},
			'summary'        => "automatyczne powitanie edytora",
			'bot'            => 1,
			'appendtext'     => $greet,
		);
	}

	$done{ $entry->{title} }++;
}

$storable->{timestamp} = $timestamp;
$storable->{logid}     = $logid;

$bot->storeData($storable);

# perltidy -et=8 -l=0 -i=8
