#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Text::Diff;

my $logger = Log::Any->get_logger();
my $bot    = new Bot4;
$bot->single(1);
$bot->setup;

my @projects = (    #
	{
		'family'                => 'wikipedia',
		'language'              => 'pl',
		'ignored_categories'    => [],
		'ignored_subcategories' => [              #
			'Kategoria:Kategorie tymczasowe',
			'Kategoria:Szablony - błędy wywołań',
		],
		'ignored_pages' => [                      #
			'Wikipedysta:Beau.bot/listy/brudnopisy',
			'Wikipedysta:Beau.bot/listy/wikipedyści',
                        'Wikipedysta:mastiBot/listy/brudnopisy',
                        'Wikipedysta:mastiBot/listy/wikipedyści',
		],
		'report_category' => 'Kategoria:Kategoryzacja',
	},
	{
		'family'                => 'wikisource',
		'language'              => 'pl',
		'ignored_categories'    => [],
		'ignored_subcategories' => [],
		'ignored_pages'         => [               #
			'Wikiskryba:Beau.bot/listy/brudnopisy',
                        'Wikiskryba:mastiBot/listy/brudnopisy',
		],
	},
);

my $api;
my %ignored_categories;
my %ignored_pages;
my %warned_users;
my $ignored_list = 'User:mastiBot/listy/brudnopisy/ignorowane';
my $report_page  = 'User:mastiBot/listy/brudnopisy';

sub is_ignored($) {
	return 1 if exists $ignored_categories{ $_[0] };
	return 1 if $_[0] =~ /^Kategoria:User/i;
	return 1 if $_[0] =~ /^Kategoria:Wikipedyści/i;
	return 1 if $_[0] =~ /^Kategoria:Wikipedystki/i;
	if ( $_[0] =~ /infobox bez/ ) {
		$ignored_categories{ $_[0] }++;
		return 1;
	}
	return 0;
}

sub filter_categories($) {
	my $items = shift;
	return unless defined $items;

	my @result;
	foreach my $item ( values %{$items} ) {
		next if is_ignored( $item->{title} );
		push @result, $item;
	}
	return @result;
}

sub remove_categories($) {
	my $page = shift;

	$logger->info("[[$page->{title}]] pobieranie strony");

	my $data = $api->query(
		'action'  => 'query',
		'prop'    => 'revisions|info',
		'titles'  => $page->{title},
		'rvlimit' => 1,
		'rvdir'   => 'older',
		'rvprop'  => 'content|timestamp|user',
	);

	($page) = values %{ $data->{query}->{pages} };
	my ($revision) = values %{ $page->{revisions} };
	my $content = $revision->{'*'};
	return unless defined $content;

	my @content;

	while ( $content =~ m{\G(.*?)(<nowiki>.*?(?:</nowiki>|$)|<!--.*?(?:-->|$)|<includeonly>.*?(?:</includeonly>|$)|<pre>.*?(?:</pre>|$)|$)}sig ) {

		#last if $1 eq '' and $2 eq '';
		push @content, $1, $2;
	}
	for ( my $i = 0 ; $i < scalar(@content) ; $i += 2 ) {
		$content[$i] =~ s/\[\[(\s*(?:Category|Kategoria)\s*:\s*)(.+?)(\s*(?:\|.+?)?)\]\]/
			my $prefix = $1;
			my $cat = ucfirst $2;
			$prefix = ":$prefix" unless is_ignored("Kategoria:$cat");
			"[[$prefix$cat$3]]";
		/gie;
	}
	$content = join( '', @content );
	undef(@content);

	if ( $content ne $revision->{'*'} ) {
		print "Strona: $page->{title}\n";
		print diff( \$revision->{'*'}, \$content ) . "\n";
	}

	# Wykonuje edycję.
	# Pusta edycja powoduje ponowne parsowanie strony, co odświeża listę
	# kategorii, w której strona się znajduje.

	$logger->debug(Dumper($page));
	$api->edit(
		'title'          => $page->{title},
		'starttimestamp' => $page->{touched},
		'basetimestamp'  => $revision->{timestamp},
		'nocreate'       => 1,
		'bot'            => 1,
		'minor'          => 1,
		'text'           => $content,
		'summary'        => "automatyczne usunięcie strony z kategorii",
	);

	return if $content eq $revision->{'*'};

	return 1 unless $page->{ns} == 2;
	return 1 unless $page->{title} =~ /:(.+?)(?:\/|$)/;
	my $user = $1;
	return 1 if $warned_users{$user}++;

	$logger->info("[[$page->{title}]] ostatnio edytowane przez $revision->{user}");
	return 1 unless $user eq $revision->{user};
	$logger->info("[[$page->{title}]] wysłanie wiadomości do właściciela");

	my $message;

	if ( $page->{ns} == 2 and $page->{title} !~ m{/} ) {
		$message = 'Witam. Twoja strona użytkownika została usunięta z kategorii, w których znajdować się nie powinna - odwołanie do kategorii zostało zamienione na link. Ta wiadomość została wygenerowana automatycznie, dlatego nie musisz na nią odpowiadać. ~~~~';
	}
	else {
		$message = 'Witam. Twoja strona brudnopisu została usunięta z kategorii, w których znajdować się nie powinna - odwołanie do kategorii zostało zamienione na link. Podczas pisania artykułu w brudnopisie zamiast: <nowiki>[[Kategoria:XXX]]</nowiki>, używaj <b><nowiki>[[:Kategoria:XXX]]</nowiki></b> (w przypadku szablonów jest to <nowiki>{{</nowiki><b>s|</b><nowiki>xxx}}</nowiki>). Pozwoli to uniknąć  sytuacji, kiedy czyjaś strona brudnopisu przebywa w poważnej kategorii {{subst:grammar:D.lp|{{subst:SITENAME}}}}. Podczas umieszczania artykułu pod właściwą nazwą należy ten dodatkowy dwukropek po prostu skasować (dotyczy to również linków [[Pomoc:Interwiki|interwiki]]). Dziękuję za zrozumienie. Ta wiadomość została wygenerowana automatycznie, dlatego nie musisz na nią odpowiadać. ~~~~';
	}

	$api->sendMessage( $user, "[[:$page->{title}]]", $message );

	return 1;
}

