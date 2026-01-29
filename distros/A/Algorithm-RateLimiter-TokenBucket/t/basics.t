use v5.40;
use Test2::V0;
use lib 'lib', '../lib';
use Algorithm::RateLimiter::TokenBucket;
#
subtest Initialization => sub {
    my $limit = 1000;
    my $rl    = Algorithm::RateLimiter::TokenBucket->new( limit => $limit );
    is $rl->limit,     $limit, 'Limit correctly set';
    is $rl->available, $limit, 'Tokens start at limit';
};
subtest Consumption => sub {
    isa_ok my $rl = Algorithm::RateLimiter::TokenBucket->new( limit => 1000 ), ['Algorithm::RateLimiter::TokenBucket'];
    is $rl->consume(400),  400, 'Consumed 400 tokens';
    is $rl->available,     600, '600 tokens remaining';
    is $rl->consume(1000), 600, 'Requested 1000, only got remaining 600';
    is $rl->available,     0,   'Bucket now empty';
};
subtest 'Ticking (Accumulation)' => sub {
    isa_ok my $rl = Algorithm::RateLimiter::TokenBucket->new( limit => 1000 ), ['Algorithm::RateLimiter::TokenBucket'];
    ok $rl->consume(1000), 'consume( 1000 )';
    is $rl->available, 0, 'Started empty';
    note 'tick( 0.5 )';    # Tick 0.5 seconds -> should add 500 tokens
    $rl->tick(0.5);
    is $rl->available, 500, 'Added 500 tokens after 0.5s';
    note 'tick( 2.0 )';    # Tick another 1.0 seconds -> should hit max_burst (limit * 2 = 2000)
    $rl->tick(2.0);
    is $rl->available, 2000, 'Capped at max_burst (2000)';
};
subtest 'Dynamic Limit Updates' => sub {
    isa_ok my $rl = Algorithm::RateLimiter::TokenBucket->new( limit => 1000 ), ['Algorithm::RateLimiter::TokenBucket'];
    ok $rl->set_limit(5000), 'set_limit( 5000 )';
    is $rl->limit, 5000, 'limit updated';
    ok $rl->consume(5000), 'consume( 5000 )';    # Simulate an initial burst
    note 'tick( 1.0 )';
    $rl->tick(1.0), is $rl->available, 5000, 'accumulated at new rate';
};
subtest 'Unlimited Mode' => sub {
    isa_ok my $rl = Algorithm::RateLimiter::TokenBucket->new( limit => 0 ), ['Algorithm::RateLimiter::TokenBucket'];
    is $rl->limit,              0,             'Limit is 0 (unlimited)';
    is $rl->consume(1_000_000), 1_000_000,     'Can consume massive amounts';
    is $rl->available,          1_000_000_000, 'Available returns high default';
};
#
done_testing;
