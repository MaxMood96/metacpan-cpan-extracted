# ADR 0036 — The order-preserving reparse is asked of the format handler

- Status: **accepted** — decided and implemented together, in this commit.
- Date: 2026-08-21
- Tags: mac, format, parser, interop, roadmap, env, ini
- Resolves k74 (split out of k36 as 36a). Prerequisite for k36
  (ENV) and k37 (INI).
- **Refines ADR 0001; it does not change it.** Every decision ADR 0001 took is
  still in force, including the one that looks like it moves — see
  *What ADR 0001 says now* below.
- Depends on ADR 0001 (which built the mechanism), ADR 0024 (which requires the
  reparse to stay structurally identical to `parse`) and ADR 0033 (the
  one-document rule the reparse holds for itself).

## Context

ADR 0001 gave MAC verification its key order by reparsing the raw document with
`YAML::PP` (`PRESERVE_ORDER`) and walking that skeleton against the real tree.
The reparse lived in `File::SOPS::_parse_in_document_order` as a direct
`YAML::PP` call.

That is correct for the two formats YAML::PP can read, and it is **nothing at
all** for a format it cannot. `_parse_in_document_order` returns `undef` for
text it cannot load, and the caller then hashes in sorted key order. For YAML
and JSON that fallback is nearly unreachable. For an env or ini document it
would be the *only* path — and an env file `sops` writes is in **document
order**, so every such file whose keys were not already sorted would fail
verification, with an error naming the MAC and nothing pointing at the cause.

So the mechanism was bound to a format it did not have to be bound to. That is
the standalone value k74 names, and it is also a hard precondition: no ENV
and no INI handler can verify a MAC `sops` wrote until this is fixed, which is
why k36 and k37 both depend on it.

The mechanism has two halves, and only one of them is format-independent:

| Half | Format-specific? |
|---|---|
| Reading a document's key order out of raw text | **Yes.** Which reader parses it, what "one document" means for it, and **where its metadata sits** — a `sops` mapping in YAML and JSON, top-level `sops_*` keys in an env file, a `[sops]` section in an ini one |
| Walking that order against the real tree and hashing what it points at | No |

`File::SOPS` was doing both. It now does the second and asks for the first.

## Decision

**`File::SOPS::_parse_in_document_order($content, $format_class)` asks
`$format_class->parse_in_document_order($content)`.** The format class is the
one that already parsed the document, threaded from `decrypt` through
`_verify_mac`, so the order and the values can never come from two different
readings of the same text.

`File::SOPS::Format::YAML->parse_in_document_order` holds the `YAML::PP`
loader, the one-document rule and the `sops`-branch removal — the body of the
old private sub, moved. `File::SOPS::Format::JSON->parse_in_document_order`
delegates to it. `File::SOPS` no longer loads `YAML::PP` at all.

### The contract a handler must meet

Stated in full at `File::SOPS::_parse_in_document_order` and in each handler's
POD:

1. **Take the raw document text; return a HashRef of the same shape as the
   handler's own `parse`** — mappings where `parse` has mappings, sequences of
   the same length, leaves where `parse` has leaves. The **values are never
   read**, only the shape. That is ADR 0001's boundary, unchanged: nothing the
   order reader produces reaches the digest as data, so a scalar the two
   readers resolve differently cannot move a MAC.
2. **Every mapping must iterate its keys in document order.** Perl's plain hash
   has no key order, so for a format whose parser has no order-preserving mode
   this is a **tied hash** and nothing else. There is no third option: `keys`
   is what `_document_leaves` walks.
3. **The metadata section is already gone.** The handler drops it, because only
   the handler knows where it is. This keeps ADR 0001's rule that the metadata
   is excluded *structurally* rather than by matching `mac:` in text.
4. **Decline — return nothing, or die — when the text cannot be read that
   way.** Declining is safe. Guessing is not.

### The one failure that is loud

A format class that cannot do this **at all** — no such method — is a `croak`,
not a fallback. That is not a document's fault, it is a hole in this
distribution, and swallowing it would silently degrade every document in that
format to sorted order: precisely the env/ini defect k74 exists to
prevent. The message names the missing method and says what would otherwise
have happened.

Everything else declines quietly, and that is deliberate: a handler that cannot
read a particular document must not be able to turn a MAC check into an error
the caller reads as corruption.

## The fail-safe property, and how it was checked

ADR 0001's fourth bullet is the load-bearing one: *"Failure falls back to sorted
order. This is safe in one direction only, and that is the direction we need: a
wrong order can make verification fail, never wrongly succeed."* A refactor that
loses it produces silently wrong MACs, so it was checked three ways rather than
argued:

