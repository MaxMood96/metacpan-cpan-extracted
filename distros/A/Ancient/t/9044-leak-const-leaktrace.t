#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use const qw/all/;

# Warmup
for (1..10) {
    my $x = const::c(42);
    my $y = const::c({ a => 1 });
}

# ============================================
# Basic c() operations
# ============================================

subtest 'c(scalar) no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = const::c(42);
        }
    } 'c(scalar) does not leak';
};

subtest 'c(string) no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = const::c("hello world constant");
        }
    } 'c(string) does not leak';
};

subtest 'c(float) no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = const::c(3.14159);
        }
    } 'c(float) does not leak';
};

subtest 'c(undef) no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = const::c(undef);
        }
    } 'c(undef) does not leak';
};

# ============================================
# Reference types
# ============================================

subtest 'c(arrayref) no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $x = const::c([1, 2, 3, 4, 5]);
        }
    } 'c(arrayref) does not leak';
};

subtest 'c(hashref) no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $x = const::c({ a => 1, b => 2, c => 3 });
        }
    } 'c(hashref) does not leak';
};

subtest 'c(nested) no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $x = const::c({
                arr => [1, 2, 3],
                hash => { deep => { deeper => 'value' } },
                mixed => [{ a => 1 }, { b => 2 }]
            });
        }
    } 'c(nested) does not leak';
};

# ============================================
# const() function
# ============================================

subtest 'const scalar no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            const my $x => 42;
        }
    } 'const scalar does not leak';
};

subtest 'const array no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            const my @arr => (1, 2, 3, 4, 5);
        }
    } 'const array does not leak';
};

subtest 'const hash no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            const my %h => (a => 1, b => 2, c => 3);
        }
    } 'const hash does not leak';
};

# ============================================
# make_readonly operations
# ============================================

subtest 'make_readonly scalar no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = 42;
            make_readonly($x);
        }
    } 'make_readonly scalar does not leak';
};

subtest 'make_readonly arrayref no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $x = [1, 2, 3, 4, 5];
            make_readonly($x);
        }
    } 'make_readonly arrayref does not leak';
};

subtest 'make_readonly hashref no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $x = { a => 1, b => 2, c => 3 };
            make_readonly($x);
        }
    } 'make_readonly hashref does not leak';
};

# ============================================
# make_readonly_ref
# ============================================

subtest 'make_readonly_ref no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $ref = const::make_readonly_ref({ a => 1, b => [2, 3] });
        }
    } 'make_readonly_ref does not leak';
};

# ============================================
# unmake_readonly
# ============================================

subtest 'unmake_readonly scalar no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = 42;
            make_readonly($x);
            unmake_readonly($x);
        }
    } 'unmake_readonly scalar does not leak';
};

subtest 'unmake_readonly ref no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $x = { a => [1, 2, 3] };
            make_readonly($x);
            unmake_readonly($x);
        }
    } 'unmake_readonly ref does not leak';
};

# ============================================
# is_readonly
# ============================================

subtest 'is_readonly on const no leak' => sub {
    my $x = const::c(42);
    no_leaks_ok {
        for (1..500) {
            my $r = is_readonly($x);
        }
    } 'is_readonly on const does not leak';
};

subtest 'is_readonly on non-const no leak' => sub {
    my $x = 42;
    no_leaks_ok {
        for (1..500) {
            my $r = is_readonly($x);
        }
    } 'is_readonly on non-const does not leak';
};

subtest 'is_readonly on ref no leak' => sub {
    my $x = const::c({ a => 1 });
    no_leaks_ok {
        for (1..500) {
            my $r = is_readonly($x);
        }
    } 'is_readonly on ref does not leak';
};

# ============================================
# Deep structures
# ============================================

subtest 'deeply nested no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $x = const::c({
                l1 => {
                    l2 => {
                        l3 => {
                            l4 => [1, 2, { l5 => 'deep' }]
                        }
                    }
                }
            });
        }
    } 'deeply nested does not leak';
};

subtest 'large array no leak' => sub {
    no_leaks_ok {
        for (1..20) {
            my $x = const::c([1..100]);
        }
    } 'large array does not leak';
};

subtest 'large hash no leak' => sub {
    no_leaks_ok {
        for (1..20) {
            my %h = map { ("key$_" => "val$_") } 1..50;
            my $x = const::c(\%h);
        }
    } 'large hash does not leak';
};

# ============================================
# Edge cases
# ============================================

subtest 'empty arrayref no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = const::c([]);
        }
    } 'empty arrayref does not leak';
};

subtest 'empty hashref no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $x = const::c({});
        }
    } 'empty hashref does not leak';
};

subtest 'mixed types in array no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $x = const::c([1, "str", 3.14, undef, [1,2], {a=>1}]);
        }
    } 'mixed types does not leak';
};

done_testing();
