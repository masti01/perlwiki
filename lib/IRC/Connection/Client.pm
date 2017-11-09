package IRC::Connection::Client;
use strict;
use base 'IRC::Socket';
use IRC::Connection::User;
use IRC::Connection::Channel;

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = $class->SUPER::new(
		'realname' => 'IRC::Connection::Client',
		'username' => 'perl',
		@_
	);

	bless $this, $class;

	$this->registerHandler( '001',           \&m_welcome );
	$this->registerHandler( 'connected',     \&m_connected );
	$this->registerHandler( 'disconnected',  \&m_disconnected );
	$this->registerHandler( '005',           \&m_isupport );
	$this->registerHandler( '324',           \&m_324 );
	$this->registerHandler( '329',           \&m_329 );
	$this->registerHandler( '332',           \&m_332 );
	$this->registerHandler( '333',           \&m_333 );
	$this->registerHandler( '353',           \&m_353 );
	$this->registerHandler( '366',           \&m_366 );
	$this->registerHandler( 'JOIN',          \&m_join );
	$this->registerHandler( 'channel leave', \&e_channel_leave );
	$this->registerHandler( 'PART',          \&m_part );
	$this->registerHandler( 'NICK',          \&m_nick );
	$this->registerHandler( 'QUIT',          \&m_quit );
	$this->registerHandler( 'KICK',          \&m_kick );
	$this->registerHandler( 'TOPIC',         \&m_topic );
	$this->registerHandler( 'MODE',          \&m_mode );
	$this->registerHandler( 'PRIVMSG',       \&m_privmsg );
	$this->registerHandler( 'NOTICE',        \&m_privmsg );

	return $this;
}

sub connect {
	my $this = shift;

	if ( $this->connected ) {
		$this->disconnect;
	}

	$this->{channels} = {};
	$this->{users}    = {};
	$this->{isupport} = {};

	$this->{regexpStatusMsg} = undef;
	$this->{regexpNames}     = undef;
	$this->{prefixes}        = {};
	$this->{modeHandlers}    = undef;

	$this->{me} = undef;

	die "No nick specified\n" unless defined $this->{nick} and $this->{nick} ne '';
	return $this->SUPER::connect(@_);
}

sub getUser {
	my $this = shift;
	if (@_) {
		my $nick = shift;
		return undef
		  unless defined $nick;
		my $refinedNick = $this->refineNick($nick);
		$refinedNick =~ s/!.+$//;
		return $this->{users}->{$refinedNick};
	}
	else {
		return $this->{me};
	}
}

sub getUsers {
	my $this = shift;
	return values %{ $this->{users} };
}

sub getChannel {
	my $this        = shift;
	my $refinedName = $this->refineName(shift);
	return $this->{channels}->{$refinedName};
}

sub getChannels {
	my $this = shift;
	return values %{ $this->{channels} };
}

sub refineNick {
	return lc $_[1];
}

sub refineName {
	return lc $_[1];
}

sub parse($) {
	my $text = shift;
	$text = shift if ref($text) ne '';
	my @args;

	return unless defined $text;
	my $pos = 0;
	while ( $pos < length($text) ) {
		if ( substr( $text, $pos, 1 ) eq ':' ) {
			push @args, substr( $text, $pos + 1 );
			last;
		}
		my $newPos = index( $text, " ", $pos );
		if ( $newPos < $pos ) {
			push @args, substr( $text, $pos );
			last;
		}
		push @args, substr( $text, $pos, $newPos - $pos );
		$pos = $newPos + 1;
	}

	return @args;
}

sub _createUser {
	my $this   = shift;
	my $prefix = shift;

	my ( $nick, $ident, $host ) = $prefix =~ /^(.+?)(?:!(.+?)\@(.+?))?$/;
	my $refinedNick = $this->refineNick($nick);
	my $user        = $this->{users}->{$refinedNick};

	if ($user) {
		$user->{nick}  = $nick;
		$user->{ident} = $ident
		  if defined $ident;
		$user->{host} = $host
		  if defined $host;
	}
	else {
		$user = IRC::Connection::User->new(
			'nick'        => $nick,
			'ident'       => $ident,
			'host'        => $host,
			'refinedNick' => $refinedNick,
		);
		$this->{users}->{$refinedNick} = $user;
	}

	return $user;
}

