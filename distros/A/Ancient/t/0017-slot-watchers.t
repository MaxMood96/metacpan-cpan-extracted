#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Test slot watchers in detail

use slot qw(watched1 watched2 watched3);

# ============================================
# Multiple watchers - all fire
# ============================================

subtest 'multiple watchers all fire' => sub {
    my @log1;
    my @log2;
    
    slot::watch('watched1', sub {
        my ($name, $val) = @_;
        push @log1, [$name, $val];
    });
    
    slot::watch('watched1', sub {
        my ($name, $val) = @_;
        push @log2, [$name, $val];
    });
    
    watched1("test value");
    
    is(scalar @log1, 1, 'first watcher fired');
    is(scalar @log2, 1, 'second watcher fired');
    is($log1[0][0], 'watched1', 'first watcher got correct name');
    is($log1[0][1], 'test value', 'first watcher got correct value');
    is($log2[0][0], 'watched1', 'second watcher got correct name');
    is($log2[0][1], 'test value', 'second watcher got correct value');
    
    slot::unwatch('watched1');
};

# ============================================
# Watcher receives correct arguments
# ============================================

subtest 'watcher receives name and value' => sub {
    my @received;
    
    slot::watch('watched2', sub {
        @received = @_;
    });
    
    watched2(42);
    
    is(scalar @received, 2, 'watcher receives 2 arguments');
    is($received[0], 'watched2', 'first arg is slot name');
    is($received[1], 42, 'second arg is value');
    
    # Change value again
    watched2("new value");
    is($received[0], 'watched2', 'name stays same');
    is($received[1], "new value", 'value updates');
    
    slot::unwatch('watched2');
};

# ============================================
# Watcher only fires on change
# ============================================

subtest 'watcher fires on each set' => sub {
    my $count = 0;
    
    slot::watch('watched3', sub {
        $count++;
    });
    
    watched3(1);
    is($count, 1, 'watcher fires on first set');
    
    watched3(2);
    is($count, 2, 'watcher fires on second set');
    
    watched3(2);  # Same value
    is($count, 3, 'watcher fires even for same value');
    
    slot::unwatch('watched3');
};

# ============================================
# Specific watcher removal
# ============================================

subtest 'unwatch specific watcher' => sub {
    my $count1 = 0;
    my $count2 = 0;
    
    my $cb1 = sub { $count1++ };
    my $cb2 = sub { $count2++ };
    
    slot::watch('watched1', $cb1);
    slot::watch('watched1', $cb2);
    
    watched1("trigger both");
    is($count1, 1, 'cb1 fired');
    is($count2, 1, 'cb2 fired');
    
    # Remove only cb1
    slot::unwatch('watched1', $cb1);
    
    watched1("trigger remaining");
    is($count1, 1, 'cb1 no longer fires');
    is($count2, 2, 'cb2 still fires');
    
    slot::unwatch('watched1');
};

# ============================================
# Unwatch all removes all watchers
# ============================================

subtest 'unwatch all' => sub {
    my $count1 = 0;
    my $count2 = 0;
    
    slot::watch('watched2', sub { $count1++ });
    slot::watch('watched2', sub { $count2++ });
    
    watched2("trigger");
    is($count1, 1, 'first watcher fired');
    is($count2, 1, 'second watcher fired');
    
    slot::unwatch('watched2');
    
    watched2("after unwatch");
    is($count1, 1, 'first watcher not fired after unwatch');
    is($count2, 1, 'second watcher not fired after unwatch');
};

# ============================================
# Unwatch non-existent is safe
# ============================================

subtest 'unwatch non-existent is no-op' => sub {
    eval { slot::unwatch('watched3') };
    ok(!$@, 'unwatch on unwatched slot is safe');
    
    my $cb = sub { };
    eval { slot::unwatch('watched3', $cb) };
    ok(!$@, 'unwatch specific non-registered callback is safe');
};

done_testing;
