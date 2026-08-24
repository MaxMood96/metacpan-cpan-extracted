use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Temp qw(tempfile);
use Uniform::Upload::File;

# Test 1: Filename sanitization against path traversal
my $file = Uniform::Upload::File->new(
    name     => 'avatar',
    filename => '../../../etc/passwd.png',
    tmp_path => '/tmp/upload_abc',
    size     => 512,
    type     => 'image/png',
);

is($file->filename, '../../../etc/passwd.png', 'raw filename preserved');
is($file->sanitized_filename, 'passwd.png', 'sanitized_filename strips relative paths');

# Test 2: Size validation failure
my $large_file = Uniform::Upload::File->new(
    name     => 'document',
    filename => 'big.pdf',
    tmp_path => '/tmp/upload_big',
    size     => 10000,
    max_size => 5000,
);

ok(!$large_file->is_valid, 'file fails validation when size exceeds max_size');
like($large_file->error, qr/exceeds maximum limit/, 'error string populated correctly');

# Test 3: MIME type validation failure
my $bad_type = Uniform::Upload::File->new(
    name          => 'script',
    filename      => 'hack.sh',
    tmp_path      => '/tmp/upload_sh',
    size          => 100,
    type          => 'text/x-shellscript',
    allowed_types => ['image/png'],
);

ok(!$bad_type->is_valid, 'file fails validation on disallowed MIME type');
like($bad_type->error, qr/not allowed/, 'MIME type error populated');

# Test 4: File copying operations
my ($fh, $temp_src) = tempfile(UNLINK => 1);
print $fh "dummy content";
close $fh;

my ($out_fh, $temp_dst) = tempfile(UNLINK => 1);
close $out_fh;

my $valid_file = Uniform::Upload::File->new(
    name     => 'file',
    filename => 'valid.txt',
    tmp_path => $temp_src,
    size     => 13,
);

lives_ok { $valid_file->copy_to($temp_dst) } 'copy_to succeeds on valid file';

done_testing();
