# ADR 0026 — A plain YAML infinity is the float go-yaml reads

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`; nothing is
  inherited from the ticket, and two of the ticket's premises did not survive
  the measurement (see "What the ticket had wrong").
- Date: 2026-08-21
- Tags: float, yaml, wire-format, interop, parser, mac
- Resolves k105
- Depends on ADR 0001 (order and values come from two different parses, and a
  leaf repaired in the parse reaches the digest through the side that was
  repaired), ADR 0002 (the type comes from the SV — which is why this decision
  needs an authority *outside* the SV, and says so), ADR 0006 (`+Inf` / `-Inf` /
  `NaN` as a non-finite float's digest text), ADR 0013 and ADR 0017 (`%GO_CONSTANT`,
  the Go resolution model, which already holds the answer and is re-verified
  here) and ADR 0023, whose walk this one runs after and whose stated
  disjointness it has to keep true
- Does **not** touch the non-finite guard from k59 in
  `Encrypted::assert_representable`. A measurement that says the guard is now
  too wide for one scalar shape is in "What this leaves broken", and is filed
  rather than acted on

## Context

`File::SOPS` cannot read a YAML document sops writes and sops verifies, when
that document holds a bare `.inf` in an unencrypted slot. Reproduced at 7a12364:

    plaintext   keep: x
                v_unencrypted: .inf

    sops -e     exit 0, the wire holds `.inf` verbatim
    sops -d     exit 0

    File::SOPS->decrypt of that same file
      -> MAC verification failed: the digest over 2 leaf values in document
         order does not match the one stored in the sops section.

`YAML::XS` is libyaml, whose resolver leaves `.inf` a **string**; `gopkg.in/yaml.v3`
resolves it to the float `+Inf`, and sops digests `+Inf`. So our digest covers
four characters and Go's covers four different ones.

### What sops actually writes, measured

Twelve spellings, one `sops -e` per row, both slots, sops 3.13.3:

| source | `sops -e` | encrypted slot | unencrypted wire | MAC plaintext |
|---|---|---|---|---|
| `.inf` `.Inf` `.INF` `+.inf` `+.Inf` `+.INF` | exit 0 | `type:float`, plaintext `+Inf` | **`.inf`** | `+Inf` |
| `-.inf` `-.Inf` `-.INF` | exit 0 | `type:float`, plaintext `-Inf` | **`-.inf`** | `-Inf` |
| `.nan` `.NaN` `.NAN` | exit 0 | `type:float`, plaintext `NaN` | **`.nan`** | `NaN` |

The MAC plaintext was read out of each document's own `mac:` field and matched
against a digest computed here, not inferred. Two things follow.

`%GO_CONSTANT` in `Format::YAML` is **right**, verified against the binary
rather than against its source: all twelve map to exactly the bytes sops digests.

And **sops normalises nine of the twelve spellings away.** Only `.inf`, `-.inf`
and `.nan` can appear in a document sops wrote, which is the same shape as
ADR 0013's `mode: 0755` → `493` — except that there the normalisation removed
the read-side problem entirely, and here it leaves three tokens that still
disagree.

### The measurement that decides the shape of the repair

A quoted `".inf"` is a **string** to sops, and its digest is the token:

| document, unencrypted slot | sops digests | this module digests | `File::SOPS->decrypt` |
|---|---|---|---|
| `v_unencrypted: .inf` | `+Inf` | `.inf` | **MAC verification failed** |
| `v_unencrypted: ".inf"` | `.inf` | `.inf` | reads, `'.inf'` |

`YAML::XS` returns **the same POK-only scalar for both**. The two documents are
different, their digests are different, and our parse result cannot tell them
apart. Worse, both spellings occur in one document as easily as in two —
measured, sops writes this and `sops -d` reads it back at exit 0:

    list_unencrypted:
        - .inf          <- Go: float, digested `+Inf`
        - ".inf"        <- Go: string, digested `.inf`
        - one

So **any repair keyed on the leaf's text is wrong**: it fixes row 1 and breaks
row 2, which works today. The missing fact is not in the value. It is whether
the document wrote that scalar **plain**, and that is a fact about the bytes.

### The oracle

`YAML::PP` — already this distribution's second parser (ADR 0001) — answers it.
Its Core schema resolves a scalar to a non-finite number **iff** the scalar was
written plain and its token is one of the twelve. Measured, three ways:

| probe | rows | resolves non-finite |
|---|---|---|
| the twelve `%GO_CONSTANT` tokens, plain | 12 | **12** |
| nine near-miss spellings (`.INf` `.iNF` `.Nan` `.NAn` `+.nan` `-.nan` `-.NAN` `.infinity` `.Infinity`) and the bare `Inf` / `inf` / `NaN` class | 12 | **0** |
| the twelve, single- or double-quoted | 24 | **0** |

The near-miss row is the one that matters: every one of those twelve is a
`type:str` to sops, digested verbatim, and read correctly here today. YAML::PP
declines all of them, so the oracle's boundary and sops's boundary are the same
boundary.

Four edge cases, on the **wire** document rather than the plaintext, because
that is what the read path sees:

| plaintext | sops writes | sops digests | YAML::PP on the wire |
|---|---|---|---|
| `!!float .inf` | `.inf` | `+Inf` | non-finite |
| `&a .inf` | `.inf` | `+Inf` | non-finite |
| `!!str .inf` | `".inf"` | `.inf` | string |
| `'.inf'` | `".inf"` | `.inf` | string |

sops normalises the tag and the anchor away, so the wire carries only the two
spellings the oracle already separates, and it separates them correctly in all
four.

This is **not** the "ask YAML::PP instead of modelling Go" that ADR 0013 and
ADR 0023 rejected. There the question was *what value is this*, and YAML::PP
answers it the way libyaml does — `0755` is 755 to both and 493 to Go, so it
agrees with the side that is already wrong. Here the question is *was this
scalar written plain*, which is syntax, not resolution; the **value** still
comes from `%GO_CONSTANT`, and the token has to be in `%GO_CONSTANT` before
YAML::PP is consulted at all. A parser that reads the same bytes we do is a
perfectly good authority on what the bytes say; it is a bad authority on what
another language's resolver makes of them.

## Decision

**`File::SOPS::Format::YAML::parse` replaces a leaf that the document wrote as a
plain scalar whose token go-yaml resolves to a non-finite float with a
`dualvar` carrying that float and that token.**

The walk runs after the `sops` section is split off and after ADR 0023's
`_restring_non_finite_leaves`, and:

1. **runs only for a document that carried a `sops:` section.** A plaintext
   document has no MAC for a foreign reader to disagree with, and on the encrypt
   path ADR 0013's guard already refuses this leaf with a message that names the
   key path and the resolver disagreement — a better error than the one the
   non-finite guard would give (see "What this leaves broken"). It also keeps
   ADR 0023's pinned disjointness (`t/39`, section 2) true for the input it
   measures;
2. **gates twice, cheapest first.** A plain scalar is literal text, so a
   repairable token is in the raw bytes or it is nowhere: one scan of
   `$content` for `.inf` / `.nan` and their cases, built from the same
   `%GO_CONSTANT` keys, ends it for a document that never mentions one. (The
   filter can only be conservative in the harmless direction: the one way the
   string `.inf` reaches a leaf without those bytes in the document is an
   escape in a *quoted* scalar, which this walk does not repair.) `config.info`
   and `.infrastructure` carry the bytes as well, so a second pass over the
   tree then looks for a plain-scalar leaf whose first byte is `.`, `+` or `-`
   and whose text is one of the twelve. Only past both is `YAML::PP` asked for
   anything;
3. **asks the document.** `YAML::PP` (Core schema) loads the same raw content,
   the `sops` branch is dropped from its tree too, and the two trees are walked
   in parallel;
4. **replaces only where both sides agree.** The `YAML::XS` leaf must be a
   defined, unreferenced scalar with public `SVf_POK` and neither public
   `SVf_NOK` nor public `SVf_IOK` — a plain string, read off the SV, nothing
   numified (ADR 0002, k32) — whose text is a key of `%GO_CONSTANT`. The
   `YAML::PP` leaf at the same position must be a scalar with public `SVf_NOK`
   whose NV is `NaN` or `±Inf`. The replacement is
   `dualvar($double, $token)`: the double derived from `%GO_CONSTANT`'s own
   byte string, so there is one token list and not two, and the token taken
   from the document, so every emitter writes back exactly what it read;
5. **fails safe.** Replacements are collected and applied only if the parallel
   walk completed with the two trees structurally identical. A `YAML::PP` that
   dies, a shape mismatch, a missing key — any of them and **nothing** is
   replaced, which is today's behaviour and today's MAC error.

### Why a dualvar and not a plain infinity

Both make the digest right. The dualvar also makes the **document** right.

`value_to_bytes` reads the numeric half either way, so the digest is `+Inf`
from both. What differs is what an emitter writes: measured, `YAML::XS` writes a
bare non-finite NV as `Inf` / `-Inf` / `NaN` — tokens go-yaml resolves as
**strings** — and writes `dualvar(+Inf, '.inf')` as `.inf`, the token sops
itself writes. So `decrypt_file` of such a document reproduces sops's own
plaintext byte for byte, and its output re-encrypts to the same value it came
from, where a plain infinity would have degraded to the string `Inf` on the
first plaintext round-trip.

It is also what ADR 0011's carrier already does one layer down: a float leaf
whose string half is the text the document contains.

### What the ticket had wrong

k105 says the repair "would have to manufacture a real `+Inf` on parse,
which `assert_representable` then refuses on any re-encrypt, so `rotate` breaks
on a document we just learned to read". Measured, both halves of that are off:

- **`rotate` already breaks on that document**, before this change, with
  `MAC verification failed` — the read is the first thing it does. Nothing that
  worked stops working, because nothing worked.
- **The blocking case is a different one entirely**: the quoted `".inf"` above,
  which the ticket does not mention and which no text-keyed repair can survive.

### What was measured

A 24-row corpus — the twelve tokens × two slots — each document written by
`sops -e` and read back by `File::SOPS->decrypt`, plus the same twelve through
`File::SOPS->encrypt_file` and handed to `sops -d`. At f5d433d and again after:

| direction | before | after |
|---|---|---|
| `sops -e` → `File::SOPS->decrypt`, **unencrypted** slot | **0 of 12 read** | 12 of 12 |
| `sops -e` → `File::SOPS->decrypt`, **encrypted** slot | 12 of 12 | 12 of 12, unchanged |
| `File::SOPS->encrypt_file` → `sops -d`, either slot | 12 croak / 12 exit 0 | **unchanged** |

Alongside it, the rows that must not move, every one of them a document sops
writes and `sops -d` reads: the twelve tokens single- and double-quoted, the
twelve near misses, `"1_000"`, an ordinary string, `1e400` and ADR 0023's
overflow class. **None moves**, before or after.

Counter-check: the new file `t/42-yaml-plain-infinity-is-a-float.t` was run
against the unpatched f5d433d first — **7 of its 17 subtests and 44 assertions
fail**, and every one of the ten that pass is a "must not move" section. That
is the shape a text-keyed repair would invert: it would turn section 1 green
and sections 3 to 6 red, silently.

`prove -lr t/` was 934/934 at 7a12364 and 941/941 at f5d433d, and is 974/974
with the new file, no
existing test edited; `SOPS_BIN=/tmp/sops prove -l t/04-interop.t` is 32/32,
executed rather than skipped, before and after.

## Consequences

### Wire bytes that move

None on the write path. `File::SOPS` still cannot *create* a document with a
bare `.inf` in a MAC-covered slot — ADR 0013 refuses it for a caller-supplied
string, and the non-finite guard refuses it for the dualvar this walk produces.

On the read path, a plain `%GO_CONSTANT` token in an unencrypted YAML slot goes
into the digest as `+Inf` / `-Inf` / `NaN` instead of as its own text. That is
what sops digests for the same document, and it is the entire fix.

### What changes for existing callers

| input | before | after |
|---|---|---|
| sops-written YAML, bare `.inf` / `-.inf` / `.nan` in an **unencrypted** slot | MAC verification failed | reads; the leaf is a float whose text is the token |
| the same, hand-written `.Inf` `.INF` `+.inf` `-.INF` `.NAN` … (nine spellings sops normalises away, reachable only in a file sops did not write) | MAC verification failed | reads |
| the same slot holding a **quoted** `".inf"` | reads, `'.inf'` | **unchanged** — still the string, still verifies |
| `.INf` `.iNF` `+.nan` `.infinity` `Inf` `NaN` and the rest of the near misses | reads, a string | **unchanged** |
| an **encrypted** `type:float` whose plaintext is `+Inf` | a real Perl infinity | **unchanged** |
| a **plaintext** YAML parsed by `encrypt_file` | ADR 0013's refusal, naming the key path | **unchanged** — the walk does not run |
| `decrypt` / `extract` of a repaired slot | never returned | a `dualvar`: `+Inf` numerically, `.inf` as text |
| `decrypt_file` of such a document | never got that far | writes `v_unencrypted: .inf`, byte-identical to `sops -d` |
| `rotate` / `edit` of such a document | croak, `MAC verification failed` | croak, the non-finite guard, **naming the key path** |
| a YAML literal that overflows a double (`1e400`) | ADR 0023's string | **unchanged** — not a `%GO_CONSTANT` token, so this walk never sees it |

### What this leaves broken, and why it is filed rather than fixed

A document this now reads still cannot be written back. `_compute_mac` runs
`assert_representable` over every leaf, and k59's non-finite guard refuses
the dualvar.

The guard's stated premise does not hold for this scalar shape, and that was
measured rather than argued: with the guard bypassed **in a scratch process, no
code changed**, `File::SOPS->encrypt` of a tree holding `dualvar(+Inf, '.inf')`
in an unencrypted slot writes `v_unencrypted: .inf` and `sops -d` reads it back
at **exit 0** — five tokens tried, five exit 0. The guard is right about a bare
non-finite NV, which `YAML::XS` writes as `Inf`; it is too wide for one that
carries a `%GO_CONSTANT` token as its string half.

Narrowing it is a decision about a guard, with its own corpus and its own ADR,
and k105 says in as many words not to take it here. Filed as k113.

### Cost

Measured per `parse`, against the same code with the walk stubbed out:

| document | before | after |
|---|---|---|
| 20 leaves, no token | 0.096 ms | **0.096 ms** |
| 20 leaves, a `config.info` key | 0.096 ms | 0.115 ms |
| 20 leaves, one bare `.inf` | 0.096 ms | 2.5 ms |
| 1000 string leaves, no token | 2.9 ms | **2.8 ms** |
| 1000 string leaves, one bare `.inf` | 2.5 ms | 107 ms |

The first gate is what makes the ordinary row free; without it the tree walk
alone cost 2.9 ms → 4.1 ms per 1000 leaves, which is a 40% tax on every parse
for a defect three tokens wide. A document that really holds one pays a second
`YAML::PP` load of the raw content and one parallel walk — on the decrypt path
the third parse of the document (`YAML::XS` for values, `YAML::PP` for order
under ADR 0001, `YAML::PP` again here), and paid only by the documents that
were unreadable before.

Seven structural edge cases were put through `parse` to check that the pairing
neither hangs nor mispairs: a recursive anchor, a shared (non-recursive) alias,
a token three levels down inside a list, a duplicate key, the token as a
mapping **key** beside a quoted one as a value, an empty document, and a token
inside the `sops` branch. All seven answer correctly. The recursive one is the
only place the fail-safe fires — `YAML::PP` refuses it outright (`Found cyclic
ref for alias 'a'`) where `YAML::XS` hands back a real Perl cycle, so nothing
is repaired and the document is refused downstream by k110's guard anyway.

All three walks carry their own visited set. A recursive YAML anchor really does come
back from `YAML::XS` as a cycle (ADR 0023), and the parallel walk would follow
it twice over.

## Rejected alternatives

**Repair the MAC path instead of the parse** — k105's option (ii): leave the
leaf a string in the tree and give the digest Go's bytes for this one token. It
needs the format-blind `_value_to_bytes` in `File::SOPS` to learn a YAML rule,
which is a second value→bytes conversion beside `Encrypted::value_to_bytes` —
the duplication this distribution names as its signature defect, and the one
ADR 0002 spent a release removing. It also leaves the **value** wrong: `decrypt`
would keep handing back the string `.inf` for a slot sops reads as a float. And
without the style oracle it breaks the quoted row, exactly like every other
text-keyed repair.

**Refuse the document with a message that names the path** — k105's option
(iii), and ADR 0024's shape. It needs the same oracle, the same walk and the same
ADR, and then declines to use the answer it just computed: with plain/quoted in
hand the leaf can simply be read correctly. Refusing would also be strictly worse
than the read this ships, and no better on the write side, which croaks either way.

**Accept the divergence and document it** — option (iv). It makes permanent the
statement that a document sops writes and sops verifies is unreadable here, for
a distribution whose whole claim is byte compatibility. It was defensible while
the repair looked like it required loosening a guard; it does not.

**Key the repair on the leaf's text alone, without the oracle.** Twenty lines,
no second parse, and it silently breaks `v_unencrypted: ".inf"` — a document
sops writes, `sops -d` reads and this module reads correctly today. The
three-element list above is the counter-example in one document.

**Loosen the non-finite guard so the write path works too.** It is the other
half of the round trip and it is a separate decision about a guard that is right
about every value it was written for. k105 says not to; k113 is where
it gets its own measurement.

**Put the rule in `detect_type`.** One rung, in the single source of truth for
the type — and it would have to read the leaf's text to find the rung, which is
ADR 0002's defect exactly, and it would answer the same for the quoted document.
The defect is a parse result, so the parse result is where it is repaired. Same
answer ADR 0023 gave for the same reason.

**Run the walk on plaintext documents too, for symmetry.** It changes which
error a caller gets from `encrypt_file` on a plaintext holding a bare `.inf`:
ADR 0013's, which names the key path and both resolvers, becomes the non-finite
guard's, which advises storing the value as a string — advice that leads
straight back to ADR 0013's refusal, because the string `.inf` is written bare
in YAML. A worse message for no gain, since neither path can write the document.

**Ask `YAML::PP` for the value rather than for the style.** Its Core schema
happens to agree with Go for these twelve tokens, and disagrees with Go for
`0755`, `010` and every literal ADR 0013 lists. Trusting it as a resolver would
be right here and wrong there; trusting it as a witness to what the document
says is right everywhere. The conjunction with `%GO_CONSTANT` is what keeps the
distinction real rather than stylistic.
