#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Crypt::Age;
use YAML::PP;

use File::SOPS;
use File::SOPS::Metadata;
use File::SOPS::Format::YAML;
use File::SOPS::Backend::Age;
use File::SOPS::Encrypted;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k159 -- docs/adr/0050. The open half of k144 (docs/adr/0044).
#
# `lastmodified: 2026-08-21T09:05:08Z` written PLAIN is a document sops
# refuses whole, before it decrypts anything: gopkg.in/yaml.v3 resolves a bare
# RFC3339 scalar to a Go time.Time and sops's decoder wants a string.
#
#   lastmodified: "2026-08-21T09:05:08Z"    sops -d exit 0
#   lastmodified: 2026-08-21T09:05:08Z      sops -d exit 1
#         'lastmodified' expected type 'string', got unconvertible type
#         'time.Time'
#
# This library reads both, because a bare and a quoted scalar arrive at
# from_hash as the SAME Perl string (docs/adr/0038), so the decision cannot be
# taken in Metadata.pm at all. It is a plain/quoted question about the source
# bytes, which is the YAML handler's.
#
# WHAT LANDED IS A WARNING, not a refusal, and that is measured rather than
# timid: every write path here re-stamps and quotes the timestamp, so `rotate`
# turns such a document into one `sops -d` reads at exit 0. A refusal would
# take the one tool that can still repair the file and leave it unopenable by
# every tool.
#
# THE GUARD NEVER FIRES ON A DOCUMENT SOPS READS -- k145's condition, and
# the reason that ticket was closed unimplemented. Two spellings pin it: a
# quoted timestamp (the ordinary case), and `!!str <bare timestamp>`, where the
# explicit tag stops go-yaml's implicit resolver before parseTimestamp runs and
# sops reads the document at exit 0.

###############################################################################
# 1. The oracle -- YAML::PP's parser, asked for one scalar's style
#
# NOT ADR 0026's mechanism. There YAML::PP is asked as a RESOLVER, and its
# answer IS the plain/quoted answer because its Core schema reads a plain
# `.inf` as a float and a quoted one as a string. YAML 1.2's Core schema has no
# timestamp type, so it hands back the same Perl string for both spellings
# here -- pinned below, because it is the reason this file needs a different
# oracle rather than a copy of that one.
###############################################################################
subtest 'YAML::PP as a RESOLVER cannot tell the two apart' => sub {
    my $pp = YAML::PP->new(schema => [qw( Core )]);

    my $bare   = $pp->load_string("sops:\n    lastmodified: 2026-08-21T09:05:08Z\n");
    my $quoted = $pp->load_string("sops:\n    lastmodified: \"2026-08-21T09:05:08Z\"\n");

    is $bare->{sops}{lastmodified}, $quoted->{sops}{lastmodified},
        'the Core schema resolves a plain and a quoted timestamp identically';
    ok !ref $bare->{sops}{lastmodified},
        'both are strings, so the resolution carries no plain/quoted answer';

    # The contrast, and why ADR 0026's mechanism works where this one cannot:
    # for an infinity the SAME loader answers a number for the plain spelling
    # and a string for the quoted one.
    my $inf = $pp->load_string("v: .inf\nq: \".inf\"\n");
    isnt "$inf->{v}", "$inf->{q}",
        'where for .inf the resolution IS the plain/quoted answer';
};

