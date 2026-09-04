# ADR 0065 — Three RE2/Perl regex divergences that survived ADR 0048 are accepted as limits

- Status: accepted
- Date: 2026-08-23
- Resolves k165
- Depends on ADR 0048 (which closed 28 of the 29 measured (rule, key)
  disagreements and recorded these three as Limits there), ADR 0051 (which
  split the refusal between the read and write paths), ADR 0038 (the
  discriminator: *does sops read back what sops wrote?*)
- **Moves no bytes.** Nothing is parsed, emitted or digested differently.
  What changes is which limits are recorded in writing, and which tests
  pin them

## Context

ADR 0048 measured 29 (rule, key) disagreements between
`unencrypted_regex` / `encrypted_regex` as Perl matches them and as RE2
matches them, and closed 28 of them: 22 by switching the pattern
compile to `/a` (RE2's answer for `\w`, `\d`, `\s`, `\b` and the POSIX
classes), 6 by refusing patterns RE2 cannot compile. The Limits section
left three rows standing:

| shape | rule | key | Perl | RE2 | direction |
|---|---|---|---|---|---|
| full case folding | `(?i)^ss$` | `ß` (U+00DF) | matches (ß -> ss) | no match (simple folding) | secret-bare |
| `$` before trailing newline | `^foo$` | `"foo\n"` | matches (`$` is `(?=\n?\z)`) | no match (`$` is `\z`) | secret-bare |
| `\p{NAME}` Go does not have | `\p{Word}` | `"Word"` | matches | rule compile error, matches nothing | secret-bare |

k165 was opened to decide whether any of the three is reachable by
a fix proportionate to one rule nobody has been seen to write. The
measurement it took is the one this ADR records.

## The re-measurement

sops 3.13.3 at `/tmp/sops`, one age keypair generated for the run.
Every cell was re-measured on 2026-08-23 against the current tree (which
already carries `/a`, the construct scan and the read/write split).

### Shape 1 — full case folding

`(?i)^ss$` over `ß`:

| | answer |
|---|---|
| Perl `should_encrypt_path([ß])` (current tree) | **0 — BARE** (full case folding: ß -> ss) |
| `sops -e --unencrypted-regex '(?i)^ss$'` on the same input | ENC[`AES256_GCM`,...] (simple folding does not fold ß -> ss) |

The fix alternatives measured against Perl 5.40:

- `/a` (already in use): Perl still folds ß -> ss under `(?i)`.
- `/aa`: suppresses the ß fold AND the k/KELVIN and s/LONG-S folds that
  RE2 *does* perform, so `(?i)^k$` over U+212A KELVIN SIGN and
  `(?i)^s$` over U+017F LONG S go from "match" to "no match" -- the
  inverse direction. One for two, the wrong way around.

No other Perl flag reproduces RE2's simple folding.

### Shape 2 — `$` before a trailing newline

`^foo$` over `"foo\n"` (4 chars: `f`, `o`, `o`, `0x0A`; the JSON file
holds the escape, the in-memory key is a real newline):

| | answer |
|---|---|
| Perl `should_encrypt_path([foo\n])` (current tree) | **0 — BARE** (`$` is `(?=\n?\z)`) |
| `sops -e --unencrypted-regex '^foo$'` on the same JSON file | ENC[`AES256_GCM`,...] (`$` is `\z`) |
| `(?m)^foo$` over the same key on both sides | BARE on both (`(?m)` makes `$` a line boundary on both sides) |

The ticket's fix is a pattern-text rewrite: `$` -> `\z`, applied outside
a class, outside an escape, and not under `(?m)`. That is a
mini-parser on the rule text -- character-by-character, escape-aware,
class-aware, group-aware (`(?m)` scope).

### Shape 3 — `\p{NAME}` with a name Go does not have

`\p{Word}` over `"Word"` (measured, plus `\p{Alpha}`, `\p{IsAlpha}`,
`\p{XPosixAlpha}`; the names `\p{Greek}` and `\p{Lu}` are accepted by
both dialects):

| | answer |
|---|---|
| Perl `should_encrypt_path([Word])` (current tree) | **0 — BARE** (Perl has `\p{Word}`) |
| `sops -e --unencrypted-regex '\p{Word}'` on the same input | ENC[`AES256_GCM`,...] (RE2: `invalid character class range`; sops discards the compile error, rule matches nothing) |
| `_rule_qr` under `\p{Word}` | compiles, no refusal (the escape `\p` is on the accepted list in `_re2_divergent_construct`; the name is one Perl has) |

The exact fix needs Go's Unicode category and script table on this side,
so the scanner can label `\p{Word}` `unsupported` the way it labels
`(?=foo)` `unsupported`. Reproducing that table is out of proportion to
a rule nobody has been seen to write.

