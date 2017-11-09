package ClueBot;

use strict;
use warnings;
use utf8;
use lib "..";
use Bot4;
use Data::Dumper;
use Algorithm::Diff;
use Text::Diff;
use Log::Any;

my $logger = Log::Any->get_logger();
my $bot    = undef;

sub setup {
	my $client = shift;
	$bot = shift;

	$client->registerHandler( 'rc edit', \&rc_edit );
}

sub rc_edit {
	my ( $this, $data ) = @_;

	return unless $data->{channel} eq '#pl.wikipedia';

	my $api = $bot->getApi( "wikipedia", "pl" );    # FIXME
	$data->{namespace} = $api->getPageNamespace( $data->{title} );

	if ( $data->{flags}->{new} and $data->{namespace} == 0 ) {
		main::spawn_task( \&checkNewArticle, $data );
	}
	elsif ( !$data->{flags}->{new} ) {

		# FIXME
		# main::spawn_task( \&checkEdit, $data );
	}
}

my @grawpList = (

	#
	qr/H.{0,2}(?:A.{0,2})?G.{0,2}(?:G.{0,2})?E.{0,2}R/,
	qr/(?:grawp|massive).*(?:cock|dick)/i,
	qr/suck.*my.*dick.*wikipedia/i,
	qr/stillman.*street/i,
	qr/epic.*lulz.*on.*nimp.*org/i,
	qr/on.*nimp.*org.*epic.*lulz/i,
	qr/punishing.*wikipedia/i,
	qr/anti.*avril.*hate.*campaign/i,
	qr/\[\[grawp\|consensus\]\]/i,
);

