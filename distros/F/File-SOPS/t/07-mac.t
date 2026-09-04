#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Digest::SHA ();
use JSON::MaybeXS;
use YAML::XS ();
use Crypt::Age;

use File::SOPS;
use File::SOPS::Encrypted;
use File::SOPS::Metadata;
use File::SOPS::Format::YAML;
use File::SOPS::Backend::Age;

# ----------------------------------------------------------------------------
# Regressions for four defects in the MAC, all of which produced files that
# File::SOPS was perfectly happy with -- three of them made File::SOPS reject
# its OWN output, and the fourth made it accept anything.
#
# Half of these are about reading a file this library did not write, so half
# the fixtures below are built by hand: a data key, values encrypted straight
# through File::SOPS::Encrypted, a digest computed here in the test, and the
# document text assembled in an order of the test's choosing. That is what
# lets these run with no sops binary. Nothing here shells out; t/04-interop.t
# is where the same ground is covered against the real thing.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();

# ----------------------------------------------------------------------------
# Fixture builder: a SOPS YAML document with the data keys in an order WE
# choose, so that "document order" can be made to differ from sorted order.
#
# Each leaf is [ $key, $kind, $payload ]:
#   enc   => [ $plaintext_bytes, $type ]   an ENC[...] value
#   plain => $yaml_scalar_text             written through as-is
#   hash  => [ leaf, leaf, ... ]           a nested mapping
#
# Returns the document text and the exact byte string the MAC covers, so the
# test states the expected digest input rather than re-deriving it from the
# code under test.
# ----------------------------------------------------------------------------

