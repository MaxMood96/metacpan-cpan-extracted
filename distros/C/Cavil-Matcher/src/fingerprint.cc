// SPDX-FileCopyrightText: SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later

#include "fingerprint.h"

#include "SpookyV2.h"   // content hashing for dedup
#include "segment.h"    // cavil_crc32

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <unordered_map>
#include <unordered_set>
#include <vector>

static const int MAX_LINE_SIZE = 8000;

// A single file that winnows to more than this many tokens is almost certainly a minified/generated
// blob, not human source; cap it so one pathological file cannot balloon memory during a build.
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

// The one shared read+tokenize path (byte-for-byte the same numbering as Matcher::find_matches). Both
// fingerprint_file (opening a path) and the bulk scanner (over an in-memory buffer via fmemopen) go
// through here, so the fingerprint counts a measurement reports are the counts production would store.
// When `content` is non-null the raw bytes are hashed as read, before tokenize lower-cases them.
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

bool build_fp_segment(const std::vector<std::string>& files, const std::string& out_path, int k, int w,
                      bool dedup, FpBuildStats& stats) {
  std::vector<FpRec>     recs;
  std::vector<FpContent> contents;
  std::unordered_map<ContentHash, uint32_t, ContentHashHash, ContentHashEq> ref_of;    // content -> content_ref
  std::unordered_set<ContentHash, ContentHashHash, ContentHashEq>           distinct;  // for stats only

  for (const std::string& path : files) {
    struct stat st;
    if (stat(path.c_str(), &st) == 0 && st.st_size > 0) stats.source_bytes += (uint64_t)st.st_size;

    size_t      toks = 0;
    ContentHash chash;
    auto        fps = fingerprint_file(path, k, w, &toks, &chash);
    stats.tokens += toks;
    stats.files++;
    if (fps.empty()) continue;

    if (distinct.insert(chash).second) stats.unique_contents++;

    if (dedup && ref_of.find(chash) != ref_of.end()) {
      stats.duplicate_files++;
      continue;    // byte-identical to a content already stored (e.g. another package version)
    }
    uint32_t ref = (uint32_t)contents.size();
    if (dedup) ref_of.emplace(chash, ref);
    contents.push_back({chash.hi, chash.lo, (uint32_t)fps.size(), 0});
    for (const Fingerprint& f : fps) recs.push_back({f.fp, ref, fp_pack_loc(f.sline, f.eline)});
  }

  std::sort(recs.begin(), recs.end(), [](const FpRec& a, const FpRec& b) {
    if (a.fp != b.fp) return a.fp < b.fp;
    if (a.content_ref != b.content_ref) return a.content_ref < b.content_ref;
    return a.loc < b.loc;
  });

  stats.records = recs.size();
  uint64_t d = 0, max_df = 0, run = 0, prev = 0;
  for (size_t i = 0; i < recs.size(); ++i) {
    if (i == 0 || recs[i].fp != prev) {
      if (run > max_df) max_df = run;
      d++;
      run  = 1;
      prev = recs[i].fp;
    } else {
      run++;
    }
  }
  if (run > max_df) max_df = run;
  stats.distinct = d;
  stats.max_df   = max_df;

  size_t rec_bytes     = recs.size() * sizeof(FpRec);
  size_t content_bytes = contents.size() * sizeof(FpContent);
  size_t total         = sizeof(FpHeader) + rec_bytes + content_bytes;
  std::vector<char> buf(total, 0);
  char*             p = buf.data();

  FpHeader* h = reinterpret_cast<FpHeader*>(p);
  if (!recs.empty()) memcpy(p + sizeof(FpHeader), recs.data(), rec_bytes);
  if (!contents.empty()) memcpy(p + sizeof(FpHeader) + rec_bytes, contents.data(), content_bytes);

  memcpy(h->magic, FP_MAGIC, 8);
  h->format_version = FP_FORMAT_VERSION;
  h->flags          = 0;
  h->generation     = 0;
  h->rec_count      = recs.size();
  h->content_count  = (uint32_t)contents.size();
  h->k              = (uint32_t)k;
  h->w              = (uint32_t)w;
  h->payload_crc32  = cavil_crc32(p + sizeof(FpHeader), total - sizeof(FpHeader));

  std::string tmp = out_path + ".tmp";
  FILE*       f   = fopen(tmp.c_str(), "wb");
  if (!f) return false;
  bool ok = fwrite(buf.data(), 1, total, f) == total;
  if (fclose(f) != 0) ok = false;
  if (!ok) {
    unlink(tmp.c_str());
    return false;
  }
  if (rename(tmp.c_str(), out_path.c_str()) != 0) {
    unlink(tmp.c_str());
    return false;
  }
  return true;
}

// ---- segment reader ----
FpSegment::~FpSegment() {
  if (_data && _data != MAP_FAILED) munmap((void*)_data, _len);
  if (_fd >= 0) close(_fd);
}

static bool fp_structure_ok(size_t len, const FpHeader* h) {
  if (len < sizeof(FpHeader)) return false;
  if (memcmp(h->magic, FP_MAGIC, 8) != 0) return false;
  if (h->format_version != FP_FORMAT_VERSION) return false;
  size_t rec_bytes = (size_t)h->rec_count * sizeof(FpRec);
  if (rec_bytes / sizeof(FpRec) != h->rec_count) return false;    // multiply overflow guard
  size_t content_bytes = (size_t)h->content_count * sizeof(FpContent);
  return sizeof(FpHeader) + rec_bytes + content_bytes == len;
}