# 1 plain, 0 not plain, undef for "this parser could not say".
my @STYLE = (
    [ "sops:\n    lastmodified: 2026-08-21T09:05:08Z\n",
      1, 'a bare scalar' ],
    [ "sops:\n    lastmodified: \"2026-08-21T09:05:08Z\"\n",
      0, 'double-quoted' ],
    [ "sops:\n    lastmodified: '2026-08-21T09:05:08Z'\n",
      0, 'single-quoted' ],
    # the style IS plain, but an explicit tag stops go-yaml's resolver, and
    # sops reads such a document -- measured, interop block below
    [ "sops:\n    lastmodified: !!str 2026-08-21T09:05:08Z\n",
      0, 'plain but tagged !!str' ],
    # a plain scalar does not have to sit on its key's line
    [ "sops:\n    lastmodified:\n        2026-08-21T09:05:08Z\n",
      1, 'plain, on the line below its key' ],
    [ "sops:\n    lastmodified: >-\n        2026-08-21T09:05:08Z\n",
      0, 'a folded block scalar' ],
    [ "sops: {lastmodified: 2026-08-21T09:05:08Z}\n",
      1, 'plain inside a flow mapping' ],
    [ "sops: {lastmodified: \"2026-08-21T09:05:08Z\"}\n",
      0, 'quoted inside a flow mapping' ],
    [ "sops:\n    ? lastmodified\n    : 2026-08-21T09:05:08Z\n",
      1, 'plain behind an explicit ? key' ],
    # an alias carries the anchor's type in go-yaml and no style of its own
    # here, so it answers "not plain" -- a quiet miss, in the safe direction
    [ "x: &t 2026-08-21T09:05:08Z\nsops:\n    lastmodified: *t\n",
      0, 'an alias' ],
    # position, not name: only the sops section's own key counts
    [ "a:\n    lastmodified: 2026-08-21T09:05:08Z\n",
      undef, "a user's own lastmodified elsewhere" ],
    [ "sops:\n    x:\n        lastmodified: 2026-08-21T09:05:08Z\n",
      undef, 'one level deeper inside the sops section' ],
    [ "lastmodified: 2026-08-21T09:05:08Z\n",
      undef, 'at the top level' ],
    [ "sops:\n    age: []\n    lastmodified: 2026-08-21T09:05:08Z\n    mac: x\n",
      1, 'with the siblings a real section has' ],
    [ "sops:\n    age:\n        - recipient: r\n          enc: e\n"
      . "    lastmodified: 2026-08-21T09:05:08Z\n",
      1, 'after a sequence of mappings' ],
    [ "a: [1, 2]\nsops:\n    lastmodified: 2026-08-21T09:05:08Z\n",
      1, 'after a flow sequence' ],
    # fails safe, like its merge and !!bool twins
    [ "this is not: [yaml\n",
      undef, 'a document YAML::PP will not read' ],
);

subtest 'the parser places the scalar and reports its style' => sub {
    for my $row (@STYLE) {
        my ($content, $want, $label) = @$row;
        my $got = File::SOPS::Format::YAML::_plain_lastmodified($content);
        is $got, $want, $label;
    }
};

###############################################################################
# 2. The fixture, and the warning on a real document
###############################################################################
my $dir = tempdir(CLEANUP => 1);
my ($pub, $sec) = Crypt::Age->generate_keypair();

my %DATA = (alpha => 'one', beta => 42);
my $document = File::SOPS->encrypt(
    data => { %DATA }, recipients => [$pub], format => 'yaml',
);

my (undef, $meta) = File::SOPS::Format::YAML->parse($document);
my $stamp    = $meta->lastmodified;
my $data_key = File::SOPS::Backend::Age->decrypt_data_key(
    age_keys   => [ $meta->get_age_encrypted_keys ],
    identities => [$sec],
);
my $mac_plaintext = File::SOPS::Encrypted->parse($meta->mac)
    ->decrypt_bytes(key => $data_key, aad => $stamp);

# The fixture with its lastmodified line re-spelled VERBATIM -- quotes, tags
# and all -- and its MAC re-encrypted under the AAD ADR 0044 derives from the
# value, so the only thing under test is how the line is written.
sub respell {
    my ($spelling, $value) = @_;
    $value //= $stamp;

    my $aad = File::SOPS::Metadata->from_hash({
        age => [], lastmodified => $value,
    })->lastmodified;
    my $mac = File::SOPS::Encrypted->encrypt_value(
        value => $mac_plaintext, key => $data_key, aad => $aad, type => 'str',
    )->to_string;

    my $doc = $document;
    $doc =~ s/^(\s+lastmodified: ).*$/$1$spelling/m
        or die 'the fixture has no lastmodified line';
    $doc =~ s/^(\s+mac: ).*$/$1$mac/m
        or die 'the fixture has no mac line';
    return $doc;
}

sub read_back {
    my ($doc) = @_;
    my @warnings;
    my $data = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        eval {
            File::SOPS->decrypt(
                encrypted => $doc, identities => [$sec], format => 'yaml',
            );
        };
    };
    return ($data, $@, \@warnings);
}

subtest 'a plain timestamp warns, and the document is still read' => sub {
    my ($data, $error, $warnings) = read_back(respell($stamp));

    is scalar @$warnings, 1, 'exactly one warning'
        or diag(explain($warnings));
    like $warnings->[0], qr/PLAIN scalar/,
        'it says the scalar is plain';
    like $warnings->[0], qr/unconvertible type 'time\.Time'/,
        "and quotes sops's own refusal";
    like $warnings->[0], qr/rotate/,
        'and names the repair';

    is $error, '', 'nothing died';
    is_deeply $data, { %DATA }, 'the values came back';
};

