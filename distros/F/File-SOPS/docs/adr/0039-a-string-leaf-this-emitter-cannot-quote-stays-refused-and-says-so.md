# ADR 0039 — A string leaf this emitter cannot quote stays refused, and the refusal says so

- Status: **accepted** — decided and implemented together, in this commit. Every
  table below was measured here against sops 3.13.3 at `/tmp/sops`; the two
  candidate mechanisms were probed in a scratch copy before anything in the
  repository changed.
- Date: 2026-08-21
- Tags: yaml, emitter, wire-format, guards, interop, diagnostics
- Answers k135, which ADR 0038 handed to the wire lane. Leaves the refusal
  in place and corrects the message it is delivered with; adds the two measured
  preconditions to k99 and k127 rather than widening either here
- Depends on ADR 0013 and ADR 0017 (the foreign-resolution guard and the token
  it answers from), ADR 0008 (a leaf the emitter cannot write as the text the
  digest covers is refused), ADR 0038 (the measurement this starts from),
  ADR 0026 and ADR 0034 (the parse-side resolution that makes seven of the
  twenty-two rows unambiguous, and is the only reason they are), ADR 0019
  (which rejected write-path text surgery and filed k99 for it), ADR 0028
  (which allowed read-path text surgery, under conditions this case does not
  meet) and ADR 0032 (a loud refusal is not traded for a silent divergence)
- Moves **no wire byte**: no document that is written today is written
  differently, and no document that is refused today is written

## Context

ADR 0038 measured 50 scalars in three slot configurations and found one class
where this library is simply wrong: **22 spellings that sops writes, sops reads
back at exit 0, and `File::SOPS->encrypt_file` refuses to produce.** Each is a
leaf that is a **string** on both sides — quoted in the plaintext, so both
implementations agree about its type — and each is refused by ADR 0013's
foreign-resolution guard, because `YAML::XS` writes the string as a **bare**
token and Go's yaml.v3 resolves that token into a number, a null, a boolean or
a time.

The 22 are `".inf" ".Inf" ".INF" "+.inf" "-.inf" ".nan" ".NaN"`, `"1_000" "0_7"
"685_230.15"`, `"2015-01-01" "2015-1-2" "2015-01-01t12:00:00Z"
"2015-01-01 12:00:00"`, `"0o10" "0O10" "0x1f" "0b101"`, and `"Null" "NULL"
"TRUE" "FALSE"`.

**A 23rd row was found here**, in the same class and by the same mechanism:
`"0xffffffffffffffff"`. sops writes it double-quoted and reads it back at exit
0; the guard refuses it because `_go_scalar_bytes` cannot model a `uint64` and
refuses what it cannot decide (ADR 0013). Its neighbour `"9223372036854775808"`
is written here, because `looks_like_number` is true for it and `YAML::XS`
quotes it for us. The row is recorded on k135 rather than changing
anything: it is the same defect and the same answer.

The refusal is wrong. The question this ADR answers is what to do about it
**today**, with the emitter and the parser this distribution actually has.

## What was measured

### 1. The read direction already works — the defect is write-only

22 spellings × one document each, `sops -e` from a **quoted** plaintext with the
leaf in both slots (`v` encrypted, `v_unencrypted` not), handed to
`File::SOPS->decrypt`: **22 of 22 read back with the MAC verified and the string
intact in both slots.** Nothing has to be taught to *read* these documents. What
is missing is the ability to *write* one.

### 2. There is no per-scalar quoting in this emitter, by any route

Three routes were probed, because a fix that does not need text surgery would
end the question:

**A global option that quotes wider.** `$YAML::XS::QuoteNumericStrings` set to
0, 1, 2 and 3 over 19 spellings: it is a **boolean** — 1, 2 and 3 are
byte-identical — and what it quotes is exactly what Perl's `looks_like_number`
accepts (`0755`, `007`, `1e3`, and also `Inf`, `Infinity`, `NaN`, `nan`), plus
lower-case `true`, `false`, `null`, `~` and the empty string. `.inf`, `TRUE`,
`Null`, `1_000`, `0x1f` and every date stay bare at every setting. There is no
other knob in the module: `Boolean`, `LoadBlessed`, `LoadCode`, `UseCode`,
`DumpCode`, `Indent`, `ForbidDuplicateKeys` and `QuoteNumericStrings` are the
whole surface.