bool FpSegment::open(const std::string& path) {
  if (_data && _data != MAP_FAILED) munmap((void*)_data, _len);    // reset any prior mapping (e.g. verify reopens)
  if (_fd >= 0) close(_fd);
  _data   = nullptr;
  _fd     = -1;
  _valid  = false;
  _header = nullptr;
  _fd     = ::open(path.c_str(), O_RDONLY);
  if (_fd < 0) return false;
  struct stat st;
  if (fstat(_fd, &st) != 0 || st.st_size <= (off_t)sizeof(FpHeader)) {
    close(_fd);
    _fd = -1;
    return false;
  }
  void* pv = mmap(nullptr, (size_t)st.st_size, PROT_READ, MAP_SHARED, _fd, 0);
  if (pv == MAP_FAILED) {
    close(_fd);
    _fd = -1;
    return false;
  }
  _data = static_cast<const char*>(pv);
  _len  = (size_t)st.st_size;

  const FpHeader* h = reinterpret_cast<const FpHeader*>(_data);
  if (!fp_structure_ok(_len, h)) return false;
  _header   = h;
  _recs     = reinterpret_cast<const FpRec*>(_data + sizeof(FpHeader));
  _contents = reinterpret_cast<const FpContent*>(_data + sizeof(FpHeader) + (size_t)h->rec_count * sizeof(FpRec));
  _valid    = true;
  return true;
}

bool FpSegment::verify(const std::string& path) {
  if (!open(path)) return false;
  return cavil_crc32(_data + sizeof(FpHeader), _len - sizeof(FpHeader)) == _header->payload_crc32;
}

std::string FpSegment::content_hash_hex(uint32_t content_ref) const {
  if (!_valid || content_ref >= _header->content_count) return "";
  char buf[33];
  snprintf(buf, sizeof(buf), "%016llx%016llx", (unsigned long long)_contents[content_ref].hash_hi,
           (unsigned long long)_contents[content_ref].hash_lo);
  return std::string(buf, 32);
}

std::vector<FpMatch> FpSegment::score(const std::vector<uint64_t>& query_fps, int top_n, double min_containment,
                                      uint64_t max_df, bool want_regions) const {
  std::vector<FpMatch> out;
  if (!_valid || query_fps.empty()) return out;

  std::vector<uint64_t> q(query_fps);
  std::sort(q.begin(), q.end());
  q.erase(std::unique(q.begin(), q.end()), q.end());    // containment is over DISTINCT query fingerprints

  struct Acc {
    uint32_t              hits = 0;
    std::vector<FpRegion> regions;
  };
  std::unordered_map<uint32_t, Acc> per;    // content_ref -> accumulator

  // Containment is over the query fingerprints actually used. With DF-pruning on (max_df > 0), a fingerprint
  // that appears in more than max_df records is boilerplate: it is skipped, so it neither adds coincidental
  // matches nor counts against containment. Off (max_df == 0) leaves every distinct query fingerprint in.
  uint64_t denom = 0;
  for (uint64_t qfp : q) {
    const FpRec* lo = std::lower_bound(_recs, _recs + _header->rec_count, qfp,
                                       [](const FpRec& r, uint64_t v) { return r.fp < v; });
    if (max_df > 0) {
      const FpRec* hi = std::upper_bound(_recs, _recs + _header->rec_count, qfp,
                                         [](uint64_t v, const FpRec& r) { return v < r.fp; });
      if ((uint64_t)(hi - lo) > max_df) continue;    // too common to be distinctive: prune it
    }
    ++denom;

    std::unordered_set<uint32_t> seen;      // one content counts once toward this qfp's hit
    for (const FpRec* r = lo; r < _recs + _header->rec_count && r->fp == qfp; ++r) {
      uint32_t cref = r->content_ref;
      if (cref >= _header->content_count) continue;    // bounds-check the ref rather than scanning on open
      Acc& a = per[cref];
      if (seen.insert(cref).second) a.hits++;
      if (want_regions) a.regions.push_back({fp_loc_sline(r->loc), fp_loc_span(r->loc), qfp});
    }
  }
  if (denom == 0) return out;    // every query fingerprint was pruned as boilerplate

  out.reserve(per.size());
  for (auto& kv : per) {
    // The containment floor is applied here so sub-floor coincidences (a query full of common fingerprints can
    // match hundreds of thousands of them) never leave the segment to be filtered by the caller.
    double containment = (double)kv.second.hits / (double)denom;
    if (containment < min_containment) continue;

    uint32_t cref  = kv.first;
    uint32_t cfps  = _contents[cref].fp_count;
    FpMatch  m;
    m.content_hash   = content_hash_hex(cref);
    m.hits           = kv.second.hits;
    m.containment    = containment;
    m.containment_of = cfps ? (double)kv.second.hits / (double)cfps : 0.0;
    m.regions        = std::move(kv.second.regions);
    out.push_back(std::move(m));
  }

  auto better = [](const FpMatch& a, const FpMatch& b) { return a.containment > b.containment; };
  if (top_n > 0 && (int)out.size() > top_n) {
    std::partial_sort(out.begin(), out.begin() + top_n, out.end(), better);
    out.resize(top_n);
  } else {
    std::sort(out.begin(), out.end(), better);
  }
  return out;
}
