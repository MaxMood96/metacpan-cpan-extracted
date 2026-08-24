use strict;
use warnings;
use Test::More;
use Test::Exception;
use Uniform::Upload;

# Test 1: Manager initialization with string size limit
my $upload = Uniform::Upload->new(
    max_size      => '2MB',
    allowed_types => [qw( image/png image/jpeg )],
);

isa_ok($upload, 'Uniform::Upload');
is($upload->max_size, 2097152, 'max_size parses "2MB" string into bytes');
is_deeply($upload->allowed_types, ['image/png', 'image/jpeg'], 'allowed_types retains configured list');
is($upload->file_class, 'Uniform::Upload::File', 'file_class defaults to Uniform::Upload::File');

# Test 2: Wrap returns file object
my $file = $upload->wrap(
    name     => 'photo',
    filename => 'test.png',
    tmp_path => '/tmp/test_123',
    size     => 1024,
    type     => 'image/png',
);

isa_ok($file, 'Uniform::Upload::File');
ok($file->is_valid, 'file passes validation under limits');

# Test 3: Abstract extract method croaks when called directly on base
dies_ok { $upload->extract } 'extract() croaks on base class';

done_testing();
