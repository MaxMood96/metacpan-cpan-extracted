use strict;
use warnings;
use Test::More;

unless ($ENV{WWW_BUND_LIVE_TEST}) {
    plan skip_all => 'Set WWW_BUND_LIVE_TEST=1 to run live API tests';
}

# For live tests, we need File::ShareDir to find our share/ dir
use File::Spec;
use FindBin;

# Override File::ShareDir to use local share/ during development
BEGIN {
    my $share = File::Spec->catdir($FindBin::Bin, '..', 'share');
    $ENV{WWW_BUND_SHARE_DIR} = $share;
}

use WWW::Bund;

my $bund = WWW::Bund->new(
    registry => WWW::Bund::Registry->new(
        registry_file  => File::Spec->catfile($FindBin::Bin, '..', 'share', 'registry.yml'),
        endpoints_file => File::Spec->catfile($FindBin::Bin, '..', 'share', 'endpoints.yml'),
    ),
);

# Autobahn
{
    my $roads = $bund->autobahn->roads;
    ok($roads, 'autobahn roads returned data');
    ok(ref $roads eq 'HASH', 'roads is a hashref');
    ok($roads->{roads}, 'has roads key');
    ok(scalar @{$roads->{roads}} > 0, 'has road entries');
    diag("Roads: " . join(', ', @{$roads->{roads}}[0..4]) . '...');
}

# Pegel-Online
{
    my $stations = $bund->pegel_online->stations;
    ok($stations, 'pegel_online stations returned data');
    ok(ref $stations eq 'ARRAY', 'stations is an arrayref');
    ok(scalar @$stations > 0, 'has station entries');
    diag("First station: $stations->[0]{longname}");
}

# Tagesschau
{
    my $homepage = $bund->tagesschau->homepage;
    ok($homepage, 'tagesschau homepage returned data');
    diag("Tagesschau returned " . (ref $homepage) . " data");
}

# DWD
{
    my $overview = $bund->dwd->station_overview(stationIds => '10865');
    ok($overview, 'DWD station overview returned data');
    diag("DWD returned " . (ref $overview) . " data");
}

done_testing;
