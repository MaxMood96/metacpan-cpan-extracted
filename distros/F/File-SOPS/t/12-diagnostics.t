#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Test::More;

use File::SOPS;
use File::SOPS::Encrypted;
use File::SOPS::Metadata;
use File::SOPS::Format::YAML;
use JSON::MaybeXS;
use Crypt::Age;
use Scalar::Util qw(dualvar);
use YAML::XS qw(Load);

# ----------------------------------------------------------------------------
# Failures have to say WHERE and WHY (k19).
#
# The MAC path swallowed everything it could not place, parse or decrypt, so a
# document with one bad leaf out of a hundred produced exactly one line --
# "MAC verification failed" -- with nothing to act on. That is what made every
# other MAC defect in this distribution expensive to find.
#
# Two silent passes on the read side belong to the same family:
#
#   * an unknown `type:` field fell through to the string branch and returned
#     the raw plaintext, where Go stops with "Unknown datatype: %s";
#   * MIME::Base64::decode_base64 ignores characters outside the alphabet, so a
#     corrupted ENC value decoded to something shorter and failed later as an
#     authentication error, where Go's base64.StdEncoding fails immediately.
#
# Two types Go emits that our ladder did not know are added rather than
# rejected, because both are real and both already worked by accident:
#
#   type:time    -- a bare RFC3339 scalar or date; plaintext is RFC3339,
#                   measured: `2026-08-09` is stored as `2026-08-09T00:00:00Z`
#   type:comment -- a YAML comment, written as `#ENC[...]` on its own line
#
# Rejecting those would have broken reading any sops file with a timestamp in
# it, which verifies here today.
#
# NOTHING in an error message may carry a plaintext value, a data key or an age
# identity. The key path is fair game -- a SOPS document leaves its keys
# readable by design -- and it is the only thing that makes a message useful.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();
my $KEY = "\3" x 32;

# ----------------------------------------------------------------------------
# 1. Types Go emits that we must read, not reject.
# ----------------------------------------------------------------------------

{
    my $ts = '2026-08-09T12:00:00Z';
    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => $ts, key => $KEY, aad => 'ts:', type => 'time',
    );
    is($enc->type, 'time', 'type:time survives a round trip through the object');
    is($enc->decrypt_value(key => $KEY, aad => 'ts:'), $ts,
        'a type:time value decrypts to its RFC3339 text');
    is($enc->decrypt_bytes(key => $KEY, aad => 'ts:'), $ts,
        'and the digest input is the same bytes');

    # FLIPPED for k76 / docs/adr/0041: this asserted that a type:comment
    # value decrypts to its TEXT. It decrypts to a File::SOPS::Comment now,
    # because a comment is not a value and a string here is an element of the
    # document that the file does not contain (k108). The text is still
    # exactly what it was, and decrypt_bytes -- what the digest would see, if
    # the digest covered a comment -- is unchanged.
    my $c = File::SOPS::Encrypted->encrypt_value(
        value => ' a comment', key => $KEY, aad => '', type => 'comment',
    );
    my $comment = $c->decrypt_value(key => $KEY, aad => '');
    isa_ok($comment, 'File::SOPS::Comment',
        'a type:comment value decrypts to a comment leaf');
    is($comment->text, ' a comment', 'carrying its text');
    is($c->decrypt_bytes(key => $KEY, aad => ''), ' a comment',
        'and the wire plaintext is that text');
}

# ----------------------------------------------------------------------------
# 2. An unknown type is refused, the way Go refuses it.
# ----------------------------------------------------------------------------

{
    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => 'whatever', key => $KEY, aad => 'v:', type => 'quaternion',
    );

    my $err = do {
        local $@;
        eval { $enc->decrypt_value(key => $KEY, aad => 'v:') };
        $@;
    };
    like($err, qr/unknown datatype/i, 'an unknown type: field is refused');
    like($err, qr/quaternion/, 'and the message names the type');
    unlike($err, qr/whatever/, 'and never the plaintext');

    # The plaintext is still reachable, so nothing is lost.
    is($enc->decrypt_bytes(key => $KEY, aad => 'v:'), 'whatever',
        'decrypt_bytes still returns the authenticated plaintext');
}

