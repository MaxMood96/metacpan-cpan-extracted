# ADR 0066 — A rule pattern neither dialect can compile is refused on the read path, and that residue is accepted as a limit

- Status: accepted
- Date: 2026-08-31
- Resolves k176
- Depends on ADR 0051 (which split the rule-regex refusal between the read
  and write paths and already recorded this case as a Limit), ADR 0048 (the
  construct scan and the `/a` compile), ADR 0038 (the discriminator: *does
  sops read back what sops wrote?*)
- **Moves no bytes.** Nothing is parsed, emitted or digested differently. No
  code changes. What changes is that the residue ADR 0051 left standing is
  now a decided limit with a test that pins it.

## Context

ADR 0051 made the read path reproduce sops for a rule regex RE2 cannot
compile: sops discards the compile error, so the rule matches nothing, and
`decrypt` / `extract` / `decrypt_file` answer exactly as `sops -d` does. The
split is taken by RE2's verdict, in two places in `File::SOPS::Metadata`:

1. `_re2_divergent_construct` names a construct RE2 does not have -> kind
   `unsupported` -> the `$MATCHES_NOTHING` matcher -> the read path passes.
2. Nothing is named, and the Perl compile then fails -> kind `perl` ->
   refused everywhere, read path included.

Step 2 conflates two cases that are *not* the same:

| pattern | RE2 | Perl | correct read-path answer |
|---|---|---|---|
| `(?U)fo+` | **compiles** (ungreedy flag) | rejects | **refuse** — RE2 selects keys here and this side cannot say which; guessing "matches nothing" would classify leaves wrongly |
| `fo(` | **rejects** (`missing closing )`) | rejects | matches nothing — sops reads the document at exit 0 |

So `fo(` is a document sops reads and this library does not. It is the
narrow case ADR 0048's discriminator does not reach, because both sides land
in the same Perl-compile failure and there is nothing there to tell them
apart.

## The re-measurement

sops 3.13.3 at `/tmp/sops`, one age keypair generated for the run, on
2026-08-31 against the current tree.

`fo(` as a `.sops.yaml` `path_regex` (the one place sops *reports* the RE2
verdict rather than discarding it):

```
can not compile regexp: error parsing regexp: missing closing ): `fo(`
```

A real age-encrypted document whose `sops` section carries
`unencrypted_regex: "fo("` (the suffix rule replaced by it, since the two are
mutually exclusive; the pattern excludes nothing because RE2 rejects it, so
every value stays encrypted and the MAC is unchanged):

| reader | answer |
|---|---|
| `sops -d` | `foo: bar` / `baz: qux`, **exit 0** |
| `File::SOPS->decrypt` | **refused**: *Cannot use 'fo(' as the unencrypted_regex: it is not a valid Perl regular expression (Unmatched ( in regex ...)* |

The divergence is real, loud, and one-directional: sops reads, this side
refuses. Nothing here returns a wrong plaintext quietly.

## Options considered

- **(a) A paren-/bracket-balance check** feeding the `unsupported` kind, so a
  pattern with an unbalanced group is treated as matches-nothing like sops.
  This is the only thing that could supply the positive knowledge "RE2 rejects
  it" for `fo(`. Rejected: telling balance correctly apart requires an
  escape- and character-class-aware mini-parser over the pattern text (a
  bare `(` in `[(]` or an escaped `\(` is balanced; a naive counter is not),
  a second regex parser living beside `_re2_divergent_construct`. Its errors
  fall in the **dangerous** direction: a false "unbalanced" verdict on a
  pattern RE2 *does* compile would make this side lenient (matches nothing)
  on a rule sops actually uses, misclassifying leaves silently — the one
  failure mode ADR 0051 was careful not to introduce. That trade is out of
  proportion to a malformed rule nobody has been seen to write.

- **(b) Treat every Perl-uncompilable pattern as matches-nothing.** Rejected
  outright: `(?U)fo+` is the standing counterexample — RE2 compiles it and
  selects keys, so "matches nothing" would leave leaves sops encrypts
  readable here (or the reverse), and the failure would be *silent*.

- **(c) Shell out to a real RE2 when one is present.** Rejected on its face:
  the library must not depend on the `sops` binary, or any RE2, being
  installed to decide what a leaf is.

- **(d) Accept the residue and pin it.** What ADR 0051 already does in prose.
  The failure is loud in both directions (a wrongly-refused document raises
  the dialect refusal naming the pattern; a wrongly-lenient read would fail
  on the MAC or the bare-at-a-selected-path guard), the case is unreachable
  by any well-formed rule, and the exact fix (a) is disproportionate and
  itself risky.

## Decision

Accept the residue as a limit (option d). A rule pattern **neither** dialect
can compile is refused on the read path, where sops reads it. No code
changes; the behaviour is exactly what ADR 0051 shipped. The limit is now a
decided one rather than an observation, recorded here and already stated in
the `File::SOPS::Metadata` POD (the *fourth arrived with the read path*
paragraph under **The regex rules are matched in RE2's dialect**), and pinned
by a test so a future change — if a proportionate balance check is ever built
— has a measurement to move against.

## Consequences

- The one-line change that would close it (option a) is on record as
  rejected, with the reason. Reopening `k176` means overturning that, not
  rediscovering the case.
- The pinning test measures both halves against sops 3.13.3: `sops -d` reads
  the `fo(` document at exit 0, and `File::SOPS->decrypt` refuses it naming
  the pattern. The interop half skips when no binary is found; the Perl-side
  refusal is asserted with or without one.
- No MAC, AAD, encrypted wire byte, parser, emitter or type-ladder decision
  moves.
