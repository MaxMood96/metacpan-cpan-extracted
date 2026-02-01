#!/usr/bin/env perl
# Integration test: slot + const + util for configuration management
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use const;
use util;

package TestApp;
use slot qw(debug_level max_retries timeout);

package TestCache;
use slot qw(capacity ttl);

package main;

subtest 'basic slot accessors' => sub {
    TestApp::debug_level(3);
    TestApp::max_retries(5);
    TestApp::timeout(30);
    
    is(TestApp::debug_level(), 3, 'debug_level set correctly');
    is(TestApp::max_retries(), 5, 'max_retries set correctly');
    is(TestApp::timeout(), 30, 'timeout set correctly');
};

subtest 'slot::get and slot::set' => sub {
    TestCache::capacity(100);
    TestCache::ttl(3600);
    
    is(slot::get('capacity'), 100, 'slot::get works');
    
    slot::set('capacity', 200);
    is(TestCache::capacity(), 200, 'slot::set updates value');
};

subtest 'slots with util validation' => sub {
    TestApp::debug_level(5);
    
    my $level = TestApp::debug_level();
    ok(util::is_positive($level), 'debug_level is positive');
    ok(util::is_between($level, 1, 10), 'debug_level is in valid range');
    
    my $clamped = util::clamp(500, 1, 120);
    TestApp::timeout($clamped);
    
    is(TestApp::timeout(), 120, 'timeout clamped to max');
};

subtest 'freeze slot values' => sub {
    TestCache::capacity(1000);
    TestCache::ttl(3600);
    
    my $frozen_config = const::c({
        capacity => TestCache::capacity(),
        ttl      => TestCache::ttl(),
    });
    
    ok(const::is_readonly($frozen_config->{capacity}), 'frozen config value is readonly');
    is($frozen_config->{capacity}, 1000, 'frozen capacity is correct');
    is($frozen_config->{ttl}, 3600, 'frozen ttl is correct');
};

subtest 'list all slots' => sub {
    my @all_slots = slot::slots();
    my %slot_hash = map { $_ => 1 } @all_slots;
    
    ok(exists $slot_hash{debug_level}, 'debug_level in slots list');
    ok(exists $slot_hash{max_retries}, 'max_retries in slots list');
    ok(exists $slot_hash{capacity}, 'capacity in slots list');
    ok(exists $slot_hash{ttl}, 'ttl in slots list');
};

done_testing();
