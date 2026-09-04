# ADR 0051 — A rule RE2 cannot compile matches nothing on the read path, and is refused on the write path

- Status: accepted
- Date: 2026-08-22
- Resolves k171 (the read regression), k166 (the refusal reported
  under a leaf path) and k163 (the `rotate` POD) — one decision, because
  all three are the same question about *where* ADR 0048's refusal belongs
- Depends on ADR 0048 (which chose the refusal and put it at the point of
  match) and ADR 0049 (which made the read path ask the rule, and so gave the
  refusal a reach ADR 0048 had explicitly ruled out)
- Uses the discriminator of ADR 0038 — *does sops read back what sops wrote?*
- **Moves no bytes.** Nothing is parsed, emitted or digested differently. What
  changes is which documents are read at all, and where one refusal is raised

## Context

ADR 0048 refuses a rule regex the two dialects do not share, **at the point of
use**, and its §3 is explicit about what that leaves open:

> `Metadata->from_hash` still reads such a rule, so a document carrying one can
> still be decrypted and extracted — neither consults the rule — and the rescue
> path out of a damaged file stays open. `encrypt`, `encrypt_file`,
> `encrypt_in_place`, `rotate` and `edit` stop.

ADR 0049 then made `_decrypt_tree` consult `should_encrypt_path`, because that
is how sops decides what a leaf *is*. The premise of ADR 0048 §3 went with it,
and it took the refusal onto the read path without anybody choosing that. ADR
0049 recorded it as a limit and handed it over rather than deciding it.

Two smaller defects sit in the same two files and turn out to be the same
question:

- **k166.** `encrypt` reaches the rule from inside `_assert_leaves_representable`,
  which wraps the exception with `_at_path`. The refusal therefore arrives
  under whichever leaf the walk reached first — `bar: Cannot use '(?=f)foo' as
  the unencrypted_regex ...` — where `bar` has nothing to do with the rule and
  reads as though the key were at fault.
- **k163.** The `rotate` POD said the RE2 divergence "is open and is karr
  k161". It is not; and by the time this was picked up, commit 085773e had
  already rewritten that whole section for ADR 0049, so the paragraph the
  ticket quotes no longer exists in any form.

## The measurement

sops 3.13.3 at `/tmp/sops`, one age keypair generated for the run.

### The regression, reproduced before anything was changed

One document, two keys, `sops -e --age ... --unencrypted-regex '(?=foo)'`:

| | result |
|---|---|
| `sops -e` | **exit 0**, both values encrypted, rule written into the section verbatim |
| `sops -d` on it | **exit 0**, `foo: topsecret` / `bar: alsosecret` |
| `File::SOPS->decrypt_file` | **refused** — ADR 0048's message, from `SOPS.pm` line 3467 |
| `File::SOPS->extract` | **refused**, same message |

An ordinary sops document, produced by an ordinary sops command line, that this
library read before 085773e and does not read after it. Nothing leaks — it is a
refusal — but it is ADR 0038's discriminator pointing straight at us.

The same in the other direction, `--encrypted-regex '(?=foo)'`: sops writes
**every value in plaintext** at exit 0 under a `sops` section, and reads it back
at exit 0.

### Is "matches nothing" actually what RE2 does — for every construct we refuse?

This is the measurement the decision rests on, and it had to be taken because
the scanner in `_re2_divergent_construct` is **whitelist-shaped**: it says
`unsupported` for anything nobody has measured, which was harmless while
`unsupported` only ever meant "refuse" and is not harmless once it means "sops
matches nothing".

RE2's own verdict was read off the `.sops.yaml` `path_regex` oracle — the one
place sops reports `error parsing regexp` instead of discarding it — for
**every escape letter** and for every `(?...)` form the scanner names:

| | verdict |
|---|---|
| escapes the scanner accepts (`\A \B \D \P \S \W \a \b \d \f \n \p \r \s \t \w \x \z \0`) | RE2 **compiles** all of them |
| escapes the scanner calls `unsupported` (`\C \E \G \H \I \J \K \L \M \N \O \R \T \U \V \X \Y \Z \c \e \g \h \i \j \k \l \m \o \q \u \y`, `\1`, `\8`, `\b` in a class) | RE2 **rejects** all of them |
| `(?=` `(?!` `(?<=` `(?<!` `(?>` `*+` `(?#` `(?\|` `(?R` `(?1` `(?P=` `(?'n'` `(?^` `(?x` `(?a` | RE2 **rejects** all of them |
| `(?i)` `(?P<n>)` `(?<n>)` `(?i-s:)` `\p{L}` `\P{L}` `\x{41}` `\v` `\Qa.b\E` | RE2 **compiles** all of them |