**A carrier, the ADR 0037 route.** This is the route the handover named as the
most promising, and it is the one this decision spent the most on. It is dead,
and it is dead in the worse direction. Six SV shapes × 9 spellings through
`Dump`:

| leaf | `".inf"` | `"TRUE"` | `"1_000"` | `"0755"` |
|---|---|---|---|---|
| a plain string | `.inf` | `TRUE` | `1_000` | **`'0755'`** |
| `dualvar(0, T)` | `.inf` | `TRUE` | `1_000` | **`0755`** |
| `dualvar(1, T)` / `dualvar(1.5, T)` | `.inf` | `TRUE` | `1_000` | **`0755`** |
| a string with a numeric cache | `.inf` | `TRUE` | `1_000` | **`0755`** |
| the same string UTF-8-upgraded | `.inf` | `TRUE` | `1_000` | `'0755'` |

No shape makes `YAML::XS` quote anything it would not quote anyway — and the
`0755` column is the finding: **a dualvar carrier makes the quoting worse.**
Because the emitter's rule reads the SV, a numeric half turns the one spelling
it quotes for us today into a bare token. ADR 0037's carrier works for a
non-finite float because the target form there is a **plain** token (`.inf`);
here the target form is the one thing a carrier cannot produce.

**Replacing the leaf inside the existing walk.** `reject_scalar` is called from
`Encrypted::_written_leaf`, whose return value is `$leaf` — the callback's
answer is discarded, by construction. A replacement would need either an edit to
`canonical_float_tree`'s contract (another lane's file, and k122 is in it)
or a **second full tree walk** inside `emit`.

So the only way to get a quoted scalar out of this emitter is to rewrite the
text after `Dump`, exactly as `_quote_sops_timestamp` does for `lastmodified`
and exactly as ADR 0019 refused to do for arbitrary leaves.

### 3. The obvious fix is wrong, and the measurement says by how much

"Quote every `str` leaf the guard refuses" cannot tell two different documents
apart. Measured, one document per row, `File::SOPS::Format::YAML->parse` of a
**bare** and a **quoted** source, compared by `detect_type` and `value_to_bytes`:

| family | rows | bare source parses as | quoted source parses as | distinguishable? |
|---|---|---|---|---|
| `.inf .Inf .INF +.inf -.inf .nan .NaN` | **7** | `float` `+Inf` / `-Inf` / `NaN` | `str`, the token | **yes** |
| `1_000 0_7 685_230.15` | 3 | `str`, the token | `str`, the token | no |
| `2015-01-01 2015-1-2 2015-01-01t12:00:00Z 2015-01-01 12:00:00` | **4** | `str`, the token | `str`, the token | no |
| `0o10 0O10 0x1f 0b101` | 4 | `str`, the token | `str`, the token | no |
| `Null NULL TRUE FALSE` | 4 | `str`, the token | `str`, the token | no |

**15 of the 22 arrive as the identical Perl string from a bare source and from a
quoted one**, and the two sources are two different documents to sops. Measured,
44 `sops -e` runs, the same 22 spellings bare and quoted, leaf under
`v_unencrypted`, all 44 at exit 0:

| plaintext | what `sops -e` writes |
|---|---|
| `v_unencrypted: 1_000` | `v_unencrypted: 1000` |
| `v_unencrypted: "1_000"` | `v_unencrypted: "1_000"` |
| `v_unencrypted: 0x1f` | `v_unencrypted: 31` |
| `v_unencrypted: Null` | `v_unencrypted: null` |
| `v_unencrypted: TRUE` | `v_unencrypted: true` |
| `v_unencrypted: 2015-01-01` | `v_unencrypted: 2015-01-01T00:00:00Z` |
| `v_unencrypted: "2015-01-01"` | `v_unencrypted: "2015-01-01"` |
| `v_unencrypted: .inf` | `v_unencrypted: .inf` |
| `v_unencrypted: ".inf"` | `v_unencrypted: ".inf"` |

So quoting a leaf whose source was bare writes a **string** where sops writes a
resolved number, null, boolean or RFC3339 time — turning today's loud refusal
into a silent divergence, which is the direction ADR 0032 refused for `!!bool
True` and the direction ADR 0038 refused for k128's unencrypted half.
The date family is **4** of the 22 rows; the trap it is named for covers **15**.

