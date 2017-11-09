package Proc::Single;
require Exporter;

use strict;
use warnings;
use utf8;

use IO::Handle;
use Fcntl qw(:flock);

our $VERSION = 20110816;

sub new {
	my $caller = shift;
	my $class = ref($caller) || $caller;

	my $pidFile = shift;
	my $fh;

	open( $fh, '+>>', $pidFile )
	  or die "Can't open '$pidFile'\n";

	if ( !flock( $fh, LOCK_EX | LOCK_NB ) ) {
		close($fh);
		return undef;
	}

	# FIXME: check pid?

	truncate( $fh, 0 );
	seek( $fh, 0, 0 );
	$fh->autoflush(1);

	unless ( print $fh "$$\n" ) {
		close($fh);
		die "Unable to write pid to '$pidFile': $!\n";
	}

	my $this = {
		'fh'   => $fh,
		'file' => $pidFile,
	};
	bless $this, $class;
	return $this;
}

sub DESTROY {
	my $this = shift;
	close $this->{fh};

	# Reopen the file to check if lock is still in place
	open( $this->{fh}, '+<', $this->{file} )
	  or return;    # Ignore errors

	if ( flock( $this->{fh}, LOCK_EX | LOCK_NB ) ) {

		# Noone else is holding the lock, so remove the file
		unlink $this->{file};
	}

	# Close file
	close $this->{fh};
}

1;

=head1 NAME

Proc::Single - Perl extension for ensuring that only one instance of an
  application is running.

=head1 SYNOPSIS

	use Proc::Single;

	# Acquire an exclusive lock
	my $lock = Proc::Single->new("$0.pid");

	# Check if lock has been acquired
	unless (defined $lock) {
		print STDERR "Another instance is already running!\n";
		exit(1);
	}

	# Here do something which requires exclusive lock
	...

	# Release lock
	undef $lock;


=head1 DESCRIPTION

The module is based on advisory file lock mechanism provided by L<flock|perlfunc/flock>.

=head2 EXPORT

None by default.

=head1 SEE ALSO

The module is based on advisory file lock mechanism provided by L<flock|perlfunc/flock>.

=head1 AUTHOR

Szymon Świerkosz <szymek@adres.pl>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Szymon Świerkosz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
