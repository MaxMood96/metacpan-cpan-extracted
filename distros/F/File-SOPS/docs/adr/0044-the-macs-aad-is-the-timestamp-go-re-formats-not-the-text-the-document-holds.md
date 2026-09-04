# ADR 0044 — The MAC's AAD is the timestamp Go re-formats, not the text the document holds

- Status: accepted
- Date: 2026-08-21
- Tags: mac, aad, metadata, interop, wire
- Resolves k144, the AAD half of the sweep that produced ADR 0042
- Corrects one row of ADR 0042's field table: `lastmodified` is a Go **string**
  where `mapstructure` decodes it and a Go **`time.Time`** everywhere after
  that, and the AAD is taken from the second one
- Depends on ADR 0002 (the type comes from the scalar — `_is_text` is reused
  rather than asked again) and ADR 0043 (a reference in a string field is
  already refused before this decode runs)
- Leaves k144's second direction — an **unquoted** timestamp — undecided
  here and hands it to the format lane, for the reason ADR 0038 recorded about
  bare and quoted scalars being the same Perl string

## Context

`lastmodified` is the AAD the metadata MAC is authenticated with. Both sides of
that — `_compute_mac` and `_verify_mac` in `File::SOPS.pm` — read it as
`$metadata->lastmodified // ''`, which is the document's **text**.

sops does not use the text. It decodes the `sops` section's `lastmodified`
string into a Go `time.Time` and everything downstream uses
`LastModified.Format(time.RFC3339)` — the AAD included. Where a document spells
an instant in any RFC3339 form that is not Go's own rendering of it, the two
disagree: sops reads the file, this library refuses it with
`Cannot decrypt MAC - refusing to return unverified data`.

k144 recorded six measured rows and said outright that it needed the full
spelling set measured before anything was written. This is that measurement.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient generated for the run, on a
document sops itself wrote — only the `lastmodified` line edited, and, where
the experiment needs it, the `mac` value re-encrypted under a chosen AAD
through this distribution's own `File::SOPS::Encrypted->encrypt_value`. The
MAC plaintext was first recovered by decrypting the stored `mac` with the
document's own timestamp as AAD, the same method the k108, k116, k109 and
k138 lanes used.

### The AAD is the re-formatted timestamp — measured directly, not inferred

The decisive experiment is three rows wide. Each builds a document whose
`lastmodified` **text** is one thing and whose `mac` was encrypted under a
**chosen** AAD, and then asks `sops -d` which of the two it agreed with.

| `lastmodified` text in the document | AAD the `mac` was built under | `sops -d` |
|---|---|---|
| `"2026-08-21T09:05:08Z"` | `2026-08-21T09:05:08Z` | **0** |
| `"2026-08-21T09:05:08+00:00"` | `2026-08-21T09:05:08Z` | **0** |
| `"2026-08-21T09:05:08+00:00"` | `2026-08-21T09:05:08+00:00` — *the literal text* | **51** |
| `"2026-08-21T09:05:08.123Z"` | `2026-08-21T09:05:08Z` | **0** |
| `"2026-08-21T09:05:08.123Z"` | `2026-08-21T09:05:08.123Z` — *the literal text* | **51** |
| `"2026-08-21T11:05:08+02:00"` | `2026-08-21T09:05:08Z` — *the same instant in UTC* | **51** |
| `"2026-08-21T11:05:08+02:00"` | `2026-08-21T11:05:08+02:00` | **0** |

Exit 51 is `Cannot decrypt MAC: Could not decrypt with AES_GCM: cipher: message
authentication failed` in every case — GCM refusing the AAD, not a MAC
mismatch over the values.

Three facts, none of them guessed:

1. **The literal text is not the AAD.** Two rows fail with the document's own
   bytes as AAD and succeed with something else.
2. **A zero offset becomes `Z`, and the fraction is dropped.** That is
   `time.Parse(time.RFC3339, s).Format(time.RFC3339)`: the layout
   `2006-01-02T15:04:05Z07:00` carries no fractional field, and Go writes `Z`
   whenever the zone offset is zero.
3. **A non-zero offset is kept, not shifted to UTC.** `+02:00` stays `+02:00`.
   The wall-clock fields are the parsed ones; only the spelling is re-derived.

### The full spelling set

