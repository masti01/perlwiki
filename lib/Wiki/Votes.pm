package Wiki::Votes;
require Exporter;

use utf8;
use strict;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(get_subpages get_results);
our @EXPORT_OK = qw();
our $VERSION   = 20110228;

sub get_subpages {
	my $api              = shift @_;
	my $main_page        = shift @_;
	my $page_prefix      = shift @_;
	my %ignored_subpages = map { $_ => 1 } @_;

	my @pages;

	my $data = $api->query(
		'prop'        => 'templates',
		'tlnamespace' => 4,
		'tllimit'     => 500,
		'titles'      => $main_page,
	);

	my ($page) = values %{ $data->{query}->{pages} };
	foreach my $item ( values %{ $page->{templates} } ) {
		my $title = $item->{title};

		next unless $title =~ m{^$page_prefix/(.+)$}i;
		next if defined $ignored_subpages{$1};
		push @pages, $title;
	}
	return @pages;
}

sub get_results {
	my $api = shift @_;
	my $re  = shift;
	return unless scalar @_;

	my $data = $api->query(
		'prop'   => 'revisions',
		'titles' => join( "|", @_ ),
		'rvprop' => 'content',

		#'rvlimit'	=> 1,
		#'rvdir'	=> 'older',
	);

	my @results;
	foreach my $page ( values %{ $data->{query}->{pages} } ) {
		my ($revision) = values %{ $page->{revisions} };
		my $content    = $revision->{'*'};
		my $title      = $page->{title};

		my @lists;
		my @chunks = defined $content ? $content =~ $re : ();
		foreach my $text (@chunks) {
			my @list;

			foreach ( split "\n", $text ) {
				next unless /^#/;
				next if /^#[:*#]/;
				next if /^#\s*$/;

				if (/\[\[(?:User|Wikipedysta|Wikipedystka):([^\]\|]+)/i) {
					my $name = ucfirst $1;
					$name =~ tr/_/ /;
					push @list, $name;
				}
				else {
					push @list, undef;
				}
			}
			push @lists, \@list;
		}
		my $page = {
			'title'   => $title,
			'content' => $content,
			'values'  => \@lists,
		};

		if ( defined $content ) {
			if ( $content =~ /(?:enunx_start|startU)=\s*(\d+)/ ) {
				$page->{start} = $1;
			}

			if ( $content =~ /(?:stopU|enunx)=\s*(\d+)/ ) {
				$page->{finish} = $1;
			}
			elsif ( $content =~ /(?:stopU|enunx)=\s*\{\{#expr:([0-9+*]+)\}\}/ ) {
				$page->{finish} = eval $1;
			}
		}
		push @results, $page;
	}
	return @results;
}

1;

# perltidy -et=8 -l=0 -i=8
