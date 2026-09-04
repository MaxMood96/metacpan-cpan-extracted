# ADR 0060 — A mapping-position YAML comment is dropped silently on a write, and the asymmetry with the sequence position is deliberate

- Status: accepted
- Date: 2026-08-23
- Resolves k169
- Lane: format
- Depends on **ADR 0041** (the sequence-position guard that defines what
  "refused loudly" looks like here) and **ADR 0041's two-tracker POD in
  `File::SOPS::Format::YAML`** (which already names the asymmetry this ADR
  records as a decision). The work this ADR records is the decision itself;
  the asymmetry was measured against sops 3.13.3 in k148, before karr
  k169 was filed.
- **Moves no bytes.** Every behaviour described here is today's behaviour.
  This ADR records it as deliberate so a future reader does not mistake it
  for an accident of where YAML::XS drops comments, and so the asymmetry
  cannot regress silently when the read-side repair below eventually lands.

## Context

sops attaches a YAML comment to the node that **follows** it. Above a
mapping key the comment stays a comment line (`#ENC[…,type:comment]`); above
a sequence entry there is no comment line to write, so sops emits the
comment as a real element (`- ENC[…,type:comment]`). That gives two
positions a sops document can carry a comment in, and the two positions
behave differently here.

k169's measurement against sops 3.13.3, reproduced on this branch:

| document | `sops -d` | this library's `decrypt_file` |
|---|---|---|
| A: file-leading comment, comment above a mapping key, comment above a sequence entry | exit 0, all three comments back | **REFUSED** — `list:0: cannot write a sops comment into this document…`, no output file |
| B: file-leading comment, comment above a mapping key, **no** sequence | exit 0, both comments back | **exit 0**, plaintext written, **neither comment in the output** |

So the same loss — a sops comment present in the file, absent from the
plaintext this library writes back — is **loud** in one position and
**silent** in the other, and which one a caller gets depends on whether
the document happens to contain a sequence.

## Why the asymmetry exists

YAML::XS (libyaml) discards comment text **before** `parse()` ever sees a
tree. The mapping-position comment is therefore not in `$data` for any
guard to refuse: the tree is the values, with no trace of the comment (t/63
subtest 2 pins this). The write path proceeds with the values it has, and
the comment is gone — silently, at exit 0.

The sequence-position comment is in the tree as an `ENC[…,type:comment]`
leaf (ADR 0041 keeps it), and `_reject_unwritable_leaf` in
`File::SOPS::Format::YAML` croaks at it because `YAML::XS` cannot emit a
comment at all. The refusal names the path, and `decrypt_file` / `edit`
write nothing.

The two positions are not the same thing for two reasons:

1. **The data is there in one case, gone in the other.** A sequence
   element reaches `parse`; a mapping-position comment line does not.
   Nothing in the tree model can see what was discarded.
2. **The asymmetry is already sops's own.** `sops -e --output-type json`
   drops mapping-position comments too (k148 / ADR 0041 row 1, last
   column): the JSON emitter has no place for them either. We are not
   making this worse than what sops does to its own YAML-to-JSON round
   trip; we are mirroring the same loss.

## Decision

**Doing nothing is the answer.** Today's behaviour is the behaviour this
ADR records as deliberate, for the three reasons below.

### 1. Making B loud would refuse a document sops reads at exit 0

The k169 body itself names this:

