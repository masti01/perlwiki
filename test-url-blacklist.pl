#!/usr/bin/perl -w

use strict;
use Bot4;
use utf8;
use Data::Dumper;
use MediaWiki::Parser;

my $bot = new Bot4;
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

sub parseRegexes {
	my @regexes;

	foreach my $page (@_) {
		$logger->info("Parsing page [[$page->{title}]]");
		my ($revision) = values %{ $page->{revisions} };
		my $text = $revision->{'*'};
		foreach my $line ( split '\n', $text ) {
			$line =~ s/#.*$//;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next if $line eq '';
			my $re = eval { qr/$line/i; };
			if ($@) {
				$logger->error("Unable to parse '$line', reason: $@");
				next;
			}
			push @regexes,
			  {
				're'   => $re,
				'page' => $page->{title},
			  };
		}
	}
	return @regexes;
}

my @regexes;

# Local wiki
{
	my $api = $bot->getApi;

	my @titles = ( 'MediaWiki:Spam-blacklist', 'MediaWiki:Spam-whitelist' );
	my $response = $api->query(
		'titles' => join( '|', @titles ),
		'prop'   => 'revisions|info',
		'rvprop' => 'content|timestamp',
		'maxlag' => 20,
	);
	push @regexes, parseRegexes( values %{ $response->{query}->{pages} } );
}

# Meta wiki
{
	my $api = $bot->getApi( "wikimedia", "meta" );

	my @titles   = ('Spam blacklist');
	my $response = $api->query(
		'titles' => join( '|', @titles ),
		'prop'   => 'revisions|info',
		'rvprop' => 'content|timestamp',
		'maxlag' => 20,
	);
	push @regexes, map { $_->{page} = 'meta:' . $_->{page}; $_ } parseRegexes( values %{ $response->{query}->{pages} } );
}

$logger->debug( "Regular expressions:\n" . Dumper( \@regexes ) );

while (<STDIN>) {
	s/\s+$//;
	$logger->info("Checking '$_'");
	foreach my $entry (@regexes) {
		next unless /$entry->{re}/;
		$logger->info("'$_' is matched by $entry->{re} from [[$entry->{page}]]");
	}
}
