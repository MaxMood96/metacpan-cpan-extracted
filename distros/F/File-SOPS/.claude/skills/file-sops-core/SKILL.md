---
name: file-sops-core
description: "Load before editing File::SOPS — the pure-Perl Mozilla SOPS implementation: AAD and path derivation, MAC ordering, type detection, Go-compatible value serialization."
---

# File::SOPS — core

Pure-Perl implementation of the Mozilla SOPS encrypted-file format, byte-compatible
with the Go reference implementation (`github.com/getsops/sops`). Interop is the whole
product: every design choice here exists because Go does it that way.

## Module map

| Module | Owns |
|---|---|
| `File::SOPS` | public API (`encrypt`/`decrypt`/`encrypt_file`/`decrypt_file`/`extract`/`rotate`), tree walk, path→AAD, MAC |
| `File::SOPS::Encrypted` | one `ENC[...]` value — parse, encrypt, decrypt, type (de)serialization |
| `File::SOPS::Metadata` | the `sops:` section — backends, mac, lastmodified, version, encryption rules |
| `File::SOPS::Backend::Age` | data-key encryption via `Crypt::Age` (the only backend implemented) |
| `File::SOPS::Format::{YAML,JSON}` | parse/serialize, split off and re-attach the `sops:` section |

Everything is `Moo` + `namespace::clean`. The public API is class methods on
`File::SOPS`, not instance methods.

## The wire format

```
ENC[AES256_GCM,data:<b64>,iv:<b64>,tag:<b64>,type:<str|int|float|bool|bytes>]
```

Parsed and matched by one regex in `File::SOPS::Encrypted` (`$ENC_REGEX`, anchored).
`is_encrypted` and `parse` share it — keep them sharing it.

## Invariants that interop depends on

Break any of these and the file still *looks* fine, still round-trips through this
library's own tests, and fails against the real `sops` binary.

1. **AAD is the path, colon-joined, with a trailing colon.** `database:password:` for
   `{database}{password}`. Empty path → empty AAD.
2. **Arrays do not contribute a path component.** Every element of an array shares the
   *parent's* path — no index. `_encrypt_tree`/`_decrypt_tree`/`_build_enc_path_mapping`
   all implement this; they must stay in agreement.
3. **The IV is 32 bytes**, not the AES-GCM-conventional 12. SOPS-Go uses a 32-byte
   nonce. (`=attr iv` in the POD said 12 for two releases; it now says 32 and explains
   why. Do not "correct" either back.)
4. **Booleans serialize Go-style titlecase**: `True` / `False` — on the wire *and* in
   the bytes fed to the MAC digest. Never `1`/`0`, never lowercase.
5. **The type comes from the scalar, never from its text** — `Encrypted->detect_type`:
   `JSON::PP::Boolean` → bool; public `SVf_IOK` → int; public `SVf_NOK` → float; else
   str. SOPS types a value by what the *parser* returned, and YAML::XS and
   Cpanel::JSON::XS both preserve the SV's string-vs-number distinction, so a quoted
   scalar is a string end to end. Verified against sops 3.13.3: bare `false` →
   `type:bool`, but quoted `"false"`, `"true"`, `"1"`, `"0"`, `"007"`, `"1.50"` are all
   `type:str`. Perl's own literals set the same flags, so `5432` is int and `'5432'` is
   str for a structure passed straight to `encrypt`. Decided in **ADR 0002**;
   read it before changing any of this.

   Two things follow, and both are load-bearing:

   - **Do not pattern-match a value's text anywhere.** `looks_like_number`, `/^\d+$/`
     and `$v eq 'true'` are all the defect this replaced. And do not read the *private*
     `SVp_IOK`/`SVp_NOK`: those are set by merely reading a string numerically, so a
     caller's `if ($h{port} > 1024)` would retype the document.
   - **A numeric plaintext is canonical, not the source spelling.** Go re-derives the
     digest input from the type, so `007` under `type:int` must be written `7` and
     `1.50` under `type:float` must be written `1.5` (`strconv.Itoa` /
     `strconv.FormatFloat(v,'f',-1,64)`, the latter reimplemented in
     `Encrypted::_float_bytes`). Writing the source spelling makes `sops -d` reject the
     whole file. A *string* is always written verbatim.

   **There is now ONE ladder and ONE conversion**, `Encrypted->detect_type` and
   `Encrypted->value_to_bytes`; `SOPS::_value_to_bytes` delegates and
   `SOPS::_detect_type_for_mac` is gone. Keep it that way — a second copy is how this
   distribution produces files that verify against themselves and against nothing else.
6. **`bool` deserializes to `JSON::PP::Boolean`** (`JSON->true` / `JSON->false`), not to
   `1`/`0`, so that YAML::XS (with `$YAML::XS::Boolean = 'JSON::PP'`) and JSON::MaybeXS
   emit real `true`/`false` on re-serialization. A plain `1` here silently degrades
   every bool in the file to an int on the next write.
