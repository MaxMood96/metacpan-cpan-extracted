#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More;
use MIME::Base64 qw(encode_base64);

use lib 'lib';
use Developer::Dashboard::Codec qw(encode_payload decode_payload);

# Round-trip baseline so the success sides of both branches stay exercised.
my $token = encode_payload('hello coverage');
ok( defined $token && length $token, 'encode_payload returns a token' );
is( decode_payload($token), 'hello coverage', 'round-trips back to the original text' );

# Failure branch: a token whose bytes carry the gzip magic header (\x1f\x8b) but
# a corrupt body defeats IO::Uncompress::Gunzip's Transparent passthrough, so the
# inflate fails and takes decode_payload's own internal failure side. (Arbitrary
# non-gzip bytes would be copied through transparently and would NOT fail here.)
# DD-627: this now returns undef instead of propagating the gunzip die, matching
# encode_payload's own undef-for-invalid-input contract.
my $corrupt = encode_base64( "\x1f\x8b\x08\x00corrupted-gzip-body-not-inflatable", '' );
my $result = eval { decode_payload($corrupt) };
is( $@, '', 'decode_payload does not propagate an exception on a corrupt gzip token' );
is( $result, undef, 'decode_payload returns undef on a corrupt gzip token' );

# Round-trip is unaffected by the failure-path change (AC-2).
my $token2 = encode_payload('another round trip');
is( decode_payload($token2), 'another round trip', 'valid-token round-trip is unchanged' );

done_testing;

__END__

=pod

=head1 NAME

t/59-codec-failure-coverage.t - failure-path coverage for the payload codec

=head1 PURPOSE

This test is the executable coverage contract for the failure side of
C<Developer::Dashboard::Codec::decode_payload>. It confirms that a token whose
base64 body is not valid gzip data makes the inflate step fail internally and
C<decode_payload> returns C<undef> rather than propagating an exception (DD-627).

=head1 WHY IT EXISTS

The coverage gate requires C<lib/> to reach 100% on branch and condition
metrics, not only statement and subroutine. The codec's decode path has an
internal C<eval { gunzip ... }> whose failure side is only reached with a
corrupt token; this test drives that path deterministically so the branch stays
covered and cannot silently regress. It also guards against DD-627's specific
regression: a caller (e.g. a malformed C<?token=> URL) must get a clean
C<undef> back, never an uncaught exception.

=head1 WHEN TO USE

Use this file when changing the codec's token format, its compression handling,
or the error behavior of encode/decode, and whenever revisiting branch coverage
for the payload transport.

=head1 HOW TO USE

Run C<prove -lv t/59-codec-failure-coverage.t> while iterating on the codec, and
keep it green under C<prove -lr t> and the coverage gate before release.

=head1 WHAT USES IT

Developers during TDD, the repository test suite, and the coverage gate use this
file to keep the codec's decode failure branch covered end to end.

=head1 EXAMPLES

Example 1:

  prove -lv t/59-codec-failure-coverage.t

Run the dedicated codec failure-path coverage check by itself.

Example 2:

  prove -lr t

Run it inside the full repository suite before release.

=cut
