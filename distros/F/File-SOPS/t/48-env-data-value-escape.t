#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Digest::SHA qw(sha512_hex);
use JSON::MaybeXS qw(decode_json);
use YAML::XS ();

use File::SOPS::Metadata;
use File::SOPS::Metadata::Flat;
use File::SOPS::Backend::Age;
use File::SOPS::Encrypted;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k109 / docs/adr/0030 -- the ENV store applies the flat metadata
# encoding's newline escape to DATA values too, and the escape is not
# injective: a real newline and the two characters backslash-`n` are written
# as the same bytes, and both read back as a newline.
#
# That matters here and not in the format lane because the MAC covers the
# plaintext of every value, encrypted or not. The measurement this file pins
# is which side of the escape the digest sits on, and what the reference
# implementation does with a value the escape cannot carry.
#
# Two halves, proving different things:
#
#   * The UNIT half pins our escape against the bytes measured off sops for a
#     DATA value, and pins the round-trip predicate ADR 0030 makes the guard
#     out of. No binary needed.
#   * The INTEROP half is the only half that proves anything about sops: that
#     it writes the two documents identically, that its MAC covers the
#     PRE-escape bytes, and that it then refuses to read back one of the two
#     files it just wrote. ADR 0030 decides to refuse that value on the
#     strength of exactly that; if sops ever stops doing it, this goes red and
#     the decision wants re-reading rather than quietly aging.
#
# There is no ENV format handler yet (k36), so nothing here exercises a
# writer of ours. What it exercises is File::SOPS::Metadata::Flat against a
# real sops-written .env file, which t/38 does not do -- t/38 uses a captured
# layout and a document we wrote ourselves.

# value => [ bytes the ENV store writes, does the escape round-trip it ]
#
# Measured one document per row against sops 3.13.3, value in an unencrypted
# slot, read back with `sops -d --output-type json`. The right-hand column is
# exactly the exit code: round-trips => exit 0, does not => MAC mismatch,
# exit 51.
my @CASES = (
    [ 'real newline'          => "a\nb",       "a\\nb",     1 ],
    [ 'two real newlines'     => "a\n\nb",     "a\\n\\nb",  1 ],
    [ 'literal backslash-n'   => "a\\nb",      "a\\nb",     0 ],
    [ 'literal backslash x2'  => "a\\\\nb",    "a\\\\nb",   0 ],
    [ 'literal backslash-t'   => "a\\tb",      "a\\tb",     1 ],
    [ 'a lone backslash'      => "a\\b",       "a\\b",      1 ],
    [ 'a tab'                 => "a\tb",       "a\tb",      1 ],
    [ 'a carriage return'     => "a\rb",       "a\rb",      1 ],
    [ 'an equals sign'        => 'a=b',        'a=b',       1 ],
    [ 'a hash'                => 'a#b',        'a#b',       1 ],
    [ 'a dollar'              => 'a$b',        'a$b',       1 ],
    [ 'a double quote'        => 'a"b',        'a"b',       1 ],
    [ 'a single quote'        => "a'b",        "a'b",       1 ],
    [ 'a leading space'       => ' ab',        ' ab',       1 ],
    [ 'a trailing space'      => 'ab ',        'ab ',       1 ],
    [ 'the empty string'      => '',           '',          1 ],
);

###############################################################################
# Unit -- our escape against the bytes sops writes for a DATA value
###############################################################################
subtest 'escape_value reproduces the ENV store on data values, not just metadata' => sub {
    # prefix is irrelevant for the escape itself; a data value carries none.
    my $flat = File::SOPS::Metadata::Flat->new(prefix => 'sops_');

    for my $case (@CASES) {
        my ($name, $value, $written, $lossless) = @$case;
        is $flat->escape_value($value), $written,
            "$name: written as sops writes it";
    }

    # The read side, on the bytes sops actually put in the file.
    is $flat->unescape_value("a\\nb"),   "a\nb",
        'backslash-n comes back as a newline';
    is $flat->unescape_value("a\\\\nb"), "a\\\nb",
        'a preceding backslash does not protect it -- backslash, then newline';
    is $flat->unescape_value("a\\tb"),   "a\\tb",
        'backslash-t is left alone';
};

