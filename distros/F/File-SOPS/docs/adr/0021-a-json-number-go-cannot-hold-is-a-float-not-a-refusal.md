# ADR 0021 — A JSON number Go cannot hold is a float, not a refusal

- Status: **proposed** — written as a form decision before any code, the way
  k63's pass wrote ADR 0020. Every table below comes from a measurement
  against sops 3.13.3 at `/tmp/sops`, with the guard under discussion switched
  off in a scratchpad monkey-patch rather than in `lib/`. The implementing
  lanes correct it where they measure something else, marked where it sits
  rather than smoothed over; lane 1 (`file-sops-wire`) has run and left two
  corrections, in "The two gates" and in "What changes for existing callers".
  A third correction landed 2026-08-21 as k107: the cross-format YAML
  rows split on `uint64max`, and that is not the discriminator — measured, it
  is whether ADR 0011's repair has to fire at all. Marked where it sits, in
  "The two gates".
- Date: 2026-08-20
- Tags: int, float, json, wire-format, guards, interop, parser
- Resolves k101
- Depends on ADR 0002 (the type comes from the SV's public flags, which is why
  the answer has to be a different SV and not a different label), ADR 0005 (the
  JSON backend is named, so its decoder is ours to walk), ADR 0006 (the
  `roundtrips`/`carrier` pair, and `FormatFloat(v,'f',-1,64)` as a float's
  digest), ADR 0011 (the float repair this leaf then takes), ADR 0013 (the YAML
  side, which stays exactly as it is) and **ADR 0020**, whose mechanism this
  extends by one magnitude downwards
- Neighbour, deliberately **not** resolved here: k104, the same window for
  a value that did not come from a JSON parse
- Contradicts k101's own analysis in one place, and the contradiction is
  the reason the fix is one gate instead of a slot-dependent guard: see
  "What the ticket got wrong"

## Context

