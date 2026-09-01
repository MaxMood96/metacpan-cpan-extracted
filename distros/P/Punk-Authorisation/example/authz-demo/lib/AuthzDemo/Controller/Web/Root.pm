package
	AuthzDemo::Controller::Web::Root;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

# The actions the home page asks about for every document. `may` croaks on a
# name no rule defines, so this list cannot drift from the policy silently -
# which is why it croaks.
my @ACTIONS = qw(doc.read doc.edit doc.publish doc.delete doc.share);

sub home {
    my ($c) = @_;

    my @docs;
    for my $doc (@{ $c->model('Doc')->all->{rows} }) {
        # A list and not a hash keyed by action: the names have dots in them
        # and a template cannot subscript its way past that.
        my @actions;
        for my $action (@ACTIONS) {
            my $may = $c->auth_id ? ($c->may($action, $doc) ? 1 : 0) : 0;
            (my $verb = $action) =~ s/\Adoc\.//;
            push @actions, {
                name   => $action,
                verb   => $verb,
                may    => $may,
                status => $may ? '' : ($c->auth_id ? _refusal($c) : '-'),
            };
        }
        push @docs, {
            %$doc,
            owner   => $c->model('User')->get(id => $doc->{owner_id}),
            actions => \@actions,
            shared  => _shared_with($c, $doc),
        };
    }

    return $c->page('home', { docs => \@docs });
}

# Which status the refusal just recorded would carry.
#
# This reads the plugin's own stash slot, and it is the one thing in this
# demo an application should NOT copy: a controller calls `$c->deny` and lets
# it choose. The page wants to SHOW 403 against 404 in a table without
# sending five requests per row, so it peeks.
#
# The default when a rule refused with a bare false is `deny`'s: 404 for a
# check that carried a subject, and every check here carries one.
sub _refusal {
    my ($c) = @_;
    return $c->stash->{'punk.authz.why'} || 404;
}

# The grants standing against this document, for the page. `granted` answers
# one question at a time, which is the right shape for a rule and the wrong
# one for a list, so this asks the model directly.
sub _shared_with {
    my ($c, $doc) = @_;
    my $rows = $c->model('Punk::Model::Grant')->search(
        { action => 'doc.edit', object_id => $doc->{id} }, { limit => 20 }
    )->{rows};
    return [ map { $c->model('User')->get(id => $_->{subject_id}) } @$rows ];
}

sub signin {
    my ($c) = @_;
    my $id  = $c->param('user_id');
    my $who = $id && $c->model('User')->get(id => $id);
    if ($who) {
        $c->session->{user_id} = $who->{id};
        $c->flash(kind => 'ok',
                  notice => "signed in as $who->{email} ($who->{role})");
    }
    return $c->redirect('/');
}

sub logout {
    my ($c) = @_;
    delete $c->session->{user_id};
    $c->flash(kind => 'ok', notice => 'signed out - now nobody may anything');
    return $c->redirect('/');
}

1;

__END__
