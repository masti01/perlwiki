package MediaWiki::WWW;
require Exporter;

use strict;
use utf8;
use WWW::Mechanize;
use Data::Dumper;
use URI::Escape;

our @ISA       = qw(Exporter);
our @EXPORT    = qw();
our @EXPORT_OK = qw();
our $VERSION   = 20090911;

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'url'      => 'http://pl.wikipedia.org/w/index.php',
		'login'    => '',
		'password' => '',
		'assert'   => 'user',
		'nassert'  => '',
		@_
	};

	$this->{ua} = WWW::Mechanize->new( 'agent' => "MediaWiki::WWW $VERSION" );
	bless $this, $class;
	return $this;
}

sub login {
	my ( $this, $login, $password ) = @_;

	$this->{login}    = $login    if defined $login;
	$this->{password} = $password if defined $password;

	eval {
		$this->_get( 'title' => 'Special:UserLogin' );
		$this->{ua}->submit_form(
			form_name => 'userlogin',
			fields    => {
				'wpName'     => $this->{login},
				'wpPassword' => $this->{password},

			},
			button => 'wpLoginattempt',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub _get {
	my $this = shift;
	my %args = (@_);

	if ( defined $this->{assert} and $this->{assert} ne "" ) {
		$args{assert} = $this->{assert};
	}
	if ( defined $this->{nassert} and $this->{nassert} ne "" ) {
		$args{nassert} = $this->{nassert};
	}

	my $args = "";
	foreach my $key ( keys %args ) {
		my $value = $args{$key};
		utf8::encode($value) if utf8::is_utf8 $value;
		$value = uri_escape($value);
		utf8::encode($key) if utf8::is_utf8 $key;
		$key = uri_escape($key);
		$args .= "&$key=$value";
	}

	$args =~ s/^&/?/;
	my $response = $this->{ua}->get( $this->{url} . $args );
	die $response->{status_line} unless $response->is_success;
	return $response;
}

sub _prepare_request {
	my $this = shift;
	my @args;
	while (@_) {
		my $data = shift;
		utf8::encode($data) if utf8::is_utf8 $data;
		push @args, $data;
	}
	my %args = @args;
	if ( defined $this->{assert} and $this->{assert} ne "" ) {
		$args{assert} = $this->{assert};
	}
	if ( defined $this->{nassert} and $this->{nassert} ne "" ) {
		$args{nassert} = $this->{nassert};
	}
	return %args;
}

sub _post {
	my $this = shift;
	my $url  = shift;
	$url = $this->{url} unless defined $url;
	my %args = $this->_prepare_request(@_);

	my $response = $this->{ua}->post( $url, \%args );
	die $response->{status_line} unless $response->is_success;
	return $response;
}

sub _form {
	my $this = shift;
	my $name = shift;
	my $form = $this->{ua}->form_name($name);
	die "No form named $form\n" unless $form;
	return $form;
}

sub _error {
	my ( $this, $error ) = @_;
	$this->{error} = $error;
	die $error;
}

sub delete {
	my ( $this, $title, $reason ) = _encode(@_);

	die "delete: title is missing\n" unless defined $title;
	$reason = "" unless defined $reason;

	eval {
		$this->_get(
			action => "delete",
			title  => $title,
		);
		$this->{ua}->submit_form(
			form_number => 0,
			fields      => { wpReason => $reason },
			button      => 'wpConfirmB',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub undelete {
	my ( $this, $title, $reason ) = _encode(@_);

	die "delete: title is missing\n" unless defined $title;
	$reason = "" unless defined $reason;

	eval {
		$this->_get(
			target => $title,
			title  => 'Special:Undelete',
		);
		$this->{ua}->submit_form(
			form_number => 0,
			fields      => { 'wpComment' => $reason },
			button      => 'restore',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}
my %edit_request = (
	'section' => 'wpSection',
	'text'    => 'wpTextbox1',
	'content' => 'wpTextbox1',
	'summary' => 'wpSummary',
	'minor'   => 'wpMinoredit',
	'watch'   => 'wpWatchthis',
	'token'   => 'wpEditToken',
);

sub edit2 {
	my $this    = shift;
	my %request = _encode(@_);
	%request = _rename_keys( \%request, \%edit_request );

	eval {

		# unless (exists $request{wpEditToken}){
		# 	warn "no token, fetching";
		# 	$this->_get(
		# 		action => "edit",
		# 		title => $request{title},
		# 	);
		#
		# 	$request{'wpEditToken'} = $this->{ua}->value('wpEditToken');
		# }
		unless ( exists $request{wpEditToken} ) {
			die "no token";
		}

		if ( exists $request{wpEdittime} ) {
			$request{wpEdittime} =~ s/\D//g;
			$request{wpStarttime} = $request{wpEdittime}
			  unless exists $request{wpStarttime};
		}

		$request{action} = 'edit';
		$this->_post( undef, %request );
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub edit_begin {
	my ( $this, $title ) = _encode(@_);
	die "edit: title is missing\n" unless defined $title;

	my $text = undef;
	eval {
		$this->_get(
			action => "edit",
			title  => $title,
		);
		$this->{ua}->form_name('editform');
		$text = $this->{ua}->value('wpTextbox1');
		utf8::decode($text);
	};
	if ($@) {
		$this->_error($@);
	}
	return $text;
}

sub edit_finish {
	my ( $this, $text, $summary ) = _encode(@_);
	$summary = "" unless defined $summary;
	$text    = "" unless defined $text;

	eval {
		$this->{ua}->submit_form(
			form_name => 'editform',
			fields    => {
				'wpTextbox1' => $text,
				'wpSummary'  => $summary,

			},
			button => 'wpSave',
		);

	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub edit {
	my ( $this, $title, $text, $summary ) = _encode(@_);
	die "edit: title is missing\n" unless defined $title;
	$summary = "" unless defined $summary;
	$text    = "" unless defined $text;

	eval {
		$this->_get(
			action => "edit",
			title  => $title,
		);

		$this->{ua}->submit_form(
			form_name => 'editform',
			fields    => {
				'wpTextbox1' => $text,
				'wpSummary'  => $summary,

			},
			button => 'wpSave',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub addsection {
	my ( $this, $title, $text, $summary ) = _encode(@_);

	die "edit: title is missing\n" unless defined $title;
	$summary = "" unless defined $summary;
	$text    = "" unless defined $text;

	eval {
		$this->_get(
			action  => "edit",
			title   => $title,
			section => "new",
		);
		$this->{ua}->submit_form(
			form_name => 'editform',
			fields    => {
				'wpTextbox1' => $text,
				'wpSummary'  => $summary,

			},
			button => 'wpSave',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub protect {
	my ( $this, $title, $expiry, $reason, %levels ) = _encode(@_);

	die "protect: title is missing\n" unless defined $title;
	$reason = '' unless defined $reason;
	$expiry = '' unless defined $expiry;

	my %fields;
	foreach my $name ( keys %levels ) {
		$fields{"mwProtect-level-$name"} = $levels{$name};
	}

	eval {
		$this->_get(
			action => "protect",
			title  => $title,
		);
		$this->{ua}->submit_form(
			form_number => 0,
			fields      => {
				%fields,
				'mwProtect-reason' => $reason,
				'mwProtect-expiry' => $expiry,
			},
			button => '',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub move {
	my ( $this, $oldtitle, $newtitle, $reason ) = _encode(@_);
	die "move: title is missing\n" unless defined $oldtitle;
	die "move: title is missing\n" unless defined $newtitle;
	$reason = '' unless defined $reason;

	eval {
		$this->_get(
			action => "protect",
			title  => "Special:MovePage/$oldtitle",
		);
		$this->{ua}->submit_form(
			form_number => 0,
			fields      => {
				'wpNewTitle' => $newtitle,
				'wpReason'   => $reason,
			},
			button => '',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub block {
	my ( $this, $address, $expiry, $reason ) = _encode(@_);
	die "block: address is missing\n" unless defined $address;
	$reason = '' unless defined $reason;
	$expiry = '' unless defined $expiry;

	eval {
		$this->_get(
			ip    => $address,
			title => "Special:Blockip",
		);
		$this->{ua}->submit_form(
			form_number => 0,

			#form_name => 'blockip',
			fields => {
				'wpBlockAddress' => $address,
				'wpBlockReason'  => $reason,
				'wpBlockExpiry'  => $expiry,
			},
			button => '',
		);
	};
	if ($@) {
		$this->_error($@);
		return 0;
	}
	return 1;
}

sub _rename_keys(\%\%) {
	my ( $data, $keys ) = @_;
	my %result;

	foreach my $key ( keys %{$data} ) {
		my $value = $data->{$key};
		if ( exists $keys->{$key} ) {
			$key = $keys->{$key};
		}
		$result{$key} = $value;
	}
	return %result;
}

sub _encode {
	my @result;
	while (@_) {
		my $text = shift;
		if ( ref($text) eq '' ) {
			utf8::encode($text) if utf8::is_utf8($text);
		}
		push @result, $text;
	}
	return @result;
}

1;

# perltidy -et=8 -l=0 -i=8
