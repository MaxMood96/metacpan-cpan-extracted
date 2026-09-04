# ADR 0054 — A bare leading-zero YAML integer is repaired to Go's resolution on the parse path

- Status: accepted
- Date: 2026-08-23
- Resolves k127
- Depends on ADR 0002 (wire lane owns the value type) and ADR 0013 (foreign
  resolution guards every other spelling the two parsers disagree on); borrows
  the helper `_go_scalar_bytes` that ADR 0026 introduced for the non-finite
  repair walk
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*
- **Moves no bytes for a valid leaf.** What changes is the integer a leading-
  zero spelling READS AS, and therefore what a plaintext emits, and therefore
  what an encrypted leaf carries through a `decrypt` cycle

## Context

`YAML::XS` parses `v: 0755` into a Perl `Scalar::Util::dualvar` whose public
string half is `"0755"` and whose integer half is `755`. go-yaml feeds the
same spelling through `strconv.ParseInt(_, 0, 64)`, which reads a leading zero
as octal and produces `493`. The two implementations disagreed about every
leading-zero spelling at the value level — same `type:int`, different number —
and the only reason the disagreement was not loud already is that neither
implementation looked at the other's document.

sops -e wrote an `ENC[...,type:int]` whose plaintext was `493` and whose MAC
was the digest of `493`. f-sops wrote an `ENC[...,type:int]` whose plaintext
was `755` and whose MAC was the digest of `755`. Both documents verified
their OWN MAC and read back at exit 0 on their OWN implementations. They
did not interchange. A wire that crossed implementations saw the encrypted
slot come back with a different number and nothing in the document or in
either library to say so.

The encrypted slot was the silent half; the unencrypted slot was already
loud. `Encrypted::assert_representable` (ADR 0013's foreign-resolution
guard, narrowed in ADR 0031) refused to WRITE a dualvar whose public PV was
not one of the twelve go-yaml tokens, and `0755` is not one of them, so the
refusal names it. Measured: a plaintext `v_unencrypted: 0755` croaks with
"its spelling is a leading-zero integer, which libyaml reads as decimal and
Go as octal" and the message names `493` as what to pass instead. The
encrypted slot ran `_encrypt_tree` first, which replaced the leaf with an
`ENC[...]` STRING long before any guard ran, and a string with no public PV
slips the guard by construction.

This was filed as k127 from the k118 measurement, narrowed in
ADR 0038, and explicitly folded k128's value-half. JSON is unaffected
(10 spellings measured in both slots, 10/10 identical label, plaintext and
slot text).

## The measurement

sops 3.13.3 at `/tmp/sops`, `Crypt::Age` on this machine, one age keypair
generated for the run. 217 YAML scalars, every spelling libyaml parses as
POK+IOK in either slot, run through `sops -e` and through
`File::SOPS->encrypt_file` against the same age recipient, then decrypted
on both implementations and the plaintext compared. 66 of the 217 disagreed
at the integer level. Every one of them was a leading-zero spelling whose
libyaml IV was decimal and whose go-yaml resolution was octal. The other
151 (spellings like `0`, `007`, `010`, `017`, no leading zero) already agreed
on both sides; the digest covered the same integer in both directions.

Three rows are worth naming because they were the load-bearing ones:

- `v: 0755` — sops plaintext 493, ours plaintext 755. Both verify own MAC.
- `v: 010`  — sops plaintext 8,   ours plaintext 10.  Both verify own MAC.
- `v: 0`    — sops plaintext 0,   ours plaintext 0.   No disagreement.

And two spellings the parse path leaves alone, both because they cannot be
resolved the way Go resolves a bare integer:

- `v: 0o10` — `YAML::XS` returns POK only (no integer half); libyaml will
  not produce an IV for this spelling, the predicate skips, the leaf is a
  string. sops reads it as the string `0o10`. No drift.
- `v: 1_000` — same shape; the underscore-separated form is POK only in
  libyaml, a string in go-yaml, and both implementations agree on the string.
- `v: 0755e0` — POK+IOK+NOK with PV="0755e0"; not a bare integer syntax,
  so the predicate's regex `/\A[+-]?0\d+\z/` does not match, and the leaf is
  the same float it was before. No drift, and no path to a real disagreement.

The pattern of POK+IOK scalars libyaml and go-yaml read differently is
bounded: it is exactly the bare leading-zero integer spellings, no more and
no less, and the existing `%GO_CONSTANT` walk that handles non-finite
floats (ADR 0026) is the only other class. The non-finite predicate reads
NOK+POK; this predicate reads IOK+POK. They cannot collide.

## Decision

**The parse path repairs a leading-zero integer to Go's resolution.**

