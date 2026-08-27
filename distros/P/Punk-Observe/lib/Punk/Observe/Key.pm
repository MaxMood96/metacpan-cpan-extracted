package Punk::Observe::Key;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Key - ingest keys

=head1 SYNOPSIS

    use Punk::Observe::Key;

    my $r = Punk::Observe::Key::check(
        [ prod => $token ], $env->{HTTP_AUTHORIZATION}, undef);
    return [401, [], []] unless $r->{ok};

=head1 DESCRIPTION

A box exposing the ingest prefix to the network wants that endpoint
authenticated, and the exporter side already has the channel: a bearer token
in C<Authorization>, which is what C<OTEL_EXPORTER_OTLP_HEADERS> gives every
OpenTelemetry SDK. No new mechanism and no client change.

=head2 A key is stored as a hash

The key file lives in F</etc>, gets backed up, and ends up in a
configuration-management repository. As a list of tokens it is a list of
credentials; as a list of hashes it is a list of nothing useful. The token
exists once, when it is issued.

The hash is not a password KDF, deliberately: an ingest key is high-entropy
machine-generated material, not a human-chosen password, so there is no
dictionary to stretch against. That would be the wrong primitive if keys
could be user-chosen, which is why they are generated and never accepted.

=head2 A key compared with C<eq> is a timing oracle

Every string comparison in every language returns as soon as two bytes
differ, so the time taken leaks the length of the matching prefix and a key
is recovered one byte at a time.

The comparison here is constant-time B<by construction>: one return, no
branch on the data, and no library comparison that could short-circuit. Every
key in the ring is examined even after a match, so the position of a key does
not leak either.

That is asserted structurally rather than by measurement. A timing test on a
loaded smoker measures the smoker.

=head2 An ingest key is not the session credential

Keys are scoped to ingest and cannot read the UI. A key that could do both
leaks a whole installation the first time it is baked into a container image,
which is where ingest keys go.

=head1 FUNCTIONS

=head2 bearer

    my $token = Punk::Observe::Key::bearer($header);

The token from an C<Authorization> header, or C<undef>. The scheme is matched
case-insensitively because RFC 7235 says it is; the token is not.

=head2 check

    my $r = Punk::Observe::Key::check(\@name_token_pairs, $header, $revoke);

Returns C<< { ok, code, required, name } >>. C<code> is 0 accepted, 1 no
token presented, 2 unknown, 3 revoked - a revoked key is told apart from an
unknown one, because they are different operational events.

With no keys configured the endpoint is open and C<required> is false. It
says so rather than silently accepting.

=head2 ct_eq

    my $bool = Punk::Observe::Key::ct_eq($a, $b);

The constant-time comparison, exposed so it can be driven directly.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Plugin::Observe>

=cut
