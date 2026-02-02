#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use file;
use File::Temp qw(tempfile tempdir);

# Test file hooks system

my $tempdir = tempdir(CLEANUP => 1);

# ============================================
# Basic hook registration
# ============================================

subtest 'hook registration functions exist' => sub {
    ok(defined(&file::register_read_hook), 'register_read_hook exists');
    ok(defined(&file::register_write_hook), 'register_write_hook exists');
    ok(defined(&file::clear_hooks), 'clear_hooks exists');
    ok(defined(&file::has_hooks), 'has_hooks exists');
};

subtest 'no hooks by default' => sub {
    ok(!file::has_hooks('read'), 'no read hooks initially');
    ok(!file::has_hooks('write'), 'no write hooks initially');
};

# ============================================
# Read hooks
# ============================================

subtest 'read hook transforms data' => sub {
    # Clear any existing hooks
    file::clear_hooks('read');

    # Register a hook that uppercases content
    file::register_read_hook(sub {
        my ($path, $data) = @_;
        return uc($data);
    });

    ok(file::has_hooks('read'), 'read hook registered');

    # Write test file (use slurp_raw to bypass hooks for setup)
    my $testfile = "$tempdir/read_hook_test.txt";
    file::spew($testfile, "hello world");

    # Clear and re-register to ensure clean state
    file::clear_hooks('read');
    file::register_read_hook(sub {
        my ($path, $data) = @_;
        return uc($data);
    });

    # Read should apply hook
    my $content = file::slurp($testfile);
    is($content, 'HELLO WORLD', 'read hook transformed content');

    file::clear_hooks('read');
};

subtest 'read hook receives path' => sub {
    file::clear_hooks('read');

    my $received_path;
    file::register_read_hook(sub {
        my ($path, $data) = @_;
        $received_path = $path;
        return $data;  # Pass through unchanged
    });

    my $testfile = "$tempdir/path_test.txt";
    file::spew($testfile, "test");

    file::clear_hooks('read');
    file::register_read_hook(sub {
        my ($path, $data) = @_;
        $received_path = $path;
        return $data;
    });

    file::slurp($testfile);
    is($received_path, $testfile, 'hook received correct path');

    file::clear_hooks('read');
};

# ============================================
# Write hooks
# ============================================

subtest 'write hook transforms data' => sub {
    file::clear_hooks('write');

    # Register a hook that lowercases content
    file::register_write_hook(sub {
        my ($path, $data) = @_;
        return lc($data);
    });

    ok(file::has_hooks('write'), 'write hook registered');

    my $testfile = "$tempdir/write_hook_test.txt";
    file::spew($testfile, "HELLO WORLD");

    file::clear_hooks('write');

    # Read raw to verify transformation
    my $content = file::slurp($testfile);
    is($content, 'hello world', 'write hook transformed content');
};

subtest 'write hook can add prefix' => sub {
    file::clear_hooks('write');

    file::register_write_hook(sub {
        my ($path, $data) = @_;
        return "PREFIX: $data";
    });

    my $testfile = "$tempdir/prefix_test.txt";
    file::spew($testfile, "content");

    file::clear_hooks('write');

    my $content = file::slurp($testfile);
    is($content, 'PREFIX: content', 'write hook added prefix');
};

# ============================================
# Hook clearing
# ============================================

subtest 'clear_hooks removes hooks' => sub {
    file::clear_hooks('read');
    file::clear_hooks('write');

    file::register_read_hook(sub { uc($_[1]) });
    file::register_write_hook(sub { lc($_[1]) });

    ok(file::has_hooks('read'), 'read hook present');
    ok(file::has_hooks('write'), 'write hook present');

    file::clear_hooks('read');
    ok(!file::has_hooks('read'), 'read hook cleared');
    ok(file::has_hooks('write'), 'write hook still present');

    file::clear_hooks('write');
    ok(!file::has_hooks('write'), 'write hook cleared');
};

# ============================================
# No hooks = no overhead path
# ============================================

subtest 'operations work without hooks' => sub {
    file::clear_hooks('read');
    file::clear_hooks('write');

    my $testfile = "$tempdir/no_hooks.txt";
    my $data = "test data without hooks";

    file::spew($testfile, $data);
    my $read = file::slurp($testfile);

    is($read, $data, 'read/write work without hooks');
};

# ============================================
# slurp_raw bypasses hooks
# ============================================

subtest 'slurp_raw bypasses read hooks' => sub {
    file::clear_hooks('read');

    file::register_read_hook(sub {
        my ($path, $data) = @_;
        return uc($data);
    });

    my $testfile = "$tempdir/raw_test.txt";
    file::spew($testfile, "lowercase");

    file::clear_hooks('read');
    file::register_read_hook(sub { uc($_[1]) });

    # slurp_raw should bypass hooks
    my $raw = file::slurp_raw($testfile);
    is($raw, 'lowercase', 'slurp_raw bypasses read hooks');

    # regular slurp should use hooks
    my $hooked = file::slurp($testfile);
    is($hooked, 'LOWERCASE', 'slurp uses read hooks');

    file::clear_hooks('read');
};

# ============================================
# Multiple operations with same hook
# ============================================

subtest 'hook persists across multiple operations' => sub {
    file::clear_hooks('read');

    my $call_count = 0;
    file::register_read_hook(sub {
        my ($path, $data) = @_;
        $call_count++;
        return $data;
    });

    my $testfile = "$tempdir/persist_test.txt";
    file::spew($testfile, "data");

    file::slurp($testfile);
    file::slurp($testfile);
    file::slurp($testfile);

    is($call_count, 3, 'hook called for each read');

    file::clear_hooks('read');
};

# ============================================
# Encoding-style hook example
# ============================================

subtest 'encoding hook example' => sub {
    file::clear_hooks('read');
    file::clear_hooks('write');

    # Simulate base64-like encoding (just reverse for simplicity)
    file::register_write_hook(sub {
        my ($path, $data) = @_;
        return scalar(reverse($data));
    });

    file::register_read_hook(sub {
        my ($path, $data) = @_;
        return scalar(reverse($data));
    });

    my $testfile = "$tempdir/encoding_test.txt";
    my $original = "Hello, World!";

    file::spew($testfile, $original);

    # File on disk should be reversed
    file::clear_hooks('read');
    my $on_disk = file::slurp($testfile);
    is($on_disk, '!dlroW ,olleH', 'data encoded on disk');

    # Re-register read hook
    file::register_read_hook(sub {
        my ($path, $data) = @_;
        return scalar(reverse($data));
    });

    # Reading should decode
    my $decoded = file::slurp($testfile);
    is($decoded, $original, 'data decoded on read');

    file::clear_hooks('read');
    file::clear_hooks('write');
};

done_testing();
