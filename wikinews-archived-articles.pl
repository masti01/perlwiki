#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use DateTime;
use DateTime::Format::Strptime;
use Log::Any;
use MediaWiki::Parser;

my $logger  = Log::Any::get_logger;
my $year    = 2011;
my $pretend = 0;

my $bot = new Bot4;
$bot->addOption( "pretend" => \$pretend, "Do not edit wiki page" );
$bot->addOption( "year"    => \$year,    "" );
$bot->single(1);
$bot->setProject( "wikinews", "pl" );
$bot->setup;

my $api = $bot->getApi;
$api->checkAccount;

my $contentDateFormat = new DateTime::Format::Strptime(
	pattern   => '%d %b %Y',
	time_zone => 'UTC',
	locale    => 'pl_PL.utf8',
	on_error  => 'croak',
);

my $titleDateFormat = new DateTime::Format::Strptime(
	pattern   => '%Y-%m-%d',
	time_zone => 'UTC',
	locale    => 'pl_PL.utf8',
	on_error  => 'croak',
);

my $lastDate = DateTime->new(
	year       => $year,
	month      => 1,
	day        => 1,
	hour       => 0,
	minute     => 0,
	second     => 0,
	nanosecond => 0,
	time_zone  => 'UTC',
	locale     => 'pl_PL.utf8',
);

my $iterator = $api->getIterator(
	'generator'    => 'embeddedin',
	'geititle'     => 'Template:Data',
	'geilimit'     => '50',
	'geinamespace' => 0,
	'prop'         => 'revisions|info',
	'rvprop'       => 'content|timestamp',
);

my @list;
my @errors;

while ( my $page = $iterator->next ) {
	$logger->info("Sprawdzanie [[$page->{title}]]");
	eval {
		my ($revision) = values %{ $page->{revisions} };
		my @templates = grep { $_->{name} =~ /^[Dd]ata$/ } extract_templates( $revision->{'*'} );

		my %dates;
		foreach my $template (@templates) {
			next unless defined $template->{fields}->{1};
			$dates{ $template->{fields}->{1} }++;
		}

		die "Brak informacji na temat daty\n"
		  unless scalar keys %dates;

		die "Data jest niejednoznaczna\n"
		  if scalar keys %dates > 1;

		my ($date) = keys %dates;

		my $dt = $contentDateFormat->parse_datetime($date);

		if ( $dt > $lastDate ) {
			$logger->info("[[$page->{title}]] Artykuł nie jest archiwalny");
			return;
		}

		if ( $page->{title} =~ /^\d{4}-\d{2}-\d{2}: / ) {
			$logger->info("[[$page->{title}]] Strona ma datę w nazwie");
			return;
		}

		push @list,
		  {
			'old' => $page->{title},
			'new' => $titleDateFormat->format_datetime($dt) . ': ' . $page->{title},
		  };
	};
	if ($@) {
		$@ =~ s/\s+$//;
		$logger->error("[[$page->{title}]]: $@");
		push @errors, "[[$page->{title}]]: $@";
	}
}

my $i = 0;
foreach my $entry ( sort { $a->{old} cmp $b->{old} } @list ) {
	if ( $i % 3000 == 0 ) {
		print "== $i ==\n";
		print ";Strony do przeniesienia\n";
	}
	$i++;
	print "* [[$entry->{old}]] -> [[$entry->{new}]]\n";
}
print ";Problemy\n";
foreach my $error (@errors) {
	print "* $error\n";
}
