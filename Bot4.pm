package Bot4;
require Exporter;

use strict;
use warnings;
use utf8;

use POSIX qw(setsid);
use MediaWiki::API;
use MediaWiki::Utils qw(to_wiki_timestamp from_wiki_timestamp isAnonymous);
use IO::Handle;
use Storable qw(lock_nstore lock_retrieve);
use Env;
use HTTP::Cookies;
use Log::Any;
use Log::Any::Adapter;
use File::Spec;
use File::Path;
use Getopt::Long;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(to_wiki_timestamp from_wiki_timestamp writeFile readFile NS_MEDIA NS_SPECIAL NS_MAIN NS_TALK NS_USER NS_USERTALK NS_PROJECT NS_PROJECTTALK NS_FILE NS_FILETALK NS_MEDIAWIKI NS_MEDIAWIKITALK NS_TEMPLATE NS_TEMPLATETALK NS_HELP NS_HELPTALK NS_CATEGORY NS_CATEGORYTALK);
our @EXPORT_OK = qw();
our $VERSION   = 20150417;

my $logger = Log::Any->get_logger();
my %wmfProjects = map { $_ => 1 } qw(wikipedia wiktionary wikibooks wikinews wikiquote wikisource wikiversity wikimedia mediawiki);

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'family'       => undef,
		'language'     => undef,
		'tag'          => 'default',
		'cache'        => 0,
		'refreshCache' => 0,
		'daemon'       => 0,
		'single'       => 0,
		'options'      => [],
		'paths'        => {},
	};

	# WARNING: This may cause memory leaks if many projects is used.
	$this->{apis}       = {};
	$this->{cookieJars} = {};

	bless $this, $class;

	$this->addOption( "family=s",        \$this->{family},       "Default family of projects bot operates on" );
	$this->addOption( "lang|language=s", \$this->{language},     "The language bot operates on" );
	$this->addOption( "tag=s",           \$this->{tag},          "Alternative account bot operates on" );
	$this->addOption( "cache",           \$this->{cache},        "Use cache for all page requests" );
	$this->addOption( "refresh-cache",   \$this->{refreshCache}, "Use cache only for storing all page requests" );

	$this->addOption( "daemon", \$this->{daemon}, "Daemonize" );
	$this->addOption( "help", sub { $this->printHelp; exit(0); }, "Prints this message" );

	return $this;
}

sub setup {
	my ( $this, %args ) = @_;

	my $exe = defined $args{exe} ? $args{exe} : $0;

	# Set up paths used by the framework
	$this->{paths}{script} = File::Spec->rel2abs($exe);
	( my $volume, my $path, my $name ) = File::Spec->splitpath( $this->{paths}{script} );
	$name =~ s/\..+?$//;
	$this->{paths}{bin} = File::Spec->catdir( $volume, $path );

	my $root = defined $args{root} ? $args{root} : $this->{paths}{bin};
	$this->{paths}{var} = File::Spec->catdir( $root, 'var' );
	$this->{paths}{logs} = File::Spec->catdir( $this->{paths}{var}, 'log' );
	$this->{paths}{pid} = File::Spec->join( $this->{paths}{var},  'run', "$name.pid" );
	$this->{paths}{log} = File::Spec->join( $this->{paths}{logs}, "$name.log" );
	$this->{paths}{tmp} = File::Spec->tmpdir;

	$this->{name} = $name;

	$this->setupOutput;
	$this->processCommandLine;

	# Send all logs to Log::Log4perl
	use Log::Log4perl;
	Log::Log4perl->init( File::Spec->join( $root, 'log4perl.conf' ) );
	Log::Any::Adapter->set('Log4perl');

	$SIG{'__WARN__'} = sub { $this->handleWarn(@_) };
	$SIG{'__DIE__'}  = sub { $this->handleDie(@_) };
	$SIG{'HUP'}      = sub { $this->handleHup(@_) };

	chdir( $this->{paths}{bin} ) or die $!;

	$this->{daemon} ||= $ENV{DAEMON};
	if ( $this->{daemon} ) {
		fork() and exit(0);
		setsid();
		$this->openLogs();
	}

	# Checks if instance of the script is already running
	if ( $this->{single} ) {
		require Proc::Single;

		$this->{singleton} = new Proc::Single( $this->{paths}{pid} );
		exit(0) unless $this->{singleton};
	}

	# Just to be safe
	chmod( 0700, $this->{paths}{var} );
}

################################################################################

sub processCommandLine {
	my $this = shift;

	my @options;
	foreach my $option ( @{ $this->{options} } ) {
		push @options, $option->{name}, $option->{value};
	}
	GetOptions(@options);
}

