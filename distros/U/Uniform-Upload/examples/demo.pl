use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Uniform::Upload;
use File::Temp qw(tempfile);

# 1. Initialize standalone upload manager
my $uploader = Uniform::Upload->new(
    max_size      => '2MB',
    allowed_types => [qw( image/png image/jpeg application/pdf )],
);

# Create a dummy temporary file on disk for testing
my ($fh, $tmp_path) = tempfile(UNLINK => 1);
print $fh "Fake image bytes";
close $fh;

print "=== Testing Valid Upload ===\n";
my $valid_file = $uploader->wrap(
    name     => 'avatar',
    filename => '../../../uploads/profile_photo.png', # Attempted path traversal
    tmp_path => $tmp_path,
    size     => 1024,
    type     => 'image/png',
);

print "Original Filename:  " . $valid_file->filename . "\n";
print "Sanitized Filename: " . $valid_file->sanitized_filename . "\n";
print "Is Valid?           " . ($valid_file->is_valid ? 'Yes' : 'No') . "\n\n";

print "=== Testing Size Limit Validation ===\n";
my $oversized_file = $uploader->wrap(
    name     => 'raw_video',
    filename => 'movie.mp4',
    tmp_path => $tmp_path,
    size     => 10_000_000, # ~10MB (Exceeds 2MB limit)
    type     => 'video/mp4',
);

print "Is Valid?           " . ($oversized_file->is_valid ? 'Yes' : 'No') . "\n";
print "Error Message:      " . $oversized_file->error . "\n";
