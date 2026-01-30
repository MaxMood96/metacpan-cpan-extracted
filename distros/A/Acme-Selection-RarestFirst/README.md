# NAME

Acme::Selection::RarestFirst - Rarest-First Selection Algorithm

# SYNOPSIS

```perl
use Acme::Selection::RarestFirst;

my $selector = Acme::Selection::RarestFirst->new( size => 100 );

# Update availability based on what peers have
$selector->update( $peer_bitfield, 1 ); # peer joined
$selector->update( $peer_bitfield, -1); # peer left

# Pick the next best item to request
my $idx = $selector->pick( $my_bitfield );
```

# DESCRIPTION

`Acme::Selection::RarestFirst` implements the classic "rarest-first" algorithm used in distributed systems to ensure
high data availability. It prioritizes items that have the lowest count in the global set (the "swarm").

# METHODS

## `update( $bitfield, $delta )`

Increments or decrements the availability count for every item marked in the provided bitfield (which must support a
`get( $index )` method).

## `pick( $my_bitfield, [$priorities] )`

Finds the rarest item that is **not** present in `$my_bitfield`.

`$priorities` is an optional arrayref of weights. Items with priority less than or equal to 0 are skipped. Higher
weights are picked before lower weights, even if they aren't the rarest.

## `get_availability( $index )`

Returns the current availability count for a specific item.

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.
