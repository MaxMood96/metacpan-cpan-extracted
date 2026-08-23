use strict;
use warnings;
use FindBin;
use File::Temp qw(tempfile);
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../perl-Uniform/lib";

use Test::More;
use Test::Exception;

use Uniform::Upload;

# Create a small virtual temporary text node file mock to simulate physical disk reads
my ($fh, $tmp_path) = File::Temp::tempfile();
print $fh "Fake content line context.";
close($fh);

# Mock a subclass configuration block simulating framework drivers
package Mock::Uniform::Upload;
use parent 'Uniform::Upload';
sub new {
    my ($class, $mock_files_map) = @_;
    return bless { files => $mock_files_map }, $class;
}
package main;

# Initialize standard file payload maps
my $upload_map = {
    avatar_field => {
        tempname => $tmp_path,
        filename => '../../malicious_path\null_byte_test.png',
        size     => 1_500_000, # 1.5MB
        type     => 'image/png',
    }
};

my $ul = Mock::Uniform::Upload->new($upload_map);

# =========================================================================
# RUN CHECKS
# =========================================================================
ok($ul->has_file('avatar_field'), 'Correctly identifies field presence tracking elements');
ok(!$ul->has_file('empty_field'), 'Correctly filters out missing fields safely');

# --- Test Subset A: Size and Type Validations ---
my $file_validate = $ul->file('avatar_field');
isa_ok($file_validate, 'Uniform::Upload::File', 'Accessor successfully instantiates value mutator object references');

lives_ok { $file_validate->max_size('2M') } 'Passes file size boundary evaluations safely when within limits';
throws_ok { $file_validate->max_size('1M') } 'Uniform::Exceptions', 'Throws clean ecosystem exception object if size breaks capping rules';

lives_ok { $file_validate->allowed_types(['image/jpeg', 'image/png']) } 'Passes file validation when content type matches';
throws_ok { $file_validate->allowed_types(['application/pdf']) } 'Uniform::Exceptions', 'Rejects bad content categories safely';

# --- Test Subset A2: file() accessor error paths and caching behavior ---
throws_ok { $ul->file('') } 'Uniform::Exceptions',
    'file() throws when given an empty field name';
throws_ok { $ul->file(undef) } 'Uniform::Exceptions',
    'file() throws when given an undef field name';
throws_ok { $ul->file('does_not_exist') } 'Uniform::Exceptions',
    'file() throws when the field has no matching upload data';

my $file_again = $ul->file('avatar_field');
is($file_again, $file_validate,
    'file() returns the same cached instance on repeated calls for the same field');


# --- Test Subset B: ISOLATED SANITIZATION TESTING ---
# Resetting the map to ensure clean, un-thrown object memories for the security scrub test
my $fresh_upload_map = {
    avatar_field => {
        tempname => $tmp_path,
        filename => '../../malicious_path\\null_byte_test.png', # Double escaped backslash for safety
        size     => 1_500_000,
        type     => 'image/png',
    }
};
my $ul_fresh = Mock::Uniform::Upload->new($fresh_upload_map);
my $file_sanitize = $ul_fresh->file('avatar_field');

$file_sanitize->sanitize_filename;

is(
    $file_sanitize->filename,
   'null_byte_test.png',
   'Successfully isolates files, drops cross-platform back references, and purges null bytes safely'
);

# Clean out the sandboxed temp tracking elements from your filesystem storage
unlink($tmp_path);

done_testing();