7. **Empty and undefined leaf values are not encrypted** — they serialize as `''`.
8. **Everything hashed or encrypted is UTF-8 bytes, encoded UNCONDITIONALLY** —
   `_aad_bytes` for the AAD, `_utf8_bytes` for the value. Neither reads Perl's UTF-8
   flag, and **nothing here may start reading it**. Below U+0100 that flag is storage,
   not meaning: `"caf\x{e9}"` may be held as one byte or as two, Perl considers both
   the same string, and `YAML::XS::Dump` / `JSON::MaybeXS(utf8 => 1)` write both to
   the file as `caf\xc3\xa9`. Anything that consults the flag disagrees with the bytes
   our own emitter wrote, and the document fails *its own* MAC on the next read.

   Both halves were flag-guarded once and both were bugs (**ADR 0003**; the
   AAD half landed a release earlier). Measured with an unflagged `"caf\x{e9}"`:
   an **unencrypted** value went into the document as UTF-8 and into the digest as
   Latin-1, so `sops -d` reported `MAC mismatch`; an **encrypted** one was
   self-consistent — invisible from inside Perl — but came back out of `sops -d` as
   `!!binary Y2Fm6Q==` instead of `café`.

   - **The one exemption is `type:bytes`**, which is not text: no encode on the way
     in, no decode on the way out. It is also the *only* way a caller can say that an
     unflagged scalar really is bytes, since Perl does not make that distinction.
   - **The cost, accepted deliberately:** a caller passing UTF-8 *bytes* is now
     double-encoded. The emitters were already doing that to such a caller's
     unencrypted values, so it was never a whole guarantee — see ADR 0003 for why the
     ambiguity can only be resolved once, and the same way, everywhere.

