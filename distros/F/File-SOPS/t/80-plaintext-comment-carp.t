#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Crypt::Age;

use File::SOPS;
use File::SOPS::Comment;

# ----------------------------------------------------------------------------
# k173 -- docs/adr/0067. The open half of docs/adr/0049's Limits.
#
# A PLAINTEXT comment stands in a slot the encryption rule SELECTS. sops keeps
# it at exit 0 -- one of the four bare shapes docs/adr/0049 measured -- but it
# also WARNS, because a comment in an encrypted slot can hold a secret in the
# clear and nothing authenticates it:
#
#     level=warning msg="Found possibly unencrypted comment in file. This is to
#     be expected if the file being decrypted was created with an older version
#     of SOPS." comment=" note"
#
# Measured on sops 3.13.3 (/tmp/sops), 2026-09-01: the warning is on the
# DECRYPT path only, in yaml, dotenv and ini; on the ENCRYPT path sops encrypts
# the comment into a type:comment leaf and says nothing. docs/adr/0049
# reproduced the OUTCOME (the comment is kept) and deliberately not the warning.
# This is that warning, added as a `carp` -- the precedent is docs/adr/0018.
#
# WHERE THE CARP IS REACHABLE. The plaintext comment must survive parsing into
# a File::SOPS::Comment before _decrypt_tree can meet it at a selected path.
# The dotenv and ini handlers preserve a plaintext comment as such a leaf; the
# yaml handler cannot, because YAML::XS discards every plaintext comment before
# this distribution sees a tree (docs/adr/0060). So the carp fires for dotenv
# and ini, and there is no comment leaf to carp about in yaml -- a pre-existing
# limit of the yaml handler, not a gap this ticket opens.
#
# HARD INVARIANT. The carp is advisory. It moves no wire bytes and no digest:
# it sits in _decrypt_tree, which is not the MAC path, and the injected
# comment is not authenticated. Each format's section proves it two ways --
# the stored MAC line is byte-identical with and without the comment, and the
# document still decrypts fail-closed (a comment that entered the digest would
# make verification FAIL against the MAC computed without it).
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();

# Decrypt, collecting warnings, without letting a carp reach the test harness.
sub read_back {
    my ($doc) = @_;
    my @warnings;
    my $data = do {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        eval {
            File::SOPS->decrypt(encrypted => $doc, identities => [$secret]);
        };
    };
    return ($data, $@, \@warnings);
}

# Insert a raw comment line just above the first line matching $before.
sub inject_comment {
    my ($doc, $before, $comment_line) = @_;
    my @lines = split /^/, $doc;
    my @out;
    my $done = 0;
    for my $l (@lines) {
        if (!$done && $l =~ $before) {
            push @out, $comment_line;
            $done = 1;
        }
        push @out, $l;
    }
    die 'the fixture had no line to inject above' unless $done;
    return join '', @out;
}

# The stored MAC line, extracted so it can be compared byte for byte.
sub mac_line {
    my ($doc) = @_;
    for my $l (split /^/, $doc) {
        return $l if $l =~ /(?:^|_)mac\s*[:=]/;
    }
    die 'no mac line in document';
}

###############################################################################
# dotenv -- a plaintext `# note` comment in the encrypted body.
###############################################################################

subtest 'dotenv: a plaintext comment in an encrypted slot carps, digest holds'
=> sub {
    my $clean = File::SOPS->encrypt(
        data => { FOO => 'one', BAR => 'two' },
        recipients => [$public], format => 'env',
    );

    # Clean document: reads back with no warning at all.
    my ($cdata, $cerr, $cwarn) = read_back($clean);
    is $cerr, '', 'clean dotenv decrypts';
    is scalar @$cwarn, 0, 'and says nothing';

    my $injected = inject_comment($clean, qr/^FOO=/, "# note\n");

    # The MAC was not touched -- only a comment line was inserted.
    is mac_line($injected), mac_line($clean),
        'the stored MAC line is byte-identical with the comment present';

    my ($data, $err, $warn) = read_back($injected);

    is $err, '', 'the document still decrypts -- fail-closed MAC verified, so '
        . 'the plaintext comment contributed nothing to the digest';
    is scalar @$warn, 1, 'exactly one carp' or diag(explain($warn));
    like $warn->[0], qr/plaintext comment/, 'it names the shape';
    like $warn->[0], qr/not encrypted and not authenticated/,
        'and why it matters';
    like $warn->[0], qr/possibly unencrypted comment/,
        "and quotes sops's own warning";
    like $warn->[0], qr/rotate/, 'and names the repair';

    is $data->{FOO}, 'one', 'the values came back (FOO)';
    is $data->{BAR}, 'two', 'the values came back (BAR)';
    my ($leaf) = grep { ref } map { ref eq 'ARRAY' ? @$_ : $_ } values %$data;
    isa_ok $leaf, 'File::SOPS::Comment',
        'and the comment is kept as a comment leaf';
    is $leaf->text, ' note', 'with its text intact';
};

###############################################################################
# ini -- a plaintext `; note` comment inside an encrypted section.
###############################################################################

subtest 'ini: a plaintext comment in an encrypted slot carps, digest holds'
=> sub {
    my $clean = File::SOPS->encrypt(
        data => { sec => { foo => 'one', bar => 'two' } },
        recipients => [$public], format => 'ini',
    );

    my ($cdata, $cerr, $cwarn) = read_back($clean);
    is $cerr, '', 'clean ini decrypts';
    is scalar @$cwarn, 0, 'and says nothing';

    my $injected = inject_comment($clean, qr/^foo\s*=/, "; note\n");

    is mac_line($injected), mac_line($clean),
        'the stored MAC line is byte-identical with the comment present';

    my ($data, $err, $warn) = read_back($injected);

    is $err, '', 'the document still decrypts -- fail-closed MAC verified';
    is scalar @$warn, 1, 'exactly one carp' or diag(explain($warn));
    like $warn->[0], qr/plaintext comment/, 'it names the shape';
    like $warn->[0], qr/possibly unencrypted comment/,
        "and quotes sops's own warning";

    is $data->{sec}{foo}, 'one', 'the values came back (foo)';
    is $data->{sec}{bar}, 'two', 'the values came back (bar)';
    my ($leaf) = grep { ref eq 'File::SOPS::Comment' } @{ $data->{sec}{''} // [] };
    isa_ok $leaf, 'File::SOPS::Comment',
        'and the comment is kept as a comment leaf';
    is $leaf->text, 'note', 'with its text intact';
};

###############################################################################
# The discriminator: an ENCRYPTED type:comment is NOT a plaintext comment, and
# must stay silent. This is what scopes the carp to the shape sops warns about
# -- decrypting an ENC[...,type:comment] hands back a File::SOPS::Comment too,
# but through the cipher, not bare in an encrypted slot.
###############################################################################

subtest 'an encrypted type:comment round-trips silently' => sub {
    my $enc = File::SOPS->encrypt(
        data => { list => [ File::SOPS::Comment->new(text => ' note'), 'one' ] },
        recipients => [$public], format => 'yaml',
    );
    like $enc, qr/type:comment/, 'the comment is encrypted on the wire';

    my ($data, $err, $warn) = read_back($enc);
    is $err, '', 'it decrypts';
    is scalar @$warn, 0, 'and says nothing -- an encrypted comment is not the '
        . 'plaintext one sops warns about';
    isa_ok $data->{list}[0], 'File::SOPS::Comment', 'it comes back a comment';
};

done_testing;
