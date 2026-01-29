# NAME

Algorithm::RateLimiter::TokenBucket - Loop-agnostic Token Bucket Rate Limiter

# SYNOPSIS

```perl
use Algorithm::RateLimiter::TokenBucket;

# Limit to 500 KB/s
my $limiter = Algorithm::RateLimiter::TokenBucket->new( limit => 512_000 );

# In your main loop
while ( 1 ) {
    my $delta = 0.1; # Time elapsed since last tick
    $limiter->tick( $delta );

    my $can_send = $limiter->consume( 16384 );
    if ($can_send > 0) {
        # Send $can_send bytes
    }
}
```

# DESCRIPTION

`Algorithm::RateLimiter::TokenBucket` implements the [token bucket](https://en.wikipedia.org/wiki/Token_bucket)
algorithm for rate limiting. It is specifically designed to be **loop-agnostic**, meaning it does not manage its own
timers or background threads. Instead, you "drive" it by calling `tick( )` with the amount of time that has passed.

This makes it ideal for integration into event loops (like [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync) or [Mojo::IOLoop](https://metacpan.org/pod/Mojo%3A%3AIOLoop)) or high-performance network
applications.

# METHODS

## `new( limit =` $bytes\_per\_second )>

Creates a new limiter. `limit` is optional and defaults to 0 (unlimited).

## `set_limit( $limit )`

Dynamically updates the rate limit.

## `tick( $delta_seconds )`

Adds new tokens to the bucket based on the time elapsed.

## `consume( $amount )`

Attempts to consume `$amount` units (tokens) from the bucket. Returns the number of units actually consumed.

## `available( )`

Returns the current number of tokens in the bucket.

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.
