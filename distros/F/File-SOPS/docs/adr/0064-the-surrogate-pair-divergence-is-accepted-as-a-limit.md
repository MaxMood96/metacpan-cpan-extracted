# ADR 0064 — A surrogate-pair escape in a JSON key splits the two decoders, and the divergence is accepted as a limit

- Status: accepted
- Date: 2026-08-23
- Resolves k139
- Lane: format
- Depends on **ADR 0001** (the MAC's order comes from a YAML::PP reparse,
  whose fail-safe property is exactly what makes this divergence
  tolerable), **ADR 0036** (the order-preserving reparse is asked of the
  format handler, and the same reparse is what surfaces the disagreement
  here), and **ADR 0049** (a path component one walk adds and the other
  does not is a document this library writes and cannot read -- the same
  class of bug the surrogate-pair key produces when it reaches the
  reparse)
- Does **not** touch any parser, emitter, encoder, the MAC, the AAD, the
  value->bytes conversion, or any backend. No bytes move for any
  document this library already writes. The code comment at
  `File::SOPS::Format::JSON` lines 410-428 already names the divergence
  this ADR accepts as deliberate; this ADR documents the measurement
  behind that comment and turns it into the bound a future change would
  have to measure against.

## Context

The MAC's order is the document's. The order is recovered by reparse,
the reparse is asked of the format handler, and the format handler for
JSON delegates the reparse to the YAML handler (ADR 0036 refining
ADR 0001). So the order of a JSON document is read by `YAML::PP`, while
its values are read by `Cpanel::JSON::XS`. The two readers must agree
on what each key is; if they disagree, the walk that hashes the values
in order will look for a key in the Cpanel tree that is not there, and
must refuse loudly. The fail-safe direction is named in both ADRs: a
lost order costs a fallback that can only make verification fail, never
wrongly succeed.

There is one key shape the two readers resolve differently. A literal
JSON-escape surrogate pair

```
"😀"
```

reads as

- one codepoint, U+1F600 (UTF-8 bytes `\xF0\x9F\x98\x80`), to
  `Cpanel::JSON::XS` and to Go's `encoding/json` and to sops 3.13.3.
- two lone surrogates, U+D83D and U+DE00 (six UTF-16-like code units),
  to `YAML::PP` quoted-string parsing.

The mismatch is on the key's value, not on the document's shape. Both
readers find one key where the source declares one key; they just
disagree about what the bytes of that key are.

## Measurement

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23 with a
hand-written JSON document whose key was the literal six ASCII
characters `😀`:

```
$ od -c test-surr-flat.json
0000000   {   "   \   u   D   8   3   D   \   u   D   E   0   0   "   :
0000020       "   v   "   }  \n
0000026
```

A 26-byte file. Two decoders reading it:

| decoder                     | key the read yields                                          |
|---|---|
| `Cpanel::JSON::XS`          | one codepoint, `chr(0x1F600)`, length 1, bytes `\xF0\x9F\x98\x80` |
| `YAML::PP` (quoted form)    | two codepoints, `chr(0xD83D) . chr(0xDE00)`, length 2       |

Same input, two different keys, byte-lengths apart.

`sops 3.13.3` reading the same six ASCII characters:

| step              | result                                                      |
|---|---|
| `sops -e` exit    | 0                                                           |
| encrypted key bytes | `\xF0\x9F\x98\x80`, the UTF-8 of U+1F600                  |
| encrypted key text  | the surrogate escape `😀` is NOT in the output   |
| `sops -d` exit    | 0                                                           |
| decrypted key bytes | `\xF0\x9F\x98\x80`, identical to what sops wrote           |

Sops combines the pair and writes UTF-8 bytes -- the same decision Go's
`encoding/json` makes. YAML's wire form for the same U+1F600 is the
seven-character `\U0001F600` escape, which sops writes when the format
is YAML; the same key on the same document, in YAML, round-trips
through sops 3.13.3 at exit 0.

