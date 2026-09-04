# ADR 0001 — MAC key order comes from an order-preserving reparse, not from scraping the raw text

- Status: accepted
- Date: 2026-08-09
- Tags: mac, interop, wire-format, dependencies

## Context

The SOPS MAC is a SHA-512 over the document's values, and it is **order
dependent**: the digest is built by walking the document and feeding each value
into the hash in the order the document presents them. Perl hash iteration order
is randomized, so a decrypting implementation cannot recover that order from a
parsed tree — it has to get it from the document itself.

The original implementation solved this by scraping the raw file text with a
regex for `ENC[...]` strings, in match order, and mapping each back to its path.
That works exactly as long as *every value that goes into the MAC is encrypted*,
because only encrypted values leave a recognisable `ENC[...]` marker in the text.

That premise turned out to be false. The Go reference includes **unencrypted**
values in the MAC on both sides unless `mac_only_encrypted` is set
(`sops.go:537-546`, `:628-638`). File::SOPS hashed them when encrypting and
skipped them when decrypting, so with the default `unencrypted_suffix` of
`_unencrypted` — no configuration required — it rejected its own output and
could not read any sops file containing such a key. Fixing that means placing
unencrypted values in document order, and an `ENC[...]` scrape structurally
cannot see them.

Three options were on the table:

1. **Extend the scrape** to also recognise plain values. This means writing a
   YAML/JSON tokenizer out of regexes — the exact class of code that produced
   the `mac:`/`hmac:` collision, where an unanchored pattern silently dropped a
   user's value from the digest.
2. **Replace YAML::XS with an order-preserving emitter/parser** (YAML::PP
   throughout). This changes what produces our on-wire bytes, and the MAC's
   encrypt side depends on the emitter sorting keys — a property YAML::XS has
   and that the whole two-sided digest agreement rides on.
3. **Keep YAML::XS as parser and emitter; use a second parser for order only.**

## Decision

Option 3. `_verify_mac` recovers document key order from an order-preserving
reparse using **YAML::PP** (`PRESERVE_ORDER`), a new runtime prerequisite, for
both formats — JSON is a YAML 1.2 subset, so one parser covers both.

The boundary is deliberate and narrow:

- **YAML::PP supplies order and nothing else.** Values still come from the real
  tree, via a parallel walk. Nothing YAML::PP produces reaches the digest as
  data, so a divergence in how it *represents* a scalar cannot change a MAC.
- **YAML::XS and JSON::MaybeXS remain the parsers and the emitters.** Our
  on-wire bytes are unchanged, and the encrypt side's dependency on sorted key
  emission (see the MAC section of `file-sops-core`) is untouched.
- **The metadata MAC is excluded structurally**, by dropping the `sops` branch
  during the reparse, rather than by pattern-matching `mac:` in the text. That
  removes the class of bug in which a user key ending in `mac` was silently
  omitted from the digest.
- **Failure falls back to sorted order.** This is safe in one direction only,
  and that is the direction we need: a wrong order can make verification fail,
  never wrongly succeed.

## Consequences

- A new runtime dependency on YAML::PP. It is pure Perl and adds no XS build
  burden, but it is a second YAML implementation in the dependency tree, and the
  two must agree on *structure* (not on formatting) for the parallel walk to
  line up. This was checked against sops output containing block scalars, keys
  with spaces and `#`, tabs, quotes and emoji.
- `mac_only_encrypted` is now honourable, and is honoured — including the
  32-byte `MACOnlyEncryptedInitialization` prefix that keeps the two settings'
  digests apart. That prefix is not documented anywhere except the reference
  source; it was found because a first implementation without it failed against
  the real binary.
- Verification is now derived from document structure rather than from a text
  pattern. Diagnosing a MAC failure means reasoning about the walk, not about
  what a regex matched.
- The MAC is verified in more situations than before, so documents that were
  previously accepted without checking now fail (see the `ignore_mac` escape
  hatch, added in the same release).

## Notes

Correctness here was established against the real `sops` binary in both
directions, not by reading the Go source alone. The suite is the record: every
rule above is pinned by a test in `t/07-mac.t` that requires no binary, because
the defect class this replaces went unnoticed for two releases behind a
conditionally-skipped interop test.
