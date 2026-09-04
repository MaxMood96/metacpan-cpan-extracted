# ADR 0033 — A multi-document stream is an ArrayRef, which no single document can be

- Status: **accepted** — 2026-09-01, by the maintainer, who took the return-type
  decision (Decision 1: a stream is an ArrayRef, one document stays a HashRef) as
  written and cleared k31 to implement. The review stack the ADR's schedule
  note warned about is now closed.
- Date: 2026-08-21
- Tags: api, yaml, interop, wire-format, multi-document
- Prepares k31 step 1 (the plan in that ticket makes this ADR a precondition
  for every other step)
- Follows k14, which stopped the data loss by refusing multi-document YAML
  rather than truncating it
- Related: ADR 0001 (MAC key order comes from an order-preserving reparse — the
  reparse is one of the two places the one-document rule is held, and it is the
  place a stream breaks silently), ADR 0002 (a value's type comes from the scalar
  — unchanged here, and the reason the AAD needs no change), ADR 0027 (the alias
  budget is go-yaml's ratio — measured below to be **per document**, not per
  stream), ADR 0029 (the depth a walk refuses)

## Context

`File::SOPS::Format::YAML->parse` refuses a multi-document stream today. That
refusal is not conservatism about a parser edge case; it is the fix for real data
loss. `YAML::XS::Load` in scalar context returns the **last** document, so
`a: 1\n---\nb: 2\n` parsed to `{b => 2}` and `encrypt_file` wrote that back as the
whole file. A write path that silently discarded the first half of its input.

sops supports these streams. Not as "several files concatenated", but as **one
tree with N branches** carrying **one** metadata section and **one** MAC across
all of them. Reproducing that reaches encryption, the MAC on both sides, the
order-preserving reparse, `decrypt_file`'s emitter, `extract`'s path language and
`rotate` — which is why k31 asks for a decision before an implementation.

The open question is the public API shape. `encrypt(data => ...)` takes a HashRef
and `decrypt` is documented to return one. A stream has N documents. Something in
the signature has to carry the document axis, or it has to be declared absent.

## What sops does

Everything below was re-measured today against **sops 3.13.3** (`/tmp/sops`), on a
throwaway age keypair, in a scratch directory. The seven points k31 recorded
on 2026-08-08 all still hold; the numbered findings after them are new and were
not in the ticket.

**The seven points, re-measured and confirmed:**

1. **Every document gets its own `sops:` block on write, byte-identical across
   documents** — same age blob, same `lastmodified`, same `mac`. Compared as
   bytes, not by eye.
2. **On read the metadata is taken from the first document.** A stream carrying it
   only in the first document decrypts fine. A stream carrying it only in a later
   document is refused with `sops metadata not found` (exit 1). So the reader must
   not require it in every document, and must not accept it from a later one.
3. **One MAC over all documents in document order.** Dropping the second document
   fails verification; swapping the two documents fails verification. Both report
   `MAC mismatch` with exit 51.
4. **The AAD carries no document index.** Two documents each holding `db: {pw:
   samevalue}` were encrypted, then their two `pw` ciphertexts were swapped between
   documents. The stream decrypts unchanged, exit 0. A ciphertext produced at key
   path K in one document decrypts at key path K in another. `_path_to_aad` needs
   no change.
5. **Separators.** A leading `---` is dropped on write. A trailing `---` is
   preserved, because it opens a real, empty trailing document — measured output
   had two separators and **three** `sops:` blocks.
6. **An empty document anywhere is a real document**, mid-stream as well as
   trailing: it gets its own metadata block and reads back as `{}`.
7. **Every document must be a mapping.** A top-level sequence in a later document
   is refused with `YAML documents that are sequences are not supported`; a
   top-level scalar with `YAML documents that are values are not supported`
   (both exit 2). Note that a *single*-document top-level sequence produces a
   different message — `cannot unmarshal !!seq into map[string]interface {}` — so
   sops has a distinct multi-document code path, and these two messages are its
   fingerprint.

