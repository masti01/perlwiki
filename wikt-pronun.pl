#!/usr/bin/perl -w

use strict;
use Bot4;
use utf8;
use Text::Diff;
use MediaWiki::Parser;

my $pretend  = 0;
my $useCache = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend,  "Do not edit wiki page" );
$bot->addOption( "cached"    => \$useCache, "Use cache" );
$bot->single(1);
$bot->setProject( "wiktionary", "pl" );
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $api = $bot->getApi;
$api->checkAccount;

my $commonsApi = $bot->getApi( "wikimedia", "commons" );
$commonsApi->checkAccount;

my @audioTemplates = ( 'audio', 'audioUS', 'audioUK', 'audioCA', 'audioAT', 'audioAU' );
my $reAudioTemplate = qr/audio(?:CA|US|UK|AT|AU)?/i;

my $maxRecordingLength = 10;
my @groups             = (     #
	{
		regex    => qr/^en[ _-](?:us|boston[ _-]us)[ _-]/i,
		language => 'angielski',
		template => 'audioUS',
	},
	{
		regex    => qr/^en[ _-]ca[ _-]/i,
		language => 'angielski',
		template => 'audioCA',
	},
	{
		regex    => qr/^en[ _-]aus?[ _-]/i,
		language => 'angielski',
		template => 'audioAU',
	},
	{
		regex    => qr/^en[ _-](?:uk|gb)[ _-]/i,
		language => 'angielski',
		template => 'audioUK',
	},
	{
		regex    => qr/^en[ _-]/i,
		language => 'angielski',
	},
	{
		regex    => qr/^de[ _-]at[ _-]/i,
		language => 'niemiecki',
		template => 'audioAT',
	},
	{
		regex    => qr/^de[ _-]/i,
		language => 'niemiecki',
	},
	{
		regex    => qr/^es[ _-](?:(?:mx|us)[ _-])?/i,
		language => 'hiszpański',
	},
	{
		regex    => qr/^la[ _-](?:(?:ecc|cls)[ _-])?/i,
		language => 'łaciński',
	},
	{
		regex    => qr/^pt[ _-](?:(?:pt|br|dos)[ _-])?/i,
		language => 'portugalski',
	},
	{
		regex    => qr/^sv[ _-](?:(?:ett|en)[ _-])?/i,
		language => 'szwedzki',
	},
	{
		regex    => qr/^fr[ _-](?:(?:la|une?|Paris-)[ _-])?/i,
		language => 'francuski',
	},
	{
		regex    => qr/(?:[ _-]fr)?[ _-]fr[ _-]Paris$/i,
		language => 'francuski',
	},
	{
		regex    => qr/[ _-]ca[ _-]Montréal$/i,
		language => 'francuski',
		template => 'audioCA',
	},
	{
		regex    => qr/^be[ _-]/i,
		language => 'białoruski',
	},
	{
		regex    => qr/^cs[ _-]/i,
		language => 'czeski',
	},
	{
		regex    => qr/^eo[ _-]/i,
		language => 'esperanto',
	},
	{
		regex    => qr/^pl[ _-]/i,
		language => 'polski',
	},
	{
		regex    => qr/^ru[ _-]/i,
		language => 'rosyjski',
	},
	{
		regex    => qr/^hu[ _-]/i,
		language => 'węgierski',
	},
	{
		regex    => qr/^it[ _-]/i,
		language => 'włoski',
	},
	{
		regex    => qr/^wi[ _-]/i,
		language => 'wietnamski',
	},
	{
		regex    => qr/^ar[ _-]/i,
		language => 'arabski',
	},
	{
		regex    => qr/^fa[ _-]/i,
		language => 'perski',
	},
	{
		regex    => qr/^fi[ _-]/i,
		language => 'fiński',
	},
	{
		regex    => qr/^hsb[ _-]/i,
		language => 'górnołużycki',
	},
	{
		regex    => qr/^uk[ _-]/i,
		language => 'ukraiński',
	},
	{
		regex    => qr/^da[ _-]/i,
		language => 'duński',
	},
	{
		regex    => qr/^tu?r[ _-]/i,
		language => 'turecki',
	},
	{
		regex    => qr/^th[ _-]/i,
		language => 'tajski',
	},
	{
		regex    => qr/^sk[ _-]/i,
		language => 'słowacki',
	},
	{
		regex    => qr/^ga[ _-]/i,
		language => 'irlandzki',
	},
	{
		regex    => qr/^nl[ _-]/i,
		language => 'holenderski',
	},
	{
		regex    => qr/^wo[ _-]/i,
		language => 'wolof',
	},
	{
		regex    => qr/^ell[ _-]/i,
		language => 'grecki',
	},
	{
		regex    => qr/^he[ _-]/i,
		language => 'hebrajski',
	},
	{
		regex    => qr/^no[ _-]/i,
		language => 'norweski',
	},
	{
		regex    => qr/^mk[ _-]/i,
		language => 'macedoński',
	},
	{
		regex    => qr/^bg[ _-](?:bg[ _-])?/i,
		language => 'bułgarski',
	},
);

