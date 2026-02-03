package file;

use strict;
use warnings;

our $VERSION = '0.16';

require XSLoader;
XSLoader::load('file', $VERSION);

1;

__END__

=head1 NAME

file - Fast IO operations using direct system calls

=head1 SYNOPSIS

    use file;

    # Slurp entire file
    my $content = file::slurp('/path/to/file');

    # Write to file
    file::spew('/path/to/file', $content);

    # Append to file
    file::append('/path/to/file', "more data\n");

    # Get all lines as array
    my $lines = file::lines('/path/to/file');

    # Process lines efficiently with callback
    file::each_line('/path/to/file', sub {
        my $line = shift;
        print "Line: $line\n";
    });

    # Memory-mapped file access
    my $mmap = file::mmap_open('/path/to/file');
    my $data = $mmap->data;  # Zero-copy access
    $mmap->close;

    # Line iterator (memory efficient)
    my $iter = file::lines_iter('/path/to/file');
    while (!$iter->eof) {
        my $line = $iter->next;
        # process line
    }
    $iter->close;

    # File stat operations
    my $size   = file::size('/path/to/file');
    my $mtime  = file::mtime('/path/to/file');
    my $exists = file::exists('/path/to/file');

    # Type checks
    file::is_file('/path/to/file');
    file::is_dir('/path/to/dir');
    file::is_readable('/path/to/file');
    file::is_writable('/path/to/file');

=head1 DESCRIPTION

Fast IO operations using direct system calls, bypassing PerlIO overhead.
This module provides significantly faster file operations compared to
Perl's built-in IO functions.

=head2 Performance

The module uses:

=over 4

=item * Direct read(2)/write(2) syscalls

=item * Pre-allocated buffers based on file size

=item * Memory-mapped file access for zero-copy reads

=item * Efficient line iteration without loading entire file

=back

=head1 FUNCTIONS

=head2 slurp

    my $content = file::slurp($path);

Read entire file into a scalar. Returns undef on error.
Pre-allocates the buffer based on file size for optimal performance.

=head2 slurp_raw

    my $content = file::slurp_raw($path);

Same as slurp, explicit binary mode.

=head2 spew

    my $ok = file::spew($path, $data);

Write data to file (creates or truncates). Returns true on success.

=head2 append

    my $ok = file::append($path, $data);

Append data to file. Returns true on success.

=head2 lines

    my $lines = file::lines($path);

Returns arrayref of all lines (without newlines).

=head2 each_line

    file::each_line($path, sub {
        my $line = shift;
        # process line
    });

Process each line with a callback. Memory efficient - doesn't load
entire file into memory.

=head2 lines_iter

    my $iter = file::lines_iter($path);
    while (!$iter->eof) {
        my $line = $iter->next;
    }
    $iter->close;

Returns a line iterator object for memory-efficient line processing.

=head2 mmap_open

    my $mmap = file::mmap_open($path);
    my $mmap = file::mmap_open($path, 1);  # writable

Memory-map a file. Returns a file::mmap object.

=head3 file::mmap methods

=over 4

=item data() - Returns the mapped content as a scalar (zero-copy)

=item sync() - Flush changes to disk (for writable maps)

=item close() - Unmap the file

=back

=head2 size

    my $bytes = file::size($path);

Returns file size in bytes, or -1 on error.

=head2 mtime

    my $epoch = file::mtime($path);

Returns modification time as epoch seconds, or -1 on error.

=head2 exists

    if (file::exists($path)) { ... }

Returns true if path exists.

=head2 is_file

    if (file::is_file($path)) { ... }

Returns true if path is a regular file.

=head2 is_dir

    if (file::is_dir($path)) { ... }

Returns true if path is a directory.

=head2 is_readable

    if (file::is_readable($path)) { ... }

Returns true if path is readable.

=head2 is_writable

    if (file::is_writable($path)) { ... }

Returns true if path is writable.

=head2 is_executable

    if (file::is_executable($path)) { ... }

Returns true if path is executable.

=head2 is_link

    if (file::is_link($path)) { ... }

Returns true if path is a symbolic link.

=head2 atime

    my $epoch = file::atime($path);

Returns access time as epoch seconds, or -1 on error.

=head2 ctime

    my $epoch = file::ctime($path);

Returns change time as epoch seconds, or -1 on error.

=head2 mode

    my $mode = file::mode($path);

Returns file permission mode (e.g., 0644), or -1 on error.

=head2 unlink

    my $ok = file::unlink($path);

Delete a file. Returns true on success.

=head2 copy

    my $ok = file::copy($src, $dst);

