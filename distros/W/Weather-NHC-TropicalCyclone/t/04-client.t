use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON::PP qw/decode_json encode_json/;
use File::Temp qw/tempfile/;
use MockHTTP;
use Weather::NHC::TropicalCyclone ();

sub slurp {
    my ($file) = @_;
    open my $fh, '<', $file or die $!;
    local $/;
    return <$fh>;
}

sub dies_like (&$;$) {
    my ( $code, $re, $name ) = @_;
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    ok !$ok && $err =~ $re, $name;
}

my $json = slurp('t/data/2026/CurrentStorms.json');
my $mock = MockHTTP->new(
    routes => {
        $Weather::NHC::TropicalCyclone::DEFAULT_URL => { success => 1, status => 200, content => $json },
        'mock://current' => { success => 1, status => 200, content => $json },
        $Weather::NHC::TropicalCyclone::DEFAULT_RSS_ATLANTIC => { success => 1, status => 200, content => '<rss>atlantic</rss>' },
        $Weather::NHC::TropicalCyclone::DEFAULT_RSS_EAST_PACIFIC => { success => 1, status => 200, content => '<rss>east</rss>' },
        $Weather::NHC::TropicalCyclone::DEFAULT_RSS_CENTRAL_PACIFIC => { success => 1, status => 200, content => '<rss>central</rss>' },
    },
);

my $nhc = Weather::NHC::TropicalCyclone->new( http => $mock );
isa_ok $nhc, 'Weather::NHC::TropicalCyclone';

is $nhc->load_json('{"activeStorms":[]}'), $nhc, 'load_json is chainable';
is_deeply $nhc->active_storms, [], 'empty feed supported';
is_deeply $nhc->get_storm_ids, [], 'empty id cache';
is $nhc->get_storm_by_id(undef), undef, 'undefined lookup returns undef';

$nhc->load_file('t/data/2026/CurrentStorms.json');
is_deeply $nhc->get_storm_ids, [qw/al042026 cp012026/], 'load_file builds sorted storm cache';
isa_ok $nhc->get_storm_by_id('al042026'), 'Weather::NHC::TropicalCyclone::Storm';
is $nhc->get_storm_by_id('missing'), undef, 'missing id returns undef';
is scalar @{ $nhc->active_storms }, 2, 'two active storms';

my $data = decode_json($json);
$data->{activeStorms}->[0]->{newFromNHC} = 1;
$nhc->load_json(encode_json($data));
like $nhc->validation_warnings->[0], qr/newFromNHC/, 'unknown field warning retained';
ok exists $nhc->get_storm_by_id('al042026')->{newFromNHC}, 'unknown field preserved';

my $report = $nhc->validate($json);
is scalar @{ $report->{errors} }, 0, 'validate accepts JSON text';
$report = $nhc->validate('{bad json');
like $report->{errors}->[0], qr/JSON decode error/, 'validate reports JSON decode failure';
$report = $nhc->validate({ activeStorms => [] });
is scalar @{ $report->{errors} }, 0, 'validate accepts decoded data';

dies_like { $nhc->load_json() } qr/JSON input is required/, 'load_json requires input';
dies_like { $nhc->load_json('{bad') } qr/JSON decode error/, 'load_json rejects malformed JSON';
dies_like { $nhc->load_json('{"activeStorms":{}}') } qr/validation failed/, 'load_json rejects invalid structure';
dies_like { $nhc->load_file() } qr/JSON file is required/, 'load_file requires path';
dies_like { $nhc->load_file('does-not-exist.json') } qr/Can't open/, 'load_file open error';

is $nhc->fetch(), $nhc, 'default fetch URL and timeout work with injected transport';
is $nhc->fetch( timeout => 0, url => 'mock://current' ), $nhc, 'named fetch options work';
is_deeply $nhc->get_storm_ids, [qw/al042026 cp012026/], 'fetch updates cache';

my ( $fh, $save ) = tempfile();
close $fh;
$nhc->fetch( 0, $save );
is slurp($save), $json, 'legacy positional fetch saves exact JSON';
unlink $save;

( $fh, $save ) = tempfile();
close $fh;
$nhc->fetch( timeout => 0, save_to => $save );
is slurp($save), $json, 'named save_to works';
unlink $save;

( $fh, $save ) = tempfile();
close $fh;
$nhc->fetch( timeout => 0, file => $save );
is slurp($save), $json, 'file alias works';
unlink $save;

is $nhc->fetch_rss_atlantic, '<rss>atlantic</rss>', 'Atlantic RSS';
is $nhc->fetch_rss_east_pacific, '<rss>east</rss>', 'East Pacific RSS';
is $nhc->fetch_rss_central_pacific, '<rss>central</rss>', 'Central Pacific RSS';

( $fh, $save ) = tempfile();
close $fh;
is $nhc->fetch_rss_atlantic($save), '<rss>atlantic</rss>', 'RSS can be saved';
is slurp($save), '<rss>atlantic</rss>', 'saved RSS content';
unlink $save;

my $slow = MockHTTP->new( sleep => 2 );
my $slow_nhc = Weather::NHC::TropicalCyclone->new( http => $slow );
dies_like { $slow_nhc->fetch(1) } qr/timed out/, 'legacy alarm timeout retained';

my $failed = MockHTTP->new( routes => { 'mock://bad' => { success => 0, status => 503 } } );
my $failed_nhc = Weather::NHC::TropicalCyclone->new( http => $failed );
dies_like { $failed_nhc->fetch( timeout => 0, url => 'mock://bad' ) } qr/503/, 'fetch HTTP failure propagated';
dies_like { $nhc->fetch( timeout => 0, save_to => 'no-such-dir/current.json' ) } qr/Can't open/, 'fetch save failure propagated';

done_testing;
