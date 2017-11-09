#!/usr/bin/perl -w

use strict;
use utf8;
use Data::Dumper;
use DBI;
use Getopt::Long;

my $database = 'plwiki_20090731';
my $host     = '127.0.0.1';
my $user     = 'root';
my $usepass  = 0;
my $password = '';

GetOptions(
	"database|d=s" => \$database,
	"host|h=s"     => \$host,
	"user|u=s"     => \$user,
	"p"            => \$usepass,
);

if ($usepass) {
	$password = <STDIN>;
	chop($password);
}

binmode STDOUT, "utf8";
my $dbh = DBI->connect( "DBI:mysql:database=$database;host=$host", $user, $password, { RaiseError => 1, 'mysql_enable_utf8' => 1 } )
  or die "Can't connect to database...\n";

my $db_get_list = $dbh->prepare( "
	SELECT page_title, rev_text_id, old_text
	FROM page
		JOIN revision ON (page_latest = rev_id)
		JOIN text ON (rev_text_id = old_id)
	WHERE page_namespace = 0 AND old_text LIKE '%<gallery%'
	" );

#my $db_get_list = $dbh->prepare( "SELECT old_id FROM text WHERE old_text LIKE '%<gallery%'" );

$db_get_list->execute;

while ( my $row = $db_get_list->fetchrow_hashref ) {
	print "== [[$row->{page_title}]] ==\n";
	utf8::decode( $row->{old_text} );
	my @galleries = $row->{old_text} =~ m{(<gallery.+?</gallery>)}isg;
	print "$_\n" for @galleries;
}

# perltidy -et=8 -l=0 -i=8
