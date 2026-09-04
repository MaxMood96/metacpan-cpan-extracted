# ADR 0061 — A top-level `sops` data key is refused only when the format reserves it

- Status: accepted
- Date: 2026-08-23
- Resolves k157
- Lane: api
- Depends on **ADR 0022** (the flat metadata encoding ENV and INI share via
  `File::SOPS::Metadata::Flat` — the prefix is the only thing that differs
  between them) and the `k18` reasoning this guard was originally
  written to enforce (`t/09-reserved-sops-key.t` pins that case for YAML
  and JSON).
- **Moves no wire bytes.** The YAML and JSON case is unchanged; ENV and
  INI now accept a `sops` data key and write/read it like any other entry.
  Every existing YAML/JSON test that pins the `k18` refusal still
  passes byte-for-byte.

## Context

SOPS keeps its metadata under a single namespace root. For YAML and JSON
that namespace is a literal `sops:` mapping at the top of the document;
the metadata and the user's data live in the same hash and a collision
overwrites one with the other. `k18` is the bug that followed from
not noticing it: `serialize` assigned the metadata into `sops`
unconditionally, so a user value under that name was overwritten by the
metadata section; the digest, computed before serialization, had already
covered the user's value; and the resulting document failed its own MAC
on the very next read. The guard `exists $data->{sops}` at the head of
`encrypt` was the loud refusal that replaced the silent overwrite.

For ENV and INI the namespace is different. ENV writes its metadata into
flat top-level `sops_*` keys (`Metadata/Flat.pm` with `prefix => 'sops_'`,
one entry per field); INI writes it into a `[sops]` section
(`Metadata/Flat.pm` with `prefix => ''`, every field a key under one
section). Neither format has a top-level `sops` key, so neither format
has a place where a caller's `sops` data entry collides with the
metadata. A document that already had `sops=1` as a plain env value is
one sops encrypts and decrypts without comment:

```
$ printf "sops=1\nA=2\n" > sk.env
$ sops -e --age age1... sk.env           # exit 0
$ sops -d sk.enc.env
sops=1
A=2                                     # exit 0
```

`encrypt` here refused that document, format-blind, even though the file
on disk was the same shape sops itself just wrote. The ENV parser
returned `{ sops => '1', A => '2' }`, the guard fired on `exists
$data->{sops}`, and the caller had no way to round-trip a sops-written
env file back through this library. The same hole existed for INI's
`sops=1` analog, although INI's `[sops]` section makes the test rarer in
practice.

The format handlers' own serialize-time guards are still in place as
defense in depth: `Format::ENV` refuses a `sops_*` prefix at write time
(because that IS the metadata namespace there), and `Format::INI`
refuses a `[sops]` section for the same reason. The duplicate keys
between those guards and the SOPS-level guard were always intentional
— they defend against direct callers of `serialize`, who do not pass
through `encrypt`'s guard. The two-layer setup is what makes the
`%RESERVES_SOPS_KEY` decision possible: the SOPS-level guard is the
broad catch, the handler guards are the precise catch, and the broad
catch can now correctly say "defer to the handler" for a format that
does not reserve the name.

## Decision

`encrypt` consults a small hash that records which format handlers
reserve the bare `sops` name as their metadata namespace root:

```perl
my %RESERVES_SOPS_KEY = (
    'File::SOPS::Format::YAML' => 1,
    'File::SOPS::Format::JSON' => 1,
    'File::SOPS::Format::ENV'  => 0,
    'File::SOPS::Format::INI'  => 0,
);
```

The guard fires only when the resolved format class is in the truthy
set:

```perl
my $format_class = $FORMATS{$format} // croak "Unknown format: $format";
croak _sops_key_reserved('data') if exists $data->{sops}
    && $RESERVES_SOPS_KEY{$format_class};
```

The format class is resolved BEFORE the guard — the only structural
change in `encrypt`. The handler guards inside `Format::ENV` and
`Format::INI` are kept as defense in depth for direct callers of
`serialize`, who do not pass through `encrypt` and therefore never see
the SOPS-level guard.

The `_sops_key_reserved` wording changes. The previous text advised the
caller to "use edit to change its contents or rotate to re-key it, or
decrypt it first." The same guard fires from inside both `edit` and
`rotate` (rotate via the `encrypt` below it, edit by the same path), so
the message named the method that had just refused the caller. The new
text says what is wrong and what to do without pointing at a method that
may itself have failed:

