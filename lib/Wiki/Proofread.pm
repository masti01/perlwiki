package Wiki::Proofread;
require Exporter;

use strict;
use warnings;
use Log::Any;

our @ISA       = qw(Exporter);
our @EXPORT    = qw(fetchProofreadPages);
our @EXPORT_OK = qw();
our $VERSION   = 20100424;

use constant NS_PAGE => 100;

my $logger = Log::Any->get_logger();

# Funkcja pobiera strony dla podanego indeksu
sub fetchProofreadPages {
	my $api       = shift;
	my $index     = shift;
	my $generator = $api->getIterator(
		'generator'    => 'links',
		'titles'       => $index,
		'prop'         => 'revisions|info',
		'rvprop'       => 'content|timestamp',
		'gplnamespace' => NS_PAGE,
		'gpllimit'     => '100',
	);

	my %pages;
	while ( my $page = $generator->next ) {
		$pages{ $page->{title} } = $page;
	}

	my $response = $api->query(
		'titles' => $index,
		'prop'   => 'revisions',
		'rvprop' => 'content',
	);

	my ($page) = values %{ $response->{query}->{pages} };
	die "Nie można pobrać strony indeksu\n" unless $page;
	my ($revision) = values %{ $page->{revisions} };
	die "Nie można pobrać strony indeksu\n" unless $revision;

	# FIXME: sprawdzić czy jest tam wywolanie <pagelist>
	my @links = $revision->{'*'} =~ /\[\[Strona:([^\|\[\]]+?)(?:\|([^\|\[\]]+?))?\]\]/ig;
	my @pages;

	while (@links) {
		my ( $title, $caption ) = splice @links, 0, 2;
		$title = ucfirst($title);
		my $page = delete $pages{"Strona:$title"};
		unless ($page) {
			$logger->warn("Podlinkowana strona [[Strona:$title]] nie została pobrana");
			next;
		}
		$page->{caption} = $caption;
		push @pages, $page;
	}
	if ( scalar keys %pages ) {
		$logger->warn("Nie wszystkie pobrane strony są bezpośrednio podlinkowane");
	}
	return @pages;
}

1;
