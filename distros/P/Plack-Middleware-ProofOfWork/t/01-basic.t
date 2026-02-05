use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64);

# Simple test app
my $app = builder {
    enable "ProofOfWork",
        difficulty => 2,  # Low difficulty for tests
        cookie_name => 'test_pow',
        cookie_duration => 1,
        bot_verification_level => 1;  # User-Agent only (no DNS in tests)
    sub { [200, ['Content-Type' => 'text/plain'], ['Hello World']] };
};

test_psgi $app, sub {
    my $cb = shift;
    
    # Test 1: Request without cookie should return challenge
    {
        my $res = $cb->(GET "/");
        is $res->code, 200, "Challenge page returns 200";
        like $res->content, qr/Proof of Work/i, "Challenge page contains PoW text";
        like $res->content, qr/script/i, "Challenge page contains script";
        is $res->header('X-Proof-of-Work'), 'required', "X-Proof-of-Work header is set";
    }
    
    # Test 2: Request with valid PoW cookie should pass through
    {
        # Simulate valid PoW
        my $user_agent = 'Mozilla/5.0 Test';
        my $now = time();
        my $timestamp = $now - ($now % (86400 * 1));  # 1 day window
        my $source = "$user_agent|$timestamp|en-US|localhost";
        
        # Find valid nonce (difficulty 2 = "00" at start)
        my $difficulty = 2;
        my $full = int($difficulty);
        my $fraction = $difficulty - $full;
        my $nonce = 0;
        my $hash;
        
        while (1) {
            $hash = sha256_hex("$source:$nonce");
            
            # Check integer part
            last if substr($hash, 0, $full) eq ('0' x $full);
            
            $nonce++;
            die "Could not find valid nonce" if $nonce > 100000;
        }
        
        my $cookie_value = encode_base64($nonce, '');
        
        my $req = GET "/", 
            'User-Agent' => $user_agent,
            'Accept-Language' => 'en-US',
            'Host' => 'localhost',
            'Cookie' => "test_pow=$cookie_value";
        
        my $res = $cb->($req);
        is $res->code, 200, "Valid PoW cookie allows access";
        is $res->content, 'Hello World', "Correct content is returned";
    }
    
    # Test 3: Googlebot should pass without PoW
    {
        my $req = GET "/", 
            'User-Agent' => 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
        
        my $res = $cb->($req);
        is $res->code, 200, "Googlebot is allowed without PoW";
        is $res->content, 'Hello World', "Googlebot gets correct content";
    }
    
    # Test 4: Bingbot should pass without PoW
    {
        my $req = GET "/", 
            'User-Agent' => 'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)';
        
        my $res = $cb->($req);
        is $res->code, 200, "Bingbot is allowed without PoW";
        is $res->content, 'Hello World', "Bingbot gets correct content";
    }
    
    # Test 5: Invalid cookie should return challenge
    {
        my $req = GET "/", 
            'Cookie' => 'test_pow=invalid_token';
        
        my $res = $cb->($req);
        is $res->code, 200, "Invalid cookie returns challenge";
        like $res->content, qr/Proof of Work/i, "Invalid cookie shows challenge page";
    }
};

# Test configuration
{
    my $test_app = builder {
        enable "ProofOfWork",
            difficulty => 5,
            cookie_name => 'custom_pow',
            cookie_duration => 7,
            bot_verification_level => 0;  # Block all bots
        sub { [200, ['Content-Type' => 'text/plain'], ['OK']] };
    };
    
    test_psgi $test_app, sub {
        my $cb = shift;
        
        # With bot_verification_level => 0, even Googlebot should get challenge
        my $req = GET "/", 
            'User-Agent' => 'Googlebot';
        
        my $res = $cb->($req);
        like $res->content, qr/Proof of Work/i, "With bot_verification_level => 0, even Googlebot gets challenge";
    };
}

# Test fractional difficulty
{
    my $test_app = builder {
        enable "ProofOfWork",
            difficulty => 2.5,  # Fractional difficulty
            cookie_name => 'test_pow_frac',
            cookie_duration => 1,
            bot_verification_level => 1;  # User-Agent only (no DNS in tests)
        sub { [200, ['Content-Type' => 'text/plain'], ['Fractional OK']] };
    };
    
    test_psgi $test_app, sub {
        my $cb = shift;
        
        # Test with fractional difficulty
        my $user_agent = 'Mozilla/5.0 Test';
        my $now = time();
        my $timestamp = $now - ($now % (86400 * 1));
        my $source = "$user_agent|$timestamp|en-US|localhost";
        
        # Find valid nonce for difficulty 2.5
        my $difficulty = 2.5;
        my $full = int($difficulty);
        my $fraction = $difficulty - $full;
        my $div = 16 - (16 * $fraction);
        my $nonce = 0;
        my $hash;
        
        while (1) {
            $hash = sha256_hex("$source:$nonce");
            
            # Check integer part (2 zeros)
            if (substr($hash, 0, $full) eq ('0' x $full)) {
                # Check fractional part
                my $next_hex = hex(substr($hash, $full, 1));
                last if $next_hex < $div;
            }
            
            $nonce++;
            die "Could not find valid nonce for fractional difficulty" if $nonce > 500000;
        }
        
        my $cookie_value = encode_base64($nonce, '');
        
        my $req = GET "/", 
            'User-Agent' => $user_agent,
            'Accept-Language' => 'en-US',
            'Host' => 'localhost',
            'Cookie' => "test_pow_frac=$cookie_value";
        
        my $res = $cb->($req);
        is $res->code, 200, "Fractional difficulty (2.5) works";
        is $res->content, 'Fractional OK', "Correct content with fractional difficulty";
    };
}

# Test that invalid PoW is actually rejected (regression test for v0.08 bug fix)
{
    my $test_app = builder {
        enable "ProofOfWork",
            difficulty => 2,
            cookie_name => 'test_pow_validation',
            cookie_duration => 1,
            bot_verification_level => 1;  # User-Agent only (no DNS in tests)
        sub { [200, ['Content-Type' => 'text/plain'], ['Validation OK']] };
    };
    
    test_psgi $test_app, sub {
        my $cb = shift;
        
        # Test with completely wrong nonce that should definitely fail validation
        my $user_agent = 'Mozilla/5.0 Test';
        my $now = time();
        my $timestamp = $now - ($now % (86400 * 1));
        my $source = "$user_agent|$timestamp|en-US|localhost";
        
        # Use nonce 0 which is very unlikely to produce valid hash
        my $invalid_nonce = 0;
        my $hash = sha256_hex("$source:$invalid_nonce");
        
        # Verify this nonce does NOT produce valid PoW
        my $is_valid = substr($hash, 0, 2) eq '00';
        
        if (!$is_valid) {
            # Good - nonce 0 is invalid, use it for test
            my $cookie_value = encode_base64($invalid_nonce, '');
            
            my $req = GET "/", 
                'User-Agent' => $user_agent,
                'Accept-Language' => 'en-US',
                'Host' => 'localhost',
                'Cookie' => "test_pow_validation=$cookie_value";
            
            my $res = $cb->($req);
            
            # Should get challenge page, NOT the protected content
            like $res->content, qr/Proof of Work/i, 
                "Invalid PoW nonce is properly rejected (v0.08 bug fix)";
            isnt $res->content, 'Validation OK', 
                "Invalid PoW does not return protected content";
        } else {
            # Nonce 0 happened to be valid (extremely unlikely)
            pass("Skipped test - nonce 0 was accidentally valid");
        }
    };
}

done_testing();
