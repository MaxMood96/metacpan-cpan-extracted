#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Scalar::Util qw(dualvar);

use File::SOPS::Format::YAML;
use File::SOPS::Format::JSON;

# ----------------------------------------------------------------------------
# k140: a plaintext emit refused to write a non-finite float whose
# string half contradicted its number, and the leaf was silently retyped to
# str on the next parse -- a decrypt_file -> encrypt_file round trip changing
# the type without warning. The MAC-covered paths refused the same shape all
# along: assert_representable in _compute_mac's leaf sweep, and the
# mac_covered croak in canonical_float_tree for the JSON case. The plaintext
# path used to fall through with $node returned as-is, the emitter wrote the
# string half verbatim, and the document and the digest no longer agreed on
# what the leaf was.
#
# The fix is one line: canonical_float_tree now consults
# assert_representable's `encrypted => 0` branch when the leaf carries a
# public PV. That predicate (gates on !_carries_go_non_finite_token) was
# already the one the encrypt side used, so the rule is in one place and the
# plaintext emit does not have to repeat it. Bare NV leaves are not in scope
# here: _non_finite_token_leaf manufactures a token for them in YAML and
# croaks in JSON, which is the existing k113 / k134 behaviour, and
# without the `_has_public_pv` filter on the new call assert_representable
# would refuse those bare infinities the encrypt side does not.
#
# Reachable only by a caller who constructs such a dualvar by hand -- no
# parse and no decryption produces one -- which is why this is medium and
# not high.
#
# No binary. This file is the Perl-level guarantee that the gate fires for
# every caller of the walk (decrypt_file, edit, _serialize_plaintext, and a
# direct emit() on a tree the caller built). The byte-level question is what
# t/52 documents against the binary, and it is unaffected by this change.
# ----------------------------------------------------------------------------

my $INF = 9**9**9;
my $NAN = $INF - $INF;

sub error_from {
    my ($code) = @_;
    local $@;
    eval { $code->(); 1 };
    return $@;
}

###############################################################################
# 1. THE FIX. A non-finite float whose public PV contradicts its number is
#    refused on the plaintext emit path -- in both formats, in both formats
#    where the leaf is a hash value, and in arrays. The croak is the same
#    message the encrypt side already used (k59), so the rule and the
#    message live in one place: assert_representable.
###############################################################################

subtest 'plaintext emit refuses a non-finite float whose PV contradicts its number' => sub {
    # The same set the encrypt side refused all along, with the same message.
    for my $case (
        [ 'banana'        => $INF,  'banana'    ],
        [ '.INf'          => $INF,  '.INf'      ],
        [ '.infinity'     => $INF,  '.infinity' ],
        [ '-.inf on +Inf' => $INF,  '-.inf'     ],
        [ '.inf on -Inf'  => -$INF, '.inf'      ],
        [ '.inf on NaN'   => $NAN,  '.inf'      ],
        [ 'empty PV'      => $INF,  ''          ],
    ) {
        my ($name, $double, $pv) = @$case;
        my $leaf = dualvar($double, $pv);

        my $err = error_from(sub {
            File::SOPS::Format::YAML->emit({ v => $leaf });
        });
        ok($err, "[$name] YAML refuses it");
        like($err, qr/non-finite float/,
            "[$name] and dies with the k59 message");

        my $jerr = error_from(sub {
            File::SOPS::Format::JSON->emit({ v => $leaf });
        });
        ok($jerr, "[$name] JSON refuses it too");
    }
};

subtest 'the croak names the key path' => sub {
    # The leaf's location matters: a document with a thousand leaves and one
    # bad one is useless without a way to find it, and the existing MAC walk
    # already names the path (the colon-joined key sequence, '(document root)'
    # for the empty path, array indices included). _leaf_location is the one
    # helper, here -- a caller who has to learn two notations for the same
    # document is the reason k68 exists at all.
    for my $path (
        [ 'top-level hash'    => { v => dualvar($INF, 'banana') } ],
        [ 'nested hash'       => { db => { pass => dualvar($INF, 'banana') } } ],
        [ 'array element'     => { list => [ dualvar($INF, 'banana') ] } ],
        [ 'deeply nested'     => { a => { b => { c => { d => dualvar($INF, 'banana') } } } } ],
    ) {
        my ($name, $tree) = @$path;
        my $err = error_from(sub { File::SOPS::Format::YAML->emit($tree) });
        ok($err, "[$name] YAML refuses it");
        like($err, qr/\b(?:v|db:pass|list:0|a:b:c:d)\b/,
            "[$name] and the key path is in the message");
        unlike($err // '', qr/\bAGE-SECRET/,
            "[$name] with no key material in it");
    }
};

###############################################################################
# 2. NO REGRESSION: the leaf the plaintext path USED to repair correctly
#    still works. Three cases, each covered by a more focused test elsewhere,
#    pinned here so a future change to canonical_float_tree cannot quietly
#    move them.
###############################################################################

subtest 'a bare non-finite float: YAML manufactures a token (k134)' => sub {
    # Bare NV with no PV. _non_finite_token_leaf manufactures a dualvar for
    # it in YAML, asserting the carrier's answer carries the token PV AND
    # the bytes the digest covers -- exactly the k134 path. The karr
    # k140 fix is gated on _has_public_pv, so a bare NV does not hit the new
    # call to assert_representable.
    for my $case (
        [ '+Inf' => $INF,  '.inf'  ],
        [ '-Inf' => -$INF, '-.inf' ],
        [ 'NaN'  => $NAN,  '.nan'  ],
    ) {
        my ($name, $double, $token) = @$case;
        my $yaml = File::SOPS::Format::YAML->emit({ v => $double });
        like($yaml, qr/^v: \Q$token\E$/m,
            "[$name] YAML writes the carrier's token");
    }
};

subtest 'a non-finite dualvar carrying the right go-yaml token still passes' => sub {
    # ADR 0031's `banana` row, narrowed: the leaf is a `type:float` if and
    # only if its PV is one of the twelve tokens go-yaml resolves to the
    # same double. The k140 fix does not touch this case -- the new
    # assert_representable call passes for it because _carries_go_non_finite_
    # token is true.
    for my $case (
        [ '.inf'  => $INF,  '.inf'  ],
        [ '.Inf'  => $INF,  '.Inf'  ],
        [ '.INF'  => $INF,  '.INF'  ],
        [ '-.inf' => -$INF, '-.inf' ],
        [ '.nan'  => $NAN,  '.nan'  ],
    ) {
        my ($name, $double, $token) = @$case;
        my $yaml = File::SOPS::Format::YAML->emit({ v => dualvar($double, $token) });
        like($yaml, qr/^v: \Q$token\E$/m,
            "[$name] YAML writes the token");
    }
};

subtest 'a finite float still passes' => sub {
    # The assert_representable `encrypted => 0` branch only fires for non-
    # finite doubles. A finite one is never on the wrong side of the
    # _carries_go_non_finite_token predicate, and the k140 fix must
    # not slow it down or refuse it.
    for my $value (0.0, 1.5, -3.5, 0.1 + 0.2, 1e20) {
        for my $fmt (qw( yaml json )) {
            my $code = $fmt eq 'yaml'
                ? sub { File::SOPS::Format::YAML->emit({ v => $value }) }
                : sub { File::SOPS::Format::JSON->emit({ v => $value }) };
            my $err = error_from($code);
            is($err, '', "[$fmt] finite $value is not refused")
                or diag($err);
        }
    }
};

done_testing;