> Making B loud too would refuse a document sops reads, and would need
> the read half of k148 (YAML::PP's raw token stream) purely to
> power a refusal.

ADR 0041 made the sequence-position equivalent loud on the same trade —
a document `sops -d` reads at exit 0 is refused by `decrypt_file` and
`edit`. The asymmetry, on the loud side, is "we cannot write the comment
back" (true for both positions). On the silent side, the asymmetry is "we
do not even see the comment" (true for the mapping position only). The
two refuse-for-different-reasons, and only one of them can be refused at
all today.

A loud guard on B would need the comment text in the first place, and the
comment text is not in the tree. YAML::PP's parser keeps it in its raw
token stream (ADR 0041 / k148's measurement), but a recovered
comment has nowhere to go: a sequence comment is preserved because a
**sequence element** is a slot the tree model already has, and a mapping-
position comment sits **before a key**, where a Perl hash has no slot.
The recovery work is the read half of k148 — a sizeable refactor
whose deliverable is a comment that lands in the tree, not in a refusal.

### 2. Making A quiet would undo ADR 0041's decision

ADR 0041 made the sequence-position comment loud because the leaf was in
the tree as an `ENC[…,type:comment]` string and the write path was
**silently dropping the comment** from the plaintext output (the prior
behaviour, k108's defect). The decision was loud-or-silent, not
loud-or-perfect: a comment in the tree is either refused by name or
dropped without a word, and ADR 0041 chose the refusal because the
information was available to refuse. Undoing that to make A and B
symmetric is to re-introduce k108 in a different position.

### 3. The asymmetry is already documented and the loss is recoverable

A caller who needs a mapping-position comment back has two measured
paths:

- **`File::SOPS->decrypt` returns the value tree** — the tree that does
  not see the comment either, since the comment is not in the parse
  result — and **`File::SOPS->extract` reaches any value**, neither of
  which restores a comment because there is no comment in their input.
  The data is recoverable; the comment is not.
- **`sops -d` reads the file at exit 0 with the comment intact**, which
  is the reference behaviour and the only way the mapping-position
  comment survives at all today, on either side.

The current `Format::YAML::parse` POD section "A comment inside a list is
kept" already names the asymmetry in the prose this ADR generalises:

> A document whose comment is a sequence element is **refused** by
> `emit` -- which is what makes `decrypt_file` and `edit` refuse it
> rather than drop it -- while a document whose only comment is above a
> mapping key is written back **silently without it**. `sops -d` returns
> both comments intact for both documents.

This ADR records that prose as the decision, with the k169
measurement and the architectural reason behind it — so a future reader
who meets the asymmetry does not mistake it for an accident of where
YAML::XS drops comments.

## Consequences

- **`decrypt_file` and `edit` write plaintext without mapping-position
  comments, at exit 0, today and from now on.** The loss is silent. The
  data, the MAC and the AAD are unaffected.
- **`decrypt`, `extract`, `rotate` and `edit` itself** behave as they
  always have: the comment is not in the parse result, so there is no
  leaf for them to act on.
- **The asymmetry is pinned by `t/74-a-mapping-position-yaml-comment-is-dropped-silently.t`**, which
  asserts both halves of the measurement against sops 3.13.3: the
  sequence-position document is refused by name, the mapping-only
  document is written without error and without the comments. The test
  fails under any future change that makes the sequence-position case
  silent or the mapping-position case loud.
- **The mapping-position comment is still open as a half of k148**,
  the ticket ADR 0041 named and k148 measured. When the read half
  of k148 lands — a YAML::PP raw-token recovery with somewhere for
  the comment to live — the silent loss this ADR records as deliberate
  becomes a recoverable one, and a future ADR will replace this one.

## Rejected alternatives

**Make B loud.** The mirror of the decision, and what a fail-loud reading
of k169 would reach for. Refused for the same reason ADR 0041's
guard is loud where it can be: refusing requires the data. The comment is
in YAML::PP's raw token stream, but a guard that fires on its presence is
a refusal fired on data the parse did not retain, with no caller-visible
recovery and a sizeable refactor (k148) upstream of it. It also
moves an asymmetry that is **already sops's own** in the YAML→JSON round
trip (k148 / ADR 0041 row 1), in a worse direction for this library:
sops drops the comment at the format boundary, this library would die.

**Make A quiet (drop the sequence-position refusal).** Undoes ADR 0041
and re-opens k108's defect at a different position. Rejected on the
same grounds ADR 0041 rejected it: the data is in the tree, the loss
would be silent, and a `decrypt` + `encrypt` cycle would make it
permanent with every party reporting success.

**Read the source bytes for `#ENC[…,type:comment]` lines and refuse on
their presence.** The text-surgery form of "make B loud", and the class
ADR 0019 rejected: a regex over the raw text, on the read path, where a
mis-hit refuses a document whose comment line the regex happens to
match. ADR 0028's conditions for permitted surgery (one fixed token,
reconciled against a second parser before the result is used) are met by
none of the work — k148 measured this and the half that would
power a refusal is the half that has nowhere to put the comment.

**Re-render the document through `sops -d` after `decrypt_file`.** A
different kind of recovery: the mapping-position comment survives `sops
-d`, and a write-then-decrypt pair could in principle preserve it.
Refused because it asks the caller to have `sops` on `PATH`, because
`decrypt_file` is not supposed to be a foreign-process wrapper, and
because it does not survive `edit` (the editor writes plaintext, not
ciphertext, and the round trip is different).

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23 from a scratch
copy of the tree at `078f4c0`: two plaintexts encrypted by `sops -e`,
decrypted by both `sops -d` (exit 0, comments back) and `File::SOPS::
decrypt_file` (sequence case refused with `list:0: cannot write a sops
comment…`, mapping-only case exit 0 with no comments in the output).
Reproduced before this commit on the worktree at
`.claude/worktrees/sops-169`.

The deliverable is the ADR (this file), a `Changes` entry, and
`t/74-a-mapping-position-yaml-comment-is-dropped-silently.t`. No code in `lib/`
moves. The existing `Format::YAML::parse` POD section "A comment inside
a list is kept" already names the asymmetry in prose and stays as-is.
Lane: format. Wire as second reader: nothing in the encrypted wire format
moves, and the `_is_comment_leaf` / `_digested_leaves` exclusion (ADR
0041) is unchanged.
