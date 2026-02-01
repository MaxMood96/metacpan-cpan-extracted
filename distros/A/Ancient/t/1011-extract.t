#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(pick pluck);

# ============================================
# pick tests
# ============================================

my $user = {
    name => 'Alice',
    age => 30,
    email => 'alice@example.com',
    password => 'secret123',
    role => 'admin',
};

# Pick subset of keys
my $public = pick($user, qw(name age email));
is_deeply($public, { name => 'Alice', age => 30, email => 'alice@example.com' },
    'pick: extracts subset of keys');

# Pick single key
my $name_only = pick($user, 'name');
is_deeply($name_only, { name => 'Alice' }, 'pick: single key');

# Pick non-existent key
my $with_missing = pick($user, qw(name nonexistent));
is_deeply($with_missing, { name => 'Alice' }, 'pick: ignores missing keys');

# Pick all non-existent keys
my $all_missing = pick($user, qw(foo bar baz));
is_deeply($all_missing, {}, 'pick: returns empty hash for all missing');

# Pick no keys
my $empty = pick($user);
is_deeply($empty, {}, 'pick: no keys returns empty hash');

# Pick preserves values
my $nested = { a => [1,2,3], b => { x => 1 }, c => 42 };
my $picked = pick($nested, qw(a b));
is($picked->{a}, $nested->{a}, 'pick: preserves arrayref reference');
is($picked->{b}, $nested->{b}, 'pick: preserves hashref reference');

# Pick with undefined values
my $with_undef = { a => 1, b => undef, c => 3 };
my $pick_undef = pick($with_undef, qw(a b c));
is_deeply($pick_undef, { a => 1, c => 3 }, 'pick: skips undefined values');

# ============================================
# pluck tests
# ============================================

my @users = (
    { name => 'Alice', age => 30 },
    { name => 'Bob', age => 25 },
    { name => 'Carol', age => 35 },
);

# Basic pluck
my $names = pluck(\@users, 'name');
is_deeply($names, ['Alice', 'Bob', 'Carol'], 'pluck: extracts field from each');

my $ages = pluck(\@users, 'age');
is_deeply($ages, [30, 25, 35], 'pluck: extracts numeric field');

# Pluck missing field
my $missing = pluck(\@users, 'email');
is_deeply($missing, [undef, undef, undef], 'pluck: undef for missing field');

# Pluck from empty array
my $empty_pluck = pluck([], 'name');
is_deeply($empty_pluck, [], 'pluck: empty array returns empty');

# Pluck with mixed content
my @mixed = (
    { name => 'Alice' },
    "not a hash",
    { name => 'Bob' },
    undef,
    { name => 'Carol' },
);
my $mixed_names = pluck(\@mixed, 'name');
is_deeply($mixed_names, ['Alice', undef, 'Bob', undef, 'Carol'],
    'pluck: handles non-hash elements');

# Pluck nested values (just the key)
my @products = (
    { id => 1, meta => { price => 100 } },
    { id => 2, meta => { price => 200 } },
);
my $ids = pluck(\@products, 'id');
is_deeply($ids, [1, 2], 'pluck: extracts simple field from complex hashes');

my $metas = pluck(\@products, 'meta');
is($metas->[0]{price}, 100, 'pluck: extracts nested hashref');
is($metas->[1]{price}, 200, 'pluck: extracts nested hashref 2');

# Pluck with some missing
my @partial = (
    { name => 'Alice', email => 'a@a.com' },
    { name => 'Bob' },
    { name => 'Carol', email => 'c@c.com' },
);
my $emails = pluck(\@partial, 'email');
is_deeply($emails, ['a@a.com', undef, 'c@c.com'], 'pluck: handles partial data');

# ============================================
# Practical examples
# ============================================

# API response filtering
my $api_response = {
    id => 123,
    name => 'Product',
    price => 99.99,
    internal_code => 'ABC123',
    inventory_count => 50,
};

my $frontend_data = pick($api_response, qw(id name price));
is_deeply($frontend_data, { id => 123, name => 'Product', price => 99.99 },
    'pick: practical API filtering');

# Extracting IDs for batch operation
my @records = (
    { id => 1, data => 'a' },
    { id => 2, data => 'b' },
    { id => 3, data => 'c' },
);
my $ids_list = pluck(\@records, 'id');
is_deeply($ids_list, [1, 2, 3], 'pluck: practical ID extraction');

done_testing;
