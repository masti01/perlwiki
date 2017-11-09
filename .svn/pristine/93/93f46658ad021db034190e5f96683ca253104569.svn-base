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

sub fetchInvalidNames() {
	my $query = $dbh->prepare( << 'EOF' );
	SELECT rev_user AS id, rev_user_text AS name
	FROM revision
	WHERE rev_user > 0
	GROUP BY rev_user, rev_user_text
EOF

	$query->execute();
	my %users;
	while ( my $row = $query->fetchrow_hashref ) {
		push @{ $users{ $row->{id} } }, $row->{name};
	}
	my %invalid;
	while ( my ( $id, $names ) = each %users ) {
		next unless @{$names} > 1;
		$invalid{$id} = $names;
	}
	undef(%users);
	return %invalid;
}

my %names = fetchInvalidNames;

my $db_fetch_name = $dbh->prepare("SELECT user_name FROM user WHERE user_id = ?");

while ( my ( $id, $names ) = each %names ) {
	$db_fetch_name->execute($id);
	my $row = $db_fetch_name->fetchrow_hashref;
	unless ($row) {
		print STDERR "There is no user with id = $id\n";
		next;
	}
	local $" = "', '";
	print "User id '$id'\n";
	print "Current name: '$row->{user_name}'\n";
	print "rev_user_text: '@{$names}'\n";
	print "\n";
}

# perltidy -et=8 -l=0 -i=8
