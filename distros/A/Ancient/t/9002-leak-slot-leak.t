#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'void';
use Test::More;

# Skip if ps command not available (Windows, minimal docker containers, etc.)
my $ps_available = eval { my $r = `ps -o rss= -p $$ 2>/dev/null`; defined $r && $r =~ /\d/ };
plan skip_all => 'ps command not available' unless $ps_available;

# Memory leak tests for slot module

use slot qw/test_slot test_slot2 test_slot3/;

# Helper to get current RSS in KB
sub get_rss {
    my $pid = $$;
    my $rss = `ps -o rss= -p $pid`;
    chomp $rss;
    return $rss + 0;
}

# Helper to test for memory leak
sub test_no_leak {
    my ($name, $code, $iterations, $threshold) = @_;
    $iterations //= 100_000;
    $threshold //= 10_000;  # 10MB threshold
    
    # Warmup
    $code->() for 1..1000;
    
    my $before = get_rss();
    $code->() for 1..$iterations;
    my $after = get_rss();
    
    my $growth = $after - $before;
    ok($growth < $threshold, "$name: memory growth ${growth}KB < ${threshold}KB threshold");
    
    if ($growth >= $threshold) {
        diag("LEAK DETECTED: $name grew by ${growth}KB after $iterations iterations");
    }
}

# Test slot accessor get
test_slot(42);
test_no_leak("slot accessor get", sub {
    my $x = test_slot();
});

# Test slot accessor set
test_no_leak("slot accessor set", sub {
    test_slot(42);
});

# Test slot::get
test_no_leak("slot::get", sub {
    my $x = slot::get('test_slot');
});

# Test slot::set
test_no_leak("slot::set", sub {
    slot::set('test_slot', 42);
});

# Test slot::get_by_idx
my $idx = slot::index('test_slot');
test_no_leak("slot::get_by_idx", sub {
    my $x = slot::get_by_idx($idx);
});

# Test slot::set_by_idx
test_no_leak("slot::set_by_idx", sub {
    slot::set_by_idx($idx, 42);
});

# Test slot::add (adding same slot is idempotent)
test_no_leak("slot::add (existing)", sub {
    slot::add('test_slot');
});

# Test storing refs
test_no_leak("slot with hashref", sub {
    test_slot2({ a => 1, b => 2 });
    my $x = test_slot2();
});

# Test storing arrayrefs
test_no_leak("slot with arrayref", sub {
    test_slot3([1, 2, 3]);
    my $x = test_slot3();
});

# Test watchers (add and trigger)
my $counter = 0;
slot::watch('test_slot', sub { $counter++ });
test_no_leak("slot with watcher", sub {
    test_slot(42);
}, 10_000);  # Fewer iterations since watchers are slower
slot::unwatch('test_slot');

# Test slot::index (constant lookup)
test_no_leak("slot::index", sub {
    my $i = slot::index('test_slot');
});

# Test slot::clear
test_no_leak("slot::clear", sub {
    slot::clear('test_slot');
    test_slot(42);  # Re-set for next iteration
});

# Test multiple watchers add/remove cycle
test_no_leak("watcher add/remove cycle", sub {
    slot::watch('test_slot', sub { });
    slot::unwatch('test_slot');
}, 10_000);

done_testing;
