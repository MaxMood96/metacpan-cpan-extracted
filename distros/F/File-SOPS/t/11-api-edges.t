#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use File::SOPS;
use File::SOPS::Encrypted;
use File::SOPS::Format::YAML;
use JSON::MaybeXS;
use YAML::XS ();
use Crypt::Age;

# ----------------------------------------------------------------------------
# Small correctness edges, all reproduced before being fixed (k20).
#
#   (a) extract's bracket notation only understood QUOTED keys, so the form its
#       own POD documents -- ["items"][0] -- silently returned the whole
#       arrayref instead of the element. sops -d --extract '["items"][0]'
#       returns the element.
#   (b) a missing path returned undef at the top level and croaked when nested.
#       sops errors at every level: "component ['nope'] not found", exit 1.
#   (c) encrypt_value on an empty string built an ENC[...] string its own regex
#       rejects -- and sops rejects it too: "Input string ENC[...] does not
#       match sops' data format", exit 25.
#   (d) undef became an empty string. sops leaves a null alone, in both formats.
#   (e) setting $YAML::XS::Boolean at load time is a process-global side effect
#       on whatever else in the program uses YAML::XS.
#   (f) two things this distribution gets from the ORDER of its own use lines,
#       neither of which this file can check in its own process because it
#       loads JSON::MaybeXS itself at the top. Added with k49, which
#       proposed deleting `use JSON::MaybeXS` from File/SOPS.pm as an unused
#       import; it is not one. Both checks run in a fresh perl that loads
#       nothing but File::SOPS.
#
# No sops binary needed; t/04-interop.t pins the reference behaviour these are
# written against.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();
my $tempdir = tempdir(CLEANUP => 1);

my %DATA = (
    database => { host => 'db.example.com', password => 'extract-me' },
    items    => [ 'first', 'second', 'third' ],
    rows     => [ { name => 'a' }, { name => 'b' } ],
);

my $enc_file = "$tempdir/extract.yaml";
{
    my $encrypted = File::SOPS->encrypt(
        data => \%DATA, recipients => [$public], format => 'yaml',
    );
    open my $fh, '>:raw', $enc_file or die $!;
    print $fh $encrypted;
    close $fh;
}

sub extract_ok {
    my ($path) = @_;
    return File::SOPS->extract(
        file => $enc_file, path => $path, identities => [$secret],
    );
}

# ----------------------------------------------------------------------------
# (a) Bracket notation with a numeric index.
# ----------------------------------------------------------------------------

is(extract_ok('["database"]["password"]'), 'extract-me',
    'bracket notation with quoted keys still works');
is(extract_ok('database.password'), 'extract-me',
    'dot notation still works');
is(extract_ok('items.1'), 'second',
    'dot notation with a numeric index still works');

is(extract_ok('["items"][0]'), 'first',
    'bracket notation with a bare numeric index reaches the element');
is(extract_ok('["items"][2]'), 'third',
    'and the last one');
is(extract_ok('["rows"][1]["name"]'), 'b',
    'and an index followed by a key');
is(extract_ok(q{['items'][0]}), 'first',
    'single-quoted keys work too');

# Extracting a whole branch is legal -- sops does it -- so the POD claim that
# extract returns "a scalar, not a reference" was wrong in that direction too.
is_deeply(extract_ok('["database"]'), $DATA{database},
    'extracting a branch returns the branch');

# ----------------------------------------------------------------------------
# (b) A missing component fails the same way at every depth.
# ----------------------------------------------------------------------------

for my $path ('["nope"]', 'nope', '["database"]["nope"]', 'database.nope',
              '["items"][9]', '["database"]["password"]["deeper"]') {
    my $err = do {
        local $@;
        eval { extract_ok($path) };
        $@;
    };
    like($err, qr/\bnot found\b|\bcannot navigate\b/i,
        "missing path '$path' fails loudly");
}

# ----------------------------------------------------------------------------
# (c) An empty plaintext has no representation in the wire format.
# ----------------------------------------------------------------------------

