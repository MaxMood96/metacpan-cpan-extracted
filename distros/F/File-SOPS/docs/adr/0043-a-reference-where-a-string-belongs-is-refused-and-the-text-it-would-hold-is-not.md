# ADR 0043 — A reference where a string belongs is refused, and the text it would hold is not

- Status: accepted
- Date: 2026-08-21
- Resolves k145 and k146, and clears the two divergences ADR 0042
  measured and left open
- Depends on ADR 0042 (the two typed metadata fields, and the shape refusal it
  established for them) and ADR 0002 (the type comes from the scalar)
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*

## Context

ADR 0042 decoded the two fields in a `sops` section that are **not** strings,
and named two divergences in the fields that **are**, both left open:

- a float-spelled string field — `unencrypted_suffix: 1e20` is
  `100000000000000000000` in Go and `1e+20` here (k146);
- `version` is weakly stringified and then **semver-parsed**, so sops refuses
  `version: 3` where this library accepts it (k145).

Both were filed as "what does `from_hash` do with a field whose value is not
what sops expects", and the answer turns out to be **three** answers, not one.
Measured against sops 3.13.3 at `/tmp/sops`, one age recipient, one document
per row, on 2026-08-21.

### sops stringifies a scalar, and writes the text back

| `unencrypted_suffix:` | `sops -d` | what `sops rotate` writes back |
|---|---|---|
| `3` | exit 0 | `"3"` |
| `3.13` | exit 0 | `"3.13"` |
| `1.5` | exit 0 | `"1.5"` |
| `true` / `false` | exit 0 | `"1"` / `"0"` |
| `0755` | exit 0 | `"493"` |
| `1e20` | exit 0 | `"100000000000000000000"` |

`strconv.FormatFloat(v, 'f', -1, 64)` for the float, `FormatInt` for the
integer, `"1"`/`"0"` for the bool. The decode is visible without the round trip
as well: `mac: 1e20` fails with `Input string 100000000000000000000 does not
match sops' data format`, and `mac: true` with `Input string 1`.

### sops refuses a container in every one of those fields

| field | `[]` | `{}` |
|---|---|---|
| `mac`, `lastmodified`, `version` | exit 1 | exit 1 |
| `unencrypted_suffix`, `encrypted_suffix`, `unencrypted_regex`, `encrypted_regex` | exit 1 | exit 1 |
| `unencrypted_comment_regex`, `encrypted_comment_regex` | exit 1 | exit 1 |

Always the same message — `'<field>' expected type 'string', got
unconvertible type` — and always before the document is opened. A field
**neither** implementation models is the exception that proves the rule:
`totally_unknown_field: []` is exit 0, ignored whatever it holds.

### `version` is not stringified and read, it is stringified and parsed

Refused on every read path — `sops -d`, `sops -d --extract`, `sops rotate` —
and never merely warned about:

| `version:` | sops |
|---|---|
| `3.13.3`, `"3.13.3"`, `3.7.3`, `99.0.0`, `0.0.0` | exit 0 |
| `v3.13.3`, `3.13.3-rc.1`, `3.13.3+build.5`, `3.13.3-alpha.beta+exp.sha.5114f85` | exit 0 |
| `1.2`, `1.a.b`, `1.2.3.4`, `1.2.3-!`, `1.2.3-01` | **exit 0** |
| `3`, `3.13`, `true`, `1`, `1.` | exit 1, *No Major.Minor.Patch elements found* |
| `""`, `null`, `~`, **and an absent `version` key** | exit 1, *Version string empty* |
| `03.13.3`, `3.13.03` | exit 1, *must not contain leading zeroes* |
| `3.13.3-`, `3.13.3+` | exit 1, *Prerelease is empty* / *Build meta data is empty* |
| `3.13.3-!`, `3.13.3-α`, `3.13.3+!`, `3.13.3+a..b`, `3.13.3-01` | exit 1 |
| `18446744073709551616.0.0` | exit 1, *ParseUint … value out of range* |
| `[]`, `{}` | exit 1, *unconvertible type* |

