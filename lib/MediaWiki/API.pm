package MediaWiki::API;
require Exporter;

use strict;
use warnings;
use MediaWiki::API::Iterator;
use utf8;
use LWP::UserAgent;
use HTTP::Request;
use URI;
use MediaWiki::Unserializer;
use Log::Any;
use Data::Dumper;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(NS_MEDIA NS_SPECIAL NS_MAIN NS_TALK NS_USER NS_USERTALK NS_PROJECT NS_PROJECTTALK NS_FILE NS_FILETALK NS_MEDIAWIKI NS_MEDIAWIKITALK NS_TEMPLATE NS_TEMPLATETALK NS_HELP NS_HELPTALK NS_CATEGORY NS_CATEGORYTALK);
our @EXPORT_OK = qw();
our $VERSION   = 20150417;

our $hasZlib;
our $logger;

use constant NS_MEDIA         => -2;
use constant NS_SPECIAL       => -1;
use constant NS_MAIN          => 0;
use constant NS_TALK          => 1;
use constant NS_USER          => 2;
use constant NS_USERTALK      => 3;
use constant NS_PROJECT       => 4;
use constant NS_PROJECTTALK   => 5;
use constant NS_FILE          => 6;
use constant NS_FILETALK      => 7;
use constant NS_MEDIAWIKI     => 8;
use constant NS_MEDIAWIKITALK => 9;
use constant NS_TEMPLATE      => 10;
use constant NS_TEMPLATETALK  => 11;
use constant NS_HELP          => 12;
use constant NS_HELPTALK      => 13;
use constant NS_CATEGORY      => 14;
use constant NS_CATEGORYTALK  => 15;

BEGIN {
	$hasZlib = eval 'use Compress::Zlib (); 1;';
	$logger  = Log::Any->get_logger();
}

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	$logger->warn("Compress::Zlib was not found") unless $hasZlib;

	my $this = {
		'url'          => 'http://pl.wikipedia.org/w/api.php',
		'login'        => '',
		'password'     => '',
		'attempts'     => 5,
		'attemptdelay' => 15,
		'maxlag'       => undef,
		'tokens'       => {},
		'cache'        => {},
		'cookieJar'    => {},
		@_
	};

	$this->{ua} = LWP::UserAgent->new()
	  unless defined $this->{ua};

	$this->{ua}->agent( __PACKAGE__ . '/' . $VERSION );
	$this->{ua}->cookie_jar( $this->{cookieJar} );

	bless $this, $class;
	return $this;
}

sub _encode($) {
	my $data = shift;
	utf8::encode($data) if utf8::is_utf8 $data;
	return $data;
}

sub prepareRequest {
	my $this = shift;

	# check parameters
	my %args = @_;
	while ( my ( $key, $value ) = each %args ) {
		if ( !defined $value ) {
			die("The value of the parameter '$key' is undef\n");
		}
		elsif ( ref($value) eq 'ARRAY' ) {
			no utf8;
			$args{$key} = join( '|', @{$value} );
		}
		elsif ( ref($value) ne '' ) {
			die("The value of the parameter '$key' is neither a scalar nor an array\n");
		}
	}
	if ( !exists $args{maxlag} and defined $this->{maxlag} ) {
		$args{maxlag} = $this->{maxlag};
	}
	$args{format} = 'php';
	$args{action} = 'query' unless exists $args{action};
	%args = map { _encode $_ } %args;

	if ( $logger->is_debug ) {
		$logger->debug( "Preparing request:\n" . Dumper( \%args ) );
	}

	my $uri = URI->new('http:');
	$uri->query_form(%args);
	my $content = $uri->query;

	# FIXME: what about cookies?

	my $request = HTTP::Request->new( 'POST', $this->{url} );
	$request->header( 'Content-Type',    'application/x-www-form-urlencoded' );
	$request->header( 'Content-Length',  bytes::length($content) );
	$request->header( 'Accept-Encoding', $hasZlib ? 'gzip' : 'identity' );
	$request->content($content);

	return $request;
}

