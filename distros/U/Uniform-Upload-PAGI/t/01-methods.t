use strict;
use warnings;
use Test::More;
use Test::Exception;
use Uniform::Upload::PAGI;

my $mock_scope = {
    type    => 'http',
    method  => 'POST',
    headers => [ ['content-type', 'multipart/form-data; boundary=---123'] ],
};

# Test 1: Positional instantiation
my $pagi = Uniform::Upload::PAGI->new(
    $mock_scope,
    max_size      => '5MB',
    allowed_types => ['image/png'],
);

isa_ok($pagi, 'Uniform::Upload::PAGI');
isa_ok($pagi, 'Uniform::Upload');
is($pagi->max_size, 5242880, 'max_size inherited and parsed from base');
is_deeply($pagi->allowed_types, ['image/png'], 'allowed_types correctly passed via SUPER::new');

# Test 2: Named instantiation
my $pagi_named = Uniform::Upload::PAGI->new(
    scope    => $mock_scope,
    max_size => '1MB',
);

isa_ok($pagi_named, 'Uniform::Upload::PAGI');
is($pagi_named->max_size, 1048576, 'named options work via SUPER::new');

# Test 3: Invalid scope throws exception
dies_ok { Uniform::Upload::PAGI->new("invalid_scope") } 'croaks on non-hash scope';

done_testing();
