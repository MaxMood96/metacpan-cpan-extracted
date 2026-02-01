#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);

use_ok('file');

my $tmpdir = tempdir(CLEANUP => 1);

# Test spew and slurp
subtest 'spew and slurp' => sub {
    my $file = "$tmpdir/test.txt";
    my $content = "Hello, World!\nLine 2\nLine 3";

    ok(file::spew($file, $content), 'spew returns true');
    ok(file::exists($file), 'file exists');

    my $read = file::slurp($file);
    is($read, $content, 'slurp returns correct content');
};

# Test append
subtest 'append' => sub {
    my $file = "$tmpdir/append.txt";

    file::spew($file, "Line 1\n");
    file::append($file, "Line 2\n");
    file::append($file, "Line 3\n");

    my $content = file::slurp($file);
    is($content, "Line 1\nLine 2\nLine 3\n", 'append works correctly');
};

# Test lines
subtest 'lines' => sub {
    my $file = "$tmpdir/lines.txt";
    file::spew($file, "one\ntwo\nthree");

    my $lines = file::lines($file);
    is(ref($lines), 'ARRAY', 'lines returns arrayref');
    is(scalar(@$lines), 3, 'correct number of lines');
    is($lines->[0], 'one', 'first line correct');
    is($lines->[1], 'two', 'second line correct');
    is($lines->[2], 'three', 'third line correct');
};

# Test each_line
subtest 'each_line' => sub {
    my $file = "$tmpdir/each.txt";
    file::spew($file, "a\nb\nc\nd\ne");

    my @collected;
    file::each_line($file, sub {
        push @collected, shift;
    });

    is(scalar(@collected), 5, 'collected all lines');
    is_deeply(\@collected, [qw(a b c d e)], 'lines in order');
};

# Test line iterator
subtest 'lines_iter' => sub {
    my $file = "$tmpdir/iter.txt";
    file::spew($file, "first\nsecond\nthird");

    my $iter = file::lines_iter($file);
    ok($iter, 'iterator created');

    ok(!$iter->eof, 'not eof at start');
    is($iter->next, 'first', 'first line');
    is($iter->next, 'second', 'second line');
    is($iter->next, 'third', 'third line');
    ok($iter->eof, 'eof after last line');

    $iter->close;
};

# Test stat operations
subtest 'stat operations' => sub {
    my $file = "$tmpdir/stat.txt";
    file::spew($file, "12345");

    is(file::size($file), 5, 'size is correct');
    ok(file::mtime($file) > 0, 'mtime is positive');
    ok(file::exists($file), 'exists returns true');
    ok(file::is_file($file), 'is_file returns true');
    ok(!file::is_dir($file), 'is_dir returns false for file');
    ok(file::is_dir($tmpdir), 'is_dir returns true for dir');
    ok(file::is_readable($file), 'is_readable returns true');
    ok(file::is_writable($file), 'is_writable returns true');
};

# Test non-existent file
subtest 'non-existent file' => sub {
    my $file = "$tmpdir/nonexistent.txt";

    ok(!file::exists($file), 'exists returns false');
    is(file::slurp($file), undef, 'slurp returns undef');
    is(file::size($file), -1, 'size returns -1');
};

# Test mmap
subtest 'mmap' => sub {
    my $file = "$tmpdir/mmap.txt";
    file::spew($file, "Memory mapped content!");

    my $mmap = file::mmap_open($file);
    ok($mmap, 'mmap opened');

    my $data = $mmap->data;
    is($data, "Memory mapped content!", 'mmap data correct');

    $mmap->close;
};

# Test empty file
subtest 'empty file' => sub {
    my $file = "$tmpdir/empty.txt";
    file::spew($file, "");

    is(file::slurp($file), "", 'slurp empty file returns empty string');
    is(file::size($file), 0, 'size of empty file is 0');

    my $lines = file::lines($file);
    is(scalar(@$lines), 0, 'lines of empty file is empty array');
};

