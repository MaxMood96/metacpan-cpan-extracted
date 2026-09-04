# ADR 0002 — A value's type comes from the scalar the parser produced, not from a pattern match on its text

- Status: accepted
- Date: 2026-08-09
- Tags: types, mac, interop, wire-format
- Supersedes nothing; extends ADR 0001 (same digest, different half of it)

## Context

Every leaf in a SOPS document carries a declared type on the wire:

    ENC[AES256_GCM,data:…,iv:…,tag:…,type:str]

The type is not decoration. It decides two things that must agree between
producer and consumer or the file is unreadable:

1. **What the ciphertext's plaintext is.** `type:bool` is stored as the byte
   string `True`/`False`, `type:int` as a decimal integer, `type:float` as a
   decimal float, `type:str` as the string itself.
2. **What the MAC covers.** The digest is taken over exactly those plaintext
   bytes, on both sides — and Go rebuilds them by parsing the plaintext
   according to the declared type and re-serializing it (`ToBytes` in
   `stores.go`). So a producer whose plaintext is not the *canonical* form for
   the type it declared computes a digest over bytes the verifier will never
   reproduce.

File::SOPS derived the type by pattern-matching the scalar's text:

```perl
return 'bool'  if $value eq 'true' || $value eq 'false';
return 'int'   if $value =~ /^-?\d+$/;
return 'float' if $value =~ /^-?\d+\.\d+$/;
return 'str';
```

The Go implementation does nothing of the kind. It takes the type from the
value the YAML/JSON parser handed it — a `bool` is a `bool` because the parser
returned `bool`, not because the text spelled `true`. Measured against sops
3.13.3 with this document:

```yaml
q_false: "false"    b_false: false
q_true:  "true"     b_true:  true
q_one:   "1"        b_int:   1
q_zero:  "0"        b_float: 1.50
q_padded: "007"     b_padded: 007
q_float: "1.50"     b_e:     1e20
q_e:     "1e20"
```

`sops -e` produced, and the plaintexts inside those values decrypt to:

| key        | type    | plaintext                 |
|------------|---------|---------------------------|
| `q_false`  | `str`   | `false`                   |
| `q_true`   | `str`   | `true`                    |
| `q_one`    | `str`   | `1`                       |
| `q_zero`   | `str`   | `0`                       |
| `q_padded` | `str`   | `007`                     |
| `q_float`  | `str`   | `1.50`                    |
| `q_e`      | `str`   | `1e20`                    |
| `b_false`  | `bool`  | `False`                   |
| `b_true`   | `bool`  | `True`                    |
| `b_int`    | `int`   | `1`                       |
| `b_float`  | `float` | `1.5`                     |
| `b_padded` | `int`   | `7`                       |
| `b_e`      | `float` | `100000000000000000000`   |

Identical results for the same document written as JSON. Two rules fall out of
that table, and File::SOPS obeyed neither:

- **Quoting decides the type.** Every quoted scalar is `type:str`, whatever it
  spells. Only a bare `true`/`false` is `type:bool`.
- **A numeric plaintext is canonical, not verbatim.** `007` is stored as `7`,
  `1.50` as `1.5`, `1e20` as `100000000000000000000`, `1.0` as `1`, `0x10` as
  `16`, `.5` as `0.5`. Go writes `strconv.Itoa` / `strconv.FormatFloat(v, 'f',
  -1, 64)` output, never the source text.

Both failures are two-directional and both are silent:

- **sops → us.** A document containing `flag: "true"` round-trips through
  File::SOPS as a boolean, and `id: "007"` as the integer 7. The value is
  quietly changed on its way through a library whose entire job is not to
  change it.
- **us → sops.** `File::SOPS->encrypt(data => { padded => '007' })` wrote
  `type:int` with plaintext `007`. Go recomputes the MAC as `ToBytes(7)` =
  `7`, gets a different digest, and `sops -d` refuses the file outright. Same
  for `'1.50'` as `type:float`. Our own suite could not see it: our encrypt
  and decrypt sides were wrong together, so the file verified against itself.

