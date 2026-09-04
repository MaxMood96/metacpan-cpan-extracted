# ADR 0018 — A `mac_only_encrypted` document warns where it cannot refuse

- Status: accepted
- Date: 2026-08-20
- Tags: yaml, mac, wire-format, guards, interop, diagnostics
- Resolves k87
- Revises ADR 0013's "`mac_only_encrypted` documents are not affected, and are
  deliberately left out" — the same rule, the same model of Go, and now a
  warning where the MAC has nothing to say
- Depends on ADR 0017 (the guard answers from the emitted token; both modes go
  through that one check)

## Context

ADR 0013 refuses a YAML leaf whose spelling `gopkg.in/yaml.v3` resolves to
something other than what the MAC digest covers, because the document then fails
its own MAC. With `mac_only_encrypted` set the digest covers encrypted values
only, so an **unencrypted** leaf cannot make such a document disagree with
itself — and the guard is therefore not installed at all (`serialize` passes
`mac_covered => 0`).

That was right about the MAC and it left the value behind. Measured, sops 3.13.3,
leaf `mode_unencrypted: 0755`:

| | `sops -d` | what it reads |
|---|---|---|
| `mac_only_encrypted = 0` | exit 51, MAC mismatch | — (refused here since ADR 0013) |
| `mac_only_encrypted = 1` | **exit 0** | **493**, where this library reads 755 |

Nothing fails. The file says `0755`, sops reads the integer 493, File::SOPS
reads 755, and no reader of either complains. The question k87 asks is not
whether the MAC holds — it does — but whether a caller who turns
`mac_only_encrypted` on can find out that a `mode: 0755` in their document is a
different number for the two implementations.

### What was measured

217 `mac_only_encrypted` YAML documents, one per corpus leaf, each with the leaf
in an unencrypted slot and an encrypted string beside it, written by this
library and read back both by `sops -d` and by `decrypt`. The guard was forced
on and its refusal captured rather than raised, so each row records what a
warning **would** have said:

- **66 rows would warn, and all 66 really do diverge.** 60 show it directly in a
  round trip (`0o10` → `int 8` there, `str "0o10"` here; `2015-01-01` →
  `2015-01-01T00:00:00Z`; `1_000` → `1000`; `Null` → `null`). The other 6 are
  the `.inf` / `-.inf` / `.nan` family, where sops writes the same spelling back
  out so a YAML round trip cannot see the difference — `sops -d --output-type
  json` proves it does: exit 4, `Error marshaling to json: json: unsupported
  value: +Inf`. Go is holding a float where this library holds a string.
- **0 false warnings.** No row warns about a leaf the two implementations agree
  on.
- **4 divergences stay silent**, and they are outside this rule: a `True` or
  `False` **string** leaf is a `str` here and a `bool` in Go, while both digest
  the bytes `True`/`False` — so the guard, which compares digest bytes, is
  correct to accept it. ADR 0013 lists it as an agreeing row for the same
  reason. Filed as k92.
- **2 documents sops refuses outright** (`0xffffffffffffffff`, exit 25,
  `Cannot walk value, unknown type: uint64`) — unchanged, and they warn.
- **0 documents stop being written.** All 217 are written before and after, and
  `sops -d` reads the same 215 of them.

The false-positive profile is ADR 0013's, because it is ADR 0013's check: over
that ADR's second corpus of 105 values a real configuration file holds, 4 hint
enough to be examined and refused, and all four are spellings `sops -d` rejects.
A warning inherits exactly that rate.

## Decision

**Where the MAC cannot catch a foreign resolution, the caller is told about it
instead. `serialize` installs the same check in a warning mode for a
`mac_only_encrypted` document; the document is written either way.**

- `emit` gains `warn_foreign_resolution => 1` beside `mac_covered => 1`. The two
  install the same walk hook and differ only in the verdict: `croak` versus
  `carp`. Neither is set by the plaintext emitters, which stay silent for the
  reason ADR 0013 gave.