# Test binary data
subtest 'binary data' => sub {
    my $file = "$tmpdir/binary.dat";
    my $binary = join('', map { chr($_) } 0..255);

    file::spew($file, $binary);
    my $read = file::slurp_raw($file);

    is(length($read), 256, 'binary length correct');
    is($read, $binary, 'binary content matches');
};

# Test large file
subtest 'large file' => sub {
    my $file = "$tmpdir/large.txt";
    my $content = "x" x (1024 * 100);  # 100KB

    file::spew($file, $content);
    my $read = file::slurp($file);

    is(length($read), length($content), 'large file length correct');
};

# Test additional stat operations
subtest 'additional stat ops' => sub {
    my $file = "$tmpdir/stat2.txt";
    file::spew($file, "test content");

    ok(file::atime($file) > 0, 'atime is positive');
    ok(file::ctime($file) > 0, 'ctime is positive');
    my $mode = file::mode($file);
    ok($mode >= 0, 'mode is non-negative');
    ok(!file::is_link($file), 'regular file is not a link');
    # is_executable depends on mode
};

# Test unlink
subtest 'unlink' => sub {
    my $file = "$tmpdir/to_delete.txt";
    file::spew($file, "delete me");
    ok(file::exists($file), 'file exists before unlink');
    ok(file::unlink($file), 'unlink returns true');
    ok(!file::exists($file), 'file gone after unlink');
    ok(!file::unlink($file), 'unlink non-existent returns false');
};

# Test copy
subtest 'copy' => sub {
    my $src = "$tmpdir/copy_src.txt";
    my $dst = "$tmpdir/copy_dst.txt";
    my $content = "content to copy\nline 2";

    file::spew($src, $content);
    ok(file::copy($src, $dst), 'copy returns true');
    ok(file::exists($dst), 'destination exists');
    is(file::slurp($dst), $content, 'copied content matches');

    # Source should still exist
    ok(file::exists($src), 'source still exists after copy');
};

# Test move
subtest 'move' => sub {
    my $src = "$tmpdir/move_src.txt";
    my $dst = "$tmpdir/move_dst.txt";
    my $content = "content to move";

    file::spew($src, $content);
    ok(file::move($src, $dst), 'move returns true');
    ok(!file::exists($src), 'source gone after move');
    ok(file::exists($dst), 'destination exists');
    is(file::slurp($dst), $content, 'moved content matches');
};

# Test touch
subtest 'touch' => sub {
    my $file = "$tmpdir/touched.txt";

    # Touch new file
    ok(file::touch($file), 'touch new file returns true');
    ok(file::exists($file), 'touched file exists');
    is(file::size($file), 0, 'touched file is empty');

    # Touch existing file - should update mtime
    my $mtime1 = file::mtime($file);
    sleep(1);  # Need a small delay
    ok(file::touch($file), 'touch existing file returns true');
    my $mtime2 = file::mtime($file);
    ok($mtime2 >= $mtime1, 'mtime updated after touch');
};

# Test chmod
subtest 'chmod' => sub {
    my $file = "$tmpdir/chmod_test.txt";
    file::spew($file, "chmod test");

    ok(file::chmod($file, 0644), 'chmod returns true');
    # Mode check is platform-specific, just verify no error
};

# Test mkdir and rmdir
subtest 'mkdir and rmdir' => sub {
    my $dir = "$tmpdir/newdir";

    ok(file::mkdir($dir), 'mkdir returns true');
    ok(file::is_dir($dir), 'created directory exists');
    ok(!file::mkdir($dir), 'mkdir existing dir returns false');

    ok(file::rmdir($dir), 'rmdir returns true');
    ok(!file::is_dir($dir), 'directory gone after rmdir');
    ok(!file::rmdir($dir), 'rmdir non-existent returns false');
};

