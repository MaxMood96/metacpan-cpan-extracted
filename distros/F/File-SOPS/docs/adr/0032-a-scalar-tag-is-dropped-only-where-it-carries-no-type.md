# ADR 0032 — A scalar tag is dropped only where it carries no type; the rest are refused by name

- Status: accepted
- Date: 2026-08-21
- Tags: yaml, parser, interop, format, types
- Resolves k118
- Extends ADR 0028 (the `!!merge` repair — same mechanism, same reconciliation,
  and this is the second and last token that qualifies for it). ADR 0028's
  "Limits" section deferred exactly this question and its measurement table is
  reproduced and completed below.
- Rests on ADR 0002 (the type comes from the scalar), which is what makes the
  answer different for `!!bool` than for every other tag here.
- Related: ADR 0013 / ADR 0017 (the foreign-resolution guard, which is what
  keeps the *write* side of this honest), ADR 0019 (a string Go reads as a
  boolean), ADR 0024 (a refusal is the right answer where a repair would
  change a value; also the rule that an error message is no place for
  plaintext).

## Context

`YAML::XS` accepts exactly three tags on a scalar — `!!str`, `!!int`, `!!float`
— and dies on every other one:

```
YAML::XS Error: bad tag found for scalar: 'tag:yaml.org,2002:binary'
```

That is a message about a foreign library, not about the document. sops accepts
all of them, resolves them, and writes the resolved value with the tag gone. So
a hand-written plaintext that `sops -e` encrypts at exit 0 could not be
**opened** here at all — the fifth document class in this position after karr
k102, k105, k108 and k116, and the first that is purely on the **encrypt** path:
sops writes none of these tags into an encrypted document. `!!merge` was the
only one it writes, and that is ADR 0028.

ADR 0028 deferred this deliberately, and the reason it gave is the reason this
ADR exists: `<<` is an ordinary key whose tag carries nothing, while **every tag
here carries a type** — and in this distribution the type comes from the scalar
(ADR 0002). Removing such a tag is not a tag removal, it is a retype.

## The measurement

sops 3.13.3, one leaf encrypted and the same leaf under a `_unencrypted` key,
with the stored `mac:` decrypted out of each document and the digest reproduced
here leaf by leaf. `type` and `plaintext` are the encrypted slot; the plaintext
is also exactly what the MAC covers.

| plaintext leaf | sops type | sops plaintext = MAC bytes | unencrypted slot | File::SOPS before |
|---|---|---|---|---|
| `!!bool true` | `bool` | `True` | `true` | dies |
| `!!bool false` | `bool` | `False` | `false` | dies |
| `!!bool True` | `bool` | `True` | `true` | dies |
| `!!bool yes` | — | sops **refuses** the plaintext | — | dies |
| `!!binary aGVsbG8=` | `str` | `hello` | `hello` | dies |
| `!!binary AAECAw==` | `str` | the four bytes `00 01 02 03` | (re-encoded) | dies |
| `!!timestamp 2026-08-21` | `time` | `2026-08-21T00:00:00Z` | `2026-08-21T00:00:00Z` | dies |
| `!!timestamp 2001-12-14t21:59:43.10-05:00` | `time` | `2001-12-14T21:59:43.1-05:00` | same | dies |
| `!!null ~` | — | not encrypted, **nothing hashed** | `null` | undef, ok |
| `!!null Null` | — | not encrypted, nothing hashed | `null` | dies |
| `!!str 5` | `str` | `5` | `"5"` | `str`, `5` — agrees |
| `!!int 42` | `int` | `42` | `42` | `int`, `42` — agrees |
| `!!int 0755` | `int` | `493` | `493` | `int`, **`755`** |
| `!!float 1` | `float` | `1` | `1` | **`int`**, `1` |
| `!!float 1.50` | `float` | `1.5` | `1.5` | `float`, `1.5` — agrees |
| `!!value 1` | `str` | `1` | `"1"` | dies |
| `!!seq x` / `!!set x` / `!!omap x` / `!!map x` | `str` | `x` | `x` | dies |

The `!!null ~` row is not a rounding of the truth: the whole document's MAC
plaintext came out as `CF83E135…` — SHA-512 of the empty string — with both
leaves present. A null contributes nothing to the digest.

### The one row where the tag carries nothing

`!!bool true` and a bare `true` produce **byte-identical documents**. Same
`type:bool`, same plaintext `True`, and the two stored MACs decrypted to the
same 128 hex characters. The same for `false`. That is the `!!merge` situation
exactly: a plain `true` resolves to `tag:yaml.org,2002:bool` on both sides, so
the tag is redundant by construction.

### And the rows where it carries a type

