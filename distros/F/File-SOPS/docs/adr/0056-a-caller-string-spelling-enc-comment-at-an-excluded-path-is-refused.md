# ADR 0056 — A caller string spelling ENC[...,type:comment] at an excluded path is refused

- Status: accepted
- Date: 2026-08-23
- Resolves k168
- Lane: api
- Depends on ADR 0041 (the File::SOPS::Comment mapping-value guard, the twin
  shape) and ADR 0046 (the read-side `_decrypt_tree` rule-driven exit, which
  closed the other half of the asymmetric walk). The `should_encrypt_path`
  predicate the guard consults is the one ADR 0046 picked.
- **Does not move wire bytes.** The guard fires before any byte reaches the
  wire: a shape that today would be WRITTEN as a plain `type:str` value is
  REFUSED at write time, so the only byteset change is "no bytes at all" for
  documents that carry the bad shape.

## Context

`_encrypt_tree` is rule-driven: a leaf is written as it stands where
`should_encrypt_path` is false, and encrypted under the data key where it is
true. `_decrypt_tree` answers the same predicate at the leaf, ADR 0049
narrowed it to that one answer, and ADR 0046 measured the cost of leaving the
walks asymmetric. The walks now agree on the rule.

They disagree on what they ASK of the leaf, and for one shape that
disagreement is the bug. The rule says exclude; the leaf spells
`ENC[AES256_GCM,…,type:comment]`. The encrypt side writes it as a plain
`type:str` value and hashes its text into the MAC. The read side reaches the
same leaf, `_is_comment_leaf` (with `$data_key` defined) reads the label and
drops it from the digest, where the encrypt side already hashed its text. The
document fails its own MAC, written by this library at exit 0.

The reproducer, from the ticket body, verbatim:

```perl
File::SOPS->encrypt(
    data => { db_unencrypted => { q{} => [ $literal_enc_comment_string ] },
              k => q{v} },
    recipients => [$pub], format => q{yaml},
);
```

The path `db_unencrypted:` is excluded by the default `unencrypted_suffix:
_unencrypted` rule, and `q{}` holds a sequence of one element: the literal
`ENC[...]` string the caller asked the library to encrypt. The leaf lands
bare. On the next decrypt, `_decrypt_tree` reaches it first and tries to
decrypt it -- the leaf's own text fails `_decrypt_value`'s verification, and
the symptom on decrypt is `Authentication failed` rather than `MAC mismatch`.
That is why the ticket is low priority: the file is broken loudly, not
silently. It is still a file this library wrote and cannot read back, which
is the defect class the file-this-library-cannot-read rule exists to close.

The fix is the twin of the File::SOPS::Comment mapping-value guard at
`_encrypt_tree` line 3396 (ADR 0041). That one fires on a blessed Comment
object in a mapping value slot -- a shape no SOPS store writes, where sops
reads it back at exit 0 as a dump of Go's `yaml.Comment` struct. This one
fires on the same shape, at the same kind of slot, but reached via the wire
because the caller passed a plain string rather than a Comment object. Same
answer, different predicate, same error class.

The mapping-position mapping-value guard is in place (line 3396, ADR 0041)
and unchanged here. The `_decrypt_tree` mapping-value type:comment guard at
line 3480 is also unchanged -- the read side already refuses the same shape
on the way back in, where the existing `Authentication failed` symptom comes
from. This ADR adds the WRITE-side refusal that closes the file-this-library-
writes-and-cannot-read half of the defect, and leaves the read side alone.

## Decision

A caller plain STRING whose text parses as `ENC[…,type:comment]` in a slot
the encryption rule EXCLUDES is refused at write time in `_encrypt_tree`,
naming the path and the shape.

The guard lives in the leaf branch of `_encrypt_tree`, BEFORE the existing
`return $node unless $metadata->should_encrypt_path($path);` early return,
with a predicate of three conjuncts that exactly match the k168 ticket:

```perl
croak _at_path($path, "a caller string whose text parses as an "
    . "ENC[...,type:comment] token cannot stand as a value at a "
    . "path the encryption rule EXCLUDES: this library writes the "
    . "literal as a plain type:str and hashes its text into the "
    . "MAC, but the read side (_is_comment_leaf with \$data_key "
    . "defined) drops the same text from the digest, so the "
    . "document fails its own MAC at the next decrypt. sops reads "
    . "the document but ignores the leaf at the same level -- "
    . "which is why the symptom on decrypt is 'Authentication "
    . "failed' rather than 'MAC mismatch'. Replace the string "
    . "with a File::SOPS::Comment in a SEQUENCE position, or "
    . "rename the key so the rule no longer excludes it")
    if !$metadata->should_encrypt_path($path)
        && !ref $node
        && (File::SOPS::Encrypted->encrypted_type($node) // '')
           eq 'comment';
```