Three rules on top of `blang/semver`'s strict `Parse`, and all three matter:

- a leading **`v` is stripped** (`v3.13.3` is accepted, `V3.13.3` and `vv3.1.3`
  are not);
- a version whose text **begins `1.`** is accepted **without being parsed at
  all** — which is why `1.a.b` and `1.2.3-01` pass while `10.2.3-01` and
  `v1.2.3-01` fail (the bypass is tested before the `v` is stripped, and `1.`
  is a float to go-yaml, so it arrives as `1` and fails);
- everything else is the full grammar: uint64 components, no leading zeroes,
  prerelease components either all-digit-without-leading-zeroes or
  `[0-9A-Za-z-]+`, build components `[0-9A-Za-z-]+`, none of them empty.

**And `sops rotate` writes the version back verbatim** — `v3.13.3`, `1.2.3`,
`3.13.3-rc.1` and `3.7.3` each come out exactly as they went in. sops does not
normalise this field to its own version.

### What this library did with the same documents

`from_hash` accepted every row of all three tables. Two of them are not inert:

- **`encrypted_regex: []` is a plaintext write.** Measured: the reference
  reached `should_encrypt_key` as the pattern, matched no key, and
  `File::SOPS->rotate` wrote `password: hunter2` into the file and reported
  success — for a document `sops -d` refuses to open. (Reproduced in
  `t/57`, which fails on exactly that assertion without this change.)
- **`lastmodified: []`** becomes the AAD the MAC is authenticated with, whose
  bytes are then a memory address. It fails, loudly but with a message that
  blames the MAC.

## Decision

**Three questions, three answers, and the severity decides which.**

### 1. A reference in a string field is refused — k145's and k146's shape half

`File::SOPS::Metadata->from_hash` refuses a list, a map, a code reference or a
blessed object in any of the nine string fields, naming the field and the shape
and quoting what sops says about the same document. The check is the one
ADR 0042 already applies to `mac_only_encrypted` and `shamir_threshold`
(`_is_unconvertible`), extended to the fields that were left out of it — a
`JSON::PP::Boolean` is a scalar to sops and stays one here.

It costs no grammar, it is exactly what sops does in all nine fields, and it is
the only measured row of either ticket where this library did something
**silently wrong** rather than something merely different.

Unmodelled fields keep whatever they hold: sops ignores what it does not know,
and `key_groups` is a list by definition.

**The constructor is not changed**, for ADR 0042's reason: there is no document
there to be faithful to, and what a Perl caller means by
`File::SOPS::Metadata->new(mac => $x)` is a Perl question.

### 2. A non-string scalar is **not** restringified — k146

`unencrypted_suffix: 3` stays the number 3. For every spelling Perl's text and
Go's agree, and the one that differs — a float outside positional range —
**is not reachable from any document either implementation wrote**: sops writes
these fields as quoted strings always, including when it normalises a
hand-written float, and this library writes back the scalar its parser gave it.
The divergence needs a hand-edited document to exist, and the first `sops`
write removes it.

ADR 0038's discriminator asks whether sops reads back what sops wrote. Here it
does, and so do we, and we agree on it. What we would be reproducing is not a
wire behaviour but a repair of somebody's hand-editing — and reproducing it
would mean giving `Metadata.pm` a second opinion about a scalar's text, which
is ADR 0002's territory and this distribution's signature defect.

### 3. `version` is **not** semver-parsed — k145

The fail-loud rule points the other way and is answered on the measurement, not
waved off:

- **We never write a version sops refuses.** `policy_args` deliberately omits
  `version`, so every write path constructs a fresh `Metadata` stamped
  `3.7.3`. A malformed version can be read here; it can never be produced here.
  That makes this purely a read question.
- **Nothing in this distribution reads the field.** It is in no digest, no AAD
  and no decryption decision.
- **A partial check is a worse defect than no check.** `v3.13.3`,
  `3.13.3-rc.1`, `3.13.3+build.5` and `1.a.b` are all documents sops writes,
  reads at exit 0, and preserves verbatim across a `rotate`; refusing them
  would be the class ADR 0038 calls *we are wrong*, in a field whose whole
  purpose is to say which implementation wrote the file.
