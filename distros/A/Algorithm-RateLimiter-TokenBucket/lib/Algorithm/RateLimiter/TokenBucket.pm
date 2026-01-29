use v5.40;
use feature 'class';
no warnings 'experimental::class';
#
class Algorithm::RateLimiter::TokenBucket v1.0.0 {
    field $limit : param : reader //= 0;    # Bytes per second, 0 = unlimited
    field $tokens : reader = $limit;
    field $max_burst = $limit * 2;          # Allow some burst, but not too much

    #
    method set_limit ($new_limit) {
        $limit     = $new_limit;
        $max_burst = $limit * 2;
    }

    method tick ($delta) {
        return if !$limit;
        $tokens += $limit * $delta;
        $tokens = $max_burst if $tokens > $max_burst;
    }

    method consume ($amount) {
        return $amount if !$limit;
        my $allowed = ( $amount > $tokens ) ? $tokens : $amount;
        $allowed = 0 if $allowed < 0;
        $tokens -= $allowed;
        int $allowed;
    }
    method available () { $limit ? int($tokens) : 1_000_000_000 }    # Near enough to infinity for a network transfer
};
1;