sub _createChannel {
	my $this        = shift;
	my $name        = shift;
	my $refinedName = $this->refineName($name);

	my $channel = IRC::Connection::Channel->new(
		'name'        => $name,
		'refinedName' => $refinedName,
	);
	$this->{channels}->{$refinedName} = $channel;

	return $channel;
}

sub _register {
	my $this = shift;
	$this->send("PASS $this->{pass}") if defined $this->{pass} and $this->{pass} ne '';
	$this->send("NICK $this->{nick}");
	$this->send("USER $this->{username} * * :$this->{realname}");
}

# Event handlers

sub m_connected {
	my $this = shift;
	$this->_register;
}

sub m_disconnected {
	my $this = shift;

	foreach my $user ( $this->getUsers ) {
		$user->{channels} = undef;
	}
	foreach my $channel ( $this->getChannels ) {
		$channel->{users} = undef;
	}
	$this->{channels} = undef;
	$this->{users}    = undef;
	$this->{me}       = undef;
}

sub m_welcome {
	my ( $this, $data ) = @_;

	if ( $data->{content} =~ /^\S+ :Welcome to the (\S+) IRC Network (.+?!.+?\@.+?)$/ ) {
		$this->{isupport}->{NETWORK} = $1;
		$this->{me} = $this->_createUser($2);
	}
	elsif ( $data->{content} =~ /^(\S+)/ ) {
		$this->{me} = $this->_createUser($1);
	}
	else {
		die "Malformed 001\n";
	}

	$this->invokeHandler(
		'event' => 'user registered',
		'user'  => $this->{me},
	);
}

sub m_isupport {
	my ( $this, $data ) = @_;

	my $content = $data->{content};
	die "isupport regexp failed" unless $content =~ s/:are supported by this server$//;
	$content =~ s/^\S+ //;
	foreach my $item ( split ' ', $content ) {
		if ( $item =~ /^(.+?)=(.+)$/ ) {
			$this->{isupport}->{$1} = $2;
		}
		else {
			$this->{isupport}->{$item} = 1;
		}
	}
	if ( defined $this->{isupport}->{STATUSMSG}
		and !defined $this->{regexpStatusMsg} )
	{
		my $re = $this->{isupport}->{STATUSMSG};
		$re =~ s/(.)/\\$1/g;

		$this->{regexpStatusMsg} = qr/^([$re]?)(.+)$/;
	}

	if ( defined $this->{isupport}->{PREFIX}
		and !defined $this->{regexpNames} )
	{
		my ( $modes, $prefixes ) = $this->{isupport}->{PREFIX} =~ /^\((.+?)\)(.+)$/;
		my $re = $prefixes;
		$re =~ s/(.)/\\$1/g;

		$this->{regexpNames} = qr/^([$re]*)(.+)$/;

		@{ $this->{prefixes} }{ split '', $prefixes } = split '', $modes;
	}

	if (        defined $this->{isupport}->{PREFIX}
		and defined $this->{isupport}->{CHANMODES}
		and !defined $this->{modeHandlers} )
	{

		$this->{modeHandlers} = {};
		foreach my $privilege ( values %{ $this->{prefixes} } ) {
			$this->{modeHandlers}->{$privilege} = \&mode_handler_privilege;
		}

		my @handlers = ( \&mode_handler_list, \&mode_handler_arg1, \&mode_handler_arg01, \&mode_handler_switch );
		my @groups = split ',', $this->{isupport}->{CHANMODES};

		while ( scalar @groups and scalar @handlers ) {
			my @modes = split //, shift @groups;
			my $handler = shift @handlers;

			foreach my $mode (@modes) {
				$this->{modeHandlers}->{$mode} = $handler;
			}
		}
	}
}

# :<user> JOIN <channel>

sub m_join {
	my ( $this, $data ) = @_;

	my ( $target, undef ) = parse( $data->{content} );

	my $user = $this->_createUser( $data->{prefix} );
	my $channel;

	if ( $user == $this->{me} ) {
		$channel = $this->_createChannel($target);
	}
	else {
		$channel = $this->getChannel($target);
		die "$data->{prefix} joins non-existent channel $target\n" unless $channel;
	}

	my $channelData = {
		'user'    => $user,
		'channel' => $channel,
		'status'  => {},

		#'idleSince' => time(),
	};

	$user->{channels}->{$channel} = $channelData;
	$channel->{users}->{$user}    = $channelData;

	$this->invokeHandler(
		'event'   => 'channel join',
		'prefix'  => $data->{prefix},
		'user'    => $user,
		'target'  => $target,
		'channel' => $channel,
	);
}