```
$what contains a top-level 'sops' entry, which is reserved for the
SOPS metadata section. Encrypting would overwrite it and produce a
document that fails its own MAC verification. This usually means the
input is already encrypted -- decrypt it first if you want to change
its contents or re-key it. If it really is plaintext, rename the
entry. (sops refuses such a file too, with exit code 203.)
```

The remedies are documented under `edit` and `rotate`; the message here
says what is wrong and what to do about it. The error CLASS is the
same — `exists $data->{sops} && $RESERVES_SOPS_KEY{$format_class}` —
so existing callers that pattern-match on the message can narrow to its
leading clause; the only thing that changed is the advice.

## Consequences

- **An env plaintext file with `sops=1` round-trips.** Encrypt writes
  `sops=ENC[…,type:str]` alongside `sops_age__list_0__map_enc=…` in the
  flat layout; decrypt hands `{ sops => '1', … }` back to the caller.
  This is the user-visible effect of the change and the one the ticket
  asks for.
- **An INI plaintext file with `[sops]` as a data section is still
  refused, with the INI handler's own message.** The SOPS-level guard
  correctly defers to the handler guard (which fires first, because the
  handler is what produces the bytes). The caller sees the precise
  refusal rather than the broad one, and the precise refusal names the
  section rather than the key — `[sops]: …` reads as the section-named
  refusal it is.
- **YAML and JSON still refuse a top-level `sops` data key.** The
  `t/09-reserved-sops-key.t` cases (a) encrypt refuses, (b)
  `encrypt_file` refuses an already-encrypted file, (c) `encrypt_file`
  refuses in-place re-encryption, (d) the same refusal for a `sops`
  entry that is not a mapping, all pass byte-for-byte. The MAC
  verification failure mode `k18` describes is unchanged.
- **`rotate` and `edit` succeed on a sops-written env file with
  `sops=1`.** Both reach `encrypt` for the re-encryption; before the
  fix, both died with the format-blind refusal. After the fix, the
  guard returns NO for the env format class and the re-encryption
  proceeds under the same rules the document already had.
- **`encrypt_in_place` on an env plaintext file with `sops=1` works.**
  ENV parses such a file as plain data, not as already-encrypted, so
  the already-encrypted check at the head of `encrypt_in_place` does
  not fire either. The previously-over-firing guard no longer fires.
- **Format detection at the call site is unchanged.** The format is
  passed to `encrypt` as `format => 'yaml'` / `'json'` / `'env'` /
  `'ini'` as before; the guard does not look at the value's contents
  or auto-detect. A caller that knows the format can predict the
  outcome without writing a test.
- **The error message no longer names `edit` or `rotate`.** A caller
  refused by `encrypt_file` (whose failure may have been caused by a
  previous rotate leaving a duplicate key in the file, for example) is
  no longer told to "use edit or rotate" — advice that, from inside
  `rotate`, would have been "use the method that just refused you."
  The new wording is accurate for every call site, including `edit`
  and `rotate` themselves.

## Limits

- **No auto-detection of "the caller meant the other format."** The
  guard fires on the format passed to `encrypt`, period. A caller who
  encrypts `{ sops => '1' }` as YAML is refused; a caller who encrypts
  the same hash as ENV is not. This is the correct behavior: `encrypt`
  does not know the file the value came from, and refusing what the
  caller asked for is louder than second-guessing them.
- **The ENV handler still refuses a `sops_*` data key.** ENV's metadata
  lives in flat `sops_*` keys, so a data key carrying that prefix
  collides with the metadata namespace and the handler's own guard
  refuses it at serialize time. The SOPS-level guard's "bare `sops` is
  fine in ENV" decision does not extend to the `sops_` prefix, which is
  a different name with a different collision.
- **The INI handler still refuses a `[sops]` section.** INI's metadata
  lives in a `[sops]` section, so a data section with that name
  collides with the metadata namespace and the handler's own guard
  refuses it. The SOPS-level guard's "bare `sops` is fine in INI"
  decision does not extend to the section name, because INI's data
  structure is `{ section_name => { key => value } }` — the key under
  which `sops` would land is exactly the section name.
- **No new guard on the YAML/JSON case.** The existing
  `%RESERVES_SOPS_KEY{YAML}` and `%RESERVES_SOPS_KEY{JSON}` truthy
  entries are wired to the same refusal the previous format-blind
  guard produced. The YAML/JSON wire shape is unchanged.
- **No new guard for the `sops_mac` / `sops_age__list_0__map_enc`
  etc. collision in env.** ENV's flat layout puts the metadata under
  explicitly-prefixed keys, so a caller data key like
  `sops_age__list_0__map_enc` would collide with the same-named
  metadata field. ENV's own serialize-time guard refuses the `sops_`
  prefix at the leaf level (line 565-570); the SOPS-level guard does
  not cover this case because it is not about the bare `sops` name.

