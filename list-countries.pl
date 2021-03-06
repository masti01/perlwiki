#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Text::Diff;
use MediaWiki::Parser;
use locale;

my $logger = Log::Any->get_logger;
$logger->info("Start");

my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->single(1);
$bot->setup;

my $api = $bot->getApi( "wikipedia", "pl" );
$api->checkAccount;

sub fetchIsoCodes {
	my $response = $api->query(
		'titles'  => 'ISO 3166-1',
		'prop'    => 'revisions',
		'rvprop'  => 'content',
		'rvlimit' => 1,
	);

	my ($page) = values %{ $response->{query}->{pages} };
	die "[[$page->{title}]] is missing\n" if exists $page->{missing};

	my ($revision) = values %{ $page->{revisions} };
	my $text = $revision->{'*'};

	$text =~ s{<[^>]+>}{}g;
	$text =~ s{\[\[[^\[\]\|]+\|([^\[\]\|]+)\]\]}{$1}g;

	my @codes = $text =~ m{^\|\s*([A-Z]{2})\s*\|\|\s*([A-Z]{3})\s*\|\|\s*(\d{3})\s*\|}gm;
	my %codes;

	die "No codes found on [[$page->{title}]]\n"
	  unless @codes;

	while (@codes) {
		my ( $alfa2, $alfa3, $digits ) = splice @codes, 0, 3;
		die "alfa2 collision: $alfa2\n"  if exists $codes{$alfa2};
		die "digits collision: $alfa2\n" if exists $codes{$alfa2};
		$codes{$alfa2}  = $alfa3;
		$codes{$digits} = $alfa3;
	}

	# Wyjątki
	$codes{GB} = 'GBR';
	$codes{UK} = 'GBR';
	return %codes;
}

my %continents = (
	'Państwa Ameryki Południowej' => 'Ameryka Południowa',
	'Państwa Ameryki Północnej'  => 'Ameryka Północna',
	'Państwa Azji'                 => 'Azja',
	'Państwa Europy'               => 'Europa',
	'Państwa Afryki'               => 'Afryka',
	'Państwa Oceanii'              => 'Australia i Oceania',
);

my %blacklist = map { $_ => 1 } (    #
	'Azory',
	'Cypr Północny',
	'Grenlandia',
	'Galmudug',
	'Maakhir',
	'Wielka Rzeczpospolita',
	'Republika Chińska',
	'Puntland',
	'Sahara Zachodnia',
	'Samoa Amerykańskie',
	'Związek Rosji i Białorusi',
	'Serbia i Czarnogóra',
);

my %isoCodes = fetchIsoCodes;
my %data;

