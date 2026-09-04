# ADR 0004 — A foreign scalar is normalised where its bytes become a value, not at every XS boundary

- Status: accepted
- Date: 2026-08-09
- Tags: crypto, dependencies, types, determinism
- Records the rule introduced by commit cf2bb15 (k32) and scopes it against
  ADR 0002, which is what makes the unconditional version of it wrong

## Context

`File::SOPS::Encrypted::decrypt_bytes` ends in

```perl
return "$plaintext";
```

and the quotes are load-bearing. `return $plaintext` is a silent
data-corruption bug: CryptX's `gcm_decrypt_verify` hands back the plaintext in
an SV whose PV buffer is not NUL-terminated at `SvCUR`, and Perl's own
string-to-number conversion depends on that terminator. `sv_2nv` consults
`SvCUR` only through `grok_number`; for anything `grok_number` cannot settle
inside a UV — every float, and every integer wider than 64 bits — it falls
through to `Atof(SvPVX)`, a C string read with no length. So the `$data + 0.0`
in `_deserialize_value` ran off the end of the plaintext into whatever the
allocator had left there, and when that byte was one of the ten digit
characters it joined the number. The `100000000000000000000` that Go writes for
`1e20` came back as `1e21`, on measured 143 of 4000 round trips, with the
ciphertext and the MAC both intact. A wrong value handed to a caller, silently,
by a library whose whole job is to return what was stored.

That is fixed. What is not written down anywhere is the *rule* the fix
establishes, and the rule has two halves that a later reader would plausibly get
wrong in opposite directions:

- **Why the stringify is at `decrypt_bytes` and not at the two conversions that
  actually do the numeric read.** Read at the conversion site, the copy looks
  like it is in the wrong place.
- **Why the same treatment is not applied to the other scalars CryptX hands
  us** — the ciphertext and tag out of `gcm_encrypt_authenticate`, the IV and
  data key out of `Crypt::PRNG::random_bytes`. Read at `decrypt_bytes`, the copy
  looks like an arbitrarily chosen one of four.

A line whose only defence is "it was needed once, for reasons that are not
visible here" gets deleted. This ADR is the defence.

### How wide the defect actually is

Measured on this machine, 300 samples per call, with the allocator deliberately
poisoned before each call — digit-filled buffers of every size the call is about
to request, freed — so that a non-terminating return lands on a digit rather
than on a lucky zero:

| call | what it returns here | not NUL-terminated at `SvCUR` |
|---|---|---|
| `gcm_decrypt_verify` | the plaintext | 298/300 |
| `gcm_encrypt_authenticate` | the ciphertext | 299/300 |
| `gcm_encrypt_authenticate` | the tag | 0/300 |
| `Crypt::PRNG::random_bytes(32)` | the IV, the data key | 299/300 |
| `chacha20poly1305_decrypt_verify` | (age payload, via Crypt::Age) | 300/300 |
| `hkdf` | (age key derivation, via Crypt::Age) | 300/300 |
| `hmac` | (age header MAC, via Crypt::Age) | 0/300 |
| `Crypt::Age->decrypt` | the data key | 0/300 |
| `YAML::XS::Load` | every scalar in the document | 0/300 |
| `Cpanel::JSON::XS` decode | every scalar in the document | 0/300 |

Three things fall out of that table that the ticket proposing this ADR could
only guess at:

- **The ticket's guess was right and understated.** `gcm_encrypt_authenticate`'s
  ciphertext and `Crypt::PRNG::random_bytes` are not "possibly" affected, they
  are affected on essentially every call.
- **The split inside CryptX is by return shape, not by function.** The calls
  that build a variable-length result into a preallocated SV and set `SvCUR`
  afterwards do not terminate; the ones that return a fixed-size digest or tag
  do. That is why `hmac` and the GCM tag are clean and the ciphertext next to
  them is not.
- **`Crypt::Age`'s cleanliness is incidental.** Crypt::Age is pure Perl over
  CryptX, and the primitive underneath its data key —
  `chacha20poly1305_decrypt_verify` — is non-terminated 300/300. The data key
  arrives terminated only because `Crypt::Age::Primitives::decrypt_payload` ends
  in `join('', @plaintext_chunks)`, which is a Perl-built string. Nothing
  promises that; a future Crypt::Age that short-circuits the single-chunk case
  would hand back the primitive's own SV.

### Why "normalise everything foreign" is not available