sub build_document {
    my (%args) = @_;
    my $leaves   = $args{leaves};
    my $data_key = $args{data_key};
    my %meta_args = %{ $args{metadata} // {} };

    my (@lines, @mac_bytes);

    my $emit;
    $emit = sub {
        my ($list, $path, $indent) = @_;
        for my $leaf (@$list) {
            my ($key, $kind, $payload) = @$leaf;
            my $pad = '    ' x $indent;

            if ($kind eq 'hash') {
                push @lines, "$pad$key:";
                $emit->($payload, [@$path, $key], $indent + 1);
                next;
            }

            if ($kind eq 'enc') {
                my ($plaintext, $type) = @$payload;
                my $enc = File::SOPS::Encrypted->encrypt_value(
                    value => $plaintext,
                    type  => $type,
                    key   => $data_key,
                    aad   => join(':', @$path, $key) . ':',
                );
                push @lines, "$pad$key: " . $enc->to_string;
                push @mac_bytes, [ [@$path, $key], $plaintext, 1 ];
                next;
            }

            push @lines, "$pad$key: $payload->[0]";
            push @mac_bytes, [ [@$path, $key], $payload->[1], 0 ];
        }
    };
    $emit->($leaves, [], 0);

    my $metadata = File::SOPS::Metadata->new(%meta_args);
    $metadata->lastmodified('2026-01-10T12:00:00Z');
    $metadata->age(
        File::SOPS::Backend::Age->encrypt_data_key(
            data_key => $data_key, recipients => [$public],
        )
    );

    # Only the values the MAC is defined to cover, in document order.
    my @covered = $metadata->mac_only_encrypted
        ? grep { $_->[2] } @mac_bytes
        : @mac_bytes;
    my $digest_input = join '', map { $_->[1] } @covered;

    my $ctx = Digest::SHA->new(512);
    $ctx->add($File::SOPS::MAC_ONLY_ENCRYPTED_INIT) if $metadata->mac_only_encrypted;
    $ctx->add($digest_input);

    $metadata->mac(
        File::SOPS::Encrypted->encrypt_value(
            value => uc($ctx->hexdigest),
            type  => 'str',
            key   => $data_key,
            aad   => $metadata->lastmodified,
        )->to_string
    );

    # Let the real serializer produce the sops block (so the fixture cannot
    # drift from the metadata format), then splice our own ordered data in.
    my $sops_block = File::SOPS::Format::YAML->serialize(
        data => {}, metadata => $metadata,
    );
    $sops_block =~ s/\A---\n//;

    return (join("\n", @lines) . "\n" . $sops_block, $digest_input);
}

sub decrypt_ok {
    my ($doc, $name) = @_;
    my $out = eval {
        File::SOPS->decrypt(encrypted => $doc, identities => [$secret], format => 'yaml')
    };
    is($@, '', $name) or diag("died: $@");
    return $out;
}

my $data_key = "\x02" x 32;

# ----------------------------------------------------------------------------
# k8 -- the decrypt side hashed a value that had been round-tripped through
# Perl's numeric conversion while the encrypt side hashed the live scalar.
#
# File::SOPS::Encrypted::_deserialize_value applies int() to type:int and
# + 0.0 to type:float. Neither is the identity on the text SOPS actually
# stores: '007' comes back as 7, '1.50' as 1.5, and the expanded
# 100000000000000000000 that Go writes for 1e20 restringifies as '1e+20'.
# Hashing a re-serialization of the converted value therefore digests
# different bytes than the producer did, and the file fails its own MAC.
#
# The fix is to hash what was authenticated -- Encrypted::decrypt_bytes --
# rather than a round trip through the type system.
# ----------------------------------------------------------------------------

subtest 'decrypt hashes the authenticated plaintext, not a re-serialization' => sub {
    # Values a producer can legitimately write that Perl's conversion mangles.
    # int/float are chosen so the type: field triggers the lossy conversion.
    my @cases = (
        [ '007',                   'int',   'zero-padded integer' ],
        [ '1.50',                  'float', 'trailing zero float' ],
        [ '-0.0',                  'float', 'negative zero' ],
        [ '100000000000000000000', 'float', "Go's expanded form of 1e20" ],
        [ '0.00000015',            'float', 'small float Perl would exponentiate' ],
        [ '1e+20',                 'float', 'exponent notation' ],
    );

    for my $case (@cases) {
        my ($plaintext, $type, $label) = @$case;

        my ($doc) = build_document(
            data_key => $data_key,
            leaves   => [ [ 'v', enc => [ $plaintext, $type ] ] ],
        );

        decrypt_ok($doc, "$label ($plaintext, type:$type) verifies");
    }
};

subtest 'lossy values survive a File::SOPS round trip' => sub {
    # Same defect reached through the public API: our own encrypt side hashes
    # the live scalar, so anything the decrypt side normalises differently
    # made the document reject itself.
    #
    # These are Perl STRINGS, so since k15 / ADR 0002 they are type:str
    # and are written verbatim -- there is no numeric normalisation left for
    # the two sides to disagree about, and the value that comes back is the
    # one that went in. That is the assertion; it used to be a weaker
    # `== $value`, which passed while '007' was silently returning 7.
    for my $value (qw( 007 1.50 -0.0 0.00000015 1e20 )) {
        my $encrypted = File::SOPS->encrypt(
            data       => { v => $value },
            recipients => [$public],
            format     => 'yaml',
        );
        like($encrypted, qr/^v: ENC\[[^\]]*type:str\]$/m,
            "the string '$value' is written as type:str");
        my $out = decrypt_ok($encrypted, "round trip of '$value' passes its own MAC");
        is($out->{v}, $value, "'$value' comes back as the string it was") if $out;
    }

    # And the numbers, which DO get normalised. Taken from a YAML parse rather
    # than written as Perl literals, because the point is a bare scalar whose
    # source spelling is not its canonical form: sops stores 007 as 7 and 1.50
    # as 1.5, and recomputes the MAC from that canonical form. Writing the
    # source spelling instead is what made `sops -d` refuse our files.
    my $numbers = YAML::XS::Load("a: 007\nb: 1.50\nc: 1e20\nd: 1.0\n");

    my $encrypted = File::SOPS->encrypt(
        data       => $numbers,
        recipients => [$public],
        format     => 'yaml',
    );
    like($encrypted, qr/^a: ENC\[[^\]]*type:int\]$/m,   'bare 007 is type:int');
    like($encrypted, qr/^b: ENC\[[^\]]*type:float\]$/m, 'bare 1.50 is type:float');

    my $out = decrypt_ok($encrypted, 'document of bare non-canonical numbers passes its own MAC');
    if ($out) {
        cmp_ok($out->{a}, '==', 7,    'bare 007 is the number 7');
        cmp_ok($out->{b}, '==', 1.5,  'bare 1.50 is the number 1.5');
        cmp_ok($out->{c}, '==', 1e20, 'bare 1e20 survives');
        cmp_ok($out->{d}, '==', 1,    'bare 1.0 survives');
    }
};