# ----------------------------------------------------------------------------
# 3. Base64 that Go's decoder would reject is refused here too.
# ----------------------------------------------------------------------------

{
    my $good = File::SOPS::Encrypted->encrypt_value(
        value => 'value', key => $KEY, aad => 'v:',
    )->to_string;

    ok(File::SOPS::Encrypted->parse($good), 'a well-formed value still parses');

    # A character outside the base64 alphabet. decode_base64 drops it silently,
    # so this used to decode to a SHORTER string and surface much later as
    # "Authentication failed - data may be corrupted".
    (my $bad_data = $good) =~ s/data:([^,]+),/data:$1!,/;
    my $err = do { local $@; eval { File::SOPS::Encrypted->parse($bad_data) }; $@ };
    like($err, qr/base64/i, 'an invalid character in data: is refused at parse time');
    like($err, qr/\bdata\b/, 'and the message says which field');

    (my $bad_iv = $good) =~ s/iv:([^,]+),/iv:\@$1,/;
    $err = do { local $@; eval { File::SOPS::Encrypted->parse($bad_iv) }; $@ };
    like($err, qr/base64/i, 'an invalid character in iv: is refused too');

    # Wrong length is the other half: base64 comes in groups of four.
    (my $bad_len = $good) =~ s/tag:([^,]+),/tag:AAAAA,/;
    $err = do { local $@; eval { File::SOPS::Encrypted->parse($bad_len) }; $@ };
    like($err, qr/base64/i, 'and so is a truncated group');

    # is_encrypted stays a pure predicate on the SHAPE -- it must not start
    # dying, because it is what decides whether a value is a candidate at all.
    ok(File::SOPS::Encrypted->is_encrypted($bad_data),
        'is_encrypted still answers about the shape without dying');
}

# ----------------------------------------------------------------------------
# 4. A value that will not decrypt names the path it is at.
# ----------------------------------------------------------------------------

{
    my $encrypted = File::SOPS->encrypt(
        data       => { database => { password => 'secret-value' }, other => 'o' },
        recipients => [$public],
        format     => 'yaml',
    );

    # Move the ciphertext to a different key: the AAD no longer matches, so it
    # authenticates against nothing. This is the substitution the AAD exists to
    # catch, and it used to surface as a bare "Authentication failed".
    my ($enc_string) = $encrypted =~ /^\s+password: (ENC\[[^\]]+\])$/m;
    ok($enc_string, 'found the encrypted value to move');

    (my $tampered = $encrypted) =~ s/^other: ENC\[[^\]]+\]$/other: $enc_string/m;
    isnt($tampered, $encrypted, 'and moved it');

    my $err = do {
        local $@;
        eval {
            File::SOPS->decrypt(
                encrypted => $tampered, identities => [$secret], format => 'yaml',
            );
        };
        $@;
    };
    like($err, qr/\bother\b/, 'the error names the key the bad value sits under');
    unlike($err, qr/secret-value/, 'and does not contain the plaintext');
    unlike($err, qr/AGE-SECRET-KEY/, 'and no age identity');
}

# ----------------------------------------------------------------------------
# 5. A MAC failure says what was checked, not just that it failed.
# ----------------------------------------------------------------------------

{
    my $encrypted = File::SOPS->encrypt(
        data       => { a_unencrypted => 'plain', secret => 'shh' },
        recipients => [$public],
        format     => 'yaml',
    );

    # Change an unencrypted value: every individual value still authenticates,
    # so only the MAC can catch this. That is exactly the case where the old
    # message told you nothing.
    (my $tampered = $encrypted) =~ s/^a_unencrypted: plain$/a_unencrypted: other/m;
    isnt($tampered, $encrypted, 'tampered with an unencrypted value');

    my $err = do {
        local $@;
        eval {
            File::SOPS->decrypt(
                encrypted => $tampered, identities => [$secret], format => 'yaml',
            );
        };
        $@;
    };
    like($err, qr/MAC verification failed/, 'still says the MAC failed');
    like($err, qr/\bleaves\b|\bleaf\b/i, 'and how much was covered');
    like($err, qr/ignore_mac/, 'and how to read it anyway');
    unlike($err, qr/\bshh\b/, 'and never the plaintext of a value');
    unlike($err, qr/AGE-SECRET-KEY/, 'and no age identity');
}