- **A faithful check is a semver parser plus two sops quirks** — the `v` strip
  and the `1.`-prefix bypass — in a library whose other refusals all protect a
  digest or a secret.

So the divergence is **recorded in the POD**, with the measured table and the
`1.` bypass, rather than implemented. The one row of the table that is not
about semver at all — `version: []` — is refused by decision 1.

**The absent-version divergence is recorded with it.** sops refuses a document
with no `version` key at all; `from_hash` invents `3.7.3`. That default is
older than this measurement and changing it would break every caller that
builds a section by hand, for the same nothing: the field is read by nobody.
It is now named in the POD and pinned in `t/57` as a divergence rather than
sitting in the code unremarked.

## Consequences

- **A document sops opens is unaffected.** Every one of them carries a string
  in these fields, and a string is what passed through before. The metadata
  lane — `t/03`, `t/09`, `t/14`, `t/15`, `t/22`, `t/38`, `t/50`, `t/55` — is
  unchanged and green at 145/145, and with `t/04-interop.t` (32/32,
  **executed** against sops 3.13.3) and the new `t/57` the lane is
  **183/183**. `SOPS_BIN=/tmp/sops prove -lr t/` was green over the whole tree
  at the time of the run, which also carried the k76 lane's work in
  progress.
- **`rotate` can no longer turn a malformed rule into a plaintext file.** For
  the reference half of it. A rule that is a perfectly ordinary string and
  matches nothing still does — `encrypted_regex: "^nothing$"` on a document
  encrypted under another rule writes every value in plaintext here and stops
  `sops rotate` at exit 51, *MAC mismatch*. That is a different defect in a
  different lane, filed rather than folded in.
- **A caller who really wants a reference in one of these fields** has to say
  what text they mean, which is the only thing sops would have stored anyway.
- **Two divergences are now documented instead of undocumented**: the float
  spelling and the whole `version` grammar, both with the measurement that says
  why they are left.

## Rejected alternatives

**Restringify a non-string scalar the way Go does.** The conversion exists
(`Encrypted->value_to_bytes`, `FormatFloat(-1)`) and reusing it would be cheap.
Rejected because the only spelling it changes cannot occur in a document either
implementation wrote, and because it would make `from_hash` a second place with
an opinion about a scalar's text — the thing ADR 0002 exists to prevent — for a
suffix nobody can name.

**Refuse a non-string scalar instead.** It reads as the strict, fail-loud
answer and it is measurably wrong: sops accepts every one of them at exit 0 and
writes the text back. Refusing would put us in ADR 0038's *we are wrong* class.

**Implement the semver check.** See decision 3. Worth restating: this was the
close call, and what decided it was that we never write such a version and that
an approximate parser refuses real sops output.

**Implement half the semver check** — three dot-separated numbers. Refuses
`v3.13.3` and `3.13.3-rc.1`, both of which sops writes and reads. The measured
rows are what rule this out; it would have looked entirely reasonable from the
ticket alone.

**Refuse an absent `version` too.** sops does. Rejected here because it changes
what every hand-built `from_hash({...})` means for a field nothing reads, and
because the default predates this measurement by a long way. Recorded instead.

**Put the shape check in the format handlers.** ADR 0042's answer, unchanged:
`from_hash` is the one place every format's parsed section arrives.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this machine,
on 2026-08-21: 45 `version` spellings, 9 string fields × `[]`/`{}`, 8
`unencrypted_suffix` spellings through a `sops rotate` round trip, plus the
`encrypted_regex: []` and `encrypted_regex: "^nothing$"` rotate probes on both
implementations. All fixtures are invented values; every age keypair was
generated for the run.

`t/57-a-reference-in-a-string-metadata-field-is-refused.t` carries the tables
and asserts them twice: once against `from_hash` (always) and once against the
binary (interop-gated — without one it skips and proves nothing about sops,
which is the honest outcome). Without the change it fails **94 assertions**,
two of them the plaintext-on-disk pair.
