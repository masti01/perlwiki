#!/usr/bin/perl -w

use strict;
use Bot4;
use utf8;

my $logger = Log::Any->get_logger;

my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->single(1);
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

# tools.wikimedia.pl ma rozsynchronizowany zegar
# funkcja pobiera czas z serwerów wikipedii
my $currentTime = $api->expandtemplates( 'text' => '{{#time:U}}' );
die "Nie mogę pobrać czasu z serwerów WMF\n"
  unless defined $currentTime;

my ( undef, undef, undef, undef, $mon, $year, undef ) = localtime( $currentTime + 7 * 24 * 3600 );
$year += 1900;

my @month = qw(styczeń luty marzec kwiecień maj czerwiec lipiec sierpień wrzesień październik listopad grudzień);
my $month = $month[$mon];

my $monthNumber = sprintf( "%02d", $mon + 1 );

my @pages;

push @pages, {
	'title'   => "Kategoria:Dyskusje nad naprawą artykułów − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] nad naprawą artykułów − $month $year.
}}

[[Kategoria:Dyskusje nad naprawą artykułów|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje nad usunięciem artykułu zakończone bez konsensusu − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone bez podjęcia zgodnej decyzji w sprawie usunięcia artykułu niebiograficznego − $month $year.
}}

[[Kategoria:Dyskusje nad usunięciem artykułu zakończone bez konsensusu|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje zakończone pozostawieniem artykułu − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone decyzją o pozostawieniu artykułu niebiograficznego − $month $year.
}}

[[Kategoria:Dyskusje zakończone pozostawieniem artykułu|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje zakończone usunięciem artykułu − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone decyzją o usunięciu artykułu niebiograficznego − $month $year.
}}

[[Kategoria:Dyskusje zakończone usunięciem artykułu|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje nad usunięciem biografii zakończone bez konsensusu − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone bez podjęcia zgodnej decyzji w sprawie usunięcia artykułu biograficznego − $month $year.
}}

[[Kategoria:Dyskusje nad usunięciem biografii zakończone bez konsensusu|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje zakończone pozostawieniem biografii − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone decyzją o pozostawieniu artykułu biograficznego − $month $year.
}}

[[Kategoria:Dyskusje zakończone pozostawieniem biografii|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje zakończone usunięciem biografii − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone decyzją o usunięciu artykułu biograficznego − $month $year.
}}

[[Kategoria:Dyskusje zakończone usunięciem biografii|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje nad usunięciem stron technicznych zakończone bez konsensusu − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone bez podjęcia zgodnej decyzji w sprawie usunięcia strony technicznej − $month $year.
}}

[[Kategoria:Dyskusje nad usunięciem stron technicznych zakończone bez konsensusu|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje zakończone pozostawieniem strony technicznej − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone decyzją o pozostawieniu strony technicznej − $month $year.
}}

[[Kategoria:Dyskusje zakończone pozostawieniem strony technicznej|$year-$monthNumber]]
EOF
};

push @pages, {
	'title'   => "Kategoria:Dyskusje zakończone usunięciem strony technicznej − $month $year",
	'content' => << "EOF",
{{Opis kategorii
| grupuje = Dyskusje [[Wikipedia:Poczekalnia|Poczekalni]] zakończone decyzją o usunięciu strony technicznej − $month $year.
}}

[[Kategoria:Dyskusje zakończone usunięciem strony technicznej|$year-$monthNumber]]
EOF
};

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
		title      => $page->{title},
		createonly => 1,
		bot        => 1,
		minor      => 1,
		text       => $newPage->{content},
		summary    => "utworzenie kategorii",
	) unless $pretend;
}

# perltidy -et=8 -l=0 -i=8