my %words;              # word => [info1, info2]
my %files;              # name => info
my %normalizedFiles;    # Lista nazw plików, które zostały znormalizowane
my %longFiles;          # Lista długich plików

sub fetchFiles() {
	$logger->info("Pobieranie podkategorii z Category:Pronunciation");
	my $iterator = $commonsApi->getIterator(
		'list'        => 'categorymembers',
		'cmtitle'     => "Category:Pronunciation",
		'cmlimit'     => 'max',
		'cmnamespace' => NS_CATEGORY,
	);

	my %visitedCategories;
	my @categories;
	my $maxDepth = 5;

	while ( my $item = $iterator->next ) {
		next if $item->{ns} != NS_CATEGORY;
		$item->{depth} = 0;
		push @categories, $item;
		$visitedCategories{ $item->{title} }++;
	}

	foreach my $category (@categories) {
		$logger->info("Pobieranie stron z $category->{title}, głębokość: $category->{depth}");
		$iterator = $commonsApi->getIterator(
			'generator'    => 'categorymembers',
			'gcmtitle'     => $category->{title},
			'gcmlimit'     => 'max',
			'gcmnamespace' => NS_FILE,
			'prop'         => 'imageinfo',
			'iiprop'       => 'metadata',

		);
		while ( my $item = $iterator->next ) {
			my $info = fileInfo($item);

			unless ( defined $info->{language} ) {
				$logger->trace("Nie można określić języka dla pliku: $item->{title}");
				next;
			}

			push @{ $words{ $info->{word} } }, $info;
			$files{ $info->{name} } = $info;
		}

		# Sprawdź podkategorię
		if ( $category->{depth} < $maxDepth ) {
			$iterator = $commonsApi->getIterator(
				'list'        => 'categorymembers',
				'cmtitle'     => $category->{title},
				'cmlimit'     => 'max',
				'cmnamespace' => NS_CATEGORY,
			);
			while ( my $item = $iterator->next ) {
				next unless $item->{ns} == NS_CATEGORY;
				next if $visitedCategories{ $item->{title} };
				$item->{depth} = $category->{depth} + 1;
				push @categories, $item;
				$visitedCategories{ $item->{title} }++;
			}
		}
	}
}

sub checkFiles {
	while (@_) {
		my @names = splice( @_, 0, 200 );
		my $response = $api->query(
			'titles' => join( '|', map { "Plik:" . $_ } @names ),
			'prop'   => 'imageinfo',
			'iiprop' => 'metadata',
		);

		if ( $response->{query}->{normalized} ) {
			foreach my $item ( values %{ $response->{query}->{normalized} } ) {
				$item->{from} =~ s/^[^:]+://;    # Usuń przestrzeń nazw
				$item->{to} =~ s/^[^:]+://;      # Usuń przestrzeń nazw
				$normalizedFiles{ $item->{from} } = $item->{to};
			}
		}

		foreach my $page ( values %{ $response->{query}->{pages} } ) {
			my $name = $page->{title};
			next unless $name =~ s/^[^:]+://;        # Usuń przestrzeń nazw
			next if exists $files{$name};

			if ( $page->{imagerepository} eq '' ) {
				$files{$name} = undef;
				next;

			}
			$files{$name} = fileInfo($page);
		}
	}
}

sub fetchBlacklist() {
	my $iterator = $api->getIterator(
		'titles'  => 'User:Beau.bot/czarna lista/wymowa',
		'prop'    => 'links',
		'pllimit' => 'max',
	);

	my %blacklist;
	while ( my $page = $iterator->next ) {
		foreach my $link ( values %{ $page->{links} } ) {
			$link->{title} =~ s/^[^:]+://;
			$blacklist{ $link->{title} }++;
		}
	}
	return %blacklist;
}

