use Test2::V0;
use Data::Smile::PP qw(encode_smile decode_smile);

my $data = {
	a => 1,
	b => [2, 3, "x"],
	c => undef,
	d => "",
	e => { nested => "ok" },
};

my $smile = encode_smile($data);
ok(length($smile) > 4, 'encoded bytes');

my $back = decode_smile($smile);
is($back, $data, 'roundtrip');

done_testing;
