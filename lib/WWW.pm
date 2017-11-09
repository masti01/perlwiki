use lib "/usr/home/beau/tools/lib";
use lib "/home/szymek/wiki/tools/lib";

package Template::Provider::utf8;

use base qw(Template::Provider);

sub _load {
	my $self = shift;

	my ( $data, $error ) = $self->SUPER::_load(@_);

	if ( defined $data ) {
		utf8::decode( $data->{text} );
	}

	return ( $data, $error );
}

package WWW;

sub render {
	use Template;
	my ( $name, $vars ) = @_;

	my $template = Template->new(
		LOAD_TEMPLATES => [ Template::Provider::utf8->new( INCLUDE_PATH => '/home/szymek/wiki/tools/www/templates_tt/:/usr/home/beau/www/templates_tt' ) ],

	);

	my $result;
	$template->process( $name, $vars, \$result )
	  || die "Template process failed: ", $template->error(), "\n";
	return $result;
}

sub output {
	binmode STDOUT, ":utf8";
	print "Content-type: text/html; charset=utf-8\n\n" . render(@_);
}

1;

# perltidy -et=8 -l=0 -i=8
