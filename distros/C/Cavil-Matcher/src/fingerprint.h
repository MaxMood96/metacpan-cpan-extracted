// SPDX-FileCopyrightText: SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later
//
// A FingerprintSegment is the snippet-provenance sibling of the pattern Segment. Where a Segment
// answers "which license patterns does this file contain" by walking a prefix tree, a
// FingerprintSegment answers "which known open source content does this snippet resemble" by probing
// winnowed content fingerprints into a sorted array. It reuses the frozen tokenizer/hashing and the
// same on-disk discipline (magic + version + whole-payload CRC, structure validated on every open) so
// a corrupt or foreign file is rejected, never mis-read. No Perl types here.
//
// The record is minimal and keyed by a 128-bit CONTENT hash, not a file name: the hash is what the Cavil
// database maps to paths and metadata, so the index stays lean and new conveniences never need a format
// change.

#ifndef CAVIL_MATCHER_FINGERPRINT_H_
#define CAVIL_MATCHER_FINGERPRINT_H_

#include "tokenizer.h"

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

// A 128-bit content hash (SpookyHash of the raw file bytes), rendered elsewhere as 32 hex chars exactly
// like Cavil::Matcher::Hash::hex, so the Cavil database can join on it.
struct ContentHash {
  uint64_t hi = 0;
  uint64_t lo = 0;
  bool operator==(const ContentHash& o) const { return hi == o.hi && lo == o.lo; }
};
struct ContentHashEq {
  bool operator()(const ContentHash& a, const ContentHash& b) const { return a == b; }
};
struct ContentHashHash {
  size_t operator()(const ContentHash& h) const { return h.hi * 1099511628211ULL ^ h.lo; }
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
// tokenize, winnow. out_tokens receives the token count; out_hash receives the 128-bit content hash used
// to deduplicate byte-identical files (the same file shipped across many package versions). Missing or
// unreadable files yield an empty result, not an error.
std::vector<Fingerprint> fingerprint_file(const std::string& path, int k, int w, size_t* out_tokens = nullptr,
                                          ContentHash* out_hash = nullptr);

// Stats from build_fp_segment: the manifest records the record count; the rest report dedup and build detail.
struct FpBuildStats {
  uint64_t files           = 0;
  uint64_t source_bytes    = 0;
  uint64_t tokens          = 0;
  uint64_t records         = 0;    // total fingerprint occurrences written
  uint64_t distinct        = 0;    // distinct fingerprint values
  uint64_t max_df          = 0;    // largest number of records sharing one fingerprint value
  uint64_t unique_contents = 0;    // distinct content hashes stored
  uint64_t duplicate_files = 0;    // files whose content had already been seen (skipped when dedup on)
};

// Build a fingerprint segment from a list of files and write it atomically to out_path (temp+rename).
// Records reference a per-segment content-hash table, not file names, so a caller resolves a match to
// paths/packages through its own database. When dedup is true, a file whose content matches one already
// processed contributes no records, collapsing the same file shipped across many package versions to one
// stored copy (no package-name parsing needed). Returns false on write failure. Never crashes on bad
// input.
bool build_fp_segment(const std::vector<std::string>& files, const std::string& out_path, int k, int w,
                      bool dedup, FpBuildStats& stats);

// v1 stored a filename table; v2 stores a 128-bit content-hash table and an exact line span per record.
static const char     FP_MAGIC[8]       = {'C', 'A', 'V', 'I', 'L', 'F', 'P', '2'};
static const uint32_t FP_FORMAT_VERSION = 2;

#pragma pack(push, 1)
struct FpHeader {
  char     magic[8];
  uint32_t format_version;
  uint32_t flags;
  uint64_t generation;
  uint64_t rec_count;        // length of the sorted FpRec array
  uint32_t content_count;    // number of FpContent entries
  uint32_t k;
  uint32_t w;
  uint32_t payload_crc32;
};
struct FpRec {               // 16 bytes; the array is sorted by (fp, content_ref, loc)
  uint64_t fp;
  uint32_t content_ref;      // index into the FpContent table
  uint32_t loc;              // (start_line << 8) | span_in_lines; see fp_pack_loc
};
struct FpContent {           // 24 bytes; one per distinct content this segment holds
  uint64_t hash_hi;
  uint64_t hash_lo;
  uint32_t fp_count;         // total fingerprints of this content (for content-direction containment)
  uint32_t pad;
};
#pragma pack(pop)

// Pack a matched line range into the 4-byte loc slot: 24 bits of start line (up to 16M, ample for real
// source; minified single-line files are excluded by size) and 8 bits of span (clamped at 255 lines,
// which a k-gram fingerprint never realistically exceeds).
static inline uint32_t fp_pack_loc(uint32_t sline, uint32_t eline) {
  uint32_t span = eline > sline ? eline - sline : 0;
  if (span > 255) span = 255;
  if (sline > 0xFFFFFF) sline = 0xFFFFFF;
  return (sline << 8) | span;
}
static inline uint32_t fp_loc_sline(uint32_t loc) { return loc >> 8; }
static inline uint32_t fp_loc_span(uint32_t loc) { return loc & 0xFF; }

// One matched fingerprint occurrence: the content line span it covers, and the query fingerprint value it
// was. The value (not an index) is the key because score() sorts the query set internally, so a caller maps
// a match back to its query position by value. This lets a caller tell an aligned copy from a scattered one.
struct FpRegion {
  uint32_t sline;
  uint32_t span;
  uint64_t fp;
};

// One scored candidate: the matched content and how much of the query it contains (the match percentage),
// plus the reverse direction and the exact matched fingerprints for highlighting and alignment.
struct FpMatch {
  std::string content_hash;    // 32 hex chars (hi, lo), joinable to the Cavil database
  uint32_t    hits;            // distinct query fingerprints found in this content
  double      containment;     // hits / distinct query fingerprints (how much of the query is here)
  double      containment_of;  // hits / this content's fingerprints (how much of this content is the query)
  std::vector<FpRegion> regions;    // each matched fingerprint: content line span + the query fp value
};

// Read-only view over a compiled fingerprint segment. open() mmaps and validates structure; a query
// winnows a snippet and score() reports the best-containment content.
class FpSegment {
public:
  FpSegment() = default;
  ~FpSegment();

  bool open(const std::string& path);    // mmap + validate structure (not whole-payload CRC)
  bool verify(const std::string& path);  // full structure + CRC check, on demand (fsck)
  bool valid() const { return _valid; }

  // Score a query fingerprint set, returning up to top_n contents by containment (0 = all). When
  // want_regions is false the matched-region lists are left empty (a small saving for callers that only
  // need the ranking).
  std::vector<FpMatch> score(const std::vector<uint64_t>& query_fps, int top_n, double min_containment = 0.0,
                             uint64_t max_df = 0, bool want_regions = true) const;

private:
  std::string content_hash_hex(uint32_t content_ref) const;

  int             _fd     = -1;
  const char*     _data   = nullptr;
  size_t          _len    = 0;
  bool            _valid  = false;
  const FpHeader*  _header   = nullptr;
  const FpRec*     _recs     = nullptr;
  const FpContent* _contents = nullptr;
};

#endif
