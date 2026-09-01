package
	AuthzDemo::Controller::Web::Doc;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

# Every action here is the same four lines, and that is the point:
#
#     my $doc = $c->model('Doc')->get(id => $c->param('id'));
#     $c->may('doc.something', $doc) or return $c->deny;
#
# The rule decides; the controller asks. Nothing here knows what an owner is,
# what a rank is, or which status a refusal carries.

sub _doc {
    my ($c) = @_;
    return $c->model('Doc')->get(id => $c->param('id'));
}

sub show {
    my ($c) = @_;
    my $doc = _doc($c);
    $c->may('doc.read', $doc) or return $c->deny;
    return $c->page('doc', { doc => $doc,
                             owner => $c->model('User')->get(id => $doc->{owner_id}) });
}

sub edit {
    my ($c) = @_;
    my $doc = _doc($c);
    $c->may('doc.edit', $doc) or return $c->deny;

    my $title = $c->param('title');
    $c->model('Doc')->update({ id => $doc->{id}, title => $title })
        if defined $title && length $title;
    $c->flash(kind => 'ok', notice => "edited: $title");
    return $c->redirect('/');
}

sub publish {
    my ($c) = @_;
    my $doc = _doc($c);
    $c->may('doc.publish', $doc) or return $c->deny;

    $c->model('Doc')->update({ id => $doc->{id}, public => 1 });
    $c->flash(kind => 'ok', notice => "published: $doc->{title}");
    return $c->redirect('/');
}

# `remove`, not `delete`: a sub called delete in a controller shadows the
# builtin for everything else in the package.
sub remove {
    my ($c) = @_;
    my $doc = _doc($c);
    $c->may('doc.delete', $doc) or return $c->deny;

    $c->model('Doc')->delete(id => $doc->{id});
    $c->flash(kind => 'ok', notice => "deleted: $doc->{title}");
    return $c->redirect('/');
}

sub share {
    my ($c) = @_;
    my $doc = _doc($c);
    $c->may('doc.share', $doc) or return $c->deny;

    my $to = $c->param('user_id');
    if ($to) {
        $c->grant('doc.edit', $doc->{id}, to => 0 + $to);
        my $who = $c->model('User')->get(id => $to);
        $c->flash(kind => 'ok',
                  notice => "$who->{email} may now edit $doc->{title}");
    }
    return $c->redirect('/');
}

sub unshare {
    my ($c) = @_;
    my $doc = _doc($c);
    $c->may('doc.share', $doc) or return $c->deny;

    my $from = $c->param('user_id');
    if ($from) {
        my $gone = $c->revoke_grant('doc.edit', $doc->{id}, from => 0 + $from);
        my $who  = $c->model('User')->get(id => $from);
        $c->flash(kind => 'ok',
                  notice => "revoked $gone grant(s) from $who->{email}");
    }
    return $c->redirect('/');
}

1;

__END__
