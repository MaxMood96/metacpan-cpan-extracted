use Test::More;
use Test::Deep;
use Try::Tiny;
use lib 't/lib';

BEGIN {   
    use_ok('Crypt::JWS::OpenSSL');
}

## using canonical JSON ordering for tests. DON'T do this in production
our $handler = Crypt::JWS::OpenSSL->new('JSON' => JSON::MaybeXS->new->canonical->utf8(1));

my $claims = {
    'sub'   => 'Test subject',
    'roles' => 'testrole',
    'exp'   => 1786935249,
    'iss'   => 'this/test/file'
};

my $conf = { algo => 'HS512', secret => 't/keys/hmac_512.secret', bits => 512 };

my $algo = $conf->{algo};
my $secret = $handler->decode_base64(load_key($conf->{secret}));


$handler->throw_errors(0);

my $token = $handler->encode(
    claims      => $claims,
    header      => { alg => $algo, typ => 'JWT' }
);

is($token, undef, 'encode - token is undef for missing secret');
is($handler->last_error, 'Missing or invalid secret for signing', 'encode - last error for missing secret');

$handler->throw_errors(1);

$token = try {
    return $handler->encode(
        claims      => $claims,
        header      => { alg => $algo, typ => 'JWT' }
    );
} catch {
    like($_, qr(^Missing or invalid secret for signing), 'encode throw - last error for missing secret');
    return undef;
};

is($token, undef, 'encode throw - token is undef for missing secret');

$handler->throw_errors(0);

$token = $handler->encode(
    secret      => 'abc',
    claims      => $claims,
    header      => { alg => $algo, typ => 'JWT' }
);

is($token, undef, 'encode - token is undef for short secret');
is($handler->last_error, 'Missing or invalid secret for signing', 'encode - last error for short secret');

$handler->throw_errors(1);

$token = try {
    return $handler->encode(
        secret      => 'abc',
        claims      => $claims,
        header      => { alg => $algo, typ => 'JWT' }
    );
} catch {
    like($_, qr(^Missing or invalid secret for signing), 'encode throw - last error for short secret');
    return undef;
};

is($token, undef, 'encode throw - token is undef for short secret');

$handler->throw_errors(0);

$token = $handler->encode(
    secret      => $secret,
    claims      => $claims,
    header      => 'blah'
);

is($token, undef, 'encode - token is undef for invalid header');
is($handler->last_error, 'Missing or invalid header argument', 'encode - last error invalid header');

$handler->throw_errors(1);

$token = try {
    return $handler->encode(
        secret      => $secret,
        claims      => $claims,
        header      => 'blah'
    );
} catch {
    like($_, qr(^Missing or invalid header argument), 'encode throw - last error invalid header');
    return undef;
};

is($token, undef, 'encode throw - last error invalid header');

$handler->throw_errors(0);

$token = $handler->encode(
    secret      => $secret,
    claims      => $claims,
    header      => { alg => 'TRIPPY', typ => 'JWT' }
);

is($token, undef, 'encode - algorithm unsupported');
is($handler->last_error, 'Algorithm "TRIPPY" is not supported', 'encode - last error unsupported algorithm');

$handler->throw_errors(1);

$token = try {
    return $handler->encode(
        secret      => $secret,
        claims      => $claims,
        header      => { alg => 'TRIPPY', typ => 'JWT' }
    );
} catch {
    like($_, qr(^Algorithm "TRIPPY" is not supported), 'encode throw - last error unsupported algorithm');
    return undef;
};

is($token, undef, 'encode throw - algorithm unsupported');

$handler->throw_errors(0);

$token = $handler->encode(
    secret      => $secret,
    claims      => 'blah',
    header      => { alg => $algo, typ => 'JWT' }
);

is($token, undef, 'encode - bad claims argument');
is($handler->last_error, 'Missing or invalid claims argument', 'encode - bad claims argument');

$handler->throw_errors(1);

$token = try {
    return $handler->encode(
        secret      => $secret,
        claims      => 'blah',
        header      => { alg => $algo, typ => 'JWT' }
    );
} catch {
    like($_, qr(^Missing or invalid claims argument), 'encode throw - bad claims argument');
    return undef;
};

is($token, undef, 'encode throw - bad claims argument');

$handler->throw_errors(0);

$token = $handler->encode(
    secret      => $secret,
    claims      => {},
    header      => { alg => $algo, typ => 'JWT' }
);

is($token, undef, 'encode - empty claims hash');
is($handler->last_error, 'Missing or invalid claims argument', 'encode - empty claims hash');

$handler->throw_errors(1);

$token = try {
    return $handler->encode(
        secret      => $secret,
        claims      => {},
        header      => { alg => $algo, typ => 'JWT' }
    );
} catch {
    like($_, qr(^Missing or invalid claims argument), 'encode throw - empty claims hash');
    return undef;
};

is($token, undef, 'encode throw - empty claims hash');

$handler->throw_errors(0);

my $dufftoken = 'ab.cd';

my $decoded = $handler->decode_unverified( token  => $dufftoken );

is($decoded, undef, 'decode - 2 segments in token');
is($handler->last_error, 'Invalid number of segments( 2 ) in token', 'decode - 2 segments in token');

$handler->throw_errors(1);

my $match = quotemeta('Invalid number of segments( 2 ) in token');

$decoded = try {
    return $handler->decode_unverified( token  => $dufftoken );
} catch {
    like($_, qr(^${match}), 'decode throw - 2 segments in token');
    return undef;
};

is($decoded, undef, 'decode throw - 2 segments in token');

$handler->throw_errors(0);

$dufftoken = 'abcdefgh.abcdefgh.abcdefgh';

$decoded = $handler->decode_unverified( token  => $dufftoken );

is($decoded, undef, 'decode - bad token');
like($handler->last_error, qr(^Error decoding token : ) , 'decode - bad token');

$handler->throw_errors(1);

$decoded = try {
    return $handler->decode_unverified( token  => $dufftoken );
} catch {
    like($_, qr(^Error decoding token : ), 'decode throw - bad token');
    return undef;
};

is($decoded, undef, 'decode throw - bad token');

$handler->throw_errors(0);

done_testing;

sub load_key {
    my $filepath = shift;
    open(my $fh, '<:encoding(UTF-8)', $filepath) or die "Could not open '$filepath': $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    return $content;
}

sub random_byte_base64_signature {
    $bits = shift;
    
    my $size = ( $bits % 8 )
        ? int( $bits / 8) + 1
        : $bits / 8;
        
    my $octets = '';
    for (1 .. $size) {
        $octets .= chr(int(rand(256)));
    }
    
    return Crypt::JWS::OpenSSL->encode_jwt_signature($octets);
}



1;