subtest 'and the spellings sops reads stay silent' => sub {
    for my $spelling ("\"$stamp\"", "'$stamp'", "!!str $stamp", "!!str \"$stamp\"") {
        my ($data, $error, $warnings) = read_back(respell($spelling));
        is scalar @$warnings, 0, "lastmodified: $spelling -- no warning"
            or diag(explain($warnings));
        is_deeply $data, { %DATA }, "lastmodified: $spelling -- values came back";
    }
};

subtest 'a plain scalar go-yaml does not resolve stays silent too' => sub {
    # Neither is a timestamp to go-yaml, so neither is the divergence this
    # guard is about. sops refuses both documents for its OTHER reason --
    # time.Parse on the string -- whether they are quoted or not, so quoting
    # is not the discriminator here and ADR 0044 passes them through.
    for my $value ('hello', '2026-08-21T09:05:08') {
        my ($data, $error, $warnings) = read_back(respell($value, $value));
        is scalar @$warnings, 0, "lastmodified: $value -- no warning"
            or diag(explain($warnings));
        is $error, '', "lastmodified: $value -- nothing died";
    }
};

subtest 'a user key called lastmodified is not the sops section' => sub {
    # Both spelled bare in one document: the user's own, which sops resolves
    # as a timestamp and hashes as a value like any other, and the section's,
    # which is the only one this guard is about.
    my $doc = "lastmodified: 2026-08-21T09:05:08Z\n"
            . "sops:\n"
            . "    age: []\n"
            . "    lastmodified: \"2026-08-21T09:05:08Z\"\n"
            . "    version: 3.13.3\n";

    my @warnings;
    my ($data, $metadata) = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        File::SOPS::Format::YAML->parse($doc);
    };

    is scalar @warnings, 0, 'the section is quoted, so nothing is warned about'
        or diag(explain(\@warnings));
    is $data->{lastmodified}, '2026-08-21T09:05:08Z',
        "and the user's own key is untouched";

    # And the other way round: the user's key quoted, the section's bare.
    (my $swapped = $doc) =~ s/^lastmodified: (.*)$/lastmodified: "$1"/m;
    $swapped =~ s/^(\s+lastmodified: )"(.*)"$/$1$2/m;

    @warnings = ();
    {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        File::SOPS::Format::YAML->parse($swapped);
    }
    is scalar @warnings, 1, 'the section bare is the one that warns'
        or diag(explain(\@warnings));
};

###############################################################################
# 3. Every RFC3339 spelling ADR 0044 measured sops ACCEPTING when it is
#    quoted. Bare, sops refuses every one of them with the resolver message --
#    the interop block below measures that -- so there is no accepted bare
#    spelling for this guard to fire on wrongly, which is k145's
#    condition.
###############################################################################
my @ACCEPTED_QUOTED = (
    '2026-08-21T09:05:08Z',
    '2026-08-21T09:05:08+00:00',
    '2026-08-21T09:05:08-00:00',
    '2026-08-21T11:05:08+02:00',
    '2026-08-21T04:05:08-05:00',
    '2026-08-21T14:35:08+05:30',
    '2026-08-22T09:05:08+24:00',
    '2026-08-21T09:05:08+00:60',
    '2026-08-21T09:05:08.0Z',
    '2026-08-21T09:05:08.123456789Z',
    '2026-08-21T09:05:08,123Z',
    '2026-08-21T9:05:08Z',
    '2026-08-21T1:05:08+02:00',
    '0000-01-01T00:00:00Z',
    '0001-01-01T00:00:00Z',
);

subtest 'quoted is silent and bare warns, for every spelling sops accepts'
=> sub {
    for my $value (@ACCEPTED_QUOTED) {
        my (undef, undef, $quoted) = read_back(respell("\"$value\"", $value));
        is scalar @$quoted, 0,
            "lastmodified: \"$value\" -- read here without a warning"
            or diag(explain($quoted));

        # The one spelling where _go_timestamp and go-yaml's own
        # parseTimestamp were measured to disagree in this direction: a comma
        # fraction is a timestamp to go-yaml and not to this model, so the
        # guard stays quiet on a document sops refuses. The disagreement the
        # other way round is `+25:00`, which is not in this list because sops
        # refuses it quoted as well.
        next if $value eq '2026-08-21T09:05:08,123Z';

        my (undef, undef, $bare) = read_back(respell($value, $value));
        is scalar @$bare, 1, "lastmodified: $value -- bare, warned about here";
    }
};

