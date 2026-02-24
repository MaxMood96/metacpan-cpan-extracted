/*
 * Copyright (c) 2017-2026 Christian Hansen <chansen@cpan.org>
 * <https://github.com/chansen/c-utf8-valid>
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef UTF8_VALID_H
#define UTF8_VALID_H
#include <stddef.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#ifndef UTF8_VALID_ENDIAN_BIG
#  if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#    define UTF8_VALID_ENDIAN_BIG 1
#  elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#    define UTF8_VALID_ENDIAN_BIG 0
#  else
#    error "Unknown byte order"
#  endif
#endif

#ifndef UTF8_VALID_FAST_PATH4
#  define UTF8_VALID_FAST_PATH4 0
#endif

#ifndef UTF8_VALID_FAST_PATH16
#  define UTF8_VALID_FAST_PATH16 0
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*
 *    UTF-8 Encoding Form
 *
 *    U+0000..U+007F       0xxxxxxx
 *    U+0080..U+07FF       110xxxxx 10xxxxxx
 *    U+0800..U+FFFF       1110xxxx 10xxxxxx 10xxxxxx
 *   U+10000..U+10FFFF     11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
 *
 *
 *    U+0000..U+007F       00..7F
 *                      N  C0..C1  80..BF                   1100000x 10xxxxxx
 *    U+0080..U+07FF       C2..DF  80..BF
 *                      N  E0      80..9F  80..BF           11100000 100xxxxx
 *    U+0800..U+0FFF       E0      A0..BF  80..BF
 *    U+1000..U+CFFF       E1..EC  80..BF  80..BF
 *    U+D000..U+D7FF       ED      80..9F  80..BF
 *                      S  ED      A0..BF  80..BF           11101101 101xxxxx
 *    U+E000..U+FFFF       EE..EF  80..BF  80..BF
 *                      N  F0      80..8F  80..BF  80..BF   11110000 1000xxxx
 *   U+10000..U+3FFFF      F0      90..BF  80..BF  80..BF
 *   U+40000..U+FFFFF      F1..F3  80..BF  80..BF  80..BF
 *  U+100000..U+10FFFF     F4      80..8F  80..BF  80..BF   11110100 1000xxxx
 *
 *  Legend:
 *    N = Non-shortest form
 *    S = Surrogates
 */

static inline size_t
utf8_check_sequence_units(const char *p) {
  uint32_t v;

  memcpy(&v, p, 4);
#if UTF8_VALID_ENDIAN_BIG
  v = ((v & 0xFF000000) >> 24) |
      ((v & 0x00FF0000) >>  8) |
      ((v & 0x0000FF00) <<  8) |
      ((v & 0x000000FF) << 24);
#endif

#if UTF8_VALID_FAST_PATH4
  if ((v & 0x80808080) == 0)
    return 4;
#endif

  /* 0xxxxxxx */
  if ((v & 0x80) == 0)
    return 1;

  /* 110xxxxx 10xxxxxx */
  if ((v & 0xC0E0) == 0x80C0) {
    /* Ensure that the top 4 bits is not zero */
    if ((v & 0x1E) == 0)
      return 0;
    return 2;
  }

  /* 1110xxxx 10xxxxxx 10xxxxxx */
  if ((v & 0xC0C0F0) == 0x8080E0) {
    /* Ensure that the top 5 bits is not zero and not a surrogate */
    v = v & 0x00200F;
    if (v == 0 || v == 0x00200D)
      return 0;
    return 3;
  }

  /* 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx */
  if ((v & 0xC0C0C0F8) == 0x808080F0) {
    /* Ensure that the top 5 bits is not zero and not out of range */
    v = ((v & 0x07) << 4) | ((v & 0x3000) >> 12);
    if (v == 0 || v > 0x40)
      return 0;
    return 4;
  }

  return 0;
}

static inline bool
utf8_check(const char *src, size_t len, size_t *cursor) {
  char buf[4];
  size_t pos = 0;

  while (pos < len) {
#if UTF8_VALID_FAST_PATH16
    for (; len - pos >= 16; pos += 16) {
      uint64_t v1, v2;
      memcpy(&v1, src + pos, sizeof(uint64_t));
      memcpy(&v2, src + pos + sizeof(uint64_t), sizeof(uint64_t));
      if (((v1 | v2) & UINT64_C(0x8080808080808080)) != 0)
        break;
    }
#endif

    const char *p = src + pos;
    if (len - pos < 4) {
      memset(buf, 0xFF, 4);
      memcpy(buf, p, len - pos);
      p = buf;
    }
    size_t count = utf8_check_sequence_units(p);
    if (!count)
      break;
    pos += count;
  }

  if (cursor)
    *cursor = pos;
  return pos == len;
}

static inline bool
utf8_valid(const char *src, size_t len) {
  return utf8_check(src, len, NULL);
}

static inline size_t
utf8_maximal_subpart(const char *src, size_t len) {
  const unsigned char *cur = (const unsigned char *)src;
  uint32_t v;

  if (len < 2)
    return len;

  v = (cur[0] << 8) | cur[1];
  if ((v & 0xC0C0) != 0xC080)
    return 1;

  if ((v & 0x2000) == 0) {
    v = v & 0x1E00;
    if (v == 0)
      return 1;
    return 2;
  }

  if ((v & 0x1000) == 0) {
    v = v & 0x0F20;
    if (v == 0 || v == 0x0D20)
      return 1;
    if (len < 3 || (cur[2] & 0xC0) != 0x80)
      return 2;
    return 3;
  }

  if ((v & 0x0800) == 0) {
    v = v & 0x0730;
    if (v == 0 || v > 0x0400)
      return 1;
    if (len < 3 || (cur[2] & 0xC0) != 0x80)
      return 2;
    if (len < 4 || (cur[3] & 0xC0) != 0x80)
      return 3;
    return 4;
  }

  return 1;
}

#ifdef __cplusplus
}
#endif
#endif

