use Test::More;
use Test::Deep;
use JSON::MaybeXS 1.002002 ();
use lib 't/lib';

BEGIN {   
    use_ok('Crypt::JWS::OpenSSL');
}

## using canonical JSON ordering for tests. DON'T do this in production
our $handler = Crypt::JWS::OpenSSL->new('JSON' => JSON::MaybeXS->new->canonical->utf8(1));

$handler->throw_errors(1);

my $inputclaims = {
    'sub'   => 'Test subject',
    'roles' => 'testrole',
    'exp'   => 1786935249,
    'iss'   => 'this/test/file'
};

## HMAC TESTS
{
    my @configs = (
        { algo => 'HS256', secret => 't/keys/hmac_256.secret', bits => 256 },
        { algo => 'HS384', secret => 't/keys/hmac_384.secret', bits => 384 },
        { algo => 'HS512', secret => 't/keys/hmac_512.secret', bits => 512 },
    );
    
    my $SECRETS = {};

    for my $cnf ( @configs ) {
        my $algo = $cnf->{algo};
        my $secret = load_key($cnf->{secret});
        $secret = MIME::Base64::decode_base64($secret);
        $SECRETS->{$algo} = $secret;
    }
    
    for my $cnf ( @configs ) {
        my $algo = $cnf->{algo};
        my $BITS = $cnf->{bits};
        my $prvkey = $SECRETS->{$algo};
        my $pubkey = $SECRETS->{$algo};
        
        my $token = $handler->encode({
            claims      => $inputclaims,
            secret      => $prvkey,
            header      => { alg => $algo, typ => 'JWT' },
        });
        
        ok( $token, qq($algo - token returned) );
        my @parts = split(/\./, $token );
        is( scalar @parts, 3, qq($algo - token has 3 parts));
        
        my $expected_decoded = {
            claims      => $inputclaims,
            header      => { alg => $algo, typ => 'JWT' },
            verifytoken => join(':', $algo, $parts[0] . '.' . $parts[1],  $parts[2] ),
        };
        
        my $bad_verify_token = join(':', $algo, $parts[0] . '.' . $parts[1], random_byte_base64_signature($BITS) );
            
        my $decoded = $handler->decode_unverified( token  => $token );
        
        cmp_deeply($decoded, $expected_decoded, qq($algo - decoded is expected decoded));
        
        my $verified = $handler->verify(
            verifytoken => $decoded->{verifytoken},
            secret      => $pubkey 
        );
        
        is($verified, 1, qq($algo - verified));
        
        $verified = $handler->verify(
            verifytoken => $bad_verify_token,
            secret      => $pubkey 
        );
        
        is($verified, 0, qq($algo - bad verify token fails in correct part of code));
    }

}

