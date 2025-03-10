# Generated by WebService::BitbucketServer::WADL - DO NOT EDIT!
package WebService::BitbucketServer::MirroringUpstream::V1;
# ABSTRACT: Bindings for a Bitbucket Server REST API


use warnings;
use strict;

our $VERSION = '0.605'; # VERSION

use Moo;
use namespace::clean;


has context => (
    is          => 'ro',
    isa         => sub { die 'Not a WebService::BitbucketServer' if !$_[0]->isa('WebService::BitbucketServer'); },
    required    => 1,
);


sub _croak { require Carp; Carp::croak(@_) }

sub _get_url {
    my $url  = shift;
    my $args = shift || {};
    $url =~ s/\{([^:}]+)(?::\.\*)?\}/_get_path_parameter($1, $args)/eg;
    return $url;
}

sub _get_path_parameter {
    my $name = shift;
    my $args = shift || {};
    return delete $args->{$name} if defined $args->{$name};
    $name =~ s/([A-Z])/'_'.lc($1)/eg;
    return delete $args->{$name} if defined $args->{$name};
    _croak("Missing required parameter $name");
}


sub set_preferred_mirror {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/account/settings/preferred-mirror', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'POST', url => $url, $data ? (data => $data) : ());
}


sub get_preferred_mirror {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/account/settings/preferred-mirror', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub remove_preferred_mirror {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/account/settings/preferred-mirror', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'DELETE', url => $url, $data ? (data => $data) : ());
}


sub get_analytics_settings {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/analyticsSettings', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub authenticate {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/authenticate', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'POST', url => $url, $data ? (data => $data) : ());
}