my $iterator = $api->getIterator(
	'generator'    => 'embeddedin',
	'geititle'     => 'Template:Państwo infobox',
	'geilimit'     => 100,
	'geinamespace' => 0,
	'prop'         => 'revisions',
	'rvprop'       => 'content',
);
while ( my $page = $iterator->next ) {
	$logger->info("Analizowanie [[$page->{title}]]");

	my ($revision) = values %{ $page->{revisions} };

	die "No revision fetched\n"
	  unless $revision;

	# Refine
	$revision->{'*'} =~ s/\{\{Ref\|\d+\}\}//ig;
	$revision->{'*'} =~ s/[¹²]//g;
	$revision->{'*'} =~ s/\{\{(?:wzrost|spadek)}}//ig;
	$revision->{'*'} =~ s/\{\{Ukryj[^\}]+\}\}//ig;

	my @templates = extract_templates( $revision->{'*'} );

	#my %templates = map { ucfirst( $_->{name} ) => 1 } @templates;

	my @infoboxes = grep { $_->{name} eq 'Państwo infobox' } @templates;
	unless (@infoboxes) {
		$logger->warn("Nie można odczytać infoboksu ze strony [[$page->{title}]]");
		next;
	}

	my $infobox = shift @infoboxes;
	my %entry;

	$entry{iso} = $infobox->{fields}->{'kod_ISO'};
	$entry{iso} = 'xxx' if $page->{title} eq 'Sudan Południowy';    # FIXME: hack for Sudan

	my $ignore;
	if ( !defined $entry{iso} or $entry{iso} eq '' ) {
		$ignore = 'brak kodu iso';
	}
	elsif ( defined $infobox->{fields}->{'zależne_od'} and $infobox->{fields}->{'zależne_od'} ne '' ) {
		$ignore = 'terytorium zależne';
	}
	elsif ( defined $infobox->{fields}->{'ustrój_polityczny'} and $infobox->{fields}->{'ustrój_polityczny'} =~ /terytorium zamorskie/ ) {
		$ignore = 'terytorium zamorskie';
	}
	elsif ( defined $infobox->{fields}->{'likwidacja_data'} and $infobox->{fields}->{'likwidacja_data'} ne '' ) {
		$ignore = 'zlikwidowano';
	}
	elsif ( exists $blacklist{ $page->{title} } ) {
		$ignore = 'wpis na czarnej liście';
	}

	if ( defined $ignore ) {
		$logger->info("Ignorowanie [[$page->{title}]]: $ignore");
		next;
	}

	if ( $entry{iso} =~ m{^[A-Z]{2}/([A-Z]{3})/\d{3}$} ) {
		$entry{iso} = $1;
	}
	elsif ( exists $isoCodes{ $entry{iso} } ) {
		$entry{iso} = $isoCodes{ $entry{iso} };
	}

	$entry{population} = $infobox->{fields}->{'ludność'};
	$entry{density}    = $infobox->{fields}->{'gęstość'};
	$entry{area}       = $infobox->{fields}->{'powierzchnia'};
	$entry{capital}    = $infobox->{fields}->{'stolica'};
	$entry{map}        = $infobox->{fields}->{'mapa_obraz'};
	$entry{page}       = $page->{title};

	#print Dumper \%templates;
	my @continents;

	foreach my $template ( keys %continents ) {

		#next unless exists $templates{$template};
		next unless $revision->{'*'} =~ /\{\{$template/i;
		push @continents, $continents{$template};
	}
	die "Unknown continent for $page->{title}\n" unless @continents;
	$entry{continent} = join( ", ", sort @continents );
	$data{ $page->{title} } = \%entry;
}

sub parseNumber($) {
	my $text = shift;
	$text =~ s/(?:&nbsp;|\s)//ig;
	$text =~ s/\[\[.+?\|(.+?)\]\]/$1/g;
	$text =~ tr/,/./;
	return '0' unless $text =~ /^(\d+(\.\d+)?)/;                                    # FIXME: hack for Sudan
	die "Unable to parse number from '$text'\n" unless $text =~ /^(\d+(\.\d+)?)/;
	return $1;
}

sub formatNumber($$) {
	my ( $number, $length ) = @_;

	$number = int( $number * 100 );

	if ( length($number) < $length ) {
		$number = ( '0' x ( $length - length($number) ) ) . $number;
	}
	elsif ( length($number) > $length ) {
		die "Invalid ($length) padding for $number\n";
	}

	return $number;
}

$data{'Bułgaria'}->{map} = 'Bulgaria CIA map PL.png';
$data{'Francja'}->{map}   = 'Fr-map.png';
$data{'Polska'}->{map}    = 'Polandmap cia.png';

my $list = << "EOF";
<!--
 UWAGA! Tabelka została wygenerowana automatycznie przez bota.
 Zamiast wprowadzać w niej zmiany, popraw infobox w artykule
 dotyczącym danego państwa, a następnie skontaktuj się z
 wikipedystą msati w celu wygenerowania tabelki od nowa.
-->
{| class="wikitable sortable"
! Lp.
! Państwo
! Mapa
! Położenie na kontynencie
! Stolica
! Powierzchnia w km²
! Liczba ludności
! Gęstość zaludnienia os/km²
EOF

my $i = 0;
foreach my $title ( sort keys %data ) {
	$i++;
	my %entry = %{ $data{$title} };
	my $map   = '';
	if ( defined $entry{map} and $entry{map} ne '' ) {
		$entry{map} =~ tr/_/ /;
		$map = "[[Plik:$entry{map}|50px|center]]";
	}
	my $country = ( defined $entry{iso} and $entry{iso} ne '' ) ? "{{Państwo|$entry{iso}}}" : $title;

	foreach my $key ( 'area', 'population', 'density' ) {
		my $n = parseNumber( $entry{$key} );
		$n = formatNumber( $n, 12 );
		$entry{$key} = '<span style="display:none;">' . $n . " </span>$entry{$key}";
	}

	$list .= << "EOF";
|-
| $i
| $country
| $map
| $entry{continent}
| $entry{capital}
| style="text-align: right" | $entry{area}
| style="text-align: right" | $entry{population}
| style="text-align: right" | $entry{density}
EOF

}

$list .= << 'EOF';
|}
EOF

print $list;

# perltidy -et=8 -l=0 -i=8
