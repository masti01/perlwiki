#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Text::Diff;
use Data::Dumper;
use MediaWiki::Gadgets;
use Digest::SHA1 qw(sha1_hex);
use DBI;
use WWW;
use URI::Escape;
use POSIX qw(strftime);

my $db  = 'var/gadgets-list.sqlite';
my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $logger = Log::Any::get_logger;
$logger->info("Start");

unlink($db);
my $time = time();
my $dbh = DBI->connect( "dbi:SQLite:dbname=$db", "", "", { RaiseError => 1, PrintError => 0 } );

my @projects = (    #
	{           #
		'family' => 'wikipedia',
		'lang'   => 'pl',
		'prefix' => '',
	},
	{           #
		'family' => 'wikisource',
		'lang'   => 'pl',
		'prefix' => 's',
	},
	{           #
		'family' => 'wikibooks',
		'lang'   => 'pl',
		'prefix' => 'b',
	},
	{           #
		'family' => 'wiktionary',
		'lang'   => 'pl',
		'prefix' => 'wikt',
	},
	{           #
		'family' => 'wikinews',
		'lang'   => 'pl',
		'prefix' => 'n',
	},
	{           #
		'family' => 'wikiquote',
		'lang'   => 'pl',
		'prefix' => 'q',
	},
);

sub createTables {
	my $query = << 'EOF';
CREATE TABLE IF NOT EXISTS project (
	project_id INTEGER NOT NULL PRIMARY KEY,
	project_family TEXT NOT NULL,
	project_lang TEXT NOT NULL
)
EOF

	$dbh->do($query);
	$dbh->do('CREATE UNIQUE INDEX IF NOT EXISTS project_name ON project (project_family, project_lang)');

	$query = << 'EOF';
CREATE TABLE IF NOT EXISTS page (
	page_id INTEGER NOT NULL PRIMARY KEY,
	page_project INTEGER NOT NULL,
	page_ns INTEGER NOT NULL,
	page_title TEXT NOT NULL,
	page_checksum TEXT NOT NULL,
	page_content BLOB
)
EOF

	$dbh->do($query);
	$dbh->do('CREATE UNIQUE INDEX IF NOT EXISTS page_name ON page (page_ns, page_title, page_project)');

	$query = << 'EOF';
CREATE TABLE IF NOT EXISTS gadget (
	gadget_id INTEGER NOT NULL PRIMARY KEY,
	gadget_project INTEGER NOT NULL,
	gadget_name TEXT NOT NULL,
	gadget_section TEXT NOT NULL,
	gadget_hidden BOOLEAN,
	gadget_default BOOLEAN,
	gadget_rl BOOLEAN,
	gadget_rl_dependencies TEXT,
	gadget_rights TEXT,
	gadget_files TEXT
)
EOF

	$dbh->do($query);
	$dbh->do('CREATE UNIQUE INDEX IF NOT EXISTS gadget_name_project ON gadget (gadget_name, gadget_project)');

}

sub fetchData {
	my $insertProject = $dbh->prepare('INSERT INTO project(project_family, project_lang) VALUES(?, ?)');
	my $insertPage    = $dbh->prepare('INSERT INTO page(page_project, page_ns, page_title, page_checksum, page_content) VALUES(?, ?, ?, ?, ?)');

	foreach my $project (@projects) {
		$logger->info("Downloading pages from $project->{lang}.$project->{family}...");

		my $api = $bot->getApi( $project->{family}, $project->{lang} );
		$api->checkAccount;

		$insertProject->execute( $project->{family}, $project->{lang} );
		$project->{id} = $dbh->last_insert_id( "", "", "", "" );

		my $iterator = $api->getIterator(
			'generator'    => 'allpages',
			'gaplimit'     => '20',
			'gapnamespace' => NS_MEDIAWIKI,
			'prop'         => 'revisions',
			'rvprop'       => 'content',
		);

		$dbh->begin_work;
		while ( my $page = $iterator->next ) {
			$page->{title} =~ s/^[^:]+://;

			my ($revision) = values %{ $page->{revisions} };
			my $checksum = sha1_hex( $revision->{'*'} );

			$insertPage->execute( $project->{id}, $page->{ns}, $page->{title}, $checksum, $revision->{'*'} );
		}
		$dbh->commit;
	}
}

sub readGadgets {
	my $selectDefinitions = $dbh->prepare('SELECT page_project, page_content FROM page WHERE page_ns = ? AND page_title = ?');
	$selectDefinitions->execute( NS_MEDIAWIKI, 'Gadgets-definition' );

	my $insertGadget = $dbh->prepare( '
INSERT INTO gadget (
	gadget_project,
	gadget_name,
	gadget_section,
	gadget_hidden,
	gadget_default,
	gadget_rl,
	gadget_rl_dependencies,
	gadget_rights,
	gadget_files
    )
    VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)' );

	$dbh->begin_work;
	while ( my $row = $selectDefinitions->fetchrow_hashref ) {
		utf8::decode( $row->{page_content} );
		foreach my $gadget ( MediaWiki::Gadgets::parse( $row->{page_content} ) ) {
			my @args;
			push @args, $row->{page_project};
			push @args, $gadget->{name};
			push @args, $gadget->{section} || '';
			push @args, $gadget->{attributes}->{hidden} ? 1 : 0;
			push @args, $gadget->{attributes}->{default} ? 1 : 0;
			push @args, $gadget->{attributes}->{ResourceLoader} ? 1 : 0;
			my $rl_dependencies = $gadget->{attributes}->{dependencies} || '';
			$rl_dependencies =~ s/\s*,\s*/,/g;
			push @args, $rl_dependencies;
			my $rights = $gadget->{attributes}->{rights} || '';
			$rights =~ s/\s*,\s*/,/g;
			push @args, $rights;
			push @args, join( '|', @{ $gadget->{files} } );
			$insertGadget->execute(@args);
		}
	}
	$dbh->commit;
}

