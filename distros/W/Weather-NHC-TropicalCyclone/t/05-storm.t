use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON::PP qw/decode_json/;
use File::Temp qw/tempdir tempfile/;
use Cwd qw/getcwd/;
use MockHTTP;
use Weather::NHC::TropicalCyclone ();
use Weather::NHC::TropicalCyclone::Storm ();

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
my $forecast = slurp('t/data/017.al202020.fst.txt');
my $mock = MockHTTP->new(
    routes => {
        'mock://public'        => { success => 1, status => 200, content => '<html><pre>Public &amp; Advisory</pre></html>' },
        'mock://forecast'      => { success => 1, status => 200, content => "<html><pre>$forecast</pre></html>" },
        'mock://probabilities' => { success => 1, status => 200, content => '<pre>Probabilities</pre>' },
        'mock://discussion'    => { success => 1, status => 200, content => '<pre>Discussion</pre>' },
        'mock://no-pre'        => { success => 1, status => 200, content => '<html>none</html>' },
        'mock://graphics'      => { success => 1, status => 200, content => 'storm_graphics/AT4/refresh' },
        "$Weather::NHC::TropicalCyclone::Storm::DEFAULT_GRAPHICS_ROOT/AT4" => {
            success => 1, status => 200,
            content => '<a href="AL042026_001.png">x</a><a href="AL042026_track.png">x</a><a href="OTHER.png">x</a>',
        },
        'mock://no-prefix'     => { success => 1, status => 200, content => 'no graphics path' },
    },
);

my $nhc = Weather::NHC::TropicalCyclone->new( http => $mock );
$nhc->load_json($json);
my $storm = $nhc->get_storm_by_id('al042026');
my $cp    = $nhc->get_storm_by_id('cp012026');

isa_ok $storm, 'Weather::NHC::TropicalCyclone::Storm';
can_ok $storm, qw/latitudelongitude latitude_numberic kmzFile34kt kmzFile50kt kmzFile64kt/;
is $storm->kind, 'Tropical Storm', 'kind';
is $storm->basin, 'atlantic', 'Atlantic basin';
is $cp->basin, 'central_pacific', 'Central Pacific basin';

my $data = decode_json($json)->{activeStorms}->[0];
$data->{binNumber} = 'EP3';
my $ep = Weather::NHC::TropicalCyclone::Storm->new( $data, http => $storm->{_http} );
is $ep->basin, 'pacific', 'historical East Pacific return value preserved';

is_deeply [ sort keys %{ $storm->_get_validation_rules->{classifications} } ], [ sort qw/HU PC PTC STD STS TD TS TY/ ], 'validation metadata';
ok scalar grep( $_ eq 'publicAdvisory', @{ $storm->_fetch_text_types->{text} } ), 'text type metadata';
ok scalar grep( $_ eq 'trackCone', @{ $storm->_fetch_data_types->{kmzFile} } ), 'download type metadata';

my ( $text, $adv, $saved ) = $storm->fetch_publicAdvisory;
is $text, 'Public & Advisory', 'pre text extracted and entity decoded';
is $adv, '001', 'text advisory number';
is $saved, undef, 'no file by default';

my ( $fh, $file ) = tempfile();
close $fh;
( $text, $adv, $saved ) = $storm->fetch_forecastDiscussion($file);
is $text, 'Discussion', 'discussion fetched';
is $saved, $file, 'text save path returned';
is slurp($file), 'Discussion', 'text saved';
unlink $file;

( $text, $adv ) = $storm->fetch_windspeedProbabilities;
is $text, 'Probabilities', 'probabilities fetched';

( $text, $adv, $saved ) = $storm->fetch_forecastAdvisory;
is $text, $forecast, 'forecast advisory fetched directly';
is $adv, '001', 'forecast advisory number';
is $saved, undef, 'forecast advisory not saved by default';

my @atcf = $storm->fetch_forecastAdvisory_as_atcf;
is ref $atcf[0], 'ARRAY', 'forecast advisory converted to ATCF';
is $atcf[1], '001', 'ATCF conversion advisory number';

( $fh, $file ) = tempfile();
close $fh;
@atcf = $storm->fetch_forecastAdvisory_as_atcf($file);
ok -s $file, 'ATCF conversion saved';
unlink $file;

is_deeply $storm->fetch_forecastGraphics_urls,
    [
        "$Weather::NHC::TropicalCyclone::Storm::DEFAULT_GRAPHICS_ROOT/AT4/AL042026_001.png",
        "$Weather::NHC::TropicalCyclone::Storm::DEFAULT_GRAPHICS_ROOT/AT4/AL042026_track.png",
    ],
    'forecast graphics URLs';
is_deeply $cp->fetch_forecastGraphics_urls, [], 'no graphics resource returns empty list';

