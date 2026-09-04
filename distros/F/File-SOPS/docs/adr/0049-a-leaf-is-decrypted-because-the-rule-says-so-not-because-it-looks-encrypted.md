# ADR 0049 — A leaf is decrypted because the rule says so, not because it looks encrypted

- Status: accepted
- Date: 2026-08-21
- Resolves k160, the structural half of k150 that ADR 0046 closed
  with a guard and handed on
- Removes the guard ADR 0046 installed, and the walker behind it
- Depends on ADR 0048 (the two regex rules are RE2's now, so asking the rule on
  the read path asks the same question sops asks) and on ADR 0041 (a comment is
  not a value and is not digested — which turns out to have a rule-dependent
  half nobody had measured)
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*

## Context

This distribution decrypts **ENC-driven**: `_decrypt_tree` asks whether a leaf
looks like `ENC[...]` and never consults `should_encrypt_path`. It encrypts
**rule-driven**: `_encrypt_tree` asks `should_encrypt_path` and nothing else.
`file-sops-core` has named that asymmetry for as long as it has existed.

sops decrypts **rule-first**. The rule decides what a leaf *is*: a leaf the
rule excludes is a literal value, whatever its text spells, and a leaf the rule
selects must be an encrypted string.

ADR 0046 measured what the asymmetry costs — `rotate` and `edit` wrote the
plaintext of every excluded leaf back into the file at exit 0 — and closed it
with a refusal on the write path, because the structural fix moves what the MAC
covers and that is the wire lane's to move. This is that move.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient generated for the run. Every
figure below is read off the binary, not off the Go source.

### The matrix: 4 formats × 4 rule fields × 4 cells

One key, one value, one leaf per probe document, so that no cell can be reached
through another one. Each document was written by `sops -e` and then had its
rule field replaced — the whole of what a hand-edited section, or a
`.sops.yaml` that has moved on, amounts to.

| | rule SELECTS the leaf | rule EXCLUDES the leaf |
|---|---|---|
| leaf is `ENC[...]` | **exit 0**, value decrypted | **exit 51**, *MAC mismatch* |
| leaf is bare | **exit 25**, *Could not decrypt value* | **exit 0**, value read as it stands |

**All 64 cells answer the same way** — yaml, json, dotenv and ini; `unencrypted_suffix`,
`encrypted_suffix`, `unencrypted_regex` and `encrypted_regex`. Not one format
and not one rule field is an exception.

### What is in the MAC plaintext, read directly

sops prints both digests on a mismatch, which makes the digest input readable
without inferring it. For the excluded-`ENC[...]` cell:

    MAC mismatch. File has 5A625ECC…062D6, computed 08816461…D3D6B

    SHA-512("topsecret")                              = 5A625ECC…062D6
    SHA-512("ENC[AES256_GCM,data:zSM+2tEp3Ubh,iv:…]") = 08816461…D3D6B

byte for byte. The stored MAC is the digest over the plaintext (what the
document was written with); the digest sops computes is over **the literal
`ENC[...]` string**.

Confirmed from the other side as well: recomputing the document's MAC over that
literal and storing it back makes `sops -d` answer **exit 0** and print

    secret_key: ENC[AES256_GCM,data:zSM+2tEp3Ubh,iv:…,type:str]

as the value. `sops rotate` on that same document is **exit 0** too: it writes
the `ENC[...]` string back **verbatim** under a new data key and reads its own
result at exit 0. To sops the leaf is a string that happens to spell `ENC[…]`,
and it is copied through untouched.

### The exceptions — the cells that are NOT refused

A bare leaf at a **selected** path is exit 25, with four measured exceptions.
Every one of them was checked in all four formats:

