# ADR 0019 — A string Go resolves as a boolean is warned about, in both modes

- Status: accepted
- Date: 2026-08-20
- Tags: yaml, wire-format, guards, interop, diagnostics
- Resolves k92
- Amends ADR 0013 (its "rows that agree" table lists `True` / `False` as agreeing,
  and by the measure that guard uses they do — the digest bytes are the same. The
  refusal rule is unchanged and no document moves)
- Depends on ADR 0017 (one check, taken from the emitted token) and ADR 0018
  (the second verdict — `carp` where nothing fails and the two implementations
  still read different things)

## Context

`File::SOPS::Format::YAML::_foreign_resolution_token` asks whether Go's resolver
derives **the bytes the MAC digest covers** from the token this emitter writes.
That question has one axis, and a leaf can disagree on a second one.

A Perl string `True` is a `str` to `detect_type`, `value_to_bytes` derives the
bytes `True` from it, and `YAML::XS` writes it as a bare `True` — libyaml's
resolver knows `true` and `false` and not their titlecase spellings, so it does
not quote them. `gopkg.in/yaml.v3` resolves that same token to a **boolean**,
and sops's `ToBytes` renders a boolean Go-style titlecase, which is the byte
string `True` again. The digests match, the MAC holds, `sops -d` exits 0, and
the two implementations are holding different things.

Measured, sops 3.13.3, YAML, leaf in an unencrypted slot:

| document | this module reads | sops reads | `sops -d` |
|---|---|---|---|
| `x_unencrypted: True` | `str "True"` | `bool true` | exit 0 |
| `x_unencrypted: False` | `str "False"` | `bool false` | exit 0 |

### The question k92 asks: does the value survive a sops write-back

It does not. Measured, one document per row, the same document handed to three
sops subcommands that rewrite it:

| write-back | exit | the leaf afterwards | what this module then reads |
|---|---|---|---|
| `sops rotate -i` | 0 | `x_unencrypted: true` | `JSON::PP::Boolean` true |
| `sops set … '["keep"]' '"w"'` | 0 | `x_unencrypted: true` | `JSON::PP::Boolean` true |
| `sops edit` (editor rewrote the same `True` text) | 0 | `x_unencrypted: true` | `JSON::PP::Boolean` true |

sops resolves the spelling on read and emits its own canonical `true` on write,
exactly as it resolves `mode: 0755` to `493` (ADR 0013). Nothing fails anywhere
along that path: the rewritten document verifies its MAC here, `decrypt` returns
it, and the caller's string has become a boolean — printing as `1` where it used
to print as `True`.

### What was measured

A 364-row corpus: 91 leaves × 2 slots (`x_unencrypted`, `x`) × both handlers.
The leaves are ADR 0013's spellings as caller-supplied Perl strings, the same
spellings taken through a real `YAML::XS` parse, the whole YAML 1.1 boolean
family (`Yes` `No` `YES` `NO` `yes` `no` `y` `n` `Y` `N` `On` `Off` `ON` `OFF`
`on` `off`), the nulls (`~` `null` `Null` `NULL`), the timestamps, plain ints and
floats, boolean sentinels, `undef` and a non-ASCII string. Each row was
encrypted, read by `sops -d --output-type json`, rewritten with `sops rotate -i`
and read back here. Two runs produce byte-identical results once key material,
`lastmodified` and the MAC are normalised.

- **14 of 364 rows come back from a sops write-back differently than they went
  in, and 4 of them change TYPE.** All four are a `True` or `False` **string** in
  an unencrypted YAML slot. The other 10 are the same value in a different SV
  shape: an int leaf that carried its source spelling as a PV (`007`, `08`,
  `1e3`) comes back as a bare `int 7` / `8` / `1000`, and a computed float comes
  back carrying the canonical decimal as its PV. Same number, same type, in both
  slots and both handlers — that is the source spelling not surviving a round
  trip through anything, not a divergence.
- **The neighbours do not diverge.** `Yes` `No` `YES` `NO` `yes` `no` `y` `n` `Y`
  `N` `On` `Off` `ON` `OFF` `on` `off` are all `"Yes"`, `"y"`, `"off"` … to
  `sops -d --output-type json` — a string — and survive `sops rotate` byte for
  byte. yaml.v3 dropped YAML 1.1's boolean spellings; libyaml, measured here,
  never resolved them either (`YAML::XS::Load("x: yes")` is the string `yes`).
  ADR 0013 lists them as agreeing rows and they agree on both axes.
