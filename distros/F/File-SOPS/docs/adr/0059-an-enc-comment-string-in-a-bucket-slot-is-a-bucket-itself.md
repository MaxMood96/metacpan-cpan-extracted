# ADR 0059 — An ENC-comment string in a bucket slot is a bucket itself

- Status: accepted
- Date: 2026-08-23
- Resolves k172
- Lane: wire
- Depends on **ADR 0041** (a sops comment is a leaf of its own), **ADR 0047**
  (an INI comment lives in its section — the predicate `$COMMENT_BUCKET_KEY`
  that this ADR widens), and **ADR 0056** (the k168 leaf guard this
  decision narrows, deliberately). The Comment-object half of the predicate
  is unchanged; the wire half is what this ADR adds.
- **Moves no wire bytes.** The fix preserves a comment line the previous
  encrypt already wrote: `_encrypt_tree` returns the bucket list as-is
  instead of letting the leaf walk descend into it and re-encrypt each item
  as a plain `type:str`. For every document that did not carry the bad
  shape, every byte — and every MAC value — is unchanged.

## Context

ADR 0047 introduced the comment bucket: a non-empty ARRAY held under the
empty key `''` adds no path component to the walk, because a comment
authenticates under its section's path, not under `section::`. The predicate
that recognises a bucket was `_is_comment_bucket`, and at the time it
answered YES only for a list of `File::SOPS::Comment` objects — the
plaintext tree's spelling of "comment bucket".

ADR 0049 (rule-first decrypt) closed the asymmetric walk: `_decrypt_tree`
now answers the rule about the path it builds, the same way `_encrypt_tree`
does. The walk that builds the WIRE tree (decrypting each leaf in place)
returns, for a leaf the rule EXCLUDES, the leaf's own `ENC[…,type:comment]`
text — because decrypting it would produce plaintext that does not belong
in the document at all. The wire tree thus carries the comment bucket as a
list of literal `ENC[…,type:comment]` strings, which is what every encrypt
this library has ever done wrote into the file.

The encrypt walk does not recognise that list. `_is_comment_bucket`
answered NO — its `_is_comment_leaf` half is gated on the data key, which
`_encrypt_tree` has none of — so the bucket key ADDED a path component on
the way back in. Two wrongs followed.

1. The leaf guard (k168 / ADR 0056) fired at each item: the rule
   excludes the bucket path (under `[db]`, with the default suffix), the
   item is a plain string, and the label is `comment`. The walk died with
   "a caller string whose text parses as an ENC[...,type:comment] token
   cannot stand as a value at a path the encryption rule EXCLUDES", at
   every item in the bucket. Rotate of an already-encrypted file (with
   `ignore_mac => 1` to bypass the inevitable MAC mismatch, since the same
   shape on the read side dropped the text from the digest) refused.
2. At any path the walk would have re-encrypted the strings as `type:str`
   and lost the `comment` label. The INI emitter then croaked at the
   `''` slot with "a plain scalar is not one" — a leaf the previous
   encrypt wrote is silently flattened and the document fails its own
   emitter. This is the failure mode the k172 ticket names.

The reproducer, from the ticket body:

```perl
File::SOPS->encrypt(
    data       => { db => { '' => [ File::SOPS::Comment->new(text => ' a comment') ],
                            host => 'h' } },
    recipients => [$pub],
    format     => 'ini',
    unencrypted_regex => '^public_',
);
# mutate the rule to ^db$ so the [db] section is now excluded,
# then rotate with ignore_mac => 1.
```

The original rule `^public_` selected every key in the fixture (nothing
starts with `public_`), so the comment was written as
`ENC[…,type:comment]`. After mutating the rule to `^db$` the bucket at
`[db]` is excluded, and `rotate` reaches the bug.

Both halves of the fix have to land together. Widening the bucket
predicate without stopping the ARRAY walk at a wire bucket would still
let the leaf guard fire; stopping the ARRAY walk at a wire bucket without
widening the bucket predicate would let the walk descend into the bucket
and re-encrypt the items as `type:str`.

## Decision

`_is_comment_bucket` recognises the wire half — a plain string whose
`encrypted_type` reads `comment` — alongside the plaintext half it
already recognised:

```perl
sub _is_comment_bucket {
    my ($value) = @_;

    return 0 unless ref $value eq 'ARRAY' && @$value;
    for my $item (@$value) {
        next if File::SOPS::Encrypted->is_comment($item);
        next if !ref $item
            && (File::SOPS::Encrypted->encrypted_type($item) // '')
                eq 'comment';
        return 0;
    }
    return 1;
}
```

The ARRAY branch in `_encrypt_tree` returns the bucket list as-is when
the list holds nothing but those wire-half items, so the walk does not
descend into one and the k168 leaf guard never reaches a bucket
item:

