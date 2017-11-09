#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;
use Data::Dumper;
use DBI;
use File::stat;
use File::Path qw(make_path);
use Digest::SHA1;

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

my $backupDir = 'var/wikisource-backup';
mkdir $backupDir
  or die $!
  unless -d $backupDir;

sub checkSha1 {
	my $file           = shift;
	my $expectedDigest = lc shift;

	$logger->debug("Computing SHA1 for $file");
	open( my $fh, '<', $file )
	  or die $!;

	my $sha1 = Digest::SHA1->new;
	$sha1->addfile($fh);
	close($fh);

	my $digest = lc $sha1->hexdigest;
	if ( $digest eq $expectedDigest ) {
		return 1;
	}
	else {
		$logger->info("File $file has SHA-1 digest $digest, expected $expectedDigest");
		return 0;
	}
}

sub download {
	my $file           = shift;
	my $url            = shift;
	my $size           = shift;
	my $expectedDigest = lc shift;

	$logger->info("Downloading $url to $file");

	my $ua = $api->{ua};

	my $sha1 = Digest::SHA1->new;
	if ( -e $file ) {
		open( my $fh, '<', $file )
		  or die $!;

		$sha1->addfile($fh);
		close($fh);
	}
	open( my $fh, ">>", $file )
	  or die "Unable to open file $file: $!";
	binmode $fh;

	my $bytes_received = tell($fh) || 0;

	my $request = HTTP::Request->new( 'GET' => $url );
	$request->header( 'Range' => "bytes=$bytes_received-" );

	my $res = $ua->request(
		$request,
		sub {
			my ( $chunk, $res ) = @_;

			unless ( print $fh $chunk ) {
				die "Unable to write: $!\n";
			}
			$sha1->add($chunk);
		}
	);
	$bytes_received = tell($fh);
	close($fh)
	  or die $!;
	die $res->status_line . "\n" unless $res->is_success;
	die "Received file has different size ($bytes_received) from expected ($size)\n"
	  unless $bytes_received == $size;

	my $digest = lc $sha1->hexdigest;

	die "File $file has SHA-1 digest $digest, expected $expectedDigest\n"
	  unless $digest eq $expectedDigest;
}

my $selectFilesSth = $dbh->prepare('SELECT * FROM file JOIN file_metadata ON (file_id = fm_file)');
$selectFilesSth->execute();

while ( my $entry = $selectFilesSth->fetchrow_hashref ) {
	$logger->info( "Processing entry:\n" . Dumper($entry) );
	my $name = $entry->{file_name};
	my $size = $entry->{fm_size};
	my $sha1 = lc $entry->{fm_sha1};
	my $url  = $entry->{fm_url};

	die "File name is not defined\n"
	  unless defined $name;
	die "File url is not defined\n"
	  unless defined $url;
	die "File checksum is not defined\n"
	  unless defined $sha1;

	die "Invalid checksum\n"
	  unless $sha1 =~ /^(.)(.)/;

	my $dir = File::Spec->catfile( $backupDir, $1, $2 );
	make_path($dir)
	  or die "Unable to create directory $dir"
	  unless -d $dir;

	my $file = File::Spec->catfile( $dir, $name );

	if ( defined $entry->{fm_description} ) {
		open( my $fh, '>', "$file.txt" )
		  or die $!;
		print $fh $entry->{fm_description}
		  or die $!;
		close($fh)
		  or die $!;
	}

	my $download = 1;
	if ( -e $file ) {
		my $stat = stat($file);
		if ( defined $size and $size != $stat->size ) {
			if ( $stat->size > $size ) {
				$logger->info("Removing file $file, invalid size");
				unlink $file
				  or die $!;
			}
			$download = 1;
		}
		elsif ( defined $sha1 and !checkSha1( $file, $sha1 ) ) {
			$logger->info("Removing file $file, invalid digest");
			unlink $file
			  or die $!;
			$download = 1;
		}
		else {
			$download = 0;
		}
	}

	if ($download) {
		download( $file, $url, $size, $sha1 );
	}
}
