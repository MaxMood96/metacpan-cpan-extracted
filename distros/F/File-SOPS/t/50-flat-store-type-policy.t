#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Digest::SHA qw(sha512_hex);
use JSON::MaybeXS;

use File::SOPS::Metadata;
use File::SOPS::Metadata::Flat;
use File::SOPS::Backend::Age;
use File::SOPS::Encrypted;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k77 / docs/adr/0035 -- the per-format type policy for the two untyped
# stores, ENV and INI, and with it k124 (an unencrypted boolean) and
# k125 (an unencrypted null).
#
# The ticket's premise was that the env store writes type:str for everything,
# `NUM=5` included, so our scalar-derived type (ADR 0002) would produce a
# document the store never writes. Measured against sops 3.13.3, that is the
# INPUT store speaking: `sops -e` on a plaintext .env types everything str
# because its reader returned strings, while the same tree from a YAML source
# written OUT as dotenv or ini carries type:int, type:float, type:bool and
# type:time and reads back at exit 0.
#
# What is really broken is one rung lower. An unencrypted slot carries no type
# label at all, so the untyped reader hands the digest the literal text of the
# line -- and sops writes a DISPLAY form there while its own MAC covers the
# WIRE form. Three classes, all of them files sops writes with exit 0 and then
# refuses to read:
#
#     a boolean            written `true`,  digest covers `True`
#     a null               written `<nil>`, digest covers the empty string
#     an integral or       written `1.0` / `1E+20` / `-0.0`,
#     exponent-range float digest covers `1` / `100000000000000000000` / `-0`
#
# The third was in no ticket. ADR 0035 decides that our emitter writes exactly
# `Encrypted->value_to_bytes` in an unencrypted ENV or INI slot -- the bytes
# the digest already covers -- and refuses nothing for its type.
#
# Two halves, proving different things:
#
#   * The UNIT half pins that value_to_bytes produces the digest column of the
#     measured table, for every type. That is the half that goes red if anyone
#     ever teaches the ladder a format. No binary needed.
#   * The INTEROP half is the only half that proves anything about sops: which
#     label it writes in each slot, that its MAC covers value_to_bytes on every
#     row, which rows it then cannot read, and that the bytes ADR 0035 writes
#     instead are bytes sops itself writes and reads at exit 0.
#
# There is no ENV or INI format handler (k36, k37), so nothing here
# exercises a writer of ours.

# label, YAML spelling, the bytes the digest covers, does sops's own
# unencrypted slot round-trip -- ENV and INI measured identical on every row.
my @LADDER = (
    [ 'str hello'   => '"hello"',                'hello',                  'str',   1 ],
    [ 'str empty'   => '""',                     '',                       undef,   1 ],
    [ 'int 42'      => '42',                     '42',                     'int',   1 ],
    [ 'int 007'     => '007',                    '7',                      'int',   1 ],
    [ 'float 1.50'  => '1.50',                   '1.5',                    'float', 1 ],
    [ 'float 1.0'   => '1.0',                    '1',                      'float', 0 ],
    [ 'float 1e20'  => '1e20',                   '100000000000000000000',  'float', 0 ],
    [ 'float -0.0'  => '-0.0',                   '-0',                     'float', 0 ],
    [ 'bool true'   => 'true',                   'True',                   'bool',  0 ],
    [ 'bool false'  => 'false',                  'False',                  'bool',  0 ],
    [ 'null'        => 'null',                   '',                       undef,   0 ],
    [ 'time'        => '2026-01-01T00:00:00Z',   '2026-01-01T00:00:00Z',   'time',  1 ],
);

