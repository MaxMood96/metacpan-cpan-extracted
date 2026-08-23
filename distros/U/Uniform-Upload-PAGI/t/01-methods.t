use strict;
use warnings;
use FindBin;
use File::Temp qw(tempfile);

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../perl-Uniform/lib";
use lib "$FindBin::Bin/../../perl-Uniform-Upload/lib";

use Test::More;
use Test::Exception;
use Test::Deep;

use Uniform::Upload::PAGI;

# 1. Establish a virtual local temporary file node on disk to mock the multi-part file layout
my ($fh, $tmp_file_path) = tempfile();
print $fh "Asynchronous PAGI multipart upload data content testing block stream.";
close($fh);

# 2. Build a valid mock PAGI connection scope hash tracking multipart items
my $mock_scope = {
    type    => 'http',
    path    => '/submit-pagi-upload',
    uploads => [
        {
            field    => 'avatar_field',
            tempname => $tmp_file_path,
            filename => 'first_attempt_ignored.png',
            size     => 500,
            type     => 'image/gif',
        },
        {
            field    => 'avatar_field',
            tempname => $tmp_file_path,
            filename => 'final_winning_target.png',
            size     => 12345,
            type     => 'image/png',
        }
    ],
};

my $upload = Uniform::Upload::PAGI->new($mock_scope);

# =========================================================================
# ASSERTS
# =========================================================================
isa_ok($upload, 'Uniform::Upload', 'PAGI driver correctly inherits core upload base specification');
ok($upload->has_file('avatar_field'), 'Correctly flags field presence tracking properties');

my $file = $upload->file('avatar_field');
isa_ok($file, 'Uniform::Upload::File', 'Lazy encapsulation structures return clean file mutator targets');

# Verify your structural duplicate resolution rules pass cleanly
is($file->filename, 'final_winning_target.png', 'Prioritizes and isolates the trailing duplicate entry scalar definition');
is($file->type, 'image/png', 'Extracts and maps MIME file profiles successfully out of arrays');
is($file->size, 12345, 'Extracts non-zero numeric byte dimensions perfectly');

# 3. Exception Boundary Assert Check
throws_ok {
    Uniform::Upload::PAGI->new({ type => 'websocket' });
} 'Uniform::Exceptions', 'Throws explicit validation failure if connection context scope declarations mismatch http configurations';

# Evaporate the local test artifact safely
unlink($tmp_file_path);

done_testing();
