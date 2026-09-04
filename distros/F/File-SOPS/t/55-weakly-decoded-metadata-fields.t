#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;
use File::Temp qw(tempdir);
use JSON::MaybeXS;
use Crypt::Age;

use File::SOPS;
use File::SOPS::Metadata;
use File::SOPS::Metadata::Flat;
use File::SOPS::Format::YAML;
use File::SOPS::Format::JSON;
use File::SOPS::Backend::Age;
use File::SOPS::Encrypted;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k138, handed over from k77 -- docs/adr/0042.
#
# sops decodes its `sops` section through mapstructure with WeaklyTypedInput,
# in EVERY format and not only in the untyped flat ones. Two fields in that
# section are not strings:
#
#     mac_only_encrypted   bool   strconv.ParseBool, plus "" as false
#     shamir_threshold     int    strconv.ParseInt(s, 0, 64), plus "" as 0
#
# The first one PICKS THE DIGEST -- with it set the MAC covers only encrypted
# values, behind a 32-byte MACOnlyEncryptedInitialization prefix -- so reading
# it wrong computes the wrong MAC for a document sops reads at exit 0. And
# Perl's 'false' is TRUE, which is exactly what
# File::SOPS::Metadata::Flat->unflatten hands back for
# `sops_mac_only_encrypted=false`, faithfully, because the flat formats have
# no types. It is the same hazard in a NESTED YAML section: a quoted
# `mac_only_encrypted: "false"` is the boolean false to sops.
#
# So the coercion lives in File::SOPS::Metadata->from_hash, the one place
# every format's parsed section arrives, typed or not -- not in unflatten,
# which stays the structural inverse of flatten and has no schema (t/38 and
# t/50 pin that and stay right).
#
# Every row below was measured against sops 3.13.3 in a nested YAML sops
# section. The interop half at the bottom re-measures all of them and asserts
# that our answer is the binary's answer, row for row.

###############################################################################
# The measured tables. `want` is what sops decodes the value to; for a YAML
# document `sops -d` reports it as an exit code, because the option selects
# the digest:
#
#     exit 0   decoded false -- the digest covers every value, as written
#     exit 51  decoded TRUE  -- MAC mismatch, the digest moved
#     exit 1   refused, "cannot parse value as 'bool'"
###############################################################################

# yaml spelling | the scalar OUR parser produces for it | sops's answer
my @MAC_ONLY = (
    [ q{false},    JSON->false, 'false'   ],
    [ q{"false"},  'false',     'false'   ],
    [ q{"FALSE"},  'FALSE',     'false'   ],
    [ q{"False"},  'False',     'false'   ],
    [ q{"f"},      'f',         'false'   ],
    [ q{"F"},      'F',         'false'   ],
    [ q{"0"},      '0',         'false'   ],
    [ q{""},       '',          'false'   ],
    [ q{0},        0,           'false'   ],
    [ q{0.0},      0.0,         'false'   ],
    [ q{null},     undef,       'false'   ],
    [ q{true},     JSON->true,  'true'    ],
    [ q{"true"},   'true',      'true'    ],
    [ q{"TRUE"},   'TRUE',      'true'    ],
    [ q{"True"},   'True',      'true'    ],
    [ q{"t"},      't',         'true'    ],
    [ q{"T"},      'T',         'true'    ],
    [ q{"1"},      '1',         'true'    ],
    [ q{1},        1,           'true'    ],
    [ q{1.0},      1.0,         'true'    ],
    [ q{2},        2,           'true'    ],
    [ q{-1},       -1,          'true'    ],
    [ q{"2"},      '2',         'refused' ],
    [ q{"yes"},    'yes',       'refused' ],
    [ q{"no"},     'no',        'refused' ],
    [ q{"on"},     'on',        'refused' ],
    [ q{"off"},    'off',       'refused' ],
    [ q{"tRuE"},   'tRuE',      'refused' ],
    [ q{" false"}, ' false',    'refused' ],
    [ q{"false "}, 'false ',    'refused' ],
    [ q{"0.0"},    '0.0',       'refused' ],
    [ q{"1.0"},    '1.0',       'refused' ],
    [ q{[]},       [],          'refused' ],
    [ q{{}},       {},          'refused' ],
);

