#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use MediaWiki::Parser;
use DBI;
use Text::Diff;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $ask  = 0;
my $scan = 0;
my $db   = 'var/zabytki.sqlite';

my $bot = new Bot4;
$bot->addOption( "ask"  => \$ask );
$bot->addOption( "scan" => \$scan );
$bot->setup;

my $api = $bot->getApi( "wikipedia", "pl" );
$api->checkAccount;

my $commonsApi = $bot->getApi( "wikimedia", "commons" );
$commonsApi->checkAccount;

if ( $scan and -e $db ) {
	$logger->info("Removing database $db");
	unlink($db);
}

my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", "", "", { RaiseError => 1, PrintError => 0 } );

my %voivodeship = (
	'DS' => 'województwo dolnośląskie',
	'KP' => 'województwo kujawsko-pomorskie',
	'LB' => 'województwo lubuskie',
	'LD' => 'województwo łódzkie',
	'LU' => 'województwo lubelskie',
	'MA' => 'województwo małopolskie',
	'MZ' => 'województwo mazowieckie',
	'OP' => 'województwo opolskie',
	'PD' => 'województwo podlaskie',
	'PK' => 'województwo podkarpackie',
	'PM' => 'województwo pomorskie',
	'SK' => 'województwo świętokrzyskie',
	'SL' => 'województwo śląskie',
	'WN' => 'województwo warmińsko-mazurskie',
	'WP' => 'województwo wielkopolskie',
	'ZP' => 'województwo zachodniopomorskie',
);

my %voivodeshipCodes = ( reverse %voivodeship );
my %months           = (                           #
	'I'             => 1,
	'STYCZNIA'      => 1,
	'II'            => 2,
	'LUTEGO'        => 2,
	'III'           => 3,
	'MARCA'         => 3,
	'IV'            => 4,
	'KWIETNIA'      => 4,
	'V'             => 5,
	'MAJA'          => 5,
	'VI'            => 6,
	'CZERWCA'       => 6,
	'VII'           => 7,
	'LIPCA'         => 7,
	'VIII'          => 8,
	'SIERPNIA'      => 8,
	'IX'            => 9,
	'WRZEŚNIA'     => 9,
	'WRZESNIA'      => 9,
	'X'             => 10,
	'PAŹDZIERNIKA' => 10,
	'PAZDZIERNIKA'  => 10,
	'XI'            => 11,
	'LISTOPADA'     => 11,
	'XII'           => 12,
	'GRUDNIA'       => 12,
);

$_ = join( "|", keys %months );
my $monthRe          = qr/(?:$_)/i;
my $normalizedDateRe = qr/[0123]\d\.[01]\d\.\d{4}/;