**Why exactly seven rows escape it, and it is not luck.** ADR 0026 and ADR 0034
already resolve a *plain* non-finite token the way go-yaml does, on every parse:
a bare `.inf` comes back as a float carrying the document's own token, so the
**string** `.inf` can only have come from a quoted scalar or from a caller's own
Perl string. That is k127's fix — a plain scalar resolved as Go resolves it
— already implemented for one token family. The seven unambiguous rows are
exactly that family, which is the measurement's way of saying that the general
answer to k135 is k127.

### 4. Both remedies the message recommends really work

22 spellings, one document each: the leaf in an **encrypted** slot —
**22 of 22** `sops -d` exit 0 with the string intact — and the same 22 in
**JSON**, both slots at once — **22 of 22** `sops -d --output-type json` exit 0
with the string intact. The advice in the refusal is measured, not offered.

### 5. The message is wrong for a string leaf

Measured against the binary and against the code: the refusal ends with

> sops itself resolves such a spelling when it writes: a plaintext `mode: 0755`
> becomes the integer 493 in its output, and that decimal is what to pass here.

which is **true for an `int` leaf** (ADR 0038 re-verified it) and **false for
these**. Given the string, sops resolves nothing: it writes it double-quoted and
reads it back. And the advice is unusable — there is no other spelling of a
string that this emitter writes quoted, so "what to pass here" has no answer.
The `mac_only_encrypted` warning carries the same sentence and the same defect.

## Decision

**The refusal stands. The message stops claiming, for a leaf that is already a
string, that sops would resolve its spelling away — and says instead what is
true of it: sops writes such a string quoted, this emitter cannot, and here are
the two things that do work.**

Concretely, in `File::SOPS::Format::YAML`, and nowhere else:

- `_reject_foreign_resolution` and `_warn_foreign_resolution` keep their common
  head — the key path, the reason from `_foreign_resolution_reason`, the two
  resolvers, and what the document would do (`sops -d` exit 51 for the refusal,
  "nothing will fail" for the warning). The **tail** is chosen by
  `File::SOPS::Encrypted->detect_type($leaf)`: the existing `0755` → 493
  sentence for a numeric leaf, and a new one for a `str` leaf.
- The verdict, the guard, its model of Go and every byte it writes are
  untouched. `detect_type` is the ladder the digest already goes through — not
  a second opinion about what the leaf is, and not a text pattern.

**The guard is not loosened**, and ADR 0008 is why: the emitter cannot write
this leaf as the text the digest covers, so the leaf is refused *until the
emitter can*. Loosening it would write a document that fails its own MAC —
measured, `sops -d` exit 51 — which is worse than the refusal in every direction.

**What k135 actually needs is two changes, and neither belongs to this
ticket:**

1. **k99 — an emitter that can quote one scalar.** ADR 0019 filed it
   explicitly "for the maintainer to decide against a real emitter rather than
   in passing", and that is still the right place for it. With it, and nothing
   else, **7 of the 22 rows** become writable today.
2. **k127 — a plain scalar resolved the way Go resolves it, at parse.**
   With both, all 22 become writable, because the bare/quoted ambiguity that
   blocks the other 15 disappears at the parse, where the information still
   exists.

This ADR states that decomposition with the numbers behind it, so the next lane
to pick k135 up does not have to re-measure it.

## Consequences

- **No document moves.** No leaf that was written is refused, no leaf that was
  refused is written, no emitted byte and no digest byte changes. The only
  difference a caller can observe is the text of an error and of a warning.
- **A caller who hits this now gets advice that works.** Before: a decimal to
  pass, for a leaf that has no decimal. After: encrypt the leaf, or write the
  document as JSON — both measured 22 of 22 above.
- **The 22 spellings still cannot be written**, and that is a defect this ADR
  records rather than removes. It is pinned by
  `t/53-a-string-leaf-sops-quotes-is-refused-and-says-why.t` in the shape
  ADR 0037 used for k134: the rows are asserted as refused *today* and
  named with their ticket, so the fix flips them visibly instead of quietly.
- The refusal still never names the value: the string tail contains no example
  spelling at all, which is stronger than the numeric one (`0755`, deliberately
  named because it is the ticket case).