# yaml spelling | the scalar OUR parser produces | what sops decodes it to,
# `undef` where sops refuses the document with "cannot parse value as 'int'".
# Base 0: 0x/0X hex, 0b/0B binary, 0o/0O octal, a bare leading 0 octal, and
# underscores between digits. The window is Go's int64.
my @SHAMIR = (
    [ q{2},                      2,                      2                    ],
    [ q{"2"},                    '2',                    2                    ],
    [ q{"0"},                    '0',                    0                    ],
    [ q{""},                     '',                     0                    ],
    [ q{"00"},                   '00',                   0                    ],
    [ q{"+2"},                   '+2',                   2                    ],
    [ q{"-1"},                   '-1',                   -1                   ],
    [ q{"-0"},                   '-0',                   0                    ],
    [ q{"010"},                  '010',                  8                    ],
    [ q{"0x10"},                 '0x10',                 16                   ],
    [ q{"0X1f"},                 '0X1f',                 31                   ],
    [ q{"0b101"},                '0b101',                5                    ],
    [ q{"0B11"},                 '0B11',                 3                    ],
    [ q{"0o17"},                 '0o17',                 15                   ],
    [ q{"0O7"},                  '0O7',                  7                    ],
    [ q{"1_000"},                '1_000',                1000                 ],
    [ q{"0x_1"},                 '0x_1',                 1                    ],
    [ q{"9223372036854775807"},  '9223372036854775807',  9223372036854775807  ],
    [ q{"-9223372036854775808"}, '-9223372036854775808', -9223372036854775808 ],
    # int64's ends spelled in the other bases, where a Perl UV of 2**63 and a
    # double are both one wrong step away.
    [ q{"0x7fffffffffffffff"},   '0x7fffffffffffffff',   9223372036854775807  ],
    [ q{"-0x8000000000000000"},  '-0x8000000000000000',  -9223372036854775808 ],
    [ q{"0777777777777777777777"},
                                 '0777777777777777777777', 9223372036854775807 ],
    [ q{"0x8000000000000000"},   '0x8000000000000000',   undef                ],
    [ q{"0xFFFFFFFFFFFFFFFFF"},  '0xFFFFFFFFFFFFFFFFF',  undef                ],
    [ q{"false"},                'false',                undef                ],
    [ q{"true"},                 'true',                 undef                ],
    [ q{"abc"},                  'abc',                  undef                ],
    [ q{"2.0"},                  '2.0',                  undef                ],
    [ q{"1e3"},                  '1e3',                  undef                ],
    [ q{" 2"},                   ' 2',                   undef                ],
    [ q{"2 "},                   '2 ',                   undef                ],
    [ q{"+"},                    '+',                    undef                ],
    [ q{"-"},                    '-',                    undef                ],
    [ q{"0x"},                   '0x',                   undef                ],
    [ q{"0b"},                   '0b',                   undef                ],
    [ q{"08"},                   '08',                   undef                ],
    [ q{"0o8"},                  '0o8',                  undef                ],
    [ q{"0_"},                   '0_',                   undef                ],
    [ q{"_1"},                   '_1',                   undef                ],
    [ q{"1_"},                   '1_',                   undef                ],
    [ q{"1__0"},                 '1__0',                 undef                ],
    [ q{"0_x1"},                 '0_x1',                 undef                ],
    [ q{"9223372036854775808"},  '9223372036854775808',  undef                ],
    [ q{"-9223372036854775809"}, '-9223372036854775809', undef                ],
    [ q{[]},                     [],                     undef                ],
    [ q{{}},                     {},                     undef                ],
);

###############################################################################
# 1. mac_only_encrypted -- strconv.ParseBool's set, plus the empty string
###############################################################################
subtest 'mac_only_encrypted decodes exactly what sops decodes' => sub {
    for my $row (@MAC_ONLY) {
        my ($yaml, $perl, $want) = @$row;

        my $meta = eval { section(mac_only_encrypted => $perl) };
        my $err  = $@;

        if ($want eq 'refused') {
            ok $err, "$yaml is refused, as sops refuses it with exit 1";
            like $err, qr/\Qmac_only_encrypted\E/,
                "   and the message names the field";
            next;
        }

        is $err, '', "$yaml is accepted";
        next if $err;

        my $got = $meta->mac_only_encrypted;
        is(($got ? 'true' : 'false'), $want, "$yaml decodes to $want");
    }
};

subtest 'a decoded string becomes a real boolean, never 1 or 0' => sub {
    # Invariant 6: a bool in this distribution is a JSON::PP::Boolean, so that
    # every emitter writes `true`/`false` rather than degrading it to an int.
    for my $text (qw( false true 0 1 f t F T FALSE TRUE False True ), '') {
        my $got = section(mac_only_encrypted => $text)->mac_only_encrypted;
        isa_ok $got, 'JSON::PP::Boolean', "the decoding of '$text'";
    }
};

