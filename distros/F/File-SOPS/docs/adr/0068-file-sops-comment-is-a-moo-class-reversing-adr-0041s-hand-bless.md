# ADR 0068 — File::SOPS::Comment is a Moo class, reversing ADR 0041's hand-bless

- Status: accepted
- Date: 2026-09-01
- Resolves k154
- Reverses the implementation choice in ADR 0041 (a hand-written `bless` with
  `sub new` / `sub text`), not its decision (a comment is a leaf of its own).
- **Moves no bytes.** No wire, MAC, AAD, type-ladder or encoding change.
  `detect_type`, `value_to_bytes` and the digest see the same object either way.

## Context

Every other class in this distribution is `Moo` + `namespace::clean`.
`File::SOPS::Comment` was the one exception: a nine-line hand-written `bless`
with its own `sub new` and `sub text`. That is how ADR 0041 first wrote it, when
it lived inside `File::SOPS::Encrypted` as a leaf small enough that the ladder
could load it without a dependency cycle. k147 moved it into
`lib/File/SOPS/Comment.pm` unchanged — a move must not move behaviour.

The divergence from the house rule "one object system per distribution" was
therefore visible in a file of its own, which is what k154 raised as a
question for the maintainer. The maintainer decided: convert (conformance over
taste).

The class is still a good fit for the reason ADR 0041 wrote it by hand: one
immutable field, no roles, no lazy build, no coercion, and it loads nothing from
this distribution — `File::SOPS::Encrypted` loads *it*. Moo does not change any
of that. It loads only `Moo` and `Carp`, so the load direction the ladder
depends on is unchanged.

## Decision

`File::SOPS::Comment` becomes a `Moo` class:

- `has text => (is => 'ro', required => 1)`.
- A `BUILD` carries the two refusals `required => 1` cannot: a reference and an
  empty string are both defined, so they satisfy `required` and are refused in
  `BUILD`, which runs once the attribute is set.

The three refused inputs are unchanged from the hand-written constructor:

| input | refused by | message |
|---|---|---|
| missing `text` | Moo `required => 1` | `Missing required arguments: text` |
| a reference | `BUILD` | `a comment's text is a string, not a ... reference` |
| an empty string | `BUILD` | `a comment's text cannot be empty: ...` |

The empty-string message is kept verbatim from ADR 0041's constructor, because
`t/56` reads it (`like($@, qr/cannot be empty/)`). The other two are read only
as "did it die" (`ok(!defined(eval {...}))`), and a Moo constructor dies for
both. So `t/56` is unchanged.

## Consequences

- The class now matches the house pattern; the one-object-system divergence
  k154 named is gone.
- The missing-`text` message text changed (`text required` →
  `Missing required arguments: text`). No test asserted the old wording, and the
  refusal is unchanged in kind — a `new` with no `text` still dies. Callers that
  matched the old string do not exist in this distribution.
- No wire byte, MAC, AAD, encrypted-value, parser, emitter or type-ladder
  decision moves. Verified with a full interop run (`t/04-interop.t` against
  sops 3.13.3) and the whole suite.

## Rejected alternatives

- **Leave it as a hand-written `bless`.** The other defensible answer in
  k154: the class is small and self-contained and the hand-bless works.
  Rejected by the maintainer in favour of conformance — the divergence was the
  only one of its kind and cost a reader a second mental model for no gain.
- **Add an `isa => Str` type constraint for the reference refusal.** Would fold
  the ref-check into the attribute, but `Str` would also reject a numeric-looking
  scalar in ways the hand-written check never did, and would change the message
  to a `Type::Tiny` one for no behavioural gain. The `BUILD` ref-check keeps the
  exact refusal and message ADR 0041 shipped.
