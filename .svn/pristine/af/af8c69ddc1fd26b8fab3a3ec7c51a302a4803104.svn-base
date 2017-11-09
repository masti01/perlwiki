#!/usr/bin/perl -w

use strict;
use utf8;
use Data::Dumper;
use DBI;
use Getopt::Long;
use locale;

my $database = 'plwiki_p';

GetOptions( "database|d=s" => \$database, );

my $server = $database;
$server =~ tr/_/-/;

my $dbh = DBI->connect( "DBI:mysql:database=$database;host=$server.db.toolserver.org;mysql_read_default_group=client;mysql_read_default_file=$ENV{HOME}/.my.cnf", undef, undef, { RaiseError => 1, 'mysql_enable_utf8' => 0 } )
  or die "Can't connect to database...\n";

my $db_get_list = $dbh->prepare("SELECT page_title FROM page WHERE page_namespace = 0");

$db_get_list->execute;

my %titles;

while ( my $row = $db_get_list->fetchrow_hashref ) {
	$titles{ $row->{page_title} }++;
	if ( $row->{page_title} =~ s/_\([^()]+\)$// ) {
		$titles{ $row->{page_title} }++;
	}
}

my %badtitles;
foreach my $title ( keys %titles ) {
	my $strippedTitle = $title;

	next unless $strippedTitle =~ s/_\([^()]+\)$//;
	next if exists $titles{$strippedTitle} and $titles{$strippedTitle} > 1;
	$badtitles{$title} = $strippedTitle;
}

foreach my $title ( sort keys %badtitles ) {
	my $line = "* [[$title]] -> [[$badtitles{$title}]]\n";
	$line =~ tr/_/ /;
	print $line;
}

# perltidy -et=8 -l=0 -i=8