subtest 'a real boolean, number or absence is left alone' => sub {
    # The coercion is for STRINGS -- what an untyped store and a quoted YAML
    # scalar produce. A value the parser already typed is sops's own zero
    # work, and Perl's truth of it agrees with Go's on every row above.
    my $t = section(mac_only_encrypted => JSON->true)->mac_only_encrypted;
    my $f = section(mac_only_encrypted => JSON->false)->mac_only_encrypted;
    is ref($t), 'JSON::PP::Boolean', 'a JSON::PP::Boolean true passes through';
    is ref($f), 'JSON::PP::Boolean', 'a JSON::PP::Boolean false passes through';
    ok $t, 'and it is still true';
    ok !$f, 'and it is still false';

    is section(mac_only_encrypted => 2)->mac_only_encrypted, 2,
        'a number is not touched -- Go asks int != 0 and so does Perl';
    is section(mac_only_encrypted => 0)->mac_only_encrypted, 0,
        'including a numeric zero';
    is section()->mac_only_encrypted, undef,
        'an absent field stays absent';
    is section(mac_only_encrypted => undef)->mac_only_encrypted, undef,
        'and a null stays undef, which is false here as nil is false there';
};

###############################################################################
# 2. shamir_threshold -- strconv.ParseInt(s, 0, 64), plus the empty string
###############################################################################
subtest 'shamir_threshold decodes exactly what sops decodes' => sub {
    for my $row (@SHAMIR) {
        my ($yaml, $perl, $want) = @$row;

        my $meta = eval { section(shamir_threshold => $perl) };
        my $err  = $@;

        if (!defined $want) {
            ok $err, "$yaml is refused, as sops refuses it with exit 1";
            like $err, qr/\Qshamir_threshold\E/,
                "   and the message names the field";
            next;
        }

        is $err, '', "$yaml is accepted";
        next if $err;

        is $meta->extra->{shamir_threshold}, $want, "$yaml decodes to $want";
    }
};

subtest 'a decoded shamir_threshold is an integer, and stays unmodelled' => sub {
    my $meta = section(shamir_threshold => '0x10');
    is(File::SOPS::Encrypted->detect_type($meta->extra->{shamir_threshold}),
       'int', 'the decoded value is an int SV, so every emitter writes 16 bare');
    is $meta->to_hash->{shamir_threshold}, 16,
        'and to_hash carries it back out of extra';

    # A value the parser already typed is left exactly as it was: nothing here
    # reads shamir_threshold, and sops re-reads whatever we write.
    is section(shamir_threshold => 2)->extra->{shamir_threshold}, 2,
        'a real number passes through';
    is section(shamir_threshold => 2.7)->extra->{shamir_threshold}, 2.7,
        'a real float too -- sops truncates it to 2 on the way in, either way';
};

###############################################################################
# 3. The bug the ticket was filed for: the flat encoding's string
###############################################################################
subtest 'the flat encoding reaches from_hash as a string, and decodes there' => sub {
    my $flat = File::SOPS::Metadata::Flat->new(prefix => 'sops_');

    my $off = $flat->unflatten({ sops_mac_only_encrypted => 'false' });
    is $off->{mac_only_encrypted}, 'false',
        'unflatten is still faithful to the untyped encoding (t/38, t/50)';
    ok !File::SOPS::Metadata->from_hash($off)->mac_only_encrypted,
        'and from_hash reads it as the FALSE sops reads, not as Perl truth';

    my $on = $flat->unflatten({ sops_mac_only_encrypted => 'true' });
    ok(File::SOPS::Metadata->from_hash($on)->mac_only_encrypted,
       'while the string true is true, as it is there');

    my $n = $flat->unflatten({ sops_shamir_threshold => '2' });
    is(File::SOPS::Metadata->from_hash($n)->extra->{shamir_threshold}, 2,
       'and the untyped threshold arrives as the integer 2');
};

###############################################################################
# 4. Nothing moves for a document that already carried a real boolean
###############################################################################
subtest 'a YAML or JSON document with a real boolean is untouched' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();
    my %data = (v => 'hello', n => 42, plain_unencrypted => 'visible');

    for my $format (qw( yaml json )) {
        my %digest;
        for my $mode (qw( absent false true )) {
            my $doc = File::SOPS->encrypt(
                data       => { %data },
                recipients => [$public],
                format     => $format,
                ($mode eq 'true' ? (mac_only_encrypted => 1) : ()),
            );
            $doc = add_false($doc, $format) if $mode eq 'false';

            $digest{$mode} = mac_plaintext($doc, $format, $secret);

            my $back = File::SOPS->decrypt(
                encrypted => $doc, identities => [$secret]);
            is $back->{v}, 'hello', "[$format/$mode] the document still verifies";
        }

        is $digest{false}, $digest{absent},
            "[$format] an explicit `mac_only_encrypted: false` is the absent one";
        isnt $digest{true}, $digest{absent},
            "[$format] and setting it picks the other digest";
        note("[$format] digest off = $digest{absent}");
        note("[$format] digest on  = $digest{true}");
    }
};