sub sanitizeNumber {
	my $number = shift;
	my %result;

	#$result{$number}++;
	$number = uc $number;
	$number =~ s/\s+(?:Z|FROM)\s+(?:dn\.?|dnia)\s*/ Z /ig;
	$number =~ s/^(\S+)\s*[–-]\s*(\d+)/$1-$2/ig;
	$number =~ s/(?:\s*z\s*)?\{\{[Dd]ts\|(\d+)\|(\d+)\|(\d+)\}\}/ sprintf(' Z %02d.%02d.%04d', $1, $2, $3) /ieg;
	$number =~ s/(\d{1,2})\.(\d{1,2})\.(\d{4})(?: R\.)?/ sprintf('%02d.%02d.%04d', $1, $2, $3) /ieg;
	$number =~ s/(\d{2})-(\d{2})-(\d{4})(?: R\.)?/ sprintf('%02d.%02d.%04d', $1, $2, $3) /ieg;
	$number =~ s/(\d{1,2})\.(\d{1,2})\.(\d{2})\b/ $_ = ($3 > 49) ? sprintf('%02d.%02d.%04d', $1, $2, 1900 + $3) : "$1.$2.$3" /eg;
	$number =~ s/(\d{4})-(\d{1,2})-(\d{1,2})/ sprintf('%02d.%02d.%04d', $3, $2, $1) /eg;
	$number =~ s/(\d{4})\.(\d{1,2})\.(\d{1,2})/ sprintf('%02d.%02d.%04d', $3, $2, $1) /eg;
	$number =~ s/\((?:wyciąg|wypis) z księgi rejestru\)//ig;
	$number =~ s/\(NIE ISTNIEJE\s*\??\)//ig;
	$number =~ s/Z\s+(\d+)\s+($monthRe)\s+(\d{4})(?:\s+R\.)?/ sprintf(' Z %02d.%02d.%04d', $1, $months{$2}, $3) /oieg;

	$number =~ s/\s+/ /g;
	$number =~ s/\s+$//;
	$number =~ s/^\s+$//;

	return $number
	  if $number =~ s/^(\S+(?: \d+)?) Z (\d{1,2}.\d{1,2}\.\d{4})$/[$1|$2]/i;
	return $number
	  if $number =~ s/^(\d+)$/[$1]/;
	return $number
	  if $number =~ s/^(\S+)$/[$1]/;
	return $number
	  if $number =~ s{^(\S[- ]\d+)$}{[$1]};
	return $number
	  if $number =~ s{^(\S-\d+/\S+)$}{[$1]};

	my $success = 0;

	if ( !$success and $number =~ /^(\S+) Z ($normalizedDateRe)\s*(?:[;,]|ORAZ|I)\s*(\S+) Z ($normalizedDateRe)$/io ) {
		$result{"[$1|$2]"}++;
		$result{"[$3|$4]"}++;
		$success++;
	}
	if ( !$success and $number =~ /^(\S+) Z ($normalizedDateRe)\s*(?:[;,]|ORAZ|I)\s*Z\s*($normalizedDateRe)$/io ) {
		$result{"[$1|$2]"}++;
		$result{"[$1|$3]"}++;
		$success++;
	}
	unless ($success) {
		$result{$number}++;

		#print $number . "\n";
	}

	return keys %result;
}

sub sanitizeGmina {
	my $name = shift;

	return ''
	  unless defined $name;

	$name =~ s/\[\[(?:[^\|\[\]]+\|)?([^\|\[\]]+)\]\]/$1/g;

	$name =~ tr/_/ /;
	$name =~ s/\s+/ /g;
	$name =~ s/\s+$//;
	$name =~ s/^\s+$//;

	return $name;
}

if (0) {
	my @examples = (    #
		'1006/WŁ z 30.03.1981',
		'1007 z 10.12.1963',
		'1007 z dn. 10.12.63',
		'100-790 z 26.10.60',
		'1007/J z 12.02.1991',
		'1007/L z 29.12.1993 i z 20.04.1995',
		'1007/L z dn. 29.12.93',
		'1007/WŁ z 31.03.1981',
		'1008 z 08.01.1964',
		'1008/J z 12.02.1991',
		'1008/L z 29.12.1993 i z 20.04.1995',
		'1008/L z dn. 29.12.93',
		'1008/WŁ z 31.03.1984',
		'1009 z 08.01.1964',
		'1009 z 8.01.1964',
		'1009/J z 12.02.1991',
		'1009/L z 29.12.1993 i 20.04.1995',
		'1009/L z 29.12.1993',
		'1009/L z dn. 29.12.93',
		'1009/WŁ z 31.03.1983',
		'101 z 14.02.1962',
		'101 z 4.12.1949; 123 z 15.02.1962',
		'1010 z 08.01.1964',
		'1010 z 8.01.1964',
		'1010/J z 11.01.1990',
		'1010/L z 29.12.1993 i z 20.04.1995',
		'1010/L z dn. 29.12.93',
		'1010/WŁ z 31.03.1984',
		'453/58 z 10.08.1958 (wyciąg z księgi rejestru)',
		'453/58 z 10.08.1958 (wypis z księgi rejestru)',
		'933-A {{dts|26|10|1978}}',
		'933-A z {{dts|26|10|1978}}',
		'933-A z 26.10.1978',
		'A/302/10 Z 18 VI 2010 R.',
		'A/3021/523 Z 1990.12.13',
		'A/313/10 Z 20 VIII 2010',
		'A/523/57 Z 2 MAJA 1957',
		'KOK-I-541/63 Z 30.05.1963 ORAZ 61 Z 28.10.1976',
		'KOK-I-554 Z 20.06.1963; KOK-I-783 Z 15.02.1964; 64 Z 02.11.1976',
		'KOK-I-556/63 Z 20.06.1963; 66 Z 02.11.1976',
		'906 Z 11.07.1984 I Z 01.07.1993',
		'A/287 Z 31.03.1967 I Z 25.10.1984',
	);

	foreach my $example (@examples) {
		print "'$example'\n";
		print "'" . join( "', '", sanitizeNumber($example) ) . "'\n";
	}
	exit(0);
}