**1. The property is structural, not incidental.** The digest is over the same
leaf *values* whatever order they arrive in; order only permutes the
concatenation. There is no order — right, wrong, sorted or random — that can
make a document whose values differ from the MAC's inputs verify. Recovering
order can therefore only ever *add* failures, never remove one. Nothing in this
change touches `_mac_digest`, `_mac_bytes`, `_sorted_leaves` or
`_document_leaves`.

**2. The multi-document trap is still held, and now held by the handler.**
`YAML::XS::Load` in scalar context returns the **last** document of a stream;
`YAML::PP->load_string` returns the **first**. The walk takes its order from one
and its values from the other, so a reparse that quietly accepted a stream would
pair one document's order with another document's values — a wrong digest, not
an error. This was live in shipped code once (k31). The LIST-context call
and the `@docs == 1` test moved into `Format::YAML->parse_in_document_order`
verbatim and are pinned in `t/51` for the handler, the JSON delegation and the
dispatcher, alongside the existing `t/13` assertions on the dispatcher.

**3. Measured over a corpus.** 63 encrypted documents (below). Every one
recovered document order before the change and after it, and every one produced
the same digest. Not one moved to the sorted fallback.

## Measurement: the digest does not move

The central claim of the change, measured rather than reasoned. Corpus: 63
encrypted documents — 21 written by **sops 3.13.3** (`/tmp/sops`, 12 YAML and 9
JSON) and 42 written by **File::SOPS** (the same fixtures, each with and without
`mac_only_encrypted`). Fixtures deliberately in non-sorted key order, covering
flat and nested mappings, sequences, sequences of mappings, mixed types,
unicode keys and values, an `_unencrypted` leaf, nulls and empty strings, block
scalars, keys containing a space and a `#`, four levels of nesting, and a
single-key document.

For each document, the computed MAC digest was taken through the real path —
`_parse_in_document_order` → `_document_leaves` (or `_sorted_leaves` on the
fallback) → `_mac_digest` — before and after, with one script called identically
on both sides.

| | Before | After |
|---|---|---|
| Documents | 63 | 63 |
| Recovered **document** order | 63 | 63 |
| Fell back to **sorted** order | 0 | 0 |
| `decrypt` succeeds | 63 | 63 |
| Digests differing between the two runs | — | **0** |

Of the 63, **17 are order-sensitive**: their digest in sorted order differs from
their digest in document order, so a broken order recovery would show up on
them. (The other 46 are documents File::SOPS wrote, whose emitter sorts, so
document order *is* sorted order — which is exactly the property ADR 0001 relies
on and `t/05-format-key-order.t` pins.)

The pre-change library was reconstructed in a scratch copy of `lib/` by
reversing the three edits, and it reproduced the baseline byte for byte before
being used as the reference.

**Because no digest moves, this stays in the format lane.** k74's body
says "hand over to wire as soon as what the digest covers moves". It does not
move: this is restructuring, and the measurement is the evidence.

## Measurement: what JSON was actually doing

Step 2 of the task, because a refactor that gives JSON its own seam makes any
existing imprecision visible.

**JSON does run on the YAML::PP rail, and it works.** A `sops`-written JSON
document with unsorted keys (`zebra`, `alpha`, `middle`, `plain_unencrypted`)
recovers document order and verifies at exit 0. That is not luck: JSON is a
subset of YAML 1.2, and the flow syntax `sops` and `Cpanel::JSON::XS` emit is
inside it. Measured on the two decoders side by side, key sets identical:

| Case | Verdict |
|---|---|
| Tab-indented pretty JSON (what `sops` writes) | same |
| Compact JSON, no space after `:` | same |
| Nested and array-of-mapping compact JSON | same |
| Solidus escape `\/` in a key | same |
| `é` in a key | same |
| ` ` and `\n` escapes in a key | same |
| Empty key, backslash in key | same |
| YAML 1.1 booleans as keys (`y`, `n`, `on`) | same |
| CRLF line endings | same |
| Duplicate keys | both refuse |
| **Surrogate PAIR escape in a key** (`"😀"`) | **differ** |

The one divergence: `Cpanel::JSON::XS` combines the pair into U+1F600,
`YAML::PP` keeps two lone surrogates. Neither emitter writes that — both put
non-ASCII on the wire as UTF-8 — so it takes a hand-written key to reach. When
it is reached the key sets disagree and `_document_leaves` says so at the path
(`present in the document but not in the parsed tree`), measured. **A false
refusal, never a false pass**, so it is a fidelity gap of the same class as
k29 and not a correctness hole.

`Cpanel::JSON::XS` has no order-preserving decode mode, so giving JSON a reader
of its own means a second hand-written scanner over raw text — which is what
ADR 0001 rejected, for this exact job, after the text scrape it replaced had
silently dropped values from the digest. So the delegation stands, and it is now
**stated** in `Format::JSON` rather than being an unremarked fact about
`File::SOPS`.

