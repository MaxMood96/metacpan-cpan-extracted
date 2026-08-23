use strict;
use warnings;
use FindBin;
use File::Temp qw(tempfile tempdir);
use File::Spec;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../perl-Uniform/lib";

use Test::More;
use Test::Exception;

use Uniform::Upload::File;

# =========================================================================
# Constructor defaults
# =========================================================================
{
    my $bare = Uniform::Upload::File->new({});

    is($bare->size, 0, 'new() defaults size to 0 when omitted');
    is($bare->type, undef, 'new() defaults type to undef when omitted');
    is($bare->filename, undef, 'new() defaults filename to undef when omitted');
}

{
    my $full = Uniform::Upload::File->new({
        tempname => '/tmp/does-not-matter',
        filename => 'report.pdf',
        size     => 4096,
        type     => 'application/pdf',
    });

    is($full->size, 4096, 'size() reflects constructor value');
    is($full->type, 'application/pdf', 'type() reflects constructor value');
    is($full->filename, 'report.pdf', 'filename() reflects constructor value');
}

# =========================================================================
# max_size() error paths (happy path already covered in 01-methods.t)
# =========================================================================
{
    my $f = Uniform::Upload::File->new({ size => 500 });

    throws_ok { $f->max_size(undef) } 'Uniform::Exceptions',
        'max_size throws when limit is undef';

    throws_ok { $f->max_size('') } 'Uniform::Exceptions',
        'max_size throws when limit is an empty string';

    throws_ok { $f->max_size('not-a-size') } 'Uniform::Exceptions',
        'max_size throws when limit string is unparsable';

    lives_ok { $f->max_size('1K') } 'max_size accepts K unit and passes when within limit';
    lives_ok { $f->max_size(500) } 'max_size accepts a plain byte count';
    throws_ok { $f->max_size(499) } 'Uniform::Exceptions',
        'max_size throws when a plain byte count is exceeded';
}

# =========================================================================
# allowed_types() error paths (happy path already covered in 01-methods.t)
# =========================================================================
{
    my $f = Uniform::Upload::File->new({ type => 'image/png' });

    throws_ok { $f->allowed_types(undef) } 'Uniform::Exceptions',
        'allowed_types throws when types arg is undef';

    throws_ok { $f->allowed_types([]) } 'Uniform::Exceptions',
        'allowed_types throws when types arg is an empty arrayref';

    throws_ok { $f->allowed_types('image/png') } 'Uniform::Exceptions',
        'allowed_types throws when types arg is not an arrayref';
}

# =========================================================================
# sanitize_filename() edge cases
# =========================================================================
{
    my $no_name = Uniform::Upload::File->new({ filename => undef });
    my $ret = $no_name->sanitize_filename;
    is($no_name->filename, undef, 'sanitize_filename is a no-op when filename is undef');
    is($ret, $no_name, 'sanitize_filename returns $self even in the no-op case');
}

{
    # new() normalizes an empty-string filename to undef (filename => $meta->{filename} || undef),
    # so this exercises the same no-op path as an omitted filename.
    my $empty_name = Uniform::Upload::File->new({ filename => '' });
    is($empty_name->filename, undef, 'new() normalizes an empty-string filename to undef');
    $empty_name->sanitize_filename;
    is($empty_name->filename, undef, 'sanitize_filename remains a no-op after that normalization');
}

{
    # Every character gets stripped to hyphens, then collapsed away entirely,
    # so the safety fallback should kick in.
    my $junk_name = Uniform::Upload::File->new({ filename => '???' });
    $junk_name->sanitize_filename;
    is($junk_name->filename, 'uploaded_file',
        'sanitize_filename falls back to a safe default when filtering empties the name');
}

{
    # basename('.') is '.', which is explicitly guarded against.
    my $dot_name = Uniform::Upload::File->new({ filename => '.' });
    $dot_name->sanitize_filename;
    is($dot_name->filename, 'uploaded_file',
        'sanitize_filename falls back to a safe default for a bare "." filename');
}

# =========================================================================
# save_to()
# =========================================================================
{
    my $dir = tempdir(CLEANUP => 1);
    my ($fh, $tmp_path) = tempfile();
    print $fh 'payload contents';
    close($fh);

    my $file = Uniform::Upload::File->new({
        tempname => $tmp_path,
        filename => 'report.pdf',
        size     => 17,
        type     => 'application/pdf',
    });

    lives_ok { $file->save_to("$dir/") } 'save_to lives when given a directory with a trailing slash';

    my $expected = File::Spec->catfile($dir, 'report.pdf');
    ok(-e $expected, 'save_to writes the file inside the destination directory under its filename');

    open(my $rfh, '<', $expected) or die $!;
    local $/;
    my $contents = <$rfh>;
    close($rfh);
    is($contents, 'payload contents', 'save_to copies the source file contents exactly');
}

{
    # Destination is an existing directory without a trailing slash.
    my $dir = tempdir(CLEANUP => 1);
    my ($fh, $tmp_path) = tempfile();
    print $fh 'x';
    close($fh);

    my $file = Uniform::Upload::File->new({
        tempname => $tmp_path,
        filename => 'note.txt',
        size     => 1,
        type     => 'text/plain',
    });

    $file->save_to($dir);
    ok(-e File::Spec->catfile($dir, 'note.txt'),
        'save_to detects an existing directory target even without a trailing slash');
}

{
    # Destination is an exact file path, not a directory.
    my $dir = tempdir(CLEANUP => 1);
    my ($fh, $tmp_path) = tempfile();
    print $fh 'x';
    close($fh);

    my $file = Uniform::Upload::File->new({
        tempname => $tmp_path,
        filename => 'note.txt',
        size     => 1,
        type     => 'text/plain',
    });

    my $exact_target = File::Spec->catfile($dir, 'renamed.txt');
    $file->save_to($exact_target);
    ok(-e $exact_target, 'save_to writes to an exact target path when destination is not a directory');
}

{
    # save_to must sanitize an unsanitized filename before writing, even if
    # the caller never called sanitize_filename themselves. Note that 'evil'
    # here is a directory segment (once the backslash is normalized to '/'),
    # so basename() strips it along with '../../', leaving just 'payload.txt'
    # -- consistent with the malicious_path example already covered in
    # 01-methods.t.
    my $dir = tempdir(CLEANUP => 1);
    my ($fh, $tmp_path) = tempfile();
    print $fh 'x';
    close($fh);

    my $file = Uniform::Upload::File->new({
        tempname => $tmp_path,
        filename => '../../evil\\payload.txt',
        size     => 1,
        type     => 'text/plain',
    });

    $file->save_to("$dir/");

    ok(-e File::Spec->catfile($dir, 'payload.txt'),
        'save_to auto-sanitizes an unsanitized filename before writing');
    is($file->filename, 'payload.txt',
        'save_to updates filename() to the sanitized value as a side effect');
}

{
    throws_ok { Uniform::Upload::File->new({ size => 1 })->save_to(undef) }
        'Uniform::Exceptions',
        'save_to throws when destination is undef';

    throws_ok { Uniform::Upload::File->new({ size => 1 })->save_to('') }
        'Uniform::Exceptions',
        'save_to throws when destination is an empty string';
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $file = Uniform::Upload::File->new({
        tempname => File::Spec->catfile($dir, 'does-not-exist.tmp'),
        filename => 'whatever.txt',
        size     => 1,
        type     => 'text/plain',
    });

    throws_ok { $file->save_to("$dir/") } 'Uniform::Exceptions',
        'save_to throws when the temporary source file no longer exists';
}

done_testing();