subtest 'the round-trip predicate ADR 0030 makes the guard out of' => sub {
    my $flat = File::SOPS::Metadata::Flat->new(prefix => 'sops_');

    # The guard asks the escape whether it is the identity on these bytes,
    # rather than testing for a character. A second spelling of the rule is
    # how a guard and the transform it guards drift apart.
    my $survives = sub {
        my ($bytes) = @_;
        return $flat->unescape_value($flat->escape_value($bytes)) eq $bytes ? 1 : 0;
    };

    for my $case (@CASES) {
        my ($name, $value, undef, $lossless) = @$case;
        is $survives->($value), $lossless,
            "$name: the escape " . ($lossless ? 'round-trips it' : 'does NOT round-trip it');
    }

    # An encrypted leaf never reaches the guard's failing side: the ENC string
    # alphabet is base64 plus []:,= and holds neither a backslash nor a
    # newline. Stated here so the unit half carries the reason the interop
    # half measures.
    my $enc = 'ENC[AES256_GCM,data:4ZmhhMuDkYQaV14=,'
            . 'iv:xo7k6vNgQNLK0yQME+VZXyW1rVY1hThErN6qtk5fljg=,'
            . 'tag:JaWjMjrSs5DEdZVCsUeJRQ==,type:str]';
    is $survives->($enc), 1, 'an ENC[...] string is untouched by the escape';
};

