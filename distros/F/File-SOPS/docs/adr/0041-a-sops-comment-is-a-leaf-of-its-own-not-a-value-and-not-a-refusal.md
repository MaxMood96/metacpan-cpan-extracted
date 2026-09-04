# ADR 0041 — A sops comment is a leaf of its own: not a value, and not a refusal

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`, with the
  mechanism probed in a **scratch copy of `lib/`** and nothing in the repository
  changed until the tables existed.
- Date: 2026-08-21
- Tags: yaml, json, wire-format, mac, data-model, interop, guards
- Resolves k76 for the shape that occurs. Removes the parse-time guard
  ADR 0024 installed and replaces it with two narrower ones, on the write side
- **Supersedes the decision of ADR 0024** — "a `type:comment` leaf found in a
  parsed YAML tree is refused" — which that ADR wrote as a deliberate
  intermediate step and shaped so that this would be a straight removal. What
  survives from it is every measurement, and the refusal for the one position
  no SOPS document has
- Depends on ADR 0002 (the type comes from the scalar, and a comment now has a
  scalar of its own to come from), ADR 0003 (the text is encoded
  unconditionally, like every other string), ADR 0001 (the two trees have to
  agree structurally, and a preserved comment element is how they do) and
  ADR 0008 (a leaf the emitter cannot write is refused — which is now the whole
  of what is refused)
- **Moves wire bytes**: a document this library writes can now contain a
  `type:comment` leaf, and the MAC it computes no longer covers one

## Context

sops attaches a comment to the node that **follows** it. Where that node is a
mapping entry, the comment stays a comment line (`#ENC[…,type:comment]`), which
`YAML::XS` discards before this distribution sees a tree. Where the following
node is a **sequence entry** there is no comment line to write, so sops emits
the comment as a sequence entry of its own:

```yaml
list:
    - ENC[AES256_GCM,…,type:comment]
    - ENC[AES256_GCM,…,type:str]
```

ADR 0024 refused such a document, because reading the leaf as a value put a
string in the caller's list that the file does not contain, and a
`decrypt` + `encrypt` cycle made it permanent with every party reporting
success. The refusal closed the corruption and cost the ability to read a
document `sops -d` reads at exit 0. k36 and k37 then reported that the
cost is not payable at all for ENV and INI, where a comment is the ordinary
case rather than the exception.

k76's body states that a comment leaf is **in the digest**. It is not, and
that premise is what made the ticket look like a data-model change of its own.
Four measurements at k108 said so; a fifth, sixth and seventh are below.

## What was measured

All rows: sops 3.13.3, `/tmp/sops`, one age recipient, YAML unless the row says
otherwise.

### 1. Where a comment leaf can sit — one shape, not nine

Six comment positions in one document, `sops -e`:

| plaintext position | what sops wrote |
|---|---|
| above the first entry of a block sequence | sequence **element** 0 |
| after the last entry of a block sequence (attached to nothing) | sequence **element**, last |
| trailing on the same line as a sequence entry | sequence **element**, before that entry |
| trailing after a flow sequence | flow sequence becomes a block sequence, comment is **element** 0 |
| above a mapping key | `#ENC[…,type:comment]` **comment line** |
| first line of the file | `#ENC[…,type:comment]` **comment line** |

Two further rows decide the size of the whole ticket:

| document | what sops wrote |
|---|---|
| the same file with `--output-type json` | the **sequence** comments survive as JSON string elements carrying `type:comment`; the mapping-position ones are **dropped** |
| a comment inside a subtree the encryption rules exclude (`x_unencrypted`) | a plain `# comment` **line**, not encrypted and not an element |

So the only shape any sops document carries is **a comment as a sequence
element**, in both wire formats. A sequence element is not a leaf without a
key: it **is** an entry, and the tree model already has a place for it. The
key-less leaf k76 was filed for does not occur, and nothing needs to be
invented for it.

### 2. The AAD is the ordinary path

