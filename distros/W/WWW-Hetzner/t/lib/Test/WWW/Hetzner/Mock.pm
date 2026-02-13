package Test::WWW::Hetzner::MockIO;

use Moo;
use JSON::MaybeXS qw(encode_json decode_json);
use WWW::Hetzner::HTTPResponse;

with 'WWW::Hetzner::Role::IO';

has routes => (is => 'ro', default => sub { {} });
has base_url => (is => 'ro', default => '');

sub call {
    my ($self, $req) = @_;

    my $method = $req->method;

    # Extract path by stripping base_url
    my $path = $req->url;
    my $base = $self->base_url;
    $path =~ s{^\Q$base\E}{} if $base;
    $path =~ s{\?.*$}{};

    # Build backward-compatible opts for callbacks
    my %opts;
    if ($req->has_content && $req->content) {
        $opts{body} = decode_json($req->content);
    }

    my $key = "$method $path";
    my $routes = $self->routes;

    # Exact match
    if (exists $routes->{$key}) {
        return $self->_handle($routes->{$key}, $method, $path, %opts);
    }

    # Pattern match against $path
    for my $pattern (keys %$routes) {
        if ($path =~ /$pattern/) {
            return $self->_handle($routes->{$pattern}, $method, $path, %opts);
        }
    }

    die "No mock route for: $key";
}

sub _handle {
    my ($self, $handler, $method, $path, %opts) = @_;

    # If handler returns an HTTPResponse, use it directly
    if (ref $handler eq 'WWW::Hetzner::HTTPResponse') {
        return $handler;
    }

    my $data = ref $handler eq 'CODE'
        ? $handler->($method, $path, %opts)
        : $handler;

    # Allow callbacks to return HTTPResponse directly
    if (ref $data eq 'WWW::Hetzner::HTTPResponse') {
        return $data;
    }

    return WWW::Hetzner::HTTPResponse->new(
        status  => 200,
        content => ref $data ? encode_json($data) : ($data // ''),
    );
}

package Test::WWW::Hetzner::Mock;

use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use Path::Tiny qw(path);
use WWW::Hetzner::Cloud;
use WWW::Hetzner::Robot;

my $FIXTURES_DIR;

BEGIN {
    # t/lib/Test/WWW/Hetzner/Mock.pm -> t/fixtures
    $FIXTURES_DIR = path(__FILE__)->parent(5)->child('fixtures');
}

sub import {
    my $class = shift;
    my $caller = caller;

    no strict 'refs';
    *{"${caller}::mock_cloud"} = \&mock_cloud;
    *{"${caller}::mock_robot"} = \&mock_robot;
    *{"${caller}::load_fixture"} = \&load_fixture;
}

sub load_fixture {
    my ($name) = @_;
    my $file = $FIXTURES_DIR->child("$name.json");
    return decode_json($file->slurp_utf8);
}

sub mock_cloud {
    my (%routes) = @_;

    my $io = Test::WWW::Hetzner::MockIO->new(
        routes   => \%routes,
        base_url => 'https://api.hetzner.cloud/v1',
    );

    return WWW::Hetzner::Cloud->new(
        token => 'test-token',
        io    => $io,
    );
}

sub mock_robot {
    my (%routes) = @_;

    my $io = Test::WWW::Hetzner::MockIO->new(
        routes   => \%routes,
        base_url => 'https://robot-ws.your-server.de',
    );

    return WWW::Hetzner::Robot->new(
        user     => 'test-user',
        password => 'test-password',
        io       => $io,
    );
}

1;