###############################################################################
# 4. The write path -- this library has never produced such a document, and
#    reading one and writing it back is what repairs it.
###############################################################################
subtest 'every document this library writes is quoted, so nothing warns' => sub {
    my @warnings;
    my $data = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        File::SOPS->decrypt(
            encrypted => $document, identities => [$sec], format => 'yaml',
        );
    };

    like $document, qr/^\s+lastmodified: "\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ"$/m,
        'encrypt quotes the timestamp';
    is scalar @warnings, 0, 'and reading it back warns about nothing'
        or diag(explain(\@warnings));
    is_deeply $data, { %DATA }, 'values round-trip';
};

subtest 'rotate repairs a document that came in plain' => sub {
    my $path = "$dir/plain.yaml";
    write_bytes($path, respell($stamp));

    {
        local $SIG{__WARN__} = sub { };
        File::SOPS->rotate(file => $path, identities => [$sec]);
    }

    open my $fh, '<:raw', $path or die "open $path: $!";
    my $after = do { local $/; <$fh> };
    close $fh;

    like $after, qr/^\s+lastmodified: "\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ"$/m,
        'the rewritten document quotes the timestamp';

    my @warnings;
    my $data = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        File::SOPS->decrypt(
            encrypted => $after, identities => [$sec], format => 'yaml',
        );
    };
    is scalar @warnings, 0, 'and reading it warns about nothing any more'
        or diag(explain(\@warnings));
    is_deeply $data, { %DATA }, 'the values survived the rotation';
};

###############################################################################
# 5. Interop -- the only half that proves what sops does
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the whole premise of this file, that sops refuses a "
       . "plain lastmodified and reads a quoted one, went unmeasured. Run "
       . "maint/fetch-sops or set SOPS_BIN.", 3
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");
    diag("sops version: " . (split /\n/, `$sops_bin --version 2>&1`)[0]);

    write_bytes("$dir/key.txt", $sec);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    subtest 'sops reads every one of them quoted and refuses every one bare'
    => sub {
        for my $value (@ACCEPTED_QUOTED) {
            is run_sops($sops_bin, $dir, respell("\"$value\"", $value)), 0,
                "lastmodified: \"$value\" -- sops -d exit 0";

            my ($rc, $out) = run_sops_out($sops_bin, $dir, respell($value, $value));
            is $rc, 1, "lastmodified: $value -- bare, sops -d exit 1";
            like $out, qr/unconvertible type 'time\.Time'/,
                "lastmodified: $value -- and it is the RESOLVER that refuses it";
        }
    };

    subtest 'a bare but TAGGED timestamp is read by sops, and is not warned about'
    => sub {
        my $doc = respell("!!str $stamp");

        is run_sops($sops_bin, $dir, $doc), 0,
            '!!str <bare timestamp> -- sops -d exit 0, the tag stops its resolver';

        my ($data, $error, $warnings) = read_back($doc);
        is scalar @$warnings, 0, 'and this guard says nothing about it'
            or diag(explain($warnings));
        is_deeply $data, { %DATA }, 'the values come back';

        # The negative control: the same document without the tag.
        is run_sops($sops_bin, $dir, respell($stamp)), 1,
            'the same scalar untagged is exit 1 at sops';
    };

    subtest 'and what rotate wrote is a document sops reads' => sub {
        my $path = "$dir/repaired.yaml";
        write_bytes($path, respell($stamp));

        is run_sops($sops_bin, $dir, respell($stamp)), 1,
            'the document sops could not read';

        {
            local $SIG{__WARN__} = sub { };
            File::SOPS->rotate(file => $path, identities => [$sec]);
        }

        open my $fh, '<:raw', $path or die "open $path: $!";
        my $after = do { local $/; <$fh> };
        close $fh;

        is run_sops($sops_bin, $dir, $after), 0,
            'is one sops reads after a rotate here -- which a refusal would '
            . 'have made impossible';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

sub run_sops {
    my ($sops_bin, $where, $doc) = @_;
    my ($rc) = run_sops_out($sops_bin, $where, $doc);
    return $rc;
}

sub run_sops_out {
    my ($sops_bin, $where, $doc) = @_;
    write_bytes("$where/probe.yaml", $doc);
    my $out = `$sops_bin -d --input-type yaml --output-type json '$where/probe.yaml' 2>&1`;
    return ($? >> 8, $out);
}

sub write_bytes {
    my ($path, $bytes) = @_;
    open my $fh, '>:raw', $path or die "open $path: $!";
    print $fh $bytes;
    close $fh or die "close $path: $!";
    return;
}
