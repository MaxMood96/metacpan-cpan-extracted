package WWW::Bund::Caller;
our $VERSION = '0.002';
# ABSTRACT: Generic API call engine

use Moo;
use WWW::Bund::HTTPRequest;
use WWW::Bund::Response::JSON;
use WWW::Bund::Response::XML;
use WWW::Bund::Response::Raw;
use URI::Escape qw(uri_escape);
use Log::Any qw($log);
use Carp qw(croak);
use namespace::clean;


has registry => (is => 'ro', required => 1);


has auth => (is => 'ro', required => 1);


has cache => (is => 'ro', required => 1);


has rate_limiter => (is => 'ro', required => 1);


has io => (is => 'ro', required => 1);


sub call {
    my ($self, $api, $endpoint_name, %opts) = @_;

    my $endpoint = $self->registry->endpoint($endpoint_name);
    croak "Endpoint '$endpoint_name' belongs to API '$endpoint->{api}', not '$api'"
        if $endpoint->{api} ne $api;

    my $method   = uc($endpoint->{method});
    my $base_url = $opts{base_url} // $endpoint->{base_url};
    my $path     = $endpoint->{path};
    my $params   = $opts{params} // {};

    croak "No base_url for endpoint '$endpoint_name'" unless $base_url;

    # Substitute base_url parameters (e.g., {region} for abfallnavi)
    my %remaining_params = %$params;
    while ($base_url =~ /\{([^}]+)\}/g) {
        my $param = $1;
        croak "Missing base_url parameter '$param' for endpoint '$endpoint_name'"
            unless exists $remaining_params{$param};
        my $value = uri_escape(delete $remaining_params{$param});
        $base_url =~ s/\{\Q$param\E\}/$value/g;  # Replace all occurrences
    }

    # Substitute path parameters
    while ($path =~ /\{([^}]+)\}/g) {
        my $param = $1;
        croak "Missing path parameter '$param' for endpoint '$endpoint_name'"
            unless exists $remaining_params{$param};
        my $value = uri_escape(delete $remaining_params{$param});
        $path =~ s/\{\Q$param\E\}/$value/;
    }

    # Build URL
    $base_url =~ s{/$}{};
    $path =~ s{^/}{};
    my $url = "$base_url/$path";

    # Prepare body content for POST/PUT
    my $body_content;
    my @param_pairs;
    if (%remaining_params) {
        for my $k (sort keys %remaining_params) {
            my $v = $remaining_params{$k};
            next unless defined $v;
            push @param_pairs, uri_escape($k) . '=' . uri_escape($v);
        }
    }

    # Append query params for GET, use body for POST/PUT
    if ($method eq 'GET' && @param_pairs) {
        $url .= '?' . join('&', @param_pairs);
    } elsif (($method eq 'POST' || $method eq 'PUT') && @param_pairs) {
        $body_content = join('&', @param_pairs);
    }

    # Rate limiting
    $self->rate_limiter->check($api);

    # Cache check (GET only)
    my $cache_key;
    my $cache_ttl = $endpoint->{cache_ttl};
    if ($method eq 'GET') {
        $cache_key = "$method $url";
        if (my $cached = $self->cache->get($cache_key, $cache_ttl)) {
            $log->debug("Cache hit: $cache_key");
            return $self->_build_response($cached)->data;
        }
    }

    $log->debug("$method $url" . ($body_content ? " (body: " . length($body_content) . " bytes)" : ""));

    # Build headers
    my %headers = ('Accept' => 'application/json, application/xml, */*');
    if ($body_content) {
        $headers{'Content-Type'} = 'application/x-www-form-urlencoded';
    }
    my $auth_headers = $self->auth->headers_for($api);
    @headers{keys %$auth_headers} = values %$auth_headers;

    # Build and execute request
    my $req = WWW::Bund::HTTPRequest->new(
        method  => $method,
        url     => $url,
        headers => \%headers,
        ($body_content ? (content => $body_content) : ()),
    );

    my $response = $self->io->call($req);

    unless ($response->status >= 200 && $response->status < 300) {
        $log->errorf("API error: %s %s -> %s", $method, $url, $response->status);
        croak "Bund API error: HTTP " . $response->status . " for $method $url";
    }

    $log->infof("%s %s -> %s", $method, $url, $response->status);

    # Cache response
    if ($cache_key && $response->content) {
        $self->cache->set($cache_key, $response->content);
    }

    return $self->_build_response($response->content, $response->content_type)->data;
}


sub _build_response {
    my ($self, $content, $content_type) = @_;
    $content_type //= '';

    if ($content_type =~ m{application/json} || $content =~ /^\s*[\{\[]/) {
        return WWW::Bund::Response::JSON->new(
            content => $content, content_type => $content_type,
        );
    }
    if ($content_type =~ m{(?:application|text)/xml} || $content =~ /^\s*</) {
        return WWW::Bund::Response::XML->new(
            content => $content, content_type => $content_type,
        );
    }
    return WWW::Bund::Response::Raw->new(
        content => $content, content_type => $content_type,
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Caller - Generic API call engine

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund::Caller;

    my $caller = WWW::Bund::Caller->new(
        registry     => $registry,
        auth         => $auth,
        cache        => $cache,
        rate_limiter => $rate_limiter,
        io           => $io,
    );

    my $data = $caller->call('autobahn', 'autobahn_roads');
    my $data = $caller->call('autobahn', 'autobahn_webcams',
        params => { roadId => 'A7' }
    );

=head1 DESCRIPTION

The call engine coordinates endpoint lookup, URL building, path parameter
substitution, authentication, rate limiting, caching, HTTP execution, and
response parsing.

Flow:

=over

=item 1. Look up endpoint metadata from registry

=item 2. Build URL with path and query parameters

=item 3. Check rate limit

=item 4. Check cache (GET only)

=item 5. Add authentication headers

=item 6. Execute HTTP request via IO adapter

=item 7. Parse response (JSON, XML, or raw)

=item 8. Cache response (GET only)

=item 9. Return parsed data

=back

=head2 registry

L<WWW::Bund::Registry> instance for endpoint lookup. Required.

=head2 auth

L<WWW::Bund::Auth> instance for authentication headers. Required.

=head2 cache

L<WWW::Bund::Cache> instance for response caching. Required.

=head2 rate_limiter

L<WWW::Bund::RateLimit> instance for rate limiting. Required.

=head2 io

HTTP client implementing L<WWW::Bund::Role::IO>. Required.

=head2 call

    my $data = $caller->call($api_id, $endpoint_name, %options);

Execute an API call. Returns parsed data (HashRef or ArrayRef).

Options:

=over

=item * C<params> - HashRef of path and query parameters

=item * C<base_url> - Override endpoint's base URL

=back

Path parameters (C<{roadId}> in path) are substituted first. Remaining
parameters are:

=over

=item * Added as query params for GET requests

=item * Sent as form-encoded body for POST/PUT requests (Content-Type: application/x-www-form-urlencoded)

=back

Throws exception on HTTP errors (non-2xx status codes) or missing endpoints.

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
