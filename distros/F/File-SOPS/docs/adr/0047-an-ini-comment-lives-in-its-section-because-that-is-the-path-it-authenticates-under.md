# ADR 0047 — An ini comment lives in its section, because that is the path it authenticates under

- Status: **accepted** — decided and implemented together, in this commit.
- Date: 2026-08-21
- Tags: ini, format, mac, aad, comments, interop, roadmap
- Resolves k37 (the INI format handler), which CLAUDE.md has promised
  since 0.001. Unblocked by k74, k75, k76, k77 and k36
- Depends on, and does not revisit: **ADR 0022** (the flat metadata encoding,
  here with an empty prefix), **ADR 0035** (an untyped store's unencrypted leaf
  is written as its digest bytes), **ADR 0036** (the order-preserving reparse is
  asked of the format handler), **ADR 0041** (a sops comment is a leaf of its
  own) and **ADR 0045** (the ENV handler, whose shape this one follows).
  ADR 0002 is used unchanged
- **Changes one AAD rule in `File::SOPS`.** No YAML, JSON or dotenv document
  moves — measured, the whole suite is byte-identical before and after — but
  the change is in `_encrypt_tree`/`_decrypt_tree` and is named here rather
  than buried in the handler

## Context

ADR 0045 built the dotenv handler and listed what INI would inherit and what it
would have to measure for itself. The item it flagged hardest was the comment:

> the comment key (INI is two levels deep, so a comment's path is a section,
> not the root — **that has to be measured, not assumed**)

The guess in k37's body was `['section','']`, AAD `section::`. It is
wrong, and the measurement below is the whole reason this ADR exists.

## What was measured

sops 3.13.3 at `/tmp/sops`, one age recipient, every keypair generated for the
run. One plaintext `.ini` carrying every case at once, `sops -e`, then the
document taken apart with this distribution's own modules.

### 1. The whole document, in one piece

Input (comments in every position, values outside a section, duplicate section,
duplicate key, quotes, alignment, a multi-line value, blank lines):

```ini
; leading semicolon comment
# leading hash comment
outside_a = before any section
outside_b=no padding here

[db]
; comment above a key
host = localhost
port = 5432 ; trailing after value
empty =
quoted = "hello world"
spaced =   padded
hashish = a#b
semi = a;b
eq = a=b
uni = café
plain_unencrypted = visible
# hash comment inside a section

[api]
key = secret
multi = """line1
line2"""

[db]
dup_section_key = second db block

[dupkey]
k = first
k = second
# trailing comment at end of file
```

`sops -e`, exit 0, and `sops -d --output-type json` on the result:

```json
{ "DEFAULT": { "outside_a": "…", "outside_b": "…" },
  "db":  { "host": "localhost", "port": "5432", "empty": "", "quoted": "hello world",
           "spaced": "padded", "hashish": "a", "semi": "a", "eq": "a=b",
           "uni": "café", "plain_unencrypted": "visible" },
  "api": { "key": "secret", "multi": "line1\nline2" },
  "db":  { "dup_section_key": "second db block" },
  "dupkey": { "k": "second" } }
```

| question | answer |
|---|---|
| a value outside any section | section **`DEFAULT`**, written **headerless and first** |
| a **duplicate section** | **two branches with the same name** — the JSON above has `db` twice |
| a **duplicate key** in one section | the **last** wins, silently; the file sops writes holds one |
| the line | `key = value`, and **`:` is a delimiter too** — `host: localhost` is the key `host` |
| an unquoted `#` or `;` in a value | starts an **inline comment**: `a#b` is the value `a` and the comment `b` |
| a trailing `\` | **continues** the value onto the next line: `a = one\` + `b = two` is `oneb = two` |
| a surrounding pair of quotes | **stripped** — `"hello world"` is `hello world` |
| an unquoted value | trimmed both ends |
| a comment | `;` or `#`; **consecutive comment lines are ONE leaf** |
| a comment with no text | **dropped** — a bare `#` produces no leaf at all |
| a comment at end of file | **dropped**, it has no following node |
| a blank line | skipped, and does **not** end a comment block |
| the alignment | every key padded to the longest **in that section**, in **bytes** |
| the metadata | a `[sops]` section, last, keys sorted, values escaped, no prefix |

And what refuses: an **empty section name** (`[]`) is exit 2, an **empty key
name** (`= v`) is exit 2, a line with **no delimiter** is exit 2, a data section
named **`sops`** is exit 203 — the same message a YAML document with a top-level
`sops` key gets. A **nested** document is *not* refused: sops writes
`inner = [{host ENC[…]}]`, a dump of the Go value.

### 2. The MAC of that document, recomputed here