The information the pattern match was guessing at is not lost — it is sitting
on the scalar. Perl distinguishes a string from a number in the SV, and both
parsers preserve the distinction. Measured:

| source                         | public SV flags |
|--------------------------------|-----------------|
| YAML::XS `"007"`               | `POK`           |
| YAML::XS `007`                 | `IOK POK`       |
| YAML::XS `1.50`                | `NOK POK`       |
| YAML::XS `true`                | `ROK` (JSON::PP::Boolean) |
| Cpanel::JSON::XS `"007"`       | `POK`           |
| Cpanel::JSON::XS `1`           | `IOK`           |
| Cpanel::JSON::XS `1.50`        | `NOK`           |
| Perl literal `'5432'`          | `POK`           |
| Perl literal `5432`            | `IOK`           |
| Perl literal `3.14`            | `NOK`           |

The two parsers differ in whether they keep the source text alongside the
number (YAML::XS does, Cpanel::JSON::XS does not), but they agree on the only
thing that matters: **a string has `POK` and neither `IOK` nor `NOK`; a number
has `IOK` or `NOK`.** The flags survive assignment, being pushed through an
arrayref, and being compared with `eq` — every copy the tree walk makes.

## Decision

**The type and the wire bytes are both read off the scalar, in one place.**

`File::SOPS::Encrypted` gains two class methods that are the single source of
truth for the value → wire mapping, and `File::SOPS`'s MAC path calls them
instead of keeping its own copy:

- `detect_type($value)` — `bool` for a `JSON::PP::Boolean`, `int` for a scalar
  with public `SVf_IOK`, `float` for public `SVf_NOK`, `str` otherwise.
- `value_to_bytes($value, $type)` — the plaintext, which is also the MAC
  digest input: `True`/`False` for a boolean, canonical decimal for a numeric
  scalar, the string verbatim for anything else.

Four things about this are deliberate:

- **Nothing is "carried" through the walk.** The obvious reading of the defect
  is that the walk loses type information and has to be threaded with it. It
  does not: the walk passes the parser's own SV, and the SV *is* the type
  information. The fix is to stop discarding it by pattern-matching the text,
  not to build a parallel channel. This is what keeps the change small enough
  to be reviewable — no new tree structure, no second parse, no wrapper
  objects.
- **Public flags, not private ones.** Perl sets the private `SVp_IOK`/`SVp_NOK`
  on any scalar that has merely been *used* numerically. Reading those would
  make `_encrypt_tree`'s own `$node eq ''` guard, or a caller's `if
  ($cfg->{port} > 1024)`, change the file's type field. The public flags are
  set on far fewer occasions (see Consequences for the one that remains).
- **The two type ladders become one.** `Encrypted::_detect_type` and
  `SOPS::_detect_type_for_mac` were separate implementations of the same rule
  that had to stay byte-identical, one producing the ciphertext and the other
  the digest over it. That is the shape of this distribution's signature bug:
  when they drift the two are *consistently* wrong and only the Go binary
  notices. `SOPS::_detect_type_for_mac` is deleted and
  `SOPS::_value_to_bytes` becomes a one-line delegation.
- **An explicit `type` argument overrides the label, not the bytes.**
  `encrypt_value(value => '007', type => 'int')` writes the label `int` and
  the bytes `007`, because the caller passed a string and strings are written
  verbatim. That is the only way to express "a foreign producer wrote these
  exact bytes under this label", which is what `t/07-mac.t`'s hand-built
  fixtures need in order to test the decrypt side without a binary.

**Amended by k89 — the ladder gains its one exception, and the rule above
is what decides it.** Perl caches an `IV` on an `NV` whenever the cast
round-trips and sets the **public** `IOK` when it does, so a **negative zero**
reached the `int` rung and the sign was gone from the wire and from the digest.
The rung now asks, of a scalar publishing both halves, whether its float half
is a negative zero — the one value whose cached integer is a different number.
Still the scalar deciding and not its text, still one ladder: one value, one
rung, one extra question. See ADR 0015.

