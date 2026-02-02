# NAME

Acme::Bitfield - Bitmask for Tracking Boolean Sets

# SYNOPSIS

```perl
use Acme::Bitfield;

my $bf = Acme::Bitfield->new( size => 100 );

# Mark item 42 as present
$bf->set( 42 );

# Check if we have item 42
say 'Found it!' if $bf->get(42);

# Statistics
printf "Progress: %.2f%%\r", ($bf->count / $bf->size * 100);

# Export raw binary for network transfer
my $raw = $bf->data;
```

# DESCRIPTION

`Acme::Bitfield` provides a compact way to track a large set of big endian boolean flags. It is specifically designed
to follow the BitTorrent (BEP 03) bit-ordering convention, where the most significant bit of the first byte represents
index 0.

## Bit Ordering

\* Byte 0, Bit 0 (0x80) -> Index 0 \* Byte 0, Bit 7 (0x01) -> Index 7 \* Byte 1, Bit 0 (0x80) -> Index 8

This is the inverse of Perl's internal `vec` bit-ordering, and this module handles the necessary bit-swizzling
transparently.

# METHODS

## `get( $index )`

Returns 1 if the bit at `$index` is set, 0 otherwise.

## `set( $index )`

Sets the bit at `$index` to 1.

## `clear( $index )`

Sets the bit at `$index` to 0.

## `count( )`

Returns the total number of bits set to 1.

## `is_full( )`

Returns true if all bits are set to 1.

## `is_empty( )`

Returns true if all bits are set to 0.

## `size( )`

Returns the total capacity of the bitfield.

## `data( )`

Returns the raw binary string representation of the bitfield.

## `set_data( $string )`

Sets the raw binary representation. The input string will be truncated or padded to match the `size`, and any excess
bits in the last byte will be zeroed.

## `fill( )`

Sets all bits within the `size` to 1.

## `find_missing( )`

Returns the index of the first bit set to 0, or `undef` if all bits are set.

## `inverse( )`

Returns a new bitfield object with all bits within the `size` inverted. Bit 0 becomes 1, and 1 becomes 0.

## `union( $other )`

Returns a new bitfield object representing the bitwise OR of this bitfield and `$other`.

## `intersection( $other )`

Returns a new bitfield object representing the bitwise AND of this bitfield and `$other`.

## `difference( $other )`

Returns a new bitfield object representing the bits set in this bitfield but NOT in `$other` (bitwise AND NOT).

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.
