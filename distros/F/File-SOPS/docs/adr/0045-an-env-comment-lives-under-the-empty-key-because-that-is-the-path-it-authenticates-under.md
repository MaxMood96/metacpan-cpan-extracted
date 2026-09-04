# ADR 0045 — An env comment lives under the empty key, because that is the path it authenticates under

- Status: **accepted** — decided and implemented together, in this commit.
- Date: 2026-08-21
- Tags: env, format, mac, comments, interop, roadmap
- Resolves k36 (the ENV format handler), which CLAUDE.md has promised since
  0.001. Unblocked by k74, k75, k76 and k77, all four landed today
- Depends on, and does not revisit: **ADR 0022** (the flat `sops_*` metadata
  encoding and its escape), **ADR 0030** (an ENV value the escape cannot carry
  is refused), **ADR 0035** (an untyped store's unencrypted leaf is written as
  its digest bytes), **ADR 0036** (the order-preserving reparse is asked of the
  format handler) and **ADR 0041** (a sops comment is a leaf of its own).
  ADR 0002 is used unchanged: the type comes from the scalar, with no
  format-specific rule anywhere
- **Adds wire surface, moves no existing bytes.** No YAML or JSON document is
  parsed, emitted, digested or refused differently

## Context

k36's body said the hard parts were the flat metadata (1), the MAC's key
order (2), `type:comment` (3) and a per-format type policy (4), and that the
parse/serialize class was "the cheap part" (5). Four ADRs have since answered
1–4 — including the finding that 4 was not a real question, since ADR 0002
already reproduces what the env **reader** does. What was left was 5, plus the
one question none of the four could answer because it is about the tree and not
about a value:

**where does a comment go in a Perl tree whose format is flat?**

ADR 0041 could leave that open. It measured that the only shape any *SOPS* store
writes is a comment as a **sequence element**, and YAML and JSON both have
sequences, so `_encrypt_tree` and `_decrypt_tree` needed nothing new. An env
document has no sequences at all. It has lines.

## What was measured

sops 3.13.3 at `/tmp/sops`, one age recipient, every keypair generated for the
run. One plaintext `.env` carrying every case at once, `sops -e`, and then the
document taken apart with this distribution's own modules.

### 1. The whole document, in one piece

Nobody had measured a *complete* env document before; the earlier ADRs each
measured their own row. Input (blank lines and comments deliberate):

```
# a leading comment
FOO=bar
NUM=5

# a comment before a group
EMPTY=
QUOTED="hello world"
SPACED=  padded  <- two spaces each side, kept
HASH=a#b
EQ=a=b
DOLLAR=a$b
BOOLISH=true
UNI=café
LONG=line1\nline2
plain_unencrypted=visible
# trailing comment at end of file
```

What sops wrote, structurally (ciphertext elided):

```
#ENC[…,type:comment]
FOO=ENC[…,type:str]
NUM=ENC[…,type:str]
#ENC[…,type:comment]
EMPTY=
QUOTED=ENC[…,type:str]
…
plain_unencrypted=visible
#ENC[…,type:comment]
sops_age__list_0__map_enc=-----BEGIN AGE ENCRYPTED FILE-----\nYWdl…\n
sops_age__list_0__map_recipient=age1…
sops_lastmodified=2026-08-21T08:47:47Z
sops_mac=ENC[…,type:str]
sops_unencrypted_suffix=_unencrypted
sops_version=3.13.3
```

| question | answer |
|---|---|
| the line | `KEY=VALUE`, no spaces around `=`, key up to the **first** `=` |
| a blank line in the input | **dropped**, and not written back by `sops -d` either |
| an empty value | `EMPTY=`, **not encrypted** — and it is in the digest as the empty string |
| a comment | `#` + the encrypted leaf, **in place** among the data lines |
| quotes, `#`, `=`, edge whitespace in a value | all kept verbatim; nothing is stripped |
| the metadata | last, keys sorted, values escaped, `sops_` prefix |
| the file | ends with exactly one `\n` |

