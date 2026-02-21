use Test2::V0;
use Data::Smile::XS qw(dump_smile load_smile encode_smile decode_smile);

use File::Temp qw(tempdir);
use IO::File;

my $dir  = tempdir(CLEANUP => 1);
my $file = "$dir/test.sml";

my $data = { a => 1, b => [ "x", "x" ] };

ok(dump_smile($file, $data), 'dump_smile(filename) ok');
is(load_smile($file), $data, 'load_smile+decode ok');

my $fh = IO::File->new($file, '>:raw');
ok($fh, 'opened fh');
ok(dump_smile($fh, $data), 'dump_smile(filehandle) ok');
$fh->close;

SKIP: {
	skip "Path::Tiny not installed", 2 unless eval { require Path::Tiny; 1 };
	my $p = Path::Tiny::path($file);
	ok(dump_smile($p, $data), 'dump_smile(Path::Tiny) ok');
	is(load_smile($p), $data, 'load_smile(Path::Tiny) ok');
}

done_testing;
