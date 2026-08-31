package Punk::TOTP;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.06';

require XSLoader;
XSLoader::load('Punk::TOTP', $VERSION);

1;

__END__

=head1 NAME

Punk::TOTP - HOTP and TOTP one-time passwords

=head1 VERSION

Version 0.05

=head1 SYNOPSIS

    use Punk::TOTP;

    # enrolment
    my $secret = Punk::TOTP->secret;
    my $uri    = Punk::TOTP->uri($secret,
        issuer  => 'openapi-proxy.com',
        account => 'alice@example.com');
    # show $uri as a QR (QR::Code renders it) and store $secret

    # the challenge
    my ($ok, $counter) = Punk::TOTP->verify($secret, $submitted,
        last_counter => $stored_counter);
    if ($ok) {
        store_counter($counter);    # replay protection
    }

=head1 DESCRIPTION

RFC 4226 HOTP and RFC 6238 TOTP, with secret generation, the
C<otpauth://> provisioning URI, and a verifier that is replay-safe by
construction. No external crypto library: HMAC comes from
L<File::Raw::Hash> at runtime, so installing this dist needs nothing
beyond a C compiler.

=head1 CLASS METHODS

=head2 secret

    my $b32 = Punk::TOTP->secret;
    my $b32 = Punk::TOTP->secret(algorithm => 'sha256');
    my $b32 = Punk::TOTP->secret(bytes => 32);

A fresh shared secret, base32-encoded, sized for the algorithm (20
bytes for sha1, 32 for sha256, 64 for sha512) unless C<bytes> says
otherwise. Croaks rather than degrade when the entropy source fails.

=head2 uri

    my $uri = Punk::TOTP->uri($secret,
        issuer => ..., account => ..., %options);

The C<otpauth://totp/> provisioning URI. The issuer appears both in
the label prefix and as a query parameter because different apps read
different ones; issuer and account are percent-encoded; the label's
separating colon never is. Non-default C<algorithm>, C<digits> and
C<period> are included, defaults omitted to keep the QR payload
small.

=head2 code

    my $digits = Punk::TOTP->code($secret, %options);

The current code, or the code at C<< time => $t >>. Options:
C<algorithm>, C<digits> (6 to 8, default 6), C<period> (default 30),
C<time>.

=head2 hotp

    my $digits = Punk::TOTP->hotp($secret, $counter, %options);

The counter-based flavour. Options: C<algorithm>, C<digits>.

=head2 verify

    my $ok            = Punk::TOTP->verify($secret, $code, %options);
    my ($ok, $counter) = Punk::TOTP->verify($secret, $code, %options);

Checks the code against the window C<< now/period - skew .. + skew >>
(default C<skew> 1, so a code survives about ninety seconds of clock
drift). Three codes being valid at any moment is what makes replay
the real threat, so the verifier owns it: pass C<last_counter> and
any code whose counter does not exceed it is refused even when it
would otherwise match; in list context the matched counter comes
back for storing. Store it on every acceptance and replay protection
holds by construction.

The window is checked in full with constant-time comparisons - no
early exit - so timing does not report which step matched. A code of
the wrong length or with a non-digit is refused before any HMAC runs.

Options: C<algorithm>, C<digits>, C<period>, C<time>, C<skew>,
C<last_counter>.

=head2 b32_encode, b32_decode

    my $text  = Punk::TOTP->b32_encode($bytes);
    my $bytes = Punk::TOTP->b32_decode($text);

RFC 4648 base32. The decoder folds case and skips the spaces and
hyphens apps display secrets with, and refuses everything else - a
decoder that absorbs a typo produces a different secret that
verifies nothing and reports nothing. C<b32_decode> croaks on
invalid input; so does every method handed an undecodable secret.

=head1 STORAGE

The shared secret cannot be hashed: verification needs it, so
whatever the database holds is sufficient to mint codes. Anyone who
can read the secrets can be every user's second factor. Store it
knowing that, and store C<last_counter> beside it - the counter
write on each successful login is the replay protection.

=head1 SEE ALSO

L<File::Raw::Hash> (the HMAC underneath), L<QR::Code> (renders the
provisioning URI), L<Crypt::JWS> (keys, signatures and JWS - the
things this dist deliberately is not).

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
