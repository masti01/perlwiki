#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Log::Any;
use Data::Dumper;
use Mail::Sendmail;

my $logger = Log::Any->get_logger();

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

sub scanCookie {
	my ( undef, $key, undef, undef, $domain, undef, undef, undef, $expires, undef ) = @_;
	return unless defined $expires;
	my $diff = $expires - time();
	my $days = int( $diff / ( 24 * 3600 ) );

	die "Ciastko $key wygasło!\n"                     if $days < 1;
	die "Ciastko $key wygaśnie w ciągu $days dni!\n" if $days < 3;
}

my @accounts;

# FIXME: umieścić to w pliku konfiguracyjnym
push @accounts, $bot->getApi( "wiktionary", "pl" );
push @accounts, $bot->getApi( "wikisource", "pl" );
push @accounts, $bot->getApi( "wikipedia",  "pl" );
push @accounts, $bot->getApi( "wikipedia",  "pl", "sysop" );

eval {
	foreach my $acc (@accounts)
	{
		my $jar = $acc->{ua}->cookie_jar();
		$jar->load();
		$jar->scan( \&scanCookie );

		$acc->checkAccount;
	}
};

if ($@) {
	$logger->warn($@);

	no warnings;
	my %mail = (

		# FIXME: umieścić to w pliku konfiguracyjnym
		'To'           => 'beau@adres.pl',
		'From'         => 'beau@tools.wikimedia.pl',
		'Subject'      => 'Sprawdź ciastka dla bota!',
		'Content-Type' => 'text/plain;charset="utf-8"',
		'Message'      => $@,
	);

	foreach my $key ( keys %mail ) {
		utf8::encode( $mail{$key} );
	}
	sendmail(%mail) or die $Mail::Sendmail::error;
}

# perltidy -et=8 -l=0 -i=8
