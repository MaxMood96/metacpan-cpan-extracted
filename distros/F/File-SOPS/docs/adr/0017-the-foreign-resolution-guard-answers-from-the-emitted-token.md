# ADR 0017 — The foreign-resolution guard answers from the emitted token, not from the leaf's stringification

- Status: accepted
- Date: 2026-08-20
- Tags: yaml, mac, wire-format, guards, interop
- Resolves k91
- Amends ADR 0013 (same guard, same model of Go, different step order — the
  refusal rule itself is unchanged and no document moves)
- Depends on ADR 0016 (Perl's own boolean SV is the one leaf class whose
  written token is not its stringification) and ADR 0002 (this still does not
  type a value from its text; see ADR 0013's section of the same name, which
  applies here unchanged)

## Context

`Format::YAML::_reject_foreign_resolution` decides whether Go's resolver derives
the bytes the MAC digest covers **from the token this emitter writes**. That is
the question. What it has been asking since ADR 0013 is four steps, and only the
last two are about the token:

1. return unless `"$leaf"` starts with a byte Go's `resolveTable` looks at;
2. return if `_go_agrees("$leaf", $text)` — the leaf's **stringification**,
   resolved as if it were the token;
3. otherwise ask `_emitted_plain_scalar` what the emitter writes, and return if
   it is quoted;
4. return if `_go_agrees($token, $text)`; croak otherwise.

Steps 1 and 2 use the stringification as a **proxy** for the token. ADR 0013
chose that deliberately and for a measured reason: step 3 is an emit per leaf,
and an ordinary string leaf should not pay it.

For every leaf class but one the proxy is the same string as the token. **A
boolean SV is the exception, and it breaks the proxy in both directions:**

| leaf | `"$leaf"` | token the emitter writes | digest text |
|---|---|---|---|
| `!!1` | `1` | `true` | `True` |
| `!!0` | *(empty)* | `false` | `False` |

k90 came through step 2 by exactly this route: before that fix the digest
text for `!!1` was `1`, so `_go_agrees("1", "1")` was true, the guard returned
**before it had asked the emitter anything**, and the document carried a bare
`true` against a digest of `1` — `sops -d` exit 51. The fix was one level down,
in `detect_type`; the guard's blind spot is still there and is now only hidden,
because the digest text moved to `True` and `1` no longer resolves to it.

Step 1 has the mirror-image hole and it is still open: `!!0` stringifies to the
empty string, which `$GO_LOOKS_AT` does not match, so the guard returns before
step 2 as well. Measured after the k90 fix, sops 3.13.3: the answer is
correct anyway — the emitted `false` resolves through `%GO_CONSTANT` to `False`,
which is the digest — so this is a latent gap, not a live defect.

### What was measured before deciding

