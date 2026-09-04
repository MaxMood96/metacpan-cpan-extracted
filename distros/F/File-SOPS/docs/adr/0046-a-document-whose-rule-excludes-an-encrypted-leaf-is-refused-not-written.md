# ADR 0046 — A document whose rule excludes an encrypted leaf is refused, not written

- Status: accepted
- Date: 2026-08-21
- Resolves k150; hands the structural half to k160 and the
  regex-dialect half to k161
- Depends on ADR 0043, which closed the reference-shaped half of the same
  defect (`encrypted_regex: []`) and filed this one rather than folding it in
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*

## Context

This distribution decrypts **ENC-driven** and encrypts **rule-driven**.
`_decrypt_tree` asks whether a leaf looks like `ENC[...]` and never consults
`should_encrypt_path`; `_encrypt_tree` asks `should_encrypt_path` and nothing
else. `file-sops-core` names the asymmetry; nothing until now measured what it
costs.

It costs a secret. Every method that does **both** halves — `rotate` and
`edit` — decrypts every leaf that looks encrypted and then writes back bare
every leaf the rule excludes.

### The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient, one document per row:

```yaml
api_key: ENC[...]                 # 'topsecret'
db:
  password: ENC[...]              # 'hunter2'
tokens: [ ENC[...], ENC[...] ]    # 'first-token', 'second-token'
note_unencrypted: public
```

encrypted under the default rule, then its rule replaced — which is what a
hand-edited section, or a `.sops.yaml` that has moved on, amounts to:

| rule the document carries | `sops -d` / `sops rotate` | `File::SOPS->rotate` | on disk afterwards |
|---|---|---|---|
| `encrypted_regex: "^nothing$"` | exit 51, *MAC mismatch* | **exit 0** | `api_key: topsecret` |
| `encrypted_suffix: _nope` | exit 51, *MAC mismatch* | **exit 0** | `api_key: topsecret` |
| `unencrypted_regex: "."` | exit 51, *MAC mismatch* | **exit 0** | `api_key: topsecret` |
| `unencrypted_suffix: word` | exit 25, *Input string public …* | **exit 0** | `password: hunter2` |
| `unencrypted_suffix: s` | exit 25, *Input string public …* | **exit 0** | `tokens: first-token` |
| `unencrypted_suffix: _unencrypted` (unchanged) | exit 0 | exit 0 | nothing bare |

**All four rule fields trigger it**, not only an `encrypted_regex` that matches
nothing: any rule that excludes a leaf which is encrypted in the file.
`edit` is affected identically — same two halves, same document, and the
plaintext is written after the editor has already been opened.

`encrypt_file` and `encrypt_in_place` are **not**: both refuse an input that
already carries a top-level `sops` entry (exit 203 at sops too), so neither can
be handed an encrypted document to re-encrypt. `decrypt`, `decrypt_file` and
`extract` write no encrypted document.

### Why sops cannot reach the same state

sops decrypts **rule-first**. A leaf the rule excludes is read as the literal
`ENC[...]` string and hashed as one, so the digest is computed over text that
does not match the stored MAC and the document is stopped before anything is
written — exit 51 in the three rows above. The two exit-25 rows are the
**other** direction of the same disagreement, reached first by sops's walk:
`note_unencrypted` is bare and those two rules select it, so sops tries to
decrypt the literal `public`.

### It does not need a hand-edited file

The rows above all start from an edited `sops` section, which makes it look
like a defect only a hand edit can reach. It is not.

`unencrypted_regex` and `encrypted_regex` are matched here by Perl and in sops
by RE2, and RE2's `\w`, `\d`, `\s` and POSIX classes are **ASCII-only** where
Perl's are Unicode-aware for any string carrying the UTF-8 flag — which is
every non-ASCII key our parsers produce. Measured end to end with one ordinary
`.sops.yaml`, an ordinary `sops -e`, and then `File::SOPS->rotate`, with no
editing anywhere:

| `unencrypted_regex` | key | sops | this library stored | rotate wrote |
|---|---|---|---|---|
| `^\w+$` | `café` | encrypts | bare | **`café: hunter2`** |
| `^n\d$` | `n٣` | encrypts | bare | **plaintext** |
| `^[[:alpha:]]+$` | `café` | encrypts | bare | **plaintext** |
| `^a\sb$` | `a<NBSP>b` | encrypts | bare | **plaintext** |
| `^\w+$` | `密` | encrypts | bare | **plaintext** |
| `^\w+$` | `plain` | leaves bare | bare | (never encrypted) |

`sops -d` reads its own output at exit 0 and reads ours at exit 25. So the
defect is **practical, not theoretical**: a `.sops.yaml` rule, a non-ASCII key,
and a rotation.

The paths that are *not* a way in were measured too. `rotate` does not read
`.sops.yaml` at all — it carries the document's own section — so changing the
config and rotating cannot reach it. `creation_rules_for` + `encrypt_in_place`
is refused by the reserved-`sops`-key guard. `sops updatekeys` re-wraps the
data key and leaves the rule field alone.

## Decision

**`rotate` and `edit` refuse a document holding an encrypted leaf at a path its
own encryption rule says is not encrypted, and name the leaf and the rule.**

