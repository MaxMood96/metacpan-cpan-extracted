#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';

BEGIN { use_ok('util') }

# ============================================
# Test XS-level built-in predicates
# These are registered in C with : prefix
# ============================================

subtest 'Built-in :is_defined' => sub {
    my @list = (undef, 0, '', 1, undef, 'foo');
    
    ok(util::any_cb(\@list, ':is_defined'), 'any defined');
    ok(!util::all_cb(\@list, ':is_defined'), 'not all defined');
    ok(!util::none_cb(\@list, ':is_defined'), 'not none defined');
    
    is(util::first_cb(\@list, ':is_defined'), 0, 'first defined is 0');
    is(util::count_cb(\@list, ':is_defined'), 4, 'count defined is 4');
    
    my @defined = util::grep_cb(\@list, ':is_defined');
    is_deeply(\@defined, [0, '', 1, 'foo'], 'grep defined');
};

subtest 'Built-in :is_true/:is_false' => sub {
    my @list = (0, '', undef, 1, 'yes', 0);
    
    is(util::count_cb(\@list, ':is_true'), 2, 'count true');
    is(util::count_cb(\@list, ':is_false'), 4, 'count false');
    
    is(util::first_cb(\@list, ':is_true'), 1, 'first true is 1');
    is(util::first_cb(\@list, ':is_false'), 0, 'first false is 0');
};

subtest 'Built-in :is_ref/:is_array/:is_hash/:is_code' => sub {
    my @list = (1, [], {}, sub {}, 'str', \1);
    
    is(util::count_cb(\@list, ':is_ref'), 4, 'count refs');
    is(util::count_cb(\@list, ':is_array'), 1, 'count arrays');
    is(util::count_cb(\@list, ':is_hash'), 1, 'count hashes');
    is(util::count_cb(\@list, ':is_code'), 1, 'count codes');
    
    my @refs = util::grep_cb(\@list, ':is_ref');
    is(scalar @refs, 4, 'grep refs returns 4');
};

subtest 'Built-in :is_positive/:is_negative/:is_zero' => sub {
    my @nums = (-5, -1, 0, 1, 5, 10);
    
    is(util::count_cb(\@nums, ':is_positive'), 3, 'count positive');
    is(util::count_cb(\@nums, ':is_negative'), 2, 'count negative');
    is(util::count_cb(\@nums, ':is_zero'), 1, 'count zero');
    
    is(util::first_cb(\@nums, ':is_positive'), 1, 'first positive');
    is(util::first_cb(\@nums, ':is_negative'), -5, 'first negative');
    
    my @positives = util::grep_cb(\@nums, ':is_positive');
    is_deeply(\@positives, [1, 5, 10], 'grep positive');
};

subtest 'Built-in :is_even/:is_odd' => sub {
    my @nums = (1, 2, 3, 4, 5, 6, 7, 8);
    
    is(util::count_cb(\@nums, ':is_even'), 4, 'count even');
    is(util::count_cb(\@nums, ':is_odd'), 4, 'count odd');
    
    my @evens = util::grep_cb(\@nums, ':is_even');
    is_deeply(\@evens, [2, 4, 6, 8], 'grep even');
    
    my @odds = util::grep_cb(\@nums, ':is_odd');
    is_deeply(\@odds, [1, 3, 5, 7], 'grep odd');
};

subtest 'Built-in :is_empty/:is_nonempty' => sub {
    my @list = ('', 'foo', undef, [], [1], {}, {a=>1});
    
    # :is_empty returns true for: '', undef, [], {}
    is(util::count_cb(\@list, ':is_empty'), 4, 'count empty');
    is(util::count_cb(\@list, ':is_nonempty'), 3, 'count nonempty');
};

subtest 'Built-in :is_string/:is_number/:is_integer' => sub {
    my @list = ('foo', 42, 3.14, 'bar');
    
    # Pure strings (not numbers)
    is(util::count_cb(\@list, ':is_string'), 2, 'count pure strings'); # 'foo', 'bar'
    
    # Numbers (including numeric strings)
    my @nums = (42, 3.14, '123', 0, 'foo');
    is(util::count_cb(\@nums, ':is_number'), 4, 'count numbers'); # 42, 3.14, '123', 0
    
    # Integers
    my @ints = (1, 2.0, 3.5, 4, '5', 6.1);
    is(util::count_cb(\@ints, ':is_integer'), 4, 'count integers'); # 1, 2.0, 4, '5'
};

