use Test2::V0;
use Data::Smile::XS qw(encode_smile decode_smile);

{
	package Local::Obj;
	sub new { bless { x => 1 }, shift }
	sub TO_JSON { return { y => 2 } }
}

my $obj = Local::Obj->new;
my $bin = encode_smile($obj);
my $val = decode_smile($bin);

is($val, { y => 2 }, 'TO_JSON used');

done_testing;
