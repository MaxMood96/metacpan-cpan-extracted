#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0 '!call';
no warnings 'redefine';
no warnings 'prototype';
use Logic::Relational qw(variable call all);
use Logic::Relational::Program;
use feature 'try';
no warnings 'experimental::try';

# 1. Simple static generator
my $p = Logic::Relational::Program->new;
$p->generator(
    'my_relation',
    2,
    sub ( $x, $y ) {
        my @candidates = ( [ 'alice', 10 ], [ 'bob', 20 ], [ 'charlie', 30 ] );
        return sub {
            return shift @candidates;
        };
    }
);

my $who = variable('who');
my $val = variable('val');
my $q1  = $p->query( call( my_relation => $who, $val ) );

my @sols;
while ( my $sol = $q1->next ) {
    push @sols, [ $sol->value($who), $sol->value($val) ];
}

is(
    \@sols,
    [ [ 'alice', 10 ], [ 'bob', 20 ], [ 'charlie', 30 ] ],
    'Generative relation yields all candidates'
);

# 2. Input-sensitive generator (optimizes if argument is bound)
my $p2        = Logic::Relational::Program->new;
my $called_db = 0;
$p2->generator(
    'db_lookup',
    2,
    sub ( $id, $name ) {
        if ( defined $id && !ref($id) ) {

            # Optimized lookup by ID
            $called_db++;
            my @res = ( [ $id, 'alice' ] );
            return sub { return shift @res };
        }
        else {
            # Scan all
            $called_db += 10;
            my @res = ( [ 1, 'alice' ], [ 2, 'bob' ] );
            return sub { return shift @res };
        }
    }
);

# Bound query
my $q_bound = $p2->query( call( db_lookup => 1, $who ) );
my $sol_b   = $q_bound->next;
is( $sol_b->value($who), 'alice', 'Bound query yields name' );
is( $called_db,          1,       'Optimized lookup called once' );

# Unbound query
$called_db = 0;
my $id    = variable('id');
my $q_unb = $p2->query( call( db_lookup => $id, $who ) );
my @unb_res;
while ( my $sol = $q_unb->next ) {
    push @unb_res, [ $sol->value($id), $sol->value($who) ];
}
is( \@unb_res,  [ [ 1, 'alice' ], [ 2, 'bob' ] ], 'Unbound query yields all' );
is( $called_db, 10,                               'Full scan path called' );

# 3. Backtracking integration
my $p3 = Logic::Relational::Program->new;
$p3->generator(
    'gen_nums',
    1,
    sub ($n) {
        my @nums = ( [1], [2], [3], [4] );
        return sub { return shift @nums };
    }
);
$p3->fact( is_even => 2 );
$p3->fact( is_even => 4 );

my $num = variable('num');
my $q3 = $p3->query( all( call( gen_nums => $num ), call( is_even => $num ) ) );
my @even_sols;
while ( my $sol = $q3->next ) {
    push @even_sols, $sol->value($num);
}
is( \@even_sols, [ 2, 4 ], 'Backtracking between generator and fact succeeds' );

# 4. Error validation
my $p4 = Logic::Relational::Program->new;
$p4->generator( 'bad_gen', 1, sub ($n) { return 'not a coderef' } );

my $q4 = $p4->query( call( bad_gen => $num ) );
my $ok = 0;
try {
    $q4->next;
}
catch ($e) {
    like(
        $e,
        qr/did \s+ not \s+ return \s+ a \s+ coderef \s+ iterator/x,
        'Bad generator throws error'
    );
    $ok = 1;
}
ok( $ok, 'Error caught successfully' );

done_testing;
