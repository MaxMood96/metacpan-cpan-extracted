package Punk::Passkey;

use 5.010;
use strict;
use warnings;

our $VERSION;

BEGIN {
    $VERSION = '0.01';
    require XSLoader;
    XSLoader::load('Punk::Passkey', $VERSION);
}

# The reason the last decode or conversion refused. For a log line, and
# deliberately not for a client - a verifier that tells an
# unauthenticated caller which check it failed is helping tune the next
# attempt.
our $ERR = '';

1;

__END__

=head1 NAME

Punk::Passkey - WebAuthn passkeys for Punk applications

=head1 SYNOPSIS

    package MyApp;
    use Punk;

    session secret => secret('session_key');
    host 'https://example.com';          # the rpId comes from here

    # offer a credential
    post '/account/passkeys/options' => sub {
        my ($c) = @_;
        $c->json(Punk::Passkey::register_options($c, {
            user_id   => $c->auth_id,
            user_name => $c->current_user->{email},
        }));
    };

    # take one
    post '/account/passkeys' => sub {
        my ($c) = @_;
        my $cred = Punk::Passkey::register($c, $c->req->json)
            or return $c->json({ error => 'registration failed' }, 400);
        $c->model('Passkey')->create({
            user_id       => $c->auth_id,
            credential_id => $cred->{credential_id},
            public_key    => $cred->{public_key},
            sign_count    => $cred->{sign_count},
            created_at    => time,
        });
        $c->json({ ok => 1 });
    };

=head1 DESCRIPTION

Passkeys are the fourth authentication factor for the Punk stack,
beside passwords, TOTP and OAuth2. This distribution is where WebAuthn
lives, separately from Punk itself, because it brings libcrypto -
through L<Crypt::JWS> and its C ABI, the same route L<Punk::OAuth2>
takes.

B<This release carries both ceremonies and the parsing layer under
them.>
The C<passkey> keyword follows; until it exists the ceremonies are
called as functions from routes of your own, which is what the
SYNOPSIS shows.

=head1 REGISTRATION

=head2 register_options($c, \%args)

Returns the C<PublicKeyCredentialCreationOptions> hashref to hand to
C<navigator.credentials.create>, and leaves a fresh challenge in the
session.

C<user_id> is required - the credential is bound to an account and
only the application knows which. C<user_name> and
C<user_display_name> are what the authenticator shows the person
choosing a credential. C<rp_name> names the site; C<exclude> is an
arrayref of the base64url credential ids this user already has, so the
platform refuses a duplicate registration in its own interface instead
of letting it reach the unique constraint. C<user_verification> and
C<resident_key> default to C<preferred>.

They default to C<preferred> rather than C<required> deliberately.
C<required> is how a deployment discovers, at the moment its users try
to sign up, that some authenticator they already own cannot satisfy
it.

=head2 register($c, \%response, \%args)

Verifies the browser's response and returns the credential to store,
or C<undef>.

    { credential_id => ..., public_key => ..., sign_count => ...,
      alg => -7, aaguid => ..., transports => [...], fmt => 'none',
      uv => 0 }

C<public_key> is the COSE key B<exactly as the authenticator sent it>.
Store those bytes: they are re-imported and re-checked against the
algorithm allowlist on every login, rather than trusted because they
were acceptable once.

The failure is uniform. Every refusal returns C<undef> and logs its
reason at warn, because a verifier that tells an unauthenticated
caller B<which> check failed is describing what to change for the next
attempt. The reason is in your log, with the request id and path
already attached.

=head2 What is checked

C<clientDataJSON> parses and its type is C<webauthn.create>; the
challenge is the one this session was issued, compared in constant
time; the origin is this application's canonical origin, matched
exactly; the attestation object parses, its C<rpIdHash> is the SHA-256
of this application's rpId, and user presence and attested credential
data are both set; the credential id is present and within the spec's
1023-byte ceiling; and the COSE key is on the allowlist and converts.

=head2 The origin is configuration, never the request

The rpId is the host of C<< $c->origin >> - the L<Punk/host> keyword's
declared origin, or one of its C<allow> list. It is never the C<Host>
header, and an application with no C<host> declared is refused at the
first ceremony rather than defaulted.