`File::SOPS->rotate` croaks, exit 255, on a JSON document `sops -e` wrote and
`sops -d` reads. Reproduced at f1c1471:

    $ echo '{"keep":"x","b_unencrypted":9223372036854775808}' | sops -e …
      -> "b_unencrypted": 9223372036854776000        exit 0
    $ sops -d that file                                exit 0
    $ File::SOPS->rotate that file
      b_unencrypted: value is an integer outside the range the SOPS int type
      can hold (-9223372036854775808 .. 9223372036854775807, Go's int64) …

`sops -e` normalises a JSON number wider than `int64` by writing the `float64`
back out. `9223372036854775808` becomes `9223372036854776000`, which is still
above `int64max` but **below** `uint64max`, so `Cpanel::JSON::XS` decodes it as
a Perl UV, `detect_type` calls it an `int`, and
`Encrypted::assert_representable` refuses it.

ADR 0020 named this row as its neighbour and deliberately left it open. It is
the middle row of that ADR's own boundary table — the one window where
**Perl can hold the integer and Go cannot**:

| range | plain decode | before ADR 0020 | after ADR 0020 | after this ADR |
|---|---|---|---|---|
| `… 9223372036854775807` | `IOK` | int | int | int |
| `9223372036854775808 … 18446744073709551615` | `IOK` | **croak** | **croak** | **float** |
| `18446744073709551616 …` | `POK` | str | float | float |
| `… -9223372036854775808` | `IOK` | int | int | int |
| `-9223372036854775809 …` | `POK` | str | float | float |

The window is positive-only, because an `IV` cannot go below `int64min`;
`-9223372036854775809` is already a plain PV and already ADR 0020's leaf.

### What sops itself does with this window

Measured, sops 3.13.3, one `sops -e` per row, the same literal in an encrypted
slot (`v`) and an unencrypted one (`u_unencrypted`):

| literal | `type:` sops writes | `sops -d` gives back | unencrypted slot rewritten as |
|---|---|---|---|
| `9223372036854775807` | `int` | `9223372036854775807` | `9223372036854775807` |
| `9223372036854775808` | **`float`** | `9223372036854776000` | `9223372036854776000` |
| `9223372036854775809` | **`float`** | `9223372036854776000` | `9223372036854776000` |
| `9223372036854776000` | **`float`** | `9223372036854776000` | `9223372036854776000` |
| `9223372036854776001` | **`float`** | `9223372036854776000` | `9223372036854776000` |
| `9223372036854777000` | **`float`** | `9223372036854778000` | `9223372036854778000` |
| `9300000000000000000` | **`float`** | `9300000000000000000` | `9300000000000000000` |
| `10000000000000000000` | **`float`** | `10000000000000000000` | `10000000000000000000` |
| `12345678901234567890` | **`float`** | `12345678901234567000` | `12345678901234567000` |
| `18446744073709551615` | **`float`** | `18446744073709552000` | `18446744073709552000` |
| `-9223372036854775808` | `int` | `-9223372036854775808` | `-9223372036854775808` |
| `-9223372036854775809` | **`float`** | `-9223372036854776000` | `-9223372036854776000` |

The switch is at `int64`, exactly, in **both slots**. ADR 0020's sentence holds
one magnitude lower without a word changed: **there is no big integer in the
SOPS data model.** Past `int64` a JSON number is a `float64` to Go, and sops
loses the digits itself before this library is ever involved.

### What the ticket got wrong

k101's analysis says the guard "is not simply wrong — for an ENCRYPTED
slot it is right", and concludes the fix has to be slot-dependent and therefore
belongs at emit time. Both halves were measured. One holds and one does not.

**The premise holds.** A `type:int` we write with such a plaintext is refused by
sops:

    Error decrypting tree: Error walking tree: Could not decrypt value:
    strconv.Atoi: parsing "9223372036854776000": value out of range   exit 25

Twelve literals across the window, written by this library as `type:int` with
the int64 rung switched off: **12 of 12 exit 25**, with `int64max` itself as
the control at exit 0. `type:int` is not available here.

**The conclusion does not.** `type:int` being unavailable is not the same as
the leaf being unwritable, because sops does not write `type:int` either — it
writes `type:float`. Measured with literals from the same window taken through
this library's ordinary float path and compared against `sops -e`'s own output
for the identical input, ciphertext plaintext included:

| literal | sops's token / plaintext | ours / plaintext | |
|---|---|---|---|
| `9223372036854775808` | `float` `9223372036854776000` | `float` `9223372036854776000` | identical |
| `12345678901234567890` | `float` `12345678901234567000` | `float` `12345678901234567000` | identical |
| `18446744073709551615` | `float` `18446744073709552000` | `float` `18446744073709552000` | identical |
| `9223372036854777000` | `float` `9223372036854778000` | `float` `9223372036854778000` | identical |

So the encrypted slot has an answer, it is the same answer the unencrypted slot
has, and it is not a refusal. **The question is not slot-dependent, and nothing
new has to run at emit time.**

### The acceptance condition the ticket asked for, measured anyway

It is the reason the slot-dependent shape was worth measuring, and it is worth
recording even though the decision does not use it as a guard. Thirty-five
literals across `[2^63 .. 2^64-1]` — both boundaries, the `±1`/`±2048` doubles
around them, the exact ties-to-even midpoints, round decimals and arbitrary
ones — put into an **unencrypted** JSON slot with the int64 rung switched off,
and handed to `sops -d`:

| the literal's text | rows | `sops -d` |
|---|---|---|
| **equals** `FormatFloat(double,'f',-1,64)` of the double it names | 14 | **exit 0, 14 of 14** |
| differs from it | 21 | **exit 51, MAC mismatch, 21 of 21** |

No exceptions in either direction. It is the same round-trip notion ADR 0006
uses and the same one the k63 pass sharpened: **digest stability is not a
numeric range, it is "the text is the shortest round-trip decimal of its
double"**. `9223372036854776832` is inside the window, ends in three zeros, and
fails — its double is `2^63` (ties-to-even) whose shortest decimal is
`9223372036854776000`. `9999999999999999999` fails. `9300000000000000000`
passes.

Every positional literal `sops -e` writes satisfies the condition by
construction, which is why a sops-written document is always in the passing
set and a hand-written one usually is not.

### YAML is a different question and stays shut

Confirmed, sops 3.13.3, plaintext YAML, both slots:

    v: 9223372036854775808     -> sops -e  exit 23
    Error encrypting tree: Error walking tree: Cannot walk value, unknown type: uint64

`gopkg.in/yaml.v3` resolves this window as `uint64`, and sops has no case for
it. Four literals across the window — `9223372036854775808`,
`9223372036854776000`, `10000000000000000000`, `18446744073709551615` — each
put in an encrypted slot and in an unencrypted one, one document per cell:
**8 of 8 exit 23**, so **sops cannot write such a YAML document at all**, in
either slot. `Format::YAML::_go_int` already models exactly this and refuses (ADR
0013). Nothing in `Format::YAML` moves.

## Decision

**`Format::JSON::parse`'s wide-number gate also fires for a bare integer
literal Perl *did* hold but Go's `int64` cannot: the leaf comes back as
`dualvar($double, $digits)`, the same leaf class ADR 0020 already produces one
magnitude higher.**

That is the whole change. Concretely, in `Format::JSON::_wide_number`, before
the existing plain-PV branch:

- the leaf publishes `SVf_IOK` — it is an integer the decoder built from a bare
  numeric literal. A JSON **string** never arrives this way: measured,
  `"9223372036854775808"`, `"18446744073709551615"`, `"5432"`, `"007"` and
  `"1e20"` all decode with `IOK` clear, so the type map ADR 0020 needs for its
  branch answers a question this branch does not have to ask;
- and it is **above `int64max`**. Only the upper bound is tested, because an
  `IV` cannot hold anything below `int64min` — the negative half of the window
  does not exist;
- then the digits are taken from the leaf and the leaf becomes
  `dualvar(unpack('d', pack('d', $digits)), $digits)` — the double the digits
  name, carrying the digits as its string half.

Everything downstream is untouched and already correct, measured leaf by leaf
on `dualvar(2^63, '9223372036854775808')` — and **re-measured by lane 1 against
the code at f1c1471**, every row confirmed, plus eleven literals across the
window through `detect_type` / `value_to_bytes` / `assert_representable` /
`Format::JSON->emit`:

| asked | answer |
|---|---|
| SV flags | `NOK+POK`, identical to ADR 0020's leaf and to what `YAML::XS` returns for the same digits |
| `detect_type` | `float` |
| `value_to_bytes` | `9223372036854776000` — Go's `FormatFloat(v,'f',-1,64)` |
| `assert_representable` | passes; the `int64` rung only looks at an `int` kind |
| ADR 0012's integer guard | never fires — that branch is `$kind eq 'int'` |
| ADR 0011's float repair | fires as designed; `_float_carrier` writes the canonical decimal as a **bare number** |
| `Format::JSON->emit` | `{ "v" : 9223372036854776000 }` |
| `Format::YAML->emit` under `mac_covered` | ADR 0013 refuses it, correctly — Go would read a `uint64` |
| `_reject_referenced_leaf` | never sees it — not a reference |

Lane 1 also took the leaf class itself the whole way, without the parser gate:
the `dualvar` handed straight to `File::SOPS->encrypt`, the document to
`sops -d`. **Thirteen cells, both slots, both formats.** Every JSON cell is
`sops -d` **exit 0** with the value sops's own normalisation gives it —
`9223372036854775808` and `12345678901234567890` and `9300000000000000000` and
`18446744073709551615`, encrypted slot and unencrypted one alike. So the wire
half of this decision holds independently of how the leaf is produced, which is
the half this ADR is actually about.

The **YAML** cells are the interesting ones, and they are not uniform. A caller
can reach them by parsing JSON and emitting YAML, which is a supported crossing:

| cross-format cell | result |
|---|---|
| encrypted slot, whole window | written `type:float`, `sops -d` **exit 0** |
| unencrypted slot, `%.15g` form round-trips | written in **exponent** notation, `sops -d` **exit 0** |
| unencrypted slot, `%.15g` form does not round-trip, canonical decimal ≤ `uint64max` | **croak**, ADR 0013's message |
| unencrypted slot, canonical decimal > `uint64max` | written bare, `sops -d` **exit 0** |

**Corrected 2026-08-21, k107.** This table had three rows and split them on
`uint64max` alone, which is measurably not the discriminator. The sweep that
found it: 12 literals across the window × 2 formats × 2 slots, the float answer,
against sops 3.13.3 — 7 of 48 cells croak, all of them unencrypted YAML, but
`9300000000000000000`, `9999999999999999999` and `18000000000000000000` have a
canonical decimal **well below** `uint64max` and reach that slot at `sops -d`
exit 0. The full series is in the comment block above the `int64` croak in
`lib/File/SOPS/Encrypted.pm`.

The real split sits **upstream of `_go_int`**, and it is ADR 0011's repair
deciding whether it has to fire. `YAML::XS` writes Perl's `%.15g` form. Where
that form round-trips to the same double — `9.3e+18`, `1e+19`, `1.8e+19` — the
leaf goes out in exponent notation, which `_go_int` does not match at all, so
ADR 0013 never looks at it. Where it does not round-trip, the repair writes the
bare canonical decimal instead and `_go_int` reads a `uint64` there: refusal.
Two ways through the unencrypted slot, not one.

The last row is still not a hole in ADR 0013, but its reason is the second of
those two paths rather than a rule of its own: `18446744073709551615` does not
round-trip through `%.15g`, so the repair writes its canonical decimal
`18446744073709552000` bare — and *that* is past `uint64max`, so `yaml.v3`
resolves it as a float and `_go_int` correctly declines to refuse it. The rows
together are what the consequences table's YAML row should have said, and did
not — see the correction there.

### The two gates, and why they are in that order

The cheap fact about the leaf comes first and the conversion second — the same
discipline ADR 0012 states for its own guard, and here it is the difference
between free and expensive. Measured, `Format::JSON->parse` of a 3000-leaf
document containing 1000 integers, 40 iterations:

| gate | ms/parse |
|---|---|
| baseline (no change) | 4.14 / 4.86 |
| flag test, then one numeric comparison, then the conversion for what passes | **3.78 / 3.77** |
| `detect_type` + `value_to_bytes` on every integer leaf | 10.65 / 10.87 |

The middle row is not a typo: folding the new branch into the existing walk
reads the SV's flags **once** where `_plain_pv_leaf` read them separately, so
the gate pays for itself. The third row is what happens if the one conversion
is called before the cheap fact is checked.

The numeric comparison is safe on this leaf and would not be on the text. The
comment above `_decimal_fits_int64` records why the **decimal-text** test
exists — `0 + "-9223372036854775809"` rounds to exactly `-2^63` and answers
yes to a value Go says no to. That trap is about numifying a *string*. Here the
scalar is already `IOK`, so `$node > $INT64_MAX` is an integer comparison with
no double in it. The boundary itself must still come from
`File::SOPS::Encrypted`, not be spelled a second time in `Format::JSON`.

**Corrected by lane 1: the order is not only a cost decision, it is a
correctness one, and this section framed it as cost alone.** A numeric
comparison against an integer sets the **public** `SVf_IOK` on the scalar it
reads, in place — so a comparison made *before* the flag test does not merely
waste time on a string leaf, it retypes it. Measured on
`{"port":"5432","zip":"007","ver":"1.50","name":"x"}`, one
`$tree->{$k} > $INT64_MAX` per leaf ahead of any flag test:

| leaf | before | after the comparison | written |
|---|---|---|---|
| `"5432"` | `str` | **`int`** | bare `5432` |
| `"1.50"` | `str` | **`float`** | bare `1.5` |
| `"007"` | `str` | **`int`** | **croak**, ADR 0012's guard |
| `"x"` | `str` | `str` | `"x"` |

Three of four string leaves retyped, and the document either silently changes
schema or stops being writable — from a walk that never reached the window at
all. This is k32's mechanism and ADR 0002's rule, and it is the reason the
gate order is not negotiable rather than merely preferable. Two forms are safe
and no third is: **test the flag first**, so the comparison only ever runs on a
leaf that is already `IOK` and where it is a no-op, or compare a **copy**. The
predicate below does the second by construction; lane 2 must still do the
first, because that is the branch's own question.

The boundary is exposed as `File::SOPS::Encrypted->integer_fits_int64($value)`
— one comparison against the one spelling of `int64` in this distribution, next
to `_decimal_fits_int64`, which keeps its own callers. It is a *numeric*
predicate and asks nothing about the SV's kind: the caller's flag test is the
cheap fact and must come first, and a type ladder inside it would be the second
copy ADR 0002 removed. Its argument contract is "a scalar Perl holds as an
integer", and the two other kinds fail it in opposite directions, both measured:
a **float** of exactly `2^63` answers *true*, because the comparison promotes
`2^63-1` to a double and the two become the same number; a decimal **string**
`'-9223372036854775809'` answers *true* to a value Go refuses, which is the trap
`_decimal_fits_int64` exists for. Its own cost, measured, is **0.33 ms per 1000
integer leaves** — about what one `B::svref_2object` flag read costs, and ~8% of
the 4.14 ms baseline parse above. It is paid once per integer leaf, and the
middle row's budget absorbs it.

### Why the parser and not `assert_representable`

k101 asked the question as "where does a slot-dependent guard go", and
ADR 0008, 0012 and 0013 all answered their own version of it with "emit time,
never `assert_representable`". This decision does not need that answer, and the
reason is worth stating because it is the line between the two ADRs:

**`assert_representable` sees a scalar. The parser sees a document.** A caller
who hands us a Perl UV has an exact integer in hand and no reader has spoken
for it; turning that into a lossy double would be this library guessing, which
is what ADR 0012 refuses to do for the leaf one rung over. A leaf that came out
of `Format::JSON::parse` is not a guess: Go's `encoding/json` has already read
those same bytes as a `float64`, and reading them the same way is the
compatibility act ADR 0013 describes — "a pattern that decides a value's type
is a defect here; a pattern that decides whether two implementations agree
about a document is a compatibility check". Nothing here reads a pattern at
all; it reads the SV the decoder built and the boundary the reference
documents.

So `assert_representable` keeps its `int64` rung unchanged, `File::SOPS.pm`'s
call to it in `_compute_mac` is untouched, and no emitter gains a check.

## Consequences

### Wire bytes that move

For a JSON leaf that was a bare integer literal in `[2^63 .. 2^64-1]`, and for
nothing else.

- **Documents that croak today start being written.** All of them. There is no
  input that produced a file before this change and produces a different one
  after: the leaf class was unreachable.
- **Rotating a sops-written document is byte-identical to what sops wrote.**
  Nine literals, `sops -e` → our `rotate` → `sops -d`: **9 of 9 unencrypted
  slots byte-identical**, `sops -d` exit 0 for all nine. The encrypted slots
  come back `type:float`, sops's own token, with byte-identical plaintext.
- **Encrypting a hand-written document writes what `sops -e` writes.** Eighteen
  literals × two slots, our `encrypt` → `sops -d`: **36 of 36 exit 0**, and
  every value matches `sops -e`'s output for the same input. On the baseline
  the same 36 cells are 12 exit 0 and **24 croaks**. The `sops -e` → our
  `rotate` → `sops -d` direction is 36 of 36 exit 0 after, against 27 exit 0
  and **9 croaks** before.
- **The digits move where sops moves them.** `9223372036854775808` is written
  `9223372036854776000` and `12345678901234567890` is written
  `12345678901234567000`. That is not a loss this decision introduces: it is
  what `sops -e` does to the identical input, measured, in both slots. The
  alternative is to go on being the only implementation that refuses the
  document.

### Corpus

Fifty JSON literal shapes through `parse` → `detect_type` → `value_to_bytes` →
both emitters, before and after: **9 rows move, and all 9 are this leaf class**
— seven scalars plus the same leaf nested in an array and in a hash. No float
row, no string row (`"9223372036854775808"` quoted is still a `str` and still
written quoted), no boolean, `null`, container, `int64max`, `int64min` or
ADR 0020 row.

`prove -lr t/` with the change prototyped: **846 of 848**, and the two failures
are `t/36` subtests 10 and 12 — the subtest whose name is *"k101 (open,
NOT fixed here): the uint64 window still stays an integer and still refuses"*,
and one row of a flags table that lists `uint64_max` as a leaf outside the
target class. Both are claims this ADR replaces on purpose.
`SOPS_BIN=/tmp/sops prove -l t/04-interop.t` **ran** and was 32/32 with the
prototype loaded.

