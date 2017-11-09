sub extract_templates($) {
	my $data = shift @_;

	my $open  = '{{';
	my $close = '}}';

	my @templates = $data =~ /$open((?:[^\{\}]*(?:$open.*?$close)?)*)$close/og;
	my @results;

	while ( scalar(@templates) ) {
		my $template = shift @templates;
		my %infobox;
		my ( $name, $content ) = $template =~ /^\s*(.+?)\s*(?:\|(.*?)|)$/s;
		$infobox{'name'}   = $name;
		$infobox{'fields'} = {};
		$infobox{'order'}  = [];
		my $argc = 0;
		$content .= '|';
		#my @items = $content =~ /((?:[^\|\{\}\[\]]+(?:\{\{[^\{\}]*\}\}|\[{1,2}[^\[\]]*\]{1,2}|))+)(?:\||$)/sg;
		my @items = $content =~ /((?:[^\|\{\}\[\]]*(?:\{\{[^\{\}]*\}\}|\[{1,2}[^\[\]]*\]{1,2}|))+)\|/sg;    # fajny regexp
		                                                                                                    #pop(@items);
		while ( scalar(@items) ) {
			my $item = shift @items;

			#if ( $item =~ /^\s*([^= ]+)\s*=[ \t]*(.*?)\s*$/s )
			if ( $item =~ /^\s*([^=]+?)\s*=[ \t]*(.*?)\s*$/s ) {
				$infobox{'fields'}{$1} = $2;
				push @{ $infobox{'order'} }, $1;
			}
			else {
				$argc++;
				$infobox{'fields'}{$argc} = $item;
				push @{ $infobox{'order'} }, $argc;
			}
		}
		push @results, \%infobox;
	}
	return @results;
}

sub infobox_regenerate {
	my $data    = shift;
	my $padding = shift;
	$padding ||= 0;
	my $result = "{{$data->{name}\n";
	foreach my $name ( @{ $data->{order} } ) {
		my $value = $data->{fields}->{$name};
		$value = '' unless defined $value;
		$name .= ' ' x ( $padding - length($name) ) if length($name) < $padding;
		$result .= "| $name = $value\n";
	}
	$result .= "}}";
	return $result;
}

sub rebuild_templates {
	my $result = '';
	foreach my $item (@_) {
		$result .= "{{$item->{name}";
		foreach my $field ( keys %{ $item->{fields} } ) {
			$result .= "\n| $field = $item->{fields}->{$field}";
		}
		$result .= "}}";
	}
	return $result;
}

package MediaWiki::Parser::Simple;

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'position' => 0,
		'content'  => $_[0],
	};

	bless $this, $class;
	return $this;
}

my %prefixes = (
	'[' => \&_parse_link,

	#'{' => \&_parse_template,
	#'<' => \&_parse_tag,
);

sub parse {
	my $this = shift;
	$this->{length} = length( $this->{content} );

	my @result;
	my $text = '';
	while ( $this->{position} < $this->{length} ) {
		my $char    = $this->_next_char;
		my $handler = $prefixes{$char};
		if ( defined $handler ) {
			my @r = &$handler( $this, $text );
			if ( scalar @r ) {
				if ( $text ne '' ) {
					push @result,
					  {
						'type'    => 'text',
						'content' => $text,
					  };
					$text = '';
				}
				push @result, @r;
			}
		}
		else {
			$text .= $char;
		}
	}
	return @result;
}

sub _next_char {
	my $this = shift;
	return undef unless $this->{position} < $this->{length};
	return substr( $this->{content}, $this->{position}++, 1 );
}

sub _back {
	my $this = shift;
	my $count = defined $_[0] ? $_[0] : 1;
	$this->{position} -= $count;
	die if $this->{position} < 0;
}

sub _parse_link {
	my $this = shift;
	my $unparsed = substr( $this->{content}, $this->{position} - 1 );

	if ( $unparsed =~ m/^(\[\[(?:Kategoria|Category):([^\n\[\]\{\}\|]+)(?:\|([^\n\[\]\{\}]+))?\]\])/i ) {
		my $raw  = $1;
		my $link = $2;
		my $key  = $3;

		$link =~ s/^\s+//;
		$link =~ s/\s+$//;

		if ( $link eq '' ) {
			$_[0] .= '[';
			return;
		}
		my $result = {
			'type' => 'category',
			'name' => $link,
			'raw'  => $raw,
		};
		$result->{key} = $key if defined $key;
		$this->{position} += length($raw);
		return ($result);
	}
	elsif ( $unparsed =~ m/^(\[\[([^\n\[\]\{\}\|]+)(?:\|([^\n\[\]\{\}]+))?\]\])/ ) {
		my $raw     = $1;
		my $link    = $2;
		my $caption = $3;
		$link =~ s/^\s+//;
		$link =~ s/\s+$//;

		if ( $link eq '' ) {
			$_[0] .= '[';
			return;
		}
		my $result = {
			'type' => 'link',
			'link' => $link,
			'raw'  => $raw,
		};
		if ( defined $caption ) {
			$caption =~ s/^\s+//;
			$caption =~ s/\s+$//;
			$result->{caption} = $caption;
		}
		$this->{position} += length($raw);
		return ($result);
	}
	else {
		$_[0] .= '[';
		return;
	}
}

sub _parse_template {
	my $this = shift;

}

sub _parse_tag {

}

sub _parse_comment {
	my $this = shift;

}

sub _parse_nowiki {
	my $this = shift;

}

1;

# perltidy -et=8 -l=0 -i=8
