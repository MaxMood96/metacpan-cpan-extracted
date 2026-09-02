#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational qw(variable unify rest slurp);
use feature 'try';
no warnings 'experimental::try';

# 1. Simple exact hash unification
my $s1 = unify( { a => 1, b => 2 }, { a => 1, b => 2 } );
ok( $s1, 'Simple identical hashes unify' );

my $s2 = unify( { a => 1, b => 2 }, { a => 1, b => 3 } );
ok( !$s2, 'Different hash values fail' );

my $s3 = unify( { a => 1, b => 2 }, { a => 1 } );
ok( !$s3, 'Different key sets fail' );

# 2. Variable bindings
my $x  = variable('X');
my $y  = variable('Y');
my $s4 = unify( { name => $x, age => 30 }, { name => 'Alice', age => $y } );
ok( $s4, 'Hash unification binds variables' );
is( $s4->walk($x), 'Alice', 'X is bound to Alice' );
is( $s4->walk($y), 30,      'Y is bound to 30' );

# 3. slurp/rest subset matching
my $tail = variable('Tail');
my $s5   = unify(
    { name => 'Alice', rest => slurp($tail) },
    { name => 'Alice', age  => 30, city => 'London' }
);
ok( $s5, 'slurp subset matching succeeds' );
is(
    $s5->reify($tail),
    { age => 30, city => 'London' },
    'tail binds remaining key-value pairs'
);

my $s6 =
  unify( { name => 'Alice', rest => slurp($tail) }, { name => 'Alice' } );
ok( $s6, 'slurp matching empty remainder succeeds' );
is( $s6->reify($tail), {}, 'tail is empty hash' );

# 4. Error on multiple slurps
my $s7 = 0;
try {
    unify( { a => slurp( variable('V1') ), b => slurp( variable('V2') ) },
        { a => 1, b => 2 } );
    $s7 = 1;
}
catch ($e) {
    like(
        $e,
        qr/Only \s+ one \s+ slurp\/rest/x,
        'Multiple slurps throws error'
    );
}
is( $s7, 0, 'Multiple slurps constraint enforced' );

# 5. Nested mixed structures
my $sub_var = variable('Sub');
my $s8      = unify(
    { name => 'Alice', tags => [ 'admin', $sub_var ] },
    { name => 'Alice', tags => [ 'admin', 'user' ] }
);
ok( $s8, 'Nested array inside hash unifies' );
is( $s8->walk($sub_var), 'user', 'Sub variable bound in nested array' );

my $s9 = unify(
    [ { id => 1, name => $x },      { id => 2, name => 'Bob' } ],
    [ { id => 1, name => 'Alice' }, { id => 2, name => 'Bob' } ]
);
ok( $s9, 'Array of hashes unifies' );
is( $s9->walk($x), 'Alice', 'Variable bound inside hash inside array' );

# 6. Occurs check inside nested hashes
my $s10 = 0;
try {
    unify( $x, { val => $x }, Logic::Relational::Substitution->new );
    $s10 = 1;
}
catch ($e) {
    like(
        $e,
        qr/Occurs \s+ check \s+ failed/x,
        'Occurs check fails on nested hash'
    );
}
is( $s10, 0, 'Occurs check inside hash enforced' );

done_testing;
