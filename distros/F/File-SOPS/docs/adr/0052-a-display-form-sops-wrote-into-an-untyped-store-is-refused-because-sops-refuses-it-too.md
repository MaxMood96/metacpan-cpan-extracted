# ADR 0052 — A display form sops wrote into an untyped store is refused, because sops refuses it too

- Status: accepted
- Date: 2026-08-22
- Tags: env, ini, mac, types, interop, guards
- Closes k124, k125 and k137 — the three tickets ADR 0035
  decided the **write** half of, deferred to k36 and k37, and left
  open on a question neither ticket body asked
- Depends on ADR 0035 (an untyped store's unencrypted leaf is written as the
  bytes the digest covers — the write half, now implemented), ADR 0008 (a leaf
  the emitter cannot write as what the digest covers), ADR 0038 (the
  discriminator), ADR 0049 (a leaf is decrypted because the rule says so)
- Uses ADR 0038's discriminator, and answers it **no** for the first time on a
  whole class rather than on a single spelling

## Context

k124, k125 and k137 are one defect in three values. In the **unencrypted**
slot of a dotenv or ini document — a slot with no type label, whose reader hands
the digest the literal text of the line — sops writes a Go *display* form while
its own MAC covers the *wire* form:

| value | sops writes | `sops_mac` covers | ticket |
|---|---|---|---|
| `true` / `false` | `true` / `false` | `True` / `False` | k124 |
| `null` | `<nil>` | *(empty)* | k125 |
| `1.0`, `2.0`, `0.0`, `-0.0`, `018` | `1.0`, `2.0`, `0.0`, `-0.0`, `18.0` | `1`, `2`, `0`, `-0`, `18` | k137 |
| `1e2`, `1e20` | `100.0`, `1E+20` | `100`, `100000000000000000000` | k137 |

Every one of those is a file sops wrote at exit 0 and then refuses to read.

All three ticket bodies end with the same line — *"bleibt offen bis k36/k37 die
Regel im Emitter umsetzen"*. **Both handlers now exist** (k36 in 89d01ee,
k37 in 610ec6c) and both implement ADR 0035's rule, so the sentence the
tickets were parked on has come true. What none of the three bodies asks is the
question that was actually still open, and it is the expensive one in this
distribution:

> **Can we read what sops writes?**

The write half is our emitter and we control it. The read half is a file
somebody else produced, and k102, k105 and k108 are all the same shape — a
document sops writes and this library refuses. That class is this project's
most expensive defect type, so the tickets were re-measured against the read
direction before being closed.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient per document, measured 2026-08-22
against the working tree.

### The write half, verified rather than assumed

`File::SOPS->encrypt(format => 'env' | 'ini', unencrypted_suffix =>
'_unencrypted')` over a boolean, an `undef`, `1.0`, `1e20`, `-0.0`, `42` and
`'hello'` writes

```
b_unencrypted=True          bf_unencrypted=False        n_unencrypted=
f_unencrypted=1             fe_unencrypted=100000000000000000000
fz_unencrypted=-0           i_unencrypted=42            s_unencrypted=hello
```

and the ini handler writes the same values in `key = value` shape. **`sops -d`
reads both at exit 0**, returning every value as a string. ADR 0035's rule is
implemented, in both handlers, and it works. Nothing in this ADR changes it.

### The read half — 27 scalars × 2 formats

Each scalar in its own document, in both slots (`v` encrypted, `v_unencrypted`
plain), written by `sops -e --input-type yaml --output-type dotenv|ini`, then
handed to `sops -d` and to `File::SOPS->decrypt`:

| scalars | sops writes | `sops -d` | `File::SOPS->decrypt` |
|---|---|---|---|
| `true`, `false` | `true`, `false` | **51** | **refused** — MAC |
| `null`, `~` | `<nil>` | **25** | **refused** — the rule says encrypted, the file holds a plain value |
| `1.0` `2.0` `100.0` `0.0` `-0.0` `018` `1e2` `1.0e2` `1e20` | `1.0` … `1E+20` | **51** | **refused** — MAC |
| `1.50` `0.5` `.5` `3.14` `1.23456789012345678` | `1.5` `0.5` `0.5` `3.14` `1.2345678901234567` | 0 | **read**, values equal |
| `42` `007` `0` `-7` | `42` `7` `0` `-7` | 0 | **read**, values equal |
| `"hello"` `""` `"True"` `"<nil>"` | `hello` … `<nil>` | 0 | **read**, values equal |
| `2026-01-01T00:00:00Z` | the timestamp | 0 | **read** |

