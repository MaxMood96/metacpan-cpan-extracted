#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 27;

use Stefo;

# =============================================================================
# Debugging ref($_) eq 'TYPE' patterns
# =============================================================================

# First, verify basic ref() works
{
    my $is_ref = Stefo::compile(sub { ref($_) });
    ok(Stefo::is_optimized($is_ref), "ref(\$_) optimized");
    ok(Stefo::check($is_ref, []), "ref([]) is truthy");
    ok(Stefo::check($is_ref, {}), "ref({}) is truthy");
    ok(!Stefo::check($is_ref, 'string'), "ref('string') is falsy");

    my $ref_count = Stefo::instruction_count($is_ref);
    diag("ref(\$_) has $ref_count instructions");
}

# Test ref eq 'ARRAY'
{
    my $is_array = Stefo::compile(sub { ref($_) eq 'ARRAY' });
    ok(Stefo::is_optimized($is_array), "ref(\$_) eq 'ARRAY' optimized");

    my $count = Stefo::instruction_count($is_array);
    diag("ref(\$_) eq 'ARRAY' has $count instructions");

    # If it's using COPS_IS_ARRAY, should be ~2-3 instructions
    # If it's doing full string comparison, would be more

    my $result_array = Stefo::check($is_array, [1,2,3]);
    my $result_hash = Stefo::check($is_array, {a=>1});
    my $result_str = Stefo::check($is_array, 'ARRAY');

    diag("ref([1,2,3]) eq 'ARRAY' = " . ($result_array ? "true" : "false"));
    diag("ref({a=>1}) eq 'ARRAY' = " . ($result_hash ? "true" : "false"));
    diag("ref('ARRAY') eq 'ARRAY' = " . ($result_str ? "true" : "false"));

    ok($result_array, "array ref detected as ARRAY");
    ok(!$result_hash, "hash ref not detected as ARRAY");
    ok(!$result_str, "string 'ARRAY' not detected as ARRAY ref");
}

# Test ref eq 'HASH'
{
    my $is_hash = Stefo::compile(sub { ref($_) eq 'HASH' });
    ok(Stefo::is_optimized($is_hash), "ref(\$_) eq 'HASH' optimized");

    my $count = Stefo::instruction_count($is_hash);
    diag("ref(\$_) eq 'HASH' has $count instructions");

    my $result_hash = Stefo::check($is_hash, {a=>1});
    my $result_array = Stefo::check($is_hash, [1,2,3]);

    diag("ref({a=>1}) eq 'HASH' = " . ($result_hash ? "true" : "false"));
    diag("ref([1,2,3]) eq 'HASH' = " . ($result_array ? "true" : "false"));

    ok($result_hash, "hash ref detected as HASH");
    ok(!$result_array, "array ref not detected as HASH");
}

# Test ref eq 'CODE'
{
    my $is_code = Stefo::compile(sub { ref($_) eq 'CODE' });
    ok(Stefo::is_optimized($is_code), "ref(\$_) eq 'CODE' optimized");

    my $count = Stefo::instruction_count($is_code);
    diag("ref(\$_) eq 'CODE' has $count instructions");

    my $result_code = Stefo::check($is_code, sub { 1 });
    my $result_array = Stefo::check($is_code, []);

    diag("ref(sub{}) eq 'CODE' = " . ($result_code ? "true" : "false"));

    ok($result_code, "code ref detected as CODE");
    ok(!$result_array, "array ref not detected as CODE");
}

# Test ref eq 'SCALAR'
{
    my $is_scalar = Stefo::compile(sub { ref($_) eq 'SCALAR' });
    ok(Stefo::is_optimized($is_scalar), "ref(\$_) eq 'SCALAR' optimized");

    my $x = 42;
    my $result_scalar = Stefo::check($is_scalar, \$x);
    my $result_array = Stefo::check($is_scalar, []);

    diag("ref(\\scalar) eq 'SCALAR' = " . ($result_scalar ? "true" : "false"));

    ok($result_scalar, "scalar ref detected as SCALAR");
    ok(!$result_array, "array ref not detected as SCALAR");
}

# Test ref eq 'Regexp'
{
    my $is_rx = Stefo::compile(sub { ref($_) eq 'Regexp' });
    ok(Stefo::is_optimized($is_rx), "ref(\$_) eq 'Regexp' optimized");

    my $result_rx = Stefo::check($is_rx, qr/test/);
    my $result_array = Stefo::check($is_rx, []);

    diag("ref(qr//) eq 'Regexp' = " . ($result_rx ? "true" : "false"));

    ok($result_rx, "regexp ref detected as Regexp");
    ok(!$result_array, "array ref not detected as Regexp");
}

# Test ref ne 'ARRAY' (negated)
{
    my $not_array = Stefo::compile(sub { ref($_) ne 'ARRAY' });
    ok(Stefo::is_optimized($not_array), "ref(\$_) ne 'ARRAY' optimized");

    my $result_hash = Stefo::check($not_array, {});
    my $result_array = Stefo::check($not_array, []);
    my $result_str = Stefo::check($not_array, 'hello');

    diag("ref({}) ne 'ARRAY' = " . ($result_hash ? "true" : "false"));
    diag("ref([]) ne 'ARRAY' = " . ($result_array ? "true" : "false"));

    ok($result_hash, "hash ref ne 'ARRAY' is true");
    ok(!$result_array, "array ref ne 'ARRAY' is false");
    ok($result_str, "string ne 'ARRAY' is true");
}

# Combined: ref($_) && ref($_) eq 'ARRAY'
{
    my $ref_and_array = Stefo::compile(sub { ref($_) && ref($_) eq 'ARRAY' });
    ok(Stefo::is_optimized($ref_and_array), "ref && ref eq 'ARRAY' optimized");

    my $result = Stefo::check($ref_and_array, [1,2,3]);
    diag("ref && ref eq 'ARRAY' for [] = " . ($result ? "true" : "false"));

    ok($result, "combined ref check works for array");
    ok(!Stefo::check($ref_and_array, {}), "combined ref check fails for hash");
}
