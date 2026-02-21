use Test2::V0;
use Data::Smile::XS qw(encode_smile decode_smile);

my $data = [ { foo => 1 }, { foo => 2 } ];
my $bin  = encode_smile($data);

like($bin, qr/^\x3A\x29\x0A\x03/s, 'header enables shared names+values');

# Expect at least one short shared key reference token 0x40 (index 0)
ok(index($bin, "\x40") >= 0, 'contains short shared key ref 0x40');

my $back = decode_smile($bin);
is($back, $data, 'decodes correctly');

done_testing;
