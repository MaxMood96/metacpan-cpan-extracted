use Test2::V0;
use Data::Smile::XS qw( encode_smile decode_smile );

my $src = {
	foo => '41',
	bar => '41',
};

my $bin = encode_smile($src);

ok index( $bin, "\x01" ) >= 0, 'contains shared value backref token';

my $decoded = decode_smile($bin);

is $decoded, $src, 'decoded structure matches source';

$decoded->{foo} .= 'x';

is $decoded->{foo}, '41x', 'foo string mutation is local';
is $decoded->{bar}, '41', 'bar is independent after string mutation';

$decoded->{bar}++;

is $decoded->{bar}, 42, 'bar numeric increment is local';
is $decoded->{foo}, '41x', 'foo remains unchanged after bar++';

done_testing;
