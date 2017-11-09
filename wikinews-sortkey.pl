#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use DateTime;
use DateTime::Format::Strptime;
use Log::Any;
use Wiki::Page;
use Text::Diff;

my $logger  = Log::Any::get_logger;
my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend" => \$pretend, "Do not edit wiki page" );
$bot->single(1);
$bot->setProject( "wikinews", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

my $contentOldDateFormat = new DateTime::Format::Strptime(
	pattern   => '%d %b %Y',
	time_zone => 'UTC',
	locale    => 'pl_PL.utf8',
	on_error  => 'croak',
);

my $contentNewDateFormat = new DateTime::Format::Strptime(
	pattern   => '%Y-%m-%d',
	time_zone => 'UTC',
	locale    => 'pl_PL.utf8',
	on_error  => 'croak',
);

sub processPage {
	my $page = shift;
	my ($revision) = values %{ $page->{revisions} };

	my $oldContent = $revision->{'*'};
	my $newContent = $oldContent;

	my $categoryDate;

	if ( $oldContent =~ m/\{\{data\|\d\d\d\d-\d\d-\d\d\}\}/i ) {
		$logger->debug("[[$page->{title}]]: Jest już poprawiony");
		return;
	}

	my $templateRegex = qr/\{\{(?i:szablon:)?[Dd]ata\s*\|\s*(\d+ \S+ \d+)\s*(?:\|[^\|\{\}]*)?\}\}/;

	if ( $newContent =~ m/$templateRegex/ ) {
		$categoryDate = $1;
		my $date = $contentOldDateFormat->parse_datetime($1);
		my $text = $contentNewDateFormat->format_datetime($date);

		$newContent =~ s/$templateRegex/{{data|$text}}/;
	}
	else {
		$logger->info("[[$page->{title}]]: Nie udało się odnaleźć szablonu z datą");
		return;
	}

	my $p = new Wiki::Page(
		'api'     => $api,
		'title'   => $page->{title},
		'content' => $newContent,
	);
	$p->parse;

	$p->removeCategory('Archiwalne');
	$p->removeCategory($categoryDate)
	  if defined $categoryDate;

=head
	foreach my $cat ( keys %{ $p->{categories} } ) {
		$p->{categories}->{$cat} = undef;
	}
=cut

	$p->content =~ s/\{\{DEFAULTSORT:(?:[^\{\}]+|\{\{[^\{\}]+\}\})+\}\}//ig;
	die "[[$page->{title}]]: defaultsort\n"
	  if $p->{content} =~ m/DEFAULTSORT/i;

	$p->defaultSortKey = undef;

	$newContent = $p->rebuild;

	if ( $oldContent eq $newContent ) {
		$logger->debug("Strona [[$page->{title}]] nie wymaga zmian");
		return;
	}

	if ( $logger->is_info ) {
		$logger->info( "Zmiany do wprowadzenia na stronie [[$page->{title}]]:\n" . diff( \$oldContent, \$newContent ) );
	}

	#my $a = <STDIN>;
	#$pretend = !( $a =~ /[yYtT]/ );

	$api->edit(
		title          => $page->{title},
		starttimestamp => $page->{touched},
		basetimestamp  => $revision->{timestamp},
		nocreate       => 1,
		bot            => 1,
		minor          => 1,
		text           => $newContent,
		summary        => "aktualizacja kategorii oraz wywołania szablonu data",
	) unless $pretend;
}

my $iterator = $api->getIterator(
	'generator'    => 'embeddedin',
	'geititle'     => 'Template:Data',
	'geilimit'     => '50',
	'geinamespace' => 0,
	'prop'         => 'revisions|info',
	'rvprop'       => 'content|timestamp',
);

while ( my $page = $iterator->next ) {
	eval {
		$logger->debug("Sprawdzanie [[$page->{title}]]");

		unless ( $page->{ns} == 0 ) {
			$logger->debug("Strona [[$page->{title}]] nie znajduje się w przestrzeni głównej");
			return;
		}

		processPage($page);
	};
	if ($@) {
		$@ =~ s/\s+$//;
		$logger->error($@);
	}
}
