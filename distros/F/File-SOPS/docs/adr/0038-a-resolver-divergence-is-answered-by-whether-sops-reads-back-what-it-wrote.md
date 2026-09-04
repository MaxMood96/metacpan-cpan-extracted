# ADR 0038 — A resolver divergence is answered by whether sops reads back what it wrote

- Status: accepted
- Date: 2026-08-21
- Tags: yaml, parser, emitter, types, interop, guards
- Resolves k131 and k128, narrows k127 to its measured half, and
  **hands k135 to the wire lane** rather than deciding it here
- Completes the three open bullets in ADR 0032's "Limits", which named `!!int
  0755`, `!!float 1` and the untagged timestamp and deferred all three
- Depends on ADR 0002 (the type comes from the scalar), ADR 0013 and ADR 0017
  (the foreign-resolution guard and the token it answers from), ADR 0026 and
  ADR 0034 (a plain scalar is resolved the same way on every parse — the
  machinery a k135 fix would have to reuse)
- Uses the discriminator ADR 0030 and ADR 0035 both turned on, stated below

## Context

Four tickets were opened out of the k118 and k123 measurements, all
four saying some version of "sops and this library resolve the same scalar
differently":

- **k127** — `0755` is 493 to sops and 755 here. Same `type:int` label,
  different number.
- **k128** — a timestamp is `type:time` at sops, with the spelling
  normalised to RFC3339, and `type:str` here with the source spelling kept.
- **k131** — `!!float 1` is `type:float` at sops and `type:int` here, with
  the same plaintext `1` on both sides.
- **k135** — a leaf that is a **string** on both sides is refused here
  where sops quotes it and reads it back.

Answered one at a time they would have produced contradicting answers, because
the four differ in **severity** and not in mechanism, and the severity is only
visible when the same scalar is measured in both slots at once. They were
therefore measured as one corpus.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient. **50 scalars × 3 documents each**
— the leaf in the encrypted slot alone (`v`), in the unencrypted slot alone
(`v_unencrypted`), and in both — encrypted once by `sops -e` and once by
`File::SOPS->encrypt_file`, then each resulting document handed back to
`sops -d`. The `sops_mac` of every document was decrypted through this
distribution's own modules (`Metadata->from_hash`, `Backend::Age->decrypt_data_key`,
`Encrypted->parse`/`decrypt_bytes` with `lastmodified` as AAD) and the digest
**solved** against candidate plaintexts rather than assumed — the same method
the k108, k116, k109 and k77 lanes used.

**All 150 documents sops wrote, sops read back at exit 0.** Not one exception,
in any slot, for any of the 50 spellings. That is the fact the whole decision
turns on.

### The encrypted slot — 50 scalars

49 written here (1 refused: `!!timestamp`, by ADR 0032's tag rule), and
**`sops -d` exit 0 on all 49**. Of those 49, 42 agree with sops exactly. The
other seven:

| plaintext leaf | sops label | sops plaintext | our label | our plaintext | both `sops -d` |
|---|---|---|---|---|---|
| `0755` | `int` | **`493`** | `int` | **`755`** | 0 |
| `!!int 0755` | `int` | **`493`** | `int` | **`755`** | 0 |
| `010` | `int` | **`8`** | `int` | **`10`** | 0 |
| `2026-08-21` | `time` | **`2026-08-21T00:00:00Z`** | `str` | **`2026-08-21`** | 0 |
| `2001-12-14t21:59:43.10-05:00` | `time` | **`2001-12-14T21:59:43.1-05:00`** | `str` | *(source spelling)* | 0 |
| `2026-08-21T04:35:49Z` | `time` | `2026-08-21T04:35:49Z` | `str` | `2026-08-21T04:35:49Z` | 0 |
| `!!float 1` | `float` | `1` | `int` | `1` | 0 |

**Five value divergences and two label divergences.** Nothing fails, in either
direction, for any of the seven.

### The unencrypted slot — the same 50 scalars

22 written here, **all 22 byte-identical to what sops wrote and all 22
`sops -d` exit 0**; 28 refused by the foreign-resolution guard. The 28 split
along the ticket boundary, and the split is the finding:

| refused | what sops writes from the same plaintext | is the refusal right? |
|---|---|---|
| `0755`, `!!int 0755`, `010` (k127) | `493`, `493`, `8` — resolved, spelling gone | **yes** — sops never writes the spelling we are refusing |
| `2026-08-21`, `2001-12-14t…`, `!!timestamp 2026-08-21` (k128) | `2026-08-21T00:00:00Z` etc. — normalised | **yes** — same reason |
| 22 **string** leaves (k135) | the same string, **double-quoted**, `sops -d` exit 0 | **no** — sops writes exactly those bytes |

The 22 are `".inf" ".Inf" ".INF" "+.inf" "-.inf" ".nan" ".NaN"`, `"1_000"
"0_7" "685_230.15"`, `"2015-01-01" "2015-1-2" "2015-01-01t12:00:00Z"
"2015-01-01 12:00:00"`, `"0o10" "0O10" "0x1f" "0b101"`, and `"Null" "NULL"
"TRUE" "FALSE"` — each quoted in the plaintext, so both implementations agree
it is a string, and each measured `sops -e` → `sops -d` exit 0 with the string
intact.

### Why one row of k135's five behaves differently

The ticket's fifth row, `"0755"`, is written here and not refused. Probed over
68 spellings: `$YAML::XS::QuoteNumericStrings` quotes a string that looks like a
**decimal** number (`'0755' '007' '08' '1e3' '-010'`), plus lower-case
`'true' 'false' 'null' '~'` and the empty string — and nothing else. It leaves
`.inf`, `.nan`, `Null`, `NULL`, `TRUE`, `FALSE`, `True`, `False`, `yes`, `on`,
`1:30`, `0x1f`, `1_000` and every date bare, even though libyaml's own
**resolver** reads several of them as YAML 1.1 types. So the guard's step 4
("is it written bare at all?") answers *quoted* for `"0755"` and returns before
any verdict, and *bare* for the other 22. There is no third rule: the whole
difference is the width of one emitter option.

### JSON is not in this at all

Ten of these spellings as JSON strings, in both slots at once — **10 of 10
agree on all four things at once**: the same `type:str` label, the same
encrypted plaintext, the same unencrypted-slot text, and `sops -d` exit 0 on
both documents. Nothing is refused here and nothing diverges. JSON has no
octal, no timestamps, no bare constants, and `Cpanel::JSON::XS` quotes every
string. Every row of this ADR is YAML-only.

## The discriminator

The same question ADR 0030 and ADR 0035 were both decided on:

> **Does sops read back what sops wrote?**

- **It does, and we refuse it** → we are wrong. (k102, k105, k116, k118 —
  and k135.)
- **It does not** → refusing is right. (k109 / ADR 0030.)
- **Both read their own documents and the labels or values differ** → a
  divergence, and possibly nothing to do. (k106, k77 / ADR 0035.)

Applied to the four, with the measurement as the evidence:

| ticket | slot | class | evidence |
|---|---|---|---|
| **k131** | both | **divergence** | `type:float` vs `type:int`, plaintext `1` on both sides, `sops -d` exit 0 both ways, MAC covers `1` in both documents |
| **k128** RFC3339-exact | both | **divergence** | `type:time` vs `type:str`, plaintext identical, exit 0 both ways |
| **k128** other spellings | encrypted | **divergence** | value differs, exit 0 both ways |
| **k128** other spellings | unencrypted | **refusal is right** | sops writes the normalised form, never the source spelling |
| **k127** | encrypted | **divergence** | 493 vs 755, exit 0 both ways |
| **k127** | unencrypted | **refusal is right** | sops writes `493`, never `0755` |
| **k135** | unencrypted | **we are wrong** | sops writes the quoted string and reads it back at exit 0; we refuse to produce it |

## Decision

**Four questions, three different answers, and the severity decides which.**

### 1. k131 — closed, recorded, not fixed

`!!float 1` stays `type:int` here. The plaintext is `1` on both sides, Go
re-derives the digest input from the declared type (`ToBytes(int 1) ==
ToBytes(float 1) == "1"`), and both documents verify in both directions. There
is no wire consequence to fix.

The only available fix is to take the type from the **tag** instead of from the
scalar, which inverts ADR 0002 — the rule that removed `looks_like_number` and
`/^\d+$/` from this distribution. Paying that for a label nothing reads
differently is the wrong trade. Same answer, same reasoning, as k106 and
k77.

### 2. k128 — closed, and split between the other two

The untagged timestamp is **not one question**:

- Where the source spelling is already **exactly RFC3339**, the plaintext is
  byte-identical on both sides and only the label differs. That is k131's
  class and gets k131's answer: recorded, not fixed. Reproducing
  `type:time` would mean implementing Go's time parsing *and* its RFC3339-Nano
  rendering to hit the same digest bytes — a new value transformation, on the
  wire path, for a type Perl does not have.
- Where the spelling is anything else, the **value** differs, and that is
  k127's class exactly. It is folded into k127 rather than tracked
  twice: the mechanism, the slot behaviour and the fix are the same.

### 3. k127 — the ticket's claim is verified; it stays open on its
### encrypted half, at its current priority

Both halves were checked, because the priority hangs on them.

- **The unencrypted half is closed, and the message is right.** Measured: a
  plaintext `v_unencrypted: 0755` croaks with `its spelling is a leading-zero
  integer, which libyaml reads as decimal and Go as octal`, and the message
  names `493` as what to pass instead — which is, measured, exactly what
  `sops -e` writes from the same plaintext. Nothing in the message is wrong for
  an `int` leaf.
- **The encrypted half is open and silent.** `v: 0755` is written here with
  plaintext `755` and at sops with plaintext `493`, both `type:int`, both
  `sops -d` exit 0, both self-consistent. No guard sees it: `_encrypt_tree`
  replaces the leaf with an `ENC[…]` string long before the emitter runs, and
  an `ENC[…]` string is a string to every resolver.

**It is not raised to high.** Nothing fails, no document is corrupt, and it is
k29's class — a fidelity gap between two parsers. What is worth recording,
because it is *worse* than k29 and the ticket is right about that: there
the type label differed and something was visible; here both sides say
`type:int` and only the number differs, so nothing anywhere signals it.

Closing it means resolving a plain scalar the way Go resolves it instead of the
way libyaml does — on the **parse** side, for every document, changing the value,
the ciphertext and the digest. That is ADR 0002's territory and the wire lane's,
not a formatting change.

### 4. k135 — a real defect, and it is handed over, not fixed here

Of the four this is the only one where **sops writes a document, reads it back
at exit 0, and this library refuses to produce it** — 22 measured spellings.
The refusal is wrong and the message is wrong with it: for a string leaf it
says "sops itself resolves such a spelling when it writes: a plaintext
`mode: 0755` becomes the integer 493", which is true for an `int` leaf and
false for these — sops resolves nothing, it quotes the string and keeps it.

It is **not** the alternative ADR 0013 rejected. There the objection was that
quoting **changes the type**: `mode: 0755` would become a string where the
caller's parser said integer. Here `detect_type` says `str` on this side and
go-yaml reads a string out of sops's own quoted output on the other, so quoting
states the type the document has rather than inventing one.

**It is handed to `file-sops-wire` and not implemented here, for three reasons
that were established by measuring, not by reading the lane boundary:**

- **It moves bytes on the wire.** 22 leaves that produce no document today would
  produce one. That is the handover condition k135 itself names.
- **YAML::XS has no per-scalar style control** — no tag, no forced-quote hook,
  as `_quote_sops_timestamp` has recorded since 0.003. The only way to get a
  quoted scalar out of this emitter is to rewrite the text after `Dump`, and
  doing that for arbitrary **data** leaves (rather than for one metadata key in
  one block) is a new mechanism on the wire path.
- **The obvious fix is wrong, and the measurement is what shows it.** "Quote
  every `str` leaf the guard would refuse" also silently changes k128's
  unencrypted half: `v_unencrypted: 2015-01-01` **bare** and
  `v_unencrypted: "2015-01-01"` **quoted** arrive as the *same Perl string* —
  verified, both `[2015-01-01]`, length 10 — so the emitter cannot tell them
  apart. The bare one is a `time` to sops, normalised to
  `2015-01-01T00:00:00Z`; quoting it would turn today's loud refusal into a
  silent divergence, which is the direction ADR 0032 refused for `!!bool True`.

  The distinction lives in the **source text**, and this module already makes it
  for one token family: `_restore_plain_infinities` re-parses the document with
  a plain-style loader so that a bare `.inf` becomes a float (ADR 0026) while a
  quoted `".inf"` stays a string (ADR 0034). Measured today, that asymmetry is
  visible from outside — **bare `.inf` is written, quoted `".inf"` croaks** —
  which is both the proof that a correct fix is reachable with machinery this
  module has, and the proof that it needs plain/quoted state carried from parse
  into emit. New cross-phase state on the wire path is not this lane's to add.

## Consequences

- **No code changes.** No document moves, no digest byte moves, no message
  changes, no test changes — this ADR adds one file under `docs/`. `prove -lr t/`
  is 53 files, **1172/1172**, and `SOPS_BIN=/tmp/sops prove -lv t/04-interop.t`
  is **32/32, executed** against sops 3.13.3 — the same before and after,
  because nothing under `lib/` was touched.
- ADR 0032's three deferred "Limits" bullets are now decided rather than open:
  `!!float 1` and the RFC3339-exact timestamp are accepted divergences,
  `!!int 0755` is k127's encrypted half.
- **k131 and k128 are closed.** k127 stays open, narrowed to the
  encrypted slot and carrying k128's value half. k135 stays open and
  is reassigned to the wire lane with the mechanism above.
- A caller who needs any of these spellings preserved exactly has two answers
  the guard's message already gives, and both are measured: encrypt the leaf —
  an `ENC[…]` string carries any text verbatim and every one of the 50 scalars
  round-trips through it at exit 0 — or write the document as JSON, where all
  10 probed spellings agree in both slots.

## Alternatives rejected

**Answer the four separately.** They would have contradicted each other. Read
alone, k135 argues for quoting a `str` leaf the guard refuses, and
k128's unencrypted half is a `str` leaf the guard refuses — so k135's fix,
scoped by k135's ticket, would have silently retyped k128's case while k128 was
being closed as "recorded, not fixed" on the strength of it failing loudly.

**Raise k127 to high because the encrypted slot is silent.** The silence is
real and is recorded above. But nothing fails, no document is corrupt, and the
same caller reading the same file with plain `YAML::XS` gets 755 as well —
priority `high` is for something that breaks, and this changes a number that
libyaml itself chose.

**Fix k131 by typing from the tag.** Two lines in the parser, and it
inverts the rule (ADR 0002) that this distribution spent k15 establishing,
for a label whose digest bytes are identical.

**Close k135 as "documented, not fixed" like the other three.** The
discriminator forbids it. The other three are documents both implementations
write and read; k135 is a document *sops* writes and reads and we refuse. That
is the class this session has fixed four times (k102, k105, k116, k118),
not the class it has recorded.
