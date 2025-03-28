# Generated by WebService::BitbucketServer::WADL - DO NOT EDIT!
package WebService::BitbucketServer::Audit::V1;
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


sub get_events_for_project {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('audit/1.0/projects/{projectKey}/events', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


sub get_events_for_repository {
    my $self = shift;
    my $args = {@_ == 1 ? %{$_[0]} : @_};
    my $url  = _get_url('audit/1.0/projects/{projectKey}/repos/{repositorySlug}/events', $args);
    my $data = (exists $args->{data} && $args->{data}) || (%$args && $args);
    $self->context->call(method => 'GET', url => $url, $data ? (data => $data) : ());
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WebService::BitbucketServer::Audit::V1 - Bindings for a Bitbucket Server REST API

=head1 VERSION

version 0.605

=head1 SYNOPSIS

    my $stash = WebService::BitbucketServer->new(
        base_url    => 'https://stash.example.com/',
        username    => 'bob',
        password    => 'secret',
    );
    my $api = $stash->audit;

=head1 DESCRIPTION

This is a Bitbucket Server REST API for L<Audit::V1|https://developer.atlassian.com/static/rest/bitbucket-server/5.10.0/bitbucket-audit-rest.html>.

Original API documentation created by and copyright Atlassian.

=head1 ATTRIBUTES

=head2 context

Get the instance of L<WebService::BitbucketServer> passed to L</new>.

=head1 METHODS

=head2 new

    $api = WebService::BitbucketServer::Audit::V1->new(context => $webservice_bitbucketserver_obj);

Create a new API.

Normally you would use C<<< $webservice_bitbucketserver_obj->audit >>> instead.

=head2 get_events_for_project

Retrieve the audit events for this project. The list of events will match those shown in the UI, for
a complete list of events please check the audit log file.

The authenticated user must have B<<< PROJECT_ADMIN >>> permission for the specified project to call this
resource.

    GET audit/1.0/projects/{projectKey}/events

Responses:

=over 4

=item * C<<< 200 >>> - page, type: application/json

The audit events for this project

=item * C<<< 401 >>> - errors, type: application/json

The currently authenticated user has insufficient permissions to administer the
project.

=item * C<<< 404 >>> - errors, type: application/json

The specified project does not exist.

=back

=head2 get_events_for_repository

Retrieve the subset of audit events stored for this repository. The list of events will match those shown in the UI, for
a complete list of events please check the audit log file.

The authenticated user must have B<<< REPO_ADMIN >>> permission for the specified repository to call this
resource.

    GET audit/1.0/projects/{projectKey}/repos/{repositorySlug}/events

Responses:

=over 4

=item * C<<< 200 >>> - page, type: application/json

The audit events for this repository

=item * C<<< 401 >>> - errors, type: application/json

The currently authenticated user has insufficient permissions to administer the
repository.

=item * C<<< 404 >>> - errors, type: application/json

The specified repository does not exist.

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
