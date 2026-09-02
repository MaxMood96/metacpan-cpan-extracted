#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational qw(variable unify rest slurp);
use feature 'try';
no warnings 'experimental::try';

# 1. Simple array unification
my $s1 = unify( [ 1, 2 ], [ 1, 2 ] );
ok( $s1, 'Simple identical arrays unify' );

my $s2 = unify( [ 1, 2 ], [ 1, 3 ] );
ok( !$s2, 'Different array elements fail' );

my $s3 = unify( [ 1, 2 ], [ 1, 2, 3 ] );
ok( !$s3, 'Different array lengths fail' );

# 2. Variable bindings
my $x  = variable('X');
my $y  = variable('Y');
my $s4 = unify( [ $x, 2 ], [ 1, $y ] );
ok( $s4, 'Array unification binds variables' );
is( $s4->walk($x), 1, 'X is bound to 1' );
is( $s4->walk($y), 2, 'Y is bound to 2' );

# 3. rest/slurp tail matching
my $tail = variable('Tail');
my $s5   = unify( [ 1, 2, rest($tail) ], [ 1, 2, 3, 4 ] );
ok( $s5, 'rest tail matching succeeds' );
is( $s5->reify($tail), [ 3, 4 ], 'tail is bound to remainder array slice' );

my $s6 = unify( [ 1, 2, slurp($tail) ], [ 1, 2 ] );
ok( $s6, 'slurp tail matching with empty remainder succeeds' );
is( $s6->reify($tail), [], 'tail is bound to empty array' );

# 4. rest/slurp non-tail validation
my $s7 = 0;
try {
    unify( [ 1, rest($tail), 3 ], [ 1, 2, 3 ] );
    $s7 = 1;
}
catch ($e) {
    like( $e, qr/must be the last element/, 'Non-tail rest throws error' );
}
is( $s7, 0, 'Non-tail rest check enforced' );

# 5. Nested arrays
my $s8 = unify( [ 1, [ 2, $x ] ], [ 1, [ 2, 3 ] ] );
ok( $s8, 'Nested arrays unify' );
is( $s8->walk($x), 3, 'Nested variable bound correctly' );

# 6. Occurs check inside nested arrays
my $s9 = 0;
try {
    unify( $x, [ 1, $x ], Logic::Relational::Substitution->new );
    $s9 = 1;
}
catch ($e) {
    like( $e, qr/Occurs check failed/, 'Occurs check fails on nested array' );
}
is( $s9, 0, 'Nested array occurs check enforced' );

done_testing;
