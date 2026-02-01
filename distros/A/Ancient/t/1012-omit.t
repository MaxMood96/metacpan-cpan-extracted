#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(omit);

# ============================================
# omit tests (inverse of pick)
# ============================================

my $user = {
    name => 'Alice',
    age => 30,
    email => 'alice@example.com',
    password => 'secret123',
    role => 'admin',
};

# Omit sensitive keys
my $public = omit($user, qw(password role));
is_deeply($public, { name => 'Alice', age => 30, email => 'alice@example.com' },
    'omit: excludes specified keys');

# Omit single key
my $no_password = omit($user, 'password');
is_deeply($no_password, { name => 'Alice', age => 30, email => 'alice@example.com', role => 'admin' },
    'omit: single key');

# Omit non-existent key
my $same = omit($user, qw(nonexistent));
is_deeply($same, { name => 'Alice', age => 30, email => 'alice@example.com', password => 'secret123', role => 'admin' },
    'omit: ignores non-existent keys');

# Omit all keys
my $empty = omit($user, qw(name age email password role));
is_deeply($empty, {}, 'omit: all keys returns empty hash');

# Omit no keys (identity)
my $all = omit($user);
is_deeply($all, $user, 'omit: no keys returns copy of hash');

# Omit preserves values
my $nested = { a => [1,2,3], b => { x => 1 }, c => 42 };
my $omitted = omit($nested, 'c');
is($omitted->{a}, $nested->{a}, 'omit: preserves arrayref reference');
is($omitted->{b}, $nested->{b}, 'omit: preserves hashref reference');
ok(!exists $omitted->{c}, 'omit: key is actually removed');

# Omit with undefined values - they should not be copied
my $with_undef = { a => 1, b => undef, c => 3 };
my $omit_a = omit($with_undef, 'a');
is_deeply($omit_a, { c => 3 }, 'omit: skips undefined values in source');

# Original not modified
is($user->{password}, 'secret123', 'omit: original unchanged');

done_testing;
