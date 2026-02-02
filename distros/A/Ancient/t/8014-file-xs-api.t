#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';
use File::Temp qw(tempdir);

# Test file hooks C API via file_api_test XS module

BEGIN { use_ok('file') }

# Load the XS API test module
# Skip all tests if module can't load (linking issues on some platforms)
my $load_error;
BEGIN {
    eval { require file_api_test; file_api_test->import(); };
    $load_error = $@;
}

if ($load_error) {
    plan skip_all => "file_api_test not loadable (linking issue): $load_error";
}
pass('file_api_test loaded');

my $tempdir = tempdir(CLEANUP => 1);

# ============================================
# Test C API functions exist
# ============================================

subtest 'C API functions available' => sub {
    can_ok('file_api_test', 'install_uppercase_hook');
    can_ok('file_api_test', 'install_lowercase_hook');
    can_ok('file_api_test', 'install_reverse_hook');
    can_ok('file_api_test', 'clear_hook');
    can_ok('file_api_test', 'has_hook');
    can_ok('file_api_test', 'get_hook_ptr');
    can_ok('file_api_test', 'transform_string');
};

# ============================================
# Test direct string transformations (no file I/O)
# ============================================

subtest 'direct C transformations' => sub {
    is(file_api_test::transform_string('uppercase', 'hello'), 'HELLO', 'uppercase transform');
    is(file_api_test::transform_string('lowercase', 'HELLO'), 'hello', 'lowercase transform');
    is(file_api_test::transform_string('reverse', 'hello'), 'olleh', 'reverse transform');
    is(file_api_test::transform_string('uppercase', 'Hello World'), 'HELLO WORLD', 'uppercase mixed');
    is(file_api_test::transform_string('lowercase', 'Hello World'), 'hello world', 'lowercase mixed');
};

# ============================================
# Test hook installation from C
# ============================================

subtest 'hook installation from C' => sub {
    # Clear any existing hooks
    file::clear_hooks('read');
    file::clear_hooks('write');

    ok(!file_api_test::has_hook('read'), 'no read hook initially');
    ok(!file_api_test::has_hook('write'), 'no write hook initially');

    # Install read hook from C
    file_api_test::install_uppercase_hook('read');
    ok(file_api_test::has_hook('read'), 'read hook installed via C');

    # Install write hook from C
    file_api_test::install_lowercase_hook('write');
    ok(file_api_test::has_hook('write'), 'write hook installed via C');

    # Clear hooks
    file_api_test::clear_hook('read');
    ok(!file_api_test::has_hook('read'), 'read hook cleared via C');

    file_api_test::clear_hook('write');
    ok(!file_api_test::has_hook('write'), 'write hook cleared via C');
};

# ============================================
# Test C hooks with actual file I/O
# ============================================

subtest 'C read hook with file I/O' => sub {
    file::clear_hooks('read');

    my $testfile = "$tempdir/c_read_hook.txt";
    file::spew($testfile, "hello world");

    # Install uppercase hook from C
    file_api_test::install_uppercase_hook('read');

    my $content = file::slurp($testfile);
    is($content, 'HELLO WORLD', 'C read hook transforms file content');

    file_api_test::clear_hook('read');
};

subtest 'C write hook with file I/O' => sub {
    file::clear_hooks('write');

    # Install lowercase hook from C
    file_api_test::install_lowercase_hook('write');

    my $testfile = "$tempdir/c_write_hook.txt";
    file::spew($testfile, "HELLO WORLD");

    file_api_test::clear_hook('write');

    my $content = file::slurp($testfile);
    is($content, 'hello world', 'C write hook transforms before writing');
};

# ============================================
# Test encoding simulation with reverse hooks
# ============================================

subtest 'encoding simulation with C hooks' => sub {
    file::clear_hooks('read');
    file::clear_hooks('write');

    # Install reverse on both read and write
    file_api_test::install_reverse_hook('write');
    file_api_test::install_reverse_hook('read');

    my $testfile = "$tempdir/encoding_test.txt";
    my $original = "Hello, World!";

    file::spew($testfile, $original);

    # Reading should reverse the reversed content back to original
    my $decoded = file::slurp($testfile);
    is($decoded, $original, 'reverse encoding round-trip works');

    # Check what's actually on disk (clear read hook)
    file_api_test::clear_hook('read');
    my $on_disk = file::slurp($testfile);
    is($on_disk, '!dlroW ,olleH', 'data reversed on disk');

    file_api_test::clear_hook('write');
};

# ============================================
# Test hook pointer retrieval
# ============================================

subtest 'hook pointer retrieval' => sub {
    file::clear_hooks('read');

    ok(!defined(file_api_test::get_hook_ptr('read')), 'no hook ptr when not set');

    file_api_test::install_uppercase_hook('read');
    my $ptr1 = file_api_test::get_hook_ptr('read');
    # Note: ptr can be negative when large addresses are cast to signed IV
    ok(defined($ptr1) && $ptr1 != 0, 'hook ptr returned when set');

    file_api_test::install_lowercase_hook('read');
    my $ptr2 = file_api_test::get_hook_ptr('read');
    ok(defined($ptr2) && $ptr2 != 0, 'different hook ptr after change');
    isnt($ptr1, $ptr2, 'hook ptrs are different');

    file_api_test::clear_hook('read');
};

# ============================================
# Test interop between Perl and C hooks
# ============================================

subtest 'Perl and C hook interop' => sub {
    file::clear_hooks('read');

    # Set hook via C
    file_api_test::install_uppercase_hook('read');
    ok(file::has_hooks('read'), 'Perl sees C-installed hook');

    # Clear via Perl
    file::clear_hooks('read');
    ok(!file_api_test::has_hook('read'), 'C sees Perl-cleared hook');

    # Set via Perl callback
    file::register_read_hook(sub { lc($_[1]) });
    ok(file::has_hooks('read'), 'Perl hook registered');

    # Note: C simple hooks and Perl hooks use different mechanisms
    # The C file_get_read_hook only sees file_set_read_hook() hooks
    # Perl register_read_hook uses the hook list

    file::clear_hooks('read');
};

# ============================================
# Edge cases
# ============================================

subtest 'edge cases' => sub {
    file::clear_hooks('read');
    file::clear_hooks('write');

    # Empty string
    is(file_api_test::transform_string('uppercase', ''), '', 'uppercase empty string');
    is(file_api_test::transform_string('reverse', ''), '', 'reverse empty string');

    # Numbers only
    is(file_api_test::transform_string('uppercase', '12345'), '12345', 'uppercase numbers unchanged');

    # Special characters
    is(file_api_test::transform_string('uppercase', 'a!b@c#'), 'A!B@C#', 'uppercase with special chars');

    # Unicode-safe (ASCII only transformation)
    is(file_api_test::transform_string('uppercase', 'cafe'), 'CAFE', 'uppercase ascii');
};

# ============================================
# Cleanup
# ============================================

file::clear_hooks('read');
file::clear_hooks('write');

done_testing();