**Amended by k90 — Perl's own boolean SV is a `bool`, and it is asked
above `int`.** Since 5.36, `!!1`, `!!0` and every comparison's result carry
`SvIsBOOL`, which publishes `IOK`, so the `int` rung claimed them: the digest
covered `1`/`0` while both emitters wrote a bare `true`/`false`, and the
document failed its own MAC. The ladder gains a rung above `int` that asks
`builtin::is_bool` — the same predicate the emitters ask, so the type and the
token cannot drift apart. This is not a return to the pattern match either:
nothing reads the value's text, only a mark Perl put on the scalar. See ADR
0016.

### Canonical numeric plaintext

Taking the type from the scalar forces the second half. Once a bare YAML
`1.50` is `type:float` because the parser said `NOK` — rather than because its
text matched `/^-?\d+\.\d+$/` — the bytes can no longer be that text: Go will
re-derive them as `1.5`. So `value_to_bytes` produces:

- `int`: `0 + $value`, stringified. Perl's IV/UV stringification is
  `strconv.Itoa`'s output for every value in range.
- `float`: the shortest `%g` representation that still compares equal to the
  original, with any exponent expanded into positional notation. This is
  `strconv.FormatFloat(v, 'f', -1, 64)` reimplemented; it is pinned by a table
  of values taken from sops output rather than derived from the Go docs.

This is not scope creep away from the type question — it is the same question.
A type label without the matching byte form is a file the reference
implementation rejects, and the ADR would otherwise have to record a rule that
is knowingly half-applied.

### Alternatives rejected

1. **Keep the pattern match, add exceptions.** Every exception is a guess
   about a value's origin made at the point where the origin is no longer
   visible. It also cannot express the distinction at all: `"1"` and `1` are
   the same text.
2. **Thread a type map alongside the walk, recovered from a second parse** —
   the shape ADR 0001 used for key order. It works, but it buys nothing here:
   key order genuinely is absent from a Perl hash, whereas the type is present
   on the scalar. It would add a second document parse to the encrypt side,
   which currently has none, and would leave the "not from a parser" case
   (a Perl structure passed straight to `encrypt`) with no answer at all.
3. **Wrap every parsed scalar in a typed object.** Exact and origin-explicit,
   and it would survive a caller numifying a value. It also changes what
   `decrypt` returns to something no caller can `is_deeply` against a plain
   structure, and makes `File::SOPS` a data-model library rather than a codec.
   Rejected on API cost, not on correctness.
4. **`Scalar::Util::looks_like_number`.** Answers a different question — it
   tests the *text*, so it says true for `"007"`. It is the same defect with a
   module in front of it.
