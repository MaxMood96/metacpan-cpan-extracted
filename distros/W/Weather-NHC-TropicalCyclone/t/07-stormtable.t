use strict;
use warnings;
use Test::More;
use Weather::NHC::TropicalCyclone::StormTable ();

sub dies_like (&$;$) {
    my ( $code, $re, $name ) = @_;
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    ok !$ok && $err =~ $re, $name;
}

my $data = <<'TABLE';
ALPHA, AL, L,  ,  ,  ,  , 01, 2024, HU, O, 2024060100, 2024060200, , , , , , ARCHIVE, , AL012024
ALPHA, EP, L,  ,  ,  ,  , 02, 2025, TS, O, 2025070100, 2025070200, , , , , , ARCHIVE, , EP022025
BETA, AL, L,  ,  ,  ,  , 03, 2025, TD, O, 2025080100, 2025080200, , , , , , ARCHIVE, , AL032025
TABLE

my $table = Weather::NHC::TropicalCyclone::StormTable->new( data => $data );
isa_ok $table, 'Weather::NHC::TropicalCyclone::StormTable';
is scalar @{ $table->storm_table }, 3, 'custom storm table ingested';
is_deeply $table->get_storm_numbers(2025, 'AL'), ['03'], 'storm numbers by year/basin';
is_deeply $table->get_storm_numbers(1999, 'AL'), [], 'missing storm numbers are empty';

ok scalar grep( $_ eq '2025', @{ $table->years } ), 'years';
is scalar @{ $table->by_year(2025) }, 2, 'by_year';
is_deeply $table->by_year(1900), [], 'missing year empty';
ok scalar grep( $_ eq 'ALPHA', @{ $table->names } ), 'names';
is scalar @{ $table->by_name('alpha') }, 2, 'by_name case insensitive';
is_deeply $table->by_name('missing'), [], 'missing name empty';
ok scalar grep( $_ eq 'AL', @{ $table->basins } ), 'basins';
is scalar @{ $table->by_basin('al') }, 2, 'by_basin';
is_deeply $table->by_basin('xx'), [], 'missing basin empty';
ok scalar grep( $_ eq 'AL032025', @{ $table->nhc_designations } ), 'designations';
is scalar @{ $table->by_nhc_designation('al032025') }, 1, 'by designation';
is_deeply $table->by_nhc_designation('xx'), [], 'missing designation empty';
ok scalar grep( $_ eq 'HU', @{ $table->storm_kinds } ), 'storm kinds';
is scalar @{ $table->by_storm_kind('hu') }, 1, 'by kind';
is_deeply $table->by_storm_kind('xx'), [], 'missing kind empty';
is scalar @{ $table->get_by_year_basin(2025, 'AL') }, 1, 'year/basin indexing fixed';

is $table->get_archive_url(2025), 'https://ftp.nhc.noaa.gov/atcf/archive/2025', 'archive URL';
is $table->get_history_archive_url(2025, 'AL', 3), 'https://ftp.nhc.noaa.gov/atcf/archive/2025/aAL032025.dat.gz', 'history URL';
is $table->get_best_track_archive_url(2025, 'AL', 3), 'https://ftp.nhc.noaa.gov/atcf/archive/2025/bAL032025.dat.gz', 'best track URL';
is $table->get_fixes_archive_url(2025, 'AL', 3), 'https://ftp.nhc.noaa.gov/atcf/archive/2025/fAL032025.dat.gz', 'fixes URL';

my $updated = <<'TABLE';
GAMMA, CP, L,  ,  ,  ,  , 01, 2026, TS, O, 2026080100, 2026080200, , , , , , ARCHIVE, , CP012026
TABLE

{
    package TableHTTP;
    sub new { bless { success => $_[1], content => $_[2] }, $_[0] }
    sub get { my $s = shift; return { success => $s->{success}, status => $s->{success} ? 200 : 500, content => $s->{content} } }
}

my $live = Weather::NHC::TropicalCyclone::StormTable->new( data => $data, http => TableHTTP->new( 1, $updated ) );
$live->get_latest_table;
is_deeply $live->names, ['GAMMA'], 'get_latest_table replaces indexes with downloaded table';
is_deeply $live->get_storm_numbers(2026, 'CP'), ['01'], 'downloaded table actually ingested';

my $fail = Weather::NHC::TropicalCyclone::StormTable->new( data => $data, http => TableHTTP->new( 0, q{} ) );
dies_like { $fail->get_latest_table } qr/Unable to retreive/, 'table fetch failure';

my $line = Weather::NHC::TropicalCyclone::StormTable->_parse_line(' NAME, al, L,  ,  ,  ,  , 01, 2020, hu');
is $line->[0], 'NAME', '_parse_line name normalized';
is $line->[1], 'AL', '_parse_line basin normalized';
is $line->[9], 'HU', '_parse_line kind normalized';

my $full = Weather::NHC::TropicalCyclone::StormTable->new;
ok scalar @{ $full->storm_table } > 1000, 'embedded historical table still loads';

done_testing;
