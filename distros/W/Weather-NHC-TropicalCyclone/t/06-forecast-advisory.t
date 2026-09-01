use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use Weather::NHC::TropicalCyclone::ForecastAdvisory ();

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

my $input = 't/data/017.al202020.fst.txt';
my $control = slurp('t/data/017.al202020.fst');
my ( $fh, $output ) = tempfile();
close $fh;

for my $args (
    {},
    { input_file => $input },
    { output_file => $output },
    { input_file => $input, input_text => 'both', output_file => $output },
) {
    dies_like {
        Weather::NHC::TropicalCyclone::ForecastAdvisory->new(%$args)
    } qr/Constructor requires/, 'constructor validates input/output combination';
}

my $f = Weather::NHC::TropicalCyclone::ForecastAdvisory->new(
    input_file  => $input,
    output_file => $output,
);
isa_ok $f, 'Weather::NHC::TropicalCyclone::ForecastAdvisory';
is $f->input_file, $input, 'input_file accessor';
is $f->output_file, $output, 'output_file accessor';
my $records = $f->extract_atcf;
is ref $records, 'ARRAY', 'extract_atcf returns arrayref';
ok @$records > 1, 'multiple ATCF records extracted';
is $f->save_atcf, $output, 'save_atcf returns output path';
is slurp($output), $control, 'saved ATCF matches historical control';
is $f->extract_and_save_atcf, $output, 'combined extraction/save';

my $text = slurp($input);
my $from_text = Weather::NHC::TropicalCyclone::ForecastAdvisory->new(
    input_text  => $text,
    output_file => $output,
);
is_deeply $from_text->extract_atcf, $records, 'input_text and input_file produce same ATCF';

my $no_output = Weather::NHC::TropicalCyclone::ForecastAdvisory->new(
    input_text  => $text,
    output_file => undef,
);
$no_output->extract_atcf;
dies_like { $no_output->save_atcf } qr/(?:No output_file|Failed to open output ATCF file)/, 'save requires usable output path';

my $line = '_BASIN_, 01, 2009010100,   , OFCL,   0, 000N,  000W,  30,    0,   ,  34, NEQ,    0,    0,    0,    0,    0,    0,   0,  40,   0,    ,   0, TBK,  65,  17,           ,  , 12, NEQ,  60,  60,   0,   0';
my @body = ('34 KT... 10NE  20SE  30SW  40NW.', 'next');
my ( $next, $out ) = Weather::NHC::TropicalCyclone::ForecastAdvisory::_parseIotachs( \@body, 0, $line );
is $next, 1, '_parseIotachs advances input index';
is scalar @$out, 1, '_parseIotachs creates record';
like $out->[0], qr/\b34\b/, 'isotach written';

@body = ('no isotachs');
( $next, $out ) = Weather::NHC::TropicalCyclone::ForecastAdvisory::_parseIotachs( \@body, 0, $line );
is $next, 0, 'no-isotach input index unchanged';
is_deeply $out, [$line], 'no-isotach path retains line';

my $cross_year = <<'ADV';
000
WTNT21 KNHC 311500
TCMAT1

HURRICANE TEST FORECAST/ADVISORY NUMBER  1
NWS NATIONAL HURRICANE CENTER MIAMI FL       AL012026
1500 UTC THU DEC 31 2026

HURRICANE CENTER LOCATED NEAR 20.0N  60.0W AT 31/1500Z
PRESENT MOVEMENT TOWARD THE NORTH OR 360 DEGREES AT  10 KT
ESTIMATED MINIMUM CENTRAL PRESSURE  990 MB
MAX SUSTAINED WINDS  70 KT WITH GUSTS TO  85 KT.

FORECAST VALID 01/0000Z 21.0N  60.0W
MAX WIND  70 KT...GUSTS  85 KT.

$$
ADV
my $year_test = Weather::NHC::TropicalCyclone::ForecastAdvisory->new(
    input_text => $cross_year, output_file => $output,
);
my $yr = $year_test->extract_atcf;
ok @$yr >= 2, 'cross-year advisory parsed';
is 0 + substr( $yr->[-1], 29, 4 ), 9, 'December-to-January forecast period is 9 hours';

