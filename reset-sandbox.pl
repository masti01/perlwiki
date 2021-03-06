#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $logger = Log::Any->get_logger();
$logger->info("Start");

my @sandboxes = (
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Wikipedia:Brudnopis',
		'content'  => '{{Prosimy - NIE ZMIENIAJ, NIE KASUJ, NIE PRZENOŚ tej linijki - pisz niżej}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Pomoc:Krok pierwszy - edytowanie',
		'content'  => '{{/podstrona}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Pomoc:Krok drugi - formatowanie',
		'content'  => '{{/podstrona}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Pomoc:Krok trzeci - linki',
		'content'  => '{{/podstrona}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Pomoc:Krok czwarty - grafiki',
		'content'  => '{{/podstrona}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Pomoc:Krok piąty - szablony',
		'content'  => '{{/podstrona}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'pl',
		'title'    => 'Pomoc:Krok szósty - znaczniki',
		'content'  => '{{/podstrona}}',
		'summary'  => 'resetowanie brudnopisu',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Ndihmë:Guida e redaktimit/Formatimi i tekstit',
		'content'  => '{{/udhëzime}}',
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Ndihmë:Guida e redaktimit/Seksionet dhe listat',
		'content'  => '{{/udhëzime}}',
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Ndihmë:Guida e redaktimit/Lidhjet',
		'content'  => '{{/udhëzime}}',
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Ndihmë:Guida e redaktimit/Skedat',
		'content'  => '{{/udhëzime}}',
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Ndihmë:Guida e redaktimit/Stampat',
		'content'  => '{{/udhëzime}}',
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Ndihmë:Guida e redaktimit/Etiketat',
		'content'  => '{{/udhëzime}}',
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikipedia',
		'language' => 'sq',
		'title'    => 'Wikipedia:Livadhi',
		'content'  => "{{livadhi}}\n<!-- Ju lutemi mos e hiqni shënimin e mësipërm. -->",
		'summary'  => 'resetting the sandbox page',
	},
	{
		'family'   => 'wikisource',
		'language' => 'pl',
		'title'    => 'Wikiźródła:Brudnopis',
		'template' => 'Wikiźródła:Brudnopis/Nagłówek',
		'content'  => '<!-- Prosimy o nieusuwanie tej linii -->{{/Nagłówek}}',
		'summary'  => 'resetowanie brudnopisu',
	},
);

foreach my $sandbox (@sandboxes) {
	eval {
		my $api = $bot->getApi( $sandbox->{family}, $sandbox->{language} );
		$api->checkAccount;
		my $response = $api->query(
			'prop'    => 'templates|info',
			'titles'  => $sandbox->{title},
			'tllimit' => 'max',
		);
		my ($page) = values %{ $response->{query}->{pages} };
		my %templates = map { $_->{title} => 1 } values %{ $page->{templates} };

		unless ( defined $sandbox->{template} and exists $templates{ $sandbox->{template} } ) {
			$logger->info("Resetowanie brudnopisu: $sandbox->{title}");
			$api->edit(
				'title'          => $page->{title},
				'starttimestamp' => $page->{touched},
				'text'           => $sandbox->{content},
				'summary'        => $sandbox->{summary},
				'bot'            => 1,
				'nocreate'       => 1,
			);
		}
	};
	if ($@) {
		$logger->error($@);
	}

}

# perltidy -et=8 -l=0 -i=8
