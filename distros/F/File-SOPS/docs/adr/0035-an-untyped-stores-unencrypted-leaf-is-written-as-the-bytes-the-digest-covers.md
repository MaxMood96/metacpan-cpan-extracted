# ADR 0035 — An untyped store's unencrypted leaf is written as the bytes the digest covers

- Status: accepted
- Date: 2026-08-21
- Tags: env, ini, types, mac, wire-format, interop
- Resolves k77 (the per-format type policy), and decides k124 and
  k125 with it
- Depends on ADR 0002 (a value's type comes from the scalar — **extended here,
  not changed**), ADR 0008 (the general rule: a leaf the emitter cannot write
  as the text the digest covers), ADR 0022 (the flat encoding) and ADR 0030
  (the same discriminator, applied to the ENV escape)
- Has no caller: `File::SOPS::Format::ENV` and `File::SOPS::Format::INI` do not
  exist. This ADR records the decision so that k36 and k37 inherit it
  rather than inventing it.

## Context

k77 was split out of k36 with this premise, repeated in k37:

> In the env store every value is `type:str`, `NUM=5` included, because the
> store parses everything as a string. Our type comes from the scalar
> (ADR 0002), so `encrypt(data => {n => 5}, format => 'env')` would write
> `type:int` — a document the env store would never produce. That needs a
> per-format type policy, and a per-format exception to ADR 0002.

**The premise is half right, and the half that is wrong is the half the ticket
was opened for.** Measured against sops 3.13.3, both halves below.

### Where `type:str` on everything actually comes from

`sops -e` on a plaintext `.env` does write `type:str` for every value,
`NUM=5` included — and on a plaintext `.ini` too:

```
NUM=ENC[AES256_GCM,data:Lg==,…,type:str]        # from NUM=5 in a .env
num  = ENC[AES256_GCM,data:jw==,…,type:str]     # from num = 5 in a .ini
```

But that is the **input** store speaking, not the output store. Hand sops the
same tree from a YAML source and ask for the same output format:

```
$ sops -e --input-type yaml --output-type dotenv   #  v: 42
v=ENC[AES256_GCM,data:Iu4=,…,type:int]

$ sops -e --input-type yaml --output-type ini      #  db: {v: 42}
v = ENC[AES256_GCM,data:TM0=,…,type:int]
```

`type:int`, `type:float`, `type:bool` and `type:time` all appear in a dotenv
and in an ini document, and `sops -d` reads every one of them back at exit 0,
returning a JSON number, a JSON boolean and an RFC3339 string respectively.

So "everything is `str`" is a property of the ENV/INI **reader**: it has no
syntax for a type, so it hands the tree plain Go strings, and they are typed
`str` because that is what they are. **This distribution reproduces that for
free under ADR 0002** — an ENV or INI parser hands the walk plain Perl string
SVs, `detect_type` reads `POK` without `IOK`/`NOK` and answers `str`, with no
format-specific rule anywhere. And `encrypt(data => {n => 5}, format => 'env')`
writing `type:int` is not a divergence: it is byte-for-byte the label sops
writes for the same tree.

**There is no per-format type policy to write.** The rule the ticket asked for
already exists and is ADR 0002's.

### What is really broken, and it is not the type label

The full ladder, one document per row, value in the encrypted slot (`v`) and in
the unencrypted slot (`v_unencrypted`), YAML source so the value is exact,
`sops 3.13.3`. The `sops_mac` plaintext was decrypted through this
distribution's own modules — `Metadata::Flat->unflatten`, `Metadata->from_hash`,
`Backend::Age->decrypt_data_key`, `Encrypted->parse`/`decrypt_bytes` with
`lastmodified` as AAD.

**ENV and INI produced identical results on every row**, so one table serves
both. The `sops -d` column is the exit code of reading the file sops has just
written.