sub fetch_ignored() {
	$logger->info("Pobieranie listy ignorowanych ze strony [[$ignored_list]]");
	my $iterator = $api->getIterator(
		'titles'      => $ignored_list,
		'prop'        => 'links|info',
		'pllimit'     => 'max',
		'plnamespace' => [ NS_USER, NS_CATEGORY ],
		'inprop'      => 'protection',
	);

	while ( my $page = $iterator->next ) {
		if ( exists $page->{missing} ) {
			$logger->info("Strona [[$ignored_list]] nie istnieje");
			return 1;
		}

		my $protected = 0;
		if ( $page->{protection} ) {
			my %protection = ( 'edit' => 'sysop', 'move' => 'sysop' );
			foreach my $entry ( values %{ $page->{protection} } ) {
				next
				  unless exists $protection{ $entry->{type} };

				next
				  unless $protection{ $entry->{type} } eq $entry->{level};

				delete $protection{ $entry->{type} };
			}
			$protected = scalar keys %protection ? 0 : 1;
		}

		unless ($protected) {
			$logger->warn("Strona [[$ignored_list]] nie jest zabezpieczona");
			return 2;
		}

		foreach my $link ( values %{ $page->{links} } ) {
			if ( $link->{ns} == NS_CATEGORY ) {
				$ignored_categories{ $link->{title} } = 1;
			}
			else {
				$ignored_pages{ $link->{title} } = 1;
			}
		}
	}
	return 0;
}

