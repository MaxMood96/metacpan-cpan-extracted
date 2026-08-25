package Punk::Plugin::TOTP;

use 5.010;
use strict;
use warnings;
use Punk::TOTP ();    # one dist, one bootstrap: the plugin lives in its bundle

our $VERSION = '0.05';

1;

__END__

=head1 NAME

Punk::Plugin::TOTP - a second factor for Punk applications

=head1 SYNOPSIS

    use Punk;

    session secret => secret('session_key');
    auth model => 'User';
    plugin 'TOTP' => { issuer => 'openapi-proxy.com' };

    # enrolment
    post '/account/2fa' => sub {
        my ($c) = @_;
        my $secret = $c->totp_secret;
        $c->session->{totp_enrolling} = $secret;
        return $c->render('account/2fa',
            { qr => $c->totp_qr($secret) });
    };

    # the challenge
    post '/login/totp' => sub {
        my ($c) = @_;
        my $user = ...;
        return $c->render('auth/totp', { error => 'Try again.' })
            unless $c->totp_verify($user, $c->param('code'));
        ...
    };

=head1 DESCRIPTION

Wires L<Punk::TOTP> into a Punk application: secret generation, the
enrolment QR, and verification with the counter write-back that makes
replay protection hold. The engine is usable without this plugin; the
plugin exists so every application does not re-derive the wiring that
is easy to get wrong.

=head1 CONFIG

    plugin 'TOTP' => {
        issuer    => 'openapi-proxy.com',   # required
        algorithm => 'sha1',                # sha1 | sha256 | sha512
        digits    => 6,
        period    => 30,
        skew      => 1,
        model     => 'User',
        attempts       => 5,      # failed codes before the factor locks
        attempt_window => 900,    # ... and how long the count stands
        render    => sub { ... }, # render the challenge form can also be a context method name
        fields    => {
            secret    => 'totp_secret',
            counter   => 'totp_last_counter',
            enabled   => 'totp_enabled',
            email     => 'email',
            failed    => 'totp_failed',
            failed_at => 'totp_failed_at',
        },
    };

C<fields> maps the plugin onto the application's own column names.
Unknown options croak at boot.

=head1 HELPERS

=head2 $c->totp_secret

A fresh secret, base32, sized for the configured algorithm.

=head2 $c->totp_uri($secret, %opt)

The C<otpauth://> URI, issuer from config, account from C<%opt> or
the signed-in user's email field.

=head2 $c->totp_qr($secret, %opt)

The URI as an SVG through L<QR::Code>, at ECC level H - an enrolment
QR is scanned once, from a screen, by every phone the user will ever
own, so it gets maximum margin and no logo unless C<%opt> asks.
C<%opt> otherwise passes through to C<< QR::Code->svg >>. An
application that renders the QR some other way builds the
C<otpauth://> URI with C<totp_uri> instead.

=head2 $c->totp_verify($user, $code)

Verifies against the user's stored secret and, on success, writes the
matched counter back through the configured model before returning
true - the write is the replay protection. An account with no secret
burns the same verification work and returns false, so response time
does not report who has 2FA enabled.

=head2 $c->totp_recovery_codes($user, %opt)

    my $codes = $c->totp_recovery_codes($user);          # ten
    my $codes = $c->totp_recovery_codes($user, count => 5);

A fresh set of single-use recovery codes, returned in plaintext
exactly once - grouped base32 in an alphabet with no confusable
digits. Issuing a new set revokes the old one entirely: partial
invalidation is how a drawer ends up holding codes that half-work.
Rows go through C<recovery_model> (default C<Token>) in the token
table's shape - C<user_id>, C<kind> C<totp_recovery>, a lowercase
SHA-256 hex C<digest>, C<expires> 0 for never - so they share a
production tokens table untouched.

This is deliberately not C<< $c->issue_token >>: that keyword deletes
older same-kind tokens first (ten codes would collapse to one) and
refuses a non-positive ttl (a code in a drawer must not expire). Both
behaviours are right for mailed links; recovery codes get their own
path rather than weakening them.

=head2 $c->totp_use_recovery($user, $code)

Spends a code: true once, false forever after. Case and grouping fold
before the digest, so what the paper shows is what works.

The lookup is scoped to C<$user>, and the row's C<user_id> is compared
as bytes, so a code only ever works for the account it was issued to
whether that account is keyed on a number, a username, an email
address or a UUID. Rows belonging to anyone else are never reached.

Within that scope the row is deleted BEFORE the code is judged - a
probe with the wrong kind burns the row it hit rather than leaving it
live for its real endpoint, the same discipline C<take_token>
documents.

