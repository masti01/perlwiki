package ProxyDatabase;

use strict;
use warnings;
use Log::Any;
use DBI;
use DateTime;
use DateTime::Format::Strptime;

my $logger = Log::Any->get_logger;

my $dateFormat = new DateTime::Format::Strptime(
	pattern   => '%Y-%m-%dT%TZ',
	time_zone => 'UTC',
	on_error  => 'croak',
);

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'dbh'  => undef,
		'file' => undef,
		@_,
	};
	bless $this, $class;

	die "A path to a database is missing\n"
	  unless defined $this->{file};

	$this->{dbh} = DBI->connect( "dbi:SQLite:dbname=$this->{file}", "", "", { RaiseError => 1, PrintError => 0, sqlite_use_immediate_transaction => 1 } );

	return $this;
}

# ------------------------------------------------------------------------------

sub begin {
	my $this = shift;
	$this->{dbh}->begin_work;
}

sub commit {
	my $this = shift;
	$this->{dbh}->commit;
}

# ------------------------------------------------------------------------------

sub getSetting {
	my $this = shift;
	my $name = shift;

	my $sth = $this->{dbh}->prepare_cached('SELECT value FROM settings WHERE name = ?');
	$sth->execute($name);
	my ($value) = $sth->fetchrow_array();
	$sth->finish;
	return $value;
}

sub setSetting {
	my $this  = shift;
	my $name  = shift;
	my $value = shift;

	my $sth = $this->{dbh}->prepare_cached('INSERT OR REPLACE INTO settings(name, value) VALUES(?, ?)');
	$sth->execute( $name, $value );
}

# ------------------------------------------------------------------------------

sub insertOrIgnoreProxy {
	my $this    = shift;
	my $address = shift;
	my $source  = shift;

	my $sth = $this->{dbh}->prepare_cached('INSERT OR IGNORE INTO proxies (proxy_address, proxy_added, proxy_source) VALUES (?, ?, ?)');
	$sth->execute( $address, $dateFormat->format_datetime( DateTime->now ), $source );
}

sub fetchProxiesToCheck {
	my $this  = shift;
	my $since = shift;
	my $limit = shift || 50;

	my $sth = $this->{dbh}->prepare_cached( "
	SELECT proxy_id, proxy_address
	FROM proxies
	WHERE proxy_checked IS NULL OR proxy_checked < ?
	ORDER BY proxy_checked, proxy_id DESC
	LIMIT $limit
" );
	$sth->execute( $dateFormat->format_datetime($since) );

	my @list;

	while ( my $row = $sth->fetchrow_hashref ) {
		push @list, $row;
	}
	return @list;
}

# ------------------------------------------------------------------------------

sub insertCheckResult {
	my $this    = shift;
	my $proxy   = shift;
	my $status  = shift;
	my $type    = shift;
	my $address = shift;

	my $timestamp = $dateFormat->format_datetime( DateTime->now );
	my $insertSth = $this->{dbh}->prepare_cached('INSERT INTO checks (check_proxy, check_timestamp, check_status, check_type, check_address) VALUES (?, ?, ?, ?, ?)');
	$insertSth->execute( $proxy, $timestamp, $status, $type, $address );
	my $updateSth = $this->{dbh}->prepare_cached('UPDATE proxies SET proxy_checked = ? WHERE proxy_id = ?');
	$updateSth->execute( $timestamp, $proxy );
}

# ------------------------------------------------------------------------------

sub insertOrIgnoreBlock {
	my $this   = shift;
	my $target = shift;
	my $start  = shift;
	my $expiry = shift;

	my $sth = $this->{dbh}->prepare_cached('INSERT OR IGNORE INTO blocks (block_address, block_start, block_expiry) VALUES (?, ?, ?)');
	$sth->execute( $target, $dateFormat->format_datetime($start), $expiry );
}

sub removeBlock {
	my $this    = shift;
	my $blockId = shift;

	my $sth = $this->{dbh}->prepare_cached('DELETE FROM blocks WHERE block_id = ?');
	$sth->execute($blockId);
}

sub fetchBlocks {
	my $this    = shift;
	my $blockId = shift;
	my $limit   = shift || 50;

	my $sth = $this->{dbh}->prepare_cached("SELECT block_id AS id, block_address AS address, block_start AS start, block_expiry AS expiry FROM blocks ORDER BY block_id ASC LIMIT $limit");
	$sth->execute;

	my @list;
	while ( my $row = $sth->fetchrow_hashref ) {
		$row->{start} = $dateFormat->parse_datetime( $row->{start} );
		push @list, $row;
	}
	return @list;
}

# ------------------------------------------------------------------------------

my @sessionChars = ( 'A' .. 'Z', 'a' .. 'z', '0' .. '9' );

sub generateSessionId {
	my $result = '';

	for ( my $i = 0 ; $i < 32 ; $i++ ) {
		$result .= $sessionChars[ int( rand( scalar @sessionChars ) ) ];
	}
	return $result;
}

sub createSession {
	my $this = shift;

	my $sth   = $this->{dbh}->prepare_cached('INSERT INTO sessions (session_id) VALUES (?)');
	my $count = 0;
	while ( $count < 100 ) {
		my $sessionId = generateSessionId();
		eval {    #
			$sth->execute($sessionId);
		};
		my $error = $@;
		if ($error) {
			die $error
			  unless $error =~ /column session_id is not unique/;
		}
		else {
			return $sessionId;
		}
		$count++;
	}
	die "Unable to generate sessionId\n";
}

sub destroySession {
	my $this      = shift;
	my $sessionId = shift;

	my $sth = $this->{dbh}->prepare_cached('DELETE FROM sessions WHERE session_id = ?');
	$sth->execute($sessionId);
}

sub getSessionAddress {
	my $this      = shift;
	my $sessionId = shift;

	my $sth = $this->{dbh}->prepare_cached('SELECT session_address FROM sessions WHERE session_id = ?');

	$sth->execute($sessionId);
	my ($address) = $sth->fetchrow_array;
	$sth->finish;
	return $address;
}

sub setSessionAddress {
	my $this      = shift;
	my $sessionId = shift;
	my $address   = shift;

	my $sth = $this->{dbh}->prepare_cached('UPDATE sessions SET session_address = ? WHERE session_id = ? AND session_address IS NULL');
	$sth->execute( $address, $sessionId );

	return $sth->rows;
}

# ------------------------------------------------------------------------------

1;