sub createTables {
	my $query = << 'EOF';
CREATE TABLE IF NOT EXISTS page (
	page_id INTEGER NOT NULL PRIMARY KEY,
	page_ns INTEGER NOT NULL,
	page_title TEXT NOT NULL
)
EOF

	$dbh->do($query);
	$dbh->do('CREATE UNIQUE INDEX IF NOT EXISTS ns_title ON page (page_ns, page_title)');

	$query = << 'EOF';
CREATE TABLE IF NOT EXISTS number (
	number_id INTEGER NOT NULL PRIMARY KEY,
	number_voivodeship TEXT NOT NULL,
	number_gmina TEXT NOT NULL,
	number_text TEXT NOT NULL
)
EOF

	$dbh->do($query);
	$dbh->do('CREATE UNIQUE INDEX IF NOT EXISTS vt ON number (number_voivodeship, number_gmina, number_text)');

	$query = << 'EOF';
CREATE TABLE IF NOT EXISTS page_number (
	page_id INTEGER NOT NULL,
	number_id INTEGER NOT NULL,
	pn_type INTEGER NOT NULL,
	PRIMARY KEY (page_id, number_id)
)
EOF

	$dbh->do($query);
	$dbh->do('CREATE INDEX IF NOT EXISTS numberidx ON page_number (number_id)');
}

createTables;
my $selectNumber = $dbh->prepare("SELECT number_id FROM number WHERE number_voivodeship = ? AND number_gmina = ? AND number_text = ?");

sub getNumber($$$) {
	my ( $voivodeship, $gmina, $text ) = @_;
	$selectNumber->execute( $voivodeship, $gmina, $text );
	if ( my ($id) = $selectNumber->fetchrow_array ) {
		return $id;
	}
	return undef;
}

