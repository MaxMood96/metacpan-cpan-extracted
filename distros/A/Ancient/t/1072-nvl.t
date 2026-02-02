#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(nvl coalesce);

# ============================================
# nvl tests
# ============================================

# Basic defined value
is(nvl(42, 0), 42, 'nvl returns defined value (number)');
is(nvl("hello", "default"), "hello", 'nvl returns defined value (string)');
is(nvl(0, 99), 0, 'nvl returns 0 (falsy but defined)');
is(nvl("", "default"), "", 'nvl returns empty string (falsy but defined)');

# Undefined value
is(nvl(undef, 42), 42, 'nvl returns default for undef');
is(nvl(undef, "default"), "default", 'nvl returns default string for undef');
is(nvl(undef, 0), 0, 'nvl returns 0 as default');

# References
my $ref = { a => 1 };
is(nvl($ref, {}), $ref, 'nvl returns defined reference');
is_deeply(nvl(undef, { b => 2 }), { b => 2 }, 'nvl returns default reference');

# Nested nvl
is(nvl(undef, nvl(undef, 99)), 99, 'nested nvl works');
is(nvl(undef, nvl(42, 99)), 42, 'nested nvl returns first defined');

# ============================================
# coalesce tests
# ============================================

# Single value
is(coalesce(42), 42, 'coalesce with single defined value');
is(coalesce(undef), undef, 'coalesce with single undef');

# Two values
is(coalesce(1, 2), 1, 'coalesce returns first defined (both defined)');
is(coalesce(undef, 2), 2, 'coalesce skips undef');
is(coalesce(undef, undef), undef, 'coalesce returns undef when all undef');

# Multiple values
is(coalesce(undef, undef, 3), 3, 'coalesce finds third value');
is(coalesce(undef, 2, 3), 2, 'coalesce finds second value');
is(coalesce(1, 2, 3), 1, 'coalesce finds first value');

# Falsy but defined values
is(coalesce(undef, 0, 5), 0, 'coalesce returns 0 (falsy but defined)');
is(coalesce(undef, "", "default"), "", 'coalesce returns empty string');
is(coalesce(undef, undef, 0), 0, 'coalesce returns 0 at end');

# Many undefs
is(coalesce(undef, undef, undef, undef, 42), 42, 'coalesce works with many undefs');
is(coalesce(undef, undef, undef, undef, undef), undef, 'coalesce returns undef for all undef');

# References
my $hash = { x => 1 };
my $array = [1, 2, 3];
is(coalesce(undef, $hash, $array), $hash, 'coalesce returns first defined ref');
is(coalesce($array, $hash), $array, 'coalesce returns first ref when both defined');

# Practical examples
my $config;
my $env_value;
my $default = "fallback";
is(coalesce($config, $env_value, $default), "fallback", 'practical config fallback');

$env_value = "from_env";
is(coalesce($config, $env_value, $default), "from_env", 'env value takes precedence');

$config = "from_config";
is(coalesce($config, $env_value, $default), "from_config", 'config takes precedence');

done_testing;
