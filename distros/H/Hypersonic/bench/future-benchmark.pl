#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(:all);
use Time::HiRes qw(time);
use lib 'lib';
use lib 'blib/lib';
use lib 'blib/arch';

# ============================================================================
# Benchmark: Future::XS vs Hypersonic::Future
# ============================================================================
#
# Tests basic Future operations that work on both implementations.
# Note: Future::XS 0.15 requires wrap_cb for callback methods which
# may not work without proper Future integration, so we focus on
# core operations: new, done, fail, is_ready, is_done, result
# ============================================================================

print "=" x 70, "\n";
print "Future Benchmark: Future::XS vs Hypersonic::Future\n";
print "=" x 70, "\n\n";

# Try to load both modules
my $has_future_xs = eval { 
    require Future;
    require Future::XS; 
    1 
};
my $has_hypersonic = eval { require Hypersonic::Future; 1 };

unless ($has_future_xs) {
    print "WARNING: Future::XS not available, install with: cpanm Future::XS\n";
}

unless ($has_hypersonic) {
    die "ERROR: Hypersonic::Future not available. Run from Hypersonic directory.\n";
}

# Pre-compile Hypersonic::Future
print "Compiling Hypersonic::Future JIT...\n";
Hypersonic::Future->compile();
print "JIT compilation complete.\n\n";

# Use time-based benchmarking
my $bench_time = $ENV{BENCH_TIME} || 2;  # seconds
print "Running each test for $bench_time CPU seconds...\n";
print "(Set BENCH_TIME env var to change)\n\n";

if ($has_future_xs) {
    print "Future::XS version: $Future::XS::VERSION\n";
}
print "Hypersonic::Future version: $Hypersonic::Future::VERSION\n\n";

