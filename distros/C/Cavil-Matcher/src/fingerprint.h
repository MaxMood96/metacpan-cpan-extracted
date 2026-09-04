// SPDX-FileCopyrightText: SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later
//
// Snippet-provenance primitives: winnow a file's tokens into content fingerprints, and hash its bytes
// into a 128-bit content key. These answer "what fingerprints does this content have"; the searchable
// index that turns fingerprints back into packages/paths lives in the consuming application (Cavil, in
// Postgres), not here. Uses the frozen tokenizer/hashing so identical text always fingerprints
// identically. No Perl types here.

#ifndef CAVIL_MATCHER_FINGERPRINT_H_
#define CAVIL_MATCHER_FINGERPRINT_H_

#include "tokenizer.h"

#include <cstdint>
#include <string>
#include <vector>

// A 128-bit content hash (SpookyHash of the raw file bytes), rendered elsewhere as 32 hex chars exactly
// like Cavil::Matcher::Hash::hex, so the Cavil database can join on it.
struct ContentHash {
  uint64_t hi = 0;
  uint64_t lo = 0;
  bool operator==(const ContentHash& o) const { return hi == o.hi && lo == o.lo; }
};

// One winnowed fingerprint occurrence: the 64-bit gram hash and the source line range (start..end) it
// covers, so a match can be highlighted exactly.
struct Fingerprint {
  uint64_t fp;
  uint32_t sline;
  uint32_t eline;
};

// Winnow a token stream into fingerprints. k = tokens per gram, w = grams per window; expected density
// is ~2/(w+1) of grams. Deterministic (rightmost-min tie-break), so identical text always yields
// identical fingerprints regardless of how the file was chunked while reading.
std::vector<Fingerprint> winnow_tokens(const TokenList& tokens, int k, int w);

// Fingerprint a whole file: read it (raw bytes, NUL-tolerant, token count bounded like the matcher),
// tokenize, winnow. out_tokens receives the token count; out_hash receives the 128-bit content hash the
// caller joins on (identical across byte-identical files). Missing or unreadable files yield an empty
// result, not an error.
std::vector<Fingerprint> fingerprint_file(const std::string& path, int k, int w, size_t* out_tokens = nullptr,
                                          ContentHash* out_hash = nullptr);

#endif