sub scanCommons {
	my $templateIterator = $commonsApi->getIterator(
		'generator'    => 'embeddedin',
		'geititle'     => 'Template:Zabytek',
		'geilimit'     => '50',
		'geinamespace' => [ NS_CATEGORY, NS_FILE ],
		'prop'         => 'revisions',
		'rvprop'       => 'content'
	);

	my $insertPage       = $dbh->prepare("INSERT OR IGNORE INTO page (page_id, page_ns, page_title) VALUES(?, ?, ?)");
	my $insertNumber     = $dbh->prepare("INSERT OR IGNORE INTO number (number_voivodeship, number_gmina, number_text) VALUES(?, ?, ?)");
	my $insertPageNumber = $dbh->prepare("INSERT OR IGNORE INTO page_number (page_id, number_id, pn_type) VALUES(?, ?, ?)");

	my $count = 0;
	$dbh->begin_work;
	while ( my $page = $templateIterator->next ) {
		$logger->info("Sprawdzanie [[$page->{title}]]");
		eval {
			my ($revision) = values %{ $page->{revisions} };

			my $content = $revision->{'*'};
			$content =~ s/\{\{[Dd]ate\|(\d+)\|(\d+)\|(\d+)\}\}/$3.$2.$1/g;

			my @templates = $content =~ /(\{\{[Zz]abytek(.+?)\}\})/sg;
			@templates = grep { $_->{name} =~ /^[Zz]abytek$/ } extract_templates( join( '', @templates ) );

			die "Brak szablonów Zabytek\n"
			  unless @templates;

			my $title = $page->{title};
			$title =~ s/^[^:]+://;

			$insertPage->execute( $page->{pageid}, $page->{ns}, $title );
			my @numberIds;

			foreach my $template (@templates) {
				my $code = $template->{fields}->{1};
				die "Nieprawidłowy kod województwa: $code\n"
				  unless exists $voivodeship{$code};

				my $number = $template->{fields}->{2};
				die "Brak numeru z rejestru\n"
				  unless defined $number;

				my $gmina = sanitizeGmina( $template->{fields}->{3} );

				foreach my $saneNumber ( sanitizeNumber($number) ) {
					$insertNumber->execute( $code, $gmina, $saneNumber );
					my $numberId = getNumber( $code, $gmina, $saneNumber );
					push @numberIds, $numberId;
					$insertPageNumber->execute( $page->{pageid}, $numberId, 0 );
					$count++;
				}
			}

			if ( @numberIds and $page->{ns} == NS_CATEGORY ) {
				my $categoryIterator = $commonsApi->getIterator(
					'list'        => 'categorymembers',
					'cmtitle'     => $page->{title},
					'cmlimit'     => 'max',
					'cmnamespace' => [ NS_CATEGORY, NS_FILE ],
				);
				while ( my $memberPage = $categoryIterator->next ) {
					my $title = $memberPage->{title};
					$title =~ s/^[^:]+://;
					$insertPage->execute( $memberPage->{pageid}, $memberPage->{ns}, $title );
					foreach my $numberId (@numberIds) {
						$insertPageNumber->execute( $memberPage->{pageid}, $numberId, 1 );
					}
				}
			}

			if ( $count > 100 ) {
				$count = 0;
				$dbh->commit;
				$dbh->begin_work;
			}
		};
		if ($@) {
			$@ =~ s/\s+$//;
			$logger->error("[[$page->{title}]]: $@");

			#die;
		}
	}
	$dbh->commit;
}

my $countSth = $dbh->prepare('SELECT * FROM page LIMIT 1');
$countSth->execute;

unless ( $countSth->fetchrow_array ) {
	$logger->info("Przeszukiwanie commons");
	scanCommons;
}

my $iterator = $api->getIterator(
	'generator'     => 'embeddedin',
	'geititle'      => 'Template:Zabytki wiersz',
	'geilimit'      => '1',
	'geinamespace'  => '102',
	'prop'          => 'revisions|info',
	'rvprop'        => 'content|timestamp',
	'rvexcludeuser' => 'Beau.bot',
	'rvlimit'       => 1,
);

my $selectSth = $dbh->prepare('SELECT page_ns, page_title FROM number n JOIN page_number pn ON (n.number_id = pn.number_id) JOIN page p ON (pn.page_id = p.page_id) WHERE number_voivodeship = ? AND number_gmina = ? AND number_text = ?');
my @pagesWithDuplicates;