## Rejected alternatives

**Make the ENV handler rewrite a bare `sops` data key to a `sops_`
prefix.** Tighter — the user never sees `sops` in the file at all.
Rejected because it would move bytes the user typed and expect to read
back. sops does not rewrite the name either; the file on disk after
`sops -e` has `sops=ENC[…]` next to `sops_age__…=…`, and `sops -d`
hands both back under their typed names. Diverging from the binary on a
shape the binary accepts would be a wire break in everything but name.

**Strip the `sops` key from `$data` in `encrypt` and let the file
emit normally.** Looser. Rejected because it would silently drop the
caller's value, which is the failure mode `k18` was meant to
prevent. The MAC covers the value; if the value disappears between
digest and serialize, the document fails its own MAC on the next read.
Refusing is louder than dropping.

**Keep the format-blind guard and add an ENV/INI exception in the
caller.** Tighter than the decision but at the wrong layer. Rejected
because the exception belongs in the library, not in every caller:
the caller does not know the conditional better than the format
dispatch table does, and pushing the conditional out means the next
caller gets it wrong again. `%RESERVES_SOPS_KEY` is the dispatch table,
and `encrypt` is where the decision lives.

**Drop the SOPS-level guard entirely, let the format handlers' own
guards carry the refusal.** Looser still. Rejected because the handler
guards fire AT SERIALIZE TIME, after the digest has been computed over
the user's value. A YAML caller passing `{ sops => 'mine' }` would
reach the handler guard with a MAC already computed over `mine`, and
the resulting document would either silently drop the user's value or
fail the handler guard — both wrong, and one of them silently wrong,
which is the `k18` failure mode the guard exists to prevent.

**Use `sops -i` as the recovery path in the error message.** Closer to
the previous wording, but worse. `sops -i` is editor mode; the SOPS
library does not have a single equivalent (`File::SOPS::edit` is the
closest), and pointing at a sops flag that the library does not call is
misleading. The new wording says "decrypt it first," which is what
both `edit` and `rotate` do internally and what the caller can do
manually with `decrypt_file`.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23: `prove -lr t/`
runs at 75 files (the new `t/74-flat-format-keeps-its-own-sops-key.t`
included) and 1373 tests, all PASS. The interop proof (`t/04-interop.t`)
is executed rather than skipped; `t/74`'s SKIP block runs all four
binary subtests when sops is on PATH (the env file with `sops=1`
round-trips in both directions, and a sops -> rotate -> sops sequence
agrees on `sops=1` in the result). Before the fix, `t/74`'s subtest 9
dies with the format-blind guard inside `decrypt` — the guard fires on
the re-encryption `rotate` triggers below it — and subtests 4, 5, 6, 9
and 10 are RED for the reason this ADR names. After the fix, all 10
subtests pass.

Three commits, in this order:

- **BEHAVIOUR CHANGE** (`854c0ff`): `lib/File/SOPS.pm` adds
  `%RESERVES_SOPS_KEY`, moves format class resolution ahead of the
  guard, narrows the guard to the truthy set, and rewrites
  `_sops_key_reserved` to drop the `use edit / rotate` advice. The
  encrypt POD is updated to spell out the YAML/JSON-only scope. No
  other file moves.
- **TEST** (`b552b8d`): `t/74-flat-format-keeps-its-own-sops-key.t` is
  added — round-trip pin for env with `sops=1`, INI refusal pin, the
  YAML/JSON guard-still-fires regression net, rotate and
  encrypt_in_place pins, the wording pin, and the binary round-trip
  subtests. Cites k157 in the header.
- **DOCS** (this ADR + `Changes` entry): this file plus the
  `k157` bullet in `Changes`.

The ENV handler guard at line 565-570 and the INI handler guard at
line 798-803 are unchanged. `Metadata/Flat.pm` is unchanged (the
prefix split is what decided that ENV's metadata namespace is `sops_*`
and INI's is `[sops]`, and the decision is correct on both sides of
this fix). `Encrypted.pm`, `Metadata.pm`, `Backend/Age.pm`, and the
JSON handler are untouched.

Lane: api. The decision moves an argument guard in `encrypt`, which is
api-layer territory; the wire bytes do not move (every YAML/JSON test
that pins the `k18` refusal still passes byte-for-byte), and the
flat metadata encoding that decides the format-specific guard behavior
is api-visible through `%RESERVES_SOPS_KEY`.
