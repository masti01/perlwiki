package CachedLWP;

use strict;
use utf8;
use Log::Any;

our $AUTOLOAD;
our $VERSION = 20111211;

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'directory' => 'cache',
		'ua'        => undef,
		'namespace' => undef,
		'cache'     => undef,
		'writeOnly' => 0,
		'retention' => '1 week',
		@_
	};

	unless ( $this->{cache} ) {
		use CHI;

		$this->{cache} = CHI->new(
			driver    => 'File',
			root_dir  => $this->{directory},
			namespace => $this->{namespace},
		);
	}

	die "Undefined 'ua' parameter\n"
	  unless defined $this->{ua};

	bless $this, $class;
}

sub request {
	my $this    = shift;
	my $request = shift;

	my $response;
	unless ( $this->{writeOnly} ) {
		$response = $this->fetchFromCache($request);
	}
	unless ($response) {
		$response = $this->{ua}->request($request);
		$this->saveToCache($response);
	}
	return $response;
}

sub keyFromRequest {
	my $this    = shift;
	my $request = shift;

	return __PACKAGE__ . ":" . $request->method . ":" . $request->uri->as_string . ( $request->method eq 'POST' ? ":" . $request->content : '' );
}

sub fetchFromCache {
	my $this    = shift;
	my $request = shift;

	#return undef;

	return undef
	  unless defined $this->{cache};

	my $key      = $this->keyFromRequest($request);
	my $response = $this->{cache}->get($key);
	if ($response) {
		$logger->trace("Cache hit for '$key'");
	}
	else {
		$logger->trace("Cache miss for '$key'");
	}

	return $response;
}

sub saveToCache {
	my $this     = shift;
	my $response = shift;

	return 0
	  unless defined $this->{cache};

	return 0
	  if ref($response) eq '';

	return 0
	  unless $response->is_success;

	my $key = $this->keyFromRequest( $response->request );
	$logger->trace("Caching document as '$key'");
	$this->{cache}->set( $key, $response, $this->{retention} );
}

sub AUTOLOAD {
	my $this = shift;
	my $type = ref($this)
	  or die "$this is not an object\n";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;    # strip fully-qualified portion
	return if $name eq 'DESTROY';

	$this->{ua}->$name(@_);
}

1;