# ----------------------------------------------------------------------------
# 6. A structural disagreement between the document and the parsed tree is
#    reported, not silently dropped from the digest.
#
#    _document_leaves takes key ORDER from an order-preserving reparse and
#    VALUES from the tree the rest of the library uses. When the two disagree it
#    returned the leaves it had so far -- so the digest quietly covered part of
#    the document, and the only symptom was a MAC failure.
# ----------------------------------------------------------------------------

{
    my $encrypted = File::SOPS->encrypt(
        data       => { branch => { a => 'x', b => 'y' }, top => 'z' },
        recipients => [$public],
        format     => 'yaml',
    );

    # Replace a mapping with a scalar in the raw text only. Both parsers see the
    # same thing here, so this is a self-check of the reporting path rather than
    # of a real parser divergence -- it makes the digest cover fewer leaves.
    (my $tampered = $encrypted) =~ s/^branch:\n(?:  .*\n)+/branch: flattened\n/m;
    isnt($tampered, $encrypted, 'flattened a branch');

    my $err = do {
        local $@;
        eval {
            File::SOPS->decrypt(
                encrypted => $tampered, identities => [$secret], format => 'yaml',
            );
        };
        $@;
    };
    ok($err, 'a flattened branch is an error');
    unlike($err, qr/\bx\b.*\bENC\b|type:str.*type:str/, 'without dumping the document');
}

# ...and a blessed scalar is NOT a structural disagreement. The format parsers
# return a JSON::PP::Boolean for a bare true/false while the order-preserving
# reparse returns a plain scalar for the same node, so the two differ in the
# boolean's REPRESENTATION at every unencrypted boolean in every document. The
# reparse supplies order and nothing else, so that is not a disagreement about
# the document -- treating any ref as one rejects a document File::SOPS wrote
# itself, with the default settings.
{
    for my $format (qw(yaml json)) {
        my $encrypted = File::SOPS->encrypt(
            data       => {
                flag_unencrypted  => JSON->true,
                off_unencrypted   => JSON->false,
                block_unencrypted => { nested => JSON->true },
                secret            => 'shh',
            },
            recipients => [$public],
            format     => $format,
        );

        my $back = eval {
            File::SOPS->decrypt(
                encrypted => $encrypted, identities => [$secret], format => $format,
            );
        };
        is($@, '', "[$format] a document with unencrypted booleans verifies")
            or diag("died: $@");
        isa_ok($back->{flag_unencrypted}, 'JSON::PP::Boolean',
            "[$format] the unencrypted boolean") if $back;
        ok(!$back->{off_unencrypted}, "[$format] and a false one is still false")
            if $back;
    }
}

# ----------------------------------------------------------------------------
# 7. The encrypt side names the path too.
# ----------------------------------------------------------------------------

{
    my $err = do {
        local $@;
        eval {
            File::SOPS->encrypt(
                data       => { outer => { inner => 12345678901234567890 } },
                recipients => [$public],
                format     => 'yaml',
            );
        };
        $@;
    };
    like($err, qr/outer:inner/, 'an unwritable value is reported at its path');
    unlike($err, qr/12345678901234567890/, 'without echoing the value');
}

# ----------------------------------------------------------------------------
# 8. Non-ASCII keys survive the path formatting.
# ----------------------------------------------------------------------------

{
    my $err = do {
        local $@;
        eval {
            File::SOPS->encrypt(
                data       => { "caf\x{e9}" => { "\x{f6}ffentlich" => 12345678901234567890 } },
                recipients => [$public],
                format     => 'yaml',
            );
        };
        $@;
    };
    like($err, qr/caf\x{e9}:\x{f6}ffentlich/, 'a non-ASCII path is reported as characters');
}