Copy a file. Returns true on success. Preserves file permissions.

=head2 move

    my $ok = file::move($src, $dst);

Move/rename a file. Returns true on success. Works across filesystems.

=head2 touch

    my $ok = file::touch($path);

Create file or update modification time. Returns true on success.

=head2 chmod

    my $ok = file::chmod($path, $mode);

Change file permissions. Returns true on success.

    file::chmod('/path/to/file', 0755);

=head2 mkdir

    my $ok = file::mkdir($path);
    my $ok = file::mkdir($path, $mode);

Create a directory. Default mode is 0755. Returns true on success.

=head2 rmdir

    my $ok = file::rmdir($path);

Remove an empty directory. Returns true on success.

=head2 readdir

    my $entries = file::readdir($path);

Returns arrayref of directory entries (excluding . and ..).

=head2 atomic_spew

    my $ok = file::atomic_spew($path, $data);

Write data atomically using a temp file + rename. Returns true on success.
This is safe against partial writes and power failures.

=head2 basename

    my $name = file::basename($path);

Returns the filename portion of a path.

    file::basename('/path/to/file.txt')  # returns 'file.txt'

=head2 dirname

    my $dir = file::dirname($path);

Returns the directory portion of a path.

    file::dirname('/path/to/file.txt')  # returns '/path/to'

=head2 extname

    my $ext = file::extname($path);

Returns the file extension including the dot.

    file::extname('/path/to/file.txt')  # returns '.txt'

=head2 join

    my $path = file::join(@parts);

Join path components with the appropriate separator.

    file::join('path', 'to', 'file')  # returns 'path/to/file'

=head2 head

    my $lines = file::head($path);
    my $lines = file::head($path, $n);

Returns arrayref of first N lines (default 10).

=head2 tail

    my $lines = file::tail($path);
    my $lines = file::tail($path, $n);

Returns arrayref of last N lines (default 10).

=head1 CUSTOM OP IMPORT

For maximum performance, you can import function-style accessors that
use custom ops instead of method calls:

    use file qw(import);

    my $content = file_slurp($path);     # custom op, fastest
    file_spew($path, $data);
    my $exists = file_exists($path);
    my $size = file_size($path);
    my $is_file = file_is_file($path);
    my $is_dir = file_is_dir($path);
    my $lines = file_lines($path);
    file_unlink($path);
    file_mkdir($path);
    file_rmdir($path);
    file_touch($path);
    my $base = file_basename($path);
    my $dir = file_dirname($path);
    my $ext = file_extname($path);

Custom ops provide 2-6% additional speed over method calls.

=head1 LINE PROCESSING

Advanced line processing functions for filtering and transforming file content.

=head2 count_lines

    my $count = file::count_lines($path);
    my $count = file::count_lines($path, $predicate);

Count lines in a file. With a predicate, counts only matching lines.

    my $total = file::count_lines($path);
    my $non_blank = file::count_lines($path, 'is_not_blank');
    my $long = file::count_lines($path, sub { length(shift) > 80 });

=head2 find_line

    my $line = file::find_line($path, $predicate);

Find and return the first line matching a predicate. Returns undef if
no match found.

    my $comment = file::find_line($path, 'is_comment');
    my $error = file::find_line($path, sub { /ERROR/ });

=head2 grep_lines

    my $lines = file::grep_lines($path, $predicate);

Filter lines matching a predicate. Returns arrayref.

    my $comments = file::grep_lines($path, 'is_comment');
    my $non_blank = file::grep_lines($path, 'is_not_blank');
    my $errors = file::grep_lines($path, sub { /ERROR|WARN/ });

=head2 map_lines

    my $result = file::map_lines($path, $transform);

Transform each line. Returns arrayref of transformed values.

    my $upper = file::map_lines($path, sub { uc(shift) });
    my $lengths = file::map_lines($path, sub { length($_) });

=head1 LINE CALLBACKS

Register custom predicates for use with grep_lines, count_lines, etc.

=head2 register_line_callback

    file::register_line_callback($name, $coderef);

Register a named predicate for line filtering.

    file::register_line_callback('is_todo', sub { /TODO|FIXME/ });

    # Now use it:
    my $todos = file::grep_lines($path, 'is_todo');

=head2 list_line_callbacks

    my $names = file::list_line_callbacks();

Returns arrayref of all registered callback names.

Built-in predicates: C<is_blank>, C<is_not_blank>, C<blank>, C<not_blank>,
C<is_empty>, C<is_not_empty>, C<is_comment>, C<is_not_comment>.

=head1 AUTHOR

LNATION

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
