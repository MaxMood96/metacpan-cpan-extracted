use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Spec;
use FindBin;

use WWW::Bund::Registry;

my $share = File::Spec->catdir($FindBin::Bin, '..', 'share');

my $reg = WWW::Bund::Registry->new(
    registry_file  => File::Spec->catfile($share, 'registry.yml'),
    endpoints_file => File::Spec->catfile($share, 'endpoints.yml'),
);

# list all APIs
{
    my $all = $reg->list;
    ok(ref $all eq 'ARRAY', 'list returns arrayref');
    ok(scalar @$all > 0, 'registry has APIs');

    my %ids = map { $_->{id} => 1 } @$all;
    ok($ids{autobahn}, 'autobahn in registry');
    ok($ids{nina}, 'nina in registry');
    ok($ids{pegel_online}, 'pegel_online in registry');
    ok($ids{tagesschau}, 'tagesschau in registry');
    ok($ids{bundestag}, 'bundestag in registry');
    ok($ids{dwd}, 'dwd in registry');
}

# filter by tag
{
    my $transport = $reg->list(tag => 'transport');
    ok(scalar @$transport > 0, 'filter by tag returns results');
    my %ids = map { $_->{id} => 1 } @$transport;
    ok($ids{autobahn}, 'autobahn has transport tag');
}

# filter by auth
{
    my $public = $reg->list(auth => 'none');
    ok(scalar @$public > 0, 'filter by auth returns results');
    for my $api (@$public) {
        is($api->{auth}, 'none', "API $api->{id} has no auth");
    }
}

# search
{
    my $results = $reg->search('wetter');
    ok(ref $results eq 'ARRAY', 'search returns arrayref');
    my %ids = map { $_->{id} => 1 } @$results;
    ok($ids{dwd}, 'search for wetter finds DWD');
}

# info
{
    my $info = $reg->info('autobahn');
    is($info->{id}, 'autobahn', 'info returns correct API');
    is($info->{provider}, 'Autobahn GmbH', 'info has provider');
    ok(ref $info->{tags} eq 'ARRAY', 'info has tags array');

    throws_ok { $reg->info('nonexistent_api') } qr/Unknown API/, 'info dies on unknown API';
}

# endpoint lookup
{
    my $ep = $reg->endpoint('autobahn_roads');
    is($ep->{api}, 'autobahn', 'endpoint has correct api');
    is($ep->{method}, 'get', 'endpoint has correct method');
    is($ep->{path}, '/', 'endpoint has correct path');
    ok($ep->{base_url}, 'endpoint has base_url');

    throws_ok { $reg->endpoint('nonexistent_endpoint') } qr/Unknown endpoint/, 'endpoint dies on unknown';
}

# endpoints_for_api
{
    my $eps = $reg->endpoints_for_api('autobahn');
    ok(ref $eps eq 'ARRAY', 'endpoints_for_api returns arrayref');
    ok(scalar @$eps >= 7, 'autobahn has at least 7 endpoints');
}

done_testing;
