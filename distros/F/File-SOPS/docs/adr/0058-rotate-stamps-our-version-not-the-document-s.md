# ADR 0058 — Rotate stamps our version (3.7.3) over the document's; sops preserves it verbatim

- Status: accepted
- Date: 2026-08-23
- Resolves k151
- Lane: api
- **No code change.** Documentation-only: POD in `lib/File/SOPS/Metadata.pm` and
  this ADR. No test, no wire byte, no behaviour change. The behaviour this
  records is what the code already does and what it has done since 0.003.

## Context

sops's `sops` section carries a `version` field that names the implementation
that produced the document. Measured against sops 3.13.3 (`/tmp/sops`):

```
file written by sops 3.13.3, then sops rotate -i file.yaml
  version stays 3.13.3

file written by sops 3.13.3 with version: v3.13.3, then sops rotate
  version stays v3.13.3

file written by sops 3.13.3 with version: 1.2.3, then sops rotate
  version stays 1.2.3

file written by sops 3.13.3 with version: 3.13.3-rc.1, then sops rotate
  version stays 3.13.3-rc.1
```

sops does not normalise the field on a rewrite: whatever the document carries
is what comes back out, and only `sops -e` on a plaintext file stamps the
writer's own version. The Go source's relevant path is the metadata merge in
`Update` / `rotateData` -- it preserves the source field and only rewrites
the data key, the MAC and `lastmodified`.

Here, `File::SOPS::Metadata->policy_args` deliberately omits `version` from
the constructor arguments it returns, and the POD for that method has, since
the rule policy was introduced, named `version` as one of the fields that
"describes B<what> encrypted this particular document" -- because none of
that survives a re-encryption:

> ... the per-backend key material (age, pgp, kms and friends) wraps a data
> key that is about to be replaced, mac authenticates values that are about
> to be rewritten, lastmodified is the AAD of that MAC, and version names
> the implementation doing the writing rather than the one that wrote the
> file before.

`File::SOPS->rotate` then constructs a fresh `File::SOPS::Metadata` via
`_metadata_for_encrypt`, which calls `policy_args` and hands the result to
`Metadata->new`. The constructor's `version` attribute defaults to
`$File::SOPS::Metadata::SOPS_VERSION`, which is `3.7.3`. A document written
by sops 3.13.3 therefore reads back here with `version: 3.7.3` after a
rotation, where it carried `3.13.3` before. The stamp goes backwards; the
field is a provenance label that names a different writer than the one that
actually wrote the file.

NOTHING BREAKS. Measured on sops 3.13.3:

- 3.7.3 is a version sops reads at exit 0 -- it is not in the semver-refused
  set.
- No digest, AAD, decryption decision, or any other path here reads the
  field. The MAC, the AES-GCM AAD, the rule walks, the data-key unwrap and
  the encryption-rule selector all ignore it.
- The only consumer of the field is sops itself, and sops uses it only to
  decide whether the document's version is one it can parse -- and 3.7.3 is.

The defect class this looks like is not the defect class it is. k18
(re-encrypting in place producing unrecoverable values) and k150
(silent document collapse to its last YAML document) are both "this library
wrote a document that lost something". This ticket is the opposite: nothing
on the document has been lost, and a field whose only consumer is a binary
that no longer trusts the field's writer has been silently re-attributed to
the new writer. The cost of carrying the original version across would be a
field that goes forward when sops's own goes backward; the cost of stamping
our own is a field that goes backward when sops's own goes forward. Both are
cosmetic, neither is observable from any test this distribution has.

## The decision

Keep the stamp as it is. `File::SOPS::Metadata->policy_args` continues to
omit `version`, and the consequence -- that `File::SOPS->rotate` writes a
fresh `version: 3.7.3` over whatever the document carried -- is named in
the method's POD and in the `version` attribute's POD, with the divergence
recorded in this ADR. No code change, no test, no wire byte.

The decision is taken on three measurements and a deliberate property of the
field:

1. **The field is unobserved end-to-end on this side.** Nothing reads it
   -- not the MAC, not the AAD, not the rule walk, not the data-key unwrap,
   not the encryption-rule selector, not the format handlers. The POD for
   `version` has said so since the field was modelled, and the ADR cited
   there (`docs/adr/0043`) carries the measured table. The cost of the
   divergence is therefore the appearance of a writer that did not write the
   file, and nothing else.

2. **The field is observable end-to-end on sops's side, but only as a
   parse-accept gate.** sops semver-parses the field and refuses a document
   it cannot parse -- `3`, `3.13`, `true`, `""`, and an ABSENT version are
   all exit 1 on every read path. That gate is strictly narrower than the
   set we write. We default an absent version to `3.7.3` on read and stamp
   `3.7.3` on write, and `3.7.3` is in sops's accepted set; carrying the
   document's own value across would never let a document that sops accepts
   into one that sops refuses, because every version sops accepts is one
   we'd be happy to write. It would let a document sops REJECTED into one
   we would still REJECT, because the rejection is on the read side and
   this ADR doesn't touch it; ADR 0043 measures the accepted set in detail.

3. **The document's version reaching a document is the first path that lets
   the field escape.** `Metadata::from_hash` accepts every spelling sops
   refuses, deliberately (ADR 0043); a document written by an old or
   experimental sops with a version sops itself has stopped supporting
   would round-trip a value sops reads at exit 0 into one it reads at exit
   1 -- silently, on a rotation, with no error and no log. The stamp's
   job is exactly to not propagate that. It is the same property that keeps
   `policy_args` from carrying the other fields in the "describes B<what>
   encrypted this particular document" list -- `mac` is computed for the
   values that are about to be rewritten, `lastmodified` is the AAD of that
   MAC, and the per-backend key material wraps a key that is about to be
   replaced. `version` is the provenance stamp for the same reason: it
   names the writer, and the writer is changing.