45 spellings, one document each, every one built so that the `mac` sits under
the AAD the row's rule predicts, so that `sops -d` exit 0 *is* the confirmation
of the AAD. `F::S` is `File::SOPS->decrypt` on the same document **before** this
change.

| spelling in the document | AAD sops derives | `sops -d` | `F::S` |
|---|---|---|---|
| `"2026-08-21T09:05:08Z"` | `2026-08-21T09:05:08Z` | 0 | ok |
| `"2026-08-21T09:05:08+00:00"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08-00:00"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T11:05:08+02:00"` | `2026-08-21T11:05:08+02:00` | 0 | ok |
| `"2026-08-21T04:05:08-05:00"` | `2026-08-21T04:05:08-05:00` | 0 | ok |
| `"2026-08-21T14:35:08+05:30"` | `2026-08-21T14:35:08+05:30` | 0 | ok |
| `"2026-08-21T00:20:08-08:45"` | `2026-08-21T00:20:08-08:45` | 0 | ok |
| `"2026-08-21T09:06:08+00:01"` | `2026-08-21T09:06:08+00:01` | 0 | ok |
| `"2026-08-21T09:04:08-00:01"` | `2026-08-21T09:04:08-00:01` | 0 | ok |
| `"2026-08-22T09:04:08+23:59"` | `2026-08-22T09:04:08+23:59` | 0 | ok |
| `"2026-08-22T09:05:08+24:00"` | `2026-08-22T09:05:08+24:00` | 0 | ok |
| `"2026-08-21T09:05:08+00:60"` | `2026-08-21T09:05:08+01:00` | 0 | **die** |
| `"2026-08-21T09:05:08-00:60"` | `2026-08-21T09:05:08-01:00` | 0 | **die** |
| `"2026-08-21T09:05:08+24:60"` | `2026-08-21T09:05:08+25:00` | 0 | **die** |
| `"2026-08-21T09:05:08.0Z"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08.1Z"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08.123Z"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08.123456Z"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08.123456789Z"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08.123456789012Z"` (12 digits) | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T09:05:08,123Z"` (comma) | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T11:05:08.5+02:00"` | `2026-08-21T11:05:08+02:00` | 0 | **die** |
| `"2026-08-21T09:05:08.75+00:00"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T9:05:08Z"` (1-digit hour) | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"2026-08-21T1:05:08+02:00"` | `2026-08-21T01:05:08+02:00` | 0 | **die** |
| `"2026-08-21T9:05:08.25Z"` | `2026-08-21T09:05:08Z` | 0 | **die** |
| `"0000-01-01T00:00:00Z"` | `0000-01-01T00:00:00Z` | 0 | ok |
| `"0001-01-01T00:00:00Z"` (Go's zero time) | `0001-01-01T00:00:00Z` | 0 | ok |
| `'2026-08-21T09:05:08Z'` (single-quoted) | `2026-08-21T09:05:08Z` | 0 | ok |
| `!!str "2026-08-21T09:05:08Z"` | `2026-08-21T09:05:08Z` | 0 | ok |

And the spellings sops **refuses outright**, exit 1, with no AAD to derive —
`parsing time ...` from `time.Parse`, or a range error after it:

| spelling | sops's message |
|---|---|
| `"…09:05:08+0000"`, `"…09:05:08+00"` | cannot parse as `Z07:00` — the colon is required |
| `"2026-08-21t09:05:08Z"`, `"…09:05:08z"`, `"2026-08-21 09:05:08Z"` | `T` and `Z` are case-sensitive, and the separator is `T` |
| `"2026-8-21T09:05:08Z"` | month and day are two fixed digits (the **hour** is not — see above) |
| `"2026-08-21T09:05:08"`, `"2026-08-21"`, `"20260821T090508Z"` | the layout wants a zone, a time and the dashes |
| `"2026-08-21T09:05:08.Z"` | a fraction needs at least one digit |
| `"10000-08-21T09:05:08Z"`, `"-0001-01-01T00:00:00Z"` | the year is four digits, unsigned |
| `"2026-08-21T09:05:08Z "`, `" 2026-08-21T09:05:08Z"` | `extra text` / cannot parse |
| `""` | cannot parse `""` |
| `"2026-13-01…"`, `"2026-00-01…"`, `"2026-08-00…"`, `"2026-02-29…"` | month / day out of range (leap-aware: `2024-02-29` is accepted) |
| `"…T24:00:00Z"`, `"…09:60:08Z"`, `"…09:05:60Z"` | hour / minute / second out of range |
| `"…+25:00"`, `"…+00:61"` | time zone offset hour / minute out of range (24 and 60 are **in** range) |
| bare `2026-08-21T09:05:08Z` (unquoted) | `'lastmodified' expected type 'string', got unconvertible type 'time.Time'` |

### What the rule is

**AAD = `time.Parse(time.RFC3339, text).Format(time.RFC3339)`**, and — this is
what makes it implementable here — that round trip is **purely lexical**. The
location Go builds is a fixed zone with the parsed offset, so the wall-clock
fields it formats back are the ones it read. Nothing is converted, nothing is
normalised across a date boundary, and no calendar arithmetic is involved:

- the fractional seconds are dropped;
- the hour is zero-padded to two digits (Go's `15` accepts one or two, its
  `01`/`02`/`04`/`05` do not);
- the zone is re-derived from the **total** offset — `+00:60` becomes `+01:00`
  and `+24:60` becomes `+25:00`, measured — and is written `Z` whenever that
  total is zero, whichever sign the document used;
- everything else is copied through.

### The counter-direction: what we write, and what sops writes

Every document sops writes carries `Format(time.RFC3339)` of `time.Now()`, so
it is always the `Z` form; measured, `sops --set` on a document holding
`+00:00` re-stamps it as `"2026-08-21T09:11:38Z"`.

This library has exactly one producer. `File::SOPS::encrypt` is the only caller
of `_metadata_for_encrypt` and of `update_lastmodified`, `policy_args`
deliberately does not carry `lastmodified` across a re-encryption, and
`update_lastmodified` is `strftime('%Y-%m-%dT%H:%M:%SZ', gmtime)` — the
canonical form by construction. **We have never written a spelling this ADR
moves**, and `to_hash` passes that string through unchanged.

## Decision

**`File::SOPS::Metadata->from_hash` decodes `lastmodified` the way sops decodes
it: the stored value is Go's RFC3339 rendering of the timestamp the document
spells, and the document's own text only where that rendering cannot be
derived.**

Four properties, all deliberate.

- **The decode lives in `from_hash`**, the one place every format's parsed
  section arrives — the position ADR 0042 established for exactly this class of
  field, and the only one reachable without changing the two AAD call sites in
  `File::SOPS.pm`. `File::SOPS::Metadata::Flat->unflatten` stays schema-free and
  hands `from_hash` a string, so the ENV and INI stores inherit this with no
  code of their own.
- **The stored attribute is the re-formatted form, not the source text.** That
  is what sops holds: its `Metadata.LastModified` is a `time.Time`, and both
  the AAD and the text it later writes are derived from it. Modelling the text
  and deriving the AAD at each use would need a second conversion, in
  `File::SOPS.pm`, at two call sites that must never drift apart — the defect
  class this distribution has one type ladder and one value conversion to
  prevent.
- **A text this grammar cannot parse is passed through unchanged, not
  refused.** sops stops at exit 1 on every one of them, so nothing is silently
  mis-read; and the grammar is a reimplementation of Go's parser, so the risk
  worth guarding against is that it is *narrower* than Go's somewhere unmeasured.
  Passing through leaves such a document behaving exactly as it does today
  instead of turning a hypothetical gap into a refusal. This is k145's
  reasoning, applied one field over.
- **No range checks are reproduced.** Go refuses a month of 13 or an offset
  hour of 25 *after* lexing; a value out of range therefore only ever appears
  in a document sops will not open, where any AAD we derive is unobservable.
  Reproducing the ranges would add a calendar to this module and could only
  change behaviour for documents nobody can read.

**k144's second direction — an unquoted timestamp — is not decided here.**
go-yaml v3 resolves a bare RFC3339 scalar as `!!timestamp` and `mapstructure`
refuses the document at exit 1; this library reads it. The distinction between
`lastmodified: 2026-08-21T09:05:08Z` and `lastmodified: "2026-08-21T09:05:08Z"`
does not exist by the time `from_hash` sees it — ADR 0038 measured that bare
and quoted scalars arrive as the same Perl string — so no decision in
`Metadata.pm` can implement it. It is a plain/quoted question in the YAML
handler, which is the format lane's, and it is filed as its own ticket. It is
also the permissive direction: nothing is decrypted wrongly, and this library
never *writes* such a document, because `File::SOPS::Format::YAML` quotes the
timestamp on the way out and `t/06-wire-format-regressions.t` pins it.

## Consequences

**Nothing moves for a document either implementation writes.** Measured over a
nine-document corpus before and after — four written by `sops -e` (YAML, JSON,
`--mac-only-encrypted`, `--unencrypted-suffix`), one by `sops -e
--encrypted-suffix`, and four by `File::SOPS->encrypt` (YAML, JSON,
`mac_only_encrypted`, `unencrypted_suffix`) — the AAD, the decrypted MAC
plaintext and the decrypted document are **byte-identical in all nine rows**.
Every such document already carries the canonical form, on which the decode is
the identity.

**What changes is what a document carrying another RFC3339 spelling means.**
14 of the 26 self-consistent spellings measured above were documents `sops -d`
reads at exit 0 and this library refused with `Cannot decrypt MAC`; they are
now read. They fall in three families: a zero offset written as `+00:00` or
`-00:00`, any fractional-second field, and an hour written with one digit —
alone or in combination, and with any offset.

**The permissive gap in the other direction widens by the same families.** A
document whose timestamp is both **unquoted** and non-canonical — bare
`lastmodified: 2026-08-21T09:05:08+00:00` — used to fail here for the AAD
reason while sops refused it for the resolver reason. It now reads here and is
still refused there. That is a wider disagreement about documents sops will not
open, and it is the ticket handed to the format lane above.

**`$meta->lastmodified` is no longer the document's text** for those spellings.
Nothing in this distribution reads the field except the two AAD call sites and
`to_hash`, and `to_hash` only ever runs on a freshly stamped metadata, so the
change is not observable on any write path. A caller that wants the document's
own bytes has the document.

## Rejected alternatives

**Derive the AAD at the two call sites in `File::SOPS.pm`.** The natural
reading of "the AAD is a re-format" — and it puts the same conversion in two
places that must agree forever, which is the single defect this distribution's
one-conversion rule exists to stop. It also spreads a metadata concern into the
MAC path for a field only the metadata owns.

**Add a `mac_aad` method to `File::SOPS::Metadata` and call it from the MAC
path.** Cleaner than two copies and still one conversion, and it keeps
`lastmodified` verbatim. Rejected because it models the field as text and the
AAD as a view of it, where sops models the field as a time and the text as a
view of *that* — and because it leaves `lastmodified` a value whose meaning
depends on which caller reads it.

**Coerce in the constructor as well.** ADR 0042 rejected this for
`mac_only_encrypted` and the reason carries: `File::SOPS::Metadata->new(
lastmodified => $t)` is a Perl caller stating a value, not a document being
read, and there is no producer to be faithful to. `update_lastmodified` already
writes the canonical form, so the constructor has nothing to correct.

**Refuse a `lastmodified` that does not parse, the way sops does.** Fail-loud
argues for it and sops stops at exit 1 on all 16 measured spellings. Rejected
for k145's measured reason: a refusal is only as good as the grammar
behind it, and this grammar is a hand reimplementation of Go's `parse` with a
fallback layout, including corners that look like bugs and are not — a
one-digit hour is accepted, a one-digit month is not; `+24:00` is a legal
offset and `+25:00` is not; `+00:60` is legal and becomes `+01:00`. Getting any
of that narrower than Go refuses a document sops reads, which is the class this
ADR exists to close, not to open somewhere else.

**Normalise the instant to UTC.** The obvious meaning of "canonical RFC3339",
and measured wrong: a `+02:00` document whose MAC sits under the UTC form of
the same instant is exit 51 at sops, and under `+02:00` it is exit 0.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-21, with an age keypair
generated for the run: 45 `lastmodified` spellings for the acceptance table, 26
of them rebuilt as self-consistent documents to confirm the derived AAD, three
purpose-built documents for the literal-versus-re-format experiment, and a
nine-document corpus for the before/after comparison. Every timestamp and
document in the run is invented.

`t/58-lastmodified-is-re-formatted-before-it-is-the-aad.t` carries both
directions: the derived-AAD table against `from_hash` (always) and the same
documents against the binary (interop-gated — without one it skips, which is
the honest outcome and proves nothing about sops).