sub fetchExistingPronunciation() {
	$logger->info("Pobieranie listy stron z szablonami audio");

	foreach my $template (@audioTemplates) {
		my $iterator = $api->getIterator(
			'list'        => 'embeddedin',
			'eititle'     => "Szablon:$template",
			'eilimit'     => 'max',
			'einamespace' => NS_MAIN,
		);

		while ( my $item = $iterator->next ) {
			my $title = $item->{title};
			unless ( exists $words{$title} ) {
				$words{$title} = [];
			}
		}
	}
}

sub fileInfo($) {
	my $item = shift;

	return undef unless $item->{ns} == NS_FILE;
	return undef unless $item->{title} =~ /\.og[ga]$/i;
	return undef unless $item->{title} =~ s/^[^:]+://;

	my $name = $item->{title};
	my $word = $name;
	$word =~ s/\.og[ga]$//i;
	my %info;
	$info{name} = $name;

	# FIXME: brion pisał na liście, żeby dodać do api
	# uniwersalne pobieranie czasu trwania
	my %imageinfo;
	foreach my $hash ( values %{ $item->{imageinfo} } ) {
		while ( my ( $key, $value ) = each %{$hash} ) {
			$imageinfo{$key} = $value;
		}
	}
	$imageinfo{metadata} = { map { $_->{name} => $_->{value} } values %{ $imageinfo{metadata} } };
	$info{length} = $imageinfo{metadata}{length};

	foreach my $group (@groups) {
		if ( $word =~ s/$group->{regex}//i ) {
			$info{word}     = $word;
			$info{template} = defined $group->{template} ? $group->{template} : 'audio';
			$info{language} = $group->{language};
			last;
		}
	}
	return \%info;
}

sub checkAudioTemplate($$) {
	my $code    = shift;
	my $summary = shift;

	my @templates = extract_templates($code);

	if ( @templates != 1 ) {
		return $code;
	}

	my $template = shift @templates;

	return $code unless $template->{name} =~ /^$reAudioTemplate$/;

	my $name = $template->{fields}->{1};
	unless ( defined $name ) {
		return $code;
	}

	if ( exists $normalizedFiles{$name} ) {
		$name = $normalizedFiles{$name};
	}

	if ( $files{$name} ) {
		my $info = $files{$name};

		# Zaznacz długie nagrania
		if ( $info->{length} > $maxRecordingLength ) {
			$longFiles{$name} = $info;
		}
		return $code;
	}
	else {
		push @{$summary}, "-[[Plik:$name]]";
		return '';
	}
}

sub listLongFiles {
	$logger->info("Zapis listy długich nagrań");
	my $report = "Poniżej znajduje się lista nagrań wymowy, których czas trwania przekracza $maxRecordingLength sekund.\n";

	if ( scalar keys %longFiles ) {
		foreach my $name ( sort keys %longFiles ) {
			$longFiles{$name}{length} =~ /^(.{1,6})/;
			$report .= "* ([[Specjalna:Linkujące/Plik:$name|linkujące]]) [[:Plik:$name|]] ${1}s\n";
		}
	}
	else {
		$report .= "* (brak)";
	}

	$api->edit(
		title   => "User:Beau.bot/wymowa/długie",
		text    => $report,
		summary => 'aktualizacja listy',
	);
}

my $skipFetch = 0;
if ($useCache) {
	my $cache = $bot->retrieveData() if $useCache;
	if ( $cache->{files} and $cache->{words} ) {
		%files     = %{ $cache->{files} };
		%words     = %{ $cache->{words} };
		$skipFetch = 1;
	}
}

unless ($skipFetch) {
	fetchFiles;
	fetchExistingPronunciation;
	$bot->storeData(
		{
			files => \%files,
			words => \%words,
		}
	);
}

my %blacklist = fetchBlacklist;

if ( $logger->is_info ) {
	$logger->info( "Czarna lista plików:\n- " . join( "\n- ", sort keys %blacklist ) );
}

