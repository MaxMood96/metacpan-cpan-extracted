use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
use Punk::TOTP;

# The provisioning URI - where a subtly wrong byte enrols the account
# under the wrong name and the user finds out weeks later - and secret
# generation.

my $secret = Punk::TOTP->b32_encode('12345678901234567890');

# --- the URI ----------------------------------------------------------------
{
    my $uri = Punk::TOTP->uri($secret,
        issuer => 'openapi-proxy.com', account => 'alice@example.com');

    is $uri,
       'otpauth://totp/openapi-proxy.com:alice%40example.com'
     . "?secret=$secret&issuer=openapi-proxy.com",
       'the default URI: label colon bare, @ encoded, defaults omitted';

    like $uri, qr{^otpauth://totp/[^:]+:}, 'the label colon is a colon';
    unlike $uri, qr/%3A/i, 'and never percent-encoded';
}

{
    my $uri = Punk::TOTP->uri($secret,
        issuer  => 'Ex & Co',
        account => 'bob+2fa@example.com',
        algorithm => 'sha256', digits => 8, period => 60);

    like $uri, qr{/Ex%20%26%20Co:}, 'issuer encodes in the label';
    like $uri, qr{issuer=Ex%20%26%20Co}, 'and in the parameter';
    like $uri, qr{bob%2B2fa%40example\.com\?}, 'account encodes fully';
    like $uri, qr{&algorithm=SHA256}, 'non-default algorithm included';
    like $uri, qr{&digits=8}, 'non-default digits included';
    like $uri, qr{&period=60}, 'non-default period included';
}

{
    my $err = do {
        local $@;
        eval { Punk::TOTP->uri($secret, issuer => 'x') };
        $@;
    };
    like $err, qr/needs both issuer and account/, 'account required';

    $err = do {
        local $@;
        eval { Punk::TOTP->uri('not!base32',
                               issuer => 'x', account => 'y') };
        $@;
    };
    like $err, qr/not valid base32/,
        'an undecodable secret is refused before it is advertised';
}

# --- secrets ----------------------------------------------------------------
{
    my %len = (sha1 => 20, sha256 => 32, sha512 => 64);
    for my $alg (sort keys %len) {
        my $s = Punk::TOTP->secret(algorithm => $alg);
        is length Punk::TOTP->b32_decode($s), $len{$alg},
            "$alg secret is $len{$alg} bytes and decodes";
    }

    is length Punk::TOTP->b32_decode(Punk::TOTP->secret(bytes => 24)),
        24, 'bytes overrides';

    isnt +Punk::TOTP->secret, Punk::TOTP->secret,
        'two secrets differ';

    my $err = do {
        local $@;
        eval { Punk::TOTP->secret(bytes => 8) };
        $@;
    };
    like $err, qr/bytes must be 16 to/, 'a short secret refuses';
}

# --- option validation ------------------------------------------------------
for my $case (
    [ sub { Punk::TOTP->code($secret, wibble => 1) },
      qr/unknown code option 'wibble'/,           'unknown option' ],
    [ sub { Punk::TOTP->code($secret, 'odd') },
      qr/odd number of options given to code/,    'odd options' ],
    [ sub { Punk::TOTP->code($secret, algorithm => 'md5') },
      qr/algorithm must be sha1, sha256 or sha512/, 'md5 refused' ],
    [ sub { Punk::TOTP->code($secret, digits => 5) },
      qr/digits must be 6, 7 or 8/,               'digits floor' ],
    [ sub { Punk::TOTP->code($secret, digits => 9) },
      qr/digits must be 6, 7 or 8/,               'digits ceiling' ],
    [ sub { Punk::TOTP->code($secret, period => 0) },
      qr/period must be 1 to 300/,                'period floor' ],
    [ sub { Punk::TOTP->verify($secret, '123456', skew => 11) },
      qr/skew must be 0 to 10/,                   'skew ceiling' ],
) {
    my ($cb, $re, $name) = @$case;
    my $err = do { local $@; eval { $cb->() }; $@ };
    like $err, $re, $name;
}

done_testing;
