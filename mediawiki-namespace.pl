#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;

my $logger = Log::Any->get_logger;

my $bot = new Bot4;
$bot->setup;

my $plApi = $bot->getApi( "wikipedia", "pl" );
my $enApi = $bot->getApi( "wikipedia", "en" );

sub fetchList($) {
	my $api = shift;

	my $next = '';
	my @result;

	my $iterator = $api->getIterator(
		'list'        => 'allpages',
		'apnamespace' => 8,
		'aplimit'     => 'max',
	);

	while ( my $item = $iterator->next ) {
		push @result, $item->{title};
	}

	return @result;
}

sub fetchMessages($) {
	my $api = shift;

	my $data = $api->query(
		'action' => 'query',
		'meta'   => 'allmessages',
	);

	return unless $data;
	return values %{ $data->{query}->{allmessages} };
}

my %messages;
{
	my @messages = fetchMessages($plApi);
	foreach my $msg (@messages) {
		$messages{ $msg->{name} } = $msg->{'*'};
	}
}

my @pages = fetchList($plApi);

my %pages_en;

{
	my @pages_en = fetchList($enApi);

	foreach my $page (@pages_en) {
		$pages_en{$page} = 1;
	}
}

foreach my $page ( sort @pages ) {
	my $message = $page;
	$message =~ s/^MediaWiki:(.)/\L$1/;
	$message =~ tr/ /_/;
	next if exists $messages{$message};
	print "* [[$page]]";
	print " [[:en:$page|en]]" if exists $pages_en{$page};
	print "\n";
}

# perltidy -et=8 -l=0 -i=8
