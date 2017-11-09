package Abuse::WikingerDetector;

use strict;
use warnings;
use utf8;
use Log::Any;
use Data::Dumper;

my $logger = Log::Any->get_logger();

# List of expressions applied to edit texts and comments.
my @contentScoreList = (
	{
		'regex' => qr/odpierdo+l/i,
		'score' => -5,
	},
	{
		'regex' => qr/spierdalaj/i,
		'score' => -5,
	},
	{
		'regex' => qr/aferzysta; komuch;/i,
		'score' => -10,
	},
	{
		'regex' => qr/ochlaptus; złodziej;/,
		'score' => -10,
	},
	{
		'regex' => qr/kanciarz; kłamca;/i,
		'score' => -10,
	},
	{
		'regex' => qr/zbrodniarz wojenny; czerwona świnia./,
		'score' => -10,
	},
	{
		'regex' => qr/już jesteś na redwatchu suko/i,
		'score' => -10,
	},
	{
		'regex' => qr/Red.?Watch/i,
		'score' => -8,
	},
	{
		'regex' => qr/polski luj i chooj/i,
		'score' => -10,
	},
	{
		'regex' => qr/stary bałwan fekalie mentalne/i,
		'score' => -10,
	},
	{
		'regex' => qr/kaci Polaków. do dziś nie dostał żadnej rekompensaty./i,
		'score' => -10,
	},
	{
		'regex' => qr/lamblia/i,
		'score' => -8,
	},
	{
		'regex' => qr/czerwony bandyta/i,
		'score' => -10,
	},
	{
		'regex' => qr/malaryja na kazdym ku/i,
		'score' => -10,
	},
	{
		'regex' => qr/czerwony burak .+ miasto/i,
		'score' => -10,
	},
	{
		'regex' => qr/prowadzi propagandę antypolską, namawiając za pośrednictwem mediów do blokowania/i,
		'score' => -8,
	},
	{
		'regex' => qr{www.youtube.com/watch\?v=(?:hpRGwO8ZSME|KIV3PygMMFY|znmnlbSa3Ko|FhiJNbiwSIs)},
		'score' => -10,
	},
	{
		'regex' => qr{Więc dopisuje tutaj}i,
		'score' => -5,
	},
	{
		'regex' => qr{co inne \[Ja nie jestem\]},
		'score' => -5,
	},
	{
		'regex' => qr{Globalne duraczenie}i,
		'score' => -10,
	},
	{
		'regex' => qr{zawracanie gitary cyc.ka.mi}i,
		'score' => -10,
	},
	{
		'regex' => qr{żądaniom komunistycznej mafii ukrytej w instytucjach państwowych}i,
		'score' => -10,
	},
	{
		'regex' => qr{pedalski}i,
		'score' => -5,
	},
	{
		'regex' => qr/do ochrony bezpieczeństwa przestępców przed narodem/i,
		'score' => -10,
	},
	{
		'regex' => qr/to tyle\. wiecie, co macie z nim zrobić/i,
		'score' => -10,
	},
	{
		'regex' => qr/Kupa Chujewódzki/i,
		'score' => -10,
	},
	{
		'regex' => qr/JUŻ CIĘ Q.RWO NIE MA/i,
		'score' => -10,
	},
	{
		'regex' => qr/pingwinojad/i,
		'score' => -10,
	},
	{
		'regex' => qr/(PO[^[:upper:]\s]+)/,
		'score' => -10,
	},
	{
		'regex' => qr/ANTIFA/,
		'score' => -10,
	},
	{
		'regex' => qr/ostre dymanie twojej dupy/i,
		'score' => -10,
	},
	{
		'regex' => qr/Auschwitz heil/i,
		'score' => -10,
	},
	{
		'regex' => qr/VVjkjnger/i,
		'score' => -10,
	},
	{
		'regex' => qr/netyja/i,
		'score' => -10,
	},
	{
		'regex' => qr/jesteś komuchem/i,
		'score' => -10,
	},
	{
		'regex' => qr/ceglarz masonski/i,
		'score' => -10,
	},
	{
		'regex' => qr/łupanie młotkiem w parapet/i,
		'score' => -10,
	},
	{
		'regex' => qr/kręcenie młynkiem do kawy/i,
		'score' => -10,
	},
	{
		'regex' => qr/kręcenie młynkiem do kawy/i,
		'score' => -10,
	},
	{
		'regex' => qr/Był masonem oraz tajnym; świadomym agentem Ochrany../i,
		'score' => -10,
	},
	{
		'regex' => qr/NIEMCY SPALILI TRUPY W KREMATORIUMIE AKADEMII MEDYCZNEJ NA ŚNIADECKICH/i,
		'score' => -10,
	},
);

# List of expressions applied only to edit comments.
my @commentScoreList = (
	{
		'regex' => qr/^Anulowanie wersji nr/,
		'score' => -2,
	},
	{
		'regex' => qr/^[[:upper:]\s]{4,}$/,
		'score' => -2,
	},
	{
		'regex' => qr/uu[ck][yi]nger/,
		'score' => -10,
	},
	{
		'regex' => qr/heil/,
		'score' => -10,
	},
);

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {};

	bless $this, $class;
	return $this;

}

sub getRegexScore {
	my $content = shift;
	my $result  = 0;

	study $content;
	foreach my $entry (@_) {
		$result += $entry->{score} * scalar( $content =~ /$entry->{regex}/g );
	}
	return $result;
}

sub getScore {
	my $this = shift;
	my %edit = @_;

	my $result = 0;

	my $oldContent = $edit{oldContent};
	my $newContent = $edit{newContent};
	my $comment    = $edit{comment};

	return undef
	  unless defined $newContent;

	$result = getRegexScore( $newContent, @contentScoreList );

	if ( defined $oldContent ) {
		$result -= getRegexScore( $oldContent, @contentScoreList );
	}
	if ( defined $comment ) {
		$result += getRegexScore( $comment, @contentScoreList, @commentScoreList );
	}

	# FIXME: Sprawdzić zamiane %

=head
	if ( $entry->{title} =~ /^Dyskusja/ and bytes::length($oldContent) > bytes::length($newContent) + 100 ) {
		$result--;
	}
=cut

	# Mark all edits from Netia range as suspicious...
	if ( defined $edit{whois} and $edit{whois} =~ /netia/i ) {
		$result--;
	}

	return $result;
}

1;

# TODO:
# - moduł powinien zwracać listę pól, które wykorzystuje
# - moduł powinien otrzymywać takie informacje jak:
# -- użytkownik jest botem, adminem, redaktorem...
# -- użytkownik edytuje spod open proxy
# -- użytkownik jest zablokowany na innych projektach
# -- liczba edycji użytkownika
# -- edycja została przejrzana