**Which leaves the two gates disagree about.** A 225-leaf corpus — the ADR 0013
spellings both as caller-supplied Perl strings and taken through a real
`YAML::XS` parse, plain ints, floats, the ADR 0006/0011/0012/0014 float and
dualvar cases, boolean sentinels, `undef`, an empty string and a non-ASCII
string — pushed through `emit` with the guard replaced by a recorder. 220 of
them reach `reject_scalar` at all (1 croaks earlier, in ADR 0012's guard; the
rest are `undef`, or references that ADR 0008's `reject` takes first).

- **Gap A — the gate skips a leaf whose token Go does look at: 4 of 220.** All
  four are a false boolean (`!!0`, `$x > 9`, `'a' eq 'b'`, and a `false` parsed
  by YAML::XS in its default boolean mode). In all four the answer is `agrees`,
  so today's early return is right by luck.
- **Gap B — step 2 accepts while the token disagrees: 0 of 220 today.** It was
  not 0 before k90; it was the defect.

**Whether the cheap gate can be made sound without asking the emitter.** The
claim it rests on is: *for a leaf that is not a boolean, the token starts with
the same byte as the stringification, or is quoted.* Probed over 2119 non-bool
leaves — every printable ASCII character alone and in first and last position,
600 random integers as IVs, as negated IVs and as PVs, 900 floats spread over
30 orders of magnitude, the int64 and subnormal edges, dualvars, embedded
newlines, leading and trailing whitespace, and non-ASCII characters — **2 have a
different first byte, and both are the UTF-8 encoding of a non-ASCII first
character** (`chr(0xe9)` → `\xc3\xa9`, `\x{263a}` → `\xe2\x98\xba`). Neither
matters and neither can: every UTF-8 lead and continuation byte is ≥ `\x80`,
and every byte in `$GO_LOOKS_AT` is ASCII.

So one clause closes gap A, and it is a clause this distribution already has an
authority for: `detect_type` says `bool` for exactly the SVs both emitters write
as a bare `true`/`false` (ADR 0016 measured that the emitters use `SvIsBOOL`
itself, not a flag or text lookalike). No second ladder, no new predicate.

**What each shape costs.** Per 1000 leaves through `emit`, best of five runs,
perl 5.40.1 / YAML::XS 0.910.0. `A` asks the emitter for every leaf and gates on
the token alone; `E` keeps a cheap gate and takes the verdict from the token:

| leaf class | today | E | A |
|---|---|---|---|
| a string Go's resolver ignores | 5.2ms | **6.0ms** | 17.0ms |
| an `ENC[...]` slot | 5.4ms | **6.3ms** | 17.3ms |
| a hinted string | 9.5ms | 23.9ms | 23.4ms |
| an int | 13.3ms | 31.1ms | 30.9ms |
| a float | 78.8ms | 98.3ms | 96.7ms |
| a boolean SV | 24.9ms | **17.5ms** | 17.0ms |

End to end, `File::SOPS->encrypt` over a mixed 400-leaf document: 16.1ms with
the guard off, 17.1ms today, **19.5ms under E**, 23.9ms under A. Over 40 leaves
the three are within noise of each other (4.8 / 5.3 / 5.4ms).

A is what k91 costed and ADR 0013 declined, and the measurement says the
ADR was right about the price: it is the leaves Go's resolver **ignores** that
pay it, and in a real configuration file those are the majority. E buys the same
answer for the leaves that can disagree. Over the same 220 leaves: today 199
pass the gate and 103 go on to ask the emitter; under E 203 pass and all 203
ask.

## Decision

**The guard gates cheaply on whether Go's resolver could look at what the
emitter writes, and then takes its answer from the token and from nothing else.**

```
return if the leaf is in the sops branch;
return unless "$leaf" is hinted OR detect_type($leaf) eq 'bool';
$token = _emitted_plain_scalar($leaf);   return unless defined $token;
$text //= value_to_bytes($leaf);
return if _go_agrees($token, $text);
croak
```

Two changes to ADR 0013's four steps, and nothing else:

- the gate gains the one leaf class whose token is not its stringification,
  named by the same `detect_type` the digest goes through;
- **step 2 is deleted.** The stringification no longer decides anything. It is a
  hint about whether to look, never the thing looked at.

`_reject_foreign_resolution` keeps its model of Go (`_go_scalar_bytes`), its
message, its `sops`-branch skip and its refusal rule unchanged. This ADR moves
where the verdict comes from, not what the verdict is.

## Consequences

- **No document moves.** Corpus of 225 leaves × 2 slots (`x_unencrypted`, `x`)
  × 2 handlers = 900 rows, each encrypted before and after in the same process
  so the only difference is the guard: **900 identical outcomes, 0 moved**, 804
  written and 96 refused on both sides, and the written documents are
  byte-identical once the random key material and `lastmodified` are
  normalised. That is the whole counter-measurement: **0 of 900 cases that work
  today stop working.**
- **A boolean leaf gets cheaper, not dearer** (24.9ms → 17.5ms per 1000): the
  guard now resolves `true`/`false`, which `%GO_CONSTANT` answers immediately,
  instead of resolving `1` through the integer model first.
- **An int, float or hinted-string leaf now always asks the emitter**, where it
  used to ask only when the stringification already disagreed: +18ms per 1000
  ints, +20ms per 1000 floats, +2.4ms on a 400-leaf document. That is the price
  of the guarantee, and it is the smaller half of A's.
- **A string Go's resolver ignores still pays one regex and one `detect_type`**
  — +0.8ms per 1000 — and never reaches the emitter. That property is now
  pinned by a test rather than left as a comment, so a later "just always ask"
  cannot land unmeasured.
- The gap class this closes stays closed by construction rather than by luck: a
  second leaf class whose token is not its stringification would have to get
  past `detect_type` *and* be written bare *and* resolve to something other
  than the digest text.

### What changes for existing callers

Nothing. No message text changes, no leaf that was written is refused, no leaf
that was refused is written, and `emit`'s arguments are unchanged.

## Rejected alternatives

**Keep today's form and close the ticket with the measurement.** Defensible on
the numbers as they stand — gap A is 4 rows out of 220 and all four answer
correctly. It is not defensible on the mechanism: gap B was the same "latent"
shape until k90 made it live, and this session made two latent guard gaps
live three times (k84 → k86 → k89 → k90, each one "the guard does not see it").
A guard whose correctness depends on the digest text of one type never colliding
with the resolution of another type's stringification is a coincidence that has
already failed once.

**Ask the emitter for every leaf (option A).** The literal reading of k91,
and the one ADR 0013 costed. Measured above: it is 3x on the leaf class that
dominates a real document — strings the resolver ignores, 5.2ms → 17.0ms per
1000 — and it buys nothing over E, because a token the resolver ignores cannot
disagree with anything. 0 rows of 900 differ between A and E.

**Batch the emitter probes.** One `Dump` of all candidate leaves costs 1.7ms per
1000 against 6.8ms for one `Dump` each, so A would become nearly free. It needs
the walk split into a collect phase and a check phase, which moves the croak out
of the walk and away from the leaf that caused it — the key path in the message
is k68's fix and is worth more than 5ms per 1000 leaves. Reconsider only if
a document size ever makes the emit path matter.

**Let the walk hand the guard a `bool` hint** — the narrower fix k91 itself
suggests. `_canonical_floats` already calls `detect_type($node) eq 'bool'` one
line earlier, so the hint is free there and saves the guard's own call: 1ms per
1000 string leaves. It widens `reject_scalar`'s contract with a fifth argument
that both format handlers and every future one would have to know about, to
carry an answer either can get from the one ladder in one call. Simplicity wins
at this price.

**Refuse the leaf classes the proxy cannot see, instead of looking properly.**
There is nothing to refuse: all four gap-A rows are documents `sops -d` accepts,
and a boolean is the most ordinary leaf a caller can write.
