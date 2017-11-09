#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use DBI;
use Env;
use Getopt::Long;

my $database = 'plwiki_p';

GetOptions( "database|d=s" => \$database, );

my $server = $database;
$server =~ tr/_/-/;

my $dbh = DBI->connect( "DBI:mysql:database=$database;host=$server.db.toolserver.org;mysql_read_default_group=client;mysql_read_default_file=$ENV{HOME}/.my.cnf", undef, undef, { RaiseError => 1, 'mysql_enable_utf8' => 0 } )
  or die "Can't connect to database...\n";

sub fetchLocation {

	my $query = $dbh->prepare( << 'EOF' );
SELECT pl_title
        FROM page JOIN pagelinks ON(page_id = pl_from)
        WHERE page_namespace = 4 AND page_title = ? AND pl_namespace = 2;
EOF

	my $prefix = 'Atlas_wikipedystów/województwo_';
	my @pages  = qw(
	  dolnośląskie
	  kujawsko-pomorskie
	  lubelskie
	  lubuskie
	  łódzkie
	  małopolskie
	  mazowieckie
	  opolskie
	  podkarpackie
	  podlaskie
	  pomorskie
	  śląskie
	  świętokrzyskie
	  warmińsko-mazurskie
	  wielkopolskie
	  zachodniopomorskie
	);

	my %location;

	print "Fetching location of users\n";
	my $time = time();

	foreach my $page (@pages) {
		my $name = "$prefix$page";
		$query->execute($name);
		while ( my $row = $query->fetchrow_hashref ) {
			$row->{pl_title} =~ tr/_/ /;
			$location{ $row->{pl_title} } = $page;
		}
	}
	print "Done, query time: " . ( time() - $time ) . "s\n";
	return %location;
}

sub fetchBots {
	my $query = $dbh->prepare( << 'EOF' );
SELECT page_title
	FROM categorylinks
	JOIN page ON(page_id = cl_from)
	WHERE (cl_to = 'Nieaktywne_boty_Wikipedii' OR cl_to = 'Boty_Wikipedii') AND page_namespace = 2
EOF

	print "Fetching bots\n";
	my $time = time();
	$query->execute();
	print "Done, query time: " . ( time() - $time ) . "s\n";

	my %bots = map { $_ => 1 } ( 'Stv.bot', 'PixelBot', 'Erwin-Bot', 'conversion script', 'Template namespace initialisation script' );

	while ( my $row = $query->fetchrow_hashref ) {
		$row->{page_title} =~ tr/_/ /;
		$bots{ $row->{page_title} } = 1;
	}
	return %bots;
}

my $db_fetch_date = $dbh->prepare("SELECT MAX(rev_timestamp) AS timestamp FROM revision");
$db_fetch_date->execute();

# Ostatni timestamp w tabeli revisions
my $timestamp;

if ( my $row = $db_fetch_date->fetchrow_hashref ) {
	$timestamp = $row->{timestamp};
}
else {
	die "Unable to fetch MAX(rev_timestamp)\n";
}

$timestamp =~ s/.{6}$/000000/;    # bez obecnego dnia

# Ostatni - 6 miesięcy
my $start = $timestamp;

$start =~ s{^(\d{4})(\d{2})}{
    my $c = $1 * 12 + $2 - 6;
    $_ = sprintf("%04d%02d", int($c / 12), $c % 12);
}ex;

my %location = fetchLocation;
my %bots     = fetchBots;

print "Fetching stats\n";
my $time = time();

