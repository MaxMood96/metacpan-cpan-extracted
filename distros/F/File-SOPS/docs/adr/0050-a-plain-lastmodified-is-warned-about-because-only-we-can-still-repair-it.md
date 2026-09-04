# ADR 0050 — A plain `lastmodified` is warned about, because only we can still repair it

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`, in a scratch
  copy of the tree at 42f15b8, before anything in `lib/` was touched
- Date: 2026-08-21
- Tags: yaml, metadata, parser, interop, guards
- Resolves k159, which is k144's second direction — the one ADR 0044
  measured, named and could not implement where it lived
- Depends on ADR 0044 (`lastmodified` is decoded in `from_hash`, and the
  attribute is Go's re-format rather than the document's text — so this guard
  reads the raw section, not the object), ADR 0038 (a bare and a quoted scalar
  arrive as the same Perl string, which is why the decision cannot be taken in
  `Metadata.pm`), ADR 0026 (the plain/quoted question, asked here of a different
  oracle for a measured reason) and ADR 0032 (`!!timestamp` never reaches this
  guard, because `YAML::XS` refuses it at parse)
- Answers k145's condition — "does the guard refuse a document sops
  accepts?" — with a measured no, and lands on a **warning** rather than the
  refusal that question was about
- **Moves no bytes.** Nothing is parsed differently, nothing is emitted
  differently, and no digest changes. What is new is a `carp` on one read path

## Context

sops writes the `sops` section's timestamp quoted:

```yaml
sops:
    lastmodified: "2026-08-21T09:05:08Z"
