#!/usr/bin/perl -w

use strict;
use utf8;
use Data::Dumper;
use DBI;
use Getopt::Long;

my $database = 'plwiki_p';

GetOptions( "database|d=s" => \$database, );

my $server = $database;
$server =~ tr/_/-/;

my $dbh = DBI->connect( "DBI:mysql:database=$database;host=$server.db.toolserver.org;mysql_read_default_group=client;mysql_read_default_file=$ENV{HOME}/.my.cnf", undef, undef, { RaiseError => 1, 'mysql_enable_utf8' => 0 } )
  or die "Can't connect to database...\n";

my $db_get_list = $dbh->prepare(
	"SELECT LEFT(log_timestamp, 6) AS month, log_type, COUNT(*) as Cnt
	FROM logging
	WHERE log_type IN ('block', 'delete', 'protect') AND log_user <> 70825 AND log_user <> 198721
	GROUP BY month, log_type;
	"
);

$db_get_list->execute;

my %data;
my %months;

while ( my $row = $db_get_list->fetchrow_hashref ) {
	$months{ $row->{month} }++;
	$data{ $row->{log_type} }->{ $row->{month} } = $row->{Cnt};
}

sub plotYear($) {
	my $year = shift;

	my @types = qw(delete block protect);

	open( my $fh, '>', 'plot.dat' ) or die $!;
	binmode $fh, ':utf8';
	local $" = "\t";
	print $fh "Data\t@types\n";

	foreach my $month ( 1 .. 12 ) {
		my %row;

		my $key = sprintf( "%04d%02d", $year, $month );

		foreach my $type (@types) {
			$row{$type} = 0;
			next unless exists $data{$type}{$key};
			$row{$type} = $data{$type}{$key};
		}

		print $fh "$key\t@row{@types}\n";
	}
	close($fh);
	open( $fh, '|-', 'gnuplot' ) or die $!;
	binmode $fh, ':utf8';

	my $cmd = << "EOF";
set title "Rok $year"
set key invert reverse Left outside
set key autotitle columnheader
set yrange [0:40000]
set auto x
unset xtics
set xtics nomirror rotate by -45
set style data histogram
set style histogram rowstacked
set style fill solid # -1
set boxwidth 0.75
set terminal svg
set output "year-$year.svg"
#
plot 'plot.dat' using 2:xtic(1), \\
'' using 3, \\
'' using 4
EOF

	print $fh $cmd;
	close($fh);
}

plotYear($_) for ( 2004 .. 2009 );

sub plotYears {
	my @types = qw(delete block protect);

	open( my $fh, '>', 'plot.dat' ) or die $!;
	binmode $fh, ':utf8';
	local $" = "\t";
	print $fh "Data\t@_\n";

	foreach my $month ( 1 .. 12 ) {
		my %row;

		foreach my $year (@_) {
			my $key = sprintf( "%04d%02d", $year, $month );
			$row{$year} = 0;
			my $value = $data{delete}{$key};
			next unless defined $value;
			$row{$year} = $value;
		}

		print $fh "$month\t@row{@_}\n";
	}
	close($fh);
	open( $fh, '|-', 'gnuplot' ) or die $!;
	binmode $fh, ':utf8';

	my $cmd = << "EOF";
set title "delete"
set key invert reverse Left outside
set key autotitle columnheader
set yrange [0:25000]
set auto x
unset xtics
set xtics nomirror rotate by -45
set terminal svg
set output "delete.svg"
#
plot 'plot.dat' using 2:xtic(1) with lines, '' using 3 with lines, '' using 4 with lines, '' using 5 with lines, '' using 6 with lines, '' using 7 with lines
EOF

	print $fh $cmd;
	close($fh);
}

#plotYears(2004..2009);

# perltidy -et=8 -l=0 -i=8
