#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use YAML::XS qw(Load);

use File::SOPS;
use File::SOPS::Metadata;
use Crypt::Age;

# Which values a document encrypts is configurable in sops, and every one of
# those switches was documented here long before any of them was reachable:
# File::SOPS->encrypt built its Metadata with the defaults and took no
# argument for it, so the only rule that could ever be in effect was the
# _unencrypted default (k17).
#
# The rules themselves are pinned against the reference implementation in
# t/04-interop.t. What this file pins is that they can be SET, that setting one
# stands the others down, and that a rule read out of a document is the rule
# that document gets written back under.

my ($public, $secret) = Crypt::Age->generate_keypair();

sub encrypt_ok {
    my (%args) = @_;
    return File::SOPS->encrypt(
        recipients => [$public],
        format     => 'yaml',
        %args,
    );
}

sub sops_section {
    my ($yaml) = @_;
    return Load($yaml)->{sops};
}

###############################################################################
# unencrypted_suffix: reachable, and not just the default
###############################################################################
subtest 'unencrypted_suffix can be chosen' => sub {
    my $data = {
        keep_plain      => 'readable',
        secret          => 'hidden',
        also_unencrypted => 'this suffix is NOT in effect',
    };

    my $yaml = encrypt_ok(data => $data, unencrypted_suffix => '_plain');

    like($yaml, qr/^keep_plain: readable$/m,
        'a key carrying the chosen suffix is left in plaintext');
    like($yaml, qr/^secret: ENC\[/m, 'everything else is encrypted');
    like($yaml, qr/^also_unencrypted: ENC\[/m,
        'and the DEFAULT suffix no longer applies once another was chosen');

    my $sops = sops_section($yaml);
    is($sops->{unencrypted_suffix}, '_plain', 'the choice is recorded in the file');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        $data,
        'and the document verifies and round-trips',
    );
};

###############################################################################
# encrypted_suffix: the inverted rule, which was entirely unreachable
###############################################################################
subtest 'encrypted_suffix can be chosen' => sub {
    my $data = { password_enc => 'hidden', host => 'db.example.com' };

    my $yaml = encrypt_ok(data => $data, encrypted_suffix => '_enc');

    like($yaml, qr/^password_enc: ENC\[/m, 'a key carrying the suffix is encrypted');
    like($yaml, qr/^host: db\.example\.com$/m, 'everything else is left readable');

    my $sops = sops_section($yaml);
    is($sops->{encrypted_suffix}, '_enc', 'the rule is recorded in the file');
    ok(!exists $sops->{unencrypted_suffix},
        'and the default unencrypted_suffix is NOT written alongside it')
        or diag('sops refuses a document that carries two rules');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        $data,
        'the document verifies and round-trips',
    );
};

###############################################################################
# The regex rules
###############################################################################
subtest 'the regex rules can be chosen' => sub {
    my $yaml = encrypt_ok(
        data              => { public_host => 'h', token => 't' },
        unencrypted_regex => '^public_',
    );
    like($yaml, qr/^public_host: h$/m, 'unencrypted_regex leaves a match readable');
    like($yaml, qr/^token: ENC\[/m,    'and encrypts the rest');
    is(sops_section($yaml)->{unencrypted_regex}, '^public_', 'recorded in the file');

    $yaml = encrypt_ok(
        data            => { secret_token => 't', host => 'h' },
        encrypted_regex => '^secret_',
    );
    like($yaml, qr/^secret_token: ENC\[/m, 'encrypted_regex encrypts a match');
    like($yaml, qr/^host: h$/m,            'and leaves the rest readable');
    is(sops_section($yaml)->{encrypted_regex}, '^secret_', 'recorded in the file');
};

###############################################################################
# No rule at all is a setting, not an absence
###############################################################################
subtest 'unencrypted_suffix => undef means no rule' => sub {
    my $yaml = encrypt_ok(
        data               => { cfg_unencrypted => 'v', other => 'o' },
        unencrypted_suffix => undef,
    );

    like($yaml, qr/^cfg_unencrypted: ENC\[/m,
        'with no rule, even a _unencrypted key is encrypted');

    my $sops = sops_section($yaml);
    ok(!exists $sops->{unencrypted_suffix}, 'and no rule is written to the file');
};

###############################################################################
# Mutual exclusion -- the reference refuses such a document outright
###############################################################################
subtest 'at most one rule' => sub {
    my $err = do {
        local $@;
        eval {
            encrypt_ok(
                data               => { a => 1 },
                unencrypted_suffix => '_plain',
                encrypted_suffix   => '_enc',
            );
        };
        $@;
    };
    like($err, qr/Cannot use more than one of/,
        'two rules on encrypt is refused here rather than by sops later');

    $err = do {
        local $@;
        eval { File::SOPS::Metadata->new(encrypted_regex => 'a', unencrypted_regex => 'b') };
        $@;
    };
    like($err, qr/Cannot use more than one of/, 'and the same on Metadata itself');

    $err = do {
        local $@;
        eval {
            File::SOPS::Metadata->from_hash({
                unencrypted_suffix      => '_unencrypted',
                encrypted_comment_regex => 'sops',
            });
        };
        $@;
    };
    like($err, qr/Cannot use more than one of/,
        'including a rule this distribution does not implement');
};

###############################################################################
# from_hash: an absent rule stays absent
#
# The asymmetry against a freshly constructed object is deliberate. Measured
# against sops 3.13.3: delete unencrypted_suffix from a file it wrote and it
# stops treating a _unencrypted key as plaintext.
###############################################################################
subtest 'from_hash does not invent a rule the document did not carry' => sub {
    my $ruleless = File::SOPS::Metadata->from_hash({ age => [], version => '3.7.3' });
    is($ruleless->unencrypted_suffix, undef, 'a document with no rule field has no rule');
    ok($ruleless->should_encrypt_path(['cfg_unencrypted']),
        'so a _unencrypted key is encrypted, as sops does with such a file');

    my $fresh = File::SOPS::Metadata->new;
    is($fresh->unencrypted_suffix, '_unencrypted',
        'while CREATING a document still applies the default, as sops does');

    my $carried = File::SOPS::Metadata->from_hash({ encrypted_suffix => '_enc' });
    is($carried->encrypted_suffix,   '_enc', 'a document rule is read back');
    is($carried->unencrypted_suffix, undef,  'and does not pick up a second rule');
};

###############################################################################
# metadata => $meta carries the policy, never the key material
###############################################################################
subtest 'encrypt takes its policy from a metadata template' => sub {
    my $source = File::SOPS::Metadata->from_hash({
        encrypted_suffix   => '_enc',
        mac_only_encrypted => 1,
        age                => [ { recipient => 'age1stale', enc => 'STALE' } ],
        mac                => 'ENC[AES256_GCM,data:x,iv:y,tag:z,type:str]',
        lastmodified       => '1999-01-01T00:00:00Z',
    });

    my $yaml = encrypt_ok(
        data     => { password_enc => 'hidden', host => 'h' },
        metadata => $source,
    );

    my $sops = sops_section($yaml);
    is($sops->{encrypted_suffix}, '_enc', 'the rule is carried over');
    ok($sops->{mac_only_encrypted}, 'so is mac_only_encrypted');

    is(scalar @{ $sops->{age} }, 1, 'exactly one age recipient');
    is($sops->{age}[0]{recipient}, $public, 'and it is the one just encrypted for')
        or diag('the template key material must never be carried into a new document');
    isnt($sops->{lastmodified}, '1999-01-01T00:00:00Z', 'lastmodified is regenerated');
    isnt($sops->{mac}, 'ENC[AES256_GCM,data:x,iv:y,tag:z,type:str]', 'and so is the MAC');

    like($yaml, qr/^password_enc: ENC\[/m, 'the carried rule is actually applied');
    like($yaml, qr/^host: h$/m,            'to both sides of it');
};

subtest 'an explicit rule replaces the template rule' => sub {
    my $source = File::SOPS::Metadata->from_hash({ encrypted_suffix => '_enc' });

    my $yaml = encrypt_ok(
        data               => { a_enc => 'x', b_plain => 'y' },
        metadata           => $source,
        unencrypted_suffix => '_plain',
    );

    my $sops = sops_section($yaml);
    is($sops->{unencrypted_suffix}, '_plain', 'the explicit rule wins');
    ok(!exists $sops->{encrypted_suffix},
        'and the template rule is dropped rather than joined')
        or diag('joining them would build a document sops refuses');

    like($yaml, qr/^a_enc: ENC\[/m,  'the explicit rule is the one applied');
    like($yaml, qr/^b_plain: y$/m,   'on both sides of it');
};

subtest 'a rule we cannot apply is refused on the write side' => sub {
    # Reading such a document is fine -- decryption goes by which values look
    # encrypted -- but writing one would classify every value wrongly, because
    # neither of our parsers keeps the comments the rule selects on.
    my $source = File::SOPS::Metadata->from_hash({ encrypted_comment_regex => 'sops' });

    my $err = do {
        local $@;
        eval { encrypt_ok(data => { a => 'b' }, metadata => $source) };
        $@;
    };
    like($err, qr/comment/, 'encrypt refuses a comment-based rule')
        or diag("got: $err");
};

###############################################################################
# The rules apply to the whole path, not to one level at a time (k16)
#
# The document below is the one measured against sops 3.13.3 with
# --encrypted-suffix _enc; the expectations are that binary's output, not this
# library's. The tree walk used to ask should_encrypt_key about each key as it
# descended, which gets the unencrypted rules right by accident -- an excluded
# branch stays excluded anyway -- and the encrypted ones wrong twice over: it
# left everything under top_enc: readable, and never reached plain:nested_enc
# at all because it stopped descending at `plain`.
###############################################################################
subtest 'encrypted_suffix matches any path component' => sub {
    my $data = {
        top_enc => { inner => 'v1', other => 'v2' },
        plain   => { nested_enc => 'v3', nested => 'v4' },
        deep    => { branch => { leaf_enc => 'v5', leaf => 'v6' } },
        list_enc => [ 'e1', 'e2' ],
    };

    my $yaml = encrypt_ok(data => $data, encrypted_suffix => '_enc');

    like($yaml, qr/^  inner: ENC\[/m,
        'a leaf under a matching parent is encrypted');
    like($yaml, qr/^  other: ENC\[/m,
        'and so is its sibling -- the parent decides for the whole branch');
    like($yaml, qr/^  nested_enc: ENC\[/m,
        'a matching leaf under a non-matching parent is reached and encrypted')
        or diag('the walk used to stop descending at the non-matching parent');
    like($yaml, qr/^  nested: v4$/m, 'while its sibling stays readable');
    like($yaml, qr/^    leaf_enc: ENC\[/m, 'the same two levels down');
    like($yaml, qr/^    leaf: v6$/m,       'and its sibling too');
    # YAML::XS emits a block sequence at its parent's indentation.
    like($yaml, qr/^- ENC\[/m,
        'array elements match on the parent key, having no path component of their own');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        $data,
        'and the document verifies and round-trips',
    );
};

subtest 'encrypted_regex matches any path component' => sub {
    my $data = { secret_block => { a => 'x' }, public => { b => 'y' } };

    my $yaml = encrypt_ok(data => $data, encrypted_regex => '^secret_');

    like($yaml, qr/^  a: ENC\[/m, 'a leaf under a matching parent is encrypted');
    like($yaml, qr/^  b: y$/m,    'and one under a non-matching parent is not');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        $data,
        'and the document verifies and round-trips',
    );
};

subtest 'the unencrypted rules still exclude a whole branch' => sub {
    # Behaviour that must NOT change: the per-level walk and the per-path walk
    # give the same answer here, and this is the shape the default rule makes
    # every caller depend on.
    my $data = {
        blk_unencrypted => { host => 'db.example.com', deeper => { leaf => 'v' } },
        secret          => 'shh',
    };

    my $yaml = encrypt_ok(data => $data);

    like($yaml, qr/^  host: db\.example\.com$/m, 'a leaf under the excluded branch');
    like($yaml, qr/^    leaf: v$/m,              'at any depth');
    like($yaml, qr/^secret: ENC\[/m,             'and the rest is still encrypted');

    is_deeply(
        File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]),
        $data,
        'and the document verifies and round-trips',
    );
};

###############################################################################
# encrypt_file offers the same switches as encrypt
###############################################################################
subtest 'encrypt_file passes the rules through' => sub {
    my $dir = tempdir(CLEANUP => 1);
    open my $fh, '>:raw', "$dir/in.yaml" or die $!;
    print $fh "password_enc: hidden\nhost: db.example.com\n";
    close $fh;

    File::SOPS->encrypt_file(
        input            => "$dir/in.yaml",
        output           => "$dir/out.yaml",
        recipients       => [$public],
        encrypted_suffix => '_enc',
    );

    open my $in, '<:raw', "$dir/out.yaml" or die $!;
    my $yaml = do { local $/; <$in> };
    close $in;

    like($yaml, qr/^password_enc: ENC\[/m, 'the rule reached the file API');
    like($yaml, qr/^host: db\.example\.com$/m, 'and applies there too');
    is(sops_section($yaml)->{encrypted_suffix}, '_enc', 'recorded in the file');
};
done_testing;
