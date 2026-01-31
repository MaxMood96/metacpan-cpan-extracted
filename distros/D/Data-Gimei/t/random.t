use 5.010;
use strict;
use warnings;

use Data::Gimei::Random;

use Test2::V1 -utf8;
use Test2::Tools::Spec;

describe "Data::Gimei::Random" => sub {

    it "omitted seed" => sub {
        my $r = Data::Gimei::Random->new;    # default seed: time()

        T2->ok( defined( $r->seed ),         'seed is initialized' );
        T2->ok( defined( $r->next_int(42) ), 'next_int() returns a value' );
    };

    it "initialized with single argument (seed)" => sub {
        my $seed = 42;
        my $r    = Data::Gimei::Random->new($seed);    # set seed

        T2->is( $r->seed, $seed, 'seed is initialized' );
        T2->ok( defined( $r->next_int(42) ), 'next_int() returns a value' );
    };

    it "initialized with named argument (seed)" => sub {
        my $seed = 42;
        my $r    = Data::Gimei::Random->new( seed => $seed );    # set seed

        T2->is( $r->seed, $seed, 'seed is initialized' );
        T2->ok( defined( $r->next_int(42) ), 'next_int() returns a value' );
    };

    it "set_seed() method" => sub {
        my $seed = 42;
        my $r    = Data::Gimei::Random->new( $seed + 1 );        # different seed

        T2->isnt( $r->seed, $seed, 'initial seed is different' );
        $r->set_seed($seed);
        T2->is( $r->seed, $seed, 'set_seed() sets seed correctly' );
    };

    it "Deterministic output of next_int() method" => sub {
        my ( $seed, $size ) = ( 42, 1024 );

        my $r        = Data::Gimei::Random->new($seed);
        my $expected = $r->next_int($size);

        $r->set_seed($seed);
        T2->is( $r->next_int($size), $expected, 'produces deterministic output' );
    };

    it "sample() method" => sub {
        use List::Util qw( any );

        my $r   = Data::Gimei::Random->new(42);
        my @arr = ( 1, 2, 3, 4, 5 );

        T2->ok(
            ( any { $r->sample( \@arr ) == $_ } @arr ),
            'sample() method returns an element from the array'
        );
    };
};

T2->done_testing();
