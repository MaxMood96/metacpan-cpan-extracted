#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;

# 1. Test basic Family logic program syntax compiling and running
logic Family {
    fact parent( 'alice', 'bob' );
    fact parent( 'bob',   'carol' );

    rule ancestor( $x, $y ) {
        parent( $x, $y );
    }

    rule ancestor( $x, $y ) {
        fresh my $z;
        parent( $x, $z );
        ancestor( $z, $y );
    }
}

# Run query
query Family::ancestor( 'alice', fresh my $descendant )->my $q;

my @results;
while ( my $sol = $q->next ) {
    push @results, $sol->value($descendant);
}

is( \@results, [ 'bob', 'carol' ], 'Family ancestors resolved correctly' );

# 2. Test disjunction (either/or), negation (not), and domain constraints ($x in 1..9)
logic MathPuzzle {
    rule solve( $x, $y ) {
        $x in 1 .. 5;
        $y in 1 .. 5;
        either {
            unify( $x, 2 );
        }
        or {
            unify( $x, 3 );
        }
        label( $x, $y );
        not {
            unify( $x, $y );
        }
    }
}

query MathPuzzle::solve( fresh my $aa, fresh my $bb )->my $q_math;

my @math_sols;
while ( my $sol = $q_math->next ) {
    push @math_sols, [ $sol->value($aa), $sol->value($bb) ];
}

# The results should have x=2 or x=3, and y in 1..5 but y != x.
# For x=2: y can be 1, 3, 4, 5.
# For x=3: y can be 1, 2, 4, 5.
is( scalar @math_sols,
    8, 'MathPuzzle correctly resolved 8 disjunction/negation solutions' );

ok( ( grep { $_->[0] == 2 && $_->[1] == 1 } @math_sols ),
    'Contains solution [2, 1]' );
ok(
    !( grep { $_->[0] == $_->[1] } @math_sols ),
    'Contains no solution where a == b'
);

# 3. Test facts { ... } block syntax
logic GroupedFacts {
    facts {
        user( 'alice', 28, 'active' );
        user( 'bob',   15, 'active' );
    }
}

query GroupedFacts::user( fresh my $uname, fresh my $uage, fresh my $ustatus )->my $q_users;

my @grouped_users;
while ( my $sol = $q_users->next ) {
    push @grouped_users, $sol->value($uname);
}
is( \@grouped_users, [ 'alice', 'bob' ], 'facts block parsed facts correctly' );

# 4. Test multi-branch either ... or ... or ... disjunction
logic MultiOrTest {
    rule solve( $x ) {
        either {
            unify( $x, 'first' );
        }
        or {
            unify( $x, 'second' );
        }
        or {
            unify( $x, 'third' );
        }
    }
}

query MultiOrTest::solve( fresh my $choice )->my $q_multi;

my @choices;
while ( my $sol = $q_multi->next ) {
    push @choices, $sol->value($choice);
}
is(
    \@choices,
    [ 'first', 'second', 'third' ],
    'Multi-branch either/or/or parsed and evaluated correctly'
);

# 5. Test infix := unification operator
logic InfixUnifyTest {
    rule assign_values( $x, $y ) {
        $x := 'hello';
        $y := [ 1, 2, 3 ];
    }
}

query InfixUnifyTest::assign_values( fresh my $val1, fresh my $val2 )->my $q_infix;

my $sol_infix = $q_infix->next;
ok( $sol_infix, 'Infix := unification query succeeded' );
is( $sol_infix->value($val1), 'hello',     'Infix := bound scalar correctly' );
is( $sol_infix->value($val2), [ 1, 2, 3 ], 'Infix := bound array correctly' );

# 6. Test combined fresh my (...) in MIN..MAX declaration and constraint
logic CombinedFreshDomain {
    rule solve($x, $y) {
        fresh my ($a, $b) in 1..3;
        $x := $a;
        $y := $b;
        label($a, $b);
    }
}

query CombinedFreshDomain::solve( fresh my $r1, fresh my $r2 )->my $q_comb;

my @comb_sols;
while ( my $sol = $q_comb->next ) {
    push @comb_sols, [ $sol->value($r1), $sol->value($r2) ];
}
is( scalar @comb_sols,
    9, 'Combined fresh my ($a, $b) in 1..3 constrained domains correctly' );

# 7. Test discrete list domain constraint: $x in [1, 4, 9, 16]
logic DiscreteDomainTest {
    rule solve($sq) {
        fresh my $val in [1, 4, 9, 16];
        $sq := $val;
        label($val);
    }
}

query DiscreteDomainTest::solve( fresh my $res )->my $q_disc;

my @disc_sols;
while ( my $sol = $q_disc->next ) {
    push @disc_sols, $sol->value($res);
}
is(
    \@disc_sols,
    [ 1, 4, 9, 16 ],
    'Discrete list domain $x in [1, 4, 9, 16] evaluated correctly'
);

done_testing;