###############################################################################
# Unit -- the digest column of that table is value_to_bytes, with no format in
# sight
###############################################################################
subtest 'value_to_bytes produces the bytes sops digests, for every type' => sub {
    # The Perl value on the left is the one a parser -- or a caller -- hands
    # the walk for the YAML spelling in @LADDER. The bytes on the right are the
    # measured sops_mac input for that row.
    my $nz = -0.0;

    my @rows = (
        [ 'str hello'  => 'hello',      'hello'                  ],
        [ 'str empty'  => '',           ''                       ],
        [ 'int 42'     => 42,           '42'                     ],
        [ 'int 007'    => 7,            '7'                      ],
        [ 'float 1.50' => 1.5,          '1.5'                    ],
        [ 'float 1.0'  => 1.0,          '1'                      ],
        [ 'float 1e20' => 1e20,         '100000000000000000000'  ],
        [ 'float -0.0' => $nz,          '-0'                     ],
        [ 'bool true'  => JSON->true,   'True'                   ],
        [ 'bool false' => JSON->false,  'False'                  ],
        [ 'null'       => undef,        ''                       ],
        [ 'time'       => '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z' ],
    );

    my %expected = map { $_->[0] => $_->[2] } @LADDER;

    for my $row (@rows) {
        my ($name, $value, $bytes) = @$row;
        is( File::SOPS::Encrypted->value_to_bytes($value), $bytes,
            "$name: value_to_bytes is the wire form" );
        is $bytes, $expected{$name},
            "$name: and the wire form is what sops's MAC covers";
    }
};

subtest 'the three classes where sops writes a display form instead' => sub {
    # What sops puts in an unencrypted ENV or INI slot, next to what its own
    # digest covers. The rows that differ are exactly the rows it then refuses
    # to read -- which is what makes "write the digest bytes" the repair.
    my %written = (
        'str hello'  => 'hello',
        'str empty'  => '',
        'int 42'     => '42',
        'int 007'    => '7',
        'float 1.50' => '1.5',
        'float 1.0'  => '1.0',
        'float 1e20' => '1E+20',
        'float -0.0' => '-0.0',
        'bool true'  => 'true',
        'bool false' => 'false',
        'null'       => '<nil>',
        'time'       => '2026-01-01T00:00:00Z',
    );

    for my $row (@LADDER) {
        my ($name, undef, $digest_bytes, undef, $roundtrips) = @$row;
        my $agrees = $written{$name} eq $digest_bytes ? 1 : 0;
        is $agrees, $roundtrips,
            "$name: sops's line " . ($agrees ? 'is' : 'is NOT')
          . ' the text its digest covers, and it '
          . ($roundtrips ? 'reads its own file' : 'refuses its own file');
    }
};

subtest 'the bytes ADR 0035 writes survive the ENV escape' => sub {
    # ADR 0030's guard sits on top of this one and asks the same function for
    # the same bytes. None of the type forms trips it -- a value that does is
    # a `str`, and it is that ADR's business, not this one's.
    my $flat = File::SOPS::Metadata::Flat->new(prefix => 'sops_');

    for my $row (@LADDER) {
        my ($name, undef, $bytes) = @$row;
        is $flat->unescape_value($flat->escape_value($bytes)), $bytes,
            "$name: the ENV escape is the identity on these bytes";
    }
};

