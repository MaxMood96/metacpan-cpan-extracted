use strict;
use warnings;
use Test::More;
use Test::Exception;
use File::Spec;
use FindBin;
use JSON::MaybeXS qw(encode_json);

use WWW::Bund::Registry;
use WWW::Bund::Caller;
use WWW::Bund::Auth;
use WWW::Bund::Cache;
use WWW::Bund::RateLimit;
use WWW::Bund::HTTPResponse;

# MockIO: record requests and return canned responses
{
    package MockIO;
    use Moo;
    with 'WWW::Bund::Role::IO';

    has requests  => (is => 'ro', default => sub { [] });
    has responses => (is => 'ro', default => sub { {} });

    has default_response => (is => 'ro');

    sub call {
        my ($self, $req) = @_;
        push @{$self->requests}, $req;

        my $url = $req->url;
        # Match longest pattern first to avoid ambiguity
        for my $pattern (sort { length($b) <=> length($a) } keys %{$self->responses}) {
            next unless length $pattern;
            if ($url =~ /\Q$pattern\E/) {
                return $self->responses->{$pattern};
            }
        }

        if (my $default = $self->default_response) {
            return $default;
        }

        return WWW::Bund::HTTPResponse->new(
            status  => 200,
            content => '{"ok":true}',
        );
    }
}

my $share = File::Spec->catdir($FindBin::Bin, '..', 'share');
my $cache_dir = File::Spec->catdir($FindBin::Bin, '..', '.test-cache');

my $registry = WWW::Bund::Registry->new(
    registry_file  => File::Spec->catfile($share, 'registry.yml'),
    endpoints_file => File::Spec->catfile($share, 'endpoints.yml'),
);

my $mock = MockIO->new(
    responses => {
        'o/autobahn/' => WWW::Bund::HTTPResponse->new(
            status       => 200,
            content      => encode_json({ roads => [qw(A1 A2 A3)] }),
            content_type => 'application/json',
        ),
        'roadworks' => WWW::Bund::HTTPResponse->new(
            status       => 200,
            content      => encode_json({ roadworks => [] }),
            content_type => 'application/json',
        ),
        'stations.json' => WWW::Bund::HTTPResponse->new(
            status       => 200,
            content      => encode_json({ stations => [{ name => 'MAXAU' }] }),
            content_type => 'application/json',
        ),
        'conferences.xml' => WWW::Bund::HTTPResponse->new(
            status       => 200,
            content      => '<tagesordnungen><tagesordnung><date>01.01.2025</date><sitzungsnummer>1</sitzungsnummer><name>Test-Sitzung</name></tagesordnung></tagesordnungen>',
            content_type => 'application/xml',
        ),
    },
);

my $caller = WWW::Bund::Caller->new(
    registry     => $registry,
    auth         => WWW::Bund::Auth->new,
    cache        => WWW::Bund::Cache->new(cache_dir => $cache_dir),
    rate_limiter => WWW::Bund::RateLimit->new,
    io           => $mock,
);

# basic call without params
{
    my $data = $caller->call('autobahn', 'autobahn_roads');
    is_deeply($data->{roads}, [qw(A1 A2 A3)], 'basic call returns parsed JSON');

    my $req = $mock->requests->[-1];
    is($req->method, 'GET', 'request method is GET');
    like($req->url, qr{verkehr\.autobahn\.de/o/autobahn/$}, 'request URL correct');
}

# call with path params
{
    my $data = $caller->call('autobahn', 'autobahn_roadworks',
        params => { roadId => 'A1' },
    );

    my $req = $mock->requests->[-1];
    like($req->url, qr{/autobahn/A1/services/roadworks}, 'path parameter substituted');
    unlike($req->url, qr{\{roadId\}}, 'no placeholder left in URL');
}

# missing path parameter
{
    throws_ok {
        $caller->call('autobahn', 'autobahn_roadworks')
    } qr/Missing path parameter/, 'dies on missing path param';
}

# wrong API for endpoint
{
    throws_ok {
        $caller->call('nina', 'autobahn_roads')
    } qr/belongs to API/, 'dies when endpoint does not match API';
}

# pegel_online call
{
    my $data = $caller->call('pegel_online', 'pegel_online_stations');
    ok($data->{stations}, 'pegel_online stations call works');
}

# XML response parsing (bundestag)
{
    my $data = $caller->call('bundestag', 'bundestag_conferences');
    is(ref $data, 'HASH', 'XML response parsed to hash');
    is(ref $data->{tagesordnung}, 'HASH', 'XML child element parsed');
    is($data->{tagesordnung}{date}, '01.01.2025', 'XML element text extracted');
    is($data->{tagesordnung}{name}, 'Test-Sitzung', 'XML element name extracted');
}

# HTTP error handling
{
    my $error_mock = MockIO->new(
        default_response => WWW::Bund::HTTPResponse->new(
            status  => 500,
            content => 'Internal Server Error',
        ),
    );

    my $error_cache_dir = File::Spec->catdir($FindBin::Bin, '..', '.test-cache-error');
    my $error_caller = WWW::Bund::Caller->new(
        registry     => $registry,
        auth         => WWW::Bund::Auth->new,
        cache        => WWW::Bund::Cache->new(cache_dir => $error_cache_dir),
        rate_limiter => WWW::Bund::RateLimit->new,
        io           => $error_mock,
    );

    throws_ok {
        $error_caller->call('autobahn', 'autobahn_roads')
    } qr/HTTP 500/, 'dies on HTTP error';

    File::Path::remove_tree($error_cache_dir) if -d $error_cache_dir;
}

# Cache: second call hits cache
{
    my $count_mock = MockIO->new(
        responses => {
            'o/autobahn/' => WWW::Bund::HTTPResponse->new(
                status       => 200,
                content      => encode_json({ roads => ['A1'] }),
                content_type => 'application/json',
            ),
        },
    );

    my $cache = WWW::Bund::Cache->new(cache_dir => $cache_dir);
    $cache->clear;

    my $cached_caller = WWW::Bund::Caller->new(
        registry     => $registry,
        auth         => WWW::Bund::Auth->new,
        cache        => $cache,
        rate_limiter => WWW::Bund::RateLimit->new,
        io           => $count_mock,
    );

    $cached_caller->call('autobahn', 'autobahn_roads');
    $cached_caller->call('autobahn', 'autobahn_roads');

    is(scalar @{$count_mock->requests}, 1, 'second call served from cache');

    $cache->clear;
}

# Cleanup
{
    use File::Path qw(remove_tree);
    remove_tree($cache_dir) if -d $cache_dir;
}

done_testing;