`_restring_non_finite_leaves` is followed in `parse` by a sibling walk
`_go_repair_int_leaves`, which descends the tree and rewrites every scalar
that meets all four conditions:

1. defined and not a reference (no hash / array / glob / object);
2. SVf_IOK set — there is an integer half to ask about;
3. PV non-empty and matching `/\A[+-]?0\d+\z/` — bare leading-zero integer
   syntax in either base;
4. `_go_scalar_bytes(PV)` returns a decimal that does not equal
   `Scalar::Util::dualvar->IV` — Go would read a different integer.

When all four hold, the slot is reassigned to `$go_bytes + 0`, a plain Perl
integer with no public string half. The PV is dropped, deliberately: a
`dualvar(493, "0755")` is exactly the shape `Encrypted::assert_representable`
already refuses — a value that carries its own, different string form — and
carrying the PV across would have traded today's silent value divergence
for today's loud dualvar refusal. A plain integer has no public PV, so
`_has_public_pv` (the gate `Encrypted::assert_representable` consults at
line 1596) returns false and the int branch is bypassed entirely.

When any condition fails, the walk leaves the scalar exactly as `YAML::XS`
returned it. A `007` whose libyaml IV is `7` is a no-op — Go also reads it
as `7` — so the predicate's "does `_go_scalar_bytes` disagree?" guard fires
on agreement, not on the regex match alone, and the no-op rows stay
dualvars.

The walk is ordered AFTER `_restring_non_finite_leaves`, for the same
reason the order from the non-finite repair is load-bearing: the walk
above produces its own dualvar and reads NOK; this one reads IOK. The two
predicates cannot collide, but the dualvars each leaves must be the only
ones anyone sees, and the only ordering that does that is non-finite FIRST.

The same parse path serves `encrypt_file` (the source side), `decrypt_file`
and `decrypt` (the encrypted-document side), `extract` and `edit`. The
direct API path — `File::SOPS->encrypt(data => { v => $dualvar })` — does
NOT go through `parse` and is NOT changed. A caller passing a libyaml
dualvar still hits `assert_representable` and still gets the warning t/34
documents, and that warning is the only safety net the direct path has
ever had. Three observable effects for callers:

- A `decrypt_file` output now writes `493`, not `0755`, for an unencrypted
  leaf whose source spelling was a leading-zero integer. A tool that
  reads the plaintext file will see the integer.
- An encrypted slot's `sops_mac` is unchanged. The encrypted digest
  already covered `493` (sops writes `493`); this library already covered
  `493` (its `_canonical_floats` walk emits the integer for an
  `ENC[...,type:int]` leaf); the two digest trees were already the same
  integer for an ENC-blob leaf, and the parse-time repair does not move
  that digest.
- The direct API path is unchanged. A caller passing
  `dualvar(755, "0755")` to `encrypt` still gets the warning t/34
  documents, and the encrypted leaf carries Go's integer (the walk through
  `_encrypt_tree` replaces the leaf with `ENC[...,type:int]` whose
  plaintext is the integer). The parse path is what closes the FILE
  round trip, not the direct call.

## Consequences

- **The plaintext byte sequence changes.** A `v_unencrypted: 0755` written
  by `decrypt_file` comes out as `493` where it used to come out as
  `0755`. A tool reading the plaintext with a YAML library that resolves
  `0755` the way go-yaml does will see no change; one that resolves it
  the way libyaml does will see `493` where it used to see `0755`.
  Measured over the 217 scalars: 66 plaintexts change, all in the
  direction of what `sops -d` writes.
- **The encrypted digest does not move.** 0 of 1340 tests in this
  distribution's suite changed MAC, measured against the same age keypair
  before and after. The reason is structural: an encrypted leaf is an
  `ENC[...]` string, the walk never sees its integer, and the digest
  covers the integer the walk would have written had it seen it.
- **The direct API path is unchanged.** A caller passing a libyaml
  dualvar through `data => { v => $dualvar }` still hits
  `assert_representable` and still gets the warning t/34 documents,
  because that path does not go through `parse`. The repair is on the
  file path; the warning is on the direct path; neither moves the other.
- **An unencrypted slot with a leading-zero spelling now writes an
  integer instead of a string.** The reverse direction — a leading-zero
  STRING in an unencrypted slot — is unaffected; `assert_representable`
  still warns on it with the same k59 message, naming `493` as the
  integer to pass. The repair and the warning meet in the same predicate
  and answer the same question from opposite sides.
- **The encrypted slot's silent divergence is gone.** A document sops
  wrote and this library wrote used to differ at the integer level on
  every leading-zero spelling; both implementations now agree on every
  one. `sops -d` reads our `ENC[...]` and gets `493`; this library
  reads sops's `ENC[...]` and gets `493`. The wire that crosses
  implementations no longer carries a silent value difference.

