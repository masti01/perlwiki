#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;

my $logger = Log::Any::get_logger;

my $bot = new Bot4;
$bot->setProject( "wikisource", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

my %whitelist;

sub isTrusted($) {
	my $name = shift;
	return exists $whitelist{$name};
}

my @failed;

foreach my $group ( "bot", "sysop", "bureaucrat", "editor" ) {
	my %query = (
		'action'  => 'query',
		'list'    => 'allusers',
		'augroup' => $group,
		'aulimit' => 'max',
	);
	my $data = $api->query(%query);
	foreach my $user ( values %{ $data->{query}->{allusers} } ) {
		$whitelist{ $user->{name} }++;
	}
}

# Sprawdza tylko ostatnie wersje stron.
foreach my $ns ( NS_TEMPLATE, NS_CATEGORY, NS_HELP, 100, 102 ) {
	my $iterator = $api->getIterator(    #
		'action'       => 'query',
		'generator'    => 'allpages',
		'gapnamespace' => $ns,
		'gaplimit'     => 'max',
		'prop'         => 'revisions|info',
		'rvprop'       => 'ids|user|flagged',
	);

	while ( my $page = $iterator->next ) {
		my ($revision) = values %{ $page->{revisions} };

		next unless isTrusted( $revision->{user} );
		next if exists $revision->{flagged};
		$logger->info("Oznaczanie [[$page->{title}]]");
		eval {
			$api->review(    #
				'revid' => $revision->{revid},
			);
		};
		if ($@) {
			push @failed, $page->{title};
			$logger->error($@);
			next;
		}
	}
}

if (@failed) {
	local $" = "]]\n* [[";
	$logger->info("Lista stron, których nie udało się oznaczyć:\n* [[@failed]]");
}

__END__
print join("', '", sort keys %whitelist);

Zapytanie pobiera identyfikatory stron edytowanych tylko przez wskazanych użytkowników.
Dokładniej jest to revision id!

CREATE TEMPORARY TABLE u_beau.ids AS
SELECT page_latest
FROM page
WHERE page_namespace = 0
	AND page_id NOT IN (
		SELECT rev_page
		FROM revision
		WHERE rev_user_text NOT IN ('ABach', 'Abronikowski', 'Ajsmen91', 'AkBot', 'Akira', 'Alan ffm', 'AlohaBOT', 'Ankry', 'Ashaio', 'Awersowy', 'Azahar', 'Beau', 'Beau.bot', 'Chesterx', 'Crower', 'CzarnyZajaczek', 'DrPZ', 'EMeczKa', 'Electron', 'Elfhelm', 'FlotsamJetsam', 'Holek', 'Jos.', 'Jurkal', 'KamikazeBot', 'Karol007', 'Kubaro', 'Leszek Jańczuk', 'Lethern', 'Ludmiła Pilecka', 'Magalia', 'Masti', 'MastiBot', 'Masur', 'Mathiasrex', 'Mintho', 'MonteChristof', 'Niki K', 'Nutaj', 'Odder', 'Ohtnim', 'Olaf', 'Paelius', 'Patrol110', 'Pozytywny robert', 'Przykuta', 'Rdrozd', 'Remedios44', 'SKbot', 'Saperka', 'Seval', 'Slav88', 'Sp5uhe', 'Teukros', 'Tommy Jantarek', 'Trevas', 'Tsca', 'Viatoro', 'Von.grzanka', 'Waćpan', 'Wpedzich', 'Yarl')
	);

SELECT page_latest FROM u_beau.ids LEFT JOIN flaggedrevs ON (page_latest = fr_rev_id)
WHERE fr_rev_id IS NULL;