## Consequences

- `File::SOPS->rotate` on a document written by sops 3.13.3 reads back with
  `version: 3.7.3`. Same as before; documented in `policy_args`'s POD and
  in this ADR; no test pinned because the behaviour is already what every
  test in the suite passes against.
- A caller who wants the document's version preserved across a rotation can
  read the document's `sops.version` field before the rotation (it is in
  `$meta->version` after `from_hash`) and write it back afterwards by
  calling `File::SOPS::Metadata->from_hash($rotated)->version($kept)` and
  re-emitting, or by editing the file directly with `sops`. The first path
  is documented as the way; the second is what sops itself does.
- A document whose `sops.version` is one sops refuses at read time
  (`3`, `3.13`, `true`, `""`, null, `03.13.3`, `3.13.03`, `3.13.3-`,
  `3.13.3+`, `3.13.3-!`, `3.13.3-01`) is accepted here on read and refused
  on write: `encrypt`, `encrypt_file`, `encrypt_in_place`, `rotate` and
  `edit` all build a fresh `Metadata` whose `version` defaults to `3.7.3`,
  and the refusal no longer applies. The ADR records this as a deliberate
  outcome -- the field is permissive on read, normalizing on write, and the
  normalisation is a single value that sops accepts.
- `policy_args`'s POD now names the divergence explicitly: it cites the
  measured behaviour of sops 3.13.3, names the field, and points at this
  ADR. The `version` attribute's POD and the `from_hash` method's "Nothing
  reads the field" bullet are updated in the same edit to point here too.
  The decision is no longer implicit in a one-sentence aside about what the
  field describes.

## Limits

- The fix is documentation. No code in `lib/`, no test, and no format handler
  is touched. A regression test that pins the version on rotation would
  need a fresh sops binary every time the field moved, and the field does
  not move -- it always comes out as `3.7.3`. The absence of a test is the
  absence of a claim that needs pinning.
- The decision does not address every divergence in the `sops` section.
  `mac_only_encrypted`, the four encryption rules, and the unmodelled
  fields in `extra` are carried across a rotation by `policy_args` (the
  rules because they describe HOW the document is encrypted; the unmodelled
  fields because this class does not model them and dropping them would
  change what sops does, ADR 0022). The decision here is specifically about
  `version`, which is the only field whose meaning is purely provenance.
- The decision does not change the read side. `from_hash` still accepts
  every spelling sops refuses, and ADR 0043 is the read-side ADR. A document
  whose version sops rejects is read at exit 0 here and refused at write
  time -- the same as today.

## Rejected alternatives

**Carry the document's version across a rotation the way sops does.** The
other path the ticket names. `policy_args` would optionally include
`version` when the caller passes one; `rotate` (in `lib/File/SOPS.pm`)
would read the existing version BEFORE building the fresh `Metadata` and
pass it into `policy_args`'s caller. The change is small, but it is the
first path that lets the field escape on a write, which is the third
measurement in §"The decision". A document whose version sops refuses is
read permissively here; carrying it across means rewriting a document sops
would now reject, silently. Rejected because the cost is a divergence from
sops (this time in the other direction) for a benefit nobody asked for: the
stamp is provenance, and the new writer is a different writer, and that is
the whole point of the field.

**Refuse to rotate a document whose version is one we don't write.** Tighter
than the current behaviour. The document carries a `version: 3.7.3-rc.1`
that we never emit, and rotation is refused until the field is normalised
by hand. Rejected because the field is unobserved on this side and the
cost of an extra refusal is a caller-side step that changes nothing about
the document's contents. The field is also permissive on read (ADR 0043);
adding a write-side refusal that depends on the read-side permissiveness
would make the two halves of the round trip disagree.

**Drop the field entirely on a write.** Tighter still. `version` would be
removed from `to_hash`, the `version` attribute would be marked internal,
and every document this library produces would carry no `version` field at
all. Rejected because sops refuses an absent version on read (measured,
exit 1, every path); stripping the field would make every document this
library writes unreadable by sops. The stamp has to stay; the question is
which stamp.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) on 2026-08-23, with `version:
3.13.3` in the `sops` section:

```
$ sops -e --age age1... file.yaml          # writes version: 3.13.3
$ perl -Ilib -MFile::SOPS -e '
      File::SOPS->rotate(
        file       => "file.yaml",
        identities => ["AGE-SECRET-KEY-1..."],
      )'
$ grep '^    version:' file.yaml
    version: 3.7.3
```

The rotation succeeds at exit 0, the document decrypts, the MAC verifies,
and the only field that has moved is the one this ADR records. The same
measurement with `version: v3.13.3`, `version: 1.2.3` and `version:
3.13.3-rc.1` produces the same outcome. The interop proof
(`t/04-interop.t`) and the full suite pass against the same binary
before and after the POD edit; the edit is prose and adds no test.

The single edit is in `lib/File/SOPS/Metadata.pm`'s POD: `policy_args`,
`version` attribute and the "Every write path stamps a fresh `3.7.3`"
bullet under `from_hash` are updated to point at this ADR. The entry is
in `Changes` under `{{$NEXT}}`. `lib/File/SOPS.pm`, `Encrypted.pm`,
`Backend/Age.pm`, every format handler, and every test are untouched.

Lane: api. The decision is in the method's POD, and the method lives in
the API lane. The wire lane does not touch the field, and the format lane
neither reads it nor writes it.
