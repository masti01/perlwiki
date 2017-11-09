#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;

my $logger = Log::Any->get_logger;

my $bot = new Bot4;
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

sub seen($) {
	my %query = (
		'action'  => 'query',
		'list'    => 'usercontribs',
		'ucuser'  => $_[0],
		'uclimit' => 1,
	);
	my $data     = $api->query(%query);
	my @contribs = values %{ $data->{query}->{usercontribs} };
	return $contribs[0]->{timestamp};
}

sub bots() {
	my %query = (
		'action'  => 'query',
		'list'    => 'allusers',
		'augroup' => 'bot',
		'aulimit' => 'max',
		'auprop'  => 'editcount',
	);
	my $data = $api->query(%query);
	return values %{ $data->{query}->{allusers} };
}

$logger->info("Pobieranie listy botów");
$bot->status("Pobieranie listy botów");

my @bots = bots();

@bots = sort { $a->{name} cmp $b->{name} } @bots;

foreach my $bot (@bots) {

	print "Sprawdzam $bot->{name}... ";
	eval {
		$bot->{seen} = seen( $bot->{name} );
		$bot->{seen} ||= '';
		print "$bot->{seen}\n";
	};
	if ($@) {
		print "błąd\n";
		$bot->{seen} = 'fail';
		$logger->warn($@);
	}
}

my $text = << 'EOF';
Ostatnia aktualizacja: '''~~~~~'''

{| class="wikitable sortable"
! login
! ostatnia edycja
! liczba edycji
|-
EOF

foreach my $bot (@bots) {
	$text .= << "EOF";
| {{użytkownik|$bot->{name}}}
| $bot->{seen}
| $bot->{editcount}
|-
EOF
}

$text .= "|}\n";

$logger->info("Zapis listy");

$api->edit(
	'title'   => 'User:mastiBot/listy/boty',
	'text'    => $text,
	'bot'     => 1,
	'summary' => 'aktualizacja listy',
);

# perltidy -et=8 -l=0 -i=8
