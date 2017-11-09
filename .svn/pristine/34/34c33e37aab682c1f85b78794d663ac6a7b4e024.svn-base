#!/usr/bin/perl -w

use strict;
use Bot4;
use Term::ReadKey;

my $url;
my $login;
my $wmf;

my $bot = new Bot4;
$bot->addOption( "login|l=s", \$login, "The user name" );
$bot->addOption( "url=s",     \$url,   "A URL to API" );
$bot->addOption( "wmf",       \$wmf,   "The user is logging to wmf sites" );
$bot->setup;

my $api;

if ( defined $url ) {
	$api = $bot->getApiByUrl( $url, $bot->{tag} );
}
elsif ( defined $bot->{family} ) {
	$api = $bot->getApi;
}
elsif ( !$wmf ) {
	die "You need to specify either family and language or url\n";
}

unless ( defined $login ) {
	print "Enter login: ";
	$login = <STDIN>;
	chop $login;
}

print "Enter password: ";
ReadMode( "noecho", *STDIN );
my $pass = <STDIN>;
ReadMode( "original", *STDIN );

print "\n";
chop $pass;

if ($wmf) {
	die "Login failed\n"
	  unless $bot->loginWmf( $login, $pass, $bot->{tag} );
}
else {
	die "Login failed\n"
	  unless $api->login( $login, $pass );

	$api->checkAccount;
}

$bot->saveCookies;

# perltidy -et=8 -l=0 -i=8
