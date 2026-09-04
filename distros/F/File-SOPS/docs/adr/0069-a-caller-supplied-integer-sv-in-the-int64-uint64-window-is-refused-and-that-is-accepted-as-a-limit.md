# ADR 0069 — A caller-supplied integer SV in the int64..uint64 window is refused, and that residue is accepted as a limit

- Status: accepted
- Date: 2026-09-01
- Resolves k104 (part b — part a landed in c8eee80)
- Depends on ADR 0021 (which fixed the window for a value that arrives through
  `Format::JSON::parse`, and deferred exactly this remainder), ADR 0006 (the
  acceptance condition: the literal text equals `FormatFloat(double,'f',-1,64)`
  of the double it names), ADR 0013 (the foreign-resolution guard on the
  unencrypted YAML slot)
- **Moves no bytes.** Nothing is parsed, emitted or digested differently. No
  code changes. What changes is that the residue ADR 0021 left standing is now
  a decided limit, already pinned by `t/10-integer-range.t`.

## Context

ADR 0021 fixed the window `[2^63 .. 2^64-1]` for a value that reaches
`assert_representable` **through `Format::JSON::parse`**: the parser hands back
the `float64` Go's own decoder reads, so encrypt/rotate of a sops-written JSON
document works again. A value in that window that does **not** come from a JSON
parse — a Perl UV literal, a computed integer, or a scalar out of a YAML parse —
still carries `SVf_IOK` and still hits `assert_representable`, which croaks: no
`type:int` exists outside int64 (Go's int type), and this side refuses rather
than silently truncating to a float.

Part (a) of k104 (c8eee80) already did the cheap, safe half: the croak
message now names **both** answers the caller has — pass the value as a string
to store the digits exactly (`type:str`, verbatim, both formats, both slots),
or as a float (`unpack('d', pack('d', $value))`) to get what sops writes for
the same digits. What remains (part b) is the slot-dependent guard that would
let such a value through *unquoted* in the one slot where sops accepts it.

## The measurement

sops 3.13.3 at `/tmp/sops`, 35 literals across `[2^63 .. 2^64-1]`, guard
switched off in a scratchpad patch, each written and read back:

| slot | outcome with the guard off | correct answer |
|---|---|---|
| **JSON, unencrypted** | 14 of 35 produce a document `sops -d` accepts; the other 21 fail their own MAC | 14 wrongly refused, 21 rightly refused |
| **JSON, encrypted** | all 35 refused | all correct (`type:int` -> `strconv.Atoi` out of range, exit 25) |
| **YAML, both slots** | all 35 refused | all correct (sops cannot walk `uint64`, exit 23) |

So the guard is wrong for at most **14 of 35** caller-supplied integer SVs, and
only in the **JSON unencrypted** slot. The acceptance condition is the ADR 0006
one, measured with no exceptions in either direction: the literal text equals
`FormatFloat(double,'f',-1,64)` of the double it names.

The negative side of the window is **structurally unreachable**, proven while
landing part (a): `SVf_IOK` means the SV carries an IV or a UV; an IV bottoms
out at exactly `int64min` and a UV cannot be negative, so no integer SV exists
below the window. Measured over 14 negative decimals near `int64min`/`uint64max`
by 13 construction paths each: 182 rows, 36 of kind `int`, none below
`int64min`, zero croaks. A designer of part (b) would therefore need a rule for
the **positive** side only.

## Options considered

- **(a) Build the slot-dependent guard.** Thread a `mac_covered`-style flag
  through `Format::JSON::serialize`, add a `reject_scalar` hook the JSON emitter
  does not have today, drop the int64 rung from `File::SOPS::_compute_mac`'s
  slot-blind sweep and re-cover it from `Encrypted::encrypt_value` for encrypted
  slots. Four files, and — decisively — it **loosens a guard on the MAC path**.
  Rejected: the house rule is caution over speed in exactly this zone (no
  drive-by change to the MAC, never weaken a check), the reachable win is 14
  caller-supplied integer SVs in one slot, the priority is low, and the change
  reaches the slot-blind MAC sweep whose blindness other ADRs rely on.

- **(b) Accept the residue.** The refusal is loud (a croak), the caller already
  has two working answers named in the message (part a): a string stores the
  digits exactly in every slot, a float reproduces what sops writes. Neither
  answer lays a file sops rejects on disk — the float answer's few failures are
  refusals *here*, before writing. The case is an edge (a caller handing this
  library a bare integer SV in a 2^63-wide window, not a value read from a sops
  document), and the negative half does not exist.

## Decision

Accept the residue as a limit (option b). A caller-supplied integer SV in
`[2^63 .. 2^64-1]` is refused by `assert_representable`, the refusal names both
workarounds, and the slot-dependent loosening is on record as rejected with its
reason. No code changes; the behaviour is exactly what ADR 0021 plus part (a)
shipped. The limit is pinned by `t/10-integer-range.t` (the int64/uint64
sections, and sections 7–8 added by part a), so a future change — if the
slot-dependent guard is ever built with intent — has a measurement to move
against.

## Consequences

- The four-file change that would close it (option a) is on record as rejected,
  with the reason. Reopening k104(b) means overturning that decision, not
  rediscovering the case.
- No MAC, AAD, encrypted wire byte, parser, emitter or type-ladder decision
  moves. The guard that refuses, and the message that names the two answers,
  are unchanged from c8eee80.
- The negative side of the window is recorded as unreachable, so any revival
  needs only a positive-side rule.