{
    my $key = "\2" x 32;

    my $err = do {
        local $@;
        eval { File::SOPS::Encrypted->encrypt_value(value => '', key => $key, aad => 'v:') };
        $@;
    };
    like($err, qr/empty/i, 'encrypt_value refuses an empty value');

    $err = do {
        local $@;
        eval { File::SOPS::Encrypted->encrypt_value(value => undef, key => $key, aad => 'v:') };
        $@;
    };
    like($err, qr/empty/i, 'and refuses undef, which serializes to the same nothing');

    # The shape it used to build: unparseable by its own regex, and rejected by
    # sops with "does not match sops' data format".
    my $broken = 'ENC[AES256_GCM,data:,iv:AAAA,tag:BBBB,type:str]';
    ok(!File::SOPS::Encrypted->is_encrypted($broken),
        'an ENC string with empty data is not a valid encrypted value');

    # A one-byte value is fine and must stay fine.
    my $enc = File::SOPS::Encrypted->encrypt_value(value => 'x', key => $key, aad => 'v:');
    ok(File::SOPS::Encrypted->is_encrypted($enc->to_string),
        'a one-character value still round-trips through the regex');
}

# ----------------------------------------------------------------------------
# (d) undef is null, not an empty string.
# ----------------------------------------------------------------------------

for my $format (qw(yaml json)) {
    my $encrypted = File::SOPS->encrypt(
        data       => { nothing => undef, empty => '', filled => 'v' },
        recipients => [$public],
        format     => $format,
    );

    if ($format eq 'yaml') {
        like($encrypted, qr/^nothing: ~?\s*$|^nothing: null$/m,
            '[yaml] undef is emitted as a null, not as an empty string');
        unlike($encrypted, qr/^nothing: ''$/m,
            '[yaml] and specifically not as the empty string');
    }
    else {
        like($encrypted, qr/"nothing"\s*:\s*null/,
            '[json] undef is emitted as null');
    }

    my $back = File::SOPS->decrypt(
        encrypted => $encrypted, identities => [$secret], format => $format,
    );
    ok(exists $back->{nothing}, "[$format] the null key survives");
    is($back->{nothing}, undef, "[$format] and comes back as undef");
    is($back->{empty}, '', "[$format] an empty string is still an empty string");
    is($back->{filled}, 'v', "[$format] and a real value is untouched");
}

# The digest must still cover a null leaf the way Go does -- as nothing at all.
# A sops-written document with a null verifies here today, so this is a
# regression guard rather than a new claim.
{
    my $encrypted = File::SOPS->encrypt(
        data       => { a_unencrypted => undef, b => 'x' },
        recipients => [$public],
        format     => 'yaml',
    );
    my $back = eval {
        File::SOPS->decrypt(encrypted => $encrypted, identities => [$secret]);
    };
    is($@, '', 'a document with an unencrypted null verifies against itself')
        or diag("died: $@");
    is($back->{a_unencrypted}, undef, 'and the null is still a null') if $back;
}

# ----------------------------------------------------------------------------
# (e) $YAML::XS::Boolean must not be set behind the caller's back.
# ----------------------------------------------------------------------------

