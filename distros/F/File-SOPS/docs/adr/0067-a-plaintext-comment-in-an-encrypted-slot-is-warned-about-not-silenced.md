# ADR 0067 — A plaintext comment in an encrypted slot is warned about, not silenced

- Status: accepted
- Date: 2026-09-01
- Resolves k173, the last open item in docs/adr/0049's *Limits*
- Reproduces the WARNING docs/adr/0049 measured and deliberately left un-emitted
- The carp precedent is docs/adr/0018 (a document warned about where it cannot
  be refused); the OUTCOME it rides on — the comment is kept, one of four bare
  shapes tolerated in a selected slot — is docs/adr/0049

## Context

docs/adr/0049 measured, across four formats, what sops does with a bare leaf in
a slot the encryption rule SELECTS. All but four shapes are refused; a plaintext
comment is one of the four that are kept, at exit 0. What that ADR reproduced
was the outcome — the comment survives, out of the digest — and it explicitly
did **not** reproduce the third thing sops does there: it warns.

That was the right call for one ADR (every other bare shape is a hard refusal,
so a warning is a third answer that did not fit the change), and it left a
question open: a comment in an encrypted slot can hold a secret in the clear,
nothing authenticates it, and this distribution said nothing. k173 asked
whether that is worth a carp. The maintainer decided it is.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient generated for the run, 2026-09-01.
A document was encrypted with `sops -e`, a plaintext comment line was inserted
into an encrypted slot by hand, and the result was fed back to `sops -d`.

| path | yaml | dotenv | ini |
|---|---|---|---|
| `sops -d` (decrypt) | **exit 0 + warning** | **exit 0 + warning** | **exit 0 + warning** |
| `sops -e` (encrypt a plaintext file that has a comment) | exit 0, silent | exit 0, silent | exit 0, silent |

The warning, verbatim:

    level=warning msg="Found possibly unencrypted comment in file. This is to
    be expected if the file being decrypted was created with an older version
    of SOPS." comment=" note"

Two facts fix where our carp goes:

- **It is a DECRYPT-path warning.** On encrypt, sops turns the plaintext comment
  into a `type:comment` leaf and says nothing (measured: the yaml comment came
  back as `ENC[…,type:comment]`). So the carp belongs on the read path, not the
  write path.
- **It is per plaintext comment**, and the comment text is echoed in sops's
  `comment=` field. We do **not** echo the text: a comment in an encrypted slot
  is exactly the thing that might be a secret, and a value that lands in a log
  was not encrypted for any practical purpose. The house refusal one branch
  away (docs/adr/0049's bare-value refusal) already declines to quote the value
  for the same reason.

## Decision

**`File::SOPS::_decrypt_tree` carps when a `File::SOPS::Comment` stands bare in a
slot the rule selects**, at the one line that already returns it unchanged —
the third of docs/adr/0049's four tolerated shapes. The carp names the path
(keys only, never the value), says the comment is neither encrypted nor
authenticated, quotes sops's own *Found possibly unencrypted comment* wording,
and names the repair (any re-encryption turns it into a `type:comment` leaf).

The carp is guarded by the same `should_encrypt_path` the branch already sits
behind, so it fires only at a SELECTED path — the scope k173 asked for. A
plaintext comment at an EXCLUDED path returns one branch earlier and stays
silent.

**Where the carp is reachable.** A plaintext comment must survive parsing into a
`File::SOPS::Comment` before `_decrypt_tree` can meet it. The dotenv and ini
handlers preserve a plaintext comment as such a leaf, so the carp fires there.
The yaml handler cannot: YAML::XS discards every plaintext comment before this
distribution sees a tree (docs/adr/0060), so there is no comment leaf in a yaml
tree to carp about. That is a pre-existing limit of the yaml handler, not a gap
this ADR opens — sops warns for yaml, but this library never sees the comment
that sops warns about.

**The discriminator that scopes it.** An `ENC[…,type:comment]` leaf is decrypted
through the cipher and also hands back a `File::SOPS::Comment` — but through the
`is_encrypted` branch, not bare in the selected slot. It is not a *plaintext*
comment and does not carp. This is what keeps the carp on the exact shape sops
warns about and off the encrypted comment sops writes itself.

## Consequences

- **Advisory only. No wire bytes move and the digest does not change.** The carp
  lives in `_decrypt_tree`, which is not the MAC path, and the plaintext comment
  it warns about is not authenticated. The regression proves both: the stored
  MAC line is byte-identical with and without the comment, and the document
  still decrypts fail-closed — a comment that had entered the digest would fail
  verification against the MAC computed without it.
- **`File::SOPS.pm` carps for the first time.** It croaks in many places and
  carped nowhere; `carp` is now imported alongside `croak`. The carp precedent
  in the distribution (docs/adr/0018, docs/adr/0050) lived in the format
  handlers until now.
- **The comment is still kept, placed and returned** exactly as docs/adr/0049
  and docs/adr/0041 leave it. Nothing about the value round-trip changes; only
  a warning is added.
- **The yaml/dotenv/ini asymmetry is now explicit.** dotenv and ini warn;
  yaml cannot, because it never holds the comment. Recorded here rather than
  papered over.

## Rejected alternatives

**Refuse the document.** sops reads it at exit 0; a refusal would refuse a
document the reference implementation accepts, and the house rule (docs/adr/0018,
docs/adr/0050) is to warn, not refuse, where sops proceeds. Also the comment is
one of docs/adr/0049's four deliberately tolerated shapes — refusing it would
reopen a decision already measured and made.

**Echo the comment text, as sops does in its `comment=` field.** Rejected: the
comment in an encrypted slot is the very thing that may be a secret in the clear,
and a plaintext value never lands in a warning here. The path (keys only) is
enough to locate it.

**Carp on the encrypt path too.** sops does not — on encrypt it silently
encrypts the comment. There is nothing to warn about there: the output is a
`type:comment` leaf, encrypted and authenticated like any value.

**Also warn for yaml by teaching the yaml handler to keep plaintext comments.**
Out of scope and a much larger change (YAML::XS discards them; docs/adr/0060
records the mapping-position half as a deliberate silent drop). This ADR emits
the warning wherever the comment survives to be seen, and names the yaml limit
rather than closing it.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this machine,
2026-09-01: a plaintext comment injected into a `sops -e` output in yaml, dotenv
and ini, read back with `sops -d` (exit 0, one warning each); and the encrypt
path confirmed silent. All fixtures are invented values; the age keypair was
generated for the run. The regression is `t/80-plaintext-comment-carp.t`.
