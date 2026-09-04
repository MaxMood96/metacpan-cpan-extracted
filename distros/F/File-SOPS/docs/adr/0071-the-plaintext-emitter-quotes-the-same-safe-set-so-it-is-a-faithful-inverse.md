# ADR 0071 — The plaintext emitter quotes the same safe set, so it is a faithful inverse

- Status: accepted
- Date: 2026-09-01
- Tags: yaml, emitter, wire-format, interop, plaintext
- Resolves k186
- Extends ADR 0070 (the scoped per-scalar quote), which deliberately scoped the
  plaintext path **out** and named this gap for a follow-up. This is that
  follow-up, and it reuses ADR 0070's mechanism unchanged
- Depends on ADR 0026/0034 (a plain non-finite scalar is a float, a quoted one a
  string — the distinction this relies on), ADR 0013/0018 (the plaintext
  emitters install no foreign-resolution guard, deliberately)

## Context

ADR 0070 taught the emitter to double-quote a safe set of divergent leaves — the
`True`/`False` type divergence and the seven parse-unambiguous non-finite str
spellings (`.inf .Inf .INF +.inf -.inf .nan .NaN`) — but only on the
**MAC-covered** write path, where a bare leaf makes a document fail its own MAC.
It scoped the plaintext emitters (`decrypt_file`, `edit`) out, because there is
no MAC there to protect.

k186 measured the cost of that scope-out. sops writes such a string
double-quoted; the plaintext emitter wrote it **bare**:

```
sops -d        x_unencrypted: ".inf"   (str, quoted)
decrypt_file   x_unencrypted: .inf     (bare)
```

The read is correct — the library reads `str ".inf"` with the MAC verified — but
the plaintext write-back loses the quote, so a `decrypt_file` → re-encrypt round
trip flips the leaf from string to float: a bare `.inf` resolves to `+Inf` at the
next parse (ADR 0026). **`decrypt_file` is not a faithful inverse for this leaf
class**, and `edit` inherits the same gap (the editor is shown a bare `.inf`,
and saving it unchanged re-encrypts a float where the document held a string).

## What sops does

Measured, sops 3.13.3, one age recipient, YAML, leaf in an unencrypted slot:

| encrypted document holds | `sops -d` writes | round-trips as |
|---|---|---|
| a `str` `.inf` / `.nan` / `-.inf` | `".inf"` / `".nan"` / `"-.inf"` (quoted) | string |
| a `str` `True` | `"True"` (quoted) | string |
| a `type:float` `+Inf` | `.inf` (bare) | float |

sops's own `-d` writes exactly the double-quoted form for the string case and
the bare token for the float case. A faithful inverse writes what sops writes.

## Decision

**The plaintext emitter quotes the same safe set ADR 0070 quotes, by the same
fail-closed sentinel mechanism. Force-quoting now runs on every `emit` path
except `mac_only_encrypted` (warn).**

Concretely, the one gate in `File::SOPS::Format::YAML::emit` changes from
"quote only when `mac_covered`" to "quote unless `warn_foreign_resolution`":

```perl
my $force_quote = !$args{warn_foreign_resolution};
```

- **MAC-covered** (ADR 0070): unchanged — quoting is what lets a document that
  would fail its own MAC be written.
- **Plaintext** — `decrypt_file`, `edit`, which call `emit($data)` with no
  arguments (k186): now quotes the same safe set, so the emitter writes what
  sops writes.
- **mac_only_encrypted** (warn): the one exception, kept as ADR 0070 left it. The
  document already works and the leaf is not MAC-covered, so its bytes are
  unchanged.

Everything downstream of the gate — `_is_quotable_leaf`,
`_sentinel_quotable_leaves`, `_quote_sentinels`, `_yaml_double_quote` — is
reused **unchanged**.

### Why it is safe on the plaintext path

1. **No digest to move.** The plaintext output is never hashed (`decrypt_file`
   writes it to disk; `edit` hands it to `$EDITOR`), and the MAC-covered digest
   is computed over the original tree in `File::SOPS::_compute_mac` **before**
   `emit`. So quoting moves no digest byte on any path it runs.

2. **The safe-set predicate needs no guard and no MAC state.**
   `_is_quotable_leaf` keys on `_foreign_resolution_token` (the `type` verdict
   for `True`/`False`) and `%QUOTABLE_NON_FINITE` + `detect_type eq 'str'` for
   the rest. Both are pure functions of the leaf — verified reachable on the
   plaintext path, where no `reject_scalar` is installed.

3. **The float carrier stays bare — the case that must not move.** A decrypted
   `type:float` `+Inf` is a `dualvar(+Inf, '.inf')`: `SVf_NOK` is set, so
   `detect_type` is `float`, so `_is_quotable_leaf` returns 0 and it is written
   **bare** `.inf` (ADR 0031/0040 — the token go-yaml resolves back to the float).
   Only a leaf `detect_type` calls `str` is quoted. Measured: a bare `.inf` that
   is a `type:float` in both slots stays bare through `decrypt_file` and
   re-encrypts as `type:float`; a `str ".inf"` is quoted and re-encrypts as a
   string.

4. **Fail-closed holds identically.** Any sentinel miss or re-`Load` mismatch
   falls back to today's bare emit — a faithful-inverse *gap*, never a corrupt
   file.

## Consequences

- **`decrypt_file` and `edit` are now faithful inverses for this leaf class.**
  Measured end to end against sops 3.13.3: `sops -e` a quoted `".inf"`, `".nan"`,
  `"-.inf"`, `"True"` → `decrypt_file` writes them double-quoted (byte-identical
  to `sops -d`) → re-encrypt → `sops -d` reads strings. A bare float `.inf`, a
  normal string, and a bare number are unchanged.
- **Multi-document plaintext is covered too** — the sentinel walk runs per
  document, and a quotable leaf in document 2 of a decrypted stream is quoted
  there (verified via `emit` directly).
- **No wire byte moves on any MAC-covered document.** This changes only the
  plaintext emit path; the encrypt path is exactly ADR 0070.
- **One existing test assertion is invalidated**, for routing to the test lane:
  `t/35`'s "the plaintext emitters stay silent" asserts `emit` writes a `True`
  string as a bare `flag: True`; it now writes `flag: "True"`. The subtest's
  other two assertions (that quoting is silent — no warning on emit or on
  `decrypt_file`) still hold: quoting is silent, exactly as the bare write was.

## Rejected alternatives

**Record this as an addendum inside ADR 0070.** ADR 0070 is accepted and its
scope is deliberate; folding a scope change into it would blur what it decided.
A short ADR that references it is the house pattern and keeps k186's
motivation (faithful inverse, no digest) discoverable on its own.

**Quote on the warn path too, for uniformity.** ADR 0070 kept
`mac_only_encrypted` unchanged because the document already works and the leaf is
not MAC-covered; k186 is about the plaintext emitters being a faithful
inverse, which the warn path is not in the business of. Leaving it untouched
keeps the change to the two paths the ticket measured.