my @queue = sort keys %words;
while (@queue) {
	my @titles = splice( @queue, 0, 200 );

	my $response = $api->query(
		'titles' => join( '|', @titles ),
		'prop'   => 'revisions|info',
		'rvprop' => 'content|timestamp',
		'maxlag' => 20,
	);

	# Listuj odwołania do plików w szablonach audio
	my %needCheck;

	foreach my $page ( values %{ $response->{query}->{pages} } ) {
		next if exists $page->{missing};
		my ($revision) = values %{ $page->{revisions} };

		my @templates = extract_templates( $revision->{'*'} );
		foreach my $template (@templates) {
			next unless $template->{name} =~ /^$reAudioTemplate$/;
			my $name = $template->{fields}->{1};
			unless ( defined $name ) {
				$logger->info("Nieprawidłowe wywołanie szablonu $template->{name} w [[$page->{title}]]");
				next;
			}

			next if exists $files{$name};
			$needCheck{$name}++;
		}
	}

	# Sprawdź, czy linkowane pliki istnieją
	checkFiles( keys %needCheck );

	# Dodawaj lub usuwaj szablony jeśli jest taka potrzeba
	foreach my $page ( values %{ $response->{query}->{pages} } ) {
		$logger->debug("Sprawdzanie strony [[$page->{title}]]");

		if ( exists $page->{missing} ) {
			$logger->debug("[[$page->{title}]] nie istnieje");
			next;
		}

		my $candidates = $words{ $page->{title} };

		unless ($candidates) {
			$logger->warn("Nazwa strony [[$page->{title}]] została znormalizowana");
			next;
		}

		my ($revision) = values %{ $page->{revisions} };
		my $content = $revision->{'*'};
		my @summary;

		# Usuń szablony
		$content =~ s/( *\{\{$reAudioTemplate\s*\|(?:[^{}]+|\{\{[^{}]+\}\})+\}\})/ $_ = checkAudioTemplate($1, \@summary) /ige;

		# Dodaj szablony
		my @sections = split /^(?==)/m, $content;
		foreach my $section (@sections) {
			unless ( $section =~ /^==.+\(\s*\{\{(?:język +)?([^{}()\[\]]+)/ ) {
				next;
			}
			my $language = $1;
			$logger->trace("Sekcja 'język $language'");
			next if $section =~ /\{\{[Aa]udio/;
			unless ( $section =~ /^\{\{wymowa\}\}(.*?)$/m ) {
				next;
			}
			my $pronunciation = $1;
			$logger->debug("Wymowa dla sekcji 'język $language': $pronunciation");

			# Sprawdzenie czy szablony są poprawnie skonstruowane
			my @opened = $pronunciation =~ /\{\{/g;
			my @closed = $pronunciation =~ /\}\}/g;

			if ( @opened != @closed ) {
				$logger->info("Wymowa dla sekcji 'język $language' jest zawiera dziwną konstrukcję");
				next;
			}

			my @changes;
			foreach my $info ( @{$candidates} ) {
				next unless $language eq $info->{language};
				if ( exists $blacklist{ $info->{name} } ) {
					$logger->info("Nagranie $info->{name} zostaje zignorowane, ponieważ znajduje się na czarnej liście");
					next;
				}
				unless ( defined $info->{length} ) {
					$logger->info("Nagranie $info->{name} zostaje zignorowane z powodu nieokreślonej długości");
					next;
				}

				unless ( $info->{length} < $maxRecordingLength ) {
					$logger->info("Nagranie $info->{name} zostaje zignorowane z powodu długości: $info->{length}");
					next;
				}

				$pronunciation .= " {{$info->{template}|$info->{name}}}";
				push @changes, "+$language: [[Plik:$info->{name}]]";
			}

			if ( @changes == 1 ) {
				$section =~ s/^(\{\{wymowa\}\}).*?$/$1$pronunciation/m;
				push @summary, @changes;
			}
			elsif ( @changes > 1 ) {
				local $" = ", ";
				$logger->info("Istnieje kilka plików z wymową dla [[$page->{title}]], ignorowanie: @changes");
			}
		}
		$content = join( '', @sections );

		if ( $revision->{'*'} eq $content ) {
			$logger->info("Brak zmian w $page->{title}");
			next;
		}

		if ( $logger->is_info ) {
			local $" = ", ";
			$logger->info( "Zmiany w [[$page->{title}]], które zostaną wprowadzone (@summary):\n" . diff( \$revision->{'*'}, \$content ) );
		}

		next if $pretend;

		# Wykonaj edycję
		$api->edit(
			title          => $page->{title},
			starttimestamp => $page->{touched},
			basetimestamp  => $revision->{timestamp},
			text           => $content,
			summary        => "robot modyfikuje linki do plików z wymową: " . join( ', ', @summary ),
			bot            => 1,
			minor          => 1,
			nocreate       => 1,
		);
	}
}

listLongFiles
  unless $pretend;
