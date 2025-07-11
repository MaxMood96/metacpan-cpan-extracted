package Crypt::Sodium::XS::auth;
use strict;
use warnings;

use Crypt::Sodium::XS;
use Exporter 'import';

_define_constants();

my @constant_bases = qw(
  BYTES
  KEYBYTES
);

my @bases = qw(
  init
  keygen
  verify
);

my $default = [
  "auth",
  (map { "auth_$_" } @bases),
  (map { "auth_$_" } @constant_bases, "PRIMITIVE"),
];
my $hmacsha256 = [
  "auth_hmacsha256",
  (map { "auth_hmacsha256_$_" } @bases),
  (map { "auth_hmacsha256_$_" } @constant_bases),
];
my $hmacsha512 = [
  "auth_hmacsha512",
  (map { "auth_hmacsha512_$_" } @bases),
  (map { "auth_hmacsha512_$_" } @constant_bases),
];
my $hmacsha512256 = [
  "auth_hmacsha512256",
  (map { "auth_hmacsha512256_$_" } @bases),
  (map { "auth_hmacsha512256_$_" } @constant_bases),
];

our %EXPORT_TAGS = (
  all => [ @$default, @$hmacsha256, @$hmacsha512, @$hmacsha512256 ],
  default => $default,
  hmacsha256 => $hmacsha256,
  hmacsha512 => $hmacsha512,
  hmacsha512256 => $hmacsha512256,
);

our @EXPORT_OK = @{$EXPORT_TAGS{all}};

1;

__END__

=encoding utf8

=head1 NAME

Crypt::Sodium::XS::auth - Secret key message authentication

=head1 SYNOPSIS

  use Crypt::Sodium::XS::auth ":default";

  my $key = auth_keygen;
  my $msg = "authenticate this message";

  my $mac = auth($msg, $key);
  die "message tampered with!" unless auth_verify($mac, $msg, $key);

  my $multipart = auth_init($key);
  $multipart->update("authenticate");
  $multipart->update(" this", " message");
  $mac = $multipart->final;
  die "message tampered with!" unless auth_verify($mac, $msg, $key);

=head1 DESCRIPTION

L<Crypt::Sodium::XS::auth> Computes an authentication MAC for a message and a
secret key, and provides a way to verify that a given MAC is valid for a given
message and a key.

The function computing the MAC is deterministic: the same C<($message, $key)>
tuple will always produce the same output. However, even if the message is
public, knowing the key is required in order to be able to compute a valid MAC.
Therefore, the key should remain confidential. The MAC, however, can be public.

A typical use case is:

* Alice prepares a message, adds an authentication MAC, sends it to Bob

* Alice doesn't store the message

* Later on, Bob sends the message and the authentication MAC back to Alice

* Alice uses the authentication MAC to verify that she created this message

L<Crypt::Sodium::XS::auth> does not encrypt the message. It only computes and
verifies an authentication MAC.

=head1 FUNCTIONS

Nothing is exported by default. A C<:default> tag imports the functions and
constants as documented below. A separate import tag is provided for each of
the primitives listed in L</PRIMITIVES>. For example, C<:hmacsha256>
imports C<auth_hmacsha256_verify>. You should use at least one import tag.

=head2 auth

  my $mac = auth($message, $key);

=head2 auth_init

  my $multipart = auth_init($key);

Returns a multi-part auth object. This is useful when authenticating a stream
or large message in chunks, rather than in one message. See L</MULTI-PART
INTERFACE>.

=head2 auth_keygen

  my $key = auth_keygen();

=head2 auth_verify

  my $is_valid = auth_verify($mac, $message, $key);

=head1 MULTI-PART INTERFACE

NOTE: The multipart interface may use arbitrary-length keys. this is not
recommended as it can be easily misused (e.g., accidentally using an empty
key).

A multipart auth object is created by calling the L</auth_init> function. Data
to be authenticated is added by calling the L</update> method of that object as
many times as desired. An output mac is generated by calling its L</final>
method. Do not use the object after calling L</final>.

The multipart auth object is an opaque object which provides the following
methods:

=head2 clone

  my $multipart_copy = $multipart->clone;

Returns a cloned copy of the multipart auth object, duplicating its internal
state.

=head2 final

  my $mac = $multipart->final;

Once C<final> has been called, the auth object must not be used further.

=head2 update

  $multipart->update($message);
  $multipart->update(@messages);

Adds all given arguments (stringified) to authenticated data.

=head1 CONSTANTS

=head2 auth_PRIMITIVE

  my $default_primitive = auth_PRIMITIVE();

=head2 auth_BYTES

  my $mac_length = auth_BYTES();

=head2 auth_KEYBYTES

  my $key_length = auth_KEYBTES();

=head1 PRIMITIVES

All constants (except _PRIMITIVE) and functions have
C<auth_E<lt>primitiveE<gt>>-prefixed counterparts (e.g.,
auth_hmacsha256_verify, auth_hmacsha512256_BYTES).

=over 4

=item * hmachsa256

=item * hmacsha512

=item * hmacsha512256

=back

=head1 SEE ALSO

=over 4

=item L<Crypt::Sodium::XS>

=item L<Crypt::Sodium::XS::OO::auth>

=item L<https://doc.libsodium.org/secret-key_cryptography/secret-key_authentication>

=item L<https://doc.libsodium.org/advanced/hmac-sha2>

=back

=head1 FEEDBACK

For reporting bugs, giving feedback, submitting patches, etc. please use the
following:

=over 4

=item *

RT queue at L<https://rt.cpan.org/Dist/Display.html?Name=Crypt-Sodium-XS>

=item *

IRC channel C<#sodium> on C<irc.perl.org>.

=item *

Email the author directly.

=back

=head1 AUTHOR

Brad Barden E<lt>perlmodules@5c30.orgE<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2022 Brad Barden. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
