# Hash::Util::Set and Hash::Util::Join

A collection of utilities for set operations and SQL-like joins on Perl hashes.

## Modules

### Hash::Util::Set - Set Operations on Hash Keys

Provides set operations on hash keys.

**Set Operations:**
- `keys_union` - Keys in either hash (A ∪ B)
- `keys_intersection` - Keys in both hashes (A ∩ B)
- `keys_difference` - Keys in first but not second (A \ B)
- `keys_symmetric_difference` - Keys in either but not both (A △ B)
- `keys_partition` - Split into three sets: only A, both, only B

**Set Predicates:**
- `keys_disjoint` - No common keys?
- `keys_equal` - Same keys?
- `keys_subset` - A ⊆ B?
- `keys_proper_subset` - A ⊂ B (strict)?
- `keys_superset` - A ⊇ B?
- `keys_proper_superset` - A ⊃ B (strict)?

**Membership Tests:**
- `keys_any` - At least one key exists?
- `keys_all` - All keys exist?
- `keys_none` - No keys exist?


### Hash::Util::Join - SQL-like Join Operations

Provides SQL-like join operations for combining two hashes based on their keys.

**Join Operations:**
- `hash_inner_join` - Keys in both hashes
- `hash_left_join` - All keys from left hash
- `hash_right_join` - All keys from right hash
- `hash_outer_join` - All keys from both hashes
- `hash_left_anti_join` - Keys only in left hash
- `hash_right_anti_join` - Keys only in right hash
- `hash_full_anti_join` - Keys in either but not both

## Installation

```bash
cpanm Hash::Util::Set
```

Or manually:

```bash
perl Makefile.PL
make
make test
make install
```

## Performance

Both modules automatically use XS implementations when available, falling back to pure Perl otherwise for maximum compatibility and performance.

## Author

Christian Hansen <chansen@cpan.org>

## Copyright and License

Copyright (C) 2026 Christian Hansen

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
