#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Test slot::clear operations

use slot qw(clear1 clear2 clear3 clear4);

# ============================================
# Basic clear
# ============================================

subtest 'clear sets value to undef' => sub {
    clear1("initial value");
    is(clear1(), "initial value", 'value set');
    
    slot::clear('clear1');
    ok(!defined clear1(), 'value is undef after clear');
};

subtest 'cleared slot can be re-set' => sub {
    clear2("first");
    slot::clear('clear2');
    ok(!defined clear2(), 'cleared');
    
    clear2("second");
    is(clear2(), "second", 'can set after clear');
};

# ============================================
# Clear removes watchers
# ============================================

subtest 'clear removes watchers' => sub {
    my $count = 0;
    
    slot::watch('clear3', sub { $count++ });
    
    clear3("trigger");
    is($count, 1, 'watcher fires before clear');
    
    slot::clear('clear3');
    
    clear3("after clear");
    is($count, 1, 'watcher does not fire after clear');
};

# ============================================
# Clear by index
# ============================================

subtest 'clear_by_idx basic' => sub {
    clear4("test value");
    my $idx = slot::index('clear4');
    
    slot::clear_by_idx($idx);
    ok(!defined clear4(), 'value is undef after clear_by_idx');
};

subtest 'clear_by_idx allows re-set' => sub {
    clear4("initial");
    my $idx = slot::index('clear4');
    
    slot::clear_by_idx($idx);
    clear4("after clear by idx");
    is(clear4(), "after clear by idx", 'can set after clear_by_idx');
};

# ============================================
# Clear non-existent slot
# ============================================

subtest 'clear non-set slot is safe' => sub {
    # clear1 was cleared above and not re-set
    eval { slot::clear('clear1') };
    ok(!$@, 'clearing already cleared slot is safe');
};

done_testing;