# ----------------------------------------------------------------------------
# k9 -- values excluded from encryption were hashed by the encrypt side and
# skipped by the decrypt side, because the decrypt side only ever saw ENC
# values. The Go implementation covers them on both sides unless
# mac_only_encrypted is set. Fires with zero configuration: unencrypted_suffix
# defaults to _unencrypted.
# ----------------------------------------------------------------------------

subtest 'unencrypted values are covered by the MAC on both sides' => sub {
    my $encrypted = File::SOPS->encrypt(
        data       => { cfg_unencrypted => 'notsecret', secret => 'shh' },
        recipients => [$public],
        format     => 'yaml',
    );

    like($encrypted, qr/^cfg_unencrypted: notsecret$/m,
        'the unencrypted key really is written in plaintext');

    my $out = decrypt_ok($encrypted, 'document with an unencrypted key passes its own MAC');
    is($out->{cfg_unencrypted}, 'notsecret', 'unencrypted value returned') if $out;
};

subtest 'unencrypted values are covered in a foreign document' => sub {
    # Deliberately NOT in sorted order: zz before blk_unencrypted before aa.
    # A sops-written file preserves the order of the original document, so
    # walking the parsed tree in sorted order is not good enough.
    my ($doc, $digest_input) = build_document(
        data_key => $data_key,
        leaves   => [
            [ zz => enc   => [ 'last', 'str' ] ],
            [ blk_unencrypted => hash => [
                [ b => plain => [ '1',   '1'   ] ],
                [ a => plain => [ 'two', 'two' ] ],
            ] ],
            [ aa => enc   => [ 'first', 'str' ] ],
        ],
    );

    is($digest_input, 'last1twofirst',
        'the MAC covers unencrypted values, interleaved in document order');

    my $out = decrypt_ok($doc, 'foreign document with an unencrypted branch verifies');
    is_deeply($out->{blk_unencrypted}, { b => 1, a => 'two' },
        'unencrypted branch returned intact') if $out;
};

subtest 'an unencrypted boolean is hashed titlecased' => sub {
    # SOPS's ToBytes titlecases booleans whether or not the value was
    # encrypted, so the plaintext `true` in the document contributes 'True'.
    my ($doc, $digest_input) = build_document(
        data_key => $data_key,
        leaves   => [
            [ flag_unencrypted => plain => [ 'true', 'True' ] ],
            [ s                => enc   => [ 'x', 'str' ] ],
        ],
    );

    is($digest_input, 'Truex', 'plaintext true contributes True, not 1 or true');
    decrypt_ok($doc, 'document with an unencrypted boolean verifies');
};

subtest 'document order is recovered, not assumed to be sorted' => sub {
    # If the decrypt side walked the parsed tree in sorted order this would
    # pass by accident for a sorted document, so make sorted order and
    # document order disagree in a way a wrong implementation cannot survive.
    my ($doc, $digest_input) = build_document(
        data_key => $data_key,
        leaves   => [
            [ zebra => enc => [ 'Z', 'str' ] ],
            [ apple => enc => [ 'A', 'str' ] ],
            [ mango => enc => [ 'M', 'str' ] ],
        ],
    );

    is($digest_input, 'ZAM', 'fixture is in document order, not sorted order');
    isnt($digest_input, 'AMZ', 'fixture would digest differently under sorted order');

    decrypt_ok($doc, 'foreign document with unsorted keys verifies');
};

subtest 'mac_only_encrypted is honoured' => sub {
    my ($doc, $digest_input) = build_document(
        data_key => $data_key,
        metadata => { mac_only_encrypted => 1 },
        leaves   => [
            [ zz              => enc   => [ 'last', 'str' ] ],
            [ cfg_unencrypted => plain => [ 'notsecret', 'notsecret' ] ],
            [ aa              => enc   => [ 'first', 'str' ] ],
        ],
    );

    is($digest_input, 'lastfirst',
        'with mac_only_encrypted the unencrypted value is left out');

    decrypt_ok($doc, 'foreign mac_only_encrypted document verifies');

    # And the same flag through the public API, in both directions.
    my $encrypted = File::SOPS->encrypt(
        data               => { cfg_unencrypted => 'notsecret', secret => 'shh' },
        recipients         => [$public],
        format             => 'yaml',
        mac_only_encrypted => 1,
    );
    like($encrypted, qr/^\s+mac_only_encrypted: true$/m,
        'mac_only_encrypted is recorded in the sops section');
    decrypt_ok($encrypted, 'self-produced mac_only_encrypted document verifies');
};

