use Test2::V0;

if ( $] >= 5.008 and $] < 5.009 ) {
	plan skip_all => 'integration test skipped on Perl 5.8.x';
}

use Test2::Require::Module 'Path::Tiny';
use Data::Smile::PP qw(load_smile);
use Path::Tiny 'path';
use FindBin '$Bin';
use JSON::PP 'decode_json';

my $data = path($Bin)->parent->child('data');
my $smile_data = $data->child('smile');
my $json_data  = $data->child('json');

for my $child ( $smile_data->children( qr/\.smile$/ ) ) {
	my $basename = $child->basename('.smile');
	my $got      = load_smile( $child );
	my $expected = decode_json( $json_data->child("${basename}.jsn")->slurp_raw );
	is( $got, $expected, "file: $basename" );
}

done_testing;
