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
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k145 and k146 -- docs/adr/0043, the third answer out of the sweep
# that produced docs/adr/0042.
#
# Everything in a `sops` section except mac_only_encrypted and
# shamir_threshold is a Go string, and sops decodes it through mapstructure
# with WeaklyTypedInput: a non-string SCALAR is stringified and read (measured,
# `unencrypted_suffix: 3` is "3", `true` is "1", and `sops rotate` writes the
# text back), while a LIST or a MAP is refused outright with
#
#     '<field>' expected type 'string', got unconvertible type
#
# exit 1. Both halves are reproduced here, and the second one is not
# decoration: measured before this landed, `encrypted_regex: []` reached
# should_encrypt_key as the pattern, matched no key, and File::SOPS->rotate
# wrote every value of the document in PLAINTEXT and reported success -- on a
# document sops refuses to open at all.
#
# What is deliberately NOT here, because it is the same ticket's other half:
# from_hash does not restringify a non-string scalar. Perl's text and Go's
# agree for every spelling but a float outside positional range, and the first
# thing sops writes for such a document is a quoted string, so the divergence
# is not reachable from any document either implementation produced. See
# docs/adr/0043 and the POD of from_hash.

# The section's string fields, as sops's Metadata struct declares them. The
# two comment-based rules are in the list although this distribution does not
# implement them: it recognises them, refuses to encrypt under them, and they
# are strings to sops exactly like the four it does implement.
my @STRING_FIELDS = qw(
    mac
    lastmodified
    version
    unencrypted_suffix
    encrypted_suffix
    unencrypted_regex
    encrypted_regex
    unencrypted_comment_regex
    encrypted_comment_regex
);

my @REFS = (
    [ 'a list',                    sub { [] }                      ],
    [ 'a list with something in',  sub { [ 'x' ] }                 ],
    [ 'a map',                     sub { +{} }                     ],
    [ 'a code reference',          sub { sub { 'x' } }             ],
    [ 'a blessed object',          sub { bless {}, 'Some::Thing' } ],
);

###############################################################################
# 1. A reference where sops wants a string
###############################################################################
subtest 'every string field in the section refuses a reference' => sub {
    for my $field (@STRING_FIELDS) {
        for my $ref (@REFS) {
            my ($what, $make) = @$ref;
            my $err = exception { section($field => $make->()) };
            like $err, qr/\Q'$field'\E/,
                "$field: $what is refused, and the message names the field";
            like $err, qr/expected type 'string', got unconvertible type/,
                "$field: $what quotes what sops says about the same document";
        }
    }
};

###############################################################################
# 2. A scalar is NOT refused -- sops stringifies those and reads them
###############################################################################
subtest 'a scalar in the same field passes through untouched' => sub {
    # Every one of these is a document sops opens: it stringifies the value
    # (3 -> "3", true -> "1", 1.5 -> "1.5") and carries on. from_hash keeps
    # the scalar it was given -- see docs/adr/0043 for why it does not
    # restringify it here.
    for my $field (@STRING_FIELDS) {
        is reader(section($field => '_unencrypted'), $field), '_unencrypted',
            "$field: a string is kept";
        is reader(section($field => 3), $field), 3,
            "$field: a number is kept, not stringified";

        # version is the one field with a default, and the default is older
        # than this measurement: sops refuses a document whose version is
        # absent, empty or null ("Version string empty", exit 1), where
        # from_hash invents 3.7.3. Recorded, not changed -- docs/adr/0043.
        next if $field eq 'version';
        is reader(section($field => undef), $field), undef,
            "$field: an absent value stays absent";
    }

    is section(version => undef)->version, '3.7.3',
        'version keeps its default, which is a divergence and not this ticket';

    my $bool = section(mac => JSON->true)->mac;
    isa_ok $bool, 'JSON::PP::Boolean',
        'a JSON::PP::Boolean is a scalar to sops (it reads "1"), not a reference';
};

###############################################################################
# 3. An unmodelled field keeps whatever it holds
###############################################################################
subtest 'an unknown field keeps its list, because sops ignores it entirely' => sub {
    # Measured: a field sops does not know is neither decoded nor refused --
    # `totally_unknown_field: []` in a document it wrote is exit 0. And
    # key_groups IS known to sops and IS a list, so refusing a reference
    # everywhere would refuse the one document that legitimately carries one.
    my $meta = File::SOPS::Metadata->from_hash({
        age               => [],
        lastmodified      => 'T',
        version           => '3.13.3',
        key_groups        => [ { age => [] } ],
        some_future_field => [ 1, 2 ],
    });

    is_deeply $meta->extra->{key_groups}, [ { age => [] } ],
        'key_groups keeps its list';
    is_deeply $meta->extra->{some_future_field}, [ 1, 2 ],
        'and so does a field this distribution has never heard of';
};

