# ADR 0028 — The `!!merge` tag is dropped, because the merge key is an ordinary key

- Status: accepted
- Date: 2026-08-21
- Tags: yaml, parser, interop, format
- Resolves k116
- Related: ADR 0001 (the emitter and the MAC are one mechanism — this change is
  measured against that rule and moves neither), ADR 0019 (which rejected text
  surgery for a different case; the difference is set out below), ADR 0026
  (YAML::PP consulted as an authority the resolver cannot supply)
- Corrects a parenthetical in ADR 0027 ("go-yaml expands the merge") — go-yaml
  expands a merge key when decoding into a Go map or struct, and **sops does
  not decode that way**. Measured below. ADR 0027's guard is unaffected; only
  its aside about node counts is imprecise.

## Context

sops does not expand a YAML merge key. It unmarshals into a `yaml.Node` tree,
where go-yaml performs no merge resolution, so `<<` survives as an ordinary
mapping key — and go-yaml's emitter then writes the tag its resolver assigned
back out **explicitly**. Measured, sops 3.13.3, from the plaintext
`base: &b` / `x: 1` / `derived:` / `<<: *b` / `y: 2`:

```yaml
base:
    x: ENC[AES256_GCM,data:9Q==,...,type:int]
derived:
    !!merge <<:
        x: ENC[AES256_GCM,data:fg==,...,type:int]
    "y": ENC[AES256_GCM,data:sA==,...,type:int]
```

The alias is flattened into a copy, and the two `x` leaves are encrypted
independently under different paths.

`YAML::XS` accepts exactly three tags on a scalar — `!!str`, `!!int`, `!!float`
— and dies on every other one. Measured, `!!bool`, `!!null`, `!!binary`,
`!!timestamp`, `!!value`, `!!merge` all die, with `$YAML::XS::LoadBlessed` set
either way. So the document above could not be **opened** here at all:

```
YAML::XS Error: bad tag found for scalar: 'tag:yaml.org,2002:merge'
    at lib/File/SOPS/Format/YAML.pm line 138.
```

A parse error, not a MAC error, on a file `sops -d` reads at exit 0 — the
fourth document in this class after k102, k105 and k108.

And it was never only sops's own documents. This library writes the untagged
spelling, which sops reads happily; measured, one `sops rotate -i` on a
File::SOPS document containing a `<<` key adds the tag, and from that moment
File::SOPS could no longer read the file it had written itself.

## The measurement the decision rests on

The claim in k116 was that the MAC runs over values and not over keys, so
the digest is unaffected. That is the assumption a cheap fix stands or falls
on, so it was measured rather than derived — the stored `mac:` was decrypted
out of each document and compared against a digest computed here, leaf by leaf.

**`<<` is a completely ordinary key on both sides of the wire.**

- It is a **path component in the AAD**. The leaf under a merge key
  authenticates under `derived:<<:x:` and under nothing else. AES-GCM
  authenticates the AAD, so this is a direct measurement of what sops put
  there, not an inference.
- It is **in the digest**, with its whole subtree, in the document's own order,
  exactly like any other key.

Five documents, one per position sops was measured to write the tag in, each
one's stored MAC recovered and reproduced:

| position sops writes | leaves in the digest | stored MAC reproduced |
|---|---|---|
| `derived:` / `!!merge <<:` (mapping key) | `base:x`, `derived:<<:x`, `derived:y` | yes |
| `!!merge <<:` with a **sequence** value (`<<: [*a, *b]`) | `a:p`, `b:q`, `derived:<<:p`, `derived:<<:q`, `derived:r` | yes |
| `- !!merge <<:` (first key of a sequence entry) | `tpl:k`, `list:<<:k`, `list:m` | yes, in **document** order |
| `!!merge <<:` at the document root | `<<:k`, `tpl:k`, `z` | yes |
| `!!merge <<:` inside a `!!merge <<:` | `outer:<<:<<:deep` and four more | yes |

