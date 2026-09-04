# ADR 0025 — A document that contains itself is refused, not walked

- Status: accepted
- Date: 2026-08-21
- Tags: api, guards, yaml, robustness, interop
- Resolves k110
- Related: ADR 0008 (a leaf this library cannot faithfully carry is refused
  rather than approximated — this is the same rule for a whole document)
- Opens k112 (an *acyclic* alias bomb is a separate exposure and is not
  addressed here)

## Context

`YAML::XS` resolves a recursive anchor into a real Perl cycle and hands it over
without complaint:

```yaml
root: &a
  b: *a
```

Measured: `$d->{root}` and `$d->{root}{b}` are the same hashref.
`File::SOPS::Format::YAML->parse` returns that tree, and every tree walk below
it recursed until the process was killed:

| Entry point | Walk that never returned |
|---|---|
| `encrypt`, `encrypt_file`, `encrypt_in_place` | `_sorted_leaves`, via `_compute_mac` |
| `decrypt`, `decrypt_file`, `extract`, `rotate`, `edit` | `_decrypt_tree` |

`_encrypt_tree` and `_document_leaves` carry the same defect and were simply
never reached, their siblings hanging first.

All eight public entry points were affected. A hang is the worst of the
available answers: it reports nothing, it cannot be caught by the caller, and
where the document arrived from outside it is resource exhaustion by a file.

Two walks in `File::SOPS::Format::YAML` — `_restring_non_finite_leaves`
(ADR 0023) and `_reject_comment_leaves` (ADR 0024) — already carry their own
visited sets and terminate. They were written that way deliberately, so that a
parse which returns does not become a parse which hangs. They cannot and do not
fix the walks above.

## What sops does

Measured against sops 3.13.3, which decides this and could not be derived:

```
$ sops -e --age age1… rec.yaml
Error unmarshalling file: yaml: anchor 'a' value contains itself     (exit 2)

$ sops -d enc-cyclic.yaml
yaml: anchor 'a' value contains itself                               (exit 1)
```

Both directions refuse. Two further measurements shaped the design:

- **The refusal precedes the key.** `sops -d` on the same document with no age
  identity available still reports the cycle, not `Failed to get the data key`.
  The unmarshalling error comes first.
- **An ordinary, non-recursive anchor is accepted and expanded.** `base: &b` /
  `  p: 1` / `other: *b` encrypts to two *independent* `ENC[...]` values, with
  different IVs, and decrypts back to both keys. Reusing an anchor is normal
  YAML and must keep working.

A self-referential *sequence* (`root: &a` / `  - *a`) is refused identically.

## Decision

**A container that is its own ancestor is refused, at the API boundary, before
anything is generated, unwrapped or written.**

One guard, `_assert_acyclic`, called from exactly two places:

- `encrypt`, with the other argument guards, before the data key exists.
- `decrypt`, immediately after the parse and *before* `decrypt_data_key`,
  matching the order sops answers in.

Every file-level entry point funnels through one of those two, so those two
sites cover all eight.

### Why not a visited set in the walks

That was the other obvious route, and it is a wrong answer that terminates. A
walk which skipped an already-seen node would emit a document with the alias
expanded exactly once, and a digest taken over a tree that is not the one the
file describes. The caller would get a file back, and it would be the wrong
file. Fail loud: there is no finite set of values here, so there is no document
to write and nothing honest to return.

### Why an ancestor set and not a visited set

The distinction is the whole guard. A plain visited set refuses a shared but
acyclic subtree — which is what every ordinary anchor builds, and which sops
accepts. `_assert_acyclic` therefore marks a node as *active* on the way down
and unwinds that mark on the way back up; only a node found active is its own
ancestor.

A second set, `$clean`, records nodes already proven acyclic, so a diamond is
walked once rather than once per path through it. That is not an optimisation
detail but a correctness-of-cost one: without it the guard would itself take
exponential time on a document it is supposed to accept. Measured, a 40-level
diamond (2^40 distinct paths, 81 distinct nodes) clears the guard in 0.3 ms.

### One message for two origins

A caller who hands `encrypt` a self-referential Perl structure reaches the same
guard by a different road, and no YAML anchor is involved. The message names
both origins and quotes sops's own wording for the YAML one, and says explicitly
that a merely reused anchor is not this.

## Consequences

- All eight entry points now croak, at the path where the cycle closes, instead
  of hanging. `root:b: this value contains itself, so the document has no finite
  set of values to encrypt or to hash. …`
- Nothing is written on the way out: the refusal happens before `_replace_file`
  is reached, so `encrypt_in_place` leaves the original untouched and
  `encrypt_file` creates no output.
- A document sops accepts is unaffected. Non-recursive anchors, shared
  subtrees and diamonds all still encrypt and decrypt as before.
- No behaviour that reaches the wire changes. This document neither had nor
  could have had a digest.

## Not addressed

An **acyclic** alias bomb still hangs. sops has a second guard for it —
`Error unmarshalling file: yaml: document contains excessive aliasing`,
measured on a 25-level diamond — and this library has no equivalent: the
expansion is exponential in `_sorted_leaves` and `_encrypt_tree`, and the
document is legitimately acyclic, so this ADR's guard correctly does not fire.
That is a separate exposure with a separate answer, and it is k112.
