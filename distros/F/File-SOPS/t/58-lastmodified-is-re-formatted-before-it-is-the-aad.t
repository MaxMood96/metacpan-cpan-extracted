#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Crypt::Age;

use File::SOPS;
use File::SOPS::Metadata;
use File::SOPS::Format::YAML;
use File::SOPS::Backend::Age;
use File::SOPS::Encrypted;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k144 -- docs/adr/0044.
#
# `lastmodified` is the AAD the metadata MAC is authenticated with, and sops
# does NOT use the document's text for it. It decodes the field into a Go
# time.Time and everything after that reads
# `LastModified.Format(time.RFC3339)` -- the AAD included. So a document that
# spells the same instant in any other RFC3339 form verifies at sops and used
# to die here with "Cannot decrypt MAC".
#
# Proved directly rather than inferred, by building documents whose
# lastmodified TEXT is one thing and whose `mac` was encrypted under a CHOSEN
# AAD, and asking sops which of the two it agreed with:
#
#   text "…09:05:08+00:00"  mac under "…09:05:08Z"        sops -d exit 0
#   text "…09:05:08+00:00"  mac under "…09:05:08+00:00"   sops -d exit 51
#   text "…09:05:08.123Z"   mac under "…09:05:08Z"        sops -d exit 0
#   text "…11:05:08+02:00"  mac under "…09:05:08Z"        sops -d exit 51
#   text "…11:05:08+02:00"  mac under "…11:05:08+02:00"   sops -d exit 0
#
# The round trip is purely lexical: Go parses into a fixed zone carrying the
# offset it just read, so the wall-clock fields it formats back are the ones
# it parsed. The fraction is dropped, the hour is zero-padded, the zone is
# re-derived from the TOTAL offset, and it is written `Z` whenever that total
# is zero. Nothing is converted to UTC -- `+02:00` stays `+02:00`, measured.

###############################################################################
# The measured table. Every row was confirmed against sops 3.13.3 by building
# the document with its `mac` under the AAD in column two and reading
# `sops -d` exit 0 back; the interop block at the bottom re-measures all of
# them.
#
#   spelling in the document | the AAD sops derives from it
###############################################################################
my @DERIVED = (
    [ '2026-08-21T09:05:08Z',              '2026-08-21T09:05:08Z'      ],
    # a zero offset is written `Z`, whichever sign the document used
    [ '2026-08-21T09:05:08+00:00',         '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08-00:00',         '2026-08-21T09:05:08Z'      ],
    # a non-zero offset is KEPT, not shifted to UTC
    [ '2026-08-21T11:05:08+02:00',         '2026-08-21T11:05:08+02:00' ],
    [ '2026-08-21T04:05:08-05:00',         '2026-08-21T04:05:08-05:00' ],
    [ '2026-08-21T14:35:08+05:30',         '2026-08-21T14:35:08+05:30' ],
    [ '2026-08-21T00:20:08-08:45',         '2026-08-21T00:20:08-08:45' ],
    [ '2026-08-21T09:06:08+00:01',         '2026-08-21T09:06:08+00:01' ],
    [ '2026-08-21T09:04:08-00:01',         '2026-08-21T09:04:08-00:01' ],
    [ '2026-08-22T09:04:08+23:59',         '2026-08-22T09:04:08+23:59' ],
    # 24 hours and 60 minutes are both still IN range for an offset, and the
    # zone is re-derived from the total, so +00:60 comes back out as +01:00
    [ '2026-08-22T09:05:08+24:00',         '2026-08-22T09:05:08+24:00' ],
    [ '2026-08-21T09:05:08+00:60',         '2026-08-21T09:05:08+01:00' ],
    [ '2026-08-21T09:05:08-00:60',         '2026-08-21T09:05:08-01:00' ],
    [ '2026-08-21T09:05:08+24:60',         '2026-08-21T09:05:08+25:00' ],
    # the RFC3339 layout carries no fractional field, so every fraction is
    # dropped -- at any length, and after a comma as well as a period
    [ '2026-08-21T09:05:08.0Z',            '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08.1Z',            '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08.123Z',          '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08.123456Z',       '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08.123456789Z',    '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08.123456789012Z', '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T09:05:08,123Z',          '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T11:05:08.5+02:00',       '2026-08-21T11:05:08+02:00' ],
    [ '2026-08-21T09:05:08.75+00:00',      '2026-08-21T09:05:08Z'      ],
    # Go's `15` takes one digit or two where its `01`/`02`/`04`/`05` take
    # exactly two, so the HOUR is the one field a document may under-pad
    [ '2026-08-21T9:05:08Z',               '2026-08-21T09:05:08Z'      ],
    [ '2026-08-21T1:05:08+02:00',          '2026-08-21T01:05:08+02:00' ],
    [ '2026-08-21T9:05:08.25Z',            '2026-08-21T09:05:08Z'      ],
    [ '0000-01-01T00:00:00Z',              '0000-01-01T00:00:00Z'      ],
    [ '0001-01-01T00:00:00Z',              '0001-01-01T00:00:00Z'      ],
);

