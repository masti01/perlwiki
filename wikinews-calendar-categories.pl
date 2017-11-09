#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use DateTime;
use DateTime::Duration;
use Log::Any;

my $logger  = Log::Any::get_logger;
my $year    = 2012;
my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->addOption( "year|y"    => \$year,    "Full year to create categories for" );
$bot->single(1);
$bot->setProject( "wikinews", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

my $day = DateTime::Duration->new(
	years       => 0,
	months      => 0,
	weeks       => 0,
	days        => 1,
	hours       => 0,
	minutes     => 0,
	seconds     => 0,
	nanoseconds => 0,
);

my @months = qw(styczeń luty marzec kwiecień maj czerwiec lipiec sierpień wrzesień październik listopad grudzień);

sub fullDate {
	my $dt = shift;
	return $dt->day . ' ' . $dt->month_name . ' ' . $year;
}
my @pages;

my $monthNumber = 1;
for my $monthName ( map { ucfirst } @months ) {
	my $monthIndex = sprintf( "%02d", $monthNumber );

	push @pages, {
		'title'   => "Kategoria:$monthName $year",
		'content' => << "EOF",
[[Kategoria:$year|* $monthIndex]]
EOF

	};

	my $dt = DateTime->new(
		year       => $year,
		month      => $monthNumber,
		day        => 1,
		hour       => 0,
		minute     => 0,
		second     => 0,
		nanosecond => 0,
		time_zone  => 'Europe/Warsaw',
		locale     => 'pl_PL.utf8',
	);

	my @categories;

	while ( $dt->month == $monthNumber ) {
		my $name = fullDate($dt);
		push @categories, $name;

		my $dayIndex  = sprintf( "%02d", $dt->day );
		my $dayBefore = fullDate( $dt - $day );
		my $dayAfter  = fullDate( $dt + $day );
		push @pages, {
			'title'   => "Kategoria:$name",
			'content' => << "EOF",
{{Kategoria daty|$dayBefore|$dayAfter}}
[[Kategoria:$monthName $year|* $dayIndex]]
EOF

		};

		$dt += $day;
	}
	my $portal = "{{MiesiącBegin|$monthNumber|$year}}\n";
	foreach my $category (@categories) {
		$portal .= << "EOF";
==$category==
<DynamicPageList>
category=$category
namespace=0
suppresserrors=true
</DynamicPageList>
EOF

	}

	$portal .= "{{MiesiącEnd|$monthNumber|$year}}";
	push @pages,
	  {
		'title'   => "Portal:$monthName $year",
		'content' => $portal,
	  };

	$monthNumber++;
}

my $iterator = $api->getIterator(
	'titles' => [ map { $_->{title} } @pages ],
	'prop'   => 'info',
);

my %pages = map { $_->{title} => $_ } @pages;
while ( my $page = $iterator->next ) {
	my $newPage = $pages{ $page->{title} };
	unless ($newPage) {
		$logger->error("Nieprawidłowa nazwa strony [[$page->{title}]]");
		next;
	}
	unless ( exists $page->{missing} ) {
		$logger->info("Strona [[$page->{title}]] już istnieje");
		next;
	}

	$logger->info("Tworzenie strony [[$page->{title}]]");

	$api->edit(
		'title'          => $page->{title},
		'starttimestamp' => $page->{touched},
		'createonly'     => 1,
		'bot'            => 1,
		'minor'          => 1,
		'text'           => $newPage->{content},
		'summary'        => "automatyczne utworzenie strony",
	) unless $pretend;
}