And the parts of the grammar that refuse: a line with no `=` that is not a
comment is `invalid dotenv input line`, exit 2 — **including a line of blanks**,
so only a *truly* empty line is skipped. A key may be empty (`=value` is
accepted, exit 0). A **duplicate key** is accepted and both entries survive the
round trip: the env store's branch is an ordered list of items, not a map. A
top-level key starting with `sops_` is refused at exit 203, with the same
message sops gives a YAML document with a top-level `sops` entry. A nested value
is `cannot use complex value in dotenv file; offending key db`, exit 4. CRLF
input leaves the `\r` **inside the value**.

### 2. The MAC of that document, recomputed here

The digest was rebuilt from the document with this distribution's modules —
`Metadata::Flat->unflatten`, `Metadata->from_hash`, `Backend::Age`,
`Encrypted->parse`/`decrypt_bytes` — and compared with the plaintext of the
document's own `sops_mac`:

```
computed over the 12 data values, in DOCUMENT order, comments excluded
   A80EA7F656DC17A7D947D8A6EC0706E47684363E9FCF68CBC1F50951B2721509…
sops_mac plaintext
   A80EA7F656DC17A7D947D8A6EC0706E47684363E9FCF68CBC1F50951B2721509…      MATCH
```

Three properties in one measurement: comments are **not** in the digest (ADR
0041's rule, confirmed in a third format), an unencrypted leaf contributes the
literal text of its line, and an empty value contributes the empty string.

### 3. The AAD of a comment: `:`, and nothing else

This is the measurement that decides the tree shape. Each comment leaf was
decrypted against a list of candidate AADs:

| document | comment position | AAD that works |
|---|---|---|
| env | any of the three | `:` — and **not** `''`, not `sops:` |
| YAML | first line of the file | `:` |
| YAML | above a key inside `map:` | `map:` |
| YAML | element of `list:` | `list:` |

Go joins the path with `:` and appends one, so a leaf at the document **root**
authenticates under `:`, where this distribution's `_path_to_aad` answers `''`
for a genuinely empty path. No YAML or JSON document can reach that difference —
their leaves are never at the root — but every env comment is.

So `_path_to_aad(['']) eq ':'`: **an env comment is a leaf under an empty key
component.** Any other spelling of the key changes the AAD and the leaf stops
decrypting.

### 4. Comment position is not in the MAC, and key order is

Two edits to a file sops wrote, then `sops -d`:

| edit | `sops -d` |
|---|---|
| every comment line moved to the **top** | **exit 0** |
| the data lines **sorted** | **exit 51**, MAC mismatch |

The first is what makes this handler's layout possible; the second is why it
cannot simply write the keys in whatever order the hash yields.

### 5. A comment's text is verbatim in both directions

| input | sops wrote | sops read back |
|---|---|---|
| comment `#a\nb` | `#a\nb` | `a\nb` — the two characters |
| value `V=a\nb` | `V=a\nb` | a real newline |

The escape is the **data** value writer's, not the line writer's. A comment is
neither escaped nor unescaped.

## Decision

**`File::SOPS::Format::ENV` exists, shaped like `Format::JSON`, and it consumes
the four ADRs rather than re-deciding any of them.** What is new here is the
tree, the order, and the refusals.

### 1. A comment lives under the empty key, as a sequence

```perl
{
    ''  => [ File::SOPS::Comment->new(text => ' a comment'), ... ],
    FOO => 'bar',
}
```

Measurement 3 fixes the key and nothing else was available:

- **Not an invented key** (`__comments`, `#`): the AAD would be
  `__comments:` and the leaf would not decrypt.
- **Not a mapping value** (`'' => $comment`): `File::SOPS::_encrypt_tree`
  refuses a comment there, because sops reads such a document at exit 0 and
  writes Go's comment struct into the key (ADR 0041, measurement 7).
- **A sequence adds no path component** (invariant 2), so every element of the
  bucket authenticates under `:` exactly as sops writes it — which is why the
  bucket can hold *all* of them.

The empty key is therefore **reserved**: `parse` refuses a document with an
empty data key rather than silently losing one of the two, and `emit` refuses
anything in that slot that is not a comment. An empty data key is a document
sops reads, so this is a real (and narrow) divergence, recorded rather than
hidden.

Nothing about the digest is this handler's business: `_digested_leaves` excludes
a comment in every format and both MAC modes, and the handler neither helps nor
may.

### 2. Keys are written sorted, and the comment block comes first

The MAC's encrypt side hashes leaves in `sort keys` order, so a document this
library writes has to *be* in that order — the property `t/05-format-key-order.t`
pins for the other two emitters, which get it from YAML::XS and `canonical`.
Here the emitter sorts explicitly. The empty key sorts first, so the comments
head the document.

**Comment position is therefore not preserved, and cannot be.** The tree is a
Perl hash; its order is gone before any emitter sees it, and the data keys are
being reordered anyway. Measurement 4 is what makes that acceptable rather than
merely unavoidable: comment position is in no digest, and `sops -d` reads the
result at exit 0.

### 3. Reading takes its order from the document

`parse_in_document_order` meets ADR 0036's contract with the tied hash that ADR
described: top-level keys in file order, `sops_*` dropped by the handler,
values `undef`, and the comment bucket present with the right length so the
shapes line up with `parse`'s. Without it every env document sops writes fails
verification, because sops writes in document order and this library would hash
in sorted order.

### 4. Everything a value does was already decided

- **The type label** comes from the scalar (ADR 0002). An env *source* yields
  plain string SVs, so `NUM=5` is `type:str`; a tree from elsewhere keeps its
  types, and sops writes `type:int` for the same tree.
- **An unencrypted leaf** is written as exactly
  `File::SOPS::Encrypted->value_to_bytes($leaf)` (ADR 0035) — asked of the
  single source of truth, never re-derived. That is where this library writes
  `True`, an empty string and `1` for the three values sops writes as `true`,
  `<nil>` and `1.0` and then cannot read (k124, k125, k137).
- **A value the escape cannot carry** is refused when the document is written
  (ADR 0030), through the round-trip test on the escape rather than a test for
  a character, and only for unencrypted leaves and only on the write side.
- **A comment** is a `File::SOPS::Comment` (ADR 0041), written as `#` + its
  text with no escape, and refused where its text holds a newline — for which
  the format has no spelling at all.

### 5. What is refused, and why each one

| refused | because | sops |
|---|---|---|
| a line that is neither a comment nor `KEY=VALUE` | there is nothing to read | same, exit 2 |
| a **duplicate** key | a Perl hash cannot hold both, and dropping one silently is worse | accepts both |
| an **empty data key** | the comment bucket lives there (decision 1) | accepts |
| a top-level `sops_*` key | it would be read back as metadata | same, exit 203 |
| a **nested** value | the format is one level deep | same, exit 4 |
| an unblessed **reference** | the digest would cover a heap address (ADR 0008's class) | n/a |
| a **comment in a value slot** | sops writes its comment struct into the key | reads it, exit 0 |
| a comment holding a **newline** | a comment is one line and is not escaped | writes a broken file |
| bytes that are not **valid UTF-8** | the boundary is characters and the emitters encode unconditionally (ADR 0003) | reads them |

The last two rows are the only places this handler refuses a document `sops -d`
reads at exit 0, and both are recorded for that reason. Invalid UTF-8 is refused
by both sibling parsers as well (`invalid trailing UTF-8 octet` from YAML::XS,
`malformed UTF-8 character` from Cpanel::JSON::XS), so this is the
distribution's existing answer rather than a new one.

### 6. Detection

`.env` by file name — the same two shapes Go's `filepath.Ext` gives sops (a
bare `.env` and `secrets.env`). From **content**, `File::SOPS::_detect_format`
asks `Format::ENV->detect_content`, which requires *both* halves of what an
encrypted env document is: every non-empty line a comment or a `KEY=VALUE`
pair, **and** at least one flat metadata key. Either half alone is too weak — a
YAML block scalar can hold a line spelling `sops_version=3.13.3`, and a
plaintext `.env` carries no metadata at all. The prefix is not spelled in
`File::SOPS`: it is `File::SOPS::Metadata::Flat`'s, asked through the handler.

`dotenv` is accepted as an alias for `env` in `%FORMATS`, for the same reason
`yml` is accepted for `yaml`: it is the name sops itself uses.

## Consequences

**A `.env` goes through every method.** `encrypt`, `decrypt`, `encrypt_file`,
`decrypt_file`, `encrypt_in_place`, `edit`, `extract` and `rotate` all work on
env documents, with comments, in both directions against the binary.

**A commented `.env` survives `decrypt_file` and `edit`** — the half of k76
that ADR 0041 had to leave open, since `Format::YAML` cannot write a comment
line and refuses rather than dropping one. This handler can, and does.

**Two things a caller sees that no other format does.** A tree from an env
document may contain the empty key holding a list of `File::SOPS::Comment`
objects; and an *unencrypted* leaf's type is erased by the round trip (`42`
comes back as `"42"`, a boolean as `"True"`, an `undef` as `''`), because the
store has no syntax for a type. sops does the same to every unencrypted value
it reads. An encrypted leaf keeps its type, because the `type:` label carries
it.