- **The counter-check.** `t/53` run against the unpatched `lib/` with `perl -I`
  and no `use lib` in the file: **3 of its 10 subtests and 54 assertions fail**,
  and the other 7 subtests are the must-not-move sections — the int leaf's
  message, the 22 refusals, `"0755"` still written, what sops does with the same
  plaintext, the bare/quoted split, both remedies, and the emitter's quoting
  rule.
- `SOPS_BIN=/tmp/sops prove -lv t/04-interop.t` is **32/32, executed rather than
  skipped**, against sops 3.13.3 — unchanged, as nothing on the wire moved.
  `prove -lr t/` was 1172/1172 over 53 files before this session; at the time of
  writing the tree also carries k122's in-flight work in `Encrypted.pm` and
  `File::SOPS.pm`, and 8 subtests in four non-finite-float files fail because of
  it. Verified independent of this change: the same four files fail identically
  with this ADR's `Format/YAML.pm` and with the pre-change copy of it.

### What changes for existing callers

| input | before | after |
|---|---|---|
| a `str` leaf whose spelling Go resolves differently, in a MAC-covered YAML document | croak, ending "a plaintext `mode: 0755` becomes the integer 493 … that decimal is what to pass here" | croak, ending with what sops does with a **string** and the two remedies that work |
| the same leaf under `mac_only_encrypted` | carp, ending "Pass the value sops itself would write (the decimal for `0755` is 493)" | carp, ending with the same two remedies |
| an `int` or `float` leaf, either mode (`0755`, `010`) | as it was | **unchanged**, word for word |
| everything else | — | **unchanged** |

## Alternatives rejected

**Quote every `str` leaf the guard refuses.** The literal reading of k135,
and the measurement in §3 is what refuses it: 15 of the 22 rows arrive
identically from a bare source, where sops writes a resolved value and we would
write a quoted string. It trades a loud refusal for a silent divergence in the
majority of the class it fixes.

**Quote only the seven unambiguous rows, with sentinel text surgery.** This was
worked out far enough to cost it, because it is the only thing that could have
shipped today: substitute a random 128-bit sentinel for the leaf before `Dump`,
replace the sentinel token in the finished text with a double-quoted scalar, and
verify by counting the sentinel's occurrences and re-`Load`ing the document to
compare the leaf at its recorded key path. That safeguard is genuinely stronger
than ADR 0028's count check — it verifies the finished bytes rather than the
substitution. It is still rejected, on three measured grounds:

- **The ratio is the worst available.** It buys 7 of 23 measured rows — and the
  7 are a string that spells an infinity, the rarest of the families. The rows
  a real configuration file has (`"2015-01-01"`, `"1_000"`, `"0x1f"`) are
  exactly the 15 it cannot touch.
- **It is a new mechanism on the write path**, and ADR 0019 rejected write-path
  surgery for this very case with an argument this proposal does not answer:
  a mis-hit writes a corrupt file that everyone downstream accepts. ADR 0028's
  surgery is allowed because it is one fixed token, in one lexical position, on
  the **read** path, on a document that has already failed to parse. This one is
  arbitrary values at arbitrary nesting on the **write** path, on every document.
- **It pre-empts k99 in passing**, which is the one thing ADR 0019 asked
  the next lane not to do. A real emitter answers all 23 rows and this answers 7.

**Loosen the guard for `str` leaves.** It writes the bare token into a
MAC-covered document: measured by ADR 0013, `sops -d` exit 51 for every one of
these spellings. ADR 0008's rule is the one that applies — refuse while the
emitter cannot write what the digest covers — and the fix is to make the emitter
able, not to stop checking.

**Warn instead of refusing, as ADR 0018 and ADR 0019 do.** Those two warn about
documents that **work** — the MAC holds and sops reads them. Here the document
fails its own MAC, so a warning would hand the caller a broken file with a note
attached.

**Say nothing and leave the message as it is.** It is the cheapest option and it
is what k135 explicitly refuses: the sentence sends a caller looking for a
decimal that does not exist, and it says sops resolves a spelling that, for this
leaf, sops keeps.

**Fix k127 here so all 22 become unambiguous.** It is the real answer and
it is a different decision: resolving a plain scalar the way Go does changes the
**value**, the ciphertext and the digest of every document that contains one.
It needs its own corpus and its own ADR, and ADR 0038 already narrowed the
ticket to the half that has to be argued.
