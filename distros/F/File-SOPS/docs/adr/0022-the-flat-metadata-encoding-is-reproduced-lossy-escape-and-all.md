# ADR 0022 — The flat metadata encoding is reproduced as sops writes it, lossy escape and all

- Status: accepted
- Date: 2026-08-21
- Tags: metadata, wire-format, env, ini, escaping, interop
- Resolves k75 (split out of k36 as 36b; k37 shares it)
- Depends on nothing here yet: `File::SOPS::Metadata::Flat` has **no caller**
  until the ENV (k36) and INI (k37) handlers exist. This ADR records the shape
  the layer was cut to so that both use it rather than each growing its own.

## Context

The `sops` metadata section has two wire formats, not one.

YAML and JSON carry it as the nested mapping `File::SOPS::Metadata->to_hash`
produces. The ENV and INI formats have no nesting to put it in, so sops
flattens the same mapping onto single keys with a path-mangling scheme of its
own — the same scheme in both, differing only in where the flat keys are put:

```
ENV:  sops_age__list_0__map_enc=-----BEGIN AGE ENCRYPTED FILE-----\nYWdl…\n
      sops_lastmodified=2026-08-21T01:34:51Z

INI:  [sops]
      age__list_0__map_enc       = -----BEGIN AGE ENCRYPTED FILE-----\nYWdl…\n
      lastmodified               = 2026-08-21T01:34:51Z
```

That is a second metadata wire format and not a formatting detail.

### What was measured

Everything below is sops 3.13.3 on this machine, run against the binary rather
than read out of the Go source, with **two** age recipients so that
`__list_1__` is an observation and not a guess.

**The scheme.** A descent into a map under key `K` appends `__map_K`; a descent
into a list at index `N` appends `__list_N`; the root field name is bare. They
compose to any depth — a `--shamir-secret-sharing-threshold 2` document writes
`key_groups__list_0__map_age__list_0__map_enc`, which is five levels. The
reader parses the same way: `sops_unencrypted_suffix__map_x=y` is refused with
`'unencrypted_suffix' expected type 'string', got unconvertible type
'map[string]interface {}'`, so `__map_` really is a separator and not part of a
name.

**List indices must run from 0 without gaps.** Renumbering `age__list_1__` to
`age__list_2__` in a file sops wrote makes it stop with `Error while
unflattening: Incomplete list`, exit 1. So does a bare `__list_1` with no
`__list_0` beside it.

**Order is a structural walk, not a sort of the finished keys.** With eleven
recipients sops writes `age__list_10__map_enc` **after** `age__list_9__map_enc`:
maps in sorted key order, lists in ascending index order. Line order does not
matter on the read side — a file with its `sops_` lines reversed still
decrypts, exit 0 — and the metadata section is excluded from the MAC
structurally, so no digest depends on it.

**Empty lists have no representation at all.** `kms`, `pgp`, `gcp_kms`,
`azure_kv` and `hc_vault` produce no line whatsoever, where the nested format
always writes them as `[]`. This is not cosmetic: adding `sops_kms=` and
`sops_pgp=` to a document sops wrote makes `sops -d` fail with

```
'kms[0]' expected a map or struct, got "string"
'pgp[0]' expected a map or struct, got "string"
```

because an empty value reads back as a one-element list holding an empty
string. **Writing an empty list breaks the file.**

**The escape.** A newline becomes the two characters backslash and `n`. Nothing
else is touched. Feeding sops an `unencrypted_suffix` holding each character in
turn and reading the bytes back off the file it wrote:

| value passed to sops | bytes sops wrote |
|---|---|
| `a<TAB>b` | `a<TAB>b` — a real tab, unescaped |
| `a<CR>b` | `a<CR>b` — a real CR, unescaped |
| `a\\b` | `a\\b` — **the backslash is not doubled** |
| `a\tb` | `a\tb` — left alone |
| `a<LF><LF>b` | `a\n\nb` |

The read side is the same transform inverted, non-recursive, with no backslash
escape. Measured by putting each spelling into `sops_lastmodified` and reading
the value back out of Go's own parse error, which quotes the string it got:

| file bytes | sops parsed |
|---|---|
| `A\nB` | `A<LF>B` |
| `A\\nB` | `A\<LF>B` — a backslash, then a newline |
| `A\tB` | `A\tB` — untouched |
| `A\rB` | `A\rB` — untouched |

**The escape belongs to the metadata layer, not to the format.** This is the
measurement that decided where the code goes. In ENV, sops applies the same
`\n` transform to data values too: a plaintext `line1<LF>line2` is written
`plain_unencrypted=line1\nline2` and read back as a real newline. In INI it
does **not** — a multi-line data value is written with go-ini's triple-quote
form,

```
plain_unencrypted = """line1
line2"""
```

and a data value holding a literal `a\nb` comes back as the literal `a\nb`
(`sops -d --output-type json` shows `"a\\nb"`), where the same bytes in an ENV
data value come back as a newline. Since INI's *metadata* is escaped with `\n`
while INI's *data* is not, the escape cannot be the INI format's value writer —
it has to happen before go-ini sees the value, inside the flattening.

## Decision

**A new module, `File::SOPS::Metadata::Flat`, owns the flat encoding, and it
reproduces sops's behaviour exactly — including the lossy escape.**

### It is a module, not methods on Metadata.pm

Three reasons, in the order they matter.