###############################################################################
# 4. The harm the refusal closes
###############################################################################
subtest 'rotate refuses the document instead of writing it in plaintext' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();
    my $dir = tempdir(CLEANUP => 1);

    my $doc = File::SOPS->encrypt(
        data       => { db => { password => 'hunter2' } },
        recipients => [ $public ],
        format     => 'yaml',
    );

    # An encryption rule that is a LIST. sops stops at exit 1 without opening
    # the document; before docs/adr/0043 this library used the reference as
    # the pattern, matched nothing, and rotate wrote `password: hunter2`.
    $doc =~ s/^(\s+)unencrypted_suffix: .*$/$1encrypted_regex: []/m
        or die 'the fixture has no unencrypted_suffix line';

    my $file = "$dir/secrets.yaml";
    open my $fh, '>:raw', $file or die "open $file: $!";
    print $fh $doc;
    close $fh or die "close $file: $!";

    like exception {
        File::SOPS->rotate(file => $file, identities => [ $secret ])
    }, qr/\Q'encrypted_regex'\E.*expected type 'string'/s,
        'rotate stops on the malformed rule';

    open my $in, '<:raw', $file or die "open $file: $!";
    my $after = do { local $/; <$in> };
    close $in;

    unlike $after, qr/hunter2/,
        'and the secret is not on disk in plaintext';
    like $after, qr/\QENC[AES256_GCM\E/,
        'the file is the one that was there before';
};

###############################################################################
# 5. Interop -- the only half that proves anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the refusal above was NOT measured against sops, so "
       . "whether it refuses the same documents went unchecked. Run "
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

    subtest 'sops refuses a reference in each of those fields' => sub {
        for my $field (@STRING_FIELDS) {
            for my $spelling ('[]', '{}') {
                my ($code, $out)
                    = probe($sops_bin, $dir, $base, $field, $spelling);
                is $code, 1, "sops refuses $field: $spelling";
                like $out,
                    qr/\Q'$field' expected type 'string', got unconvertible type\E/,
                    "  and says so about '$field'";
            }
        }
    };

    subtest 'and reads a scalar in the same field, weakly' => sub {
        # The contrast rows. A scalar gets past the decoder and is judged on
        # its VALUE -- which is why refusing every non-string here would be
        # wrong, and refusing a reference is not.
        my ($ok) = probe($sops_bin, $dir, $base, 'unencrypted_suffix', '3');
        is $ok, 0, 'unencrypted_suffix: 3 is read as the string "3"';

        my ($mac) = probe($sops_bin, $dir, $base, 'mac', '3');
        is $mac, 51,
            'mac: 3 gets past the type decode and fails as a MAC, not as a type';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# A minimal sops section carrying one field, through the method under test.
sub section {
    my ($field, $value) = @_;
    return File::SOPS::Metadata->from_hash({
        age => [], lastmodified => 'T', version => '3.13.3', $field => $value,
    });
}

# The two comment rules are not attributes -- they live in `extra`, because
# this distribution recognises them without implementing them.
sub reader {
    my ($meta, $field) = @_;
    return $meta->can($field) ? $meta->$field : $meta->extra->{$field};
}

sub probe {
    my ($sops_bin, $dir, $base, $field, $spelling) = @_;
    my $doc = $base;

    # A rule field REPLACES the rule the fixture already has: sops refuses a
    # document carrying two of them, which would hide the answer we are after.
    if ($field =~ /(?:^|_)(?:un)?encrypted_(?:suffix|regex|comment_regex)$/) {
        $doc =~ s/^(\s+)unencrypted_suffix: .*$/$1$field: $spelling/m
            or die 'the metadata fixture has no unencrypted_suffix line';
    }
    elsif ($doc =~ /^\s+\Q$field\E:/m) {
        $doc =~ s/^(\s+)\Q$field\E: .*$/$1$field: $spelling/m
            or die "the metadata fixture has no $field line";
    }
    else {
        $doc =~ s/^(\s+)version:/$1$field: $spelling\n$1version:/m
            or die 'the metadata fixture has no version line';
    }

    write_bytes("$dir/probe.yaml", $doc);
    my $out = `$sops_bin -d --output-type json '$dir/probe.yaml' 2>&1`;
    return ($? >> 8, $out);
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