Rebuilt from the document with this distribution's modules and compared with the
plaintext of the document's own `mac`:

```
computed over the 18 data values, in DOCUMENT order, comments excluded
   C869F8432DEE16802DC88220C539CF5F7A52E26E199FBC86C2B94B56BDC32204…
mac plaintext
   C869F8432DEE16802DC88220C539CF5F7A52E26E199FBC86C2B94B56BDC32204…      MATCH
```

Three properties in one measurement, in a **third** format after YAML (karr
k108) and dotenv (k36): comments are **not** in the digest, an unencrypted
leaf contributes the literal text of its line, and an empty value contributes
the empty string. A value outside any section is hashed under `DEFAULT:<key>`,
so `DEFAULT` is real in the AAD and not only in the JSON view.

### 3. The AAD of a comment: the SECTION, and nothing else

The measurement that decides the tree. Each comment leaf decrypted against
candidate AADs:

| where the comment was written | AAD that works |
|---|---|
| above the first key, outside any section | `DEFAULT:` |
| above a key inside `[db]` | `db:` |
| inline, after a value inside `[db]` | `db:` |
| above the `[api]` header (written at the end of `[db]`) | `api:` |
| before the first section header, no `DEFAULT` keys | the **following** section |

Never `db::`. And measured separately, on a YAML document, `db::` is exactly
what a **genuine empty key** nested in a mapping authenticates under:

```yaml
map:
    "": ENC[…]        # decrypts under map::, and under nothing else
```

So the two are different things, and Go says why: sops walks a branch with the
branch's own path, and a comment is an **item of the branch whose key is a
`Comment` struct** — it contributes no path component where an ordinary key
contributes one.

ADR 0045 could keep a dotenv comment under a real, **empty key** because there
the branch is the document root: Go's `join(path,":")+":"` gives `:` for an
empty path, and this distribution's `_path_to_aad(!)` spells that `['']`. The
two coincided. **For a section they do not.**

### 4. Position, order and padding

Edits to a file sops wrote, then `sops -d`:

| edit | `sops -d` |
|---|---|
| every comment line moved to the top | **exit 0** |
| one `[db]` data line **sorted** | **exit 51**, MAC mismatch |
| a data line **deleted** (control) | **exit 51** |
| a comment leaf **deleted** | **exit 0** |
| the alignment padding **stripped** | **exit 0** |

Comment position and padding are in no digest; key order is.

### 5. The quoting, and the four values sops cannot read back

go-ini's writer quotes in three cases; its reader undoes rather more. Measured
on **unencrypted** values, which are the only ones whose text reaches the file
as itself:

