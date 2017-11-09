package Wiki::Page;

use strict;
use warnings;
use Log::Any;
use MediaWiki::API;
use Data::Dumper;

my $logger = Log::Any->get_logger();

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $this = {
		'api'     => undef,
		'title'   => undef,
		'content' => undef,
		@_
	};

	unless ( $this->{collator} ) {
		require ICU::MyCollator;
		$this->{collator} = new ICU::MyCollator('pl_PL');
	}

	bless $this, $class;
	return $this;
}

sub newFromApi {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $api        = shift;
	my $page       = shift;
	my ($revision) = values %{ $page->{revisions} };

	my $this = {
		'api'     => $api,
		'title'   => $page->{title},
		'content' => $revision->{'*'},
		@_
	};

	bless $this, $class;
	return $this;
}

sub _linkfix {
	my $this = shift;

	my $link    = shift;
	my $caption = shift;

	$link =~ tr/_/ /;
	$link = trim($link) if defined $link;

	#$caption = trim($caption) if defined $caption;

	my $colon = 0;
	if ( $link =~ s/^:// ) {
		$colon = 1;
	}

	my $namespace = $this->{api}->getPageNamespace($link);

	if ( $namespace == NS_CATEGORY && !$colon ) {
		$link =~ s/^[^:]+\s*:\s*//;

		$this->_addCategory( $link, $caption );
		return '';

	}
	elsif ($namespace) {
		my $name = $this->{api}->getNamespace($namespace);
		$link =~ s/^[^:]+\s*:\s*/$name:/;
	}
	elsif ( !$colon and $link =~ /^([^:]+):/ and exists $this->{cache}->{iwmap}->{ lc($1) } ) {
		$this->_addInterwiki( $1, $link );
		return '';
	}

	if ( defined $caption and $link eq $caption ) {
		$caption = undef;
	}

	if ($colon) {
		$link = ":$link";
	}

	if ( defined $caption ) {
		return "[[$link|$caption]]";
	}
	else {
		return "[[$link]]";
	}
}

sub parse {
	my $this = shift;
	$this->{categories} = {};
	$this->{interwikis} = {};

	$this->{cache}->{iwmap} = { map { $_->{prefix} => 1 } grep { exists $_->{language} } $this->{api}->getInterwikiMap };

	#$logger->trace("IWMAP:" . Dumper($this->{cache}->{iwmap}));
	$this->{content} =~ s/\[\[([^\[|]+)\]\]/ $_ = $this->_linkfix($1) /ge;
	$this->{content} =~ s/\[\[([^\[|]+)\|([^\[|]+)\]\]/ $_ = $this->_linkfix($1, $2) /ge;
	$this->{content} =~ s/\s+$//;

	$this->{cache} = undef;

	$this->{parsed} = 1;
}

sub rebuild {
	my $this = shift;

	$this->{content} =~ s/\s+$//;
	my $collator = $this->{collator};

	if ( keys %{ $this->{categories} } ) {
		$this->{content} .= "\n";

		if ( defined $this->{defaultSortKey} ) {
			$this->{content} .= "\n{{DEFAULTSORT:$this->{defaultSortKey}}}";
		}

		my $category = $this->{api}->getNamespace(NS_CATEGORY);

		# FIXME: sortowanie nie zawsze jest dobrym pomysłem
		foreach my $name ( sort { $collator->compare( $a, $b ) } keys %{ $this->{categories} } ) {
			$this->{content} .= "\n[[$category:$name" . ( defined $this->{categories}->{$name} ? '|' . $this->{categories}->{$name} : '' ) . "]]";
		}
	}
	else {
		if ( defined $this->{defaultSortKey} ) {
			$this->{content} .= "\n\n{{DEFAULTSORT:$this->{defaultSortKey}}}";
		}
	}

	if ( keys %{ $this->{interwikis} } ) {
		$this->{content} .= "\n";

		# FIXME: sortowanie nie zawsze jest dobrym pomysłem
		foreach my $prefix ( sort { $collator->compare( $a, $b ) } keys %{ $this->{interwikis} } ) {
			$this->{content} .= "\n[[$this->{interwikis}->{$prefix}]]";
		}
	}

	$this->{parsed} = 0;
	return $this->{content};
}

sub content : lvalue {
	my $this = shift;
	$this->{content} = $_[0] if defined $_[0];
	$this->{content};
}

sub defaultSortKey : lvalue {
	my $this = shift;
	$this->_checkState;
	$this->{defaultSortKey} = $_[0] if defined $_[0];
	$this->{defaultSortKey};
}

sub removeCategory {
	my $this = shift;

	$this->_checkState;

	foreach my $category (@_) {
		delete $this->{categories}->{ $this->_normalizeTitle($category) };
	}
}

sub addCategory {
	my $this = shift;

	$this->_checkState;
	$this->_addCategory(@_);
}

sub _addCategory {
	my $this     = shift;
	my $category = shift;
	my $sortkey  = shift;

	$logger->debug("Adding category '$category'");
	$this->{categories}->{ $this->_normalizeTitle($category) } = $sortkey;
}

sub hasCategory {
	my $this     = shift;
	my $category = shift;

	return exists $this->{categories}->{ $this->_normalizeTitle($category) };
}

sub addInterwiki {
	my $this = shift;
	my $link = shift;

	$this->_checkState;

	unless ( $link =~ /^([^:]+):/ ) {
		die "Invalid interwiki link '$link'\n";
	}

	$this->_addInterwiki( $1, $link );
}

sub _addInterwiki {
	my $this   = shift;
	my $prefix = lc(shift);
	my $link   = shift;
	$logger->debug("Adding interwiki with prefix '$prefix' - $link");

	$this->{interwikis}->{$prefix} = $link;
}

sub _normalizeTitle {
	my $this  = shift;
	my $title = shift;

	# FIXME: Sprawdź, czy wielkość pierwszej litery ma znaczenie
	return ucfirst($title);
}

sub _checkState {
	my $this = shift;

	unless ( $this->{parsed} ) {
		die "Need to parse the content first\n";
	}
}

sub trim {
	my $text = shift;
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return $text;
}

1;
