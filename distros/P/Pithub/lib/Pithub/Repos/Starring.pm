package Pithub::Repos::Starring;
our $AUTHORITY = 'cpan:PLU';
our $VERSION = '0.01043';

# ABSTRACT: Github v3 Repo Starring API

use Moo;
extends 'Pithub::Base';


sub has_starred {
    my ( $self, %args ) = @_;
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'GET',
        path   => sprintf(
            '/user/starred/%s/%s', delete $args{user}, delete $args{repo}
        ),
        %args,
    );
}


sub list {
    my ( $self, %args ) = @_;
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'GET',
        path   => sprintf(
            '/repos/%s/%s/stargazers', delete $args{user}, delete $args{repo}
        ),
        %args,
    );
}


sub list_repos {
    my ( $self, %args ) = @_;
    if ( my $user = delete $args{user} ) {
        return $self->request(
            method => 'GET',
            path   => sprintf( '/users/%s/starred', $user ),
            %args,
        );
    }
    return $self->request(
        method => 'GET',
        path   => '/user/starred',
        %args,
    );
}


sub star {
    my ( $self, %args ) = @_;
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'PUT',
        path   => sprintf(
            '/user/starred/%s/%s', delete $args{user}, delete $args{repo}
        ),
        %args,
    );
}


sub unstar {
    my ( $self, %args ) = @_;
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'DELETE',
        path   => sprintf(
            '/user/starred/%s/%s', delete $args{user}, delete $args{repo}
        ),
        %args,
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pithub::Repos::Starring - Github v3 Repo Starring API

=head1 VERSION

version 0.01043

=head1 METHODS

=head2 has_starred

=over

=item *

Check if you are starring a repository.

Requires for the user to be authenticated.

    GET /user/starred/:user/:repo

Examples:

    my $s = Pithub::Repos::Starring->new;
    my $result = $s->has_starred(
        repo => 'Pithub',
        user => 'plu',
    );

=back

=head2 list

=over

=item *

List all stargazers of a repository

    GET /repos/:user/:repo/stargazers

Examples:

    my $s = Pithub::Repos::Starring->new;
    my $result = $s->list(
        repo => 'Pithub',
        user => 'plu',
    );

=back

=head2 list_repos

=over

=item *

List repositories being starred by a user.

    GET /users/:user/starred

Examples:

    my $s = Pithub::Repos::Starring->new;
    my $result = $s->list_repos(
        user => 'plu',
    );

=item *

List repos being starred by the authenticated user

    GET /user/starred

Examples:

    my $s = Pithub::Repos::Starring->new;
    my $result = $s->list_repos;

=back

=head2 star

=over

=item *

Star a repository.

Requires for the user to be authenticated.

    PUT /user/starred/:user/:repo

Examples:

    my $s = Pithub::Repos::Starring->new;
    my $result = $s->star(
        repo => 'Pithub',
        user => 'plu',
    );

=back

=head2 unstar

=over

=item *

Unstar a repository.

Requires for the user to be authenticated.

    DELETE /user/starred/:user/:repo

Examples:

    my $s = Pithub::Repos::Starring->new;
    my $result = $s->unstar(
        repo => 'Pithub',
        user => 'plu',
    );

=back

=head1 AUTHOR

Johannes Plunien <plu@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Johannes Plunien.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