###############################################################################
# Interop -- the only half that proves anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the ENV/INI type ladder was NOT measured against "
       . "sops, so ADR 0035's premise went unchecked. Run maint/fetch-sops "
       . "or set SOPS_BIN.", 5
        unless $sops_bin;

    require Crypt::Age;
    diag("Using sops binary: $sops_bin");

    my $dir = tempdir(CLEANUP => 1);
    my ($pub, $sec) = Crypt::Age->generate_keypair();
    write_bytes("$dir/key.txt", $sec);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    ###########################################################################
    subtest 'type:str on everything is the INPUT store, not the output one' => sub {
        # k77's premise, and the half of it that is true.
        write_bytes("$dir/plain.env", "STR=hello\nNUM=5\nFLT=1.5\nBOOL=true\n");
        my $from_env = run_ok($sops_bin, "sops -e on a plaintext .env",
            "-e --age '$pub' '$dir/plain.env'");
        for my $key (qw( STR NUM FLT BOOL )) {
            my ($line) = $from_env =~ /^($key=.*)$/m;
            like $line, qr/,type:str\]$/,
                "an ENV source types $key as str -- its reader returned a string";
        }

        write_bytes("$dir/plain.ini", "[db]\nstr = hello\nnum = 5\n");
        my $from_ini = run_ok($sops_bin, "sops -e on a plaintext .ini",
            "-e --age '$pub' '$dir/plain.ini'");
        like $from_ini, qr/^num\s*=\s*ENC\[[^\]]*,type:str\]$/m,
            'an INI source types num as str for the same reason';

        # And the half that is not: the same tree from a typed source keeps its
        # types in both flat formats.
        for my $probe ([ dotenv => 'v: 42',        qr/^v=ENC\[[^\]]*,type:int\]$/m       ],
                       [ dotenv => 'v: true',      qr/^v=ENC\[[^\]]*,type:bool\]$/m      ],
                       [ dotenv => 'v: 1.5',       qr/^v=ENC\[[^\]]*,type:float\]$/m     ],
                       [ ini    => "db:\n  v: 42", qr/^v\s*=\s*ENC\[[^\]]*,type:int\]$/m ]) {
            my ($fmt, $src, $want) = @$probe;
            write_bytes("$dir/typed.yaml", "$src\n");
            my $out = run_ok($sops_bin, "sops -e yaml -> $fmt",
                "-e --age '$pub' --input-type yaml --output-type $fmt '$dir/typed.yaml'");
            like $out, $want,
                "yaml -> $fmt keeps the scalar's type: " . (split /\n/, $src)[-1];
        }
    };

    ###########################################################################
    for my $fmt (qw( dotenv ini )) {
        my $ext = $fmt eq 'dotenv' ? 'env' : 'ini';

        subtest "$fmt: the ladder, both slots" => sub {
            for my $row (@LADDER) {
                my ($name, $yaml, $bytes, $label, $roundtrips) = @$row;
                my $tag = $name; $tag =~ s/\W+/_/g;

                # --- the ENCRYPTED slot: the label is the scalar's type -----
                my $enc = encrypt_flat($sops_bin, $dir, "${tag}_e", $fmt, $pub,
                                       'v', $yaml);
                write_bytes("$dir/${tag}_e.$ext", $enc);
                my $enc_line = data_line($enc, $fmt, 'v');

                if (defined $label) {
                    like $enc_line, qr/^ENC\[[^\]]*,type:\Q$label\E\]$/,
                        "$name: the encrypted cell carries type:$label";
                }
                else {
                    # An empty string and a null are not encrypted at all
                    # (invariant 7); sops writes the empty string for one and
                    # its Go placeholder for the other.
                    unlike $enc_line, qr/^ENC\[/,
                        "$name: not encrypted -- no cell to carry a label";
                }

                is mac_plaintext($enc, $fmt, $sec), uc(sha512_hex($bytes)),
                    "$name: sops_mac covers SHA-512 of value_to_bytes, encrypted slot";

                # --- the UNENCRYPTED slot: no label, the text is everything --
                my $plain = encrypt_flat($sops_bin, $dir, "${tag}_p", $fmt, $pub,
                                         'v_unencrypted', $yaml);
                my $path = "$dir/${tag}_p.$ext";
                write_bytes($path, $plain);

                is mac_plaintext($plain, $fmt, $sec), uc(sha512_hex($bytes)),
                    "$name: sops_mac covers the same bytes, unencrypted slot";

                my (undef, $exit) = decrypt_flat($sops_bin, $path, $fmt);
                is $exit, ($roundtrips ? 0 : 51),
                    "$name: sops " . ($roundtrips ? 'reads' : 'REFUSES')
                  . ' the unencrypted document it just wrote';

                is +(data_line($plain, $fmt, 'v_unencrypted') eq $bytes ? 1 : 0),
                   $roundtrips,
                    "$name: the written line " . ($roundtrips ? 'is' : 'is NOT')
                  . ' the text the digest covers';
            }

            # k125's worse half: an encrypted null is not encrypted, so a
            # bare <nil> reaches the file and sops stops before the MAC.
            my (undef, $nil_exit) = decrypt_flat($sops_bin, "$dir/null_e.$ext", $fmt);
            is $nil_exit, 25,
                'null in an encrypted slot: sops stops at the data format, exit 25';
        };
    }

    ###########################################################################
    subtest 'the bytes ADR 0035 writes are bytes sops writes and reads' => sub {
        # Offered to sops as a QUOTED string, so sops itself both writes and
        # digests them -- the resulting line is one sops produces, and it is
        # the line ADR 0035 makes our emitter produce for the typed value.
        for my $fmt (qw( dotenv ini )) {
            my $ext = $fmt eq 'dotenv' ? 'env' : 'ini';

            for my $row (@LADDER) {
                my ($name, undef, $bytes) = @$row;
                next if $name eq 'time';   # already round-trips as itself

                my $tag = "cand_$name"; $tag =~ s/\W+/_/g;
                my $quoted = $bytes; $quoted =~ s/(["\\])/\\$1/g;
                my $text = encrypt_flat($sops_bin, $dir, "${tag}_$ext", $fmt,
                                        $pub, 'v_unencrypted', qq{"$quoted"});
                my $path = "$dir/${tag}_$ext.$ext";
                write_bytes($path, $text);

                is data_line($text, $fmt, 'v_unencrypted'), $bytes,
                    "$fmt/$name: sops writes our bytes verbatim";
                is mac_plaintext($text, $fmt, $sec), uc(sha512_hex($bytes)),
                    "$fmt/$name: and the digest is the digest of that text";

                my (undef, $exit) = decrypt_flat($sops_bin, $path, $fmt);
                is $exit, 0, "$fmt/$name: sops reads it back";
            }

            # All of them at once, next to encrypted typed cells, because a
            # one-leaf document proves nothing about a document.
            my @plain = map  { $_->[2] }
                        grep { $_->[0] ne 'time' } @LADDER;
            my $src = '';
            my $i   = 0;
            for my $bytes (@plain) {
                my $quoted = $bytes; $quoted =~ s/(["\\])/\\$1/g;
                $src .= sprintf "k%02d_unencrypted: \"%s\"\n", $i++, $quoted;
            }
            $src .= "h: true\ni: 1.0\nj: 42\n";
            $src = "db:\n" . join('', map { "  $_\n" } split /\n/, $src)
                if $fmt eq 'ini';
            write_bytes("$dir/combined.yaml", $src);

            my $out = run_ok($sops_bin, "sops -e combined -> $fmt",
                "-e --age '$pub' --input-type yaml --output-type $fmt '$dir/combined.yaml'");
            write_bytes("$dir/combined.$ext", $out);
            my (undef, $exit) = decrypt_flat($sops_bin, "$dir/combined.$ext", $fmt);
            is $exit, 0,
                "$fmt: a document holding every type form, plus encrypted "
              . 'typed cells, reads back at exit 0';
        }
    };

    ###########################################################################
    subtest 'the metadata half: sops decodes its section weakly in EVERY format' => sub {
        # k75 handed k77 the question of what Metadata::Flat->unflatten
        # should do with `sops_mac_only_encrypted=false`, which it returns as the
        # STRING 'false' -- true in Perl, and that option selects the digest.
        #
        # This is the measurement that decides where the coercion goes: it is
        # not a flat-format property. A NESTED YAML sops section takes a quoted
        # "false" as the boolean false, through strconv.ParseBool's set, so the
        # fix belongs in Metadata->from_hash and not in unflatten.
        write_bytes("$dir/meta.yaml", "v: hello\n");
        my $base = run_ok($sops_bin, 'sops -e for the metadata fixture',
            "-e --age '$pub' '$dir/meta.yaml'");

        # exit 0  -> decoded FALSE (the document's digest covers every value)
        # exit 51 -> decoded TRUE  (mac_only_encrypted selects another digest)
        # exit 1  -> refused outright
        my %expect = (
            'false'   => 0,  '"false"' => 0,  '"FALSE"' => 0,  '"False"' => 0,
            '"f"'     => 0,  '"0"'     => 0,  '""'      => 0,  '0'       => 0,
            'true'    => 51, '"true"'  => 51, '"TRUE"'  => 51, '"True"'  => 51,
            '"t"'     => 51, '"1"'     => 51, '1'       => 51,
            '"yes"'   => 1,  '"no"'    => 1,  '"on"'    => 1,  '"off"'   => 1,
        );

        for my $spelling (sort keys %expect) {
            my $doc = $base;
            $doc =~ s/^(\s+)version:/$1mac_only_encrypted: $spelling\n$1version:/m
                or die 'the metadata fixture has no version line';
            write_bytes("$dir/meta_probe.yaml", $doc);
            my $out = `$sops_bin -d --output-type json '$dir/meta_probe.yaml' 2>&1`;
            is $? >> 8, $expect{$spelling},
                "mac_only_encrypted: $spelling -> "
              . ($expect{$spelling} == 0  ? 'false'
              :  $expect{$spelling} == 51 ? 'TRUE (and the digest moves with it)'
              :                             'refused');
        }

        # Our own read path returns the string, faithfully, and that is what
        # ADR 0035 leaves in place -- the coercion is from_hash's.
        my $flat = File::SOPS::Metadata::Flat->new(prefix => 'sops_');
        my $back = $flat->unflatten({ sops_mac_only_encrypted => 'false' });
        is $back->{mac_only_encrypted}, 'false',
            'unflatten stays faithful to the untyped encoding';
        ok !ref $back->{mac_only_encrypted},
            'and hands back a plain string, not a boolean it invented';
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

sub run_ok {
    my ($sops_bin, $what, $args) = @_;
    my $out = `$sops_bin $args 2>&1`;
    die "$what failed: $out" if $? != 0;
    return $out;
}

# A YAML source is the only way to hand sops an exact typed value -- the flat
# stores' own readers have no syntax for a type, which is the whole subject.
# INI needs a section, so the tree is one level deeper there.
sub encrypt_flat {
    my ($sops_bin, $dir, $tag, $fmt, $pub, $key, $yaml) = @_;

    my $src = "$dir/$tag.yaml";
    write_bytes($src, $fmt eq 'ini' ? "db:\n  $key: $yaml\n" : "$key: $yaml\n");

    return run_ok($sops_bin, "sops -e for '$tag'",
        "-e --age '$pub' --input-type yaml --output-type $fmt '$src'");
}

sub decrypt_flat {
    my ($sops_bin, $path, $fmt, @flags) = @_;
    my $out = `$sops_bin -d @flags --input-type $fmt --output-type json '$path' 2>&1`;
    return ($out, $? >> 8);
}

# The value side of one key, as bytes, out of a document in either flat format.
# go-ini pads the name out to the widest one and puts a single space after the
# `=`; the dotenv store writes `KEY=VALUE` with no padding at all.
sub data_line {
    my ($text, $fmt, $key) = @_;

    if ($fmt eq 'dotenv') {
        my ($value) = $text =~ /^\Q$key\E=(.*)$/m;
        return defined $value ? $value : '(no data line)';
    }

    my ($value) = $text =~ /^\Q$key\E\s*=[ ]?(.*)$/m;
    return defined $value ? $value : '(no data line)';
}

# Metadata::Flat -> Metadata -> Backend::Age -> Encrypted, on a file sops wrote.
# Returns the uppercase hex SHA-512 the document claims for itself.
sub mac_plaintext {
    my ($text, $fmt, $identity) = @_;

    my %lines;
    my $prefix = 'sops_';

    if ($fmt eq 'dotenv') {
        for my $line (split /\n/, $text) {
            next unless length $line;
            my ($k, $v) = split /=/, $line, 2;
            $lines{$k} = $v;
        }
    }
    else {
        # The [sops] section already separates the metadata, so the flat keys
        # carry no prefix there -- the one difference between the two encodings.
        $prefix = '';
        my $in_sops = 0;
        for my $line (split /\n/, $text) {
            if ($line =~ /^\s*\[(.+)\]\s*$/) { $in_sops = ($1 eq 'sops'); next }
            next unless $in_sops && $line =~ /=/;
            my ($k, $v) = split /=/, $line, 2;
            $k =~ s/\s+$//;
            $v =~ s/^[ ]//;
            $lines{$k} = $v;
        }
    }

    my $flat = File::SOPS::Metadata::Flat->new(prefix => $prefix);
    my $meta = File::SOPS::Metadata->from_hash($flat->unflatten(\%lines));
    my $key  = File::SOPS::Backend::Age->decrypt_data_key(
        age_keys   => [ $meta->get_age_encrypted_keys ],
        identities => [ $identity ],
    );

    return File::SOPS::Encrypted->parse($meta->mac)
        ->decrypt_bytes(key => $key, aad => $meta->lastmodified // '');
}