**54 documents, zero divergent rows.** There is no scalar for which sops reads
its own file and this library does not, and none for which we read a file sops
rejects. The read half already tracks the reference implementation exactly.

Applied to ADR 0038's discriminator — *does sops read back what sops wrote?* —
the broken rows answer **no**, and that is the branch where refusing is right.
This is **not** k102/k105/k108's class. It only looked like it because the
tickets were written from the write side.

### The finding that decides the shape of the fix

The obvious repair — *recognise `<nil>` on read and hand back an `undef`*, and
its two siblings for `true` and `1.0` — is not merely unnecessary. **It is not
implementable, because the text is ambiguous and only the digest disambiguates
it.**

For each broken value there is a **string** whose text sops writes to the same
bytes, and that document sops reads at exit 0:

| the typed value | the string | line sops writes for both | `sops -d` typed | `sops -d` string |
|---|---|---|---|---|
| `true` | `"true"` | `v_unencrypted=true` | 51 | **0** |
| `false` | `"false"` | `v_unencrypted=false` | 51 | **0** |
| `null` | `"<nil>"` | `v_unencrypted=<nil>` | 25 / 51 | **0** |
| `1.0` | `"1.0"` | `v_unencrypted=1.0` | 51 | **0** |
| `1e20` | `"1E+20"` | `v_unencrypted=1E+20` | 51 | **0** |
| `-0.0` | `"-0.0"` | `v_unencrypted=-0.0` | 51 | **0** |

Byte-identical lines, measured in both formats. The two documents differ *only*
in the stored digest: for the string the digest covers the text as written, so
the file verifies; for the typed value it covers `True` / the empty string /
`1`, so it does not. A reader looking at the line cannot tell which document it
is holding, and the one signal that could tell it — the MAC — is the very thing
that has already failed.

So mapping `<nil>` back to `undef` on read would silently corrupt the string
`"<nil>"`, a value sops itself writes and reads at exit 0, in order to rescue a
file sops cannot read at all. That trade is backwards, and it is the trade
k125's body invites by naming the byte sequence.

### What `ignore_mac => 1` already gives

For the MAC-failing rows the existing rescue works and returns the truthful
answer: `{ v_unencrypted => 'true' }`, `{ v_unencrypted => '<nil>' }`,
`{ v_unencrypted => '1.0' }` — the literal text sops wrote, unauthenticated and
documented as such. That is exactly what sops's own reader would have produced
had its MAC matched, so a caller who has to open one of these files gets the
same value sops would have handed them, with the authentication caveat stated.

## Decision

**All three tickets are closed as done, and the read half stays exactly as it
is. No code changes.**

1. **The write half is ADR 0035's and is implemented.** k124, k125 and
   k137 asked for an emitter rule; both handlers apply it; sops reads the
   result at exit 0 in both formats. Verified above rather than inherited from
   the tickets.

2. **A document whose unencrypted slot holds a display form is refused, and the
   refusal is correct.** sops refuses the same file, at exit 51 for a boolean
   and a float and at exit 25 for a null. Under ADR 0038's discriminator this
   is the "sops does not read back what it wrote" branch, where refusing is the
   right answer and passing the value through would mean inventing a reading
   the document does not support.

3. **The display form is never repaired on read, in either store.** Not for
   `<nil>`, not for `true`, not for `1.0`. The text is ambiguous with a string
   both implementations read at exit 0, so any text-directed repair trades a
   working value for a broken one. This is recorded as a decision rather than
   left implicit precisely because the byte sequence is named in k125 and
   invites the fix.

4. **The null in the encrypted slot keeps ADR 0049's structural refusal.** The
   document's own rule says the leaf is encrypted and the file holds a plain
   `<nil>`, so it is refused for that reason and not by matching the text —
   the same reasoning as (3), and it already lands there for free.

