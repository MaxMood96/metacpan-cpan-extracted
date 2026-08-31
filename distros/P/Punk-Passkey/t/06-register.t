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
    # 0.29 for $c->origin: an older Punk has no canonical origin, and
    # the ceremony refuses to read the Host header instead. Naming the
    # version here means an old one SKIPS rather than failing on a
    # missing method, which would read as this dist's bug.
    plan skip_all => 'Punk 0.29+ is needed to drive a ceremony'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
}
use File::Raw::JSON qw(file_json_decode);

# The registration ceremony, end to end, against registration responses
# captured from real authenticators.
#
# Every one of these was produced by a real device answering a real
# challenge at a real origin, so the test app declares the origin the
# capture was made at and seeds the session with the challenge the
# capture answered. Nothing else is arranged: the attestation object,
# the clientDataJSON and the key inside them are exactly what the
# authenticator sent.
#
# The refusals matter more than the acceptance. A verifier that accepts
# a good response and also accepts a tampered one has not verified
# anything, so each named check gets an input that differs from the
# good one in exactly that respect.

# ---- an application, and a way to reach a context ---------------------------

our %CTX;
{
    package PKApp;
    use Punk;
    session secret => 'passkey-test-secret';
    host 'https://webauthn.io';

    # The ceremony runs inside a request, because it needs the session
    # and the origin. These routes are the "hand-written route" phase 1
    # is specified against - phase 3 generates them.
    post '/reg/options' => sub {
        my ($c) = @_;
        $CTX{options} = Punk::Passkey::register_options($c, $CTX{args});
        $c->json($CTX{options});
    };
    post '/reg' => sub {
        my ($c) = @_;
        # a test hook: put the challenge the capture answered where the
        # ceremony will look for it
        $c->session->{'punk.passkey.reg'} = {
            c => $CTX{seed}, exp => time + 300,
        } if defined $CTX{seed};
        $CTX{result} = Punk::Passkey::register($c, $CTX{body}, $CTX{args});
        $CTX{err}    = $Punk::Passkey::ERR;
        $CTX{session_after} = { %{ $c->session } };
        $c->text($CTX{result} ? 'ok' : 'no');
    };
}

{
    package LocalApp;                      # the yubikey capture's origin
    use Punk;
    session secret => 'passkey-test-secret';
    host 'http://localhost:9005';
    post '/reg' => sub {
        my ($c) = @_;
        $c->session->{'punk.passkey.reg'} = {
            c => $CTX{seed}, exp => time + 300,
        } if defined $CTX{seed};
        $CTX{result} = Punk::Passkey::register($c, $CTX{body}, $CTX{args});
        $CTX{err}    = $Punk::Passkey::ERR;
        $c->text($CTX{result} ? 'ok' : 'no');
    };
}

my %APP = (PKApp => PKApp->to_app, LocalApp => LocalApp->to_app);