**New findings, none of them in the ticket body:**

**N1. sops loses documents silently when the output format cannot hold them.**
`sops -d --input-type yaml --output-type json` on a two-document stream prints
**only the first document**, exit 0, nothing on stderr. Worse, the same is true on
the **write** path: `sops -e --input-type yaml --output-type json` on a
two-document input writes a single-document JSON file containing only the first
document's keys, exit 0, silent. This is precisely the k14 defect class,
present in the reference implementation. It is measured, and it is not a mandate.

**N2. `sops --extract` sees document 0 and nothing else.** On a two-document
stream, `--extract '["alpha"]'` (a key in document 1) returns its value;
`--extract '["beta"]'` (a key that exists only in document 2) fails with
`error truncating tree: component ['beta'] not found`. There is no document axis:
a top-level integer index addresses **document 0's ordered key list**, not
documents. On a stream whose first document has two keys, `[0]` and `[1]` return
those two key/value pairs and `[2]` reports `accesses out of bounds` — even though
a second document exists. And `--extract '[1]["beta"]'` **panics the Go binary**
(`interface conversion: interface {} is sops.TreeItem, not sops.TreeBranch`).

**N3. Document boundaries are not covered by the MAC.** A stream `a: 1, b: 2 /
--- / c: 3` was re-split by moving the `b` ciphertext line into the second
document, giving `a: 1 / --- / b: 2, c: 3`. It verifies and decrypts, exit 0. The
digest is the concatenated leaf sequence across all documents; where the split
falls is not authenticated. Consistent with this, an empty document contributes
nothing: deleting the trailing empty document from a three-document file still
verifies. Combined with point 4, a value can be moved across a document boundary
undetected as long as the concatenated leaf order is preserved. That is a property
of the format, not something an implementation may repair, but it belongs in the
POD next to what the MAC does guarantee.

**N4. The alias budget (ADR 0027) is per document, not per stream — measured.**
An alias structure calibrated to sit just under go-yaml's threshold (three levels,
fanout 6) is accepted alone. Two such structures with distinct anchor names in
**one** document are refused with `yaml: document contains excessive aliasing`.
The same two structures split across **two** documents are accepted. Four copies
in one document are refused; four copies as four documents are accepted. go-yaml
resets `decodeCount`/`aliasCount` per document. This settles a question ADR 0027's
history says has been guessed wrong before.

**N5. go-yaml carries the anchor table across `---`; both Perl parsers do not.**
`a: &x 1\n---\nb: *x\n` is accepted by sops and decrypts to `a: 1 / --- / b: 1` —
the alias in document 2 resolves against document 1's anchor. `YAML::XS::Load`
refuses it (`No anchor for alias 'x'`) and so does `YAML::PP` (`No anchor defined
for alias 'x'`). This is a go-yaml divergence from document-scoped anchors, and it
is a stream sops can write that this library's parsers cannot load at all.

**N6. `rotate` preserves the invariant.** `sops -r -i` on a two-document stream
rewraps one new data key and writes identical metadata into both documents;
the two `mac` values stay equal and the file decrypts.

**N7. Encryption rules are one set for the whole stream.** `--unencrypted-suffix`
applied to a two-document input leaves the suffixed key readable in *both*
documents and writes `unencrypted_suffix` into both metadata blocks. The rule
policy is a property of the stream, not of a document.

## The trap, re-measured

k31 records it and it is unchanged today, on `YAML::XS` v0.910.0 and
`YAML::PP` v0.41.0:

| | scalar context | list context |
|---|---|---|
| `YAML::XS::Load` | the **last** document | all documents |
| `YAML::PP->load_string` | the **first** document | all documents |

The MAC walk takes key **order** from the YAML::PP reparse and **values** from the
YAML::XS tree, so any path that lets a stream reach that walk pairs one document's
order with another's values — a wrong MAC, computed without an error.