sub query {
	my $this = shift;

	# reset error
	$this->{error} = undef;

	my $request = $this->prepareRequest(@_);
	my $attempt = 0;

	while (1) {
		my $response = $this->{ua}->request($request);

		if ( $logger->is_trace ) {
			$logger->trace( "Response content:\n" . $response->decoded_content( charset => 'none' ) );
		}

		unless ( $response->is_success ) {
			$logger->info( "Request failed, HTTP error: " . $response->status_line );
			$this->{error} = {
				'code' => $response->code,
				'info' => $response->message,
			};
			die $response->status_line . "\n" unless ++$attempt < $this->{attempts};
			sleep( $this->{attemptdelay} );
			next;
		}

		my $unserializer = MediaWiki::Unserializer->new();
		my $data = $unserializer->decode( $response->decoded_content( charset => 'none' ) );

		if ( $logger->is_debug ) {
			$logger->debug( "Response:\n" . Dumper($data) );
		}

		if ( exists $data->{error} ) {

			# handle replication lag here
			if ( $data->{error}->{code} eq 'maxlag' and ++$attempt < $this->{attempts} ) {
				$logger->info("Request failed, replication lag: $data->{error}->{info}, sleeping $this->{attemptdelay} seconds");
				sleep( $this->{attemptdelay} );
				next;
			}
			$this->{error} = $data->{error};
			die "Request failed, API error: $data->{error}->{info}\n";
		}

		if ( $data->{warnings} ) {
			$logger->warn( "API warning:\n" . Dumper( $data->{warnings} ) );
		}

		return $data;
	}
}

sub attempts : lvalue {
	my $this = shift;
	$this->{attempts} = $_[0] if @_;
	$this->{attempts};
}

sub attemptdelay : lvalue {
	my $this = shift;
	$this->{attemptdelay} = $_[0] if @_;
	$this->{attemptdelay};
}

sub maxlag : lvalue {
	my $this = shift;
	$this->{maxlag} = $_[0] if @_;
	$this->{maxlag};
}

sub agent($) {
	my $this = shift;
	return $this->{ua}->agent(@_);
}

sub error {
	my $this = shift;
	return $this->{error};
}

sub login {
	my ( $this, $login, $password ) = @_;

	$this->{login}    = $login    if defined $login;
	$this->{password} = $password if defined $password;

	my $tokenResponse = $this->query( 'meta' => 'tokens', 'type' => 'login' );

	my %query = (
		'action'     => 'login',
		'lgname'     => $this->{login},
		'lgpassword' => $this->{password},
		'lgtoken'    => $tokenResponse->{query}->{tokens}->{logintoken},
	);
	my $response = $this->query(%query);

	if ( $response->{login}->{result} ne 'Success' ) {
		$this->{error} = { 'code' => $response->{login}->{result}, };
		$this->{error}->{info} = "$response->{login}->{result}: $response->{login}->{details}"
		  if defined $response->{login}->{details};

		die "API error: $this->{error}->{code}\n";
	}
	return $response;
}

sub expandtemplates {
	my $this = shift;

	my %query = ( @_, 'action' => 'expandtemplates', 'prop' => 'wikitext' );
	my $data = $this->query(%query);

	return undef unless $data;
	return $data->{expandtemplates}->{'wikitext'};
}

sub checkAccount {
	my $this = shift;
	my $data = $this->query(
		'meta'   => 'userinfo',
		'uiprop' => 'blockinfo|hasmsg',
		'maxlag' => 20
	);

	$data = $data->{query}->{userinfo};
	if ( exists $data->{anon} ) {
		die "User is not logged in\n";
	}
	if ( exists $data->{blockreason} ) {
		my $message = "User has been blocked by $data->{blockedby}";
		$message .= ": $data->{blockreason}"
		  if defined $data->{blockreason} and $data->{blockreason} ne '';

		die $message . "\n";
	}
	$this->{login} = $data->{name};
}

# -----------------------------------------------------------
# Cached site info
# -----------------------------------------------------------

sub invalidateSiteInfoCache {
	my $this = shift;

	if ( !defined $this->{cache}->{url} or $this->{url} ne $this->{cache}->{url} ) {
		$logger->debug("Fetching site info");
		my %cache;
		$cache{url} = $this->{url};

		my $response = $this->query(
			'meta'   => 'siteinfo',
			'siprop' => 'general|namespaces|namespacealiases|magicwords|interwikimap',
		);

		$cache{general} = $response->{query}->{general};

		$cache{namespaceAliases}    = {};
		$cache{namespaces}          = {};
		$cache{canonicalNamespaces} = {};

		foreach my $alias ( values %{ $response->{query}->{namespacealiases} } ) {
			$cache{namespaceAliases}{ lc( $alias->{'*'} ) } = $alias->{id};
		}

		foreach my $namespace ( values %{ $response->{query}->{namespaces} } ) {
			$cache{namespaceAliases}{ lc( $namespace->{'*'} ) } = $namespace->{id};
			$cache{namespaceAliases}{ lc( $namespace->{canonical} ) } = $namespace->{id} if defined $namespace->{canonical};

			$cache{namespaces}{ $namespace->{id} } = $namespace->{'*'};

			$cache{canonicalNamespaces}{ $namespace->{id} } = defined $namespace->{canonical} ? $namespace->{canonical} : '';
		}

		$cache{interwikiMap} = [ values %{ $response->{query}->{interwikimap} } ];
		$cache{magicWords} = { map { $_->{name} => $_ } values %{ $response->{query}->{magicwords} } };

		if ( $logger->is_debug ) {
			$logger->debug( "New site info\n" . Dumper( \%cache ) );

		}

		$this->{cache} = \%cache;
	}
}