9. **The API boundary is characters, the wire is UTF-8 bytes, and the library encodes
   exactly once.** Keys, values, `extract` paths and everything `decrypt` returns are
   character strings. Two documented exceptions come back as bytes rather than being
   mangled: `type:bytes` (SOPS's binary type) and a `type:str` whose plaintext is not
   valid UTF-8.

## The MAC — and its ordering dependency

The MAC is a SHA-512 over the **plaintext values only** (no keys, no paths), uppercase
hex, then itself AES-GCM-encrypted with **`lastmodified` as AAD** and stored as an
`ENC[...]` string in the `sops:` section.

**Every value goes into the digest, encrypted or not** — matching the Go reference —
unless `mac_only_encrypted` is set, which switches to encrypted values only behind a
32-byte `MACOnlyEncryptedInitialization` prefix that keeps the two settings' digests
apart. That prefix appears nowhere but the reference source.

Both directions funnel through `_mac_digest`. What differs is only how leaves are
collected and where the order comes from:

| Direction | Leaves | Order |
|---|---|---|
| encrypt | the live tree | `sort keys %$node` |
| decrypt | the parsed tree, walked in parallel | an order-preserving reparse (YAML::PP, `PRESERVE_ORDER`) |

Perl hash order is randomized and the MAC is order-dependent, so the decrypt side must
recover order from the document. It used to scrape `ENC[...]` strings out of the raw
text with a regex; that could not see unencrypted values and so could not place them.
**ADR 0001** records why YAML::PP supplies order and nothing else — values still come
from the real tree, and YAML::XS / JSON::MaybeXS remain the parsers and emitters. The
metadata MAC is excluded structurally by dropping the `sops` branch, not by matching
`mac:` in text (which used to swallow any user key ending in `mac`).

**The encrypt side still depends on the emitters sorting keys** — `YAML::XS::Dump`
sorts, `File::SOPS::Format::JSON` sets `canonical => 1`. That is load-bearing and
`t/05-format-key-order.t` pins it: a serializer that emits insertion order breaks
verification for self-produced files, and the failure surfaces as `MAC verification
failed`, nowhere near the cause.

**What a leaf contributes is the authenticated plaintext**, from
`File::SOPS::Encrypted::decrypt_bytes`, with only the bool titlecase rule applied —
never a re-serialization. Hashing a value after Perl's numeric conversion is what made
`'007'` hash as `007` on write and `7` on read.

Verification **fails closed**: a missing, malformed or undecryptable MAC dies. Callers
that need the old lax behaviour pass `ignore_mac => 1` to `decrypt`, `decrypt_file`,
`extract` or `rotate` — that returns data which is decrypted but *not authenticated*,
and exists mainly to rescue files damaged by the pre-0.003 boolean bugs.

## Metadata section

`to_hash` always emits `kms`, `gcp_kms`, `azure_kv`, `hc_vault`, `age`, `pgp` — empty
arrays included, because the Go implementation expects the keys to exist. Optional
fields (`lastmodified`, `mac`, `version`, the four encryption-rule fields) are emitted
only when defined. `version` defaults to `3.7.3`.

Encryption rules: `unencrypted_suffix` (default `_unencrypted`) marks keys that are
**not encrypted but still hashed into the MAC**; `encrypted_suffix`,
`unencrypted_regex` and `encrypted_regex` are the other three. `should_encrypt_key`
answers for one key, `should_encrypt_path` for a whole path — the second is the one
the walks ask.

**The rule decides what a leaf *is*, in both directions (ADR 0049, since 0.003).**
`_encrypt_tree` and `_decrypt_tree` both consult `should_encrypt_path`, and the leaf's
own text gets no vote. This *reversed* the asymmetry this document described for most
of its life — decryption used to be driven purely by whether a leaf matched `ENC[...]`
— so anything you remember about ENC-driven decryption is out of date. Two
consequences, both measured against sops and both caller-visible:

- A leaf the rule **excludes** is a literal value whatever it spells. An `ENC[...]`
  string there is *not* decrypted, and the digest covers that text rather than the
  value behind it — so a document whose rule excludes an encrypted leaf fails its own
  MAC, exactly as sops fails it (exit 51).
- A leaf the rule **selects** must be encrypted; a bare one is refused at its path
  (sops: exit 25). Four shapes stay bare because sops leaves them alone: an `undef`,
  an empty string, a comment, and an empty list or mapping.

Because both walks now ask the same predicate, a path component one adds and the other
does not is a document this library writes and then cannot read. That is why
`_adds_no_path_component` exists and why every walk that builds a path goes through it.

**The two regex rules are matched in RE2's dialect, not Perl's (ADR 0048/0051).** A
pattern RE2 cannot compile matches *nothing* on the **read** path — sops discards the
compile error, so that answer is reproducible and is reproduced — and is refused on the
**write** path, where handing a caller "matches nothing" for `encrypted_regex` would put
every secret on disk in plaintext at exit 0. A pattern both dialects compile and read
*differently* (`\v`, `\Q`, `\E`), or one Perl cannot compile at all (`(?U)`), is
refused everywhere: there is no sops answer to reproduce.

## Verification — read this before saying "tests pass"

```bash
prove -lr t/          # recursive; -r matters if subdirs ever appear
dzil test             # recursive by construction
```

**`t/04-interop.t` is the only test that proves compatibility with SOPS** — round-trips
in both directions (Perl→sops, sops→Perl), YAML and JSON, types, unicode, nested
structures. It finds a binary via `$SOPS_BIN`, then `PATH`, then `/tmp/sops`, and only
skips when none of the three yields one. A `$SOPS_BIN` that is set but not executable
is a hard failure, not a fall-through to something nobody chose.

**Check the run, not the summary.** `t/04-interop.t` is no longer the only file that
drives the binary — most files added since `t/34` do — so a missing binary now quietly
subtracts hundreds of assertions from the whole suite, not twenty from one file.
Measured 2026-08-22: **1325 tests with the binary, 1107 without**, and the run reports
`All tests successful` either way. That gap is the entire compatibility proof, and it
does not announce itself. `ls -l /tmp/sops` before you believe a green run. This is
exactly how two releases shipped a library whose every YAML file sops rejected. When
the test runs it prints the binary and version it used; quote that when you claim
compatibility.

If a binary is missing, `maint/fetch-sops` installs the pinned version (needs a Go
toolchain). A release without a real interop run is a release of untested compatibility
claims.

## Deliberate gaps

`CLAUDE.md` is the original design document and still describes a little more than
exists. Not implemented today: every backend other than age — PGP, KMS, GCP KMS,
Azure KV, Vault (the metadata fields for them exist and round-trip, the
encryption does not), and that gap is **parked on a maintainer decision**, not merely
undone. All four format handlers exist: YAML, JSON, ENV/dotenv and INI,
the last two since 2026-08-21. Treat `CLAUDE.md` as a roadmap, not as a
description of the code.

`.sops.yaml` creation rules **do** exist now (`creation_rules_for`). Two
things about them are easy to get wrong: `path_regex` matches the path relative to
the **config file's directory**, not the absolute path, and the search for the
config runs upward from the **file's** directory where sops searches upward from
the **working directory**. The second is a deliberate divergence and the only one
in this distribution that can change *who can read a secret* — it is pinned in
`t/04-interop.t`, which asserts both behaviours side by side, and is open for the
maintainer to confirm or revert.

`encrypt_in_place` and `edit` do exist. **Every** method that writes a file now goes
through `_replace_file` — temp file next to the target, then `rename` — so a failure
part-way leaves the original intact (this closed a real bug: `encrypt_file`,
`decrypt_file` and `rotate`, which used to open the target with `>` and check neither
the `print` nor the `close`). The cost is a new inode: hard links keep the old
content, and replacing a file needs write permission on the *directory*. A target
that exists and is not a regular file (`/dev/stdout`, a fifo) is written through
directly instead.
`edit` re-encrypts under a **new data key**, where `sops edit` keeps the existing one,
which is why it refuses the same foreign-key-material documents `rotate`
refuses.