# ----------------------------------------------------------------------------
# 9. A refusal is reported at the CALLER's line, not at ours (k71).
#
# croak names the caller of the frame it stands in, and between a caller and
# these guards every frame is this distribution's own: File::SOPS::encrypt
# calls emit(), emit() calls Encrypted->canonical_float_tree, and the walk
# calls the handler's guards BACK. So the message ended "at
# lib/File/SOPS/Encrypted.pm line NNN" -- the walk's own recursion -- which is
# exactly what the house rule "croak, never die; errors report the caller's
# line, not ours" exists to prevent. It is fixed with @CARP_NOT in the two
# handlers and in the age backend, and Carp skips a frame when EITHER side
# trusts the other, so the same list also covers the guard that croaks from
# inside the walk.
#
# Asserted here because nothing else can see it: the frames are invisible to
# every other test in this suite, and a later refactor that moves a guard into
# a new frame would put the library's own line back with no test going red.
#
# Measured over 32 refusal paths: 9 locations move, all of them out of lib/,
# and NOT ONE message text changes -- the path prefixes k68 added are
# untouched, which the last subtest asserts alongside the location.
# ----------------------------------------------------------------------------

{
    my $file = __FILE__;
    my $dualvar = dualvar(5, 'five');
    my $blessed = bless {}, 'Foo';
    my $sealed  = File::SOPS->encrypt(
        data => { a => 1 }, recipients => [$public], format => 'yaml',
    );

    my @cases;
    my ($err, $line);

    eval { $line = __LINE__; File::SOPS::Format::YAML->emit({ a => $blessed }) };
    push @cases, [ 'YAML emit, blessed leaf', $@, $line ];

    eval { $line = __LINE__; File::SOPS::Format::JSON->emit({ a => $blessed }) };
    push @cases, [ 'JSON emit, blessed leaf', $@, $line ];

    eval { $line = __LINE__; File::SOPS::Format::JSON->emit({ a => \1 }) };
    push @cases, [ 'JSON emit, unblessed ref', $@, $line ];

    eval { $line = __LINE__; File::SOPS::Format::YAML->emit({ a => $dualvar }) };
    push @cases, [ 'YAML emit, int-half guard (croaks inside the walk)', $@, $line ];

    eval { $line = __LINE__; File::SOPS::Format::JSON->emit({ a => $dualvar }) };
    push @cases, [ 'JSON emit, int-half guard (croaks inside the walk)', $@, $line ];

    eval { $line = __LINE__; File::SOPS->encrypt(data => { a_unencrypted => $blessed }, recipients => [$public], format => 'yaml') };
    push @cases, [ 'encrypt(), blessed leaf', $@, $line ];

    eval { $line = __LINE__; File::SOPS->encrypt(data => Load("a_unencrypted: 0x1f\n"), recipients => [$public], format => 'yaml') };
    push @cases, [ 'encrypt(), foreign-resolution guard', $@, $line ];

    eval { $line = __LINE__; File::SOPS->decrypt(encrypted => $sealed, identities => []) };
    push @cases, [ 'decrypt(), no usable identity (age backend)', $@, $line ];

    for my $case (@cases) {
        my ($label, $error, $at) = @$case;
        ok($error, "[$label] refuses") or next;
        like($error, qr/\Qat $file line $at\E\b/,
            "[$label] and reports the caller's own line");
        unlike($error, qr{at \S*lib/File/SOPS\S*\.pm line},
            "[$label] and names no file of ours");
    }
}

# And the location is not bought with the key path k68 added: both have
# to be in the same message.
{
    my $err = do {
        local $@;
        eval {
            File::SOPS::Format::YAML->emit({ outer => { inner => bless({}, 'Foo') } });
        };
        $@;
    };
    like($err, qr/^outer:inner: cannot write a leaf blessed into Foo/,
        'the message still opens with the key path');
    like($err, qr/at \Q@{[ __FILE__ ]}\E line \d+/,
        'and still ends at the caller');
}

done_testing;