sub addOption {
	my $this = shift;
	my %option;
	@option{ 'name', 'value', 'description' } = @_;
	push @{ $this->{options} }, \%option;
}

sub printHelp {
	my $this = shift;

	print "HELP:\n";
	foreach my $option ( @{ $this->{options} } ) {
		my $description = $option->{description} || '';
		print "  --$option->{name} \t $description\n";
	}
}

################################################################################

sub daemon : lvalue {
	my $this = shift;
	$this->{daemon} = $_[0] if @_;
	$this->{daemon};
}

sub single : lvalue {
	my $this = shift;
	$this->{single} = $_[0] if @_;
	$this->{single};
}

################################################################################

sub handleWarn {
	my $this = shift;
	my $msg  = $_[0];

	# Silences the bug in LWP::UserAgent
	return if index( $msg, 'Parsing of undecoded UTF-8 will give garbage' ) >= 0;
	$msg =~ s/\n$//;

	#cluck($msg);
	$logger->warn($msg);
}

sub handleDie {
	my $this = shift;
	return if $^S;    # die() is called from eval()

	my $msg = $_[0];
	$msg =~ s/\n$//;
	$SIG{'__DIE__'} = 'DEFAULT';

	#cluck($msg);
	$logger->fatal($msg);
	exit(1);
}

sub handleHup {
	my $this = shift;
	$logger->info("Received HUP signal");

	if ( $this->{daemon} ) {
		$this->openLogs();
	}

	$this->loadCookies();
}

sub openLogs {
	my $this = shift;
	open( STDERR, '>>', $this->{paths}{log} ) or die $!;
	open( STDOUT, '>>', $this->{paths}{log} ) or die $!;
	$this->setupOutput;
}

sub setupOutput {
	binmode( STDOUT, ':utf8' );
	binmode( STDERR, ':utf8' );

	STDOUT->autoflush(1);
	STDERR->autoflush(1);
}

################################################################################

sub retrieveData {
	my $this = shift;
	my $name = shift;
	$name ||= "$this->{name}.dat";
	$name = File::Spec->join( $this->{paths}{var}, $name );
	return undef unless -e $name;
	return lock_retrieve($name);
}

sub storeData($) {
	my $this = shift;
	my $data = shift;
	my $name = shift;
	$name ||= "$this->{name}.dat";
	$name = File::Spec->join( $this->{paths}{var}, $name );
	lock_nstore( $data, "$name~" );
	rename "$name~", "$name";
}

sub readFile($) {
	my $name = shift;

	die "Cannot open $name: $!"
	  unless open( IN, '<', $name );

	local $/;
	my $data = <IN>;
	close(IN);
	return $data;
}

sub writeFile($$) {
	my ( $name, $content ) = @_;
	die "Cannot open $name: $!"
	  unless open( OUT, '>', $name );

	utf8::encode($content) if utf8::is_utf8 $content;

	die "Cannot write: $!"
	  unless print OUT $content;

	die "Error closing $name: $!"
	  unless close(OUT);
}

sub status($) {
	my ( $this, $text ) = @_;
	utf8::encode($text) if utf8::is_utf8 $text;
	$0 = "$this->{name}: $text";
}

################################################################################

sub setProject {
	my $this = shift;

	my $family   = shift;
	my $language = shift;
	my $tag      = shift;

	$this->{family}   = $family   if defined $family;
	$this->{language} = $language if defined $language;
	$this->{tag}      = $tag      if defined $tag;
}

sub getApi($$;$) {
	my $this = shift;

	my $family   = shift;
	my $language = shift;
	my $tag      = shift;

	$family   ||= $this->{family};
	$language ||= $this->{language};
	$tag      ||= $this->{tag};

	die "Wiki family is not defined\n"
	  unless defined $family;

	if ( exists $wmfProjects{$family} ) {
		my $url;

		if ( $family eq 'mediawiki' ) {
			$language = 'www';
		}
		elsif ( $family eq 'wikisource' and !defined $language ) {
			$url = "https://wikisource.org/w/api.php";
		}
		elsif ( !defined $language ) {
			$language = 'en';
		}

		$url = "https://$language.$family.org/w/api.php"
		  unless defined $url;

		if ( exists $this->{apis}{$url}{$tag} ) {
			return $this->{apis}{$url}{$tag};
		}
		else {
			my $api = MediaWiki::API->new(
				'url'       => $url,
				'cookieJar' => $this->getCookieJar( File::Spec->join( $this->{paths}{var}, "cookies-wmf-$tag.txt" ) ),
			);
			$this->{apis}{$url}{$tag} = $api;
			$api->agent( $api->agent() . ", mastigm\@gmail.com, w:pl:User:masti" );
			$this->configureCaching( $api, "$language.$family" );
			return $api;
		}
	}
	elsif ( $family eq 'testwiki' ) {
		return $this->getApiByUrl( "http://tools.wikimedia.pl/testwiki/w/api.php", $tag );
	}
	elsif ( $family eq 'translatewiki' ) {
		return $this->getApiByUrl( "http://translatewiki.net/w/api.php", $tag );
	}
	else {
		die "Unknown family: $family\n";
	}
}

