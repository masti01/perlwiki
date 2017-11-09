#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;
use Data::Dumper;
use RevisionCache;

my $bot = new Bot4;
$bot->setup;

my $logger = Log::Any::get_logger;
my $cache  = new RevisionCache;

my $insertAbuseEditSth = $cache->dbh->prepare("INSERT INTO abusers_edits(ae_edit, ae_confirmed) VALUES(?, ?) ON DUPLICATE KEY UPDATE ae_confirmed = VALUES(ae_confirmed)");

sub insertEdit {
	my %args = @_;
	$logger->info( "Recording an edit " . Dumper \%args );

	my $pk = $cache->storeRevision(%args);
	$insertAbuseEditSth->execute( $pk, 1 );
}

my %list;

while (<>) {
	s/\s+$//;
	my $link = $_;

	$link =~ s{^https://secure\.wikimedia\.org/(.+?)/(.+?)/}{http://$2.$1.org/};

	die "Unable to parse link: $link\n"
	  unless $link =~ m{https?://([^.]+?)\.([^.]+?)\.org};

	my $family = $2;
	my $lang   = $1;

	my $api = $bot->getApi( $family, $lang, "beau" );
	my $project = "$lang.$family";

	if ( $link =~ /diff=(\d+)/ ) {
		my $response = $api->query(
			'action' => 'query',
			'revids' => $1,
			'prop'   => 'revisions',
			'rvprop' => [ 'ids', 'comment', 'user', 'userid', 'timestamp' ],
		);

		my ($page)     = values %{ $response->{query}->{pages} };
		my ($revision) = values %{ $page->{revisions} };

		insertEdit(
			'project'   => $project,
			'id'        => $revision->{revid},
			'userText'  => $revision->{user},
			'userId'    => $revision->{userid},
			'comment'   => $revision->{comment},
			'page'      => $page->{title},
			'timestamp' => $revision->{timestamp},
		);
	}
	elsif ( $link =~ /[&?]diff=prev&oldid=(\d+)/ ) {
		my $response = $api->query(
			'action'   => 'query',
			'revids'   => $1,
			'prop'     => 'revisions',
			'rvdiffto' => 'prev',
			'rvprop'   => [ 'ids', 'comment', 'user', 'userid', 'timestamp' ],
		);

		my ($page)     = values %{ $response->{query}->{pages} };
		my ($revision) = values %{ $page->{revisions} };

		insertEdit(
			'project'   => $project,
			'id'        => $revision->{revid},
			'userText'  => $revision->{user},
			'userId'    => $revision->{userid},
			'comment'   => $revision->{comment},
			'page'      => $page->{title},
			'timestamp' => $revision->{timestamp},
		);
	}
	elsif ( $link =~ m{/(\d+.\d+.\d+.\d+)$} ) {
		my $iterator = $api->getIterator(
			'list'    => 'usercontribs',
			'ucprop'  => [ 'title', 'comment', 'ids', 'timestamp', 'userid' ],
			'ucuser'  => $1,
			'uclimit' => 'max',
		);
		while ( my $contrib = $iterator->next ) {
			insertEdit(
				'project'   => $project,
				'id'        => $contrib->{revid},
				'userText'  => $contrib->{user},
				'userId'    => $contrib->{userid},
				'comment'   => $contrib->{comment},
				'page'      => $contrib->{title},
				'timestamp' => $contrib->{timestamp},
			);
		}
	}
	else {
		die "Unable to parse link: $link\n";
	}
}

# perltidy -et=8 -l=0 -i=8
