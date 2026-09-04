# ADR 0048 — A rule regex is matched in RE2's dialect, or not at all

- Status: accepted
- Date: 2026-08-21
- Resolves k161, which ADR 0046 filed rather than folded in
- Depends on ADR 0003 (the UTF-8 flag is not read anywhere in this
  distribution — here the regex engine was reading it for us) and on ADR 0007
  (the `.sops.yaml` search, which is why the end-to-end measurement below runs
  sops from the config's directory)
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*

## Context

`unencrypted_regex` and `encrypted_regex` are matched in
`Metadata::should_encrypt_path` (and in `should_encrypt_key`, which nothing in
the tree walk uses) with Perl, and in sops with Go's RE2. Those are not the
same dialect, and the disagreement decides **which keys get encrypted**.

k161 was opened out of the k150 measurement as the *reachability*
half of that defect: the way an ordinary `.sops.yaml` gets a document into the
state ADR 0046's guard refuses. The first thing measured here was whether it is
only that.

**It is not.** The divergence is on the **write** path, before any rotation:

```perl
File::SOPS->encrypt_file(
    input => $f, output => $o,
    recipients => [ $age ],
    unencrypted_regex => '^\w+$',
);
```

with one key `café` produces a document whose value is **readable**, where
`sops -e --unencrypted-regex '^\w+$'` on the same input **encrypts** it.
Nothing is rotated, nothing is hand-edited, and no guard fires — the caller
asked for a rule, was given a different one, and got a plaintext secret in a
file that looks like a sops file. That makes this a defect of its own and not
the reachability half of another one.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age recipient. Two harnesses.

**One key, one value, both sides.** 43 (rule field, pattern, key) rows: the
plaintext document written once, then `sops -e -i` with the matching
`--unencrypted-regex` / `--encrypted-regex` flag, and `File::SOPS->encrypt_file`
with the matching named argument. Whether the leaf came out encrypted is read
off the document. **29 of the 43 rows disagreed**, 22 of them leaving readable
a secret sops encrypts:

| pattern | key | sops | this library (0.002) |
|---|---|---|---|
| `^\w+$` | `café` | encrypts | **bare** |
| `^\w+$` | `密` | encrypts | **bare** |
| `^\w$` | `é` | encrypts | **bare** |
| `^n\d$` | `n٣` | encrypts | **bare** |
| `^\d+$` | `٣٤` | encrypts | **bare** |
| `^a\sb$` | `a<NBSP>b` | encrypts | **bare** |
| `^\s$` | `<NBSP>` | encrypts | **bare** |
| `\Bfoo$` | `éfoo` | encrypts | **bare** |
| `^[[:alpha:]]+$`, `[[:alnum:]]`, `[[:digit:]]`, `[[:space:]]`, `[[:upper:]]`, `[[:lower:]]`, `[[:punct:]]`, `[[:word:]]`, `[[:graph:]]`, `[[:print:]]`, `[[:blank:]]`, `[[:xdigit:]]` | a matching non-ASCII key | encrypts | **bare** (12 rows) |
| `(?i)^ss$` | `ß` | encrypts | **bare** |
| `encrypted_regex: ^\D+$` | `n٣` | encrypts | **bare** |
| `^\W$` | `é` | bare | **encrypts** |
| `^\D+$`, `^\S$`, `\bfoo$`, `[[:^alpha:]]` | the matching key | bare | **encrypts** (4 rows) |
| `encrypted_regex: ^\w+$`, `^[[:alpha:]]+$` | `café` | bare | **encrypts** (2 rows) |
| `^\w+$` | `plain` | bare | bare |
| `^\p{L}+$`, `^.$`, `^[^a]$`, `(?i)^k$`, `(?i)^s$` | non-ASCII keys | agree | agree |

Every disagreement is a class whose meaning depends on Unicode. RE2's `\w`,
`\W`, `\d`, `\D`, `\s`, `\S`, `\b`, `\B` and its POSIX classes reach ASCII and
nothing else, for every subject. Perl's are Unicode-aware for any string
carrying the UTF-8 flag — which is every non-ASCII key `YAML::XS` and
`Cpanel::JSON::XS` produce (verified: all four probe keys came back flagged).
`\p{...}` and `.` are Unicode on both sides and agreed on every row.

**The flag is the second half of the trap.** Perl's default `/d` semantics read
the subject's internal representation, so the *same key* decided differently
depending on where the string came from: `"caf\x{e9}"` out of a Perl literal is
latin-1 storage and matched `^\w+$` ASCII-only, and the same key out of
`YAML::XS` carries the flag and matched Unicode-aware. Reading that flag is
what ADR 0003 forbids everywhere else in this distribution; here the regex
engine was doing it on our behalf.

**End to end, with nothing hand-edited.** One `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: \.yaml$
    age: age1...
    unencrypted_regex: '^\w+$'
```

`sops -e` encrypts `école` and leaves `plain` readable. `creation_rules_for`
returns `unencrypted_regex => '^\w+$'` unchanged, and `encrypt_in_place` under
it wrote `école: hunter2` — and `sops -d` answered **exit 25** on the file we
produced. That is the whole ticket in one run.

### What RE2 will not compile — and what sops does with it

sops does **not** report a pattern RE2 cannot compile. It matches with the
compile error discarded, so the rule silently matches nothing. Measured, exit 0
in every case:

| flag | pattern | what sops wrote |
|---|---|---|
| `--encrypted-regex` | `(?=f)foo` | **every value in plaintext**, under a `sops` section |
| `--encrypted-regex` | `fo(` | the same |
| `--encrypted-regex` | `(?>foo)` | the same |
| `--unencrypted-regex` | `(?=f)foo` | every value encrypted |

The one place sops *does* report it is a `.sops.yaml` `path_regex`, which
fails with `error parsing regexp: invalid or unsupported Perl syntax: `(?=``
at exit 1. That path was used as an **oracle**: 137 patterns were put through
it to read RE2's own compile verdict rather than infer it. What it says RE2
rejects, and Perl accepts:

- lookahead `(?=`, `(?!`; lookbehind `(?<=`, `(?<!`
- backreferences `\1`..`\9` and `(?P=name)`
- atomic groups `(?>`; possessive quantifiers `*+`, `++`, `?+`, `{n,m}+`
- the escapes `\Z \K \G \R \h \H \V \N \X \c \e \o \u \l \U \L`, `\g`, `\k`,
  and `\b` **inside a character class** (where it is BACKSPACE, not a
  boundary)
- `(?#comment)`, `(?|branch reset)`, `(?{code})`, `(?R)`, `(?1)`, `(?&n)`,
  `(?'name'...)`, `(?^flags)`
- the flags RE2 has no letter for: `x`, `a`, `d`, `l`, `u`, `n`, `p`

The escape `\C` is refused by RE2 and refused by Perl (`\C no longer
supported in regex`), so it is not a divergence and belongs in the default
"both refuse" class rather than in either list.

and, in the other direction, what RE2 accepts and **Perl** rejects: `(?U)`
alone. Both dialects take `\w \d \s \b \A \z`, `\p{...}`, `\pL`,
`\P{...}`, `[[:alpha:]]`, `[[:^alpha:]]`, `(?i) (?m) (?s)`, `(?i-s:...)`,
`(?P<name>)`, `(?<name>)`, the lazy quantifiers, `\0`-octal, `\x{}` and every
punctuation escape.

Two more take a pattern on both sides and **read it differently**, which no
whitelist of names would have caught:

- `\v` is the vertical TAB to Go and the vertical-whitespace *class* to Perl.
- `\Q`/`\E` quote a literal run for RE2, and are `\Q`/`\E`-processed by Perl
  only when a pattern is written out in *source*. A pattern arriving in a
  variable — which is every pattern here — keeps them as the letters `Q` and
  `E`. Measured: `\Qa.b\E` selects the key `a.b` at sops and the key `Qa.bE`
  here.

## Decision

**The two rule patterns are compiled `/a`, and a pattern the two dialects do
not agree on is refused rather than matched.**

### 1. `/a`, which is RE2's answer for the classes

`Metadata::_rule_qr` compiles both patterns inside a `use re '/a'` block. That
is one lexical pragma over two match sites; the stored pattern is untouched, so
what `to_hash` writes back into the document is what the document said.
Injecting `(?a)` into the pattern text was rejected: `(?a)` is itself one of
the flags RE2 rejects (measured), so it would have to be stripped again before
anything could read it.

It is `/a` and **not** `/aa`, and the measurement decides that: RE2's `(?i)`
*is* Unicode-aware — Go folds `k` to U+212A KELVIN SIGN and `s` to U+017F LONG
S, both of which `/a` keeps and `/aa` would break. `/aa` would have fixed one
row (`ß`) and broken two.

**After the change, 42 of the 43 rows agree**; the one that does not is the
`ß` row, below.

### 2. A pattern RE2 cannot compile is refused

`_re2_divergent_construct` scans the pattern — escape-aware, character-class
aware — and names the first construct the two dialects do not share.
`_rule_qr` croaks with it, quoting the pattern, naming the construct, and
saying what sops does instead.

This is a **deliberate divergence** and not a reproduction. sops's own answer
is reproducible: treat such a rule as matching nothing. It was rejected because
the `encrypted_regex` half of that answer is *this library writing every secret
in the document to disk in plaintext, at exit 0*, which is k18 and
k150's failure mode with a new cause. Where we cannot do what was asked,
this layer fails loudly rather than approximately — and the caller can always
rewrite the pattern.

The scan is **whitelist-shaped**: an escape or `(?...)` form nobody has
measured is refused rather than assumed harmless, because the harm runs one
way. It is escape-aware (`a\\Zb` is a literal backslash then `Z`, and RE2 takes
it — measured) and class-aware (`[*+]`, `[(?=)]`, `[\\]Z`, `[^]]x` and
`foo[]]bar` are all RE2-ok and all pass). 32 patterns both dialects have are
pinned as *taken*, so a guard that grew a false positive fails a test.

A pattern **Perl** cannot compile is refused with its reason, which is the same
question from the other side: `(?U)fo+` is a rule sops takes and this side
cannot match with. Before this it died out of the middle of a tree walk with a
bare `Sequence (?U...) not recognized in regex`.

### 3. Where the refusal is raised

At the point of **use**, not at parse. `Metadata->from_hash` still reads such a
rule, so a document carrying one can still be `decrypt`ed and `extract`ed —
neither consults the rule — and the rescue path out of a damaged file stays
open. `encrypt`, `encrypt_file`, `encrypt_in_place`, `rotate` and `edit` stop.

## Consequences

- **Which keys get encrypted changes**, for a regex rule and a non-ASCII key.
  It changes towards what sops does, in both directions: a key sops encrypts
  is now encrypted here (22 measured rows, each of them a secret that used to
  be written readable), and a key sops leaves readable is now left readable
  (7 rows).
- **The ordinary case does not move.** Measured over the 15_960 decisions this
  distribution's own test suite makes — its 11 rule patterns against its 653
  keys, both fields — **18 changed**, all of them a non-ASCII key under
  `^\w+$`, and **not one an ASCII key**.
- **The answer no longer depends on the UTF-8 flag**, which brings the rule
  match under ADR 0003 with everything else.
- **One subtest of `t/60` is inverted, deliberately.** Its interop half pinned
  `rotate` *refusing* the `café` document — correct while the classification
  was wrong, because the rule excluded a leaf the file had encrypted. The
  premise is gone: the rule and the file now agree, so rotation goes through
  and the value stays encrypted. What it pins now is that, plus `sops -d`
  reading what we rotated. ADR 0046's guard and the other 49 assertions are
  untouched — those documents carry rules that exclude an encrypted leaf in
  either dialect.
- **`use re '/a'` needs perl 5.014**, and `cpanfile` says `requires 'perl',
  '5.010'`. That line has to move with this change; it is outside this lane's
  files and is handed over rather than edited.
- `lib/File/SOPS.pm`'s POD for `rotate` still says this divergence "is open and
  is k161". It is not, and that paragraph needs the update; `SOPS.pm` was
  being changed by another lane and is not touched here.
- `File::SOPS::_re2_incompatible_construct` (for `.sops.yaml` `path_regex`,
  k53) is the narrow ancestor of this scan — lookarounds and `\1` only.
  It should become one mechanism with `_re2_divergent_construct`, in `SOPS.pm`,
  which is likewise not this change's file.

## Limits

Three disagreements survive, all measured, none of them reachable by `/a` or by
a construct check:

- **Full case folding.** Perl's `(?i)` folds U+00DF to `ss` and RE2's does not,
  so `unencrypted_regex: '(?i)^ss$'` leaves a key `ß` readable here and sops
  encrypts it. Perl has no simple-fold-only flag: `/aa` suppresses it, and
  suppresses the k/KELVIN and s/LONG-S folds that RE2 *does* perform along
  with it.
- **`$` before a trailing newline.** Perl's `$` is `(?=\n?\z)` and RE2's is
  `\z`, so `^foo$` matches a key `"foo\n"` here and not there — measured, sops
  encrypts that key and we leave it bare. It is not refused, because `^foo$` is
  a pattern sops takes and reads: by ADR 0038's discriminator, refusing a rule
  sops reads back is the wrong answer. `\z` is in both dialects and says what
  RE2's `$` says.
- **`\p{NAME}` with a name Go does not have.** `\p{Word}`, `\p{Alpha}`,
  `\p{IsAlpha}`, `\p{XPosixAlpha}` are RE2 compile errors (measured) and so
  match nothing at sops, while `\p{Greek}` and `\p{Lu}` are accepted by both.
  Refusing every `\p{...}` longer than a general-category code would refuse
  `\p{Greek}`, which sops takes; accepting it leaves the Perl-only names
  divergent. Reproducing Go's script table on this side is the only exact fix
  and is out of proportion to a rule nobody has been seen to write.

## Rejected alternatives

**Reproduce sops, including the discarded compile error.** Exactly compatible,
and it means `encrypted_regex: '(?=foo)'` writes every value of the document to
disk in plaintext at exit 0 — this distribution's signature defect, on purpose.
The line that decides it is the one this layer already had to learn twice
(k18, k150): where we cannot do what was asked, fail loudly rather
than approximately.

**Refuse only, and not fix the classes.** It would refuse `\w`, `\d`, `\s` and
every POSIX class — the patterns sops's own documentation uses — and close
none of the 29 measured rows.

**Fix the classes only, and let RE2-unsupported constructs through.** It closes
26 of the 29 rows and leaves the two directions of the compile-error case
silent, one of which is a secret written readable.

**`/aa` instead of `/a`.** Measured: it fixes the `ß` row and breaks the
KELVIN SIGN and LONG S rows, which agree today. One for two, in the direction
of a secret left bare.

**Validate the rule in `BUILD`, or in `from_hash`.** Earlier, and a better
message — and it would refuse to *read* a document carrying such a rule, which
closes the `decrypt`/`extract` rescue path for exactly the documents most
likely to need it.

**Refuse a key containing a newline while a `$`-anchored rule is set.** The
only exact answer available for the anchor row, and ADR 0038's discriminator
forbids it: sops writes and reads that document at exit 0.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this machine,
on 2026-08-21: 43 (field, pattern, key) rows through `sops -e` and
`File::SOPS->encrypt_file`, before and after; 137 patterns through the
`.sops.yaml` `path_regex` compile oracle; one end-to-end `.sops.yaml` run in
both implementations with `sops -d` reading both results; 15_960 rule decisions
from the test suite's own patterns and keys, diffed across the change. All
fixtures are invented values; the age keypair was generated for the run.

`SOPS_BIN=/tmp/sops prove -lr t/` is green over the whole tree at 63 files and
1282 tests, with `t/04-interop.t` **executed** against sops 3.13.3 (32/32)
rather than skipped.
`t/62-rule-regexes-are-matched-in-re2s-dialect.t` fails **189 assertions** in 5
of its 9 subtests against the tree before this change.