my @scoreList = (
	{
		'regex' => qr/cluebot_test/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)moher([^a-z]|$)/i,
		'score' => -3,
	},
	{
		'regex' => qr/g(ł|l)upek/i,
		'score' => -5,
	},
	{
		'regex' => qr/haha/i,
		'score' => -5,
	},
	{
		'regex' => qr/hehe/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)sperm(a|y|ą)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)kup(a|y|ą)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)psi(a|e|ą)\bkup(a|y|ą)([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)peda(l|ł)(ek)([^a-z]|$)/i,
		'score' => -3,
	},
	{
		'regex' => qr/([^a-z]|^)pa(ł|l)a([^a-z]|$)/i,
		'score' => -3,
	},
	{
		'regex' => qr/([^a-z]|^)cyc(a|ami|e(|m|k)|k(a|i|em|ami))([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)idio(t(k|om|)(a|i)|ci)([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)komuch([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)żyd([^a-z]|$)/i,
		'score' => -1,
	},
	{
		'regex' => qr/([^a-z]|^)dziwk([ąaoi]|om)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)(o(b|)|z|za|po|)rzyg/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)rzygacz/,
		'score' => 2,
	},
	{
		'regex' => qr/([^a-z]|^)debil/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)krety(n|ń)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)frajer/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)palant(em|y|ami|)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)lolek/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)[l]+[o]+[l]+([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/[l]+[oó0]{2,}[l]+/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)elo{2,}/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)gupi/i,
		'score' => -7,
	},
	{
		'regex' => qr/(o|u|e|^|[^a-z])sra(ta|[ckmnsćłl])/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)zdzir[aeoy]([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)osram([^a-z]|$)/i,
		'score' => 7,
	},
	{
		'regex' => qr/([^a-z]|^)sex([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)n[0o]{2,}b([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)su(cz|)k[aio]([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)le(s|z)b[aoy][^s]/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)(rlz|rulez)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)(p|)(o|0)wned([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)hacked([^a-z]|$)/i,
		'score' => -3,
	},
	{
		'regex' => qr/([^a-z]|^)sux([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)mend[aoy]([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/penis/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)buzi(ak|aki|aczek|aczki)([^a-z]|$)/i,
		'score' => -3,
	},
	{
		'regex' => qr/([^a-z]|^)tesh([^a-z]|$)/i,
		'score' => -3,
	},
	{
		'regex' => qr/([^a-z]|^)miszcz(a|em|e|u)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)pozdro([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)gr[e]+tz([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)zajefajn/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)siem(k|)a(n|[^a-z]|$|sz([^a-z]|$))/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)ziom(|y|a|al|ale|alk[ai]|ali|al(om|kom)|k[ia]|alkom)([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)pipa([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)ciot(a|y)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)to\sciot(y|a)([^a-z]|$)/i,
		'score' => -2,
	},
	{
		'regex' => qr/([^a-z]|^)sik(i|ów)([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)maci(ek|uś)\sz\sklanu([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)bujaj\ssi/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)cienias(|a|i|y|o|o)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)rucha(n|ł|l|ć|cz|c\s|[^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)[ea]h{5,}([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)pozdrawiam([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)pozdrawiam.{0,15}('|")/i,
		'score' => 5,
	},
	{
		'regex' => qr/([^a-z]|^)pedzi(o|em|a)([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)fucker/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)kof(f|)am([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)spox([^a-z]|^)/i,
		'score' => -7,
	},
	{
		'regex' => qr/be(s|ś)ciak/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)wioch([ay]|men([ya]|))([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)gównozjad/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)pojebus(a|y|)([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)qp(a|e|y)([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)kole(s|ś|sia)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)wymiata(|cz)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)wypas(ion[aey]|)([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)(po|)bzyka[ćł]/i,
		'score' => -3,
	},
	{
		'regex' => qr/666+([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/v\.666/i,
		'score' => 2,
	},
	{
		'regex' => qr/motor\sinn/i,
		'score' => 2,
	},
	{
		'regex' => qr/fiat\s666rn/i,
		'score' => 2,
	},
	{
		'regex' => qr/666\s(album)/i,
		'score' => 2,
	},
	{
		'regex' => qr/(HIM|KAT)/,
		'score' => 2,
	},
	{
		'regex' => qr/(płyt.|album(ie|u|))\s666/i,
		'score' => 2,
	},
	{
		'regex' => qr/dept.\s666/i,
		'score' => 2,
	},
	{
		'regex' => qr/([^a-z]|^)dup((n|)([aoy]|om)|k([aoi]|om)|ek|s(ko|two|kie)|ie)([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)pieprzon[aey]([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/w\sdupie/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)obci(a|ą)gacz(a|em|)([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)h[óu]i/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)(o|wy|prze|)(c|)h[uó]j/i,
		'score' => -20,
	},
	{
		'regex' => qr/(o|s|w|)kurw/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^|y)kurewsk/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)q(u|)rw[aoy]([^a-z]|$)/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^|[oswyz])pierd/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^|[oyz])pizd([aoyu]|)(n|[^a-z]|$)/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^|[oyzea])jeban[aeiy]/,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^|[oyze])jeba(ł|l|k|ć|c)/,
		'score' => -20,
	},
	{
		'regex' => qr/(za|wy)jebist[aeys]/i,
		'score' => -15,
	},
	{
		'regex' => qr/(za|wy)jebiś/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)cip(k|)[aoyi]([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)(wy|nie|do|)rucha(n[aeky]|j|li|ł)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)fiut/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)pedzi(o|e)([^a-z]|$)/i,
		'score' => -10,
	},
	{
		'regex' => qr/([^a-z]|^)penisist/i,
		'score' => -15,
	},
	{
		'regex' => qr/\[\[grafika:.{,35}penis.{,35}\]\]/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)g(o|u|ó)wn(em|a|o|ian(a|e|y))([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)(wali|trzep).{1,10}(konia|gruch)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)(matko|wujko|ojc|p)ojeb/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)szczyny([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)(za)dup(a|iu|ie|nie)([^a-z]|$)/i,
		'score' => -10,
	},
	{
		'regex' => qr/([^a-z]|^)cwel(|e|u|em|a(mi|))([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)(c|)hwdp([^a-z]|$)/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)kutas[^i]/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)pedal(ec|ca|cu|ce)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)(s|)pierd(o|a)l(cie|ala(j|cie|m|my))( sie)([^a-z]|$)/i,
		'score' => -100,
	},
	{
		'regex' => qr/([^a-z]|^)t(f|w)(o|ó|u)(j|i)(a|e|).{1,5}star(y|a|e)([^a-z]|$)/i,
		'score' => -12,
	},
	{
		'regex' => qr/h[ae]{5,}/i,
		'score' => -15,
	},
	{
		'regex' => qr/(h[ae]){3,}/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)lodziar(a|y)([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/\sto\spa(l|ł)(a|y)([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/([^a-z]|^)hapa(ć|ł|ła|li)([^a-z]|$)/i,
		'score' => -15,
	},
	{
		'regex' => qr/ssie\spa[lł][ey]/i,
		'score' => -15,
	},
	{
		'regex' => qr/d\.u\.p\.(a|e)/i,
		'score' => -20,
	},
	{
		'regex' => qr/chujania/i,
		'score' => -20,
	},
	{
		'regex' => qr/6h blokady za zwykle/i,
		'score' => -20,
	},
	{
		'regex' => qr/najlepsze\sszamba\sbetonowe/i,
		'score' => -20,
	},
	{
		'regex' => qr/eko-pol\.pl/i,
		'score' => -20,
	},
	{
		'regex' => qr/r(e|ę)ce(\s|)precz(\s|)od(\s|)tybetu/i,
		'score' => -20,
	},
	{
		'regex' => qr/([^a-z]|^)(;|:)(\)|>|p|\])([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)(0|o)_(0|o)([^a-z]|$)/i,
		'score' => -7,
	},
	{
		'regex' => qr/([^a-z]|^)buźki([^a-z]|$)/i,
		'score' => -5,
	},
	{
		'regex' => qr/([^a-z]|^)(x|:|;)d([^a-z]|$)/i,
		'score' => -6,
	},
	{
		'regex' => qr/([^a-z]|^)[A-Z].*?[.!?]([^a-z]|$)/,
		'score' => 2,
	},
	{
		'regex' => qr/([^a-z]|^)[A-Z][^a-z]{30,}?([^a-z]|$)/,
		'score' => -10,
	},
	{
		'regex' => qr/([^a-z]|^)[^A-Z]{1500,}?([^a-z]|$)/,
		'score' => -10,
	},
	{
		'regex' => qr/!{5,}/i,
		'score' => -10,
	},
	{
		'regex' => qr/!!+1+(one)*/i,
		'score' => -30,
	},
	{
		'regex' => qr/\[\[.*?\]\]/,
		'score' => 1,
	},
	{
		'regex' => qr/\{\{.*?\}\}/,
		'score' => 5,
	},
	{
		'regex' => qr/\{\{[iI]nfobox .*?\}\}/,
		'score' => 20,
	},
	{
		'regex' => qr/\[\[Kategoria\:.*?\]\]/i,
		'score' => 3,
	},
	{
		'regex' => qr/([^:a-z0-9\/?=]|^)([a-z][a-z0-9]{35,}|[a-z0-9]{35,}[a-z])/i,
		'score' => -6,
	},
	{
		'regex' => qr/[fghjkvbnmrty]{20,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[sdfzxcv]{15,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[asdf]{15,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[zxcvbnm]{20,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[sdfghjkl]{20,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[qwertyuiop]{35,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[hjklnm]{20,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[rtyufghj]{20,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[a-z0-9]{30,}/i,
		'score' => -11,
	},
	{
		'regex' => qr/[\.'"\?]{15,}/i,
		'score' => -11,
	},
);

sub checkNewArticle($) {
	my $data = shift;

	my %checks = (
		'cv'     => 1,
		'speedy' => 1,
	);

	$bot->status("Checking: $data->{title}");
	my $api = $bot->getApi( "wikipedia", "pl" );    # FIXME
	$api->checkAccount;

	$logger->info("[[$data->{title}]] has been created, size: $data->{size}b");

	my $page;
	eval {
		my %query = (
			'action'  => 'query',
			'prop'    => 'info|revisions|links|categories|extlinks',
			'intoken' => 'edit',
			'rvprop'  => 'content|comment|timestamp|user',
			'rvlimit' => 1,
			'rvdir'   => 'older',
			'cllimit' => 100,
			'ellimit' => 100,
			'titles'  => $data->{title},
			'maxlag'  => 10,
		);
		my $response = $api->query(%query);
		($page) = values %{ $response->{query}->{pages} };

		# ponów próbę
		if ( exists $page->{missing} ) {
			sleep(5);
			$response = $api->query(%query);
			($page) = values %{ $response->{query}->{pages} };
		}
	};
	if ($@) {
		$logger->error($@);
		return;
	}

	if ( exists $page->{missing} ) {
		$logger->warn("[[$data->{title}]] is missing");
		return;
	}

	my ($revision) = values %{ $page->{revisions} };
	my $content = $revision->{'*'};

	my %categories = map { $_->{title} => 1 } values %{ $page->{categories} };
	$logger->debug( "[[$data->{title}]] kategorie: " . join( ", ", sort keys %categories ) ) if scalar keys %categories;

	my $type;

	if ( $content eq '' ) {
		$type   = 'pusta?';
		%checks = ();
	}
	elsif ( exists $page->{redirect} ) {
		$type   = 'przekierowaniem (API)';
		%checks = ();

		# sprawdzać czy redir jest do przestrzeni głównej i do istniejącego artu
	}
	elsif ( $content =~ /^#REDIRECT\s*\[\[.+?\]\]/i ) {
		$type   = 'przekierowaniem (content)';
		%checks = ();
	}
	elsif ( exists $categories{'Kategoria:Artykuły w edycji'} ) {
		$type = 'w edycji';
		delete $checks{speedy};
	}
	elsif ( exists $categories{'Kategoria:Artykuły w przebudowie'} ) {
		$type = 'w przebudowie';
		delete $checks{speedy};
	}
	elsif ( exists $categories{'Kategoria:Strony ujednoznaczniające'} ) {
		$type = 'stroną ujednoznaczniającą';
		delete $checks{speedy};
	}
	elsif ( exists $categories{'Kategoria:Ekspresowe kasowanie'} ) {
		$type = 'oznaczona do skasowania';
		delete $checks{speedy};
	}

	$logger->info("[[$data->{title}]] strona jest $type") if defined $type;

	if ( $checks{speedy} ) {
		$logger->info("[[$data->{title}]] sprawdzanie czy strona nadaje się do {{ek}}");
		my $score = score($content);
		$logger->info("[[$data->{title}]] score: $score");

		# Więcej na [[Specjalna:Wszystkie_komunikaty]]
		# lub http://svn.wikimedia.org/viewvc/mediawiki/trunk/phase3/languages/messages/MessagesPl.php

		my $tmpcontent = $content;

		$tmpcontent =~ s/\s+/ /g;

		my $count = 1;
		while ($count) {
			$count = 0;
			$count += $tmpcontent =~ s/Tekst tłustą czcionką//g;
			$count += $tmpcontent =~ s/Tekst pochyłą czcionką//g;
			$count += $tmpcontent =~ s/Tytuł linku//g;
			$count += $tmpcontent =~ s{http://www.example.com nazwa linku}{}g;
			$count += $tmpcontent =~ s/Tekst nagłówka//g;
			$count += $tmpcontent =~ s/Przyklad.jpg//g;
			$count += $tmpcontent =~ s/Przyklad.ogg//g;
			$count += $tmpcontent =~ s/Pl-przykład.ogg//g;
			$count += $tmpcontent =~ s/Tutaj wprowadź wzór//g;
			$count += $tmpcontent =~ s/Tutaj wstaw niesformatowany tekst//g;
			$count += $tmpcontent =~ s/Tekst indeksem (?:górnym|dolnym)//g;
			$count += $tmpcontent =~ s/Nazwa kategorii//g;

			$count += $tmpcontent =~ s/\[\[\s*\]\]//g;
			$count += $tmpcontent =~ s/'''\s*'''//g;
			$count += $tmpcontent =~ s/(?:^|[^'])''\s*''(?:$|[^'])//g;
			$count += $tmpcontent =~ s{<sup>\s*</sup>}{}g;
			$count += $tmpcontent =~ s{<sub>\s*</sub>}{}g;
			$count += $tmpcontent =~ s{<math>\s*</math>}{}g;
			$count += $tmpcontent =~ s{<nowiki>\s*</nowiki>}{}g;
			$count += $tmpcontent =~ s{\[\[Kategoria:\s*\]\]}{}g;
			$count += $tmpcontent =~ s{<!--\s*-->}{}g;
			$count += $tmpcontent =~ s{----}{}g;
			$count += $tmpcontent =~ s{==\s*==}{}g;
		}
		$tmpcontent =~ s/(.)\1+/$1/g;

		my $template;
		my $summary;
		if ( length($tmpcontent) < 35 ) {
			$summary  = '{{[[Template:Ek|ek]]}} - prawdopodobnie eksperyment edycyjny';
			$template = '{{ek|prawdopodobnie eksperyment edycyjny}}';
		}
		elsif ( length($tmpcontent) < 75 and $score < 0 ) {
			$summary  = '{{[[Template:Ek|ek]]}} - prawdopodobnie eksperyment edycyjny';
			$template = '{{ek|prawdopodobnie eksperyment edycyjny}}';
		}
		elsif ( $content !~ / / ) {
			$summary  = '{{[[Template:Ek|ek]]}} - artykuł nie zawiera spacji, prawdopodobnie eksperyment edycyjny';
			$template = '{{ek|artykuł nie zawiera spacji, prawdopodobnie eksperyment edycyjny}}';
		}

		if ( defined $template ) {
			if ( $tmpcontent ne $content ) {
				$logger->debug("[[$data->{title}]] treść (odfiltrowana):\n$tmpcontent");
			}

			$logger->debug("[[$data->{title}]] treść:\n$content");
			$logger->debug("[[$data->{title}]] template: $template");
			$logger->debug("[[$data->{title}]] summary : $summary");

			if ( exists $revision->{anon} ) {
				eval {
					$api->edit(

						#
						'title'          => $page->{title},
						'token'          => $page->{edittoken},
						'starttimestamp' => $page->{starttimestamp},

						'minor'       => 1,
						'nocreate'    => 1,
						'summary'     => $summary,
						'prependtext' => $template . "\n",
					);
				};
				$logger->error("[[$data->{title}]] $@") if $@;
			}
			else {
				$logger->info("[[$data->{title}]] zignorowanie edycji, użytkownik zarejestrowany: $revision->{user}");
			}
		}
	}
}

sub getUserData($) {
	my $name = shift;

	# Jakieś cache potrzebne

	my $api = $bot->getApi( "wikipedia", "pl" );    # FIXME
	my $response = $api->query(
		'list'    => 'allusers',
		'aulimit' => 1,
		'aufrom'  => $name,
		'auprop'  => 'groups|editcount',
	);

	my ($entry) = values %{ $response->{query}->{allusers} };
	return undef if $entry->{name} ne $name;

	$entry->{groups} = [ map { $_ => 1 } values %{ $entry->{groups} } ] if $entry->{groups};

	return $entry;
}

sub isPageIgnored($) {

}

sub isPageChecked($) {

}

sub isUserIgnored($) {

}

sub checkEdit {
	my $data = shift;

	if ( $logger->is_debug ) {
		$logger->debug( Dumper($data) );
	}

	# Ignoruj nowe strony, ich się nie da rewertować
	return
	  if $data->{flags}->{new};

	# Ignoruj bocie edycje
	return
	  if $data->{flags}->{bot};

	# Ignoruj strony z listy opt-out
	return
	  if isPageIgnored( $data->{title} );

	# Sprawdzaj strony z przestrzeni głównej oraz te z opt-in
	return
	  unless $data->{namespace} == 0
		  or isPageChecked( $data->{title} );

	# Ignoruj edytowanie swojej własnej strony

	# Ignoruj użytkowników zarejestrowanych
	return
	  unless MediaWiki::Utils::isAnonymous( $data->{user} );

	# Ignoruj sysopów, botów, redaktorów
	# xxx - patrz wyżej

	# CB ignoruje ipki z liczbą edycji > 50,
	# ale to nie ma sensu dla dynamicznych adresów

	unless ( $data->{diff} =~ /oldid=(\d+)/ ) {
		die "Unable to find oldid parameter in url: $data->{diff}\n";
	}
	my $oldid = $1;
	unless ( $data->{diff} =~ /diff=(\d+)/ ) {
		die "Unable to find diff parameter in url: $data->{diff}\n";
	}
	my $newid = $1;

	my $api = $bot->getApi( "wikipedia", "pl" );    # FIXME
	my $response = $api->query(
		'titles'  => $data->{title},
		'prop'    => 'revisions|info',
		'intoken' => 'edit',
		'rvprop'  => 'content|timestamp|user|comment|ids',

		#'rvtoken' => 'rollback',
		#'rvlimit' => '2',
		'rvdir'     => 'newer',
		'rvstartid' => $oldid,
		'maxlag'    => 2,
	);

	my ($page) = values %{ $response->{query}->{pages} };

	if ( exists $page->{missing} ) {
		$logger->info("[[$page->{title}]] is missing");
		return;
	}
	my @revisions = values %{ $page->{revisions} };

	my $old = shift @revisions;
	die '$oldid != $old->{revid}' unless $oldid == $old->{revid};

	my $new = shift @revisions;
	die '$newid != $new->{revid}' unless $newid == $new->{revid};
	die '$data->{user} ne $new->{user}' unless $data->{user} eq $new->{user};

	die 'There are more revisions!' if @revisions;

	$logger->info("[[$page->{title}]] has been edited by $new->{user}");
	print diff( \$old->{'*'}, \$new->{'*'} ) . "\n";

	my @diff = @{ Algorithm::Diff::diff( [ split "\n", $old->{'*'} ], [ split "\n", $new->{'*'} ] ) };
	my @addedLines;
	my @removedLines;
	foreach my $hunk (@diff) {
		foreach my $change ( @{$hunk} ) {
			my ( $what, undef, $line ) = @{$change};
			if ( $what eq '+' ) {
				push @addedLines, $line;
			}
			else {
				push @removedLines, $line;
			}
		}
	}

	# Wykonaj heurystyki

	my %heuristics;

	my $score = 0;
	$score += score( join( "\n", @addedLines ) );
	$score -= score( join( "\n", @removedLines ) );

	$logger->info("Score:\t$score");
	$logger->info("Size:\t$data->{size}");

	# Massive tables

=head
	if ( /* Massive tables */
		($change['length'] >= 7500)
		and ($rv = $wpapi->revisions($change['title'],2,'older',true,$change['revid']))
		and (substr_count(strtolower($rv[0]['*']),'<td') > 300)
		and ($reason = 'adding huge, browser-crashing tables')
	) $heuristicret = true;
=cut

	if ( $data->{size} >= 7500 ) {

		my $cnt = 0;
		foreach my $line (@addedLines) {
			while ( $line =~ /\G<td/g ) {
				$cnt++;
			}
		}
		if ( $cnt > 300 ) {
			$heuristics{'massive tables'} = 'adding huge, browser-crashing tables';
		}
	}

	# Massive deletes

=head

	if ( /* Massive deletes */
		($change['length'] <= -7500)
		and ($pagedata = $wpq->getpage($change['title']))
		and (!myfnmatch('*#REDIRECT*',strtoupper(substr($pagedata,0,9))))
		and ($rv = $wpapi->revisions($change['title'],2,'older',true,$change['revid']))
		and ($s = score($scorelist,$rv[0]['*']))
		and ($s += (score($scorelist,$rv[1]['*'])) * -1)
		and ($s < -50) /* There are times when massive deletes are ok. */
		and ($reason = 'deleting '.($change['length'] * -1).' characters')
	) $heuristicret = true;
=cut

	if ( $data->{size} <= -7500 and $score < -50 ) {

		# FIXME: Sprawdź, czy strona nie jest przekierowaniem
		$heuristics{'massive deletes'} = "deleting " . abs( $data->{size} ) . " bytes";
	}

	# Massive additions

=head
	if ( /* Massive additions */
		($change['length'] >= 7500)
		and ($rv = $wpapi->revisions($change['title'],2,'older',true,$change['revid']))
		and ($pagedata = $wpq->getpage($change['title']))
		and ($s = score($scorelist,$rv[0]['*']))
		and ($s += (score($scorelist,$rv[1]['*'])) * -1)
		and ($s < -1000)
		and ($reason = 'score equals '.$s)
	) $heuristicret = true;
=cut

	if ( $data->{size} >= 7500 and $score < -1000 ) {
		$heuristics{'massive additions'} = "score equals $score";
	}

	# The Grawp vandal

=head
	if ( /* The Grawp vandal */
		(
			(myfnmatch('*HAGGER*',$change['comment']))
			or (myfnmatch('*suck*my*dick*wikipedia*',strtolower($change['comment'])))
			or (myfnmatch('*stillman*street*',strtolower($change['comment'])))
			or (myfnmatch('*epic*lulz*on*nimp*org*',strtolower($change['comment'])))
			or (myfnmatch('*on*nimp*org*epic*lulz*',strtolower($change['comment'])))
			or (myfnmatch('*punishing*wikipedia*',strtolower($change['comment'])))
			or (myfnmatch('*anti*avril*hate*campaign*',strtolower($change['comment'])))
			or (myfnmatch('*H?A?G?G?E?R*',$change['comment']))
			or (myfnmatch('*h??a??g??g??e??r*',strtolower($change['comment'])))
			or (myfnmatch('*grawp*cock*',strtolower($change['comment'])))
			or (myfnmatch('*massive*cock*',strtolower($change['comment'])))
			or (myfnmatch('*grawp*dick*',strtolower($change['comment'])))
			or (myfnmatch('*massive*dick*',strtolower($change['comment'])))
			or (myfnmatch('*H?A?G?E?R*',$change['comment']))
			or (myfnmatch('*hgger*',strtolower($change['comment'])))
			or (stripos(strtolower($change['comment']),'[[grawp|consensus]]') !== false)
		)
		and ($reason = 'Grawp?')
	) {
		$heuristicret = true;
		foreach (explode(',',$ircreportchannel) as $y) fwrite($irc,'PRIVMSG '.$y.' :!admin Grawp vandal? [[Special:Contributions/'.$change['user']."]] .\n");
	}
=cut

	foreach my $re (@grawpList) {
		next unless $data->{summary} =~ /$re/;
		$heuristics{'grawp'} = "Grawp?";
	}

	# Small changes with obscenities

=head
	unset($log,$log2);
	if ( /* Small changes with obscenities. */
		(($change['length'] >= -200) and ($change['length'] <= 200))
		and (($d = $wpi->diff($change['title'],$change['old_revid'],$change['revid'])) or true)
		and ((($change['title'] == 'User:ClueBot/Sandbox') and print_r($rv)) or true)
		and (($s = score($obscenelist,$d[0],$log)) or true)
		and (($s -= score($obscenelist,$d[1],$log2)) or true)
		and (
			(
				($s < -5) /* There are times when small changes are ok. */
				and (($rv = $wpapi->revisions($change['title'],2,'older',true,$change['revid'])) or true)
				and (!myfnmatch('*#REDIRECT*',strtoupper(substr($rv[0]['*'],0,9))))
				and (!myfnmatch('*SEX*',strtoupper($rv[1]['*'])))
				and (!myfnmatch('*BDSM*',strtoupper($rv[1]['*'])))
				and (score($obscenelist,$change['title']) >= 0)
				and (score($obscenelist,$rv[1]['*']) >= 0)
				and (!preg_match('/(^|\s)([a-z]{1,2}(\*+|\-{3,})[a-z]{0,2}|\*{4}|\-{4}|(\<|\()?censored(\>|\))?)(ing?|ed)?(\s|$)/iS',$rv[1]['*']))
				and ($heuristic .= '/obscenities')
				and ($reason = 'making a minor change with obscenities')
			)
			or (
				($s > 5)
				and (($rv = $wpapi->revisions($change['title'],2,'older',true,$change['revid'])) or true)
				and (!myfnmatch('*#REDIRECT*',strtoupper(substr($rv[0]['*'],0,9))))
				and (!preg_match('/(^|\s)([a-z]{1,2}(\*+|\-{3,})[a-z]{0,2}|\*{4}|\-{4}|(\<|\()?censored(\>|\))?)(ing?|ed)?(\s|$)/iS',$rv[1]['*']))
				and (preg_match('/(^|\s)([a-z]{1,2}(\*+|\-{3,})[a-z]{0,2}|\*{4}|\-{4}|(\<|\()?censored(\>|\))?)(ing?|ed)?(\s|$)/iS',$rv[0]['*']))
				and ($heuristic .= '/censor')
				and ($reason = 'making a minor change censoring content ([[WP:CENSOR|Wikipedia is not censored]])')
			)
			or (
				(preg_match('/\!\!\!/S',$d[0]))
				and (($rv = $wpapi->revisions($change['title'],2,'older',true,$change['revid'])) or true)
				and (!preg_match('/\!\!\!/S',$rv[1]['*']))
				and (!myfnmatch('*#REDIRECT*',strtoupper(substr($rv[0]['*'],0,9))))
				and ($heuristic .= '/exclamation')
				and ($reason = 'making a minor change adding "!!!"')
			)
		)
	) { $heuristicret = true; if (isset($log2) and is_array($log2)) foreach ($log2 as $k => $v) $log[$k] -= $v; if (isset($log) and is_array($log)) foreach ($log as $k => $v) if ($v == 0) unset($log[$k]); unset($log2); /* fwrite($irc,'PRIVMSG #wikipedia-BAG/ClueBot :Would revert http://en.wikipedia.org/w/index.php?title='.urlencode($change['namespace'].$change['title']).'&diff=prev'.'&oldid='.urlencode($change['revid'])." .\n"); */ }
=cut

	if ( abs( $data->{size} ) <= 200 && !exists $page->{redirect} ) {
		if ( $score < -5 ) {

			my $positive = 1;

			$positive &&= $old->{'*'} !~ /(?:sex|seks|bdsm)/i;
			$positive &&= score( $page->{title} ) >= 0;
			$positive &&= score( $old->{'*'} ) >= 0;

			if ($positive) {
				$heuristics{'obscenities'} = 'making a minor change with obscenities';
			}

=head
				and (!preg_match('/(^|\s)([a-z]{1,2}(\*+|\-{3,})[a-z]{0,2}|\*{4}|\-{4}|(\<|\()?censored(\>|\))?)(ing?|ed)?(\s|$)/iS',$rv[1]['*']))
=cut

		}
		elsif ( $score > 5 ) {

			#$heuristics{'censor'} = 'making a minor change censoring content';

=head
				and (!preg_match('/(^|\s)([a-z]{1,2}(\*+|\-{3,})[a-z]{0,2}|\*{4}|\-{4}|(\<|\()?censored(\>|\))?)(ing?|ed)?(\s|$)/iS',$rv[1]['*']))
				and (preg_match('/(^|\s)([a-z]{1,2}(\*+|\-{3,})[a-z]{0,2}|\*{4}|\-{4}|(\<|\()?censored(\>|\))?)(ing?|ed)?(\s|$)/iS',$rv[0]['*']))
=cut

		}
		elsif ( grep { /!!!/ } @addedLines and $old->{'*'} !~ /!!!/ ) {
			$heuristics{'exclamation'} = 'making a minor change adding "!!!"';

		}
	}

	if ( scalar keys %heuristics ) {
		$logger->info("POSITIVE!");
		print Dumper( \%heuristics );
	}

=head
- modyfikacje własnych stron wikipedystów są ignorowane
- pobranie ostatniej wersji strony, jeśli revid się nie zgadza z tym z komunikatu, to znaczy, że strona była zmieniona i edycja jest ignorowana,
=cut

}

sub score {
	my $text  = shift;
	my $score = 0;
	foreach my $item (@scoreList) {
		while ( $text =~ m/\G.*?$item->{regex}/sg ) {
			$score += $item->{score};
		}
	}
	return $score;
}

1;

# perltidy -et=8 -l=0 -i=8

__END__

<?PHP
	if ( /* The Redirect vandals */
		(
			($tfa == $change['title'])
			and (myfnmatch('*#redirect *',strtolower($wpq->getpage($change['title']))))
			and ($reason = 'redirecting featured article to new title')
		)
		or (
			($pagedata = $wpq->getpage($change['title']))
			and (substr(trim(strtolower($pagedata)),0,10) == '#redirect ')
			and (preg_match('/\[\[(.*)\]\]/',$pagedata,$m))
			and (!$wpq->getpage($m[1]))
			and ($reason = 'redirecting article to non-existant page')
		)
	) {
		$heuristicret = true;
//		fwrite($irc,'PRIVMSG #cvn-wp-en :!admin Grawp vandal? http://en.wikipedia.org/wiki/Special:Contributions/'.$change['user']." .\n");
	}
?>

<?PHP
	if ( /* Page replaces */
		(preg_match('/\[\[WP:.*\]\]Replaced content with (.*)$/',$change['comment'],$m))
		and ($pagedata = $wpq->getpage($change['title']))
		and ($fc = $wpapi->revisions($change['title'],1,'newer'))
		and ($fc[0]['user'] != $change['user']) /* The creator is allowed to replace the page. */
		and ($reason = 'replacing entire content with something else')
	) $heuristicret = true;
?>


<?PHP
	if ( /* Page blanks */
		(preg_match('/\[\[WP:.*Blanked.*page/',$change['comment'],$m))
		and (($pagedata = $wpq->getpage($change['title'])) or true)
		and ($fc = $wpapi->revisions($change['title'],1,'newer'))
		and ($fc[0]['user'] != $change['user']) /* The creator is allowed to blank the page. */
		and ($reason = 'blanking the page')
	) $heuristicret = true;
?>