my $db_fetch_user_group = $dbh->prepare( '
	SELECT ug_group
	FROM user
	LEFT JOIN user_groups ON(user_id = ug_user)
	WHERE user_name = ?
' );

my $db_fetch_stats = $dbh->prepare( '
	SELECT /* SLOW_OK */
		rev_user_text AS user,
		MAX(rev_timestamp) AS lastedit,
		COUNT(rev_id) AS editcount,
		SUM(IF(rev_timestamp > ?, 1, 0)) AS editcount6m
	FROM revision
	WHERE rev_timestamp < ?
	GROUP BY user
	ORDER BY editcount6m DESC
	LIMIT 1024
' );

$db_fetch_stats->execute( $start, $timestamp ) or die "Unable to fetch stats\n";
print "Done, query time: " . ( time() - $time ) . "s\n";

my $count = 0;

$timestamp =~ /^(\d{4})(\d{2})(\d{2})/;
my $content = << "EOF";
Lista zawiera 600 najaktywniejszych wikipedystów w ostatnich 6 miesiącach. Dane na dzień $3.$2.$1.

{| class="wikitable"
! width="50%" | Ikona
! width="50%" | Status
|-
| [[Plik:Bonhomme crystal marron.png|30px]]
| [[WP:Użytkownicy|użytkownik]]
|-
| [[Plik:Gnome-stock person redact.svg|30px]]
| [[WP:Redaktorzy|redaktor]]
|-
| [[Plik:Gnome-stock person admin.svg|30px]]
| [[WP:Administratorzy|administrator]]
|-
| [[Plik:Gnome-stock person bure.svg|30px]]
| [[WP:Biurokraci|biurokrata]]
|-
| [[Plik:Gnome-stock person check.svg|30px]]
| [[WP:CheckUser|checkuser]]
|}

{| class="wikitable sortable"
!Wikipedysta
!Liczba edycji <br/><small>ostatnie pół roku</small>
!Liczba edycji <br/><small>cały okres edytowania</small>
!Status
!Aktywność
!Województwo
EOF

$timestamp =~ /^(\d{4})(\d{2})(\d{2})/ or die;
my $month = ( $1 * 12 ) + $2;
my $day   = $3;

while ( my $row = $db_fetch_stats->fetchrow_hashref ) {
	$db_fetch_user_group->execute( $row->{user} );
	my $user = $db_fetch_user_group->fetchrow_hashref;
	my %groups;

	if ( defined $user and defined $user->{ug_group} ) {
		$groups{ $user->{ug_group} } = 1;
		while ( $_ = $db_fetch_user_group->fetchrow_hashref ) {
			$groups{ $_->{ug_group} } = 1;
		}
	}
	delete $user->{ug_group} if defined $user;

	next if $groups{bot};
	next if $bots{ $row->{user} };

	$count++;
	last if $count > 600;

	$row->{editcount}   ||= 0;
	$row->{editcount6m} ||= 0;
	my $icons = '';
	my $level = 0;

	if ( $groups{editor} ) {
		$level |= 1;
		$icons .= '[[Plik:Gnome-stock person redact.svg|30px|link=WP:Redaktorzy]]';
	}
	if ( $groups{sysop} ) {
		$level |= 2;
		$icons .= '[[Plik:Gnome-stock person admin.svg|30px|link=WP:Administratorzy]]';
	}
	if ( $groups{bureaucrat} ) {
		$level |= 4;
		$icons .= '[[Plik:Gnome-stock person bure.svg|30px|link=WP:Biurokraci]]';
	}
	if ( $groups{checkuser} ) {
		$level |= 8;
		$icons .= '[[Plik:Gnome-stock person check.svg|30px|link=WP:CheckUser]]';
	}

	$icons = '[[Plik:Bonhomme crystal marron.png|30px|link=WP:Użytkownicy]]' if $icons eq '';

	$row->{lastedit} =~ /^(\d\d\d\d)(\d\d)(\d\d)/;
	my $lastMonth = ( $1 * 12 ) + $2;
	my $lastDay   = $3;

	if ( $day < $lastDay ) {
		$lastMonth++;
	}

	my $inactivity = $month - $lastMonth;
	my ( $active, $activeStyle );

	$active = '<span style="display:none">' . "$1$2$3</span>";

	if ( $inactivity < 1 ) {
		$activeStyle = 'color:Green;';
		$active .= '<strong>A</strong>ktywnie edytuje';
	}
	elsif ( $inactivity < 2 ) {
		$activeStyle = 'background-color:WhiteSmoke; color:SeaGreen;';
		$active .= '<strong>B</strong>rak edycji od <strong>miesiąca</strong>';
	}
	else {
		$activeStyle = 'background-color:WhiteSmoke; color:DarkGray;';
		$active .= '<strong>B</strong>rak edycji od <strong>';

		if ( $inactivity > 24 ) {
			$active .= int( $inactivity / 12 ) . "</strong> lat";
		}
		elsif ( $inactivity > 12 ) {
			$active .= "roku</strong>";
		}
		else {
			$active .= $inactivity . "</strong> miesięcy";
		}
	}

	my $location = '';
	$location = "[[WP:Atlas wikipedystów/województwo $location{ $row->{user} }|$location{ $row->{user} }]]" if exists $location{ $row->{user} };

	$content .= << "EOF";
|-
| [[Wikipedysta:$row->{user}|$row->{user}]]
| style="text-align:right" | $row->{editcount6m}
| style="text-align:right" | $row->{editcount}
| <span style="display:none">$level</span>$icons
| style="$activeStyle" | $active
| $location
EOF
}

$content .= "|}\n";
$content .= "\n[[Kategoria:Rankingi wikipedystów|{{SUBPAGENAME}}]]\n";

print $content;

# perltidy -et=8 -l=0 -i=8
