package RevisionCache;

use strict;
use warnings;
use utf8;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error);
use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);
use DBI;
use Env;
use Digest::SHA qw(sha1);

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'project'      => undef,
		'projectCache' => {},
		'dbh'          => undef,
		@_
	};

	unless ( $this->{dbh} ) {
		$this->{dbh} = DBI->connect(    #
			"DBI:mysql:database=wikimedia;mysql_read_default_group=wikibot;mysql_read_default_file=$ENV{HOME}/.my.cnf",
			undef,
			undef,
			{ RaiseError => 1, 'mysql_enable_utf8' => 1 }
		) or die "Can't connect to database...\n";
	}

	bless $this, $class;
	$this->{projectId} = $this->_getProjectId( $this->{project} )
	  if defined $this->{project};

	return $this;
}

sub _getProjectId {
	my $this = shift;
	my $name = shift;

	die "Undefined project name\n"
	  unless defined $name;

	# FIXME: this is bad when transaction is rolled back!!!
	my $projectId = $this->{projectCache}->{$name};
	return $projectId
	  if defined $projectId;

	# FIXME: race condition when there is concurrent access
	my $select = $this->{dbh}->prepare('SELECT project_id FROM projects WHERE project_name = ?');
	$select->execute($name);
	($projectId) = $select->fetchrow_array;

	unless ( defined $projectId ) {
		my $insert = $this->{dbh}->prepare('INSERT INTO projects(project_name) VALUES (?)');
		$insert->execute($name);
		$projectId = $this->{dbh}->last_insert_id( "", "", "", "" );
	}

	$this->{projectCache}->{$name} = $projectId;
	return $projectId;
}

sub _encodeText {
	my $this = shift;
	my $text = shift;

	utf8::encode $text
	  if utf8::is_utf8 $text;

	# Compress the data
	my $encodedText;
	bzip2 \$text => \$encodedText
	  or die $Bzip2Error;

	if ( bytes::length($encodedText) > bytes::length($text) ) {

		# Plain text
		return ( $text, 0 );
	}
	else {

		# Bzip2
		return ( $encodedText, 1 );
	}
}

sub _decodeText {
	my $this     = shift;
	my $text     = shift;
	my $encoding = shift;

	my $result;

	if ( $encoding == 0 ) {

		# Plain text
		$result = $text;
	}
	elsif ( $encoding == 1 ) {

		# Bzip2
		bunzip2 \$text => \$result
		  or die $Bunzip2Error;
	}
	else {
		die "Unknown encoding: $encoding\n";
	}

	utf8::decode $result
	  unless utf8::is_utf8 $result;

	return $result;
}

sub begin_work {
	my $this = shift;
	$this->{dbh}->begin_work;
}

sub commit {
	my $this = shift;
	$this->{dbh}->commit;
}

sub dbh {
	my $this = shift;
	return $this->{dbh};
}

sub findText {
	my $this = shift;
	my $text = shift;
	my $sha1 = shift;

	utf8::decode $text unless utf8::is_utf8 $text;
	$sha1 = sha1($text)
	  unless defined $sha1;

	my $len = bytes::length($text);

	my $selectTexts = $this->{dbh}->prepare_cached('SELECT text_id id, text_content content, text_encoding encoding FROM texts WHERE text_sha1 = ? AND text_len = ?');

	$selectTexts->execute( $sha1, $len );
	while ( my $row = $selectTexts->fetchrow_hashref ) {
		my $rowText = $this->_decodeText( $row->{content}, $row->{encoding} );

		if ( $rowText eq $text ) {
			$selectTexts->finish;
			return $row->{id};
		}
	}
	return undef;
}

sub storeText {
	my $this = shift;
	my $text = shift;

	utf8::decode $text unless utf8::is_utf8 $text;
	my $sha1 = sha1($text);
	my $len  = bytes::length($text);

	# FIXME: race condition when there is concurrent access
	# Check if there is existing record in the database
	my $textId = $this->findText( $text, $sha1 );

	# Compress the data
	my ( $encodedText, $encoding ) = $this->_encodeText($text);

	# Insert into the database
	my $insertText = $this->{dbh}->prepare_cached('INSERT INTO texts (text_content, text_encoding, text_sha1, text_len) VALUES(?, ?, ?, ?)');
	$insertText->execute( $encodedText, $encoding, $sha1, $len );
	return $this->{dbh}->last_insert_id( "", "", "", "" );
}

sub loadText {
	my $this   = shift;
	my $textId = shift;

	my $selectText = $this->{dbh}->prepare_cached('SELECT text_content, text_encoding FROM texts WHERE text_id = ?');
	$selectText->execute($textId);
	my ( $encodedText, $encoding ) = $selectText->fetchrow_array;
	$selectText->finish;

	die "Revision text $textId does not exist in the database\n"
	  unless defined $encodedText;

	return $this->_decodeText( $encodedText, $encoding );
}