`_assert_rule_covers_encrypted_leaves` walks the **stored** tree with
`_encrypt_tree`'s path rules — an array contributes no path component, the
decision is taken at the leaf against the whole path — and collects every leaf
that `Encrypted->is_encrypted` accepts and `should_encrypt_path` excludes.
Keys are walked sorted, so the path the refusal names is the same on every run.

    Refusing to rotate 'secrets.yaml': one of its values is encrypted at a
    path this document's own encryption rule (unencrypted_regex: ^\w+$) says
    is NOT encrypted -- db:password. Rotation re-encrypts the document under
    that rule, so that value would be written back into the file in
    PLAINTEXT ...

**Naming the leaf is not decoration.** The two things a caller can have got
wrong are the rule and the document, and "refused" on its own says which of
them only by elimination. The path is made of keys, which a SOPS document
leaves readable by design, so it costs no secret to print — the same rule
`_at_path` already follows.

It is asked **after** the decryption, so a document that cannot be read at all
still fails on its MAC rather than on its rule, and **before** anything is
written. In `edit` that is also before the editor is opened: refusing
afterwards would throw away what was just typed for a defect that was in the
file before it started.

**Only the direction that writes a secret out is refused.** The mirror image —
a bare leaf the rule selects — encrypts a value that was readable. Nothing goes
to disk in plaintext, so what is wrong with it is a divergence and not a
disclosure, and any check for it has to exclude the case sops itself produces:
an empty string and a null stay bare whatever the rule says, and `sops -d`
reads them at exit 0 (measured). It stays with k160.

## Consequences

- **`rotate` and `edit` now refuse documents they used to write.** For the
  documents in the first table that refusal replaces a plaintext write; there
  is no document where it replaces a correct one, because a rule that excludes
  an encrypted leaf cannot have produced that leaf.
- **This is a guard beside the problem, not the problem.** The problem is that
  `_decrypt_tree` does not consult the rule. Fixing that is k160 and it is
  the **wire lane's**: taking an excluded leaf literally puts the `ENC[...]`
  text into the digest, which moves what the MAC covers.
- **The step is monotone.** Everything this refuses, a rule-driven
  `_decrypt_tree` refuses too — on the MAC, which is exactly where sops refuses
  it — so the guard and its walker come out when k160 lands and nothing
  reopens. One case survives the removal and has to be decided there rather
  than inherited: under `ignore_mac => 1` the MAC cannot refuse anything, and
  the guard still does.
- **The regex dialect stays divergent** and is k161. The guard turns what
  it costs from a leaked secret into a refusal, which is why it is filed rather
  than fixed here: `should_encrypt_path` lives in `Metadata.pm`.
- `t/60-a-rule-that-excludes-an-encrypted-leaf-is-refused.t` pins the
  **plaintext on disk**, not the exit code, in both halves. Without the change
  it fails **49 assertions**, 16 of which name a secret that is in the file.

## Rejected alternatives

**Make `_decrypt_tree` rule-driven now.** The reference behaviour, and the
right end state. Rejected for this change because it moves what the digest
covers — an excluded `ENC[...]` leaf would go into the MAC as its own text —
and that is the wire lane's to move, not the API lane's. Handed over with the
measurement as k160, which is the pattern ADR 0024 → k76 and
ADR 0034 → k122 used: close the exposure now, hand over the mechanism.

**Refuse both directions.** Symmetric, and it states the rule more cleanly
("the rule must reproduce the document"). Rejected because the second direction
writes no secret, because it doubles the surface on which a
`should_encrypt_path` that disagrees with RE2 refuses a document sops accepts —
with k161 open, that surface is known to be uneven — and because refusing
it would leave a caller unable to rotate a file at all where today they get a
document sops reads.

**Refuse on the read side, in `decrypt`.** It is where sops refuses, and it
would cover every caller rather than the two that write. Rejected because it
*is* k160 by another name: the refusal only makes sense once the digest
sees what the rule says it should, and a read-side refusal without that would
also break `ignore_mac`'s whole purpose, which is to get data out of a damaged
file.

**Warn and carry on.** ADR 0018's shape, for a case where refusing would be
wrong. It is wrong here: the thing being warned about has already been written
by the time anyone reads the warning, and this distribution's own history —
k18, k150 — is of exactly that failure mode.

**Fix the regex dialect instead and call the hole closed.** It would close the
no-hand-editing row of the second table and none of the first. The hand-edited
and rule-replaced documents are the larger set, and a `.sops.yaml` rule can
disagree with RE2 in ways nobody has enumerated yet.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this machine,
on 2026-08-21: six rule shapes through `sops -d`, `sops rotate`,
`File::SOPS->rotate` and `File::SOPS->edit`; six regex/key pairs through a
`.sops.yaml`, `sops -e` and `File::SOPS->rotate`; `creation_rules_for` and
`sops updatekeys` on a document whose config had moved on. All fixtures are
invented values; every age keypair was generated for the run.

`SOPS_BIN=/tmp/sops prove -lr t/` is green over the whole tree at 61 files and
1262 tests, with `t/04-interop.t` **executed** against sops 3.13.3 rather than
skipped.
