# ADR 0009 — A decrypted float comes back as a float, whatever its digits spell

- Status: accepted
- Date: 2026-08-20
- Tags: float, types, mac, wire-format, json, interop
- Resolves k73
- Depends on ADR 0002 (a value's type comes from the scalar's SV flags — this
  is the same rule applied to the scalar *we* manufacture) and ADR 0006 (the
  canonical float text and the emitters' rendering of a bare NV)

## Context

`File::SOPS::Encrypted::_deserialize_value` turned a `type:float` plaintext
into a Perl number with `$data + 0.0`. For an **integral** plaintext that
addition hands back a scalar carrying the public `SVf_IOK` flag: Perl's
`grok_number` settles a text like `2` as an integer, and `pp_add` calls
`SvIV_please` on an integral result. `_sv_kind` reads exactly those public
flags, so `detect_type` calls the value an **int**, and the next write labels
the leaf `type:int`.

The label the document itself carried is discarded on the way through, by our
own conversion. ADR 0002 is working precisely as written — the type comes from
the SV — but the SV it is reading was not produced by a parser or handed over
by a caller. We made it, and we made it the wrong shape.

Measured end to end against sops 3.13.3, one document per format, `sops -e` of
`whole: 2.0, negwhole: -2.0, zero: 0.0, half: 1.5, ratio: 0.30000000000000004`:

| leaf | sops wrote | after our `rotate` |
|---|---|---|
| `whole` | `type:float` | `type:int` |
| `negwhole` | `type:float` | `type:int` |
| `zero` | `type:float` | `type:int` |
| `half` | `type:float` | `type:float` |
| `ratio` | `type:float` | `type:float` |

Both formats, three of five leaves relabelled. `sops -d` exits 0 before and
after and prints `whole: 2` both times, so **nothing fails**: the plaintext is
`2` under either label and the digest covers `2` either way. What changes is
the document's own type field, silently, on a document sops wrote. Go keeps
`type:float` there, because `yaml.v3` hands it a `float64` and it never
re-derives the type from the digits.

The same read also decides how the plaintext emitters render the value, so the
defect had a second, invisible face: `decrypt_file` on that JSON document wrote
`"whole": 2`, which parses back as an integer, so a `decrypt_file` → edit →
`encrypt_file` round trip relabelled the leaf as well.

The full read ladder, `encrypt_value(type => 'float')` → `decrypt_value` →
`value_to_bytes`, 37 plaintexts. Twelve of them came back as `int`:

    0  +0  1  -1  2  -2  1e2  100  -100  1e-400
    9007199254740993  9223372036854775807

and the remaining 25 — every non-integral value, every non-finite one, and
every negative zero (ADR 0006 / k72 already returns a literal `-0.0`
there) — came back as `float`.

## Decision

**The float branch converts through the double itself, not through Perl's
arithmetic:**

```perl
my $number = unpack('d', pack('d', $data));
```

`pack 'd'` takes the scalar's numeric value and lays it out as a native
double; `unpack 'd'` builds a fresh SV from those eight bytes with `sv_setnv`,
so the result carries `SVf_NOK` and nothing else. Measured across the ladder
above, every one of the 37 rows now reports `float`, and no other conversion
does this — `$data + 0.0`, `0.0 + $data` and `$data * 1.0` all set `IOK` on an
integral result, and `Scalar::Util::dualvar` **inherits** it from its numeric
argument.

Three things about this are deliberate:

- **It is one conversion, not a conversion plus a correction.** The obvious
  alternative is to keep `+ 0.0` and teach `detect_type` about the wire label,
  which is the second type ladder ADR 0002 deleted. The label is already
  encoded in the value's flags once the value is built correctly; nothing
  needs to be carried alongside it.
- **It goes through a 64-bit double on purpose.** `pack 'd'` is `float64`
  whatever Perl's own NV is, which is what Go parses the plaintext into. On a
  `-Duselongdouble` or `-Dusequadmath` Perl the old path could hold a value Go
  cannot, and would then re-derive digits the other side never wrote.
- **The sign branch stays.** `pack 'd'` on the text `-0` still yields a
  positive zero — Perl's numeric conversion settles that text as an integer
  zero before `pack` ever sees a double — so the explicit negative-zero
  restoration from ADR 0006 / k72 is still doing the work, and its
  throwaway-copy comparison is still load-bearing for the same reason.

### The digits change for a float that never was one

Two ladder rows move their **bytes**, not just their label:

| plaintext | was | now |
|---|---|---|
| `9007199254740993` | `9007199254740993` (as `type:int`) | `9007199254740992` |
| `9223372036854775807` | `9223372036854775807` (as `type:int`) | `9223372036854776000` |

`+ 0.0` preserved those digits by accident: Perl did the addition in IV
arithmetic and kept an exact integer that no `float64` can hold. Go's
`strconv.ParseFloat` gives `9007199254740992` for the first, so a document
carrying such a plaintext already meant that number to the reference
implementation, and our exactness was a private opinion attached to a wrong
label. sops cannot write such a value itself — every float it emits is a
`FormatFloat` of a `float64` — so this is reachable only from a hand-built or
foreign document. `decrypt_bytes` still returns the plaintext digits verbatim,
which is how the original text is recovered.

## Consequences

### Wire bytes that move

For every integral `type:float` leaf: the label goes back to `float` and
**stays** `float` across `rotate`, `edit` and any re-encryption. That is the
fix, and it is a wire change — a self-produced document from before this
release has `type:int` where one produced after it has `type:float`. Both are
read by both implementations; the plaintext bytes are identical, so the MAC is
identical, and no existing file becomes unreadable.

The plaintext digest input is unchanged for 35 of the 37 measured rows, and
moves only for the two beyond-2^53 rows above.

### `decrypt_file` writes `2.0` where it wrote `2`, in JSON only

`Cpanel::JSON::XS` renders a bare NV of 2 as `2.0`; `YAML::XS` renders it as
`2`, through Perl's stringification. Measured on a sops-written document with
an encrypted `type:float` of `2.0`:

| | before | after | `sops -d` prints |
|---|---|---|---|
| YAML | `whole: 2` | `whole: 2` | `whole: 2` |
| JSON | `"whole": 2` | `"whole": 2.0` | `"whole": 2` |

So our JSON plaintext output now differs from `sops -d`'s by one rendering
choice, and our YAML output still matches it exactly. This is accepted rather
than papered over, for two reasons. It is the same defect seen from the other
end — the `2` was written *because* the value had been retyped to int, so a
JSON emitter that keeps writing `2` is the bug preserved in the one place it is
visible. And it is the more faithful of the two: `2.0` parses back as a float,
so `decrypt_file` → edit → `encrypt_file` keeps the leaf a `type:float`, where
`2` silently makes it a `type:int`. The plaintext file is not a SOPS document,
carries no MAC, and `sops -e` accepts `2.0` in JSON.

The YAML side keeps the round-trip defect, and keeps it *because* sops has it
too: `sops -d` writes `whole: 2`, YAML resolves that as an integer, and
`sops -e` of its own output writes `type:int`. Diverging there would mean
disagreeing with the reference about a plaintext document, which is a worse
trade than agreeing with it about a lossy one.

### What changes for existing callers

A caller who receives a decrypted structure gets a scalar with `NOK` where they
used to get one with `IOK`, for an integral float. Nothing in Perl separates
them at the language level: `==`, `<=>`, `printf '%d'`, `sprintf '%s'` and
`is_deeply` all behave identically, and both stringify as `2`. The difference
is visible to `B::svref_2object`, to `JSON::MaybeXS` (which now writes `2.0`)
and to `File::SOPS` itself, which is the point.

`decrypt_bytes` is unchanged in every case, so anything that hashes or logs the
authenticated plaintext is unaffected.

## Rejected alternatives

**Return a `dualvar` of the number and its canonical text.** It looks like it
solves this and k61's `extract` half in one place, and it does not solve
this one at all: measured, `dualvar($data + 0.0, '2')` carries `IOK|POK` — the
flag is inherited from the numeric argument, so the value is still an `int` to
`detect_type` unless the *numeric half* is fixed first, which is this ADR.
It also cannot live in the decrypt tree: `Cpanel::JSON::XS` writes a dualvar as
a **quoted string** (measured: `"0.30000000000000004"` where a bare NV gives
`0.30000000000000004`), and `File::SOPS::Format::JSON::_float_roundtrips`
cannot catch it, because the string it reads back re-derives its own text
through `value_to_bytes` and compares equal. `YAML::XS` emits the dualvar's PV
verbatim, so a `1e300` leaf would be written as 301 positional digits. See
ADR 0010, which puts the dualvar at `extract`'s boundary instead, where no
emitter sees it.

**Keep `+ 0.0` and pass the wire type down to `detect_type`.** A second source
of truth for a leaf's type, alongside its SV — exactly the shape ADR 0002
deleted, and the shape whose two copies drift into being consistently wrong
together. It also answers nothing for a value that reaches an emitter without
passing the point where the type was threaded.

**Restore `NOK` by re-reading the plaintext text at type-detection time.**
Pattern-matching a value's text is what ADR 0002 removed, and it would have to
run in `detect_type`, which sees values that have no plaintext behind them at
all.

**`POSIX::strtod`.** It produces a clean NV, and it reads the decimal point
from `LC_NUMERIC`, so a caller running under a locale with a decimal comma
would change what this library decrypts. `pack`/`unpack` has no locale.