- **It has to serve two format handlers that do not exist yet.** Building it
  inside whichever of ENV/INI lands first is precisely how the two drift, which
  is what k75 was split out of k36 to prevent. A module both `use` is the
  sharing mechanism.
- **`Metadata.pm` models the section's *semantics*** — which backends, which
  encryption rule, what is key material. This is one *encoding* of that
  section, with escaping and separator rules that have nothing to do with what
  the section means. The distribution already draws that line: `Encrypted.pm`
  is one value's wire format, `Format/*.pm` are document wire formats.
- **Lanes.** `Metadata.pm` is the API lane's file; a format-lane wire encoding
  bolted onto it would put two owners in one file for no gain.

### The difference between ENV and INI is one attribute

`prefix` — `sops_` for ENV, the empty string for INI — and nothing else.
`is_metadata_key` exists so the ENV handler does not spell `/^sops_/` itself:
that spelling and the one `flatten` writes have to agree, and the way they stay
agreeing is by being the same string in one place.

### `flatten` returns ordered pairs

Maps in sorted key order, lists in ascending index order, which is what sops
writes. A HashRef return would throw that away for no gain. The order is
**cosmetic for correctness** — reordering the lines changes nothing, and the
metadata is not in the MAC — but producing the same bytes as the reference
implementation is what this distribution is for.

### Empty lists are dropped, and nothing is lost

`to_hash` always emits the six backend lists; `flatten` emits nothing for an
empty one, because that is what the format requires and writing one anyway
produces the refusal above. `Metadata->from_hash` defaults every one of them to
`[]` when the document does not carry it, so the trip back restores them.
Verified: `unflatten` → `from_hash` → `to_hash` → `flatten` reproduces a real
sops file's metadata **byte for byte**, in both formats.

### The escape is reproduced lossy, deliberately

Because a backslash is not escaped on the way out and `\n` is not protected on
the way in, a value that already contains the two characters backslash-`n` is
indistinguishable from one containing a newline, and comes back as a newline.

**We reproduce that rather than fixing it.** A lossless escape — doubling the
backslash — would write `a\\nb` where sops writes `a\nb`, and sops's reader
would turn that into a backslash followed by a newline. The file would be
wrong in the one direction that matters. Interop is the product; a bug shared
with the reference implementation is a feature of the wire format, and
unilaterally correcting it produces documents sops misreads.

In practice the only metadata value that carries newlines is the age `enc`
block, which is PEM armor over base64 and contains no backslash at all, so the
lossy case cannot arise for the field that would be catastrophic. It is
recorded because a future reader will see the missing backslash escape and
recognise it as a defect.

### Every leaf comes back a string, and the trap is documented rather than closed

The flat formats are untyped — there is no parser here to say `2` was a number
and `true` a boolean, the way YAML::XS and Cpanel::JSON::XS do for the nested
format. `unflatten` is faithful to that.

**That leaves one live hazard, and this ADR does not close it.** Measured:
`sops_mac_only_encrypted=false` added to a document whose MAC covers every
value decrypts fine (exit 0), and `sops_mac_only_encrypted=true` on the same
document fails with `MAC mismatch`, exit 51 — the option selects the digest.
Perl's `'false'` is **true**, so handing `unflatten`'s output straight to
`from_hash` would make this library compute the wrong digest for a document
sops reads.

Typing the flat formats' values is **k77**'s decision (per-format type
policy, which also has to answer why `NUM=5` is `type:str` to the env store and
`type:int` here under ADR 0002). It is MAC-relevant and it spans the wire and
API lanes, so it is not the format lane's to settle alone. Until it lands, a
handler wiring this up has to map `true`/`false` itself; `t/38-flat-metadata.t`
asserts the string comes back as a string so that closing this is a deliberate
change rather than a silent one.

## Consequences

**No wire bytes move, and no digest moves.** `File::SOPS::Metadata::Flat` has
no caller. It touches no emitter, no parser and no MAC path, and the metadata
section is excluded from the digest structurally, so nothing existing can
change. It is new surface only.

**What k36 and k37 still owe.** This layer is the *metadata* half. Both
handlers still need the document half — and one piece of it is MAC-relevant and
belongs to the wire lane, not here: **ENV applies the same `\n` escape to data
values**, so an unencrypted ENV value containing a literal backslash-`n` reads
back as a newline, changing the plaintext the digest covers. INI does not have
that problem (triple-quote), but INI has its own: it is exactly two levels
deep, a top-level scalar is refused by sops itself (`Section values should
always be TreeBranches`), and values outside any section land in a `DEFAULT`
section that `sops -d --output-type json` shows as `"DEFAULT": {}`.

**INI alignment padding is cosmetic.** sops pads `key = value` to the longest
key *in that section*; stripping the padding entirely from a file it wrote
still decrypts, exit 0. Reproducing it is a diff-readability choice for k37,
not a correctness one — though reproducing it does make our `[sops]` section
byte-identical to sops's, which it currently is.

## Notes

Measured against sops 3.13.3 with Crypt::Age 0.002 on this machine.
`t/38-flat-metadata.t` pins the scheme against a captured sops layout with no
binary needed, and additionally — when a binary is present — hands sops a
document whose entire metadata section this module wrote and requires sops to
decrypt it, with only the **second** recipient's key available so that the
`__list_1__` entry has to have survived byte-exactly. Our flatten agreeing with
our unflatten proves nothing about sops; only that half does.