# Test readdir
subtest 'readdir' => sub {
    my $dir = "$tmpdir/listdir";
    file::mkdir($dir);
    file::spew("$dir/a.txt", "a");
    file::spew("$dir/b.txt", "b");
    file::spew("$dir/c.txt", "c");

    my $entries = file::readdir($dir);
    is(ref($entries), 'ARRAY', 'readdir returns arrayref');
    is(scalar(@$entries), 3, 'correct number of entries');

    my %files = map { $_ => 1 } @$entries;
    ok($files{'a.txt'}, 'a.txt in listing');
    ok($files{'b.txt'}, 'b.txt in listing');
    ok($files{'c.txt'}, 'c.txt in listing');
    ok(!$files{'.'}, '. not in listing');
    ok(!$files{'..'}, '.. not in listing');
};

# Test basename
subtest 'basename' => sub {
    is(file::basename('/path/to/file.txt'), 'file.txt', 'basename with path');
    is(file::basename('file.txt'), 'file.txt', 'basename without path');
    is(file::basename('/path/to/dir/'), 'dir', 'basename with trailing slash');
    is(file::basename('/'), '', 'basename of root');
    is(file::basename(''), '', 'basename of empty string');
};

# Test dirname
subtest 'dirname' => sub {
    is(file::dirname('/path/to/file.txt'), '/path/to', 'dirname with file');
    is(file::dirname('file.txt'), '.', 'dirname without path');
    is(file::dirname('/path/to/dir/'), '/path/to', 'dirname with trailing slash');
    is(file::dirname('/path'), '/', 'dirname of root child');
    is(file::dirname('/'), '/', 'dirname of root');
};

# Test extname
subtest 'extname' => sub {
    is(file::extname('/path/to/file.txt'), '.txt', 'extname with extension');
    is(file::extname('file.tar.gz'), '.gz', 'extname with multiple dots');
    is(file::extname('noext'), '', 'extname without extension');
    is(file::extname('.hidden'), '', 'extname of hidden file (no ext)');
    is(file::extname('.hidden.txt'), '.txt', 'extname of hidden file with ext');
};

# Test join
subtest 'join' => sub {
    my $sep = '/';  # Will be correct for this platform
    my $j1 = file::join('path', 'to', 'file');
    ok($j1 =~ /path.to.file/, 'join multiple parts');

    my $j2 = file::join('/root', 'path');
    ok($j2 =~ /root.path/, 'join with root');
};

# Test head
subtest 'head' => sub {
    my $file = "$tmpdir/head_test.txt";
    file::spew($file, join("\n", map { "Line $_" } 1..20));

    my $h5 = file::head($file, 5);
    is(ref($h5), 'ARRAY', 'head returns arrayref');
    is(scalar(@$h5), 5, 'head returns correct count');
    is($h5->[0], 'Line 1', 'head first line correct');
    is($h5->[4], 'Line 5', 'head last line correct');

    my $h10 = file::head($file);  # Default
    is(scalar(@$h10), 10, 'head default is 10 lines');
};

# Test tail
subtest 'tail' => sub {
    my $file = "$tmpdir/tail_test.txt";
    file::spew($file, join("\n", map { "Line $_" } 1..20));

    my $t5 = file::tail($file, 5);
    is(ref($t5), 'ARRAY', 'tail returns arrayref');
    is(scalar(@$t5), 5, 'tail returns correct count');
    is($t5->[0], 'Line 16', 'tail first line correct');
    is($t5->[4], 'Line 20', 'tail last line correct');

    my $t10 = file::tail($file);  # Default
    is(scalar(@$t10), 10, 'tail default is 10 lines');
};

# Test atomic_spew
subtest 'atomic_spew' => sub {
    my $file = "$tmpdir/atomic.txt";
    my $content = "atomic content\nline 2";

    ok(file::atomic_spew($file, $content), 'atomic_spew returns true');
    ok(file::exists($file), 'file exists after atomic_spew');
    is(file::slurp($file), $content, 'atomic_spew content correct');
};

# Test import (custom ops)
subtest 'import custom ops' => sub {
    # This is tested implicitly - if the module loads, import works
    # Let's verify the functions are available after import
    my $file = "$tmpdir/import_test.txt";
    file::spew($file, "import test");

    # These should all work
    ok(file::exists($file), 'exists works');
    ok(file::is_file($file), 'is_file works');
    is(file::size($file), 11, 'size works');
};

done_testing();