**Every construct the scanner labels `unsupported` is measurably one RE2
refuses, and every construct RE2 accepts passes the scanner.** The label is
accurate, not merely conservative, so treating it as "sops matches nothing"
reproduces sops rather than guessing at it.

### A correction to ADR 0048

ADR 0048 says, of the other direction: *"what RE2 accepts and Perl rejects:
`(?U)`, `\C`, `\g`, `\k`"*. Measured through the same oracle:

| pattern | RE2 |
|---|---|
| `(?U)fo+` | **compiles** |
| `f\Coo` | rejects — `invalid escape sequence: \C` |
| `(f)\g{1}`, `(f)\g1` | rejects — `invalid escape sequence: \g` |
| `(?<n>f)\k<n>`, `(?<n>f)\k'n'` | rejects — `invalid escape sequence: \k` |

`(?U)` is the **only** measured pattern that RE2 compiles and Perl does not.
The other three are rejected by both, which puts them in the lenient half, not
beside `(?U)`. ADR 0048's list is wrong there and is corrected in the POD;
k175 carries the fix to the ADR itself.

(A lone `\E` is also RE2-rejected — `\Q..\E` compiles as a pair. It stays
refused regardless, as a `different` construct.)

### What an over-lenient read would cost, if the scanner ever did grow a hole

Worth measuring because it is what makes leniency affordable at all. If a
pattern RE2 *accepts* were ever classified `unsupported`, the read path would
select the wrong leaves — and in both directions that fails **loudly**:

- `unencrypted_regex`: we select a leaf sops left bare → bare at a selected
  path → the ADR 0049 refusal, naming the path.
- `encrypted_regex`: we exclude a leaf sops encrypted → its `ENC[...]` text
  goes into the digest instead of its plaintext → **MAC verification fails**.

It cannot return a wrong plaintext quietly and it cannot leak. That is a
property of ADR 0049's rule-first read, and it is the safety net under this
change.

## Decision

**The refusal moves off the match and onto the write path, and the read path
answers what sops answers.**

### 1. `should_encrypt_path` has one answer everywhere, and it is sops's

`_rule_qr` no longer croaks for a pattern RE2 cannot compile. It returns a
matcher that **matches nothing**, which is exactly what sops matches with once
it has discarded the compile error. The two rule fields then fall out on their
own, with no special case anywhere above them:

- `unencrypted_regex` matching nothing excludes nothing → every value encrypted;
- `encrypted_regex` matching nothing selects nothing → every value a literal.

Both are what sops wrote for the same flags, measured.

The knowledge is split into `_rule_verdict`, which returns the matcher, the
*kind* of disagreement, and the refusal that goes with it. The two callers take
different halves of that answer, and that is the whole of this ADR.

### 2. Two kinds stay refused wherever the rule is asked

- **`different`** — both dialects compile it and read it apart (`\v`, `\Q`,
  `\E`). There is no single answer to reproduce.
- **`perl`** — RE2 compiles it and we cannot (`(?U)`, and only `(?U)`).

For neither is there a sops answer available to this side, and guessing at one
would classify leaves wrongly. They are refused on the read path too.

### 3. The write path refuses all three, once, before any walk

`Metadata->assert_rule_regexes_agree` is new, public, and raises ADR 0048's
refusal for any of the three kinds. It is called from:

- `File::SOPS::_assert_rules_supported`, which `_metadata_for_encrypt` already
  called — so `encrypt`, `encrypt_file` and `encrypt_in_place` are covered
  where they already build their metadata;
- `rotate` and `edit` directly, next to `_assert_rekeyable`, **ahead of the
  decryption**. Without that the read below would now succeed and the refusal
  would arrive at the bottom — for `edit`, after the editor had opened and the
  user had typed.

That closes k166 as a side effect and not as a patch: the rule is checked
once, where the rule is, so there is no leaf path for the message to be
reported under. The message text is unchanged.

### 4. ADR 0048's decision is intact; only its *reach* is corrected

Refusing to **write** under such a rule is still right, and for ADR 0048's own
reason: a caller who asks for `encrypted_regex => '(?=foo)'` and is silently
given "matches nothing" gets every secret in the document written to disk in
plaintext, at exit 0, under a `sops` section that makes the file look
encrypted. That is k18 and k150's failure mode. Reading a document
that already exists is a different question — nothing is being decided on the
caller's behalf, the document already is what it is — and there the reference
implementation's answer is the correct one.

