#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Test the noop module

use_ok('noop', 'noop');

# ============================================
# Basic functionality
# ============================================

subtest 'noop returns undef in scalar context' => sub {
    my $result = noop();
    ok(!defined $result, 'noop returns undef');
};

subtest 'noop returns empty list in list context' => sub {
    my @result = noop();
    is(scalar @result, 0, 'noop returns empty list');
};

subtest 'noop accepts arguments without error' => sub {
    eval { noop(1, 2, 3) };
    ok(!$@, 'noop accepts multiple arguments');
    
    eval { noop("string") };
    ok(!$@, 'noop accepts string argument');
    
    eval { noop({ key => 'value' }) };
    ok(!$@, 'noop accepts hashref argument');
    
    eval { noop([1, 2, 3]) };
    ok(!$@, 'noop accepts arrayref argument');
};

subtest 'noop::noop full qualification' => sub {
    my $result = noop::noop();
    ok(!defined $result, 'noop::noop works with full qualification');
};

# ============================================
# Callback pattern
# ============================================

subtest 'noop as default callback' => sub {
    my %opts = ();  # No callback provided
    my $cb = $opts{callback} // \&noop;
    
    my $result = $cb->("some value");
    ok(!defined $result, 'noop works as default callback');
};

subtest 'noop in callback chain' => sub {
    my @log;
    my $real_cb = sub { push @log, shift };
    
    # With real callback
    $real_cb->("test1");
    is(scalar @log, 1, 'real callback logs');
    
    # With noop callback  
    my $noop_cb = \&noop;
    $noop_cb->("test2");
    is(scalar @log, 1, 'noop callback does not log');
};

# ============================================
# Context behavior
# ============================================

subtest 'noop in map' => sub {
    my @input = (1, 2, 3);
    my @result = map { noop() } @input;
    is(scalar @result, 0, 'noop in map produces empty results');
};

subtest 'noop as expression value' => sub {
    my $val = noop() || "default";
    is($val, "default", 'noop falsy allows fallback');
};

subtest 'noop in boolean context' => sub {
    ok(!noop(), 'noop is falsy');
    
    my $executed = 0;
    if (noop()) {
        $executed = 1;
    }
    is($executed, 0, 'noop does not trigger if block');
};

subtest 'noop in ternary' => sub {
    my $result = 1 ? noop() : "fallback";
    ok(!defined $result, 'noop in ternary returns undef');
};

# ============================================
# Multiple calls
# ============================================

subtest 'noop can be called repeatedly' => sub {
    for my $i (1..100) {
        noop();
    }
    pass('noop can be called many times');
};

done_testing;