sub get_mirrors {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/mirrorServers', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub get_mirror {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/mirrorServers/{mirrorId}', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub remove_mirror {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/mirrorServers/{mirrorId}', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'DELETE', url => $url, $data ? (data => $data) : ());
}


sub render_webpanel {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/mirrorServers/{mirrorId}/webPanels/config', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub get_repositories {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/repos', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub get_repository {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/repos/{repoId}', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub get_repository_mirrors {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/repos/{repoId}/mirrors', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub get_requests {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/requests', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub create_request {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/requests', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'POST', url => $url, $data ? (data => $data) : ());
}


sub get_request {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/requests/{mirroringRequestId}', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub delete_request {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/requests/{mirroringRequestId}', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'DELETE', url => $url, $data ? (data => $data) : ());
}


sub accept_request {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/requests/{mirroringRequestId}/accept', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'POST', url => $url, $data ? (data => $data) : ());
}


sub reject_request {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('mirroring/1.0/requests/{mirroringRequestId}/reject', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'POST', url => $url, $data ? (data => $data) : ());
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebService::BitbucketServer::MirroringUpstream::V1 - Bindings for a Bitbucket Server REST API

=head1 VERSION

version 0.605

=head1 SYNOPSIS

    my $stash = WebService::BitbucketServer->new(
        base_url    => 'https://stash.example.com/',
        username    => 'bob',
        password    => 'secret',
    );
    my $api = $stash->mirroring_upstream;

=head1 DESCRIPTION

This is a Bitbucket Server REST API for L<MirroringUpstream::V1|https://developer.atlassian.com/static/rest/bitbucket-server/4.14.10/bitbucket-mirroring-upstream-rest.html>.

Original API documentation created by and copyright Atlassian.

=head1 ATTRIBUTES

=head2 context

Get the instance of L<WebService::BitbucketServer> passed to L</new>.

=head1 METHODS

=head2 new

    $api = WebService::BitbucketServer::MirroringUpstream::V1->new(context => $webservice_bitbucketserver_obj);

Create a new API.

Normally you would use C<<< $webservice_bitbucketserver_obj->mirroring_upstream >>> instead.

=head2 set_preferred_mirror

Sets the mirror specified by a mirror ID as the current user's preferred mirror

    POST mirroring/1.0/account/settings/preferred-mirror

Responses:

=over 4

=item * C<<< 204 >>> - data, type: application/json

an empty response indicating that the user setting has been updated

=item * C<<< 404 >>> - not-found, type: application/json

The mirror could not be found.

=back

=head2 get_preferred_mirror

Retrieves the current user's preferred mirror server

    GET mirroring/1.0/account/settings/preferred-mirror

Responses:

=over 4

=item * C<<< 200 >>> - data, type: application/json

the preferred mirror server

=item * C<<< 404 >>> - not-found, type: application/json

The user's preferred mirror server could not be found.

=back

=head2 remove_preferred_mirror

Removes the current user's preferred mirror

    DELETE mirroring/1.0/account/settings/preferred-mirror

Responses:

=over 4

=item * C<<< 204 >>> - data, type: application/json

an empty response indicating that the user setting has been updated

=back

=head2 get_analytics_settings

    GET mirroring/1.0/analyticsSettings

Responses:

=over 4

=item * C<<< 200 >>> - data, type: application/json

The analytics settings from upstream

=back

=head2 authenticate

Authenticates on behalf of a user. Used by mirrors to check the credentials supplied to them by users.
If successful a user and their effective permissions are
returned. Currently only username/password and SSH credentials are supported.

    POST mirroring/1.0/authenticate

Responses:

=over 4

=item * C<<< 200 >>> - user, type: application/json

The user for the supplied credentials and their effective permissions.

=item * C<<< 400 >>> - errors, type: application/json

If the supplied credentials are incomplete or not understood.

=item * C<<< 401 >>> - errors, type: application/json

The currently authenticated user is not permitted
to authenticate on behalf of users or authentication with the
supplied user credentials failed for some reason

=back

=head2 get_mirrors

Returns a list of mirrors

    GET mirroring/1.0/mirrorServers

Responses:

=over 4

=item * C<<< 200 >>> - page, type: unknown

a page of mirrors

=back

=head2 get_mirror

Returns the mirror specified by a mirror ID

    GET mirroring/1.0/mirrorServers/{mirrorId}

Parameters:

=over 4

=item * C<<< mirrorId >>> - string, default: none

the ID of the mirror to remove

=back

Responses:

=over 4

=item * C<<< 200 >>> - mirror, type: application/json

the mirror

=item * C<<< 404 >>> - not-found, type: application/json

The mirror could not be found.

=back

=head2 remove_mirror

Removes a mirror, disabling all access and notifications for the mirror server in question

    DELETE mirroring/1.0/mirrorServers/{mirrorId}

Parameters:

=over 4

=item * C<<< mirrorId >>> - string, default: none

the ID of the mirror to remove

=back

Responses:

=over 4

=item * C<<< 204 >>> - data, type: unknown

an empty response indicating that the mirror has been removed

=back

=head2 render_webpanel

This renders the HTML that is needed to get the remote connect web-panel on the mirror.

    GET mirroring/1.0/mirrorServers/{mirrorId}/webPanels/config

Parameters:

=over 4

=item * C<<< mirrorId >>> - string, default: none

=back

=head2 get_repositories

Returns a page of repositories enriched with a content hash

    GET mirroring/1.0/repos

Responses:

=over 4

=item * C<<< 200 >>> - page, type: application/json

A page of repositories with content hashes

=item * C<<< 409 >>> - errors, type: application/json

Mirroring is not available

=back

=head2 get_repository

Returns a repository enriched with a content hash

    GET mirroring/1.0/repos/{repoId}

Parameters:

=over 4

=item * C<<< repoId >>> - int, default: none

the ID of the requested repository

=back

Responses:

=over 4

=item * C<<< 200 >>> - repository, type: application/json

The repository with the specified repoId

=item * C<<< 409 >>> - errors, type: application/json

Repository not found

=back

=head2 get_repository_mirrors

Returns a page of mirrors for a repository.
This resource will return B<<< all mirrors >>> along with authorized links to the mirror's repository
REST resource. To determine if a repository is available on the mirror, the returned URL needs to be called.

    GET mirroring/1.0/repos/{repoId}/mirrors

Parameters:

=over 4

=item * C<<< repoId >>> - int, default: none

the ID of the requested repository

=back

Responses:

=over 4

=item * C<<< 200 >>> - repositoryDescriptor, type: application/json

The mirrored repository descriptor

=item * C<<< 409 >>> - errors, type: application/json

Mirroring is not available

=back

=head2 get_requests

Retrieves a mirroring request

    GET mirroring/1.0/requests

Parameters:

=over 4

=item * C<<< state >>> - string, default: none

(optional) the request state to filter on

=back

Responses:

=over 4

=item * C<<< 200 >>> - page, type: application/json

A page of mirroring requests

=back

=head2 create_request

Creates a new mirroring request

    POST mirroring/1.0/requests

Responses:

=over 4

=item * C<<< 200 >>> - data, type: application/json

The created mirroring request

=item * C<<< 409 >>> - errors, type: application/json

The request was invalid or missing

=back

=head2 get_request

Retrieves a mirroring request

    GET mirroring/1.0/requests/{mirroringRequestId}

Parameters:

=over 4

=item * C<<< mirroringRequestId >>> - int, default: none

the ID of the mirroring request to delete

=back

Responses:

=over 4

=item * C<<< 200 >>> - data, type: application/json

The mirroring request

=item * C<<< 409 >>> - errors, type: application/json

The request could not be found

=back

=head2 delete_request

Deletes a mirroring request

    DELETE mirroring/1.0/requests/{mirroringRequestId}

Parameters:

=over 4

=item * C<<< mirroringRequestId >>> - int, default: none

the ID of the mirroring request to delete

=back

Responses:

=over 4

=item * C<<< 204 >>> - data, type: application/json

The request was deleted

=item * C<<< 409 >>> - errors, type: application/json

The request could not be found

=back

=head2 accept_request

Accepts a mirroring request

    POST mirroring/1.0/requests/{mirroringRequestId}/accept

Parameters:

=over 4

=item * C<<< mirroringRequestId >>> - int, default: none

the ID of the request to accept

=back

Responses:

=over 4

=item * C<<< 200 >>> - data, type: application/json

The accepted mirror server

=item * C<<< 409 >>> - errors, type: application/json

The request could not be found

=back

=head2 reject_request

Rejects a mirroring request

    POST mirroring/1.0/requests/{mirroringRequestId}/reject

Parameters:

=over 4

=item * C<<< mirroringRequestId >>> - int, default: none

the ID of the request to reject

=back

Responses:

=over 4

=item * C<<< 200 >>> - data, type: application/json

The rejected mirroring request

=item * C<<< 409 >>> - errors, type: application/json

The request could not be found

=back

=head1 SEE ALSO

=over 4

=item * L<WebService::BitbucketServer>

=item * L<https://developer.atlassian.com/bitbucket/server/docs/latest/>

=back

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/chazmcgarvey/WebService-BitbucketServer/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Charles McGarvey <chazmcgarvey@brokenzipper.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Charles McGarvey.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