# :<user> PART <channel>
# :<user> PART <channel> :<reason>

sub m_part {
	my ( $this, $data ) = @_;

	my ( $target, $reason, undef ) = parse( $data->{content} );
	my $user    = $this->getUser( $data->{prefix} );
	my $channel = $this->getChannel($target);

	$this->invokeHandler(
		'event'   => 'channel part',
		'prefix'  => $data->{prefix},
		'target'  => $target,
		'reason'  => $reason,
		'channel' => $channel,
		'user'    => $user,
	);

	return unless $channel;
	return unless $user;

	$this->invokeHandler(
		'event'   => 'channel leave',
		'user'    => $user,
		'channel' => $channel,
	);
}

# :<user> NICK <new-nick>

sub m_nick {
	my ( $this, $data ) = @_;

	my $user = $this->getUser( $data->{prefix} );

	my ( $newNick, undef ) = parse( $data->{content} );

	$this->invokeHandler(
		'event'   => 'user nick',
		'prefix'  => $data->{prefix},
		'newNick' => $newNick,
		'user'    => $user,
	);

	return unless $user;

	delete $this->{users}->{ $user->{refinedNick} };

	$user->{refinedNick} = $this->refineNick($newNick);
	$user->{nick}        = $newNick;

	$this->{users}->{ $user->{refinedNick} } = $user;
}

# :<user> QUIT :<reason>

sub m_quit {
	my ( $this, $data ) = @_;

	my ( $reason, undef ) = parse( $data->{content} );
	my $user = $this->getUser( $data->{prefix} );

	$this->invokeHandler(
		'event'  => 'user quit',
		'prefix' => $data->{prefix},
		'reason' => $reason,
		'user'   => $user,
	);

	return unless $user;

	foreach my $channelData ( $user->getChannels ) {
		$this->invokeHandler(
			'event'   => 'channel leave',
			'user'    => $user,
			'channel' => $channelData->{channel},
		);
	}
}

# :<user> KICK <channel> <victim> :<reason>

sub m_kick {
	my ( $this, $data ) = @_;
	my ( $target, $victim, $reason, undef ) = parse( $data->{content} );

	my $user       = $this->getUser( $data->{prefix} );
	my $channel    = $this->getChannel($target);
	my $victimUser = $this->getUser($victim);

	$this->invokeHandler(
		'event'      => 'channel kick',
		'prefix'     => $data->{prefix},
		'target'     => $target,
		'reason'     => $reason,
		'channel'    => $channel,
		'user'       => $user,
		'victim'     => $victim,
		'victimUser' => $victimUser,
	);

	return unless $channel;
	return unless $victimUser;

	$this->invokeHandler(
		'event'   => 'channel leave',
		'user'    => $victimUser,
		'channel' => $channel,
	);
}

# :<user> TOPIC <channel> :<content>

sub m_topic {
	my ( $this, $data ) = @_;
	my ( $target, $content, undef ) = parse( $data->{content} );

	my $user    = $this->getUser( $data->{prefix} );
	my $channel = $this->getChannel($target);

	$this->invokeHandler(
		'event'   => 'channel topic',
		'prefix'  => $data->{prefix},
		'user'    => $user,
		'target'  => $target,
		'channel' => $channel,
		'content' => $content,
	);

	next unless $channel;

	$channel->{topic}       = $content;
	$channel->{topicDate}   = time();
	$channel->{topicAuthor} = $data->{prefix};
}

# :<sender> MODE <target> <changes>

sub m_mode {
	my ( $this, $data ) = @_;
	my ( $target, $changes ) = $data->{content} =~ /^(\S+) :?(.*)$/;

	if ( my $channel = $this->getChannel($target) ) {
		my $user = $this->getUser( $data->{prefix} );

		$this->invokeHandler(
			'event'   => 'channel mode',
			'prefix'  => $data->{prefix},
			'user'    => $user,
			'target'  => $target,
			'channel' => $channel,
			'content' => $changes,
		);

		$this->parseChannelMode( $channel, $changes );
	}
	elsif ( my $user = $this->getUser($target) ) {

		$this->invokeHandler(
			'event'   => 'user mode',
			'prefix'  => $data->{prefix},
			'user'    => $user,
			'target'  => $target,
			'content' => $changes,
		);
	}
}

