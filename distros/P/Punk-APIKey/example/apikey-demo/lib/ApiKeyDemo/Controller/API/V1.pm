package ApiKeyDemo::Controller::API::V1;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

# Behind api_key_guard. By the time any of these runs the credential is good
# and its scope has been checked, so none of them asks again.
#
# $c->api_key_auth is what the guard decided:
#
#     { owner => 7, key => 3, kind => 'live', scopes => [ 'read' ] }
#
# and `scopes` is the EFFECTIVE set - after the owner's current role has
# narrowed whatever the row claims. $c->stash->{auth} holds the same hash in
# an ordinary handler, but an `api` mount replaces that slot with its own
# per-scheme results, so this method is the one that works either way.

sub whoami {
    my ($c) = @_;
    my $auth = $c->api_key_auth;

    return $c->json({
        owner  => $auth->{owner},
        kind   => $auth->{kind},
        scopes => $auth->{scopes},
        # What the ROW says, for comparison: differs from `scopes` above
        # whenever the owner's rank no longer reaches one of them.
        granted => $c->api_key->{scopes},
        label   => $c->api_key->{label},
        prefix  => $c->api_key->{prefix},
    });
}

sub list {
    my ($c) = @_;
    my $owner = $c->api_key_auth->{owner};

    my $rows = $c->model('Note')->search({ owner_id => $owner },
                                         { order_by => [ id => 'desc' ] });

    return $c->json({ notes => $rows->{rows} });
}

sub create {
    my ($c) = @_;
    my $body = $c->req->json || {};

    return $c->json({ errors => [ { message => 'body is required' } ] }, 422)
        unless defined $body->{body} && length $body->{body};

    my $note = $c->model('Note')->create({
        owner_id => $c->api_key_auth->{owner},
        body     => $body->{body},
        created  => time,
    });

    return $c->json({ note => $note }, 201);
}

sub stats {
    my ($c) = @_;
    my $owner = $c->api_key_auth->{owner};

    return $c->json({
        notes => scalar @{ $c->model('Note')->search({ owner_id => $owner })
                                            ->{rows} },
        keys  => scalar @{ $c->api_keys($owner) },
    });
}

1;

__END__
