/* po_crc32c.h - CRC-32C (Castagnoli), hardware where there is one.
 *
 * CRC-32C rather than the zlib CRC-32 because every architecture that matters
 * has an instruction for it: SSE4.2 on x86-64, the v8 CRC extension on ARM.
 * The polynomial is 0x1EDC6F41, reflected 0x82F63B78, and the reflected form
 * is what both instructions implement.
 *
 * The probes are in Makefile.PL and they LINK rather than merely compile -
 * MSVC exits 0 on an undeclared intrinsic and old gcc treats an implicit
 * declaration as a warning, so a compile-only probe reports an instruction
 * that is not there and the .so dies at load.
 *
 * The table fallback is not a lesser implementation, it is the SAME function.
 * t/0004-wal.t asserts they agree bit for bit on the same input, because a WAL
 * written on a machine with the instruction and replayed on one without has
 * to verify - and that is not a hypothetical, it is a segment archive moved
 * between hosts.
 */
#ifndef PO_CRC32C_H
#define PO_CRC32C_H

#include "punk_observe/po_compat.h"

#if defined(PO_HAVE_CRC32C_X86)
#  include <nmmintrin.h>
#endif
#if defined(PO_HAVE_CRC32C_ARM)
#  include <arm_acle.h>
#endif

/* The reflected Castagnoli table, generated on first use rather than shipped
 * as 1KB of literals nobody can check. */
static uint32_t po_crc32c_tab[256];
static int      po_crc32c_ready = 0;

static void po_crc32c_init(void) {
    uint32_t i, j, c;
    if (po_crc32c_ready) return;
    for (i = 0; i < 256; i++) {
        c = i;
        for (j = 0; j < 8; j++)
            c = (c & 1) ? (0x82F63B78u ^ (c >> 1)) : (c >> 1);
        po_crc32c_tab[i] = c;
    }
    po_crc32c_ready = 1;
}

static uint32_t po_crc32c_table(uint32_t crc, const void *buf, size_t len) {
    const uint8_t *p = (const uint8_t *)buf;
    po_crc32c_init();
    crc = ~crc;
    while (len--) crc = po_crc32c_tab[(crc ^ *p++) & 0xFF] ^ (crc >> 8);
    return ~crc;
}

/* The public entry. Same signature, same answer, whichever path runs. */
static uint32_t po_crc32c(uint32_t crc, const void *buf, size_t len) {
#if defined(PO_HAVE_CRC32C_X86) || defined(PO_HAVE_CRC32C_ARM)
    const uint8_t *p = (const uint8_t *)buf;
    uint32_t c = ~crc;

    /* Align to 8 bytes a byte at a time, then eat 8 at a time. Unaligned
     * loads are legal on both architectures but the aligned path is the one
     * the instruction is scheduled for. */
    while (len && ((uintptr_t)p & 7)) {
#  if defined(PO_HAVE_CRC32C_X86)
        c = (uint32_t)_mm_crc32_u8(c, *p);
#  else
        c = __crc32cb(c, *p);
#  endif
        p++; len--;
    }
    while (len >= 8) {
        po_u64 v;
        memcpy(&v, p, 8);            /* memcpy, not a cast: strict aliasing */
#  if defined(PO_HAVE_CRC32C_X86)
        c = (uint32_t)_mm_crc32_u64((po_u64)c, v);
#  else
        c = __crc32cd(c, v);
#  endif
        p += 8; len -= 8;
    }
    while (len--) {
#  if defined(PO_HAVE_CRC32C_X86)
        c = (uint32_t)_mm_crc32_u8(c, *p);
#  else
        c = __crc32cb(c, *p);
#  endif
        p++;
    }
    return ~c;
#else
    return po_crc32c_table(crc, buf, len);
#endif
}

static int po_crc32c_hardware(void) {
#if defined(PO_HAVE_CRC32C_X86) || defined(PO_HAVE_CRC32C_ARM)
    return 1;
#else
    return 0;
#endif
}

#endif /* PO_CRC32C_H */
