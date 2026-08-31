package PasskeyDemo;

use strict;
use warnings;
use Punk;
use Punk::Plugin::Passkey ();

our $VERSION = '0.01';

# A passkey and nothing else.
#
# There is no password in this application, deliberately: it is the
# shortest way to show that a passkey is a whole authentication factor
# rather than a second one bolted to something else. You create an
# account with a passkey and you sign in with a passkey.
#
# It also makes one rule visible that a password would have hidden -
# the plugin refuses to delete your LAST passkey, because here that
# really is the last way in. Add a second one and the first becomes
# removable.

config 'config/punk.yml';

# WHERE THE BROWSER LOADS THIS FROM, and it has to be right.
#
# A passkey is bound to an origin, and the browser checks the origin it
# is on against the relying-party id the server asked for. Declare an
# origin that is not the one in the address bar and every registration
# fails - correctly, and confusingly.
#
# WebAuthn also needs a secure context: https, or http on localhost,
# which browsers exempt. So the default below matches `plackup app.psgi`
# out of the box. Serving on another port or host means changing this
# to match.
host $ENV{PASSKEY_DEMO_ORIGIN} || 'http://localhost:5000';

# Minted per boot, so restarting the server signs everybody out - which
# is what you want from a demo and never what you want in production. A
# real application reads a configured one:
#
#     session secret => secret('session_key');
session secret => _boot_secret();

# The auth battery, for its users table and nothing else.
#
# No password is ever set: punk_auth's `password_hash` is nullable, and
# the column comment says why - an account can exist with no password,
# for an invite or a federated sign-in. A passkey-only account is the
# same shape. What this buys the demo is $c->auth_id and $c->login,
# which is why the plugin below needs no `user_id` callback.
#
# sqitch => 1 registers punk_auth's schema project, so `punk sqitch
# deploy` creates the users table before the passkeys one that
# references it.
auth model => 'User', sqitch => 1;

# ---- the plugin -------------------------------------------------------------
#
# Everything below this comment is what adopting passkeys costs an
# application that already has accounts: a `sqitch => 1`, one callback
# the plugin cannot guess, and a page to render. There is no `user_id`
# because the auth battery above already answers that.

plugin 'Passkey' => {
    # sqitch => 1 registers the credential table as a schema project,
    # deployed by `punk sqitch deploy` after punk_auth's users table -
    # which its plan declares as a dependency, so the ordering is
    # sqitch's to enforce rather than something a README asks you to
    # remember.
    sqitch => 1,

    # There is no `user_id` here, and no `user_name` either: with the
    # `auth` keyword above, the plugin already knows who is signed in
    # ($c->auth_id) and what to show on the device. This is what
    # adopting passkeys costs an application that already has accounts.

    # what the authenticator shows the person choosing a credential
    user_name => sub {
        my ($c) = @_;
        return ($c->current_user || {})->{email} // 'you';
    },

    # THE RECOVERY QUESTION, and the plugin asks the application because
    # only the application can answer it. Here there is no password and
    # no TOTP, so the honest answer is no: the last passkey cannot be
    # removed. An application with another factor returns true and the
    # last one becomes removable.
    has_other_factor => sub { 0 },

    # the sign-count signal. It does NOT fail the login - see
    # Punk::Passkey - it tells you a credential may have been cloned.
    on_clone_signal => sub {
        my ($cred, $stored, $asserted) = @_;
        warn "passkey $cred->{credential_id}: sign count went "
           . "$stored -> $asserted\n";
    },

    # the management page, through this application's own layout rather
    # than the plugin's built-in one
    render => 'passkey_page',
};

# ---- routes -----------------------------------------------------------------

get  '/'        => 'Web::Root#index',   { name => 'home' };
post '/signup'  => 'Web::Root#signup',  { name => 'signup' };
post '/signout' => 'Web::Root#signout', { name => 'signout' };

# The chokepoint. The plugin's login route calls $c->sign_in with the
# verified user id and nothing else - it does not decide what a session
# is, where to go next, or whether to rotate. Every factor an
# application grows arrives here, so those decisions are made once.
helper sign_in => sub {
    my ($c, $user_id) = @_;
    # the auth battery's own: it rotates the session and seals the
    # identity where current_user and auth_id will look for it
    $c->login($user_id);
    return $c->json({ ok => 1, to => '/' });
};

# The plugin hands `render` the context and the user's credentials.
helper passkey_page => sub {
    my ($c, $rows) = @_;
    return $c->render('passkeys', {
        title => 'Your passkeys',
        user  => $c->current_user,
        keys  => $rows,
    });
};

sub _boot_secret {
    my $bytes;
    if (open my $fh, '<:raw', '/dev/urandom') {
        read $fh, $bytes, 32;
        close $fh;
    }
    return unpack 'H*', $bytes if defined $bytes && length $bytes == 32;
    # no /dev/urandom (Windows): good enough for a demo whose sessions
    # are meant to die with the process, and not good enough for
    # anything else
    return join '', map { sprintf '%08x', int rand 2**32 } 1 .. 8;
}

1;

__END__