## What an ENV handler must now deliver

This is what k36 and k37 get out of this ADR:

```perl
sub parse_in_document_order {
    my ($class, $content) = @_;
    my @keys;
    for my $line (split /\n/, $content) {
        next unless $line =~ /\A([^=#]+)=/;
        my $key = $1;
        next if $key =~ /\Asops_/;      # the metadata, dropped by the handler
        push @keys, $key;
    }
    my %doc;
    tie %doc, 'File::SOPS::Format::ENV::Ordered';
    $doc{$_} = undef for @keys;
    return \%doc;
}
```

Three notes an implementer needs, all of them measured:

- **The tie is the whole cost, and it is unavoidable.** `YAML::PP`'s own
  ordered hash (`YAML::PP::Preserve::Hash`) is not a separately loadable class,
  and `Tie::IxHash` is not a prerequisite of this distribution. A ~12-line
  `Tie::Hash` implementation is what "order preserving" means for a format
  whose parser has none; `t/51` carries one, working, as the proof that the
  contract is satisfiable outside YAML.
- **The values may be `undef`.** Only the shape is read. An env document is
  flat, so the shape is one mapping of scalars; an ini document is exactly two
  levels. Neither needs sequences.
- **The metadata belongs to the handler.** ENV's is a `sops_` key prefix, INI's
  is a `[sops]` section. Dropping it is condition 3 of the contract and it is
  the reason the contract could not be met by `File::SOPS` deleting
  `$doc->{sops}` on the handler's behalf.

A handler that returns a **plain** hash is the trap the contract exists to
close: the order would be Perl's randomised iteration order, verification would
fail unpredictably, and the error would name the MAC. It is *safe* — it cannot
make a bad document verify — but it is useless, and it is worth saying out loud
because it is the mistake this interface invites.

## What ADR 0001 says now

**Precised, not changed.** Its decision was "keep YAML::XS as parser and
emitter; use a second parser for order only", and every clause of it is intact:

- YAML::PP still supplies **order and nothing else**, still for both formats.
- YAML::XS and JSON::MaybeXS are still the parsers and the emitters; the wire
  bytes are untouched and the encrypt side still rides on the emitters sorting
  keys.
- The metadata MAC is still excluded **structurally**.
- Failure still falls back to sorted order, safe in the one direction that
  matters.

One sentence of ADR 0001 changes its owner rather than its content: *"a new
runtime prerequisite, for both formats — JSON is a YAML 1.2 subset, so one
parser covers both"* was a fact about `File::SOPS` and is now a decision stated
in `File::SOPS::Format::JSON`, where it can be revisited for one format without
touching the other. That is the whole of the amendment.

The consequences ADR 0001 recorded are unchanged, including the dependency on
YAML::PP — it is still a runtime prerequisite, now reached through
`Format::YAML` alone.

## Rejected alternatives

**Give the handler a shape a plain Perl hash can carry** — a mapping as an
arrayref of `[key, child]` pairs, or an explicitly tagged node form. It would
spare an ENV handler its tie. Rejected: `_document_leaves` is the walk the
digest is built on, its `$ordered` side is pinned as a plain hash tree by
`t/45`, and the dispatcher's return shape is pinned by `t/13`. Changing the
node form means changing the walk, which is a change to what gets hashed for a
consumer that does not exist yet — the opposite of the measured no-op this
needed to be.

**Keep the reparse in `File::SOPS` and pass it a per-format reader.** Same
result with the format knowledge split across two files, and no place to put
"where the metadata sits", which is the part `File::SOPS` cannot know.

**Give JSON an order-preserving reader of its own.** No decoder in the
dependency tree offers one, so it means a hand-written scanner over raw text.
ADR 0001 rejected exactly that, for exactly this job, and the divergence it
would fix (a surrogate-pair escape in a key) is not written by either emitter
and already fails loudly.

**Fall back to sorted order for a format class with no such method.** Silent,
and silently wrong for exactly the formats this ADR exists to unblock.

## Notes

`t/51-order-preserving-parse-per-format.t` pins the seam: both shipped handlers
answering in document order, the dispatcher using the class it is given, all
five ways of declining, the loud refusal for a class that cannot answer, and —
the load-bearing pair — one encrypted document verifying through a flat,
line-oriented, non-YAML handler and failing through one that returns the same
keys reversed. Against the pre-change library it fails 15 of its 33 assertions.

`prove -lr t/`: 52 files, 1157 tests, PASS. `t/04-interop.t` **ran** against
sops 3.13.3 at `/tmp/sops`: 32 tests, PASS.