while ( my $page = $iterator->next ) {
	$logger->info("Sprawdzanie [[$page->{title}]]");
	eval {
		die "Nieprawidłowa nazwa strony\n"
		  unless $page->{title} =~ m{^Wikiprojekt:Wiki Lubi Zabytki/wykazy/(województwo [^/]+?)/};

		my $code = $voivodeshipCodes{$1};

		die "Nieprawidłowe województwo $1\n"
		  unless defined $code;

		my ($revision) = values %{ $page->{revisions} };
		my $content = $revision->{'*'};

		my %used;
		my %parent;

		my %categories;
		my %files;

		foreach my $template ( grep { $_->{name} =~ /^[Zz]abytki wiersz$/ } extract_templates($content) ) {
			my $number = $template->{fields}->{numer};
			unless ( defined $number and $number ne '' ) {

				#$logger->warn("Brak numeru");
				next;
			}

			my $gmina = sanitizeGmina( $template->{fields}->{gmina} );

			foreach my $saneNumber ( sanitizeNumber($number) ) {
				$used{"$saneNumber/$gmina"}++;
				$parent{"$saneNumber/$gmina"}{"$number/$gmina"}++;

				$selectSth->execute( $code, $gmina, $saneNumber );

				while ( my $row = $selectSth->fetchrow_arrayref ) {
					utf8::decode( $row->[1] );
					if ( $row->[0] == NS_CATEGORY ) {
						$categories{$number}{ $row->[1] }++;
					}
					else {
						$files{$number}{ $row->[1] }++;
					}
				}
			}
		}

		my %duplicates;
		while ( my ( $k, $v ) = each %used ) {
			next if $v < 2;
			foreach my $parent ( keys %{ $parent{$k} } ) {
				$duplicates{$parent}++;
			}
		}
		undef %used;
		undef %parent;

		if (%duplicates) {
			$logger->warn( "Na stronie [[$page->{title}]] występują duplikaty: '" . join( "', '", keys %duplicates ) . "'" );
			push @pagesWithDuplicates,
			  {
				'page' => $page->{title},
				'list' => [ keys %duplicates ],
			  };
		}

		my $modifyTemplate = sub {
			my $text      = shift;
			my @templates = extract_templates($text);

			return $text
			  unless @templates == 1;

			my $template = shift @templates;

			return $text
			  unless $template->{name} =~ /^[Zz]abytki wiersz$/;

			my @fields = (    #
				{ 'name' => 'numer',       required => 1 },
				{ 'name' => 'nazwa',       required => 1 },
				{ 'name' => 'adres',       required => 1 },
				{ 'name' => 'gmina',       required => 1 },
				{ 'name' => 'koordynaty',  required => 0 },
				{ 'name' => 'szerokość', required => 0 },
				{ 'name' => 'długość',  required => 0 },
				{ 'name' => 'zdjęcie',    required => 1 },
				{ 'name' => 'commons',     required => 1 },
			);

			my $number = $template->{fields}->{numer};
			my $gmina  = sanitizeGmina( $template->{fields}->{gmina} );

			if ( defined $number and $number ne '' and !$duplicates{"$number/$gmina"} ) {
				my $categories = $categories{$number};

				if ($categories) {
					my $cn = scalar keys %{$categories};
					if ( $cn == 1 ) {
						my $commons = $template->{fields}->{commons};
						if ( !defined $commons or $commons eq '' ) {
							( $template->{fields}->{commons} ) = keys %{$categories};
						}
					}
				}
				my $files = $files{$number};
				if ( $files and %{$files} ) {
					my $file = $template->{fields}->{'zdjęcie'};
					if ( !defined $file or $file eq '' ) {
						( $template->{fields}->{'zdjęcie'}, undef ) = keys %{$files};

					}
				}
			}

			my $newText     = "{{Zabytki wiersz\n";
			my $fieldLength = 10;

			foreach my $field (@fields) {
				my $name  = $field->{name};
				my $value = $template->{fields}->{$name};
				if ( !defined $value and $field->{required} ) {
					$value = '';
				}
				next
				  unless defined $value;

				my $displayName = $name;
				while ( length($displayName) < $fieldLength ) {
					$displayName .= ' ';
				}

				$newText .= "| $displayName = $value\n";
			}

			$newText .= '}}';

			return $newText;

		};

		$content =~ s/(\{\{[Zz]abytki wiersz(?:[^\{\}]*(?:\{\{.*?\}\})?)*\}\})/ $modifyTemplate->($1) /sge;

		if ( $content ne $revision->{'*'} ) {

			my $edit = 1;

			if ($ask) {
				print diff( \$revision->{'*'}, \$content ) . "\n";
				$_ = <STDIN>;
				$edit = ( $_ =~ /[TtYy]/i ) ? 1 : 0;
			}

			$api->edit(
				title          => $page->{title},
				starttimestamp => $page->{touched},
				text           => $content,
				bot            => 1,
				minor          => 1,
				summary        => "uzupełnienie szablonów",
				basetimestamp  => $revision->{timestamp},
				nocreate       => 1,
			) if $edit;

		}
	};
	if ($@) {
		$@ =~ s/\s+$//;
		$logger->error("[[$page->{title}]]: $@");
		die;
	}

}

