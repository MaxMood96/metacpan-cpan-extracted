# ADR 0063 — A MAC mismatch hint names the bare negative zero sops writes

- Status: accepted
- Date: 2026-08-23
- Tags: mac, hint, yaml, json, interop, sops-bug
- Resolves k121
- Depends on ADR 0014 (Perl `-0.0` is shipped as `-0.0`, never as bare
  `-0`; the broken shape exists only on the Go side), ADR 0052 (the
  precedent for hedged MAC-failure hints, on env / ini display forms)
- Follows the wording convention of `_mac_failure_sops_display_hint`

## Context

`float.FormatFloat(-0, 'f', -1, 64)` is the string `-0`. Go uses that
format for every float that underflows to negative zero on write. yaml.v3
and json.v2 then read `-0` back as int 0, the file's MAC covers `-0`,
and the document fails its own MAC -- with `sops -d` itself returning
exit 51 ("MAC mismatch") on the file it wrote. ADR 0014 closed the
Perl-side half of this: our YAML emitter ships `-0.0` and the JSON
carrier reconstructs the signed zero through `pack/unpack 'd'`, so a
Perl-written document is never the broken shape. The read side is the
gap: a sops-produced document carrying `-0` reaches us, our MAC
verification refuses it (correctly), and the user sees the same opaque
"MAC verification failed" they would get from any other cause.

Three measured properties of the failure:

| Cell | YAML | JSON |
|---|---|---|
| `sops -e` of `v_unencrypted: -1e-400` | exit 0, writes `v_unencrypted: -0` | exit 0, writes `"v_unencrypted": -0` |
| `sops -d` on the file sops wrote | exit 51, "MAC mismatch" | exit 51, "MAC mismatch" |
| `sops rotate -i` on the file sops wrote | exit 51, "MAC mismatch" | exit 51, "MAC mismatch" |
| `File::SOPS->decrypt` on the same file | "MAC verification failed" | "MAC verification failed" |
| Hand-fix `-0` to `-0.0` and `sops -d` again | exit 0 | exit 0 |

The hand-fix is the smoking gun: nothing else in the document changes,
and the file verifies. So the cause is the bare `-0` token on the wire,
not the data key, the age recipient, or anything else.

`ignore_mac => 1` is the existing escape (it skips verification
entirely, returning the document decrypted but not authenticated). What
was missing was a hint at the failure that named the sops shape, so a
user who had just run `sops -e` and seen `sops -d` exit 51 had any
chance of recognising the same shape from our message.

## Decision

**Append a hedged hint to the MAC verification failure message when
the raw document text carries a bare `-0(\.0+)*` token at a value
position in a YAML or JSON document, alongside the existing
`_mac_failure_sops_display_hint` for the env / ini display-form case.**

```perl
# Sibling of the existing display-form hint. Same hedge wording,
# same format-scoped guard, same MAC-failure-only trigger.
sub _mac_failure_sops_negzero_hint {
    my ($document, $format_class) = @_;
    return '' unless $format_class && $format_class->can('format_name');
    my $name = $format_class->format_name;
    return '' unless $name eq 'yaml' || $name eq 'json';
    return '' unless defined $document
        && $document =~ /-0(?:\.0+)*(?![0-9.eE])/;
    return 'The document also carries a bare `-0` token in an '
         . 'unencrypted value -- a known sops shape: any float that '
         . 'underflows to negative zero is written as `-0` but '
         . 'parses back as int 0, so the file fails its own MAC '
         . 'and `sops -d` also refuses it.';
}
```

Wired into `_verify_mac` next to the existing display-form call; the
second hint fires only when the first returned empty, so the two never
overlap on a single document.

### Why this regex and not something tighter

The wire shape Go produces for a negative zero is `FormatFloat(-0,
'f', -1, 64)`, which is the token `-0` (or, for values where the
textual form already has a `.0+` suffix, `-0.0`, `-0.00`, etc.). The
match is `-0` then zero or more `.0+` repetitions, then a token
boundary: a digit, a period, or an exponent marker cannot follow.
The lookahead `(?![0-9.eE])` keeps `-01`, `-0.5`, `-0e3`, `-0E3`
out -- they are different literals, and the bug only manifests for
the bare-`-0(\.0+)?` spelling. The sops section itself cannot carry
this shape (age recipients are base32, the mac is `ENC[...]`, the
lastmodified is ISO 8601, the version is a dotted triplet, base64
alphabet has no `-`), so a raw substring match over the whole
document is safe without scoping the regex to user data.

### Why the hint is hedged

Same convention as `_mac_failure_sops_display_hint` (ADR 0052): a
hint that names a specific cause is a misdiagnosis on a document that
shares the same shape for a different reason -- a user with a key
named `lastoffset: -0` would match the regex but for unrelated
reasons, and a hint that said "this is the cause" would be wrong
there. "Consistent with" / "also carries" / "sops -d also refuses it"
is the wording the existing hint uses; the new one matches it.

### Why yaml / json only