5. **`ignore_mac => 1` remains the only way in, and its contract is unchanged.**
   Decrypted, not authenticated, returning the literal text.

## Consequences

- **No wire byte moves, no digest moves, no message changes.** This ADR adds
  one file under `docs/` and one under `t/`.
- **The three tickets close on evidence, not on a deferral.** What they asked
  for exists; what they did not ask — the read direction — is measured and
  correct in 54 of 54 documents.
- **The read half is pinned for the first time in the ini store.**
  `t/59-env-format-handler.t` already pinned three of the six broken forms for
  dotenv; nothing pinned any of them for ini, and nothing anywhere pinned the
  ambiguity in (3). A future attempt at the "obvious" fix now goes red.
- **A diagnostic gap is recorded and handed over, not closed here.** For the
  MAC-failing rows the message says the document *"has been altered since it
  was written, or was written by something that computes the digest
  differently"*. Both halves are true and neither is the useful sentence, which
  is *sops wrote this file and cannot read it either*. A caller whose whole
  reason for using this distribution is compatibility will read a bare MAC
  failure as our defect. Improving it means touching `_verify_mac` in
  `lib/File/SOPS.pm`, which is the API lane's file; filed as its own ticket
  with the measured detection rule rather than reached across for.

### What changes for existing callers

Nothing. No public method changes behaviour, no document that reads today stops
reading, and no document that is refused today starts being accepted.

## Rejected alternatives

**Map the display form back on read** — `<nil>` to `undef`, `true` to a
boolean, `1.0` to `1`. The fix k125's body points at by naming the bytes.
Refuted by measurement, not by taste: the identical line is a legitimate string
in a document sops reads at exit 0, so the mapping corrupts a working value to
rescue an unreadable one. It would also be a second value→bytes conversion, in
the reverse direction, in a layer whose single source of truth is the property
the distribution is built on.

**Recompute the MAC over the display forms so these files verify.** Our files
would then verify against themselves and fail against sops, whose digest covers
`True` and the empty string in every measured row. This is the exact
self-consistency failure the briefing names, and ADR 0035 already rejected its
write-side twin.

**Accept the file with a warning instead of refusing.** Tempting because
`ignore_mac` already exists and the value is recoverable. Rejected because the
MAC is the only authentication the format has: downgrading a verification
failure to a warning for a *class of text* means an attacker who can edit an
unencrypted line into one of six shapes gets the document accepted. The caller
who knowingly wants the unauthenticated read already has `ignore_mac => 1`, and
it returns the same bytes.

**Refuse these documents earlier, with a message about the display form,
instead of letting the MAC fail.** A parser-level guard that spots
`v_unencrypted=<nil>` would produce a better message for the null case — and
would fire on the string `"<nil>"` too, refusing a document sops reads at
exit 0. Same defect as the first alternative, one layer up. The improvement
belongs in the MAC failure path, where the digest has already answered, which
is the handover in Consequences.

**Close the tickets without measuring the read half**, on the strength of
ADR 0035 and the two handler commits. It is what the ticket bodies invite, and
it would have shipped three "done" tickets whose expensive half nobody looked
at. The 54-document ladder cost one script and turned an assumption into the
one table this ADR is built on.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with Crypt::Age, on 2026-08-22,
one document per scalar, every age keypair generated for the run. The fixtures
are invented values, not anyone's secrets.
`t/67-a-display-form-sops-wrote-is-refused-in-both-stores.t` pins the read half
and the ambiguity, and is interop-gated: without a binary it skips, which is the
honest outcome for an ADR whose content is what the reference implementation
does.

**A harness artifact worth recording, because it cost time and will cost it
again:** `sops -d --input-type dotenv` on a file named `x.dotenv` exits 4 with
`error emitting binary store: no binary data found in tree`. The *input* type
was set and the *output* type was still being inferred from an extension sops
does not know, so it fell back to the binary store. `--input-type` and
`--output-type` are independent and a measurement of a dotenv document needs
both, or a `.env` extension. Two rows of an early table read as sops refusing
a document it in fact reads at exit 0.