The obvious rule — *a scalar returned by XS code outside this distribution is
normalised where it enters* — cannot be taken literally, because the parsers are
XS code outside this distribution too, and normalisation is not neutral.
`"$x"` produces a scalar carrying only `POK`, and ADR 0002 reads the value's
type off exactly the flags it drops. Measured:

| scalar | flags as the parser returned it | flags after `"$x"` | type before | type after |
|---|---|---|---|---|
| `YAML::XS` bare `007` | `IOK POK` | `POK` | `int` | `str` |
| `YAML::XS` bare `1.50` | `NOK POK` | `POK` | `float` | `str` |
| `Cpanel::JSON::XS` `7` | `IOK` | `POK` | `int` | `str` |
| `Cpanel::JSON::XS` `1.5` | `NOK` | `POK` | `float` | `str` |

An unconditional rule would therefore rewrite every numeric leaf in every
document as `type:str` — a wire-format change on the encrypt side, in both
formats, for any document containing a number. And it would buy nothing even if
it were free: both parsers terminate their scalars, so they were never the
hazard. They would be collateral damage only.

So the rule needs a scope. The choice this ADR makes is to put the scope *in*
the rule rather than to state the rule unconditionally and keep an unwritten
list of exceptions.

## Decision

**A foreign scalar is normalised at the boundary where this distribution starts
reading its bytes as a value. A foreign scalar that only ever passes through as
opaque, length-delimited bytes is not normalised. A scalar whose SV state is
itself the information is never normalised.**

Today that names exactly one site: `File::SOPS::Encrypted::decrypt_bytes`.

Each clause carries its own reason.

**1. At the boundary, not at the reads.** `decrypt_bytes`'s contract is "the
authenticated plaintext, as bytes", and everything that interprets those bytes
is downstream of it: the `0 + $data` and `$data + 0.0` in
`_deserialize_value`, the MAC digest in `File::SOPS::_mac_bytes`, and whatever
arithmetic a caller does with a public return value. Fixing the two conversions
would have left the third unprotected, and would have created two sites that
have to stay identical forever — the twin-that-drifts shape ADR 0002 spent a
release collapsing. One boundary is checkable by reading one method; two
conversions are checkable only by remembering.

**2. Not at the boundaries that stay opaque.** The ciphertext, the tag, the IV
and the data key are measured non-terminated in three of those four cases, and
the defect is unreachable for all four, because every consumer they have is
length-delimited: `MIME::Base64::encode_base64` (`SvPV` with a length), the GCM
and age calls (`SvPVbyte` with a length), `length`, `eq`. The precondition for
the defect is a **read that ignores `SvCUR`**, not an origin. The evidence that
those consumers really are length-delimited is that the distribution works at
all: the ciphertext handed to `encode_base64` is non-terminated on 498 of 500
calls *without* any poisoning, so a length-blind base64 would corrupt
essentially every document rather than one leaf in a hundred.

**3. Never where the SV is the information.** ADR 0002. A parser's scalar is
carrying its type in its flags, and a normalising copy is the one operation
guaranteed to destroy it.

### What the rule says about Crypt::Age

The data key falls on the opaque side and is not normalised. It is only ever a
`key` argument to length-aware XS and a `plaintext` argument to age; nothing
reads it as a number or as a C string, and nothing would break if it arrived
non-terminated.

That answer does **not** rest on the measurement above. `Crypt::Age->decrypt`
happens to return a terminated scalar today, for a reason internal to Crypt::Age
that it does not document and could change. This is stated explicitly so that a
later reader does not take 0/300 as the licence — the licence is that the data
key is never interpreted here, and it would survive Crypt::Age becoming as
non-terminating as the primitive it wraps.

### Alternatives rejected

1. **Normalise every scalar returned by foreign XS, literally.** Takes the
   parsers in and turns every `type:int` and `type:float` leaf into `type:str`
   (table above). It is not a stricter version of this rule, it is a
   contradiction of ADR 0002.

