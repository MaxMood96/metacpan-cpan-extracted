#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}

use Test::LeakTrace;
use lib 'blib/lib', 'blib/arch';
use nvec;

subtest 'new does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::new([1, 2, 3, 4, 5]);
    } 'new';
};

subtest 'zeros does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::zeros(100);
    } 'zeros';
};

subtest 'ones does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::ones(100);
    } 'ones';
};

subtest 'fill does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::fill(100, 42);
    } 'fill';
};

subtest 'range does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::range(0, 100);
    } 'range';
};

subtest 'linspace does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::linspace(0, 1, 100);
    } 'linspace';
};

subtest 'get/set do not leak' => sub {
    no_leaks_ok {
        my $v = nvec::new([1, 2, 3]);
        my $x = $v->get(0);
        $v->set(1, 42);
    } 'get/set';
};

subtest 'to_array does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::new([1, 2, 3, 4, 5]);
        my $arr = $v->to_array;
    } 'to_array';
};

subtest 'add does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        my $c = $a->add($b);
    } 'add';
};

subtest 'sub does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        my $c = $a->sub($b);
    } 'sub';
};

subtest 'mul does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        my $c = $a->mul($b);
    } 'mul';
};

subtest 'div does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        my $c = $a->div($b);
    } 'div';
};

subtest 'scale does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = $a->scale(2);
    } 'scale';
};

subtest 'add_inplace does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        $a->add_inplace($b);
    } 'add_inplace';
};

subtest 'scale_inplace does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        $a->scale_inplace(2);
    } 'scale_inplace';
};

subtest 'clamp_inplace does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        $a->clamp_inplace(0, 2);
    } 'clamp_inplace';
};

subtest 'sum does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::new([1, 2, 3, 4, 5]);
        my $s = $v->sum;
    } 'sum';
};

subtest 'dot does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        my $d = $a->dot($b);
    } 'dot';
};

subtest 'norm does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::new([3, 4]);
        my $n = $v->norm;
    } 'norm';
};

subtest 'normalize does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::new([3, 4]);
        my $n = $v->normalize;
    } 'normalize';
};

subtest 'distance does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([0, 0]);
        my $b = nvec::new([3, 4]);
        my $d = $a->distance($b);
    } 'distance';
};

subtest 'cosine_similarity does not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 0]);
        my $b = nvec::new([0, 1]);
        my $c = $a->cosine_similarity($b);
    } 'cosine_similarity';
};

subtest 'chained operations do not leak' => sub {
    no_leaks_ok {
        my $a = nvec::new([1, 2, 3]);
        my $b = nvec::new([4, 5, 6]);
        my $c = $a->add($b)->scale(2)->normalize;
    } 'chained';
};

subtest 'large vector does not leak' => sub {
    no_leaks_ok {
        my $v = nvec::ones(10000);
        my $s = $v->sum;
    } 'large vector';
};

done_testing;
