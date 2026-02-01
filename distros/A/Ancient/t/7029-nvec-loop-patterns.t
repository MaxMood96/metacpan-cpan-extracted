#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';
use nvec;
use TestVec qw(is_quadmath);

if (is_quadmath()) {
    diag("Testing with quadmath (128-bit precision)");
}

# Test nvec functions with various loop variable patterns

subtest 'for with $vec' => sub {
    my @vecs = (
        nvec::new([1, 2, 3]),
        nvec::new([4, 5, 6]),
        nvec::new([7, 8, 9]),
    );

    my @sums;
    for my $vec (@vecs) {
        push @sums, $vec->sum();
    }
    is_deeply(\@sums, [6, 15, 24], 'nvec sum with $vec');
};

subtest 'for with $v' => sub {
    my @data = ([1,2], [3,4], [5,6]);
    my @means;
    for my $v (@data) {
        my $vec = nvec::new($v);
        push @means, $vec->mean();
    }
    is_deeply(\@means, [1.5, 3.5, 5.5], 'nvec mean with $v');
};

subtest 'map with $_' => sub {
    my @arrays = ([1,2,3], [4,5,6], [7,8,9]);
    my @lens = map { nvec::new($_)->len() } @arrays;
    is_deeply(\@lens, [3, 3, 3], 'nvec len with $_ in map');
};

subtest 'for with $i index' => sub {
    my $vec = nvec::new([10, 20, 30, 40, 50]);
    my @result;
    for my $i (0..4) {
        push @result, $vec->get($i);
    }
    is_deeply(\@result, [10, 20, 30, 40, 50], 'nvec get with $i');
};

subtest 'for with $idx' => sub {
    my $vec = nvec::new([1, 2, 3, 4, 5]);
    my $sum = 0;
    for my $idx (0 .. $vec->len() - 1) {
        $sum += $vec->get($idx);
    }
    is($sum, 15, 'nvec iteration with $idx');
};

subtest 'for with $row matrix' => sub {
    my @matrix = ([1,2,3], [4,5,6], [7,8,9]);
    my @row_sums;
    for my $row (@matrix) {
        my $vec = nvec::new($row);
        push @row_sums, $vec->sum();
    }
    is_deeply(\@row_sums, [6, 15, 24], 'matrix rows with $row');
};

subtest 'nested $outer/$inner' => sub {
    my @vecs;
    for my $outer (1..2) {
        for my $inner (1..3) {
            push @vecs, nvec::new([$outer * $inner]);
        }
    }

    my @sums = map { $_->sum() } @vecs;
    is_deeply(\@sums, [1, 2, 3, 2, 4, 6], 'nested nvec creation');
};

subtest 'for with $arr arrayref' => sub {
    my @arrays = ([1,1,1], [2,2,2], [3,3,3]);
    my @norms;
    for my $arr (@arrays) {
        my $vec = nvec::new($arr);
        push @norms, sprintf("%.3f", $vec->norm());
    }
    is($norms[0], '1.732', 'norm with $arr');
    is($norms[1], '3.464', 'norm with $arr');
    is($norms[2], '5.196', 'norm with $arr');
};

subtest 'for with $a and $b vectors' => sub {
    my @pairs = (
        [nvec::new([1,2]), nvec::new([3,4])],
        [nvec::new([5,6]), nvec::new([7,8])],
    );

    my @dots;
    for my $pair (@pairs) {
        my ($a, $b) = @$pair;
        push @dots, $a->dot($b);
    }
    is_deeply(\@dots, [11, 83], 'dot product with $a/$b');
};

subtest 'for with $n creating ranges' => sub {
    my @sizes = (3, 5, 7);
    my @sums;
    for my $n (@sizes) {
        my $vec = nvec::range(1, $n + 1);
        push @sums, $vec->sum();
    }
    # sum 1..3 = 6, sum 1..5 = 15, sum 1..7 = 28
    is_deeply(\@sums, [6, 15, 28], 'range sums with $n');
};

subtest 'grep with $_ on vectors' => sub {
    my @vecs = (
        nvec::new([1, 2, 3]),
        nvec::new([10, 20, 30]),
        nvec::new([5, 5, 5]),
    );

    my @high_sum = grep { $_->sum() > 10 } @vecs;
    is(scalar(@high_sum), 2, 'grep vectors with $_');
};

subtest 'for with $val element iteration' => sub {
    my $vec = nvec::new([2, 4, 6, 8, 10]);
    my @doubled;
    my $arr = $vec->to_array();
    for my $val (@$arr) {
        push @doubled, $val * 2;
    }
    is_deeply(\@doubled, [4, 8, 12, 16, 20], 'element iteration with $val');
};

done_testing();
