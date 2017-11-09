#!/usr/bin/perl -w

use strict;
use utf8;
use Bot4;
use Data::Dumper;
use Mail::Sendmail;
use File::Spec;

my $logger = Log::Any::get_logger;

my $bot = new Bot4;
$bot->single(1);
$bot->setup;

my $logs = $bot->{paths}{logs};

opendir( my $dh, $logs ) or die "Cannot open directory '$logs': $!\n";
my @errors;
while ( my $file = readdir($dh) ) {
	next unless $file =~ /\.log$/;
	$logger->info("Checking $file");
	open( my $fh, '<', File::Spec->join( $logs, $file ) ) or die "Cannot open file '$file': $!\n";
	while ( my $line = <$fh> ) {
		next unless $line =~ /\s(?:ERROR|FATAL)\s/;
		next if $line =~ /504 Gateway Time-out/;
		$line =~ s/\s+$//;
		push @errors, "$file: $line";
	}
	close($fh);
}
closedir($dh);

if (@errors) {
	$logger->info("Found errors, sending an e-mail");
	no warnings;
	my %mail = (
		'To'           => 'beau@adres.pl',
		'From'         => 'beau@tools.wikimedia.pl',
		'Subject'      => 'Sprawdz działanie bota - lista błędów',
		'Content-Type' => 'text/plain;charset="utf-8"',
		'Message'      => "Lista błędów z logów:\n" . join( "\n", @errors ),
	);

	foreach my $key ( keys %mail ) {
		utf8::encode( $mail{$key} );
	}
	sendmail(%mail) or die $Mail::Sendmail::error;
}
else {
	$logger->info("No errors has been found");
}

# perltidy -et=8 -l=0 -i=8
