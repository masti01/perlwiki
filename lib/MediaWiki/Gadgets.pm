package MediaWiki::Gadgets;

sub parse {
	my $content = shift;
	my @gadgets;

	my $section = undef;

	foreach my $line ( split "\n", $content ) {
		if ( $line =~ /^=+\s*(.+?)\s*=+$/ ) {
			$section = $1;
			next;
		}
		next unless $line =~ s/^\*\s*//;
		$line =~ s/\s*([\[\]\|])\s*/$1/g;

		my ( $name, $attributes, $files ) = $line =~ /^\s*([^\|\[\]]+)(?:\[(.+?)\])?((?:\|[^\|]+?)*)\s*$/;
		$name =~ tr/_/ /;
		my @files;
		if ( defined $files ) {
			$files =~ tr/_/ /;
			$files =~ s/^\|//;
			@files = split /\|/, $files;
		}
		my %attributes;
		if ( defined $attributes ) {
			foreach my $entry ( split /\|/, $attributes ) {
				if ( $entry =~ /^([^=]+)=(.+?)$/ ) {
					$attributes{$1} = $2;
				}
				else {
					$attributes{$entry} = 1;
				}
			}
		}

		my %gadget = (
			'name'       => $name,
			'section'    => $section,
			'attributes' => \%attributes,
			'files'      => \@files,
		);

		push @gadgets, \%gadget;
	}
	return @gadgets;
}

1;

# perltidy -et=8 -l=0 -i=8