Three things about the predicate, all of them load-bearing.

1. **`!$metadata->should_encrypt_path($path)`** -- the guard fires only where
   the rule excludes. At a SELECTED path the leaf is encrypted normally by
   `_encrypt_value`, which handles both a plain string and a Comment object,
   and the ticket's shape is the EXCLUDED one. Without this conjunct a leaf
   the rule selects would be refused here even though `_encrypt_value`
   would have encrypted it just fine.

2. **`!ref $node`** -- the guard fires only on a plain string. A blessed
   `File::SOPS::Comment` is a Comment OBJECT, not a literal ENC token, and
   is caught earlier by the line-3396 guard (ADR 0041) -- which has to be
   the case, because `_encrypt_value` only sees a leaf the rule selects, and
   a Comment object can stand at an INCLUDED path where `_encrypt_value`
   encrypts it normally. The two guards partition the shape cleanly:
   `File::SOPS::Comment` at any path is caught by line 3396 (mapping-value
   slot) or `_encrypt_value` (any other slot); a plain string parsing as
   `type:comment` at an EXCLUDED path is caught here.

3. **`(encrypted_type($node) // '') eq 'comment'`** -- the wire half of the
   predicate. `File::SOPS::Encrypted->encrypted_type` reads the label from
   the one anchored regex, without decoding the ciphertext, and answers for
   a string whose plaintext is damaged; that is the case the existing
   `_decrypt_tree` guard at line 3489 uses, and using the same call here
   keeps the two predicates in step. `// ''` defends a `undef` answer (the
   leaf is not an ENC token at all), so a leaf that just happens to contain
   the letters `ENC` is not refused.

The guard is placed BEFORE the existing early return -- which would have
returned the leaf as-is had the rule excluded it -- because the existing
return is the `should_encrypt_path == 0` branch and the guard must fire
there. The comment block above the guard names the failure mode, points at
`_is_comment_leaf` as the read side, and references this ADR and the ticket,
matching the documentation density of the line-3396 guard it twins.

## Consequences

- **A caller that hands a literal `ENC[...,type:comment]` string at an
  excluded path gets a loud refusal at write time**, naming the path and the
  shape, with the two safe answers called out: replace the string with a
  `File::SOPS::Comment` in a SEQUENCE position (the file shape sops actually
  writes, ADR 0041), or rename the key so the rule no longer excludes it.
  This is the entire user-visible effect of the change, and the one the
  ticket asks for.
- **A document this library has already accepted and encrypted is unchanged.**
  The guard fires at write time, on a leaf in the plaintext tree the caller
  hands to `encrypt`. A document that came in via `decrypt` is read, not
  written, and the read-side path (`_decrypt_tree` line 3480) is unchanged.
  No file on disk changes its bytes.
- **No MAC moves.** The guard refuses the bad shape before any byte reaches
  the wire; a shape that would have been written as a plain `type:str` (and
  produced a MAC mismatch on the next decrypt) is refused instead. The MAC
  for any document that did not contain the bad shape is unchanged. The
  existing MAC for a document that DID contain the bad shape is, by the
  same token, also unchanged -- the document was never the right document.
- **The `File::SOPS::Comment` mapping-value guard (line 3396, ADR 0041) is
  unchanged.** A Comment OBJECT is a different shape -- a blessed reference,
  not a literal ENC token -- and the predicate is `is_comment`, not
  `encrypted_type`. The two guards do not absorb each other, and the test
  pins both: the new guard fires on a plain string at an excluded path; the
  old guard fires on a Comment object in a mapping value slot, with its own
  message and its own predicate.
- **The `_decrypt_tree` mapping-value guard (line 3480, ADR 0041) is
  unchanged.** That guard fires on the read side, where the symptom on
  decrypt was already `Authentication failed`. Closing the write side keeps
  the file this library writes honest; closing the read side is k160
  territory and lives in another lane.
- **A `type:str` (or any other label) ENC token at an excluded path still
  WRITES verbatim.** The guard's predicate discriminates on the label, and
  the label here is `comment` -- the only one sops treats as a comment rather
  than a value. A `type:str` token at an excluded path is what `_encrypt_tree`
  always wrote there, and the read side returns it as the literal ENC
  string, which the round-trip test pins.

