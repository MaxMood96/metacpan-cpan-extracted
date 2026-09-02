#!/usr/bin/env perl
use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Syntax;

logic StdLibTest {
    # No user rules needed; StdLib auto-injected
}

# 1. append
query StdLibTest::append( [ 1, 2 ], [ 3, 4 ], fresh my $app_res )->my $q1;
my $sol1 = $q1->next;
ok( $sol1, 'append concatenation succeeded' );
is( $sol1->value($app_res), [ 1, 2, 3, 4 ], 'append concatenated correctly' );

# 2. member
query StdLibTest::member( fresh my $m, [ 'a', 'b', 'c' ] )->my $q2;
my @members;
while ( my $s = $q2->next ) {
    push @members, $s->value($m);
}
is( \@members, [ 'a', 'b', 'c' ], 'member generated all elements' );

# 3. length
query StdLibTest::length( [ 10, 20, 30, 40 ], fresh my $len )->my $q3;
my $sol3 = $q3->next;
ok( $sol3, 'length succeeded' );
is( $sol3->value($len), 4, 'length calculated 4' );

# 4. reverse
query StdLibTest::reverse( [ 1, 2, 3 ], fresh my $rev )->my $q4;
my $sol4 = $q4->next;
ok( $sol4, 'reverse succeeded' );
is( $sol4->value($rev), [ 3, 2, 1 ], 'reverse reversed array correctly' );

# 5. select
query StdLibTest::select( 'b', [ 'a', 'b', 'c' ], fresh my $rest )->my $q5;
my $sol5 = $q5->next;
ok( $sol5, 'select succeeded' );
is( $sol5->value($rest), [ 'a', 'c' ], 'select extracted element correctly' );

# 6. permutation
query StdLibTest::permutation( [ 1, 2 ], fresh my $p )->my $q6;
my @perms;
while ( my $s = $q6->next ) {
    push @perms, $s->value($p);
}
is( \@perms, [ [ 1, 2 ], [ 2, 1 ] ], 'permutation generated all permutations' );

# 7. succ, min, max
query StdLibTest::succ( 10, fresh my $next_num )->my $q7;
is( $q7->next->value($next_num), 11, 'succ(10) = 11' );

query StdLibTest::min( 15, 7, fresh my $min_val )->my $q8;
is( $q8->next->value($min_val), 7, 'min(15, 7) = 7' );

query StdLibTest::max( 15, 7, fresh my $max_val )->my $q9;
is( $q9->next->value($max_val), 15, 'max(15, 7) = 15' );

# 8. between
query StdLibTest::between( 1, 3, fresh my $b )->my $q10;
my @between_vals;
while ( my $s = $q10->next ) {
    push @between_vals, $s->value($b);
}
is( \@between_vals, [ 1, 2, 3 ], 'between generated range 1..3' );

done_testing;
