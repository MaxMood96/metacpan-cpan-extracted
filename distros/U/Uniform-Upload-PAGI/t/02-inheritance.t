use strict;
use warnings;
use Test::More;
use Uniform::Upload::PAGI;

my $mock_scope = { type => 'http' };
my $pagi = Uniform::Upload::PAGI->new($mock_scope);

ok($pagi->isa('Uniform::Upload'), 'inherits directly from Uniform::Upload');
ok($pagi->can('wrap'), 'can call base wrap method');
ok($pagi->can('extract_async'), 'implements async extraction interface');

# Verify wrapping through subclass works correctly
my $file = $pagi->wrap(
    name     => 'avatar',
    filename => 'test.png',
    tmp_path => '/tmp/pagi_upload_123',
    size     => 2048,
    type     => 'image/png',
);

isa_ok($file, 'Uniform::Upload::File');
ok($file->is_valid, 'wrapped file object is valid');

done_testing();
