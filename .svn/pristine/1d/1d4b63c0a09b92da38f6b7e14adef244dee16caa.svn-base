#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;
use Data::Dumper;
use DBI;

use constant NS_PAGE  => 100;
use constant NS_INDEX => 102;

my $logger = Log::Any->get_logger();
my $bot    = new Bot4;
$bot->single(1);
$bot->setProject( "wikisource", "pl" );
$bot->setup;

my $db = 'var/wikisource-backup-files.sqlite';
my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", "", "", { RaiseError => 1, PrintError => 0 } );

my $api = $bot->getApi;
$api->checkAccount;

$dbh->do(<< 'EOF');
CREATE TABLE IF NOT EXISTS file (
	file_id INTEGER PRIMARY KEY,
	file_name TEXT NOT NULL UNIQUE
)
EOF

$dbh->do(<< 'EOF');
CREATE TABLE IF NOT EXISTS file_metadata (
	fm_file INTEGER PRIMARY KEY REFERENCES file (file_id),
	fm_sha1 TEXT,
	fm_size INTEGER,
	fm_repo TEXT,
	fm_url TEXT,
	fm_description TEXT
)
EOF

sub fetchFileList {
	my $insertFileSth = $dbh->prepare('INSERT OR IGNORE INTO file(file_name) VALUES(?)');

	my $indexIterator = $api->getIterator(
		'list'        => 'allpages',
		'apnamespace' => NS_INDEX,
		'aplimit'     => 'max',
	);

	while ( my $indexPage = $indexIterator->next ) {
		if ( $logger->is_debug ) {
			$logger->debug( "Processing:\n" . Dumper($indexPage) );
		}

		my $pageIterator = $api->getIterator(
			'prop'        => 'links',
			'titles'      => $indexPage->{title},
			'plnamespace' => NS_PAGE,
			'pllimit'     => 'max',
		);

		$dbh->begin_work;
		while ( my $page = $pageIterator->next ) {
			foreach my $link ( values %{ $page->{links} } ) {
				next unless $link->{ns} == NS_PAGE;

				if ( $link->{title} =~ m{^Strona:([^/]+)$} ) {
					$insertFileSth->execute($1);
				}
				elsif ( $link->{title} =~ m{^Strona:([^/]+)/\d+$} ) {
					$insertFileSth->execute($1);
				}
				else {
					die Dumper $link;
				}
			}
		}
		$dbh->commit;
	}
}

sub fetchMetadata {
	my $selectFilesSth    = $dbh->prepare('SELECT file_id, file_name FROM file LEFT JOIN file_metadata ON (file_id = fm_file) WHERE fm_file IS NULL');
	my $insertMetadataSth = $dbh->prepare('INSERT INTO file_metadata VALUES (?, ?, ?, ?, ?, ?)');
	$selectFilesSth->execute();

	while (1) {
		my %files;

		while ( my ( $fileId, $fileName ) = $selectFilesSth->fetchrow_array and scalar keys %files < 50 ) {
			utf8::decode($fileName);
			$files{$fileName} = $fileId;
		}
		last unless scalar keys %files;
		my $iterator = $api->getIterator(
			'action' => 'query',
			'prop'   => 'revisions|imageinfo|info',
			'titles' => [ map { "File:$_" } keys %files ],
			'rvprop' => 'content',
			'iiprop' => "size|url|sha1",
		);
		$dbh->begin_work;
		while ( my $page = $iterator->next ) {
			if ( $logger->is_debug ) {
				$logger->debug( "Processing:\n" . Dumper($page) );
			}
			next if exists $page->{redirect};

			my $name = $page->{title};
			$name =~ s/^[^:]+://;
			my $fileId = $files{$name};
			die "Unknown fileId for $name\n"
			  unless defined $fileId;

			my $info = $page->{imageinfo}->{0};
			next unless defined $info;
			die "No imageinfo for $name\n"
			  unless defined $info;

			my $description = undef;
			if ( $page->{revisions} ) {
				my ($revision) = values %{ $page->{revisions} };
				$description = $revision->{'*'};

			}

			die "No image url\n"
			  unless defined $info->{url};

			$insertMetadataSth->execute( $fileId, $info->{sha1}, $info->{size}, $page->{imagerepository}, $info->{url}, $description );

		}
		$dbh->commit;
	}
}

sub fetchDescriptions {
	my $commonsApi = $bot->getApi( "wikimedia", "commons" );
	$commonsApi->checkAccount;

	my $updateDescription = $dbh->prepare('UPDATE file_metadata SET fm_description = ? WHERE fm_file = ?');
	my $selectFilesSth    = $dbh->prepare("SELECT file_id, file_name FROM file JOIN file_metadata ON (file_id = fm_file) WHERE fm_repo = 'shared' AND fm_description IS NULL");
	$selectFilesSth->execute();

	while (1) {
		my %files;

		while ( my ( $fileId, $fileName ) = $selectFilesSth->fetchrow_array and scalar keys %files < 50 ) {
			utf8::decode($fileName);
			$files{$fileName} = $fileId;
		}
		last unless scalar keys %files;
		my $iterator = $commonsApi->getIterator(
			'action' => 'query',
			'prop'   => 'revisions',
			'titles' => [ map { "File:$_" } keys %files ],
			'rvprop' => 'content',
		);
		$dbh->begin_work;
		while ( my $page = $iterator->next ) {
			if ( $logger->is_debug ) {
				$logger->debug( "Processing:\n" . Dumper($page) );
			}

			my $name = $page->{title};
			$name =~ s/^[^:]+://;
			my $fileId = $files{$name};
			die "Unknown fileId for $name\n"
			  unless defined $fileId;

			if ( $page->{revisions} ) {
				my ($revision) = values %{ $page->{revisions} };
				$updateDescription->execute( $revision->{'*'}, $fileId );

			}
		}
		$dbh->commit;
	}

}

fetchFileList;
fetchMetadata;
fetchDescriptions;
