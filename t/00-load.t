#!perl

use Test::More tests => 1;

BEGIN {
	use_ok( 'Getopt::Chain' );
}

diag( "Testing Getopt::Chain $Getopt::Chain::VERSION, Perl $], $^X" );
