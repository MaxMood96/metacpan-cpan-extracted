package Pithub::Repos::Commits;
our $AUTHORITY = 'cpan:PLU';
our $VERSION = '0.01043';

# ABSTRACT: Github v3 Repo Commits API

use Moo;
use Carp qw( croak );
extends 'Pithub::Base';


sub compare {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: base' unless $args{base};
    croak 'Missing key in parameters: head' unless $args{head};
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'GET',
        path   => sprintf(
            '/repos/%s/%s/compare/%s...%s', delete $args{user},
            delete $args{repo}, delete $args{base}, delete $args{head}
        ),
        %args,
    );
}


sub create_comment {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: sha' unless $args{sha};
    croak 'Missing key in parameters: data (hashref)'
        unless ref $args{data} eq 'HASH';
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'POST',
        path   => sprintf(
            '/repos/%s/%s/commits/%s/comments', delete $args{user},
            delete $args{repo},                 delete $args{sha}
        ),
        %args,
    );
}


sub delete_comment {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: comment_id' unless $args{comment_id};
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'DELETE',
        path   => sprintf(
            '/repos/%s/%s/comments/%s', delete $args{user},
            delete $args{repo},         delete $args{comment_id}
        ),
        %args,
    );
}


sub get {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: sha' unless $args{sha};
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'GET',
        path   => sprintf(
            '/repos/%s/%s/commits/%s', delete $args{user},
            delete $args{repo},        delete $args{sha}
        ),
        %args,
    );
}


sub get_comment {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: comment_id' unless $args{comment_id};
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'GET',
        path   => sprintf(
            '/repos/%s/%s/comments/%s', delete $args{user},
            delete $args{repo},         delete $args{comment_id}
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
            '/repos/%s/%s/commits', delete $args{user}, delete $args{repo}
        ),
        %args,
    );
}


sub list_comments {
    my ( $self, %args ) = @_;
    $self->_validate_user_repo_args( \%args );
    if ( my $sha = delete $args{sha} ) {
        return $self->request(
            method => 'GET',
            path   => sprintf(
                '/repos/%s/%s/commits/%s/comments', delete $args{user},
                delete $args{repo},                 $sha
            ),
            %args,
        );
    }
    return $self->request(
        method => 'GET',
        path   => sprintf(
            '/repos/%s/%s/comments', delete $args{user}, delete $args{repo}
        ),
        %args,
    );
}


sub update_comment {
    my ( $self, %args ) = @_;
    croak 'Missing key in parameters: comment_id' unless $args{comment_id};
    croak 'Missing key in parameters: data (hashref)'
        unless ref $args{data} eq 'HASH';
    $self->_validate_user_repo_args( \%args );
    return $self->request(
        method => 'PATCH',
        path   => sprintf(
            '/repos/%s/%s/comments/%s', delete $args{user},
            delete $args{repo},         delete $args{comment_id}
        ),
        %args,
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pithub::Repos::Commits - Github v3 Repo Commits API

=head1 VERSION

version 0.01043

=head1 METHODS

=head2 compare

=over

=item *

Compare two commits

    GET /repos/:user/:repo/compare/:base...:head

Examples:

    my $c      = Pithub::Repos::Commits->new;
    my $result = $c->compare(
        user => 'plu',
        repo => 'Pithub',
        base => 'v0.01008',
        head => ' master ',
    );

=back

=head2 create_comment

=over

=item *

Create a commit comment

    POST /repos/:user/:repo/commits/:sha/comments

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->create_comment(
        user => 'plu',
        repo => 'Pithub',
        sha  => 'df21b2660fb6',
        data => { body => 'some comment' },
    );

=back

=head2 delete_comment

=over

=item *

Delete a commit comment

    DELETE /repos/:user/:repo/comments/:id

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->delete_comment(
        user       => 'plu',
        repo       => 'Pithub',
        comment_id => 1,
    );

=back

=head2 get

=over

=item *

Get a single commit

    GET /repos/:user/:repo/commits/:sha

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->get(
        user => 'plu',
        repo => 'Pithub',
        sha  => 'df21b2660fb6',
    );

=back

=head2 get_comment

=over

=item *

Get a single commit comment

    GET /repos/:user/:repo/comments/:id

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->get_comment(
        user       => 'plu',
        repo       => 'Pithub',
        comment_id => 1,
    );

=back

=head2 list

=over

=item *

List commits on a repository

    GET /repos/:user/:repo/commits

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->list(
        user => 'plu',
        repo => 'Pithub',
    );

=back

=head2 list_comments

=over

=item *

List commit comments for a repository

Commit Comments leverage these custom mime types. You can read more
about the use of mimes types in the API here. See also:
L<http://developer.github.com/v3/mimes/>.

    GET /repos/:user/:repo/comments

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->list_comments(
        user => 'plu',
        repo => 'Pithub',
    );

=item *

List comments for a single commit

    GET /repos/:user/:repo/commits/:sha/comments

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->list_comments(
        user => 'plu',
        repo => 'Pithub',
        sha  => 'df21b2660fb6',
    );

=back

=head2 update_comment

=over

=item *

Update a commit comment

    PATCH /repos/:user/:repo/comments/:id

Examples:

    my $c = Pithub::Repos::Commits->new;
    my $result = $c->update_comment(
        user       => 'plu',
        repo       => 'Pithub',
        comment_id => 1,
        data       => { body => 'updated comment' },
    );

=back

=head1 AUTHOR

Johannes Plunien <plu@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Johannes Plunien.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
