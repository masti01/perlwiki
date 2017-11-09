#!/usr/bin/perl -w

use strict;
use Bot4;
use utf8;
use Text::Diff;
use Data::Dumper;

my $logger = Log::Any->get_logger;

my $bot = new Bot4;
$bot->single(1);
$bot->setProject( "wiktionary", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

# Większa tolerancja na błędy
$api->attempts     = 10;
$api->attemptdelay = 30;

my %withoutPrefix = map { $_ => 1 } split '\|', 'dżuhuri|esperanto|ewe|greka|hindi|ido|interlingua|inuktitut|jidysz|ladino|lingala|lojban|novial|papiamento|pitjantjatjara|sanskryt|slovio|sranan tongo|tetum|tok pisin|tupinambá|użycie międzynarodowe|volapük|zarfatit|znak chiński|quenya|brithenig|Lingua Franca Nova|wenedyk|romániço';
my %ignoredLanguages = map { $_ => 1 } ('znak chiński');

sub fetchCategories {

=head
	my $iterator = $api->getIterator(
		'action'       => 'query',
		'generator'    => 'categorymembers',
		'gcmlimit'     => 'max',
		'gcmtitle'     => 'Kategoria:Indeks a tergo słów wg języków',
		'gcmnamespace' => NS_CATEGORY,
		'prop'         => 'categoryinfo',
	);

	# Do obliczenia różnicy pomiędzy kategoriami
	my %atergo;

	while ( my $entry = $iterator->next ) {
		next unless $entry->{ns} == NS_CATEGORY;
		next unless $entry->{title} =~ / \(indeks a tergo\)$/;
		next unless $entry->{categoryinfo};
		my $title = $entry->{title};
		$title =~ s/ a tergo//;
		$atergo{$title} = $entry->{categoryinfo}->{pages};
	}
=cut

	my $iterator = $api->getIterator(
		'action'    => 'query',
		'generator' => 'categorymembers',
		'gcmlimit'  => 'max',
		'gcmtitle'  => 'Kategoria:Indeks słów wg języków',
		'prop'      => 'categoryinfo',
	);
	my @list;

	while ( my $entry = $iterator->next ) {
		next unless $entry->{ns} == NS_CATEGORY;
		next unless $entry->{title} =~ /^Kategoria:(.+?) \(indeks\)$/;

		if ( exists $ignoredLanguages{$1} ) {
			$logger->info("$entry->{title} jest ignorowana, ponieważ znajduje się na czarnej liście");
			next;
		}

		unless ( $entry->{categoryinfo} ) {
			$logger->warn("Brak categoryinfo dla $entry->{title}");
			next;
		}

		unless ( $entry->{categoryinfo}->{pages} > 2000 ) {
			$logger->info("$entry->{title} jest ignorowana, ma stron: $entry->{categoryinfo}->{pages}");
			next;
		}

=head
		if ( $atergo{ $entry->{title} } and abs( $entry->{categoryinfo}->{pages} - $atergo{ $entry->{title} } ) < 100 ) {
			$logger->info("$entry->{title} jest ignorowana, różnica między obiema kategoriami jest za mała");
			next;
		}
=cut

		push @list, $entry->{title};
	}
	return @list;
}

sub doEdit {
	my $page       = shift;
	my $newContent = shift;

	my $maxAttempts = $api->attempts;
	my $attempt     = $maxAttempts;
	while ( $attempt > 0 ) {
		$attempt--;

		my $revision;
		if ( $page->{revisions} ) {
			($revision) = values %{ $page->{revisions} };
		}

		if ( defined $revision and $revision->{'*'} eq $newContent ) {
			$logger->info("Brak zmian w $page->{title}");
			return;
		}

		if ( $logger->is_info ) {
			my $old = defined $revision ? \$revision->{'*'} : \'';
			$logger->info( "Zmiany w $page->{title}, które zostaną wprowadzone:\n" . diff( $old, \$newContent ) );
		}

		$api->attempts = 1;
		eval {

			# Wykonaj edycję
			$api->edit(
				title          => $page->{title},
				starttimestamp => $page->{touched},
				basetimestamp  => $revision ? $revision->{timestamp} : '',
				text           => $newContent,
				bot            => 1,
				summary        => "aktualizacja szablonu",
				notminor       => 1,
			);
		};
		$api->attempts = $maxAttempts;
		if ($@) {
			$logger->warn($@);
		}
		else {
			return;
		}
		my $response = $api->query(
			'action' => 'query',
			'prop'   => 'info|revisions',
			'rvprop' => 'timestamp|content',
			'titles' => $page->{title},
		);
		($page) = values %{ $response->{query}->{pages} };
	}
	die "Nie można zapisać strony [[$page->{title}]]\n";
}

foreach my $category (fetchCategories) {
	my @list;

	# Dla danego indeksu pobierz wszystkie elementy
	my $iterator = $api->getIterator(
		'action'      => 'query',
		'list'        => 'categorymembers',
		'cmlimit'     => 'max',
		'cmprop'      => 'title',
		'cmtitle'     => $category,
		'cmnamespace' => NS_MAIN,
	);
	while ( my $entry = $iterator->next ) {
		next unless $entry->{ns} == NS_MAIN;    # Odrzucaj z innych przestrzeni
		push @list, $entry->{title};
	}
	@list = sort @list;                             # Sortuj

	# Podziel listę na szablony
	my @templates;

	my $list   = '';
	my $length = 0;
	foreach my $item (@list) {
		my $line = "|$item=" . reverse($item) . "\n";

		if ( $item =~ /["'&]/ ) {
			my $item2 = $item;
			$item2 =~ s/&/&amp;/g;
			$item2 =~ s/"/&quot;/g;
			$item2 =~ s/'/&#39;/g;
			$line .= "|$item2=" . reverse($item) . "\n";
		}
		$list .= $line;
		$length += bytes::length($line);

		if ( $length > 100000 ) {
			push @templates, $list;
			$length = 0;
			$list   = '';
		}
	}
	push @templates, $list if $length;
	undef(@list);
	undef($list);
	undef($length);

	# Ekstrakcja nazwy języka
	unless ( $category =~ /^Kategoria:(.+?) \(indeks\)$/ ) {
		$logger->error("Dziwna nazwa kategorii: $category");
		next;
	}
	my $language = $1;

	my $mainTitle      = "Szablon:a tergo/$language";
	my $atergoCategory = "Kategoria:$language (indeks a tergo)";

	# Pobranie zawartości obecnych szablonów (o ile istnieją)
	my @titles;
	push @titles, $mainTitle;
	push @titles, $atergoCategory;

	for my $i ( 1 .. scalar(@templates) ) {
		push @titles, $mainTitle . "/" . sprintf( "%02d", $i );
	}

	my $response = $api->query(
		'action' => 'query',
		'prop'   => 'info|revisions',
		'rvprop' => 'timestamp|content',
		'titles' => join( "|", @titles ),
	);
	my %pages = map { $_->{title} => $_ } values %{ $response->{query}->{pages} };
	undef($response);

	# Aktualizacja
	my $mainTemplate = '';
	my $number       = scalar @templates;
	foreach my $list ( reverse @templates ) {
		my $title = $mainTitle . "/" . sprintf( "%02d", $number );

		my $pagename = $title;
		$pagename =~ s/^Szablon://;
		$mainTemplate = "{{#if:{{$pagename|{{PAGENAME}}}}|{{$pagename|{{PAGENAME}}}}|$mainTemplate}}";

		my $page = $pages{$title};    # FIXME: normalizacja

		$list = "<noinclude>{{skomplikowany}}[[Kategoria:Szablony a tergo|$language" . sprintf( "%02d", $number ) . "]]</noinclude>{{#switch:{{{1}}}\n$list}}";

		doEdit( $page, $list );
		$number--;
	}

	if ( defined $pages{$atergoCategory} and exists $pages{$atergoCategory}->{missing} ) {
		my $page = $pages{$atergoCategory};
		my $parentCategory;

		if ( $withoutPrefix{$language} ) {
			$parentCategory = ucfirst($language);
		}
		else {
			$parentCategory = "Język $language";
		}
		my $newContent = << "EOF";
__HIDDENCAT__
[[Kategoria:Indeks a tergo słów wg języków]]
[[Kategoria:$parentCategory| {{PAGENAME}}]]
EOF

		# Wykonaj edycję
		$api->edit(
			title          => $page->{title},
			starttimestamp => $page->{touched},
			text           => $newContent,
			summary        => "utworzenie nowej kategorii",
			notminor       => 1,
			createonly     => 1,
		);
	}

	my $page = $pages{$mainTitle};
	$mainTemplate = "<noinclude>{{skomplikowany}}[[Kategoria:Szablony a tergo|${language}00]]</noinclude><includeonly>{{#ifexist:{{PAGENAME}}|{{#ifeq:{{NAMESPACE}}x|{{ns:0}}x|{{#ifexist:Kategoria:$language (indeks a tergo)|{{a tergo/kategoria|$language|$mainTemplate|}}}}}}}}</includeonly>";

	doEdit( $page, $mainTemplate . " " ); # Ta spacja jest po to, żeby strona została nadpisana
}

# perltidy -et=8 -l=0 -i=8