- **`!!binary` is the only case where sops changes the value.** It base64-
  *decodes* the scalar; `aGVsbG8=` becomes `hello`, and those decoded bytes are
  what the digest covers. Dropping the tag would encrypt the base64 text — a
  different value, a different digest, and a document that disagrees with the
  one sops writes from the same plaintext.
- **`!!timestamp` normalises the spelling.** `2026-08-21` becomes
  `2026-08-21T00:00:00Z` under `type:time`. Dropping the tag leaves the source
  spelling as a string, so the two sides would digest different bytes.
- **`!!bool` on a spelling libyaml does not resolve** (`True`, `False`, `TRUE`,
  `FALSE`, or a quoted `true`) types the leaf `bool` at sops and `str` here. The
  digest bytes still agree — `True` on both sides — so such a file *verifies*;
  the type does not.
- **`!!null Null`** is a null to sops, hashed as nothing; dropping the tag makes
  it the string `Null`, which is hashed.
- **`!!value`, `!!set`, `!!omap`, `!!seq`, `!!map` on a scalar** keep their text
  verbatim under `type:str` — but only because the tag suppressed go-yaml's own
  resolver. `!!value 1` is the string `1` there and would be the integer `1`
  here.

### The silent divergence hunt, and what it found

k118 asked, before anything else, whether the tags `YAML::XS` *accepts*
hide a worse defect: a document we open and type differently from sops. The
answer is **yes, one — and it is not caused by a tag.**

`!!int 0755` is `type:int` on both sides, and the values are **493 there and
755 here**: go-yaml reads a leading zero as octal, libyaml as decimal. The tag
changes nothing about it — the untagged `0755` diverges identically, and
measured, the two documents' MACs are the same on each side. So this is karr
k29's parser divergence, not this ticket's, and its dangerous half is **already
closed**: the foreign-resolution guard (ADR 0013 / ADR 0017) refuses to *write*
such a leaf unencrypted, with a message naming the octal, which is what would
otherwise fail the document's own MAC. What remains is an encrypted leaf whose
value differs from sops's — self-consistent on both sides, `sops -d` exit 0,
recorded as a fidelity gap and not touched here.

`!!float 1` is the second, and it is milder: sops writes `type:float`, we write
`type:int`, and both write the plaintext `1`. Since Go re-derives the digest
from the declared type, `ToBytes` produces `1` either way and the file verifies
in both directions. It is a type-label difference with no digest consequence.

Everything else in the accepted set — `!!str`, `!!int`, `!!float` on spellings
libyaml resolves — agrees with sops exactly, byte for byte.

## Decision

**A scalar tag is removed before parsing only where it has been measured to
carry no type. That is `!!bool` on a plain `true` or `false`, and nothing else.
Every other yaml.org tag on a scalar is refused by name, saying what sops
resolves the tag to.**

The repair is ADR 0028's mechanism, unchanged in shape:

- It runs **only after `YAML::XS` has already refused the document**, so nothing
  that parses today takes a different path.
- The substitution matches `!!bool` in tag position followed by a **plain**
  `true`/`false` ending the node, and is reconciled against ground truth before
  its result is used: `YAML::PP`'s **parser** — events only, no tree, no
  resolver — reports how many `!!bool`-tagged scalars sit on a plain
  `true`/`false`. Unless the substitution removed exactly that many, nothing is
  retried.
- The count is deliberately *not* "how many `!!bool` tags are in this document"
  but "how many of them this substitution is allowed to touch". A document
  mixing `!!bool true` with `!!bool True` therefore has the equivalent tag
  removed, fails the parse again on the other one, and gets the refusal that
  names it.

