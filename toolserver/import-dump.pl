#!/usr/bin/perl -w

use strict;
use IO::Handle;
use Env;
use LWP::UserAgent;
use Data::Dumper;
use Getopt::Long;

my $database;
my $host;
my $user;
my $wiki;
my $date;
my $dir;

GetOptions(
	"database|d=s" => \$database,
	"host|h=s"     => \$host,
	"user|u=s"     => \$user,
	"wiki=s"       => \$wiki,
	"date=s"       => \$date,
	"dir=s"        => \$dir,

);

$host     = 'localhost'              unless defined $host;
$user     = 'beau'                   unless defined $user;
$wiki     = 'plwiki'                 unless defined $wiki;
$date     = '20100307'               unless defined $date;
$database = "beau"                   unless defined $database;
$dir      = "./$wiki-$date"          unless defined $dir;

my @smallFiles = qw(
  image.sql.gz
  oldimage.sql.gz
  site_stats.sql.gz
  interwiki.sql.gz
  user_groups.sql.gz
  category.sql.gz
  page_restrictions.sql.gz
  page_props.sql.gz
  protected_titles.sql.gz
  redirect.sql.gz
);

my @links = qw(
  categorylinks.sql.gz
  imagelinks.sql.gz
  templatelinks.sql.gz
  externallinks.sql.gz
  langlinks.sql.gz
  pagelinks.sql.gz
);

@links      = map { "$wiki-$date-$_" } @links;
@smallFiles = map { "$wiki-$date-$_" } @smallFiles;

mkdir($dir) unless -e $dir;
chdir($dir) or die $!;

STDOUT->autoflush(1);

my %sqlCreateTable;
my %sqlCreateIndex;

$sqlCreateTable{pagelinks} = << 'EOF';
CREATE TABLE /*_*/pagelinks (
  pl_from int unsigned NOT NULL default 0,
  pl_namespace int NOT NULL default 0,
  pl_title varchar(255) binary NOT NULL default ''
) TYPE=InnoDB;
EOF

$sqlCreateIndex{pagelinks} = << 'EOF';
ALTER TABLE pagelinks
  ADD UNIQUE KEY `pl_from` (`pl_from`,`pl_namespace`,`pl_title`),
  ADD UNIQUE KEY `pl_namespace` (`pl_namespace`,`pl_title`,`pl_from`);
EOF

$sqlCreateTable{categorylinks} = << 'EOF';
CREATE TABLE /*_*/categorylinks (
  cl_from int unsigned NOT NULL default 0,
  cl_to varchar(255) binary NOT NULL default '',
  cl_sortkey varchar(70) binary NOT NULL default '',
  cl_timestamp timestamp NOT NULL
) TYPE=InnoDB;
EOF

$sqlCreateIndex{categorylinks} = << 'EOF';
ALTER TABLE categorylinks
  ADD UNIQUE KEY `cl_from` (`cl_from`,`cl_to`),
  ADD KEY `cl_sortkey` (`cl_to`,`cl_sortkey`,`cl_from`),
  ADD KEY `cl_timestamp` (`cl_to`,`cl_timestamp`);
EOF

$sqlCreateTable{externallinks} = << 'EOF';
CREATE TABLE /*_*/externallinks (
  el_from int unsigned NOT NULL default 0,
  el_to blob NOT NULL,
  el_index blob NOT NULL
) TYPE=InnoDB;
EOF

$sqlCreateIndex{externallinks} = << 'EOF';
ALTER TABLE externallinks
  ADD KEY `el_from` (`el_from`,`el_to`(40)),
  ADD KEY `el_to` (`el_to`(60),`el_from`),
  ADD KEY `el_index` (`el_index`(60));
EOF

$sqlCreateTable{imagelinks} = << 'EOF';
CREATE TABLE /*_*/imagelinks (
  il_from int unsigned NOT NULL default 0,
  il_to varchar(255) binary NOT NULL default ''
) TYPE=InnoDB;
EOF

$sqlCreateIndex{imagelinks} = << 'EOF';
ALTER TABLE imagelinks
  ADD UNIQUE KEY `il_from` (`il_from`,`il_to`),
  ADD UNIQUE KEY `il_to` (`il_to`,`il_from`);
EOF