$storm->{forecastGraphics}->{url} = 'mock://no-prefix';
is_deeply $storm->fetch_forecastGraphics_urls, [], 'unresolvable graphics base returns empty list';
$storm->{forecastGraphics}->{url} = 'mock://graphics';

my $dir = tempdir( CLEANUP => 1 );
my $cwd = getcwd();
chdir $dir or die $!;

my %method_for = (
    forecastTrack                  => 'fetch_forecastTrack',
    windWatchesWarnings            => 'fetch_windWatchesWarnings',
    trackCone                      => 'fetch_trackCone',
    initialWindExtent              => 'fetch_initialWindExtent',
    forecastWindRadiiGIS           => 'fetch_forecastWindRadiiGIS',
    bestTrackGIS                   => 'fetch_bestTrackGIS',
    earliestArrivalTimeTSWindsGIS  => 'fetch_earliestArrivalTimeTSWindsGIS',
    mostLikelyTimeTSWindsGIS       => 'fetch_mostLikelyTimeTSWindsGIS',
    windSpeedProbabilitiesGIS      => 'fetch_windSpeedProbabilitiesGIS',
    stormSurgeWatchWarningGIS      => 'fetch_stormSurgeWatchWarningGIS',
    potentialStormSurgeFloodingGIS => 'fetch_potentialStormSurgeFloodingGIS',
    peakSurgeKML                   => 'fetch_peakSurgeKML',
);

for my $type ( sort keys %{ $storm->_fetch_data_types } ) {
    for my $resource ( @{ $storm->_fetch_data_types->{$type} } ) {
        my $method = $method_for{$resource};
        my $obj = $storm->{$resource};
        if ( ref($obj) && $obj->{$type} ) {
            my ( $out, $out_adv ) = $storm->$method($type);
            ok -e $out, "$method/$type downloaded";
            is $out_adv, ( exists $obj->{advNum} ? $obj->{advNum} : 'N/A' ), "$method/$type advisory";
            unlink $out;
        }
        else {
            is scalar $storm->$method($type), undef, "$method/$type unavailable returns undef";
        }
    }
}

is $storm->fetch_best_track, 'bal042026.dat', 'best track default filename';
ok -e 'bal042026.dat', 'best track downloaded';
unlink 'bal042026.dat';
is $storm->fetch_best_track('custom.dat'), 'custom.dat', 'best track custom filename';
unlink 'custom.dat';

chdir $cwd or die $!;

dies_like { Weather::NHC::TropicalCyclone::Storm->new([]) } qr/hash reference/, 'constructor requires hash';
for my $field (qw/id binNumber name classification/) {
    my %bad = %$data;
    delete $bad{$field};
    dies_like { Weather::NHC::TropicalCyclone::Storm->new(\%bad) } qr/$field/, "constructor requires $field";
}
my %bad_class = %$data;
$bad_class{classification} = 'XX';
dies_like { Weather::NHC::TropicalCyclone::Storm->new(\%bad_class) } qr/classification/, 'constructor rejects unknown classification';

$storm->classification('XX');
dies_like { $storm->kind } qr/Unknown storm classification/, 'kind protects unknown classification';
$storm->classification('TS');
$storm->classification(undef);
dies_like { $storm->kind } qr/not set/, 'kind requires classification';
$storm->classification('TS');

$storm->binNumber('XX1');
is $storm->basin, undef, 'unknown basin returns undef';
$storm->binNumber(undef);
dies_like { $storm->basin } qr/not set/, 'basin requires binNumber';
$storm->binNumber('AT4');

dies_like { $storm->_get_text('bogus') } qr/not a supported text resource/, 'invalid text resource rejected';
$storm->{forecastDiscussion}->{url} = 'mock://no-pre';
dies_like { $storm->fetch_forecastDiscussion } qr/No <pre>/, 'missing pre rejected';
$storm->{forecastDiscussion}->{url} = 'mock://discussion';

is scalar $cp->fetch_publicAdvisory, undef, 'unavailable text resource returns undef';
dies_like { $storm->fetch_trackCone('bogus') } qr/not a valid type/, 'invalid file type rejected';
dies_like { $storm->fetch_publicAdvisory('no-such-dir/advisory.txt') } qr/Failed to open/, 'text save open failure propagated';
dies_like { Weather::NHC::TropicalCyclone::Storm::_filename_from_url('filename') } qr/Unable to determine/, 'filename extraction failure';
is Weather::NHC::TropicalCyclone::Storm::_extract_pre_text('<pre>&lt;x&gt; &#65; &quot;q&quot; &#39;s&#39; &nbsp;</pre>', 'mock'), '<x> A "q" \'s\'  ', 'minimal HTML entity decoder';

done_testing;
