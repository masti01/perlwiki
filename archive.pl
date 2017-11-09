#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Text::Diff;
use DateTime;
use POSIX;
use Log::Any;

my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend", \$pretend, "Wypisuje różnice bez zapisywania zmian" );
$bot->single(1);
$bot->setup;

my $logger = Log::Any->get_logger();

my @archived = (
#	{
#		'family'       => 'wikipedia',
#		'language'     => 'pl',
#		'title'        => 'Project:Prośby do administratorów',
#		'archive'      => 'Project:Prośby do administratorów/archiwum/%Y/%m',
#		'defaultTime'  => 7 * 24 * 3600,
#		'doneTime'     => 3 * 24 * 3600,
#		'doneTemplate' => qr/\{\{[Zz]ałatwione\}\}/,
#		'header'       => '[[Kategoria:Administracja Wikipedii - archiwum]]',
#	},
	{
		'family'      => 'wikisource',
		'language'    => 'pl',
		'title'       => 'Project:Prośby do administratorów',
		'archive'     => 'Project:Prośby do administratorów/archiwum/%Y/%m',
		'defaultTime' => 14 * 24 * 3600,
		'header'      => '[[Kategoria:Archiwa Wikiźródeł]]',
	},
);

sub parseTime($) {
	my $text = shift;

	unless ( $text =~ /^(\d\d):(\d\d), (\d+) (\S+) (\d{4}) \((CES?T)\)$/ ) {
		$logger->warn("Unknown time format: $text");
		return 0;
	}

	my $i = 1;
	my %months = map { $_ => $i++ } ( 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze', 'lip', 'sie', 'wrz', 'paź', 'lis', 'gru' );

	unless ( exists $months{$4} ) {
		$logger->warn("Unknown time format: $text");
		return 0;
	}

	my $dt = DateTime->new(
		hour      => $1,
		minute    => $2,
		day       => $3,
		month     => $months{$4},
		year      => $5,
		second    => 0,
		time_zone => 'UTC',
	);

	my $time = $dt->epoch;
	if ( $6 eq 'CET' ) {
		$time -= 3600;
	}
	elsif ( $6 eq 'CEST' ) {
		$time -= 3600 * 2;
	}
	else {
		$logger->warn("Unknown time format: $text");
		return 0;
	}
	return $time;
}

sub archive {
	my $settings = shift;
	$logger->info("Sprawdzanie [[$settings->{title}]]");

	my $api = $bot->getApi( $settings->{family}, $settings->{language} );
	$api->checkAccount;

	# The clock on tools.wikimedia.pl is sometimes out of sync.
	# Fetch the correct start time from WMF servers.
	my $currentTime = $api->expandtemplates( 'text' => '{{#time:U}}' );
	die unless defined $currentTime;

	my $response = $api->query(
		'titles'  => $settings->{title},
		'prop'    => 'revisions|info',
		'rvlimit' => 1,
		'rvdir'   => 'older',
		'rvprop'  => 'content|ids|timestamp',
		'maxlag'  => 20,
	);

	my ($page)     = values %{ $response->{query}->{pages} };
	my ($revision) = values %{ $page->{revisions} };
	my $content    = $revision->{'*'};

	$response = $api->query(
		'action' => 'parse',
		'oldid'  => $revision->{revid},
		'prop'   => 'sections',
	);

	my @sections = sort { $b->{index} <=> $a->{index} } values %{ $response->{parse}->{sections} };
	my @activeSections;      # Odwrócona kolejność!
	my @inactiveSections;    # Odwrócona kolejność!

	foreach my $section (@sections) {
		next unless $section->{level} == 2;
		next unless $section->{fromtitle} ne $page->{title};
		$logger->debug("Sprawdzanie sekcji '$section->{line}'");
		$section->{lastEdit} = 0;
		$section->{content} = substr( $content, $section->{byteoffset} );
		substr( $content, $section->{byteoffset} ) = '';

		foreach my $textTime ( $section->{content} =~ /(\d\d:\d\d, \d+ \S+ \d{4} \(CES?T\))/g ) {

			my $unixTime = parseTime($textTime);
			$section->{lastEdit} = $unixTime if $section->{lastEdit} < $unixTime;
		}

		$logger->debug("Ostatnia edycja: $section->{lastEdit}");

		my $time = $settings->{defaultTime};

		if ( $section->{content} =~ /$settings->{doneTemplate}/ ) {
			$time = $settings->{doneTime};
		}
		$logger->infof( "Czas po którym wątek zostanie zarchiwizowany: %d", $time );

		if ( $section->{lastEdit} and $currentTime - $section->{lastEdit} > $time ) {
			$logger->info("Sekcja '$section->{line}' zostanie zarchiwizowana");
			push @inactiveSections, $section;
		}
		else {
			push @activeSections, $section;
		}

	}

	unless (@inactiveSections) {
		$logger->info("Nic do roboty");
		return;
	}

	$content = $content . join( '', map { $_->{content} } reverse @activeSections );
	$logger->info( "Zmiany, które zostaną wprowadzone na stronie [[$page->{title}]]:\n" . diff( \$revision->{'*'}, \$content ) );

	return if $pretend;

	my @toc;

	foreach my $section ( sort { $a->{lastEdit} <=> $b->{lastEdit} } reverse @inactiveSections ) {
		push @toc, "* [{{fullurl:$page->{title}|oldid=$revision->{revid}#$section->{anchor}}} $section->{line}]\n";
	}

	# Sprawdzić czy strona archiwum istnieje, jeśli nie, to należy ją utworzyć
	# z odpowiednią kategorią oraz wstępem/nagłówkiem

	$response = $api->query(
		'titles' => strftime( $settings->{archive}, gmtime($currentTime) ),
		'prop'   => 'info',
	);

	my ($archivePage) = values %{ $response->{query}->{pages} };
	my $newContent = "\n" . join( '', @toc );

	if ( exists $archivePage->{missing} ) {
		$api->edit(
			'title'      => $archivePage->{title},
			'appendtext' => $settings->{header} . $newContent,
			'createonly' => 1,
			'bot'        => 1,
			'summary'    => 'dodanie listy archiwizowanych wątków',
		);
	}
	else {
		$api->edit(
			'title'          => $archivePage->{title},
			'starttimestamp' => $archivePage->{touched},
			'appendtext'     => $newContent,
			'nocreate'       => 1,
			'bot'            => 1,
			'summary'        => 'dodanie listy archiwizowanych wątków',
		);
	}

	$api->edit(
		'title'          => $page->{title},
		'starttimestamp' => $page->{touched},
		'basetimestamp'  => $revision->{timestamp},
		'text'           => $content,
		'bot'            => 1,
		'summary'        => "archiwizacja starych zgłoszeń",
		'notminor'       => 1,
	);
}

foreach my $settings (@archived) {
	eval { archive($settings); };
	if ($@) {
		$logger->error($@);
	}
}
