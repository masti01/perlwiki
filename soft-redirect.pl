#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Text::Diff;
use HTML::Entities;
use MediaWiki::WWW;

my $logger = Log::Any::get_logger;
$logger->info("Start");

my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend|p" => \$pretend, "Do not edit wiki page" );
$bot->single(1);
$bot->setup;

my @projects = (
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'template' => 'Softredirect',
	},
	{
		'family'   => 'wiktionary',
		'language' => 'pl',
		'template' => 'Softredirect',
	},
	{
		'family'   => 'wikisource',
		'language' => 'pl',
		'template' => 'Softredirect',
	},
	{
		'family'   => 'wikibooks',
		'language' => 'pl',
		'template' => 'Softredirect',
	},
	{
		'family'   => 'wikiquote',
		'language' => 'pl',
		'template' => 'Softredirect',
	},
	{
		'family'   => 'wikinews',
		'language' => 'pl',
		'template' => 'Softredirect',
	},
);

sub getRepairedRedirects {
	my $www = shift;
	$www->_get( 'title' => 'Special:BrokenRedirects', );
	my $content = $www->{ua}->content;
	my @links   = $content =~ m{<li><(?:s|del)>(.+?)</(?:s|del)></li>}g;
	my @result;
	foreach my $link (@links) {
		next unless $link =~ m/title="(.+?)"/;
		push @result, decode_entities($1);
	}
	return @result;
}

foreach my $project (@projects) {
	$logger->info("Naprawa zerwanych przekierowań w projekcie $project->{language}.$project->{family}");
	eval {
		my $api = $bot->getApi( $project->{family}, $project->{language} );
		$api->checkAccount;

		# FIXME: jak będzie odpowiedni moduł to trzeba pobierać via api
		my $www = MediaWiki::WWW->new( 'url' => "http://$project->{language}.$project->{family}.org/w/index.php", );
		$www->{ua}->cookie_jar( $api->{ua}->cookie_jar() );

		my @links = getRepairedRedirects($www);
		my $prefixes;
		{
			my @prefixes = map { $_->{prefix} } $api->getInterwikiMap;
			local $" = '|';
			@prefixes = map { quotemeta } @prefixes;
			$prefixes = qr/(?:@prefixes)/i;
		}
		my $redirect;
		{
			my $magicWord = $api->getMagicWords('redirect');
			my @aliases = map { quotemeta } values %{ $magicWord->{aliases} };
			local $" = '|';
			$redirect = qr/^(?i:@aliases)\s*\[\[:?($prefixes:.+?)(?:\|.+?)?\]\]/i;
		}

		foreach my $link (@links) {
			my $data = $api->query(
				'action'  => 'query',
				'prop'    => 'revisions|info',
				'titles'  => $link,
				'rvlimit' => 1,
				'rvdir'   => 'older',
				'rvprop'  => 'content|timestamp',
			);

			my ($page)     = values %{ $data->{query}->{pages} };
			my ($revision) = values %{ $page->{revisions} };
			my $content    = $revision->{'*'};
			next unless defined $content;

			next unless $content =~ s/$redirect/{{$project->{template}|$1}}/i;

			$logger->info( "Modyfikacja strony [[$page->{title}]]\n" . diff( \$revision->{'*'}, \$content ) );

			next if $pretend;

			# FIXME: edycja może się nie powieść jeśli bot będzie
			# chciał edytować zabezpieczoną stronę - pozostałe linki
			# zostaną zignorowane i bot przejdzie do następnego projektu
			$api->edit(
				'title'          => $page->{title},
				'starttimestamp' => $page->{touched},
				'basetimestamp'  => $revision->{timestamp},
				'text'           => $content,
				'bot'            => 1,
				'minor'          => 1,
				'summary'        => "przekierowanie do innego projektu, wstawienie szablonu {{[[Template:$project->{template}|$project->{template}]]}}",
				'nocreate'       => 1,
			);
			sleep(10);
		}
	};
	if ($@) {
		$logger->error($@);
	}
}

# perltidy -et=8 -l=0 -i=8