unlink $output;

# Historical/special-format regression cases exercise parser paths that are not
# present in the primary 2020 fixture but remain supported by the converter.
my @synthetic = (
    [
        'pre-2006 advisory date format',
        <<'ADV'
000
WTNT21 KNHC 021500
TCMAT1

HURRICANE TEST FORECAST/ADVISORY NUMBER  1
NWS TPC/NATIONAL HURRICANE CENTER MIAMI FL   AL012004
1500Z THU SEP 02 2004

HURRICANE CENTER LOCATED NEAR 20.0N  60.0W AT 02/1500Z
PRESENT MOVEMENT TOWARD THE NORTH OR 360 DEGREES AT  10 KT
ESTIMATED MINIMUM CENTRAL PRESSURE  990 MB
MAX SUSTAINED WINDS  70 KT WITH GUSTS TO  85 KT.

FORECAST VALID 03/0000Z 21.0N  60.0W
MAX WIND  70 KT...GUSTS  85 KT.

$$
ADV
    ],
    [
        'non-forecast advisory header and tropical-storm classification',
        <<'ADV'
000
WTNT21 KNHC 271500
TCMAT1

TROPICAL STORM TEST ADVISORY NUMBER  1
NWS NATIONAL HURRICANE CENTER MIAMI FL       AL012026
1500 UTC THU AUG 27 2026

TROPICAL STORM CENTER LOCATED NEAR 20.0N  60.0W AT 27/1500Z
PRESENT MOVEMENT TOWARD THE NORTH OR 360 DEGREES AT  10 KT
ESTIMATED MINIMUM CENTRAL PRESSURE 1000 MB
MAX SUSTAINED WINDS  40 KT WITH GUSTS TO  50 KT.

FORECAST VALID 28/0000Z 21.0N  60.0W
MAX WIND  40 KT...GUSTS  50 KT.

$$
ADV
    ],
    [
        'potential tropical cyclone classification',
        <<'ADV'
000
WTNT21 KNHC 271500
TCMAT1

POTENTIAL TROPICAL CYCLONE TEST FORECAST/ADVISORY NUMBER  1
NWS NATIONAL HURRICANE CENTER MIAMI FL       AL012026
1500 UTC THU AUG 27 2026

POTENTIAL TROPICAL CYCLONE CENTER LOCATED NEAR 20.0N  60.0W AT 27/1500Z
PRESENT MOVEMENT TOWARD THE NORTH OR 360 DEGREES AT  10 KT
ESTIMATED MINIMUM CENTRAL PRESSURE 1005 MB
MAX SUSTAINED WINDS  30 KT WITH GUSTS TO  40 KT.

OUTLOOK VALID 28/0000Z 21.0N  60.0W
MAX WIND  35 KT...GUSTS  45 KT.

$$
ADV
    ],
    [
        'dissipating center and dissipated forecast',
        <<'ADV'
000
WTNT21 KNHC 271500
TCMAT1

TROPICAL DEPRESSION TEST FORECAST/ADVISORY NUMBER  1
NWS NATIONAL HURRICANE CENTER MIAMI FL       AL012026
1500 UTC THU AUG 27 2026

TROPICAL DEPRESSION DISSIPATING NEAR 20.0N  60.0W AT 27/1500Z
PRESENT MOVEMENT TOWARD THE NORTH OR 360 DEGREES AT  10 KT
ESTIMATED MINIMUM CENTRAL PRESSURE 1008 MB
MAX SUSTAINED WINDS  25 KT WITH GUSTS TO  35 KT.

FORECAST VALID 28/0000Z DISSIPATED

$$
ADV
    ],
);

for my $case (@synthetic) {
    my ( $name, $advisory ) = @$case;
    my $synthetic = Weather::NHC::TropicalCyclone::ForecastAdvisory->new(
        input_text  => $advisory,
        output_file => $output,
    );
    my $parsed = eval { $synthetic->extract_atcf };
    ok !$@, "$name parses";
    ok ref($parsed) eq 'ARRAY' && @$parsed, "$name produces ATCF output";
}

done_testing;