| value | sops wrote | `sops -d` |
|---|---|---|
| `a#b`, `a;b` | `` `a#b` ``, `` `a;b` `` | round trip |
| `line1<LF>line2` | `"""line1<LF>line2"""` | round trip |
| ``a`b`` | ``"""a`b"""`` | round trip |
| `  leading`, `trailing  ` | `"  leading"`, `"trailing  "` | round trip |
| `""` | `""` | **exit 51** — read back as the empty string |
| `'quoted'` | `'quoted'` | **exit 51** — read back as `quoted` |
| `"quoted"` | `"quoted"` | **exit 51** — read back as `quoted` |
| `"""x"""` | `"""x"""` | **exit 51** — read back as `x` |
| `"a"b"` | `"a"b"` | round trip — the quote is *inside*, so it is not stripped |

Four files sops writes at exit 0 and then refuses to read. It is ADR 0030's
class in a different spelling, and ADR 0022's finding is unchanged and
unrelated: the **`\n` escape** belongs to the metadata layer, and INI does not
apply it to data values.

## Decision

**`File::SOPS::Format::INI` exists, shaped like `Format::ENV`, and it consumes
five ADRs rather than re-deciding any of them.** What is new is the tree, the
grammar, and one rule in the walk.

### 1. A section's comments live under that section's empty key

```perl
{
    db => {
        ''   => [ File::SOPS::Comment->new(text => 'a note'), … ],
        host => 'localhost',
    },
}
```

and **`File::SOPS::_encrypt_tree` / `_decrypt_tree` know that key adds no path
component**, so every element authenticates under `db:` exactly as sops wrote
it. The rule is deliberately narrow, and both halves are load-bearing:

- **only where the path is already non-empty**, so the dotenv bucket at the
  document root keeps the `''` component it needs and nothing about that format
  moves;
- **only where the value is a non-empty sequence of comments**, so
  `{ map => { '' => 'v' } }` keeps `map::`, which measurement 3 says is the AAD
  sops gives it.

The one shape whose AAD moves is a mapping key `''` holding a list of nothing
but comments, below the top level.

**Corrected 2026-08-21 by the wire lane's review of this change, k167.**
This paragraph first said that sops writes that shape as the branch's path and
that the change therefore moves us *toward* sops. That is measured wrong, and
backwards. A genuine empty key **does** contribute a path component:

```yaml
db:
    "":
        # a comment in a list under an empty key
        - one
        - two
```

sops authenticates that comment under **`db::`** — the empty key is an ordinary
key, and only the *comment* contributes nothing. So for this one shape the
change moves us **away** from sops, and it is a deliberate trade rather than an
alignment.

What makes the trade safe is not that argument but the `all-comments` guard,
and the reason it holds is measurable: **sops cannot write a sequence of nothing
but comments.** A comment leaf exists only because a node follows it in the same
sequence — measured over leading, trailing, consecutive and lone comments, every
sequence sops wrote held at least one non-comment element, and a comment with no
following node was hoisted to the parent branch or dropped. The sequence above
therefore keeps `db::` both before and after, because it contains a
non-comment. And sops's JSON store discards comments outright, so the shape
cannot arrive from there either.

**Why not the alternatives.** A named bucket (`__comments`) was rejected here
with the claim that it changes the AAD and the leaf stops decrypting — also
corrected by that review: with the same walk rule it would not, and it would
avoid the divergence above. It is rejected instead because it costs the
parallel to `Format::ENV`, where `''` is not a bucket name but the real path,
and because it introduces a reserved key name a genuine INI line can collide
with. `{ db => { '' => [...] } }` *without* the walk rule
is `db::`, measured wrong. Representing a section the way Go does — an ordered
list `[ $comment, …, \%keys ]` — needs no walk change at all and was rejected on
the API: `$data->{db}` would be a HashRef or an ArrayRef depending on whether
the section has a comment, and `extract(path => '["db"]["host"]')` would stop
working. Teaching `_path_to_aad` to drop a trailing empty component would break
the genuine empty key in measurement 3, in every format.

The empty key is **reserved** in an ini section, and nothing is lost: sops
refuses an empty key name outright, so an ini document cannot carry one as data.

### 2. The grammar is go-ini's, in full

Two delimiters, the continuation backslash, the inline comment, the three quote
forms, quoted keys, and `hasSurroundedQuote`'s "not if the quote is inside".
Reproduced rather than approximated because an **unencrypted** leaf reaches the
file as its own text: a reader that undoes less than sops's hands the digest a
different plaintext and the document fails its own MAC.

**No INI module was added as a dependency.** `Config::Tiny` and `Config::INI`
parse a different dialect — no backticks, no triple quotes, no `:` delimiter, no
continuation lines — and would silently produce a different plaintext for the
same file. The specification here is one Go library's behaviour, and it is
measured against the binary; a Perl module that agrees with it by coincidence is
not a shorter way to get it.

### 3. What is written, and in what order

- **Sections and keys sorted**, because the MAC's encrypt side hashes
  `sort keys` at every level. The same rule as ADR 0045's, and for the same
  reason.
- **`DEFAULT` gets an explicit `[DEFAULT]` header** in its sorted position,
  where sops writes the implicit section headerless and first. Writing it
  headerless would force it to sort first, which a section named `API` breaks;
  go-ini creates its own empty implicit `DEFAULT` beside the explicit one and
  sops reads the result at exit 0, measured.
- **One comment block per node.** A section's comments are spread over its
  nodes — one before the header, one before each key — because *consecutive
  comment lines are one leaf on the way back in*, so two `; ENC[…]` lines
  written next to each other come back as a single comment holding both tokens
  as text. sops never writes that, because it keeps every comment where the
  document had it; this emitter has no positions and so must spread them. The
  capacity is exactly right: a comment block needs a following node, so a
  section with K keys can hold at most K+1 blocks, and the emitter writes K+1.
  More than that is refused.
- **The alignment padding is reproduced.** Cosmetic for the digest
  (measurement 4) and reproduced because it makes a diff against a sops-written
  file readable — and, verified byte for byte, makes our lines land in exactly
  sops's columns.

### 4. A value the quoting cannot carry is refused

The guard asks the **round trip**, the way ADR 0030's does: the value is quoted
with this format's writer, put on a line, and read back with this format's
reader. A test for a character would be a second spelling of the rule and would
drift from it. That catches all four rows of measurement 5, and the trailing
backslash as well, with one rule.

The **encrypted** slot never reaches it: an `ENC[…]` string is base64 plus
`[]:,=`, which the writer leaves bare and the reader returns unchanged.

### 5. What is refused, and why each one

| refused | because | sops |
|---|---|---|
| a line that is not a comment, a header or `key = value` | there is nothing to read | same, exit 2 |
| an empty section name, an empty key name | there is no name | same, exit 2 |
| a **duplicate section** | sops keeps both as separate branches and a Perl hash cannot | accepts, and writes such a file |
| a **duplicate key** in one section | sops keeps the last and drops the other without a word | accepts |
| a **nested** value | the format is two levels deep | writes a Go struct dump |
| a **top-level scalar** | same | same, exit 4 |
| a section named **`sops`** | it would be read back as metadata | same, exit 203 |
| a value the **quoting** cannot round-trip | the document would fail its own MAC | writes it, then exit 51 |
| **more comment blocks than nodes** | they would be written adjacent and read back as one | n/a, it keeps positions |
| a **comment in a value slot** | sops writes its comment struct into the key | reads it, exit 0 |
| bytes that are not **valid UTF-8** | the boundary is characters and the emitters encode unconditionally (ADR 0003) | reads them |

The duplicate section is the one that blocks a document sops **writes**; it is
recorded for that reason. The duplicate key never appears in a sops-written
file, because go-ini collapsed it on the way in.

### 6. What is shared rather than copied

`File::SOPS::Metadata::Flat` with `prefix => ''` (ADR 0022), and
`File::SOPS::Format::ENV::Ordered` — the tied hash ADR 0036 requires — **used
where it stands** rather than built a second time. It now has two callers and
belongs in a file of its own; that is k158, and this is the second caller
that closes the argument.

## Consequences

**A `.ini` goes through every method.** `encrypt`, `decrypt`, `encrypt_file`,
`decrypt_file`, `encrypt_in_place`, `edit`, `extract` and `rotate` all work on
ini documents, with comments, in both directions against the binary.
`format => 'ini'` was `Unknown format: ini` before this.

**Comment position is not preserved**, and cannot be: the tree is a Perl hash.
A comment written beside a value comes back above it, and a section's comments
are redistributed over its keys. Measurement 4 is what makes that acceptable
rather than merely unavoidable.

**Diffs against a sops-written file are large**, because sections and keys are
reordered. Paid once per file: a document this library rewrites is stable under
further rewrites.

**An unencrypted leaf's type is erased by the round trip**, as in dotenv and for
the same reason — the store has no syntax for a type. And a plaintext ini
document written here spells a boolean `True` where `sops -d` writes `true`;
there is no digest over a plaintext document, so this is cosmetic (ADR 0035).

### What changes for existing callers

One thing, and it is the walk rule in decision 1: a mapping key `''` holding a
list of nothing but comments, below the top level, is now encrypted under its
parent's path rather than under `parent::`. Nothing in this distribution
produces that shape and no test moved — 61 files and 1262 tests, the suite as
it stood, pass identically before and after, with `t/04-interop.t` running
against the binary in both runs. Every other path is untouched, byte for byte.

## Rejected alternatives

**Refuse comments, as `Format::YAML` does (ADR 0024).** k37 and k108
both say why not: in an ini file a comment is the ordinary case, so a handler
that refuses one refuses almost every real document, and a `decrypt_file` that
dropped them would silently delete them from the file it rewrites.

**Follow sops on a duplicate key and keep the last.** It is what the reference
does, and it means `encrypt_file` writes a document missing a line the caller
wrote, with everyone reporting success. Refusing is loud and never produces a
wrong document; no sops-written file can trip it.

**Write `DEFAULT` headerless and first, as sops does.** Byte-identical to sops
for the common case and wrong for a document with a section that sorts before
`DEFAULT`, whose keys would then be hashed in one order and written in another.

**Reproduce sops's bytes for a boolean, a null and an integral float.** The
document would fail its own MAC, as sops's does. Rejected in ADR 0035 on the
measurement, and nothing here reopens it.

**Use an INI module from CPAN.** See decision 2: the specification is go-ini's
behaviour, and a module that happens to agree with it is not the same thing as
one that is measured against it.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with Crypt::Age on this machine, on
2026-08-21. Every fixture is invented; no key material or value in this document
belongs to anyone.

`t/61-ini-format-handler.t` pins all of it: the line grammar, the comment AAD
and the narrowness of the walk rule, the quoting and its four refusals, the
two-level tree and its refusals, the emitter's layout and padding, the
order-preserving reparse against sorted order, and — interop-gated, so it proves
nothing about sops without a binary — both directions against the real one plus
the full sops → File::SOPS → sops chain. Removing the walk rule makes it fail.

`prove -lr t/`: 63 files, 1284 tests, PASS — 61/1262 before this change, plus
this ADR's `t/61` (11) and two loads in `t/00-load.t` (k155), plus a `t/62`
that k161 landed in the same window. `t/04-interop.t` **ran** against
sops 3.13.3 at `/tmp/sops`: 32 tests, PASS.