{
    is($YAML::XS::Boolean, undef,
        'loading File::SOPS does not set $YAML::XS::Boolean process-wide')
        or diag("YAML::XS::Boolean is '" . ($YAML::XS::Boolean // '') . "'");

    # And with it unset, YAML::XS behaves the way the caller configured it:
    # a bare true loads as a plain scalar, not as a JSON::PP::Boolean.
    my $loaded = YAML::XS::Load("b: true\n");
    ok(!ref $loaded->{b},
        'so a caller doing their own YAML::XS::Load gets their own semantics');
}

# ...while File::SOPS's own handling of booleans is unchanged, because it sets
# the variable around its own calls rather than globally.
{
    my $encrypted = File::SOPS->encrypt(
        data       => { t => JSON->true, f => JSON->false, flag_unencrypted => JSON->true },
        recipients => [$public],
        format     => 'yaml',
    );
    like($encrypted, qr/^flag_unencrypted: true$/m,
        'an unencrypted boolean is still emitted as a bare true');

    my $back = File::SOPS->decrypt(encrypted => $encrypted, identities => [$secret]);
    isa_ok($back->{t}, 'JSON::PP::Boolean', 'a decrypted true');
    isa_ok($back->{f}, 'JSON::PP::Boolean', 'a decrypted false');
    ok(!$back->{f}, 'and false is false');
    isa_ok($back->{flag_unencrypted}, 'JSON::PP::Boolean',
        'an unencrypted boolean read back from the document');
}

# decrypt_file writes booleans as YAML booleans, not as perl-scalar tags. It
# calls YAML::XS::Dump directly, so it used to depend on the global that was
# being set at load time.
{
    my $encrypted = File::SOPS->encrypt(
        data       => { t => JSON->true, s => 'x' },
        recipients => [$public],
        format     => 'yaml',
    );
    my $in  = "$tempdir/bool.enc.yaml";
    my $out = "$tempdir/bool.dec.yaml";
    open my $fh, '>:raw', $in or die $!;
    print $fh $encrypted;
    close $fh;

    File::SOPS->decrypt_file(input => $in, output => $out, identities => [$secret]);

    my $text = do { open my $r, '<:raw', $out or die $!; local $/; <$r> };
    like($text, qr/^t: true$/m, 'decrypt_file writes a boolean as a YAML boolean');
    unlike($text, qr/perl\/scalar/,
        'and not as a !!perl/scalar:JSON::PP::Boolean tag');
}

# ----------------------------------------------------------------------------
# (f) what File::SOPS's use-line order buys, checked in a virgin process.
# ----------------------------------------------------------------------------

# Runs $code in a fresh perl with this process's @INC and returns its stdout.
sub _in_a_fresh_perl {
    my ($code, @args) = @_;
    my @inc = map { "-I$_" } grep { !ref } @INC;
    open my $p, '-|', $^X, @inc, '-e', $code, @args
        or die "cannot fork a perl: $!";
    my $out = do { local $/; <$p> };
    close $p;
    return defined $out ? $out : '';
}

# JSON::MaybeXS binds its backend ONCE, to whichever of Cpanel::JSON::XS and
# JSON::XS is already in %INC when it is first loaded -- so whoever loads it
# first in a process decides it. File::SOPS::Encrypted loads CryptX, which
# loads JSON.pm and with it JSON::XS, so if File/SOPS.pm did not load
# JSON::MaybeXS ahead of that, JSON::MaybeXS would never get to state its own
# preference.
#
# This no longer reaches a document. k56 / docs/adr/0005 took the wire
# format out of JSON::MaybeXS's hands: Format::JSON names Cpanel::JSON::XS for
# the emitter and the parser, and t/23-json-backend.t is what pins that -- by
# comparing fresh child perls that loaded different backends first, which is
# the only way to see it. What is left here is that File::SOPS does not skew
# the process-wide choice for OTHER code that uses JSON::MaybeXS, which is
# worth keeping and is no longer a wire question.
{
    my $alone = _in_a_fresh_perl('use JSON::MaybeXS; print JSON::MaybeXS::JSON()');
    my $ours  = _in_a_fresh_perl('use File::SOPS; print JSON::MaybeXS::JSON()');

    ok(length $alone, 'a fresh perl reports a JSON::MaybeXS backend')
        or diag("got nothing back from the child perl");
    is($ours, $alone,
        'loading File::SOPS picks the same JSON backend JSON::MaybeXS would')
        or diag("File::SOPS gets '$ours', JSON::MaybeXS on its own gets "
              . "'$alone' -- File/SOPS.pm's use-line order let a dependency "
              . "pre-empt the choice, which changes emitted JSON");
}

# And decrypt hands back real JSON::PP::Boolean objects to a caller who loaded
# nothing but File::SOPS. The class comes from File::SOPS::Encrypted's own
# `use JSON::MaybeXS` -- the same file as the JSON->true call that needs it --
# so this holds however the use lines above it are reordered. The in-process
# checks earlier in this file cannot show it: this .t loads JSON::MaybeXS at
# the top.
{
    my $encrypted = File::SOPS->encrypt(
        data       => { t => JSON->true, f => JSON->false },
        recipients => [$public],
        format     => 'yaml',
    );
    my $enc_file = "$tempdir/fresh-bool.enc.yaml";
    my $key_file = "$tempdir/fresh-bool.key";
    for ([$enc_file, $encrypted], [$key_file, $secret]) {
        open my $fh, '>:raw', $_->[0] or die $!;
        print $fh $_->[1];
        close $fh;
    }

    my $out = _in_a_fresh_perl(<<'CHILD', $enc_file, $key_file);
use File::SOPS;
my ($enc_file, $key_file) = @ARGV;
my $slurp = sub { open my $r, '<:raw', $_[0] or die $!; local $/; <$r> };
my $back = File::SOPS->decrypt(
    encrypted  => $slurp->($enc_file),
    identities => [ $slurp->($key_file) ],
);
print join ',', ref($back->{t}), ref($back->{f}),
    ($back->{t} ? 'truthy' : 'falsey'), ($back->{f} ? 'truthy' : 'falsey');
CHILD

    is($out, 'JSON::PP::Boolean,JSON::PP::Boolean,truthy,falsey',
        'decrypt returns overloaded booleans to a process that loaded only File::SOPS')
        or diag("child perl printed '$out'");
}

done_testing;