foreach my $project (@projects) {
	$logger->info("Sprawdzanie projektu: $project->{language}.$project->{family}");

	$api = $bot->getApi( $project->{family}, $project->{language} );

	%ignored_categories = map { $_ => 1 } @{ $project->{ignored_categories} };
	%ignored_pages      = map { $_ => 1 } @{ $project->{ignored_pages} };
	%warned_users       = ();

	my $ignored_list_status = fetch_ignored;

	if ( $project->{ignored_subcategories} ) {
		foreach my $title ( @{ $project->{ignored_subcategories} } ) {
			$logger->info("Pobieranie listy ignorowanych kategorii - [[$title]]");
			my $iterator = $api->getIterator(
				'list'    => 'categorymembers',
				'cmtitle' => $title,
				'cmlimit' => 'max',
			);

			while ( my $entry = $iterator->next ) {
				next unless $entry->{ns} == NS_CATEGORY;
				$ignored_categories{ $entry->{title} }++;
			}
		}
	}

	$logger->info("Pobieranie listy i usuwanie kategorii");

	my %pages;
	my @recheck;

	foreach my $ns ( 2, 3 ) {
		my $iterator = $api->getIterator(
			'generator'    => 'allpages',
			'gapnamespace' => $ns,
			'gaplimit'     => 100,
			'prop'         => 'categories',
			'cllimit'      => 'max',
		);

		while ( my $page = $iterator->next ) {

			# Ignoruj strony z białej listy
			next if exists $ignored_pages{ $page->{title} };

			# Ignoruj strony bez kategorii
			next unless $page->{categories};

			# Ignoruj kategorie z białej listy
			my @categories = filter_categories( $page->{categories} );

			# Ignoruj strony bez kategorii
			next unless scalar @categories;

			$page->{categories} = \@categories;
			$pages{ $page->{title} } = $page;

			eval {
				remove_categories($page);
				push @recheck, $page;
			};
			if ($@) {
				$logger->error("[[$page->{title}]] wystąpił błąd: $@");
			}
		}
	}

	if ( scalar @recheck ) {
		$logger->info("Weryfikacja kategorii");
		eval {
			while (@recheck) {
				my @batch = splice @recheck, 0, 100;

				my $data = $api->query(
					'action'  => 'query',
					'titles'  => join( '|', map { $_->{title} } @batch ),
					'prop'    => 'categories',
					'cllimit' => 'max',
				);

				foreach my $page ( values %{ $data->{query}->{pages} } ) {
					unless ( $page->{categories} ) {
						delete $pages{ $page->{title} };
						next;
					}
					my @categories = filter_categories( $page->{categories} );
					unless (@categories) {
						delete $pages{ $page->{title} };
						next;
					}
					$pages{ $page->{title} }->{categories} = \@categories;
					$logger->info("[[$page->{title}]] nie udało się usunąć wszystkich kategorii");
				}
			}
		};
		if ($@) {
			$logger->error("Weryfikacja się nie powiodła: $@");
		}
	}

	my @lines;

	push @lines, ";Informacje";
	push @lines, '* Ta strona jest automatycznie nadpisywana przez bota. Jeśli chcesz zgłosić jakieś uwagi zrób to na [[User talk:masti|stronie dyskusji]].';
	if ( $ignored_list_status == 0 ) {
		push @lines, "* Bot korzysta z [[$ignored_list|listy ignorowanych]].";
	}
	elsif ( $ignored_list_status == 1 ) {
		push @lines, "* Bot nie odnalazł [[$ignored_list|listy ignorowanych]].";
	}
	elsif ( $ignored_list_status == 2 ) {
		push @lines, "* Bot nie używa [[$ignored_list|listy ignorowanych]], ponieważ strona nie posiada wymaganych zabezpieczeń.";
	}

	push @lines, ";Ignorowane strony";
	if ( scalar keys %ignored_pages ) {
		foreach my $title ( sort keys %ignored_pages ) {
			push @lines, "* [[$title]]";
		}
	}
	else {
		push @lines, "* (brak)";
	}

	push @lines, ";Ignorowane kategorie";
	if ( scalar keys %ignored_categories ) {
		foreach my $category ( sort keys %ignored_categories ) {
			push @lines, "* [[:$category]]";
		}
		push @lines, "* oraz wszystkie kategorie, które zaczynają się słowem ''User''";
	}
	else {
		push @lines, "* (brak)";
	}

	push @lines, ";Strony użytkowników z kategoriami";

	if ( scalar keys %pages ) {
		foreach my $title ( sort keys %pages ) {
			my $page = $pages{$title};
			push @lines, "* [[$title]]";
			foreach my $category ( @{ $page->{categories} } ) {
				push @lines, "** [[:$category->{title}]]";
			}
		}
	}
	else {
		push @lines, "* (brak)";
	}

	if ( $project->{report_category} ) {
		push @lines, "";
		push @lines, "[[$project->{report_category}]]";
	}

	my $text = join( "\n", @lines );

	$logger->info("Zapis listy");
	$api->edit(
		title   => $report_page,
		text    => $text,
		bot     => 1,
		summary => 'aktualizacja listy',
	);
}

# perltidy -et=8 -l=0 -i=8