sub storeRevisionText {
	my $this       = shift;
	my $revisionId = shift;
	my $text       = shift;

	my $textId = $this->storeText($text);

	my $insert = $this->{dbh}->prepare_cached('INSERT INTO revisions (rev_project, rev_id, rev_text) VALUES(?, ?, ?) ON DUPLICATE KEY UPDATE rev_text = VALUES(rev_text), rev_pk = LAST_INSERT_ID(rev_pk)');
	$insert->execute( $this->{projectId}, $revisionId, $textId );
	return $this->{dbh}->last_insert_id( "", "", "", "" );
}

sub loadRevisionText {
	my $this       = shift;
	my $revisionId = shift;

	my $selectText = $this->{dbh}->prepare_cached('SELECT text_content, text_encoding FROM revisions JOIN texts ON (rev_text = text_id) WHERE rev_project = ? AND rev_id = ?');
	$selectText->execute( $this->{projectId}, $revisionId );
	my ( $encodedText, $encoding ) = $selectText->fetchrow_array;
	$selectText->finish;

	die "Revision text $this->{project}:$revisionId does not exist in the database\n"
	  unless defined $encodedText;

	return $this->_decodeText( $encodedText, $encoding );
}

sub isRevisionTextCached {
	my $this       = shift;
	my $revisionId = shift;

	my $selectText = $this->{dbh}->prepare_cached('SELECT rev_text FROM revisions WHERE rev_project = ? AND rev_id = ?');
	$selectText->execute( $this->{projectId}, $revisionId );
	my ($textId) = $selectText->fetchrow_array;
	$selectText->finish;

	return defined $textId ? 1 : 0;
}

sub storeRevision {
	my $this     = shift;
	my %revision = @_;

	my $revisionId = delete $revision{id};

	die "Missing revision id\n"
	  unless defined $revisionId;

	my %fields;

	if ( defined $revision{textId} ) {
		$fields{rev_text} = delete $revision{textId};
	}
	elsif ( defined $revision{text} ) {
		$fields{rev_text} = $this->storeText( delete $revision{text} );
	}
	if ( defined $revision{timestamp} ) {
		$fields{rev_timestamp} = delete $revision{timestamp};
	}
	if ( defined $revision{comment} ) {
		$fields{rev_comment} = delete $revision{comment};
	}
	if ( defined $revision{userId} ) {
		$fields{rev_user_id} = delete $revision{userId};
	}
	if ( defined $revision{userText} ) {
		$fields{rev_user_text} = delete $revision{userText};
	}
	if ( defined $revision{parentId} ) {
		$fields{rev_parent_id} = delete $revision{parentId};
	}
	if ( defined $revision{page} ) {
		$fields{rev_page} = delete $revision{page};
	}
	if ( defined $revision{project} ) {
		$fields{rev_project} = $this->_getProjectId( delete $revision{project} );
	}
	elsif ( defined $revision{projectId} ) {
		$fields{rev_project} = delete $revision{projectId};
	}
	else {
		$fields{rev_project} = $this->{projectId};
	}

	# Remove undefined values
	foreach my $name ( keys %revision ) {
		delete $revision{$name}
		  unless defined $revision{$name};
	}
	if ( scalar %revision ) {
		die "Unknown revision fields: " . join( ', ', keys %revision ) . "\n";
	}
	unless ( scalar %fields ) {
		die "Nothing to insert\n";
	}

	my @names        = sort keys %fields;
	my @values       = @fields{@names};
	my @placeholders = map { '?' } @names;

	local $" = ', ';
	my $query = "INSERT INTO revisions (rev_id, @names) VALUES (?, @placeholders) ON DUPLICATE KEY UPDATE rev_pk = LAST_INSERT_ID(rev_pk), " . join( ', ', map { "$_ = VALUES($_)" } @names );
	my $insert = $this->{dbh}->prepare_cached($query);
	$insert->execute( $revisionId, @values );
	return $this->{dbh}->last_insert_id( "", "", "", "" );
}

my %aliases = (
	'id'        => 'rev_id',
	'textId '   => 'rev_text',
	'timestamp' => 'rev_timestamp',
	'comment'   => 'rev_comment',
	'userId'    => 'rev_user_id',
	'userText'  => 'rev_user_text',
	'parentId'  => 'rev_parent_id',
	'text'      => 'text_content',
	'length'    => 'text_len',
	'sha1'      => 'text_sha1',
);

sub loadRevision {
	my $this       = shift;
	my $revisionId = shift;
	my @fields     = shift;

	die "Missing revision id\n"
	  unless defined $revisionId;

	die "Not implemented yet\n";

	push @fields, keys %aliases
	  unless @fields;

	@fields = sort @fields;

	my %fields = map { $_ => 1 } @fields;

	# FIXME
}

1;
