#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';
use Test::More 0.82;
use lib 't/';
use Sample;

eval 'use Text::Phonetic::Phonix';
plan skip_all => 'Text::Phonetic::Phonix required for this test' if $@;

plan tests => 14;

sub a2n { return [ map { $_->name( ) } @{ $_[0] } ]; }

my $tube = new_ok( 'Sample' );
my $ret;

diag( "*** Expect many messages saying 'Negative repeat count does nothing at ...' -- ignore these, please! *** \n",
      "*** (They are coming from Text::Phonetic::Phonix. They are ugly but functionally harmless.)           ***" );

$ret = $tube->fuzzy_find( 'Bakerloo', objects => 'lines', method => 'phonix' );
is( $ret, 'Bakerloo', 'Finding line Bakerloo based on Phonix' );

$ret = $tube->fuzzy_find( 'Bakl', objects => 'lines', method => 'phonix' );
is( $ret, 'Bakerloo', 'Finding line Bakl based on Phonix' );

$ret = $tube->fuzzy_find( 'Bxqxq', objects => 'lines', method => 'phonix' );
is( $ret, undef, 'Finding line Bxqxq based on Phonix should fail' );

$ret = [ $tube->fuzzy_find( 'Bakerloo', objects => 'lines', method => 'phonix' ) ];
is_deeply( $ret, [ 'Bakerloo' ], 'Finding many lines Bakerloo based on Phonix' );

$ret = [ $tube->fuzzy_find( 'Bakl', objects => 'lines', method => 'phonix' ) ];
is_deeply( $ret, [ 'Bakerloo' ], 'Finding many lines Bakl based on Phonix' );

$ret = [ $tube->fuzzy_find( 'Bxqxq', objects => 'lines', method => 'phonix' ) ];
is_deeply( $ret, [ ], 'Finding many lines Bxqxq based on Phonix should fail' );

$ret = $tube->fuzzy_find( 'Baker Street', objects => 'stations', method => 'phonix' );
ok( $ret, 'Finding station Baker Street based on Phonix' );
is( $ret->name(), 'Baker Street', 'Finding station Baker Street based on Phonix' );

$ret = $tube->fuzzy_find( 'Bakestrt', objects => 'stations', method => 'phonix' );
ok( $ret, 'Finding station Bakestrt based on Phonix' );
is( $ret->name(), 'Baker Street', 'Finding station Bakestrt based on Phonix' );

$ret = $tube->fuzzy_find( 'Bxqxq', objects => 'stations', method => 'phonix' );
is( $ret, undef, 'Finding station Bxqxq based on Phonix should fail' );

$ret = [ $tube->fuzzy_find( 'Bakestrt', objects => 'stations', method => 'phonix' ) ];
is_deeply( a2n($ret), [ 'Baker Street' ], 'Finding many stations Bakestrt based on Phonix' );

$ret = [ $tube->fuzzy_find( 'Bxqxq', objects => 'stations', method => 'phonix' ) ];
is_deeply( $ret, [ ], 'Finding many stations Bxqxq based on Phonix should fail' );