Our emitters, measured in `t/76` section 3:

| emitter                     | what it writes for a non-ASCII key                          |
|---|---|
| `File::SOPS::Format::JSON`  | UTF-8 bytes (`Cpanel::JSON::XS`, `utf8 => 1`), never the `\uXXXX` escape form |
| `File::SOPS::Format::YAML`  | UTF-8 bytes (`YAML::XS`), never the `\uXXXX` escape form    |

Neither emitter writes the divergent form. The only input that exercises
the divergence is a hand-written or third-party JSON document -- exactly
the case the ticket names as the only reachability.

The walk's behaviour when the divergence reaches it:

| step                                 | result                                                      |
|---|---|
| walk reads `$ordered->{outer}{chr(0xD83D).chr(0xDE00)}` | the YAML::PP-ordered key, two codepoints            |
| walk checks `exists $data->{outer}{$that_key}`           | FALSE (the Cpanel tree has `chr(0x1F600)`, not the two surrogates) |
| walk croaks with `"present in the document but not in the parsed tree"` at path `outer.<key>` | LOUD refusal |

Pinned by `t/76` sections 1 and 2.

## Decision

**The divergence is accepted as a limit. No parser, emitter, encoder or
reparse hook changes; the code comment in
`File::SOPS::Format::JSON` lines 410-428 that already names it is the
canonical record.**

The default condition for accepting the limit is met. The decision
criterion stated in the ticket is:

> sops selbst kombiniert Surrogate-Paare AND die reparse-Fehler-Nachricht
> wird für ein key-only-Dokument ausgelöst.

Both halves are measured true. The two together are enough because:

- **sops reads and writes UTF-8**, which is what both `Cpanel::JSON::XS`
  and `YAML::PP` agree on for non-ASCII keys, so every document this
  library produces is byte-compatible with sops in this dimension --
  measured, exit 0 on both directions.
- **The only input that produces the divergence is hand-written or
  third-party JSON**, which is also the only input that surfaces the
  reparse error. A document that exits sops at 0 never reaches the
  walk in the divergent shape.
- **The walk refuses loudly**, naming the path. The fail-safe direction
  is exactly the one ADR 0001 and ADR 0036 name, and the ticket
  describes it as the property to preserve.

That leaves three things the limit costs, all measured:

1. **A hand-written or third-party JSON document with a surrogate-pair
   escape in a key is refused on decrypt with the reparse's loud
   error**, not silently corrupted, not silently passed through. The
   refusal names the path so the caller can re-encode the file (UTF-8
   bytes for the same codepoint, what sops itself writes) and try
   again.
2. **No file this library emits reaches the divergent input shape**,
   so applying this library's encrypt path to a hand-built tree does
   not produce a file the reparse cannot read. Round-trip through
   `File::SOPS->encrypt` then `File::SOPS->decrypt` of a Perl string
   holding U+1F600 produces a byte-identical key on both sides,
   measured.
3. **The cost of supporting the input shape is a pre-pass over the
   JSON document text** for `\uXXXX\uYYYY` sequences where the second
   pair is a low surrogate (U+DC00..U+DFFF). That is option (b) of the
   ticket. It is rejected below, with reasons.

## Rejected alternatives

**(b) Detect and re-decode the surrogate-pair escape form before the
parsers run.** A small pre-pass walks the JSON document text for
`\uXXXX\uYYYY` sequences where the second pair is in U+DC00..U+DFFF,
combines them to the corresponding codepoint in the buffer, and lets
both parsers read the same combined form. Rejected:

- the cost is one walk over the document text for every decrypt
  regardless of whether the document carries the form, which is most
  of them;
- the pre-pass must read JSON correctly enough not to rewrite a
  `\uXXXX` that lives inside a JSON STRING (a leaf value, where the
  escape is meaningful), which is a hand-written parser over a
  format we already have a parser for;
- the gain is a leaf class our own emitters do not produce and sops
  does not produce, so the only files the pre-pass would rescue are
  the hand-written / third-party ones, which the loud refusal already
  names the path for.