sub parseChannelMode {
	my ( $this, $channel, $line ) = @_;

	my ( $modes, @args ) = split ' ', $line;
	my $add = 1;

	foreach my $mode ( split //, $modes ) {
		$add = 1, next if $mode eq '+';
		$add = 0, next if $mode eq '-';

		my $handler = $this->{modeHandlers}->{$mode};
		die "Unknown mode character '$mode'\n"
		  unless defined $handler;

		&$handler( $this, $channel, $add, $mode, \@args );
	}
}

sub mode_handler_privilege {
	my ( $this, $channel, $add, $mode, $args ) = @_;

	my $arg        = shift @{$args};
	my $targetUser = $this->getUser($arg);
	return unless $targetUser;

	my $channelData = $targetUser->{channels}->{$channel};
	return unless $channelData;

	if ($add) {
		$channelData->{status}->{$mode} = 1;
	}
	else {
		delete $channelData->{status}->{$mode};
	}
}

sub mode_handler_list {
	my ( $this, $channel, $add, $mode, $args ) = @_;

	my $arg = shift @{$args};

}

sub mode_handler_arg1 {
	my ( $this, $channel, $add, $mode, $args ) = @_;

	my $arg = shift @{$args};

	if ($add) {
		$channel->{modes}->{$mode} = $arg;
	}
	else {
		delete $channel->{modes}->{$mode};
	}

}

sub mode_handler_arg01 {
	my ( $this, $channel, $add, $mode, $args ) = @_;

	if ($add) {
		my $arg = shift @{$args};
		$channel->{modes}->{$mode} = $arg;
	}
	else {
		delete $channel->{modes}->{$mode};
	}
}

sub mode_handler_switch {
	my ( $this, $channel, $add, $mode, $args ) = @_;

	my $state = $channel->{modes}->{$mode} || 0;
	return unless $add xor $state;

	if ($add) {
		$channel->{modes}->{$mode} = 1;
	}
	else {
		delete $channel->{modes}->{$mode};
	}
}

# :<server> 324 <nick> <channel> <modes>

sub m_324 {
	my ( $this, $data ) = @_;

	my ( undef, $target, $line ) = split ' ', $data->{content}, 3;
	my $channel = $this->getChannel($target);
	$this->parseChannelMode( $channel, $line )
	  if $channel;
}

# :<server> 329 <nick> <channel> <timestamp>

sub m_329 {
	my ( $this, $data ) = @_;

	my ( undef, $target, $timestamp ) = parse( $data->{content} );
	my $channel = $this->getChannel($target);
	$channel->{timestamp} = $timestamp
	  if $channel;
}

# :<sender> PRIVMSG <target> :<content>

sub m_privmsg {
	my ( $this,   $data )    = @_;
	my ( $target, $content ) = parse( $data->{content} );

	my $user = $this->getUser( $data->{prefix} );

	my %data = (
		'prefix'  => $data->{prefix},
		'content' => $content,
		'target'  => $target,
		'user'    => $user,
	);

	if ( defined $this->{regexpStatusMsg} and $target =~ $this->{regexpStatusMsg} ) {
		$data{status} = $1;
		$data{target} = $2;
	}

	if ( my $channel = $this->getChannel( $data{target} ) ) {
		$data{event}   = 'channel ' . lc( $data->{event} );
		$data{channel} = $channel;
	}
	else {
		$data{event} = 'user ' . lc( $data->{event} );
	}
	$this->invokeHandler(%data);
}

# :<server> 332 <nick> <channel> :<topic>

sub m_332 {
	my ( $this, $data ) = @_;

	my ( undef, $target, $topic ) = parse( $data->{content} );
	my $channel = $this->getChannel($target);
	$channel->{topic} = $topic
	  if $channel;
}

# :<server> 333 <nick> <channel> <author> <timestamp>

sub m_333 {
	my ( $this, $data ) = @_;

	my ( undef, $target, $author, $timestamp ) = parse( $data->{content} );
	my $channel = $this->getChannel($target);

	if ($channel) {
		$channel->{topicDate}   = $timestamp;
		$channel->{topicAuthor} = $author;
	}
}