- **`~` and `null` are quoted by libyaml** and so are strings to every reader;
  `Null` and `NULL` disagree on bytes and are already refused; a real `undef`
  leaf is written `~`, read as null by sops, written back as `null` and read
  here as `undef` again — no divergence.
- **An RFC3339 string is the one other same-bytes-different-type row, and it
  round-trips unharmed.** `2015-01-01T12:00:00Z` is a `str` here and a
  `time.Time` to Go, both digest the same bytes, `sops -d --output-type json`
  prints it as a **string**, and `sops rotate` writes the identical token back.
  Measured for the fractional form too. Nothing observable diverges and there is
  no other spelling of that value, so it is not warned about.
- **`08` and `1e3` are the same shape one type down** — `int` here, `float 8` /
  `float 1000` to Go — and the value is the same number, `sops rotate` writes
  `8` / `1000`, and this module reads an int again. Not warned about.
- **JSON is unaffected, in both slots: 0 of 182 rows.** `Cpanel::JSON::XS` quotes
  every string, so the document says `"True"` and Go reads a string.
- **Encrypted YAML slots are unaffected: 0 of 91 rows.** The leaf is an `ENC[…]`
  string by the time the emitter sees it, and `sops -d` gives `"True"` back as a
  string in every one of them.
- **The read path is unaffected, because sops cannot write such a document.**
  Measured in the other direction: a plaintext `x_unencrypted: True` becomes
  `x_unencrypted: true` under `sops -e` (and `type:bool` in an encrypted slot),
  while a plaintext `x_unencrypted: "True"` stays `"True"` (and `type:str`). A
  bare titlecase boolean never survives a `sops -e`, so it can only enter a
  document by being written here.

## Decision

**The guard gains a second class, on the axis the digest cannot see: a token Go
resolves to a boolean where this module's leaf is not one. It is `carp`ed about,
in both modes, and no document changes.**

`_foreign_resolution_token` returns the token *and which kind of disagreement it
is*:

- `mac` — Go derives different bytes from the token. Unchanged: `croak` where the
  MAC covers the leaf, `carp` under `mac_only_encrypted`.
- `type` — Go derives the same bytes and a different **type**. `carp` in both
  modes, from the same sub, because the divergence and its consequence are
  identical in both: the MAC holds either way.

The two verdicts now mean something a caller can hold on to:

> **croak: the document would disagree with its own MAC.
> carp: `sops -d` succeeds and reads something other than what this module reads.**

The check itself is still one sub and one model of Go. The new clause is one
predicate, `_go_retypes`, which fires only after the bytes have already agreed,
and asks the two authorities this distribution already has: `%GO_CONSTANT` for
what Go resolves the token to, and `detect_type` for what the leaf is. No second
ladder and no second model.

The message names the leaf's key path, says that sops reads a boolean and that a
sops write-back rewrites the spelling, and names the two remedies that are
measured to work: encrypt the leaf, or write the document as JSON. It never
names the value.

## Consequences

- **No document moves.** 364 corpus rows before and after: identical
  normalised documents, identical `sops -d` exit codes, identical values read
  back. **0 of 364 cases that work today stop working**, and nothing is refused
  that was not refused before.
- **4 of 364 rows newly warn**, and all four really do diverge — measured above,
  by three different sops write-backs. **0 false warnings**: no row warns about a
  leaf the two implementations agree on, including every neighbour that looks
  like this one (`Yes`, `on`, `y`, `~`, an RFC3339 timestamp, `08`).
- **A warning now reaches the default mode**, where this guard has only ever
  croaked or been silent. That is deliberate: the divergence does not depend on
  `mac_only_encrypted`, because the MAC holds in both modes, so reporting it only
  under the flag would hide it from every caller who does not set it.