It is currently guarded in two independent places, and both must move together:
`Format::YAML::parse` croaks above one document, and
`File::SOPS::_parse_in_document_order` holds the rule again for itself
(`return unless @docs == 1 && ref $docs[0] eq 'HASH'`), falling back to sorted
order rather than trusting a mismatched pairing. The second guard fails safe by
construction — it can only make verification fail, never wrongly succeed — and
that property must survive the change.

## Decision

### 1. A stream is an ArrayRef of HashRefs; one document stays a HashRef

`encrypt` accepts `data => [ \%doc1, \%doc2, ... ]` in addition to
`data => \%doc`. `decrypt` returns an ArrayRef of HashRefs for a stream that
really holds more than one document, and a HashRef otherwise.

This is option (a) from the ticket, and the case for it is stronger than "it is
unambiguous". It is unambiguous — point 7 is a rule sops enforces, so no document
can be an ArrayRef and no value of `data` is ambiguous between "one document" and
"a stream". But the decisive fact is different:

**Neither half is a breaking change, because both cases die today.**

- On input, `encrypt` already refuses an ArrayRef: `croak "data must be a hash
  ref" unless ref($data) eq 'HASH'`. No caller can depend on the current
  behaviour, because the current behaviour is an exception.
- On output, `decrypt` can only return an ArrayRef for a multi-document stream —
  and a multi-document stream never reaches `decrypt` today, because
  `Format::YAML::parse` croaks on it first. No caller has ever received a value
  from that path.

So the "changes the documented return type of `decrypt`" cost that made this an
ADR is real on paper and empty in practice: the type widens only over inputs that
currently raise. That is what makes (a) preferable to (b) and (c) rather than
merely nicer.

The return type mirrors the **document**, not the call. `encrypt` given a
one-element ArrayRef writes a one-document file, byte-identical to what the same
HashRef would produce, and `decrypt` reads that back as a HashRef. The asymmetry
is deliberate and must be documented: what round-trips is the *file*, not the
Perl-level container.

### 2. `extract` stays on document 0 by default, and says so

sops has no document axis and cannot grow one without colliding with itself: a
leading integer already means "the Nth key of document 0" (N2), so `[1]` is taken.
Following sops exactly means `extract` addresses the first document and a key in a
later one is simply not found.

That is the default. In addition, `extract` takes an explicit
`document => $n` argument (default `0`) to reach the others. It is a separate
argument rather than a path extension precisely so the path language stays
sops's — the same language, applied to a document the caller names.

Two guards, both loud:

- `document => $n` beyond the last document is an error naming the document count,
  not a silent `undef`.
- A path not found is an error that **names which document was searched**. sops
  says `component ['beta'] not found`; ours can search more than one document, so
  the message must say which one it looked in, or a typo in `document` reads as a
  typo in `path`.

`extract` must never fall through to later documents looking for a key. That would
diverge from sops in the one direction that turns a caller's mistake into a
plausible-looking answer.

Whatever `sops --extract '[1]["beta"]'` does, we do not reproduce: it panics
(N2). A Go panic is not a specification.

### 3. Where sops loses a document, we refuse

N1 is the one place this ADR deliberately diverges, and it is the divergence the
house rule exists for. `sops` silently drops all but the first document when the
output format cannot hold a stream — on read *and* on write, exit 0, no warning.
JSON has no document stream, so there is no faithful representation to produce.

Copying that would re-introduce k14 in a new place. So: converting a
multi-document stream to a format that cannot hold one is **refused**, with a
message that names the document count and the target format. The wire is
unaffected — this only governs a conversion sops performs lossily and we decline
to perform at all.

This is deviation, and per the house rule it is deviation that gets written down:
the POD must say that sops truncates here and that this library refuses instead.

### 4. The guards count per document

Measured (N4) for the alias budget and structural for the rest:

- **Alias budget (ADR 0027)** — `_assert_expansion_bounded` runs **once per
  document**, with a fresh accumulator and a fresh memo. go-yaml resets its
  counters per document, and N4 measures it. Running one census over the whole
  stream would refuse streams sops accepts, which is the exact error class ADR
  0027 was written to avoid. Note also that the census's two `+ 1` terms ("the
  document node itself") are per document and stay per document.