$sqlCreateTable{langlinks} = << 'EOF';
CREATE TABLE /*_*/langlinks (
  ll_from int unsigned NOT NULL default 0,
  ll_lang varbinary(20) NOT NULL default '',
  ll_title varchar(255) binary NOT NULL default ''
) TYPE=InnoDB;
EOF

$sqlCreateIndex{langlinks} = << 'EOF';
ALTER TABLE langlinks
  ADD UNIQUE KEY `ll_from` (`ll_from`,`ll_lang`),
  ADD KEY `ll_lang` (`ll_lang`,`ll_title`);
EOF

$sqlCreateTable{templatelinks} = << 'EOF';
CREATE TABLE /*_*/templatelinks (
  tl_from int unsigned NOT NULL default 0,
  tl_namespace int NOT NULL default 0,
  tl_title varchar(255) binary NOT NULL default ''
) TYPE=InnoDB;
EOF

$sqlCreateIndex{templatelinks} = << 'EOF';
ALTER TABLE templatelinks
  ADD UNIQUE KEY `tl_from` (`tl_from`,`tl_namespace`,`tl_title`),
  ADD UNIQUE KEY `tl_namespace` (`tl_namespace`,`tl_title`,`tl_from`);
EOF

$sqlCreateTable{page} = << 'EOF';
CREATE TABLE IF NOT EXISTS `page` (
  `page_id` int(10) unsigned NOT NULL,
  `page_namespace` int(11) NOT NULL,
  `page_title` varchar(255) binary NOT NULL,
  `page_restrictions` tinyblob NOT NULL,
  `page_counter` bigint(20) unsigned NOT NULL default '0',
  `page_is_redirect` tinyint(3) unsigned NOT NULL default '0',
  `page_is_new` tinyint(3) unsigned NOT NULL default '0',
  `page_random` double unsigned NOT NULL,
  `page_touched` binary(14) NOT NULL default '\0\0\0\0\0\0\0\0\0\0\0\0\0\0',
  `page_latest` int(10) unsigned NOT NULL,
  `page_len` int(10) unsigned NOT NULL
) TYPE=InnoDB;
EOF

$sqlCreateIndex{page} = << 'EOF';
ALTER TABLE `page`
  CHANGE `page_id` `page_id` INT( 10 ) UNSIGNED NOT NULL AUTO_INCREMENT,
  ADD PRIMARY KEY  (`page_id`),
  ADD UNIQUE KEY `name_title` (`page_namespace`,`page_title`),
  ADD KEY `page_random` (`page_random`),
  ADD KEY `page_len` (`page_len`);
EOF

$sqlCreateTable{revision} = << 'EOF';
CREATE TABLE IF NOT EXISTS `revision` (
  `rev_id` int(10) unsigned NOT NULL,
  `rev_page` int(10) unsigned NOT NULL,
  `rev_text_id` int(10) unsigned NOT NULL,
  `rev_comment` tinyblob NOT NULL,
  `rev_user` int(10) unsigned NOT NULL default '0',
  `rev_user_text` varchar(255) binary NOT NULL default '',
  `rev_timestamp` binary(14) NOT NULL default '\0\0\0\0\0\0\0\0\0\0\0\0\0\0',
  `rev_minor_edit` tinyint(3) unsigned NOT NULL default '0',
  `rev_deleted` tinyint(3) unsigned NOT NULL default '0',
  `rev_len` int(10) unsigned default NULL,
  `rev_parent_id` int(10) unsigned default NULL
) TYPE=InnoDB;
EOF

$sqlCreateIndex{revision} = << 'EOF';
ALTER TABLE `revision`
  CHANGE `rev_id` `rev_id` INT( 10 ) UNSIGNED NOT NULL AUTO_INCREMENT,
  ADD PRIMARY KEY  (`rev_id`),
  ADD UNIQUE KEY `rev_page_id` (`rev_page`,`rev_id`),
  ADD KEY `rev_timestamp` (`rev_timestamp`),
  ADD KEY `page_timestamp` (`rev_page`,`rev_timestamp`),
  ADD KEY `user_timestamp` (`rev_user`,`rev_timestamp`),
  ADD KEY `usertext_timestamp` (`rev_user_text`,`rev_timestamp`);
EOF

