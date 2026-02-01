#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use util;

# Test is_array
ok(util::is_array([1, 2, 3]), 'is_array: arrayref is array');
ok(!util::is_array({a => 1}), 'is_array: hashref is not array');
ok(!util::is_array('hello'), 'is_array: string is not array');
ok(!util::is_array(42), 'is_array: number is not array');

# Test is_hash
ok(util::is_hash({a => 1}), 'is_hash: hashref is hash');
ok(!util::is_hash([1, 2, 3]), 'is_hash: arrayref is not hash');
ok(!util::is_hash('hello'), 'is_hash: string is not hash');

# Test is_code
ok(util::is_code(sub { 1 }), 'is_code: coderef is code');
ok(!util::is_code([1, 2, 3]), 'is_code: arrayref is not code');
ok(!util::is_code('hello'), 'is_code: string is not code');

# Test is_scalar_ref
my $x = 42;
ok(util::is_scalar_ref(\$x), 'is_scalar_ref: scalar ref is scalar ref');
ok(!util::is_scalar_ref([1, 2, 3]), 'is_scalar_ref: arrayref is not scalar ref');
ok(!util::is_scalar_ref(42), 'is_scalar_ref: number is not scalar ref');

# Test is_ref
ok(util::is_ref([1, 2, 3]), 'is_ref: arrayref is ref');
ok(util::is_ref({a => 1}), 'is_ref: hashref is ref');
ok(util::is_ref(sub { 1 }), 'is_ref: coderef is ref');
ok(!util::is_ref('hello'), 'is_ref: string is not ref');
ok(!util::is_ref(42), 'is_ref: number is not ref');

# Test is_regex
my $rx = qr/test/;
ok(util::is_regex($rx), 'is_regex: qr// is regex');
ok(!util::is_regex('test'), 'is_regex: string is not regex');
ok(!util::is_regex([1, 2]), 'is_regex: arrayref is not regex');

# Test is_glob
ok(util::is_glob(*STDOUT), 'is_glob: *STDOUT is glob');
ok(!util::is_glob('hello'), 'is_glob: string is not glob');

# Test is_blessed
my $obj = bless {}, 'MyClass';
ok(util::is_blessed($obj), 'is_blessed: blessed ref is blessed');
ok(!util::is_blessed({a => 1}), 'is_blessed: unblessed hashref is not blessed');
ok(!util::is_blessed('hello'), 'is_blessed: string is not blessed');

done_testing();
