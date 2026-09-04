# ADR 0029 — The depth a walk refuses is the depth sops refuses

- Status: accepted
- Date: 2026-08-21
- Revised: 2026-08-23 — Survey gap closed by ADR 0057 (k179): a third walk
  outside `SOPS.pm`, `Format::YAML::_go_repair_int_leaves` (added at k127
  / ADR 0054, after k120's survey shipped), was missed by the k120
  survey and was the source of the 167 deep-recursion warnings t/45's `What
  is still noisy` diag kept reporting. The fix is the same one-line
  `no warnings 'recursion';` k120 applied to its two walks, since
  `_go_repair_int_leaves` is structurally identical to
  `_restring_non_finite_leaves`. After the change: zero residue; the open
  bullet below closes.
- Tags: api, guards, robustness, diagnostics, interop
- Resolves k117
- Opens k120 (the walks outside `SOPS.pm` still warn); ADR 0057 closes
  the survey gap that k120 left behind
- Related: ADR 0025 (a document that contains itself is refused — this bound is
  what stops the same walks when that guard is not the one asking), ADR 0027
  (the alias budget is go-yaml's ratio — same rule about whose number a
  threshold is)

## Context

Every tree walk in this distribution recurses, and none of them said
`no warnings 'recursion'`. Perl raises `Deep recursion on subroutine` once a
sub passes 100 frames. That threshold is fixed, is not configurable, and is
about perl's own stack accounting — it says nothing about the document.

A document nested deeper than 100 is not exotic and it is not invalid: sops
accepts it. So a correct `encrypt` of one wrote warnings to STDERR while
succeeding. Measured on a 265-level alias chain — 265 anchors, each nesting the
one before it, a DAG that is neither a cycle (ADR 0025) nor an alias bomb
(ADR 0027):

| | lines on STDERR | bytes | time |
|---|---|---|---|
| before | 505 | 63,457 | 0.807s |
| after | 168 | 23,856 | 0.417s |

The walk re-enters the shared subtrees, so perl's threshold is crossed once per
expansion rather than once per walk, which is why 265 levels produce hundreds
of lines rather than five. Nothing was wrong with the output: the document
encrypted correctly, verified, and `sops -d` read it back. It was a successful
operation that reads like a crash.

The obvious fix — `no warnings 'recursion'` in the walks — was not free, and
that is why k117 was a ticket and not a one-line commit.
`t/41-recursive-anchor-refused.t` bounds ADR 0025's regression by dying on the
first deep-recursion warning in a forked child: perl raises it at depth 100, so
a runaway walk is caught in milliseconds, before it has allocated anything.
Without it the walk climbs about 1 GB of RSS every three seconds, and a full
red run took 6m40 instead of 0.378s. Silencing the warning removes that net.

There was a second, older problem in the same place, and the two turn out to
have one answer. A walk that recursed without a bound had only a hang to offer
where the document really was too deep to process. Measured, on this machine:

| containers | `_sorted_leaves` alone |
|---|---|
| 1000 | 0.047s, 57 MB |
| 2000 | 0.182s, 129 MB |
| 4000 | 101s, 410 MB |

The jump is not the recursion. It is `[ @$path, $k ]`: every level copied the
whole key path, so the walk was quadratic in depth in both time and memory,
and past a few thousand levels it thrashed rather than finished.

## What sops does

Measured against sops 3.13.3, on documents built as `a: {a: {a: ...}}` and
`a: [[[ ... ]]]`, counting containers from the document's own root mapping.
Both shapes give the same boundary.

```
$ sops -e --age age1… deep-10001.yaml     # 10001 containers
(writes the file)

$ sops -e --age age1… deep-10002.yaml     # 10002 containers
Error unmarshalling file: yaml: exceeded max depth of 10000        (exit 2)

$ sops -e --age age1… deep-10001.json     # 10001 containers, JSON
Could not marshal tree: Error marshaling to json:
    invalid character '{' exceeded max depth                       (exit 4)
```

So the reference implementation has a depth limit, in both formats, and the two
halves do not agree with each other:

| | accepted | refused |
|---|---|---|
| go-yaml (`sops -e`, `sops -d`) | 10001 containers | 10002 |
| Go `encoding/json` (`sops -e`) | 10000 containers | 10001 |

The YAML limit applies in both directions and **ahead of the data key**, like
the other two document-shape refusals. An over-deep encrypted file:

```
$ sops -d too-deep.enc.yaml
yaml: exceeded max depth of 10000                                  (exit 1)

$ SOPS_AGE_KEY_FILE=/nonexistent sops -d too-deep.enc.yaml
yaml: exceeded max depth of 10000                                  (exit 1)
```

## Decision

**Every recursive walk in `File::SOPS` says `no warnings 'recursion'` and
carries a depth it refuses to pass, and that depth is 10000 — the deepest a
document can be and still be readable in both of sops's formats.**

Three parts, and none of them stands alone.

### 1. The warning is silenced where it is noise, per walk

`no warnings 'recursion'` is the first line of `_assert_acyclic`,
`_expansion_census`, `_encrypt_tree`, `_decrypt_tree`, `_sorted_leaves` and
`_document_leaves` — not a pragma at the top of the file. Nothing outside those
six loses the warning, and a walk added later has to say so itself.

### 2. What the warning was doing becomes part of the contract

`$File::SOPS::MAX_DEPTH`, default 10000. Each of the six walks asks
`_assert_depth` on the way into a container and croaks past it, naming what
sops says about the same document.

**10000 is not our number.** go-yaml would allow 10001, and the difference of
one level matters only in which direction the error goes: a document at 10001
is one this library could write and `sops -d` could read as YAML, but one that
Go's JSON encoder refuses. Writing a file sops cannot read back is the error
this distribution exists not to make, so the bound is the intersection of the
two limits and not the larger of them. This is the same rule as ADR 0027 — the
threshold belongs to the reference implementation — applied where the reference
implementation contradicts itself, and it costs exactly one level of YAML depth
that nothing real will ever want.

The variable is writable, and documented as such. A caller reading untrusted
documents can lower it; raising it above 10000 writes documents sops will
refuse.

### 3. The path is pushed and popped, so the bound can be afforded

A bound you cannot reach is a hang with a message attached. The walks now carry
one path array, pushed on the way down and popped on the way back up, and copy
it only where a leaf keeps it (`_sorted_leaves`, `_document_leaves`). Measured
on the same fixture as above:

| containers | before | after |
|---|---|---|
| 4000 | 101s, 410 MB | — |
| 10000 | did not finish | 0.017s, 24 MB |

That is what makes a refusal at 10000 arrive in under a second rather than
after minutes of thrashing, and it is why the change is here and not deferred:
without it the bound is decorative.

## Consequences

- A document nested more than 10000 containers deep is refused, in both
  directions and ahead of the data key, matching the order sops answers in.
  Nothing sops has written can reach this; the reachable origins are a
  hand-written file and a structure a caller built in Perl.
- Deep documents got considerably cheaper. The 265-level fixture encrypts in
  0.417s where it took 0.807s, and the memory a walk holds is now linear in
  depth rather than quadratic.
- `t/41-recursive-anchor-refused.t` keeps a fast net, and it is now a product
  guard rather than a side effect of perl's stack accounting: the child lowers
  `$File::SOPS::MAX_DEPTH` to 200, so a runaway walk is refused in about 2ms
  with no allocation worth naming, whatever shape the cycle has. Rehearsed both
  ways — with the cycle guard's body removed, 14 of 23 red in 0.359s; with its
  call sites removed, 14 of 23 red in 0.363s. Every failure reports
  `RAN AWAY`, none hangs, none thrashes.
- `t/45-deep-document-is-quiet.t` pins the noise itself, the bound in each of
  the six walks, and the sops boundary the number comes from.
- **The noise is not gone yet.** The walks in `Encrypted.pm` and
  `Format/YAML.pm` were held by k116 when this landed and could not be
  touched: `Encrypted::_canonical_floats` runs inside every emit, and
  `Format::YAML`'s two leaf walks run on every parse. 168 of the original 505
  lines remain, all from there. k120 carries the same two changes to them;
  section 2 of t/45 is a TODO block that flips when it lands.

## Alternatives considered

**`no warnings 'recursion'` and nothing else.** The one-line version, and the
reason the ticket existed. It removes t/41's only memory-bounded net and leaves
the library with no answer at all for a document that really is too deep: the
hang stays, it just stops warning about itself.

**Keep the warning; rewrite the hot walks as iteration.** It removes the noise
at its source and needs no bound. It also moves far more code, in the walks the
MAC's ordering rides on, for a defect that is diagnostic — and it does not help
t/41 either: an iterative runaway does not warn, so that net would have to be
replaced regardless.

**A depth bound chosen here rather than measured.** A cap low enough to be a
cheap net — a thousand, say — refuses documents sops accepts, which is the one
error this layer must not make, and ADR 0027 is the entry that learned it. The
measurement above is what makes 10000 defensible: it is not a threshold, it is
a reproduction.

**A shorter alarm in t/41 instead of a bound.** Time is not memory. At about
1 GB of RSS every three seconds, a half-second alarm still lets a runaway take
170 MB per case, on a timer that is machine-dependent and would go flaky under
load — and with the path copies removed the walk allocates *faster*, not
slower. A refusal at a depth costs nothing and does not depend on how busy the
machine is.

## What is not pinned by a test, and why

`t/45` asserts the refusal side of the sops boundary in both formats, and a
1000-container round trip through the binary. It does not assert the accepted
side at 10001: sops writes a document that deep as roughly 200 MB of indented
YAML, because block indentation is quadratic in the depth. That measurement was
taken by hand, is reproduced at the top of this entry, and would cost the suite
minutes and a gigabyte of disk to repeat.