# ============================================================================
# Test 1: new() - Create pending future
# ============================================================================
print "-" x 70, "\n";
print "Test 1: new() - Create pending future\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my $f = Future::XS->new;
        },
        'Hypersonic::Future' => sub {
            my $f = Hypersonic::Future->new;
        },
    });
} else {
    timethis(-$bench_time, sub {
        my $f = Hypersonic::Future->new;
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 2: new + done() - Create and resolve
# ============================================================================
print "-" x 70, "\n";
print "Test 2: new() + done() - Create and resolve\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my $f = Future::XS->new;
            $f->done('result');
        },
        'Hypersonic::Future' => sub {
            my $f = Hypersonic::Future->new;
            $f->done('result');
        },
    });
} else {
    timethis(-$bench_time, sub {
        my $f = Hypersonic::Future->new;
        $f->done('result');
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 3: new + fail() - Create and fail
# ============================================================================
print "-" x 70, "\n";
print "Test 3: new() + fail() - Create and fail\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my $f = Future::XS->new;
            $f->fail('error', 'category');
        },
        'Hypersonic::Future' => sub {
            my $f = Hypersonic::Future->new;
            $f->fail('error', 'category');
        },
    });
} else {
    timethis(-$bench_time, sub {
        my $f = Hypersonic::Future->new;
        $f->fail('error', 'category');
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 4: is_ready/is_done state checks on resolved future
# ============================================================================
print "-" x 70, "\n";
print "Test 4: is_ready() + is_done() - State checks (resolved)\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    # Pre-create resolved futures for state checks
    my $fx_done = Future::XS->new;
    $fx_done->done('value');
    my $hf_done = Hypersonic::Future->new;
    $hf_done->done('value');

    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my $r = $fx_done->is_ready;
            my $d = $fx_done->is_done;
        },
        'Hypersonic::Future' => sub {
            my $r = $hf_done->is_ready;
            my $d = $hf_done->is_done;
        },
    });
} else {
    my $hf_done = Hypersonic::Future->new;
    $hf_done->done('value');
    timethis(-$bench_time, sub {
        my $r = $hf_done->is_ready;
        my $d = $hf_done->is_done;
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 5: result() - Get result from resolved future
# ============================================================================
print "-" x 70, "\n";
print "Test 5: result() - Get result value\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    my $fx_done = Future::XS->new;
    $fx_done->done(1, 2, 3);
    my $hf_done = Hypersonic::Future->new;
    $hf_done->done(1, 2, 3);

    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my @r = $fx_done->result;
        },
        'Hypersonic::Future' => sub {
            my @r = $hf_done->result;
        },
    });
} else {
    my $hf_done = Hypersonic::Future->new;
    $hf_done->done(1, 2, 3);
    timethis(-$bench_time, sub {
        my @r = $hf_done->result;
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 6: done() with multiple values
# ============================================================================
print "-" x 70, "\n";
print "Test 6: done() with multiple values (5 args)\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my $f = Future::XS->new;
            $f->done(1, 2, 3, 4, 5);
        },
        'Hypersonic::Future' => sub {
            my $f = Hypersonic::Future->new;
            $f->done(1, 2, 3, 4, 5);
        },
    });
} else {
    timethis(-$bench_time, sub {
        my $f = Hypersonic::Future->new;
        $f->done(1, 2, 3, 4, 5);
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 7: is_failed check on failed future
# ============================================================================
print "-" x 70, "\n";
print "Test 7: is_failed() - Check failed state\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    my $fx_fail = Future::XS->new;
    $fx_fail->fail('error');
    my $hf_fail = Hypersonic::Future->new;
    $hf_fail->fail('error');

    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my $r = $fx_fail->is_ready;
            my $f = $fx_fail->is_failed;
        },
        'Hypersonic::Future' => sub {
            my $r = $hf_fail->is_ready;
            my $f = $hf_fail->is_failed;
        },
    });
} else {
    my $hf_fail = Hypersonic::Future->new;
    $hf_fail->fail('error');
    timethis(-$bench_time, sub {
        my $r = $hf_fail->is_ready;
        my $f = $hf_fail->is_failed;
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Test 8: failure() - Get failure reason
# ============================================================================
print "-" x 70, "\n";
print "Test 8: failure() - Get failure reason\n";
print "-" x 70, "\n";

if ($has_future_xs) {
    my $fx_fail = Future::XS->new;
    $fx_fail->fail('error', 'category', 'detail');
    my $hf_fail = Hypersonic::Future->new;
    $hf_fail->fail('error', 'category', 'detail');

    cmpthese(-$bench_time, {
        'Future::XS' => sub {
            my @f = $fx_fail->failure;
        },
        'Hypersonic::Future' => sub {
            my @f = $hf_fail->failure;
        },
    });
} else {
    my $hf_fail = Hypersonic::Future->new;
    $hf_fail->fail('error', 'category', 'detail');
    timethis(-$bench_time, sub {
        my @f = $hf_fail->failure;
    }, 'Hypersonic::Future');
}
print "\n";

# ============================================================================
# Hypersonic-only tests (callback-based operations)
# ============================================================================
print "=" x 70, "\n";
print "Hypersonic::Future Only Tests (callback operations)\n";
print "=" x 70, "\n";
print "(Future::XS 0.15 has wrap_cb issues with callbacks)\n\n";

# ============================================================================
# Test 9: then() chaining (Hypersonic only)
# ============================================================================
print "-" x 70, "\n";
print "Test 9: then() - Chain transformation [Hypersonic only]\n";
print "-" x 70, "\n";

timethis(-$bench_time, sub {
    my $f = Hypersonic::Future->new;
    my $f2 = $f->then(sub { return $_[0] * 2 });
    $f->done(21);
}, 'Hypersonic::Future');
print "\n";

# ============================================================================
# Test 10: on_done callback (Hypersonic only)
# ============================================================================
print "-" x 70, "\n";
print "Test 10: on_done() + done() - Callback [Hypersonic only]\n";
print "-" x 70, "\n";

my $counter = 0;
timethis(-$bench_time, sub {
    my $f = Hypersonic::Future->new;
    $f->on_done(sub { $counter++ });
    $f->done('value');
}, 'Hypersonic::Future');
print "\n";

# ============================================================================
# Test 11: Full chain (Hypersonic only) - uses fixed iteration count
# ============================================================================
print "-" x 70, "\n";
print "Test 11: then()->catch()->finally() [Hypersonic only]\n";
print "-" x 70, "\n";

# Chained futures use ~4 registry slots per iteration, so limit to 10000
my $chain_iter = 10000;
my $start = time();
for (1..$chain_iter) {
    my $f = Hypersonic::Future->new;
    my $chain = $f->then(sub { $_[0] * 2 })
                 ->catch(sub { 0 })
                 ->finally(sub { });
    $f->done(21);
}
my $elapsed = time() - $start;
my $rate = $chain_iter / $elapsed;
printf "Hypersonic::Future: %.0f/s (%d iterations in %.2f seconds)\n", $rate, $chain_iter, $elapsed;
print "\n";

# ============================================================================
# Summary
# ============================================================================
print "=" x 70, "\n";
print "Benchmark complete!\n";
print "=" x 70, "\n";

if ($has_future_xs) {
    print "\nResults interpretation:\n";
    print "  - Higher Rate = faster (more operations per second)\n";
    print "  - Positive % = that implementation is faster by that percentage\n";
}

print "\nHypersonic::Future advantages:\n";
print "  - Blessed scalar objects (minimal allocation overhead)\n";
print "  - JIT-compiled XS code (optimized for specific operations)\n";
print "  - Pre-allocated registry (O(1) slot allocation)\n";
print "  - Custom ops for zero-overhead state checks\n";
print "  - Direct C-level callback invocation\n";
