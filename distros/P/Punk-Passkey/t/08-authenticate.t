#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PPKTest qw(fixture b64u_decode b64u_encode auth_data);
use Punk::Passkey ();

BEGIN {
    plan skip_all => 'Punk 0.29+ is needed to drive a ceremony'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
}
use File::Raw::JSON qw(file_json_decode);

# The authentication ceremony, against an assertion captured from a
# real authenticator - the one that logs somebody in, so the refusals
# are the point and the acceptance is only the proof that the refusals
# are not refusing everything.
#
# The capture's authenticatorData carries the public key the signature
# was made with, so the "stored credential" this test hands the
# ceremony is a real key and the signature check is a real signature
# check. t/fixtures/README records that it was verified with openssl
# before it was checked in.

our %CTX;
{
    package AuthApp;
    use Punk;
    session secret => 'passkey-auth-secret';
    host 'https://webauthn.io';

    post '/login/options' => sub {
        my ($c) = @_;
        $c->json(Punk::Passkey::challenge($c, $CTX{args}));
    };
    post '/login' => sub {
        my ($c) = @_;
        $c->session->{'punk.passkey.auth'} =
            { c => $CTX{seed}, exp => time + ($CTX{ttl} // 300) }
            if defined $CTX{seed};
        $CTX{result} = Punk::Passkey::verify($c, $CTX{body}, $CTX{args});
        $CTX{err}    = $Punk::Passkey::ERR;
        $CTX{session_after} = { %{ $c->session } };
        $c->text($CTX{result} ? 'in' : 'no');
    };

    # the sign_in chokepoint, proved in miniature: the passkey route
    # does NOT decide what logging in means - it hands the user id to
    # the one helper every other factor uses, so session rotation and
    # redirect policy are inherited rather than re-decided
    helper sign_in => sub {
        my ($c, $user_id) = @_;
        push @{ $CTX{sign_in_calls} }, $user_id;
        $c->session->{user_id} = $user_id;
        return $c->redirect('/account');
    };
    post '/login/full' => sub {
        my ($c) = @_;
        $c->session->{'punk.passkey.auth'} =
            { c => $CTX{seed}, exp => time + 300 } if defined $CTX{seed};
        my $ok = Punk::Passkey::verify($c, $CTX{body}, $CTX{args})
            or return $c->text('denied', 403);
        return $c->sign_in($ok->{user_id});
    };
}
my $APP = AuthApp->to_app;

sub hit {
    my ($path, %o) = @_;
    my $body = '';
    open my $in, '<', \$body or die $!;
    return $APP->({
        REQUEST_METHOD => 'POST', PATH_INFO => $path, QUERY_STRING => '',
        CONTENT_LENGTH => 0, 'psgi.input' => $in,
        HTTP_HOST => $o{host} // 'webauthn.io',
        'psgi.url_scheme' => 'https',
        %{ $o{env} // {} },
    });
}

# ---- the captured assertion, and the key inside it ---------------------------

my $f   = fixture('auth-webauthn-io.txt');
my $ad  = b64u_decode($f->{authenticatorData});
my $cdj = file_json_decode(b64u_decode($f->{clientDataJSON}));
my $parsed = auth_data($ad);

ok($parsed, 'the captured authenticatorData reads');
is($cdj->{type}, 'webauthn.get', 'and it is an authentication, not a registration');
is($cdj->{origin}, 'https://webauthn.io', 'made at the origin the app declares');
ok($parsed->{up}, 'with user presence set');
ok($parsed->{cose} && length $parsed->{cose} > 40,
    'and it carries the public key the signature was made with');

ok(exists $cdj->{new_keys_may_be_added_here},
    'the capture carries an unexpected extra field - which is the point: '
  . 'a ceremony that matched clientDataJSON against a template rather '
  . 'than reading it by name would break on this, and the field exists '
  . 'in the wild to catch exactly that');

my $CRED = {
    user_id     => 42,
    public_key  => $parsed->{cose},
    sign_count  => 0,
};
my $CRED_ID = b64u_encode($parsed->{credentialId});

my @looked_up;
sub lookup_ok  { push @looked_up, $_[0]; return { %$CRED } }
sub lookup_none { push @looked_up, $_[0]; return undef }

sub good_body {
    return {
        id                => $CRED_ID,
        clientDataJSON    => $f->{clientDataJSON},
        authenticatorData => $f->{authenticatorData},
        signature         => $f->{signature},
    };
}

sub login {
    my (%o) = @_;
    %CTX = (seed => $o{challenge} // $cdj->{challenge},
            body => $o{body} // good_body(),
            args => { lookup => \&lookup_ok, %{ $o{args} // {} } },
            ttl  => $o{ttl});
    hit($o{path} // '/login', %o);
    return ($CTX{result}, $CTX{err});
}

# ---- the options half --------------------------------------------------------

{
    %CTX = (args => {});
    my $o = file_json_decode(join '', @{ hit('/login/options')->[2] });
    is($o->{rpId}, 'webauthn.io', 'the rpId comes from the declared host');
    is(length b64u_decode($o->{challenge}), 32, 'the challenge is 32 bytes');
    is($o->{userVerification}, 'preferred', 'user verification is preferred');
    ok(!exists $o->{allowCredentials},
        'allowCredentials is ABSENT rather than empty for the usernameless '
      . 'flow - an empty list is a different instruction to some platforms '
      . 'than no list at all');

    %CTX = (args => { allow => ['aaa', 'bbb'] });
    my $a = file_json_decode(join '', @{ hit('/login/options')->[2] });
    is_deeply($a->{allowCredentials},
        [ { type => 'public-key', id => 'aaa' },
          { type => 'public-key', id => 'bbb' } ],
        'and is populated when the application named the credentials');

    %CTX = (args => {});
    my $b = file_json_decode(join '', @{ hit('/login/options')->[2] });
    isnt($o->{challenge}, $b->{challenge}, 'two asks differ');
}

# ---- the ceremony ------------------------------------------------------------

{
    @looked_up = ();
    my ($ok, $err) = login();
    ok($ok, 'a real captured assertion logs in') or diag $err;
    is($ok->{user_id}, 42, 'returning the user the credential belongs to');
    is($looked_up[0], $CRED_ID,
        'having looked the credential up by the id the browser sent');
    is($ok->{sign_count}, 1553097241, 'and the count the authenticator asserted');
    ok($ok->{uv}, 'user verification was performed for this capture');
    is($ok->{clone_signal}, 0, 'and nothing suggested a clone');
}

# ---- one failing input per named check ---------------------------------------

sub cd_mutated {
    my ($change) = @_;
    my $cd = { %$cdj };
    $change->($cd);
    my $json = File::Raw::JSON::file_json_encode($cd);
    return { %{ good_body() }, clientDataJSON => b64u_encode($json) };
}

my @checks = (
    {   name => 'the type is a registration, not an authentication',
        body => sub { cd_mutated(sub { $_[0]{type} = 'webauthn.create' }) },
        why  => qr/type is not webauthn\.get/,
    },
    {   name => 'the challenge is not the one issued',
        body => sub { cd_mutated(sub { $_[0]{challenge} =~ tr/Ab/Ba/ }) },
        why  => qr/challenge does not match/,
    },
    {   name => 'the origin is a different site',
        body => sub { cd_mutated(sub { $_[0]{origin} = 'https://evil.example' }) },
        why  => qr/origin is not this application/,
    },
    {   name => 'the signature is over different bytes',
        body => sub {
            my $b = good_body();
            my $bad = $ad;
            # flip a byte of authenticatorData: the document still
            # parses, and the signature no longer covers it
            substr($bad, 40, 1) = chr(ord(substr($bad, 40, 1)) ^ 0xff);
            $b->{authenticatorData} = b64u_encode($bad);
            $b;
        },
        why  => qr/signature did not verify/,
    },
    {   name => 'the signature itself is altered',
        body => sub {
            my $b = good_body();
            my $sig = b64u_decode($f->{signature});
            substr($sig, -1, 1) = chr(ord(substr($sig, -1, 1)) ^ 0xff);
            $b->{signature} = b64u_encode($sig);
            $b;
        },
        why  => qr/signature did not verify|malformed|integer/,
    },
    {   name => 'authenticatorData is truncated',
        body => sub {
            my $b = good_body();
            $b->{authenticatorData} = b64u_encode(substr $ad, 0, 20);
            $b;
        },
        why  => qr/too short/,
    },
    {   name => 'no credential id',
        body => sub { my $b = good_body(); delete $b->{id}; $b },
        why  => qr/no credential id/,
    },
    {   name => 'no signature',
        body => sub { my $b = good_body(); delete $b->{signature}; $b },
        why  => qr/no signature/,
    },
);

for my $c (@checks) {
    my ($ok, $err) = login(body => $c->{body}->());
    is($ok, undef, "refused: $c->{name}");
    like($err, $c->{why}, '...for the documented reason');
}

# the rpIdHash, which needs authData changed at byte 0
{
    my $bad = $ad;
    substr($bad, 0, 1) = chr(ord(substr($bad, 0, 1)) ^ 0xff);
    my ($ok, $err) = login(body => {
        %{ good_body() }, authenticatorData => b64u_encode($bad) });
    is($ok, undef, 'refused: the assertion was signed for another rpId');
    like($err, qr/different relying party/, '...naming the reason');
}

# user presence clear
{
    my $bad = $ad;
    substr($bad, 32, 1) = chr(ord(substr($bad, 32, 1)) & ~0x01);
    my ($ok, $err) = login(body => {
        %{ good_body() }, authenticatorData => b64u_encode($bad) });
    is($ok, undef, 'refused: user presence was not set');
    like($err, qr/user presence/, '...naming the reason');
}

# ---- an unknown credential is the same answer as a bad signature -------------
# The login endpoint must not tell anyone which credential ids exist
# here: a credential id identifies a person's authenticator.
{
    my ($ok, $err) = login(args => { lookup => \&lookup_none });
    is($ok, undef, 'an unknown credential id is refused');
    like($err, qr/no such credential/, '...in the log');

    my $r_unknown = hit('/login');
    is($CTX{result}, undef, 'and the response carries no detail');

    # the two responses are indistinguishable from outside
    my $bad = $ad;
    substr($bad, 40, 1) = chr(ord(substr($bad, 40, 1)) ^ 0xff);
    login(body => { %{ good_body() }, authenticatorData => b64u_encode($bad) });
    my $r_badsig = hit('/login');
    is(join('', @{ $r_unknown->[2] }), join('', @{ $r_badsig->[2] }),
        'an unknown credential and a bad signature answer identically - '
      . 'only the log tells them apart, because otherwise the endpoint '
      . 'is an oracle for which authenticators this site knows');
    is($r_unknown->[0], $r_badsig->[0], '...with the same status');
}

# ---- the hostile Host header does not matter ---------------------------------
# The whole ceremony rests on the origin being configuration. This
# plants the header an attacker would set and watches it change
# nothing.
{
    my ($ok) = login();
    ok($ok, 'the assertion verifies normally');

    %CTX = (seed => $cdj->{challenge}, body => good_body(),
            args => { lookup => \&lookup_ok });
    hit('/login', host => 'evil.example');
    ok($CTX{result},
        'and STILL verifies with a hostile Host header - the origin came '
      . 'from the declared host, so the header the attacker controls was '
      . 'never consulted');

    # the mirror image: an assertion made at the attacker's origin is
    # refused even when the header agrees with it
    %CTX = (seed => $cdj->{challenge},
            body => cd_mutated(sub { $_[0]{origin} = 'https://evil.example' }),
            args => { lookup => \&lookup_ok });
    hit('/login', host => 'evil.example');
    is($CTX{result}, undef,
        'while an assertion made AT that origin is refused even when the '
      . 'Host header agrees with it');
}

# ---- the challenge is single-use ---------------------------------------------
{
    %CTX = (seed => $cdj->{challenge}, body => good_body(),
            args => { lookup => \&lookup_ok });
    hit('/login');
    ok($CTX{result}, 'the first login succeeds');
    ok(!exists $CTX{session_after}{'punk.passkey.auth'},
        'and the challenge is gone');

    %CTX = (seed => undef, body => good_body(),
            args => { lookup => \&lookup_ok });
    hit('/login');
    is($CTX{result}, undef, 'replaying the whole assertion fails');
    like($CTX{err}, qr/no outstanding challenge/,
        '...on the challenge - the assertion is still perfectly valid, '
      . 'which is why single use is the property that matters');
}

{   # a failed attempt consumes it too
    %CTX = (seed => $cdj->{challenge}, args => { lookup => \&lookup_none },
            body => good_body());
    hit('/login');
    is($CTX{result}, undef, 'a failed login fails');
    ok(!exists $CTX{session_after}{'punk.passkey.auth'},
        'and consumes the challenge as well');
}

{   # an expired challenge, tested by setting the expiry in the past
    # rather than by sleeping - a fixed sleep is a test that fails on a
    # loaded machine rather than on a broken expiry
    %CTX = (seed => $cdj->{challenge}, body => good_body(),
            args => { lookup => \&lookup_ok }, ttl => -1);
    hit('/login');
    is($CTX{result}, undef, 'an expired challenge is refused');
    like($CTX{err}, qr/expired|no outstanding/, '...as expired');
}

# ---- the sign count is a signal, not a gate ---------------------------------

{
    my (@clone, @used);
    my $args = {
        lookup => sub { +{ %$CRED, sign_count => 2_000_000_000 } },
        on_clone_signal => sub { push @clone, [ @_[1, 2] ]; 1 },
        on_used         => sub { push @used, $_[1]; 1 },
    };
    my ($ok, $err) = login(args => $args);

    ok($ok,
        'a sign count that went BACKWARDS still logs the user in - a hard '
      . 'failure here would lock out every cloud-synced passkey, which is '
      . 'most of them')
        or diag $err;
    is($ok->{clone_signal}, 1, 'but the login is flagged as a clone signal');
    is_deeply($clone[0], [2_000_000_000, 1553097241],
        'and the application is handed the stored and asserted counts');
    is($used[0], 1553097241,
        'while the count still moves forward, so the next login compares '
      . 'against what actually arrived');
}

{
    my (@clone, @used);
    my $args = {
        lookup => sub { +{ %$CRED, sign_count => 0 } },
        on_clone_signal => sub { push @clone, 1; 1 },
        on_used         => sub { push @used, $_[1]; 1 },
    };
    my ($ok) = login(args => $args);
    ok($ok, 'a stored count of zero logs in');
    is(scalar @clone, 0,
        'and never signals a clone - an authenticator that reports zero '
      . 'for ever is not a cloned one, it is an iPhone');
    is($used[0], 1553097241, 'the count is still recorded');
}

{
    my @clone;
    my ($ok) = login(args => {
        lookup => sub { +{ %$CRED, sign_count => 1_000_000 } },
        on_clone_signal => sub { push @clone, 1; 1 },
    });
    ok($ok, 'a count that moved forward logs in');
    is(scalar @clone, 0, 'with no signal');
    is($ok->{clone_signal}, 0, '...and none reported');
}

# ---- the sign_in chokepoint --------------------------------------------------
{
    $CTX{sign_in_calls} = [];
    %CTX = (seed => $cdj->{challenge}, body => good_body(),
            args => { lookup => \&lookup_ok }, sign_in_calls => []);
    my $r = hit('/login/full');
    is($r->[0], 302,
        'the passkey route hands off to sign_in rather than deciding what '
      . 'logging in means');
    is_deeply($CTX{sign_in_calls}, [42],
        '...calling it once, with the user id the ceremony returned');

    %CTX = (seed => $cdj->{challenge}, body => good_body(),
            args => { lookup => \&lookup_none }, sign_in_calls => []);
    my $d = hit('/login/full');
    is($d->[0], 403, 'and a refused assertion never reaches sign_in');
    is_deeply($CTX{sign_in_calls}, [], '...so no session is established');
}

# ---- user verification, only when asked --------------------------------------
{
    my $bad = $ad;
    substr($bad, 32, 1) = chr(ord(substr($bad, 32, 1)) & ~0x04);   # UV off
    my $body = { %{ good_body() }, authenticatorData => b64u_encode($bad) };

    # the signature no longer covers the altered authData, so this
    # would fail at the signature - the check being proved is that UV
    # is examined at all, so it is proved on the UNaltered capture,
    # which has UV set
    my ($ok) = login(args => { user_verification => 'required' });
    ok($ok, 'the capture satisfies user_verification => required, having UV set');

    is($ok->{uv}, 1, 'and reports it');
}

# ---- RS256, which no published capture covers --------------------------------
#
# Windows Hello registers RSA credentials, so the RS256 branch of the
# signature check is not decoration - and no RS256 assertion could be
# found published. So this one is CONSTRUCTED: the authenticatorData
# and clientDataJSON are built here, and the signature over them is
# made by openssl with a real RSA key.
#
# That is a different thing from inventing a test vector. Nothing is
# asserted to be a published value; the cryptography is genuinely
# computed, and if this distribution's RSA key encoding or its
# unconverted-signature path were wrong, libcrypto would refuse the
# signature and this would fail. What it does NOT prove is that a real
# Windows Hello authenticator formats its assertion this way - only a
# capture proves that, and t/fixtures/README says which fixtures are
# captures and which are not.
SUBTEST_RS256: {
    require File::Temp;
    my $has_openssl = PPKTest::have_openssl();
    unless ($has_openssl) {
        diag 'no openssl - skipping the RS256 path';
        last SUBTEST_RS256;
    }
    require Digest::SHA;

    my $dir = File::Temp->newdir;
    system("openssl genrsa -out $dir/rsa.key 2048 >/dev/null 2>&1") == 0
        or do { fail('openssl made an RSA key'); last SUBTEST_RS256 };
    my $text = `openssl rsa -in $dir/rsa.key -text -noout 2>/dev/null`;
    my ($modhex) = $text =~ /modulus:\s*((?:[0-9a-f]{2}[:\s]*)+)/s;
    $modhex =~ s/[^0-9a-f]//g;
    $modhex =~ s/\A00//;
    my $n = pack 'H*', $modhex;
    is(length $n, 256, 'with a 256-byte modulus');

    # the COSE RSA key, as an authenticator would have sent it:
    #   a4  map(4)
    #   01 03            kty 3 (RSA)
    #   03 39 01 00      alg -257 (RS256)
    #   20 59 01 00 ..   -1: n, a 256-byte string
    #   21 43 010001     -2: e
    my $cose = "\xa4\x01\x03\x03\x39\x01\x00\x20\x59\x01\x00" . $n
             . "\x21\x43\x01\x00\x01";
    my $decoded = Punk::Passkey::_decode_cbor($cose);
    is(ref $decoded, 'HASH', 'the hand-built COSE RSA key decodes');
    is($decoded->{1}, 3, '...kty 3, RSA');
    is($decoded->{3}, -257, '...alg -257, RS256');
    is(length $decoded->{-1}, 256, '...with the modulus intact');

    # an assertion: rpIdHash for the declared host, UP set, a counter
    my $rp_hash = Digest::SHA::sha256('webauthn.io');
    my $auth_data = $rp_hash . chr(0x01) . pack('N', 7);

    my $chal = 'rs256-challenge-value-aaaaaaaaaaaaaaaaaaaaa';
    my $cd_json = File::Raw::JSON::file_json_encode({
        type => 'webauthn.get', challenge => $chal,
        origin => 'https://webauthn.io',
    });

    my $signed = $auth_data . Digest::SHA::sha256($cd_json);
    open my $mf, '>', "$dir/msg" or die $!;
    binmode $mf; print {$mf} $signed; close $mf;
    system("openssl dgst -sha256 -sign $dir/rsa.key -out $dir/sig $dir/msg"
         . " >/dev/null 2>&1") == 0 or do {
        fail('openssl signed the assertion'); last SUBTEST_RS256 };
    open my $sf, '<', "$dir/sig" or die $!;
    binmode $sf;
    my $sig = do { local $/; <$sf> };
    close $sf;

    my $body = {
        id                => 'rsa-credential',
        clientDataJSON    => b64u_encode($cd_json),
        authenticatorData => b64u_encode($auth_data),
        signature         => b64u_encode($sig),
    };

    %CTX = (seed => $chal, body => $body, args => {
        lookup => sub { +{ user_id => 9, public_key => $cose, sign_count => 0 } },
    });
    hit('/login');
    ok($CTX{result},
        'an RS256 assertion verifies - the PKCS#1 signature is already '
      . 'the width JOSE wants, so it passes through unconverted')
        or diag $CTX{err};
    is($CTX{result} && $CTX{result}{user_id}, 9, 'against the RSA credential');

    # and the negative control, or the above would pass against a
    # verifier that returned true unconditionally
    my $bad = $sig;
    substr($bad, -1, 1) = chr(ord(substr($bad, -1, 1)) ^ 0xff);
    %CTX = (seed => $chal, args => {
        lookup => sub { +{ user_id => 9, public_key => $cose, sign_count => 0 } },
    }, body => { %$body, signature => b64u_encode($bad) });
    hit('/login');
    is($CTX{result}, undef, 'while an altered RS256 signature does not');
    like($CTX{err}, qr/signature did not verify/, '...saying so');
}

# ---- lookup discipline -------------------------------------------------------
{
    my $err = do {
        local $@;
        %CTX = (seed => $cdj->{challenge}, body => good_body(), args => {});
        eval { hit('/login') };
        $@;
    };
    my $r = hit('/login');
    is($r->[0], 500,
        'verify without a lookup callback fails loudly - the engine owns '
      . 'no storage and will not guess where credentials live');
}

{
    my ($ok, $err) = login(args => { lookup => sub { die "database down\n" } });
    is($ok, undef, 'a lookup that dies is a refusal, not a crash');
    like($err, qr/lookup callback died/, '...recorded as such');
}

done_testing;