| value in | slot | sops wrote | label | `sops_mac` covers | `sops -d` |
|---|---|---|---|---|---|
| `"hello"` | enc | `ENC[…,type:str]` | `str` | `hello` | 0 |
| `"hello"` | plain | `hello` | — | `hello` | 0 |
| `""` | enc | *(empty — not encrypted)* | — | *(empty)* | 0 |
| `""` | plain | *(empty)* | — | *(empty)* | 0 |
| `42` | enc | `ENC[…,type:int]` | `int` | `42` | 0 |
| `42` | plain | `42` | — | `42` | 0 |
| `007` | enc | `ENC[…,type:int]` | `int` | `7` | 0 |
| `007` | plain | `7` | — | `7` | 0 |
| `1.50` | enc | `ENC[…,type:float]` | `float` | `1.5` | 0 |
| `1.50` | plain | `1.5` | — | `1.5` | 0 |
| `1.0` | enc | `ENC[…,type:float]` | `float` | `1` | 0 |
| `1.0` | plain | **`1.0`** | — | `1` | **51** |
| `1e20` | enc | `ENC[…,type:float]` | `float` | `100000000000000000000` | 0 |
| `1e20` | plain | **`1E+20`** | — | `100000000000000000000` | **51** |
| `-0.0` | enc | `ENC[…,type:float]` | `float` | `-0` | 0 |
| `-0.0` | plain | **`-0.0`** | — | `-0` | **51** |
| `true` | enc | `ENC[…,type:bool]` | `bool` | `True` | 0 |
| `true` | plain | **`true`** | — | `True` | **51** |
| `false` | enc | `ENC[…,type:bool]` | `bool` | `False` | 0 |
| `false` | plain | **`false`** | — | `False` | **51** |
| `null` | enc | **`<nil>`** | — | *(empty)* | **25** |
| `null` | plain | **`<nil>`** | — | *(empty)* | **51** |
| `2026-01-01T00:00:00Z` | enc | `ENC[…,type:time]` | `time` | `2026-01-01T00:00:00Z` | 0 |
| `2026-01-01T00:00:00Z` | plain | `2026-01-01T00:00:00Z` | — | `2026-01-01T00:00:00Z` | 0 |

Read the fourth column again. **In every row of both formats and both slots,
`sops_mac` covers exactly what `File::SOPS::Encrypted->value_to_bytes` returns
for that value** — `True`, `1`, `-0`, `100000000000000000000`, the empty string
for a null. Not once is it anything else. sops's digest and this
distribution's single source of truth for a leaf's wire bytes agree on the
whole ladder, without exception.

What varies is only whether sops's **emitter** writes those bytes. In the
encrypted slot it always does, inside `ENC[…]`, and the label says how to read
them back. In the unencrypted slot there is **no label**, and the untyped
reader hands the digest the literal text of the line — so the condition for a
document to verify is exactly

    the text written == value_to_bytes(the value)

and sops breaks it in three places, writing a display form where the digest
covers the wire form:

- **a boolean** — `true` written, `True` digested (k124);
- **a null** — `<nil>` written, the empty string digested (k125), and in
  the *encrypted* slot a nil is not encrypted at all, so the bare `<nil>`
  reaches the file and sops stops at `Input string <nil> does not match sops'
  data format`, exit 25, before the MAC is even reached;
- **a float whose Go display form is not its canonical positional decimal** —
  `1.0`, `2.0`, `100.0`, `0.0`, `-0.0`, `18.0` and every exponent-range value
  (`1E+06`, `1E+20`). This one was **not** in any ticket. It is the same defect
  as the other two and it is wider: an integral float is an ordinary value.
  `1.5`, `0.5`, `3.14` and `1.2345678901234567` are unaffected, because there
  the two forms coincide.

Every one of those is a file sops wrote with exit 0 and then refused to read,
in the same run, with no diagnostic in between. `int`, `str` and `time` are
clean in both slots — the value's *type* is erased on the way back (`42` returns
as the string `"42"`), but that is the format being untyped and it is what sops
does at exit 0.

### The bytes we would write instead are bytes sops writes and reads

The candidate for each broken row is `value_to_bytes`'s output, which is what
the digest already covers. Offering sops the same text as a **quoted string**
makes sops both write and digest it, so the row below is a document sops itself
produces:

| candidate | line sops wrote | digest | `sops -d` | comes back as |
|---|---|---|---|---|
| bool `true` → `True` | `True` | = SHA-512 of the text | 0 | `"True"` |
| bool `false` → `False` | `False` | = SHA-512 of the text | 0 | `"False"` |
| null → *(empty)* | *(empty)* | = SHA-512 of the text | 0 | `""` |
| float `1.0` → `1` | `1` | = SHA-512 of the text | 0 | `"1"` |
| float `1e20` → `100000000000000000000` | `100000000000000000000` | = SHA-512 of the text | 0 | `"100000000000000000000"` |
| float `-0.0` → `-0` | `-0` | = SHA-512 of the text | 0 | `"-0"` |
| int `42` → `42` | `42` | = SHA-512 of the text | 0 | `"42"` |

Fourteen measurements, seven rows × ENV and INI, all exit 0. And the digests
are the ones already in the table above: `28A91492…` for `True`, `AF1AACE5…`
for `False`, `CF83E135…` for the empty string, `4DFF4EA3…` for `1`,
`10FCA70A…` for `1e20`'s canonical form, `18A79719…` for `-0`. **Writing these
bytes does not move the MAC at all** — it repairs sops's own document by
changing the one line that disagreed with the digest sops itself computed.

A single document carrying all seven unencrypted rows plus an encrypted
`type:bool`, `type:float` and `type:int` reads back at exit 0 in both formats.

## Decision

**Two rules, and the first one is that there is no new rule.**

### 1. The type label keeps coming from the scalar

ADR 0002 is **extended, not changed**. No rung of the ladder moves, no format
argument reaches `detect_type` or `value_to_bytes`, no wire byte moves for any
caller, and `encrypt(data => {n => 5}, format => 'env')` writes `type:int`
because that is what sops writes for the same tree. The `type:str`-on-
everything that k77 was opened for is what an ENV or INI **parser**
produces on the way in, and it falls out of ADR 0002 with no format-specific
code.

### 2. In an untyped store, an unencrypted leaf is written as its digest bytes

**A leaf that lands unencrypted in an ENV or INI document is written as exactly
`File::SOPS::Encrypted->value_to_bytes($leaf)` — the bytes the MAC digest
covers. Nothing is refused for its type.**

Five properties of that rule, all deliberate.

- **It asks the single source of truth, it does not re-derive anything.** The
  emitter and the digest call the same class method on the same leaf, so they
  cannot drift apart — which is the defect class this distribution exists to
  avoid, and the reason ADR 0002 collapsed two type ladders into one.
- **It is the emitter's rule, not the ladder's.** A *typed* store must not do
  this: `Format::YAML` writes a bare `true` and digests `True`, and that is
  correct there, because go-yaml parses `true` back into a boolean and Go
  re-derives `True` from it. The difference between the two is a property of
  the store's reader, so it belongs in the store.
- **Unencrypted leaves only.** An encrypted leaf reaches the file as an
  `ENC[…]` string carrying its own label, measured clean for `str`, `int`,
  `float`, `bool` and `time` in both formats. Nothing there changes.
- **The digest does not move.** A document written under this rule has the same
  `sops_mac` plaintext as the document sops writes for the same tree, row for
  row. The bytes that differ are only the ones sops's own MAC already
  contradicts.
- **It closes k124 and k125 as one rule and in both slots.** A
  boolean is written `True`; an `undef` is not encrypted (invariant 7) and is
  written as the empty string in either slot, where sops writes `<nil>` and
  gets exit 51 or exit 25.

ADR 0030's ENV guard stays on top of this and is unaffected: after the bytes
are chosen, a `str` whose bytes the newline escape cannot carry is still
refused, and that guard already asks `value_to_bytes` for the same bytes.

### The metadata half of k77, and where it belongs

k75 folded a second typing question into this ticket:
`Metadata::Flat->unflatten` returns every leaf as a **string**, so
`sops_mac_only_encrypted=false` reaches `Metadata->from_hash` as the string
`'false'`, which is **true** in Perl — and that option selects which values the
digest covers, so the wrong answer computes the wrong MAC for a document sops
reads fine.

