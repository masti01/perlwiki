#!/usr/bin/perl -w

use MediaWiki::API;
use MediaWiki::WWW;
use strict;
use utf8;
use Data::Dumper;
use Log::Any;
use Bot4;

my $login = 'Beau';
my $pass  = '';

my $bot = new Bot4;
$bot->addOption( "login", \$login );
$bot->addOption( "pass",  \$pass );
$bot->single(1);
$bot->setProject( "wikipedia", "pl" );
$bot->setup;

my $logger = Log::Any->get_logger();

my @sites;
{
	my $api = $bot->getApi;
	my $data = $api->query( 'action' => 'sitematrix' );

	foreach my $group ( values %{ $data->{sitematrix} } ) {
		next if ref($group) ne 'HASH';
		foreach my $site ( values %{ $group->{site} } ) {
			push @sites, $site->{url};
		}
	}
}
@sites = sort @sites;

#my @sites = ("https://af.wikipedia.org/");

foreach my $url (@sites) {
	$url =~ s/^http:/https:/;
	next if $url eq 'https://pl.wikipedia.org';

	$logger->info("Changing preferences on $url");
	my $api = MediaWiki::API->new(
		'login'    => $login,
		'password' => $pass,
		'url'      => $url . "/w/api.php",
	);

	my $www = MediaWiki::WWW->new( 'url' => $url . "/w/index.php", );
	$www->{ua}->cookie_jar( $api->{ua}->cookie_jar() );

	eval {
		my $result = $api->login();
		$logger->info( "Result: " . $result->{login}->{result} );
	};
	if ($@) {
		$@ =~ s/\s+$//;
		$logger->error($@);
		next;
	}

	$www->_get( 'title' => 'Special:Preferences' );

	#next if $www->{ua}->content() =~ /The database is currently locked|This wiki has been/;
	eval {
		$www->{ua}->submit_form(    #
			form_number => 0,
			fields      => {
				'wpccmeonemails'          => '1',
				'wpcols'                  => '90',
				'wpdate'                  => 'dmy',
				'wpdiffonly'              => '1',
				'wpdisablemail'           => '1',
				'wpeditfont'              => 'default',
				'wpeditsection'           => '1',
				'wpenotifusertalkpages'   => '1',
				'wpextendwatchlist'       => '1',
				'wpflaggedrevssimpleui'   => '0',
				'wpflaggedrevsstable'     => '0',
				'wpgender'                => 'male',
				'wphighlightbroken'       => '1',
				'wpimagesize'             => '2',
				'wplanguage'              => 'pl',
				'wpmath'                  => '1',
				'wpnorollbackdiff'        => '1',
				'wppreviewontop'          => '1',
				'wprcdays'                => '7',
				'wprclimit'               => '50',
				'wprememberpassword'      => 1,
				'wprows'                  => '25',
				'wpsearcheverything '     => '1',
				'wpsearchlimit'           => '20',
				'wpServerTime'            => '1115',
				'wpshowhiddencats'        => '1',
				'wpshowjumplinks'         => '1',
				'wpshowtoc'               => '1',
				'wpshowtoolbar'           => '1',
				'wpskin'                  => 'vector',
				'wpstubthreshold'         => '0',
				'wpstubthreshold-other'   => '',
				'wpthumbsize'             => '4',
				'wptimecorrection'        => 'ZoneInfo|60|Europe/Warsaw',
				'wptimecorrection-other'  => '01:00',
				'wpunderline'             => '2',
				'wpusebetatoolbar'        => '1',
				'wpusebetatoolbar-cgd'    => '1',
				'wpuseeditwarning'        => '0',
				'wpusenewrc'              => '1',
				'wpvector-collapsiblenav' => '0',
				'wpvector-simplesearch'   => '1',
				'wpwatchcreations'        => '1',
				'wpwatchlistdays'         => '3',
				'wpwatchlisttoken'        => '67e99eb5090afcf6cd39410186a472759461148a',
				'wpwllimit'               => '250',
			},
		);
	};
	if ($@) {
		$@ =~ s/\s+$//;
		$logger->error($@);
	}
}