### What changes for existing callers

| input | today | after |
|---|---|---|
| sops-written JSON, wide number in an unencrypted slot, `rotate`/`encrypt_in_place` | **croak, exit 255** | written back byte-identical, `sops -d` exit 0 |
| the same in an **encrypted** slot | already `type:float` (sops normalised it) | unchanged |
| hand-written JSON, wide number, either slot, `encrypt` | **croak** | `type:float` / bare canonical decimal, matching `sops -e` |
| a `mac_only_encrypted` document with such a leaf | **croak** | written, `sops -d` exit 0 |
| the value from `decrypt`, unencrypted slot | a Perl UV; `"$v"` and `0+$v` both the digits | a dualvar: `"$v"` still the digits, `0+$v` the **double** |
| the value from `decrypt`, **encrypted** slot | a bare NV (sops had already written `type:float`) | **unchanged** |
| the value from `extract`, **unencrypted** slot | a Perl UV printing the digits | a dualvar printing the digits (ADR 0010's shape) |
| the value from `extract`, **encrypted** slot | **already** a dualvar printing all its digits | **unchanged** |
| the plaintext `decrypt_file` writes | — | **unchanged, byte for byte** |
| a document whose unencrypted number is not its double's canonical decimal | **`MAC verification failed`** on `decrypt`, `decrypt_file` and `extract` | verifies, as `sops -d` already did |
| `detect_type` of such a leaf | `int` | `float` — the two slots now agree, where the unencrypted one used to disagree with the encrypted one |
| a **quoted** `"9223372036854775808"` | `type:str` | unchanged |
| the same digits in a **YAML document**, any slot | croak, `int64` message | **unchanged** — same croak, same message |
| the same digits **parsed from JSON and emitted as YAML** | croak, `int64` message | four outcomes, see below |
| a **caller-supplied Perl UV** in the window, not from a JSON parse | croak | **unchanged, still croaks** |

The `extract` row above is a correction, and the last two rows are consequences
this ADR first failed to name at all. The API lane measured them against a
tree carrying only `Format/JSON.pm` at the old revision.

**`extract` barely moves, and `decrypt_file` does not move at all.** The
original row said `extract` went from "a UV / a bare NV" to a dualvar in
*either* slot. Measured, the **encrypted** slot already returned a dualvar
printing all its digits, before and after — because sops had written
`type:float` there, so this library had always read a float out of it. Only the
**unencrypted** slot moves, and in it only the numeric half: `"$v"` printed the
digits before and prints them now. This is the mirror image of ADR 0020, where
the encrypted slot carried the sharpest consequence; here it carries none.

**A MAC that used to fail now verifies, and that is a bug fix nobody asked
for.** `9223372036854776832` is inside the window and its double is
`9223372036854775808`, so its text is *not* its double's canonical decimal.
`sops -d` accepts such a document — Go digests the number it parsed, not the
source text — while this library digested the integer's own digits and reported
`MAC verification failed` from `decrypt`, `decrypt_file` and `extract` alike.
After this change the leaf is a float, `value_to_bytes` derives Go's own text
from the double, and the document verifies. `decrypt_file` then writes the
value out with the same normalisation `sops -d` writes.

Three further rows need naming, and the first is a correction.

**The YAML row was wrong, and lane 1 measured it.** It said "croak, with
ADR 0013's message instead of the `int64` one", which conflates two different
inputs. A **YAML document** carrying those digits does not change at all:
`YAML::XS` still hands back a `UV`, and `File::SOPS::_compute_mac`'s
`assert_representable` sweep runs *before* anything is emitted, so it croaks
with the **`int64`** message exactly as it does today — measured at f1c1471,
`v_unencrypted: 9223372036854775808` parsed as YAML and encrypted as both
`format => 'yaml'` and `format => 'json'`, the `int64` message both times.
ADR 0013's message belongs to a different input, the **cross-format** one: a
leaf this decision's parser produced, emitted as YAML. That case has the
outcomes tabulated under "The two gates" — the encrypted slot writes
`type:float` and `sops -d` reads it, and an unencrypted slot croaks with ADR
0013's message only where ADR 0011's repair has to write the bare canonical
decimal and that decimal is still inside `uint64`. Where the `%.15g` form
round-trips the leaf leaves in exponent notation and `_go_int` never matches it,
and past `uint64max` the bare decimal is written and `sops -d` reads that too;
both of those are `exit 0`. Nothing in `Format::YAML` moves either way; what
changed is only which of its existing answers a JSON-parsed leaf can now reach.

**`0+$v` moves for a leaf the caller could read exactly before.** For a
sops-written value the two are the same number to sixteen digits and the
string half is untouched; for a hand-written `12345678901234567890` the numeric
half now rounds. It rounds to the number Go has been reading out of that
document all along — this is ADR 0020's consequence, and the same paragraph
applies.

**The caller-supplied UV keeps croaking, and that is deliberate**, not an
oversight. Measured, it is also not fully right: of the 35-literal window
sweep, 14 would have produced a working document in a JSON unencrypted slot and
are refused. The other 21 would not, and the encrypted slot and both YAML slots
are refusals in all 35. Closing that sliver needs the slot-dependent emit-time
guard k101 sketched — a `mac_covered`-style flag threaded through
`Format::JSON::serialize`, a `reject_scalar` hook the JSON emitter does not
have today, and the `int64` rung dropped from `_compute_mac`'s sweep and
re-covered by `encrypt_value` for encrypted slots. That is a second, larger
change with a much worse ratio, it loosens a guard rather than moving a parser,
and it is filed as k104 rather than folded in. The refusal's
**message** should learn
one sentence in the meantime: it currently offers only "pass it as a string",
where the answer that matches sops is now "pass it as a float".

### Cost

None measurable. See the table above: the gate is one flag read and one
integer comparison per leaf, folded into a walk that already runs, and it
measured slightly **faster** than the baseline because the flags are read once
instead of twice. The comparison is a method call rather than an inlined
constant, which is what keeps the boundary in one place: measured at **0.33 ms
per 1000 integer leaves**, against 0.11 ms inlined and 0.28 ms for the single
`B::svref_2object` flag read the walk already pays per leaf. That is the price
of not spelling `int64` twice, it is a tenth of what the rejected
`detect_type` + `value_to_bytes` shape costs, and the middle row's headroom
covers it. No new prerequisite — the branch needs nothing
`Cpanel::JSON::XS::Type` did not already bring in for ADR 0020.

### What it does not do

`Format::YAML` is untouched. `assert_representable` is untouched.
`File::SOPS::_compute_mac` is untouched. Both emitters' `reject` and
`reject_scalar` hooks are untouched. The float walk is untouched. ADR 0020's
plain-PV branch is untouched and still needs its type map. No public API,
argument or error message changes.

## Rejected alternatives

**The slot-dependent emit-time guard k101 describes.** It is the shape the
ticket derives from a correct premise, and the measurements take it off the
table twice. It leaves the **encrypted** slot refusing documents sops writes and
reads (`type:float`, measured identical to ours), because the ticket assumed
`type:int` was the only encrypted form available. And it leaves the
**unencrypted** slot calling the leaf an `int` where sops, ADR 0020 and Go's own
data model all call it a float — fixing the croak while keeping the type wrong.
It also costs: `_compute_mac`'s `assert_representable` sweep is slot-blind by
design (its comment says so — it is the only encrypt-side walk that sees the
leaves the encryption rules exclude), so the rung would have to move out of it
and be re-covered in two places, and `Format::JSON::emit` would need a
`mac_covered` flag and a scalar hook it does not have. Four files against one
branch, for a strictly worse result.

**Refuse in the parser instead — reject the document outright.** It is honest
and it is what we do today, and it refuses documents `sops -e` writes and
`sops -d` reads. Taken off the table for k63 by the maintainer on
2026-08-20 for the same reason, and the reason has not changed.

**Keep the leaf an `int` and teach `value_to_bytes` to write `FormatFloat` for
an out-of-range one.** It makes the digest agree with Go without touching the
parser. It also gives one type two digest rules — the drift this distribution
names as its signature defect — and it does not fix the encrypted slot, where
the `type:` token, not the digest, is what sops reads.

**A bare NV, with the string half stripped.** Simpler, and `detect_type`,
`value_to_bytes` and the digest are all correct. It emits `9.22337203685478e+18`
through Cpanel's `%.15g` where sops writes `9223372036854776000`, so rotating a
sops-written document would move bytes that this ADR keeps byte-identical.
ADR 0020 rejected it for the same measurement and the same reason.

**Widen the JSON decoder instead — `allow_bignum`, or `json.Number`-style
strings.** Re-confirmed as ADR 0020 records it: `allow_bignum` retypes every
float in every document and costs 55–84× the plain decode. Nothing in this
window needs an oracle at all: an `IOK` leaf can only have come from a bare
numeric literal, measured across five quoted digit strings that all decode with
`IOK` clear.

**Relax `assert_representable`'s `int64` rung for every caller.** One line, and
it turns a caller's exact Perl integer into a lossy double with nothing but our
guess behind it — the repair ADR 0012 refuses for the leaf one rung over, for
the same reason. It would also silently write a document that fails its own
MAC for 21 of the 35 measured literals in an unencrypted slot.

**Do the YAML half too.** There is no YAML half: sops refuses to write such a
document itself, exit 23, in both slots, measured 4 of 4. ADR 0013 already
models that and refuses.

## Implementation, in lanes and in order

They touch the same files and must run one after another.

1. **`file-sops-wire`** — **done.** The boundary is exposed as
   `File::SOPS::Encrypted->integer_fits_int64($value)`, a numeric predicate
   next to `_decimal_fits_int64`, which keeps its own callers and its own
   argument shape. Verified rather than changed: `detect_type`,
   `value_to_bytes`, `assert_representable`, `canonical_float_tree` and
   ADR 0011's repair all take the new leaf as tabulated above, confirmed
   against the code at f1c1471, and the leaf class was taken end to end
   through `encrypt` → `sops -d` in both slots and both formats. `Encrypted`'s
   `detect_type` POD gained the paragraph extending ADR 0020's by one
   magnitude. Two corrections to this ADR, marked where they sit. No behaviour
   changed: `t/36` subtest 10 still passes, as it must until lane 2 lands.
   Owns this ADR.
2. **`file-sops-format`** — `Format::JSON::_wide_number` only: the `IOK`
   branch, in front of the plain-PV branch, with the two gates in the order the
   cost table demands and the flags read once. The boundary comes from
   `File::SOPS::Encrypted->integer_fits_int64($node)` and is not spelled here;
   the flag test comes **first**, and lane 1's correction above is why that is
   a correctness requirement and not a preference — a comparison made against
   the tree's own scalar ahead of it retypes string leaves the branch never
   wanted. Nothing in `emit`, nothing in the carrier, nothing in
   `Format::YAML`. The walk must keep running on `$data` after the `sops`
   section is split off.
3. **`file-sops-api`** — the POD for `decrypt`, `decrypt_file` and `extract`
   already documents ADR 0020's dualvar; it needs the window widened and the
   `0+$v` consequence named. Owns the `Changes` entry (a behaviour change, and
   a bug fix) and the one-sentence addition to `assert_representable`'s message
   for the caller-supplied UV that still refuses.
4. **`file-sops-test-writer`** — `t/36` subtest 10 is replaced (it asserts the
   defect), `uint64_max` moves lists in subtest 12, and a new file pins the 9
   moved corpus rows, the 41 unmoved ones, the acceptance-condition table, and
   both interop directions. The interop half is the only proof.
   `integer_fits_int64` arrives from lane 1 with no test of its own and wants
   one: both boundaries and the four values around each, and — the part a
   later refactor would break silently — that it does **not** retype its
   argument, which is the only reason it may be called on a document's own
   leaf at all.