Every comment leaf in the fixture decrypts under the path of the node it is
attached to, colon-joined with a trailing colon and **no index** — `list:`,
`flow:`, `tail:` — which is the same AAD rule as for every other element
(`_path_to_aad`, unchanged). The mapping-position comment authenticates under
the mapping's path too (`map:`), for what it is worth here.

### 3. Excluding comments reproduces sops's own digest, byte for byte

The digest, computed here in document order from the leaves of a
**sops-written** document, against the plaintext of that document's own
`sops_mac`:

| document | comments **in** the digest | comments **out** |
|---|---|---|
| six comments, five positions | `B40539D2CD54EA9F…`, differs | `461FE3EA428F023F…`, **matches sops** |
| k108's three-line reproducer | `F327F66D8A39C28F…`, differs | `05F70341078ACF6A…`, **matches sops** |
| `--mac-only-encrypted` | differs | **matches sops** |
| a comment beside an `_unencrypted` subtree | differs | **matches sops** |

Four documents, two MAC modes: the exclusion is by **type**, in both modes, and
it is not a choice — it is what Go computes.

### 4. sops itself does not preserve a comment's place, only its attachment

`sops -e` then `sops -d` on the fixture: the indentation changes, a trailing
comment moves onto its own line above the value it followed, and a flow sequence
becomes a block sequence. What survives is which node the comment is attached
to. That is exactly the information a preserved sequence element carries, so
holding the element at its index is the whole of what "preserving" can mean
here.

### 5. The round trip, with the mechanism in place

`sops -e` → `File::SOPS->decrypt` → `File::SOPS->encrypt` → `sops -d`, the
six-comment fixture:

```
exit 0, MAC verified by sops, all five sequence comments back on their nodes
```

Diffed against **sops's own** `-e`/`-d` round trip of the same file, the only
difference is the mapping-position comment, which `YAML::XS` dropped at parse
and which sops itself drops when it writes JSON. The JSON fixture round-trips
the same way, `type:comment` on the wire and `sops -d` at exit 0. A comment
this library writes from scratch, and a document `rotate` re-keys, both come
back out of `sops -d` at exit 0 with the comment restored as a comment.

### 6. The JSON side was never covered, and is corrupt today

ADR 0024's guard lives in `Format::YAML::parse`. `Format::JSON` has none, and
sops writes `type:comment` leaves into JSON (row 1 above). Measured at HEAD on
such a document: `decrypt` dies with `MAC verification failed`, and
`decrypt(ignore_mac => 1)` returns `{ list => [' a comment', 'one'] }` — the
phantom element k108 reports, still open in the other format. It is closed
here by the representation rather than by a second guard.

### 7. A comment leaf in a mapping VALUE slot is corruption, and now it is measured

ADR 0024 reported that relabelling a mapping value to `type:comment` makes
`sops -d` exit 51. That is a document whose *stored* digest covers the value. A
document written the way this change writes one — the comment out of the digest
— is a different measurement, and it was taken here with the write-side guard
lifted in the scratch copy:

```yaml
k: ENC[AES256_GCM,…,type:comment]
```

`sops -d`, exit **0**:

```yaml
k:
    value: ' a mapping value comment'
    inline: false
```

Go's `yaml.Comment` struct, dumped into the document as a mapping. Silent, at
exit 0, in a file this library would have produced. That is why the write-side
refusal below is not a formality.

### 8. An empty comment is not a comment

`#` alone above a sequence entry: sops writes an **unencrypted empty string
element** (`- ""`) and no comment leaf at all, and reads it back as `- ""`. So
`type:comment` never carries an empty plaintext, and there is nothing here to
reproduce.

## Decision

**A `type:comment` leaf is a leaf of its own kind. It gets a Perl
representation, it is kept where the document keeps it, and it is excluded from
the digest. It is refused only where no SOPS document can carry it.**

Five parts.

