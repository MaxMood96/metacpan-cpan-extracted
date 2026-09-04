# ADR 0055 — _path_to_aad answers ':' for an empty path, the document root

- Status: accepted
- Date: 2026-08-23
- Resolves k156
- Touches the shared AAD derivation used by every format and by the MAC
- Lane: wire

## Context

The MAC covers every leaf in a SOPS document, and the AAD under which a leaf
authenticates is `strings.Join(path, ":") + ":"` -- Go's rule. An empty
`path` is the document ROOT, where Go answers `":"`. `File::SOPS::_path_to_aad`
answered `""` instead, with an early return that fired on an undef path OR
an empty arrayref.

The divergence was latent, not live. `_encrypt_tree` and `_decrypt_tree`
start with an empty path and push a component for every key on the way down,
and every format's top level is a mapping (or for ENV, a flat list of key=
value pairs under named keys). A leaf is never at the ROOT -- it is always
under at least one key -- so the empty path was unreachable in practice.
The one place where the path component is empty in a real document is an
env comment: `Format::ENV` writes those leaves under the literal empty key
`""`, the path is `[ '' ]`, and `_path_to_aad([''])` answers `":"` -- which
matches sops and is why the round trip works.

The divergence was discovered at k36 (docs/adr/0044, measurement 3)
and filed as k156. Recorded in `Format::ENV`'s POD and in `Format::INI`'s
POD as a comment that names the four callers and explains the gap. Until
now nothing fixed it.

## The decision

The early return narrows from "undef OR empty arrayref" to "undef only",
and the `join` that already produced the joined-with-trailing-colon answer
for a non-empty arrayref now also produces `":"` for an empty one -- exactly
what Go's `strings.Join([], ":") + ":"` produces. The change is two
characters and a comment, and the only file it touches is the shared
derivation.

The empty arrayref is still unreachable in the four formats today, so no
file f-sops has ever written changes its MAC. The fix closes a latent gap
on the shared wire derivation that would otherwise have to be rediscovered
and re-measured the first time a fifth format walked a leaf at the root.

## Consequences

- The function is now deterministic on the four input shapes that matter:
  undef → `""` (caller bug, surfaces as an AAD mismatch, NOT a silent drop);
  empty arrayref → `":"` (Go's rule for the document ROOT); `[ '' ]` → `":"`
  (Go's rule for a single empty component, the env comment case);
  multi-component → joined with `":"` and trailing `":"` (Go's rule).
- No existing MAC moves. The empty arrayref case was unreachable, and an
  undef path was a caller bug whose answer `""` no caller actually depended
  on.
- The function's callers -- `_encrypt_tree` (twice, lines 3445 and 3559) and
  the MAC verification (`_compute_mac`'s leaf walk, line 3981) -- see no
  signature change. The early return is the same shape it has been, only
  with `defined $path` where `$path && @$path` was.
- `Format::ENV` and `Format::INI` POD notes that named the divergence can
  be tightened when next they are touched; their behaviour does not move.

## Limits

- The fix is for the shared `_path_to_aad` only. No caller is asked to
  change its behaviour, no format handler is asked to walk a leaf at the
  root, and no MAC is rewritten. A future format that does walk the root
  will land here and find `":"` already in place, but that future format is
  its own ticket.
- `undef` still answers `""`, deliberately. A missing argument is a caller
  bug, and answering `""` surfaces it as a loud AAD mismatch rather than
  letting it slip through as an empty AAD.

## Rejected alternatives

**Leave the early return and document it.** What the existing comment in
`_path_to_aad` and the POD notes in `Format::ENV` and `Format::INI` already
do. Cheap and safe; leaves the latent divergence on the wire. Rejected
because the divergence is in the shared derivation and the fix is two
characters.

**Answer `""` for undef too, and let the join produce `""` for empty.** A
missing argument would then look the same as an empty path, and a caller
bug would not surface. Rejected: silent AAD mismatch is the worst failure
mode in this distribution, and the early return on `undef` is what keeps
it loud.

**Add a separate `_path_to_aad_root` and call it from `_encrypt_tree` and
`_decrypt_tree` when the path is empty.** Two functions that agree by
construction is more fragile than one function that is right on every input.
Rejected.

## Notes

Measured by `prove -lr t/` against sops 3.13.3 (`/tmp/sops`) on 2026-08-23:
0 of 1351 tests moved, 0 MAC values changed, 0 interop tests skipped. The
new `t/70-a-path-to-aad-matches-gos-join.t` pins the four answers the
function can give, all five assertions passing against the same sops
binary.

Lane: wire. The single edit is in `lib/File/SOPS.pm` (`_path_to_aad`); the
single test is `t/70-a-path-to-aad-matches-gos-join.t`; the entry is in
`Changes` under `{{$NEXT}}`. `Encrypted.pm`, `Metadata.pm`, `Backend/Age.pm`
and every format handler are untouched.