- **Depth (ADR 0029)** — per document, and the list must **not** be walked as if
  it were a container. Wrapping N documents in an ArrayRef and walking that would
  charge every document one level of the 10 000 budget and make the wrapper a
  container `_assert_depth` counts. Each document is entered by a top-level call
  with `$depth` unset.
- **Cycle (ADR 0025)** — the ancestor set is unwound on the way out, so one
  `$active`/`$clean` pair shared across documents stays correct, and sharing
  `$clean` is a win. One caveat that must not become a refusal: a caller-built
  ArrayRef may legitimately share one HashRef between two documents. That is a
  DAG, not a cycle, and it is legal. It cannot arise from a *parsed* stream in
  Perl, because anchors are document-scoped in both YAML::XS and YAML::PP (N5).
- **ADR 0023 (overflow literal) and ADR 0024 (comment leaf)** — per document, and
  their visited sets should be re-allocated per document rather than shared.
- **ADR 0026 (plain infinity)** — this is the one that breaks structurally.
  `_restore_plain_infinities` re-parses the raw `$content` with YAML::PP and pairs
  that tree against `$data`; on a stream, list context yields N documents and the
  pairing has no defined counterpart. It must pair document-by-document. Its
  `if $metadata` gate also stops being a per-document fact once one metadata block
  is shared by N documents.
- **ADR 0028 (merge tag)** — pure text substitution on `$content` before a retry,
  no tree and no counter. Unaffected.

### 5. A stream sops accepts and our parsers cannot read is refused loudly

N5 has no fix available at this layer. A stream whose later document aliases an
earlier document's anchor is a stream go-yaml reads and libyaml does not. The
parser's own error surfaces, which is loud rather than silent; the POD names the
limitation. Recording it as a ticket is the right next step, not widening this
change.

## What changes for existing callers

For the recommended option, in order of how likely anyone is to notice:

1. **Nothing, for every document that parses today.** A single-document file
   encrypts and decrypts to exactly the same bytes and the same HashRef. The MAC,
   the AAD and the type ladder are untouched — point 4 is why the AAD needs no
   change, and no leaf's digest input moves.
2. **`decrypt` may now return an ArrayRef**, but only for input that today raises
   `multi-document YAML is not supported yet`. A caller who never fed such a file
   in cannot observe the difference; a caller who did was getting an exception.
   Code that wants to be shape-agnostic writes
   `my @docs = ref $r eq 'ARRAY' ? @$r : ($r);`
3. **`encrypt` accepts an ArrayRef in `data`**, where it previously raised
   `data must be a hash ref`. Purely additive.
4. **`extract` gains `document => $n`**, defaulting to `0`. Existing calls are
   unaffected; on a single-document file the argument is a no-op.
5. **A new refusal**: converting a multi-document stream to JSON. Today that
   combination cannot arise, because the stream is refused earlier — so this
   removes no working behaviour, and it declines to add the lossy behaviour sops
   has.
6. **`Changes` entry**, naming the user-visible effect: multi-document YAML is
   read and written; `decrypt` returns an ArrayRef for such a file; `encrypt`
   takes one.

## Alternatives considered

**(b) Always an ArrayRef, even for one document.** Consistent, and the only option
here that is genuinely breaking: every existing caller of `decrypt`, `extract` and
`encrypt` would have to change, for a shape that carries no more information than
(a) does. (a) is unambiguous already — point 7 guarantees it — so uniformity buys
nothing except the break. Rejected.

**(c) Context-dependent, or a `documents => 1` argument.** This exists to avoid a
break, and there is no break to avoid (Decision 1). It would buy a second code
path in `encrypt`, `decrypt` and `extract`, permanently, in exchange for nothing.
Returning a list in list context and a scalar in scalar context is worse still:
`my ($x) = File::SOPS->decrypt(...)` and `my $x = File::SOPS->decrypt(...)` would
mean different things, and the MAC-walk trap in this very ticket is a
scalar-versus-list context bug that already cost this distribution a data-loss
defect. Rejected.