###############################################################################
# 5. to_hash writes the exact types sops expects
###############################################################################
subtest 'to_hash writes a real boolean, and omits it when off' => sub {
    my $on = File::SOPS::Metadata->new(mac_only_encrypted => 1)->to_hash;
    isa_ok $on->{mac_only_encrypted}, 'JSON::PP::Boolean',
        'to_hash writes a JSON::PP::Boolean';
    ok $on->{mac_only_encrypted}, 'and it is true';

    for my $off (JSON->false, 0, '', undef) {
        my $hash = File::SOPS::Metadata->new(mac_only_encrypted => $off)->to_hash;
        ok !exists $hash->{mac_only_encrypted},
            'the key is omitted when the option is off, as sops omits it';
    }

    # And the round trip through a decoded string, which is the whole point:
    # a document that said "false" comes back out saying nothing at all.
    my $decoded = section(mac_only_encrypted => 'false')->to_hash;
    ok !exists $decoded->{mac_only_encrypted},
        'a decoded false is written back as no key at all';
    ok section(mac_only_encrypted => 'true')->to_hash->{mac_only_encrypted},
        'and a decoded true as a real boolean';
};

###############################################################################
# 6. Interop -- the only half that proves anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the weak-decoding tables above were NOT measured "
       . "against sops, so what from_hash reproduces went unchecked. Run "
       . "maint/fetch-sops or set SOPS_BIN.", 2
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    my $dir = tempdir(CLEANUP => 1);
    my ($pub, $sec) = Crypt::Age->generate_keypair();
    write_bytes("$dir/key.txt", $sec);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    write_bytes("$dir/meta.yaml", "v: hello\n");
    my $base = run_ok($sops_bin, 'sops -e for the metadata fixture',
        "-e --age '$pub' '$dir/meta.yaml'");

    subtest 'sops decodes mac_only_encrypted weakly in a NESTED yaml section' => sub {
        for my $row (@MAC_ONLY) {
            my ($yaml, undef, $want) = @$row;
            my $code = probe($sops_bin, $dir, $base, mac_only_encrypted => $yaml);
            my $sops = $code == 0  ? 'false'
                     : $code == 51 ? 'true'
                     : $code == 1  ? 'refused'
                     :               "exit $code";
            is $sops, $want,
                "mac_only_encrypted: $yaml -> $want"
              . ($want eq 'true' ? ' (and the digest moves with it)' : '');
        }
    };

    subtest 'sops decodes shamir_threshold weakly in the same section' => sub {
        for my $row (@SHAMIR) {
            my ($yaml, undef, $want) = @$row;
            my $code = probe($sops_bin, $dir, $base, shamir_threshold => $yaml);
            if (defined $want) {
                is $code, 0, "shamir_threshold: $yaml is accepted (we read $want)";
            }
            else {
                is $code, 1, "shamir_threshold: $yaml is refused, and so are we";
            }
        }
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# A minimal sops section carrying one field, through the method under test.
sub section {
    my (%field) = @_;
    return File::SOPS::Metadata->from_hash({
        age => [], lastmodified => 'T', version => '3.13.3', %field,
    });
}

sub add_false {
    my ($doc, $format) = @_;
    if ($format eq 'yaml') {
        $doc =~ s/^(\s+)version:/$1mac_only_encrypted: false\n$1version:/m
            or die 'the yaml fixture has no version line';
    }
    else {
        $doc =~ s/"version"/"mac_only_encrypted":false,"version"/
            or die 'the json fixture has no version key';
    }
    return $doc;
}

# The uppercase hex SHA-512 a document claims for itself.
sub mac_plaintext {
    my ($text, $format, $identity) = @_;
    my (undef, $meta) = $format eq 'yaml'
        ? File::SOPS::Format::YAML->parse($text)
        : File::SOPS::Format::JSON->parse($text);
    my $key = File::SOPS::Backend::Age->decrypt_data_key(
        age_keys   => [ $meta->get_age_encrypted_keys ],
        identities => [ $identity ],
    );
    return File::SOPS::Encrypted->parse($meta->mac)
        ->decrypt_bytes(key => $key, aad => $meta->lastmodified // '');
}

sub probe {
    my ($sops_bin, $dir, $base, $field, $spelling) = @_;
    my $doc = $base;
    $doc =~ s/^(\s+)version:/$1$field: $spelling\n$1version:/m
        or die 'the metadata fixture has no version line';
    write_bytes("$dir/probe.yaml", $doc);
    my $out = `$sops_bin -d --output-type json '$dir/probe.yaml' 2>&1`;
    return $? >> 8;
}

sub write_bytes {
    my ($path, $bytes) = @_;
    open my $fh, '>:raw', $path or die "open $path: $!";
    print $fh $bytes;
    close $fh or die "close $path: $!";
    return;
}

sub run_ok {
    my ($sops_bin, $what, $args) = @_;
    my $out = `$sops_bin $args 2>&1`;
    die "$what failed: $out" if $? != 0;
    return $out;
}