This is the check the whole scheme rests on: an origin an attacker can
choose is not an origin check, and a credential minted for one site
must not be presentable at another. Punk already resists that class -
C<< $c->origin >> exists precisely so nothing has to reflect a request
header - so this uses it rather than reading the environment itself.

=head2 The challenge is single-use

One outstanding challenge per session, five minutes, and B<consumed on
the first attempt - success or failure alike>. A new C<register_options>
replaces the previous challenge rather than adding one.

Consuming it on failure is the part worth stating: a challenge that
survived a failed attempt could be answered again, which is exactly
what replaying somebody else's captured response needs. The lifecycle
is Punk's CSRF token's, reused rather than reinvented.

=head2 Attestation is not verified

The attestation statement is read out and B<not examined>. For login -
as opposed to enterprise device policy - verifying an attestation
chain buys almost nothing and costs an X.509 path validator, a trust
store, and the maintenance of both.

That is a stance, not an omission, so it has a seam: pass
C<verify_attestation> as a coderef and it receives the format and the
statement and refuses by returning false. Nothing in this distribution
implements one.

=head2 The credential table

A Sqitch project ships at
F<lib/Punk/Plugin/Passkey/sqitch>, for SQLite, PostgreSQL and MySQL.
One row per credential, because a passkey user is expected to have
several and an account that cannot register a second device is an
account lost with the first.

C<credential_id> is unique across the whole table rather than per
user. The specification requires refusing a credential already
registered to somebody else, and a constraint does that without a
check-then-insert race two requests can interleave through.

=head1 AUTHENTICATION

=head2 challenge($c, \%args)

Returns the C<PublicKeyCredentialRequestOptions> hashref for
C<navigator.credentials.get>, and leaves a fresh challenge in the
session.

C<allow> is an arrayref of the base64url credential ids this login may
use. Omit it for the usernameless flow, where the authenticator offers
whatever resident credential it holds for this site and the server
learns who it is from the credential id that comes back; pass it when
the user typed a username first, which is also the only way a
non-resident credential can be used at all. When there is nothing to
list the key is B<absent> rather than empty, because an empty array
means something different to some platforms than no array.

=head2 verify($c, \%assertion, \%args)

Verifies the assertion and returns the accepted login, or C<undef>.

    { user_id => ..., credential_id => ..., credential => {...},
      sign_count => ..., clone_signal => 0, uv => 1, user_handle => ... }

C<lookup> is required: a coderef receiving the base64url credential id
and returning the stored row (with at least C<public_key>,
C<sign_count> and C<user_id>) or C<undef>. The engine owns no storage,
because only the application knows what a user is and where its
credentials live. C<on_used> is called with the row and the new sign
count so the application can record it; C<on_clone_signal> is
described below.

The stored key is B<re-imported and re-checked against the algorithm
allowlist on every login>, rather than trusted because it was
acceptable at registration - so tightening the allowlist tightens
every credential already stored.

=head2 Every failure is the same failure

An unknown credential id, a bad signature, a foreign origin and a
stale challenge all return the same C<undef>. That is deliberate and
it matters more here than anywhere else in this distribution: a login
endpoint that distinguishes "no such credential" from "bad signature"
answers the question "does this site know this authenticator", and a
credential id identifies a person's device.

The reason is logged at warn, with the request id and path already
attached.

=head2 The sign count is a signal, not a gate

The specification offers the signature counter as clone detection: a
counter that does not increase suggests two authenticators share one
private key.

Treating that as a hard failure is the obvious reading and it is wrong
in practice. Cloud-synced passkeys - iCloud Keychain, Google Password
Manager - legitimately report zero for ever, and they are most of the
passkeys that exist. An application that refused them would lock out
the majority of its users on the day it shipped.

So a regression B<does not fail the login>. It is logged, the stored
count still moves forward, and the application is handed the event
through C<on_clone_signal>, which receives the row, the stored count
and the asserted one. C<clone_signal> in the returned hashref says the
same thing. An operator who wants to force re-enrolment has what they
need; the user with an iPhone still gets in.

=head2 Hand off to your own sign_in

C<verify> establishes that the assertion is genuine. It does not log
anybody in, set a session, or decide where to redirect - those belong
to whatever the rest of your application already does for passwords,
TOTP and OAuth2:

    my $ok = Punk::Passkey::verify($c, $c->req->json, { lookup => ... })
        or return $c->text('denied', 403);
    return $c->sign_in($ok->{user_id});