**Splitting a stream into N independent documents at the API.** Rejected on the
format: there is one metadata block and one MAC spanning all documents (points 1
and 3), so a single document out of a stream cannot be verified, decrypted or
re-encrypted on its own. Dropping a document fails verification, measured.

**Reproducing sops's silent JSON truncation** — see Decision 3.

## Consequences

- `Format::YAML->parse` returns a document list, and `_parse_in_document_order`
  returns one too. They must change **together**: the trap is that one supplies
  order and the other values. This is why k31's plan puts the trap first, in
  one commit, before the MAC change.
- The MAC becomes leaves in document order, each document contributing its own key
  order. Nothing else about the digest moves.
- `t/13-multidoc-yaml.t` (the ticket calls it `t/09-multidoc-yaml.t`; it was
  renumbered) pins the current refusal in 8 subtests, including one that drives
  the real binary. Most of it becomes the wrong assertion and should be rewritten
  into a round-trip test in both directions, not deleted — the interop subtest
  already builds a real two-document sops file and is most of the fixture the new
  test needs.
- N3 belongs in the POD: the MAC authenticates the concatenated leaf sequence, not
  where the document boundaries fall.

## What this does not decide

- Whether `edit` on a stream keeps its current new-data-key divergence (k41).
- The N5 anchor-scope divergence, which needs a ticket of its own.
- Multi-document support for any format other than YAML. JSON has no document
  stream; ENV and INI do not exist yet (k36, k37).

## Effort for k31 steps 2–6

Honest estimate, assuming this ADR is accepted as written and the lanes run in the
ticket's binding order. The interop suite must run for real at every step — a
green unit suite proves nothing here.

| Step | Lane | Size | Where the time actually goes |
|---|---|---|---|
| 2 — the trap: both parsers to document lists in one commit | wire | **M** | Small diff, high blast radius. `parse` and `_parse_in_document_order` both change, and the second must keep failing *safe*. Needs a test that fails when the two are paired wrongly — which is the hard part, since a mispairing produces a wrong MAC, not an error. |
| 3 — MAC over all documents in order | wire | **S–M** | The digest change itself is small (`_document_leaves` iterates a list). `_path_to_aad` is untouched, measured. Cost is interop proof in both directions. |
| 4 — metadata: one instance, written to every document, read from the first | api | **S** | Points 1, 2 and N7 are precise. Mostly `Format::YAML`'s split/re-attach plus the "not required in later documents" rule. |
| 5 — separators and empty documents in the emitter | format | **M** | Deceptive. Leading/trailing `---` and empty documents are fiddly (point 5, point 6), and an empty document is `undef` from YAML::XS but must read back as `{}` — a real gap between the two, not a formality. Key-order sorting per document must survive, or self-verification breaks. |
| 6 — rewrite `t/13-multidoc-yaml.t` as a round-trip | test | **M** | Both directions against the real binary, plus regressions for N1 (the refusal), N2 (`extract` on document 0 and `document =>`), N3, N5, and the per-document guards from N4. |
| — | api | **S** | POD for `encrypt`/`decrypt`/`extract`/`decrypt_file`, the `Changes` entry, and the deviation note that Decision 3 requires. |

**Overall: a solid multi-session change, not an afternoon.** Steps 2 and 3 carry
almost all the risk, and both fail silently rather than loudly when they are wrong
— a mispaired MAC verifies against nothing but itself. The three guards need a
per-document decision each (Decision 4), and one of them (ADR 0026) needs
restructuring rather than a parameter.

The largest schedule risk is not in the table: k31's own board note asks that
this ticket not land while the review stack is open, because six steps touching
the same files make every later diff unreadable. Three lanes were working in
`lib/` when this ADR was written.
