# ADR 0024 — A sops comment leaf is refused, not read as a value

- Status: accepted
- Date: 2026-08-21
- Tags: yaml, mac, wire-format, guards, interop
- Resolves k108
- Splits off the read half of k76; the write half (preserving comments)
  stays there
- Depends on ADR 0008 (a leaf the emitter cannot write as what the digest covers
  is refused — this is the same rule for a leaf the emitter cannot write at all)
  and ADR 0001 (the decrypt-side digest takes its order from a second,
  order-preserving parse of the same text, which is why the two trees have to
  agree structurally)

## Context

sops attaches a YAML comment to the node that **follows** it. Where that node is
a mapping entry the comment stays a real YAML comment on a line of its own:

```yaml
#ENC[AES256_GCM,data:…,type:comment]
database:
    #ENC[AES256_GCM,data:…,type:comment]
    host: ENC[AES256_GCM,data:…,type:str]
```

`YAML::XS` discards those before this distribution ever sees them, and sops does
not hash them either, so both implementations agree by accident and the document
reads correctly. That is measured, not assumed: the fixture above
(`t2.enc.yaml`, four comments across four positions) decrypts today to exactly
`{database => {host => 'localhost', port => 5432}, api => {key => 'secret'}}`.

Where the following node is a **sequence entry**, sops has nowhere to put a
comment line and writes the comment as a sequence entry of its own:

```yaml
list:
    - ENC[AES256_GCM,data:…,type:comment]
    - ENC[AES256_GCM,data:…,type:str]
```

`YAML::XS` keeps that, because it is not a comment any more — it is an element.
Three lines of plaintext are enough to produce it:

```yaml
list:
  # only a sequence comment
  - one
```

Measured against sops 3.13.3, on that document after `sops -e`:

| | result |
|---|---|
| `sops -d` | exit 0, the document comes back with its comment |
| `File::SOPS->decrypt` | dies, `MAC verification failed: the digest over 2 leaf values in document order …` |
| `File::SOPS->decrypt(ignore_mac => 1)` | `{ list => [' only a sequence comment', 'one'] }` |

The MAC failure is the mild symptom. The `ignore_mac` line is the defect: the
comment text is a silent extra string in the array, and it is not marked as
anything. A `decrypt` + `encrypt` cycle makes it **permanent**, and every party
involved reports success — measured, `sops -d` on the re-encrypted document:

```yaml
list:
    - ' only a sequence comment'
    - one
```

exit 0, no warning from sops and none from this library. A comment has become a
value in a secrets file.

The flow-sequence case is the same defect on a document that reads worse. sops
rewrites `flow: [1, 2]  # after a flow seq` into a block sequence with the
comment as element 0, so a list of integers gains a leading string: sops reads
`[1, 2]`, `File::SOPS` reads `[' after a flow seq', 1, 2]`.

### Why nobody had seen it

The source comment on the `type:comment` branch of the decrypt type ladder in
`File::SOPS::Encrypted` said so:

> a YAML comment sops writes as `#ENC[...]` on its own line. YAML::XS drops
> comments, so File::SOPS never meets one through a document; this is here for a
> direct caller.

The first half is true of the mapping position and false of the sequence
position, and the sentence made the second half look settled. `t/04-interop.t`
runs (32 tests against sops 3.13.3) and contains no document with a comment in
it, so nothing contradicted the comment either.

### Comments are not in the MAC

This is the measurement the fix turns on, and k76's body asserted the
opposite ("steht IM DIGEST"). Four independent measurements against sops 3.13.3:

1. **Delete a comment leaf** from an encrypted file, then `sops -d`: exit 0, in
   YAML mapping position, YAML sequence position, INI and ENV. Control, same
   method, deleting a real `type:str` value: exit 51 with a MAC mismatch in all
   of them.
2. **Three documents, identical values, different comments** (one with
   `# alpha comment`, one with another, one with none): the decrypted MAC
   plaintext is byte-identical in all three.
3. **Swap two comment ciphertexts**: `sops -d` exit 0. It warns
   `Found possibly unencrypted comment in file` and leaves the text alone — a
   comment that will not decrypt is not fatal to sops.
4. **Relabel a `type:str` mapping value to `type:comment`** in a sops-written
   file: `sops -d` exits 51 with a MAC mismatch, because relabelling it removed
   it from what sops digests. The exclusion is by type, not by position.

So the digest sops computes covers the values and nothing else, and a comment
leaf has to be kept **out** of ours.

### What a correct read would take, and where it lives

Keeping the leaf out of our digest is not enough on its own: the leaf also has
to leave the tree, or the caller still gets the phantom element and still writes
it back. Removing it from the tree at parse time is one line of walk — and it
breaks, because ADR 0001's decrypt-side digest takes document order from a
second parse of the same raw text. Measured with the parse-time drop in place
and nothing else:

```
list: the document has 2 entries here but the parsed tree has 1
```

`_document_leaves` compares the two trees entry by entry and refuses a
structural disagreement, correctly. With the same drop applied to **both** trees
— `Format::YAML::parse` and `File::SOPS::_parse_in_document_order` — the fixture
verifies its MAC and returns `{ list => ['one'] }`. That is measured too, and it
is what makes the following decision a choice rather than a limitation: reading
these documents is achievable, in about six lines, across two files.

## Decision

**A `type:comment` leaf found in a parsed YAML tree is refused, naming its path.
`File::SOPS::Format::YAML::parse` croaks rather than handing such a tree on.**

- The predicate is the **`type:` label on the wire**, not the position and not
  the text. `File::SOPS::Encrypted->encrypted_type` is a new third sharer of the
  one anchored `$ENC_REGEX` that `is_encrypted` and `parse` already share, and
  it reads the label without decoding any base64 — so a comment leaf whose
  ciphertext is damaged is still identified as a comment, which is the case
  measurement 3 above says sops tolerates.
