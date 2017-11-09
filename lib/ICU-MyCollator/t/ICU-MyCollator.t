# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl ICU-MyCollator.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
BEGIN { use_ok('ICU::MyCollator') }

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use utf8;
my $collator = new ICU::MyCollator( "pl", "pl" );

ok( $collator, "Contructed instance of class" );

is( $collator->compare( 'a', 'b' ),  'a' cmp 'b', "a cmp b" );
is( $collator->compare( 'a', 'A' ),  'a' cmp 'A', "a cmp A" );
is( $collator->compare( 'a', 'ą' ), 'a' cmp 'b', "a cmp ą" );