subtest 'mac_only_encrypted uses a distinct digest initialization' => sub {
    # sops seeds the digest with a fixed 32-byte block when the option is on,
    # so a MAC computed under one setting can never be accepted under the
    # other. Every value in this fixture is encrypted, so the "only encrypted"
    # filter selects exactly the same leaves either way: the initialization
    # block is the ONLY thing separating the two digests.
    my ($doc) = build_document(
        data_key => $data_key,
        metadata => { mac_only_encrypted => 1 },
        leaves   => [
            [ a => enc => [ 'AAA', 'str' ] ],
            [ b => enc => [ 'BBB', 'str' ] ],
        ],
    );

    decrypt_ok($doc, 'fixture verifies as the mac_only_encrypted document it is');

    # Strip the flag: same values, same order, same MAC ciphertext -- and it
    # must now be refused, because the digest was seeded differently.
    my $stripped = $doc;
    $stripped =~ s/^\s+mac_only_encrypted: true\n//m
        or die 'fixture did not carry mac_only_encrypted';

    my $out = eval {
        File::SOPS->decrypt(encrypted => $stripped, identities => [$secret], format => 'yaml')
    };
    ok(!defined $out, 'the same MAC is not accepted with the flag removed');
    like($@, qr/MAC verification failed/,
        'downgrading mac_only_encrypted is a MAC failure, not a silent pass');
};

# ----------------------------------------------------------------------------
# k10 -- the decrypt side used to scrape ENC values out of the raw text and
# skip the metadata MAC with an unanchored /mac:/ look-behind, so a user key
# called hmac or webmac was skipped as well: its value never reached the
# digest and every such document failed verification, with no workaround short
# of renaming the key.
#
# The guard is gone rather than anchored. The metadata MAC lives in the sops
# branch, and every path to the digest now drops that branch wholesale -- the
# format handlers already did, and the document-order reparse does the same --
# so there is nothing left for a "mac:" pattern to protect against.
# ----------------------------------------------------------------------------

subtest 'user keys ending in mac are not mistaken for the metadata MAC' => sub {
    for my $key (qw( mac hmac webmac signature_mac )) {
        my $encrypted = File::SOPS->encrypt(
            data       => { $key => 'value', other => 'x' },
            recipients => [$public],
            format     => 'yaml',
        );
        my $out = decrypt_ok($encrypted, "a data key named '$key' round-trips");
        is($out->{$key}, 'value', "'$key' value returned") if $out;
    }
};

subtest 'a data key named hmac is covered by the MAC in a foreign document' => sub {
    my ($doc, $digest_input) = build_document(
        data_key => $data_key,
        leaves   => [
            [ hmac   => enc => [ 'H', 'str' ] ],
            [ webmac => enc => [ 'W', 'str' ] ],
            [ other  => enc => [ 'O', 'str' ] ],
        ],
    );

    is($digest_input, 'HWO', 'hmac and webmac values are part of the digest');
    decrypt_ok($doc, 'foreign document with hmac/webmac keys verifies');
};