sub hit {
    my ($app, $path, %o) = @_;
    my $body = '';
    open my $in, '<', \$body or die $!;
    return $APP{$app}->({
        REQUEST_METHOD => 'POST', PATH_INFO => $path, QUERY_STRING => '',
        CONTENT_LENGTH => 0, 'psgi.input' => $in,
        HTTP_HOST => $o{host} // 'webauthn.io',
        'psgi.url_scheme' => $o{scheme} // 'https',
        %{ $o{env} // {} },
    });
}

# Run one ceremony: seed the challenge, hand over the response.
sub ceremony {
    my (%o) = @_;
    %CTX = (seed => $o{challenge}, body => $o{body}, args => $o{args});
    hit($o{app} // 'PKApp', '/reg', %o);
    return ($CTX{result}, $CTX{err});
}

# The good response for a fixture, as the browser would send it.
sub response_for {
    my ($name) = @_;
    my $f = fixture($name);
    my $cd = file_json_decode(b64u_decode($f->{clientDataJSON}));
    return ({
        clientDataJSON    => $f->{clientDataJSON},
        attestationObject => $f->{attestationObject},
        transports        => ['internal'],
    }, $cd->{challenge}, $cd->{origin});
}

# ---- the options half --------------------------------------------------------

{
    %CTX = (args => { user_id => 'user-7', user_name => 'ada',
                      user_display_name => 'Ada L' });
    my $r = hit(PKApp => '/reg/options');
    is($r->[0], 200, 'the options route answers');
    my $o = file_json_decode(join '', @{ $r->[2] });

    is($o->{rp}{id}, 'webauthn.io',
        'the rpId is the host of the DECLARED origin - not the request, '
      . 'which is the check the whole ceremony rests on');
    is($o->{attestation}, 'none', 'the attestation stance is stated to the browser');
    is($o->{user}{name}, 'ada', 'the user name is the application\'s');
    is($o->{user}{displayName}, 'Ada L', 'and so is the display name');
    is(b64u_decode($o->{user}{id}), 'user-7', 'the user handle round-trips');
    is($o->{authenticatorSelection}{userVerification}, 'preferred',
        'user verification is preferred, not required - requiring it '
      . 'breaks real authenticators that real users already own');
    is($o->{authenticatorSelection}{residentKey}, 'preferred', 'as is residentKey');
    is_deeply([map { $_->{alg} } @{ $o->{pubKeyCredParams} }], [-7, -257],
        'ES256 first, RS256 behind it for Windows Hello');
    is(length b64u_decode($o->{challenge}), 32, 'the challenge is 32 bytes');
    is($o->{timeout}, 300000, 'the timeout matches the challenge lifetime');
    is_deeply($o->{excludeCredentials}, [], 'nothing is excluded by default');
}

{   # a second ask REPLACES the first, and differs from it
    %CTX = (args => { user_id => 'user-7' });
    my $a = file_json_decode(join '', @{ hit(PKApp => '/reg/options')->[2] });
    %CTX = (args => { user_id => 'user-7' });
    my $b = file_json_decode(join '', @{ hit(PKApp => '/reg/options')->[2] });
    isnt($a->{challenge}, $b->{challenge},
        'two asks produce different challenges - a fixed one would make '
      . 'every captured response replayable for ever');
}

{   # excludeCredentials, so the platform refuses a duplicate in its own UI
    %CTX = (args => { user_id => 'u', exclude => ['aaa', 'bbb'] });
    my $o = file_json_decode(join '', @{ hit(PKApp => '/reg/options')->[2] });
    is_deeply($o->{excludeCredentials},
        [ { type => 'public-key', id => 'aaa' },
          { type => 'public-key', id => 'bbb' } ],
        'the ids the user already has are offered for exclusion');
}

{   # a missing user_id is a programming error, not something to invent
    my $err = do {
        local $@;
        eval {
            %CTX = (args => {});
            hit(PKApp => '/reg/options');
        };
        $@;
    };
    my $r = hit(PKApp => '/reg/options');
    is($r->[0], 500,
        'options without a user_id fails loudly - only the application '
      . 'knows what an account is');
}

# ---- the ceremony, against real captures ------------------------------------

for my $case (
    { name => 'reg-none.txt',              app => 'PKApp',
      host => 'webauthn.io', scheme => 'https', fmt => 'none' },
    { name => 'reg-fido-u2f.txt',          app => 'PKApp',
      host => 'webauthn.io', scheme => 'https', fmt => 'fido-u2f' },
    { name => 'reg-packed-yubikey.txt',    app => 'LocalApp',
      host => 'localhost:9005', scheme => 'http', fmt => 'packed' },
) {
    subtest "$case->{name} registers" => sub {
        my ($body, $challenge, $origin) = response_for($case->{name});
        my ($cred, $err) = ceremony(
            app => $case->{app}, body => $body, challenge => $challenge,
            host => $case->{host}, scheme => $case->{scheme});

        ok($cred, 'a real captured registration is accepted') or diag $err;
        return unless $cred;

        is($cred->{fmt}, $case->{fmt}, "the attestation format is $case->{fmt}");
        ok(length $cred->{credential_id} > 0, 'a credential id came back');
        ok(length $cred->{public_key} > 40, 'and the COSE key, verbatim');
        is($cred->{alg}, -7, 'ES256, from the key itself');
        is(length b64u_decode($cred->{aaguid}), 16, 'the AAGUID is 16 bytes');
        is_deeply($cred->{transports}, ['internal'],
            'transports come through from the client, as a hint');
        ok(defined $cred->{sign_count}, 'and a sign count to start from');

        # the id and key are the ones inside authData, not a re-encoding
        my $att = Punk::Passkey::_decode_cbor(b64u_decode($body->{attestationObject}));
        my $ad  = auth_data($att->{authData});
        is($cred->{credential_id}, b64u_encode($ad->{credentialId}),
            'the credential id is the one the authenticator sent');
        is($cred->{public_key}, substr($ad->{cose}, 0, length $cred->{public_key}),
            'and the stored key is the COSE bytes as they arrived - stored '
          . 'as sent, re-checked on every login rather than trusted because '
          . 'it was acceptable once');
    };
}

# ---- one failing input per named check ---------------------------------------

my ($good, $good_challenge) = response_for('reg-none.txt');

sub mutate_cd {
    my ($change) = @_;
    my $cd = file_json_decode(b64u_decode($good->{clientDataJSON}));
    $change->($cd);
    # re-encode in the field order the browser uses; the ceremony reads
    # fields by name, so order is irrelevant to it
    my $json = sprintf '{"challenge":"%s","origin":"%s","type":"%s"}',
        $cd->{challenge}, $cd->{origin}, $cd->{type};
    return { %$good, clientDataJSON => b64u_encode($json) };
}

my @checks = (
    {   name => 'the type is not webauthn.create',
        body => sub { mutate_cd(sub { $_[0]{type} = 'webauthn.get' }) },
        why  => qr/type is not webauthn\.create/,
    },
    {   name => 'the challenge is not the one issued',
        body => sub { mutate_cd(sub { $_[0]{challenge} =~ tr/Ab/Ba/ }) },
        why  => qr/challenge does not match/,
    },
    {   name => 'the origin is a different site',
        body => sub { mutate_cd(sub { $_[0]{origin} = 'https://evil.example' }) },
        why  => qr/origin is not this application/,
    },
    {   name => 'the attestation object is not base64url of CBOR',
        # +{} and not {} - a bare brace here is parsed as a BLOCK, and
        # the sub then returns the flattened hash rather than a
        # reference to it
        body => sub { +{ %$good, attestationObject => b64u_encode('nonsense') } },
        # the phase-0 decoder's own refusal, surfaced through the
        # ceremony rather than replaced by a vaguer one
        why  => qr/past end|truncated|not a map|malformed/,
    },
    {   name => 'clientDataJSON is missing entirely',
        body => sub { my %b = %$good; delete $b{clientDataJSON}; \%b },
        why  => qr/missing clientDataJSON/,
    },
);

for my $c (@checks) {
    my ($cred, $err) = ceremony(body => $c->{body}->(),
                                challenge => $good_challenge);
    is($cred, undef, "refused: $c->{name}");
    like($err, $c->{why}, '...for the documented reason');
}

# ---- the checks that need the attestation object changed ---------------------
# authData is inside a CBOR byte string, so these rebuild the object
# with one field of authData altered - the rest of the document, and
# the key inside it, are still the authenticator's.

sub with_authdata {
    my ($change) = @_;
    my $att = b64u_decode($good->{attestationObject});
    my $i = index($att, 'authData');
    my $b = ord substr($att, $i + 8, 1);
    my ($len, $hdr);
    if    ($b == 0x58) { $len = ord substr($att, $i + 9, 1); $hdr = 2 }
    elsif ($b == 0x59) { $len = unpack 'n', substr($att, $i + 9, 2); $hdr = 3 }
    else { die 'unexpected authData header' }
    my $ad = substr($att, $i + 8 + $hdr, $len);
    $change->(\$ad);
    substr($att, $i + 8 + $hdr, $len) = $ad;
    return { %$good, attestationObject => b64u_encode($att) };
}

my @ad_checks = (
    {   name => 'the authenticator signed for a different relying party',
        make => sub { with_authdata(sub { substr(${$_[0]}, 0, 1) =
                          chr(ord(substr(${$_[0]}, 0, 1)) ^ 0xff) }) },
        why  => qr/different relying party/,
    },
    {   name => 'user presence was not set',
        make => sub { with_authdata(sub { substr(${$_[0]}, 32, 1) =
                          chr(ord(substr(${$_[0]}, 32, 1)) & ~0x01) }) },
        why  => qr/user presence/,
    },
    {   name => 'attested credential data is absent',
        make => sub { with_authdata(sub { substr(${$_[0]}, 32, 1) =
                          chr(ord(substr(${$_[0]}, 32, 1)) & ~0x40) }) },
        why  => qr/no attested credential data/,
    },
    {   name => 'the credential id length runs past the end',
        make => sub { with_authdata(sub { substr(${$_[0]}, 53, 2) =
                          pack 'n', 0xfff0 }) },
        why  => qr/runs past the end/,
    },
);

for my $c (@ad_checks) {
    my ($cred, $err) = ceremony(body => $c->{make}->(),
                                challenge => $good_challenge);
    is($cred, undef, "refused: $c->{name}");
    like($err, $c->{why}, '...for the documented reason');
}

# ---- user verification, only when the application asked ----------------------
{
    my ($cred, $err) = ceremony(body => $good, challenge => $good_challenge,
                                args => { user_verification => 'required' });
    # the `none` capture has UV clear
    is($cred, undef, 'UV required and not performed is refused');
    like($err, qr/user verification was required/, '...saying so');

    ($cred, $err) = ceremony(body => $good, challenge => $good_challenge,
                             args => { user_verification => 'preferred' });
    ok($cred, 'while the same response passes when it was only preferred');
}

# ---- the challenge is consumed on the FIRST attempt --------------------------
# The property that makes a captured response useless: a failed attempt
# must not leave the challenge answerable, or an attacker who can make
# the first attempt fail gets unlimited tries at the second.
{
    %CTX = (seed => $good_challenge, body => $good, args => undef);
    hit(PKApp => '/reg');
    ok($CTX{result}, 'the first attempt succeeds');
    ok(!exists $CTX{session_after}{'punk.passkey.reg'},
        'and the challenge is gone from the session afterwards');

    # a second attempt with the same response, and no reseeding
    %CTX = (seed => undef, body => $good, args => undef);
    hit(PKApp => '/reg');
    is($CTX{result}, undef, 'replaying the same response fails');
    like($CTX{err}, qr/no outstanding challenge/,
        '...on the challenge, before any other check - the response is '
      . 'still perfectly valid, and that is exactly why single use is '
      . 'the property that matters');
}

{   # a FAILED attempt consumes it too
    my $wrong = mutate_cd(sub { $_[0]{origin} = 'https://evil.example' });
    %CTX = (seed => $good_challenge, body => $wrong, args => undef);
    hit(PKApp => '/reg');
    is($CTX{result}, undef, 'a bad attempt fails');
    ok(!exists $CTX{session_after}{'punk.passkey.reg'},
        'and consumes the challenge as well - success or failure alike');

    %CTX = (seed => undef, body => $good, args => undef);
    hit(PKApp => '/reg');
    is($CTX{result}, undef,
        'so the good response cannot be presented after a failed try');
}

{   # an expired challenge
    package ExpApp;
    use Punk;
    session secret => 'passkey-test-secret';
    host 'https://webauthn.io';
    post '/reg' => sub {
        my ($c) = @_;
        $c->session->{'punk.passkey.reg'} =
            { c => $CTX{seed}, exp => time - 1 };
        $CTX{result} = Punk::Passkey::register($c, $CTX{body});
        $CTX{err} = $Punk::Passkey::ERR;
        $c->text('done');
    };
    package main;
    $APP{ExpApp} = ExpApp->to_app;
    %CTX = (seed => $good_challenge, body => $good);
    hit(ExpApp => '/reg');
    is($CTX{result}, undef, 'an expired challenge is refused');
    like($CTX{err}, qr/expired|no outstanding/, '...as expired');
}

# ---- the attestation hook ----------------------------------------------------
{
    my @seen;
    my ($cred) = ceremony(body => $good, challenge => $good_challenge,
        args => { verify_attestation => sub { @seen = @_; 1 } });
    ok($cred, 'a hook returning true lets the ceremony finish');
    is($seen[0], 'none', 'and is handed the attestation format');

    my ($no, $err) = ceremony(body => $good, challenge => $good_challenge,
        args => { verify_attestation => sub { 0 } });
    is($no, undef, 'a hook returning false refuses the registration');
    like($err, qr/verify_attestation refused/, '...saying which hook did it');
}

# ---- no host declared --------------------------------------------------------
{
    package NoHostApp;
    use Punk;
    session secret => 'passkey-test-secret';
    post '/reg' => sub {
        my ($c) = @_;
        $CTX{result} = eval {
            Punk::Passkey::register_options($c, { user_id => 'x' }) };
        $CTX{err} = $@;
        $c->text('done');
    };
    package main;
    $APP{NoHostApp} = NoHostApp->to_app;
    %CTX = ();
    hit(NoHostApp => '/reg');
    is($CTX{result}, undef, 'without a declared host the ceremony refuses to start');
    like($CTX{err}, qr/declare the `host` keyword/,
        '...naming what to add, rather than defaulting to the request - '
      . 'which is the whole class of bug the origin check exists for');
}

done_testing;
