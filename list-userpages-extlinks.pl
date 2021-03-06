#!/usr/bin/perl

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use POSIX qw(strftime);
use HTML::Template;
use HTML::Entities;
use URI::Escape qw(uri_escape_utf8);

my @projects = qw(
  Wikipedia
  Wikimedia
  Wiktionary
  Wikibooks
  Wikinews
  Wikiquote
  Wikisource
  Wikiversity
);
my $projects = join( '|', @projects );
my $wikiurl = qr{http://[^/]*(?:$projects)\.org}i;

my $updated = strftime( "%d-%m-%Y", localtime() );

sub fetch_list($) {
	my $namespace = shift;
	my %result;

	my %query = (
		'action'       => 'query',
		'generator'    => 'allpages',
		'gapnamespace' => 2,
		'gaplimit'     => 10,           #5000,
		'prop'         => 'extlinks',
		'ellimit'      => 2,            #5000,
	);
	do {
		my $data = $api->query(%query);
		print Dumper($data);

		foreach my $page ( values %{ $data->{query}->{pages} } ) {
			next unless exists $page->{extlinks};
			my @links;
			foreach my $item ( values %{ $page->{extlinks} } ) {
				my $url = $item->{'*'};

				#next if $url =~ m{^http://.+\.wiki[pm]edia\.org}i;
				next if $url =~ $wikiurl;
				next if $url =~ m{^http://tools\.wikimedia\.(?:de|pl)}i;
				next if $url =~ m{^http://(.+?\.)?toolserv.org}i;
				push @links, $url;
			}
			next unless @links;
			$result{ $page->{title} } = \@links;
		}
		if ( $data->{'query-continue'} ) {
			$query{'eloffset'} = $data->{'query-continue'}->{extlinks}->{eloffset};
			defined $query{'eloffset'} or die;    #$query{'gapfrom'} = $data->{'query-continue'}->{allpages}->{gapfrom};
		}
		else {
			delete $query{'gapfrom'};
			delete $query{'eloffset'};
		}
	} while ( defined $query{'gapfrom'} or defined $query{'eloffset'} );

	return %result;
}

putlog "Pobieranie listy";
my %pages = fetch_list(2);
my @lines;
push @lines, '<ul>';

if ( scalar keys %pages ) {
	foreach my $title ( sort { scalar @{ $pages{$b} } <=> scalar @{ $pages{$a} } } keys %pages ) {
		my $count     = scalar @{ $pages{$title} };
		my $title_esc = uri_escape_utf8($title);
		my $title_enc = encode_entities $title, '<>&"';

		push @lines, "<li><a href=\"http://pl.wikipedia.org/w/index.php?title=$title_esc\">$title_enc</a> ($count)</li>";

		#		foreach my $link (@{ $pages{$title} }) {
		#			push @lines, "** $link";
		#		}
	}
}
else {
	push @lines, "<li>(brak)</li>";
}
push @lines, '</ul>';

putlog "Zapis listy";

my $tpl = new HTML::Template( filename => "modern.tpl" );
$tpl->param( title => "Strony użytkowników z linkami zewnętrznymi" );
$tpl->param( content => join( "\n", @lines ) );

write_file( "var/userpages-extlinks.html", $tpl->output() );

$tpl->clear_params();

# perltidy -et=8 -l=0 -i=8
