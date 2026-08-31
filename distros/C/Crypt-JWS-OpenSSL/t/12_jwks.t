use Test::More;
use Test::Deep;
use JSON::MaybeXS 1.002002 ();
use lib 't/lib';

BEGIN {   
    use_ok('Crypt::JWS::OpenSSL');
    #use_ok('Crypt::JWS::OpenSSL::Util::JWK');
}

## using canonical JSON ordering for tests. DON'T do this in production
my $handler = Crypt::JWS::OpenSSL->new('JSON' => JSON::MaybeXS->new->canonical->utf8(1));
$handler->throw_errors(1);

my $JWK_STORE;

load_jwk_store();

my $inputclaims = {
    'sub'   => 'Test subject',
    'roles' => 'testrole',
    'exp'   => 1786935249,
    'iss'   => 'this/test/file'
};

## RSA TESTS
{
    my $prvkey2048 = load_key('t/keys/rsa_private_key.pem');
    my $pubkey2048 = load_key('t/keys/rsa_public_key.pem');
    my $prvkey4096 = load_key('t/keys/rsa_private_key_4096.pem');
    my $pubkey4096 = load_key('t/keys/rsa_public_key_4096.pem');
    
    my $prvjwk2048 = get_jwk('id-rsa-2048-private');
    my $pubjwk2048 = get_jwk('id-rsa-2048-public');
    my $prvjwk4096 = get_jwk('id-rsa-4096-private');
    my $pubjwk4096 = get_jwk('id-rsa-4096-public');
    
    my $bit_key_map = {
        '2048' => {
            public      => $pubkey2048,
            private     => $prvkey2048,
            jwk_public  => $pubjwk2048,
            jwk_private => $prvjwk2048,
        },
        '4096' => {
            public      => $pubkey4096,
            private     => $prvkey4096,
            jwk_public  => $pubjwk4096,
            jwk_private => $prvjwk4096,
        },
    };
    
    my @pkcs1algos = qw( RS256 RS384 RS512 );
    my @pssalgos   = qw( PS256 PS384 PS512 );
    
    for my $BITS ( '2048', '4096' ) {
        my $pubkey = $bit_key_map->{$BITS}->{'public'};
        my $prvkey = $bit_key_map->{$BITS}->{'private'};
        my $pubjwk = $bit_key_map->{$BITS}->{'jwk_public'};
        my $prvjwk = $bit_key_map->{$BITS}->{'jwk_private'};
        
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
                    secret      => $prvjwk,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                ok( $token, qq(RSA $BITS $algo - token returned) );
                my @token_parts   = split(/\./, $token);
                is( scalar @token_parts, 3, qq(RSA $BITS $algo - token has 3 parts));
                
                my @compare_parts = split(/\./, $compare_token);
                
                is($token_parts[0], $compare_parts[0], qq(RSA $BITS $algo - comparing header  of 2 tokens with identical content));
                is($token_parts[1], $compare_parts[1], qq(RSA $BITS $algo - comparing claims of 2 tokens with identical content));
                if ($algo =~ m!^R!) {
                    is($token_parts[2], $compare_parts[2], qq(RSA $BITS $algo - signatures of 2 tokens with same content should be same));
                } else {
                    isnt($token_parts[2], $compare_parts[2], qq(RSA $BITS $algo - signatures of 2 tokens with same content should be different));
                }
                 
                my $expected_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $token_parts[0] . '.' . $token_parts[1],  $token_parts[2] ),
                };
                
                my $decoded = $handler->decode_unverified( token  => $token );
                
                cmp_deeply($decoded, $expected_decoded, qq(RSA $BITS $algo - decoded is expected decoded));
                    
                my $verified = $handler->verify(
                    verifytoken => $decoded->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified, 1, qq(RSA $BITS $algo - verified));
                
                my $jwk_verified = $handler->verify(
                    verifytoken => $decoded->{verifytoken},
                    secret      => $pubjwk
                );
                
                is($jwk_verified, 1, qq(RSA $BITS $algo - verified with jwk));
                
                
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
                    secret      => $prvjwk,
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
                
                my $decoded = $handler->decode_unverified( token  => $token );
                
                cmp_deeply($decoded, $expected_decoded, qq(RSA $BITS $algo - decoded is expected decoded));
                    
                my $verified = $handler->verify(
                    verifytoken => $decoded->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified, 1, qq(RSA $BITS $algo - verified));
                
                my $jwk_verified = $handler->verify(
                    verifytoken => $decoded->{verifytoken},
                    secret      => $pubjwk
                );
                
                is($jwk_verified, 1, qq(RSA $BITS $algo - verified with jwk));
                             
            }
        }
    }
}

