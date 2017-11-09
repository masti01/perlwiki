#!/usr/bin/perl -w

use strict;
use Bot4;
use utf8;
use Text::Diff;
use Data::Dumper;
use MediaWiki::Parser;

my $logger = Log::Any::get_logger;

my $bot = new Bot4;
$bot->setProject( "wiktionary", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

my @templates  = ( 'audio', 'audioUS', 'audioUK', 'audioCA', 'audioAT' );
my $reTemplate = qr/audio(?:CA|US|UK|AT)?/i;
my $warningLen = 10;

my %processedPages;    # Lista stron poprawionych
my %removedFiles;      # Lista nazw plików, które mają być usunięte

sub checkTemplate($$) {
	my $code    = shift;
	my $summary = shift;

	my @templates = extract_templates($code);

	if ( @templates != 1 ) {
		return $code;
	}

	my $template = shift @templates;

	return $code unless $template->{name} =~ /^$reTemplate$/;

	my $name = $template->{fields}->{1};
	unless ( defined $name ) {
		return $code;
	}

	if ( exists $removedFiles{$name} ) {
		push @{$summary}, "[[Plik:$name]]";
		return '';
	}

	return $code;
}

while (<>) {
	s/^\s+//;
	s/\s+$//;
	$removedFiles{$_}++;
}

my @queue = keys %removedFiles;

while (@queue) {
	my $file = shift @queue;

	# Pobierz linkujące do pliku
	my $iterator = $api->getIterator(
		'generator' => 'imageusage',
		'giutitle'  => "File:$file",
		'prop'      => 'revisions|info',
		'rvprop'    => 'content|timestamp',
		'maxlag'    => 20,
	);

	# Sprawdź strony i usuwaj szablony jeśli jest taka potrzeba
	while ( my $page = $iterator->next ) {
		next if exists $processedPages{ $page->{title} };
		$processedPages{ $page->{title} }++;
		my ($revision) = values %{ $page->{revisions} };
		my $newContent = $revision->{'*'};

		my @summary;
		$newContent =~ s/( *\{\{$reTemplate\s*\|(?:[^{}]+|\{\{[^{}]+\}\})+\}\})/ $_ = checkTemplate($1, \@summary) /ige;

		if ( $revision->{'*'} eq $newContent ) {
			$logger->info("Brak zmian w $page->{title}");
			next;
		}

		if ( $logger->is_info ) {
			$logger->info( "Zmiany w [[$page->{title}]], które zostaną wprowadzone:\n" . diff( \$revision->{'*'}, \$newContent ) );
		}

		$logger->info( "Usunięto linki do plików z wymową: " . join( ', ', @summary ) );

		# Wykonaj edycję
		$api->edit(
			title          => $page->{title},
			starttimestamp => $page->{touched},
			basetimestamp  => $revision->{timestamp},
			text           => $newContent,
			summary        => "robot usuwa linki do plików z wymową: " . join( ', ', @summary ),
			minor          => 1,
			nocreate       => 1,
			bot            => 1,
		);
	}
}
