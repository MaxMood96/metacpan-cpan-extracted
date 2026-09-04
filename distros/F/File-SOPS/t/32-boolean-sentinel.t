#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use YAML::XS ();
use JSON::MaybeXS qw(JSON);
use Scalar::Util qw(dualvar);

use File::SOPS;
use File::SOPS::Encrypted;
use Crypt::Age;

# ----------------------------------------------------------------------------
# k90 / docs/adr/0016: PERL'S OWN BOOLEAN SV.
#
# Perl has no boolean TYPE, but since 5.36 it has a boolean SV. `!!1`, `!!0`,
# `$x > 3`, `'a' eq 'a'`, `defined $x` and `builtin::true` all produce it, and
# the mark (SvIsBOOL) survives assignment and storage in a hash. It publishes
# the public SVf_IOK, so _sv_kind called it an int and value_to_bytes digested
# `1` / `0` -- while BOTH emitters write such an SV as a bare `true`/`false`.
#
# Measured against sops 3.13.3, ten sentinel leaves x two slots x both
# handlers = 40 documents, BEFORE the fix:
#
#   a true sentinel,  encrypted    ENC[...,type:int] plaintext 1  exit 0, reads back 1
#   a true sentinel,  unencrypted  document `true`, digest `1`    exit 51
#   a false sentinel, encrypted    document `''`,   digest `0`    exit 51
#   a false sentinel, unencrypted  --                             croak (ADR 0012)
#
# 12 exit 0 with the wrong value, 20 exit 51, 8 refused. After: 40 of 40 exit 0.
#
# The false half in an ENCRYPTED slot is a second mechanism and was not in the
# ticket: _encrypt_tree skips a leaf that is an empty string, and `!!0`'s PV IS
# the empty string, so it reached the document as a plaintext '' against a
# digest of `False`. That is the JSON->false defect the comment there already
# describes, one value class over -- the !blessed() guard does not cover a
# sentinel, because a sentinel is not blessed.
#
# REPAIRED rather than refused (ADR 0016): SOPS has a bool type, sops itself
# writes `type:bool` for a plaintext `true`, and the route in --
# `encrypt(data => { admin => ($user->{level} > 3) })` -- is ordinary Perl with
# one unambiguous meaning. Unlike ADR 0012's dualvar there are not two
# candidate halves to guess between.
#
# No binary is needed for anything below: the document and its own MAC state
# different things, which is visible from inside Perl. The round trip against
# sops itself is pinned in t/04-interop.t.
# ----------------------------------------------------------------------------

my $HAS_BOOL_SV = do {
    no warnings;
    eval q{
        no warnings 'experimental::builtin';
        use builtin qw(is_bool);
        is_bool(!!1) ? 1 : 0
    } || 0;
};

unless ($HAS_BOOL_SV) {
    plan skip_all =>
        "perl $] has no boolean SV (SvIsBOOL arrived in 5.36), so neither "
      . "emitter can write one as a bare true/false and there is nothing here "
      . "to disagree about. detect_type answers `int` on this perl by design "
      . "-- see docs/adr/0016.";
}

my ($public, $secret) = Crypt::Age->generate_keypair();

# Freshly for every use. The flags are the whole point of this file, and a
# shared scalar would let one assertion carry state into the next.
sub sentinels {
    my $x = 5;
    my @s = (
        [ '!!1'             => !!1,             1 ],
        [ '!!0'             => !!0,             0 ],
        [ '$x > 3'          => ($x > 3),        1 ],
        [ '$x > 9'          => ($x > 9),        0 ],
        [ "'a' eq 'a'"      => ('a' eq 'a'),    1 ],
        [ "'a' eq 'b'"      => ('a' eq 'b'),    0 ],
        [ 'defined $x'      => (defined $x),    1 ],
    );
    {
        no warnings 'experimental::builtin';
        require builtin;
        push @s, [ 'builtin::true'  => builtin::true(),  1 ];
        push @s, [ 'builtin::false' => builtin::false(), 0 ];
    }
    {
        # A tree the CALLER loaded with their own YAML::XS::Load: our parse
        # localises $YAML::XS::Boolean to 'JSON::PP', a caller's does not.
        my $d = YAML::XS::Load("t: true\nf: false\n");
        push @s, [ "caller's YAML::XS::Load true"  => $d->{t}, 1 ];
        push @s, [ "caller's YAML::XS::Load false" => $d->{f}, 0 ];
    }
    return @s;
}

###############################################################################
# 1. THE TYPE AND THE DIGEST. One ladder, one conversion, so both are asserted
#    together -- the label and the MAC bytes are a single decision.
###############################################################################

subtest 'a boolean sentinel is a bool digesting True / False' => sub {
    for my $s (sentinels()) {
        my ($name, $leaf, $true) = @$s;
        is(File::SOPS::Encrypted->detect_type($leaf), 'bool',
            "$name is a bool, not an int");
        is(File::SOPS::Encrypted->value_to_bytes($leaf),
            $true ? 'True' : 'False',
            "$name digests " . ($true ? 'True' : 'False'));
    }
};

