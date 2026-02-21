use Test2::V0;
use Data::Smile::XS qw(encode_smile decode_smile);

my $data = [ "x", "x", "x" ];
my $bin  = encode_smile($data);

# Expect shared value ref token 0x01 (index 0 + 1)
ok(index($bin, "\x01") >= 0, 'contains short shared value ref 0x01');

my $back = decode_smile($bin);
is($back, $data, 'decodes correctly');

done_testing;
