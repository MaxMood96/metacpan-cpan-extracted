# ADR 0027 — The alias budget is a ratio, and it is go-yaml's ratio

- Status: accepted
- Date: 2026-08-21
- Tags: api, guards, yaml, robustness, interop, dos
- Resolves k112
- Related: ADR 0025 (a document that contains itself is refused — this is the
  other half of that finding, and the two guards are ordered)

## Context

ADR 0025 refused a document that is its own ancestor. It said explicitly what
it did not address, and this is that:

```yaml
l0: &l0
  v: 1
l1: &l1
  a: *l0
  b: *l0
…  25 levels
```

727 bytes, entirely acyclic, and it expands to a tree with `2**25` leaves.
`_assert_acyclic` correctly does not fire — there is no cycle — and every walk
below it expands each alias, as it must, because sops expands them too
(measured in ADR 0025: `base: &b` / `other: *b` encrypts to two independent
`ENC[...]` values). Measured at HEAD:

| N levels | `File::SOPS->encrypt` | output |
|---|---|---|
| 9 | 0.061 s | 172 KB |
| 12 | 0.506 s | 1.5 MB |
| 15 | 4.272 s | 13.3 MB |
| 25 | did not return | — |

The growth is a clean doubling, so 25 levels is roughly 4,400 s and tens of
gigabytes. k110 measured the climb at about 1 GB of RSS every 3 seconds.

Both directions are exposed, and the caller-supplied-structure origin is too:

| Entry point | Measured |
|---|---|
| `encrypt`, `encrypt_file`, `encrypt_in_place` | exponential, above |
| `decrypt`, `decrypt_file`, `extract`, `rotate`, `edit` | exponential — at 15 levels `decrypt` walked 65,535 leaves before it could even report a MAC failure, and `ignore_mac => 1` walked the same tree with nothing to report |
| `encrypt(format => 'json')` with one hashref shared from many places | exponential, 12.2 MB at 15 levels, no YAML anywhere near it |

## The decisive measurement: where the blowup is *not*

`YAML::XS::Load` does **not** explode. It resolves an alias to the **same Perl
reference**, not to a copy, so it returns a linear DAG:

| Document | `Load` | distinct containers |
|---|---|---|
| 25 levels (`2**25` leaves) | 0.0001 s | 27 |
| 200 levels (`2**200` leaves) | 0.0007 s | 202 |

This is what decides where the guard goes. Had the expansion happened inside
`Load`, no guard of ours could have reached it and the answer would have been a
pre-check on the raw bytes before parsing — which would have been the format
lane's, not this one's. It does not, so there is nothing to pre-filter: the
blowup is created by `_sorted_leaves`, `_encrypt_tree` and `_decrypt_tree`, all
of which live here.

A parse-time guard would also have been blind to the origin that has no parser
at all. One guard at the API boundary covers both, exactly as `_assert_acyclic`
does for a cycle.

## What sops does

Measured against sops 3.13.3, which decides this and could not be derived:

```
$ sops -e --age age1… bomb25.yaml
Error unmarshalling file: yaml: document contains excessive aliasing   (exit 2, 0.022s)

$ sops -d bomb-encrypted.yaml
yaml: document contains excessive aliasing                             (exit 1, 0.018s)
```

As with the cycle, the refusal **precedes the key**: the same file with no age
identity available still reports the aliasing.

### The budget is a ratio, not a count

This is the finding that shaped everything below, and the first three models of
it were wrong. sops **accepts** a 101,000-node expansion and **refuses** a
6,120-node one. A cap on expanded nodes is therefore not what it enforces, and
anything built as a cap would refuse files sops accepts.

The boundary was bisected against the binary in four differently shaped
families:

| Family | Shape | Last accepted | First refused |
|---|---|---|---|
| A | doubling chain, `W=2` | 8 levels (4,054 expanded) | 9 levels (8,146) |
| B | two levels, `W` wide | `W=80` (32,650) | `W=81` (33,463) |
| C | plain alias chain, `W=1` | 264 deep (106,002) | 265 deep (106,801) |
| D | one anchor, `K` references | `K=2,000` (206,104) | `K=4,500` (463,604) |

No single node count fits those. What fits all four, exactly, is go-yaml's
`decode.go`:

```
decodeCount++            per node the decoder visits
aliasCount++             when that node is inside an alias expansion

fail "document contains excessive aliasing" if
      aliasCount  > 100
   && decodeCount > 1000
   && aliasCount / decodeCount > allowedAliasRatio(decodeCount)

allowedAliasRatio(dc) = 0.99                                    dc <=   400_000
                      = 0.10                                    dc >= 4_000_000
                      = 0.99 - 0.89 * (dc - 400_000)/3_600_000  in between
```

In plainer terms: **the expanded document may be up to about 100 times the
document as written**, and that allowance tightens to about 1.1 times as the
expansion approaches four million nodes. Nothing caps the expansion itself — a
large file may legitimately expand to a large tree, which is exactly why a cap
would have been wrong.

Every boundary above is reproduced by that formula to five decimal places: the
refused side of each pair lands at ratio `0.99000` and the accepted side just
under it.

## Decision

