#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use_ok('file');

my $tmpdir = tempdir(CLEANUP => 1);

# ============================================
# Error handling for nonexistent files
# ============================================

subtest 'nonexistent file operations' => sub {
    my $nonexistent = "$tmpdir/does_not_exist.txt";

    is(file::slurp($nonexistent), undef, 'slurp nonexistent returns undef');
    is(file::size($nonexistent), -1, 'size nonexistent returns -1');
    is(file::mtime($nonexistent), -1, 'mtime nonexistent returns -1');
    is(file::atime($nonexistent), -1, 'atime nonexistent returns -1');
    is(file::ctime($nonexistent), -1, 'ctime nonexistent returns -1');
    is(file::mode($nonexistent), -1, 'mode nonexistent returns -1');

    ok(!file::exists($nonexistent), 'exists nonexistent returns false');
    ok(!file::is_file($nonexistent), 'is_file nonexistent returns false');
    ok(!file::is_dir($nonexistent), 'is_dir nonexistent returns false');
    ok(!file::is_readable($nonexistent), 'is_readable nonexistent returns false');
    ok(!file::is_writable($nonexistent), 'is_writable nonexistent returns false');
    ok(!file::is_link($nonexistent), 'is_link nonexistent returns false');

    ok(!file::unlink($nonexistent), 'unlink nonexistent returns false');
    ok(!file::rmdir($nonexistent), 'rmdir nonexistent returns false');

    my $lines = file::lines($nonexistent);
    is(ref($lines), 'ARRAY', 'lines returns arrayref');
    is(scalar(@$lines), 0, 'lines of nonexistent is empty');
};

# ============================================
# Path manipulation edge cases
# ============================================

subtest 'path edge cases' => sub {
    # Empty string
    is(file::basename(''), '', 'basename of empty');
    is(file::dirname(''), '.', 'dirname of empty');
    is(file::extname(''), '', 'extname of empty');

    # Root only
    is(file::basename('/'), '', 'basename of root');
    is(file::dirname('/'), '/', 'dirname of root');

    # Multiple slashes
    is(file::basename('//'), '', 'basename of double slash');
    is(file::basename('/a//b//c'), 'c', 'basename with double slashes');
    is(file::dirname('/a//b//c'), '/a//b', 'dirname with double slashes');

    # Trailing slashes
    is(file::basename('/path/dir/'), 'dir', 'basename with trailing slash');
    is(file::dirname('/path/dir/'), '/path', 'dirname with trailing slash');

    # Hidden files
    is(file::basename('.hidden'), '.hidden', 'basename of hidden');
    is(file::extname('.hidden'), '', 'extname of hidden (no ext)');
    is(file::extname('.hidden.txt'), '.txt', 'extname of hidden with ext');

    # Multiple extensions
    is(file::extname('file.tar.gz'), '.gz', 'extname of tar.gz');
    is(file::extname('file.min.js'), '.js', 'extname of min.js');

    # No extension
    is(file::extname('Makefile'), '', 'extname of Makefile');
    is(file::extname('/path/to/README'), '', 'extname of README');

    # Dot at end
    is(file::extname('file.'), '.', 'extname of file.');
};

# ============================================
# join path edge cases
# ============================================