###############################################################################
# Interop -- the only half that proves anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the ENV data-value escape was NOT measured against "
       . "sops, so ADR 0030's premise went unchecked. Run maint/fetch-sops "
       . "or set SOPS_BIN.", 3
        unless $sops_bin;

    require Crypt::Age;
    diag("Using sops binary: $sops_bin");

    my $dir = tempdir(CLEANUP => 1);
    my ($pub, $sec) = Crypt::Age->generate_keypair();
    write_bytes("$dir/key.txt", $sec);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    ###########################################################################
    subtest 'the digest covers the value BEFORE the escape' => sub {
        # Two documents whose bodies sops writes identically, because the
        # escape maps both values onto the same bytes.
        my $real    = "line1\nline2";
        my $literal = "line1\\nline2";

        my $a = encrypt_env($sops_bin, $dir, 'A', $pub, $real);
        my $b = encrypt_env($sops_bin, $dir, 'B', $pub, $literal);

        is data_line($a), data_line($b),
            'sops writes both values as the same bytes -- the escape is lossy '
          . 'on data values, not only on metadata';
        is data_line($a), 'plain_unencrypted=line1\\nline2',
            'and the bytes are the escaped form';

        # The mac is read through this distribution's own modules, which is
        # also the only place Metadata::Flat meets a real sops .env file.
        for my $probe ([ A => $a, $real ], [ B => $b, $literal ]) {
            my ($label, $text, $value) = @$probe;
            my $expected = uc sha512_hex(
                File::SOPS::Encrypted->value_to_bytes($value)
            );
            is mac_plaintext($text, $sec), $expected,
                "$label: sops_mac covers SHA-512 of the PRE-escape bytes";
        }
    };

    ###########################################################################
    subtest 'sops writes a document it then refuses to read' => sub {
        my $real    = "line1\nline2";
        my $literal = "line1\\nline2";

        my $a_path = "$dir/A.env";
        my $b_path = "$dir/B.env";
        write_bytes($a_path, encrypt_env($sops_bin, $dir, 'A2', $pub, $real));
        write_bytes($b_path, encrypt_env($sops_bin, $dir, 'B2', $pub, $literal));

        my ($a_out, $a_exit) = decrypt_env($sops_bin, $a_path);
        is $a_exit, 0, 'the real-newline document reads back';
        is decode_json($a_out)->{plain_unencrypted}, $real,
            'as the newline it went in as';

        my ($b_out, $b_exit) = decrypt_env($sops_bin, $b_path);
        is $b_exit, 51,
            'the backslash-n document fails its own MAC -- sops wrote it with '
          . 'exit 0 and cannot read it';
        like $b_out, qr/MAC mismatch/, 'and says so';

        # This is the whole basis for ADR 0030 refusing the value: what comes
        # back with the check switched off is not what went in.
        my ($ig_out, $ig_exit) = decrypt_env($sops_bin, $b_path, '--ignore-mac');
        is $ig_exit, 0, 'with --ignore-mac it reads';
        is decode_json($ig_out)->{plain_unencrypted}, $real,
            'and the literal backslash-n has silently become a newline';
    };

    ###########################################################################
    subtest 'the sweep, and the encrypted slot that is immune to it' => sub {
        for my $case (@CASES) {
            my ($name, $value, $written, $lossless) = @$case;

            my $tag  = $name; $tag =~ s/\W+/_/g;
            my $text = encrypt_env($sops_bin, $dir, "sw_$tag", $pub, $value);
            my $path = "$dir/sw_$tag.env";
            write_bytes($path, $text);

            is data_line($text), "plain_unencrypted=$written",
                "$name: sops wrote the bytes our escape_value produces";

            my (undef, $exit) = decrypt_env($sops_bin, $path);
            is $exit, ($lossless ? 0 : 51),
                "$name: sops " . ($lossless ? 'reads its own file' : 'refuses its own file');
        }

        # An encrypted slot carries base64, which the escape cannot touch.
        for my $probe ([ 'real newline' => "line1\nline2" ],
                       [ 'literal backslash-n' => "line1\\nline2" ]) {
            my ($name, $value) = @$probe;
            my $tag  = $name; $tag =~ s/\W+/_/g;
            my $text = encrypt_env($sops_bin, $dir, "enc_$tag", $pub, $value,
                                   key => 'secret');
            my $path = "$dir/enc_$tag.env";
            write_bytes($path, $text);

            my ($line) = $text =~ /^(secret=.*)$/m;
            unlike $line, qr/\\/,
                "$name: the ENC[...] line holds no backslash for the escape to find";

            my ($out, $exit) = decrypt_env($sops_bin, $path);
            is $exit, 0, "$name: an encrypted slot round-trips";
            is decode_json($out)->{secret}, $value,
                "$name: byte for byte, escape or no escape";
        }
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

sub write_bytes {
    my ($path, $bytes) = @_;
    open my $fh, '>:raw', $path or die "open $path: $!";
    print $fh $bytes;
    close $fh or die "close $path: $!";
    return;
}

sub read_bytes {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "open $path: $!";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    return $bytes;
}

# A YAML source is the only way to hand sops an exact value: the env store's
# own reader performs the same unescape, so a plaintext .env cannot express a
# literal backslash-n either (ADR 0030).
sub encrypt_env {
    my ($sops_bin, $dir, $tag, $pub, $value, %opt) = @_;
    my $key = $opt{key} // 'plain_unencrypted';

    my $quoted = $value;
    $quoted =~ s/\\/\\\\/g;
    $quoted =~ s/"/\\"/g;
    $quoted =~ s/\n/\\n/g;
    $quoted =~ s/\r/\\r/g;
    $quoted =~ s/\t/\\t/g;

    my $src = "$dir/$tag.yaml";
    write_bytes($src, qq{$key: "$quoted"\n});

    # The fixture has to mean what we think it means before sops sees it.
    my $parsed = YAML::XS::LoadFile($src)->{$key};
    die "the YAML fixture for '$tag' does not hold the intended value"
        unless $parsed eq $value;

    my $out = `$sops_bin -e --age '$pub' --input-type yaml --output-type dotenv '$src' 2>&1`;
    die "sops -e failed for '$tag': $out" if $? != 0;
    return $out;
}

sub decrypt_env {
    my ($sops_bin, $path, @flags) = @_;
    my $out = `$sops_bin -d @flags --input-type dotenv --output-type json '$path' 2>&1`;
    return ($out, $? >> 8);
}

sub data_line {
    my ($text) = @_;
    my ($line) = $text =~ /^(plain_unencrypted=.*)$/m;
    return defined $line ? $line : '(no data line)';
}

# Metadata::Flat -> Metadata -> Backend::Age -> Encrypted, on a .env file sops
# wrote. Returns the uppercase hex SHA-512 the document claims for itself.
sub mac_plaintext {
    my ($text, $identity) = @_;

    my %lines;
    for my $line (split /\n/, $text) {
        next unless length $line;
        my ($k, $v) = split /=/, $line, 2;
        $lines{$k} = $v;
    }

    my $flat    = File::SOPS::Metadata::Flat->new(prefix => 'sops_');
    my $meta    = File::SOPS::Metadata->from_hash($flat->unflatten(\%lines));
    my $key     = File::SOPS::Backend::Age->decrypt_data_key(
        age_keys   => [ $meta->get_age_encrypted_keys ],
        identities => [ $identity ],
    );

    return File::SOPS::Encrypted->parse($meta->mac)
        ->decrypt_bytes(key => $key, aad => $meta->lastmodified // '');
}