The third row is worth its own line: its document order is not its sorted-key
order, and it reproduces only in document order. That is the order-preserving
reparse of ADR 0001 walking a merge key like any other key — YAML::PP reads the
tag without complaint and gives the same literal `<<`, so the parallel walk
lines up.

So the tag is **the only thing** that separates a document we cannot open from
a document whose every path and every digest byte we already agree with.

## Decision

**On the read path, and only after `YAML::XS` has already refused the document,
an explicit `!!merge` tag in tag position is removed from the text and the
parse is retried. Nothing else changes: the tree, the AAD paths, the digest and
every emitted byte are what they were.**

The retry is reconciled against ground truth before its result is used.
`YAML::PP`'s **parser** — events only, no tree and no resolver — reports how
many merge-tagged scalars the document really contains. Unless the substitution
removed exactly that many, nothing is retried and libyaml's own error stands,
unchanged.

That reconciliation is what makes the surgery sound rather than merely narrow:

- If the pattern **missed** a real tag, the tag is still in the text and
  `YAML::XS` refuses again — so a successful retry proves every real tag was
  removed.
- If the pattern **also hit** something that was not a tag, the counts differ
  and nothing is retried.
- Both at once means a real tag remained, so the retry fails.

A retry that succeeds with matching counts therefore had no mis-hit. The
guarantee is structural, not statistical.

`emit` is untouched. `YAML::XS` has no per-scalar tag control, so this module
writes the plain `<<` spelling — which is not a loss: go-yaml's resolver
assigns the merge tag to a plain `<<` key for itself, and measured, `sops -d`
on a document *we* wrote as `<<:` prints `!!merge <<:` back. A full cycle was
measured in both directions, sops 3.13.3, all at exit 0: sops encrypts →
File::SOPS reads with the MAC verified → File::SOPS rotates → `sops -d` reads →
File::SOPS decrypts to plaintext → `sops -e` re-encrypts → File::SOPS reads it
again.

## Why this text surgery, when ADR 0019 rejected text surgery

ADR 0019 rejected quoting an arbitrary leaf on the way out, because "doing it
for an arbitrary key path at arbitrary nesting is a new mechanism with a
corruption failure mode worse than the divergence it fixes". Every clause of
that sentence is different here.

| ADR 0019's rejected surgery | this one |
|---|---|
| on the **write** path, on a finished document about to go on the wire | on the **read** path, on input about to be parsed |
| had to find an arbitrary key path at arbitrary nesting | one fixed token, `!!merge`, in one lexical position |
| ran on every document | runs only on a document `YAML::XS` has already refused |
| a mis-hit writes a corrupt file that everyone downstream accepts | a mis-hit cannot reach the parser: the count check refuses first |
| the token it removed would have had to be re-derived | the token is **redundant by construction** — a plain `<<` resolves to this very tag, which is why go-yaml can add it back |

The kinship is with `_quote_sops_timestamp`, which ADR 0019 named as the case
where surgery is legitimate: one known token in one known position.

## Alternatives rejected

**Parse the affected documents with YAML::PP instead.** YAML::PP reads the tag
and gives the same literal `<<` key, so it would work — and it is already this
distribution's second parser. It is still wrong. Types come from the parser
(ADR 0002) and the two resolvers disagree, so a document would be typed by
whether it happened to carry a merge tag: the same leaf, `0x10` or `1_000` or a
bare `.inf`, would come back as a different value depending on a tag somewhere
else in the file. ADR 0001's rule is that the parser and the digest are one
mechanism; swapping the parser for one class of document breaks that quietly.
YAML::PP is used here for the one thing it can answer without resolving
anything — *how many merge-tagged scalars are in this text* — which is the same
shape as ADR 0026's use of it.

**A tag handler in YAML::XS.** There is none. The accepted set is fixed in the
XS layer, and none of the module's knobs (`Boolean`, `LoadBlessed`, `LoadCode`,
`QuoteNumericStrings`, `ForbidDuplicateKeys`, `Indent`, `UseCode`,
`DumpCode`) reaches it. Measured with `LoadBlessed` both ways.