1. **`File::SOPS::Comment` is the Perl representation** of the wire type — a
   blessed leaf holding the comment's text, and nothing else. It is the same
   move `type:bool` already makes with `JSON::PP::Boolean`: a wire type that is
   not a string gets a Perl value that cannot be mistaken for one. It lives in
   `File/SOPS/Encrypted.pm` beside the ladder that produces it; a file of its
   own is a move, not a rename, and is left for the day a second such class
   exists.

2. **One ladder, one conversion, as before.**
   `File::SOPS::Encrypted->detect_type` gains a rung — a `File::SOPS::Comment`
   is `comment` — and `value_to_bytes` writes its text as UTF-8 bytes,
   verbatim, exactly as it writes a string (ADR 0003; the flag is not consulted
   here either). `_deserialize_value` builds one for `type:comment`, so
   `decrypt_value` answers with the object and `_decrypt_tree` needs no comment
   knowledge at all. Nothing pattern-matches text and nothing reads a position
   to decide a type (ADR 0002).

3. **A comment leaf is not a leaf value, so the digest does not cover it.**
   One predicate, `File::SOPS::Encrypted->is_comment`, answers for both shapes
   the walks meet — the `File::SOPS::Comment` on the encrypt side and the
   `ENC[…,type:comment]` string on the decrypt side, the latter read from the
   one anchored `$ENC_REGEX` through `encrypted_type`, without decoding
   anything. `File::SOPS::_digested_leaves` applies it to the collected leaves
   in both directions, so `_compute_mac`'s representability sweep, `_mac_digest`
   and the leaf count in the MAC error message all speak about the same list.

4. **The place in the tree is the place the document uses: a sequence element.**
   Nothing is added to the tree model. `_decrypt_tree` leaves the element where
   it is and `_encrypt_tree` writes it back into the same index, which is what
   makes ADR 0001's two trees agree structurally without either of them being
   taught anything: the element is in the document text, in the
   order-preserving reparse and in the parsed tree alike.

5. **What is refused is what cannot be written, and it is refused on the write
   side** — ADR 0008's rule, and now the whole of the refusal.
   `Format::YAML::parse`'s guard is **removed**; a comment leaf no longer stops
   a read in any position, in either format. In its place:

   - `_encrypt_tree` refuses a `File::SOPS::Comment` in a **mapping value**
     slot, naming the path. Measurement 7 is why: sops reads that document at
     exit 0 and writes a Go struct into it.
   - `Format::YAML`'s emitter refuses one it is handed as a value to write —
     the plaintext emitters (`decrypt_file`, `edit`) and an encrypted document's
     unencrypted slot — naming the path and saying that `YAML::XS` cannot write
     a comment line. That guard already fired for every blessed leaf; what
     changes is that a comment gets its own message instead of the
     `!!perl/`-tagged-structure one, which is true but says nothing useful here.

The predicate is the `type:` label and the class, never the position and never
the text.

## Consequences

- **A document sops reads, this distribution reads again.** Every read path —
  `decrypt`, `decrypt_file`, `extract`, `rotate`, `edit`, `ignore_mac => 1`
  included — now reads a document with a comment in a sequence, in YAML and in
  JSON. That is the cost ADR 0024 named and paid; it is repaid.
- **A tree handed back by `decrypt` can contain a `File::SOPS::Comment`.** It is
  a blessed leaf, which is new for callers who walk the tree assuming scalars.
  It has **no overloaded stringification**, deliberately: an object that compares
  equal to a string is exactly how a comment became a value in the first place,
  and `detect_type` would then have two ways to answer for the same leaf.
- **The MAC this library computes changes for documents with comments in
  them** — from a digest sops does not compute to the one it does. No document
  without a comment leaf is affected, which is every document this library has
  ever written.
- **k108's defect is closed in JSON too**, where the guard never reached.
- **`decrypt_value` returns an object for `type:comment`** where it returned the
  text. Reachable only by a direct caller, since no read path produced one
  before this change.
