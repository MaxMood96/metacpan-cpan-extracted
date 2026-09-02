#!/usr/bin/env perl
use v5.38;
use lib ( '../lib', 'lib' );
use Test2::V0 '!call';
use Logic::Relational::Program;
use Logic::Relational::DSL qw(variable call);

# 1. Test basic all and all_values in list context
my $p1 = Logic::Relational::Program->new;
$p1->fact( item => 'apple' );
$p1->fact( item => 'banana' );
$p1->fact( item => 'cherry' );

my $item_var = variable('item');
my $q1       = $p1->query( call( item => $item_var ) );

my @sols1 = $q1->all;
is( scalar(@sols1), 3, '$q->all returns 3 solution objects in list context' );

my $q1_v       = $p1->query( call( item => $item_var ) );
my @items_list = $q1_v->all_values($item_var);
is(
    \@items_list,
    [ 'apple', 'banana', 'cherry' ],
    '$q->all_values returns list of reified values'
);

# 2. Test scalar context (array reference)
my $q2       = $p1->query( call( item => $item_var ) );
my $sols_ref = $q2->all;
is( ref($sols_ref),     'ARRAY', '$q->all returns arrayref in scalar context' );
is( scalar(@$sols_ref), 3,       'Arrayref contains 3 solution objects' );

my $q2_v      = $p1->query( call( item => $item_var ) );
my $items_ref = $q2_v->all_values($item_var);
is(
    $items_ref,
    [ 'apple', 'banana', 'cherry' ],
    '$q->all_values returns arrayref in scalar context'
);

# 3. Test limit parameter on Infinite Generator
my $p3        = Logic::Relational::Program->new;
my $gen_count = 0;
$p3->generator(
    'counter', 1,
    sub ($x) {
        return sub {
            $gen_count++;
            return [$gen_count];
        };
    }
);

my $val_var = variable('val');
my $q3      = $p3->query( call( counter => $val_var ) );

my @limited = $q3->all_values( $val_var, limit => 5 );
is(
    \@limited,
    [ 1, 2, 3, 4, 5 ],
    'limit => 5 caps infinite generator at 5 solutions'
);

# 4. Test empty solution set
my $q4    = $p1->query( call( item => 'dragonfruit' ) );
my @sols4 = $q4->all;
is( scalar(@sols4), 0, 'all on unmatchable goal returns empty list' );

my $q4_v  = $p1->query( call( item => 'dragonfruit' ) );
my @vals4 = $q4_v->all_values($item_var);
is( scalar(@vals4), 0, 'all_values on unmatchable goal returns empty list' );

# 5. Test first_value and value methods
my $q5_1 = $p1->query( call( item => $item_var ) );
is( $q5_1->first_value($item_var), 'apple', 'first_value returns first solution scalar' );

my $q5_2 = $p1->query( call( item => $item_var ) );
is( $q5_2->value($item_var), 'apple', 'value alias returns first solution scalar' );

done_testing;