```perl
elsif (ref $node eq 'ARRAY') {
    my $is_wire_bucket = 1;
    for my $item (@$node) {
        if (ref $item
            || (File::SOPS::Encrypted->encrypted_type($item) // '')
                ne 'comment') {
            $is_wire_bucket = 0;
            last;
        }
    }
    return $node if $is_wire_bucket;
    # ... existing descend ...
}
```

The Comment-object half is intentionally NOT in scope for the ARRAY
short-circuit: a Comment object at a SELECTED path still descends so the
walk can encrypt it to an `ENC[…,type:comment]` string, which is what
makes the plaintext-tree→wire round trip work. A bucket that holds a
Comment object AND a non-comment element (sops never wrote one — ADR 0047
measured it — but a caller could) descends; the leaf code path handles
each element on its own.

### Why the data-key gate is dropped on the wire half

`_is_comment_leaf` (which `_is_comment_bucket` was built on top of) is
gated on `$data_key` because the read side uses it with the key to
decrypt the leaf and recover plaintext. The encrypt side has no key to
open the leaf with — and does not need one. The predicate only needs to
ASK whether the text parses as `ENC[…,type:comment]`; that is the same
predicate k168 added to the leaf guard (ADR 0056), with the same
`// ''` defence against an `undef` answer, and `File::SOPS::Encrypted->
encrypted_type` is the one place that asks it. The gate is dropped
because the gate is for the key, and the key is not needed.

### Why path consistency requires BOTH shapes to answer YES

`_adds_no_path_component` is the predicate asked by every walk that
builds a path (encrypt and decrypt). One sub rather than two — because
the two walks MUST agree about the path they build. Where the bucket
predicate returns NO the bucket key adds a path component, and the two
walks answer `should_encrypt_path` about different paths. A plain value
at `db:` is one AAD; the same value at `db::` (the bucket key appended)
is another. The leaf walks don't share the bucket predicate — one sub
rather than two — because a path they disagree on writes a document
this library writes and then cannot read (measured, with `^$`: rotate
declined a file encrypt had just written). Recognising only one shape
and not the other moves the path for the OTHER walk, which is exactly
the defect the rule exists to close.

## Consequences

- **A misruled INI file with an `ENC[…,type:comment]` bucket at an
  excluded section rotates under `ignore_mac => 1`.** The bucket
  predicate catches the list, the ARRAY short-circuit returns it as-is,
  and the comment line survives. This is the user-visible effect of the
  change and the one the ticket asks for.
- **The Comment-object bucket still round-trips.** A list of Comment
  objects at the bucket slot still encrypts to `ENC[…,type:comment]`
  strings (because the Comment object half is a plaintext comment, and
  the walk encrypts it), and still reads back to Comment objects (because
  decrypt at a SELECTED path produces the same plaintext). The
  round-trip test pins this.
- **The k168 leaf guard still fires.** A caller that hands a plain
  `ENC[…,type:comment]` string at an excluded LEAF path is still refused
  with the k168 message — the leaf guard's reach is narrowed by the
  ARRAY short-circuit, not by removing the guard. The two guards do not
  absorb each other; the bucket predicate and the leaf guard are two
  shapes for two slots.
- **A bucket of mixed shape is treated as a wire bucket if and only if
  every element passes the test.** A list of `[Comment, ENC-comment]`
  passes (Comment objects pass the `is_comment` test; ENC-comment
  strings pass the `encrypted_type eq 'comment'` test). A list of
  `[Comment, 'plain value']` does not — the `'plain value'` fails the
  wire half, is not blessed as a Comment, and the predicate returns 0.
  The walk descends; the leaf code path refuses the `'plain value'` at
  the excluded path with the k168 message. This is intentional:
  the bucket predicate is a structural test, not a content one.
- **No MAC values move.** The guard short-circuits before any byte is
  written or re-encrypted. For every document that did not contain the
  bad shape, the MAC is byte-identical — measured by running the suite
  before and after.
- **No wire bytes move.** The bucket list this library previously wrote
  is preserved as-is; the Comment object list still encrypts to the
  same `ENC[…,type:comment]` strings. The emitter behaviour is
  unchanged. `Encrypted.pm`, `Metadata.pm`, `Backend/Age.pm` and every
  format handler are untouched.

## Limits

- **The fix is specific to `_encrypt_tree`.** `_decrypt_tree` already
  returns a list of literal `ENC[…,type:comment]` strings at an excluded
  bucket slot, because the wire-tree shape carries them as such; the
  read-side walk does not need an array short-circuit because there is
  nothing to re-encrypt. The bug is asymmetric, and the fix is too.