## RSA TESTS
{
    my $prvkey2048 = load_key('t/keys/rsa_private_key.pem');
    my $pubkey2048 = load_key('t/keys/rsa_public_key.pem');
    my $prvkey4096 = load_key('t/keys/rsa_private_key_4096.pem');
    my $pubkey4096 = load_key('t/keys/rsa_public_key_4096.pem');
    
    my $bit_key_map = {
        '2048' => { public => $pubkey2048, private => $prvkey2048 },
        '4096' => { public => $pubkey4096, private => $prvkey4096 },
    };
    
    my $badrsakey = load_key('t/keys/rsa_bad_public_key.pem');
    
    my @pkcs1algos = qw( RS256 RS384 RS512 );
    my @pssalgos   = qw( PS256 PS384 PS512 );
    
    for my $BITS ( '2048', '4096' ) {
        my $pubkey = $bit_key_map->{$BITS}->{'public'};
        my $prvkey = $bit_key_map->{$BITS}->{'private'};
        
        SKIP: {
            skip 'installed version of Crypt::OpenSSL::RSA does not support PKCS1 v1_5 RSA padding', if!$handler->can_use_pkcs1_padding;
            
            for my $algo ( @pkcs1algos ) {
                
                my $token = $handler->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                my $compare_token = $handler->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                    
                my @token_parts   = split(/\./, $token);
                my @compare_parts = split(/\./, $compare_token);
                
                is($token_parts[0], $compare_parts[0], qq(RSA $BITS $algo - comparing header  of 2 tokens with identical content));
                is($token_parts[1], $compare_parts[1], qq(RSA $BITS $algo - comparing claims of 2 tokens with identical content));
                if ($algo =~ m!^R!) {
                    is($token_parts[2], $compare_parts[2], qq(RSA $BITS $algo - signatures of 2 tokens with same content should be same));
                } else {
                    isnt($token_parts[2], $compare_parts[2], qq(RSA $BITS $algo - signatures of 2 tokens with same content should be different));
                }
                ok( $token, qq(RSA $BITS $algo - token returned) );
                my @parts = split(/\./, $token );
                is( scalar @parts, 3, qq(RSA $BITS $algo - token has 3 parts));
                    
                my $expected_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $parts[0] . '.' . $parts[1],  $parts[2] ),
                };
                
                my $bad_verify_token = join(':', $algo, $parts[0] . '.' . $parts[1], random_byte_base64_signature($BITS) );
                
                my $decoded = $handler->decode_unverified( token  => $token );
                
                cmp_deeply($decoded, $expected_decoded, qq(RSA $BITS $algo - decoded is expected decoded));
                    
                my $verified = $handler->verify(
                    verifytoken => $decoded->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified, 1, qq(RSA $BITS $algo - verified));
                
                $verified = $handler->verify(
                    verifytoken => $bad_verify_token,
                    secret      => $pubkey 
                );
                
                is($verified, 0, qq(RSA $BITS $algo - bad verify token fails in correct part of code));                
            }
        }
        
        SKIP: {
            skip 'installed version of Crypt::OpenSSL::RSA does not support RSA PSS padding', if!$handler->can_use_pkcs1_pss_padding;
            
            for my $algo ( @pssalgos ) {
                
                my $token = $handler->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                my $compare_token = $handler->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                    
                my @token_parts   = split(/\./, $token);
                my @compare_parts = split(/\./, $compare_token);
                
                is($token_parts[0], $compare_parts[0], qq(RSA $BITS $algo - comparing header  of 2 tokens with identical content));
                is($token_parts[1], $compare_parts[1], qq(RSA $BITS $algo - comparing claims of 2 tokens with identical content));
                if ($algo =~ m!^R!) {
                    is($token_parts[2], $compare_parts[2], qq(RSA $BITS $algo - signatures of 2 tokens with same content should be same));
                } else {
                    isnt($token_parts[2], $compare_parts[2], qq(RSA $BITS $algo - signatures of 2 tokens with same content should be different));
                }
                ok( $token, qq(RSA $BITS $algo - token returned) );
                my @parts = split(/\./, $token );
                is( scalar @parts, 3, qq(RSA $BITS $algo - token has 3 parts));
                    
                my $expected_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $parts[0] . '.' . $parts[1],  $parts[2] ),
                };
                
                my $bad_verify_token = join(':', $algo, $parts[0] . '.' . $parts[1], random_byte_base64_signature($BITS) );
                
                my $decoded = $handler->decode_unverified( token  => $token );
                
                cmp_deeply($decoded, $expected_decoded, qq(RSA $BITS $algo - decoded is expected decoded));
                    
                my $verified = $handler->verify(
                    verifytoken => $decoded->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified, 1, qq(RSA $BITS $algo - verified));
                
                $verified = $handler->verify(
                    verifytoken => $bad_verify_token,
                    secret      => $pubkey 
                );
                
                is($verified, 0, qq(RSA $BITS $algo - bad verify token fails in correct part of code));                
            }
        }
    }
}

## ECDSA TESTS

