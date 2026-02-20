package WWW::Bund::Auth;
our $VERSION = '0.002';
# ABSTRACT: Authentication management for Bund APIs

use Moo;
use Carp qw(croak);
use namespace::clean;


has _config => (is => 'ro', default => sub { {} });

sub set {
    my ($self, $api, %opts) = @_;
    my $type = $opts{type} // 'api_key';

    croak "Unknown auth type: $type" unless $type =~ /^(none|api_key|oauth2)$/;

    if ($type eq 'api_key') {
        croak "env_var required for api_key auth" unless $opts{env_var};
    }
    if ($type eq 'oauth2') {
        croak "oauth_url required for oauth2 auth" unless $opts{oauth_url};
    }

    $self->_config->{$api} = {
        type               => $type,
        env_var            => $opts{env_var},
        header_name        => $opts{header_name} // 'Authorization',
        scheme             => $opts{scheme},
        oauth_url          => $opts{oauth_url},
        oauth_secret_env   => $opts{oauth_secret_env},
    };

    return $self->_config->{$api};
}


sub get {
    my ($self, $api) = @_;
    return $self->_config->{$api} // { type => 'none' };
}


sub headers_for {
    my ($self, $api) = @_;
    my $config = $self->get($api);
    my $type = $config->{type} // 'none';

    return {} if $type eq 'none';

    if ($type eq 'api_key') {
        my $env_var = $config->{env_var}
            or croak "No env_var configured for API '$api'";
        my $token = $ENV{$env_var}
            or croak "Environment variable '$env_var' not set for API '$api'";

        my $header_name = $config->{header_name} // 'Authorization';

        if ($header_name eq 'Authorization') {
            my $scheme = $config->{scheme} // 'Bearer';
            return { $header_name => "$scheme $token" };
        }

        return { $header_name => $token };
    }

    return {};
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Auth - Authentication management for Bund APIs

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund::Auth;

    my $auth = WWW::Bund::Auth->new;

    # Configure auth for API
    $auth->set('my_api',
        type     => 'api_key',
        env_var  => 'MY_API_TOKEN',
        scheme   => 'Bearer',
    );

    # Get auth headers for request
    my $headers = $auth->headers_for('my_api');
    # { Authorization => 'Bearer TOKEN_VALUE' }

=head1 DESCRIPTION

Manages authentication configuration and header generation for APIs. Supports
API key and OAuth2 authentication types.

Most bund.dev APIs require no authentication (type C<none>), but this module
is extensible for APIs that do.

=head2 set

    $auth->set($api_id,
        type        => 'api_key',      # or 'oauth2', 'none'
        env_var     => 'MY_API_TOKEN',
        header_name => 'Authorization',
        scheme      => 'Bearer',
    );

Configure authentication for an API. Returns the config HashRef.

Options:

=over

=item * C<type> - 'api_key', 'oauth2', or 'none' (default: 'api_key')

=item * C<env_var> - Environment variable holding the token (required for api_key)

=item * C<header_name> - HTTP header name (default: 'Authorization')

=item * C<scheme> - Auth scheme for Authorization header (default: 'Bearer')

=item * C<oauth_url> - OAuth2 token URL (required for oauth2)

=item * C<oauth_secret_env> - Environment variable for OAuth2 secret

=back

=head2 get

    my $config = $auth->get($api_id);

Get auth config for an API. Returns HashRef. If not configured, returns
C<{ type =\> 'none' }>.

=head2 headers_for

    my $headers = $auth->headers_for($api_id);

Generate HTTP headers for API authentication. Returns HashRef.

For C<api_key> type, reads token from environment variable and formats
according to scheme. For C<none> type, returns empty HashRef.

Throws exception if required environment variable is not set.

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