sub generateDuplicatesReport {
	@pagesWithDuplicates = sort { $a->{page} cmp $b->{page} } @pagesWithDuplicates;
	my $report = << 'EOF';
{| class="wikitable"
! Nazwa strony
! Powtórzone numery
EOF

	foreach my $entry (@pagesWithDuplicates) {
		$report .= "|-\n";
		$report .= "| [[$entry->{page}]]\n";
		$report .= "|\n";
		foreach my $number ( sort @{ $entry->{list} } ) {
			$report .= "* <nowiki>$number</nowiki>\n";
		}
	}
	$report .= "|}";
	return $report;
}

$logger->info("Zapisywanie listy duplikatów");
$api->edit(
	title   => 'User:Beau.bot/listy/zabytki/duplikaty',
	text    => generateDuplicatesReport(),
	bot     => 1,
	summary => "aktualizacja listy",
);

sub generateUncategorizedReport {

	my $selectPageSth          = $dbh->prepare('SELECT page_ns, page_title FROM page WHERE page_id = ?');
	my $selectNumberSth        = $dbh->prepare('SELECT number_voivodeship, number_gmina, number_text FROM number WHERE number_id = ?');
	my $selectUncategorizedSth = $dbh->prepare('SELECT number_id, COUNT(page_id) count, GROUP_CONCAT(page_id) AS pages FROM page_number WHERE pn_type = 0 GROUP BY number_Id HAVING count > 2');
	$selectUncategorizedSth->execute();

	my %list;

	while ( my $row = $selectUncategorizedSth->fetchrow_hashref ) {
		my $key = join( ',', sort split /,/, $row->{pages} );
		push @{ $list{$key} }, $row->{number_id};
	}

	my $report = << 'EOF';
{| class="wikitable"
! Numer zabytku
! Strony
EOF

	foreach my $key ( keys %list ) {
		my @pages = sort map {
			$selectPageSth->execute($_);
			my $page = $selectPageSth->fetchrow_hashref;
			die "Unknown page_id = $_\n"
			  unless $page;

			utf8::decode( $page->{page_title} );

			$_ = ( $page->{page_ns} == NS_CATEGORY ? 'Category:' : 'File:' ) . $page->{page_title};

		} split ',', $key;
		my @numbers = sort map {
			$selectNumberSth->execute($_);
			my $number = $selectNumberSth->fetchrow_hashref;
			die "Unknown number_id = $_\n"
			  unless $number;

			utf8::decode( $number->{number_voivodeship} );
			utf8::decode( $number->{number_gmina} );
			utf8::decode( $number->{number_text} );

			$_ = "$number->{number_voivodeship} $number->{number_gmina} $number->{number_text}";

		} @{ $list{$key} };

		$report .= "|-\n|\n";
		foreach my $number (@numbers) {
			$report .= "* <nowiki>$number</nowiki>\n";
		}
		$report .= "|\n";
		foreach my $page (@pages) {
			$report .= "* [[:commons:$page]]\n";
		}
	}

	$report .= "|}";
	return $report;
}

$logger->info("Zapisywanie listy nieskategoryzowanych");

$api->edit(
	title   => 'User:Beau.bot/listy/zabytki/nieskategoryzowane',
	text    => generateUncategorizedReport(),
	bot     => 1,
	summary => "aktualizacja listy",
);
