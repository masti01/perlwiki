#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Text::Diff;

my $reason = "naprawa linków";
my $sleep  = 10;

my $bot = new Bot4;
$bot->addOption( "reason|summary=s", \$reason, "Edit summary" );
$bot->addOption( "sleep=i",          \$sleep,  "Edit interval" );
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any->get_logger;

my $api = $bot->getApi;
$api->checkAccount;

utf8::decode($reason);

my %rename;
my %backlinks;
my @queue;

sub linkfix {
	my $link    = shift;
	my $caption = shift;

	my $newLink = $link;
	$newLink =~ tr/_/ /;
	my $newCaption = $caption;

	my $anchor;

	( $newLink, $anchor ) = split( '#', $newLink, 2 );
	$newCaption ||= $newLink unless defined $anchor;    # UWAGA, to nie zawsze jest pożądane

	if ( exists $rename{ ucfirst($newLink) } ) {
		$newLink = $rename{ ucfirst($newLink) };
	}
	else {
		return "[[$link|$caption]]" if defined $caption;
		return "[[$link]]";
	}

	$newLink .= '#' . $anchor if defined $anchor;

	if ( defined $newCaption and $newLink eq $newCaption ) {
		$newCaption = undef;
	}

	if ( defined $newCaption ) {
		return "[[$newLink|$newCaption]]";
	}
	else {
		return "[[$newLink]]";
	}
}

sub replace {
	my $page = shift;

	if ( exists $page->{redirect} ) {

		#$logger->info("Strona [[$page->{title}]] jest przekierowaniem");
		return;
	}

	my ($revision) = values %{ $page->{revisions} };
	my $newcontent = $revision->{'*'};

	$newcontent =~ s/\[\[([^\[|]+)\]\]/ $_ = linkfix($1) /ge;
	$newcontent =~ s/\[\[([^\[|]+)\|([^\[|]+)\]\]/ $_ = linkfix($1, $2) /ge;

	#return if $revision->{'*'} =~ /dane tekstu/i;
	if ( $revision->{'*'} eq $newcontent ) {
		$logger->info("Strona [[$page->{title}]], brak zmian");
		return;

	}
	$logger->info("Strona [[$page->{title}]], wykonane zmiany");
	print diff( \$revision->{'*'}, \$newcontent );
	print "\n";

	my $ans = <STDIN>;
	if ( $ans =~ /^[TY]/i ) {
		$logger->info("Strona [[$page->{title}]], zapisywanie zmian");
		$api->edit(
			'title'          => $page->{title},
			'starttimestamp' => $page->{touched},
			'basetimestamp'  => $revision->{timestamp},
			'text'           => $newcontent,
			'bot'            => 1,
			'summary'        => $reason,
			'minor'          => 1,
		);

	}

}

sub processQueue {
	my @titles = splice( @queue, 0, 50 );

	my $response = $api->query(
		'titles' => join( "|", @titles ),
		'prop'   => 'revisions|info',
		'rvprop' => 'content|timestamp',
		'maxlag' => 20,
	);

	foreach my $page ( values %{ $response->{query}->{pages} } ) {
		replace($page);
	}
}

while (<>) {
	utf8::decode($_);
	s/\s+$//g;
	next if $_ eq '';
	tr/_/ /;

	my ( $oldtitle, $newtitle ) = /\[\[(.+?)\]\] -> \[\[(.+?)\]\]/;
	$oldtitle = ucfirst($oldtitle);
	$newtitle = ucfirst($newtitle);

	die if $oldtitle eq $newtitle;

	$rename{$oldtitle} = $newtitle;

	print "OLD: $oldtitle\n";
	print "NEW: $newtitle\n";
}

foreach my $oldtitle ( keys %rename ) {
	my $iterator = $api->getIterator(
		'list'    => 'backlinks',
		'bltitle' => $oldtitle,
		'bllimit' => 'max',
	);

	while ( my $link = $iterator->next ) {

		#next if $link->{ns} != 0 and $link->{ns} != NS_TEMPLATE;
		unless ( $backlinks{ $link->{title} } ) {
			push @queue, $link->{title};
		}
		$backlinks{ $link->{title} }++;
	}
	processQueue if @queue > 50;
}

while (@queue) {
	processQueue;
}