## Decision

**All three limits stand. No code change.**

### Shape 1 — accept the limit

`(?i)^ss$` over `ß` leaves the value bare here and encrypted at sops.
There is no Perl flag that reproduces RE2's simple folding without also
breaking the k/KELVIN and s/LONG-S folds. The (rule, key) pair is the
only row of the 43 measured after k161 still in the secret-bare
direction.

### Shape 2 — accept the limit

`^foo$` over `"foo\n"` leaves the value bare here and encrypted at sops.
The fix is a mini-parser on the rule text -- `$` -> `\z`, outside a
class, outside an escape, not under `(?m)`. The pattern `^foo$` is one
sops takes and reads back, so ADR 0038's discriminator forbids
refusing it: refusing a rule sops reads back is the wrong answer, and
the rewrite is the only way to make this side agree with sops without
refusing the rule.

The cost of the rewrite is its size: a mini-parser that does not
misclassify the rule sops *will* take. That is out of proportion to a
rule nobody has been seen to write.

### Shape 3 — accept the limit

`\p{Word}` over `"Word"` leaves the value bare here and encrypted at
sops. `\p` is on the accepted-escapes list in `_re2_divergent_construct`
(ADR 0048 / 0051), and the name is one Perl has. The exact fix needs
Go's Unicode category and script table on this side, so the scanner
can refuse `\p{Word}` the way it refuses `(?=foo)` -- without also
refusing `\p{Greek}`, which sops accepts.

The table is out of proportion to a rule nobody has been seen to write.

## Consequences

- **None of the three is reachable by an ASCII rule over ASCII keys.**
  The three rows are all Unicode (shape 1), an unusual key (shape 2:
  a key with an embedded newline), or a Go-mismatched property (shape
  3). The test suite's own rule decisions are unchanged (the
  measurement in ADR 0048 §"Consequences" already covered the ASCII
  case).
- **`should_encrypt_path` and `should_encrypt_key` answer what sops
  answers for 42 of the 43 measured rows** -- the same state ADR 0048
  recorded. The 43rd is now this distribution's documented limit
  rather than an unmeasured drift.
- **No MAC moves, no AAD moves, no encrypted wire bytes move.** The
  tree walk, the order-preserving reparse, and the value->bytes
  conversion are all unchanged.
- **Pinned by `t/77`** -- the (rule, key) pair for each shape, plus
  the ASCII control key under the same rule, plus the binary half
  (sops -e -i, run against `/tmp/sops`).

## Limits

**The three rows above are the limits.** They are the only measured
disagreements between this distribution and the Go reference
implementation on the regex rules. None is reachable by a fix
proportionate to the rule it would close.

## Rejected alternatives

**Add a "simple-fold-only" pre-pass on the rule (shape 1).** Translate
`(?i)` -> `(?i:...)` and strip the four characters that differ (U+00DF
ß, U+212A KELVIN SIGN, U+017F LONG S, and their upper-case variants)
from a "we won't fold these even under `(?i)`" comment that the engine
reads. Hard, and the ticket's measurement shows shape 1 hits no
production keys ("None of the three is reachable by an ASCII rule
over ASCII keys"). A pre-pass that breaks one row to close another is
not a fix.

**A pattern-text mini-parser rewriting `$` -> `\z` (shape 2).** The
only exact fix available. The ticket records it as "out of proportion
to a rule nobody has been seen to write", and ADR 0038 forbids
refusing `^foo$` -- so the rewrite is the only path to agreement
without refusing a rule sops reads back. Out of proportion.

**Reproduce Go's Unicode category and script table (shape 3).** The
only exact fix available. Out of proportion for the same reason.

**Refuse `\p{NAME}` longer than a general-category code.** Would
refuse `\p{Greek}`, which sops accepts.

**Refuse a key containing a newline while a `$`-anchored rule is set.**
ADR 0038's discriminator forbids it: sops writes and reads that
document at exit 0.

**Refuse `(?i)` and force callers to use a flag we provide.** `(?i)`
is one of RE2's accepted flags (measured); refusing it would refuse
every pattern sops accepts with it.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this
machine, on 2026-08-23: the three (rule, key) rows through
`sops -e -i` and `File::SOPS::Metadata->should_encrypt_path`, before
and after, with ASCII control keys under the same rules; one
end-to-end run of the three rows through `(?m)^foo$` to confirm the
`(?m)` boundary. All fixtures are invented values; the age keypair
was generated for the run.

`SOPS_BIN=/tmp/sops prove -lv t/77-three-re2perl-shapes-measured.t`
is green (11 subtests, all executed against the binary rather than
skipped); `SOPS_BIN=/tmp/sops prove -lr t/` is green over the whole
tree.