## Consequences

- **`decrypt`, `decrypt_file` and `extract` read documents they refused since
  085773e**, and every one of them is a document `sops -d` reads at exit 0.
- **`rotate` and `edit` refuse earlier**, before decrypting rather than after.
  Same answer, no editor session lost.
- **The refusal no longer names a leaf.** `encrypt` reports the rule.
- **`should_encrypt_path` and `should_encrypt_key` die less often**, and their
  POD says which cases remain.
- **One predicate, one answer.** ADR 0049 rejected the alternative shape — a
  lenient *mode* on `should_encrypt_path` — for being "a second answer out of
  the one predicate `_encrypt_tree`, `_compute_mac`, `mac_only_encrypted` and
  now `_decrypt_tree` all share". That objection does not apply here: the
  predicate gains no mode and no argument, and all four call sites get the same
  answer. The refusal became a guard of its own instead.
- **`t/62`'s subtest 3 is inverted**, deliberately and by one line: it asked
  `should_encrypt_path` to raise the refusal and now asks
  `assert_rule_regexes_agree`. Every row, the wording and the two other kinds
  are untouched — what moved is which call raises it.

## Limits

- **A pattern neither dialect can compile is still refused on the read path.**
  `fo(` is the measured one: RE2 rejects it (`missing closing )`), so sops
  matches nothing and reads the document at exit 0; here it passes the
  construct scan, reaches the Perl compile, and is refused there. Nothing
  available to this side tells it apart from `(?U)fo+`, which RE2 *does*
  compile and which must not be guessed at. Recording it rather than closing
  it: an unbalanced-paren check would be a second, narrower regex parser whose
  false positives would refuse rules sops takes. k176.
- **The three disagreements ADR 0048 lists as limits are untouched** — full
  case folding of U+00DF, `$` before a trailing newline, and `\p{NAME}` with a
  name Go does not have.
- **The scan is still whitelist-shaped**, so a construct a future RE2 gains
  would be read here as "matches nothing" while sops matched with it. The
  measurement above closes that for every construct that exists in 3.13.3, and
  §"What an over-lenient read would cost" is why the residue fails loudly.

## Rejected alternatives

**A lenient mode on `should_encrypt_path` for the read path only** — karr
k171's option (a), and ADR 0049's. It works, and it puts a second answer inside
the one predicate four call sites share, on the most load-bearing change in
this layer. Moving the refusal out instead leaves the predicate with one answer
and costs a method.

**Leave the refusal at the point of match and accept the read regression.**
It is the status quo, it leaks nothing, and it fails ADR 0038's discriminator
on a document an ordinary `sops -e --unencrypted-regex` writes without a word.

**Reproduce sops on the write path as well**, so nothing is ever refused.
ADR 0048 rejected this and the reason has not moved: it writes every secret in
the document to disk in plaintext at exit 0.

**Translate the divergent patterns instead of refusing them** — `\v` to
`\x0B`, `\Q..\E` to a quoted run. It would close the `different` kind exactly
rather than refusing it. Out of proportion to a rule nobody has been seen to
write, and it is a rewriting of the caller's pattern that `to_hash` would then
have to undo before writing it back into the document.

**Validate in `BUILD` or `from_hash`.** Rejected here for the reason ADR 0048
rejected it: it would refuse to *read* a document carrying such a rule, which
is the whole defect this ADR exists to remove. It is also what k166
explicitly ruled out.

## Notes

Measured against sops 3.13.3 (`/tmp/sops`) with `Crypt::Age` on this machine,
on 2026-08-22: the `(?=foo)` document through `sops -e`, `sops -d`,
`decrypt_file` and `extract` before any change; both rule fields through
`sops -e`/`sops -d`; 55 escape letters and 19 `(?...)` forms through the
`.sops.yaml` `path_regex` compile oracle; `(?U)`, `\C`, `\g{1}`, `\g1`,
`\k<n>`, `\k'n'`, `\Qa.b\E`, lone `\Q`, lone `\E` and `fo(` through the same
oracle in their realistic spellings. All fixtures are invented values; the age
keypair was generated for the run.

`t/66-a-rule-re2-cannot-compile-is-read-the-way-sops-reads-it.t` fails **27
assertions** in 6 of its 11 subtests against the tree before this change, with
the interop section executed against the binary rather than skipped.