subtest 'the predicate is the emitters own, not a flag or text lookalike' => sub {
    # dualvar(1, '1') carries the same IV, the same PV and the same PUBLIC
    # flags as !!1. Both emitters write it as `1`, so typing it `bool` would be
    # this defect reintroduced by its own fix. Measured on YAML::XS 0.910.0 and
    # Cpanel::JSON::XS 4.43.
    my %not_a_bool = (
        "dualvar(1, '1')" => [ dualvar(1, '1'),  'int', '1' ],
        "dualvar(0, '')"  => [ dualvar(0, ''),   'int', '0' ],
        'the integer 1'   => [ 1,                'int', '1' ],
        'the integer 0'   => [ 0,                'int', '0' ],
        "the string '1'"  => [ '1',              'str', '1' ],
        "the string ''"   => [ '',               'str', '' ],
        "the string 'true'"  => [ 'true',        'str', 'true' ],
        "the string 'false'" => [ 'false',       'str', 'false' ],
        'the float 1.0'   => [ 1.0,              'float', '1' ],
    );
    for my $name (sort keys %not_a_bool) {
        my ($leaf, $type, $bytes) = @{ $not_a_bool{$name} };
        is(File::SOPS::Encrypted->detect_type($leaf), $type,
            "$name is still $type");
        is(File::SOPS::Encrypted->value_to_bytes($leaf), $bytes,
            "$name still digests $bytes");
    }
};

subtest 'a JSON::PP::Boolean is untouched' => sub {
    is(File::SOPS::Encrypted->detect_type(JSON->true), 'bool', 'JSON->true is a bool');
    is(File::SOPS::Encrypted->detect_type(JSON->false), 'bool', 'JSON->false is a bool');
    is(File::SOPS::Encrypted->value_to_bytes(JSON->true), 'True', 'JSON->true digests True');
    is(File::SOPS::Encrypted->value_to_bytes(JSON->false), 'False', 'JSON->false digests False');
};

###############################################################################
# 2. THE DOCUMENT AND ITS OWN MAC. This is what actually shipped broken: the
#    file said one thing and the digest covered another, in four combinations
#    of slot and handler, and three of the four were written silently.
###############################################################################

# Encrypt and read straight back, which is all it takes to see this defect: the
# document and its own MAC disagree. Failures are RETURNED rather than thrown,
# so that a red run reports every broken claim instead of aborting at the first
# -- without the fix, writing a false sentinel into an unencrypted slot croaks
# and reading a true one back fails the MAC.
sub roundtrip {
    my ($leaf, $key, $format) = @_;
    my ($doc, $back) = eval {
        my $d = File::SOPS->encrypt(
            data       => { $key => $leaf },
            recipients => [$public],
            format     => $format,
        );
        my $b = File::SOPS->decrypt(
            encrypted  => $d,
            identities => [$secret],
            format     => $format,
        );
        ($d, $b->{$key});
    };
    return ($doc, $back, undef) unless $@;
    (my $why = $@) =~ s/\s+/ /g;
    return (undef, undef, $why);
}

for my $format (qw(yaml json)) {
    subtest "a sentinel survives its own MAC in both slots ($format)" => sub {
        for my $s (sentinels()) {
            my ($name, $leaf, $true) = @$s;
            for my $key (qw(leaf leaf_unencrypted)) {
                my ($doc, $back, $why) = roundtrip($leaf, $key, $format);
                ok(!defined $why, "$name in $key round-trips ($format)")
                    or do { diag($why); next };
                isa_ok($back, 'JSON::PP::Boolean',
                    "$name in $key comes back a boolean ($format)");
                is(!!$back, !!$true, "$name in $key keeps its value ($format)");
            }
        }
    };

    subtest "the wire form is type:bool, and the plaintext slot is a bare boolean ($format)" => sub {
        my ($enc_doc) = roundtrip(!!1, 'leaf', $format);
        like($enc_doc, qr/ENC\[AES256_GCM,[^\]]*,type:bool\]/,
            "an encrypted true sentinel is type:bool ($format)");

        # The false half went into the document as a plaintext '' -- the
        # empty-leaf skip in _encrypt_tree, whose eq test a sentinel's PV
        # satisfies -- while the digest covered `False`.
        my ($enc_doc0) = roundtrip(!!0, 'leaf', $format);
        like($enc_doc0, qr/ENC\[AES256_GCM,[^\]]*,type:bool\]/,
            "an encrypted FALSE sentinel is type:bool and not an empty string ($format)");
        unlike($enc_doc0, $format eq 'yaml' ? qr/^leaf: ''$/m
                                            : qr/"leaf"\s*:\s*""/,
            "the false sentinel is not skipped as an empty leaf ($format)");

        my ($plain_doc, undef, $why) = roundtrip(!!1, 'leaf_unencrypted', $format);
        ok(!defined $why, "an unencrypted true sentinel is writable ($format)")
            or diag($why);
        like($plain_doc, $format eq 'yaml' ? qr/^leaf_unencrypted: true$/m
                                           : qr/"leaf_unencrypted"\s*:\s*true/,
            "an unencrypted true sentinel is a bare boolean in the document ($format)");
    };

    subtest "both boolean routes write the SAME document ($format)" => sub {
        # Two boolean mechanisms with different results is exactly what this
        # change must not produce.
        for my $key (qw(leaf leaf_unencrypted)) {
            for my $true (1, 0) {
                my $sentinel = $true ? !!1 : !!0;
                my $jsonpp   = $true ? JSON->true : JSON->false;
                my ($a) = roundtrip($sentinel, $key, $format);
                my ($b) = roundtrip($jsonpp,   $key, $format);
                is(defined $a ? normalise($a) : undef,
                   defined $b ? normalise($b) : undef,
                    "sentinel and JSON::PP::Boolean agree for "
                    . ($true ? 'true' : 'false') . " in $key ($format)");
            }
        }
    };
}