{
    my @configs = (
        { algo => 'ES256', privkey => 't/keys/es256-private-key.pem', pubkey => 't/keys/es256-public-key.pem', bits => 256 },
        { algo => 'ES384', privkey => 't/keys/es384-private-key.pem', pubkey => 't/keys/es384-public-key.pem', bits => 384 },
        { algo => 'ES512', privkey => 't/keys/es512-private-key.pem', pubkey => 't/keys/es512-public-key.pem', bits => 521 },
    );
    
    my $KEYS = {};
    
    for my $cnf ( @configs ) {
        $KEYS->{$cnf->{algo}}->{prv} = load_key($cnf->{privkey});
        $KEYS->{$cnf->{algo}}->{pub} = load_key($cnf->{pubkey});
    }
    
    for my $cnf ( @configs ) {
        my $algo = $cnf->{algo};
        
        my $BITS = $cnf->{bits};
        my $prvkey = $KEYS->{$algo}->{prv};
        my $pubkey = $KEYS->{$algo}->{pub};
        
        ## non deterministic
        {
            my $token = $handler->encode(
                claims      => $inputclaims,
                secret      => $prvkey,
                header      => { alg => $algo, typ => 'JWT' },
                non_deterministic => 1,
            );
            
            my $compare_token = $handler->encode(
                claims      => $inputclaims,
                secret      => $prvkey,
                header      => { alg => $algo, typ => 'JWT' },
                non_deterministic => 1,
            );
            
            my @token_parts = split(/\./, $token);
            my @compare_parts = split(/\./, $compare_token);
            
            is($token_parts[0], $compare_parts[0], qq($algo - comparing header of 2 non deterministic tokens with identical content));
            is($token_parts[1], $compare_parts[1], qq($algo - comparing claims of 2 non deterministic tokens with identical content));
            isnt($token_parts[2], $compare_parts[2], qq($algo - comparing signatures of 2 non deterministic tokens with identical content));
            
            ok( $token, qq($algo - non deterministic token returned) );
            my @parts = split(/\./, $token );
            is( scalar @parts, 3, qq($algo - non deterministic token has 3 parts));
                
            my $expected_decoded = {
                claims      => $inputclaims,
                header      => { alg => $algo, typ => 'JWT' },
                verifytoken => join(':', $algo, $parts[0] . '.' . $parts[1],  $parts[2] ),
            };
            
            my $bad_verify_token = join(':', $algo, $parts[0] . '.' . $parts[1], random_byte_base64_signature($BITS) );
            
            my $decoded = $handler->decode_unverified( token  => $token );
            
            cmp_deeply($decoded, $expected_decoded, qq($algo - non deterministic decoded is expected decoded));
            
            my $verified = $handler->verify(
                verifytoken => $decoded->{verifytoken},
                secret      => $pubkey
            );
            
            is($verified, 1, qq($algo - non deterministic verified));
        };
        
        ## deterministic
        {
            my $det_token = $handler->encode(
                claims        => $inputclaims,
                secret        => $prvkey,
                header        => { alg => $algo, typ => 'JWT' }
            );
            
            my $det_compare_token = $handler->encode(
                claims       => $inputclaims,
                secret       => $prvkey,
                header       => { alg => $algo, typ => 'JWT' }
            );
            
            my @det_token_parts = split(/\./, $det_token);
            my @det_compare_parts = split(/\./, $det_compare_token);
            
            is($det_token_parts[0], $det_compare_parts[0], qq($algo - comparing header of 2 deterministic tokens with identical content));
            is($det_token_parts[1], $det_compare_parts[1], qq($algo - comparing claims of 2 deterministic tokens with identical content));
            is($det_token_parts[2], $det_compare_parts[2], qq($algo - comparing signatures of 2 deterministic tokens with identical content));
            
            ok( $det_token, qq($algo - deterministic token returned) );
            my @det_parts = split(/\./, $det_token );
            is( scalar @det_parts, 3, qq($algo - deterministic token has 3 parts));
                
            my $det_expected_decoded = {
                claims      => $inputclaims,
                header      => { alg => $algo, typ => 'JWT' },
                verifytoken => join(':', $algo, $det_parts[0] . '.' . $det_parts[1],  $det_parts[2] ),
            };
            
            my $det_decoded = $handler->decode_unverified( token  => $det_token );
            
            cmp_deeply($det_decoded, $det_expected_decoded, qq($algo - deterministic decoded is expected decoded));
            
            my $det_verified = $handler->verify(
                verifytoken => $det_decoded->{verifytoken},
                secret      => $pubkey
            );
            
            is($det_verified, 1, qq($algo - deterministic verified));
        }
    }
}

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