## ECDSA TESTS

{
    my @configs = (
        { algo => 'ES256', privkey => 't/keys/es256-private-key.pem', pubkey => 't/keys/es256-public-key.pem', bits => 256, privkid => 'id-es256-private', pubkid => 'id-es256-public' },
        { algo => 'ES384', privkey => 't/keys/es384-private-key.pem', pubkey => 't/keys/es384-public-key.pem', bits => 384, privkid => 'id-es384-private', pubkid => 'id-es384-public' },
        { algo => 'ES512', privkey => 't/keys/es512-private-key.pem', pubkey => 't/keys/es512-public-key.pem', bits => 521, privkid => 'id-es512-private', pubkid => 'id-es512-public' },
    );
    
    my $KEYS = {};
    
    for my $cnf ( @configs ) {
        $KEYS->{$cnf->{algo}}->{prvkey} = load_key($cnf->{privkey});
        $KEYS->{$cnf->{algo}}->{pubkey} = load_key($cnf->{pubkey});
        $KEYS->{$cnf->{algo}}->{prvjwk} = get_jwk($cnf->{privkid});
        $KEYS->{$cnf->{algo}}->{pubjwk} = get_jwk($cnf->{pubkid});
    }
    
    for my $cnf ( @configs ) {
        my $algo = $cnf->{algo};
        
        my $BITS = $cnf->{bits};
        my $prvkey = $KEYS->{$algo}->{prvkey};
        my $pubkey = $KEYS->{$algo}->{pubkey};
        my $prvjwk = $KEYS->{$algo}->{prvjwk};
        my $pubjwk = $KEYS->{$algo}->{pubjwk};
        
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
                secret      => $prvjwk,
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
            
            my $decoded = $handler->decode_unverified( token  => $token );
            
            cmp_deeply($decoded, $expected_decoded, qq($algo - non deterministic decoded is expected decoded));
            
            my $verified = $handler->verify(
                verifytoken => $decoded->{verifytoken},
                secret      => $pubkey
            );
            
            is($verified, 1, qq($algo - non deterministic verified));
            
            my $jwk_verified = $handler->verify(
                verifytoken => $decoded->{verifytoken},
                secret      => $pubjwk
            );
            
            is($jwk_verified, 1, qq($algo - non deterministic verified with jwk));
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
                secret       => $prvjwk,
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
            
            my $det_jwk_verified = $handler->verify(
                verifytoken => $det_decoded->{verifytoken},
                secret      => $pubjwk
            );
            
            is($det_jwk_verified, 1, qq($algo - deterministic verified with jwk));
        }
    }
}

done_testing;

sub load_jwk_store {
    my $filepath = 't/keys/jwks.json';
    open(my $fh, '<:encoding(UTF-8)', $filepath) or die "Could not open '$filepath': $!";
    my $content = do { local $/; <$fh> };
    close($fh);
    my $keyref = JSON::MaybeXS->new->utf8->decode($content);
    
    for my $key ( @{ $keyref->{keys} } ) {
        my $kid = $key->{kid};
        $JWK_STORE->{$kid} = $key;
    }
}

sub get_jwk {
    my $kid = shift;
    die 'cannot find kid ' . $kid unless exists($JWK_STORE->{$kid});
    return { %{ $JWK_STORE->{$kid} } };
}

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