- The check itself is one sub. `_reject_foreign_resolution` and
  `_warn_foreign_resolution` both ask `_foreign_resolution_token`, which is
  ADR 0017's body: the gate, the emitter, the model, the comparison. **A second
  copy of that check is exactly the defect class this layer keeps producing**,
  so there is one, and the two modes are two messages.
- The warning names the leaf's key path, says what the two resolvers do with the
  spelling, and says that the MAC will not catch it. It never names the value —
  a warning goes to logs.
- `carp`, not `warn`: the house rule that a diagnostic reports the caller's line
  applies to both, and `@CARP_NOT` in this module already makes it walk out of
  the emitter and the walk (k71). A caller who wants it quiet localises
  `$SIG{__WARN__}`, which the POD says.

## Consequences

- **A `mac_only_encrypted` document that was written silently now prints one
  line per divergent leaf, and is still written.** Nothing is refused: 0 of 217
  corpus documents stop being produced, and `sops -d` reads the same ones as
  before.
- The cost is ADR 0017's, paid only by a `mac_only_encrypted` document: +2.4ms
  on a 400-leaf document, nothing for a leaf Go's resolver ignores. Such a
  document paid zero before, since the hook was not installed.
- **A caller who has been living with the divergence gets a warning where they
  had silence.** That is the point, and it is the only thing this ADR changes
  for them. `mac_only_encrypted` is opt-in and the audience is exactly the
  caller who chose it.
- Warnings from a re-write, not only from a first encrypt: `rotate` and
  `encrypt_in_place` serialize too, so a document that already carries such a
  leaf warns each time it is written. That is correct — each of those writes is
  the write the warning is about.
- The rule is now documented where `mac_only_encrypted` is described
  (`File::SOPS::Metadata`, `File::SOPS/encrypt`), not only in an ADR. A caller
  reading about the option sees what it costs.

### What changes for existing callers

Nothing for a caller who does not set `mac_only_encrypted`, and no document
changes for one who does. A caller who sets it **and** has a leading-zero
integer, a `0o`/`0x`/`0b` number, `_` digit separators, `.inf` / `.nan` /
`Null` / `TRUE`, or a date that is not exactly RFC3339 in an unencrypted YAML
slot now sees a warning naming the key path. The value they get back from
`decrypt` is unchanged, and so is the one sops gets.

## Rejected alternatives

**Refuse it, as ADR 0013 does without the flag.** It is the same disagreement
and the same badness, and consistency argues for it. It would break documents
that work today — measured, 66 of 217 corpus documents, all currently `sops -d`
exit 0 — for a divergence that no reader reports. ADR 0013 stopped where the MAC
stops for exactly this reason, and this ADR does not move that line; it fills it
in.

**Document it and warn about nothing.** The ticket's fallback, and it is half of
what is done here. On its own it puts the burden on a caller to know that this
paragraph applies to their document, about a leaf they cannot see is special —
`mode: 0755` looks like a number and is one, in both languages, just not the
same one. The measurement says a warning is available at no cost to any working
document, so documentation alone would be leaving the better answer unused.

**Warn on the read path too.** A document written by sops never carries such a
spelling: sops resolves it when it writes (`mode: 0755` becomes 493 in its
output — measured, ADR 0013). The divergence can only be introduced by writing,
so that is where it is reported.

**A `warnings::register` category, so a caller can `no warnings 'File::SOPS'`.**
Lexical warning categories are checked against the *caller's* bitmask at the
point the warning is raised, and this one is raised deep inside the emitter's
own walk, where the caller's lexical scope is not in view. It would need
`warnings::enabled_at_level` gymnastics keyed to a recursion depth that changes
with the leaf — the same reason `$Carp::CarpLevel` was rejected in k71.
`$SIG{__WARN__}` is one line and works.

**A return value or a callback instead of a warning.** `serialize` returns a
document, and `encrypt` returns a document; giving either a second return value
would change the signature of the public API for a diagnostic. If a structured
report is ever wanted, it belongs on the public API as an option, not smuggled
through the emitter.