## Limits

- **No new guard on the read side.** The `_decrypt_tree` mapping-value
  type:comment guard at line 3480 stays as it is. Closing the read side is
  the asymmetric-walk ticket (k160, wire lane) and is its own decision
  -- it moves what the digest covers, which is not the API lane's.
- **No guard on a plain string parsing as `ENC[...,type:comment]` in any
  other excluded shape.** The k168 ticket names one shape -- a plain
  string at an excluded path -- and that is what this guard catches. A
  caller passing a list whose element is the bad shape fires the guard at
  the leaf, with the same path naming; a caller passing it inside a
  blessed Comment goes through line 3396, unchanged. No further coverage
  is asserted.
- **No guard on the rule SELECTS the path case.** That is `_encrypt_value`'s
  job, and a Comment object at an included path encrypts to `type:comment`
  the way the file shape ADR 0041 describes.
- **No regex-dialect handling.** A rule regex RE2 cannot compile is a
  separate question (k161, ADR 0048 / ADR 0051), and the predicate
  here uses the existing `should_encrypt_path` which already answers in
  RE2's dialect on the read path.

## Rejected alternatives

**Leave the file written and let the read side refuse it.** What happens
today. The symptom on decrypt is `Authentication failed` from
`_decrypt_tree`'s line-3557 guard (the rule-says-encrypted-but-the-file-
holds-a-plain-value half), and the file is not silently corrupted. Rejected
because it is the same defect class k18 and k150 already
demonstrated: a file this library wrote and cannot read back is a broken
file, not a working file that errs on read. The exit is louder than the
MAC mismatch that would have happened on the line-3396 guard's twin, but
it is still exit 1, and the document the caller just handed the library
is the one that triggered it.

**Forbid the ENC token text in any excluded subtree, by regex.** Tighter
than the label-only predicate, and would catch a type:str ENC token whose
ciphertext happens to be a comment's. Rejected because the only label sops
treats as a comment is `comment`; a `type:str` token at an excluded path is
what the wire already carries and round-trips, and the new shape is the
half the read side drops, which is `type:comment` only.

**Tighten `_is_comment_leaf` so the wire half is unconditional, and accept
the asymmetric digest.** Removes the gate the line-3693 comment defends.
Rejected because the line-3693 comment is right: a plain string that
happens to spell `ENC[...,type:comment]` in an INCLUDED slot is encrypted
normally by `_encrypt_value`, and the digest has to cover its text; lifting
the gate here drops that text from the digest and breaks a document that
already works. The asymmetry is between the EXCLUDED slot (encrypt hashes
text, read drops) and the INCLUDED slot (encrypt hashes encrypted bytes,
read drops nothing) -- the gate fixes the second, the new guard fixes the
first.

**Refuse the literal ENC token in `Encrypted->encrypt_value` itself.**
Wider than the k168 ticket. Rejected because encrypt_value sees leaves
the rule SELECTS, where the leaf is about to be encrypted under the data
key and the type:comment label is just a label -- the bug is specific to
the EXCLUDED slot, and the guard lives in `_encrypt_tree` to keep the
EXCLUDED-slot decision local.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23: `prove -lr t/`
runs at 72 files and 1357 tests, all PASS. The interop proof
(`t/04-interop.t`) is executed rather than skipped; the new
`t/72-caller-enc-comment-string-at-excluded-path-is-refused.t` skips no
interop assertion because the guard fires in `_encrypt_tree`, before any
byte is written, and is reached directly via the public API. Before the
guard, t/72's two RED assertions (subtests 1 and 6) fail for the reason
this ADR names -- `encrypt` returns at exit 0 and writes a file the next
`decrypt` croaks on. After the guard, all 6 subtests pass.

The single edit is `lib/File/SOPS.pm` (the guard at `_encrypt_tree`'s leaf
branch, immediately before the existing early return). The single test is
`t/72-caller-enc-comment-string-at-excluded-path-is-refused.t`. The ADR is
this file. `Encrypted.pm`, `Metadata.pm`, `Backend/Age.pm` and every
format handler are untouched. The existing line-3396 guard and the line-3480
read-side guard are unchanged.

Lane: api. The guard is the twin of the API-lane line-3396 guard, sits in
the same walk, uses the same `_at_path` helper, and fires before the wire
is reached.