**A plaintext env document written here spells a boolean `True`.** `sops -d`
writes `true` for the same leaf. There is no digest over a plaintext document,
so this is cosmetic — but it is the one place the single emitter (k35:
`emit` is `serialize` without the metadata and is also what `decrypt_file`
writes) shows through, and re-encrypting either spelling yields a `type:str`
string in both implementations.

**Diffs against a sops-written file are large**, because the keys are reordered
and the comments move to the top. That is the cost of decision 2 and it is
paid once per file, not per edit: a document this library rewrites is stable
under further rewrites.

**INI (k37) inherits most of this.** The flat metadata (ADR 0022), the type
rule (ADR 0035, measured identical line for line), the order-preserving reparse
(ADR 0036) and the comment leaf (ADR 0041) are shared, and so is the shape of
this handler. What it does **not** inherit: the escape guard (ADR 0030 measured
that INI escapes its metadata and not its data), the comment key (INI is two
levels deep, so a comment's path is a section, not the root — that has to be
measured, not assumed), and the grammar of a line.

### What changes for existing callers

Nothing. `format => 'env'` was refused with `Unknown format: env` before this
and is accepted now; every YAML and JSON path is untouched, byte for byte.

## Rejected alternatives

**Drop comments at parse.** The cheapest handler, and it makes `decrypt_file`
silently delete every comment in the file it rewrites. k36's own
constraint says a comment is the ordinary case in this format; that is exactly
where dropping is least acceptable.