# :<server> 353 <nick> <type> <channel> :<names>

sub m_353 {
	my ( $this, $data ) = @_;

	my ( undef, $type, $target, $names ) = parse( $data->{content} );

	my $channel = $this->getChannel($target);
	return unless $channel;

	push @{ $channel->{names} }, split ' ', $names;
}

# :<server> 366 <nick> <channel> :End of /NAMES list.

sub m_366 {
	my ( $this, $data ) = @_;

	my ( undef, $target, undef ) = parse( $data->{content} );
	my $channel = $this->getChannel($target);
	return unless $channel;

	die "No names regexp" unless defined $this->{regexpNames};

	my %oldusers = %{ $channel->{users} };
	$channel->{users} = {};

	foreach my $item ( @{ $channel->{names} } ) {
		my ( $prefix, $nick ) = $item =~ $this->{regexpNames};
		my $user = $this->_createUser($nick);

		my $channelData = $oldusers{$user};
		unless ($channelData) {
			$channelData = {
				'user'    => $user,
				'channel' => $channel,
				'status'  => {},
			};

			$user->{channels}->{$channel} = $channelData;
		}
		$channel->{users}->{$user} = $channelData;

		$channelData->{status} = {};
		$channelData->{status}->{ $this->{prefixes}->{$_} } = 1 foreach split '', $prefix;
	}
	delete $channel->{names};

	foreach my $channelData ( values %oldusers ) {
		next if exists $channel->{users}->{ $channelData->{user} };
		$this->_channelLeave( $channelData->{user}, $channel );
	}
}

sub _channelLeave {
	my ( $this, $user, $channel ) = @_;

	delete $channel->{users}->{$user};
	delete $user->{channels}->{$channel};

	return if $user == $this->{me};

	delete $this->{users}->{ $user->{refinedNick} }
	  unless scalar keys %{ $user->{channels} };
}

sub e_channel_leave {
	my ( $this, $data ) = @_;

	if ( $data->{user} == $this->{me} ) {
		delete $this->{channels}->{ $data->{channel}->{refinedName} };

		foreach my $channelData ( $data->{channel}->getUsers ) {
			$this->_channelLeave( $channelData->{user}, $data->{channel} );
		}

		$data->{channel}->{users} = undef;
	}
	else {
		$this->_channelLeave( $data->{user}, $data->{channel} );
	}
}

sub _targetName {
	my $this   = shift;
	my $target = shift;

	return $target if ref($target) eq '';
	return $target->getName();
}

# Methods

sub ctcp {
	my ( $this, $target, $message ) = @_;
	$this->privmsg( $target, "\x01$message\x01" );
}

sub action {
	my ( $this, $target, $message ) = @_;
	$this->ctcp( $target, "ACTION $message" );
}

sub ctcpreply {
	my ( $this, $target, $message ) = @_;
	$this->notice( $target, "\x01$message\x01" );
}

sub privmsg {
	my ( $this, $target, $message ) = @_;
	$target = $this->_targetName($target);
	$this->send("PRIVMSG $target :$message");
}

sub notice {
	my ( $this, $target, $message ) = @_;
	$target = $this->_targetName($target);
	$this->send("NOTICE $target :$message");
}

sub oper {
	my ( $this, $opernick, $operpass ) = @_;
	$this->send("OPER $opernick $operpass");
}

sub join {
	my $this = shift;
	local $" = ' ';
	$this->send("JOIN @_");
}

sub mode {
	my $this = shift;
	local $" = ' ';
	my @args;
	foreach my $arg (@_) {
		push @args, $this->_targetName($arg);
	}
	$this->send("MODE @args");
}

sub part {
	my $this   = shift;
	my $target = shift;
	my $reason = shift;

	$target = $this->_targetName($target);

	$this->send( "PART $target" . ( defined $reason ? " :$reason" : "" ) );
}

sub kick {
	my ( $this, $channel, $target, $reason ) = @_;

	$channel = $this->_targetName($channel);
	$target  = $this->_targetName($target);

	$this->send( "KICK $channel $target" . ( defined $reason ? " :$reason" : "" ) );
}

1;

# perltidy -et=8 -l=0 -i=8
