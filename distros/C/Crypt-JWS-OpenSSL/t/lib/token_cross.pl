use Test::More;
use Test::Deep;

our $H1;
our $H2;
our $H1NAME;
our $H2NAME;


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
    
    my $bit_key_map = {
        '2048' => { public => $pubkey2048, private => $prvkey2048 },
        '4096' => { public => $pubkey4096, private => $prvkey4096 },
    };
    
    my $badrsakey = load_key('t/keys/rsa_bad_public_key.pem');
    
    my @pkcs1algos = qw( RS256 RS384 RS512 );
    my @pssalgos   = qw( PS256 PS384 PS512 );
        
    SKIP: {
        
        skip qq(one or both handlers $H1NAME and $H2NAME do not support PKCS1 v1_5 RSA padding), if(!$H1->can_use_pkcs1_padding || !$H2->can_use_pkcs1_padding );
        
        for my $BITS ( '2048', '4096' ) {
            my $pubkey = $bit_key_map->{$BITS}->{'public'};
            my $prvkey = $bit_key_map->{$BITS}->{'private'};
            for my $algo ( @pkcs1algos ) {
                my $token_1 = $H1->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                my $token_2 = $H2->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                is($token_1, $token_2, qq($BITS bit $algo tokens produced by $H1NAME and $H2NAME are identical));
                
                my @token_1_parts   = split(/\./, $token_1);
                
                my $expected_1_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $token_1_parts[0] . '.' . $token_1_parts[1],  $token_1_parts[2] ),
                };
                
                my @token_2_parts   = split(/\./, $token_2);
                
                my $expected_2_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $token_2_parts[0] . '.' . $token_2_parts[1],  $token_2_parts[2] ),
                };
                 
                my $decoded_1 = $H1->decode_unverified( token  => $token_1 );
                my $decoded_2 = $H2->decode_unverified( token  => $token_2 );
                
                cmp_deeply($decoded_1, $expected_1_decoded, qq($BITS bit $algo $H1NAME decoded is expected decoded));
                cmp_deeply($decoded_2, $expected_2_decoded, qq($BITS bit $algo $H2NAME decoded is expected decoded));
                
                my $verified_1 = $H2->verify(
                    verifytoken => $decoded_1->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified_1, 1, qq($BITS bit $algo $H2NAME can verify $H1NAME token));
                
                my $verified_2 = $H1->verify(
                    verifytoken => $decoded_2->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified_2, 1, qq($BITS bit $algo $H1NAME can verify $H2NAME token));
             
            }
        }
    }
    
    SKIP: {
        
        skip qq(one or both handlers $H1NAME and $H2NAME do not support RSA PSS padding), if(!$H1->can_use_pkcs1_pss_padding || !$H2->can_use_pkcs1_pss_padding );
        
        for my $BITS ( '2048', '4096' ) {
            my $pubkey = $bit_key_map->{$BITS}->{'public'};
            my $prvkey = $bit_key_map->{$BITS}->{'private'};
            for my $algo ( @pssalgos ) {
                my $token_1 = $H1->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                my $token_2 = $H2->encode(
                    claims      => $inputclaims,
                    secret      => $prvkey,
                    header      => { alg => $algo, typ => 'JWT' }
                );
                
                isnt($token_1, $token_2, qq($BITS bit $algo tokens produced by $H1NAME and $H2NAME are not identical));
                    
                my @token_1_parts   = split(/\./, $token_1);
                
                my $expected_1_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $token_1_parts[0] . '.' . $token_1_parts[1],  $token_1_parts[2] ),
                };
                
                my @token_2_parts   = split(/\./, $token_2);
                
                my $expected_2_decoded = {
                    claims      => $inputclaims,
                    header      => { alg => $algo , typ => 'JWT' },
                    verifytoken => join(':', $algo, $token_2_parts[0] . '.' . $token_2_parts[1],  $token_2_parts[2] ),
                };
                 
                my $decoded_1 = $H1->decode_unverified( token  => $token_1 );
                my $decoded_2 = $H2->decode_unverified( token  => $token_2 );
                
                cmp_deeply($decoded_1, $expected_1_decoded, qq($BITS bit $algo $H1NAME decoded is expected decoded));
                cmp_deeply($decoded_2, $expected_2_decoded, qq($BITS bit $algo $H2NAME decoded is expected decoded));
                 
                
                my $verified_1 = $H2->verify(
                    verifytoken => $decoded_1->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified_1, 1, qq($BITS bit $algo $H2NAME can verify $H1NAME token));
                
                my $verified_2 = $H1->verify(
                    verifytoken => $decoded_2->{verifytoken},
                    secret      => $pubkey
                );
                
                is($verified_2, 1, qq($BITS bit $algo $H1NAME can verify $H2NAME token));     
            }
        }
    }
}

## ECDSA TESTS