# Everything that differs between two runs by construction: the per-value
# ciphertext, the wrapped data key and the timestamp. What is left is the
# structure, the key names and the wire TYPE, which is what these compare.
sub normalise {
    my ($doc) = @_;
    $doc =~ s/ENC\[AES256_GCM,data:[^,]*,iv:[^,]*,tag:[^,]*,(type:[a-z]+)\]/ENC[$1]/g;
    $doc =~ s/"?lastmodified"?\s*[:=]\s*"[^"]*"/lastmodified/g;
    $doc =~ s/-----BEGIN AGE ENCRYPTED FILE-----.*?-----END AGE ENCRYPTED FILE-----/AGE/gs;
    $doc =~ s/"enc"\s*:\s*"[^"]*"/"enc":"AGE"/g;
    return $doc;
}

###############################################################################
# 3. THE k88 TRAP. Perl's arithmetic marks a caller's scalar IN PLACE, so
#    a conversion that numifies its operand retypes the tree it was asked
#    about. The same tree is emitted five times, and the caller's own scalars
#    are re-read after every round.
###############################################################################

subtest 'the same tree emitted five times is the same document' => sub {
    my $x = 5;
    my $tree = {
        t   => !!1,
        f   => !!0,
        cmp => ($x > 3),
        n   => 5432,
        s   => '5432',
        fl  => 1.5,
    };
    for my $format (qw(yaml json)) {
        my %documents;
        for my $round (1 .. 5) {
            my $doc = File::SOPS->encrypt(
                data       => $tree,
                recipients => [$public],
                format     => $format,
            );
            $documents{ normalise($doc) }++;

            is(File::SOPS::Encrypted->detect_type($tree->{t}), 'bool',
                "round $round: the true sentinel is still a bool ($format)");
            is(File::SOPS::Encrypted->detect_type($tree->{f}), 'bool',
                "round $round: the false sentinel is still a bool ($format)");
            is(File::SOPS::Encrypted->value_to_bytes($tree->{t}), 'True',
                "round $round: it still digests True ($format)");
            is(File::SOPS::Encrypted->value_to_bytes($tree->{f}), 'False',
                "round $round: it still digests False ($format)");
            # The neighbours: a string next to a boolean must not be retyped
            # by anything the walk did on its way past.
            is(File::SOPS::Encrypted->detect_type($tree->{s}), 'str',
                "round $round: the neighbouring string is still a str ($format)");
            is(File::SOPS::Encrypted->detect_type($tree->{n}), 'int',
                "round $round: the neighbouring integer is still an int ($format)");
            is(File::SOPS::Encrypted->detect_type($tree->{fl}), 'float',
                "round $round: the neighbouring float is still a float ($format)");
        }
        is(scalar keys %documents, 1,
            "five rounds over one tree produced one document ($format)");
    }
};

###############################################################################
# 4. THE READ PATH IS UNTOUCHED. A type:bool still deserializes to a
#    JSON::PP::Boolean, and a 0.003 document that stored a sentinel as
#    type:int plaintext 1 still reads back as the integer it says it is.
###############################################################################

subtest 'a type:int leaf is still read back as an integer' => sub {
    # Hand-built the way t/07-mac.t builds its fixtures: an explicit type
    # writes the label, the bytes come from the value.
    my $key = "\x00" x 32;
    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => 1, key => $key, aad => 'leaf:', type => 'int',
    );
    my $back = $enc->decrypt_value(key => $key, aad => 'leaf:');
    is(File::SOPS::Encrypted->detect_type($back), 'int',
        'a stored type:int comes back an int, sentinel or not');
    is($back, 1, 'and it is the integer 1');
};

subtest 'a type:bool leaf still comes back a JSON::PP::Boolean' => sub {
    my $key = "\x00" x 32;
    for my $pair ([ 'True' => 1 ], [ 'False' => 0 ]) {
        my ($bytes, $true) = @$pair;
        my $enc = File::SOPS::Encrypted->encrypt_value(
            value => $bytes, key => $key, aad => 'leaf:', type => 'bool',
        );
        my $back = $enc->decrypt_value(key => $key, aad => 'leaf:');
        isa_ok($back, 'JSON::PP::Boolean', "a stored $bytes");
        is(!!$back, !!$true, "a stored $bytes is $bytes");
    }
};

done_testing;
