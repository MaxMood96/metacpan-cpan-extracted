use v5.10; use strict; use warnings;
use Test::More;
use Curl::Impersonate;

my @t = Curl::Impersonate->targets;
ok(scalar(@t) >= 1, 'at least one impersonate target');
ok((grep { /^chrome/ } @t), 'a chrome target exists');
ok((grep { /^safari/ } @t), 'a safari target exists');
is_deeply([@t], [sort @t], 'targets are returned sorted');

# a made-up target must be rejected by new()
eval { Curl::Impersonate->new(impersonate => 'notabrowser999') };
like($@, qr/unknown impersonate target/, 'bad target croaks');

done_testing;
