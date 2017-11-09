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

my $db_get_list = $dbh->prepare( "
	SELECT template.page_title AS template_title, target.page_title AS target_title, target.page_namespace AS target_namespace FROM pagelinks
		JOIN page template ON (pl_from = template.page_id)
		JOIN page target ON (target.page_title = pl_title AND target.page_namespace = pl_namespace)
	WHERE template.page_namespace = 10 AND target.page_is_redirect;
	" );

$db_get_list->execute;

my %templates;

while ( my $row = $db_get_list->fetchrow_hashref ) {
	my $prefix = $row->{target_namespace} ? "{{ns:$row->{target_namespace}}}:" : '';
	$templates{ $row->{template_title} }{"$prefix$row->{target_title}"}++;
}

while ( my ( $template, $links ) = each %templates ) {
	print "== [[Szablon:$template]] ==\n";
	foreach my $link ( keys %{$links} ) {
		print "* [[:$link]]\n";
	}
}

# perltidy -et=8 -l=0 -i=8