Measured, and the measurement decides the placement: **sops decodes its
metadata section weakly in every format, not only in the flat ones.** In a
nested YAML `sops:` section:

| `mac_only_encrypted:` | sops | | `shamir_threshold:` | sops |
|---|---|---|---|---|
| `false` | false | | `2` | 2 |
| `"false"`, `"FALSE"`, `"False"`, `"f"`, `"F"`, `"0"`, `""` | **false** | | `"2"` | **2** |
| `true`, `"true"`, `"TRUE"`, `"True"`, `"t"`, `"T"`, `"1"` | **true** | | `false` / `true` | accepted |
| `2`, `1.0` | true | | `"false"` | **refused, exit 1** |
| `"yes"`, `"no"`, `"on"`, `"off"` | **refused, exit 1** | | | |

That is `strconv.ParseBool`'s accepted set exactly, reached through
mapstructure's weakly-typed decoding, and it applies to a YAML document as much
as to a flat one. So the coercion is **not** a flat-format concern:

- `File::SOPS::Metadata::Flat->unflatten` stays faithful and keeps returning
  strings. It is the structural inverse of `flatten` and has no schema.
- **The coercion belongs in `File::SOPS::Metadata->from_hash`**, the one place
  every format's parsed section arrives, typed or not — `mac_only_encrypted`
  through the `ParseBool` set above with anything else a croak, and
  `shamir_threshold` through an integer parse. Putting it in `unflatten`
  instead would leave a quoted `mac_only_encrypted: "false"` in a **YAML**
  document still reading as true, which is the same bug in the format that has
  a handler today.

`Metadata.pm` is the API lane's file, so this ADR records the decision and the
measured specification and hands the change over (see k77's follow-up
ticket). `Flat.pm`'s POD, which said the typing question was k77's and
undecided, now says what was decided and where it goes.

## Consequences

**No wire bytes move and no digest moves today.** There is no ENV or INI
handler, nothing calls the rule, and the only edits are the two POD sections
that record it plus the test that pins the measurement.

**ADR 0002 is extended, not changed.** Explicitly: no rung, no flag test, no
canonical form and no caller's type changes. The extension is one sentence —
that in an untyped store the emitter, not the parser, is where the format
speaks, and it speaks by writing the digest bytes verbatim.