- **The Comment-object half does NOT get the ARRAY short-circuit.** A
  Comment object at a SELECTED path has to descend so the walk can
  encrypt it; the wire-half short-circuit would break that. The shape
  the short-circuit applies to is "list of nothing but `ENC[…,type:comment]`
  strings" — measured against the wire tree decrypt produces.
- **No new guard on a bucket item that DOES get re-encrypted.** A
  caller passing a Comment object at an excluded bucket slot still
  descends and still encrypts; the line-3396 mapping-value guard fires
  on a Comment object in a mapping value, not in a bucket sequence
  element, so this case is uncaught. That is a pre-existing shape the
  ticket does not name, and adding a guard for it would expand scope.
- **No new guard on the read side.** The `_decrypt_tree` wire-tree
  shape is correct as it is — it returns `ENC[…,type:comment]` strings
  at an excluded bucket slot, which is what the encrypt walk now
  recognises. Adding a guard there would refuse a shape that is exactly
  the shape this ADR unblocks on the write side.

## Rejected alternatives

**Keep the leaf guard and widen it to walk lists with a comment at the
head.** Tighter — fires on the list as a whole, not on each item. Rejected
because the failure is not "an `ENC[…,type:comment]` at a leaf the rule
excludes": the leaf is the previous encrypt's literal, and the rule
excludes the BUCKET, not the item. The leaf guard's predicate is the
wrong shape for the bug; the bucket predicate is the right one. Widening
the leaf guard would also keep firing on a wire bucket at a SELECTED
section, where the k168 message is wrong — the rule does not
exclude the section, only the bucket inside it (no, actually: it
excludes the whole section; this shape, if it ever happened, would be
encrypted again as `type:comment` at a SELECTED path inside the section).
The shape is the bucket predicate's, not the leaf guard's.

**Make `_is_comment_bucket` only recognise ENC-comment strings, drop the
Comment-object half.** Tighter still. Rejected because the path-
consistency argument is symmetric: BOTH walks have to ask the predicate
about the SAME shape, and the plaintext tree (Comment objects) is the
shape `_encrypt_tree` sees on the way in. Recognising only the wire
half would mean the plaintext-tree walk answers NO, the bucket key
adds a path component, and `_encrypt_tree` encrypts the Comment objects
under a path that does not match what `_decrypt_tree` will build. The
defect class — same AAD on both sides — is the rule this ADR inherits
from ADR 0047.

**Stop the ARRAY walk entirely when ANY item is an `ENC[…,type:comment]`
string.** Looser than the decision. Rejected because a list that
carries a comment AND a value (sops does not write one — ADR 0047
measured it — but a caller could) would be short-circuited and the
non-comment element would never be encrypted. The decision's "all
items must pass" predicate is what makes the short-circuit apply to a
wire bucket, not to a sequence that happens to carry a comment among
its elements.

**Refuse the bad shape at the leaf guard, where k168 already has a
hook.** Rejected because the leaf guard's predicate (`!ref $node &&
encrypted_type eq 'comment'`) fires per leaf, and a wire bucket is a
list — the leaf guard reaches each item and dies. The k172 ticket
specifically widens the bucket predicate to recognise the wire half so
the walk no longer reaches the leaf guard at all. The leaf guard stays
in place (a caller string at an excluded LEAF is still refused); the
bucket predicate is what catches the bucket-list case before the walk
descends.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23: `prove -lr t/`
runs at 74 files and 1364 tests, all PASS. The interop proof
(`t/04-interop.t`) is executed rather than skipped; the new
`t/73-ini-comment-bucket-at-excluded-path.t` exercises the bucket
predicate and the misruled-INI rotate reproducer with the sops binary on
PATH, and the INI emitter (where the second failure mode would have
croaked) is reached through it. Before the fix, t/73's two RED
subtests fail for the reason this ADR names — subtest 1's rotate dies
with the k168 message at `db::` and subtest 2's predicate returns
0 for ENC-comment strings. After the fix, all 3 subtests pass.

Two edits in `lib/File/SOPS.pm`: the `_is_comment_bucket` widening and
the ARRAY-branch short-circuit in `_encrypt_tree`. One test,
`t/73-ini-comment-bucket-at-excluded-path.t`. The existing
`t/72-caller-enc-comment-string-at-excluded-path-is-refused.t` subtest
6 is updated to assert the new (correct) behaviour for the bucket-list
case, which the k168 guard no longer reaches — documented inline as
a deliberate narrowing of k168's reach. `Encrypted.pm`,
`Metadata.pm`, `Backend/Age.pm` and every format handler are untouched.
The line-3396 mapping-value Comment-object guard and the line-3480
read-side type:comment guard are unchanged.

Lane: wire. The decision moves the bucket predicate, which is what
`_encrypt_tree` and `_decrypt_tree` share to keep their paths in step;
the predicate is the one ADR 0047 measured, and widening it is what
the wire-lane boundary requires.