subtest 'join edge cases' => sub {
    # Empty parts
    my $j1 = file::join('a', '', 'b');
    ok($j1 !~ m{//}, 'join handles empty middle part');

    # Single part
    is(file::join('single'), 'single', 'join single part');

    # Root handling
    my $j2 = file::join('/', 'path');
    like($j2, qr{^/.*path}, 'join with root');

    # Already has separator
    my $j3 = file::join('/path/', '/to/', '/file');
    ok($j3 !~ m{//}, 'join removes duplicate separators');
};

# ============================================
# head and tail edge cases
# ============================================

subtest 'head edge cases' => sub {
    my $file = "$tmpdir/head_edge.txt";

    # File with fewer lines than requested
    file::spew($file, "one\ntwo\nthree");
    my $h = file::head($file, 10);
    is(scalar(@$h), 3, 'head returns all lines when fewer than N');

    # Zero lines
    my $h0 = file::head($file, 0);
    is(scalar(@$h0), 0, 'head(0) returns empty');

    # Empty file
    file::spew($file, "");
    my $he = file::head($file);
    is(scalar(@$he), 0, 'head of empty file');

    # Nonexistent file
    my $hn = file::head("$tmpdir/nonexistent.txt", 5);
    is(scalar(@$hn), 0, 'head of nonexistent returns empty');
};

subtest 'tail edge cases' => sub {
    my $file = "$tmpdir/tail_edge.txt";

    # File with fewer lines than requested
    file::spew($file, "one\ntwo\nthree");
    my $t = file::tail($file, 10);
    is(scalar(@$t), 3, 'tail returns all lines when fewer than N');

    # Zero lines
    my $t0 = file::tail($file, 0);
    is(scalar(@$t0), 0, 'tail(0) returns empty');

    # Empty file
    file::spew($file, "");
    my $te = file::tail($file);
    is(scalar(@$te), 0, 'tail of empty file');

    # Nonexistent file
    my $tn = file::tail("$tmpdir/nonexistent.txt", 5);
    is(scalar(@$tn), 0, 'tail of nonexistent returns empty');
};

# ============================================
# Overwriting files
# ============================================

subtest 'overwrite behavior' => sub {
    my $file = "$tmpdir/overwrite.txt";

    file::spew($file, "original content that is quite long");
    is(file::slurp($file), "original content that is quite long", 'original content');

    file::spew($file, "short");
    is(file::slurp($file), "short", 'overwritten with shorter content');

    file::spew($file, "");
    is(file::slurp($file), "", 'overwritten with empty');
};

# ============================================
# Binary data edge cases
# ============================================

subtest 'binary edge cases' => sub {
    my $file = "$tmpdir/binary_edge.dat";

    # All null bytes
    my $nulls = "\0" x 100;
    file::spew($file, $nulls);
    my $read = file::slurp($file);
    is(length($read), 100, 'null bytes preserved');
    is($read, $nulls, 'null content matches');

    # All high bytes
    my $high = chr(255) x 100;
    file::spew($file, $high);
    $read = file::slurp($file);
    is($read, $high, 'high bytes preserved');

    # Mixed binary
    my $mixed = join('', map { chr($_) } 0..255);
    file::spew($file, $mixed);
    $read = file::slurp($file);
    is($read, $mixed, 'full byte range preserved');
};

# ============================================
# Copy edge cases
# ============================================

subtest 'copy edge cases' => sub {
    # Copy to self (should work but be no-op or fail gracefully)
    my $file = "$tmpdir/copy_self.txt";
    file::spew($file, "self copy test");

    # Copy empty file
    my $empty = "$tmpdir/copy_empty_src.txt";
    my $empty_dst = "$tmpdir/copy_empty_dst.txt";
    file::spew($empty, "");
    ok(file::copy($empty, $empty_dst), 'copy empty file');
    is(file::slurp($empty_dst), "", 'copied empty file is empty');

    # Copy nonexistent
    ok(!file::copy("$tmpdir/nonexistent.txt", "$tmpdir/copy_dst.txt"),
       'copy nonexistent returns false');
};

# ============================================
# Move edge cases
# ============================================

subtest 'move edge cases' => sub {
    # Move nonexistent
    ok(!file::move("$tmpdir/nonexistent.txt", "$tmpdir/move_dst.txt"),
       'move nonexistent returns false');

    # Move to existing (should overwrite)
    my $src = "$tmpdir/move_src.txt";
    my $dst = "$tmpdir/move_existing.txt";
    file::spew($src, "source content");
    file::spew($dst, "existing content");
    ok(file::move($src, $dst), 'move to existing file');
    is(file::slurp($dst), "source content", 'move overwrote existing');
    ok(!file::exists($src), 'source gone after move');
};

# ============================================
# mkdir edge cases
# ============================================

subtest 'mkdir edge cases' => sub {
    # mkdir existing directory
    my $dir = "$tmpdir/mkdir_existing";
    file::mkdir($dir);
    ok(!file::mkdir($dir), 'mkdir existing returns false');

    # mkdir over existing file
    my $file = "$tmpdir/mkdir_over_file";
    file::spew($file, "file");
    ok(!file::mkdir($file), 'mkdir over file returns false');
};

# ============================================
# rmdir edge cases
# ============================================

subtest 'rmdir edge cases' => sub {
    # rmdir non-empty directory
    my $dir = "$tmpdir/rmdir_nonempty";
    file::mkdir($dir);
    file::spew("$dir/file.txt", "content");
    ok(!file::rmdir($dir), 'rmdir non-empty returns false');

    # Clean up
    file::unlink("$dir/file.txt");
    file::rmdir($dir);

    # rmdir file
    my $file = "$tmpdir/rmdir_file.txt";
    file::spew($file, "content");
    ok(!file::rmdir($file), 'rmdir on file returns false');
};

# ============================================
# atomic_spew edge cases
# ============================================

subtest 'atomic_spew edge cases' => sub {
    my $file = "$tmpdir/atomic_edge.txt";

    # Atomic write empty
    ok(file::atomic_spew($file, ""), 'atomic_spew empty');
    is(file::slurp($file), "", 'atomic empty content');

    # Atomic overwrite
    file::atomic_spew($file, "first");
    file::atomic_spew($file, "second");
    is(file::slurp($file), "second", 'atomic overwrite works');
};

# ============================================
# readdir edge cases
# ============================================

subtest 'readdir edge cases' => sub {
    # Empty directory
    my $empty_dir = "$tmpdir/readdir_empty";
    file::mkdir($empty_dir);
    my $entries = file::readdir($empty_dir);
    is(scalar(@$entries), 0, 'readdir empty dir');

    # Nonexistent directory
    my $ne = file::readdir("$tmpdir/nonexistent_dir");
    is(ref($ne), 'ARRAY', 'readdir nonexistent returns arrayref');
    is(scalar(@$ne), 0, 'readdir nonexistent is empty');

    # readdir on file
    my $file = "$tmpdir/readdir_file.txt";
    file::spew($file, "content");
    my $rf = file::readdir($file);
    is(scalar(@$rf), 0, 'readdir on file returns empty');
};

# ============================================
# Large file operations
# ============================================

subtest 'large file operations' => sub {
    my $file = "$tmpdir/large_file.txt";
    my $size = 1024 * 1024;  # 1MB
    my $content = "x" x $size;

    file::spew($file, $content);
    is(file::size($file), $size, 'large file size');

    my $read = file::slurp($file);
    is(length($read), $size, 'large file slurp length');
    is($read, $content, 'large file content');
};

# ============================================
# Concurrent access (basic test)
# ============================================

subtest 'multiple readers' => sub {
    my $file = "$tmpdir/concurrent.txt";
    file::spew($file, "shared content");

    # Multiple slurps
    my $r1 = file::slurp($file);
    my $r2 = file::slurp($file);
    my $r3 = file::slurp($file);

    is($r1, $r2, 'concurrent reads match');
    is($r2, $r3, 'concurrent reads match');
};

done_testing();
