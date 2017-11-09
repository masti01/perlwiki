#!/usr/bin/perl -w

use strict;
use utf8;
use Data::Dumper;
use IO::Handle;
use Bot4;
use Wiki::RcBot;
use Log::Any;
use AnyEvent::Impl::Perl;
use AnyEvent;
use lib "./rcbot";
use ClueBot;
use Notify;

my $logger = Log::Any->get_logger;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

$SIG{CHLD} = 'IGNORE';

# FIXME: okresowo ładuj ciastka !

my $client = new Wiki::RcBot(
	'nick'     => 'BeauBotRC',
	'realname' => '[[pl:User:Beau.Bot]]',
	'username' => 'beau',
	'projects' => [ '#pl.wikipedia', '#pl.wikisource', '#meta.wikimedia', '#pl.wiktionary', '#test.wikipedia' ],
);

sub spawn_task {
	my $pid = fork();
	return if $pid;
	die "fork() failed: $!" unless defined $pid;
	my $proc = shift;
	eval { &$proc(@_); };
	if ($@) {
		$logger->warn("Child process died: $@");
	}
	exit(0);

	#kill 'KILL', $$;
}

Notify::setup( $client, $bot );
ClueBot::setup( $client, $bot );

$client->loop;

# perltidy -et=8 -l=0 -i=8
