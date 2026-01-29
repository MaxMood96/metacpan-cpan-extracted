# NAME

Digest::Merkle::SHA256 - Pure-Perl SHA-256 Merkle Tree with Audit Proofs

# SYNOPSIS

```perl
use Digest::Merkle::SHA256;

my $tree = Digest::Merkle::SHA256->new(
    file_size  => 1048576, # 1MiB
    block_size => 16384    # 16KiB
);

# Set a leaf node hash
$tree->set_block(0, $sha256_hash);

# Get the root hash (Merkle Root)
my $root = $tree->root();

# Generate an audit path for a specific block
my $path = $tree->get_audit_path(0);

# Verify a hash using an audit path (static method)
my $is_valid = Digest::Merkle::SHA256->verify_hash(
    $index, $hash, $path, $expected_root
);
```

# DESCRIPTION

`Digest::Merkle::SHA256` implements a SHA-256 Merkle tree (also known as a Hash Tree). Merkle trees allow for
efficient and secure verification of the contents of large data structures.

This module is general purpose and can be used for any system requiring block level data integrity proofs (IPFS,
BitTorrent v2, Certificate Transparency, Blockchain-like ledgers, etc.).

## Key Features:

- Sparse Storage: Can calculate parent hashes even if some leaf nodes are missing using pre-calculated "zero hashes" (hashes of empty space).
- Audit Proofs: Generates the sibling hashes (audit path) required to prove that a specific block belongs to a specific root.
- Layer Access: Allows retrieving entire layers of the tree as contiguous binary strings.

# METHODS

## `root( )`

Returns the binary SHA-256 root hash of the entire tree.

## `set_block( $index, $hash )`

Sets the SHA-256 hash for a leaf node at `$index`. This triggers a recursive update of all parent nodes up to the
root.

## `get_audit_path( $index )`

Returns an arrayref of binary hashes required to verify the block at `$index`.

## `get_hashes( $level, $index, $count )`

Returns a contiguous binary string containing `$count` hashes from the tree at the specified `$level`.

## `verify_hash( $index, $hash, $audit_path, $expected_root )`

Static method that performs the Merkle proof calculation. Returns a true value if the calculated root matches
`$expected_root`.

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2008-2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.