**(c) Normalize the reparse side: collapse any two-surrogate pair in
the keyset before the walk.** Cheaper than (b) but inconsistent if a
surrogate pair ever appears in a VALUE rather than a KEY -- the
values come from `Cpanel::JSON::XS`, which already combined them, so
the value side has no problem to solve; adding a keyset normalizer
binds the reparse to the Cpanel read's behaviour and removes the
property that lets the reparse fail loud on a structurally broken
input. Rejected for the same reason (b) is: it solves a case neither
emitter produces, in a way that erodes the fail-safe property.

**(d) Replace `YAML::PP` with `go-yaml` or a YAML reader that joins
standalone surrogates.** Out of scope (the YAML handler is what
`File::SOPS::Format::YAML` owns, and `go-yaml` is not a Perl module);
also out of scope because the JSON handler delegates to it for
`parse_in_document_order` precisely so the two formats share one
order-preserving reader (ADR 0036, ADR 0001). Two copies of the order
reader is the failure mode ADR 0001 records as the k32 defect
class.

## Consequences

### What changes for existing callers

Nothing. No wire byte, no error message, no behaviour for any document
this library already writes or reads.

### What stays loud, and what stays silent

The walk still refuses at the first key the Cpanel tree does not have,
naming the path. That refusal was already loud before this ADR; this
ADR records the limit and the measurement, and pins the
per-decoder/per-decoder/per-emitter shapes with `t/76-json-surrogate-pair-key-meets-its-decision.t`.

### What stays wrong, on purpose

A hand-written JSON document with a literal surrogate-pair escape in a
key is refused on decrypt with a message that names the path. The
document is well-formed and sops reads it; this library refuses it
because the order-preserving reparse disagrees with the value parser
about what the key is. The cost is a one-time re-encode (UTF-8 bytes
for the same codepoint, what sops itself writes) -- measured against
sops 3.13.3, sops -e on a file with literal `😀` writes the
UTF-8 bytes on the next round, and the resulting file decrypts here at
exit 0.

### Test

`t/76-json-surrogate-pair-key-meets-its-decision.t` pins the four
pieces of the measurement, in four sections:

1. **Per-decoder shapes**: the `chr(0x1F600)` (one codepoint) read
   `Cpanel::JSON::XS` returns for the literal escape, and the
   `chr(0xD83D).chr(0xDE00)` (two surrogates) read `YAML::PP` returns
   for the same six bytes.
2. **Fail-loud direction**: a hand-rolled walk over the YAML::PP-
   ordered tree against the Cpanel tree croaks with `"present in the
   document but not in the parsed tree"` and names the leaf's path.
3. **Our own emitters do not write the divergent form**:
   `File::SOPS->encrypt` with a U+1F600 key writes UTF-8 bytes for the
   key (asserted via `unlike` against the surrogate-pair escape regex).
4. **sops 3.13.3 reference answer**, conditional on a binary:
   `sops -e` on a hand-written file with a literal surrogate-pair
   escape in a key writes UTF-8 bytes, `sops -d` reads them back, exit
   0 in both directions, the escape form does NOT appear in the
   encrypted output.

Sections 1-3 run with no binary; section 4 skips without one.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23: the three
tables above, and `t/76` against the same binary. The full suite
after this ADR is **1400/1400 across 77 files** (one file added:
`t/76-json-surrogate-pair-key-meets-its-decision.t`, 16 tests; no
existing test changed), with `t/04-interop.t` and the other interop
sections executed rather than skipped. `prove -lr t/` runs at 77
files, 1400 tests, all PASS.

Lane: format. The decision is the format lane's because the reparse
is asked of the format handler (ADR 0036), and the divergent shape is
in the JSON document text that handler reads -- but the change is
zero-line. The code comment that already names the divergence is the
canonical record; this ADR writes the measurement behind it and the
rejected alternatives that would have undone the limit.