- **`decrypt_file` and `edit` still refuse a YAML document with a comment
  leaf**, now from the emitter and with a message that says why: the plaintext
  the editor would see cannot carry the comment, and re-reading such a plaintext
  would drop it (`YAML::XS` discards comment lines), so writing one would be a
  silent loss on the way back in. That is the ENV/INI-shaped half of k76
  that stays open — those handlers **can** write and re-read a comment line, and
  this decision is what gives them the leaf to write.
- **Mapping-position comments are unchanged**: dropped by `YAML::XS` on the way
  in, absent from anything written here, and dropped by sops itself in JSON.
  Not made better or worse, and now the only part of k76 still open.
- **The JSON emitter's refusal of a `File::SOPS::Comment` is Cpanel's generic
  one**, not a targeted message. Recorded rather than fixed here; the JSON
  handler is another lane's file.
- A comment whose ciphertext is **damaged** is refused at decrypt, naming the
  path, where sops warns and leaves the text. That is unchanged in effect — it
  was refused at parse before — and is the one place this distribution is
  stricter than the reference about a comment.

### What changes for existing callers

A caller reading a document with a comment in a sequence gets a tree where they
got a croak (0.003) or a phantom string (before it). A caller writing one back
gets it written where they could not write it at all. A caller who passes
`File::SOPS::Comment` objects of their own gets `type:comment` leaves, or a
refusal naming the path where the document cannot carry one. Nothing else moves:
a document with no comment leaf is parsed, digested, written and read exactly as
before.

## Rejected alternatives

**Keep refusing (ADR 0024, unchanged).** Correct for the read defect and
unpayable for ENV and INI, where a comment is the ordinary case (k36,
k37) — and, as measurement 6 shows, incomplete even for YAML's own defect,
which reaches JSON through `--output-type json`.

**Drop the comment leaf from both trees at parse.** ADR 0024 measured this to
work and rejected it, and the rejection stands for the same reason: every write
path would then emit the document without its comments, silently. Preservation
is what makes the drop unnecessary rather than merely quiet.

**Represent the comment as a plain string with a marker prefix.** It keeps the
tree free of objects at the price of deciding a leaf's kind by looking at its
text, which is the defect class ADR 0002 exists to keep out — and a value whose
text happens to match the marker becomes a comment.

**Give `File::SOPS::Comment` an overloaded `""`.** Convenient in tests, and it
reintroduces the failure being fixed: a comment that compares equal to a string
slips through every `eq` in the distribution, and `detect_type`'s `blessed`
branch and `_sv_kind` would disagree about it.

**Keep the `ENC[…]` string in the decrypted tree.** No new class, and the
comment survives a `decrypt` + `encrypt` cycle unchanged — but only while the
data key does. `rotate` would write a leaf encrypted under the **old** key into
a document re-keyed with a new one, which sops tolerates with a warning and
which nothing can read; and `decrypt_file` would write ciphertext into a
plaintext file.

**Return an empty string for `type:comment` from `decrypt_bytes`.** ADR 0024
rejected it and it is still a lie at the boundary the MAC walk trusts. The
digest exclusion belongs where the leaves are collected, which is where it is.

**Refuse the mapping-value comment leaf at parse, as ADR 0024 does.** It would
name the path a little earlier. It also puts the rule in one format handler
while the same document is read by the other without it, and the rule is not a
format's rule — no store in sops writes that shape. It lives in `_decrypt_tree`'s
twin on the write side, once, for both formats.

**Restore mapping-position comments by post-processing the emitted YAML.** The
lossless answer for the last open position, and the text surgery ADR 0019
rejected: an arbitrary key path at arbitrary nesting in a finished document
about to go on the wire, where a mis-hit writes a corrupt file. ADR 0028's
conditions for allowing such surgery — read path, one fixed token, reconciled
against a second parser before the result is used — are met by none of it.
