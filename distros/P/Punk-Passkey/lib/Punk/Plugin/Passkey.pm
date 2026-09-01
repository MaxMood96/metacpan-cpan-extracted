package Punk::Plugin::Passkey;

use 5.010;
use strict;
use warnings;
use Punk::Passkey ();   # one dist, one bootstrap: the plugin lives in its bundle

our $VERSION = '0.02';

1;

__END__

=head1 NAME

Punk::Plugin::Passkey - passkey sign-in for Punk applications

=head1 SYNOPSIS

    package MyApp;
    use Punk;

    session secret => secret('session_key');
    host 'https://example.com';
    auth model => 'User';

    plugin 'Passkey';

    # or, with everything named
    plugin 'Passkey' => {
        register_path     => '/account/passkeys',
        login_path        => '/login/passkey',
        model             => 'Passkey',
        user_verification => 'preferred',
        has_other_factor  => sub {
            my ($c, $user_id) = @_;
            $c->model('User')->get(id => $user_id)->{totp_enabled};
        },
        on_clone_signal   => sub {
            my ($cred, $stored, $asserted) = @_;
            warn "passkey $cred->{credential_id} may be cloned";
        },
    };

=head1 DESCRIPTION

One line adds passkeys to an application that already has a session, a
declared C<host> and somewhere to store credentials. The protocol
itself is L<Punk::Passkey>, which this mounts routes over; everything
about what is verified and why lives there.

=head2 What it needs, and what it refuses to start without

A C<session>, because a ceremony issues a challenge in one request and
checks it in the next, and the challenge cannot be kept anywhere the
client can reach. And C<host>, because the relying-party id and the
origin check are configuration - taking them from the request would
let a caller choose which site's credentials it is presenting, which
is the check the entire scheme rests on.

Both are checked at C<to_app>, and both croak naming what to add.
Neither degrades into something partly working; they degrade into
something that looks like it works.

=head1 THE ROUTES

    GET    {register_path}          the management page
    POST   {register_path}/options  creation options, as JSON
    POST   {register_path}          register a credential
    DELETE {register_path}/:id      remove one
    POST   {login_path}/options     request options, as JSON
    POST   {login_path}             sign in
    GET    {asset_path}             the browser helper, as JavaScript

The C<register_path> routes answer C<401> when nobody is signed in.
Put them behind your own auth guard as well - C<under> or the
C<auth_guard> keyword - so an unauthenticated request is refused by
the same machinery that refuses every other account page, rather than
by this plugin's own opinion.

The two C<login_path> routes are unauthenticated by definition, and
carry a per-address rate limit (30 a minute) when the application has
L<Punk/rate_limit> available - on top of anything you configure, not
instead of it.

=head2 CSRF

The JSON endpoints are unsafe methods and ride the application's
C<csrf> keyword like any other. The browser helper sends the token in
the C<X-CSRF-Token> header, which is where the server-side check reads
it for a non-form body.

=head2 Removing a credential

The last means of entry cannot be removed. A user with one passkey and
nothing else configured who deletes it has locked themselves out, and
finding that out is a support ticket at best.

Whether another factor exists is knowledge this plugin does not have,
so it arrives as C<has_other_factor>, a coderef receiving the context
and the user id. Without one, "no other factor" is assumed - the safe
direction. A user with two passkeys can always remove one.

Deletion is scoped to the signed-in user as well as the credential id.
A credential id is an identifier, not a capability.

=head1 OPTIONS

=over 4

=item register_path, login_path, asset_path

Where the routes are mounted. Defaults C</account/passkeys>,
C</login/passkey> and C</punk-passkey.js>.

=item model

The L<Punk::Model> holding credentials, default C<Passkey>. The
schema is the Sqitch project described in L<Punk::Passkey>; pass
C<< sqitch => 1 >> to register it with L<Punk::Plugin::Sqitch>.

An application that declares C<< <AppClass>::Model::Passkey >>, or
registers a model under this name, gets that one. An application that
declares neither gets L<Punk::Model::Passkey>, which is registered for
it - so the plugin line and the deployed table are enough, with no model
class to transcribe from the DDL.

=item user_verification, resident_key

Passed through to both ceremonies; both default to C<preferred>.
C<required> is how a deployment discovers, at the moment its users try
to sign in, that an authenticator they already own cannot satisfy it.

=item user_id, user_name

Coderefs receiving the context, naming the signed-in user and what to
show on their authenticator. C<user_id> defaults to C<< $c->auth_id >>
when the auth battery is present.

=item credentials_for

A coderef receiving the context and a username, returning that user's
credential ids for the C<allowCredentials> flow. Without it, logins
are usernameless: the authenticator offers whatever resident
credential it holds.

An unknown username produces an empty list and the ceremony fails the
way a wrong one does - this endpoint does not report who has an
account.

=item has_other_factor

See L</Removing a credential>.

=item on_clone_signal

A coderef receiving the row, the stored sign count and the asserted
one, when a counter fails to increase. B<The login still succeeds> -
see L<Punk::Passkey/"The sign count is a signal, not a gate">.

=item render

The management page: a coderef receiving the context and the user's
credentials, or the name of a method on the context. Without it a
plain built-in page is served, so the plugin works before anybody has
written a template.

An application with a view engine writes

    render => sub { $_[0]->render('account/passkeys', { rows => $_[1] }) }

which needs no agreement between this distribution and yours about
where templates live or which engine renders them.

=back

=head1 THE BROWSER HELPER

C<GET {asset_path}> serves a small vanilla JavaScript file -
C<window.PunkPasskey> - with C<register>, C<login>, C<supported> and
C<conditional>. It has no dependencies, no build step and B<references
no external origin>, so an application with a Content-Security-Policy
does not have to widen it to let sign-in work.

    PunkPasskey.register('/account/passkeys');
    PunkPasskey.login('/login/passkey');

C<conditional> is the autofill flow: it feature-detects
C<isConditionalMediationAvailable> and does nothing where it is
unsupported, so a browser without it simply shows your button.

    <input name="username" autocomplete="username webauthn">
    <script>PunkPasskey.conditional('/login/passkey',
                                    function () { location = '/account' })</script>

=head1 RECOVERY

A passkey user still needs a way back in when the device is gone, and
it should not be "email a link", which is forgeable and moves the
whole account's security to a mailbox.

The recommended pairing is B<a second passkey> as the primary recovery
- another device, enrolled while the first still works - with
L<Punk::TOTP>'s recovery codes behind it. This plugin deliberately
does not mint a recovery scheme of its own: a second one to keep
correct is a second one to get wrong, and the codes already exist.

Nothing here weakens an account that never enrols. Every route is
additive beside password, TOTP and OAuth2 sign-in.

=head1 SEE ALSO

L<Punk::Passkey> for the protocol and what it verifies, L<Punk>,
L<Punk::TOTP>, L<Punk::OAuth2>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