- **Every position, not only sequences.** A comment leaf is never a value,
  wherever it sits. The rule costs nothing in reach: the mapping position never
  produces one (sops writes a real comment line, `YAML::XS` drops it), and a
  comment leaf in a mapping *value* slot is a document sops itself exits 51 on
  (measurement 4). Sequence position is the only shape that actually occurs, and
  a position-specific guard would only be a narrower statement of the same rule.
- The refusal is at **parse**, so it covers every path that reads a document —
  `decrypt`, `decrypt_file`, `extract`, `rotate`, `edit` — including
  `ignore_mac => 1`. That flag means "decrypted but not authenticated"; it has
  never meant "hand back a tree the document does not contain", and the
  `ignore_mac` path is the one that produces the corruption.
- `encrypt` and `encrypt_file` are untouched. A plaintext YAML file has no
  `ENC[…]` strings in it, so the guard cannot fire on the encrypt side.
- The message names the **path** (`flow:0`, in the shape ADR 0008's guards and
  the MAC walk already use), says what the leaf is, and says what to do about
  it. It never decrypts the comment and never prints it: an error goes into bug
  reports.

## Consequences

- **A document sops reads, this distribution now refuses.** That is the price,
  it is real, and it is stated in the POD and in the message rather than left to
  be discovered. What the caller loses is a document that, before this change,
  they could not read correctly anyway: strict mode already refused it (with a
  message that blamed tampering), and lax mode answered with a tree that had a
  value in it the file does not contain.
- **The MAC error for these documents becomes a precise one.** `MAC verification
  failed … the document has been altered since it was written` was a wrong
  accusation: nothing had been altered, and no amount of looking at the file
  would have shown what to fix.
- The corruption path is closed at its source. There is no longer any way to get
  a comment into a value through this library's public API.
- Documents **already corrupted** by an earlier `decrypt`+`encrypt` cycle are
  unaffected and stay readable. Their comment is a genuine `type:str` value now;
  nothing in the file distinguishes it from a value the author wrote, so nothing
  here can or should refuse it. Repairing one means deleting the element by hand
  from the decrypted document. This guard prevents new ones; it cannot detect
  old ones.
- Mapping-position comments keep behaving exactly as they do today: silently
  dropped on read (by `YAML::XS`, before this guard runs) and absent from any
  document this library writes back. That is unchanged, it is k76's
  subject, and it is not made better or worse here.

### What changes for existing callers

Nothing for any document without a comment in sequence position — which is every
document this library has ever written, and every sops document whose comments
all sit above mapping keys. A caller who reads a sops-written YAML with a comment
inside a list gets a croak naming the path where they previously got either a
MAC failure or, with `ignore_mac => 1`, a wrong value. No document that decrypted
**correctly** before decrypts differently now.

## Rejected alternatives

**Drop the comment leaf from the tree at parse time (and from the ordered
reparse, so the two agree).** Measured to work: the minimal fixture verifies its
MAC and returns `{ list => ['one'] }`, which is exactly what sops reads. It is
the most useful answer for reading and it was very close to being this decision.
It is rejected because it is only an answer for reading. Every write path in
this distribution — `rotate`, `edit`, `encrypt_in_place`, `decrypt_file` +
`encrypt_file` — would then emit the document **without** the comments, silently,
with no diagnostic anywhere. That is the same class of defect as the one being
fixed, one notch quieter: a loud wrong read traded for a silent lossy write. The
usual defence is that this distribution already destroys mapping-position
comments on every write, so nothing new would be lost — but that is an argument
that an existing gap should be widened, and the gap is what k76 exists to
close. Refusing now and preserving later is monotone; dropping now would have to
be reversed by the same ticket that fixes it.

**Keep the leaf in the tree and give it empty digest bytes.** In-boundary and
half-tempting: replacing the `ENC[…,type:comment]` string with `''` at parse
keeps both trees the same length, and `value_to_bytes('')` contributes nothing to
the digest, so the MAC verifies against sops. It fixes the digest and leaves the
corruption completely intact — the caller still gets a phantom element, and a
re-encrypt still writes `- ''` into the list where a comment used to be. It
makes the file verify while still being wrong, which is the failure mode this
distribution's ADRs exist to avoid.

**Make `decrypt_bytes` or `decrypt_value` return an empty string for
`type:comment`.** Excludes the leaf from the digest from inside the wire layer,
without touching the MAC walk. It is a lie at the one boundary that must not
lie: `decrypt_bytes` is defined as the authenticated plaintext, the MAC walk
hashes exactly what it returns, and a direct caller decrypting a comment value
would silently get nothing back. It also still leaves the phantom element in the
tree.

**Preserve the comment through the tree and restore it on emit** — the lossless
answer, and the right end state. It needs a place in the tree model for a leaf
that is not a value, an emitter on each side that can put it back on the node it
belonged to, and the digest exclusion above. That is k76's data-model
change, it reaches both format handlers and both MAC walks, and it is a great
deal more than the read defect k108 describes. Filed there rather than
folded in, and this decision is deliberately shaped so that it becomes a
straight removal of the guard: refuse → preserve, with nothing to undo in
between.

**Add a flag to read such a document anyway.** The natural shape is an argument
on `decrypt`, which is the public API's surface and not this lane's. It is also
premature: it would be an option to receive a tree containing a value the file
does not contain, which is not something a caller can currently be told how to
use safely. If it turns out to be wanted, it belongs on top of k76's
preservation, where the flag would select what to do with a comment rather than
whether to invent a value.
