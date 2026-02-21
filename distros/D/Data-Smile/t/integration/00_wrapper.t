use Test2::V0;
use Data::Smile qw( encode_smile decode_smile dump_smile load_smile );

use File::Temp qw( tempdir );

ok( defined &encode_smile, 'encode_smile exported' );
ok( defined &decode_smile, 'decode_smile exported' );
ok( defined &dump_smile,   'dump_smile exported' );
ok( defined &load_smile,   'load_smile exported' );

my $data = {
	alpha => 1,
	beta  => [ 'x', 'y' ],
};

my $bytes = encode_smile( $data );
ok( length( $bytes ) > 4, 'encoded some bytes' );

my $round_trip = decode_smile( $bytes );
is( $round_trip, $data, 'encode_smile/decode_smile round trip' );

my $dir  = tempdir( CLEANUP => 1 );
my $file = "$dir/wrapper.smile";

ok( dump_smile( $file, $data ), 'dump_smile wrote file' );
is( load_smile( $file ), $data, 'load_smile round trip' );

done_testing;
