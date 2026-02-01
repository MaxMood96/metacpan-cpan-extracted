#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use noop 'noop';

# Warmup
for (1..10) {
    noop();
    noop::noop();
}

subtest 'noop direct call no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            noop();
        }
    } 'noop direct call does not leak';
};

subtest 'noop::noop no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            noop::noop();
        }
    } 'noop::noop does not leak';
};

subtest 'noop with args no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            noop(1, 2, 3, "string", { hash => 1 });
        }
    } 'noop with args does not leak';
};

subtest 'noop as callback no leak' => sub {
    my $cb = \&noop;
    no_leaks_ok {
        for (1..1000) {
            $cb->();
            $cb->(42);
        }
    } 'noop as callback does not leak';
};

subtest 'noop via full package name no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            noop::noop(1, 2, 3);
        }
    } 'noop via full package name does not leak';
};

done_testing();
