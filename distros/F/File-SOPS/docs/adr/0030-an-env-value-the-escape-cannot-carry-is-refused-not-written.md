# ADR 0030 — An ENV value the newline escape cannot carry is refused, not written

- Status: accepted
- Date: 2026-08-21
- Tags: env, mac, wire-format, escaping, guards, interop
- Resolves k109 (the wire half of the ENV handler, k36)
- Depends on ADR 0022 (which established the escape and decided to reproduce it
  lossy for the *metadata* section), ADR 0008 (the rule this applies: a leaf
  the emitter cannot write as the text the digest covers is refused) and
  ADR 0002 (the digest bytes come from `Encrypted::value_to_bytes`, which is
  the single source of truth for a leaf's wire bytes)
- Has no caller: `File::SOPS::Format::ENV` does not exist. This ADR records the
  decision so that k36 inherits it rather than inventing it.

## Context

ADR 0022 recorded the newline escape of the flat metadata encoding — a real
newline becomes the two characters backslash and `n`, nothing else is touched,
and a backslash is **not** doubled — and decided to reproduce it lossy, because
the only metadata value that carries newlines is the age `enc` armor, which is
base64 and contains no backslash at all, so the lossy case cannot arise for the
field where it would be catastrophic.

The same ADR then recorded, as a consequence it did not settle: **the ENV store
applies that same transform to data values.** That is the wire lane's problem
rather than the format lane's, because the MAC covers the plaintext of every
value, encrypted or not, so an escape that is not injective moves the digest.

Two questions were open. One is measurable and one is a judgement.

### Question 2 first, because it is measurable

**Does the digest cover the value before or after the escape?**

Two documents, one key each, one age recipient, `sops 3.13.3`, built from YAML
so that the value is exact:

| document | plaintext value | bytes sops wrote |
|---|---|---|
| A | `line1<LF>line2` | `plain_unencrypted=line1\nline2` |
| B | `line1\nline2` (backslash, `n`) | `plain_unencrypted=line1\nline2` |

The two data lines are **byte-identical** — `diff` of the two lines is empty.
The escape is lossy on the way out for data values exactly as it is for
metadata.

The `sops_mac` field of each was decrypted through this distribution's own
modules — `Metadata::Flat->unflatten`, `Metadata->from_hash`,
`Backend::Age->decrypt_data_key`, `Encrypted->parse` and `decrypt_bytes` with
`lastmodified` as AAD:

```
A  sops_mac plaintext  84D8F269D10AD408537928599B4843C563D8A028E1B0949D53ED59A1B5EDFEEA
                       DE74DD8463EBF378B51863ABB2F07343FCB8F53BB417020697F588A8DCB910E4
   SHA-512 of the bytes `line1<LF>line2`
                       84D8F269D10AD408537928599B4843C563D8A028E1B0949D53ED59A1B5EDFEEA
                       DE74DD8463EBF378B51863ABB2F07343FCB8F53BB417020697F588A8DCB910E4

B  sops_mac plaintext  186B7EF001E44B188989CD3CE55DE7C435E64ED56E992E3CE6B66D743C7D3F5B
                       AF273525074A311EC3B8CEC3F3E2FD56ED86FA768E638D77B992B3208511FEA0
   SHA-512 of the bytes `line1\nline2`
                       186B7EF001E44B188989CD3CE55DE7C435E64ED56E992E3CE6B66D743C7D3F5B
                       AF273525074A311EC3B8CEC3F3E2FD56ED86FA768E638D77B992B3208511FEA0
```

**The digest covers the value BEFORE the escape** — equivalently, the value
AFTER the unescape on the read side. The escape belongs to the emitter, not to
the digest, which is the same relationship every other format has: the MAC
covers the tree, the store decides how the tree is spelled.

That answers question 2 with no opinion in it, and it is what makes question 1
hard rather than easy: because the escape is not injective and the digest sits
on the pre-escape side, two different documents have the same body and
different MACs.

### What that costs, measured on sops itself

`sops -d` on the two files it wrote itself, same binary, same run:

```
A.env   {"plain_unencrypted": "line1\nline2"}                      exit 0
B.env   MAC mismatch. File has 186B7EF0…, computed 84D8F269…       exit 51
```

**sops writes B with exit 0 and no diagnostic, and then refuses to read it.**
The two digests in its own error message are the two computed above, in that
order. With `--ignore-mac` the value comes back as a real newline: the literal
backslash-`n` the caller handed in is gone, silently.

This is not "behaviour sops has that we must match". It is a document *nothing*
can read, produced without a word of warning. ADR 0022's metadata case is the
opposite situation — there, reproducing the lossy escape produces a file sops
reads correctly, because the affected field never contains a backslash.

### The full character sweep, on a DATA value

One document per row, the value in an unencrypted slot, read back with
`sops -d --output-type json`. `escape_value`'s column is this distribution's
`File::SOPS::Metadata::Flat::escape_value` applied to the same value.

| value in | bytes sops wrote | `escape_value` | sops read back | exit |
|---|---|---|---|---|
| `a<LF>b` | `a\nb` | `a\nb` | `a<LF>b` | 0 |
| `a<LF><LF>b` | `a\n\nb` | `a\n\nb` | `a<LF><LF>b` | 0 |
| `a\nb` | `a\nb` | `a\nb` | — | **51** |
| `a\\nb` | `a\\nb` | `a\\nb` | — | **51** |
| `a\tb` | `a\tb` | `a\tb` | `a\tb` | 0 |
| `a\b` | `a\b` | `a\b` | `a\b` | 0 |
| `a<TAB>b` | `a<TAB>b` | `a<TAB>b` | `a<TAB>b` | 0 |
| `a<CR>b` | `a<CR>b` | `a<CR>b` | `a<CR>b` | 0 |
| `a=b` | `a=b` | `a=b` | `a=b` | 0 |
| `a#b` | `a#b` | `a#b` | `a#b` | 0 |
| `a$b`, `a"b`, `a'b` | unchanged | unchanged | unchanged | 0 |
| ` ab`, `ab ` | unchanged | unchanged | unchanged | 0 |
| `` (empty) | `` | `` | `` | 0 |

Two things this settles. **Only backslash-`n` is affected** — a lone backslash,
`\t`, `=`, `#`, quotes and surrounding whitespace all survive, so the trigger is
precise and narrow. And **`escape_value` already reproduces sops's data-value
writer byte for byte**, on every row, which is question 3's answer (below).

`a\\nb` failing is the row that shows the read side is non-recursive and
unprotected: `s/\\n/\n/` finds the second backslash and the `n`, and returns
`a\<LF>b`. It is the same table ADR 0022 measured for metadata, arrived at
independently from the data side.

### The encrypted slot is immune, and that was measured rather than assumed

| document | plaintext value | sops read back | exit |
|---|---|---|---|
| C | `line1<LF>line2` in an encrypted slot | `line1<LF>line2` | 0 |
| D | `line1\nline2` in an encrypted slot | `line1\nline2` | 0 |

The slot holds `ENC[AES256_GCM,data:…,iv:…,tag:…,type:str]`, whose alphabet is
base64 plus `[],:=` — it contains neither a backslash nor a newline, verified by
grep on the written line. Whether the store applies the transform to it and it
does nothing, or does not apply it at all, is unobservable and equivalent.

### An ENV source cannot express the value either

The env store's **reader** performs the same unescape. A hand-written plaintext
`plain_unencrypted=a\nb` fed to `sops -e --input-type dotenv --output-type json`
comes out as a real newline. So the two-character sequence backslash-`n` has no
spelling anywhere in the ENV format: not in an encrypted document sops writes,
not in a plaintext one it reads. **"Pass it through faithfully" is not an option
that exists** — there is no faithful spelling to pass it through as. Passing it
through means writing bytes that mean a different value.

The value can still *arrive*: from a YAML or JSON source written out as dotenv,
which is exactly document B, or from a caller handing `encrypt` a Perl string.

### INI is unaffected, measured directly rather than inherited

The same two values through `--output-type ini`:

```
plain_unencrypted = line1\nline2          literal survives, sops -d exit 0
plain_unencrypted = """line1
line2"""                                  real newline, sops -d exit 0
```

while the same file's `[sops]` section carries
`age__list_0__map_enc = -----BEGIN AGE ENCRYPTED FILE-----\nYWdl…`. INI escapes
its metadata and not its data, which is ADR 0022's argument for where the escape
lives, confirmed here from the other direction. **The decision below is ENV-only
and k37 needs no guard for it.**

## Decision

**A leaf that will land unencrypted in an ENV document, and whose MAC bytes do
not survive the escape round trip, is refused when the document is written. The
read path is untouched.**

The rule, in the form k36 implements it:

```perl
my $bytes = File::SOPS::Encrypted->value_to_bytes($leaf);
croak _leaf_location($path) . ": cannot write this value into an ENV "
    . "document; the format's newline escape does not round-trip it"
    unless $flat->unescape_value($flat->escape_value($bytes)) eq $bytes;
```

Four properties of that form, all deliberate.

- **It asks the escape, it does not test for a character.** `index($bytes,
  "\\n") >= 0` is the same rule spelled a second time, and a second spelling is
  how the escape and its guard drift apart — the defect class this distribution
  is built to avoid. Asking `escape_value`/`unescape_value` whether they are the
  identity on these bytes cannot drift from them, and would keep being correct
  if sops ever escaped something else.
- **The bytes come from `Encrypted::value_to_bytes`, not from the leaf.** That
  is the single source of truth for what the digest covers (ADR 0002), and it is
  the only thing the guard may ask. Handing the raw leaf to `escape_value`
  instead would route a boolean through the *metadata* section's typing — see
  question 3 below.
- **Unencrypted leaves only.** An encrypted leaf reaches the file as an `ENC[…]`
  string the escape cannot touch, measured above. Refusing it would reject
  documents that work.
- **Write side only.** Reading an ENV document unescapes unconditionally,
  exactly as sops does. A document that already carries such a value is already
  MAC-broken; it fails the MAC verification that exists, fails closed, and
  `ignore_mac => 1` rescues it — the same escape hatch, and the same reason,
  as the pre-0.003 boolean documents.

**Where it lives: the ENV emitter, through the `reject` hook ADR 0006 built and
ADR 0008 generalised — not `assert_representable`.** `assert_representable` is
format-blind, runs over every leaf including encrypted ones, and runs on the
verify side; ADR 0008 already argued that placement out for exactly these
reasons, and every one of them applies here unchanged. This is a property of one
emitter, and only that emitter can answer it.

## Consequences

**No wire bytes move and no digest moves today.** Nothing calls this; there is
no ENV handler. `File::SOPS::Metadata::Flat` is unchanged in behaviour — the
only edit is POD recording the boundary below.

**k36 writes a croak where sops writes a broken file.** The cost is stated
rather than hidden: a caller who hands `encrypt` a value containing backslash-`n`
and asks for `format => 'env'` gets an error naming the key path, where sops
gives them a file and an exit 51 later, from a message that names no key at all.
Nothing that works stops working — every input that now croaks previously
produced a document that failed its own MAC, in both implementations. That is
ADR 0008's trade, made a second time, on a measurement rather than on the
analogy.

**The error names the key path and never the value.** A SOPS document leaves its
keys readable by design; a plaintext value in an error message was not encrypted
for any practical purpose. Same rule as ADR 0008's guard.

**Two neighbouring ENV defects are named and not fixed here.** Both were found
by the same sweep and both are the same shape — sops writes a document with
exit 0 and cannot read it back — and both belong to the type policy k77
owns rather than to the escape:

- An **unencrypted boolean**: sops writes `v_unencrypted=true` and its MAC
  covers `True` (SHA-512 `28A91492…`, which is the digest of the titlecase
  spelling, not of `true`). `sops -d` on its own file: **MAC mismatch, exit
  51**. The same document in YAML output round-trips at exit 0. Filed as karr
  k124.
- A **null**: sops writes `v_unencrypted=<nil>` and its MAC covers the empty
  string (`CF83E135…`). `sops -d`: **MAC mismatch, exit 51**. In an *encrypted*
  slot the nil is not encrypted either, so the file carries a bare `<nil>` and
  sops stops with `Input string <nil> does not match sops' data format`, **exit
  25**. Filed as k125.

  Both fall under the same general rule as this ADR — a leaf the ENV emitter
  cannot write as the text the digest covers — but what our ENV emitter *should*
  write for a bool or a nil is k77's per-format type decision, and settling
  it inside an escape ADR would pre-empt it.

**Keys are out of scope.** ENV keys are not in the MAC, and an ENV key
containing a newline breaks the format outright rather than the digest. That is
k36's parser problem.

### Question 3: are `escape_value` / `unescape_value` right for data values?

**The transform is exactly right and must be reused. The typing around it is
metadata-only and must not be.**

The sweep above put `escape_value`'s output next to the bytes sops wrote for a
*data* value on sixteen inputs and they agree on every one, which is the same
table ADR 0022 measured for metadata. There is one escape in the ENV format and
`File::SOPS::Metadata::Flat` already holds it; building a second one for data
values would reinstate precisely the duplication k75 was split out to
prevent.

What does **not** carry over is `escape_value`'s leaf handling. It maps a
`JSON::PP::Boolean` to lowercase `true`/`false` and croaks on other references,
because that is what the `sops` *section* holds — `mac_only_encrypted` is
written `true` there. A **data** leaf's wire bytes are
`Encrypted::value_to_bytes`'s, whose boolean spelling is `True`/`False`
(titlecase, invariant 4). Calling `$flat->escape_value($bool_leaf)` would
produce `true`, which is the right thing to *write* into an ENV document and the
wrong thing to *digest*, and the two would disagree — a MAC mismatch with no
wrong byte anywhere to look at. `Flat.pm`'s POD now says so at the method.

Nothing in `Flat.pm` changes behaviour; the boundary is recorded so k36 does not
have to rediscover it.

### What changes for existing callers

Nothing. There is no ENV format handler, `File::SOPS::Metadata::Flat` has no
caller, and no code path in this distribution is touched. `t/48` pins the
measurement so that the day sops stops writing a file it cannot read, this
decision goes red instead of quietly stale.

## Rejected alternatives

**Pass the value through, as sops does.** This is the option the house rule
about not refusing what sops accepts points at, and it is the one this session
has had to restore four times. It does not apply here, and the discriminator is
one measurement: *does sops read back what it wrote?* For every case those four
tickets were about, yes. For this one, no — exit 51, on its own file, in the
same run. Passing it through means writing a document that neither
implementation can read, and doing it as silently as sops does.

**Escape losslessly — double the backslash.** We would write `a\\nb` where sops
writes `a\nb`, sops's reader would turn that into `a\<LF>b`, and the file would
be wrong in the only direction that matters. This is ADR 0022's rejected
alternative and its argument is unchanged: interop is the product, a bug shared
with the reference implementation is a property of the wire format, and
unilaterally correcting it produces documents sops misreads.

**Digest the post-escape bytes instead**, so that the document and its MAC agree
whatever the escape does. It would make our own files self-consistent and make
every one of them fail against sops, because the measurement above shows the
reference digests the pre-escape value. It is the exact failure this
distribution's briefing warns about: a library that verifies its own output and
nothing else.

**Refuse on the read side too.** Attractive for symmetry and wrong: the
unescape is what makes the *working* case work, an already-damaged document
fails the MAC on its own merits with a message that says so, and `ignore_mac`
must keep being able to rescue it. Refusing at read time would reject documents
we can currently open, for no gain.

**Put the guard in `assert_representable`.** It is format-blind and runs
earlier, which is why it looks right. It also runs on encrypted leaves, where
the value is measurably safe, and on the verify side, where it would refuse to
open files. ADR 0008 rejected the same placement for the same reasons and built
the emitter-side hook that this uses instead.

**Defer the decision to k36.** Considered seriously, since there is no
handler to wire it into and a wrongly-made decision is inherited. Rejected
because the decision does not depend on the handler: the two questions are
answered by the binary, the answers do not change with our implementation, and
k36 will be writing a parser and an emitter with no reason to re-measure the
digest. Leaving it open is how the handler grows its own answer and this file
becomes an archaeology exercise.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with Crypt::Age on this machine, on
2026-08-21. Every age keypair was generated for the run; the fixtures are
invented values, not anyone's secrets. `t/48-env-data-value-escape.t` pins the
measurement, and it is interop-gated: without a binary it skips and proves
nothing, which is the honest outcome for an ADR whose whole content is what the
reference implementation does.
