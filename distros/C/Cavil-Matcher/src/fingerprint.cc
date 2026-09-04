// SPDX-FileCopyrightText: SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later

#include "fingerprint.h"

#include "SpookyV2.h"   // content hashing

#include <cstdio>
#include <cstring>
#include <vector>

static const int MAX_LINE_SIZE = 8000;

// A single file that winnows to more than this many tokens is almost certainly a minified/generated
// blob, not human source; cap it so one pathological file cannot balloon memory.
static const size_t MAX_TOKENS_PER_FILE = 4000000;

std::vector<Fingerprint> winnow_tokens(const TokenList& tokens, int k, int w) {
  std::vector<Fingerprint> out;
  if (k < 1) k = 1;
  if (w < 1) w = 1;
  int n      = (int)tokens.size();
  int ngrams = n - k + 1;
  if (ngrams <= 0) return out;

  // Hash each k-gram of token hashes (files never contain $SKIP tokens, so every hash is real).
  std::vector<uint64_t> g((size_t)ngrams);
  for (int i = 0; i < ngrams; ++i) {
    uint64_t h = 1469598103934665603ULL;
    for (int j = 0; j < k; ++j) {
      h ^= tokens[(size_t)i + j].hash;
      h *= 1099511628211ULL;
    }
    g[(size_t)i] = h;
  }

  // Classic winnowing (Schleimer/Wilkerson/Aiken): emit the minimum hash of every window of w grams,
  // preferring the rightmost on ties, never re-emitting the same selected position. A gram at position p
  // spans tokens p..p+k-1, so its line range is those tokens' line numbers.
  auto emit = [&](int pos) {
    out.push_back({g[(size_t)pos], (uint32_t)tokens[(size_t)pos].linenumber,
                   (uint32_t)tokens[(size_t)(pos + k - 1)].linenumber});
  };
  int min_pos = -1;
  for (int i = 0; i + w <= ngrams; ++i) {
    if (min_pos < i) {
      min_pos = i;
      for (int j = i + 1; j < i + w; ++j)
        if (g[(size_t)j] <= g[(size_t)min_pos]) min_pos = j;
      emit(min_pos);
    } else if (g[(size_t)(i + w - 1)] <= g[(size_t)min_pos]) {
      min_pos = i + w - 1;
      emit(min_pos);
    }
  }
  return out;
}

// The shared read+tokenize+winnow path, byte-for-byte the same numbering as Matcher::find_matches, so a
// fingerprint's line spans line up with a pattern match's. When `content` is non-null the raw bytes are
// hashed as read, before tokenize lower-cases them, yielding the content hash the caller joins on.
static std::vector<Fingerprint> winnow_stream(FILE* input, int k, int w, size_t* out_tokens,
                                              SpookyHash* content) {
  TokenList ts;
  char      line[MAX_LINE_SIZE];
  int       linenumber = 1;
  long      pos        = ftell(input);
  while (fgets(line, sizeof(line) - 1, input)) {
    long   npos = ftell(input);
    size_t got  = (pos >= 0 && npos >= pos) ? (size_t)(npos - pos) : strlen(line);
    pos         = npos;
    if (got >= sizeof(line)) got = strlen(line);
    if (content) content->Update(line, got);
    bool line_end = got > 0 && line[got - 1] == '\n';
    tokenizer().tokenize(ts, line, linenumber);
    if (line_end) ++linenumber;
    if (ts.size() > MAX_TOKENS_PER_FILE) break;
  }
  if (out_tokens) *out_tokens = ts.size();
  return winnow_tokens(ts, k, w);
}

std::vector<Fingerprint> fingerprint_file(const std::string& path, int k, int w, size_t* out_tokens,
                                          ContentHash* out_hash) {
  if (out_tokens) *out_tokens = 0;
  if (out_hash) *out_hash = ContentHash{};
  FILE* input = fopen(path.c_str(), "rb");
  if (!input) return {};

  SpookyHash content;
  if (out_hash) content.Init(0, 0);
  auto fps = winnow_stream(input, k, w, out_tokens, out_hash ? &content : nullptr);
  fclose(input);

  if (out_hash) content.Final(&out_hash->hi, &out_hash->lo);
  return fps;
}
