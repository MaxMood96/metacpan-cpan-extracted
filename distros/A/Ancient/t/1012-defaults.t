#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(defaults);

# ============================================
# defaults tests
# ============================================

# Basic defaults
my %config = (host => 'localhost', port => 8080);
my %defs = (port => 3000, timeout => 30, retries => 3);
my $merged = defaults(\%config, \%defs);

is($merged->{host}, 'localhost', 'defaults: existing key preserved');
is($merged->{port}, 8080, 'defaults: existing key not overwritten');
is($merged->{timeout}, 30, 'defaults: missing key filled from defaults');
is($merged->{retries}, 3, 'defaults: another missing key filled');

# Empty config - all from defaults
my $empty_config = defaults({}, \%defs);
is($empty_config->{port}, 3000, 'defaults: empty config uses default port');
is($empty_config->{timeout}, 30, 'defaults: empty config uses default timeout');
is($empty_config->{retries}, 3, 'defaults: empty config uses default retries');

# Empty defaults - config unchanged
my $empty_defs = defaults(\%config, {});
is($empty_defs->{host}, 'localhost', 'defaults: empty defaults - host');
is($empty_defs->{port}, 8080, 'defaults: empty defaults - port');
ok(!exists $empty_defs->{timeout}, 'defaults: empty defaults - no timeout');

# Both empty
my $both_empty = defaults({}, {});
is_deeply($both_empty, {}, 'defaults: both empty');

# Does not mutate original
my %original = (a => 1);
my %original_defs = (b => 2);
my $result = defaults(\%original, \%original_defs);
ok(!exists $original{b}, 'defaults: original not mutated');
is($result->{b}, 2, 'defaults: result has b');

# Undefined value - filled from defaults (key exists but value is undef)
my %with_undef = (a => undef, b => 1);
my %undef_defs = (a => 'default_a', b => 'default_b', c => 'default_c');
my $undef_result = defaults(\%with_undef, \%undef_defs);
ok(exists $undef_result->{a}, 'defaults: key with undef value exists');
is($undef_result->{a}, 'default_a', 'defaults: undef value IS replaced with default');
is($undef_result->{b}, 1, 'defaults: defined value preserved');
is($undef_result->{c}, 'default_c', 'defaults: missing key filled');

# With nested references
my %nested_config = (
    name => 'test',
    options => { debug => 1 },
);
my %nested_defs = (
    name => 'default',
    options => { verbose => 0 },
    extra => [1, 2, 3],
);
my $nested = defaults(\%nested_config, \%nested_defs);
is($nested->{name}, 'test', 'defaults: nested - existing key');
is_deeply($nested->{options}, { debug => 1 }, 'defaults: nested - ref not merged');
is_deeply($nested->{extra}, [1, 2, 3], 'defaults: nested - ref from defaults');

# Numeric zero is preserved (not filled)
my %zero_config = (count => 0, flag => '');
my %zero_defs = (count => 100, flag => 'default');
my $zero_result = defaults(\%zero_config, \%zero_defs);
is($zero_result->{count}, 0, 'defaults: zero preserved');
is($zero_result->{flag}, '', 'defaults: empty string preserved');

# Large hash
my %large_config = map { ("key_$_" => $_) } 1..50;
my %large_defs = map { ("key_$_" => $_ * 100) } 25..75;
my $large = defaults(\%large_config, \%large_defs);
is($large->{key_1}, 1, 'defaults: large - existing key 1');
is($large->{key_25}, 25, 'defaults: large - existing key not overwritten');
is($large->{key_51}, 5100, 'defaults: large - new key from defaults');
is(scalar(keys %$large), 75, 'defaults: large - correct total keys');

done_testing;