**Keep comments in document position by returning a tied hash from `parse`.**
It would preserve the layout for one hop and no further: `_encrypt_tree` and
`_decrypt_tree` build plain `%result` hashes, so the order is gone by the time
any emitter sees it. Preserving it means changing those walks — a change to
what every format's tree is, for a cosmetic gain in one of them.

**Give the comment bucket a named key and fix the AAD elsewhere.** The AAD is
derived from the path in one place (`_path_to_aad`), shared by every format and
by the MAC. A per-format exception there is the second conversion this
distribution exists not to have.

**Write the keys in the order the document had them,** to keep diffs small.
Then the MAC's encrypt side — which hashes `sort keys` — would disagree with
the document, and every file this library wrote would fail its own digest. That
is ADR 0001's coupling, and it does not become optional in a new format.

**Reproduce sops's bytes for a boolean, a null and an integral float.** The
document would fail its own MAC, as sops's does. Rejected in ADR 0035 on the
measurement, and nothing here reopens it.

**Refuse a duplicate key by keeping the last one instead.** Silent, and the
digest would then cover a different document than the file holds — the MAC
would fail at a distance from the cause.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with Crypt::Age on this machine, on
2026-08-21. Every fixture is invented; no key material or value in this document
belongs to anyone.

`t/59-env-format-handler.t` pins all of it: the line grammar, the comment key
and its AAD, the order-preserving reparse against sorted order, the emitter's
layout, all nine refusals, ADR 0035's ladder, and — interop-gated, so it proves
nothing about sops without a binary — both directions against the real one,
including the three documents sops writes and then refuses to read.

`prove -lr t/`: 59 files, 1248 tests, PASS. `t/04-interop.t` **ran** against
sops 3.13.3 at `/tmp/sops`: 32 tests, PASS.
