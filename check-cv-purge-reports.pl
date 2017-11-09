#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Text::Diff;

my $pretend = 0;
my $title   = 'Project:Lista NPA';

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->addOption( "title|t=s" => \$title,   "Title of report page" );
$bot->single(1);
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $api = $bot->getApi();
$api->checkAccount;

my $response = $api->query(
	'titles'  => $title,
	'prop'    => 'revisions|info',
	'rvlimit' => 1,
	'rvdir'   => 'older',
	'rvprop'  => 'content|timestamp',
	'maxlag'  => 20,
);

my ($page)     = values %{ $response->{query}->{pages} };
my ($revision) = values %{ $page->{revisions} };

my %missing;

my $iterator = $api->getIterator(
	'titles'       => $title,
	'generator'    => 'links',
	'prop'         => 'info',
	'gplnamespace' => 0,
	'gpllimit'     => 100,
	'maxlag'       => 20,
);

while ( my $item = $iterator->next ) {
	next unless exists $item->{missing};
	$missing{ $item->{title} }++;
}

my $content = $revision->{'*'};

my $re = qr/(?<=<!-- Beau.bot wstawia tutaj -->)(.*?)(?=\n==[^=])/s;

$content =~ m/$re/
  or die "Nie znaleziono znacznika w kodzie strony\n";

my $text = $1;
my @sections;

foreach my $section ( split m/^(?==)/m, $text ) {
	my ($pageTitle) = $section =~ /^===\s*\[\[([^\[\]\n]+?)\]\]\s*===/;
	if ( $section =~ /Beau\.bot/ and defined $pageTitle and exists $missing{$pageTitle} ) {
		$logger->info("$pageTitle została skasowana, sekcja zostanie usunięta");
		next;
	}
	push @sections, $section;
}

$text = join( '', @sections );
$content =~ s/$re/$text/;

if ( $content eq $revision->{'*'} ) {
	$logger->info("Nic do roboty");
	exit(0);
}

$logger->info( "Zmiany, które zostaną wprowadzone:\n" . diff( \$revision->{'*'}, \$content ) );

exit(0) if $pretend;

$api->edit(
	'title'          => $page->{title},
	'starttimestamp' => $page->{touched},
	'basetimestamp'  => $revision->{timestamp},
	'text'           => $content,
	'bot'            => 1,
	'summary'        => "usunięcie własnych zgłoszeń",
	'notminor'       => 1,
);