sub getGeneralSiteInfo {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	my $arg = shift;

	if ( defined $arg ) {
		return $this->{cache}->{general}->{$arg};
	}
	else {
		return %{ $this->{cache}->{general} };
	}
}

sub getNamespaces {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	return %{ $this->{cache}->{namespaces} };
}

sub getNamespace {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	my $ns   = shift;
	my $name = $this->{cache}{namespaces}{$ns};
	die "Unknown namespace $ns\n" unless defined $name;
	return $name;
}

sub getCanonicalNamespaces {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	return %{ $this->{cache}->{canonicalNamespaces} };
}

sub getCanonicalNamespace {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	my $ns   = shift;
	my $name = $this->{cache}{canonicalNamespaces}{$ns};
	die "Unknown namespace $ns\n" unless defined $name;
	return $name;
}

sub getPageNamespace {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	my $name = shift;
	return 0 unless $name =~ /^(.+?):/;
	my $ns = $this->{cache}{namespaceAliases}{ lc($1) };
	return $ns if defined $ns;
	return 0;
}

sub getInterwikiMap {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	if ( !$this->{realInterwikis} ) {
		my $wikiid = $this->getGeneralSiteInfo('wikiid');
		require MediaWiki::WmfInterwikis;
		return MediaWiki::WmfInterwikis::readInterwikis($wikiid);
	}

	return @{ $this->{cache}->{interwikiMap} };
}

sub getMagicWords {
	my $this = shift;
	$this->invalidateSiteInfoCache;

	my $arg = shift;

	if ( defined $arg ) {
		return $this->{cache}->{magicWords}->{$arg};
	}
	else {
		return %{ $this->{cache}->{magicWords} };
	}
}

# -----------------------------------------------------------
# Edit Api
# -----------------------------------------------------------

sub _enrichWithCsrfToken {
	my ( $this, $query ) = @_;

	return
	  if exists $query->{token};

	unless ( defined $this->{tokens}->{csrftoken} ) {

		# fetch token
		my $response = $this->query( 'meta' => 'tokens' );
		$this->{tokens}->{csrftoken} = $response->{query}->{tokens}->{csrftoken};
	}

	$query->{token} = $this->{tokens}->{csrftoken};
}

sub _invalidateCsrfToken {
	my ($this) = @_;
	delete $this->{tokens}->{csrftoken};
}

sub _doEditAction {
	my ( $this, $action, @query ) = @_;
	my $query = {@query};

	$query->{action} = $action;
	$this->_enrichWithCsrfToken($query);
	eval {
		# First query
		return $this->query( %{$query} );
	};
	if ( my $error = $@ ) {
		if ( defined $this->{error} and $this->{error}->{code} eq 'badtoken' ) {
			$this->_invalidateCsrfToken;
			delete $query->{token};
			$this->_enrichWithCsrfToken($query);
			return $this->query( %{$query} );
		}
		else {
			die $error;
		}
	}
}

sub edit {
	my $this = shift;
	$this->_doEditAction( 'edit', @_ );
}

sub move {
	my $this = shift;

	# FIXME: check the result
	# talkmove-error-code, talkmove-error-info, etc.
	$this->_doEditAction( 'move', @_ );
}

sub delete {
	my $this = shift;
	$this->_doEditAction( 'delete', @_ );
}

sub undelete {
	my $this = shift;
	$this->_doEditAction( 'undelete', @_ );
}

sub protect {
	my $this = shift;
	$this->_doEditAction( 'protect', @_ );
}

sub block {
	my $this = shift;
	$this->_doEditAction( 'block', @_ );
}

sub unblock {
	my $this = shift;
	$this->_doEditAction( 'unblock', @_ );
}

sub review {
	my $this = shift;
	$this->_doEditAction( 'review', @_ );
}

# -----------------------------------------------------------
# Return Iterator
# -----------------------------------------------------------

sub getIterator {
	my $this = shift;

	my $iterator = MediaWiki::API::Iterator->new( $this, @_ );
	return $iterator;
}

1;

# perltidy -et=8 -l=0 -i=8
