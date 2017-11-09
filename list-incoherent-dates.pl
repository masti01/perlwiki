#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Text::Diff;

my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->single(1);
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any->get_logger;
$logger->info("Start");

my $api = $bot->getApi;
$api->checkAccount;

sub sanitizeYear {
	my $year = shift;
	return 0 unless defined $year;

	if ( $year =~ /^(\d+) p\.n\.e\.$/ ) {
		$year = -$1;
	}
	return $year;
}

my $reLangLink;
{
	local $" = "|";
	my @prefixes = map { quotemeta( $_->{prefix} ) } grep { exists $_->{language} } $api->getInterwikiMap;
	push @prefixes, 'bjn', 'krc';
	$reLangLink = qr/\[\[(?:@prefixes):.+?\]\]/i;
}

sub refine {
	my $content = shift;

	# Zmiana encji
	$content =~ s/&ndash;/–/g;
	$content =~ s/&nbsp;/ /g;

	# Usuń komentarze
	$content =~ s/<!--(.+?)-->//sg;

	# Usuń interwiki
	$content =~ s/$reLangLink//g;

	# Usuń kategorie
	$content =~ s/\[\[(?:Kategoria|Category):(.+?)\]\]//gi;

	# Usuń szablony
	$content =~ s/\{\{Miesiące\}\}//gi;
	$content =~ s/\{\{Przypisy.*?\}\}//gi;

	# Popraw linki
	$content =~ s/(?<=\[\[)\s+//g;
	$content =~ s/\s+(?=\]\])//g;

	return $content;
}

my @months = qw(stycznia lutego marca kwietnia maja czerwca lipca sierpnia września października listopada grudnia);

my $reDayLink;
{
	local $" = "|";
	$reDayLink = qr/\[\[(\d+ (?:@months))(?:\|.+?)?\]\]/;
}
my $reYearLink = qr/\[\[(\d+(?: p\.n\.e\.)?)(?: w \S+)?(?:\|.+?)?\]\]/;

my $reWho = qr/^(?:\[\[(?:sir|papież|kalif|Order Imperium Brytyjskiego)(?:\|.+?)?\]\]\s*|(?:sir|św\.|bł\.|książę|święty|\w+)\s*)?\[\[(.+?)(?:\|.+?)?\]\]\s*(?:[,-–]\s*)?/i;

sub extractYearSufix($$) {
	my $what = $_[0];

	if ( $_[1] =~ s/\s*\(\s*(ur|zm)\.\s*(?:(?:ok\.|prawdopodobnie)?\s*?$reYearLink|(\d+)|\?)\s*\)//i ) {
		return undef if lc($1) ne $what;
		return sanitizeYear($2) if defined $2;
		return sanitizeYear($3) if defined $3;
	}
}

my %dates;