The refusal answers **from the document**, not from libyaml's message: libyaml
names whichever tag it reached first, which after a repair need not be the one
still there. A second `YAML::PP` parser pass finds the first tagged scalar this
module cannot honour and reports its **key path**, joined with colons and with a
sequence contributing no component — the AAD rule, so the path in the message is
the path the leaf would have authenticated under. The scalar's own text is
**never** quoted back; it is plaintext (ADR 0024's rule). Where the scan finds
nothing, or `YAML::PP` refuses the document too, libyaml's own message stands
unchanged.

`!!str`, `!!int`, `!!float` and `!!merge` are not spoken for. The first three
`YAML::XS` reads; the fourth is ADR 0028's repair. A document that fails on one
of them — `!!int 0x10`, `!!int 1_000`, `!!float .inf`, all of which sops
resolves and libyaml refuses as *content* rather than as a bad tag — keeps
libyaml's message, because that is k29 and not this decision.

## Why `!!binary` is not decoded here

Decoding would be defensible on its face — it is what sops does — and it is
rejected for two independent reasons.

**It is not this lane's change.** Decoding turns the scalar into different bytes
before anything else sees it, which moves the value, the ciphertext and the
digest. That is the wire layer, not the parser, and the rule for this module is
that a formatting change which can move the digest is handed over rather than
decided here.

**And it would be a much bigger change than it looks.** The decoded bytes are
not text. This distribution encodes every value as UTF-8 unconditionally (ADR
0003), with `type:bytes` as the single exemption — and sops does not use
`type:bytes` for `!!binary`, it uses `type:str` with the decoded bytes inside.
So a `!!binary` whose content is not valid UTF-8 (`AAECAw==` measured above) has
no representation on this side that both round-trips and stays a Perl character
string, and its *unencrypted* twin would have to be re-encoded as `!!binary` on
the way out, which this module has no way to emit. Refusing states that
honestly; decoding halfway would not.

## Alternatives rejected

**Strip every tag and let the resolver sort it out.** This is the shape of the
`!!merge` repair applied without the measurement, and the table above is why it
fails: four of the seven tags resolve to a different value, a different type, or
both. `!!binary aGVsbG8=` would become the string `aGVsbG8=` where sops has
`hello`.

**Parse the affected documents with `YAML::PP`, which reads every tag.**
Rejected for the same reason ADR 0028 rejected it, and more sharply here: types
come from the parser, the two resolvers disagree, and a document would be typed
by whether it happened to carry a tag somewhere. `YAML::PP` is used here only
for what it can answer without resolving anything — how many scalars carry which
tag, and where they sit.

**Refuse `!!bool` too, for symmetry.** Symmetry is not a reason. `!!bool true`
was measured to be the same document as `true`, MAC included; refusing it would
leave a plaintext sops encrypts and this library cannot open, for a tag that
demonstrably carries nothing.

**Accept `!!bool True` by stripping it as well.** The digest bytes agree
(`True`), so the file would verify — but the leaf would be `type:str` where sops
writes `type:bool`, silently. That is exactly the divergence ADR 0019 warns
about on the write path, and turning a hard failure into a silent retype is the
wrong direction. The refusal names the spelling rule instead, and the caller who
writes `true` gets the sops-identical document.

**Normalise `!!timestamp` to RFC3339 here.** It would make the tagged spelling
agree with sops — and it would be a new value transformation implementing Go's
time parsing and rendering, on the wire path, for a type Perl does not have.
Handed to the wire lane as a question rather than answered here; note that the
*untagged* spelling has the identical divergence and is not fixed either.

## Consequences

- A plaintext YAML carrying `!!bool true` or `!!bool false` encrypts here into
  the document sops writes from the same plaintext: `type:bool`, plaintext
  `True`/`False`, and `sops -d` reads it at exit 0.
- The other tags die exactly as they died before. **What changed for them is the
  message**, which now names the tag, the key path, and what sops resolves the
  tag to — instead of `bad tag found for scalar`, which looks like a defect in
  a foreign library.
- **No document that could be read before is read differently.** The retry runs
  only after a parse that already failed.
- **Nothing that reaches the wire moves.** No AAD path, no digest byte, no
  emitted byte; the emitter is untouched and still writes no tag at all. The
  measurement above is the evidence for that rather than the assumption behind
  it.
- `t/47-yaml-scalar-type-tags.t` pins it: 15 subtests, of which 8 fail against
  the unpatched library and 7 pass — the seven that pass are the ones pinning
  what must not move.
- `t/44-yaml-merge-key-tag.t` had pinned the `!!binary` refusal as *libyaml's*,
  with the comment "a separate gap, not this one". That claim is deliberately
  replaced: `!!binary` is still refused, by this module and by name.

## Limits, and what is deliberately not covered

- **A tag the pattern cannot see** — flow style (`{v: !!bool true}`), or a
  `%TAG`-directive spelling — is refused with the message this change adds, but
  never repaired. The count reconciliation sees the tag and the substitution
  does not remove it, so the counts disagree and nothing is retried. sops writes
  neither.
- **`!!int 0755` on an encrypted leaf** stays a fidelity gap: `493` to sops,
  `755` here, both self-consistent, k29's class. Its unencrypted twin is
  already refused by the foreign-resolution guard.
- **`!!float 1` is still `type:int` here.** The digest agrees and the file
  verifies in both directions, so this is a label difference with no wire
  consequence; recorded rather than fixed, because fixing it means taking a type
  from a tag instead of from the scalar, which is ADR 0002's territory.
- **An untagged timestamp is `type:str` here and `type:time` at sops**, with the
  spelling normalised there and not here. That is not a tag question at all —
  the tagged and untagged spellings were measured to give sops the identical
  result — and it is left open with the `!!timestamp` refusal, not closed by it.
- **`!!value`, `!!set`, `!!omap`, `!!seq` and `!!map` on a scalar** would in fact
  be strippable for a scalar whose untagged spelling resolves to a string, and
  not for one that does not (`!!value 1`). The distinction is per-scalar and the
  tags are ones sops never writes and no sane document carries, so they are
  refused whole rather than split.
