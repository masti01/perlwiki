#!/usr/bin/perl -w

use strict;
use locale;
use utf8;
use Bot4;
use Data::Dumper;

my $bot = new Bot4;
$bot->setup;
my $api = $bot->getApi( "wikipedia", "pl" );
$api->checkAccount;

my $data = $api->query(
	'action'  => 'query',
	'prop'    => 'revisions',
	'rvlimit' => 1,
	'rvprop'  => 'content',
	'rvdir'   => 'older',
	'titles'  => 'Wikipedia:Lista wikipedystów-autorów artykułów medalowych/tabela',
);

my ($page) = values %{ $data->{query}->{pages} };

my ($revision) = values %{ $page->{revisions} };
my $content = $revision->{'*'};

die "Table not found\n" unless $content =~ m/^(\{\|.+?$)\s*(?:\|-\s*)?(.+?)\s*(?:\|-\s*)?\|\}/ms;
$content = $2;
my %users;

foreach my $row ( split /^\|-\s*$/m, $content ) {
	next if $row =~ m/^!/m;

	die "Unable to parse row: \n$row" unless $row =~ m/^\|\s*(.+?)\s*^\|\s*(.+?)\s*$/m;

	my $author  = $1;
	my $article = $2;

	next if $author =~ /^'''/;
	$users{$author} = {
		'user'     => $author,
		'articles' => {},
	} unless exists $users{$author};

	$article =~ s/^\s*([a-zA-Z]+):\s*(.+?)\s*$/$2/;
	$users{$author}->{articles}->{$article} = $1;
}
my @users = values %users;
@users =
  sort { scalar( keys %{ $b->{articles} } ) <=> scalar( keys %{ $a->{articles} } ) or $a->{user} cmp $b->{user} } @users;

my $output = << 'EOF';
<noinclude><!-- NIE ZMIENIAJ TEJ LISTY SAMEMU -->
Właściwa strona to [[WP:{{BASEPAGENAME}}|{{BASEPAGENAME}}]]. Poniższa lista jest automatycznie generowana i nadpisywana przez [[User:mastiBot|bota]] na podstawie odpowiedniej [[WP:{{BASEPAGENAME}}/tabela|listy]]. Jeśli widzisz tutaj błąd skontaktuj się z wikipedystą [[User:masti|masti]] ([[User talk:masti|dyskusja]]), samemu popraw [[WP:{{BASEPAGENAME}}/tabela|tabelę źródłową]] lub napisz na [[Project talk:{{BASEPAGENAME}}|stronie dyskusji]].
</noinclude>{| class="Unicode"
!Wikipedysta
!colspan=20|Artykuły
EOF

foreach my $user (@users) {
	$output .= "|-\n| [[User:$user->{user}|$user->{user}]]\n";
	my $i = 0;
	foreach my $article ( sort keys %{ $user->{articles} } ) {
		if ( $i++ == 20 ) {
			$i = 1;
			$output .= "|-\n||\n";
		}
		$output .= "| [[$article|";

		if    ( $user->{articles}->{$article} eq 'AnM' )  { $output .= "★"; }
		elsif ( $user->{articles}->{$article} eq 'BAnM' ) { $output .= "<span style=\"color: #B7410E;\">★</span>"; }
		elsif ( $user->{articles}->{$article} eq 'DA' )   { $output .= "☆"; }
		elsif ( $user->{articles}->{$article} eq 'BDA' )  { $output .= "<span style=\"color: #B7410E;\">☆</span>"; }

		$output .= "]]\n";
	}
}

$output .= << 'EOF';
|}<noinclude>

[[Kategoria:Artykuły na medal| {{PAGENAME}}]]
</noinclude>
EOF

$api->edit(
	title    => 'Wikipedia:Lista wikipedystów-autorów artykułów medalowych/gwiazdki',
	text     => $output,
	bot      => 1,
	summary  => 'aktualizacja listy',
	nocreate => 1,
);

# perltidy -et=8 -l=0 -i=8