{
	my @titles;
	my @pages;

	my @days = ( 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
	foreach my $month (@months) {
		my $days = shift @days;
		push @titles, "$_ $month" for ( 1 .. $days );
	}

	my %validSections = map { $_ => 1 } ( 'Święta', 'Urodzili się', 'Zmarli', 'Wydarzenia w Polsce', 'Wydarzenia na świecie', 'Astronomia' );

	while (@titles) {
		my @batch = splice @titles, 0, 500;

		my $response = $api->query(
			'titles' => join( "|", @batch ),
			'prop'   => 'revisions',
			'rvprop' => 'content',
		);

		push @pages, values %{ $response->{query}->{pages} };
	}

	foreach my $page (@pages) {
		$logger->info("Sprawdzanie [[$page->{title}]]");
		die "[[$page->{title}]] nie istnieje\n" if exists $page->{missing};
		my ($revision) = values %{ $page->{revisions} };

		my %sections;
		my ( undef, @sections ) = split /^(?==)/m, refine( $revision->{'*'} );

		foreach my $section (@sections) {
			my ($sectionTitle) = $section =~ /^=+\s*(.+?)\s*=+/;
			die "Nie można odczytać nazwy sekcji\n" unless defined $sectionTitle;
			unless ( exists $validSections{$sectionTitle} ) {
				$logger->warn("[[$page->{title}]]: Nieprawidłowa sekcja: $sectionTitle");
			}
			if ( exists $sections{$sectionTitle} ) {
				$logger->warn("[[$page->{title}]]: Nazwa sekcji się powtarza: $sectionTitle");
			}

			# Usuń nagłówek
			$section =~ s/^=.+?\n//;

			$sections{$sectionTitle} = $section;
		}
		undef @sections;

		# Sekcja: Urodzili się

		my $liYear = undef;

		foreach my $line ( split "\n", $sections{'Urodzili się'} ) {
			next if $line eq '';

			my $text;
			my $year;

			if ( $line =~ m{^\*\s*$reYearLink\s*[-–]\s*(.+)$}o ) {
				$year   = $1;
				$text   = $2;
				$liYear = undef;
			}
			elsif ( $line =~ m{^\*\s*$reYearLink[;:\.]?\s*$}o ) {

				# * [[1969]]
				$liYear = $1;
				next;
			}
			elsif ( $line =~ m{^\*\*\s*(.+)\s*$}o and defined $liYear ) {

				# ** [[Roman Pisarski]], polski pisarz (ur. [[1912]])
				$text = $1;
				$year = $liYear;
			}
			else {
				$logger->warn("Nieprawidłowy format linii: '$line'");
				next;
			}
			my $data;

			$data->{birthDay}  = $page->{title};
			$data->{birthYear} = sanitizeYear($year);
			$data->{section}   = 'Urodzili się';

			my $who;

			if ( $text =~ s/$reWho// ) {
				$who = $1;
			}
			else {
				$logger->warn("Nie udało się odczytać osoby: '$line'");
				next;
			}

			$data->{diedYear} = extractYearSufix( 'zm', $text );

			if ( $text =~ m/zm\./ ) {
				$logger->warn("Nie udało się odczytać daty śmierci?: '$line'");
			}

			$dates{$who}{ $page->{title} } = $data;
		}

		# Sekcja: Zmarli

		$liYear = undef;

		foreach my $line ( split "\n", $sections{'Zmarli'} ) {
			next if $line eq '';

			my $text;
			my $year;

			if ( $line =~ m{^\*\s*$reYearLink\s*[-–]\s*(.+)$}o ) {
				$year   = $1;
				$text   = $2;
				$liYear = undef;
			}
			elsif ( $line =~ m{^\*\s*$reYearLink[;:\.]?\s*$}o ) {

				# * [[1969]]
				$liYear = $1;
				next;

			}
			elsif ( $line =~ m{^\*\*\s*(.+)\s*$}o and defined $liYear ) {

				# ** [[Roman Pisarski]], polski pisarz (zm. [[1912]])
				$text = $1;
				$year = $liYear;
			}
			else {
				$logger->warn("Nieprawidłowy format linii: '$line'");
				next;
			}

			my $data;

			$data->{diedDay}  = $page->{title};
			$data->{diedYear} = sanitizeYear($year);
			$data->{section}  = 'Zmarli';

			my $who;

			if ( $text =~ s/$reWho// ) {
				$who = $1;
			}
			else {
				$logger->warn("Nie udało się odczytać osoby: '$line'");
				next;
			}

			$data->{birthYear} = extractYearSufix( 'ur', $text );

			if ( $text =~ m/ur\./ ) {
				$logger->warn("Nie udało się odczytać daty urodzenia?: '$line'");
			}

			$dates{$who}{ $page->{title} } = $data;
		}
	}
}

sub getCategoryMembers($$$) {
	my ( $name, $regex, $depth ) = @_;

	$logger->debug("Pobieranie listy stron z $name");

	my $iterator = $api->getIterator(
		'list'    => 'categorymembers',
		'cmtitle' => $name,
		'cmlimit' => 'max',

		#'maxlag'      => 20,
	);

	my @pages;
	my @categories;

	while ( my $entry = $iterator->next ) {
		if ( $entry->{ns} == NS_CATEGORY ) {
			push @categories, $entry->{title};
			next;
		}
		next unless $entry->{title} =~ /$regex/;
		push @pages, $entry->{title};
	}

	if ( $depth and $depth > 0 ) {
		$depth--;
		foreach my $category (@categories) {
			no warnings;
			push @pages, getCategoryMembers( $category, $regex, $depth );
		}
	}
	return @pages;
}

{
	my @titles;
	my $titlesCount;
	my @pages;

	my %validSections = map { $_ => 1 } ( 'Święta ruchome', 'Urodzili się', 'Zmarli', 'Nagrody Nobla', 'Wydarzenia', 'Wydarzenia w Polsce', 'Wydarzenia na świecie', 'Astronomia', 'Zdarzenia astronomiczne', 'Zobacz też' );

	push @titles, getCategoryMembers( 'Kategoria:Kartka z kalendarza',    qr/^\d+(?: p\.n\.e\.)?$/, 1 );
	push @titles, getCategoryMembers( 'Kategoria:Kalendarium muzyczne',   qr/^\d+ w muzyce?$/,      1 );
	push @titles, getCategoryMembers( 'Kategoria:Kalendarium literatury', qr/^\d+ w literaturze?$/, 1 );
	push @titles, getCategoryMembers( 'Kategoria:Kalendarium filmowe',    qr/^\d+ w filmie?$/,      1 );
	push @titles, getCategoryMembers( 'Kategoria:Kalendarium nauki',      qr/^\d+ w nauce?$/,       1 );

	$titlesCount = scalar(@titles);

	while (@titles) {
		my @batch = splice @titles, 0, 500;

		my $response = $api->query(
			'titles' => join( "|", @batch ),
			'prop'   => 'revisions',
			'rvprop' => 'content',
		);

		push @pages, values %{ $response->{query}->{pages} };
	}

	if ( scalar @pages != $titlesCount ) {
		print "pages : " . scalar(@pages) . "\n";
		print "titles: $titlesCount\n";

		#die "Pobrano inną liczbę stron\n";
	}
	undef @titles;

	foreach my $page (@pages) {
		$logger->info("Sprawdzanie [[$page->{title}]]");

		my $pageYear = $page->{title};
		$pageYear =~ s/ w \S+$//;
		$pageYear = sanitizeYear($pageYear);

		if ( $pageYear > 2017 ) {
			$logger->info("Strona dotyczy przyszłości");
			next;
		}

		die "[[$page->{title}]] nie istnieje\n" if exists $page->{missing};
		my ($revision) = values %{ $page->{revisions} };

		my %sections;
		my ( undef, @sections ) = split /^(?==)/m, refine( $revision->{'*'} );

		foreach my $section (@sections) {
			my ($sectionTitle) = $section =~ /^=+\s*(.+?)\s*=+/;
			die "Nie można odczytać nazwy sekcji\n" unless defined $sectionTitle;
			unless ( exists $validSections{$sectionTitle} ) {
				$logger->warn("[[$page->{title}]]: Nieprawidłowa sekcja: $sectionTitle");
			}
			if ( exists $sections{$sectionTitle} ) {
				$logger->warn("[[$page->{title}]]: Nazwa sekcji się powtarza: $sectionTitle");
			}

			# Usuń nagłówek
			$section =~ s/^=.+?\n//;

			$sections{$sectionTitle} = $section;
		}
		undef @sections;

		# Sekcja: Urodzili się

		my $liDay;

		foreach my $line ( split "\n", $sections{'Urodzili się'} ) {
			next if $line eq '';
			next if $line =~ /^[\{\|}]/;
			next if $line =~ /_DODAJ_PO_GWIAZDCE/;

			my $text;
			my $day;

			if ( $line =~ m{^\*\s*$reDayLink\s*[-–]\s*(.+)$}o ) {
				$day   = $1;
				$text  = $2;
				$liDay = undef;
			}
			elsif ( $line =~ m{^\*\s*$reDayLink[;:\.]?\s*$}o ) {
				$liDay = $1;
				next;
			}
			elsif ( $line =~ m{^\*\*\s*(.+)\s*$}o and defined $liDay ) {
				$text = $1;
				$day  = $liDay;
			}
			else {
				$logger->warn("Nieprawidłowy format linii: '$line'");
				next;
			}

			my $data;

			$data->{birthDay}  = $day;
			$data->{birthYear} = $pageYear;
			$data->{section}   = 'Urodzili się';

			my $who;

			if ( $text =~ s/$reWho// ) {
				$who = $1;
			}
			else {
				$logger->warn("Nie udało się odczytać osoby: '$line'");
				next;
			}

			$data->{diedYear} = extractYearSufix( 'zm', $text );

			if ( $text =~ m/zm\./ ) {
				$logger->warn("Nie udało się odczytać daty śmierci?: '$line'");
			}

			$dates{$who}{ $page->{title} } = $data;
		}

		# Sekcja: Zmarli

		$liDay = undef;
		foreach my $line ( split "\n", $sections{'Zmarli'} ) {
			next if $line eq '';
			next if $line =~ /^[\{\|}]/;
			next if $line =~ /_DODAJ_PO_GWIAZDCE/;

			my $text;
			my $day;

			if ( $line =~ m{^\*\s*$reDayLink\s*[-–]\s*(.+)$}o ) {
				$day   = $1;
				$text  = $2;
				$liDay = undef;
			}
			elsif ( $line =~ m{^\*\s*$reDayLink[;:\.]?\s*$}o ) {
				$liDay = $1;
				next;
			}
			elsif ( $line =~ m{^\*\*\s*(.+)\s*$}o and defined $liDay ) {
				$text = $1;
				$day  = $liDay;
			}
			else {
				$logger->warn("Nieprawidłowy format linii: '$line'");
				next;
			}

			my $data;

			$data->{diedDay}  = $day;
			$data->{diedYear} = $pageYear;
			$data->{section}  = 'Zmarli';

			my $who;

			if ( $text =~ s/$reWho// ) {
				$who = $1;
			}
			else {
				$logger->warn("Nie udało się odczytać osoby: '$line'");
				next;
			}

			$data->{birthYear} = extractYearSufix( 'ur', $text );

			if ( $text =~ m/ur\./ ) {
				$logger->warn("Nie udało się odczytać daty urodzenia?: '$line'");
			}

			$dates{$who}{ $page->{title} } = $data;
		}
	}

}

{
	my @titles = keys %dates;
	my %redirects;
	my %normalized;

	# FIXME: rozwiązywanie przekierowań stwarza problemy
	#my %noRedirects = map { $_ => 1 } ( 'Cesarze Japonii', 'Cesarze rzymscy' );

	while (@titles) {
		my @batch = splice @titles, 0, 500;

		my $response = $api->query(
			'titles'    => join( "|", @batch ),
			'prop'      => 'categories',
			'cllimit'   => 'max',
			'redirects' => '',
		);

		#print Dumper $response;

		if ( $response->{query}->{redirects} ) {
			foreach my $item ( values %{ $response->{query}->{redirects} } ) {

				#next if exists $noRedirects{ $item->{to} };
				$redirects{ $item->{from} } = $item->{to};
			}
		}
		if ( $response->{query}->{normalized} ) {
			foreach my $item ( values %{ $response->{query}->{normalized} } ) {
				$normalized{ $item->{from} } = $item->{to};
			}
		}

		foreach my $page ( values %{ $response->{query}->{pages} } ) {
			next unless $page->{categories};

			my %data;

			foreach my $category ( values %{ $page->{categories} } ) {
				if ( $category->{title} =~ /^Kategoria:Zmarli w (\d+)$/ ) {
					$data{diedYear} = $1;
				}
				elsif ( $category->{title} =~ /^Kategoria:Urodzeni w (\d+)$/ ) {
					$data{birthYear} = $1;
				}
			}
			next unless scalar keys %data;
			$data{section} = 'Kategoria';
			$dates{ $page->{title} }{ $page->{title} } = \%data;
		}
	}

	#print Dumper \%normalized;
	#print Dumper \%redirects;

	my %rename;

	while ( my ( $from, $to ) = each %normalized ) {
		if ( exists $redirects{$to} ) {
			my $newTo = $redirects{$to};
			delete $redirects{$to};
			$to = $newTo;
		}
		$rename{$from} = $to;
	}

	while ( my ( $from, $to ) = each %redirects ) {
		die "Kolizja podczas zmiany nazwy z $from\n" if exists $rename{$from};
		$rename{$from} = $to;
	}

	#print Dumper \%rename;

	while ( my ( $from, $to ) = each %rename ) {
		die "Nie można odnaleźć '$from' na liście dat\n" unless exists $dates{$from};

		if ( exists $dates{$to} ) {
			$dates{$to} = { %{ $dates{$to} }, %{ $dates{$from} } };
		}
		else {
			$dates{$to} = $dates{$from};
		}
		delete $dates{$from};
	}
}

sub fetchBlacklist() {
	my $iterator = $api->getIterator(
		'titles'  => 'User:mastiBot/listy/daty/ignorowane',
		'prop'    => 'links',
		'pllimit' => 'max',
	);

	my %blacklist;
	while ( my $page = $iterator->next ) {
		foreach my $link ( values %{ $page->{links} } ) {
			$blacklist{ $link->{title} }++;
		}
	}
	return %blacklist;
}

my %blacklist = fetchBlacklist;

my $report = "Potencjalne problemy w kalendariach\n";
$report .= "* po zweryfikowaniu dat oraz wprowadzeniu poprawek usuń odpowiednią sekcję\n";
$report .= "* w nagłówkach mają być nazwiska pojedynczych osób, jeśli jest tam coś innego dodaj link na podstronie [[/ignorowane]] oraz skasuj błędną sekcję\n";
$report .= "* jeśli masz jakieś uwagi, zgłoś je na stronie dyskusji\n";
$report .= "* lista na wiki zawiera najwyżej 200 pozycji, ponieważ pełna lista jest za długa\n\n\n";
$report .= "Ostatnia aktualizacja: '''~~~~~'''\n";

my $i = 0;
foreach my $who ( sort keys %dates ) {
	next if exists $blacklist{$who};
	my $pages = $dates{$who};
	my @problems;

	while ( my ( $title, $data ) = each %{$pages} ) {
		if ( $data->{birthYear} and $data->{diedYear} ) {
			my $age = $data->{diedYear} - $data->{birthYear};

			if ( $age < 0 ) {
				push @problems, "[[$title#$data->{section}]]: $who ma rok śmierci ($data->{diedYear}) mniejszy od roku urodzenia ($data->{birthYear})";
			}
			elsif ( $age > 150 ) {
				push @problems, "[[$title#$data->{section}]]: $who ma lat $age ($data->{diedYear} - $data->{birthYear})";
			}

		}
	}

	my %data;
	my $desync = 0;

      SYNC: foreach my $data ( values %{$pages} ) {
		foreach my $key ( 'birthYear', 'birthDay', 'diedYear', 'diedDay' ) {

			#next unless exists $data->{$key};
			next unless $data->{$key};

			#unless ( exists $data{$key} ) {
			unless ( $data{$key} ) {
				$data{$key} = $data->{$key};
				next;
			}

			if ( $data{$key} ne $data->{$key} ) {
				$desync = 1;
				last SYNC;
			}
		}
	}

	if ($desync) {
		local $" = ' || ';
		my $table = << 'EOF';
Strony podają różne daty:
{| class="wikitable"
! strona !! sekcja !! dzień urodzenia !! rok urodzenia !! dzień śmierci !! rok śmierci
EOF

		while ( my ( $title, $data ) = each %{$pages} ) {
			my @cells;
			push @cells, "[[$title]]";
			push @cells, "[[$title#$data->{section}|$data->{section}]]";
			push @cells, defined $data->{birthDay} ? $data->{birthDay} : '';
			push @cells, defined $data->{birthYear} ? $data->{birthYear} : '';
			push @cells, defined $data->{diedDay} ? $data->{diedDay} : '';
			push @cells, defined $data->{diedYear} ? $data->{diedYear} : '';

			$table .= "|-\n| @cells \n";

		}
		$table .= '|}';
		push @problems, $table;
	}

	if (@problems) {
		$report .= "=== [[$who]] ===\n";
		local $" = "\n* ";
		$report .= "* @problems\n";
		$i++;
		last if $i == 200;
	}
}

print $report;

exit(0) if $pretend;

$api->edit(
	title    => 'User:mastiBot/listy/daty',
	text     => $report,
	bot      => 1,
	summary  => "aktualizacja listy",
	notminor => 1,
);

# perltidy -et=8 -l=0 -i=8
