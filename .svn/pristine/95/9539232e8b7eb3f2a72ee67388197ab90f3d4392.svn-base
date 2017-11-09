#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;
use Data::Dumper;
use DateTime;
use DateTime::Format::Strptime;
use DBI;
use Env;
use RipeInetnumDb;

my $timezone = 'UTC';
my $format   = 'wiki';
my $isp      = undef;

my %formats = (    #
	'wiki' => 'Format::Wiki',
	'text' => 'Format::Text',
);

my %isps = (       #
	'orange' => qr/PL-IDEA-MOBILE/,
	'play'   => qr/P4NET|Playonline/,
);

my $bot = new Bot4;
$bot->single(1);
$bot->addOption( "timezone=s", \$timezone, "Changes timezone" );
$bot->addOption( "format=s",   \$format,   "Changes format" );
$bot->addOption( "isp=s",      \$isp,      "Filter edits by ISP" );
$bot->setup;

die "Unknown format\n"
  unless defined $formats{$format};

my $filter = sub { return 1; };

if ( defined $isp ) {
	my $regex = $isps{$isp};
	die "Unknown isp\n"
	  unless defined $regex;

	my $ripeDb = new RipeInetnumDb(    #
		'index'    => 'var/ripe.db.inetnum.index',
		'database' => 'var/ripe.db.inetnum',
	);

	$filter = sub {
		my $row = shift;
		if ( $row->{rev_user_text} =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
			my @whois = $ripeDb->lookup( $row->{rev_user_text} );
			my $whois = $whois[-1]
			  if @whois;

			return 0
			  unless defined $whois;

			return 1 if $whois =~ $regex;
		}
		return 0;
	};
}

my $formatter = $formats{$format}->new();

my $logger = Log::Any->get_logger();
my $dbh    = DBI->connect(             #
	"DBI:mysql:database=wikimedia;mysql_read_default_group=wikibot;mysql_read_default_file=$ENV{HOME}/.my.cnf",
	undef,
	undef,
	{ RaiseError => 1, 'mysql_enable_utf8' => 1 }
) or die "Can't connect to database...\n";

my $dateParser = new DateTime::Format::Strptime(
	pattern   => '%Y-%m-%d %T',
	time_zone => 'UTC',
	on_error  => 'croak',
);

sub getProjects {
	my $selectProjects = $dbh->prepare("SELECT project_id id, project_name name FROM projects");
	$selectProjects->execute();
	my %result;
	while ( my $row = $selectProjects->fetchrow_hashref ) {
		$result{ $row->{id} } = $row->{name};
	}
	return %result;
}

my %projects = getProjects();

my $selectEdits = $dbh->prepare("SELECT * FROM revisions LEFT JOIN abusers_edits ON (rev_pk = ae_edit) WHERE ae_confirmed = 1 ORDER BY rev_timestamp DESC");
$selectEdits->execute();

$formatter->printHeader;
while ( my $row = $selectEdits->fetchrow_hashref ) {
	foreach ( %{$row} ) {
		utf8::decode($_);
	}

	next unless $filter->($row);

	$row->{project} = $projects{ $row->{rev_project} };

	my $dt = $dateParser->parse_datetime( $row->{rev_timestamp} );
	$dt->set_time_zone($timezone);
	$row->{timestamp} = $dt;

	$formatter->printEntry($row);
}
$formatter->printFooter;

package Format::Text;
use strict;
use warnings;

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = { @_, };
	bless $this, $class;

	return $this;
}

sub printHeader {
	print << "EOF";
Data ($timezone)\tAdres\tEdycja
EOF

}

sub printEntry {
	my $this = shift;
	my $row  = shift;

	my $indexLink = "https://$row->{project}.org/w/index.php";

	# FIXME: używać rev_parent_id jeśli zdefiniowane
	my $diffLink = "$indexLink?diff=prev&oldid=$row->{rev_id}";

	my $localtime;
	if ( $timezone ne 'UTC' ) {
		$localtime = $row->{timestamp}->strftime('%Y-%m-%d %H:%M:%S');
	}
	else {
		$localtime = $row->{rev_timestamp};
	}

	print << "EOF";
$localtime\t$row->{rev_user_text}\t$diffLink
EOF

}

sub printFooter {

}

1;

package Format::Wiki;
use strict;
use warnings;
use URI::Escape qw(uri_escape_utf8);

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = { @_, };
	bless $this, $class;

	return $this;
}

sub printHeader {
	print << "EOF";
{| class="wikitable sortable"
! Data<br/><small>($timezone)</small>
! Adres IP
! Strona
! Projekt
EOF

	# ! style="width: 50%" | Komentarz

}

sub printEntry {
	my $this = shift;
	my $row  = shift;

	my $indexLink = "//$row->{project}.org/w/index.php";

	# FIXME: używać rev_parent_id jeśli zdefiniowane
	my $diffLink = "$indexLink?diff=prev&oldid=$row->{rev_id}";

	my $localtime;
	if ( $timezone ne 'UTC' ) {
		$localtime = $row->{timestamp}->strftime('%Y-%m-%d %H:%M:%S');
	}
	else {
		$localtime = $row->{rev_timestamp};
	}

	my $comment = defined $row->{rev_comment} ? "<nowiki>$row->{rev_comment}</nowiki>" : "''komentarz został ukryty''";

	my $titleLink   = "$indexLink?title=" . uri_escape_utf8( $row->{rev_page} );
	my $contribLink = "$indexLink?title=Special:Contribs/" . uri_escape_utf8( $row->{rev_user_text} );

	print << "EOF";
|-
| [$diffLink <span style="white-space:nowrap;">$localtime</span>]
| [$contribLink $row->{rev_user_text}]
| [$titleLink $row->{rev_page}]
| $row->{project}
EOF

	# | $comment

}

sub printFooter {
	print "|}\n";
}

1;