**Refuse with a clear message.** More honest than a libyaml error, and it was
the right answer for k108 (ADR 0024), where refusing closed a path that
otherwise wrote a phantom value into the document permanently. There is no such
path here. Nothing is corrupt, nothing is ambiguous, and nothing is lost: the
tree behind the tag is a tree we already agree with sops about, byte for byte,
digest included. Refusing would leave a document sops writes *and* reads
unreadable here, and would leave our own `<<` documents one `sops rotate -i`
away from being unreadable to us — for a tag that carries no information.

**Expand the merge, the way a caller expecting merge semantics would want.**
Rejected, and it is the open side-question in k116. sops does not expand
it; a document whose `<<` had been folded into its parent would have different
paths, a different digest and a different shape from the file on disk. See
below.

## Consequences

- A document with a merge key that sops wrote is readable here, with the MAC
  verified — five positions measured, including a sequence-valued merge key and
  a merge key inside a merge key.
- A File::SOPS document with a `<<` key survives a `sops rotate -i` and stays
  readable here.
- **No document that could be read before is read differently.** The retry runs
  only after a parse that already failed, so every document that parses today
  takes the identical path it always did.
- **Nothing that reaches the wire moves.** No AAD path, no digest byte, no
  emitted byte. This is squarely the format lane and not the wire lane, and the
  table above is the evidence for that rather than the assumption behind it.
- `t/44-yaml-merge-key-tag.t` pins it: 12 subtests, of which 6 fail against the
  unpatched library and 6 pass — the six that pass are the ones pinning what
  must not move.

### What a caller sees, and what it does not

Unchanged, and deliberately: `YAML::XS` does **not** resolve `<<: *b` into the
parent mapping. It hands back a literal `<<` key whose value is the shared
node, and this change does not touch that. So

```yaml
base: &b
  x: 1
derived:
  <<: *b
  y: 2
```

reads as `{ base => { x => 1 }, derived => { '<<' => { x => 1 }, y => 2 } }`,
with no `x` in `derived` itself. A caller who expects YAML merge semantics does
not get them — but that is what makes the round trip with sops correct, because
sops does not fold the key either, and folding it here would produce a tree
whose paths and digest no longer match the file. The tagged and untagged
spellings now give the identical tree, which is the whole of the change.

## Limits, and what is deliberately not covered

- **A merge tag the pattern cannot see** — flow style (`{!!merge <<: *a}`), or a
  `%TAG`-directive spelling — is refused exactly as it is today, with libyaml's
  message. sops does not write either.
- **A block or quoted scalar whose text mimics a tag line** and that sits in a
  document which *also* has a real merge tag is refused rather than repaired,
  by the count check. A document with only the mimic and no real tag never
  reaches the retry at all and keeps its scalar byte for byte.
- **The other tags `YAML::XS` refuses** — `!!bool`, `!!null`, `!!binary`,
  `!!timestamp`, `!!value` — are untouched, and they do not need to be for the
  read path. `!!merge` is the only tag sops was measured to *write*: given a
  plaintext leaf carrying an explicit tag, `sops -e` resolves it and drops the
  tag, every time.

  | plaintext leaf | what `sops -e` writes |
  |---|---|
  | `!!binary aGVsbG8=` | `hello` |
  | `!!timestamp 2001-12-14t21:59:43.10-05:00` | `2001-12-14T21:59:43.1-05:00` |
  | `!!bool true` | `true` |
  | `!!null ~` | `null` |
  | `!!str 5` | `"5"` |

  The **encrypt** path is a different matter and is not fixed here: `sops -e`
  accepts all five of those plaintext documents and `File::SOPS->encrypt_file`
  refuses three of them, at parse, with libyaml's message. Recorded as karr
  k118 with this measurement rather than widened into this change — the retry
  is sound because `<<` is a key whose tag carries nothing, and each of those
  tags carries a **type**, which is ADR 0002's territory and a different
  question.
