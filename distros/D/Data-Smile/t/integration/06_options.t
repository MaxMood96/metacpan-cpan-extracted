use Test2::V0;

use Data::Smile::PP qw(encode_smile decode_smile dump_smile load_smile);

use File::Temp qw(tempdir);

my $huge = '1267650600228229401496703205376'; # 2**100
my $smile = "\x3A\x29\x0A\x03\x26\x8D\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

my $decoded_default = decode_smile($smile);
ok(ref($decoded_default), 'default decode uses an object for huge integer');
is($decoded_default->bstr, $huge, 'default decode uses Math::BigInt value');

my $decoded_native = decode_smile($smile, { use_bigint => 0 });
ok(!ref($decoded_native), 'decode with use_bigint=0 returns native scalar');
like("$decoded_native", qr/1\.26765060022823e\+30|1267650600228229401496703205376/, 'decode with use_bigint=0 returns numeric approximation');


my $nested_smile = "\x3A\x29\x0A\x03\xF8\x26\x8D\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xF9";
my $nested_default = decode_smile( $nested_smile );
ok( ref( $nested_default->[0] ), 'default decode keeps nested huge integer as object' );
is( $nested_default->[0]->bstr, $huge, 'nested huge integer value preserved as Math::BigInt' );

my $nested_native = decode_smile( $nested_smile, { use_bigint => 0 } );
ok( !ref( $nested_native->[0] ), 'use_bigint=0 applies to nested huge integer values' );
like( "$nested_native->[0]", qr/1\.26765060022823e\+30|1267650600228229401496703205376/, 'nested huge integer falls back to native numeric approximation' );

my $encoded = encode_smile({ a => 1 }, {});
ok(length($encoded) > 4, 'encode_smile accepts empty options hashref');

my $encoded_no_header = encode_smile({ a => 1 }, { write_header => 0 });
ok(substr($encoded_no_header, 0, 3) ne "\x3A\x29\x0A", 'encode_smile can omit header');
is(decode_smile($encoded_no_header), { a => 1 }, 'decode_smile decodes headerless payload by default');

my $encoded_no_shared_values = encode_smile({ a => 'same', b => 'same' }, { shared_values => 0 });
my $decoded_no_shared_values = decode_smile($encoded_no_shared_values);
is($decoded_no_shared_values, { a => 'same', b => 'same' }, 'encode_smile supports shared_values option');

my $dir = tempdir(CLEANUP => 1);
my $file = "$dir/opts.sml";
ok(dump_smile($file, { x => 1 }, { write_header => 0 }), 'dump_smile passes encode options');
is(load_smile($file, {}), { x => 1 }, 'load_smile accepts options hashref');

like(
	dies { decode_smile($smile, { not_an_option => 1 }) },
	qr/Unknown option for decode_smile/,
	'decode_smile rejects unknown options',
);

like(
	dies { encode_smile({ a => 1 }, { use_bigint => 0 }) },
	qr/Unknown option for encode_smile/,
	'encode_smile rejects unknown options',
);

like(
	dies { decode_smile($encoded_no_header, { require_header => 1 }) },
	qr/Smile header required/,
	'decode_smile can require header',
);

like(
	dies { dump_smile($file, { x => 1 }, { use_bigint => 0 }) },
	qr/Unknown option for encode_smile/,
	'dump_smile rejects unknown options',
);

done_testing;