$sqlCreateTable{text} = << 'EOF';
CREATE TABLE IF NOT EXISTS `text` (
  `old_id` int(10) unsigned NOT NULL,
  `old_text` mediumblob NOT NULL,
  `old_flags` tinyblob NOT NULL
) TYPE=InnoDB;
EOF

$sqlCreateIndex{text} = << 'EOF';
ALTER TABLE `text`
  CHANGE `old_id` `old_id` INT( 10 ) UNSIGNED NOT NULL AUTO_INCREMENT,
  ADD PRIMARY KEY  (`old_id`);
EOF

sub download {
	my @files = @_;
	my $ua    = LWP::UserAgent->new(
		'agent'   => 'download-dump.pl',
		'timeout' => 60,
	);

	my %checksums;
	{
		my $response = $ua->get("http://download.wikimedia.org/$wiki/$date/$wiki-$date-md5sums.txt");
		die $response->status_line unless $response->is_success;
		my @content = split "\n", $response->decoded_content( charset => 'none' );
		foreach my $line (@content) {
			die unless $line =~ /^(\S+)\s+(\S+)$/;
			$checksums{$2} = $1;
		}
	}
	print "Downloading database dump\n";
	$0 = "Downloading database dump";

	foreach my $file (@files) {
		$0 = "Downloading database dump: $file";
		system( 'wget', '-c', "http://download.wikimedia.org/$wiki/$date/$file" );
	}

	print "Veryfing downloads\n";
	$0 = "Veryfing downloads";
	open( my $fh, '|-', 'md5sum', '-c' ) or die $!;

	foreach my $file (@files) {
		die "There is no checksum for $file\n" unless exists $checksums{$file};
		print $fh "$checksums{$file}  $file\n";
	}
	close($fh);
	wait;
}

sub importLinks($) {
	my $name = shift;
	open( my $dest, '|-', 'mysql', '-h', $host, '-u', $user, '-D', $database ) or die $!;
	open( my $source, '-|', 'zcat', $name ) or die $!;

	my $table;

	while ( my $line = <$source> ) {
		print $dest $line;

		if ( $line =~ /^-- Table structure for table `(.+?)`$/ ) {
			$table = $1;
			last;
		}
		die "Missed injection point\n" if $line =~ /^INSERT/i;
	}

	while ( my $line = <$source> ) {
		if ( $line =~ /^-- Dumping data for table `(.+?)`$/ ) {
			last;
		}
		die "Missed injection point\n" if $line =~ /^INSERT/i;
	}

	print "Creating table $table...\n";
	die unless exists $sqlCreateTable{$table};
	die unless exists $sqlCreateIndex{$table};

	print $dest "DROP TABLE IF EXISTS `$table`;";
	print $dest $sqlCreateTable{$table};

	print "Inserting rows...\n";
	while ( my $line = <$source> ) {
		print $dest $line;
	}
	close($source);

	print "Creating indices for $table...\n";
	print $dest $sqlCreateIndex{$table};
	close($dest);
	wait;
}

sub importRevisions($) {
	my $name = shift;

	print "Importing revisions\n";

	open( my $dest, '|-', 'mysql', '-h', $host, '-u', $user, '-D', $database ) or die $!;

	foreach my $table ( 'revision', 'text', 'page' ) {
		print $dest $sqlCreateTable{$table};
	}

	open( my $source, '-|', 'java', '-jar', 'mwdumper-1.16.jar', '--format=sql:1.5', $name ) or die $!;
	while ( my $line = <$source> ) {
		print $dest $line;
	}
	close($source);
	print "Creating indices...\n";
	foreach my $table ( 'revision', 'page' ) {
		print $dest $sqlCreateIndex{$table};
	}
	close($dest);
	wait;
}

download(@smallFiles);
foreach my $name (@smallFiles) {
	print "Importing $name...\n";
	system("zcat $name | mysql -h '$host' -u '$user' -D '$database'");
}

download(@links);
foreach my $name (@links) {
	importLinks($name);
}

download("$wiki-$date-stub-meta-history.xml.gz");
importRevisions("$wiki-$date-stub-meta-history.xml.gz");

__END__
#  pages-meta-current.xml.bz2
#  pages-logging.xml.gz
#  page.sql.gz

# perltidy -et=8 -l=0 -i=8
