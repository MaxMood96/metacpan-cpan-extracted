package ApiKeyDemo::Controller::Web::Keys;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

# Minting, listing and revoking - all through the context helpers the plugin
# installs, none of them touching the api_keys table directly.

sub index {
    my ($c) = @_;
    my $me = $c->current_user;

    return $c->render('keys', {
        title => 'Your keys',
        csrf   => $c->csrf_field,
        notice => $c->flash('notice'),
        me    => $me,
        # prefix, label, scopes, last_used - never the digest, and never the
        # key. Nothing has the key after the response that minted it.
        keys  => $c->api_keys($c->auth_id),
    });
}

sub issue {
    my ($c) = @_;

    my @scopes = grep { length } split /[\s,]+/, ($c->param('scopes') // '');

    # The plaintext exists here and nowhere else. It is rendered once, on
    # this response; putting it in the session to show on the next page would
    # be storing it.
    my ($key, $row) = $c->api_key_issue(
        owner  => $c->auth_id,
        label  => ($c->param('label') // 'unnamed'),
        kind   => ($c->param('kind') eq 'test' ? 'test' : 'live'),
        scopes => \@scopes,
        # Per-key, applied by the guard after the lookup and answering the
        # same 429 and X-RateLimit-* headers `rate_limit` does. Without
        # Hyperman's shared arena under the application it fails open.
        ($c->param('rate') ? (rate_per_min => $c->param('rate')) : ()),
    );

    return $c->render('issued', {
        title => 'One key, once',
        key   => $key,
        row   => $row,
    });
}

sub revoke {
    my ($c) = @_;

    # Revoking is a timestamp, not a delete: the row stays in the list and in
    # the audit of what was revoked when.
    my $row = $c->api_key_revoke($c->param('id'));

    $c->flash(notice => $row ? "Revoked key $row->{id}."
                              : 'No key with that id.');
    return $c->redirect($c->url_for('keys'));
}

# ---------------------------------------------------------------------------
# The owner's standing, as switches
# ---------------------------------------------------------------------------
#
# These are what `owner_model` reads. Flip one and a key that was working a
# second ago answers differently, without the key's own row changing at all.
# owner_ttl in lib/ApiKeyDemo.pm is what decides how long "a second ago" is.

sub demote  { _set($_[0], role => 'member') }
sub promote { _set($_[0], role => 'admin') }
sub suspend { _set($_[0], suspended => time) }
sub restore { _set($_[0], suspended => undef) }

sub _set {
    my ($c, $field, $value) = @_;

    $c->model('User')->update({ id => $c->auth_id, $field => $value });

    # The plugin caches the owner for owner_ttl seconds per worker, so
    # without this the switch appears to do nothing for up to that long. A
    # real application either lives with the lag or calls this after any
    # change to a role or to standing.
    Punk::Plugin::APIKey->forget_owners($c->app->caller_class);

    $c->flash(notice => "$field is now " . (defined $value ? $value : 'null')
                        . ' - try your key again.');
    return $c->redirect($c->url_for('keys'));
}

1;

__END__