=head1 THE AUTH SEAM

A half-authenticated session writes C<totp_pending> into the session
and B<not> the auth session key. That is the whole mechanism: Punk's
auth battery reads exactly one key, so a session that has passed a
password but not a code has no identity as far as every existing
C<auth_guard> is concerned. Nothing was taught about 2FA; nobody is
signed in yet; there is no new enforcement path to get wrong.

=head2 $c->totp_challenge($user, %opt)

Writes the pending marker (user id, an expiry C<pending_ttl> seconds
out, the destination from C<< to => >>) and returns the redirect to
the challenge route. Call it from the sign-in chokepoint - the place
every authentication path funnels through - INSTEAD of C<< $c->login >>
when the user has the factor enabled. Gating only the password form
leaves the mailed-link sign-ins (verify, reset, invite) as a bypass.

=head2 $c->totp_complete

Deletes the marker, signs the user in, records C<totp_at> in the
session, calls C<session_rotate> where Punk provides it (0.26+; with
a session store that closes a real fixation window), and returns the
stored destination. The challenge route calls this for you.

=head2 The challenge route

Mounted at C<challenge_path> (default C</login/totp>). GET renders -
a self-contained form by default, or whatever C<< render => >> names
(a coderef or context method, called with the context and an error
flag). POST verifies the submitted code as a TOTP code or a recovery
code, promotes on success, and B<clears the pending state entirely
after C<attempts> failures> (default 5): a limit that only delays is
a limit a patient script waits out; this one un-answers the first
factor. A per-address C<rate_limit> (30/minute) sits on top.

The count is kept B<on the user row>, in the C<failed> and C<failed_at>
columns, and so belongs to the account rather than to the session or to
the pending marker. Both of the other places would have been the
client's to choose: a Punk session without a store is a signed cookie,
which a client can keep a copy of and present again with its counter
intact, and a new marker is one password step away in any case. While
an account is over the limit the submitted code is not judged at all -
a limit that still answers whether the guess was right is not a limit.

C<attempt_window> (default 900 seconds) is how long a failure counts
for. The window is what makes this self-healing, and it is not
optional: a lock with no way out hands anyone who knows a password a
way to keep the account's owner locked out for good, which is a worse
bargain than the guessing it prevents.

If the columns are missing the count cannot be kept, and rather than
guess, every failed attempt then un-answers the first factor and the
plugin warns once. Deploy the schema (see L</STORAGE>).

An application with the C<csrf> keyword enabled must pass its own
C<render> that includes the token, or exempt the path; the default
form carries none.

=head2 totp_guard

    my $admin = under '/admin' => totp_guard();
    $admin->get('/x' => ...);

The step-up guard, installed as a keyword at registration (so it is
called with parens). It passes when this session recorded C<totp_at> -
that is, when THIS login satisfied the factor - and otherwise writes a
pending marker for the signed-in user and redirects to the challenge
(or to C<login_path> when nobody is signed in). It sits inside or
after C<auth_guard>, which establishes identity; C<totp_guard> asks a
different question.

Note the test-kit gap, deliberately: C<Punk::Test::login_as> seals the
auth key directly and sails past the factor - existing suites keep
passing, which is correct and worth knowing. C<totp_guard> is not
fooled, because C<totp_at> is absent; a green suite is only evidence
of enforcement where the step-up guard stands.

=head1 STORAGE

Five columns on the user row, named by C<fields>: the secret (text,
and it cannot be hashed - whoever reads it can mint codes), the last
accepted counter (the replay floor; one write per successful
verification), the enabled flag the application flips only after
a first successful verification - enrolment is not complete until one
code proves the phone has the secret - and the failure count with the
epoch of the failure that last moved it, which is what bounds guessing
at the challenge (see L</The challenge route>). Only a failed attempt
writes the count; a sign-in that never failed costs nothing.

=head2 Shipping them with Sqitch

    plugin 'TOTP' => { issuer => 'MyApp', sqitch => 1 };

With the Punk-Sqitch distribution installed, C<< sqitch => 1 >> registers
the columns as the Sqitch project C<punk_totp> - one change,
C<totp>, that requires C<punk_auth:users> from L<Punk::Auth>'s own
project (C<< auth sqitch => 1 >>) - with scripts for SQLite, PostgreSQL
and MySQL, and C<punk sqitch deploy> deploys it after Punk::Auth's and
before the application's. Opt-in, because C<fields> exists for rows
with other column names and the project adds the defaults. Asking for
it without Punk-Sqitch installed croaks at the plugin line. See
L<Punk::Plugin::Sqitch>.

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