# ============================================
# Test all_cb with vacuous truth
# ============================================

subtest 'all_cb vacuous truth' => sub {
    my @empty = ();
    ok(util::all_cb(\@empty, ':is_positive'), 'all_cb on empty list is true');
    ok(util::all_cb(\@empty, ':is_negative'), 'all_cb on empty list is true (any predicate)');
};

# ============================================
# Test partition_cb
# ============================================

subtest 'partition_cb with built-in predicates' => sub {
    my @nums = (-3, -1, 0, 1, 2, 5);
    
    my ($pos, $non_pos) = util::partition_cb(\@nums, ':is_positive');
    is_deeply($pos, [1, 2, 5], 'partition_cb positive matches');
    is_deeply($non_pos, [-3, -1, 0], 'partition_cb positive non-matches');
    
    my ($evens, $odds) = util::partition_cb(\@nums, ':is_even');
    is_deeply($evens, [0, 2], 'partition_cb even matches');
    is_deeply($odds, [-3, -1, 1, 5], 'partition_cb even non-matches');
};

subtest 'partition_cb empty list' => sub {
    my @empty = ();
    my ($pass, $fail) = util::partition_cb(\@empty, ':is_positive');
    is_deeply($pass, [], 'partition_cb empty - pass is empty');
    is_deeply($fail, [], 'partition_cb empty - fail is empty');
};

subtest 'partition_cb with custom callback' => sub {
    util::register_callback('greater_than_10', sub { $_[0] > 10 });
    my @nums = (5, 15, 8, 20, 3);
    my ($big, $small) = util::partition_cb(\@nums, 'greater_than_10');
    is_deeply($big, [15, 20], 'partition_cb custom - big');
    is_deeply($small, [5, 8, 3], 'partition_cb custom - small');
};

# ============================================
# Test final_cb  
# ============================================

subtest 'final_cb with built-in predicates' => sub {
    my @nums = (-3, 1, 2, -1, 5, 0);
    
    is(util::final_cb(\@nums, ':is_positive'), 5, 'final_cb positive = 5');
    is(util::final_cb(\@nums, ':is_negative'), -1, 'final_cb negative = -1');
    is(util::final_cb(\@nums, ':is_zero'), 0, 'final_cb zero = 0');
    
    my @evens = (1, 2, 4, 3, 6);
    is(util::final_cb(\@evens, ':is_even'), 6, 'final_cb even = 6');
    is(util::final_cb(\@evens, ':is_odd'), 3, 'final_cb odd = 3');
};

subtest 'final_cb no match' => sub {
    my @all_positive = (1, 2, 3);
    is(util::final_cb(\@all_positive, ':is_negative'), undef, 'final_cb no match returns undef');
};

subtest 'final_cb empty list' => sub {
    my @empty = ();
    is(util::final_cb(\@empty, ':is_positive'), undef, 'final_cb empty returns undef');
};

subtest 'final_cb with custom callback' => sub {
    my @strs = ('hi', 'hello', 'goodbye', 'yo', 'wonderful');
    util::register_callback('is_long', sub { length($_[0]) > 5 });
    is(util::final_cb(\@strs, 'is_long'), 'wonderful', 'final_cb custom callback');
};

# ============================================
# Error handling for new functions
# ============================================

subtest 'partition_cb errors' => sub {
    eval { util::partition_cb([1,2], 'nonexistent') };
    like($@, qr/unknown callback/, 'partition_cb unknown callback');
    
    eval { util::partition_cb('not_array', ':is_positive') };
    like($@, qr/arrayref/, 'partition_cb requires arrayref');
};

