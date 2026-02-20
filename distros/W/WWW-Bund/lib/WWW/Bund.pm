package WWW::Bund;
our $VERSION = '0.002';
# ABSTRACT: Perl client for German Federal Government APIs (bund.dev)

use Moo;
use WWW::Bund::Registry;
use WWW::Bund::Caller;
use WWW::Bund::Auth;
use WWW::Bund::Cache;
use WWW::Bund::RateLimit;
use WWW::Bund::LWPIO;
use WWW::Bund::API::Autobahn;
use WWW::Bund::API::NINA;
use WWW::Bund::API::PegelOnline;
use WWW::Bund::API::Tagesschau;
use WWW::Bund::API::Bundestag;
use WWW::Bund::API::DWD;
use File::Spec;
use namespace::clean;


has io => (
    is      => 'lazy',
    builder => sub { WWW::Bund::LWPIO->new },
);


has cache_dir => (
    is      => 'lazy',
    builder => sub {
        my $base = $ENV{XDG_CACHE_HOME}
            // File::Spec->catdir($ENV{HOME} // (getpwuid($<))[7], '.cache');
        File::Spec->catdir($base, 'www-bund');
    },
);


has registry => (
    is      => 'lazy',
    builder => sub { WWW::Bund::Registry->new },
);


has auth => (
    is      => 'lazy',
    builder => sub { WWW::Bund::Auth->new },
);


has cache => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        WWW::Bund::Cache->new(cache_dir => $self->cache_dir);
    },
);


has rate_limiter => (
    is      => 'lazy',
    builder => sub { WWW::Bund::RateLimit->new },
);


has caller => (
    is      => 'lazy',
    builder => sub {
        my $self = shift;
        WWW::Bund::Caller->new(
            registry     => $self->registry,
            auth         => $self->auth,
            cache        => $self->cache,
            rate_limiter => $self->rate_limiter,
            io           => $self->io,
        );
    },
);


# Generic call interface
sub call {
    my ($self, $api, $endpoint, %opts) = @_;
    return $self->caller->call($api, $endpoint, %opts);
}


# Discovery
sub list {
    my ($self, %filters) = @_;
    return $self->registry->list(%filters);
}


sub search {
    my ($self, $query) = @_;
    return $self->registry->search($query);
}


sub info {
    my ($self, $id) = @_;
    return $self->registry->info($id);
}


# API adapters
has autobahn => (
    is      => 'lazy',
    builder => sub { WWW::Bund::API::Autobahn->new(client => shift) },
);


has nina => (
    is      => 'lazy',
    builder => sub { WWW::Bund::API::NINA->new(client => shift) },
);


has pegel_online => (
    is      => 'lazy',
    builder => sub { WWW::Bund::API::PegelOnline->new(client => shift) },
);


has tagesschau => (
    is      => 'lazy',
    builder => sub { WWW::Bund::API::Tagesschau->new(client => shift) },
);


has bundestag => (
    is      => 'lazy',
    builder => sub { WWW::Bund::API::Bundestag->new(client => shift) },
);


has dwd => (
    is      => 'lazy',
    builder => sub { WWW::Bund::API::DWD->new(client => shift) },
);


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund - Perl client for German Federal Government APIs (bund.dev)

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund;

    my $bund = WWW::Bund->new;

    # Generic interface
    my $data = $bund->call('autobahn', 'autobahn_roads');

    # Discovery
    my $apis = $bund->list;
    my $results = $bund->search('autobahn');
    my $info = $bund->info('autobahn');

    # Type-safe API adapters
    my $roads = $bund->autobahn->roads;
    my $webcams = $bund->autobahn->webcams('A7');
    my $warnings = $bund->nina->warnings('091620000000');
    my $stations = $bund->pegel_online->stations;

=head1 DESCRIPTION

WWW::Bund provides a Perl client for German Federal Government APIs available
through L<https://bund.dev>. It includes 16 implemented APIs with 78 endpoints,
covering traffic, weather, news, water levels, parliament data, and more.

The module provides both a generic C<call> interface and type-safe API adapters
for commonly-used APIs. All responses are automatically cached on disk with
configurable TTLs, and rate-limiting is enforced per API.

=head2 Available APIs

=over

=item * L<WWW::Bund::API::Autobahn> - Roadworks, webcams, warnings, charging stations

=item * L<WWW::Bund::API::NINA> - Civil protection warnings

=item * L<WWW::Bund::API::PegelOnline> - Water level gauges and measurements

=item * L<WWW::Bund::API::Tagesschau> - News from Tagesschau

=item * L<WWW::Bund::API::Bundestag> - Federal parliament data

=item * L<WWW::Bund::API::DWD> - Weather warnings from DWD

=back

See L<WWW::Bund::Registry> for the full list of 31 registered APIs.

=head2 io

HTTP client for making API requests. Defaults to L<WWW::Bund::LWPIO>.

Can be overridden with a custom class implementing L<WWW::Bund::Role::IO>.

=head2 cache_dir

Directory for caching API responses. Defaults to XDG-compliant location:
C<$XDG_CACHE_HOME/www-bund> or C<~/.cache/www-bund>.

=head2 registry

L<WWW::Bund::Registry> instance for API and endpoint metadata.

=head2 auth

L<WWW::Bund::Auth> instance for managing API authentication.

=head2 cache

L<WWW::Bund::Cache> instance for disk-based response caching.

=head2 rate_limiter

L<WWW::Bund::RateLimit> instance for enforcing per-API rate limits.

=head2 caller

L<WWW::Bund::Caller> instance for executing API calls with auth, caching, and rate-limiting.

=head2 call

    my $data = $bund->call($api_id, $endpoint_name, %options);

Execute a generic API call. Returns parsed response data (usually HashRef or ArrayRef).

Options:

=over

=item * C<params> - HashRef of path and query parameters

=item * C<base_url> - Override the endpoint's base URL

=back

Example:

    my $roads = $bund->call('autobahn', 'autobahn_roads');
    my $webcams = $bund->call('autobahn', 'autobahn_webcams',
        params => { roadId => 'A7' }
    );

=head2 list

    my $apis = $bund->list;
    my $apis = $bund->list(tag => 'traffic');
    my $apis = $bund->list(auth => 'none');

List all registered APIs. Returns ArrayRef of API metadata HashRefs.

Filters:

=over

=item * C<tag> - Filter by tag (e.g., 'traffic', 'weather')

=item * C<auth> - Filter by auth type (e.g., 'none', 'api_key')

=back

=head2 search

    my $results = $bund->search('autobahn');

Search APIs by ID, title, provider, or tags. Returns ArrayRef of matching APIs.

=head2 info

    my $info = $bund->info('autobahn');

Get full metadata for an API. Returns HashRef with id, title, provider, auth, tags, etc.

Throws exception if API not found.

=head2 autobahn

L<WWW::Bund::API::Autobahn> adapter for highway traffic data.

=head2 nina

L<WWW::Bund::API::NINA> adapter for civil protection warnings.

=head2 pegel_online

L<WWW::Bund::API::PegelOnline> adapter for water level gauges.

=head2 tagesschau

L<WWW::Bund::API::Tagesschau> adapter for news from Tagesschau.

=head2 bundestag

L<WWW::Bund::API::Bundestag> adapter for Federal Parliament data.

=head2 dwd

L<WWW::Bund::API::DWD> adapter for weather warnings from DWD.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