5. **Read `SVp_IOK`/`SVp_NOK` (JSON::PP's `_looks_like_number` rule).** Those
   are set by any numeric use, including our own tree walk's `eq ''` on
   neighbouring code paths and any arithmetic a caller did before handing the
   structure over. It would make the wire format depend on operations that
   have nothing to do with the value.

## Consequences

### Values with no parser behind them

`File::SOPS->encrypt(data => \%perl_hash)` has no document to take types from.
The rule is that **there is no separate rule**: Perl's own literals set exactly
the flags the parsers set, so a structure built in Perl encrypts identically to
the same structure loaded from the file it would have been written to.

- `{ port => 5432 }` → `type:int`, plaintext `5432`
- `{ port => '5432' }` → `type:str`, plaintext `5432`
- `{ ratio => 1.5 }` → `type:float`, plaintext `1.5`
- `{ flag => JSON->true }` → `type:bool`, plaintext `True`
- `{ flag => 'true' }` → `type:str`, plaintext `true`

Perl has no native boolean, so `type:bool` requires a `JSON::PP::Boolean` —
`JSON->true`/`JSON->false`, or a `true`/`false` loaded from YAML or JSON. This
is the one place where the answer is "you must say what you mean", and it is
unavoidable: the alternative is the string-matching rule this ADR removes.

### Wire bytes that move for existing callers

Any caller passing a *string* that looks like something else now gets a
different file. This is the point of the change, but it is a break:

| `encrypt(data => …)`   | 0.002 wrote        | now writes         |
|------------------------|--------------------|--------------------|
| `{ v => 'true' }`      | `type:bool` `True` | `type:str` `true`  |
| `{ v => 'false' }`     | `type:bool` `False`| `type:str` `false` |
| `{ v => '1' }`         | `type:int` `1`     | `type:str` `1`     |
| `{ v => '007' }`       | `type:int` `007`   | `type:str` `007`   |
| `{ v => '1.50' }`      | `type:float` `1.50`| `type:str` `1.50`  |
| `{ v => 1.50 }`        | `type:float` `1.50`| `type:float` `1.5` |
| `{ v => 1e20 }`        | `type:float` `1e+20` | `type:float` `100000000000000000000` |

The bottom three rows were files `sops -d` refused; the top rows were files it
accepted while returning a value the caller never supplied. Round trips change
accordingly: `'true'` comes back as the string `'true'` rather than as
`JSON->true`, and `'007'` as `'007'` rather than as `7`. Existing *encrypted
documents* are unaffected — nothing about reading them changes, because the
type on the wire is read from the file.

### The one contamination case that remains

Perl sets public `IOK`/`NOK` on a string scalar the moment it is used in
numeric context, in place:

```perl
my %cfg = (port => '8080');
if ($cfg{port} > 1024) { ... }        # $cfg{port} is now IOK|POK
File::SOPS->encrypt(data => \%cfg);   # writes type:int
```

There is no way to detect this after the fact — the resulting SV is
indistinguishable from a parsed bare `8080`. It is inherent to reading Perl's
type rather than a document's, and it is the price of alternative 3 not being
taken. Callers who need certainty should pass the value through
`File::SOPS::Encrypted->encrypt_value` with an explicit `type`, or avoid using
the structure numerically before encrypting it. `File::SOPS->encrypt` has no
per-leaf type override today; that is a gap, not a decision (k30).

### Type detection now depends on the parser, so parsers can disagree

YAML 1.1/1.2 resolution differences between YAML::XS and Go's `yaml.v3` become
visible as type differences where they were previously flattened by the
pattern match. Measured: sops types `0x10` and `1_000` as `int` (16 and 1000);
YAML::XS does not resolve either, so File::SOPS types them `str`. This is a
parser divergence, not a rule divergence, and it is out of scope here — it
changes what a value comes back as, never whether the file verifies. Recorded
as k29.

### Two numeric limits this does not reach

The canonical form is only as good as Perl's number. `type:int` is
deserialized with `int()`, which routes an integer past the IV range through a
double: sops writes `12345678901234567890` and File::SOPS reads back
`12345678901234567000`, then writes a plaintext Go refuses outright
(`strconv.Atoi: value out of range`). That is a pre-existing defect on the
deserialization side, untouched here and recorded as k28. And
`_float_bytes` is `float64` arithmetic throughout, so it inherits every limit
`strconv.FormatFloat` has and none it does not — which is the point, since Go
is doing the same arithmetic on the other side.

## Notes

Everything in the tables above was produced by running sops 3.13.3 and reading
the bytes back, not by reading `stores.go`. The float formatter in particular
was written against measured output — `1.0` → `1`, `.5` → `0.5`,
`0.00000015` → `0.00000015`, `1e20` → `100000000000000000000` — because
"shortest representation that round-trips, in positional notation" is easy to
implement almost-correctly.

The rules are pinned by tests that need no binary (`t/06-wire-format-regressions.t`
for the type table and the numeric forms, `t/07-mac.t` for the digest
agreement), because a suite that only proves this against `sops` proves it on
the machines that have `sops`. `t/04-interop.t` covers quoted scalars in both
directions, which is the hole that let this defect live through two releases.