sub generateGadgetReport {
	my $selectPage    = $dbh->prepare('SELECT page_checksum FROM page WHERE page_project = ? AND page_ns = ? AND page_title = ?');
	my $selectGadgets = $dbh->prepare('SELECT * FROM gadget');
	$selectGadgets->execute();

	my %gadgets;
	while ( my $row = $selectGadgets->fetchrow_hashref ) {
		$gadgets{ $row->{gadget_name} }{ $row->{gadget_project} } = $row;
	}

	my @gadgets;
	foreach my $name ( sort keys %gadgets ) {
		my %entry;
		$entry{name} = $name;

		my %groups;
		my %lastGroupId;

		my $getGroup = sub {
			my ( $name, $content ) = @_;

			if ( defined $groups{$name}{$content} ) {
				return $groups{$name}{$content};
			}
			else {
				my $result = ++$lastGroupId{$name};
				$groups{$name}{$content} = $result;
				return $result;
			}
		};

		my %files;
		foreach my $project_id ( keys %{ $gadgets{$name} } ) {
			my $gadget = $gadgets{$name}{$project_id};
			foreach my $file ( split( /\|/, $gadget->{gadget_files} ), $name ) {
				$selectPage->execute( $project_id, NS_MEDIAWIKI, 'Gadget-' . $file );
				if ( my $row = $selectPage->fetchrow_hashref ) {
					$files{$file}{$project_id} = $row->{page_checksum};
				}
				else {
					$files{$file}{$project_id} = '';
				}
			}
		}
		$entry{files} = [];
		foreach my $file ( $name, grep { $_ ne $name } sort keys %files ) {
			push @{ $entry{files} },
			  {
				name => $file,
				data => [],
			  };
		}

		for ( my $i = 1 ; $i <= @projects ; $i++ ) {
			my $gadget = $gadgets{$name}{$i};
			if ( !defined $gadget ) {
				push @{ $entry{rl} },      undef;
				push @{ $entry{hidden} },  undef;
				push @{ $entry{default} }, undef;

				push @{ $entry{section} },
				  {
					value => undef,
					group => 0,
				  };

				push @{ $entry{rl_dependencies} },
				  {
					value => [],
					group => 0,
				  };
				push @{ $entry{rights} },
				  {
					value => [],
					group => 0,
				  };

			}
			else {
				push @{ $entry{rl} },      $gadget->{gadget_rl};
				push @{ $entry{hidden} },  $gadget->{gadget_hidden};
				push @{ $entry{default} }, $gadget->{gadget_default};

				push @{ $entry{section} },
				  {
					value => $gadget->{gadget_section},
					group => &{$getGroup}( 'section', $gadget->{gadget_section} ),
				  };

				push @{ $entry{rl_dependencies} },
				  {
					value => [ split( ',',                    $gadget->{gadget_rl_dependencies} ) ],
					group => &{$getGroup}( 'rl_dependencies', $gadget->{gadget_rl_dependencies} ),
				  };

				push @{ $entry{rights} },
				  {
					value => [ split( ',',           $gadget->{gadget_rights} ) ],
					group => &{$getGroup}( 'rights', $gadget->{gadget_rights} ),
				  };
			}
			my $project = $projects[ $i - 1 ];
			foreach my $file ( @{ $entry{files} } ) {
				my $value = $files{ $file->{name} }{$i};

				my $link = "https://$project->{lang}.$project->{family}.org/w/index.php?action=edit&title=" . URI::Escape::uri_escape_utf8( 'Mediawiki:Gadget-' . $file->{name} );

				if ( !defined $value ) {
					push @{ $file->{data} },
					  {
						value => undef,
						group => 0,
						link  => $link,
					  };
				}
				else {
					push @{ $file->{data} },
					  {
						value => $value eq '' ? 0 : 1,
						group => &{$getGroup}( 'file-' . $file->{name}, $value ),
						link  => $link,
					  };
				}
			}
		}
		push @gadgets, \%entry;
	}

	#print Dumper \@gadgets;
	my $vars = {    #
		gadgets   => \@gadgets,
		timestamp => strftime( "%Y-%m-%d %T", localtime($time) ),
	};

	writeFile( 'var/gadgets.html', WWW::render( 'gadgets.tt', $vars ) );

}

createTables;
fetchData;
readGadgets;
generateGadgetReport;
