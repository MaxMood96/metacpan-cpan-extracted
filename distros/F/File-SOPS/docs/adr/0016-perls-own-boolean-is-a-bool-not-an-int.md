# ADR 0016 — Perl's own boolean SV is a `bool`, not an `int`

- Status: accepted
- Date: 2026-08-20
- Tags: bool, types, mac, wire-format, yaml, json, interop
- Resolves k90
- Amends ADR 0002 (the type ladder gains a rung for Perl's own boolean SV; its
  rule is untouched — the type comes from the scalar's public flags, which is
  why such a leaf was an `int` — and the ladder stays single)
- Depends on ADR 0008 and ADR 0012 (the rule that a leaf an emitter cannot
  write as the text the digest covers must not be written silently — the same
  disagreement, here **repaired** rather than refused) and ADR 0013 (the karr
  k86 guard, which cannot see this leaf and is measured again below)

## Context

Perl has no boolean *type*, but since 5.36 it has a boolean **SV**. `!!1`,
`!!0`, `$x > 3`, `'a' eq 'a'`, `defined $x`, `builtin::true` and every other
comparison return produce it, and the mark (`SvIsBOOL`: the IOK+POK flag pair
plus a static-COW PV pointing at perl's own `PL_Yes` / `PL_No`) survives
assignment, storage in a hash and being passed through a walk.

`detect_type` reads the public `SVf_IOK` first, so it calls such a scalar an
`int` and `value_to_bytes` digests `1` / `0`. **Both emitters write it as a
bare `true` / `false`.** Measured, perl 5.40.1, YAML::XS 0.910.0,
Cpanel::JSON::XS 4.43:

| leaf | `is_bool` | YAML::XS writes | Cpanel::JSON::XS writes |
|---|---|---|---|
| `!!1` | 1 | `true` | `true` |
| `!!0` | 1 | `false` | `false` |
| `dualvar(1, '1')` | 0 | `1` | `1` |
| `dualvar(0, '')` | 0 | `''` | `""` |
| `1` / `0` | 0 | `1` / `0` | `1` / `0` |

The `dualvar` rows are the ones that matter for the shape of the fix: they
carry the same IV, the same PV and the same public flags as the sentinels, and
neither emitter writes them as a boolean. So the emitters are not using a flag
or text lookalike — they are using `SvIsBOOL` itself, and any predicate here
that is not that same one disagrees with them for some leaf.

### What the document did

Measured against sops 3.13.3, one document per row, at 2724e1d, both handlers,
both slots. Every sentinel leaf collapses into one of four outcomes — and the
route in includes a caller's own `YAML::XS::Load`, since our parse localises
`$YAML::XS::Boolean` and a caller's does not:

| leaf | slot | document | digest | `sops -d` |
|---|---|---|---|---|
| a true sentinel | encrypted | `ENC[…,type:int]`, plaintext `1` | `1` | exit 0, reads back `1` |
| a true sentinel | unencrypted | `true` | `1` | **exit 51**, MAC mismatch |
| a false sentinel | encrypted | `''` | `0` | **exit 51**, MAC mismatch |
| a false sentinel | unencrypted | — | — | croak (ADR 0012's int guard) |

Ten such leaves (`!!1`, `!!0`, `$x > 3`, `$x > 9`, `'a' eq 'a'`, `defined $x`,
`builtin::true`, `builtin::false`, and a `true`/`false` from a caller's own
`YAML::XS::Load`) across two slots and two handlers is **40 document rows: 12
exit 0 with the wrong value, 20 exit 51, 8 refused.**

Three of those four rows were not in k90's ticket, and two contradict it:

- **The false sentinel in an *encrypted* slot is a MAC break of its own, and a
  second mechanism.** `_encrypt_tree` skips a leaf that is an empty string, and
  `!!0`'s PV *is* the empty string, so the leaf reached the document as a
  plaintext `''` while `_compute_mac` had already digested `0`. This is
  letter-for-letter the `JSON->false eq ''` defect the comment above that line
  already describes, one value class over — the `!blessed($node)` guard put
  there for `JSON::PP::Boolean` does not cover a sentinel, because a sentinel
  is not blessed.
- **The false sentinel in an unencrypted slot does not write a silent
  document**, in either format. The ticket recorded YAML writing `false`
  silently and JSON croaking. At 2724e1d both croak, through ADR 0012's
  integer guard: the leaf's PV (`''`) differs from its digest text (`0`), so
  the emitter is asked, and it answers with a `false` whose `value_to_bytes` is
  `False`. The guard fires for the right reason on the wrong leaf class.
- **The true sentinel in an encrypted slot is the one row `sops -d` accepts**,
  and it is the row that says why refusing is not available: the file verifies
  and gives the caller back the integer `1` for a value they wrote as a
  boolean.

### What sops does with the same input

```
$ printf 'admin: true\nadmin_unencrypted: true\nnope: false\n' > plain.yaml
$ sops -e --age … plain.yaml
admin: ENC[AES256_GCM,…,type:bool]
admin_unencrypted: true
nope: ENC[AES256_GCM,…,type:bool]
```

`type:bool`, plaintext `True` / `False` (ADR 0002's table, re-measured here).
SOPS has a boolean type, this value is a boolean, and the document sops writes
for it already exists.

### The route in is ordinary caller code

```perl
File::SOPS->encrypt(data => { admin => ($user->{level} > 3) });
```

Putting a comparison's result into a hash is not an exotic thing to do, and
neither is handing this library a tree the caller loaded with their own
`YAML::XS::Load`. Both produce sentinels.

## Decision

**`detect_type` returns `bool` for a scalar Perl itself marks as a boolean,
and it asks Perl through the same predicate the emitters ask.**

```perl
return 'bool' if blessed($value) && $value->isa('JSON::PP::Boolean');
return 'str'  if ref $value;
return 'bool' if $IS_BOOL_SV->($value);
return _sv_kind($value);
```

Everything downstream already does the right thing with that answer:
`value_to_bytes`'s `$type eq 'bool'` branch digests `True` for a PV of `1` and
`False` for a PV of `''`, which is exactly the two sentinels' PVs.

Four things about this are deliberate.

**The predicate is `builtin::is_bool`, not a flag test.** It is the only way to
reach `SvIsBOOL` from Perl, and `SvIsBOOL` is what both emitters use. A
reimplementation in terms of `B`'s public flags cannot distinguish
`dualvar(1, '1')` from `!!1` — the two differ only in whether the PV buffer is
perl's own static `PL_Yes`, which `B` does not expose — so it would type a
dualvar `bool` while the emitters write it as `1`, which is this ADR's own
defect wearing the fix. **This is not a return to ADR 0002's pattern match:**
nothing looks at the value's text. It reads a mark Perl put on the scalar, in
the same way and for the same reason `_sv_kind` reads `IOK`.

**On a perl older than 5.36 the answer is "no", and that is complete rather
than degraded.** There is no boolean SV there for either emitter to recognise,
so `!!1` is written `1` by both and the digest's `1` is what the document says.
The predicate is therefore loaded through a string eval and falls back to
`sub { 0 }`: `use builtin` and `no warnings 'experimental::builtin'` are both
compile-time errors on a perl that has neither, and this distribution declares
`perl 5.010`.

**The fallback is a correct answer below 5.36 and a fatal one at or above it.**
The predicate is probed at load — it has to say yes to both sentinels and no to
the integers and strings that share their flags and PV — and a perl that *has*
the boolean SV but cannot supply a working `is_bool` croaks there rather than
carrying on. Silently answering `int` on such a perl would make every boolean
that process encrypts a document nothing can read, and the symptom would be a
MAC mismatch a long way from the cause.

**One boolean mechanism, not two.** A sentinel and a `JSON::PP::Boolean` now
produce the same `type:bool`, the same `True`/`False` plaintext, the same
digest and the same document — verified byte for byte over both handlers and
both slots (see below). The alternative was two boolean routes with different
results, which is the shape of every defect this distribution has spent a
release removing.

**The empty-leaf skip in `_encrypt_tree` gets the same exception the blessed
boolean already has.** `return '' if !blessed($node) && $node eq ''` becomes
`… && detect_type($node) ne 'bool'`. Without it the type fix alone would leave
the false sentinel writing a plaintext `''` against a digest of `False` — the
break would move, not close. The `eq` runs first, so the ladder is consulted
only for a leaf that really does stringify empty.

**`_canonical_floats` stops before its integer branch for a bool leaf.** A
sentinel publishes `IOK`, so `_sv_kind` calls it an int and ADR 0012's guard
would ask the emitter about every boolean in every document — an emit and
reparse per leaf, to arrive at "yes, it writes it faithfully". The leaf is
handed to the handler's foreign-resolution check and nothing else.

### Why repaired, where ADR 0012 refuses

ADR 0012 refuses an integer whose string half contradicts its number, because
both halves are a candidate for what the caller meant and **nothing measurable
separates a spelling from a contradiction**. Neither clause holds here.

- **There is one candidate.** Perl has answered the question already: this
  scalar is a boolean, and it says so through a mark that no other value
  carries. The digest text is not being *chosen* between two halves, it is
  being read off the same SV ADR 0002 reads everything else off.
- **SOPS has the type.** ADR 0002's rule is "the type is what the parser
  returned"; the reason a sentinel was an `int` is that in 5.10 there was no
  boolean SV to return. There is now, and `bool` is a SOPS wire type with a
  specified plaintext.
- **A refusal would refuse `{ admin => ($u->{level} > 3) }`**, which is
  ordinary Perl with an unambiguous meaning, and it would have to refuse the
  one row `sops -d` accepts today along with the three it rejects.

This is the same line the distribution draws in ADR 0011, k62, k78, k88 and
k89: repair where a representation exists, refuse where none does or where the
halves contradict each other.

### Alternatives rejected

1. **Refuse a boolean sentinel** (ADR 0008 / 0012 shape). It names the leaf
   instead of writing a broken document, and the caller writes `JSON->true`.
   Rejected because a representation exists and is unambiguous — `type:bool`,
   `True`, a bare `true`, which is the document sops itself writes for the same
   input — and because the refusal would fall on the most ordinary expression
   in the ticket.
2. **Keep `int` and fix the emitters instead**, forcing YAML::XS and
   Cpanel::JSON::XS to write a sentinel as `1`/`0`. It puts the wire format
   back in agreement with the digest without moving the digest, and both
   emitters would have to be pinned against a future version changing its mind.
   It also stores the integer 1 for a value the caller wrote as a boolean and
   sops writes as one — the wrong repair, chosen because it is smaller.
3. **A `B`-based flag test instead of `builtin::is_bool`.** Works on every
   perl and needs no conditional load. Measured wrong: `dualvar(1, '1')` and
   `!!1` are identical in every public flag `B` exposes, so it would type the
   dualvar `bool` and digest `True` while both emitters write `1` — a new
   silent MAC break, introduced by the fix for one.
4. **Read the private flags or the PV text** (`"$v" eq '1' && $v == 1`). The
   pattern match ADR 0002 removed, and it collides with the perfectly ordinary
   integer `1`.
5. **Also refuse a `JSON::PP::Boolean` *subclass*, or accept a sentinel-like
   dualvar.** Both widen the predicate away from the one the emitters use. ADR
   0008 already settled the direction: the exception is the exact thing the
   emitter can write, not everything that resembles it.

## Consequences

### Wire bytes that move for existing callers

Only for a leaf Perl marks as a boolean, and only on perl 5.36 or newer:

| `encrypt(data => …)` | 0.003 wrote | now writes |
|---|---|---|
| `{ v => !!1 }`, encrypted | `type:int`, plaintext `1` | `type:bool`, plaintext `True` |
| `{ v => !!0 }`, encrypted | plaintext `''`, digest `0` (**exit 51**) | `type:bool`, plaintext `False` |
| `{ v_unencrypted => !!1 }` | `true`, digest `1` (**exit 51**) | `true`, digest `True` |
| `{ v_unencrypted => !!0 }` | croak | `false`, digest `False` |

The first row is the behaviour change proper: a document that verified, and
gave the caller back `1` where they wrote a boolean, now stores the boolean.
A caller who round-trips such a value through this library gets `JSON->true`
back instead of `1` — the same thing they already get for a `true` read out of
any document. The other three rows are files nothing could read, or a refusal.

Nothing changes for a tree of plain scalars, strings, numbers,
`JSON::PP::Boolean`s, `undef`, hashes and arrays — which is every tree this
library produces itself, and every tree either parser returns: measured, no
parser in this distribution ever yields a boolean sentinel (YAML::XS under
`$YAML::XS::Boolean = 'JSON::PP'`, YAML::PP under `boolean => 'JSON::PP'` and
Cpanel::JSON::XS all return `JSON::PP::Boolean`). The route in is caller data
only.

### The read path is untouched

`type:bool` still deserializes to a `JSON::PP::Boolean` (invariant 6), and
`_mac_bytes` still titlecases a decrypted `bool` plaintext. A document sops
wrote, or an older File::SOPS document, is read back exactly as before —
including a 0.003 file carrying `type:int` plaintext `1` for what was a
sentinel, which still reads back as the integer 1 it says it is.

### The k86 guard becomes consistent, and is measured saying so

ADR 0013's guard compares Go's resolution of the leaf's *stringification*
against the digest text and returns early when they agree. For a true sentinel
those were `1` and `1`, so it agreed and never asked `_emitted_plain_scalar`
what the emitter writes — the one leaf class where the two are different
strings. With the digest text now `True` the early return no longer fires, the
guard asks the emitter, gets `true`, resolves it through `%GO_CONSTANT` to
`True`, and agrees for the reason it is supposed to agree for.

The false sentinel does not reach that comparison at all: its stringification
is `''`, which fails the guard's `$GO_LOOKS_AT` gate. The outcome is correct
either way — the emitted `false` resolves to `False`, which is the digest —
but the gate is a proxy for the emitted token and this is the one leaf class
where the proxy is wrong. Recorded here rather than widened: widening it costs
an emit-and-reparse for every leaf whose text starts with anything at all, and
no leaf class is known where the proxy is wrong *and* the answer is.

### What was measured

- A 192-row corpus — 48 leaves x 2 slots (`leaf`, `leaf_unencrypted`) x both
  handlers, each row the round-tripped value plus a digest of the emitted
  document with ciphertext, key material and timestamp normalised away —
  before and after: **40 rows move, and every one of them is a boolean
  sentinel.** No string, integer, float, `JSON::PP::Boolean`, `undef`,
  dualvar, YAML-parsed-scalar, array or hash row changes, in either format or
  either slot: **0 of the other 152.**
- Every moved row end to end against sops 3.13.3, with the change stashed and
  restored so both sides are the same corpus: **before, 12 exit 0 with the
  wrong value, 20 exit 51, 8 refused; after, 40 of 40 exit 0** — 24 reading
  back `true`, 16 reading back `false`.
- The two boolean routes compared byte for byte: `{ v => !!1 }` and
  `{ v => JSON->true }` produce **identical** documents in both formats and
  both slots, and likewise for false.
- The k88 trap: the same tree emitted five times in one process, and the
  sentinels re-read after every round. The mark survives, the type stays
  `bool`, and the five documents are identical.

## Notes

Everything above is from sops 3.13.3, perl 5.40.1, YAML::XS 0.910.0,
Cpanel::JSON::XS 4.43 and Crypt::Age 0.002 on this machine, run against the
binary rather than read out of the Go source. `t/32-boolean-sentinel.t` pins
the rules that need no binary — the type, the digest text, the two routes
agreeing, both slots in both formats, and the multi-round stability — and
`t/04-interop.t` pins the round trip against sops itself.