2. **Normalise every CryptX boundary — ciphertext, tag, `random_bytes` — and
   exempt the parsers by name.** This is the closest call, and it is the option
   the proposing ticket described as reading cleaner. It costs three stringifies
   and no measurable behaviour change. Rejected because **nothing pins it**: a
   stringify on the ciphertext has no test that can go red without it, since no
   reader of the ciphertext can fire the defect. The next maintainer would delete
   it as a redundant copy and would be right by every argument available at the
   site. `decrypt_bytes`'s stringify is different in kind —
   `t/18-decrypt-determinism.t` goes red without it, 3 runs out of 3. Where the
   rule can be pinned by a test it is; where it cannot, a scope that says why not
   is more durable than three comments asking to be trusted. A secondary and
   minor point in the same direction: each stringify of key material leaves one
   more unwiped copy of it on the heap.

3. **Fix at the numeric conversions in `_deserialize_value`.** The shape the
   pre-cf2bb15 investigation started with. Two sites that must not drift, and it
   misses both the MAC path and the public return value of `decrypt_bytes` — a
   caller doing arithmetic on the bytes it hands back would still get the wrong
   number.

4. **Wait for the upstream fix.** The report is drafted (`refs/cryptx-pv-defect.md`,
   k42) and it is the correct fix, but it fixes the machines that upgrade.
   The workaround costs one character and cannot be withdrawn when the fix lands
   either, because this distribution cannot re-install its users' CryptX. The two
   are different timescales, not alternatives.

5. **Assert the invariant instead of copying — check `SvPVX[SvCUR]` and croak.**
   Reading that byte from Perl means `pack 'P'` address arithmetic on a buffer
   Perl does not promise is readable. That is a legitimate technique for the
   probe that produced the tables above; it is not something to ship, and it
   would turn a one-character fix into a new way to crash.

## Consequences

### What changes for existing callers

**Nothing.** The rule was already in the tree as of cf2bb15; this ADR adds no
code and moves no bytes. `decrypt_bytes` returned the plaintext before and
returns the same plaintext now — the normalisation is on the read side of an
already-written document and cannot change a byte any other implementation sees.
Encrypt-side wire bytes are untouched in both formats.

The only caller-visible difference is the one cf2bb15 already shipped:
`File::SOPS->decrypt` no longer returns a wrong number on roughly one round trip
in thirty.

### The cost of scoping: the rule is a precondition on reads

An unconditional rule is checked once, when a dependency is added. This one has
to be checked when a **read** is added. Concretely: before writing a new
`0 + $x`, `$x + 0.0`, `sprintf '%d'/'%g'`, or any other numeric or C-string read
of a scalar this distribution did not build itself, ask where the scalar came
from.

Every numeric read in the tree today is covered:

- `Encrypted::_deserialize_value` reads `decrypt_bytes`'s output — normalised at
  the boundary, which is the whole point.
- `Encrypted::value_to_bytes`, `assert_representable` and `_float_bytes` read
  scalars that came from a parser or from a caller. Both parsers terminate
  (measured 0/300).
- `_float_bytes`'s `$g + 0 == $n` reads its own `sprintf` output.

One case is outside what this rule can reach: a caller who hands
`File::SOPS->encrypt` a scalar taken straight out of some *other* XS module's
non-terminating return. The rule governs scalars this distribution obtains
itself; it cannot govern the ones it is given. That is the same boundary ADR
0002's contamination note draws, for the same reason.

### What it does not protect against

The defect class is "a Perl read that ignores `SvCUR`". Numeric conversion is
the member of it that has bitten. The other member is an XS function taking
`char *` through `SvPV_nolen` and `strlen`; nothing in this distribution's path
does that today. Because the rule is stated in terms of reads rather than of
CryptX, it extends to such a function without amendment — the question to ask at
a new call is the same one.

## Notes

Every number above is from this machine — perl 5.36.0, CryptX 0.087, Crypt::Age
0.001, glibc — and from a probe, not from reading the CryptX XS. The poisoning
matters to how the numbers read: without it the same calls look almost harmless.
`Crypt::PRNG::random_bytes` measures 1 non-terminated return in 500 on an
unpoisoned allocator and 299 in 300 on a poisoned one. That gap is why the
original defect took 4000 iterations to find, and it is why "measured
terminated" and "structurally terminated" are kept apart everywhere above:
only `hmac`, the GCM tag and the two parsers are the second kind.

The rule is pinned where it can be pinned. `t/18-decrypt-determinism.t` runs
3000 leaf decryptions and asserts the result is identical every time; it is
statistical by necessity, because the defect only fired when the trailing byte
happened to be a digit, and it says so in its own comments. It was verified red
before cf2bb15 and green after. Nothing pins clause 2 of the decision, and that
is deliberate — see rejected alternative 2.