**k36 and k37 inherit a rule and not a question.** What they no
longer have to decide: what type label to write (ADR 0002's), what text an
unencrypted leaf gets (this ADR's), what to do about a boolean (k124), what to
do about a null (k125), and what to do about an integral or exponent-range
float (measured here, never ticketed). What is still theirs: the tree shape,
key handling, `type:comment` (k76), the order-preserving parse (k74),
and — INI only — values outside a section, duplicate sections, quoting and the
`key = value` alignment padding.

**We write a few bytes sops does not, and only where sops's bytes are
unreadable.** `v_unencrypted=True` where sops writes `v_unencrypted=true`,
`v_unencrypted=` where sops writes `v_unencrypted=<nil>`, `v_unencrypted=1`
where sops writes `v_unencrypted=1.0`. Each of those is a line sops itself
writes for the corresponding string, each verifies, each reads back at exit 0,
and each replaces a line that makes the whole file unreadable. Nothing that
works stops working.

**An unencrypted value's type is erased by the round trip, and that is the
format.** `JSON->true` in an unencrypted ENV slot comes back as the string
`"True"`, an `undef` as `''`, `42` as `"42"`. sops does the same to every
unencrypted value it reads, including the ones it writes correctly — the ENV
and INI readers have no syntax for a type. A caller who needs the type
preserved puts the value in an **encrypted** slot, where the label carries it
and the round trip is exact.

### What changes for existing callers

Nothing. `File::SOPS::Format::ENV` and `File::SOPS::Format::INI` do not exist,
`File::SOPS::Encrypted` is unchanged in behaviour, and
`File::SOPS::Metadata::Flat` is unchanged in behaviour. YAML and JSON documents
are untouched in both directions.

## Rejected alternatives

**Write `type:str` for every value in an ENV or INI document** — the ticket's
own proposal, and the reason it was filed. Refuted by measurement: sops writes
`type:int` for exactly that tree and reads it back at exit 0. Coercing would
make our documents differ from sops's for a case sops handles correctly, throw
away the only type information the format *can* carry, and change the value a
round trip returns from `42` to `"42"` in a slot where sops returns `42`.

**Refuse an int, float or bool when the format is ENV or INI** — the house
reading of "fail loud". Refuted by the same discriminator ADR 0030 used, *does
sops read back what it wrote?*, applied per type: for `int`, `float`, `str` and
`time` in the encrypted slot, and for `int`, `str` and `time` in the
unencrypted one, the answer is yes, at exit 0. Refusing them would reject
documents that work — and would reject the documents an ENV or INI **source**
produces on the way through.

**Refuse a boolean and a null in an unencrypted ENV or INI slot** — ADR 0030's
answer, applied literally to the two rows it named. Considered seriously, and
it is the shape this repository has reached for four times. Rejected on the
discriminator, which is not "does sops break?" but "**is there a spelling
sops reads?**". ADR 0030 refused because the ENV format has *no* spelling for
the two characters backslash-`n`: not in a document sops writes, not in one it
reads, so passing the value through means writing bytes that mean something
else. Here the spelling exists, it is the one sops's own MAC already assumes,
and a document carrying it reads back at exit 0 — measured, seven types, two
formats. Refusing a value that has a working spelling would be a divergence
with nothing behind it.

**Reproduce sops's bytes exactly** — write `true`, `<nil>`, `1.0`. This is what
byte compatibility usually demands and it is wrong here for one reason: the
result is a document that fails its own MAC, produced as silently as sops
produces it. Interop is compatibility with documents that can be read, not with
the bug — the same trade ADR 0008 and ADR 0030 already made, on a measurement
rather than on the analogy.

**Digest the display form instead**, so that the document and its MAC agree
whatever the emitter writes: hash `true` for a boolean and `<nil>` for a null.
Our files would verify against themselves and every one of them would fail
against sops, whose digest covers `True` and the empty string in every row of
the table above. That is the exact failure this distribution's briefing warns
about.

**Give `detect_type` or `value_to_bytes` a format argument.** It looks like the
place because the ticket says "per-format type policy". Both are format-blind
by construction, both are shared with the encrypted path and with the digest,
and a format branch inside either would be a second conversion in the one place
that must have only one. The rule is about what a store's reader will do with a
line of text, which only that store can answer.

**Type the flat metadata inside `Flat->unflatten`.** The obvious home, since
that is where the string comes from. Rejected on the measurement above: sops's
weak decoding is not flat-specific, so a fix there would leave
`mac_only_encrypted: "false"` in a YAML document still reading as Perl-true —
the same bug in the format that has a handler today. One coercion, in
`from_hash`, covers both.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with Crypt::Age on this machine, on
2026-08-21, one document per row, every age keypair generated for the run. The
fixtures are invented values, not anyone's secrets.
`t/50-flat-store-type-policy.t` pins the measurement and is interop-gated:
without a binary it skips and proves nothing about sops, which is the honest
outcome for an ADR whose content is what the reference implementation does.

**A neighbouring finding, measured here and not decided here: a `type:bytes`
cell makes `sops -d` panic.** Exit 2, `panic: runtime error: hash of unhashable
type []uint8`, in the aes package — and it is **not** an ENV or INI property:
the same hand-built cell crashes sops in a YAML document too. No sops store was
found that produces one (`!!binary` becomes `type:str` with the decoded bytes,
and so does the whole-file `binary` input store), so `type:bytes` is a type
sops 3.13.3 can write into its own model and cannot read from a file. That
matters to ADR 0003, whose `type => 'bytes'` escape hatch therefore produces a
document sops cannot open in any format. Filed as its own ticket rather than
folded in here.
