#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Future::Strict' ) || print "Bail out!\n";
}

diag( "Testing Future::Strict $Future::Strict::VERSION, Perl $], $^X" );