subtest 'final_cb errors' => sub {
    eval { util::final_cb([1,2], 'nonexistent') };
    like($@, qr/unknown callback/, 'final_cb unknown callback');
    
    eval { util::final_cb('not_array', ':is_positive') };
    like($@, qr/arrayref/, 'final_cb requires arrayref');
};

# ============================================
# Test Perl-level callback registration
# ============================================

subtest 'Perl callback registration' => sub {
    # Register a custom Perl predicate
    util::register_callback('is_long_string', sub { length($_[0]) > 5 });
    
    ok(util::has_callback('is_long_string'), 'callback registered');
    
    my @strings = ('hi', 'hello', 'goodbye', 'x', 'testing');
    
    is(util::count_cb(\@strings, 'is_long_string'), 2, 'count long strings');
    is(util::first_cb(\@strings, 'is_long_string'), 'goodbye', 'first long string');
    
    my @long = util::grep_cb(\@strings, 'is_long_string');
    is_deeply(\@long, ['goodbye', 'testing'], 'grep long strings');
};

subtest 'Cannot re-register callback' => sub {
    eval { util::register_callback(':is_positive', sub { 1 }) };
    like($@, qr/already registered/, 'cannot re-register built-in');
    
    eval { util::register_callback('is_long_string', sub { 1 }) };
    like($@, qr/already registered/, 'cannot re-register user callback');
};

subtest 'Unknown callback error' => sub {
    eval { util::any_cb([1,2,3], 'nonexistent') };
    like($@, qr/unknown callback/, 'any_cb with unknown callback dies');
    
    eval { util::all_cb([1,2,3], 'nonexistent') };
    like($@, qr/unknown callback/, 'all_cb with unknown callback dies');
    
    eval { util::none_cb([1,2,3], 'nonexistent') };
    like($@, qr/unknown callback/, 'none_cb with unknown callback dies');
    
    eval { util::first_cb([1,2,3], 'nonexistent') };
    like($@, qr/unknown callback/, 'first_cb with unknown callback dies');
    
    eval { util::grep_cb([1,2,3], 'nonexistent') };
    like($@, qr/unknown callback/, 'grep_cb with unknown callback dies');
    
    eval { util::count_cb([1,2,3], 'nonexistent') };
    like($@, qr/unknown callback/, 'count_cb with unknown callback dies');
};

subtest 'Invalid arguments' => sub {
    eval { util::any_cb('not_array', ':is_positive') };
    like($@, qr/arrayref/, 'any_cb requires arrayref');
    
    eval { util::any_cb({}, ':is_positive') };
    like($@, qr/arrayref/, 'any_cb rejects hashref');
};

# ============================================
# Test list_callbacks returns all
# ============================================

subtest 'list_callbacks' => sub {
    my $callbacks = util::list_callbacks();
    ok(ref $callbacks eq 'ARRAY', 'returns arrayref');
    
    # Should have all built-ins
    my %cb = map { $_ => 1 } @$callbacks;
    ok($cb{':is_defined'}, 'has :is_defined');
    ok($cb{':is_positive'}, 'has :is_positive');
    ok($cb{':is_array'}, 'has :is_array');
    ok($cb{':is_even'}, 'has :is_even');
    ok($cb{'is_long_string'}, 'has user-registered callback');
};

# ============================================
# Test has_callback
# ============================================

subtest 'has_callback' => sub {
    ok(util::has_callback(':is_positive'), 'has built-in');
    ok(util::has_callback('is_long_string'), 'has user callback');
    ok(!util::has_callback('nonexistent'), 'does not have nonexistent');
    ok(!util::has_callback(':fake'), 'does not have :fake');
};

# ============================================
# Performance sanity check - C path should be fast
# ============================================

subtest 'Performance sanity' => sub {
    my @large = (1) x 10000;
    
    # This should complete in reasonable time
    my $start = time();
    for (1..100) {
        util::any_cb(\@large, ':is_positive');
        util::all_cb(\@large, ':is_positive');
        util::count_cb(\@large, ':is_positive');
    }
    my $elapsed = time() - $start;
    
    ok($elapsed < 5, "C predicate path is fast (${elapsed}s for 300 calls on 10k elements)");
};

done_testing();