subtest 'the metadata MAC never hashes itself' => sub {
    # The positive half of the same story: whatever mechanism drops the
    # metadata MAC has to keep dropping it. If the sops branch leaked into
    # the walk, the MAC would be hashing its own ciphertext and nothing would
    # ever verify.
    my ($doc) = build_document(
        data_key => $data_key,
        leaves   => [ [ only => enc => [ 'value', 'str' ] ] ],
    );
    like($doc, qr/^\s+mac: ENC\[/m, 'fixture really does carry a metadata MAC');
    decrypt_ok($doc, 'the metadata MAC is excluded from the values it covers');
};

# ----------------------------------------------------------------------------
# k11 -- verification was conditional on the MAC being present AND parseable,
# so deleting the mac line, or corrupting it into anything the ENC regex
# rejects, silently turned verification off and handed back the data as though
# it had been checked. Go refuses in both cases unless --ignore-mac.
# ----------------------------------------------------------------------------

subtest 'a document that cannot be verified is refused' => sub {
    my $good = File::SOPS->encrypt(
        data       => { a => 'b' },
        recipients => [$public],
        format     => 'yaml',
    );

    my %broken = (
        'no mac line'      => sub { my $t = shift; $t =~ s/^\s+mac: ENC\[[^\]]*\]\n//m; $t },
        'unparsable mac'   => sub { my $t = shift; $t =~ s/mac: ENC\[[^\]]*\]/mac: NOT-AN-ENC-VALUE/; $t },
        'empty mac'        => sub { my $t = shift; $t =~ s/mac: ENC\[[^\]]*\]/mac: ""/; $t },
        'undecryptable mac' => sub {
            my $t = shift;
            # A syntactically perfect ENC value that will not open under this
            # data key: Go calls this "Cannot decrypt MAC" and stops.
            my $fake = File::SOPS::Encrypted->encrypt_value(
                value => 'DEADBEEF', type => 'str', key => "\x09" x 32, aad => 'x',
            )->to_string;
            $t =~ s/mac: ENC\[[^\]]*\]/mac: $fake/;
            $t;
        },
        'lastmodified changed' => sub {
            # lastmodified is the MAC's AAD, so moving it must invalidate the
            # MAC rather than being silently tolerated.
            my $t = shift;
            $t =~ s/lastmodified: "[^"]*"/lastmodified: "2000-01-01T00:00:00Z"/;
            $t;
        },
    );

    for my $case (sort keys %broken) {
        my $doc = $broken{$case}->($good);

        my $out = eval {
            File::SOPS->decrypt(encrypted => $doc, identities => [$secret], format => 'yaml')
        };
        ok(!defined $out, "[$case] decrypt does not return data");
        like($@, qr/MAC/i, "[$case] decrypt dies with a MAC error")
            or diag("got: " . ($@ || '(no error)'));

        # ...and the documented escape hatch still gets the data out.
        my $forced = eval {
            File::SOPS->decrypt(
                encrypted  => $doc,
                identities => [$secret],
                format     => 'yaml',
                ignore_mac => 1,
            )
        };
        is($@, '', "[$case] ignore_mac => 1 decrypts anyway");
        is($forced->{a}, 'b', "[$case] ignore_mac => 1 returns the data") if $forced;
    }
};

subtest 'a tampered value is still caught' => sub {
    # The point of all of the above. Swap two encrypted values between keys:
    # each one still authenticates against its own AAD only if it stays put,
    # and the MAC is what notices reordering and substitution.
    my ($doc) = build_document(
        data_key => $data_key,
        leaves   => [
            [ a => enc => [ 'AAA', 'str' ] ],
            [ b => enc => [ 'BBB', 'str' ] ],
        ],
    );

    decrypt_ok($doc, 'baseline document verifies');

    # Replace b's ciphertext with a fresh encryption of a different plaintext
    # under b's own AAD -- individually valid, but not what was MACed.
    my $forged = File::SOPS::Encrypted->encrypt_value(
        value => 'FORGED', type => 'str', key => $data_key, aad => 'b:',
    )->to_string;
    my $tampered = $doc;
    $tampered =~ s/^b: ENC\[[^\]]*\]$/b: $forged/m;

    my $out = eval {
        File::SOPS->decrypt(encrypted => $tampered, identities => [$secret], format => 'yaml')
    };
    ok(!defined $out, 'a substituted value is rejected');
    like($@, qr/MAC verification failed/, 'and it is the MAC that rejects it');
};

# ----------------------------------------------------------------------------
# Cross-cutting: JSON goes down the same code path, including the
# document-order reparse, which has to handle JSON as well as YAML.
# ----------------------------------------------------------------------------

subtest 'the same rules hold for JSON' => sub {
    my $encrypted = File::SOPS->encrypt(
        data => {
            cfg_unencrypted => 'notsecret',
            hmac            => 'h',
            padded          => '007',
            nested          => { zz => 'last', aa => 'first' },
        },
        recipients => [$public],
        format     => 'json',
    );

    my $out = decrypt_ok($encrypted, 'JSON document with all four hazards verifies');
    return unless $out;

    is($out->{cfg_unencrypted}, 'notsecret', 'unencrypted value returned');
    is($out->{hmac},            'h',         'hmac key returned');
    is($out->{nested}{zz},      'last',      'nested value returned');
    is($out->{padded},          '007',       'zero-padded string returned verbatim');
};

done_testing;