| bare leaf at a selected path | sops |
|---|---|
| `null` | **exit 0**, stays null (Go's walk returns before the cipher) |
| `""` empty string | **exit 0**, stays `""` (the cipher short-circuits it) |
| a plaintext **comment** | **exit 0** and a warning, *Found possibly unencrypted comment* |
| `[]` / `{}` | **exit 0** — they hold no leaf at all |
| int / float / bool | exit 25, *Expected encrypted value as string, but got int* |
| `!!binary` | exit 25, read as a string and refused as a malformed `ENC[...]` |
| a string of spaces | exit 25 |

The first two are exactly the two shapes `_encrypt_tree` writes bare at a
selected path, which is what makes them the exceptions that matter: a document
this library wrote must keep reading.

### The exception nobody had measured: an encrypted COMMENT the rule excludes

ADR 0041 established that sops digests no comment, in seven ways. That is true
of a comment — and an `ENC[...,type:comment]` leaf at an **excluded** path is
not one. Measured by putting the same document through both hypotheses:

| digest taken over | `sops -d` |
|---|---|
| the value only, comment skipped | **exit 51** |
| the comment's literal `ENC[…,type:comment]` **and** the value's literal | **exit 0** |

and at exit 0 the comment comes back as an ordinary sequence entry holding the
`ENC[...]` text, not as a comment. It is a comment only where the rule selects
it, because only there does anything decrypt it back into one. A **plaintext**
comment at an excluded path is a comment, and stays out of the digest.

## Decision

**`_decrypt_tree` asks `should_encrypt_path`, and the answer decides what the
leaf is.** A leaf the rule excludes is returned as it stands — `ENC[...]` text
included — and the digest sees that text. A leaf the rule selects must be an
encrypted string, or one of the four exceptions, or it is refused at its path.

Three sites move with it, and they have to move together:

- **`_decrypt_tree`**, which is the change.
- **`_mac_bytes`**, which decrypted a leaf on the read side whenever it looked
  encrypted. It now does so only where the rule selects it; elsewhere the
  literal goes into the digest, which is what sops's own computed digest says
  above.
- **`_digested_leaves`**, whose wire-shaped comment test is now asked only at a
  selected path. Without that the excluded comment stays out of the digest and
  the document fails a MAC sops accepts — the one exception measured above.

The refusal in the other direction names the path and the rule and **never the
value**: a leaf the rule selects and the file holds bare is a value in the
clear, and sops's own message quotes it (*Input string topsecret does not match
sops' data format*). This one does not.

**ADR 0046's guard comes out**, with `_encrypted_leaves_the_rule_excludes`. It
refused what the MAC now refuses, one release earlier in the call and with a
better message — but it also refused two documents the MAC does not, and both
of them are documents sops reads:

- one whose MAC really is over the literal, which `sops -d` and `sops rotate`
  both take at exit 0 (measured above);
- and, under `ignore_mac => 1`, every such document.

**`ignore_mac` does not keep refusing.** It was the one case ADR 0046 said had
to be decided here rather than inherited, and the decision is that there is
nothing left for it to protect. The exposure it was installed against —
`rotate` writing an excluded leaf's plaintext to disk — is now structurally
impossible: the plaintext never enters the tree, because nothing decrypts an
excluded leaf. What `rotate` writes instead is the `ENC[...]` text, byte for
byte, which is what `sops rotate` writes for the same tree. The value is not
altered and no secret is disclosed; what is lost is the data key that could
have read it back, and the document's own rule already said that leaf was not
encrypted. Refusing it would refuse a document sops reads, rotates and reads
again — ADR 0038's discriminator, pointing the other way.

## Consequences

- **What the MAC covers changes**, for one shape of document: a leaf that is
  `ENC[...]` at a path the rule excludes now contributes its own text instead
  of its plaintext. No document whose rule reproduces it moves at all —
  measured below.
- **`decrypt` refuses documents it used to read**, at the leaf, in both
  directions. Every one of them is a document sops refuses too, at exit 51 or
  exit 25.
- **`decrypt` returns `ENC[...]` text** where the rule excludes an encrypted
  leaf and the MAC agrees, or under `ignore_mac => 1`. That is not a silent
  degradation: the caller sees ciphertext where they expected a value, which is
  the same thing `sops -d` prints.
- **`rotate` and `edit` no longer refuse a rule that does not cover what is
  encrypted.** They fail on the MAC instead, in `decrypt`, which is where sops
  fails. The message loses the leaf's path and gains the leaf count; the ticket
  for a better MAC message is where that belongs, not a guard.
- **The second direction is closed by the same move.** A bare leaf the rule
  selects used to be read as a literal and silently **encrypted** on the next
  write. It is now refused where sops refuses it, and it fell out of the same
  branch rather than out of a guard of its own.
- **A caller's plain string that spells `ENC[...]` now round-trips** at an
  excluded path. `_encrypt_tree` wrote it verbatim and hashed it verbatim
  already; the read side then tried to decrypt it and died on a document this
  library had just written. That is fixed as a side effect.
- **`decrypt` and `extract` now consult the two regex rules**, so ADR 0048's
  refusal reaches them. See *Limits*.

## Limits

Three, all measured, none of them closed here.

- **A rule RE2 cannot compile now stops the read path too.** ADR 0048 refuses a
  pattern the two dialects do not share, *at the point of use*, and listed
  `decrypt` and `extract` as paths that stay open because neither consulted the
  rule. Both consult it now. Measured: a document carrying
  `unencrypted_regex: "(?=foo)"` is read by `sops -d` at **exit 0** — sops
  discards the compile error, so the rule matches nothing and every value is
  decrypted — and is now refused here. Nothing is written and nothing leaks,
  but it is a sops document this library used to read. **Rule policy is the API
  lane's**, so it is handed over rather than decided here: k171.
- **An INI comment bucket at an excluded path.** `_adds_no_path_component`
  recognises a `''` key holding nothing but comments. At an excluded path the
  bucket now comes back holding `ENC[...,type:comment]` strings instead of
  `File::SOPS::Comment` objects, so a re-encryption no longer recognises it and
  the bucket key would add a path component. Reachable only through
  `ignore_mac => 1` plus `rotate`/`edit` on an ini document whose rule excludes
  a section that has comments in it. k172.
- **We do not warn about a plaintext comment at a selected path.** sops does
  (*Found possibly unencrypted comment in file*), at exit 0, and keeps the
  comment. We keep the comment and say nothing. k173.

## Rejected alternatives

**Keep the guard for `ignore_mac` only.** The one case ADR 0046 left open, and
the smallest possible answer to it. Rejected on the measurement: `sops rotate`
writes exactly what our rotate would write for the same tree, and reads it back
at exit 0, so the guard would refuse a document the reference implementation
takes. It would also keep a walker alive whose entire remaining job is one flag
combination — and a second walk over the tree with `_encrypt_tree`'s path rules
is precisely the shape of duplication ADR 0046's own comment warns about.

**Refuse an excluded `ENC[...]` leaf outright, on the read path.** Loud, and it
names the leaf. Rejected because sops reads that document at exit 0 whenever
the MAC agrees, and because it would close `ignore_mac`'s whole purpose for the
files most likely to need it.

**Reproduce sops's warning instead of refusing the second direction.** ADR
0018's shape. Rejected: sops does not warn there, it stops at exit 25, and a
value that is bare where the rule says it is encrypted gets **encrypted** on
the next write — a readable value silently turned into ciphertext under a key
the caller may not keep.

**Give `should_encrypt_path` a lenient mode for the read path**, so that a
pattern RE2 cannot compile matches nothing there exactly as it does at sops,
and the read path stays open. Measured to be correct — that really is what sops
answers — and rejected *here* rather than on its merits: it is a second answer
out of the one predicate `_encrypt_tree`, `_compute_mac`, `mac_only_encrypted`
and now `_decrypt_tree` all share, on the most load-bearing change in this
layer, and it is rule policy. k171 carries it, with the alternative of
moving ADR 0048's refusal out of `_rule_qr` and onto the write path explicitly,
which is what ADR 0048 §3 already says it is.

**Take the type from the leaf rather than from the rule** — decrypt what parses
as `ENC[...]`, and only ask the rule when the two disagree. It is the current
behaviour with a guard attached, it cannot produce sops's digest for the
excluded-`ENC` cell, and it is the defect class this whole file exists to
remove: two ways of answering one question, agreeing on every document this
library writes and on nothing else.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this machine,
on 2026-08-21: the 64-cell matrix through `sops -e` and `sops -d`; twelve bare
value shapes at a selected path; both comment-digest hypotheses through a
recomputed MAC; `sops rotate` and `sops -d --ignore-mac` on a rule-swapped
document; the excluded-`ENC` digest read straight off sops's own
*MAC mismatch* line and reproduced with `Digest::SHA`. All fixtures are
invented values; the age keypair was generated for the run.

The corpus comparison is in the k160 report: 208 documents across the four
formats, produced by sops and by this library, with and without
`mac_only_encrypted`, under six well-formed rules and eight rule swaps, diffed
leaf by leaf on AAD, MAC plaintext and decrypted value.

`SOPS_BIN=/tmp/sops prove -lr t/` and the interop run are quoted in the same
report.
