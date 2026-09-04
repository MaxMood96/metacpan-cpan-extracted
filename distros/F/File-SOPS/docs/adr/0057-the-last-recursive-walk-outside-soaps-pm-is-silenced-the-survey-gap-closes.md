# ADR 0057 — The last recursive walk outside SOPS.pm is silenced; the survey gap is closed

- Status: accepted
- Date: 2026-08-23
- Resolves k179
- Closes k120's open question (ADR 0029's `## Consequences` last bullet)
- **Does not move wire bytes.** The change is `no warnings 'recursion';` at
  the top of one walk; the walk's output is identical.

## Context

ADR 0029 silenced every recursive walk in `File::SOPS` at the time it landed:
`_assert_acyclic`, `_expansion_census`, `_sorted_leaves`, `_encrypt_tree`,
`_decrypt_tree`, `_document_leaves`. The walks in `Encrypted.pm` and
`Format/YAML.pm` were held by k116 / k120 and could not be touched then:
`Encrypted::_canonical_floats` runs inside every emit, and `Format::YAML`'s
two leaf walks run on every parse. ADR 0029's `## Consequences` named the
remaining noise as the open work, and k120 promised to remove it.

Karr k120 silenced TWO walks: `Encrypted::_canonical_floats` and
`Format::YAML::_restring_non_finite_leaves`. Measured on t/45's 265-level
alias chain (the fixture from k117): 505 warnings before either change,
168 after. The survey said 168 was the residue and the ticket closed.

It was not. A third walk warned: `Format::YAML::_go_repair_int_leaves`,
added to the parser at k127 (ADR 0054) after k120's survey. It is
structurally identical to `_restring_non_finite_leaves` -- a `my ($node,
$seen)` walk that recurses on HASH and ARRAY branches and carries a
`$seen` hash for cycle protection, no path -- but it was added on 2026-08-23,
after the survey had already shipped. Measured on the same 265-level
fixture, after k120:

```
# 167 deep-recursion warnings left, from File::SOPS::Format::YAML::_go_repair_int_leaves -- k179
```

That was t/45's `What is still noisy` diag, reporting the residue exactly
because k179 was filed and open. The fix is the same shape k120
applied to `_restring_non_finite_leaves`: a single `no warnings 'recursion';`
line at the top of the walk. There is no path, no `$seen`-hash change, no
order-of-operations change.

## Decision

`_go_repair_int_leaves` says `no warnings 'recursion';` as its first line,
matching the form `_restring_non_finite_leaves` already uses. The walk's
predicate, ordering (after `_restring_non_finite_leaves`, for the reasons
ADR 0054 spells out: the non-finite walk reads NOK+POK, this one reads
IOK+POK, the two predicates cannot collide but each must leave a clean
dualvar), `$seen` cycle guard, and HASH/ARRAY recursion are unchanged.

```perl
sub _go_repair_int_leaves {
    no warnings 'recursion';
    my ($node, $seen) = @_;

    return if $seen->{refaddr($node)}++;

    if (ref $node eq 'HASH') {
        for my $key (keys %$node) {
            ref $node->{$key}
                ? _go_repair_int_leaves($node->{$key}, $seen)
                : _go_repair_int_leaf($node->{$key});
        }
    }
    elsif (ref $node eq 'ARRAY') {
        for my $entry (@$node) {
            ref $entry
                ? _go_repair_int_leaves($entry, $seen)
                : _go_repair_int_leaf($entry);
        }
    }

    return;
}
```

The fix is exactly the diff k120 applied to `_restring_non_finite_leaves`,
which is why the structural identity is the whole case for it. There is no
`[$path, $k]` copy in this walk -- it does not carry a path, the repair is
local to each leaf and the leaf's own value -- so the additional
optimisation k120 applied to `_canonical_floats` is not in scope.

## Consequences

- **Zero deep-recursion warnings remain from any walk in the
  distribution.** Measured on t/45's 265-level alias-chain fixture, after
  this change: the `What is still noisy` diag does not fire, because
  `$residual_total == 0`. The `count_residual` function and its
  `$SIG{__WARN__}` hook stay in t/45 as a regression net for any future
  walk that forgets the pragma.
- **The k120 survey is now honest.** The ticket listed two walks and
  claimed they were all the walks. It was not the survey that was wrong;
  the third walk was added after it shipped. ADR 0029's `## Consequences`
  open bullet closes here, and k120's promise is kept.
- **No wire byte moves.** The walk's predicate, order and recursion shape
  are unchanged. The deep-recursion warning was the only output silenced;
  every leaf the walk visits lands on the same `type:int` or `type:str`
  it landed on before.
- **No AAD or MAC moves.** The walk does not build a path; it reads each
  leaf's own SV flags and rewrites the slot in place. The MAC is computed
  by `_sorted_leaves`/`_document_leaves`, which the k117 set silenced,
  and the parse path precedes the walk that records the digest.
- **No other walk silenced, deliberately.** `t/45` is the regression net;
  a walk added later that forgets the line will be caught by section 1's
  per-walk assertion or by the section-2 public-API assertion, exactly as
  before.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23. Before this
change: t/45 reports `# 167 deep-recursion warnings left, from
File::SOPS::Format::YAML::_go_repair_int_leaves -- k179`. After: the
diag does not fire. The full suite (`SOPS_BIN=/tmp/sops prove -lr t/`)
passes at the same count as before; t/45's section 1 already asserts
quiet per walk, and section 2's "encrypt writes no deep-recursion warning
at all" now covers the parse-side walks too because no walk outside
SOPS.pm prints them.

Three commits on the `karr-179` branch:

1. `BEHAVIOUR CHANGE`: one line in `lib/File/SOPS/Format/YAML.pm`, the
   `no warnings 'recursion';` at the top of `_go_repair_int_leaves`.
2. `TEST`: t/45's `What is still noisy` diag block deleted (zero residue
   makes it dead output); the `count_residual` regression net stays.
3. `DOCS`: this ADR and a `Revised:` line on ADR 0029 closing the open
   bullet; the Changes entry under `{{$NEXT}}` records the user-visible
   effect.

Lane: `file-sops-format`. The sub lives in `Format::YAML` and the change
is one line; the wire is unaffected, `Encrypted.pm` is untouched, every
other walk in the distribution is untouched. ADR 0029 is the parent
decision and gains a `Revised:` line that points here.