**A document whose expansion is disproportionate to what it contains is
refused, at the API boundary, on go-yaml's own counters and go-yaml's own
constants.**

One guard, `_assert_expansion_bounded`, called from exactly the two places
`_assert_acyclic` is called from — `encrypt` before the data key exists, and
`decrypt` immediately after the parse and before `decrypt_data_key` — so all
eight entry points are covered by two call sites.

### Why go-yaml's numbers and not our own

Because a threshold of our own is a compatibility risk in the one direction
this layer must never fail in. A document sops accepts and we refuse is the
defect class this distribution has repaired repeatedly, and any independently
chosen constant produces one: our tree units are not go-yaml's, and the same
sops-accepted documents come out at amplifications of 82, 89, 97 and 154 in the
most obvious of our own metrics. There is no single constant we could pick that
sits above all of those and still bounds anything.

We do not have to pick one. Both of go-yaml's counters are computable from the
Perl DAG:

- `decodeCount` = nodes in the expanded tree (counting a mapping key as a node,
  as go-yaml does) **plus** the alias node it passes through on the way into
  each repeated container. Every expanded container but the root arrives
  through exactly one edge, and exactly *distinct containers − 1* of those
  edges are anchor definitions rather than aliases.
- the non-alias count = the document **as written**: the document node, every
  distinct container, its keys and its scalar values, and one alias node per
  reference beyond each container's own definition.

Both are computed in one memoised pass, `_expansion_census`, in O(distinct
nodes) — the expansion is counted, never walked. Verified: our two counters
equal the simulated go-yaml counters exactly on all eight boundary documents
(54/60/330/334/1,062/1,066/4,104/10,104 non-alias, and 4,054/8,146/32,650/…
decoded), and the accept/refuse verdict matched the real binary on **400 of 400
randomly shaped documents** plus every boundary pair and the whole tightening
branch.

### Why a memo and not a walk

The same reason ADR 0025 gives for its `$clean` set, and it is correctness of
cost rather than an optimisation: a 30-level diamond has `2**30` paths and 61
nodes, and a guard that walked paths would be the very defect it exists to
remove. The census memoises on `refaddr` and is filled on the way **out**.

That makes the order of the two guards load-bearing: a cycle would recurse
forever inside `_expansion_census`, so `_assert_acyclic` runs first. It is
asserted in `t/43`.

### Where we deviate, and why

sops is a program with a human at a terminal; this is a library. Two
differences, both deliberate:

- **The message is ours, and it carries the numbers.** It says how far out of
  proportion the document is (`expands to 8146 values from the 60 it holds`),
  quotes sops's wording so a reader searching for the sops error finds it, and
  names both origins — the YAML anchor and the shared Perl structure — because
  one guard serves both and only one of them involves YAML.
- **The Perl-structure origin has no sops behaviour to match.** A caller
  sharing one hashref from many places is the same blowup arriving by a road
  sops cannot travel. It gets the same rule, which is a choice, not a
  measurement.

## Consequences

- All eight entry points croak instead of expanding. The refusal happens before
  `_replace_file`, so `encrypt_in_place` leaves the original untouched and
  `encrypt_file` creates no output.
- `ignore_mac => 1` does not get past it. It suppresses verification, not the
  document's shape.
- A document sops accepts is unaffected — that is the claim `t/43` pins, with
  both sides of all four measured boundaries.
- Ordinary anchors, shared subtrees and diamonds are untouched, and a large
  document that shares nothing amplifies nothing and is accepted however big it
  gets.
- Cost: one extra O(distinct nodes) pass. Measured at 0.0008 s on a 265-deep
  DAG and 0.039 s on an ordinary 45,000-node document — 3.3% of that
  document's `encrypt` call.
- No behaviour that reaches the wire changes. These documents never had a
  digest, because they never finished being hashed.

## Known imprecision

Two places where our census and go-yaml's decoder can disagree, neither
affecting any measured document:

- **Merge keys.** `YAML::XS` does not expand `<<: *base`; it hands back a
  literal `<<` key whose value is the shared hash. **Neither does sops**, so
  this is a smaller disagreement than first written here, and possibly none at
  all. *Corrected 2026-08-21, k119.* The original note said "go-yaml
  expands the merge", which is true only when go-yaml decodes into a Go map or
  struct; sops decodes into a `yaml.Node` tree, where it does not. Measured
  while landing k116: `sops -e` on `derived:` / `<<: *b` writes
  `!!merge <<:` carrying its own leaf, encrypted under the AAD path
  `derived:<<:x:` and digested in document order — so `<<` is an ordinary key
  to sops, not an expansion (ADR 0028 has the measurement). The sharing is
  visible to the census either way and a merge-key bomb is still refused; what
  changes is that the two node counts likely agree here rather than differing.
  Anyone touching the census should measure the ratio on a merge-key document
  against the binary rather than deriving it. The underlying `<<` handling is a
  parser question and belongs to ADR 0028, not to this guard.
- **Anchored scalars** are shared by `YAML::XS` (measured), so they are counted
  as one node where go-yaml counts an anchor and an alias. A scalar has no
  subtree and cannot amplify anything, so this moves the ratio by a term that
  cannot reach the threshold on its own.
