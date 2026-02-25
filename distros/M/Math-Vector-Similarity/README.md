# Math::Vector::Similarity

Lightweight pure-Perl functions for comparing numeric vectors. Works on plain ArrayRefs of any dimensionality, with zero dependencies.

## Functions

- `cosine_similarity(\@a, \@b)` — Cosine similarity (-1 to 1)
- `cosine_distance(\@a, \@b)` — Cosine distance (0 to 2)
- `euclidean_distance(\@a, \@b)` — Euclidean (L2) distance
- `dot_product(\@a, \@b)` — Dot product (inner product)
- `normalize(\@v)` — L2-normalize to unit vector

## Synopsis

```perl
use Math::Vector::Similarity qw( cosine_similarity cosine_distance );

my $sim = cosine_similarity([0.1, 0.2, 0.3], [0.1, 0.25, 0.28]);
# 0.998...

# Compare embedding vectors from any LLM API
my $emb1 = $engine->simple_embedding("Perl programming");
my $emb2 = $engine->simple_embedding("Italian cooking");
say cosine_similarity($emb1, $emb2);  # low — different topics
```

## Installation

```
cpanm Math::Vector::Similarity
```
