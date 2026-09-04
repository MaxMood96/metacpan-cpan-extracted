#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use YAML::XS qw(Load Dump);

use File::SOPS;
use File::SOPS::Metadata;
use Crypt::Age;

# rotate decrypts and re-encrypts, and until k13 the re-encryption threw
# away everything in the sops section that rotate had not explicitly read back:
# encrypt always constructed a fresh Metadata with the defaults. What survived
# was the age recipients, and only because rotate re-read them by hand.
#
# The dangerous case is not a lost setting, it is a lost recipient: rotating a
# file shared with PGP or KMS recipients silently revoked their access and
# reported success, and the file kept decrypting perfectly for whoever ran the
# command.

my ($public, $secret) = Crypt::Age->generate_keypair();
my $dir = tempdir(CLEANUP => 1);
my $serial = 0;

# Write an encrypted document to a file, after letting $mangle rewrite its
# sops section -- which is how a document gains metadata this distribution
# cannot itself produce.
#
# The parse-and-re-dump is only safe because the document came from our own
# emitter, which sorts keys, so the re-dump reproduces the order the MAC was
# computed over. Do not reach for this on a document sops wrote: its keys are
# in document order, the digest is order-dependent, and a re-dump would
# invalidate the MAC rather than test anything.
sub encrypted_file {
    my (%args) = @_;
    my $mangle = delete $args{mangle};

    my $yaml = File::SOPS->encrypt(
        recipients => [$public],
        format     => 'yaml',
        %args,
    );

    if ($mangle) {
        my $doc = Load($yaml);
        $mangle->($doc->{sops});
        $yaml = Dump($doc);
        # sops writes lastmodified quoted and Go's YAML types a bare RFC3339
        # scalar as a timestamp; re-dumping here loses the quotes.
        $yaml =~ s/^(\s+lastmodified: )(\S+)$/$1"$2"/m;
    }

    my $file = "$dir/rot-" . ++$serial . ".yaml";
    open my $fh, '>:raw', $file or die $!;
    print $fh $yaml;
    close $fh;

    return $file;
}

sub sops_section {
    my ($file) = @_;
    open my $fh, '<:raw', $file or die $!;
    my $yaml = do { local $/; <$fh> };
    close $fh;
    return (Load($yaml)->{sops}, $yaml);
}

###############################################################################
# The encryption rules survive a rotation
###############################################################################
subtest 'rotate keeps the rule the document was written under' => sub {
    my $file = encrypted_file(
        data             => { password_enc => 'hidden', host => 'db.example.com' },
        encrypted_suffix => '_enc',
    );

    File::SOPS->rotate(file => $file, identities => [$secret]);

    my ($sops, $yaml) = sops_section($file);
    is($sops->{encrypted_suffix}, '_enc', 'encrypted_suffix survived the rotation');
    ok(!exists $sops->{unencrypted_suffix},
        'and was not replaced by the default rule');

    like($yaml, qr/^password_enc: ENC\[/m, 'the rule is still applied');
    like($yaml, qr/^host: db\.example\.com$/m, 'on both sides of it');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        { password_enc => 'hidden', host => 'db.example.com' },
        'and the rotated document verifies',
    );
};

subtest 'rotate keeps mac_only_encrypted' => sub {
    my $file = encrypted_file(
        data               => { cfg_unencrypted => 'plain', secret => 'shh' },
        mac_only_encrypted => 1,
    );

    File::SOPS->rotate(file => $file, identities => [$secret]);

    my ($sops, $yaml) = sops_section($file);
    ok($sops->{mac_only_encrypted}, 'mac_only_encrypted survived');
    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        { cfg_unencrypted => 'plain', secret => 'shh' },
        'and the digest still verifies under it',
    );
};

subtest 'rotate keeps a document with no rule at all rule-less' => sub {
    my $file = encrypted_file(
        data               => { cfg_unencrypted => 'v' },
        unencrypted_suffix => undef,
    );

    File::SOPS->rotate(file => $file, identities => [$secret]);

    my ($sops, $yaml) = sops_section($file);
    ok(!exists $sops->{unencrypted_suffix},
        'no rule is invented on the way back out');
    like($yaml, qr/^cfg_unencrypted: ENC\[/m,
        'so the value stays encrypted rather than dropping to plaintext')
        or diag('inventing the default here would expose a value the document encrypts');
};

###############################################################################
# Fields this distribution does not model
###############################################################################
subtest 'rotate keeps sops fields this distribution does not model' => sub {
    my $file = encrypted_file(
        data   => { secret => 'shh' },
        mangle => sub {
            my ($sops) = @_;
            $sops->{shamir_threshold}  = 2;
            $sops->{some_future_field} = 'hello';
        },
    );

    File::SOPS->rotate(file => $file, identities => [$secret]);

    my ($sops) = sops_section($file);
    is($sops->{shamir_threshold}, 2,
        'shamir_threshold survived, as it does through sops rotate');
    is($sops->{some_future_field}, 'hello',
        'and so did a field neither implementation knows');
};

###############################################################################
# Key material for a backend we cannot re-encrypt for
###############################################################################
subtest 'rotate refuses a file holding foreign key material' => sub {
    for my $field (qw(pgp kms gcp_kms azure_kv hc_vault)) {
        my $file = encrypted_file(
            data   => { secret => 'shh' },
            mangle => sub { $_[0]->{$field} = [ { enc => 'WRAPPED-FOR-SOMEONE-ELSE' } ] },
        );

        my ($before) = sops_section($file);

        my $err = do {
            local $@;
            eval { File::SOPS->rotate(file => $file, identities => [$secret]) };
            $@;
        };

        like($err, qr/\Q$field\E/, "rotate refuses a file with $field entries")
            or diag('dropping them silently revokes those recipients');

        my ($after) = sops_section($file);
        is_deeply($after->{$field}, $before->{$field},
            "and leaves the $field entries untouched on disk");
    }
};

subtest 'rotate refuses a file holding key_groups' => sub {
    my $file = encrypted_file(
        data   => { secret => 'shh' },
        mangle => sub {
            $_[0]->{key_groups}       = [ [ { enc => 'GROUP-WRAPPED' } ] ];
            $_[0]->{shamir_threshold} = 2;
        },
    );

    my $err = do {
        local $@;
        eval { File::SOPS->rotate(file => $file, identities => [$secret]) };
        $@;
    };
    like($err, qr/key_groups/, 'rotate refuses a shamir/key-group document')
        or diag('those groups wrap the OLD data key');
};

subtest 'an empty backend list is not key material' => sub {
    my $file = encrypted_file(
        data   => { secret => 'shh' },
        mangle => sub { $_[0]->{pgp} = []; $_[0]->{kms} = [] },
    );

    my $ok = eval { File::SOPS->rotate(file => $file, identities => [$secret]); 1 };
    ok($ok, 'a document with empty backend lists still rotates')
        or diag("died: $@");
};

###############################################################################
# The data key really is new
###############################################################################
subtest 'rotation still rotates' => sub {
    my $file = encrypted_file(data => { secret => 'shh' });

    my ($before, $yaml_before) = sops_section($file);
    File::SOPS->rotate(file => $file, identities => [$secret]);
    my ($after, $yaml_after) = sops_section($file);

    isnt($after->{age}[0]{enc}, $before->{age}[0]{enc}, 'the wrapped data key changed');
    is($after->{age}[0]{recipient}, $public, 'the recipient did not');
    isnt($after->{mac}, $before->{mac}, 'and so did the MAC');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml_after, identities => [$secret]),
        { secret => 'shh' },
        'the rotated document still decrypts',
    );
};

done_testing;