- **Cost: one hash lookup and one `detect_type`, on the leaves that reach the
  verdict at all.** A leaf whose bytes disagree croaks before it; a leaf Go's
  resolver ignores never gets past ADR 0017's gate. Measured per 1000 leaves
  through `emit`, best of five, perl 5.40.1: a string Go's resolver ignores is
  6.8ms → 6.8ms, i.e. unchanged, and a `True` string is 23.7ms → 27.3ms for the
  predicate. Raising the warning is what actually costs — 96.2ms per 1000 `True`
  leaves, Carp's caller walk — and only a document that has such leaves pays it,
  once per leaf per write.
- **The caller's remedies are narrower than ADR 0013's**, and the message says so
  rather than pretending otherwise. For `mode: 0755` there is a decimal to pass
  instead; for a `True` string there is no spelling of a Perl string that this
  emitter writes quoted. Encrypting the leaf works (measured, every encrypted-slot
  row agrees on both axes) and so does the JSON handler (measured, `"True"`).

### What changes for existing callers

Nothing is refused, no bytes move, and no return value changes. A caller who
encrypts a YAML document with a `True` or `False` **string** in an unencrypted
slot now gets one `carp` per such leaf, naming the key path. Silence it with a
local `$SIG{__WARN__}` if the divergence is known and accepted, as for the
warnings ADR 0018 introduced.

## Rejected alternatives

**Refuse it, as ADR 0013 refuses the bytes class.** The literal reading of
k92 ("the same class as k86, so it belongs in the same guard"), and the
measurement is what argues against it: those documents work today — `sops -d`
exit 0, MAC valid, 4 of 364 corpus rows — and refusing them would be the first
refusal in this guard that breaks something that works. ADR 0018 drew that line
already, for the same reason and with the same kind of number (66 of 217), and
this ADR keeps it where it is. It also matters that the refusal could not tell
the caller what to pass instead: for `0755` the answer is `493`, the same value
sops itself writes, while a caller holding the string `True` has no spelling of
it this emitter writes quoted. "Encrypt it or use JSON" is advice, not a
correction, and advice belongs in a warning.

**Document it and warn about nothing.** The ticket's third option. ADR 0018
rejected it in the same words and they still apply: a `flag_unencrypted: "True"`
looks like an ordinary string, is one, and is a boolean to the other
implementation — a caller cannot see that the paragraph applies to their
document. The measurement says the warning costs no working document, so
documentation alone would leave the better answer unused. It is done as well:
the rule is in `File::SOPS::Format::YAML/serialize` and in `File::SOPS/encrypt`,
not only here.

**Compare the resolved TYPE for every leaf, not just the boolean one.** The
general form of the same idea, and it is too coarse to be useful: measured, it
would warn about `08` and `1e3` (int here, float to Go) and about every RFC3339
timestamp (str here, time to Go), all of which round-trip through a sops
write-back with the same value, the same type on this side and, for the
timestamp, the identical token. Those are 3 false warnings for every real one in
the corpus. What separates the boolean is not that the types differ but that
**Go's emitter writes the resolved value back as a different token**, and
modelling Go's emitter is a second model of Go this layer does not need: the
resolutions that behave this way are `True` and `False` and nothing else, which
is what `%GO_CONSTANT` already knows.

**Quote the leaf on the way out.** The tempting one, because it removes the
divergence instead of reporting it, and because ADR 0013's reason for rejecting
it does not apply here: quoting `mode: 0755` retypes an integer into a string,
where quoting a `True` **string** keeps it the string it already is — and it is
measured to be exactly what sops does with the same value (`sops -e` on a
plaintext `x_unencrypted: "True"` writes `x_unencrypted: "True"`). Two things
stop it from being this ADR's decision. It moves wire bytes for a class of
documents that are accepted today, which is a change to what this distribution
writes rather than a diagnostic. And `YAML::XS` has no per-scalar style control —
no tag, no forced-quote hook, and the dualvar carrier ADR 0011 uses writes its PV
as a *plain* scalar — so the only way to get a quoted scalar out of this emitter
is text surgery on the finished document, which `_quote_sops_timestamp` can do
safely only because it targets one known key in one known block. Doing it for an
arbitrary key path at arbitrary nesting is a new mechanism with a corruption
failure mode worse than the divergence it fixes. Recorded as k99 with this
measurement, for the maintainer to decide against a real emitter rather than in
passing.

**Warn on the read path too.** A document sops wrote never carries a bare
titlecase boolean — measured above, `sops -e` resolves it to `true` — so the
divergence can only be introduced where it is now reported.
