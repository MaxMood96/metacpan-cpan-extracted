#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Deadlock detection test for doubly
# This test verifies that operations that could cause deadlock
# (like nested destruction) complete without hanging.

# Check if we can use alarm (not available on Windows)
eval { alarm(0) };
if ($@) {
    plan skip_all => 'alarm() not available on this platform';
}

use_ok('doubly');

# Helper to run code with a timeout
# Returns 1 if completed, 0 if timed out
sub with_timeout {
    my ($timeout, $code, $name) = @_;
    
    # Use alarm for timeout detection
    local $SIG{ALRM} = sub { die "TIMEOUT\n" };
    
    my $completed = 0;
    eval {
        alarm($timeout);
        $code->();
        alarm(0);
        $completed = 1;
    };
    
    if ($@ && $@ eq "TIMEOUT\n") {
        alarm(0);
        return 0;
    } elsif ($@) {
        alarm(0);
        diag("Error in $name: $@");
        return 0;
    }
    
    return $completed;
}

# Test 1: Nested doubly objects (could deadlock on destruction)
subtest 'No deadlock with nested doubly destruction' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        my $outer = doubly->new();
        
        # Create nested structure: list containing lists
        for my $i (1..10) {
            my $inner = doubly->new();
            $inner->add("inner_$i");
            $inner->add("data_$i");
            $outer->add($inner);
        }
        
        # Force destruction by going out of scope
        # This could deadlock if list_decref holds lock while calling SvREFCNT_dec
        # on nested doubly objects
    }, 'nested destruction');
    
    ok($ok, 'Nested doubly destruction completed without deadlock');
};

# Test 2: Deeply nested doubly objects
subtest 'No deadlock with deeply nested doubly' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        my $level0 = doubly->new();
        my $level1 = doubly->new();
        my $level2 = doubly->new();
        my $level3 = doubly->new();
        
        $level3->add("deep");
        $level2->add($level3);
        $level1->add($level2);
        $level0->add($level1);
        
        # All levels destroyed when going out of scope
    }, 'deeply nested destruction');
    
    ok($ok, 'Deeply nested doubly destruction completed without deadlock');
};

# Test 3: Many operations in sequence
subtest 'No deadlock with many sequential operations' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        my $list = doubly->new();
        
        for my $i (1..1000) {
            $list->add("item_$i");
            $list->length;
            $list->start;
            $list->end;
            if ($i % 10 == 0) {
                $list->remove_from_start;
            }
        }
    }, 'many sequential operations');
    
    ok($ok, 'Many sequential operations completed without deadlock');
};

# Test 4: Callback during find (releases and reacquires lock)
subtest 'No deadlock during find callback' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        my $list = doubly->new();
        $list->bulk_add(1..100);
        
        my $found = $list->find(sub {
            my ($val) = @_;
            # Simulate some work in callback
            my $x = 0;
            $x++ for 1..100;
            return $val == 50;
        });
    }, 'find callback');
    
    ok($ok, 'Find callback completed without deadlock');
};

# Test 5: Callback during insert (releases and reacquires lock)
subtest 'No deadlock during insert callback' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        my $list = doubly->new();
        $list->bulk_add(1, 3, 5, 7, 9);
        
        # Insert 2 before the first element > 2
        $list->insert(sub { $_[0] > 2 }, 2);
    }, 'insert callback');
    
    ok($ok, 'Insert callback completed without deadlock');
};

# Test 6: Mixed nested and callbacks
subtest 'No deadlock with nested objects in find' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        my $list = doubly->new();
        
        for my $i (1..10) {
            my $inner = doubly->new();
            $inner->add({ id => $i, name => "item_$i" });
            $list->add($inner);
        }
        
        # Find a nested list and access its data
        my $found = $list->find(sub {
            my ($inner) = @_;
            return ref($inner) eq 'doubly' && $inner->data->{id} == 5;
        });
    }, 'nested objects in find');
    
    ok($ok, 'Nested objects in find completed without deadlock');
};

# Test 7: Explicit destroy followed by operations
subtest 'No issues after explicit destroy' => sub {
    plan tests => 2;
    
    my $ok = with_timeout(5, sub {
        my $list = doubly->new();
        $list->bulk_add(1..10);
        $list->destroy;
        
        # Operations on destroyed list should just return undef/0
        my $len = $list->length;
        is($len, 0, 'length is 0 after destroy');
    }, 'explicit destroy');
    
    ok($ok, 'Explicit destroy completed without deadlock');
};

# Test 8: Rapid create/destroy cycles
subtest 'No deadlock with rapid create/destroy cycles' => sub {
    plan tests => 1;
    
    my $ok = with_timeout(5, sub {
        for my $i (1..100) {
            my $list = doubly->new();
            $list->add("item");
            $list->destroy;
        }
    }, 'rapid create/destroy');
    
    ok($ok, 'Rapid create/destroy cycles completed without deadlock');
};

done_testing();