env and ini carry values as plain strings, so a `-0` literal there is
the string "-0" and the digest agrees with what gets read. Only yaml
and json have typed values, so only those formats can carry the sops
bug. The format check is the same one the display-form hint uses,
inverted -- env / ini there, yaml / json here.

## Consequences

### What changes for existing callers

| scenario | before | now |
|---|---|---|
| `decrypt` of a sops-written doc with `-0` in unencrypted slot (yaml / json) | "MAC verification failed: ... Pass ignore_mac => 1 ..." | same message + a sentence naming the bare `-0` sops shape and pointing at `sops -d` as also refusing it |
| every other MAC failure (yaml / json) | unchanged | unchanged |
| every MAC failure (env / ini) | unchanged | unchanged |
| `decrypt` with `ignore_mac => 1` | unchanged | unchanged |
| any encryption or rotation path | unchanged | unchanged |

The hint is appended with a single space, so the existing escape
clause ("Pass ignore_mac => 1 to read it anyway") still appears at
the end of the croak exactly as it did before.

### Wire bytes that move

None. The hint is wording-only. The MAC bytes, the AAD, the
type-detection ladder, the value encoder, the encrypt path, the
decrypt path, and the round-trip sections of the suite are all
unchanged.

### What this is not

Not a fix. The bug is in sops, not here. The hand-fix in section
"context" is the only known workaround short of editing the document
by hand. The hint makes the cause legible; it does not heal the file.

Not an emission fix on the read side. A document with a bare `-0` in
the wire is still a broken document, and reading it with
`ignore_mac => 1` returns int 0 (the sops-parsed shape) rather than
`-0.0` (the Go-emitted shape). That asymmetry is the bug; we
reproduce it, not repair it.

Not a claim about the future. The hint assumes sops continues to
emit bare `-0` for a negative zero. A sops release that changes
`FormatFloat`'s dialect or routes negative-zero floats through a
different spell would invalidate this hint; the regex would no
longer fire on the new shape, and the hint would silently stay
silent on the old one.

## Rejected alternatives

**Repair the wire form on read** (read the bare `-0` token back as
`-0.0`, hash the repaired form). Two reasons not to. First, the MAC
is computed by Go over `-0`; repairing the form on our side without
recomputing the MAC leaves verification broken (the document is
still inconsistent with itself). Second, repairing the form on our
side AND recomputing the MAC means we are no longer verifying
sops's MAC -- we are verifying our own -- and the user no longer has
the property that a sops-written file verifies against both
implementations.

**Always emit a hint for any MAC failure** (drop the regex, drop the
format check). Loses the property that the hint names a specific
cause. The whole point of the hint is the user's first question --
"why is this file broken?" -- and a hint that says only "this file is
broken" is the same refusal with extra text.

**Apply the hint on env / ini too.** A bare `-0` in env / ini is the
string "-0", the digest covers "-0", the read returns "-0", the
document verifies. There is no bug to hint at, and a hint that fired
on a verifying env / ini document would be a false positive. The
format check is what keeps the hint accurate.

**Read the parsed tree instead of the raw document text.** The tree
has int 0 by the time `_verify_mac` sees it -- the negative-zero
semantics are gone, and so is the signal. ADR 0002 records the
reason the type comes from the scalar; ADR 0052 makes the same
choice on the env / ini hint (parsed tree, but for a different
signal that survives parsing). The raw-text scan is what makes this
hint possible.

**Use a regex anchored to user-data keys** (skip the `sops:` section
specifically). The sops section cannot carry the bare `-0` shape --
age recipients are base32, the mac is `ENC[...]`, base64 alphabet
has no `-` -- so a global substring match is safe without that
filter. Adding the filter would couple the hint to the sops-section
key list, which changes more often than the bug it would be guarding
against.

## Measured against sops 3.13.3

The four cells from the context table, end to end, both formats,
with the file from `t/75-bare-negative-zero-mac-mismatch-hints.t`
section 2 as the carrier (binary at `/tmp/sops`):

| Cell | YAML | JSON |
|---|---|---|
| `sops -e` of `v_unencrypted: -1e-400` | exit 0, `v_unencrypted: -0` on the wire | exit 0, `"v_unencrypted": -0` on the wire |
| `sops -d` on the file | exit 51 | exit 51 |
| `sops rotate -i` on the file | exit 51 | exit 51 |
| `File::SOPS->decrypt` on the file | "MAC verification failed: ... bare `-0` token ... `sops -d` also refuses it. Pass ignore_mac => 1 ..." | same |
| Hand-fix `-0` to `-0.0`, then `sops -d` | exit 0 | exit 0 |
| `File::SOPS->decrypt` with `ignore_mac => 1` | reads back as int 0 (the sops-parsed shape) | same |

Every existing test that pinned the bare-MAC-failure behaviour
(t/07-mac.t, t/68-mac-failure-hints-sops.t) passes byte-for-byte --
the hint is appended only when the new conditions are met, and the
existing `display form` hint still owns the env / ini case. Full
suite: 77 files, 1389 tests, all PASS, with t/04-interop.t and the
other interop sections executed against the binary rather than
skipped (binary at /tmp/sops).