# Spellings Go's RFC3339 layout cannot parse. sops refuses each of these
# documents at exit 1, so there is no AAD of its own to reproduce and the
# document's own bytes are kept -- see docs/adr/0044 for why passing them
# through beats refusing them.
my @UNPARSEABLE = (
    '2026-08-21T09:05:08+0000',   # the colon in the offset is required
    '2026-08-21T09:05:08+00',
    '2026-08-21t09:05:08Z',       # `T` and `Z` are case-sensitive
    '2026-08-21T09:05:08z',
    '2026-08-21 09:05:08Z',
    '2026-8-21T09:05:08Z',        # month and day are two fixed digits
    '2026-08-21T09:05:08',        # the zone is not optional
    '2026-08-21',
    '20260821T090508Z',
    '2026-08-21T09:05:08.Z',      # a fraction needs a digit
    '10000-08-21T09:05:08Z',      # the year is four digits, unsigned
    '-0001-01-01T00:00:00Z',
    '2026-08-21T09:05:08Z ',
    ' 2026-08-21T09:05:08Z',
    '',
    'T',
);

###############################################################################
# 1. from_hash derives the AAD sops derives
###############################################################################
subtest 'from_hash re-formats lastmodified the way Go does' => sub {
    for my $row (@DERIVED) {
        my ($text, $want) = @$row;
        is section($text)->lastmodified, $want,
            "lastmodified: \"$text\" -> AAD $want";
    }
};

subtest 'a spelling Go cannot parse keeps the document bytes' => sub {
    for my $text (@UNPARSEABLE) {
        is section($text)->lastmodified, $text,
            "lastmodified: \"$text\" is passed through unchanged";
    }

    is section(undef)->lastmodified, undef,
        'an absent lastmodified stays absent';
};

###############################################################################
# 2. The write path -- we have never produced a spelling this decode moves,
#    and must not start. There is exactly one producer: File::SOPS::encrypt,
#    which stamps a fresh metadata and never carries a document's own value
#    across (policy_args leaves lastmodified out on purpose).
###############################################################################
my $dir = tempdir(CLEANUP => 1);
my ($pub, $sec) = Crypt::Age->generate_keypair();

my %DATA = (
    alpha  => 'one',
    beta   => 42,
    nested => { deep => 'secret' },
);

my $document = File::SOPS->encrypt(
    data => { %DATA }, recipients => [$pub], format => 'yaml',
);

subtest 'every document this library writes carries the canonical Z form' => sub {
    like $document, qr/^\s+lastmodified: "\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ"$/m,
        'encrypt writes an RFC3339 timestamp in Go\'s own rendering';

    my (undef, $meta) = File::SOPS::Format::YAML->parse($document);
    is $meta->lastmodified, File::SOPS::Metadata->from_hash({
            age => [], lastmodified => $meta->lastmodified,
        })->lastmodified,
        'and the decode is the identity on it, so nothing we wrote moves';
};

###############################################################################
# 3. The regression net itself, and it needs no binary: a document whose MAC
#    sits under the AAD sops derives is a document this library reads.
###############################################################################
my (undef, $meta) = File::SOPS::Format::YAML->parse($document);
my $data_key = File::SOPS::Backend::Age->decrypt_data_key(
    age_keys   => [ $meta->get_age_encrypted_keys ],
    identities => [$sec],
);
my $mac_plaintext = File::SOPS::Encrypted->parse($meta->mac)
    ->decrypt_bytes(key => $data_key, aad => $meta->lastmodified);

subtest 'a document spelling the instant otherwise still verifies here' => sub {
    for my $row (@DERIVED) {
        my ($text, $aad) = @$row;
        my $probe = respell($document, $text, $aad);
        my $back  = eval {
            File::SOPS->decrypt(
                encrypted => $probe, identities => [$sec], format => 'yaml',
            );
        };
        is_deeply $back, { %DATA },
            "lastmodified: \"$text\" -- the MAC verifies and the values come back"
            or diag("decrypt died: $@");
    }
};