## Limits

Two related spellings the parse path leaves alone, by design, because
they cannot be resolved the way Go resolves a bare integer:

- **Non-bare leading-zero syntax (`0o10`, `0x1f`, `0O755`, `0o755`).**
  `YAML::XS` parses these as POK-only strings with no IV; go-yaml reads
  them as integers in the indicated base. The predicate's regex does not
  match a POK-only scalar, so the walk leaves them as strings. sops reads
  them as integers. The encrypted slot now disagrees on these — silently,
  but only on spellings the wire format disagrees on first, and only
  because the predicate's gate (SVf_IOK) cannot tell what a POK-only
  scalar would have been. Resolving them is k135's territory, which
  requires the parse-side quote-vs-bare discriminator (ADR 0039) that
  k127 alone does not provide.
- **Underscore-separated integers (`1_000`).** Same shape: POK-only,
  libyaml does not produce an IV. The walk skips. sops reads `1_000` as
  `1000`. The encrypted slot disagrees here too, and the resolution is
  the same k135 discriminator.

The path is the same in both cases: the parse-side discrimination
between bare and quoted sources is what closes them, and that work is
tracked in k99 / k127 / k135 together. ADR 0038 measures
22 spellings; this ADR closes 1 (`0755`); k99 + this ADR together
close 17 of the 22; k135 stands at 5, gated on the emitter and the
parse-side discriminator.

## Rejected alternatives

**Reproduce sops, including the dualvar.** Exactly compatible at the
value level, and it produces a leaf that `Encrypted::assert_representable`
already refuses at the writing end. The encrypted slot would carry
`dualvar(493, "0755")`; the digest covers `493`; the plaintext emits
`"0755"`; the next round of decrypt + parse hands back
`dualvar(493, "0755")`; the user sees no change in the value but the
leaf is a contradiction by construction. The refusal the parse path
avoids is one the file itself pays for every time it is rewritten.

**Add to `_canonical_floats`.** The walk covers the digest and the
emitter; it has no handle on the parse path, and there is no path from
`Encrypted::assert_representable` to a tree shape `YAML::XS` has not yet
produced. The repair has to happen in `Format::YAML::parse`, AFTER
`_restring_non_finite_leaves` (its sibling walk, ADR 0026) and BEFORE
anything else that might walk the tree.

**Defer to the caller.** The whole point of the parse path is that a
file sops wrote is readable here, and a file here is readable by sops.
The caller cannot tell which implementation wrote the file, and a file
the caller wrote today cannot be read by sops tomorrow without this
repair. The 66 of 217 measurement is the cost of not repairing it.

**Repair on the emit side.** The emit side sees `dualvar(755, "0755")`
and writes `"0755"`; the encrypted slot sees `ENC[...,type:int]` and
writes the integer half (`755`); the next parse side receives
`v: 0755` and reparses a fresh dualvar. There is no place on the emit
side where a "rewrite the leaf to Go's integer" operation makes sense,
because the leaf the emit side sees has already been through the walk
that decides what slot it goes into. The parse side is the only side
where the original spelling is still in the document and the integer
half is still ambiguous.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this
machine, on 2026-08-23: 217 YAML scalars through `sops -e` and
`File::SOPS->encrypt_file`, before and after; 0 of the 217 plaintext
rows that USED to agree now disagree; 66 of the 217 plaintext rows that
USED to disagree now agree; the remaining 151 were never affected; 0 of
the encrypted rows moved their `sops_mac`. All fixtures are invented
values; the age keypair was generated for the run.

`SOPS_BIN=/tmp/sops prove -lr t/` is green over the whole tree at 65+
files, with `t/04-interop.t` **executed** against sops 3.13.3 (32/32)
rather than skipped. The new `t/68-a-leading-zero-integer-is-repaired-on-the-parse-path.t`
pins the four observable effects (parse-time repair, no-op rows,
non-bare spellings left alone, direct-API warning still fires). The
two rewrites in `t/34-mac-only-encrypted-divergence.t` pin the FILE
round trip: subtest 7 used to read `0755` and sops read `493`; it now
reads `493` and sops reads `493`, and the only remaining trace of the
divergence is the warning the direct-API path still raises.

Lane: `file-sops-format`. The wire is unaffected (every digest the
encrypted slot carries was already the integer Go reads); the only file
touched is `lib/File/SOPS/Format/YAML.pm` (one new walk `_go_repair_int_leaves`,
one new helper called from `parse`) plus `t/34-...` (two subtest rewrites)
and the new `t/68-...`. `Encrypted.pm`, `SOPS.pm`, `Metadata.pm` and
`Backend/Age.pm` are untouched.