sub getApiByUrl($$;$) {
	my $this = shift;
	my $url  = shift;
	my $tag  = shift;

	$tag ||= 'default';
	if ( exists $this->{apis}{$url}{$tag} ) {
		return $this->{apis}{$url}{$tag};
	}
	else {
		my $path = $url;
		$path =~ s/([^A-Za-z0-9_-])/ sprintf("%%%02x", ord($1)) /ge;

		my $api = MediaWiki::API->new(
			'url'       => $url,
			'cookieJar' => $this->getCookieJar( File::Spec->join( $this->{paths}{var}, "cookies-$path-$tag.txt" ) ),
		);
		$this->configureCaching( $api, $url );
		$this->{apis}{$url}{$tag} = $api;
		return $api;
	}
}

sub configureCaching {
	my $this      = shift;
	my $api       = shift;
	my $namespace = shift;

	if ( $this->{cache} or $this->{refreshCache} ) {
		require CachedLWP;

		my $wrapper = new CachedLWP(    #
			ua        => $api->{ua},
			directory => File::Spec->catdir( $this->{paths}{var}, 'cache' ),
			writeOnly => $this->{refreshCache},
			namespace => $namespace,
		);
		$api->{ua} = $wrapper;
	}
}

sub getCookieJar {
	my $this = shift;
	my $file = shift;
	if ( exists $this->{cookieJars}{$file} ) {
		return $this->{cookieJars}{$file};
	}
	else {
		my $jar = HTTP::Cookies->new(
			'file'     => $file,
			'autosave' => 0,
		);
		$this->{cookieJars}{$file} = $jar;
		return $jar;
	}
}

sub loadCookies {
	my $this = shift;
	foreach my $jar ( values %{ $this->{cookieJars} } ) {
		$jar->load;
	}
}

sub saveCookies {
	my $this = shift;
	foreach my $jar ( values %{ $this->{cookieJars} } ) {
		$jar->save;
	}
}

sub loginWmf {
	my $this     = shift;
	my $login    = shift;
	my $password = shift;
	my $tag      = shift;

	my $api = $this->getApi( "wikipedia", "pl", $tag );
	my $jar = $api->{cookieJar};
	$jar->clear;

	# Login
	my $response = $api->login( $login, $password );
	my @centralAuth;
	$jar->scan(
		sub {
			return unless $_[1] =~ /^centralauth_/;
			push @centralAuth, [@_];
		}
	);
	my @domains = (
		'.wikipedia.org',   '.wiktionary.org', '.wikibooks.org',     #
		'.wikinews.org',    '.wikiquote.org',  '.wikisource.org',    #
		'.wikiversity.org', '.wikimedia.org',  '.mediawiki.org',     #
	);
	$jar->clear;
	foreach my $domain (@domains) {
		foreach my $cookie (@centralAuth) {
			$cookie->[4] = $domain;
			$jar->set_cookie( @{$cookie} );
		}
	}
	$api->checkAccount;

	return $response;
}

################################################################################

sub MediaWiki::API::sendMessage {
	my ( $api, $user, $title, $message ) = @_;
	my $data = $api->query(
		'titles' => "User talk:$user",
		'prop'   => "info",
	);
	my ($page) = values %{ $data->{query}->{pages} };

	if ( exists $page->{redirect} ) {
		$logger->info("Wiadomość nie zostaje wysłana do $user, ponieważ zamiast strony dyskusji ma przekierowanie");
		return;
	}

	if ( exists $page->{missing} and !isAnonymous($user) ) {
		$message = "{{witaj|masti}}'''[[Wikipedysta:msati|msati]]''' ([[Dyskusja wikipedysty:masti|dyskusja]]) ~~~~~\n== $title ==\n$message";
		$api->edit(
			'title'          => "User talk:$user",
			'text'           => $message,
			'bot'            => 1,
			'summary'        => $title,
			'notminor'       => 1,
			'createonly'     => 1,
		);
	}
	else {
		$logger->debugf("Sending message to $user, page props %s", $page);
		$api->edit(
			'title'          => "User talk:$user",
			'text'           => $message,
			'bot'            => 1,
			'starttimestamp' => $page->{touched},
			'section'        => 'new',
			'summary'        => $title,
			'notminor'       => 1,
		);
	}
}

1;

# perltidy -et=8 -l=0 -i=8