subtest 'the document text is not the AAD' => sub {
    # The negative control. Under the old rule these four documents were the
    # readable ones and the four above were not, so a fix that merely widened
    # something would show up here.
    for my $row (grep { $_->[0] ne $_->[1] } @DERIVED[1, 14, 21, 23]) {
        my ($text) = @$row;
        my $probe = respell($document, $text, $text);
        ok !eval {
                File::SOPS->decrypt(
                    encrypted => $probe, identities => [$sec], format => 'yaml',
                );
            },
            "lastmodified: \"$text\" -- a MAC under the literal text is refused";
    }
};

###############################################################################
# 4. Interop -- the only half that proves anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the AAD table above was NOT measured against sops, "
       . "so what from_hash derives went unchecked against the only thing "
       . "that specifies it. Run maint/fetch-sops or set SOPS_BIN.", 3
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");
    diag("sops version: " . (split /\n/, `$sops_bin --version 2>&1`)[0]);

    write_bytes("$dir/key.txt", $sec);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    subtest 'sops reads every document whose MAC sits under our derived AAD' => sub {
        for my $row (@DERIVED) {
            my ($text, $aad) = @$row;
            is run_sops($sops_bin, $dir, respell($document, $text, $aad)), 0,
                "lastmodified: \"$text\" -- sops -d exit 0 with the AAD $aad";
        }
    };

    subtest 'and refuses the same document with the literal text as AAD' => sub {
        for my $row (grep { $_->[0] ne $_->[1] } @DERIVED) {
            my ($text) = @$row;
            is run_sops($sops_bin, $dir, respell($document, $text, $text)), 51,
                "lastmodified: \"$text\" -- the literal text authenticates nothing";
        }
    };

    # k144's second direction, closed by k159 and docs/adr/0050.
    # go-yaml v3 resolves a BARE RFC3339 scalar as !!timestamp, where
    # mapstructure wants a string, so sops refuses the document. This library
    # still READS it -- the values and the MAC are unaffected, and a refusal
    # would take away the only thing that can repair such a file -- but it now
    # says so, from the YAML handler, which is the only place the plain/quoted
    # state exists (ADR 0038 measured that both arrive at from_hash as the same
    # Perl string). This library never WRITES such a document --
    # t/06-wire-format-regressions.t pins the quoting, and
    # t/64-a-plain-lastmodified-is-warned-about-not-refused.t owns the guard.
    subtest 'an unquoted timestamp: sops refuses it, we read it and say so'
    => sub {
        my $bare = $document;
        $bare =~ s/^(\s+lastmodified: )"([^"]*)"$/$1$2/m
            or die 'the fixture has no quoted lastmodified line';

        is run_sops($sops_bin, $dir, $bare), 1,
            'sops refuses a bare timestamp (mapstructure gets a time.Time)';

        my @warnings;
        my $back = do {
            local $SIG{__WARN__} = sub { push @warnings, $_[0] };
            eval {
                File::SOPS->decrypt(
                    encrypted => $bare, identities => [$sec], format => 'yaml',
                );
            };
        };

        ok $back, 'this library reads it -- permissive on purpose, k159';
        is scalar @warnings, 1, 'and warns about it exactly once'
            or diag(explain(\@warnings));
        like $warnings[0], qr/unconvertible type 'time\.Time'/,
            "the warning quotes sops's own refusal";
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# A `sops` section carrying nothing but the field under test, through the
# method that decodes it.
sub section {
    my ($lastmodified) = @_;
    return File::SOPS::Metadata->from_hash({
        age => [], lastmodified => $lastmodified, version => '3.13.3',
    });
}

# The fixture with its lastmodified re-spelled and its MAC re-encrypted under
# a chosen AAD. The MAC plaintext is the fixture's own, so the digest over the
# values is untouched and the only thing under test is the AAD.
sub respell {
    my ($doc, $text, $aad) = @_;

    my $mac = File::SOPS::Encrypted->encrypt_value(
        value => $mac_plaintext, key => $data_key, aad => $aad, type => 'str',
    )->to_string;

    $doc =~ s/^(\s+lastmodified: ).*$/$1"$text"/m
        or die 'the fixture has no lastmodified line';
    $doc =~ s/^(\s+mac: ).*$/$1$mac/m
        or die 'the fixture has no mac line';

    return $doc;
}

sub run_sops {
    my ($sops_bin, $where, $doc) = @_;
    write_bytes("$where/probe.yaml", $doc);
    `$sops_bin -d --input-type yaml --output-type json '$where/probe.yaml' 2>&1`;
    return $? >> 8;
}

sub write_bytes {
    my ($path, $bytes) = @_;
    open my $fh, '>:raw', $path or die "open $path: $!";
    print $fh $bytes;
    close $fh or die "close $path: $!";
    return;
}