```

and so does this distribution — `_quote_sops_timestamp` exists for exactly that
reason, because `YAML::XS` emits an RFC3339 scalar bare and go-yaml resolves a
bare RFC3339 scalar to a Go `time.Time` where sops's `mapstructure` decode wants
a string. That half has been right since the quoting landed, and
`t/06-wire-format-regressions.t` pins it.

The read half was never closed. ADR 0044 measured it, wrote it down, and handed
it on:

> The distinction between `lastmodified: 2026-08-21T09:05:08Z` and
> `lastmodified: "2026-08-21T09:05:08Z"` does not exist by the time `from_hash`
> sees it — ADR 0038 measured that bare and quoted scalars arrive as the same
> Perl string — so no decision in `Metadata.pm` can implement it.

The fact is in the source bytes, and the source bytes are the format handler's.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age keypair generated for the run. Each row is a
document `File::SOPS->encrypt` wrote, with only the `lastmodified` line
re-spelled verbatim and the `mac` re-encrypted under the AAD ADR 0044 derives
from the row's value — so `sops -d` exit 0 means the spelling was accepted and
nothing else was disturbed.

### 1. Every spelling sops accepts quoted, it refuses bare

15 spellings, two documents each:

| value | quoted | bare |
|---|---|---|
| `2026-08-21T09:05:08Z` | **0** | 1 `time.Time` |
| `2026-08-21T09:05:08+00:00` | **0** | 1 `time.Time` |
| `2026-08-21T09:05:08-00:00` | **0** | 1 `time.Time` |
| `2026-08-21T11:05:08+02:00` | **0** | 1 `time.Time` |
| `2026-08-21T04:05:08-05:00` | **0** | 1 `time.Time` |
| `2026-08-21T14:35:08+05:30` | **0** | 1 `time.Time` |
| `2026-08-22T09:05:08+24:00` | **0** | 1 `time.Time` |
| `2026-08-21T09:05:08+00:60` | **0** | 1 `time.Time` |
| `2026-08-21T09:05:08.0Z` | **0** | 1 `time.Time` |
| `2026-08-21T09:05:08.123456789Z` | **0** | 1 `time.Time` |
| `2026-08-21T09:05:08,123Z` | **0** | 1 `time.Time` |
| `2026-08-21T9:05:08Z` | **0** | 1 `time.Time` |
| `2026-08-21T1:05:08+02:00` | **0** | 1 `time.Time` |
| `0000-01-01T00:00:00Z` | **0** | 1 `time.Time` |
| `0001-01-01T00:00:00Z` | **0** | 1 `time.Time` |

`time.Time` is `decoding failed due to the following error(s): 'lastmodified'
expected type 'string', got unconvertible type 'time.Time'`, exit 1, before any
value is decrypted. **`File::SOPS->decrypt` read all 30 documents at HEAD**, in
both columns, without a word.

**There is no accepted bare spelling.** That is the whole of k145's
question, answered: a guard keyed on "the scalar is plain and go-yaml resolves
it as a timestamp" cannot refuse or warn about a document sops opens.

### 2. …with one exception, and it is the reason for the tag check

| spelling | sops `-d` |
|---|---|
| `!!str 2026-08-21T09:05:08Z` — **bare, tagged** | **0** |
| `!!str "2026-08-21T09:05:08Z"` | **0** |
| `2026-08-21T09:05:08Z` — the same scalar, untagged | 1 |

go-yaml runs `parseTimestamp` only for an untagged node, so an explicit `!!str`
makes the same bytes a string and sops reads the document. A guard that looked
only at the scalar's *style* would fire on this one — on a document sops
accepts, which is precisely what k145 was protecting against. Hence: a
scalar carrying any tag answers "not plain". The one tag that *would* resolve
to a timestamp, `!!timestamp`, never reaches here — `YAML::XS` refuses it at
parse and `%TAG_REFUSAL` names it (ADR 0032).

### 3. What a plain scalar that is *not* a timestamp does

| bare value | what go-yaml makes of it | sops `-d`, quoted | sops `-d`, bare |
|---|---|---|---|
| `hello` | string | 1 `time.Parse` | 1 `time.Parse` |
| `2026` | int → `mapstructure` weakly converts to `"2026"` | 1 `time.Parse` | 1 `time.Parse` |
| `true` | bool → `"1"` | 1 `time.Parse` | 1 `time.Parse` |
| `3.14` | float → `"3.14"` | 1 `time.Parse` | 1 `time.Parse` |
| `null`, `~` | null → `""` | 1 `time.Parse` | 1 `time.Parse` |
| `2026-08-21T09:05:08` (no zone) | string | 1 `time.Parse` | 1 `time.Parse` |
| `2026-08-21T09:05:08+25:00` | string | 1 `time.Parse` | 1 `time.Parse` |
| `2026-08-21T24:00:00Z` | string | 1 `time.Parse` | 1 `time.Parse` |
| `2015-02-29T00:00:00Z` (not a date) | string | 1 `time.Parse` | 1 `time.Parse` |
| `2026-08-21` | **timestamp** | 1 `time.Parse` | 1 `time.Time` |
| `2026-08-21 09:05:08` | **timestamp** | 1 `time.Parse` | 1 `time.Time` |
| `2026-8-21T09:05:08Z` | **timestamp** | 1 `time.Parse` | 1 `time.Time` |
| `2026-08-21t09:05:08Z` | **timestamp** | 1 `time.Parse` | 1 `time.Time` |

`mapstructure` decodes weakly: an int, a float, a bool and a null all become
strings and then fail `time.Parse` — the same failure they have when quoted. So
**quoting is not the discriminator for any of these**, and that is what puts
them outside this ADR: they are refused by sops either way, which is the family
ADR 0044 deliberately passes through rather than refuses.

The bottom four are the family this guard covers even though sops would refuse
them quoted as well. Warning about them costs nothing: the document is not
readable at sops in either spelling.

### 4. Reading such a document and writing it back **repairs it**

The measurement the whole decision turns on. One document, `lastmodified`
un-quoted by hand:

```
sops -d                                                      exit 1
File::SOPS->rotate, then sops -d                             exit 0
File::SOPS->decrypt_file + encrypt_file, then sops -d        exit 0
```

Both write paths re-stamp the metadata and quote the timestamp, so the file
comes out readable at both ends. Whatever this library does on the read path, it
must not stop that from being possible.

### 5. Where the model and go-yaml's resolver disagree

`_go_timestamp` is this module's measured reimplementation of go-yaml's
`parseTimestamp`, already used by the emit-side foreign-resolution guard. Over
the 29 spellings above it agrees with the binary on 27, and both disagreements
land in the safe direction:

| spelling | model | go-yaml | consequence |
|---|---|---|---|
| `2026-08-21T09:05:08,123Z` (comma fraction) | not a timestamp | timestamp | the guard stays **quiet** on a document sops refuses |
| `2026-08-21T09:05:08+25:00` (offset hour out of range) | timestamp | string | the guard **fires** on a document sops refuses anyway, for its other reason |

Neither can produce a word about a document sops reads, which is the only
property that has to hold.

## Decision

**A `lastmodified` the document wrote as a plain, untagged scalar, whose token
go-yaml resolves as a timestamp, is `carp`ed about in
`File::SOPS::Format::YAML::parse`. It is not refused, and nothing else changes.**

Four properties, all deliberate.

- **It warns rather than refuses**, and measurement 4 is why. Every write path
  here repairs such a document; a refusal on the read path would take the one
  tool that can still open the file and leave it openable by nothing. In a
  library whose subject is secrets, a new way to lose access to a readable file
  is worse than the permissive gap it would close. This is the same shape as
  ADR 0018 and ADR 0019, which both warn where nothing is decrypted wrongly, and
  the opposite of ADR 0030 and ADR 0033, which refuse where something is.

- **The oracle is YAML::PP's parser, not its resolver.** ADR 0026 asks YAML::PP
  what a scalar *resolves to*, because for `.inf` that answer **is** the
  plain/quoted answer: its Core schema reads a plain `.inf` as a float and a
  quoted one as a string. That does not carry here, measured: YAML 1.2's Core
  schema has no timestamp type, so YAML::PP hands back the identical Perl string
  for `2026-08-21T09:05:08Z` and `"2026-08-21T09:05:08Z"`. What carries is the
  *question*, and the parser answers it directly — the scalar event's `style`,
  the same oracle `_plain_boolean_tagged_scalars` already uses for the `!!bool`
  retry (ADR 0030) and `_merge_tagged_scalars` for the merge tag (ADR 0028).
  Measured over 17 spellings: it places a plain scalar written on the line below
  its key, inside a flow mapping, and behind an explicit `? key`, all three of
  which a regex over the text would miss.

- **Position, not name.** The target is the value of `lastmodified` in the
  mapping that is the value of `sops` in the root mapping. A user's own
  `lastmodified` key elsewhere in the document is not this field and is never
  warned about — the same rule `_quote_sops_timestamp` holds on the write side,
  and the same defect class as the `mac:` text-match ADR 0001 removed.

- **Two cheap gates before the second parser.** No `sops` section, or a
  `lastmodified` that is not a scalar, and the walk never runs; a token
  `_go_timestamp` does not take, and it never runs either. YAML::PP parses
  nothing for the overwhelming majority of documents, and a document YAML::PP
  will not read is not warned about — fails safe, like its merge and `!!bool`
  twins.

## Consequences

**Nothing this library or sops writes is affected.** Both produce
`lastmodified: "…"`; the warning is measured silent on every document in the
suite except the two that spell it bare on purpose.

**One warning per read.** `decrypt`, `extract` and `decrypt_file` warn once;
`rotate` warns twice, because it reads the document twice. Deduplicating would
need state that outlives a call, which is worse than a second line, and the
second line is not wrong.

**`t/58`'s third subtest inverted.** It pinned "sops refuses it, we read it";
it now pins "sops refuses it, we read it and say so". Nothing else in the suite
moved: 63 files and 1286 tests PASS at 42f15b8, 64 files and 1298 tests PASS
with this change, with `t/04` and every other interop-gated file executed
against sops 3.13.3 rather than skipped.

**The permissive gap is narrowed, not closed.** Such a document is still read.
What changes is that the caller is told their file is one no sops can open, and
told how to fix it — including that re-encrypting it here is the fix.

## Rejected alternatives

**Refuse the document.** The fail-loud reading, and what k145's question
was framed around. Rejected on measurement 4: `rotate` turns such a file into
one `sops -d` reads, and a refusal deletes that path. It would also be the first
refusal in this distribution for a document that is read *correctly* — the
values, the AAD and the MAC are all right; only portability is not.

**Refuse or warn about *any* plain `lastmodified`, timestamp or not.** Simpler,
needs no grammar at all, and measured true: all 25 bare spellings tried are
refused by sops, and the reason generalises — `mapstructure` converts an int, a
float, a bool and a null to strings that `time.Parse` cannot take, and anything
`time.Parse` *can* take is resolved as a timestamp before it gets there.
Rejected because it is a wider claim than the measurement supports for a
document nobody has, and because for `hello` or `2026` quoting is not the
discriminator: those are refused by sops in both spellings, which is exactly the
family ADR 0044 decided to pass through. The line this ADR holds is that the
guard speaks only where **the plain/quoted state is what makes sops refuse**.

**Narrow the predicate until it matches go-yaml's `parseTimestamp` exactly.**
Would remove the `+25:00` over-reach in measurement 5 by reproducing Go's zone
range checks. Rejected for k145's reason: a refusal — or a warning — is
only as good as the grammar behind it, and hand-narrowing a grammar is how a
guard starts speaking about the wrong documents. The over-reach is one spelling,
in the direction that cannot hurt.

**Carry the plain/quoted state out of `parse` and let `Metadata.pm` decide.**
Keeps the field's rules in one module and would have let ADR 0044 finish its own
ticket. Rejected because it puts a YAML-only fact into the interface every
format's section arrives through: `Metadata::Flat->unflatten` has no notion of
quoting, and neither ENV nor INI has a resolver that could disagree. The fact is
YAML syntax; it belongs to the YAML handler.

**Repair the document by quoting it on the way through, silently.** The write
paths already do this, so a caller who round-trips gets the fix for free. Doing
it *silently* on the read path would leave a caller who only reads with a file
that still fails everywhere else and no reason to look.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-21 from a scratch copy of
the tree at 42f15b8, with an age keypair generated for the run: 29 spellings ×
2 documents each for the acceptance tables, 4 tagged spellings, and one
repair-path run through `rotate` and through `decrypt_file` plus `encrypt_file`.
Every timestamp and document in the run is invented.

`t/64-a-plain-lastmodified-is-warned-about-not-refused.t` carries the whole of
it: the two-parser contrast that shows why ADR 0026's mechanism does not carry,
the 17-spelling style table, the guard's behaviour on real documents (always),
and the sops columns of every table above (interop-gated — without a binary it
skips, which is the honest outcome and proves nothing about sops). Without the
mechanism it fails **32 assertions across 4 of its 12 subtests**.

### What this leaves open, and where

**k148 is not touched by this**, and was measured in the same session
rather than implemented — see the ticket. Its short form: a comment above a
mapping key is lost in both directions, and the write half is a wall rather than
a lane handoff. `YAML::XS` is libyaml, whose emitter cannot write a comment at
all; `YAML::PP`'s emitter has no comment event either, and its own documentation
lists comment-preserving round trips as a TODO. The read half is nearer than
k148's body says — `YAML::PP`'s *parser* keeps the comment text in its raw
token stream, through an undocumented accessor — but a recovered comment has
nowhere to go: ADR 0041 could preserve a sequence comment because a sequence
element is a slot the tree already has, and a mapping-position comment sits
before a key, where a Perl hash has none.

One drift found while measuring it and filed rather than acted on: a document
whose comment is a **sequence** element is refused by `emit` — which is what
makes `decrypt_file` and `edit` refuse it rather than drop it — while a document
whose only comment is above a **mapping** key is written back silently without
it. `sops -d` returns both comments intact for both documents.