Routing every factor through one C<sign_in> is what keeps session
rotation and redirect policy from being decided four times.

=head1 THE PARSING LAYER

What is here reads attacker-supplied bytes, and was built and tested
first and on its own, because it is the only genuinely new attack
surface in the design. Everything above it is assembly on
L<Crypt::JWS>, the session and the C<host> keyword, all of which
already exist and are already tested.

=head1 THE CBOR SUBSET, AND WHAT IT REFUSES

WebAuthn encodes two documents in CBOR: the attestation object
returned when a credential is created, and the COSE public key inside
it. Both arrive from an unauthenticated caller. A general-purpose CBOR
decoder is a large amount of surface to expose to that, and most of it
is surface WebAuthn never uses - so this implements the subset the
protocol actually emits and refuses the rest.

The refusal is the design, not a list of features not yet reached.
Nothing legitimate is lost: no authenticator emits any of it.

    accepted                        refused
    ----------------------------    ------------------------------------
    definite-length maps            indefinite lengths, of any type
    definite-length arrays          tags, all of them
    definite-length byte strings    floats, all three widths
    definite-length text strings    simple values other than true,
    unsigned integers within IV       false and null
    negative integers within IV     integers that do not fit in an IV
    true, false, null               nesting deeper than 8
                                    a length that reads past the end
                                    a repeated map key
                                    a map key that is not an integer
                                      or a text string
                                    more than 1024 entries in one map
                                      or array
                                    trailing bytes after the document

Three of those are worth their reasoning:

=over 4

=item * B<A repeated map key is refused, not resolved.> Taking the
first and taking the last are both defensible, which is exactly the
problem: two implementations that choose differently disagree about
which algorithm a COSE key names, and a document that reads as one
thing to the verifier and another to whatever logged it is the shape
of a real attack. RFC 8949 calls duplicate keys invalid; this treats
them as invalid.

=item * B<Tags are refused, including the harmless ones.> A tag
changes what the bytes underneath mean, which is the last thing to
accept from a document nobody has authenticated yet.

=item * B<Trailing bytes are refused rather than ignored.> A document
with something appended is not a document this understood, and
treating the prefix as the whole is how one parser's view of a message
stops matching another's.

=back

Text strings are produced as bytes with the UTF-8 flag off. Everything
the protocol layer does with them is compare against a constant or
hash, and a flagged scalar entering either is a double-encode waiting
to happen; the one place a string is human-facing - a credential's
label - is decoded at that seam, by the code that knows it is text.

=head1 THE KEY AND SIGNATURE CONVERSIONS

An authenticator hands over its public key as a COSE_Key map and its
signatures in ASN.1 DER. L<Crypt::JWS> imports PEM and verifies ECDSA
in the raw fixed-width form. This distribution owns both joins.

The algorithm allowlist is B<ES256> (ECDSA on P-256) and B<RS256>
(RSA PKCS#1 v1.5, which is what Windows Hello produces). It is applied
where the key is converted, which means it is applied twice: once when
a credential is registered, and again on every login, because the
stored key is re-imported each time. Tightening it later tightens
every credential already stored rather than only the next one.

A coordinate that is not exactly 32 bytes is refused rather than
padded. A 31-byte C<x> is not a 32-byte C<x> with a leading zero
dropped, as far as this is concerned: it is a document that did not
follow the rule, and repairing it lets two different documents become
one key.

=head1 WHAT IS TESTED, AND AGAINST WHAT

Every byte this distribution is tested against was either published as
reference data or captured from a real authenticator. Nothing was
composed to make a test pass: a vector written from memory either
fails wrongly or passes vacuously, and neither is a test.

The CBOR decoder runs against the B<RFC 8949 Appendix A> vectors,
verbatim, in both directions - every vector it accepts must decode to
the published value, and every vector it refuses must be one the table
above excludes. The key and signature conversions run against
B<registration responses captured from real authenticators> - a
YubiKey, a Windows Hello platform authenticator, and a C<none>
attestation - whose key material was confirmed to be genuine by
loading it with openssl before it was ever handed to this code.
F<t/fixtures/README> names the source of every one.

=head1 SEE ALSO

L<Punk>, L<Crypt::JWS>, L<Punk::OAuth2>, L<Punk::TOTP>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