{
    my @configs = (
        { algo => 'ES256', privkey => 't/keys/es256-private-key.pem', pubkey => 't/keys/es256-public-key.pem' },
        { algo => 'ES384', privkey => 't/keys/es384-private-key.pem', pubkey => 't/keys/es384-public-key.pem' },
        { algo => 'ES512', privkey => 't/keys/es512-private-key.pem', pubkey => 't/keys/es512-public-key.pem' },
    );
    
    my $KEYS = {};
    
    for my $cnf ( @configs ) {
        $KEYS->{$cnf->{algo}}->{prv} = load_key($cnf->{privkey});
        $KEYS->{$cnf->{algo}}->{pub} = load_key($cnf->{pubkey});
    }
    
    for my $cnf ( @configs ) {
        my $algo = $cnf->{algo};
        my $prvkey = $KEYS->{$algo}->{prv};
        my $pubkey = $KEYS->{$algo}->{pub};
        
        SKIP: {
            
            skip qq(one or both handlers $H1NAME and $H2NAME do not support non deterministic ECDSA signing), if (!$H1->can_do_non_deterministic || !$H2->can_do_non_deterministic);
            
            my $token_1 = $H1->encode(
                claims      => $inputclaims,
                secret      => $prvkey,
                header      => { alg => $algo, typ => 'JWT' },
                non_deterministic => 1,
            );
            
            my $token_2 = $H2->encode(
                claims      => $inputclaims,
                secret      => $prvkey,
                header      => { alg => $algo, typ => 'JWT' },
                non_deterministic => 1,
            );
            
            isnt($token_1, $token_2, qq($algo none deterministic tokens produced by $H1NAME and $H2NAME are not identical));
                
            my @token_1_parts   = split(/\./, $token_1);
                
            my $expected_1_decoded = {
                claims      => $inputclaims,
                header      => { alg => $algo , typ => 'JWT' },
                verifytoken => join(':', $algo, $token_1_parts[0] . '.' . $token_1_parts[1],  $token_1_parts[2] ),
            };
            
            my @token_2_parts   = split(/\./, $token_2);
            
            my $expected_2_decoded = {
                claims      => $inputclaims,
                header      => { alg => $algo , typ => 'JWT' },
                verifytoken => join(':', $algo, $token_2_parts[0] . '.' . $token_2_parts[1],  $token_2_parts[2] ),
            };
             
            my $decoded_1 = $H1->decode_unverified( token  => $token_1 );
            my $decoded_2 = $H2->decode_unverified( token  => $token_2 );
            
            cmp_deeply($decoded_1, $expected_1_decoded, qq($algo $H1NAME decoded is expected decoded));
            cmp_deeply($decoded_2, $expected_2_decoded, qq($algo $H2NAME decoded is expected decoded));
            
            my $verified_1 = $H2->verify(
                verifytoken => $decoded_1->{verifytoken},
                secret      => $pubkey
            );
            
            is($verified_1, 1, qq($algo $H2NAME can verify $H1NAME token));
            
            my $verified_2 = $H1->verify(
                verifytoken => $decoded_2->{verifytoken},
                secret      => $pubkey
            );
            
            is($verified_2, 1, qq($algo $H1NAME can verify $H2NAME token));  
            
        };
        
        SKIP: {
            
            skip qq(one or both handlers $H1NAME and $H2NAME do not support deterministic ECDSA signing), if( !$H1->can_do_deterministic || !$H2->can_do_deterministic );
            
            my $token_1 = $H1->encode(
                claims      => $inputclaims,
                secret      => $prvkey,
                header      => { alg => $algo, typ => 'JWT' }
            );
            
            my $token_2 = $H2->encode(
                claims      => $inputclaims,
                secret      => $prvkey,
                header      => { alg => $algo, typ => 'JWT' }
            );
            
            is($token_1, $token_2, qq($algo deterministic tokens produced by $H1NAME (got) and $H2NAME (expected) are identical));
                        
            my @token_1_parts   = split(/\./, $token_1);
                
            my $expected_1_decoded = {
                claims      => $inputclaims,
                header      => { alg => $algo , typ => 'JWT' },
                verifytoken => join(':', $algo, $token_1_parts[0] . '.' . $token_1_parts[1],  $token_1_parts[2] ),
            };
            
            my @token_2_parts   = split(/\./, $token_2);
            
            my $expected_2_decoded = {
                claims      => $inputclaims,
                header      => { alg => $algo , typ => 'JWT' },
                verifytoken => join(':', $algo, $token_2_parts[0] . '.' . $token_2_parts[1],  $token_2_parts[2] ),
            };
             
            my $decoded_1 = $H1->decode_unverified( token  => $token_1 );
            my $decoded_2 = $H2->decode_unverified( token  => $token_2 );
            
            cmp_deeply($decoded_1, $expected_1_decoded, qq($algo $H1NAME decoded is expected decoded));
            cmp_deeply($decoded_2, $expected_2_decoded, qq($algo $H2NAME decoded is expected decoded));
             
            
            my $verified_1 = $H2->verify(
                verifytoken => $decoded_1->{verifytoken},
                secret      => $pubkey
            );
            
            is($verified_1, 1, qq($algo $H2NAME can verify $H1NAME token));
            
            my $verified_2 = $H1->verify(
                verifytoken => $decoded_2->{verifytoken},
                secret      => $pubkey
            );
            
            is($verified_2, 1, qq($algo $H1NAME can verify $H2NAME token));  
            
        }
    }
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
    
    my $size = $bits / 8;
        
    my $octets = '';
    for (1 .. $size) {
        $octets .= chr(int(rand(256)));
    }
    
    return OpenSearch::Client::WebToken::encode_jwt_signature($octets);
}

1;