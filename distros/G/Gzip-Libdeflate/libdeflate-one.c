/*
Copyright 2016 Eric Biggers
Copyright 2024 Google LLC

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/adler32.c */


/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 



#define DIVISOR 65521


#define MAX_CHUNK_LEN	5552


#define ADLER32_CHUNK(s1, s2, p, n)					\
do {									\
	if (n >= 4) {							\
		u32 s1_sum = 0;						\
		u32 byte_0_sum = 0;					\
		u32 byte_1_sum = 0;					\
		u32 byte_2_sum = 0;					\
		u32 byte_3_sum = 0;					\
									\
		do {							\
			s1_sum += s1;					\
			s1 += p[0] + p[1] + p[2] + p[3];		\
			byte_0_sum += p[0];				\
			byte_1_sum += p[1];				\
			byte_2_sum += p[2];				\
			byte_3_sum += p[3];				\
			p += 4;						\
			n -= 4;						\
		} while (n >= 4);					\
		s2 += (4 * (s1_sum + byte_0_sum)) + (3 * byte_1_sum) +	\
		      (2 * byte_2_sum) + byte_3_sum;			\
	}								\
	for (; n; n--, p++) {						\
		s1 += *p;						\
		s2 += s1;						\
	}								\
	s1 %= DIVISOR;							\
	s2 %= DIVISOR;							\
} while (0)

static u32 MAYBE_UNUSED
adler32_generic(u32 adler, const u8 *p, size_t len)
{
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	while (len) {
		size_t n = MIN(len, MAX_CHUNK_LEN & ~3);

		len -= n;
		ADLER32_CHUNK(s1, s2, p, n);
	}

	return (s2 << 16) | s1;
}


#undef DEFAULT_IMPL
#undef arch_select_adler32_func
typedef u32 (*adler32_func_t)(u32 adler, const u8 *p, size_t len);
#if defined(ARCH_ARM32) || defined(ARCH_ARM64)
/* #  include "arm/adler32_impl.h" */


#ifndef LIB_ARM_ADLER32_IMPL_H
#define LIB_ARM_ADLER32_IMPL_H

/* #include "arm-cpu_features.h" */


#ifndef LIB_ARM_CPU_FEATURES_H
#define LIB_ARM_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_ARM32) || defined(ARCH_ARM64)

#define ARM_CPU_FEATURE_NEON		(1 << 0)
#define ARM_CPU_FEATURE_PMULL		(1 << 1)

#define ARM_CPU_FEATURE_PREFER_PMULL	(1 << 2)
#define ARM_CPU_FEATURE_CRC32		(1 << 3)
#define ARM_CPU_FEATURE_SHA3		(1 << 4)
#define ARM_CPU_FEATURE_DOTPROD		(1 << 5)

#if !defined(FREESTANDING) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
    (defined(__linux__) || \
     (defined(__APPLE__) && defined(ARCH_ARM64)) || \
     (defined(_WIN32) && defined(ARCH_ARM64)))

#  define ARM_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_arm_cpu_features;

void libdeflate_init_arm_cpu_features(void);

static inline u32 get_arm_cpu_features(void)
{
	if (libdeflate_arm_cpu_features == 0)
		libdeflate_init_arm_cpu_features();
	return libdeflate_arm_cpu_features;
}
#else
static inline u32 get_arm_cpu_features(void) { return 0; }
#endif


#if defined(__ARM_NEON) || (defined(_MSC_VER) && defined(ARCH_ARM64))
#  define HAVE_NEON(features)	1
#  define HAVE_NEON_NATIVE	1
#else
#  define HAVE_NEON(features)	((features) & ARM_CPU_FEATURE_NEON)
#  define HAVE_NEON_NATIVE	0
#endif

#if (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
	(HAVE_NEON_NATIVE || (GCC_PREREQ(6, 1) && defined(__ARM_FP)))
#  define HAVE_NEON_INTRIN	1
#  include <arm_neon.h>
#else
#  define HAVE_NEON_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRYPTO
#  define HAVE_PMULL(features)	1
#else
#  define HAVE_PMULL(features)	((features) & ARM_CPU_FEATURE_PMULL)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(7, 1) || defined(__clang__) || defined(_MSC_VER)) && \
	CPU_IS_LITTLE_ENDIAN() 
#  define HAVE_PMULL_INTRIN	1
   
#  ifdef _MSC_VER
#    define compat_vmull_p64(a, b)  vmull_p64(vcreate_p64(a), vcreate_p64(b))
#  else
#    define compat_vmull_p64(a, b)  vmull_p64((a), (b))
#  endif
#else
#  define HAVE_PMULL_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRC32
#  define HAVE_CRC32(features)	1
#else
#  define HAVE_CRC32(features)	((features) & ARM_CPU_FEATURE_CRC32)
#endif
#if defined(ARCH_ARM64) && \
	(defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))
#  define HAVE_CRC32_INTRIN	1
#  if defined(__GNUC__) || defined(__clang__)
#    include <arm_acle.h>
#  endif
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_CRC32)
#    undef __crc32b
#    define __crc32b(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32b %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32h
#    define __crc32h(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32h %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32w
#    define __crc32w(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32w %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32d
#    define __crc32d(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32x %w0, %w1, %2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_CRC32_INTRIN	0
#endif


#ifdef __ARM_FEATURE_SHA3
#  define HAVE_SHA3(features)	1
#else
#  define HAVE_SHA3(features)	((features) & ARM_CPU_FEATURE_SHA3)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(9, 1)  || \
	 CLANG_PREREQ(7, 0, 10010463) )
#  define HAVE_SHA3_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_SHA3)
#    undef veor3q_u8
#    define veor3q_u8(a, b, c)					\
	({ uint8x16_t res;					\
	   __asm__("eor3 %0.16b, %1.16b, %2.16b, %3.16b"	\
		   : "=w" (res) : "w" (a), "w" (b), "w" (c));	\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_SHA3_INTRIN	0
#endif


#ifdef __ARM_FEATURE_DOTPROD
#  define HAVE_DOTPROD(features)	1
#else
#  define HAVE_DOTPROD(features)	((features) & ARM_CPU_FEATURE_DOTPROD)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(8, 1) || CLANG_PREREQ(7, 0, 10010000) || defined(_MSC_VER))
#  define HAVE_DOTPROD_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_DOTPROD)
#    undef vdotq_u32
#    define vdotq_u32(a, b, c)					\
	({ uint32x4_t res = (a);				\
	   __asm__("udot %0.4s, %1.16b, %2.16b"			\
		   : "+w" (res) : "w" (b), "w" (c));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_DOTPROD_INTRIN	0
#endif

#endif 

#endif 



#if HAVE_NEON_INTRIN && CPU_IS_LITTLE_ENDIAN()
#  define adler32_arm_neon	adler32_arm_neon
#  if HAVE_NEON_NATIVE
     
#    define ATTRIBUTES
#  elif defined(ARCH_ARM32)
#    define ATTRIBUTES	_target_attribute("fpu=neon")
#  elif defined(__clang__)
#    define ATTRIBUTES	_target_attribute("simd")
#  else
#    define ATTRIBUTES	_target_attribute("+simd")
#  endif
static ATTRIBUTES MAYBE_UNUSED u32
adler32_arm_neon(u32 adler, const u8 *p, size_t len)
{
	static const u16 _aligned_attribute(16) mults[64] = {
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const uint16x8_t mults_a = vld1q_u16(&mults[0]);
	const uint16x8_t mults_b = vld1q_u16(&mults[8]);
	const uint16x8_t mults_c = vld1q_u16(&mults[16]);
	const uint16x8_t mults_d = vld1q_u16(&mults[24]);
	const uint16x8_t mults_e = vld1q_u16(&mults[32]);
	const uint16x8_t mults_f = vld1q_u16(&mults[40]);
	const uint16x8_t mults_g = vld1q_u16(&mults[48]);
	const uint16x8_t mults_h = vld1q_u16(&mults[56]);
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 32768 && ((uintptr_t)p & 15))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & 15);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~63);

		len -= n;

		if (n >= 64) {
			uint32x4_t v_s1 = vdupq_n_u32(0);
			uint32x4_t v_s2 = vdupq_n_u32(0);
			
			uint16x8_t v_byte_sums_a = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_b = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_c = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_d = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_e = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_f = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_g = vdupq_n_u16(0);
			uint16x8_t v_byte_sums_h = vdupq_n_u16(0);

			s2 += s1 * (n & ~63);

			do {
				
				const uint8x16_t data_a = vld1q_u8(p + 0);
				const uint8x16_t data_b = vld1q_u8(p + 16);
				const uint8x16_t data_c = vld1q_u8(p + 32);
				const uint8x16_t data_d = vld1q_u8(p + 48);
				uint16x8_t tmp;

				
				v_s2 = vaddq_u32(v_s2, v_s1);

				
				tmp = vpaddlq_u8(data_a);
				v_byte_sums_a = vaddw_u8(v_byte_sums_a,
							 vget_low_u8(data_a));
				v_byte_sums_b = vaddw_u8(v_byte_sums_b,
							 vget_high_u8(data_a));
				tmp = vpadalq_u8(tmp, data_b);
				v_byte_sums_c = vaddw_u8(v_byte_sums_c,
							 vget_low_u8(data_b));
				v_byte_sums_d = vaddw_u8(v_byte_sums_d,
							 vget_high_u8(data_b));
				tmp = vpadalq_u8(tmp, data_c);
				v_byte_sums_e = vaddw_u8(v_byte_sums_e,
							 vget_low_u8(data_c));
				v_byte_sums_f = vaddw_u8(v_byte_sums_f,
							 vget_high_u8(data_c));
				tmp = vpadalq_u8(tmp, data_d);
				v_byte_sums_g = vaddw_u8(v_byte_sums_g,
							 vget_low_u8(data_d));
				v_byte_sums_h = vaddw_u8(v_byte_sums_h,
							 vget_high_u8(data_d));
				v_s1 = vpadalq_u16(v_s1, tmp);

				p += 64;
				n -= 64;
			} while (n >= 64);

			
		#ifdef ARCH_ARM32
		#  define umlal2(a, b, c)  vmlal_u16((a), vget_high_u16(b), vget_high_u16(c))
		#else
		#  define umlal2	   vmlal_high_u16
		#endif
			v_s2 = vqshlq_n_u32(v_s2, 6);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_a),
					 vget_low_u16(mults_a));
			v_s2 = umlal2(v_s2, v_byte_sums_a, mults_a);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_b),
					 vget_low_u16(mults_b));
			v_s2 = umlal2(v_s2, v_byte_sums_b, mults_b);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_c),
					 vget_low_u16(mults_c));
			v_s2 = umlal2(v_s2, v_byte_sums_c, mults_c);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_d),
					 vget_low_u16(mults_d));
			v_s2 = umlal2(v_s2, v_byte_sums_d, mults_d);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_e),
					 vget_low_u16(mults_e));
			v_s2 = umlal2(v_s2, v_byte_sums_e, mults_e);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_f),
					 vget_low_u16(mults_f));
			v_s2 = umlal2(v_s2, v_byte_sums_f, mults_f);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_g),
					 vget_low_u16(mults_g));
			v_s2 = umlal2(v_s2, v_byte_sums_g, mults_g);
			v_s2 = vmlal_u16(v_s2, vget_low_u16(v_byte_sums_h),
					 vget_low_u16(mults_h));
			v_s2 = umlal2(v_s2, v_byte_sums_h, mults_h);
		#undef umlal2

			
		#ifdef ARCH_ARM32
			s1 += vgetq_lane_u32(v_s1, 0) + vgetq_lane_u32(v_s1, 1) +
			      vgetq_lane_u32(v_s1, 2) + vgetq_lane_u32(v_s1, 3);
			s2 += vgetq_lane_u32(v_s2, 0) + vgetq_lane_u32(v_s2, 1) +
			      vgetq_lane_u32(v_s2, 2) + vgetq_lane_u32(v_s2, 3);
		#else
			s1 += vaddvq_u32(v_s1);
			s2 += vaddvq_u32(v_s2);
		#endif
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
	return (s2 << 16) | s1;
}
#undef ATTRIBUTES
#endif 


#if HAVE_DOTPROD_INTRIN && CPU_IS_LITTLE_ENDIAN() && \
	!defined(LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_DOTPROD)
#  define adler32_arm_neon_dotprod	adler32_arm_neon_dotprod
#  ifdef __clang__
#    define ATTRIBUTES	_target_attribute("dotprod")
   
#  elif GCC_PREREQ(14, 0) || defined(__ARM_FEATURE_JCVT) \
			  || defined(__ARM_FEATURE_DOTPROD)
#    define ATTRIBUTES	_target_attribute("+dotprod")
#  else
#    define ATTRIBUTES	_target_attribute("arch=armv8.2-a+dotprod")
#  endif
static ATTRIBUTES u32
adler32_arm_neon_dotprod(u32 adler, const u8 *p, size_t len)
{
	static const u8 _aligned_attribute(16) mults[64] = {
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const uint8x16_t mults_a = vld1q_u8(&mults[0]);
	const uint8x16_t mults_b = vld1q_u8(&mults[16]);
	const uint8x16_t mults_c = vld1q_u8(&mults[32]);
	const uint8x16_t mults_d = vld1q_u8(&mults[48]);
	const uint8x16_t ones = vdupq_n_u8(1);
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 32768 && ((uintptr_t)p & 15))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & 15);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~63);

		len -= n;

		if (n >= 64) {
			uint32x4_t v_s1_a = vdupq_n_u32(0);
			uint32x4_t v_s1_b = vdupq_n_u32(0);
			uint32x4_t v_s1_c = vdupq_n_u32(0);
			uint32x4_t v_s1_d = vdupq_n_u32(0);
			uint32x4_t v_s2_a = vdupq_n_u32(0);
			uint32x4_t v_s2_b = vdupq_n_u32(0);
			uint32x4_t v_s2_c = vdupq_n_u32(0);
			uint32x4_t v_s2_d = vdupq_n_u32(0);
			uint32x4_t v_s1_sums_a = vdupq_n_u32(0);
			uint32x4_t v_s1_sums_b = vdupq_n_u32(0);
			uint32x4_t v_s1_sums_c = vdupq_n_u32(0);
			uint32x4_t v_s1_sums_d = vdupq_n_u32(0);
			uint32x4_t v_s1;
			uint32x4_t v_s2;
			uint32x4_t v_s1_sums;

			s2 += s1 * (n & ~63);

			do {
				uint8x16_t data_a = vld1q_u8(p + 0);
				uint8x16_t data_b = vld1q_u8(p + 16);
				uint8x16_t data_c = vld1q_u8(p + 32);
				uint8x16_t data_d = vld1q_u8(p + 48);

				v_s1_sums_a = vaddq_u32(v_s1_sums_a, v_s1_a);
				v_s1_a = vdotq_u32(v_s1_a, data_a, ones);
				v_s2_a = vdotq_u32(v_s2_a, data_a, mults_a);

				v_s1_sums_b = vaddq_u32(v_s1_sums_b, v_s1_b);
				v_s1_b = vdotq_u32(v_s1_b, data_b, ones);
				v_s2_b = vdotq_u32(v_s2_b, data_b, mults_b);

				v_s1_sums_c = vaddq_u32(v_s1_sums_c, v_s1_c);
				v_s1_c = vdotq_u32(v_s1_c, data_c, ones);
				v_s2_c = vdotq_u32(v_s2_c, data_c, mults_c);

				v_s1_sums_d = vaddq_u32(v_s1_sums_d, v_s1_d);
				v_s1_d = vdotq_u32(v_s1_d, data_d, ones);
				v_s2_d = vdotq_u32(v_s2_d, data_d, mults_d);

				p += 64;
				n -= 64;
			} while (n >= 64);

			v_s1 = vaddq_u32(vaddq_u32(v_s1_a, v_s1_b),
					 vaddq_u32(v_s1_c, v_s1_d));
			v_s2 = vaddq_u32(vaddq_u32(v_s2_a, v_s2_b),
					 vaddq_u32(v_s2_c, v_s2_d));
			v_s1_sums = vaddq_u32(vaddq_u32(v_s1_sums_a,
							v_s1_sums_b),
					      vaddq_u32(v_s1_sums_c,
							v_s1_sums_d));
			v_s2 = vaddq_u32(v_s2, vqshlq_n_u32(v_s1_sums, 6));

			s1 += vaddvq_u32(v_s1);
			s2 += vaddvq_u32(v_s2);
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
	return (s2 << 16) | s1;
}
#undef ATTRIBUTES
#endif 

#if defined(adler32_arm_neon_dotprod) && defined(__ARM_FEATURE_DOTPROD)
#define DEFAULT_IMPL	adler32_arm_neon_dotprod
#else
static inline adler32_func_t
arch_select_adler32_func(void)
{
	const u32 features MAYBE_UNUSED = get_arm_cpu_features();

#ifdef adler32_arm_neon_dotprod
	if (HAVE_NEON(features) && HAVE_DOTPROD(features))
		return adler32_arm_neon_dotprod;
#endif
#ifdef adler32_arm_neon
	if (HAVE_NEON(features))
		return adler32_arm_neon;
#endif
	return NULL;
}
#define arch_select_adler32_func	arch_select_adler32_func
#endif

#endif 

#elif defined(ARCH_X86_32) || defined(ARCH_X86_64)
/* #  include "x86/adler32_impl.h" */


#ifndef LIB_X86_ADLER32_IMPL_H
#define LIB_X86_ADLER32_IMPL_H

/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 



#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)
#  define adler32_x86_sse2	adler32_x86_sse2
#  define SUFFIX			   _sse2
#  define ATTRIBUTES		_target_attribute("sse2")
#  define VL			16
#  define USE_VNNI		0
#  define USE_AVX512		0
/* #include "x86-adler32_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define mask_t		u16
#  define LOG2_VL		4
#  define VADD8(a, b)		_mm_add_epi8((a), (b))
#  define VADD16(a, b)		_mm_add_epi16((a), (b))
#  define VADD32(a, b)		_mm_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm_load_si128((const void *)(p))
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VMADD16(a, b)		_mm_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm_set1_epi8(a)
#  define VSET1_32(a)		_mm_set1_epi32(a)
#  define VSETZERO()		_mm_setzero_si128()
#  define VSLL32(a, b)		_mm_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm_unpackhi_epi8((a), (b))
#elif VL == 32
#  define vec_t			__m256i
#  define mask_t		u32
#  define LOG2_VL		5
#  define VADD8(a, b)		_mm256_add_epi8((a), (b))
#  define VADD16(a, b)		_mm256_add_epi16((a), (b))
#  define VADD32(a, b)		_mm256_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm256_load_si256((const void *)(p))
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VMADD16(a, b)		_mm256_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm256_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm256_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm256_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm256_set1_epi8(a)
#  define VSET1_32(a)		_mm256_set1_epi32(a)
#  define VSETZERO()		_mm256_setzero_si256()
#  define VSLL32(a, b)		_mm256_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm256_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm256_unpackhi_epi8((a), (b))
#elif VL == 64
#  define vec_t			__m512i
#  define mask_t		u64
#  define LOG2_VL		6
#  define VADD8(a, b)		_mm512_add_epi8((a), (b))
#  define VADD16(a, b)		_mm512_add_epi16((a), (b))
#  define VADD32(a, b)		_mm512_add_epi32((a), (b))
#  define VDPBUSD(a, b, c)	_mm512_dpbusd_epi32((a), (b), (c))
#  define VLOAD(p)		_mm512_load_si512((const void *)(p))
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VMADD16(a, b)		_mm512_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm512_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm512_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm512_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm512_set1_epi8(a)
#  define VSET1_32(a)		_mm512_set1_epi32(a)
#  define VSETZERO()		_mm512_setzero_si512()
#  define VSLL32(a, b)		_mm512_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm512_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm512_unpackhi_epi8((a), (b))
#else
#  error "unsupported vector length"
#endif

#define VADD32_3X(a, b, c)	VADD32(VADD32((a), (b)), (c))
#define VADD32_4X(a, b, c, d)	VADD32(VADD32((a), (b)), VADD32((c), (d)))
#define VADD32_5X(a, b, c, d, e) VADD32((a), VADD32_4X((b), (c), (d), (e)))
#define VADD32_7X(a, b, c, d, e, f, g)	\
	VADD32(VADD32_3X((a), (b), (c)), VADD32_4X((d), (e), (f), (g)))


#undef reduce_to_32bits
static forceinline ATTRIBUTES void
ADD_SUFFIX(reduce_to_32bits)(vec_t v_s1, vec_t v_s2, u32 *s1_p, u32 *s2_p)
{
	__m128i v_s1_128, v_s2_128;
#if VL == 16
	{
		v_s1_128 = v_s1;
		v_s2_128 = v_s2;
	}
#else
	{
		__m256i v_s1_256, v_s2_256;
	#if VL == 32
		v_s1_256 = v_s1;
		v_s2_256 = v_s2;
	#else
		
		v_s1_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s1, 0),
					    _mm512_extracti64x4_epi64(v_s1, 1));
		v_s2_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s2, 0),
					    _mm512_extracti64x4_epi64(v_s2, 1));
	#endif
		
		v_s1_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s1_256, 0),
					 _mm256_extracti128_si256(v_s1_256, 1));
		v_s2_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s2_256, 0),
					 _mm256_extracti128_si256(v_s2_256, 1));
	}
#endif

	
#if USE_VNNI
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x31));
#endif
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x31));
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x02));
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x02));

	*s1_p += (u32)_mm_cvtsi128_si32(v_s1_128);
	*s2_p += (u32)_mm_cvtsi128_si32(v_s2_128);
}
#define reduce_to_32bits	ADD_SUFFIX(reduce_to_32bits)

static ATTRIBUTES u32
ADD_SUFFIX(adler32_x86)(u32 adler, const u8 *p, size_t len)
{
#if USE_VNNI
	
	static const u8 _aligned_attribute(VL) raw_mults[VL] = {
	#if VL == 64
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
	#endif
	#if VL >= 32
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
	#endif
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const vec_t ones = VSET1_8(1);
#else
	
	static const u16 _aligned_attribute(VL) raw_mults[4][VL / 2] = {
	#if VL == 16
		{ 32, 31, 30, 29, 28, 27, 26, 25 },
		{ 24, 23, 22, 21, 20, 19, 18, 17 },
		{ 16, 15, 14, 13, 12, 11, 10, 9  },
		{ 8,  7,  6,  5,  4,  3,  2,  1  },
	#elif VL == 32
		{ 64, 63, 62, 61, 60, 59, 58, 57, 48, 47, 46, 45, 44, 43, 42, 41 },
		{ 56, 55, 54, 53, 52, 51, 50, 49, 40, 39, 38, 37, 36, 35, 34, 33 },
		{ 32, 31, 30, 29, 28, 27, 26, 25, 16, 15, 14, 13, 12, 11, 10,  9 },
		{ 24, 23, 22, 21, 20, 19, 18, 17,  8,  7,  6,  5,  4,  3,  2,  1 },
	#else
	#  error "unsupported parameters"
	#endif
	};
	const vec_t mults_a = VLOAD(raw_mults[0]);
	const vec_t mults_b = VLOAD(raw_mults[1]);
	const vec_t mults_c = VLOAD(raw_mults[2]);
	const vec_t mults_d = VLOAD(raw_mults[3]);
#endif
	const vec_t zeroes = VSETZERO();
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 65536 && ((uintptr_t)p & (VL-1)))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & (VL-1));
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

#if USE_VNNI
	
	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~(4*VL - 1));
		vec_t mults = VLOAD(raw_mults);
		vec_t v_s1 = zeroes;
		vec_t v_s2 = zeroes;

		s2 += s1 * n;
		len -= n;

		if (n >= 4*VL) {
			vec_t v_s1_b = zeroes;
			vec_t v_s1_c = zeroes;
			vec_t v_s1_d = zeroes;
			vec_t v_s2_b = zeroes;
			vec_t v_s2_c = zeroes;
			vec_t v_s2_d = zeroes;
			vec_t v_s1_sums   = zeroes;
			vec_t v_s1_sums_b = zeroes;
			vec_t v_s1_sums_c = zeroes;
			vec_t v_s1_sums_d = zeroes;
			vec_t tmp0, tmp1;

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);
				vec_t data_c = VLOADU(p + 2*VL);
				vec_t data_d = VLOADU(p + 3*VL);

				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+v" (data_a), "+v" (data_b),
					     "+v" (data_c), "+v" (data_d));
			#endif

				v_s2   = VDPBUSD(v_s2,   data_a, mults);
				v_s2_b = VDPBUSD(v_s2_b, data_b, mults);
				v_s2_c = VDPBUSD(v_s2_c, data_c, mults);
				v_s2_d = VDPBUSD(v_s2_d, data_d, mults);

				v_s1_sums   = VADD32(v_s1_sums,   v_s1);
				v_s1_sums_b = VADD32(v_s1_sums_b, v_s1_b);
				v_s1_sums_c = VADD32(v_s1_sums_c, v_s1_c);
				v_s1_sums_d = VADD32(v_s1_sums_d, v_s1_d);

				v_s1   = VDPBUSD(v_s1,   data_a, ones);
				v_s1_b = VDPBUSD(v_s1_b, data_b, ones);
				v_s1_c = VDPBUSD(v_s1_c, data_c, ones);
				v_s1_d = VDPBUSD(v_s1_d, data_d, ones);

				
			#if GCC_PREREQ(1, 0) && !defined(ARCH_X86_32)
				__asm__("" : "+v" (v_s2), "+v" (v_s2_b),
					     "+v" (v_s2_c), "+v" (v_s2_d),
					     "+v" (v_s1_sums),
					     "+v" (v_s1_sums_b),
					     "+v" (v_s1_sums_c),
					     "+v" (v_s1_sums_d),
					     "+v" (v_s1), "+v" (v_s1_b),
					     "+v" (v_s1_c), "+v" (v_s1_d));
			#endif
				p += 4*VL;
				n -= 4*VL;
			} while (n >= 4*VL);

			
			tmp0 = VADD32(v_s1, v_s1_b);
			tmp1 = VADD32(v_s1, v_s1_c);
			v_s1_sums = VADD32_4X(v_s1_sums, v_s1_sums_b,
					      v_s1_sums_c, v_s1_sums_d);
			v_s1 = VADD32_3X(tmp0, v_s1_c, v_s1_d);
			v_s2 = VADD32_7X(VSLL32(v_s1_sums, LOG2_VL + 2),
					 VSLL32(tmp0, LOG2_VL + 1),
					 VSLL32(tmp1, LOG2_VL),
					 v_s2, v_s2_b, v_s2_c, v_s2_d);
		}

		
		if (n >= 2*VL) {
			const vec_t data_a = VLOADU(p + 0*VL);
			const vec_t data_b = VLOADU(p + 1*VL);

			v_s2 = VADD32(v_s2, VSLL32(v_s1, LOG2_VL + 1));
			v_s1 = VDPBUSD(v_s1, data_a, ones);
			v_s1 = VDPBUSD(v_s1, data_b, ones);
			v_s2 = VDPBUSD(v_s2, data_a, VSET1_8(VL));
			v_s2 = VDPBUSD(v_s2, data_a, mults);
			v_s2 = VDPBUSD(v_s2, data_b, mults);
			p += 2*VL;
			n -= 2*VL;
		}
		if (n) {
			
			vec_t data;

			v_s2 = VADD32(v_s2, VMULLO32(v_s1, VSET1_32(n)));

			mults = VADD8(mults, VSET1_8((int)n - VL));
			if (n > VL) {
				data = VLOADU(p);
				v_s1 = VDPBUSD(v_s1, data, ones);
				v_s2 = VDPBUSD(v_s2, data, mults);
				p += VL;
				n -= VL;
				mults = VADD8(mults, VSET1_8(-VL));
			}
			
		#if USE_AVX512
			data = VMASKZ_LOADU((mask_t)-1 >> (VL - n), p);
		#else
			data = zeroes;
			memcpy(&data, p, n);
		#endif
			v_s1 = VDPBUSD(v_s1, data, ones);
			v_s2 = VDPBUSD(v_s2, data, mults);
			p += n;
		}

		reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}
#else 
	
	while (len) {
		
		size_t n = MIN(len, MIN(2 * VL * (INT16_MAX / UINT8_MAX),
					MAX_CHUNK_LEN) & ~(2*VL - 1));
		len -= n;

		if (n >= 2*VL) {
			vec_t v_s1 = zeroes;
			vec_t v_s1_sums = zeroes;
			vec_t v_byte_sums_a = zeroes;
			vec_t v_byte_sums_b = zeroes;
			vec_t v_byte_sums_c = zeroes;
			vec_t v_byte_sums_d = zeroes;
			vec_t v_s2;

			s2 += s1 * (n & ~(2*VL - 1));

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);

				v_s1_sums = VADD32(v_s1_sums, v_s1);
				v_byte_sums_a = VADD16(v_byte_sums_a,
						       VUNPACKLO8(data_a, zeroes));
				v_byte_sums_b = VADD16(v_byte_sums_b,
						       VUNPACKHI8(data_a, zeroes));
				v_byte_sums_c = VADD16(v_byte_sums_c,
						       VUNPACKLO8(data_b, zeroes));
				v_byte_sums_d = VADD16(v_byte_sums_d,
						       VUNPACKHI8(data_b, zeroes));
				v_s1 = VADD32(v_s1,
					      VADD32(VSAD8(data_a, zeroes),
						     VSAD8(data_b, zeroes)));
				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+x" (v_s1), "+x" (v_s1_sums),
					     "+x" (v_byte_sums_a),
					     "+x" (v_byte_sums_b),
					     "+x" (v_byte_sums_c),
					     "+x" (v_byte_sums_d));
			#endif
				p += 2*VL;
				n -= 2*VL;
			} while (n >= 2*VL);

			
			v_s2 = VADD32_5X(VSLL32(v_s1_sums, LOG2_VL + 1),
					 VMADD16(v_byte_sums_a, mults_a),
					 VMADD16(v_byte_sums_b, mults_b),
					 VMADD16(v_byte_sums_c, mults_c),
					 VMADD16(v_byte_sums_d, mults_d));
			reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
#endif 
	return (s2 << 16) | s1;
}

#undef vec_t
#undef mask_t
#undef LOG2_VL
#undef VADD8
#undef VADD16
#undef VADD32
#undef VDPBUSD
#undef VLOAD
#undef VLOADU
#undef VMADD16
#undef VMASKZ_LOADU
#undef VMULLO32
#undef VSAD8
#undef VSET1_8
#undef VSET1_32
#undef VSETZERO
#undef VSLL32
#undef VUNPACKLO8
#undef VUNPACKHI8

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_VNNI
#undef USE_AVX512


#  define adler32_x86_avx2	adler32_x86_avx2
#  define SUFFIX			   _avx2
#  define ATTRIBUTES		_target_attribute("avx2")
#  define VL			32
#  define USE_VNNI		0
#  define USE_AVX512		0
/* #include "x86-adler32_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define mask_t		u16
#  define LOG2_VL		4
#  define VADD8(a, b)		_mm_add_epi8((a), (b))
#  define VADD16(a, b)		_mm_add_epi16((a), (b))
#  define VADD32(a, b)		_mm_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm_load_si128((const void *)(p))
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VMADD16(a, b)		_mm_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm_set1_epi8(a)
#  define VSET1_32(a)		_mm_set1_epi32(a)
#  define VSETZERO()		_mm_setzero_si128()
#  define VSLL32(a, b)		_mm_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm_unpackhi_epi8((a), (b))
#elif VL == 32
#  define vec_t			__m256i
#  define mask_t		u32
#  define LOG2_VL		5
#  define VADD8(a, b)		_mm256_add_epi8((a), (b))
#  define VADD16(a, b)		_mm256_add_epi16((a), (b))
#  define VADD32(a, b)		_mm256_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm256_load_si256((const void *)(p))
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VMADD16(a, b)		_mm256_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm256_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm256_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm256_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm256_set1_epi8(a)
#  define VSET1_32(a)		_mm256_set1_epi32(a)
#  define VSETZERO()		_mm256_setzero_si256()
#  define VSLL32(a, b)		_mm256_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm256_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm256_unpackhi_epi8((a), (b))
#elif VL == 64
#  define vec_t			__m512i
#  define mask_t		u64
#  define LOG2_VL		6
#  define VADD8(a, b)		_mm512_add_epi8((a), (b))
#  define VADD16(a, b)		_mm512_add_epi16((a), (b))
#  define VADD32(a, b)		_mm512_add_epi32((a), (b))
#  define VDPBUSD(a, b, c)	_mm512_dpbusd_epi32((a), (b), (c))
#  define VLOAD(p)		_mm512_load_si512((const void *)(p))
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VMADD16(a, b)		_mm512_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm512_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm512_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm512_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm512_set1_epi8(a)
#  define VSET1_32(a)		_mm512_set1_epi32(a)
#  define VSETZERO()		_mm512_setzero_si512()
#  define VSLL32(a, b)		_mm512_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm512_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm512_unpackhi_epi8((a), (b))
#else
#  error "unsupported vector length"
#endif

#define VADD32_3X(a, b, c)	VADD32(VADD32((a), (b)), (c))
#define VADD32_4X(a, b, c, d)	VADD32(VADD32((a), (b)), VADD32((c), (d)))
#define VADD32_5X(a, b, c, d, e) VADD32((a), VADD32_4X((b), (c), (d), (e)))
#define VADD32_7X(a, b, c, d, e, f, g)	\
	VADD32(VADD32_3X((a), (b), (c)), VADD32_4X((d), (e), (f), (g)))


#undef reduce_to_32bits
static forceinline ATTRIBUTES void
ADD_SUFFIX(reduce_to_32bits)(vec_t v_s1, vec_t v_s2, u32 *s1_p, u32 *s2_p)
{
	__m128i v_s1_128, v_s2_128;
#if VL == 16
	{
		v_s1_128 = v_s1;
		v_s2_128 = v_s2;
	}
#else
	{
		__m256i v_s1_256, v_s2_256;
	#if VL == 32
		v_s1_256 = v_s1;
		v_s2_256 = v_s2;
	#else
		
		v_s1_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s1, 0),
					    _mm512_extracti64x4_epi64(v_s1, 1));
		v_s2_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s2, 0),
					    _mm512_extracti64x4_epi64(v_s2, 1));
	#endif
		
		v_s1_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s1_256, 0),
					 _mm256_extracti128_si256(v_s1_256, 1));
		v_s2_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s2_256, 0),
					 _mm256_extracti128_si256(v_s2_256, 1));
	}
#endif

	
#if USE_VNNI
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x31));
#endif
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x31));
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x02));
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x02));

	*s1_p += (u32)_mm_cvtsi128_si32(v_s1_128);
	*s2_p += (u32)_mm_cvtsi128_si32(v_s2_128);
}
#define reduce_to_32bits	ADD_SUFFIX(reduce_to_32bits)

static ATTRIBUTES u32
ADD_SUFFIX(adler32_x86)(u32 adler, const u8 *p, size_t len)
{
#if USE_VNNI
	
	static const u8 _aligned_attribute(VL) raw_mults[VL] = {
	#if VL == 64
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
	#endif
	#if VL >= 32
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
	#endif
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const vec_t ones = VSET1_8(1);
#else
	
	static const u16 _aligned_attribute(VL) raw_mults[4][VL / 2] = {
	#if VL == 16
		{ 32, 31, 30, 29, 28, 27, 26, 25 },
		{ 24, 23, 22, 21, 20, 19, 18, 17 },
		{ 16, 15, 14, 13, 12, 11, 10, 9  },
		{ 8,  7,  6,  5,  4,  3,  2,  1  },
	#elif VL == 32
		{ 64, 63, 62, 61, 60, 59, 58, 57, 48, 47, 46, 45, 44, 43, 42, 41 },
		{ 56, 55, 54, 53, 52, 51, 50, 49, 40, 39, 38, 37, 36, 35, 34, 33 },
		{ 32, 31, 30, 29, 28, 27, 26, 25, 16, 15, 14, 13, 12, 11, 10,  9 },
		{ 24, 23, 22, 21, 20, 19, 18, 17,  8,  7,  6,  5,  4,  3,  2,  1 },
	#else
	#  error "unsupported parameters"
	#endif
	};
	const vec_t mults_a = VLOAD(raw_mults[0]);
	const vec_t mults_b = VLOAD(raw_mults[1]);
	const vec_t mults_c = VLOAD(raw_mults[2]);
	const vec_t mults_d = VLOAD(raw_mults[3]);
#endif
	const vec_t zeroes = VSETZERO();
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 65536 && ((uintptr_t)p & (VL-1)))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & (VL-1));
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

#if USE_VNNI
	
	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~(4*VL - 1));
		vec_t mults = VLOAD(raw_mults);
		vec_t v_s1 = zeroes;
		vec_t v_s2 = zeroes;

		s2 += s1 * n;
		len -= n;

		if (n >= 4*VL) {
			vec_t v_s1_b = zeroes;
			vec_t v_s1_c = zeroes;
			vec_t v_s1_d = zeroes;
			vec_t v_s2_b = zeroes;
			vec_t v_s2_c = zeroes;
			vec_t v_s2_d = zeroes;
			vec_t v_s1_sums   = zeroes;
			vec_t v_s1_sums_b = zeroes;
			vec_t v_s1_sums_c = zeroes;
			vec_t v_s1_sums_d = zeroes;
			vec_t tmp0, tmp1;

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);
				vec_t data_c = VLOADU(p + 2*VL);
				vec_t data_d = VLOADU(p + 3*VL);

				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+v" (data_a), "+v" (data_b),
					     "+v" (data_c), "+v" (data_d));
			#endif

				v_s2   = VDPBUSD(v_s2,   data_a, mults);
				v_s2_b = VDPBUSD(v_s2_b, data_b, mults);
				v_s2_c = VDPBUSD(v_s2_c, data_c, mults);
				v_s2_d = VDPBUSD(v_s2_d, data_d, mults);

				v_s1_sums   = VADD32(v_s1_sums,   v_s1);
				v_s1_sums_b = VADD32(v_s1_sums_b, v_s1_b);
				v_s1_sums_c = VADD32(v_s1_sums_c, v_s1_c);
				v_s1_sums_d = VADD32(v_s1_sums_d, v_s1_d);

				v_s1   = VDPBUSD(v_s1,   data_a, ones);
				v_s1_b = VDPBUSD(v_s1_b, data_b, ones);
				v_s1_c = VDPBUSD(v_s1_c, data_c, ones);
				v_s1_d = VDPBUSD(v_s1_d, data_d, ones);

				
			#if GCC_PREREQ(1, 0) && !defined(ARCH_X86_32)
				__asm__("" : "+v" (v_s2), "+v" (v_s2_b),
					     "+v" (v_s2_c), "+v" (v_s2_d),
					     "+v" (v_s1_sums),
					     "+v" (v_s1_sums_b),
					     "+v" (v_s1_sums_c),
					     "+v" (v_s1_sums_d),
					     "+v" (v_s1), "+v" (v_s1_b),
					     "+v" (v_s1_c), "+v" (v_s1_d));
			#endif
				p += 4*VL;
				n -= 4*VL;
			} while (n >= 4*VL);

			
			tmp0 = VADD32(v_s1, v_s1_b);
			tmp1 = VADD32(v_s1, v_s1_c);
			v_s1_sums = VADD32_4X(v_s1_sums, v_s1_sums_b,
					      v_s1_sums_c, v_s1_sums_d);
			v_s1 = VADD32_3X(tmp0, v_s1_c, v_s1_d);
			v_s2 = VADD32_7X(VSLL32(v_s1_sums, LOG2_VL + 2),
					 VSLL32(tmp0, LOG2_VL + 1),
					 VSLL32(tmp1, LOG2_VL),
					 v_s2, v_s2_b, v_s2_c, v_s2_d);
		}

		
		if (n >= 2*VL) {
			const vec_t data_a = VLOADU(p + 0*VL);
			const vec_t data_b = VLOADU(p + 1*VL);

			v_s2 = VADD32(v_s2, VSLL32(v_s1, LOG2_VL + 1));
			v_s1 = VDPBUSD(v_s1, data_a, ones);
			v_s1 = VDPBUSD(v_s1, data_b, ones);
			v_s2 = VDPBUSD(v_s2, data_a, VSET1_8(VL));
			v_s2 = VDPBUSD(v_s2, data_a, mults);
			v_s2 = VDPBUSD(v_s2, data_b, mults);
			p += 2*VL;
			n -= 2*VL;
		}
		if (n) {
			
			vec_t data;

			v_s2 = VADD32(v_s2, VMULLO32(v_s1, VSET1_32(n)));

			mults = VADD8(mults, VSET1_8((int)n - VL));
			if (n > VL) {
				data = VLOADU(p);
				v_s1 = VDPBUSD(v_s1, data, ones);
				v_s2 = VDPBUSD(v_s2, data, mults);
				p += VL;
				n -= VL;
				mults = VADD8(mults, VSET1_8(-VL));
			}
			
		#if USE_AVX512
			data = VMASKZ_LOADU((mask_t)-1 >> (VL - n), p);
		#else
			data = zeroes;
			memcpy(&data, p, n);
		#endif
			v_s1 = VDPBUSD(v_s1, data, ones);
			v_s2 = VDPBUSD(v_s2, data, mults);
			p += n;
		}

		reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}
#else 
	
	while (len) {
		
		size_t n = MIN(len, MIN(2 * VL * (INT16_MAX / UINT8_MAX),
					MAX_CHUNK_LEN) & ~(2*VL - 1));
		len -= n;

		if (n >= 2*VL) {
			vec_t v_s1 = zeroes;
			vec_t v_s1_sums = zeroes;
			vec_t v_byte_sums_a = zeroes;
			vec_t v_byte_sums_b = zeroes;
			vec_t v_byte_sums_c = zeroes;
			vec_t v_byte_sums_d = zeroes;
			vec_t v_s2;

			s2 += s1 * (n & ~(2*VL - 1));

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);

				v_s1_sums = VADD32(v_s1_sums, v_s1);
				v_byte_sums_a = VADD16(v_byte_sums_a,
						       VUNPACKLO8(data_a, zeroes));
				v_byte_sums_b = VADD16(v_byte_sums_b,
						       VUNPACKHI8(data_a, zeroes));
				v_byte_sums_c = VADD16(v_byte_sums_c,
						       VUNPACKLO8(data_b, zeroes));
				v_byte_sums_d = VADD16(v_byte_sums_d,
						       VUNPACKHI8(data_b, zeroes));
				v_s1 = VADD32(v_s1,
					      VADD32(VSAD8(data_a, zeroes),
						     VSAD8(data_b, zeroes)));
				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+x" (v_s1), "+x" (v_s1_sums),
					     "+x" (v_byte_sums_a),
					     "+x" (v_byte_sums_b),
					     "+x" (v_byte_sums_c),
					     "+x" (v_byte_sums_d));
			#endif
				p += 2*VL;
				n -= 2*VL;
			} while (n >= 2*VL);

			
			v_s2 = VADD32_5X(VSLL32(v_s1_sums, LOG2_VL + 1),
					 VMADD16(v_byte_sums_a, mults_a),
					 VMADD16(v_byte_sums_b, mults_b),
					 VMADD16(v_byte_sums_c, mults_c),
					 VMADD16(v_byte_sums_d, mults_d));
			reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
#endif 
	return (s2 << 16) | s1;
}

#undef vec_t
#undef mask_t
#undef LOG2_VL
#undef VADD8
#undef VADD16
#undef VADD32
#undef VDPBUSD
#undef VLOAD
#undef VLOADU
#undef VMADD16
#undef VMASKZ_LOADU
#undef VMULLO32
#undef VSAD8
#undef VSET1_8
#undef VSET1_32
#undef VSETZERO
#undef VSLL32
#undef VUNPACKLO8
#undef VUNPACKHI8

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_VNNI
#undef USE_AVX512

#endif


#if (GCC_PREREQ(12, 1) || CLANG_PREREQ(12, 0, 13000000) || MSVC_PREREQ(1930)) && \
	!defined(LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_AVX_VNNI)
#  define adler32_x86_avx2_vnni	adler32_x86_avx2_vnni
#  define SUFFIX			   _avx2_vnni
#  define ATTRIBUTES		_target_attribute("avx2,avxvnni")
#  define VL			32
#  define USE_VNNI		1
#  define USE_AVX512		0
/* #include "x86-adler32_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define mask_t		u16
#  define LOG2_VL		4
#  define VADD8(a, b)		_mm_add_epi8((a), (b))
#  define VADD16(a, b)		_mm_add_epi16((a), (b))
#  define VADD32(a, b)		_mm_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm_load_si128((const void *)(p))
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VMADD16(a, b)		_mm_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm_set1_epi8(a)
#  define VSET1_32(a)		_mm_set1_epi32(a)
#  define VSETZERO()		_mm_setzero_si128()
#  define VSLL32(a, b)		_mm_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm_unpackhi_epi8((a), (b))
#elif VL == 32
#  define vec_t			__m256i
#  define mask_t		u32
#  define LOG2_VL		5
#  define VADD8(a, b)		_mm256_add_epi8((a), (b))
#  define VADD16(a, b)		_mm256_add_epi16((a), (b))
#  define VADD32(a, b)		_mm256_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm256_load_si256((const void *)(p))
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VMADD16(a, b)		_mm256_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm256_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm256_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm256_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm256_set1_epi8(a)
#  define VSET1_32(a)		_mm256_set1_epi32(a)
#  define VSETZERO()		_mm256_setzero_si256()
#  define VSLL32(a, b)		_mm256_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm256_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm256_unpackhi_epi8((a), (b))
#elif VL == 64
#  define vec_t			__m512i
#  define mask_t		u64
#  define LOG2_VL		6
#  define VADD8(a, b)		_mm512_add_epi8((a), (b))
#  define VADD16(a, b)		_mm512_add_epi16((a), (b))
#  define VADD32(a, b)		_mm512_add_epi32((a), (b))
#  define VDPBUSD(a, b, c)	_mm512_dpbusd_epi32((a), (b), (c))
#  define VLOAD(p)		_mm512_load_si512((const void *)(p))
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VMADD16(a, b)		_mm512_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm512_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm512_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm512_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm512_set1_epi8(a)
#  define VSET1_32(a)		_mm512_set1_epi32(a)
#  define VSETZERO()		_mm512_setzero_si512()
#  define VSLL32(a, b)		_mm512_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm512_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm512_unpackhi_epi8((a), (b))
#else
#  error "unsupported vector length"
#endif

#define VADD32_3X(a, b, c)	VADD32(VADD32((a), (b)), (c))
#define VADD32_4X(a, b, c, d)	VADD32(VADD32((a), (b)), VADD32((c), (d)))
#define VADD32_5X(a, b, c, d, e) VADD32((a), VADD32_4X((b), (c), (d), (e)))
#define VADD32_7X(a, b, c, d, e, f, g)	\
	VADD32(VADD32_3X((a), (b), (c)), VADD32_4X((d), (e), (f), (g)))


#undef reduce_to_32bits
static forceinline ATTRIBUTES void
ADD_SUFFIX(reduce_to_32bits)(vec_t v_s1, vec_t v_s2, u32 *s1_p, u32 *s2_p)
{
	__m128i v_s1_128, v_s2_128;
#if VL == 16
	{
		v_s1_128 = v_s1;
		v_s2_128 = v_s2;
	}
#else
	{
		__m256i v_s1_256, v_s2_256;
	#if VL == 32
		v_s1_256 = v_s1;
		v_s2_256 = v_s2;
	#else
		
		v_s1_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s1, 0),
					    _mm512_extracti64x4_epi64(v_s1, 1));
		v_s2_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s2, 0),
					    _mm512_extracti64x4_epi64(v_s2, 1));
	#endif
		
		v_s1_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s1_256, 0),
					 _mm256_extracti128_si256(v_s1_256, 1));
		v_s2_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s2_256, 0),
					 _mm256_extracti128_si256(v_s2_256, 1));
	}
#endif

	
#if USE_VNNI
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x31));
#endif
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x31));
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x02));
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x02));

	*s1_p += (u32)_mm_cvtsi128_si32(v_s1_128);
	*s2_p += (u32)_mm_cvtsi128_si32(v_s2_128);
}
#define reduce_to_32bits	ADD_SUFFIX(reduce_to_32bits)

static ATTRIBUTES u32
ADD_SUFFIX(adler32_x86)(u32 adler, const u8 *p, size_t len)
{
#if USE_VNNI
	
	static const u8 _aligned_attribute(VL) raw_mults[VL] = {
	#if VL == 64
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
	#endif
	#if VL >= 32
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
	#endif
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const vec_t ones = VSET1_8(1);
#else
	
	static const u16 _aligned_attribute(VL) raw_mults[4][VL / 2] = {
	#if VL == 16
		{ 32, 31, 30, 29, 28, 27, 26, 25 },
		{ 24, 23, 22, 21, 20, 19, 18, 17 },
		{ 16, 15, 14, 13, 12, 11, 10, 9  },
		{ 8,  7,  6,  5,  4,  3,  2,  1  },
	#elif VL == 32
		{ 64, 63, 62, 61, 60, 59, 58, 57, 48, 47, 46, 45, 44, 43, 42, 41 },
		{ 56, 55, 54, 53, 52, 51, 50, 49, 40, 39, 38, 37, 36, 35, 34, 33 },
		{ 32, 31, 30, 29, 28, 27, 26, 25, 16, 15, 14, 13, 12, 11, 10,  9 },
		{ 24, 23, 22, 21, 20, 19, 18, 17,  8,  7,  6,  5,  4,  3,  2,  1 },
	#else
	#  error "unsupported parameters"
	#endif
	};
	const vec_t mults_a = VLOAD(raw_mults[0]);
	const vec_t mults_b = VLOAD(raw_mults[1]);
	const vec_t mults_c = VLOAD(raw_mults[2]);
	const vec_t mults_d = VLOAD(raw_mults[3]);
#endif
	const vec_t zeroes = VSETZERO();
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 65536 && ((uintptr_t)p & (VL-1)))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & (VL-1));
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

#if USE_VNNI
	
	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~(4*VL - 1));
		vec_t mults = VLOAD(raw_mults);
		vec_t v_s1 = zeroes;
		vec_t v_s2 = zeroes;

		s2 += s1 * n;
		len -= n;

		if (n >= 4*VL) {
			vec_t v_s1_b = zeroes;
			vec_t v_s1_c = zeroes;
			vec_t v_s1_d = zeroes;
			vec_t v_s2_b = zeroes;
			vec_t v_s2_c = zeroes;
			vec_t v_s2_d = zeroes;
			vec_t v_s1_sums   = zeroes;
			vec_t v_s1_sums_b = zeroes;
			vec_t v_s1_sums_c = zeroes;
			vec_t v_s1_sums_d = zeroes;
			vec_t tmp0, tmp1;

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);
				vec_t data_c = VLOADU(p + 2*VL);
				vec_t data_d = VLOADU(p + 3*VL);

				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+v" (data_a), "+v" (data_b),
					     "+v" (data_c), "+v" (data_d));
			#endif

				v_s2   = VDPBUSD(v_s2,   data_a, mults);
				v_s2_b = VDPBUSD(v_s2_b, data_b, mults);
				v_s2_c = VDPBUSD(v_s2_c, data_c, mults);
				v_s2_d = VDPBUSD(v_s2_d, data_d, mults);

				v_s1_sums   = VADD32(v_s1_sums,   v_s1);
				v_s1_sums_b = VADD32(v_s1_sums_b, v_s1_b);
				v_s1_sums_c = VADD32(v_s1_sums_c, v_s1_c);
				v_s1_sums_d = VADD32(v_s1_sums_d, v_s1_d);

				v_s1   = VDPBUSD(v_s1,   data_a, ones);
				v_s1_b = VDPBUSD(v_s1_b, data_b, ones);
				v_s1_c = VDPBUSD(v_s1_c, data_c, ones);
				v_s1_d = VDPBUSD(v_s1_d, data_d, ones);

				
			#if GCC_PREREQ(1, 0) && !defined(ARCH_X86_32)
				__asm__("" : "+v" (v_s2), "+v" (v_s2_b),
					     "+v" (v_s2_c), "+v" (v_s2_d),
					     "+v" (v_s1_sums),
					     "+v" (v_s1_sums_b),
					     "+v" (v_s1_sums_c),
					     "+v" (v_s1_sums_d),
					     "+v" (v_s1), "+v" (v_s1_b),
					     "+v" (v_s1_c), "+v" (v_s1_d));
			#endif
				p += 4*VL;
				n -= 4*VL;
			} while (n >= 4*VL);

			
			tmp0 = VADD32(v_s1, v_s1_b);
			tmp1 = VADD32(v_s1, v_s1_c);
			v_s1_sums = VADD32_4X(v_s1_sums, v_s1_sums_b,
					      v_s1_sums_c, v_s1_sums_d);
			v_s1 = VADD32_3X(tmp0, v_s1_c, v_s1_d);
			v_s2 = VADD32_7X(VSLL32(v_s1_sums, LOG2_VL + 2),
					 VSLL32(tmp0, LOG2_VL + 1),
					 VSLL32(tmp1, LOG2_VL),
					 v_s2, v_s2_b, v_s2_c, v_s2_d);
		}

		
		if (n >= 2*VL) {
			const vec_t data_a = VLOADU(p + 0*VL);
			const vec_t data_b = VLOADU(p + 1*VL);

			v_s2 = VADD32(v_s2, VSLL32(v_s1, LOG2_VL + 1));
			v_s1 = VDPBUSD(v_s1, data_a, ones);
			v_s1 = VDPBUSD(v_s1, data_b, ones);
			v_s2 = VDPBUSD(v_s2, data_a, VSET1_8(VL));
			v_s2 = VDPBUSD(v_s2, data_a, mults);
			v_s2 = VDPBUSD(v_s2, data_b, mults);
			p += 2*VL;
			n -= 2*VL;
		}
		if (n) {
			
			vec_t data;

			v_s2 = VADD32(v_s2, VMULLO32(v_s1, VSET1_32(n)));

			mults = VADD8(mults, VSET1_8((int)n - VL));
			if (n > VL) {
				data = VLOADU(p);
				v_s1 = VDPBUSD(v_s1, data, ones);
				v_s2 = VDPBUSD(v_s2, data, mults);
				p += VL;
				n -= VL;
				mults = VADD8(mults, VSET1_8(-VL));
			}
			
		#if USE_AVX512
			data = VMASKZ_LOADU((mask_t)-1 >> (VL - n), p);
		#else
			data = zeroes;
			memcpy(&data, p, n);
		#endif
			v_s1 = VDPBUSD(v_s1, data, ones);
			v_s2 = VDPBUSD(v_s2, data, mults);
			p += n;
		}

		reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}
#else 
	
	while (len) {
		
		size_t n = MIN(len, MIN(2 * VL * (INT16_MAX / UINT8_MAX),
					MAX_CHUNK_LEN) & ~(2*VL - 1));
		len -= n;

		if (n >= 2*VL) {
			vec_t v_s1 = zeroes;
			vec_t v_s1_sums = zeroes;
			vec_t v_byte_sums_a = zeroes;
			vec_t v_byte_sums_b = zeroes;
			vec_t v_byte_sums_c = zeroes;
			vec_t v_byte_sums_d = zeroes;
			vec_t v_s2;

			s2 += s1 * (n & ~(2*VL - 1));

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);

				v_s1_sums = VADD32(v_s1_sums, v_s1);
				v_byte_sums_a = VADD16(v_byte_sums_a,
						       VUNPACKLO8(data_a, zeroes));
				v_byte_sums_b = VADD16(v_byte_sums_b,
						       VUNPACKHI8(data_a, zeroes));
				v_byte_sums_c = VADD16(v_byte_sums_c,
						       VUNPACKLO8(data_b, zeroes));
				v_byte_sums_d = VADD16(v_byte_sums_d,
						       VUNPACKHI8(data_b, zeroes));
				v_s1 = VADD32(v_s1,
					      VADD32(VSAD8(data_a, zeroes),
						     VSAD8(data_b, zeroes)));
				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+x" (v_s1), "+x" (v_s1_sums),
					     "+x" (v_byte_sums_a),
					     "+x" (v_byte_sums_b),
					     "+x" (v_byte_sums_c),
					     "+x" (v_byte_sums_d));
			#endif
				p += 2*VL;
				n -= 2*VL;
			} while (n >= 2*VL);

			
			v_s2 = VADD32_5X(VSLL32(v_s1_sums, LOG2_VL + 1),
					 VMADD16(v_byte_sums_a, mults_a),
					 VMADD16(v_byte_sums_b, mults_b),
					 VMADD16(v_byte_sums_c, mults_c),
					 VMADD16(v_byte_sums_d, mults_d));
			reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
#endif 
	return (s2 << 16) | s1;
}

#undef vec_t
#undef mask_t
#undef LOG2_VL
#undef VADD8
#undef VADD16
#undef VADD32
#undef VDPBUSD
#undef VLOAD
#undef VLOADU
#undef VMADD16
#undef VMASKZ_LOADU
#undef VMULLO32
#undef VSAD8
#undef VSET1_8
#undef VSET1_32
#undef VSETZERO
#undef VSLL32
#undef VUNPACKLO8
#undef VUNPACKHI8

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_VNNI
#undef USE_AVX512

#endif

#if (GCC_PREREQ(8, 1) || CLANG_PREREQ(6, 0, 10000000) || MSVC_PREREQ(1920)) && \
	!defined(LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_AVX512VNNI)

#  define adler32_x86_avx512_vl256_vnni	adler32_x86_avx512_vl256_vnni
#  define SUFFIX				   _avx512_vl256_vnni
#  define ATTRIBUTES		_target_attribute("avx512bw,avx512vl,avx512vnni" NO_EVEX512)
#  define VL			32
#  define USE_VNNI		1
#  define USE_AVX512		1
/* #include "x86-adler32_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define mask_t		u16
#  define LOG2_VL		4
#  define VADD8(a, b)		_mm_add_epi8((a), (b))
#  define VADD16(a, b)		_mm_add_epi16((a), (b))
#  define VADD32(a, b)		_mm_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm_load_si128((const void *)(p))
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VMADD16(a, b)		_mm_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm_set1_epi8(a)
#  define VSET1_32(a)		_mm_set1_epi32(a)
#  define VSETZERO()		_mm_setzero_si128()
#  define VSLL32(a, b)		_mm_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm_unpackhi_epi8((a), (b))
#elif VL == 32
#  define vec_t			__m256i
#  define mask_t		u32
#  define LOG2_VL		5
#  define VADD8(a, b)		_mm256_add_epi8((a), (b))
#  define VADD16(a, b)		_mm256_add_epi16((a), (b))
#  define VADD32(a, b)		_mm256_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm256_load_si256((const void *)(p))
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VMADD16(a, b)		_mm256_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm256_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm256_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm256_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm256_set1_epi8(a)
#  define VSET1_32(a)		_mm256_set1_epi32(a)
#  define VSETZERO()		_mm256_setzero_si256()
#  define VSLL32(a, b)		_mm256_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm256_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm256_unpackhi_epi8((a), (b))
#elif VL == 64
#  define vec_t			__m512i
#  define mask_t		u64
#  define LOG2_VL		6
#  define VADD8(a, b)		_mm512_add_epi8((a), (b))
#  define VADD16(a, b)		_mm512_add_epi16((a), (b))
#  define VADD32(a, b)		_mm512_add_epi32((a), (b))
#  define VDPBUSD(a, b, c)	_mm512_dpbusd_epi32((a), (b), (c))
#  define VLOAD(p)		_mm512_load_si512((const void *)(p))
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VMADD16(a, b)		_mm512_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm512_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm512_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm512_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm512_set1_epi8(a)
#  define VSET1_32(a)		_mm512_set1_epi32(a)
#  define VSETZERO()		_mm512_setzero_si512()
#  define VSLL32(a, b)		_mm512_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm512_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm512_unpackhi_epi8((a), (b))
#else
#  error "unsupported vector length"
#endif

#define VADD32_3X(a, b, c)	VADD32(VADD32((a), (b)), (c))
#define VADD32_4X(a, b, c, d)	VADD32(VADD32((a), (b)), VADD32((c), (d)))
#define VADD32_5X(a, b, c, d, e) VADD32((a), VADD32_4X((b), (c), (d), (e)))
#define VADD32_7X(a, b, c, d, e, f, g)	\
	VADD32(VADD32_3X((a), (b), (c)), VADD32_4X((d), (e), (f), (g)))


#undef reduce_to_32bits
static forceinline ATTRIBUTES void
ADD_SUFFIX(reduce_to_32bits)(vec_t v_s1, vec_t v_s2, u32 *s1_p, u32 *s2_p)
{
	__m128i v_s1_128, v_s2_128;
#if VL == 16
	{
		v_s1_128 = v_s1;
		v_s2_128 = v_s2;
	}
#else
	{
		__m256i v_s1_256, v_s2_256;
	#if VL == 32
		v_s1_256 = v_s1;
		v_s2_256 = v_s2;
	#else
		
		v_s1_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s1, 0),
					    _mm512_extracti64x4_epi64(v_s1, 1));
		v_s2_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s2, 0),
					    _mm512_extracti64x4_epi64(v_s2, 1));
	#endif
		
		v_s1_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s1_256, 0),
					 _mm256_extracti128_si256(v_s1_256, 1));
		v_s2_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s2_256, 0),
					 _mm256_extracti128_si256(v_s2_256, 1));
	}
#endif

	
#if USE_VNNI
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x31));
#endif
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x31));
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x02));
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x02));

	*s1_p += (u32)_mm_cvtsi128_si32(v_s1_128);
	*s2_p += (u32)_mm_cvtsi128_si32(v_s2_128);
}
#define reduce_to_32bits	ADD_SUFFIX(reduce_to_32bits)

static ATTRIBUTES u32
ADD_SUFFIX(adler32_x86)(u32 adler, const u8 *p, size_t len)
{
#if USE_VNNI
	
	static const u8 _aligned_attribute(VL) raw_mults[VL] = {
	#if VL == 64
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
	#endif
	#if VL >= 32
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
	#endif
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const vec_t ones = VSET1_8(1);
#else
	
	static const u16 _aligned_attribute(VL) raw_mults[4][VL / 2] = {
	#if VL == 16
		{ 32, 31, 30, 29, 28, 27, 26, 25 },
		{ 24, 23, 22, 21, 20, 19, 18, 17 },
		{ 16, 15, 14, 13, 12, 11, 10, 9  },
		{ 8,  7,  6,  5,  4,  3,  2,  1  },
	#elif VL == 32
		{ 64, 63, 62, 61, 60, 59, 58, 57, 48, 47, 46, 45, 44, 43, 42, 41 },
		{ 56, 55, 54, 53, 52, 51, 50, 49, 40, 39, 38, 37, 36, 35, 34, 33 },
		{ 32, 31, 30, 29, 28, 27, 26, 25, 16, 15, 14, 13, 12, 11, 10,  9 },
		{ 24, 23, 22, 21, 20, 19, 18, 17,  8,  7,  6,  5,  4,  3,  2,  1 },
	#else
	#  error "unsupported parameters"
	#endif
	};
	const vec_t mults_a = VLOAD(raw_mults[0]);
	const vec_t mults_b = VLOAD(raw_mults[1]);
	const vec_t mults_c = VLOAD(raw_mults[2]);
	const vec_t mults_d = VLOAD(raw_mults[3]);
#endif
	const vec_t zeroes = VSETZERO();
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 65536 && ((uintptr_t)p & (VL-1)))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & (VL-1));
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

#if USE_VNNI
	
	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~(4*VL - 1));
		vec_t mults = VLOAD(raw_mults);
		vec_t v_s1 = zeroes;
		vec_t v_s2 = zeroes;

		s2 += s1 * n;
		len -= n;

		if (n >= 4*VL) {
			vec_t v_s1_b = zeroes;
			vec_t v_s1_c = zeroes;
			vec_t v_s1_d = zeroes;
			vec_t v_s2_b = zeroes;
			vec_t v_s2_c = zeroes;
			vec_t v_s2_d = zeroes;
			vec_t v_s1_sums   = zeroes;
			vec_t v_s1_sums_b = zeroes;
			vec_t v_s1_sums_c = zeroes;
			vec_t v_s1_sums_d = zeroes;
			vec_t tmp0, tmp1;

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);
				vec_t data_c = VLOADU(p + 2*VL);
				vec_t data_d = VLOADU(p + 3*VL);

				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+v" (data_a), "+v" (data_b),
					     "+v" (data_c), "+v" (data_d));
			#endif

				v_s2   = VDPBUSD(v_s2,   data_a, mults);
				v_s2_b = VDPBUSD(v_s2_b, data_b, mults);
				v_s2_c = VDPBUSD(v_s2_c, data_c, mults);
				v_s2_d = VDPBUSD(v_s2_d, data_d, mults);

				v_s1_sums   = VADD32(v_s1_sums,   v_s1);
				v_s1_sums_b = VADD32(v_s1_sums_b, v_s1_b);
				v_s1_sums_c = VADD32(v_s1_sums_c, v_s1_c);
				v_s1_sums_d = VADD32(v_s1_sums_d, v_s1_d);

				v_s1   = VDPBUSD(v_s1,   data_a, ones);
				v_s1_b = VDPBUSD(v_s1_b, data_b, ones);
				v_s1_c = VDPBUSD(v_s1_c, data_c, ones);
				v_s1_d = VDPBUSD(v_s1_d, data_d, ones);

				
			#if GCC_PREREQ(1, 0) && !defined(ARCH_X86_32)
				__asm__("" : "+v" (v_s2), "+v" (v_s2_b),
					     "+v" (v_s2_c), "+v" (v_s2_d),
					     "+v" (v_s1_sums),
					     "+v" (v_s1_sums_b),
					     "+v" (v_s1_sums_c),
					     "+v" (v_s1_sums_d),
					     "+v" (v_s1), "+v" (v_s1_b),
					     "+v" (v_s1_c), "+v" (v_s1_d));
			#endif
				p += 4*VL;
				n -= 4*VL;
			} while (n >= 4*VL);

			
			tmp0 = VADD32(v_s1, v_s1_b);
			tmp1 = VADD32(v_s1, v_s1_c);
			v_s1_sums = VADD32_4X(v_s1_sums, v_s1_sums_b,
					      v_s1_sums_c, v_s1_sums_d);
			v_s1 = VADD32_3X(tmp0, v_s1_c, v_s1_d);
			v_s2 = VADD32_7X(VSLL32(v_s1_sums, LOG2_VL + 2),
					 VSLL32(tmp0, LOG2_VL + 1),
					 VSLL32(tmp1, LOG2_VL),
					 v_s2, v_s2_b, v_s2_c, v_s2_d);
		}

		
		if (n >= 2*VL) {
			const vec_t data_a = VLOADU(p + 0*VL);
			const vec_t data_b = VLOADU(p + 1*VL);

			v_s2 = VADD32(v_s2, VSLL32(v_s1, LOG2_VL + 1));
			v_s1 = VDPBUSD(v_s1, data_a, ones);
			v_s1 = VDPBUSD(v_s1, data_b, ones);
			v_s2 = VDPBUSD(v_s2, data_a, VSET1_8(VL));
			v_s2 = VDPBUSD(v_s2, data_a, mults);
			v_s2 = VDPBUSD(v_s2, data_b, mults);
			p += 2*VL;
			n -= 2*VL;
		}
		if (n) {
			
			vec_t data;

			v_s2 = VADD32(v_s2, VMULLO32(v_s1, VSET1_32(n)));

			mults = VADD8(mults, VSET1_8((int)n - VL));
			if (n > VL) {
				data = VLOADU(p);
				v_s1 = VDPBUSD(v_s1, data, ones);
				v_s2 = VDPBUSD(v_s2, data, mults);
				p += VL;
				n -= VL;
				mults = VADD8(mults, VSET1_8(-VL));
			}
			
		#if USE_AVX512
			data = VMASKZ_LOADU((mask_t)-1 >> (VL - n), p);
		#else
			data = zeroes;
			memcpy(&data, p, n);
		#endif
			v_s1 = VDPBUSD(v_s1, data, ones);
			v_s2 = VDPBUSD(v_s2, data, mults);
			p += n;
		}

		reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}
#else 
	
	while (len) {
		
		size_t n = MIN(len, MIN(2 * VL * (INT16_MAX / UINT8_MAX),
					MAX_CHUNK_LEN) & ~(2*VL - 1));
		len -= n;

		if (n >= 2*VL) {
			vec_t v_s1 = zeroes;
			vec_t v_s1_sums = zeroes;
			vec_t v_byte_sums_a = zeroes;
			vec_t v_byte_sums_b = zeroes;
			vec_t v_byte_sums_c = zeroes;
			vec_t v_byte_sums_d = zeroes;
			vec_t v_s2;

			s2 += s1 * (n & ~(2*VL - 1));

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);

				v_s1_sums = VADD32(v_s1_sums, v_s1);
				v_byte_sums_a = VADD16(v_byte_sums_a,
						       VUNPACKLO8(data_a, zeroes));
				v_byte_sums_b = VADD16(v_byte_sums_b,
						       VUNPACKHI8(data_a, zeroes));
				v_byte_sums_c = VADD16(v_byte_sums_c,
						       VUNPACKLO8(data_b, zeroes));
				v_byte_sums_d = VADD16(v_byte_sums_d,
						       VUNPACKHI8(data_b, zeroes));
				v_s1 = VADD32(v_s1,
					      VADD32(VSAD8(data_a, zeroes),
						     VSAD8(data_b, zeroes)));
				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+x" (v_s1), "+x" (v_s1_sums),
					     "+x" (v_byte_sums_a),
					     "+x" (v_byte_sums_b),
					     "+x" (v_byte_sums_c),
					     "+x" (v_byte_sums_d));
			#endif
				p += 2*VL;
				n -= 2*VL;
			} while (n >= 2*VL);

			
			v_s2 = VADD32_5X(VSLL32(v_s1_sums, LOG2_VL + 1),
					 VMADD16(v_byte_sums_a, mults_a),
					 VMADD16(v_byte_sums_b, mults_b),
					 VMADD16(v_byte_sums_c, mults_c),
					 VMADD16(v_byte_sums_d, mults_d));
			reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
#endif 
	return (s2 << 16) | s1;
}

#undef vec_t
#undef mask_t
#undef LOG2_VL
#undef VADD8
#undef VADD16
#undef VADD32
#undef VDPBUSD
#undef VLOAD
#undef VLOADU
#undef VMADD16
#undef VMASKZ_LOADU
#undef VMULLO32
#undef VSAD8
#undef VSET1_8
#undef VSET1_32
#undef VSETZERO
#undef VSLL32
#undef VUNPACKLO8
#undef VUNPACKHI8

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_VNNI
#undef USE_AVX512



#  define adler32_x86_avx512_vl512_vnni	adler32_x86_avx512_vl512_vnni
#  define SUFFIX				   _avx512_vl512_vnni
#  define ATTRIBUTES		_target_attribute("avx512bw,avx512vnni" EVEX512)
#  define VL			64
#  define USE_VNNI		1
#  define USE_AVX512		1
/* #include "x86-adler32_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define mask_t		u16
#  define LOG2_VL		4
#  define VADD8(a, b)		_mm_add_epi8((a), (b))
#  define VADD16(a, b)		_mm_add_epi16((a), (b))
#  define VADD32(a, b)		_mm_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm_load_si128((const void *)(p))
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VMADD16(a, b)		_mm_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm_set1_epi8(a)
#  define VSET1_32(a)		_mm_set1_epi32(a)
#  define VSETZERO()		_mm_setzero_si128()
#  define VSLL32(a, b)		_mm_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm_unpackhi_epi8((a), (b))
#elif VL == 32
#  define vec_t			__m256i
#  define mask_t		u32
#  define LOG2_VL		5
#  define VADD8(a, b)		_mm256_add_epi8((a), (b))
#  define VADD16(a, b)		_mm256_add_epi16((a), (b))
#  define VADD32(a, b)		_mm256_add_epi32((a), (b))
#  if USE_AVX512
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_epi32((a), (b), (c))
#  else
#    define VDPBUSD(a, b, c)	_mm256_dpbusd_avx_epi32((a), (b), (c))
#  endif
#  define VLOAD(p)		_mm256_load_si256((const void *)(p))
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VMADD16(a, b)		_mm256_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm256_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm256_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm256_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm256_set1_epi8(a)
#  define VSET1_32(a)		_mm256_set1_epi32(a)
#  define VSETZERO()		_mm256_setzero_si256()
#  define VSLL32(a, b)		_mm256_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm256_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm256_unpackhi_epi8((a), (b))
#elif VL == 64
#  define vec_t			__m512i
#  define mask_t		u64
#  define LOG2_VL		6
#  define VADD8(a, b)		_mm512_add_epi8((a), (b))
#  define VADD16(a, b)		_mm512_add_epi16((a), (b))
#  define VADD32(a, b)		_mm512_add_epi32((a), (b))
#  define VDPBUSD(a, b, c)	_mm512_dpbusd_epi32((a), (b), (c))
#  define VLOAD(p)		_mm512_load_si512((const void *)(p))
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VMADD16(a, b)		_mm512_madd_epi16((a), (b))
#  define VMASKZ_LOADU(mask, p) _mm512_maskz_loadu_epi8((mask), (p))
#  define VMULLO32(a, b)	_mm512_mullo_epi32((a), (b))
#  define VSAD8(a, b)		_mm512_sad_epu8((a), (b))
#  define VSET1_8(a)		_mm512_set1_epi8(a)
#  define VSET1_32(a)		_mm512_set1_epi32(a)
#  define VSETZERO()		_mm512_setzero_si512()
#  define VSLL32(a, b)		_mm512_slli_epi32((a), (b))
#  define VUNPACKLO8(a, b)	_mm512_unpacklo_epi8((a), (b))
#  define VUNPACKHI8(a, b)	_mm512_unpackhi_epi8((a), (b))
#else
#  error "unsupported vector length"
#endif

#define VADD32_3X(a, b, c)	VADD32(VADD32((a), (b)), (c))
#define VADD32_4X(a, b, c, d)	VADD32(VADD32((a), (b)), VADD32((c), (d)))
#define VADD32_5X(a, b, c, d, e) VADD32((a), VADD32_4X((b), (c), (d), (e)))
#define VADD32_7X(a, b, c, d, e, f, g)	\
	VADD32(VADD32_3X((a), (b), (c)), VADD32_4X((d), (e), (f), (g)))


#undef reduce_to_32bits
static forceinline ATTRIBUTES void
ADD_SUFFIX(reduce_to_32bits)(vec_t v_s1, vec_t v_s2, u32 *s1_p, u32 *s2_p)
{
	__m128i v_s1_128, v_s2_128;
#if VL == 16
	{
		v_s1_128 = v_s1;
		v_s2_128 = v_s2;
	}
#else
	{
		__m256i v_s1_256, v_s2_256;
	#if VL == 32
		v_s1_256 = v_s1;
		v_s2_256 = v_s2;
	#else
		
		v_s1_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s1, 0),
					    _mm512_extracti64x4_epi64(v_s1, 1));
		v_s2_256 = _mm256_add_epi32(_mm512_extracti64x4_epi64(v_s2, 0),
					    _mm512_extracti64x4_epi64(v_s2, 1));
	#endif
		
		v_s1_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s1_256, 0),
					 _mm256_extracti128_si256(v_s1_256, 1));
		v_s2_128 = _mm_add_epi32(_mm256_extracti128_si256(v_s2_256, 0),
					 _mm256_extracti128_si256(v_s2_256, 1));
	}
#endif

	
#if USE_VNNI
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x31));
#endif
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x31));
	v_s1_128 = _mm_add_epi32(v_s1_128, _mm_shuffle_epi32(v_s1_128, 0x02));
	v_s2_128 = _mm_add_epi32(v_s2_128, _mm_shuffle_epi32(v_s2_128, 0x02));

	*s1_p += (u32)_mm_cvtsi128_si32(v_s1_128);
	*s2_p += (u32)_mm_cvtsi128_si32(v_s2_128);
}
#define reduce_to_32bits	ADD_SUFFIX(reduce_to_32bits)

static ATTRIBUTES u32
ADD_SUFFIX(adler32_x86)(u32 adler, const u8 *p, size_t len)
{
#if USE_VNNI
	
	static const u8 _aligned_attribute(VL) raw_mults[VL] = {
	#if VL == 64
		64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49,
		48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33,
	#endif
	#if VL >= 32
		32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17,
	#endif
		16, 15, 14, 13, 12, 11, 10,  9,  8,  7,  6,  5,  4,  3,  2,  1,
	};
	const vec_t ones = VSET1_8(1);
#else
	
	static const u16 _aligned_attribute(VL) raw_mults[4][VL / 2] = {
	#if VL == 16
		{ 32, 31, 30, 29, 28, 27, 26, 25 },
		{ 24, 23, 22, 21, 20, 19, 18, 17 },
		{ 16, 15, 14, 13, 12, 11, 10, 9  },
		{ 8,  7,  6,  5,  4,  3,  2,  1  },
	#elif VL == 32
		{ 64, 63, 62, 61, 60, 59, 58, 57, 48, 47, 46, 45, 44, 43, 42, 41 },
		{ 56, 55, 54, 53, 52, 51, 50, 49, 40, 39, 38, 37, 36, 35, 34, 33 },
		{ 32, 31, 30, 29, 28, 27, 26, 25, 16, 15, 14, 13, 12, 11, 10,  9 },
		{ 24, 23, 22, 21, 20, 19, 18, 17,  8,  7,  6,  5,  4,  3,  2,  1 },
	#else
	#  error "unsupported parameters"
	#endif
	};
	const vec_t mults_a = VLOAD(raw_mults[0]);
	const vec_t mults_b = VLOAD(raw_mults[1]);
	const vec_t mults_c = VLOAD(raw_mults[2]);
	const vec_t mults_d = VLOAD(raw_mults[3]);
#endif
	const vec_t zeroes = VSETZERO();
	u32 s1 = adler & 0xFFFF;
	u32 s2 = adler >> 16;

	
	if (unlikely(len > 65536 && ((uintptr_t)p & (VL-1)))) {
		do {
			s1 += *p++;
			s2 += s1;
			len--;
		} while ((uintptr_t)p & (VL-1));
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}

#if USE_VNNI
	
	while (len) {
		
		size_t n = MIN(len, MAX_CHUNK_LEN & ~(4*VL - 1));
		vec_t mults = VLOAD(raw_mults);
		vec_t v_s1 = zeroes;
		vec_t v_s2 = zeroes;

		s2 += s1 * n;
		len -= n;

		if (n >= 4*VL) {
			vec_t v_s1_b = zeroes;
			vec_t v_s1_c = zeroes;
			vec_t v_s1_d = zeroes;
			vec_t v_s2_b = zeroes;
			vec_t v_s2_c = zeroes;
			vec_t v_s2_d = zeroes;
			vec_t v_s1_sums   = zeroes;
			vec_t v_s1_sums_b = zeroes;
			vec_t v_s1_sums_c = zeroes;
			vec_t v_s1_sums_d = zeroes;
			vec_t tmp0, tmp1;

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);
				vec_t data_c = VLOADU(p + 2*VL);
				vec_t data_d = VLOADU(p + 3*VL);

				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+v" (data_a), "+v" (data_b),
					     "+v" (data_c), "+v" (data_d));
			#endif

				v_s2   = VDPBUSD(v_s2,   data_a, mults);
				v_s2_b = VDPBUSD(v_s2_b, data_b, mults);
				v_s2_c = VDPBUSD(v_s2_c, data_c, mults);
				v_s2_d = VDPBUSD(v_s2_d, data_d, mults);

				v_s1_sums   = VADD32(v_s1_sums,   v_s1);
				v_s1_sums_b = VADD32(v_s1_sums_b, v_s1_b);
				v_s1_sums_c = VADD32(v_s1_sums_c, v_s1_c);
				v_s1_sums_d = VADD32(v_s1_sums_d, v_s1_d);

				v_s1   = VDPBUSD(v_s1,   data_a, ones);
				v_s1_b = VDPBUSD(v_s1_b, data_b, ones);
				v_s1_c = VDPBUSD(v_s1_c, data_c, ones);
				v_s1_d = VDPBUSD(v_s1_d, data_d, ones);

				
			#if GCC_PREREQ(1, 0) && !defined(ARCH_X86_32)
				__asm__("" : "+v" (v_s2), "+v" (v_s2_b),
					     "+v" (v_s2_c), "+v" (v_s2_d),
					     "+v" (v_s1_sums),
					     "+v" (v_s1_sums_b),
					     "+v" (v_s1_sums_c),
					     "+v" (v_s1_sums_d),
					     "+v" (v_s1), "+v" (v_s1_b),
					     "+v" (v_s1_c), "+v" (v_s1_d));
			#endif
				p += 4*VL;
				n -= 4*VL;
			} while (n >= 4*VL);

			
			tmp0 = VADD32(v_s1, v_s1_b);
			tmp1 = VADD32(v_s1, v_s1_c);
			v_s1_sums = VADD32_4X(v_s1_sums, v_s1_sums_b,
					      v_s1_sums_c, v_s1_sums_d);
			v_s1 = VADD32_3X(tmp0, v_s1_c, v_s1_d);
			v_s2 = VADD32_7X(VSLL32(v_s1_sums, LOG2_VL + 2),
					 VSLL32(tmp0, LOG2_VL + 1),
					 VSLL32(tmp1, LOG2_VL),
					 v_s2, v_s2_b, v_s2_c, v_s2_d);
		}

		
		if (n >= 2*VL) {
			const vec_t data_a = VLOADU(p + 0*VL);
			const vec_t data_b = VLOADU(p + 1*VL);

			v_s2 = VADD32(v_s2, VSLL32(v_s1, LOG2_VL + 1));
			v_s1 = VDPBUSD(v_s1, data_a, ones);
			v_s1 = VDPBUSD(v_s1, data_b, ones);
			v_s2 = VDPBUSD(v_s2, data_a, VSET1_8(VL));
			v_s2 = VDPBUSD(v_s2, data_a, mults);
			v_s2 = VDPBUSD(v_s2, data_b, mults);
			p += 2*VL;
			n -= 2*VL;
		}
		if (n) {
			
			vec_t data;

			v_s2 = VADD32(v_s2, VMULLO32(v_s1, VSET1_32(n)));

			mults = VADD8(mults, VSET1_8((int)n - VL));
			if (n > VL) {
				data = VLOADU(p);
				v_s1 = VDPBUSD(v_s1, data, ones);
				v_s2 = VDPBUSD(v_s2, data, mults);
				p += VL;
				n -= VL;
				mults = VADD8(mults, VSET1_8(-VL));
			}
			
		#if USE_AVX512
			data = VMASKZ_LOADU((mask_t)-1 >> (VL - n), p);
		#else
			data = zeroes;
			memcpy(&data, p, n);
		#endif
			v_s1 = VDPBUSD(v_s1, data, ones);
			v_s2 = VDPBUSD(v_s2, data, mults);
			p += n;
		}

		reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		s1 %= DIVISOR;
		s2 %= DIVISOR;
	}
#else 
	
	while (len) {
		
		size_t n = MIN(len, MIN(2 * VL * (INT16_MAX / UINT8_MAX),
					MAX_CHUNK_LEN) & ~(2*VL - 1));
		len -= n;

		if (n >= 2*VL) {
			vec_t v_s1 = zeroes;
			vec_t v_s1_sums = zeroes;
			vec_t v_byte_sums_a = zeroes;
			vec_t v_byte_sums_b = zeroes;
			vec_t v_byte_sums_c = zeroes;
			vec_t v_byte_sums_d = zeroes;
			vec_t v_s2;

			s2 += s1 * (n & ~(2*VL - 1));

			do {
				vec_t data_a = VLOADU(p + 0*VL);
				vec_t data_b = VLOADU(p + 1*VL);

				v_s1_sums = VADD32(v_s1_sums, v_s1);
				v_byte_sums_a = VADD16(v_byte_sums_a,
						       VUNPACKLO8(data_a, zeroes));
				v_byte_sums_b = VADD16(v_byte_sums_b,
						       VUNPACKHI8(data_a, zeroes));
				v_byte_sums_c = VADD16(v_byte_sums_c,
						       VUNPACKLO8(data_b, zeroes));
				v_byte_sums_d = VADD16(v_byte_sums_d,
						       VUNPACKHI8(data_b, zeroes));
				v_s1 = VADD32(v_s1,
					      VADD32(VSAD8(data_a, zeroes),
						     VSAD8(data_b, zeroes)));
				
			#if GCC_PREREQ(1, 0)
				__asm__("" : "+x" (v_s1), "+x" (v_s1_sums),
					     "+x" (v_byte_sums_a),
					     "+x" (v_byte_sums_b),
					     "+x" (v_byte_sums_c),
					     "+x" (v_byte_sums_d));
			#endif
				p += 2*VL;
				n -= 2*VL;
			} while (n >= 2*VL);

			
			v_s2 = VADD32_5X(VSLL32(v_s1_sums, LOG2_VL + 1),
					 VMADD16(v_byte_sums_a, mults_a),
					 VMADD16(v_byte_sums_b, mults_b),
					 VMADD16(v_byte_sums_c, mults_c),
					 VMADD16(v_byte_sums_d, mults_d));
			reduce_to_32bits(v_s1, v_s2, &s1, &s2);
		}
		
		ADLER32_CHUNK(s1, s2, p, n);
	}
#endif 
	return (s2 << 16) | s1;
}

#undef vec_t
#undef mask_t
#undef LOG2_VL
#undef VADD8
#undef VADD16
#undef VADD32
#undef VDPBUSD
#undef VLOAD
#undef VLOADU
#undef VMADD16
#undef VMASKZ_LOADU
#undef VMULLO32
#undef VSAD8
#undef VSET1_8
#undef VSET1_32
#undef VSETZERO
#undef VSLL32
#undef VUNPACKLO8
#undef VUNPACKHI8

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_VNNI
#undef USE_AVX512

#endif

static inline adler32_func_t
arch_select_adler32_func(void)
{
	const u32 features MAYBE_UNUSED = get_x86_cpu_features();

#ifdef adler32_x86_avx512_vl512_vnni
	if ((features & X86_CPU_FEATURE_ZMM) &&
	    HAVE_AVX512BW(features) && HAVE_AVX512VNNI(features))
		return adler32_x86_avx512_vl512_vnni;
#endif
#ifdef adler32_x86_avx512_vl256_vnni
	if (HAVE_AVX512BW(features) && HAVE_AVX512VL(features) &&
	    HAVE_AVX512VNNI(features))
		return adler32_x86_avx512_vl256_vnni;
#endif
#ifdef adler32_x86_avx2_vnni
	if (HAVE_AVX2(features) && HAVE_AVXVNNI(features))
		return adler32_x86_avx2_vnni;
#endif
#ifdef adler32_x86_avx2
	if (HAVE_AVX2(features))
		return adler32_x86_avx2;
#endif
#ifdef adler32_x86_sse2
	if (HAVE_SSE2(features))
		return adler32_x86_sse2;
#endif
	return NULL;
}
#define arch_select_adler32_func	arch_select_adler32_func

#endif 

#endif

#ifndef DEFAULT_IMPL
#  define DEFAULT_IMPL adler32_generic
#endif

#ifdef arch_select_adler32_func
static u32 adler32_dispatch_adler32(u32 adler, const u8 *p, size_t len);

static volatile adler32_func_t adler32_impl = adler32_dispatch_adler32;


static u32 adler32_dispatch_adler32(u32 adler, const u8 *p, size_t len)
{
	adler32_func_t f = arch_select_adler32_func();

	if (f == NULL)
		f = DEFAULT_IMPL;

	adler32_impl = f;
	return f(adler, p, len);
}
#else

#define adler32_impl DEFAULT_IMPL
#endif

LIBDEFLATEAPI u32
libdeflate_adler32(u32 adler, const void *buffer, size_t len)
{
	if (buffer == NULL) 
		return 1;
	return adler32_impl(adler, buffer, len);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/crc32.c */




/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 

/* #include "crc32_multipliers.h" */


#define CRC32_X159_MODG 0xae689191 
#define CRC32_X95_MODG 0xccaa009e 

#define CRC32_X287_MODG 0xf1da05aa 
#define CRC32_X223_MODG 0x81256527 

#define CRC32_X415_MODG 0x3db1ecdc 
#define CRC32_X351_MODG 0xaf449247 

#define CRC32_X543_MODG 0x8f352d95 
#define CRC32_X479_MODG 0x1d9513d7 

#define CRC32_X671_MODG 0x1c279815 
#define CRC32_X607_MODG 0xae0b5394 

#define CRC32_X799_MODG 0xdf068dc2 
#define CRC32_X735_MODG 0x57c54819 

#define CRC32_X927_MODG 0x31f8303f 
#define CRC32_X863_MODG 0x0cbec0ed 

#define CRC32_X1055_MODG 0x33fff533 
#define CRC32_X991_MODG 0x910eeec1 

#define CRC32_X1183_MODG 0x26b70c3d 
#define CRC32_X1119_MODG 0x3f41287a 

#define CRC32_X1311_MODG 0xe3543be0 
#define CRC32_X1247_MODG 0x9026d5b1 

#define CRC32_X1439_MODG 0x5a1bb05d 
#define CRC32_X1375_MODG 0xd1df2327 

#define CRC32_X1567_MODG 0x596c8d81 
#define CRC32_X1503_MODG 0xf5e48c85 

#define CRC32_X1695_MODG 0x682bdd4f 
#define CRC32_X1631_MODG 0x3c656ced 

#define CRC32_X1823_MODG 0x4a28bd43 
#define CRC32_X1759_MODG 0xfe807bbd 

#define CRC32_X1951_MODG 0x0077f00d 
#define CRC32_X1887_MODG 0x1f0c2cdd 

#define CRC32_X2079_MODG 0xce3371cb 
#define CRC32_X2015_MODG 0xe95c1271 

#define CRC32_X2207_MODG 0xa749e894 
#define CRC32_X2143_MODG 0xb918a347 

#define CRC32_X2335_MODG 0x2c538639 
#define CRC32_X2271_MODG 0x71d54a59 

#define CRC32_X2463_MODG 0x32b0733c 
#define CRC32_X2399_MODG 0xff6f2fc2 

#define CRC32_X2591_MODG 0x0e9bd5cc 
#define CRC32_X2527_MODG 0xcec97417 

#define CRC32_X2719_MODG 0x76278617 
#define CRC32_X2655_MODG 0x1c63267b 

#define CRC32_X2847_MODG 0xc51b93e3 
#define CRC32_X2783_MODG 0xf183c71b 

#define CRC32_X2975_MODG 0x7eaed122 
#define CRC32_X2911_MODG 0x9b9bdbd0 

#define CRC32_X3103_MODG 0x2ce423f1 
#define CRC32_X3039_MODG 0xd31343ea 

#define CRC32_X3231_MODG 0x8b8d8645 
#define CRC32_X3167_MODG 0x4470ac44 

#define CRC32_X3359_MODG 0x4b700aa8 
#define CRC32_X3295_MODG 0xeea395c4 

#define CRC32_X3487_MODG 0xeff5e99d 
#define CRC32_X3423_MODG 0xf9d9c7ee 

#define CRC32_X3615_MODG 0xad0d2bb2 
#define CRC32_X3551_MODG 0xcd669a40 

#define CRC32_X3743_MODG 0x9fb66bd3 
#define CRC32_X3679_MODG 0x6d40f445 

#define CRC32_X3871_MODG 0xc2dcc467 
#define CRC32_X3807_MODG 0x9ee62949 

#define CRC32_X3999_MODG 0x398e2ff2 
#define CRC32_X3935_MODG 0x145575d5 

#define CRC32_X4127_MODG 0x1072db28 
#define CRC32_X4063_MODG 0x0c30f51d 

#define CRC32_BARRETT_CONSTANT_1 0xb4e5b025f7011641ULL 
#define CRC32_BARRETT_CONSTANT_2 0x00000001db710641ULL 

#define CRC32_NUM_CHUNKS 4
#define CRC32_MIN_VARIABLE_CHUNK_LEN 128UL
#define CRC32_MAX_VARIABLE_CHUNK_LEN 16384UL


static const u32 crc32_mults_for_chunklen[][CRC32_NUM_CHUNKS - 1] MAYBE_UNUSED = {
	{ 0  },
	
	{ 0xd31343ea , 0xe95c1271 , 0x910eeec1 , },
	
	{ 0x1d6708a0 , 0x0c30f51d , 0xe95c1271 , },
	
	{ 0xdb3839f3 , 0x1d6708a0 , 0xd31343ea , },
	
	{ 0x1753ab84 , 0xbbf2f6d6 , 0x0c30f51d , },
	
	{ 0x3796455c , 0xb8e0e4a8 , 0xc352f6de , },
	
	{ 0x3954de39 , 0x1753ab84 , 0x1d6708a0 , },
	
	{ 0x632d78c5 , 0x3fc33de4 , 0x9a1b53c8 , },
	
	{ 0xa0decef3 , 0x7b4aa8b7 , 0xbbf2f6d6 , },
	
	{ 0xe9c09bb0 , 0x3954de39 , 0xdb3839f3 , },
	
	{ 0xd51917a4 , 0xcae68461 , 0xb8e0e4a8 , },
	
	{ 0x154a8a62 , 0x41e7589c , 0x3e9a43cd , },
	
	{ 0xf196555d , 0xa0decef3 , 0x1753ab84 , },
	
	{ 0x8eec2999 , 0xefb0a128 , 0x6044fbb0 , },
	
	{ 0x27892abf , 0x48d72bb1 , 0x3fc33de4 , },
	
	{ 0x77bc2419 , 0xd51917a4 , 0x3796455c , },
	
	{ 0xcea114a5 , 0x68c0a2c5 , 0x7b4aa8b7 , },
	
	{ 0xa1077e85 , 0x188cc628 , 0x0c21f835 , },
	
	{ 0xc5ed75e1 , 0xf196555d , 0x3954de39 , },
	
	{ 0xca4fba3f , 0x0acfa26f , 0x6cb21510 , },
	
	{ 0xcf5bcdc4 , 0x4fae7fc0 , 0xcae68461 , },
	
	{ 0xf36b9d16 , 0x27892abf , 0x632d78c5 , },
	
	{ 0xf76fd988 , 0xed5c39b1 , 0x41e7589c , },
	
	{ 0x6c45d92e , 0xff809fcd , 0x0c46baec , },
	
	{ 0x6116b82b , 0xcea114a5 , 0xa0decef3 , },
	
	{ 0x4d9899bb , 0x9f9d8d9c , 0x53deb236 , },
	
	{ 0x3e7c93b9 , 0x6666b805 , 0xefb0a128 , },
	
	{ 0x388b20ac , 0xc5ed75e1 , 0xe9c09bb0 , },
	
	{ 0x0956d953 , 0x97fbdb14 , 0x48d72bb1 , },
	
	{ 0x55cb4dfe , 0x1b37c832 , 0xc07331b3 , },
	
	{ 0x52222fea , 0xcf5bcdc4 , 0xd51917a4 , },
	
	{ 0x0603989b , 0xb03c8112 , 0x5e04b9a5 , },
	
	{ 0x4470c029 , 0x2339d155 , 0x68c0a2c5 , },
	
	{ 0xb6f35093 , 0xf76fd988 , 0x154a8a62 , },
	
	{ 0xc46805ba , 0x416f9449 , 0x188cc628 , },
	
	{ 0xc3876592 , 0x4b809189 , 0xc35cf6e7 , },
	
	{ 0x5b0c98b9 , 0x6116b82b , 0xf196555d , },
	
	{ 0x30d13e5f , 0x4c5a315a , 0x8c224466 , },
	
	{ 0x54afca53 , 0xbccfa2c1 , 0x0acfa26f , },
	
	{ 0x93102436 , 0x3e7c93b9 , 0x8eec2999 , },
	
	{ 0xbd2655a8 , 0x3e116c9d , 0x4fae7fc0 , },
	
	{ 0x70cd7f26 , 0x408e57f2 , 0x1691be45 , },
	
	{ 0x2d546c53 , 0x0956d953 , 0x27892abf , },
	
	{ 0xb53410a8 , 0x42ebf0ad , 0x161f3c12 , },
	
	{ 0x67a93f75 , 0xcf3233e4 , 0xed5c39b1 , },
	
	{ 0x9830ac33 , 0x52222fea , 0x77bc2419 , },
	
	{ 0xb0b6fc3e , 0x2fde73f8 , 0xff809fcd , },
	
	{ 0x84170f16 , 0xced90d99 , 0x30de0f98 , },
	
	{ 0xd7017a0c , 0x4470c029 , 0xcea114a5 , },
	
	{ 0xadb25de6 , 0x84f40beb , 0x2b7e0e1b , },
	
	{ 0x8282fddc , 0xec855937 , 0x9f9d8d9c , },
	
	{ 0x46362bee , 0xc46805ba , 0xa1077e85 , },
	
	{ 0xb9077a01 , 0xdf7a24ac , 0x6666b805 , },
	
	{ 0xf51d9bc6 , 0x2b52dc39 , 0x7e774cf6 , },
	
	{ 0x4ca19a29 , 0x5b0c98b9 , 0xc5ed75e1 , },
	
	{ 0xdc0fc3fc , 0xb939fcdf , 0x3678fed2 , },
	
	{ 0x63c3d167 , 0x70f9947d , 0x97fbdb14 , },
	
	{ 0x5851d254 , 0x54afca53 , 0xca4fba3f , },
	
	{ 0xfeacf2a1 , 0x7a3c0a6a , 0x1b37c832 , },
	
	{ 0x93b7edc8 , 0x1fea4d2a , 0x58fa96ee , },
	
	{ 0x5539e44a , 0xbd2655a8 , 0xcf5bcdc4 , },
	
	{ 0xde32a3d2 , 0x4ff61aa1 , 0x6a6a3694 , },
	
	{ 0xf0baeeb6 , 0x7ae2f6f4 , 0xb03c8112 , },
	
	{ 0xbe15887f , 0x2d546c53 , 0xf36b9d16 , },
	
	{ 0x64f34a05 , 0xe0ee5efe , 0x2339d155 , },
	
	{ 0x1b6d1aea , 0xfeafb67c , 0x4fb001a8 , },
	
	{ 0x82adb0b8 , 0x67a93f75 , 0xf76fd988 , },
	
	{ 0x694587c7 , 0x3b34408b , 0xeccb2978 , },
	
	{ 0xd2fc57c3 , 0x07fcf8c6 , 0x416f9449 , },
	
	{ 0x9dd6837c , 0xb0b6fc3e , 0x6c45d92e , },
	
	{ 0x3a9d1f97 , 0xefd033b2 , 0x4b809189 , },
	
	{ 0x1eee1d2a , 0xf2a6e46e , 0x55b4c814 , },
	
	{ 0xb57c7728 , 0xd7017a0c , 0x6116b82b , },
	
	{ 0xf2fc5d61 , 0x242aac86 , 0x05245cf0 , },
	
	{ 0x26387824 , 0xc15c4ca5 , 0x4c5a315a , },
	
	{ 0x8c151e77 , 0x8282fddc , 0x4d9899bb , },
	
	{ 0x8ea1f680 , 0xf5ff6cdd , 0xbccfa2c1 , },
	
	{ 0xe8cf3d2a , 0x338b1fb1 , 0xeda61f70 , },
	
	{ 0x21f15b59 , 0xb9077a01 , 0x3e7c93b9 , },
	
	{ 0x6f68d64a , 0x901b0161 , 0xb9fd3537 , },
	
	{ 0x71b74d95 , 0xf5ddd5ad , 0x3e116c9d , },
	
	{ 0x4c2e7261 , 0x4ca19a29 , 0x388b20ac , },
	
	{ 0x8a2d38e8 , 0xd27ee0a1 , 0x408e57f2 , },
	
	{ 0x7e58ca17 , 0x69dfedd2 , 0x3a76805e , },
	
	{ 0xf997967f , 0x63c3d167 , 0x0956d953 , },
	
	{ 0x48215963 , 0x71e1dfe0 , 0x42a6d410 , },
	
	{ 0xa704b94c , 0x679f198a , 0x42ebf0ad , },
	
	{ 0x1d699056 , 0xfeacf2a1 , 0x55cb4dfe , },
	
	{ 0x6800bcc5 , 0x16024f15 , 0xcf3233e4 , },
	
	{ 0x2d48e4ca , 0xbe61582f , 0x46026283 , },
	
	{ 0x4c4c2b55 , 0x5539e44a , 0x52222fea , },
	
	{ 0xd8ce94cb , 0xbc613c26 , 0x33776b4b , },
	
	{ 0xd0b5a02b , 0x490d3cc6 , 0x2fde73f8 , },
	
	{ 0xa223f7ec , 0xf0baeeb6 , 0x0603989b , },
	
	{ 0x58de337a , 0x3bf3d597 , 0xced90d99 , },
	
	{ 0x37f5d8f4 , 0x4d5b699b , 0xd7262e5f , },
	
	{ 0xfa8a435d , 0x64f34a05 , 0x4470c029 , },
	
	{ 0x238709fe , 0x52e7458f , 0x9a174cd3 , },
	
	{ 0x9e1ba6f5 , 0xef0272f7 , 0x84f40beb , },
	
	{ 0xcd8b57fa , 0x82adb0b8 , 0xb6f35093 , },
	
	{ 0x0aed142f , 0xb1650290 , 0xec855937 , },
	
	{ 0xd1f064db , 0x6e7340d3 , 0x5c28cb52 , },
	
	{ 0x464ac895 , 0xd2fc57c3 , 0xc46805ba , },
	
	{ 0xa0e6beea , 0xcfeec3d0 , 0x0225d214 , },
	
	{ 0x78703ce0 , 0xc60f6075 , 0xdf7a24ac , },
	
	{ 0xfea48165 , 0x3a9d1f97 , 0xc3876592 , },
	
	{ 0xdb89b8db , 0xa6172211 , 0x2b52dc39 , },
	
	{ 0x7ca03731 , 0x1db42849 , 0xc5df246e , },
	
	{ 0x8801d0aa , 0xb57c7728 , 0x5b0c98b9 , },
	
	{ 0xf89cd7f0 , 0xcc396a0b , 0xdb799c51 , },
	
	{ 0x1611a808 , 0xaeae6105 , 0xb939fcdf , },
	
	{ 0xe3cdb888 , 0x26387824 , 0x30d13e5f , },
	
	{ 0x552a4cf6 , 0xee2d04bb , 0x70f9947d , },
	
	{ 0x85e248e9 , 0x0a79663f , 0x53339cf7 , },
	
	{ 0x1c61c3e9 , 0x8ea1f680 , 0x54afca53 , },
	
	{ 0xb14cfc2b , 0x2e073302 , 0x10897992 , },
	
	{ 0x6ec444cc , 0x9e819f13 , 0x7a3c0a6a , },
	
	{ 0xe2fa5f80 , 0x21f15b59 , 0x93102436 , },
	
	{ 0x6d33f4c6 , 0x31a27455 , 0x1fea4d2a , },
	
	{ 0xb6dec609 , 0x4d437056 , 0x42eb1e2a , },
	
	{ 0x1846c518 , 0x71b74d95 , 0xbd2655a8 , },
	
	{ 0x9f947f8a , 0x2b501619 , 0xa4924b0e , },
	
	{ 0xb7442f4d , 0xba30a5d8 , 0x4ff61aa1 , },
	
	{ 0xe2c93242 , 0x8a2d38e8 , 0x70cd7f26 , },
	
	{ 0xcd6863df , 0x78fd88dc , 0x7ae2f6f4 , },
	
	{ 0xd512001d , 0xe6612dff , 0x5c4d0ca9 , },
	
	{ 0x4e8d6b6c , 0xf997967f , 0x2d546c53 , },
	
	{ 0xfa653ba1 , 0xc99014d4 , 0xa0c9fd27 , },
	
	{ 0x49893408 , 0x29c2448b , 0xe0ee5efe , },
};


#define CRC32_FIXED_CHUNK_LEN 32768UL
#define CRC32_FIXED_CHUNK_MULT_1 0x29c2448b 
#define CRC32_FIXED_CHUNK_MULT_2 0x4b912f53 
#define CRC32_FIXED_CHUNK_MULT_3 0x454c93be 

/* #include "crc32_tables.h" */


static const u32 crc32_slice1_table[] MAYBE_UNUSED = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,
	0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
	0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de,
	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,
	0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
	0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940,
	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116,
	0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
	0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
	0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a,
	0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818,
	0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
	0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
	0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c,
	0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,
	0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
	0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
	0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086,
	0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4,
	0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
	0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
	0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8,
	0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe,
	0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
	0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
	0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252,
	0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60,
	0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
	0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
	0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04,
	0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a,
	0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
	0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
	0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e,
	0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,
	0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
	0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
	0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0,
	0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6,
	0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
	0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d,
};

static const u32 crc32_slice8_table[] MAYBE_UNUSED = {
	0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,
	0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
	0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
	0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de,
	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
	0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,
	0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
	0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
	0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940,
	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
	0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116,
	0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
	0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
	0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
	0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a,
	0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
	0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818,
	0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
	0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
	0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
	0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c,
	0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
	0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,
	0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
	0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
	0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
	0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086,
	0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
	0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4,
	0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
	0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
	0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
	0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8,
	0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
	0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe,
	0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
	0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
	0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
	0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252,
	0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
	0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60,
	0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
	0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
	0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
	0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04,
	0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
	0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a,
	0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
	0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
	0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
	0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e,
	0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
	0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,
	0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
	0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
	0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
	0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0,
	0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
	0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6,
	0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
	0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
	0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d,
	0x00000000, 0x191b3141, 0x32366282, 0x2b2d53c3,
	0x646cc504, 0x7d77f445, 0x565aa786, 0x4f4196c7,
	0xc8d98a08, 0xd1c2bb49, 0xfaefe88a, 0xe3f4d9cb,
	0xacb54f0c, 0xb5ae7e4d, 0x9e832d8e, 0x87981ccf,
	0x4ac21251, 0x53d92310, 0x78f470d3, 0x61ef4192,
	0x2eaed755, 0x37b5e614, 0x1c98b5d7, 0x05838496,
	0x821b9859, 0x9b00a918, 0xb02dfadb, 0xa936cb9a,
	0xe6775d5d, 0xff6c6c1c, 0xd4413fdf, 0xcd5a0e9e,
	0x958424a2, 0x8c9f15e3, 0xa7b24620, 0xbea97761,
	0xf1e8e1a6, 0xe8f3d0e7, 0xc3de8324, 0xdac5b265,
	0x5d5daeaa, 0x44469feb, 0x6f6bcc28, 0x7670fd69,
	0x39316bae, 0x202a5aef, 0x0b07092c, 0x121c386d,
	0xdf4636f3, 0xc65d07b2, 0xed705471, 0xf46b6530,
	0xbb2af3f7, 0xa231c2b6, 0x891c9175, 0x9007a034,
	0x179fbcfb, 0x0e848dba, 0x25a9de79, 0x3cb2ef38,
	0x73f379ff, 0x6ae848be, 0x41c51b7d, 0x58de2a3c,
	0xf0794f05, 0xe9627e44, 0xc24f2d87, 0xdb541cc6,
	0x94158a01, 0x8d0ebb40, 0xa623e883, 0xbf38d9c2,
	0x38a0c50d, 0x21bbf44c, 0x0a96a78f, 0x138d96ce,
	0x5ccc0009, 0x45d73148, 0x6efa628b, 0x77e153ca,
	0xbabb5d54, 0xa3a06c15, 0x888d3fd6, 0x91960e97,
	0xded79850, 0xc7cca911, 0xece1fad2, 0xf5facb93,
	0x7262d75c, 0x6b79e61d, 0x4054b5de, 0x594f849f,
	0x160e1258, 0x0f152319, 0x243870da, 0x3d23419b,
	0x65fd6ba7, 0x7ce65ae6, 0x57cb0925, 0x4ed03864,
	0x0191aea3, 0x188a9fe2, 0x33a7cc21, 0x2abcfd60,
	0xad24e1af, 0xb43fd0ee, 0x9f12832d, 0x8609b26c,
	0xc94824ab, 0xd05315ea, 0xfb7e4629, 0xe2657768,
	0x2f3f79f6, 0x362448b7, 0x1d091b74, 0x04122a35,
	0x4b53bcf2, 0x52488db3, 0x7965de70, 0x607eef31,
	0xe7e6f3fe, 0xfefdc2bf, 0xd5d0917c, 0xcccba03d,
	0x838a36fa, 0x9a9107bb, 0xb1bc5478, 0xa8a76539,
	0x3b83984b, 0x2298a90a, 0x09b5fac9, 0x10aecb88,
	0x5fef5d4f, 0x46f46c0e, 0x6dd93fcd, 0x74c20e8c,
	0xf35a1243, 0xea412302, 0xc16c70c1, 0xd8774180,
	0x9736d747, 0x8e2de606, 0xa500b5c5, 0xbc1b8484,
	0x71418a1a, 0x685abb5b, 0x4377e898, 0x5a6cd9d9,
	0x152d4f1e, 0x0c367e5f, 0x271b2d9c, 0x3e001cdd,
	0xb9980012, 0xa0833153, 0x8bae6290, 0x92b553d1,
	0xddf4c516, 0xc4eff457, 0xefc2a794, 0xf6d996d5,
	0xae07bce9, 0xb71c8da8, 0x9c31de6b, 0x852aef2a,
	0xca6b79ed, 0xd37048ac, 0xf85d1b6f, 0xe1462a2e,
	0x66de36e1, 0x7fc507a0, 0x54e85463, 0x4df36522,
	0x02b2f3e5, 0x1ba9c2a4, 0x30849167, 0x299fa026,
	0xe4c5aeb8, 0xfdde9ff9, 0xd6f3cc3a, 0xcfe8fd7b,
	0x80a96bbc, 0x99b25afd, 0xb29f093e, 0xab84387f,
	0x2c1c24b0, 0x350715f1, 0x1e2a4632, 0x07317773,
	0x4870e1b4, 0x516bd0f5, 0x7a468336, 0x635db277,
	0xcbfad74e, 0xd2e1e60f, 0xf9ccb5cc, 0xe0d7848d,
	0xaf96124a, 0xb68d230b, 0x9da070c8, 0x84bb4189,
	0x03235d46, 0x1a386c07, 0x31153fc4, 0x280e0e85,
	0x674f9842, 0x7e54a903, 0x5579fac0, 0x4c62cb81,
	0x8138c51f, 0x9823f45e, 0xb30ea79d, 0xaa1596dc,
	0xe554001b, 0xfc4f315a, 0xd7626299, 0xce7953d8,
	0x49e14f17, 0x50fa7e56, 0x7bd72d95, 0x62cc1cd4,
	0x2d8d8a13, 0x3496bb52, 0x1fbbe891, 0x06a0d9d0,
	0x5e7ef3ec, 0x4765c2ad, 0x6c48916e, 0x7553a02f,
	0x3a1236e8, 0x230907a9, 0x0824546a, 0x113f652b,
	0x96a779e4, 0x8fbc48a5, 0xa4911b66, 0xbd8a2a27,
	0xf2cbbce0, 0xebd08da1, 0xc0fdde62, 0xd9e6ef23,
	0x14bce1bd, 0x0da7d0fc, 0x268a833f, 0x3f91b27e,
	0x70d024b9, 0x69cb15f8, 0x42e6463b, 0x5bfd777a,
	0xdc656bb5, 0xc57e5af4, 0xee530937, 0xf7483876,
	0xb809aeb1, 0xa1129ff0, 0x8a3fcc33, 0x9324fd72,
	0x00000000, 0x01c26a37, 0x0384d46e, 0x0246be59,
	0x0709a8dc, 0x06cbc2eb, 0x048d7cb2, 0x054f1685,
	0x0e1351b8, 0x0fd13b8f, 0x0d9785d6, 0x0c55efe1,
	0x091af964, 0x08d89353, 0x0a9e2d0a, 0x0b5c473d,
	0x1c26a370, 0x1de4c947, 0x1fa2771e, 0x1e601d29,
	0x1b2f0bac, 0x1aed619b, 0x18abdfc2, 0x1969b5f5,
	0x1235f2c8, 0x13f798ff, 0x11b126a6, 0x10734c91,
	0x153c5a14, 0x14fe3023, 0x16b88e7a, 0x177ae44d,
	0x384d46e0, 0x398f2cd7, 0x3bc9928e, 0x3a0bf8b9,
	0x3f44ee3c, 0x3e86840b, 0x3cc03a52, 0x3d025065,
	0x365e1758, 0x379c7d6f, 0x35dac336, 0x3418a901,
	0x3157bf84, 0x3095d5b3, 0x32d36bea, 0x331101dd,
	0x246be590, 0x25a98fa7, 0x27ef31fe, 0x262d5bc9,
	0x23624d4c, 0x22a0277b, 0x20e69922, 0x2124f315,
	0x2a78b428, 0x2bbade1f, 0x29fc6046, 0x283e0a71,
	0x2d711cf4, 0x2cb376c3, 0x2ef5c89a, 0x2f37a2ad,
	0x709a8dc0, 0x7158e7f7, 0x731e59ae, 0x72dc3399,
	0x7793251c, 0x76514f2b, 0x7417f172, 0x75d59b45,
	0x7e89dc78, 0x7f4bb64f, 0x7d0d0816, 0x7ccf6221,
	0x798074a4, 0x78421e93, 0x7a04a0ca, 0x7bc6cafd,
	0x6cbc2eb0, 0x6d7e4487, 0x6f38fade, 0x6efa90e9,
	0x6bb5866c, 0x6a77ec5b, 0x68315202, 0x69f33835,
	0x62af7f08, 0x636d153f, 0x612bab66, 0x60e9c151,
	0x65a6d7d4, 0x6464bde3, 0x662203ba, 0x67e0698d,
	0x48d7cb20, 0x4915a117, 0x4b531f4e, 0x4a917579,
	0x4fde63fc, 0x4e1c09cb, 0x4c5ab792, 0x4d98dda5,
	0x46c49a98, 0x4706f0af, 0x45404ef6, 0x448224c1,
	0x41cd3244, 0x400f5873, 0x4249e62a, 0x438b8c1d,
	0x54f16850, 0x55330267, 0x5775bc3e, 0x56b7d609,
	0x53f8c08c, 0x523aaabb, 0x507c14e2, 0x51be7ed5,
	0x5ae239e8, 0x5b2053df, 0x5966ed86, 0x58a487b1,
	0x5deb9134, 0x5c29fb03, 0x5e6f455a, 0x5fad2f6d,
	0xe1351b80, 0xe0f771b7, 0xe2b1cfee, 0xe373a5d9,
	0xe63cb35c, 0xe7fed96b, 0xe5b86732, 0xe47a0d05,
	0xef264a38, 0xeee4200f, 0xeca29e56, 0xed60f461,
	0xe82fe2e4, 0xe9ed88d3, 0xebab368a, 0xea695cbd,
	0xfd13b8f0, 0xfcd1d2c7, 0xfe976c9e, 0xff5506a9,
	0xfa1a102c, 0xfbd87a1b, 0xf99ec442, 0xf85cae75,
	0xf300e948, 0xf2c2837f, 0xf0843d26, 0xf1465711,
	0xf4094194, 0xf5cb2ba3, 0xf78d95fa, 0xf64fffcd,
	0xd9785d60, 0xd8ba3757, 0xdafc890e, 0xdb3ee339,
	0xde71f5bc, 0xdfb39f8b, 0xddf521d2, 0xdc374be5,
	0xd76b0cd8, 0xd6a966ef, 0xd4efd8b6, 0xd52db281,
	0xd062a404, 0xd1a0ce33, 0xd3e6706a, 0xd2241a5d,
	0xc55efe10, 0xc49c9427, 0xc6da2a7e, 0xc7184049,
	0xc25756cc, 0xc3953cfb, 0xc1d382a2, 0xc011e895,
	0xcb4dafa8, 0xca8fc59f, 0xc8c97bc6, 0xc90b11f1,
	0xcc440774, 0xcd866d43, 0xcfc0d31a, 0xce02b92d,
	0x91af9640, 0x906dfc77, 0x922b422e, 0x93e92819,
	0x96a63e9c, 0x976454ab, 0x9522eaf2, 0x94e080c5,
	0x9fbcc7f8, 0x9e7eadcf, 0x9c381396, 0x9dfa79a1,
	0x98b56f24, 0x99770513, 0x9b31bb4a, 0x9af3d17d,
	0x8d893530, 0x8c4b5f07, 0x8e0de15e, 0x8fcf8b69,
	0x8a809dec, 0x8b42f7db, 0x89044982, 0x88c623b5,
	0x839a6488, 0x82580ebf, 0x801eb0e6, 0x81dcdad1,
	0x8493cc54, 0x8551a663, 0x8717183a, 0x86d5720d,
	0xa9e2d0a0, 0xa820ba97, 0xaa6604ce, 0xaba46ef9,
	0xaeeb787c, 0xaf29124b, 0xad6fac12, 0xacadc625,
	0xa7f18118, 0xa633eb2f, 0xa4755576, 0xa5b73f41,
	0xa0f829c4, 0xa13a43f3, 0xa37cfdaa, 0xa2be979d,
	0xb5c473d0, 0xb40619e7, 0xb640a7be, 0xb782cd89,
	0xb2cddb0c, 0xb30fb13b, 0xb1490f62, 0xb08b6555,
	0xbbd72268, 0xba15485f, 0xb853f606, 0xb9919c31,
	0xbcde8ab4, 0xbd1ce083, 0xbf5a5eda, 0xbe9834ed,
	0x00000000, 0xb8bc6765, 0xaa09c88b, 0x12b5afee,
	0x8f629757, 0x37def032, 0x256b5fdc, 0x9dd738b9,
	0xc5b428ef, 0x7d084f8a, 0x6fbde064, 0xd7018701,
	0x4ad6bfb8, 0xf26ad8dd, 0xe0df7733, 0x58631056,
	0x5019579f, 0xe8a530fa, 0xfa109f14, 0x42acf871,
	0xdf7bc0c8, 0x67c7a7ad, 0x75720843, 0xcdce6f26,
	0x95ad7f70, 0x2d111815, 0x3fa4b7fb, 0x8718d09e,
	0x1acfe827, 0xa2738f42, 0xb0c620ac, 0x087a47c9,
	0xa032af3e, 0x188ec85b, 0x0a3b67b5, 0xb28700d0,
	0x2f503869, 0x97ec5f0c, 0x8559f0e2, 0x3de59787,
	0x658687d1, 0xdd3ae0b4, 0xcf8f4f5a, 0x7733283f,
	0xeae41086, 0x525877e3, 0x40edd80d, 0xf851bf68,
	0xf02bf8a1, 0x48979fc4, 0x5a22302a, 0xe29e574f,
	0x7f496ff6, 0xc7f50893, 0xd540a77d, 0x6dfcc018,
	0x359fd04e, 0x8d23b72b, 0x9f9618c5, 0x272a7fa0,
	0xbafd4719, 0x0241207c, 0x10f48f92, 0xa848e8f7,
	0x9b14583d, 0x23a83f58, 0x311d90b6, 0x89a1f7d3,
	0x1476cf6a, 0xaccaa80f, 0xbe7f07e1, 0x06c36084,
	0x5ea070d2, 0xe61c17b7, 0xf4a9b859, 0x4c15df3c,
	0xd1c2e785, 0x697e80e0, 0x7bcb2f0e, 0xc377486b,
	0xcb0d0fa2, 0x73b168c7, 0x6104c729, 0xd9b8a04c,
	0x446f98f5, 0xfcd3ff90, 0xee66507e, 0x56da371b,
	0x0eb9274d, 0xb6054028, 0xa4b0efc6, 0x1c0c88a3,
	0x81dbb01a, 0x3967d77f, 0x2bd27891, 0x936e1ff4,
	0x3b26f703, 0x839a9066, 0x912f3f88, 0x299358ed,
	0xb4446054, 0x0cf80731, 0x1e4da8df, 0xa6f1cfba,
	0xfe92dfec, 0x462eb889, 0x549b1767, 0xec277002,
	0x71f048bb, 0xc94c2fde, 0xdbf98030, 0x6345e755,
	0x6b3fa09c, 0xd383c7f9, 0xc1366817, 0x798a0f72,
	0xe45d37cb, 0x5ce150ae, 0x4e54ff40, 0xf6e89825,
	0xae8b8873, 0x1637ef16, 0x048240f8, 0xbc3e279d,
	0x21e91f24, 0x99557841, 0x8be0d7af, 0x335cb0ca,
	0xed59b63b, 0x55e5d15e, 0x47507eb0, 0xffec19d5,
	0x623b216c, 0xda874609, 0xc832e9e7, 0x708e8e82,
	0x28ed9ed4, 0x9051f9b1, 0x82e4565f, 0x3a58313a,
	0xa78f0983, 0x1f336ee6, 0x0d86c108, 0xb53aa66d,
	0xbd40e1a4, 0x05fc86c1, 0x1749292f, 0xaff54e4a,
	0x322276f3, 0x8a9e1196, 0x982bbe78, 0x2097d91d,
	0x78f4c94b, 0xc048ae2e, 0xd2fd01c0, 0x6a4166a5,
	0xf7965e1c, 0x4f2a3979, 0x5d9f9697, 0xe523f1f2,
	0x4d6b1905, 0xf5d77e60, 0xe762d18e, 0x5fdeb6eb,
	0xc2098e52, 0x7ab5e937, 0x680046d9, 0xd0bc21bc,
	0x88df31ea, 0x3063568f, 0x22d6f961, 0x9a6a9e04,
	0x07bda6bd, 0xbf01c1d8, 0xadb46e36, 0x15080953,
	0x1d724e9a, 0xa5ce29ff, 0xb77b8611, 0x0fc7e174,
	0x9210d9cd, 0x2aacbea8, 0x38191146, 0x80a57623,
	0xd8c66675, 0x607a0110, 0x72cfaefe, 0xca73c99b,
	0x57a4f122, 0xef189647, 0xfdad39a9, 0x45115ecc,
	0x764dee06, 0xcef18963, 0xdc44268d, 0x64f841e8,
	0xf92f7951, 0x41931e34, 0x5326b1da, 0xeb9ad6bf,
	0xb3f9c6e9, 0x0b45a18c, 0x19f00e62, 0xa14c6907,
	0x3c9b51be, 0x842736db, 0x96929935, 0x2e2efe50,
	0x2654b999, 0x9ee8defc, 0x8c5d7112, 0x34e11677,
	0xa9362ece, 0x118a49ab, 0x033fe645, 0xbb838120,
	0xe3e09176, 0x5b5cf613, 0x49e959fd, 0xf1553e98,
	0x6c820621, 0xd43e6144, 0xc68bceaa, 0x7e37a9cf,
	0xd67f4138, 0x6ec3265d, 0x7c7689b3, 0xc4caeed6,
	0x591dd66f, 0xe1a1b10a, 0xf3141ee4, 0x4ba87981,
	0x13cb69d7, 0xab770eb2, 0xb9c2a15c, 0x017ec639,
	0x9ca9fe80, 0x241599e5, 0x36a0360b, 0x8e1c516e,
	0x866616a7, 0x3eda71c2, 0x2c6fde2c, 0x94d3b949,
	0x090481f0, 0xb1b8e695, 0xa30d497b, 0x1bb12e1e,
	0x43d23e48, 0xfb6e592d, 0xe9dbf6c3, 0x516791a6,
	0xccb0a91f, 0x740cce7a, 0x66b96194, 0xde0506f1,
	0x00000000, 0x3d6029b0, 0x7ac05360, 0x47a07ad0,
	0xf580a6c0, 0xc8e08f70, 0x8f40f5a0, 0xb220dc10,
	0x30704bc1, 0x0d106271, 0x4ab018a1, 0x77d03111,
	0xc5f0ed01, 0xf890c4b1, 0xbf30be61, 0x825097d1,
	0x60e09782, 0x5d80be32, 0x1a20c4e2, 0x2740ed52,
	0x95603142, 0xa80018f2, 0xefa06222, 0xd2c04b92,
	0x5090dc43, 0x6df0f5f3, 0x2a508f23, 0x1730a693,
	0xa5107a83, 0x98705333, 0xdfd029e3, 0xe2b00053,
	0xc1c12f04, 0xfca106b4, 0xbb017c64, 0x866155d4,
	0x344189c4, 0x0921a074, 0x4e81daa4, 0x73e1f314,
	0xf1b164c5, 0xccd14d75, 0x8b7137a5, 0xb6111e15,
	0x0431c205, 0x3951ebb5, 0x7ef19165, 0x4391b8d5,
	0xa121b886, 0x9c419136, 0xdbe1ebe6, 0xe681c256,
	0x54a11e46, 0x69c137f6, 0x2e614d26, 0x13016496,
	0x9151f347, 0xac31daf7, 0xeb91a027, 0xd6f18997,
	0x64d15587, 0x59b17c37, 0x1e1106e7, 0x23712f57,
	0x58f35849, 0x659371f9, 0x22330b29, 0x1f532299,
	0xad73fe89, 0x9013d739, 0xd7b3ade9, 0xead38459,
	0x68831388, 0x55e33a38, 0x124340e8, 0x2f236958,
	0x9d03b548, 0xa0639cf8, 0xe7c3e628, 0xdaa3cf98,
	0x3813cfcb, 0x0573e67b, 0x42d39cab, 0x7fb3b51b,
	0xcd93690b, 0xf0f340bb, 0xb7533a6b, 0x8a3313db,
	0x0863840a, 0x3503adba, 0x72a3d76a, 0x4fc3feda,
	0xfde322ca, 0xc0830b7a, 0x872371aa, 0xba43581a,
	0x9932774d, 0xa4525efd, 0xe3f2242d, 0xde920d9d,
	0x6cb2d18d, 0x51d2f83d, 0x167282ed, 0x2b12ab5d,
	0xa9423c8c, 0x9422153c, 0xd3826fec, 0xeee2465c,
	0x5cc29a4c, 0x61a2b3fc, 0x2602c92c, 0x1b62e09c,
	0xf9d2e0cf, 0xc4b2c97f, 0x8312b3af, 0xbe729a1f,
	0x0c52460f, 0x31326fbf, 0x7692156f, 0x4bf23cdf,
	0xc9a2ab0e, 0xf4c282be, 0xb362f86e, 0x8e02d1de,
	0x3c220dce, 0x0142247e, 0x46e25eae, 0x7b82771e,
	0xb1e6b092, 0x8c869922, 0xcb26e3f2, 0xf646ca42,
	0x44661652, 0x79063fe2, 0x3ea64532, 0x03c66c82,
	0x8196fb53, 0xbcf6d2e3, 0xfb56a833, 0xc6368183,
	0x74165d93, 0x49767423, 0x0ed60ef3, 0x33b62743,
	0xd1062710, 0xec660ea0, 0xabc67470, 0x96a65dc0,
	0x248681d0, 0x19e6a860, 0x5e46d2b0, 0x6326fb00,
	0xe1766cd1, 0xdc164561, 0x9bb63fb1, 0xa6d61601,
	0x14f6ca11, 0x2996e3a1, 0x6e369971, 0x5356b0c1,
	0x70279f96, 0x4d47b626, 0x0ae7ccf6, 0x3787e546,
	0x85a73956, 0xb8c710e6, 0xff676a36, 0xc2074386,
	0x4057d457, 0x7d37fde7, 0x3a978737, 0x07f7ae87,
	0xb5d77297, 0x88b75b27, 0xcf1721f7, 0xf2770847,
	0x10c70814, 0x2da721a4, 0x6a075b74, 0x576772c4,
	0xe547aed4, 0xd8278764, 0x9f87fdb4, 0xa2e7d404,
	0x20b743d5, 0x1dd76a65, 0x5a7710b5, 0x67173905,
	0xd537e515, 0xe857cca5, 0xaff7b675, 0x92979fc5,
	0xe915e8db, 0xd475c16b, 0x93d5bbbb, 0xaeb5920b,
	0x1c954e1b, 0x21f567ab, 0x66551d7b, 0x5b3534cb,
	0xd965a31a, 0xe4058aaa, 0xa3a5f07a, 0x9ec5d9ca,
	0x2ce505da, 0x11852c6a, 0x562556ba, 0x6b457f0a,
	0x89f57f59, 0xb49556e9, 0xf3352c39, 0xce550589,
	0x7c75d999, 0x4115f029, 0x06b58af9, 0x3bd5a349,
	0xb9853498, 0x84e51d28, 0xc34567f8, 0xfe254e48,
	0x4c059258, 0x7165bbe8, 0x36c5c138, 0x0ba5e888,
	0x28d4c7df, 0x15b4ee6f, 0x521494bf, 0x6f74bd0f,
	0xdd54611f, 0xe03448af, 0xa794327f, 0x9af41bcf,
	0x18a48c1e, 0x25c4a5ae, 0x6264df7e, 0x5f04f6ce,
	0xed242ade, 0xd044036e, 0x97e479be, 0xaa84500e,
	0x4834505d, 0x755479ed, 0x32f4033d, 0x0f942a8d,
	0xbdb4f69d, 0x80d4df2d, 0xc774a5fd, 0xfa148c4d,
	0x78441b9c, 0x4524322c, 0x028448fc, 0x3fe4614c,
	0x8dc4bd5c, 0xb0a494ec, 0xf704ee3c, 0xca64c78c,
	0x00000000, 0xcb5cd3a5, 0x4dc8a10b, 0x869472ae,
	0x9b914216, 0x50cd91b3, 0xd659e31d, 0x1d0530b8,
	0xec53826d, 0x270f51c8, 0xa19b2366, 0x6ac7f0c3,
	0x77c2c07b, 0xbc9e13de, 0x3a0a6170, 0xf156b2d5,
	0x03d6029b, 0xc88ad13e, 0x4e1ea390, 0x85427035,
	0x9847408d, 0x531b9328, 0xd58fe186, 0x1ed33223,
	0xef8580f6, 0x24d95353, 0xa24d21fd, 0x6911f258,
	0x7414c2e0, 0xbf481145, 0x39dc63eb, 0xf280b04e,
	0x07ac0536, 0xccf0d693, 0x4a64a43d, 0x81387798,
	0x9c3d4720, 0x57619485, 0xd1f5e62b, 0x1aa9358e,
	0xebff875b, 0x20a354fe, 0xa6372650, 0x6d6bf5f5,
	0x706ec54d, 0xbb3216e8, 0x3da66446, 0xf6fab7e3,
	0x047a07ad, 0xcf26d408, 0x49b2a6a6, 0x82ee7503,
	0x9feb45bb, 0x54b7961e, 0xd223e4b0, 0x197f3715,
	0xe82985c0, 0x23755665, 0xa5e124cb, 0x6ebdf76e,
	0x73b8c7d6, 0xb8e41473, 0x3e7066dd, 0xf52cb578,
	0x0f580a6c, 0xc404d9c9, 0x4290ab67, 0x89cc78c2,
	0x94c9487a, 0x5f959bdf, 0xd901e971, 0x125d3ad4,
	0xe30b8801, 0x28575ba4, 0xaec3290a, 0x659ffaaf,
	0x789aca17, 0xb3c619b2, 0x35526b1c, 0xfe0eb8b9,
	0x0c8e08f7, 0xc7d2db52, 0x4146a9fc, 0x8a1a7a59,
	0x971f4ae1, 0x5c439944, 0xdad7ebea, 0x118b384f,
	0xe0dd8a9a, 0x2b81593f, 0xad152b91, 0x6649f834,
	0x7b4cc88c, 0xb0101b29, 0x36846987, 0xfdd8ba22,
	0x08f40f5a, 0xc3a8dcff, 0x453cae51, 0x8e607df4,
	0x93654d4c, 0x58399ee9, 0xdeadec47, 0x15f13fe2,
	0xe4a78d37, 0x2ffb5e92, 0xa96f2c3c, 0x6233ff99,
	0x7f36cf21, 0xb46a1c84, 0x32fe6e2a, 0xf9a2bd8f,
	0x0b220dc1, 0xc07ede64, 0x46eaacca, 0x8db67f6f,
	0x90b34fd7, 0x5bef9c72, 0xdd7beedc, 0x16273d79,
	0xe7718fac, 0x2c2d5c09, 0xaab92ea7, 0x61e5fd02,
	0x7ce0cdba, 0xb7bc1e1f, 0x31286cb1, 0xfa74bf14,
	0x1eb014d8, 0xd5ecc77d, 0x5378b5d3, 0x98246676,
	0x852156ce, 0x4e7d856b, 0xc8e9f7c5, 0x03b52460,
	0xf2e396b5, 0x39bf4510, 0xbf2b37be, 0x7477e41b,
	0x6972d4a3, 0xa22e0706, 0x24ba75a8, 0xefe6a60d,
	0x1d661643, 0xd63ac5e6, 0x50aeb748, 0x9bf264ed,
	0x86f75455, 0x4dab87f0, 0xcb3ff55e, 0x006326fb,
	0xf135942e, 0x3a69478b, 0xbcfd3525, 0x77a1e680,
	0x6aa4d638, 0xa1f8059d, 0x276c7733, 0xec30a496,
	0x191c11ee, 0xd240c24b, 0x54d4b0e5, 0x9f886340,
	0x828d53f8, 0x49d1805d, 0xcf45f2f3, 0x04192156,
	0xf54f9383, 0x3e134026, 0xb8873288, 0x73dbe12d,
	0x6eded195, 0xa5820230, 0x2316709e, 0xe84aa33b,
	0x1aca1375, 0xd196c0d0, 0x5702b27e, 0x9c5e61db,
	0x815b5163, 0x4a0782c6, 0xcc93f068, 0x07cf23cd,
	0xf6999118, 0x3dc542bd, 0xbb513013, 0x700de3b6,
	0x6d08d30e, 0xa65400ab, 0x20c07205, 0xeb9ca1a0,
	0x11e81eb4, 0xdab4cd11, 0x5c20bfbf, 0x977c6c1a,
	0x8a795ca2, 0x41258f07, 0xc7b1fda9, 0x0ced2e0c,
	0xfdbb9cd9, 0x36e74f7c, 0xb0733dd2, 0x7b2fee77,
	0x662adecf, 0xad760d6a, 0x2be27fc4, 0xe0beac61,
	0x123e1c2f, 0xd962cf8a, 0x5ff6bd24, 0x94aa6e81,
	0x89af5e39, 0x42f38d9c, 0xc467ff32, 0x0f3b2c97,
	0xfe6d9e42, 0x35314de7, 0xb3a53f49, 0x78f9ecec,
	0x65fcdc54, 0xaea00ff1, 0x28347d5f, 0xe368aefa,
	0x16441b82, 0xdd18c827, 0x5b8cba89, 0x90d0692c,
	0x8dd55994, 0x46898a31, 0xc01df89f, 0x0b412b3a,
	0xfa1799ef, 0x314b4a4a, 0xb7df38e4, 0x7c83eb41,
	0x6186dbf9, 0xaada085c, 0x2c4e7af2, 0xe712a957,
	0x15921919, 0xdececabc, 0x585ab812, 0x93066bb7,
	0x8e035b0f, 0x455f88aa, 0xc3cbfa04, 0x089729a1,
	0xf9c19b74, 0x329d48d1, 0xb4093a7f, 0x7f55e9da,
	0x6250d962, 0xa90c0ac7, 0x2f987869, 0xe4c4abcc,
	0x00000000, 0xa6770bb4, 0x979f1129, 0x31e81a9d,
	0xf44f2413, 0x52382fa7, 0x63d0353a, 0xc5a73e8e,
	0x33ef4e67, 0x959845d3, 0xa4705f4e, 0x020754fa,
	0xc7a06a74, 0x61d761c0, 0x503f7b5d, 0xf64870e9,
	0x67de9cce, 0xc1a9977a, 0xf0418de7, 0x56368653,
	0x9391b8dd, 0x35e6b369, 0x040ea9f4, 0xa279a240,
	0x5431d2a9, 0xf246d91d, 0xc3aec380, 0x65d9c834,
	0xa07ef6ba, 0x0609fd0e, 0x37e1e793, 0x9196ec27,
	0xcfbd399c, 0x69ca3228, 0x582228b5, 0xfe552301,
	0x3bf21d8f, 0x9d85163b, 0xac6d0ca6, 0x0a1a0712,
	0xfc5277fb, 0x5a257c4f, 0x6bcd66d2, 0xcdba6d66,
	0x081d53e8, 0xae6a585c, 0x9f8242c1, 0x39f54975,
	0xa863a552, 0x0e14aee6, 0x3ffcb47b, 0x998bbfcf,
	0x5c2c8141, 0xfa5b8af5, 0xcbb39068, 0x6dc49bdc,
	0x9b8ceb35, 0x3dfbe081, 0x0c13fa1c, 0xaa64f1a8,
	0x6fc3cf26, 0xc9b4c492, 0xf85cde0f, 0x5e2bd5bb,
	0x440b7579, 0xe27c7ecd, 0xd3946450, 0x75e36fe4,
	0xb044516a, 0x16335ade, 0x27db4043, 0x81ac4bf7,
	0x77e43b1e, 0xd19330aa, 0xe07b2a37, 0x460c2183,
	0x83ab1f0d, 0x25dc14b9, 0x14340e24, 0xb2430590,
	0x23d5e9b7, 0x85a2e203, 0xb44af89e, 0x123df32a,
	0xd79acda4, 0x71edc610, 0x4005dc8d, 0xe672d739,
	0x103aa7d0, 0xb64dac64, 0x87a5b6f9, 0x21d2bd4d,
	0xe47583c3, 0x42028877, 0x73ea92ea, 0xd59d995e,
	0x8bb64ce5, 0x2dc14751, 0x1c295dcc, 0xba5e5678,
	0x7ff968f6, 0xd98e6342, 0xe86679df, 0x4e11726b,
	0xb8590282, 0x1e2e0936, 0x2fc613ab, 0x89b1181f,
	0x4c162691, 0xea612d25, 0xdb8937b8, 0x7dfe3c0c,
	0xec68d02b, 0x4a1fdb9f, 0x7bf7c102, 0xdd80cab6,
	0x1827f438, 0xbe50ff8c, 0x8fb8e511, 0x29cfeea5,
	0xdf879e4c, 0x79f095f8, 0x48188f65, 0xee6f84d1,
	0x2bc8ba5f, 0x8dbfb1eb, 0xbc57ab76, 0x1a20a0c2,
	0x8816eaf2, 0x2e61e146, 0x1f89fbdb, 0xb9fef06f,
	0x7c59cee1, 0xda2ec555, 0xebc6dfc8, 0x4db1d47c,
	0xbbf9a495, 0x1d8eaf21, 0x2c66b5bc, 0x8a11be08,
	0x4fb68086, 0xe9c18b32, 0xd82991af, 0x7e5e9a1b,
	0xefc8763c, 0x49bf7d88, 0x78576715, 0xde206ca1,
	0x1b87522f, 0xbdf0599b, 0x8c184306, 0x2a6f48b2,
	0xdc27385b, 0x7a5033ef, 0x4bb82972, 0xedcf22c6,
	0x28681c48, 0x8e1f17fc, 0xbff70d61, 0x198006d5,
	0x47abd36e, 0xe1dcd8da, 0xd034c247, 0x7643c9f3,
	0xb3e4f77d, 0x1593fcc9, 0x247be654, 0x820cede0,
	0x74449d09, 0xd23396bd, 0xe3db8c20, 0x45ac8794,
	0x800bb91a, 0x267cb2ae, 0x1794a833, 0xb1e3a387,
	0x20754fa0, 0x86024414, 0xb7ea5e89, 0x119d553d,
	0xd43a6bb3, 0x724d6007, 0x43a57a9a, 0xe5d2712e,
	0x139a01c7, 0xb5ed0a73, 0x840510ee, 0x22721b5a,
	0xe7d525d4, 0x41a22e60, 0x704a34fd, 0xd63d3f49,
	0xcc1d9f8b, 0x6a6a943f, 0x5b828ea2, 0xfdf58516,
	0x3852bb98, 0x9e25b02c, 0xafcdaab1, 0x09baa105,
	0xfff2d1ec, 0x5985da58, 0x686dc0c5, 0xce1acb71,
	0x0bbdf5ff, 0xadcafe4b, 0x9c22e4d6, 0x3a55ef62,
	0xabc30345, 0x0db408f1, 0x3c5c126c, 0x9a2b19d8,
	0x5f8c2756, 0xf9fb2ce2, 0xc813367f, 0x6e643dcb,
	0x982c4d22, 0x3e5b4696, 0x0fb35c0b, 0xa9c457bf,
	0x6c636931, 0xca146285, 0xfbfc7818, 0x5d8b73ac,
	0x03a0a617, 0xa5d7ada3, 0x943fb73e, 0x3248bc8a,
	0xf7ef8204, 0x519889b0, 0x6070932d, 0xc6079899,
	0x304fe870, 0x9638e3c4, 0xa7d0f959, 0x01a7f2ed,
	0xc400cc63, 0x6277c7d7, 0x539fdd4a, 0xf5e8d6fe,
	0x647e3ad9, 0xc209316d, 0xf3e12bf0, 0x55962044,
	0x90311eca, 0x3646157e, 0x07ae0fe3, 0xa1d90457,
	0x579174be, 0xf1e67f0a, 0xc00e6597, 0x66796e23,
	0xa3de50ad, 0x05a95b19, 0x34414184, 0x92364a30,
	0x00000000, 0xccaa009e, 0x4225077d, 0x8e8f07e3,
	0x844a0efa, 0x48e00e64, 0xc66f0987, 0x0ac50919,
	0xd3e51bb5, 0x1f4f1b2b, 0x91c01cc8, 0x5d6a1c56,
	0x57af154f, 0x9b0515d1, 0x158a1232, 0xd92012ac,
	0x7cbb312b, 0xb01131b5, 0x3e9e3656, 0xf23436c8,
	0xf8f13fd1, 0x345b3f4f, 0xbad438ac, 0x767e3832,
	0xaf5e2a9e, 0x63f42a00, 0xed7b2de3, 0x21d12d7d,
	0x2b142464, 0xe7be24fa, 0x69312319, 0xa59b2387,
	0xf9766256, 0x35dc62c8, 0xbb53652b, 0x77f965b5,
	0x7d3c6cac, 0xb1966c32, 0x3f196bd1, 0xf3b36b4f,
	0x2a9379e3, 0xe639797d, 0x68b67e9e, 0xa41c7e00,
	0xaed97719, 0x62737787, 0xecfc7064, 0x205670fa,
	0x85cd537d, 0x496753e3, 0xc7e85400, 0x0b42549e,
	0x01875d87, 0xcd2d5d19, 0x43a25afa, 0x8f085a64,
	0x562848c8, 0x9a824856, 0x140d4fb5, 0xd8a74f2b,
	0xd2624632, 0x1ec846ac, 0x9047414f, 0x5ced41d1,
	0x299dc2ed, 0xe537c273, 0x6bb8c590, 0xa712c50e,
	0xadd7cc17, 0x617dcc89, 0xeff2cb6a, 0x2358cbf4,
	0xfa78d958, 0x36d2d9c6, 0xb85dde25, 0x74f7debb,
	0x7e32d7a2, 0xb298d73c, 0x3c17d0df, 0xf0bdd041,
	0x5526f3c6, 0x998cf358, 0x1703f4bb, 0xdba9f425,
	0xd16cfd3c, 0x1dc6fda2, 0x9349fa41, 0x5fe3fadf,
	0x86c3e873, 0x4a69e8ed, 0xc4e6ef0e, 0x084cef90,
	0x0289e689, 0xce23e617, 0x40ace1f4, 0x8c06e16a,
	0xd0eba0bb, 0x1c41a025, 0x92cea7c6, 0x5e64a758,
	0x54a1ae41, 0x980baedf, 0x1684a93c, 0xda2ea9a2,
	0x030ebb0e, 0xcfa4bb90, 0x412bbc73, 0x8d81bced,
	0x8744b5f4, 0x4beeb56a, 0xc561b289, 0x09cbb217,
	0xac509190, 0x60fa910e, 0xee7596ed, 0x22df9673,
	0x281a9f6a, 0xe4b09ff4, 0x6a3f9817, 0xa6959889,
	0x7fb58a25, 0xb31f8abb, 0x3d908d58, 0xf13a8dc6,
	0xfbff84df, 0x37558441, 0xb9da83a2, 0x7570833c,
	0x533b85da, 0x9f918544, 0x111e82a7, 0xddb48239,
	0xd7718b20, 0x1bdb8bbe, 0x95548c5d, 0x59fe8cc3,
	0x80de9e6f, 0x4c749ef1, 0xc2fb9912, 0x0e51998c,
	0x04949095, 0xc83e900b, 0x46b197e8, 0x8a1b9776,
	0x2f80b4f1, 0xe32ab46f, 0x6da5b38c, 0xa10fb312,
	0xabcaba0b, 0x6760ba95, 0xe9efbd76, 0x2545bde8,
	0xfc65af44, 0x30cfafda, 0xbe40a839, 0x72eaa8a7,
	0x782fa1be, 0xb485a120, 0x3a0aa6c3, 0xf6a0a65d,
	0xaa4de78c, 0x66e7e712, 0xe868e0f1, 0x24c2e06f,
	0x2e07e976, 0xe2ade9e8, 0x6c22ee0b, 0xa088ee95,
	0x79a8fc39, 0xb502fca7, 0x3b8dfb44, 0xf727fbda,
	0xfde2f2c3, 0x3148f25d, 0xbfc7f5be, 0x736df520,
	0xd6f6d6a7, 0x1a5cd639, 0x94d3d1da, 0x5879d144,
	0x52bcd85d, 0x9e16d8c3, 0x1099df20, 0xdc33dfbe,
	0x0513cd12, 0xc9b9cd8c, 0x4736ca6f, 0x8b9ccaf1,
	0x8159c3e8, 0x4df3c376, 0xc37cc495, 0x0fd6c40b,
	0x7aa64737, 0xb60c47a9, 0x3883404a, 0xf42940d4,
	0xfeec49cd, 0x32464953, 0xbcc94eb0, 0x70634e2e,
	0xa9435c82, 0x65e95c1c, 0xeb665bff, 0x27cc5b61,
	0x2d095278, 0xe1a352e6, 0x6f2c5505, 0xa386559b,
	0x061d761c, 0xcab77682, 0x44387161, 0x889271ff,
	0x825778e6, 0x4efd7878, 0xc0727f9b, 0x0cd87f05,
	0xd5f86da9, 0x19526d37, 0x97dd6ad4, 0x5b776a4a,
	0x51b26353, 0x9d1863cd, 0x1397642e, 0xdf3d64b0,
	0x83d02561, 0x4f7a25ff, 0xc1f5221c, 0x0d5f2282,
	0x079a2b9b, 0xcb302b05, 0x45bf2ce6, 0x89152c78,
	0x50353ed4, 0x9c9f3e4a, 0x121039a9, 0xdeba3937,
	0xd47f302e, 0x18d530b0, 0x965a3753, 0x5af037cd,
	0xff6b144a, 0x33c114d4, 0xbd4e1337, 0x71e413a9,
	0x7b211ab0, 0xb78b1a2e, 0x39041dcd, 0xf5ae1d53,
	0x2c8e0fff, 0xe0240f61, 0x6eab0882, 0xa201081c,
	0xa8c40105, 0x646e019b, 0xeae10678, 0x264b06e6,
};



static u32 MAYBE_UNUSED
crc32_slice8(u32 crc, const u8 *p, size_t len)
{
	const u8 * const end = p + len;
	const u8 *end64;

	for (; ((uintptr_t)p & 7) && p != end; p++)
		crc = (crc >> 8) ^ crc32_slice8_table[(u8)crc ^ *p];

	end64 = p + ((end - p) & ~7);
	for (; p != end64; p += 8) {
		u32 v1 = le32_bswap(*(const u32 *)(p + 0));
		u32 v2 = le32_bswap(*(const u32 *)(p + 4));

		crc = crc32_slice8_table[0x700 + (u8)((crc ^ v1) >> 0)] ^
		      crc32_slice8_table[0x600 + (u8)((crc ^ v1) >> 8)] ^
		      crc32_slice8_table[0x500 + (u8)((crc ^ v1) >> 16)] ^
		      crc32_slice8_table[0x400 + (u8)((crc ^ v1) >> 24)] ^
		      crc32_slice8_table[0x300 + (u8)(v2 >> 0)] ^
		      crc32_slice8_table[0x200 + (u8)(v2 >> 8)] ^
		      crc32_slice8_table[0x100 + (u8)(v2 >> 16)] ^
		      crc32_slice8_table[0x000 + (u8)(v2 >> 24)];
	}

	for (; p != end; p++)
		crc = (crc >> 8) ^ crc32_slice8_table[(u8)crc ^ *p];

	return crc;
}


static forceinline u32 MAYBE_UNUSED
crc32_slice1(u32 crc, const u8 *p, size_t len)
{
	size_t i;

	for (i = 0; i < len; i++)
		crc = (crc >> 8) ^ crc32_slice1_table[(u8)crc ^ p[i]];
	return crc;
}


#undef DEFAULT_IMPL
#undef arch_select_crc32_func
typedef u32 (*crc32_func_t)(u32 crc, const u8 *p, size_t len);
#if defined(ARCH_ARM32) || defined(ARCH_ARM64)
/* #  include "arm/crc32_impl.h" */


#ifndef LIB_ARM_CRC32_IMPL_H
#define LIB_ARM_CRC32_IMPL_H

/* #include "arm-cpu_features.h" */


#ifndef LIB_ARM_CPU_FEATURES_H
#define LIB_ARM_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_ARM32) || defined(ARCH_ARM64)

#define ARM_CPU_FEATURE_NEON		(1 << 0)
#define ARM_CPU_FEATURE_PMULL		(1 << 1)

#define ARM_CPU_FEATURE_PREFER_PMULL	(1 << 2)
#define ARM_CPU_FEATURE_CRC32		(1 << 3)
#define ARM_CPU_FEATURE_SHA3		(1 << 4)
#define ARM_CPU_FEATURE_DOTPROD		(1 << 5)

#if !defined(FREESTANDING) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
    (defined(__linux__) || \
     (defined(__APPLE__) && defined(ARCH_ARM64)) || \
     (defined(_WIN32) && defined(ARCH_ARM64)))

#  define ARM_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_arm_cpu_features;

void libdeflate_init_arm_cpu_features(void);

static inline u32 get_arm_cpu_features(void)
{
	if (libdeflate_arm_cpu_features == 0)
		libdeflate_init_arm_cpu_features();
	return libdeflate_arm_cpu_features;
}
#else
static inline u32 get_arm_cpu_features(void) { return 0; }
#endif


#if defined(__ARM_NEON) || (defined(_MSC_VER) && defined(ARCH_ARM64))
#  define HAVE_NEON(features)	1
#  define HAVE_NEON_NATIVE	1
#else
#  define HAVE_NEON(features)	((features) & ARM_CPU_FEATURE_NEON)
#  define HAVE_NEON_NATIVE	0
#endif

#if (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
	(HAVE_NEON_NATIVE || (GCC_PREREQ(6, 1) && defined(__ARM_FP)))
#  define HAVE_NEON_INTRIN	1
#  include <arm_neon.h>
#else
#  define HAVE_NEON_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRYPTO
#  define HAVE_PMULL(features)	1
#else
#  define HAVE_PMULL(features)	((features) & ARM_CPU_FEATURE_PMULL)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(7, 1) || defined(__clang__) || defined(_MSC_VER)) && \
	CPU_IS_LITTLE_ENDIAN() 
#  define HAVE_PMULL_INTRIN	1
   
#  ifdef _MSC_VER
#    define compat_vmull_p64(a, b)  vmull_p64(vcreate_p64(a), vcreate_p64(b))
#  else
#    define compat_vmull_p64(a, b)  vmull_p64((a), (b))
#  endif
#else
#  define HAVE_PMULL_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRC32
#  define HAVE_CRC32(features)	1
#else
#  define HAVE_CRC32(features)	((features) & ARM_CPU_FEATURE_CRC32)
#endif
#if defined(ARCH_ARM64) && \
	(defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))
#  define HAVE_CRC32_INTRIN	1
#  if defined(__GNUC__) || defined(__clang__)
#    include <arm_acle.h>
#  endif
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_CRC32)
#    undef __crc32b
#    define __crc32b(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32b %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32h
#    define __crc32h(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32h %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32w
#    define __crc32w(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32w %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32d
#    define __crc32d(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32x %w0, %w1, %2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_CRC32_INTRIN	0
#endif


#ifdef __ARM_FEATURE_SHA3
#  define HAVE_SHA3(features)	1
#else
#  define HAVE_SHA3(features)	((features) & ARM_CPU_FEATURE_SHA3)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(9, 1)  || \
	 CLANG_PREREQ(7, 0, 10010463) )
#  define HAVE_SHA3_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_SHA3)
#    undef veor3q_u8
#    define veor3q_u8(a, b, c)					\
	({ uint8x16_t res;					\
	   __asm__("eor3 %0.16b, %1.16b, %2.16b, %3.16b"	\
		   : "=w" (res) : "w" (a), "w" (b), "w" (c));	\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_SHA3_INTRIN	0
#endif


#ifdef __ARM_FEATURE_DOTPROD
#  define HAVE_DOTPROD(features)	1
#else
#  define HAVE_DOTPROD(features)	((features) & ARM_CPU_FEATURE_DOTPROD)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(8, 1) || CLANG_PREREQ(7, 0, 10010000) || defined(_MSC_VER))
#  define HAVE_DOTPROD_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_DOTPROD)
#    undef vdotq_u32
#    define vdotq_u32(a, b, c)					\
	({ uint32x4_t res = (a);				\
	   __asm__("udot %0.4s, %1.16b, %2.16b"			\
		   : "+w" (res) : "w" (b), "w" (c));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_DOTPROD_INTRIN	0
#endif

#endif 

#endif 



#if HAVE_CRC32_INTRIN
#  ifdef __clang__
#    define ATTRIBUTES	_target_attribute("crc")
#  else
#    define ATTRIBUTES	_target_attribute("+crc")
#  endif


static forceinline ATTRIBUTES u32
combine_crcs_slow(u32 crc0, u32 crc1, u32 crc2, u32 crc3)
{
	u64 res0 = 0, res1 = 0, res2 = 0;
	int i;

	
	for (i = 0; i < 32; i++) {
		if (CRC32_FIXED_CHUNK_MULT_3 & (1U << i))
			res0 ^= (u64)crc0 << i;
		if (CRC32_FIXED_CHUNK_MULT_2 & (1U << i))
			res1 ^= (u64)crc1 << i;
		if (CRC32_FIXED_CHUNK_MULT_1 & (1U << i))
			res2 ^= (u64)crc2 << i;
	}
	
	return __crc32d(0, res0 ^ res1 ^ res2) ^ crc3;
}

#define crc32_arm_crc	crc32_arm_crc
static ATTRIBUTES u32
crc32_arm_crc(u32 crc, const u8 *p, size_t len)
{
	if (len >= 64) {
		const size_t align = -(uintptr_t)p & 7;

		
		if (align) {
			if (align & 1)
				crc = __crc32b(crc, *p++);
			if (align & 2) {
				crc = __crc32h(crc, le16_bswap(*(u16 *)p));
				p += 2;
			}
			if (align & 4) {
				crc = __crc32w(crc, le32_bswap(*(u32 *)p));
				p += 4;
			}
			len -= align;
		}
		
		while (len >= CRC32_NUM_CHUNKS * CRC32_FIXED_CHUNK_LEN) {
			const u64 *wp0 = (const u64 *)p;
			const u64 * const wp0_end =
				(const u64 *)(p + CRC32_FIXED_CHUNK_LEN);
			u32 crc1 = 0, crc2 = 0, crc3 = 0;

			STATIC_ASSERT(CRC32_NUM_CHUNKS == 4);
			STATIC_ASSERT(CRC32_FIXED_CHUNK_LEN % (4 * 8) == 0);
			do {
				prefetchr(&wp0[64 + 0*CRC32_FIXED_CHUNK_LEN/8]);
				prefetchr(&wp0[64 + 1*CRC32_FIXED_CHUNK_LEN/8]);
				prefetchr(&wp0[64 + 2*CRC32_FIXED_CHUNK_LEN/8]);
				prefetchr(&wp0[64 + 3*CRC32_FIXED_CHUNK_LEN/8]);
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_FIXED_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_FIXED_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_FIXED_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_FIXED_CHUNK_LEN/8]));
				wp0++;
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_FIXED_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_FIXED_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_FIXED_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_FIXED_CHUNK_LEN/8]));
				wp0++;
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_FIXED_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_FIXED_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_FIXED_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_FIXED_CHUNK_LEN/8]));
				wp0++;
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_FIXED_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_FIXED_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_FIXED_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_FIXED_CHUNK_LEN/8]));
				wp0++;
			} while (wp0 != wp0_end);
			crc = combine_crcs_slow(crc, crc1, crc2, crc3);
			p += CRC32_NUM_CHUNKS * CRC32_FIXED_CHUNK_LEN;
			len -= CRC32_NUM_CHUNKS * CRC32_FIXED_CHUNK_LEN;
		}
		
		while (len >= 64) {
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 0)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 8)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 16)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 24)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 32)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 40)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 48)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 56)));
			p += 64;
			len -= 64;
		}
	}
	if (len & 32) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		crc = __crc32d(crc, get_unaligned_le64(p + 16));
		crc = __crc32d(crc, get_unaligned_le64(p + 24));
		p += 32;
	}
	if (len & 16) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		p += 16;
	}
	if (len & 8) {
		crc = __crc32d(crc, get_unaligned_le64(p));
		p += 8;
	}
	if (len & 4) {
		crc = __crc32w(crc, get_unaligned_le32(p));
		p += 4;
	}
	if (len & 2) {
		crc = __crc32h(crc, get_unaligned_le16(p));
		p += 2;
	}
	if (len & 1)
		crc = __crc32b(crc, *p);
	return crc;
}
#undef ATTRIBUTES
#endif 


#if HAVE_CRC32_INTRIN && HAVE_PMULL_INTRIN
#  ifdef __clang__
#    define ATTRIBUTES	_target_attribute("crc,aes")
#  else
#    define ATTRIBUTES	_target_attribute("+crc,+crypto")
#  endif


static forceinline ATTRIBUTES u64
clmul_u32(u32 a, u32 b)
{
	uint64x2_t res = vreinterpretq_u64_p128(
				compat_vmull_p64((poly64_t)a, (poly64_t)b));

	return vgetq_lane_u64(res, 0);
}


static forceinline ATTRIBUTES u32
combine_crcs_fast(u32 crc0, u32 crc1, u32 crc2, u32 crc3, size_t i)
{
	u64 res0 = clmul_u32(crc0, crc32_mults_for_chunklen[i][0]);
	u64 res1 = clmul_u32(crc1, crc32_mults_for_chunklen[i][1]);
	u64 res2 = clmul_u32(crc2, crc32_mults_for_chunklen[i][2]);

	return __crc32d(0, res0 ^ res1 ^ res2) ^ crc3;
}

#define crc32_arm_crc_pmullcombine	crc32_arm_crc_pmullcombine
static ATTRIBUTES u32
crc32_arm_crc_pmullcombine(u32 crc, const u8 *p, size_t len)
{
	const size_t align = -(uintptr_t)p & 7;

	if (len >= align + CRC32_NUM_CHUNKS * CRC32_MIN_VARIABLE_CHUNK_LEN) {
		
		if (align) {
			if (align & 1)
				crc = __crc32b(crc, *p++);
			if (align & 2) {
				crc = __crc32h(crc, le16_bswap(*(u16 *)p));
				p += 2;
			}
			if (align & 4) {
				crc = __crc32w(crc, le32_bswap(*(u32 *)p));
				p += 4;
			}
			len -= align;
		}
		
		while (len >= CRC32_NUM_CHUNKS * CRC32_MAX_VARIABLE_CHUNK_LEN) {
			const u64 *wp0 = (const u64 *)p;
			const u64 * const wp0_end =
				(const u64 *)(p + CRC32_MAX_VARIABLE_CHUNK_LEN);
			u32 crc1 = 0, crc2 = 0, crc3 = 0;

			STATIC_ASSERT(CRC32_NUM_CHUNKS == 4);
			STATIC_ASSERT(CRC32_MAX_VARIABLE_CHUNK_LEN % (4 * 8) == 0);
			do {
				prefetchr(&wp0[64 + 0*CRC32_MAX_VARIABLE_CHUNK_LEN/8]);
				prefetchr(&wp0[64 + 1*CRC32_MAX_VARIABLE_CHUNK_LEN/8]);
				prefetchr(&wp0[64 + 2*CRC32_MAX_VARIABLE_CHUNK_LEN/8]);
				prefetchr(&wp0[64 + 3*CRC32_MAX_VARIABLE_CHUNK_LEN/8]);
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				wp0++;
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				wp0++;
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				wp0++;
				crc  = __crc32d(crc,  le64_bswap(wp0[0*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc1 = __crc32d(crc1, le64_bswap(wp0[1*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc2 = __crc32d(crc2, le64_bswap(wp0[2*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				crc3 = __crc32d(crc3, le64_bswap(wp0[3*CRC32_MAX_VARIABLE_CHUNK_LEN/8]));
				wp0++;
			} while (wp0 != wp0_end);
			crc = combine_crcs_fast(crc, crc1, crc2, crc3,
						ARRAY_LEN(crc32_mults_for_chunklen) - 1);
			p += CRC32_NUM_CHUNKS * CRC32_MAX_VARIABLE_CHUNK_LEN;
			len -= CRC32_NUM_CHUNKS * CRC32_MAX_VARIABLE_CHUNK_LEN;
		}
		
		if (len >= CRC32_NUM_CHUNKS * CRC32_MIN_VARIABLE_CHUNK_LEN) {
			const size_t i = len / (CRC32_NUM_CHUNKS *
						CRC32_MIN_VARIABLE_CHUNK_LEN);
			const size_t chunk_len =
				i * CRC32_MIN_VARIABLE_CHUNK_LEN;
			const u64 *wp0 = (const u64 *)(p + 0*chunk_len);
			const u64 *wp1 = (const u64 *)(p + 1*chunk_len);
			const u64 *wp2 = (const u64 *)(p + 2*chunk_len);
			const u64 *wp3 = (const u64 *)(p + 3*chunk_len);
			const u64 * const wp0_end = wp1;
			u32 crc1 = 0, crc2 = 0, crc3 = 0;

			STATIC_ASSERT(CRC32_NUM_CHUNKS == 4);
			STATIC_ASSERT(CRC32_MIN_VARIABLE_CHUNK_LEN % (4 * 8) == 0);
			do {
				prefetchr(wp0 + 64);
				prefetchr(wp1 + 64);
				prefetchr(wp2 + 64);
				prefetchr(wp3 + 64);
				crc  = __crc32d(crc,  le64_bswap(*wp0++));
				crc1 = __crc32d(crc1, le64_bswap(*wp1++));
				crc2 = __crc32d(crc2, le64_bswap(*wp2++));
				crc3 = __crc32d(crc3, le64_bswap(*wp3++));
				crc  = __crc32d(crc,  le64_bswap(*wp0++));
				crc1 = __crc32d(crc1, le64_bswap(*wp1++));
				crc2 = __crc32d(crc2, le64_bswap(*wp2++));
				crc3 = __crc32d(crc3, le64_bswap(*wp3++));
				crc  = __crc32d(crc,  le64_bswap(*wp0++));
				crc1 = __crc32d(crc1, le64_bswap(*wp1++));
				crc2 = __crc32d(crc2, le64_bswap(*wp2++));
				crc3 = __crc32d(crc3, le64_bswap(*wp3++));
				crc  = __crc32d(crc,  le64_bswap(*wp0++));
				crc1 = __crc32d(crc1, le64_bswap(*wp1++));
				crc2 = __crc32d(crc2, le64_bswap(*wp2++));
				crc3 = __crc32d(crc3, le64_bswap(*wp3++));
			} while (wp0 != wp0_end);
			crc = combine_crcs_fast(crc, crc1, crc2, crc3, i);
			p += CRC32_NUM_CHUNKS * chunk_len;
			len -= CRC32_NUM_CHUNKS * chunk_len;
		}

		while (len >= 32) {
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 0)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 8)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 16)));
			crc = __crc32d(crc, le64_bswap(*(u64 *)(p + 24)));
			p += 32;
			len -= 32;
		}
	} else {
		while (len >= 32) {
			crc = __crc32d(crc, get_unaligned_le64(p + 0));
			crc = __crc32d(crc, get_unaligned_le64(p + 8));
			crc = __crc32d(crc, get_unaligned_le64(p + 16));
			crc = __crc32d(crc, get_unaligned_le64(p + 24));
			p += 32;
			len -= 32;
		}
	}
	if (len & 16) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		p += 16;
	}
	if (len & 8) {
		crc = __crc32d(crc, get_unaligned_le64(p));
		p += 8;
	}
	if (len & 4) {
		crc = __crc32w(crc, get_unaligned_le32(p));
		p += 4;
	}
	if (len & 2) {
		crc = __crc32h(crc, get_unaligned_le16(p));
		p += 2;
	}
	if (len & 1)
		crc = __crc32b(crc, *p);
	return crc;
}
#undef ATTRIBUTES
#endif 


#if HAVE_PMULL_INTRIN
#  define crc32_arm_pmullx4	crc32_arm_pmullx4
#  define SUFFIX			 _pmullx4
#  ifdef __clang__
     
#    define ATTRIBUTES	_target_attribute("aes")
#  else
     
#    define ATTRIBUTES	_target_attribute("+crypto")
#  endif
#  define ENABLE_EOR3		0
/* #include "arm-crc32_pmull_helpers.h" */





#undef u32_to_bytevec
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(u32_to_bytevec)(u32 a)
{
	return vreinterpretq_u8_u32(vsetq_lane_u32(a, vdupq_n_u32(0), 0));
}
#define u32_to_bytevec	ADD_SUFFIX(u32_to_bytevec)


#undef load_multipliers
static forceinline ATTRIBUTES poly64x2_t
ADD_SUFFIX(load_multipliers)(const u64 p[2])
{
	return vreinterpretq_p64_u64(vld1q_u64(p));
}
#define load_multipliers	ADD_SUFFIX(load_multipliers)


#undef clmul_low
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(clmul_low)(uint8x16_t a, poly64x2_t b)
{
	return vreinterpretq_u8_p128(
		     compat_vmull_p64(vgetq_lane_p64(vreinterpretq_p64_u8(a), 0),
				      vgetq_lane_p64(b, 0)));
}
#define clmul_low	ADD_SUFFIX(clmul_low)


#undef clmul_high
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(clmul_high)(uint8x16_t a, poly64x2_t b)
{
#ifdef __clang__
	
	uint8x16_t res;

	__asm__("pmull2 %0.1q, %1.2d, %2.2d" : "=w" (res) : "w" (a), "w" (b));
	return res;
#else
	return vreinterpretq_u8_p128(vmull_high_p64(vreinterpretq_p64_u8(a), b));
#endif
}
#define clmul_high	ADD_SUFFIX(clmul_high)

#undef eor3
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(eor3)(uint8x16_t a, uint8x16_t b, uint8x16_t c)
{
#if ENABLE_EOR3
	return veor3q_u8(a, b, c);
#else
	return veorq_u8(veorq_u8(a, b), c);
#endif
}
#define eor3	ADD_SUFFIX(eor3)

#undef fold_vec
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(fold_vec)(uint8x16_t src, uint8x16_t dst, poly64x2_t multipliers)
{
	uint8x16_t a = clmul_low(src, multipliers);
	uint8x16_t b = clmul_high(src, multipliers);

	return eor3(a, b, dst);
}
#define fold_vec	ADD_SUFFIX(fold_vec)


#undef fold_partial_vec
static forceinline ATTRIBUTES MAYBE_UNUSED uint8x16_t
ADD_SUFFIX(fold_partial_vec)(uint8x16_t v, const u8 *p, size_t len,
			     poly64x2_t multipliers_1)
{
	
	static const u8 shift_tab[48] = {
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
		0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	};
	const uint8x16_t lshift = vld1q_u8(&shift_tab[len]);
	const uint8x16_t rshift = vld1q_u8(&shift_tab[len + 16]);
	uint8x16_t x0, x1, bsl_mask;

	
	x0 = vqtbl1q_u8(v, lshift);

	
	bsl_mask = vreinterpretq_u8_s8(
			vshrq_n_s8(vreinterpretq_s8_u8(rshift), 7));

	
	x1 = vbslq_u8(bsl_mask ,
		      vld1q_u8(p + len - 16), vqtbl1q_u8(v, rshift));

	return fold_vec(x0, x1, multipliers_1);
}
#define fold_partial_vec	ADD_SUFFIX(fold_partial_vec)


static ATTRIBUTES u32
crc32_arm_pmullx4(u32 crc, const u8 *p, size_t len)
{
	static const u64 _aligned_attribute(16) mults[3][2] = {
		{ CRC32_X159_MODG, CRC32_X95_MODG },  
		{ CRC32_X543_MODG, CRC32_X479_MODG }, 
		{ CRC32_X287_MODG, CRC32_X223_MODG }, 
	};
	static const u64 _aligned_attribute(16) barrett_consts[3][2] = {
		{ CRC32_X95_MODG, },
		{ CRC32_BARRETT_CONSTANT_1, },
		{ CRC32_BARRETT_CONSTANT_2, },
	};
	const poly64x2_t multipliers_1 = load_multipliers(mults[0]);
	uint8x16_t v0, v1, v2, v3;

	if (len < 64 + 15) {
		if (len < 16)
			return crc32_slice1(crc, p, len);
		v0 = veorq_u8(vld1q_u8(p), u32_to_bytevec(crc));
		p += 16;
		len -= 16;
		while (len >= 16) {
			v0 = fold_vec(v0, vld1q_u8(p), multipliers_1);
			p += 16;
			len -= 16;
		}
	} else {
		const poly64x2_t multipliers_4 = load_multipliers(mults[1]);
		const poly64x2_t multipliers_2 = load_multipliers(mults[2]);
		const size_t align = -(uintptr_t)p & 15;
		const uint8x16_t *vp;

		v0 = veorq_u8(vld1q_u8(p), u32_to_bytevec(crc));
		p += 16;
		
		if (align) {
			v0 = fold_partial_vec(v0, p, align, multipliers_1);
			p += align;
			len -= align;
		}
		vp = (const uint8x16_t *)p;
		v1 = *vp++;
		v2 = *vp++;
		v3 = *vp++;
		while (len >= 64 + 64) {
			v0 = fold_vec(v0, *vp++, multipliers_4);
			v1 = fold_vec(v1, *vp++, multipliers_4);
			v2 = fold_vec(v2, *vp++, multipliers_4);
			v3 = fold_vec(v3, *vp++, multipliers_4);
			len -= 64;
		}
		v0 = fold_vec(v0, v2, multipliers_2);
		v1 = fold_vec(v1, v3, multipliers_2);
		if (len & 32) {
			v0 = fold_vec(v0, *vp++, multipliers_2);
			v1 = fold_vec(v1, *vp++, multipliers_2);
		}
		v0 = fold_vec(v0, v1, multipliers_1);
		if (len & 16)
			v0 = fold_vec(v0, *vp++, multipliers_1);
		p = (const u8 *)vp;
		len &= 15;
	}

	
	if (len)
		v0 = fold_partial_vec(v0, p, len, multipliers_1);

	
	v0 = veorq_u8(clmul_low(v0, load_multipliers(barrett_consts[0])),
		      vextq_u8(v0, vdupq_n_u8(0), 8));
	v1 = clmul_low(v0, load_multipliers(barrett_consts[1]));
	v1 = clmul_low(v1, load_multipliers(barrett_consts[2]));
	v0 = veorq_u8(v0, v1);
	return vgetq_lane_u32(vreinterpretq_u32_u8(v0), 2);
}
#undef SUFFIX
#undef ATTRIBUTES
#undef ENABLE_EOR3
#endif 


#if HAVE_PMULL_INTRIN && HAVE_CRC32_INTRIN
#  define crc32_arm_pmullx12_crc	crc32_arm_pmullx12_crc
#  define SUFFIX				 _pmullx12_crc
#  ifdef __clang__
#    define ATTRIBUTES	_target_attribute("aes,crc")
#  else
#    define ATTRIBUTES	_target_attribute("+crypto,+crc")
#  endif
#  define ENABLE_EOR3	0
/* #include "arm-crc32_pmull_wide.h" */




/* #include "arm-crc32_pmull_helpers.h" */





#undef u32_to_bytevec
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(u32_to_bytevec)(u32 a)
{
	return vreinterpretq_u8_u32(vsetq_lane_u32(a, vdupq_n_u32(0), 0));
}
#define u32_to_bytevec	ADD_SUFFIX(u32_to_bytevec)


#undef load_multipliers
static forceinline ATTRIBUTES poly64x2_t
ADD_SUFFIX(load_multipliers)(const u64 p[2])
{
	return vreinterpretq_p64_u64(vld1q_u64(p));
}
#define load_multipliers	ADD_SUFFIX(load_multipliers)


#undef clmul_low
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(clmul_low)(uint8x16_t a, poly64x2_t b)
{
	return vreinterpretq_u8_p128(
		     compat_vmull_p64(vgetq_lane_p64(vreinterpretq_p64_u8(a), 0),
				      vgetq_lane_p64(b, 0)));
}
#define clmul_low	ADD_SUFFIX(clmul_low)


#undef clmul_high
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(clmul_high)(uint8x16_t a, poly64x2_t b)
{
#ifdef __clang__
	
	uint8x16_t res;

	__asm__("pmull2 %0.1q, %1.2d, %2.2d" : "=w" (res) : "w" (a), "w" (b));
	return res;
#else
	return vreinterpretq_u8_p128(vmull_high_p64(vreinterpretq_p64_u8(a), b));
#endif
}
#define clmul_high	ADD_SUFFIX(clmul_high)

#undef eor3
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(eor3)(uint8x16_t a, uint8x16_t b, uint8x16_t c)
{
#if ENABLE_EOR3
	return veor3q_u8(a, b, c);
#else
	return veorq_u8(veorq_u8(a, b), c);
#endif
}
#define eor3	ADD_SUFFIX(eor3)

#undef fold_vec
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(fold_vec)(uint8x16_t src, uint8x16_t dst, poly64x2_t multipliers)
{
	uint8x16_t a = clmul_low(src, multipliers);
	uint8x16_t b = clmul_high(src, multipliers);

	return eor3(a, b, dst);
}
#define fold_vec	ADD_SUFFIX(fold_vec)


#undef fold_partial_vec
static forceinline ATTRIBUTES MAYBE_UNUSED uint8x16_t
ADD_SUFFIX(fold_partial_vec)(uint8x16_t v, const u8 *p, size_t len,
			     poly64x2_t multipliers_1)
{
	
	static const u8 shift_tab[48] = {
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
		0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	};
	const uint8x16_t lshift = vld1q_u8(&shift_tab[len]);
	const uint8x16_t rshift = vld1q_u8(&shift_tab[len + 16]);
	uint8x16_t x0, x1, bsl_mask;

	
	x0 = vqtbl1q_u8(v, lshift);

	
	bsl_mask = vreinterpretq_u8_s8(
			vshrq_n_s8(vreinterpretq_s8_u8(rshift), 7));

	
	x1 = vbslq_u8(bsl_mask ,
		      vld1q_u8(p + len - 16), vqtbl1q_u8(v, rshift));

	return fold_vec(x0, x1, multipliers_1);
}
#define fold_partial_vec	ADD_SUFFIX(fold_partial_vec)


static ATTRIBUTES u32
ADD_SUFFIX(crc32_arm)(u32 crc, const u8 *p, size_t len)
{
	uint8x16_t v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11;

	if (len < 3 * 192) {
		static const u64 _aligned_attribute(16) mults[3][2] = {
			{ CRC32_X543_MODG, CRC32_X479_MODG }, 
			{ CRC32_X287_MODG, CRC32_X223_MODG }, 
			{ CRC32_X159_MODG, CRC32_X95_MODG },  
		};
		poly64x2_t multipliers_4, multipliers_2, multipliers_1;

		if (len < 64)
			goto tail;
		multipliers_4 = load_multipliers(mults[0]);
		multipliers_2 = load_multipliers(mults[1]);
		multipliers_1 = load_multipliers(mults[2]);
		
		v0 = veorq_u8(vld1q_u8(p + 0), u32_to_bytevec(crc));
		v1 = vld1q_u8(p + 16);
		v2 = vld1q_u8(p + 32);
		v3 = vld1q_u8(p + 48);
		p += 64;
		len -= 64;
		while (len >= 64) {
			v0 = fold_vec(v0, vld1q_u8(p + 0), multipliers_4);
			v1 = fold_vec(v1, vld1q_u8(p + 16), multipliers_4);
			v2 = fold_vec(v2, vld1q_u8(p + 32), multipliers_4);
			v3 = fold_vec(v3, vld1q_u8(p + 48), multipliers_4);
			p += 64;
			len -= 64;
		}
		v0 = fold_vec(v0, v2, multipliers_2);
		v1 = fold_vec(v1, v3, multipliers_2);
		if (len >= 32) {
			v0 = fold_vec(v0, vld1q_u8(p + 0), multipliers_2);
			v1 = fold_vec(v1, vld1q_u8(p + 16), multipliers_2);
			p += 32;
			len -= 32;
		}
		v0 = fold_vec(v0, v1, multipliers_1);
	} else {
		static const u64 _aligned_attribute(16) mults[4][2] = {
			{ CRC32_X1567_MODG, CRC32_X1503_MODG }, 
			{ CRC32_X799_MODG, CRC32_X735_MODG },   
			{ CRC32_X415_MODG, CRC32_X351_MODG },   
			{ CRC32_X159_MODG, CRC32_X95_MODG },    
		};
		const poly64x2_t multipliers_12 = load_multipliers(mults[0]);
		const poly64x2_t multipliers_6 = load_multipliers(mults[1]);
		const poly64x2_t multipliers_3 = load_multipliers(mults[2]);
		const poly64x2_t multipliers_1 = load_multipliers(mults[3]);
		const size_t align = -(uintptr_t)p & 15;
		const uint8x16_t *vp;

		
		if (align) {
			if (align & 1)
				crc = __crc32b(crc, *p++);
			if (align & 2) {
				crc = __crc32h(crc, le16_bswap(*(u16 *)p));
				p += 2;
			}
			if (align & 4) {
				crc = __crc32w(crc, le32_bswap(*(u32 *)p));
				p += 4;
			}
			if (align & 8) {
				crc = __crc32d(crc, le64_bswap(*(u64 *)p));
				p += 8;
			}
			len -= align;
		}
		vp = (const uint8x16_t *)p;
		v0 = veorq_u8(*vp++, u32_to_bytevec(crc));
		v1 = *vp++;
		v2 = *vp++;
		v3 = *vp++;
		v4 = *vp++;
		v5 = *vp++;
		v6 = *vp++;
		v7 = *vp++;
		v8 = *vp++;
		v9 = *vp++;
		v10 = *vp++;
		v11 = *vp++;
		len -= 192;
		
		do {
			v0 = fold_vec(v0, *vp++, multipliers_12);
			v1 = fold_vec(v1, *vp++, multipliers_12);
			v2 = fold_vec(v2, *vp++, multipliers_12);
			v3 = fold_vec(v3, *vp++, multipliers_12);
			v4 = fold_vec(v4, *vp++, multipliers_12);
			v5 = fold_vec(v5, *vp++, multipliers_12);
			v6 = fold_vec(v6, *vp++, multipliers_12);
			v7 = fold_vec(v7, *vp++, multipliers_12);
			v8 = fold_vec(v8, *vp++, multipliers_12);
			v9 = fold_vec(v9, *vp++, multipliers_12);
			v10 = fold_vec(v10, *vp++, multipliers_12);
			v11 = fold_vec(v11, *vp++, multipliers_12);
			len -= 192;
		} while (len >= 192);

		
		v0 = fold_vec(v0, v6, multipliers_6);
		v1 = fold_vec(v1, v7, multipliers_6);
		v2 = fold_vec(v2, v8, multipliers_6);
		v3 = fold_vec(v3, v9, multipliers_6);
		v4 = fold_vec(v4, v10, multipliers_6);
		v5 = fold_vec(v5, v11, multipliers_6);
		if (len >= 96) {
			v0 = fold_vec(v0, *vp++, multipliers_6);
			v1 = fold_vec(v1, *vp++, multipliers_6);
			v2 = fold_vec(v2, *vp++, multipliers_6);
			v3 = fold_vec(v3, *vp++, multipliers_6);
			v4 = fold_vec(v4, *vp++, multipliers_6);
			v5 = fold_vec(v5, *vp++, multipliers_6);
			len -= 96;
		}
		v0 = fold_vec(v0, v3, multipliers_3);
		v1 = fold_vec(v1, v4, multipliers_3);
		v2 = fold_vec(v2, v5, multipliers_3);
		if (len >= 48) {
			v0 = fold_vec(v0, *vp++, multipliers_3);
			v1 = fold_vec(v1, *vp++, multipliers_3);
			v2 = fold_vec(v2, *vp++, multipliers_3);
			len -= 48;
		}
		v0 = fold_vec(v0, v1, multipliers_1);
		v0 = fold_vec(v0, v2, multipliers_1);
		p = (const u8 *)vp;
	}
	
	crc = __crc32d(0, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 0));
	crc = __crc32d(crc, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 1));
tail:
	
	if (len & 32) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		crc = __crc32d(crc, get_unaligned_le64(p + 16));
		crc = __crc32d(crc, get_unaligned_le64(p + 24));
		p += 32;
	}
	if (len & 16) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		p += 16;
	}
	if (len & 8) {
		crc = __crc32d(crc, get_unaligned_le64(p));
		p += 8;
	}
	if (len & 4) {
		crc = __crc32w(crc, get_unaligned_le32(p));
		p += 4;
	}
	if (len & 2) {
		crc = __crc32h(crc, get_unaligned_le16(p));
		p += 2;
	}
	if (len & 1)
		crc = __crc32b(crc, *p);
	return crc;
}

#undef SUFFIX
#undef ATTRIBUTES
#undef ENABLE_EOR3

#endif


#if HAVE_PMULL_INTRIN && HAVE_CRC32_INTRIN && HAVE_SHA3_INTRIN && \
	!defined(LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_SHA3)
#  define crc32_arm_pmullx12_crc_eor3	crc32_arm_pmullx12_crc_eor3
#  define SUFFIX				 _pmullx12_crc_eor3
#  ifdef __clang__
#    define ATTRIBUTES	_target_attribute("aes,crc,sha3")
   
#  elif GCC_PREREQ(14, 0) || defined(__ARM_FEATURE_JCVT) \
			  || defined(__ARM_FEATURE_DOTPROD)
#    define ATTRIBUTES	_target_attribute("+crypto,+crc,+sha3")
#  else
#    define ATTRIBUTES	_target_attribute("arch=armv8.2-a+crypto+crc+sha3")
#  endif
#  define ENABLE_EOR3	1
/* #include "arm-crc32_pmull_wide.h" */




/* #include "arm-crc32_pmull_helpers.h" */





#undef u32_to_bytevec
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(u32_to_bytevec)(u32 a)
{
	return vreinterpretq_u8_u32(vsetq_lane_u32(a, vdupq_n_u32(0), 0));
}
#define u32_to_bytevec	ADD_SUFFIX(u32_to_bytevec)


#undef load_multipliers
static forceinline ATTRIBUTES poly64x2_t
ADD_SUFFIX(load_multipliers)(const u64 p[2])
{
	return vreinterpretq_p64_u64(vld1q_u64(p));
}
#define load_multipliers	ADD_SUFFIX(load_multipliers)


#undef clmul_low
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(clmul_low)(uint8x16_t a, poly64x2_t b)
{
	return vreinterpretq_u8_p128(
		     compat_vmull_p64(vgetq_lane_p64(vreinterpretq_p64_u8(a), 0),
				      vgetq_lane_p64(b, 0)));
}
#define clmul_low	ADD_SUFFIX(clmul_low)


#undef clmul_high
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(clmul_high)(uint8x16_t a, poly64x2_t b)
{
#ifdef __clang__
	
	uint8x16_t res;

	__asm__("pmull2 %0.1q, %1.2d, %2.2d" : "=w" (res) : "w" (a), "w" (b));
	return res;
#else
	return vreinterpretq_u8_p128(vmull_high_p64(vreinterpretq_p64_u8(a), b));
#endif
}
#define clmul_high	ADD_SUFFIX(clmul_high)

#undef eor3
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(eor3)(uint8x16_t a, uint8x16_t b, uint8x16_t c)
{
#if ENABLE_EOR3
	return veor3q_u8(a, b, c);
#else
	return veorq_u8(veorq_u8(a, b), c);
#endif
}
#define eor3	ADD_SUFFIX(eor3)

#undef fold_vec
static forceinline ATTRIBUTES uint8x16_t
ADD_SUFFIX(fold_vec)(uint8x16_t src, uint8x16_t dst, poly64x2_t multipliers)
{
	uint8x16_t a = clmul_low(src, multipliers);
	uint8x16_t b = clmul_high(src, multipliers);

	return eor3(a, b, dst);
}
#define fold_vec	ADD_SUFFIX(fold_vec)


#undef fold_partial_vec
static forceinline ATTRIBUTES MAYBE_UNUSED uint8x16_t
ADD_SUFFIX(fold_partial_vec)(uint8x16_t v, const u8 *p, size_t len,
			     poly64x2_t multipliers_1)
{
	
	static const u8 shift_tab[48] = {
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
		0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	};
	const uint8x16_t lshift = vld1q_u8(&shift_tab[len]);
	const uint8x16_t rshift = vld1q_u8(&shift_tab[len + 16]);
	uint8x16_t x0, x1, bsl_mask;

	
	x0 = vqtbl1q_u8(v, lshift);

	
	bsl_mask = vreinterpretq_u8_s8(
			vshrq_n_s8(vreinterpretq_s8_u8(rshift), 7));

	
	x1 = vbslq_u8(bsl_mask ,
		      vld1q_u8(p + len - 16), vqtbl1q_u8(v, rshift));

	return fold_vec(x0, x1, multipliers_1);
}
#define fold_partial_vec	ADD_SUFFIX(fold_partial_vec)


static ATTRIBUTES u32
ADD_SUFFIX(crc32_arm)(u32 crc, const u8 *p, size_t len)
{
	uint8x16_t v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11;

	if (len < 3 * 192) {
		static const u64 _aligned_attribute(16) mults[3][2] = {
			{ CRC32_X543_MODG, CRC32_X479_MODG }, 
			{ CRC32_X287_MODG, CRC32_X223_MODG }, 
			{ CRC32_X159_MODG, CRC32_X95_MODG },  
		};
		poly64x2_t multipliers_4, multipliers_2, multipliers_1;

		if (len < 64)
			goto tail;
		multipliers_4 = load_multipliers(mults[0]);
		multipliers_2 = load_multipliers(mults[1]);
		multipliers_1 = load_multipliers(mults[2]);
		
		v0 = veorq_u8(vld1q_u8(p + 0), u32_to_bytevec(crc));
		v1 = vld1q_u8(p + 16);
		v2 = vld1q_u8(p + 32);
		v3 = vld1q_u8(p + 48);
		p += 64;
		len -= 64;
		while (len >= 64) {
			v0 = fold_vec(v0, vld1q_u8(p + 0), multipliers_4);
			v1 = fold_vec(v1, vld1q_u8(p + 16), multipliers_4);
			v2 = fold_vec(v2, vld1q_u8(p + 32), multipliers_4);
			v3 = fold_vec(v3, vld1q_u8(p + 48), multipliers_4);
			p += 64;
			len -= 64;
		}
		v0 = fold_vec(v0, v2, multipliers_2);
		v1 = fold_vec(v1, v3, multipliers_2);
		if (len >= 32) {
			v0 = fold_vec(v0, vld1q_u8(p + 0), multipliers_2);
			v1 = fold_vec(v1, vld1q_u8(p + 16), multipliers_2);
			p += 32;
			len -= 32;
		}
		v0 = fold_vec(v0, v1, multipliers_1);
	} else {
		static const u64 _aligned_attribute(16) mults[4][2] = {
			{ CRC32_X1567_MODG, CRC32_X1503_MODG }, 
			{ CRC32_X799_MODG, CRC32_X735_MODG },   
			{ CRC32_X415_MODG, CRC32_X351_MODG },   
			{ CRC32_X159_MODG, CRC32_X95_MODG },    
		};
		const poly64x2_t multipliers_12 = load_multipliers(mults[0]);
		const poly64x2_t multipliers_6 = load_multipliers(mults[1]);
		const poly64x2_t multipliers_3 = load_multipliers(mults[2]);
		const poly64x2_t multipliers_1 = load_multipliers(mults[3]);
		const size_t align = -(uintptr_t)p & 15;
		const uint8x16_t *vp;

		
		if (align) {
			if (align & 1)
				crc = __crc32b(crc, *p++);
			if (align & 2) {
				crc = __crc32h(crc, le16_bswap(*(u16 *)p));
				p += 2;
			}
			if (align & 4) {
				crc = __crc32w(crc, le32_bswap(*(u32 *)p));
				p += 4;
			}
			if (align & 8) {
				crc = __crc32d(crc, le64_bswap(*(u64 *)p));
				p += 8;
			}
			len -= align;
		}
		vp = (const uint8x16_t *)p;
		v0 = veorq_u8(*vp++, u32_to_bytevec(crc));
		v1 = *vp++;
		v2 = *vp++;
		v3 = *vp++;
		v4 = *vp++;
		v5 = *vp++;
		v6 = *vp++;
		v7 = *vp++;
		v8 = *vp++;
		v9 = *vp++;
		v10 = *vp++;
		v11 = *vp++;
		len -= 192;
		
		do {
			v0 = fold_vec(v0, *vp++, multipliers_12);
			v1 = fold_vec(v1, *vp++, multipliers_12);
			v2 = fold_vec(v2, *vp++, multipliers_12);
			v3 = fold_vec(v3, *vp++, multipliers_12);
			v4 = fold_vec(v4, *vp++, multipliers_12);
			v5 = fold_vec(v5, *vp++, multipliers_12);
			v6 = fold_vec(v6, *vp++, multipliers_12);
			v7 = fold_vec(v7, *vp++, multipliers_12);
			v8 = fold_vec(v8, *vp++, multipliers_12);
			v9 = fold_vec(v9, *vp++, multipliers_12);
			v10 = fold_vec(v10, *vp++, multipliers_12);
			v11 = fold_vec(v11, *vp++, multipliers_12);
			len -= 192;
		} while (len >= 192);

		
		v0 = fold_vec(v0, v6, multipliers_6);
		v1 = fold_vec(v1, v7, multipliers_6);
		v2 = fold_vec(v2, v8, multipliers_6);
		v3 = fold_vec(v3, v9, multipliers_6);
		v4 = fold_vec(v4, v10, multipliers_6);
		v5 = fold_vec(v5, v11, multipliers_6);
		if (len >= 96) {
			v0 = fold_vec(v0, *vp++, multipliers_6);
			v1 = fold_vec(v1, *vp++, multipliers_6);
			v2 = fold_vec(v2, *vp++, multipliers_6);
			v3 = fold_vec(v3, *vp++, multipliers_6);
			v4 = fold_vec(v4, *vp++, multipliers_6);
			v5 = fold_vec(v5, *vp++, multipliers_6);
			len -= 96;
		}
		v0 = fold_vec(v0, v3, multipliers_3);
		v1 = fold_vec(v1, v4, multipliers_3);
		v2 = fold_vec(v2, v5, multipliers_3);
		if (len >= 48) {
			v0 = fold_vec(v0, *vp++, multipliers_3);
			v1 = fold_vec(v1, *vp++, multipliers_3);
			v2 = fold_vec(v2, *vp++, multipliers_3);
			len -= 48;
		}
		v0 = fold_vec(v0, v1, multipliers_1);
		v0 = fold_vec(v0, v2, multipliers_1);
		p = (const u8 *)vp;
	}
	
	crc = __crc32d(0, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 0));
	crc = __crc32d(crc, vgetq_lane_u64(vreinterpretq_u64_u8(v0), 1));
tail:
	
	if (len & 32) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		crc = __crc32d(crc, get_unaligned_le64(p + 16));
		crc = __crc32d(crc, get_unaligned_le64(p + 24));
		p += 32;
	}
	if (len & 16) {
		crc = __crc32d(crc, get_unaligned_le64(p + 0));
		crc = __crc32d(crc, get_unaligned_le64(p + 8));
		p += 16;
	}
	if (len & 8) {
		crc = __crc32d(crc, get_unaligned_le64(p));
		p += 8;
	}
	if (len & 4) {
		crc = __crc32w(crc, get_unaligned_le32(p));
		p += 4;
	}
	if (len & 2) {
		crc = __crc32h(crc, get_unaligned_le16(p));
		p += 2;
	}
	if (len & 1)
		crc = __crc32b(crc, *p);
	return crc;
}

#undef SUFFIX
#undef ATTRIBUTES
#undef ENABLE_EOR3

#endif

static inline crc32_func_t
arch_select_crc32_func(void)
{
	const u32 features MAYBE_UNUSED = get_arm_cpu_features();

#ifdef crc32_arm_pmullx12_crc_eor3
	if ((features & ARM_CPU_FEATURE_PREFER_PMULL) &&
	    HAVE_PMULL(features) && HAVE_CRC32(features) && HAVE_SHA3(features))
		return crc32_arm_pmullx12_crc_eor3;
#endif
#ifdef crc32_arm_pmullx12_crc
	if ((features & ARM_CPU_FEATURE_PREFER_PMULL) &&
	    HAVE_PMULL(features) && HAVE_CRC32(features))
		return crc32_arm_pmullx12_crc;
#endif
#ifdef crc32_arm_crc_pmullcombine
	if (HAVE_CRC32(features) && HAVE_PMULL(features))
		return crc32_arm_crc_pmullcombine;
#endif
#ifdef crc32_arm_crc
	if (HAVE_CRC32(features))
		return crc32_arm_crc;
#endif
#ifdef crc32_arm_pmullx4
	if (HAVE_PMULL(features))
		return crc32_arm_pmullx4;
#endif
	return NULL;
}
#define arch_select_crc32_func	arch_select_crc32_func

#endif 

#elif defined(ARCH_X86_32) || defined(ARCH_X86_64)
/* #  include "x86/crc32_impl.h" */


#ifndef LIB_X86_CRC32_IMPL_H
#define LIB_X86_CRC32_IMPL_H

/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 



static const u8 MAYBE_UNUSED shift_tab[48] = {
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
	0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
};

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define crc32_x86_pclmulqdq	crc32_x86_pclmulqdq
#  define SUFFIX			 _pclmulqdq
#  define ATTRIBUTES		_target_attribute("pclmul,sse4.1")
#  define VL			16
#  define USE_AVX512		0
/* #include "x86-crc32_pclmul_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define fold_vec		fold_vec128
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VXOR(a, b)		_mm_xor_si128((a), (b))
#  define M128I_TO_VEC(a)	a
#  define MULTS_8V		_mm_set_epi64x(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_4V		_mm_set_epi64x(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_2V		_mm_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG)
#  define MULTS_1V		_mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG)
#elif VL == 32
#  define vec_t			__m256i
#  define fold_vec		fold_vec256
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VXOR(a, b)		_mm256_xor_si256((a), (b))
#  define M128I_TO_VEC(a)	_mm256_zextsi128_si256(a)
#  define MULTS(a, b)		_mm256_set_epi64x(a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_4V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_2V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_1V		MULTS(CRC32_X223_MODG, CRC32_X287_MODG)
#elif VL == 64
#  define vec_t			__m512i
#  define fold_vec		fold_vec512
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VXOR(a, b)		_mm512_xor_si512((a), (b))
#  define M128I_TO_VEC(a)	_mm512_zextsi128_si512(a)
#  define MULTS(a, b)		_mm512_set_epi64(a, b, a, b, a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X4063_MODG, CRC32_X4127_MODG)
#  define MULTS_4V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_2V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_1V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#else
#  error "unsupported vector length"
#endif

#undef fold_vec128
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_vec128)(__m128i src, __m128i dst, __m128i  mults)
{
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x00));
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x11));
	return dst;
}
#define fold_vec128	ADD_SUFFIX(fold_vec128)

#if VL >= 32
#undef fold_vec256
static forceinline ATTRIBUTES __m256i
ADD_SUFFIX(fold_vec256)(__m256i src, __m256i dst, __m256i  mults)
{
#if USE_AVX512
	
	return _mm256_ternarylogic_epi32(
			_mm256_clmulepi64_epi128(src, mults, 0x00),
			_mm256_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
#else
	return _mm256_xor_si256(
			_mm256_xor_si256(dst,
					 _mm256_clmulepi64_epi128(src, mults, 0x00)),
			_mm256_clmulepi64_epi128(src, mults, 0x11));
#endif
}
#define fold_vec256	ADD_SUFFIX(fold_vec256)
#endif 

#if VL >= 64
#undef fold_vec512
static forceinline ATTRIBUTES __m512i
ADD_SUFFIX(fold_vec512)(__m512i src, __m512i dst, __m512i  mults)
{
	
	return _mm512_ternarylogic_epi32(
			_mm512_clmulepi64_epi128(src, mults, 0x00),
			_mm512_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
}
#define fold_vec512	ADD_SUFFIX(fold_vec512)
#endif 


#undef fold_lessthan16bytes
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_lessthan16bytes)(__m128i x, const u8 *p, size_t len,
				 __m128i  mults_128b)
{
	__m128i lshift = _mm_loadu_si128((const void *)&shift_tab[len]);
	__m128i rshift = _mm_loadu_si128((const void *)&shift_tab[len + 16]);
	__m128i x0, x1;

	
	x0 = _mm_shuffle_epi8(x, lshift);

	
	x1 = _mm_blendv_epi8(_mm_shuffle_epi8(x, rshift),
			     _mm_loadu_si128((const void *)(p + len - 16)),
			     
			     rshift);

	return fold_vec128(x0, x1, mults_128b);
}
#define fold_lessthan16bytes	ADD_SUFFIX(fold_lessthan16bytes)

static ATTRIBUTES u32
ADD_SUFFIX(crc32_x86)(u32 crc, const u8 *p, size_t len)
{
	
	const vec_t mults_8v = MULTS_8V;
	const vec_t mults_4v = MULTS_4V;
	const vec_t mults_2v = MULTS_2V;
	const vec_t mults_1v = MULTS_1V;
	const __m128i mults_128b = _mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG);
	const __m128i barrett_reduction_constants =
		_mm_set_epi64x(CRC32_BARRETT_CONSTANT_2, CRC32_BARRETT_CONSTANT_1);
	vec_t v0, v1, v2, v3, v4, v5, v6, v7;
	__m128i x0 = _mm_cvtsi32_si128(crc);
	__m128i x1;

	if (len < 8*VL) {
		if (len < VL) {
			STATIC_ASSERT(VL == 16 || VL == 32 || VL == 64);
			if (len < 16) {
			#if USE_AVX512
				if (len < 4)
					return crc32_slice1(crc, p, len);
				
				x0 = _mm_xor_si128(
					x0, _mm_maskz_loadu_epi8((1 << len) - 1, p));
				x0 = _mm_shuffle_epi8(
					x0, _mm_loadu_si128((const void *)&shift_tab[len]));
				goto reduce_x0;
			#else
				return crc32_slice1(crc, p, len);
			#endif
			}
			
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			if (len >= 32) {
				x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 16)),
						 mults_128b);
				if (len >= 48)
					x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 32)),
							 mults_128b);
			}
			p += len & ~15;
			goto less_than_16_remaining;
		}
		v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		if (len < 2*VL) {
			p += VL;
			goto less_than_vl_remaining;
		}
		v1 = VLOADU(p + 1*VL);
		if (len < 4*VL) {
			p += 2*VL;
			goto less_than_2vl_remaining;
		}
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		p += 4*VL;
	} else {
		
		if (len > 65536 && ((uintptr_t)p & (VL-1))) {
			size_t align = -(uintptr_t)p & (VL-1);

			len -= align;
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			p += 16;
			if (align & 15) {
				x0 = fold_lessthan16bytes(x0, p, align & 15,
							  mults_128b);
				p += align & 15;
				align &= ~15;
			}
			while (align) {
				x0 = fold_vec128(x0, *(const __m128i *)p,
						 mults_128b);
				p += 16;
				align -= 16;
			}
			v0 = M128I_TO_VEC(x0);
		#  if VL == 32
			v0 = _mm256_inserti128_si256(v0, *(const __m128i *)p, 1);
		#  elif VL == 64
			v0 = _mm512_inserti32x4(v0, *(const __m128i *)p, 1);
			v0 = _mm512_inserti64x4(v0, *(const __m256i *)(p + 16), 1);
		#  endif
			p -= 16;
		} else {
			v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		}
		v1 = VLOADU(p + 1*VL);
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		v4 = VLOADU(p + 4*VL);
		v5 = VLOADU(p + 5*VL);
		v6 = VLOADU(p + 6*VL);
		v7 = VLOADU(p + 7*VL);
		p += 8*VL;

		
		while (len >= 16*VL) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_8v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_8v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_8v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_8v);
			v4 = fold_vec(v4, VLOADU(p + 4*VL), mults_8v);
			v5 = fold_vec(v5, VLOADU(p + 5*VL), mults_8v);
			v6 = fold_vec(v6, VLOADU(p + 6*VL), mults_8v);
			v7 = fold_vec(v7, VLOADU(p + 7*VL), mults_8v);
			p += 8*VL;
			len -= 8*VL;
		}

		
		v0 = fold_vec(v0, v4, mults_4v);
		v1 = fold_vec(v1, v5, mults_4v);
		v2 = fold_vec(v2, v6, mults_4v);
		v3 = fold_vec(v3, v7, mults_4v);
		if (len & (4*VL)) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_4v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_4v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_4v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_4v);
			p += 4*VL;
		}
	}
	
	v0 = fold_vec(v0, v2, mults_2v);
	v1 = fold_vec(v1, v3, mults_2v);
	if (len & (2*VL)) {
		v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_2v);
		v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_2v);
		p += 2*VL;
	}
less_than_2vl_remaining:
	
	v0 = fold_vec(v0, v1, mults_1v);
	if (len & VL) {
		v0 = fold_vec(v0, VLOADU(p), mults_1v);
		p += VL;
	}
less_than_vl_remaining:
	
#if VL == 16
	x0 = v0;
#else
	{
	#if VL == 32
		__m256i y0 = v0;
	#else
		const __m256i mults_256b =
			_mm256_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG,
					  CRC32_X223_MODG, CRC32_X287_MODG);
		__m256i y0 = fold_vec256(_mm512_extracti64x4_epi64(v0, 0),
					 _mm512_extracti64x4_epi64(v0, 1),
					 mults_256b);
		if (len & 32) {
			y0 = fold_vec256(y0, _mm256_loadu_si256((const void *)p),
					 mults_256b);
			p += 32;
		}
	#endif
		x0 = fold_vec128(_mm256_extracti128_si256(y0, 0),
				 _mm256_extracti128_si256(y0, 1), mults_128b);
	}
	if (len & 16) {
		x0 = fold_vec128(x0, _mm_loadu_si128((const void *)p),
				 mults_128b);
		p += 16;
	}
#endif
less_than_16_remaining:
	len &= 15;

	
	if (len)
		x0 = fold_lessthan16bytes(x0, p, len, mults_128b);
#if USE_AVX512
reduce_x0:
#endif
	
	x0 = _mm_xor_si128(_mm_clmulepi64_si128(x0, mults_128b, 0x10),
			   _mm_bsrli_si128(x0, 8));
	x1 = _mm_clmulepi64_si128(x0, barrett_reduction_constants, 0x00);
	x1 = _mm_clmulepi64_si128(x1, barrett_reduction_constants, 0x10);
	x0 = _mm_xor_si128(x0, x1);
	return _mm_extract_epi32(x0, 2);
}

#undef vec_t
#undef fold_vec
#undef VLOADU
#undef VXOR
#undef M128I_TO_VEC
#undef MULTS
#undef MULTS_8V
#undef MULTS_4V
#undef MULTS_2V
#undef MULTS_1V

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_AVX512



#  define crc32_x86_pclmulqdq_avx	crc32_x86_pclmulqdq_avx
#  define SUFFIX				 _pclmulqdq_avx
#  define ATTRIBUTES		_target_attribute("pclmul,avx")
#  define VL			16
#  define USE_AVX512		0
/* #include "x86-crc32_pclmul_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define fold_vec		fold_vec128
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VXOR(a, b)		_mm_xor_si128((a), (b))
#  define M128I_TO_VEC(a)	a
#  define MULTS_8V		_mm_set_epi64x(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_4V		_mm_set_epi64x(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_2V		_mm_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG)
#  define MULTS_1V		_mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG)
#elif VL == 32
#  define vec_t			__m256i
#  define fold_vec		fold_vec256
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VXOR(a, b)		_mm256_xor_si256((a), (b))
#  define M128I_TO_VEC(a)	_mm256_zextsi128_si256(a)
#  define MULTS(a, b)		_mm256_set_epi64x(a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_4V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_2V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_1V		MULTS(CRC32_X223_MODG, CRC32_X287_MODG)
#elif VL == 64
#  define vec_t			__m512i
#  define fold_vec		fold_vec512
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VXOR(a, b)		_mm512_xor_si512((a), (b))
#  define M128I_TO_VEC(a)	_mm512_zextsi128_si512(a)
#  define MULTS(a, b)		_mm512_set_epi64(a, b, a, b, a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X4063_MODG, CRC32_X4127_MODG)
#  define MULTS_4V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_2V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_1V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#else
#  error "unsupported vector length"
#endif

#undef fold_vec128
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_vec128)(__m128i src, __m128i dst, __m128i  mults)
{
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x00));
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x11));
	return dst;
}
#define fold_vec128	ADD_SUFFIX(fold_vec128)

#if VL >= 32
#undef fold_vec256
static forceinline ATTRIBUTES __m256i
ADD_SUFFIX(fold_vec256)(__m256i src, __m256i dst, __m256i  mults)
{
#if USE_AVX512
	
	return _mm256_ternarylogic_epi32(
			_mm256_clmulepi64_epi128(src, mults, 0x00),
			_mm256_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
#else
	return _mm256_xor_si256(
			_mm256_xor_si256(dst,
					 _mm256_clmulepi64_epi128(src, mults, 0x00)),
			_mm256_clmulepi64_epi128(src, mults, 0x11));
#endif
}
#define fold_vec256	ADD_SUFFIX(fold_vec256)
#endif 

#if VL >= 64
#undef fold_vec512
static forceinline ATTRIBUTES __m512i
ADD_SUFFIX(fold_vec512)(__m512i src, __m512i dst, __m512i  mults)
{
	
	return _mm512_ternarylogic_epi32(
			_mm512_clmulepi64_epi128(src, mults, 0x00),
			_mm512_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
}
#define fold_vec512	ADD_SUFFIX(fold_vec512)
#endif 


#undef fold_lessthan16bytes
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_lessthan16bytes)(__m128i x, const u8 *p, size_t len,
				 __m128i  mults_128b)
{
	__m128i lshift = _mm_loadu_si128((const void *)&shift_tab[len]);
	__m128i rshift = _mm_loadu_si128((const void *)&shift_tab[len + 16]);
	__m128i x0, x1;

	
	x0 = _mm_shuffle_epi8(x, lshift);

	
	x1 = _mm_blendv_epi8(_mm_shuffle_epi8(x, rshift),
			     _mm_loadu_si128((const void *)(p + len - 16)),
			     
			     rshift);

	return fold_vec128(x0, x1, mults_128b);
}
#define fold_lessthan16bytes	ADD_SUFFIX(fold_lessthan16bytes)

static ATTRIBUTES u32
ADD_SUFFIX(crc32_x86)(u32 crc, const u8 *p, size_t len)
{
	
	const vec_t mults_8v = MULTS_8V;
	const vec_t mults_4v = MULTS_4V;
	const vec_t mults_2v = MULTS_2V;
	const vec_t mults_1v = MULTS_1V;
	const __m128i mults_128b = _mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG);
	const __m128i barrett_reduction_constants =
		_mm_set_epi64x(CRC32_BARRETT_CONSTANT_2, CRC32_BARRETT_CONSTANT_1);
	vec_t v0, v1, v2, v3, v4, v5, v6, v7;
	__m128i x0 = _mm_cvtsi32_si128(crc);
	__m128i x1;

	if (len < 8*VL) {
		if (len < VL) {
			STATIC_ASSERT(VL == 16 || VL == 32 || VL == 64);
			if (len < 16) {
			#if USE_AVX512
				if (len < 4)
					return crc32_slice1(crc, p, len);
				
				x0 = _mm_xor_si128(
					x0, _mm_maskz_loadu_epi8((1 << len) - 1, p));
				x0 = _mm_shuffle_epi8(
					x0, _mm_loadu_si128((const void *)&shift_tab[len]));
				goto reduce_x0;
			#else
				return crc32_slice1(crc, p, len);
			#endif
			}
			
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			if (len >= 32) {
				x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 16)),
						 mults_128b);
				if (len >= 48)
					x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 32)),
							 mults_128b);
			}
			p += len & ~15;
			goto less_than_16_remaining;
		}
		v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		if (len < 2*VL) {
			p += VL;
			goto less_than_vl_remaining;
		}
		v1 = VLOADU(p + 1*VL);
		if (len < 4*VL) {
			p += 2*VL;
			goto less_than_2vl_remaining;
		}
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		p += 4*VL;
	} else {
		
		if (len > 65536 && ((uintptr_t)p & (VL-1))) {
			size_t align = -(uintptr_t)p & (VL-1);

			len -= align;
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			p += 16;
			if (align & 15) {
				x0 = fold_lessthan16bytes(x0, p, align & 15,
							  mults_128b);
				p += align & 15;
				align &= ~15;
			}
			while (align) {
				x0 = fold_vec128(x0, *(const __m128i *)p,
						 mults_128b);
				p += 16;
				align -= 16;
			}
			v0 = M128I_TO_VEC(x0);
		#  if VL == 32
			v0 = _mm256_inserti128_si256(v0, *(const __m128i *)p, 1);
		#  elif VL == 64
			v0 = _mm512_inserti32x4(v0, *(const __m128i *)p, 1);
			v0 = _mm512_inserti64x4(v0, *(const __m256i *)(p + 16), 1);
		#  endif
			p -= 16;
		} else {
			v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		}
		v1 = VLOADU(p + 1*VL);
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		v4 = VLOADU(p + 4*VL);
		v5 = VLOADU(p + 5*VL);
		v6 = VLOADU(p + 6*VL);
		v7 = VLOADU(p + 7*VL);
		p += 8*VL;

		
		while (len >= 16*VL) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_8v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_8v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_8v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_8v);
			v4 = fold_vec(v4, VLOADU(p + 4*VL), mults_8v);
			v5 = fold_vec(v5, VLOADU(p + 5*VL), mults_8v);
			v6 = fold_vec(v6, VLOADU(p + 6*VL), mults_8v);
			v7 = fold_vec(v7, VLOADU(p + 7*VL), mults_8v);
			p += 8*VL;
			len -= 8*VL;
		}

		
		v0 = fold_vec(v0, v4, mults_4v);
		v1 = fold_vec(v1, v5, mults_4v);
		v2 = fold_vec(v2, v6, mults_4v);
		v3 = fold_vec(v3, v7, mults_4v);
		if (len & (4*VL)) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_4v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_4v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_4v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_4v);
			p += 4*VL;
		}
	}
	
	v0 = fold_vec(v0, v2, mults_2v);
	v1 = fold_vec(v1, v3, mults_2v);
	if (len & (2*VL)) {
		v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_2v);
		v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_2v);
		p += 2*VL;
	}
less_than_2vl_remaining:
	
	v0 = fold_vec(v0, v1, mults_1v);
	if (len & VL) {
		v0 = fold_vec(v0, VLOADU(p), mults_1v);
		p += VL;
	}
less_than_vl_remaining:
	
#if VL == 16
	x0 = v0;
#else
	{
	#if VL == 32
		__m256i y0 = v0;
	#else
		const __m256i mults_256b =
			_mm256_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG,
					  CRC32_X223_MODG, CRC32_X287_MODG);
		__m256i y0 = fold_vec256(_mm512_extracti64x4_epi64(v0, 0),
					 _mm512_extracti64x4_epi64(v0, 1),
					 mults_256b);
		if (len & 32) {
			y0 = fold_vec256(y0, _mm256_loadu_si256((const void *)p),
					 mults_256b);
			p += 32;
		}
	#endif
		x0 = fold_vec128(_mm256_extracti128_si256(y0, 0),
				 _mm256_extracti128_si256(y0, 1), mults_128b);
	}
	if (len & 16) {
		x0 = fold_vec128(x0, _mm_loadu_si128((const void *)p),
				 mults_128b);
		p += 16;
	}
#endif
less_than_16_remaining:
	len &= 15;

	
	if (len)
		x0 = fold_lessthan16bytes(x0, p, len, mults_128b);
#if USE_AVX512
reduce_x0:
#endif
	
	x0 = _mm_xor_si128(_mm_clmulepi64_si128(x0, mults_128b, 0x10),
			   _mm_bsrli_si128(x0, 8));
	x1 = _mm_clmulepi64_si128(x0, barrett_reduction_constants, 0x00);
	x1 = _mm_clmulepi64_si128(x1, barrett_reduction_constants, 0x10);
	x0 = _mm_xor_si128(x0, x1);
	return _mm_extract_epi32(x0, 2);
}

#undef vec_t
#undef fold_vec
#undef VLOADU
#undef VXOR
#undef M128I_TO_VEC
#undef MULTS
#undef MULTS_8V
#undef MULTS_4V
#undef MULTS_2V
#undef MULTS_1V

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_AVX512

#endif


#if (GCC_PREREQ(10, 1) || CLANG_PREREQ(6, 0, 10000000)) && \
	!defined(LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_VPCLMULQDQ)
#  define crc32_x86_vpclmulqdq_avx2	crc32_x86_vpclmulqdq_avx2
#  define SUFFIX				 _vpclmulqdq_avx2
#  define ATTRIBUTES		_target_attribute("vpclmulqdq,pclmul,avx2")
#  define VL			32
#  define USE_AVX512		0
/* #include "x86-crc32_pclmul_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define fold_vec		fold_vec128
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VXOR(a, b)		_mm_xor_si128((a), (b))
#  define M128I_TO_VEC(a)	a
#  define MULTS_8V		_mm_set_epi64x(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_4V		_mm_set_epi64x(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_2V		_mm_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG)
#  define MULTS_1V		_mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG)
#elif VL == 32
#  define vec_t			__m256i
#  define fold_vec		fold_vec256
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VXOR(a, b)		_mm256_xor_si256((a), (b))
#  define M128I_TO_VEC(a)	_mm256_zextsi128_si256(a)
#  define MULTS(a, b)		_mm256_set_epi64x(a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_4V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_2V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_1V		MULTS(CRC32_X223_MODG, CRC32_X287_MODG)
#elif VL == 64
#  define vec_t			__m512i
#  define fold_vec		fold_vec512
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VXOR(a, b)		_mm512_xor_si512((a), (b))
#  define M128I_TO_VEC(a)	_mm512_zextsi128_si512(a)
#  define MULTS(a, b)		_mm512_set_epi64(a, b, a, b, a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X4063_MODG, CRC32_X4127_MODG)
#  define MULTS_4V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_2V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_1V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#else
#  error "unsupported vector length"
#endif

#undef fold_vec128
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_vec128)(__m128i src, __m128i dst, __m128i  mults)
{
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x00));
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x11));
	return dst;
}
#define fold_vec128	ADD_SUFFIX(fold_vec128)

#if VL >= 32
#undef fold_vec256
static forceinline ATTRIBUTES __m256i
ADD_SUFFIX(fold_vec256)(__m256i src, __m256i dst, __m256i  mults)
{
#if USE_AVX512
	
	return _mm256_ternarylogic_epi32(
			_mm256_clmulepi64_epi128(src, mults, 0x00),
			_mm256_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
#else
	return _mm256_xor_si256(
			_mm256_xor_si256(dst,
					 _mm256_clmulepi64_epi128(src, mults, 0x00)),
			_mm256_clmulepi64_epi128(src, mults, 0x11));
#endif
}
#define fold_vec256	ADD_SUFFIX(fold_vec256)
#endif 

#if VL >= 64
#undef fold_vec512
static forceinline ATTRIBUTES __m512i
ADD_SUFFIX(fold_vec512)(__m512i src, __m512i dst, __m512i  mults)
{
	
	return _mm512_ternarylogic_epi32(
			_mm512_clmulepi64_epi128(src, mults, 0x00),
			_mm512_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
}
#define fold_vec512	ADD_SUFFIX(fold_vec512)
#endif 


#undef fold_lessthan16bytes
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_lessthan16bytes)(__m128i x, const u8 *p, size_t len,
				 __m128i  mults_128b)
{
	__m128i lshift = _mm_loadu_si128((const void *)&shift_tab[len]);
	__m128i rshift = _mm_loadu_si128((const void *)&shift_tab[len + 16]);
	__m128i x0, x1;

	
	x0 = _mm_shuffle_epi8(x, lshift);

	
	x1 = _mm_blendv_epi8(_mm_shuffle_epi8(x, rshift),
			     _mm_loadu_si128((const void *)(p + len - 16)),
			     
			     rshift);

	return fold_vec128(x0, x1, mults_128b);
}
#define fold_lessthan16bytes	ADD_SUFFIX(fold_lessthan16bytes)

static ATTRIBUTES u32
ADD_SUFFIX(crc32_x86)(u32 crc, const u8 *p, size_t len)
{
	
	const vec_t mults_8v = MULTS_8V;
	const vec_t mults_4v = MULTS_4V;
	const vec_t mults_2v = MULTS_2V;
	const vec_t mults_1v = MULTS_1V;
	const __m128i mults_128b = _mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG);
	const __m128i barrett_reduction_constants =
		_mm_set_epi64x(CRC32_BARRETT_CONSTANT_2, CRC32_BARRETT_CONSTANT_1);
	vec_t v0, v1, v2, v3, v4, v5, v6, v7;
	__m128i x0 = _mm_cvtsi32_si128(crc);
	__m128i x1;

	if (len < 8*VL) {
		if (len < VL) {
			STATIC_ASSERT(VL == 16 || VL == 32 || VL == 64);
			if (len < 16) {
			#if USE_AVX512
				if (len < 4)
					return crc32_slice1(crc, p, len);
				
				x0 = _mm_xor_si128(
					x0, _mm_maskz_loadu_epi8((1 << len) - 1, p));
				x0 = _mm_shuffle_epi8(
					x0, _mm_loadu_si128((const void *)&shift_tab[len]));
				goto reduce_x0;
			#else
				return crc32_slice1(crc, p, len);
			#endif
			}
			
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			if (len >= 32) {
				x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 16)),
						 mults_128b);
				if (len >= 48)
					x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 32)),
							 mults_128b);
			}
			p += len & ~15;
			goto less_than_16_remaining;
		}
		v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		if (len < 2*VL) {
			p += VL;
			goto less_than_vl_remaining;
		}
		v1 = VLOADU(p + 1*VL);
		if (len < 4*VL) {
			p += 2*VL;
			goto less_than_2vl_remaining;
		}
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		p += 4*VL;
	} else {
		
		if (len > 65536 && ((uintptr_t)p & (VL-1))) {
			size_t align = -(uintptr_t)p & (VL-1);

			len -= align;
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			p += 16;
			if (align & 15) {
				x0 = fold_lessthan16bytes(x0, p, align & 15,
							  mults_128b);
				p += align & 15;
				align &= ~15;
			}
			while (align) {
				x0 = fold_vec128(x0, *(const __m128i *)p,
						 mults_128b);
				p += 16;
				align -= 16;
			}
			v0 = M128I_TO_VEC(x0);
		#  if VL == 32
			v0 = _mm256_inserti128_si256(v0, *(const __m128i *)p, 1);
		#  elif VL == 64
			v0 = _mm512_inserti32x4(v0, *(const __m128i *)p, 1);
			v0 = _mm512_inserti64x4(v0, *(const __m256i *)(p + 16), 1);
		#  endif
			p -= 16;
		} else {
			v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		}
		v1 = VLOADU(p + 1*VL);
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		v4 = VLOADU(p + 4*VL);
		v5 = VLOADU(p + 5*VL);
		v6 = VLOADU(p + 6*VL);
		v7 = VLOADU(p + 7*VL);
		p += 8*VL;

		
		while (len >= 16*VL) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_8v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_8v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_8v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_8v);
			v4 = fold_vec(v4, VLOADU(p + 4*VL), mults_8v);
			v5 = fold_vec(v5, VLOADU(p + 5*VL), mults_8v);
			v6 = fold_vec(v6, VLOADU(p + 6*VL), mults_8v);
			v7 = fold_vec(v7, VLOADU(p + 7*VL), mults_8v);
			p += 8*VL;
			len -= 8*VL;
		}

		
		v0 = fold_vec(v0, v4, mults_4v);
		v1 = fold_vec(v1, v5, mults_4v);
		v2 = fold_vec(v2, v6, mults_4v);
		v3 = fold_vec(v3, v7, mults_4v);
		if (len & (4*VL)) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_4v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_4v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_4v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_4v);
			p += 4*VL;
		}
	}
	
	v0 = fold_vec(v0, v2, mults_2v);
	v1 = fold_vec(v1, v3, mults_2v);
	if (len & (2*VL)) {
		v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_2v);
		v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_2v);
		p += 2*VL;
	}
less_than_2vl_remaining:
	
	v0 = fold_vec(v0, v1, mults_1v);
	if (len & VL) {
		v0 = fold_vec(v0, VLOADU(p), mults_1v);
		p += VL;
	}
less_than_vl_remaining:
	
#if VL == 16
	x0 = v0;
#else
	{
	#if VL == 32
		__m256i y0 = v0;
	#else
		const __m256i mults_256b =
			_mm256_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG,
					  CRC32_X223_MODG, CRC32_X287_MODG);
		__m256i y0 = fold_vec256(_mm512_extracti64x4_epi64(v0, 0),
					 _mm512_extracti64x4_epi64(v0, 1),
					 mults_256b);
		if (len & 32) {
			y0 = fold_vec256(y0, _mm256_loadu_si256((const void *)p),
					 mults_256b);
			p += 32;
		}
	#endif
		x0 = fold_vec128(_mm256_extracti128_si256(y0, 0),
				 _mm256_extracti128_si256(y0, 1), mults_128b);
	}
	if (len & 16) {
		x0 = fold_vec128(x0, _mm_loadu_si128((const void *)p),
				 mults_128b);
		p += 16;
	}
#endif
less_than_16_remaining:
	len &= 15;

	
	if (len)
		x0 = fold_lessthan16bytes(x0, p, len, mults_128b);
#if USE_AVX512
reduce_x0:
#endif
	
	x0 = _mm_xor_si128(_mm_clmulepi64_si128(x0, mults_128b, 0x10),
			   _mm_bsrli_si128(x0, 8));
	x1 = _mm_clmulepi64_si128(x0, barrett_reduction_constants, 0x00);
	x1 = _mm_clmulepi64_si128(x1, barrett_reduction_constants, 0x10);
	x0 = _mm_xor_si128(x0, x1);
	return _mm_extract_epi32(x0, 2);
}

#undef vec_t
#undef fold_vec
#undef VLOADU
#undef VXOR
#undef M128I_TO_VEC
#undef MULTS
#undef MULTS_8V
#undef MULTS_4V
#undef MULTS_2V
#undef MULTS_1V

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_AVX512

#endif

#if (GCC_PREREQ(10, 1) || CLANG_PREREQ(6, 0, 10000000) || MSVC_PREREQ(1920)) && \
	!defined(LIBDEFLATE_ASSEMBLER_DOES_NOT_SUPPORT_VPCLMULQDQ)

#  define crc32_x86_vpclmulqdq_avx512_vl256  crc32_x86_vpclmulqdq_avx512_vl256
#  define SUFFIX				      _vpclmulqdq_avx512_vl256
#  define ATTRIBUTES		_target_attribute("vpclmulqdq,pclmul,avx512bw,avx512vl" NO_EVEX512)
#  define VL			32
#  define USE_AVX512		1
/* #include "x86-crc32_pclmul_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define fold_vec		fold_vec128
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VXOR(a, b)		_mm_xor_si128((a), (b))
#  define M128I_TO_VEC(a)	a
#  define MULTS_8V		_mm_set_epi64x(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_4V		_mm_set_epi64x(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_2V		_mm_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG)
#  define MULTS_1V		_mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG)
#elif VL == 32
#  define vec_t			__m256i
#  define fold_vec		fold_vec256
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VXOR(a, b)		_mm256_xor_si256((a), (b))
#  define M128I_TO_VEC(a)	_mm256_zextsi128_si256(a)
#  define MULTS(a, b)		_mm256_set_epi64x(a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_4V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_2V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_1V		MULTS(CRC32_X223_MODG, CRC32_X287_MODG)
#elif VL == 64
#  define vec_t			__m512i
#  define fold_vec		fold_vec512
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VXOR(a, b)		_mm512_xor_si512((a), (b))
#  define M128I_TO_VEC(a)	_mm512_zextsi128_si512(a)
#  define MULTS(a, b)		_mm512_set_epi64(a, b, a, b, a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X4063_MODG, CRC32_X4127_MODG)
#  define MULTS_4V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_2V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_1V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#else
#  error "unsupported vector length"
#endif

#undef fold_vec128
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_vec128)(__m128i src, __m128i dst, __m128i  mults)
{
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x00));
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x11));
	return dst;
}
#define fold_vec128	ADD_SUFFIX(fold_vec128)

#if VL >= 32
#undef fold_vec256
static forceinline ATTRIBUTES __m256i
ADD_SUFFIX(fold_vec256)(__m256i src, __m256i dst, __m256i  mults)
{
#if USE_AVX512
	
	return _mm256_ternarylogic_epi32(
			_mm256_clmulepi64_epi128(src, mults, 0x00),
			_mm256_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
#else
	return _mm256_xor_si256(
			_mm256_xor_si256(dst,
					 _mm256_clmulepi64_epi128(src, mults, 0x00)),
			_mm256_clmulepi64_epi128(src, mults, 0x11));
#endif
}
#define fold_vec256	ADD_SUFFIX(fold_vec256)
#endif 

#if VL >= 64
#undef fold_vec512
static forceinline ATTRIBUTES __m512i
ADD_SUFFIX(fold_vec512)(__m512i src, __m512i dst, __m512i  mults)
{
	
	return _mm512_ternarylogic_epi32(
			_mm512_clmulepi64_epi128(src, mults, 0x00),
			_mm512_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
}
#define fold_vec512	ADD_SUFFIX(fold_vec512)
#endif 


#undef fold_lessthan16bytes
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_lessthan16bytes)(__m128i x, const u8 *p, size_t len,
				 __m128i  mults_128b)
{
	__m128i lshift = _mm_loadu_si128((const void *)&shift_tab[len]);
	__m128i rshift = _mm_loadu_si128((const void *)&shift_tab[len + 16]);
	__m128i x0, x1;

	
	x0 = _mm_shuffle_epi8(x, lshift);

	
	x1 = _mm_blendv_epi8(_mm_shuffle_epi8(x, rshift),
			     _mm_loadu_si128((const void *)(p + len - 16)),
			     
			     rshift);

	return fold_vec128(x0, x1, mults_128b);
}
#define fold_lessthan16bytes	ADD_SUFFIX(fold_lessthan16bytes)

static ATTRIBUTES u32
ADD_SUFFIX(crc32_x86)(u32 crc, const u8 *p, size_t len)
{
	
	const vec_t mults_8v = MULTS_8V;
	const vec_t mults_4v = MULTS_4V;
	const vec_t mults_2v = MULTS_2V;
	const vec_t mults_1v = MULTS_1V;
	const __m128i mults_128b = _mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG);
	const __m128i barrett_reduction_constants =
		_mm_set_epi64x(CRC32_BARRETT_CONSTANT_2, CRC32_BARRETT_CONSTANT_1);
	vec_t v0, v1, v2, v3, v4, v5, v6, v7;
	__m128i x0 = _mm_cvtsi32_si128(crc);
	__m128i x1;

	if (len < 8*VL) {
		if (len < VL) {
			STATIC_ASSERT(VL == 16 || VL == 32 || VL == 64);
			if (len < 16) {
			#if USE_AVX512
				if (len < 4)
					return crc32_slice1(crc, p, len);
				
				x0 = _mm_xor_si128(
					x0, _mm_maskz_loadu_epi8((1 << len) - 1, p));
				x0 = _mm_shuffle_epi8(
					x0, _mm_loadu_si128((const void *)&shift_tab[len]));
				goto reduce_x0;
			#else
				return crc32_slice1(crc, p, len);
			#endif
			}
			
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			if (len >= 32) {
				x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 16)),
						 mults_128b);
				if (len >= 48)
					x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 32)),
							 mults_128b);
			}
			p += len & ~15;
			goto less_than_16_remaining;
		}
		v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		if (len < 2*VL) {
			p += VL;
			goto less_than_vl_remaining;
		}
		v1 = VLOADU(p + 1*VL);
		if (len < 4*VL) {
			p += 2*VL;
			goto less_than_2vl_remaining;
		}
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		p += 4*VL;
	} else {
		
		if (len > 65536 && ((uintptr_t)p & (VL-1))) {
			size_t align = -(uintptr_t)p & (VL-1);

			len -= align;
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			p += 16;
			if (align & 15) {
				x0 = fold_lessthan16bytes(x0, p, align & 15,
							  mults_128b);
				p += align & 15;
				align &= ~15;
			}
			while (align) {
				x0 = fold_vec128(x0, *(const __m128i *)p,
						 mults_128b);
				p += 16;
				align -= 16;
			}
			v0 = M128I_TO_VEC(x0);
		#  if VL == 32
			v0 = _mm256_inserti128_si256(v0, *(const __m128i *)p, 1);
		#  elif VL == 64
			v0 = _mm512_inserti32x4(v0, *(const __m128i *)p, 1);
			v0 = _mm512_inserti64x4(v0, *(const __m256i *)(p + 16), 1);
		#  endif
			p -= 16;
		} else {
			v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		}
		v1 = VLOADU(p + 1*VL);
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		v4 = VLOADU(p + 4*VL);
		v5 = VLOADU(p + 5*VL);
		v6 = VLOADU(p + 6*VL);
		v7 = VLOADU(p + 7*VL);
		p += 8*VL;

		
		while (len >= 16*VL) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_8v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_8v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_8v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_8v);
			v4 = fold_vec(v4, VLOADU(p + 4*VL), mults_8v);
			v5 = fold_vec(v5, VLOADU(p + 5*VL), mults_8v);
			v6 = fold_vec(v6, VLOADU(p + 6*VL), mults_8v);
			v7 = fold_vec(v7, VLOADU(p + 7*VL), mults_8v);
			p += 8*VL;
			len -= 8*VL;
		}

		
		v0 = fold_vec(v0, v4, mults_4v);
		v1 = fold_vec(v1, v5, mults_4v);
		v2 = fold_vec(v2, v6, mults_4v);
		v3 = fold_vec(v3, v7, mults_4v);
		if (len & (4*VL)) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_4v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_4v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_4v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_4v);
			p += 4*VL;
		}
	}
	
	v0 = fold_vec(v0, v2, mults_2v);
	v1 = fold_vec(v1, v3, mults_2v);
	if (len & (2*VL)) {
		v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_2v);
		v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_2v);
		p += 2*VL;
	}
less_than_2vl_remaining:
	
	v0 = fold_vec(v0, v1, mults_1v);
	if (len & VL) {
		v0 = fold_vec(v0, VLOADU(p), mults_1v);
		p += VL;
	}
less_than_vl_remaining:
	
#if VL == 16
	x0 = v0;
#else
	{
	#if VL == 32
		__m256i y0 = v0;
	#else
		const __m256i mults_256b =
			_mm256_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG,
					  CRC32_X223_MODG, CRC32_X287_MODG);
		__m256i y0 = fold_vec256(_mm512_extracti64x4_epi64(v0, 0),
					 _mm512_extracti64x4_epi64(v0, 1),
					 mults_256b);
		if (len & 32) {
			y0 = fold_vec256(y0, _mm256_loadu_si256((const void *)p),
					 mults_256b);
			p += 32;
		}
	#endif
		x0 = fold_vec128(_mm256_extracti128_si256(y0, 0),
				 _mm256_extracti128_si256(y0, 1), mults_128b);
	}
	if (len & 16) {
		x0 = fold_vec128(x0, _mm_loadu_si128((const void *)p),
				 mults_128b);
		p += 16;
	}
#endif
less_than_16_remaining:
	len &= 15;

	
	if (len)
		x0 = fold_lessthan16bytes(x0, p, len, mults_128b);
#if USE_AVX512
reduce_x0:
#endif
	
	x0 = _mm_xor_si128(_mm_clmulepi64_si128(x0, mults_128b, 0x10),
			   _mm_bsrli_si128(x0, 8));
	x1 = _mm_clmulepi64_si128(x0, barrett_reduction_constants, 0x00);
	x1 = _mm_clmulepi64_si128(x1, barrett_reduction_constants, 0x10);
	x0 = _mm_xor_si128(x0, x1);
	return _mm_extract_epi32(x0, 2);
}

#undef vec_t
#undef fold_vec
#undef VLOADU
#undef VXOR
#undef M128I_TO_VEC
#undef MULTS
#undef MULTS_8V
#undef MULTS_4V
#undef MULTS_2V
#undef MULTS_1V

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_AVX512



#  define crc32_x86_vpclmulqdq_avx512_vl512  crc32_x86_vpclmulqdq_avx512_vl512
#  define SUFFIX				      _vpclmulqdq_avx512_vl512
#  define ATTRIBUTES		_target_attribute("vpclmulqdq,pclmul,avx512bw,avx512vl" EVEX512)
#  define VL			64
#  define USE_AVX512		1
/* #include "x86-crc32_pclmul_template.h" */




#if VL == 16
#  define vec_t			__m128i
#  define fold_vec		fold_vec128
#  define VLOADU(p)		_mm_loadu_si128((const void *)(p))
#  define VXOR(a, b)		_mm_xor_si128((a), (b))
#  define M128I_TO_VEC(a)	a
#  define MULTS_8V		_mm_set_epi64x(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_4V		_mm_set_epi64x(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_2V		_mm_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG)
#  define MULTS_1V		_mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG)
#elif VL == 32
#  define vec_t			__m256i
#  define fold_vec		fold_vec256
#  define VLOADU(p)		_mm256_loadu_si256((const void *)(p))
#  define VXOR(a, b)		_mm256_xor_si256((a), (b))
#  define M128I_TO_VEC(a)	_mm256_zextsi128_si256(a)
#  define MULTS(a, b)		_mm256_set_epi64x(a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_4V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_2V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#  define MULTS_1V		MULTS(CRC32_X223_MODG, CRC32_X287_MODG)
#elif VL == 64
#  define vec_t			__m512i
#  define fold_vec		fold_vec512
#  define VLOADU(p)		_mm512_loadu_si512((const void *)(p))
#  define VXOR(a, b)		_mm512_xor_si512((a), (b))
#  define M128I_TO_VEC(a)	_mm512_zextsi128_si512(a)
#  define MULTS(a, b)		_mm512_set_epi64(a, b, a, b, a, b, a, b)
#  define MULTS_8V		MULTS(CRC32_X4063_MODG, CRC32_X4127_MODG)
#  define MULTS_4V		MULTS(CRC32_X2015_MODG, CRC32_X2079_MODG)
#  define MULTS_2V		MULTS(CRC32_X991_MODG, CRC32_X1055_MODG)
#  define MULTS_1V		MULTS(CRC32_X479_MODG, CRC32_X543_MODG)
#else
#  error "unsupported vector length"
#endif

#undef fold_vec128
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_vec128)(__m128i src, __m128i dst, __m128i  mults)
{
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x00));
	dst = _mm_xor_si128(dst, _mm_clmulepi64_si128(src, mults, 0x11));
	return dst;
}
#define fold_vec128	ADD_SUFFIX(fold_vec128)

#if VL >= 32
#undef fold_vec256
static forceinline ATTRIBUTES __m256i
ADD_SUFFIX(fold_vec256)(__m256i src, __m256i dst, __m256i  mults)
{
#if USE_AVX512
	
	return _mm256_ternarylogic_epi32(
			_mm256_clmulepi64_epi128(src, mults, 0x00),
			_mm256_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
#else
	return _mm256_xor_si256(
			_mm256_xor_si256(dst,
					 _mm256_clmulepi64_epi128(src, mults, 0x00)),
			_mm256_clmulepi64_epi128(src, mults, 0x11));
#endif
}
#define fold_vec256	ADD_SUFFIX(fold_vec256)
#endif 

#if VL >= 64
#undef fold_vec512
static forceinline ATTRIBUTES __m512i
ADD_SUFFIX(fold_vec512)(__m512i src, __m512i dst, __m512i  mults)
{
	
	return _mm512_ternarylogic_epi32(
			_mm512_clmulepi64_epi128(src, mults, 0x00),
			_mm512_clmulepi64_epi128(src, mults, 0x11),
			dst,
			0x96);
}
#define fold_vec512	ADD_SUFFIX(fold_vec512)
#endif 


#undef fold_lessthan16bytes
static forceinline ATTRIBUTES __m128i
ADD_SUFFIX(fold_lessthan16bytes)(__m128i x, const u8 *p, size_t len,
				 __m128i  mults_128b)
{
	__m128i lshift = _mm_loadu_si128((const void *)&shift_tab[len]);
	__m128i rshift = _mm_loadu_si128((const void *)&shift_tab[len + 16]);
	__m128i x0, x1;

	
	x0 = _mm_shuffle_epi8(x, lshift);

	
	x1 = _mm_blendv_epi8(_mm_shuffle_epi8(x, rshift),
			     _mm_loadu_si128((const void *)(p + len - 16)),
			     
			     rshift);

	return fold_vec128(x0, x1, mults_128b);
}
#define fold_lessthan16bytes	ADD_SUFFIX(fold_lessthan16bytes)

static ATTRIBUTES u32
ADD_SUFFIX(crc32_x86)(u32 crc, const u8 *p, size_t len)
{
	
	const vec_t mults_8v = MULTS_8V;
	const vec_t mults_4v = MULTS_4V;
	const vec_t mults_2v = MULTS_2V;
	const vec_t mults_1v = MULTS_1V;
	const __m128i mults_128b = _mm_set_epi64x(CRC32_X95_MODG, CRC32_X159_MODG);
	const __m128i barrett_reduction_constants =
		_mm_set_epi64x(CRC32_BARRETT_CONSTANT_2, CRC32_BARRETT_CONSTANT_1);
	vec_t v0, v1, v2, v3, v4, v5, v6, v7;
	__m128i x0 = _mm_cvtsi32_si128(crc);
	__m128i x1;

	if (len < 8*VL) {
		if (len < VL) {
			STATIC_ASSERT(VL == 16 || VL == 32 || VL == 64);
			if (len < 16) {
			#if USE_AVX512
				if (len < 4)
					return crc32_slice1(crc, p, len);
				
				x0 = _mm_xor_si128(
					x0, _mm_maskz_loadu_epi8((1 << len) - 1, p));
				x0 = _mm_shuffle_epi8(
					x0, _mm_loadu_si128((const void *)&shift_tab[len]));
				goto reduce_x0;
			#else
				return crc32_slice1(crc, p, len);
			#endif
			}
			
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			if (len >= 32) {
				x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 16)),
						 mults_128b);
				if (len >= 48)
					x0 = fold_vec128(x0, _mm_loadu_si128((const void *)(p + 32)),
							 mults_128b);
			}
			p += len & ~15;
			goto less_than_16_remaining;
		}
		v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		if (len < 2*VL) {
			p += VL;
			goto less_than_vl_remaining;
		}
		v1 = VLOADU(p + 1*VL);
		if (len < 4*VL) {
			p += 2*VL;
			goto less_than_2vl_remaining;
		}
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		p += 4*VL;
	} else {
		
		if (len > 65536 && ((uintptr_t)p & (VL-1))) {
			size_t align = -(uintptr_t)p & (VL-1);

			len -= align;
			x0 = _mm_xor_si128(_mm_loadu_si128((const void *)p), x0);
			p += 16;
			if (align & 15) {
				x0 = fold_lessthan16bytes(x0, p, align & 15,
							  mults_128b);
				p += align & 15;
				align &= ~15;
			}
			while (align) {
				x0 = fold_vec128(x0, *(const __m128i *)p,
						 mults_128b);
				p += 16;
				align -= 16;
			}
			v0 = M128I_TO_VEC(x0);
		#  if VL == 32
			v0 = _mm256_inserti128_si256(v0, *(const __m128i *)p, 1);
		#  elif VL == 64
			v0 = _mm512_inserti32x4(v0, *(const __m128i *)p, 1);
			v0 = _mm512_inserti64x4(v0, *(const __m256i *)(p + 16), 1);
		#  endif
			p -= 16;
		} else {
			v0 = VXOR(VLOADU(p), M128I_TO_VEC(x0));
		}
		v1 = VLOADU(p + 1*VL);
		v2 = VLOADU(p + 2*VL);
		v3 = VLOADU(p + 3*VL);
		v4 = VLOADU(p + 4*VL);
		v5 = VLOADU(p + 5*VL);
		v6 = VLOADU(p + 6*VL);
		v7 = VLOADU(p + 7*VL);
		p += 8*VL;

		
		while (len >= 16*VL) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_8v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_8v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_8v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_8v);
			v4 = fold_vec(v4, VLOADU(p + 4*VL), mults_8v);
			v5 = fold_vec(v5, VLOADU(p + 5*VL), mults_8v);
			v6 = fold_vec(v6, VLOADU(p + 6*VL), mults_8v);
			v7 = fold_vec(v7, VLOADU(p + 7*VL), mults_8v);
			p += 8*VL;
			len -= 8*VL;
		}

		
		v0 = fold_vec(v0, v4, mults_4v);
		v1 = fold_vec(v1, v5, mults_4v);
		v2 = fold_vec(v2, v6, mults_4v);
		v3 = fold_vec(v3, v7, mults_4v);
		if (len & (4*VL)) {
			v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_4v);
			v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_4v);
			v2 = fold_vec(v2, VLOADU(p + 2*VL), mults_4v);
			v3 = fold_vec(v3, VLOADU(p + 3*VL), mults_4v);
			p += 4*VL;
		}
	}
	
	v0 = fold_vec(v0, v2, mults_2v);
	v1 = fold_vec(v1, v3, mults_2v);
	if (len & (2*VL)) {
		v0 = fold_vec(v0, VLOADU(p + 0*VL), mults_2v);
		v1 = fold_vec(v1, VLOADU(p + 1*VL), mults_2v);
		p += 2*VL;
	}
less_than_2vl_remaining:
	
	v0 = fold_vec(v0, v1, mults_1v);
	if (len & VL) {
		v0 = fold_vec(v0, VLOADU(p), mults_1v);
		p += VL;
	}
less_than_vl_remaining:
	
#if VL == 16
	x0 = v0;
#else
	{
	#if VL == 32
		__m256i y0 = v0;
	#else
		const __m256i mults_256b =
			_mm256_set_epi64x(CRC32_X223_MODG, CRC32_X287_MODG,
					  CRC32_X223_MODG, CRC32_X287_MODG);
		__m256i y0 = fold_vec256(_mm512_extracti64x4_epi64(v0, 0),
					 _mm512_extracti64x4_epi64(v0, 1),
					 mults_256b);
		if (len & 32) {
			y0 = fold_vec256(y0, _mm256_loadu_si256((const void *)p),
					 mults_256b);
			p += 32;
		}
	#endif
		x0 = fold_vec128(_mm256_extracti128_si256(y0, 0),
				 _mm256_extracti128_si256(y0, 1), mults_128b);
	}
	if (len & 16) {
		x0 = fold_vec128(x0, _mm_loadu_si128((const void *)p),
				 mults_128b);
		p += 16;
	}
#endif
less_than_16_remaining:
	len &= 15;

	
	if (len)
		x0 = fold_lessthan16bytes(x0, p, len, mults_128b);
#if USE_AVX512
reduce_x0:
#endif
	
	x0 = _mm_xor_si128(_mm_clmulepi64_si128(x0, mults_128b, 0x10),
			   _mm_bsrli_si128(x0, 8));
	x1 = _mm_clmulepi64_si128(x0, barrett_reduction_constants, 0x00);
	x1 = _mm_clmulepi64_si128(x1, barrett_reduction_constants, 0x10);
	x0 = _mm_xor_si128(x0, x1);
	return _mm_extract_epi32(x0, 2);
}

#undef vec_t
#undef fold_vec
#undef VLOADU
#undef VXOR
#undef M128I_TO_VEC
#undef MULTS
#undef MULTS_8V
#undef MULTS_4V
#undef MULTS_2V
#undef MULTS_1V

#undef SUFFIX
#undef ATTRIBUTES
#undef VL
#undef USE_AVX512

#endif

static inline crc32_func_t
arch_select_crc32_func(void)
{
	const u32 features MAYBE_UNUSED = get_x86_cpu_features();

#ifdef crc32_x86_vpclmulqdq_avx512_vl512
	if ((features & X86_CPU_FEATURE_ZMM) &&
	    HAVE_VPCLMULQDQ(features) && HAVE_PCLMULQDQ(features) &&
	    HAVE_AVX512BW(features) && HAVE_AVX512VL(features))
		return crc32_x86_vpclmulqdq_avx512_vl512;
#endif
#ifdef crc32_x86_vpclmulqdq_avx512_vl256
	if (HAVE_VPCLMULQDQ(features) && HAVE_PCLMULQDQ(features) &&
	    HAVE_AVX512BW(features) && HAVE_AVX512VL(features))
		return crc32_x86_vpclmulqdq_avx512_vl256;
#endif
#ifdef crc32_x86_vpclmulqdq_avx2
	if (HAVE_VPCLMULQDQ(features) && HAVE_PCLMULQDQ(features) &&
	    HAVE_AVX2(features))
		return crc32_x86_vpclmulqdq_avx2;
#endif
#ifdef crc32_x86_pclmulqdq_avx
	if (HAVE_PCLMULQDQ(features) && HAVE_AVX(features))
		return crc32_x86_pclmulqdq_avx;
#endif
#ifdef crc32_x86_pclmulqdq
	if (HAVE_PCLMULQDQ(features))
		return crc32_x86_pclmulqdq;
#endif
	return NULL;
}
#define arch_select_crc32_func	arch_select_crc32_func

#endif 

#endif

#ifndef DEFAULT_IMPL
#  define DEFAULT_IMPL crc32_slice8
#endif

#ifdef arch_select_crc32_func
static u32 crc32_dispatch_crc32(u32 crc, const u8 *p, size_t len);

static volatile crc32_func_t crc32_impl = crc32_dispatch_crc32;


static u32 crc32_dispatch_crc32(u32 crc, const u8 *p, size_t len)
{
	crc32_func_t f = arch_select_crc32_func();

	if (f == NULL)
		f = DEFAULT_IMPL;

	crc32_impl = f;
	return f(crc, p, len);
}
#else

#define crc32_impl DEFAULT_IMPL
#endif

LIBDEFLATEAPI u32
libdeflate_crc32(u32 crc, const void *p, size_t len)
{
	if (p == NULL) 
		return 0;
	return ~crc32_impl(~crc, p, len);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/deflate_compress.c */


/* #include "deflate_compress.h" */
#ifndef LIB_DEFLATE_COMPRESS_H
#define LIB_DEFLATE_COMPRESS_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 




struct libdeflate_compressor;

unsigned int libdeflate_get_compression_level(struct libdeflate_compressor *c);

#endif 

/* #include "deflate_constants.h" */


#ifndef LIB_DEFLATE_CONSTANTS_H
#define LIB_DEFLATE_CONSTANTS_H


#define DEFLATE_BLOCKTYPE_UNCOMPRESSED		0
#define DEFLATE_BLOCKTYPE_STATIC_HUFFMAN	1
#define DEFLATE_BLOCKTYPE_DYNAMIC_HUFFMAN	2


#define DEFLATE_MIN_MATCH_LEN			3
#define DEFLATE_MAX_MATCH_LEN			258


#define DEFLATE_MAX_MATCH_OFFSET		32768


#define DEFLATE_WINDOW_ORDER			15


#define DEFLATE_NUM_PRECODE_SYMS		19
#define DEFLATE_NUM_LITLEN_SYMS			288
#define DEFLATE_NUM_OFFSET_SYMS			32


#define DEFLATE_MAX_NUM_SYMS			288


#define DEFLATE_NUM_LITERALS			256
#define DEFLATE_END_OF_BLOCK			256
#define DEFLATE_FIRST_LEN_SYM			257


#define DEFLATE_MAX_PRE_CODEWORD_LEN		7
#define DEFLATE_MAX_LITLEN_CODEWORD_LEN		15
#define DEFLATE_MAX_OFFSET_CODEWORD_LEN		15


#define DEFLATE_MAX_CODEWORD_LEN		15


#define DEFLATE_MAX_LENS_OVERRUN		137


#define DEFLATE_MAX_EXTRA_LENGTH_BITS		5
#define DEFLATE_MAX_EXTRA_OFFSET_BITS		13

#endif 







#define SUPPORT_NEAR_OPTIMAL_PARSING	1


#define MIN_BLOCK_LENGTH	5000


#define SOFT_MAX_BLOCK_LENGTH	300000


#define SEQ_STORE_LENGTH	50000


#define FAST_SOFT_MAX_BLOCK_LENGTH	65535


#define FAST_SEQ_STORE_LENGTH	8192


#define MAX_LITLEN_CODEWORD_LEN		14
#define MAX_OFFSET_CODEWORD_LEN		DEFLATE_MAX_OFFSET_CODEWORD_LEN
#define MAX_PRE_CODEWORD_LEN		DEFLATE_MAX_PRE_CODEWORD_LEN

#if SUPPORT_NEAR_OPTIMAL_PARSING




#define BIT_COST	16


#define LITERAL_NOSTAT_BITS	13
#define LENGTH_NOSTAT_BITS	13
#define OFFSET_NOSTAT_BITS	10


#define MATCH_CACHE_LENGTH	(SOFT_MAX_BLOCK_LENGTH * 5)

#endif 




#define MATCHFINDER_WINDOW_ORDER	DEFLATE_WINDOW_ORDER
/* #include "hc_matchfinder.h" */


#ifndef LIB_HC_MATCHFINDER_H
#define LIB_HC_MATCHFINDER_H

/* #include "matchfinder_common.h" */


#ifndef LIB_MATCHFINDER_COMMON_H
#define LIB_MATCHFINDER_COMMON_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#ifndef MATCHFINDER_WINDOW_ORDER
#  error "MATCHFINDER_WINDOW_ORDER must be defined!"
#endif


static forceinline u32
loaded_u32_to_u24(u32 v)
{
	if (CPU_IS_LITTLE_ENDIAN())
		return v & 0xFFFFFF;
	else
		return v >> 8;
}


static forceinline u32
load_u24_unaligned(const u8 *p)
{
#if UNALIGNED_ACCESS_IS_FAST
	return loaded_u32_to_u24(load_u32_unaligned(p));
#else
	if (CPU_IS_LITTLE_ENDIAN())
		return ((u32)p[0] << 0) | ((u32)p[1] << 8) | ((u32)p[2] << 16);
	else
		return ((u32)p[2] << 0) | ((u32)p[1] << 8) | ((u32)p[0] << 16);
#endif
}

#define MATCHFINDER_WINDOW_SIZE (1UL << MATCHFINDER_WINDOW_ORDER)

typedef s16 mf_pos_t;

#define MATCHFINDER_INITVAL ((mf_pos_t)-MATCHFINDER_WINDOW_SIZE)


#define MATCHFINDER_MEM_ALIGNMENT	32


#define MATCHFINDER_SIZE_ALIGNMENT	1024

#undef matchfinder_init
#undef matchfinder_rebase
#ifdef _aligned_attribute
#  define MATCHFINDER_ALIGNED _aligned_attribute(MATCHFINDER_MEM_ALIGNMENT)
#  if defined(ARCH_ARM32) || defined(ARCH_ARM64)
/* #    include "arm/matchfinder_impl.h" */


#ifndef LIB_ARM_MATCHFINDER_IMPL_H
#define LIB_ARM_MATCHFINDER_IMPL_H

/* #include "arm-cpu_features.h" */


#ifndef LIB_ARM_CPU_FEATURES_H
#define LIB_ARM_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_ARM32) || defined(ARCH_ARM64)

#define ARM_CPU_FEATURE_NEON		(1 << 0)
#define ARM_CPU_FEATURE_PMULL		(1 << 1)

#define ARM_CPU_FEATURE_PREFER_PMULL	(1 << 2)
#define ARM_CPU_FEATURE_CRC32		(1 << 3)
#define ARM_CPU_FEATURE_SHA3		(1 << 4)
#define ARM_CPU_FEATURE_DOTPROD		(1 << 5)

#if !defined(FREESTANDING) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
    (defined(__linux__) || \
     (defined(__APPLE__) && defined(ARCH_ARM64)) || \
     (defined(_WIN32) && defined(ARCH_ARM64)))

#  define ARM_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_arm_cpu_features;

void libdeflate_init_arm_cpu_features(void);

static inline u32 get_arm_cpu_features(void)
{
	if (libdeflate_arm_cpu_features == 0)
		libdeflate_init_arm_cpu_features();
	return libdeflate_arm_cpu_features;
}
#else
static inline u32 get_arm_cpu_features(void) { return 0; }
#endif


#if defined(__ARM_NEON) || (defined(_MSC_VER) && defined(ARCH_ARM64))
#  define HAVE_NEON(features)	1
#  define HAVE_NEON_NATIVE	1
#else
#  define HAVE_NEON(features)	((features) & ARM_CPU_FEATURE_NEON)
#  define HAVE_NEON_NATIVE	0
#endif

#if (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
	(HAVE_NEON_NATIVE || (GCC_PREREQ(6, 1) && defined(__ARM_FP)))
#  define HAVE_NEON_INTRIN	1
#  include <arm_neon.h>
#else
#  define HAVE_NEON_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRYPTO
#  define HAVE_PMULL(features)	1
#else
#  define HAVE_PMULL(features)	((features) & ARM_CPU_FEATURE_PMULL)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(7, 1) || defined(__clang__) || defined(_MSC_VER)) && \
	CPU_IS_LITTLE_ENDIAN() 
#  define HAVE_PMULL_INTRIN	1
   
#  ifdef _MSC_VER
#    define compat_vmull_p64(a, b)  vmull_p64(vcreate_p64(a), vcreate_p64(b))
#  else
#    define compat_vmull_p64(a, b)  vmull_p64((a), (b))
#  endif
#else
#  define HAVE_PMULL_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRC32
#  define HAVE_CRC32(features)	1
#else
#  define HAVE_CRC32(features)	((features) & ARM_CPU_FEATURE_CRC32)
#endif
#if defined(ARCH_ARM64) && \
	(defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))
#  define HAVE_CRC32_INTRIN	1
#  if defined(__GNUC__) || defined(__clang__)
#    include <arm_acle.h>
#  endif
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_CRC32)
#    undef __crc32b
#    define __crc32b(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32b %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32h
#    define __crc32h(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32h %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32w
#    define __crc32w(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32w %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32d
#    define __crc32d(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32x %w0, %w1, %2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_CRC32_INTRIN	0
#endif


#ifdef __ARM_FEATURE_SHA3
#  define HAVE_SHA3(features)	1
#else
#  define HAVE_SHA3(features)	((features) & ARM_CPU_FEATURE_SHA3)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(9, 1)  || \
	 CLANG_PREREQ(7, 0, 10010463) )
#  define HAVE_SHA3_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_SHA3)
#    undef veor3q_u8
#    define veor3q_u8(a, b, c)					\
	({ uint8x16_t res;					\
	   __asm__("eor3 %0.16b, %1.16b, %2.16b, %3.16b"	\
		   : "=w" (res) : "w" (a), "w" (b), "w" (c));	\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_SHA3_INTRIN	0
#endif


#ifdef __ARM_FEATURE_DOTPROD
#  define HAVE_DOTPROD(features)	1
#else
#  define HAVE_DOTPROD(features)	((features) & ARM_CPU_FEATURE_DOTPROD)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(8, 1) || CLANG_PREREQ(7, 0, 10010000) || defined(_MSC_VER))
#  define HAVE_DOTPROD_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_DOTPROD)
#    undef vdotq_u32
#    define vdotq_u32(a, b, c)					\
	({ uint32x4_t res = (a);				\
	   __asm__("udot %0.4s, %1.16b, %2.16b"			\
		   : "+w" (res) : "w" (b), "w" (c));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_DOTPROD_INTRIN	0
#endif

#endif 

#endif 


#if HAVE_NEON_NATIVE
static forceinline void
matchfinder_init_neon(mf_pos_t *data, size_t size)
{
	int16x8_t *p = (int16x8_t *)data;
	int16x8_t v = vdupq_n_s16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_neon

static forceinline void
matchfinder_rebase_neon(mf_pos_t *data, size_t size)
{
	int16x8_t *p = (int16x8_t *)data;
	int16x8_t v = vdupq_n_s16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = vqaddq_s16(p[0], v);
		p[1] = vqaddq_s16(p[1], v);
		p[2] = vqaddq_s16(p[2], v);
		p[3] = vqaddq_s16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_neon

#endif 

#endif 

#  elif defined(ARCH_RISCV)
#    include "riscv/matchfinder_impl.h"
#  elif defined(ARCH_X86_32) || defined(ARCH_X86_64)
/* #    include "x86/matchfinder_impl.h" */


#ifndef LIB_X86_MATCHFINDER_IMPL_H
#define LIB_X86_MATCHFINDER_IMPL_H

/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 


#ifdef __AVX2__
static forceinline void
matchfinder_init_avx2(mf_pos_t *data, size_t size)
{
	__m256i *p = (__m256i *)data;
	__m256i v = _mm256_set1_epi16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_avx2

static forceinline void
matchfinder_rebase_avx2(mf_pos_t *data, size_t size)
{
	__m256i *p = (__m256i *)data;
	__m256i v = _mm256_set1_epi16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		
		p[0] = _mm256_adds_epi16(p[0], v);
		p[1] = _mm256_adds_epi16(p[1], v);
		p[2] = _mm256_adds_epi16(p[2], v);
		p[3] = _mm256_adds_epi16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_avx2

#elif HAVE_SSE2_NATIVE
static forceinline void
matchfinder_init_sse2(mf_pos_t *data, size_t size)
{
	__m128i *p = (__m128i *)data;
	__m128i v = _mm_set1_epi16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_sse2

static forceinline void
matchfinder_rebase_sse2(mf_pos_t *data, size_t size)
{
	__m128i *p = (__m128i *)data;
	__m128i v = _mm_set1_epi16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		
		p[0] = _mm_adds_epi16(p[0], v);
		p[1] = _mm_adds_epi16(p[1], v);
		p[2] = _mm_adds_epi16(p[2], v);
		p[3] = _mm_adds_epi16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_sse2
#endif 

#endif 

#  endif
#else
#  define MATCHFINDER_ALIGNED
#endif


#ifndef matchfinder_init
static forceinline void
matchfinder_init(mf_pos_t *data, size_t size)
{
	size_t num_entries = size / sizeof(*data);
	size_t i;

	for (i = 0; i < num_entries; i++)
		data[i] = MATCHFINDER_INITVAL;
}
#endif


#ifndef matchfinder_rebase
static forceinline void
matchfinder_rebase(mf_pos_t *data, size_t size)
{
	size_t num_entries = size / sizeof(*data);
	size_t i;

	if (MATCHFINDER_WINDOW_SIZE == 32768) {
		
		for (i = 0; i < num_entries; i++)
			data[i] = 0x8000 | (data[i] & ~(data[i] >> 15));
	} else {
		for (i = 0; i < num_entries; i++) {
			if (data[i] >= 0)
				data[i] -= (mf_pos_t)-MATCHFINDER_WINDOW_SIZE;
			else
				data[i] = (mf_pos_t)-MATCHFINDER_WINDOW_SIZE;
		}
	}
}
#endif


static forceinline u32
lz_hash(u32 seq, unsigned num_bits)
{
	return (u32)(seq * 0x1E35A7BD) >> (32 - num_bits);
}


static forceinline u32
lz_extend(const u8 * const strptr, const u8 * const matchptr,
	  const u32 start_len, const u32 max_len)
{
	u32 len = start_len;
	machine_word_t v_word;

	if (UNALIGNED_ACCESS_IS_FAST) {

		if (likely(max_len - len >= 4 * WORDBYTES)) {

		#define COMPARE_WORD_STEP				\
			v_word = load_word_unaligned(&matchptr[len]) ^	\
				 load_word_unaligned(&strptr[len]);	\
			if (v_word != 0)				\
				goto word_differs;			\
			len += WORDBYTES;				\

			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
		#undef COMPARE_WORD_STEP
		}

		while (len + WORDBYTES <= max_len) {
			v_word = load_word_unaligned(&matchptr[len]) ^
				 load_word_unaligned(&strptr[len]);
			if (v_word != 0)
				goto word_differs;
			len += WORDBYTES;
		}
	}

	while (len < max_len && matchptr[len] == strptr[len])
		len++;
	return len;

word_differs:
	if (CPU_IS_LITTLE_ENDIAN())
		len += (bsfw(v_word) >> 3);
	else
		len += (WORDBITS - 1 - bsrw(v_word)) >> 3;
	return len;
}

#endif 


#define HC_MATCHFINDER_HASH3_ORDER	15
#define HC_MATCHFINDER_HASH4_ORDER	16

#define HC_MATCHFINDER_TOTAL_HASH_SIZE			\
	(((1UL << HC_MATCHFINDER_HASH3_ORDER) +		\
	  (1UL << HC_MATCHFINDER_HASH4_ORDER)) * sizeof(mf_pos_t))

struct MATCHFINDER_ALIGNED hc_matchfinder  {

	
	mf_pos_t hash3_tab[1UL << HC_MATCHFINDER_HASH3_ORDER];

	
	mf_pos_t hash4_tab[1UL << HC_MATCHFINDER_HASH4_ORDER];

	
	mf_pos_t next_tab[MATCHFINDER_WINDOW_SIZE];
};


static forceinline void
hc_matchfinder_init(struct hc_matchfinder *mf)
{
	STATIC_ASSERT(HC_MATCHFINDER_TOTAL_HASH_SIZE %
		      MATCHFINDER_SIZE_ALIGNMENT == 0);

	matchfinder_init((mf_pos_t *)mf, HC_MATCHFINDER_TOTAL_HASH_SIZE);
}

static forceinline void
hc_matchfinder_slide_window(struct hc_matchfinder *mf)
{
	STATIC_ASSERT(sizeof(*mf) % MATCHFINDER_SIZE_ALIGNMENT == 0);

	matchfinder_rebase((mf_pos_t *)mf, sizeof(*mf));
}


static forceinline u32
hc_matchfinder_longest_match(struct hc_matchfinder * const mf,
			     const u8 ** const in_base_p,
			     const u8 * const in_next,
			     u32 best_len,
			     const u32 max_len,
			     const u32 nice_len,
			     const u32 max_search_depth,
			     u32 * const next_hashes,
			     u32 * const offset_ret)
{
	u32 depth_remaining = max_search_depth;
	const u8 *best_matchptr = in_next;
	mf_pos_t cur_node3, cur_node4;
	u32 hash3, hash4;
	u32 next_hashseq;
	u32 seq4;
	const u8 *matchptr;
	u32 len;
	u32 cur_pos = in_next - *in_base_p;
	const u8 *in_base;
	mf_pos_t cutoff;

	if (cur_pos == MATCHFINDER_WINDOW_SIZE) {
		hc_matchfinder_slide_window(mf);
		*in_base_p += MATCHFINDER_WINDOW_SIZE;
		cur_pos = 0;
	}

	in_base = *in_base_p;
	cutoff = cur_pos - MATCHFINDER_WINDOW_SIZE;

	if (unlikely(max_len < 5)) 
		goto out;

	
	hash3 = next_hashes[0];
	hash4 = next_hashes[1];

	
	cur_node3 = mf->hash3_tab[hash3];
	cur_node4 = mf->hash4_tab[hash4];

	
	mf->hash3_tab[hash3] = cur_pos;

	
	mf->hash4_tab[hash4] = cur_pos;
	mf->next_tab[cur_pos] = cur_node4;

	
	next_hashseq = get_unaligned_le32(in_next + 1);
	next_hashes[0] = lz_hash(next_hashseq & 0xFFFFFF, HC_MATCHFINDER_HASH3_ORDER);
	next_hashes[1] = lz_hash(next_hashseq, HC_MATCHFINDER_HASH4_ORDER);
	prefetchw(&mf->hash3_tab[next_hashes[0]]);
	prefetchw(&mf->hash4_tab[next_hashes[1]]);

	if (best_len < 4) {  

		

		if (cur_node3 <= cutoff)
			goto out;

		seq4 = load_u32_unaligned(in_next);

		if (best_len < 3) {
			matchptr = &in_base[cur_node3];
			if (load_u24_unaligned(matchptr) == loaded_u32_to_u24(seq4)) {
				best_len = 3;
				best_matchptr = matchptr;
			}
		}

		

		if (cur_node4 <= cutoff)
			goto out;

		for (;;) {
			
			matchptr = &in_base[cur_node4];

			if (load_u32_unaligned(matchptr) == seq4)
				break;

			
			cur_node4 = mf->next_tab[cur_node4 & (MATCHFINDER_WINDOW_SIZE - 1)];
			if (cur_node4 <= cutoff || !--depth_remaining)
				goto out;
		}

		
		best_matchptr = matchptr;
		best_len = lz_extend(in_next, best_matchptr, 4, max_len);
		if (best_len >= nice_len)
			goto out;
		cur_node4 = mf->next_tab[cur_node4 & (MATCHFINDER_WINDOW_SIZE - 1)];
		if (cur_node4 <= cutoff || !--depth_remaining)
			goto out;
	} else {
		if (cur_node4 <= cutoff || best_len >= nice_len)
			goto out;
	}

	

	for (;;) {
		for (;;) {
			matchptr = &in_base[cur_node4];

			
		#if UNALIGNED_ACCESS_IS_FAST
			if ((load_u32_unaligned(matchptr + best_len - 3) ==
			     load_u32_unaligned(in_next + best_len - 3)) &&
			    (load_u32_unaligned(matchptr) ==
			     load_u32_unaligned(in_next)))
		#else
			if (matchptr[best_len] == in_next[best_len])
		#endif
				break;

			
			cur_node4 = mf->next_tab[cur_node4 & (MATCHFINDER_WINDOW_SIZE - 1)];
			if (cur_node4 <= cutoff || !--depth_remaining)
				goto out;
		}

	#if UNALIGNED_ACCESS_IS_FAST
		len = 4;
	#else
		len = 0;
	#endif
		len = lz_extend(in_next, matchptr, len, max_len);
		if (len > best_len) {
			
			best_len = len;
			best_matchptr = matchptr;
			if (best_len >= nice_len)
				goto out;
		}

		
		cur_node4 = mf->next_tab[cur_node4 & (MATCHFINDER_WINDOW_SIZE - 1)];
		if (cur_node4 <= cutoff || !--depth_remaining)
			goto out;
	}
out:
	*offset_ret = in_next - best_matchptr;
	return best_len;
}


static forceinline void
hc_matchfinder_skip_bytes(struct hc_matchfinder * const mf,
			  const u8 ** const in_base_p,
			  const u8 *in_next,
			  const u8 * const in_end,
			  const u32 count,
			  u32 * const next_hashes)
{
	u32 cur_pos;
	u32 hash3, hash4;
	u32 next_hashseq;
	u32 remaining = count;

	if (unlikely(count + 5 > in_end - in_next))
		return;

	cur_pos = in_next - *in_base_p;
	hash3 = next_hashes[0];
	hash4 = next_hashes[1];
	do {
		if (cur_pos == MATCHFINDER_WINDOW_SIZE) {
			hc_matchfinder_slide_window(mf);
			*in_base_p += MATCHFINDER_WINDOW_SIZE;
			cur_pos = 0;
		}
		mf->hash3_tab[hash3] = cur_pos;
		mf->next_tab[cur_pos] = mf->hash4_tab[hash4];
		mf->hash4_tab[hash4] = cur_pos;

		next_hashseq = get_unaligned_le32(++in_next);
		hash3 = lz_hash(next_hashseq & 0xFFFFFF, HC_MATCHFINDER_HASH3_ORDER);
		hash4 = lz_hash(next_hashseq, HC_MATCHFINDER_HASH4_ORDER);
		cur_pos++;
	} while (--remaining);

	prefetchw(&mf->hash3_tab[hash3]);
	prefetchw(&mf->hash4_tab[hash4]);
	next_hashes[0] = hash3;
	next_hashes[1] = hash4;
}

#endif 

/* #include "ht_matchfinder.h" */


#ifndef LIB_HT_MATCHFINDER_H
#define LIB_HT_MATCHFINDER_H

/* #include "matchfinder_common.h" */


#ifndef LIB_MATCHFINDER_COMMON_H
#define LIB_MATCHFINDER_COMMON_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#ifndef MATCHFINDER_WINDOW_ORDER
#  error "MATCHFINDER_WINDOW_ORDER must be defined!"
#endif


static forceinline u32
loaded_u32_to_u24(u32 v)
{
	if (CPU_IS_LITTLE_ENDIAN())
		return v & 0xFFFFFF;
	else
		return v >> 8;
}


static forceinline u32
load_u24_unaligned(const u8 *p)
{
#if UNALIGNED_ACCESS_IS_FAST
	return loaded_u32_to_u24(load_u32_unaligned(p));
#else
	if (CPU_IS_LITTLE_ENDIAN())
		return ((u32)p[0] << 0) | ((u32)p[1] << 8) | ((u32)p[2] << 16);
	else
		return ((u32)p[2] << 0) | ((u32)p[1] << 8) | ((u32)p[0] << 16);
#endif
}

#define MATCHFINDER_WINDOW_SIZE (1UL << MATCHFINDER_WINDOW_ORDER)

typedef s16 mf_pos_t;

#define MATCHFINDER_INITVAL ((mf_pos_t)-MATCHFINDER_WINDOW_SIZE)


#define MATCHFINDER_MEM_ALIGNMENT	32


#define MATCHFINDER_SIZE_ALIGNMENT	1024

#undef matchfinder_init
#undef matchfinder_rebase
#ifdef _aligned_attribute
#  define MATCHFINDER_ALIGNED _aligned_attribute(MATCHFINDER_MEM_ALIGNMENT)
#  if defined(ARCH_ARM32) || defined(ARCH_ARM64)
/* #    include "arm/matchfinder_impl.h" */


#ifndef LIB_ARM_MATCHFINDER_IMPL_H
#define LIB_ARM_MATCHFINDER_IMPL_H

/* #include "arm-cpu_features.h" */


#ifndef LIB_ARM_CPU_FEATURES_H
#define LIB_ARM_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_ARM32) || defined(ARCH_ARM64)

#define ARM_CPU_FEATURE_NEON		(1 << 0)
#define ARM_CPU_FEATURE_PMULL		(1 << 1)

#define ARM_CPU_FEATURE_PREFER_PMULL	(1 << 2)
#define ARM_CPU_FEATURE_CRC32		(1 << 3)
#define ARM_CPU_FEATURE_SHA3		(1 << 4)
#define ARM_CPU_FEATURE_DOTPROD		(1 << 5)

#if !defined(FREESTANDING) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
    (defined(__linux__) || \
     (defined(__APPLE__) && defined(ARCH_ARM64)) || \
     (defined(_WIN32) && defined(ARCH_ARM64)))

#  define ARM_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_arm_cpu_features;

void libdeflate_init_arm_cpu_features(void);

static inline u32 get_arm_cpu_features(void)
{
	if (libdeflate_arm_cpu_features == 0)
		libdeflate_init_arm_cpu_features();
	return libdeflate_arm_cpu_features;
}
#else
static inline u32 get_arm_cpu_features(void) { return 0; }
#endif


#if defined(__ARM_NEON) || (defined(_MSC_VER) && defined(ARCH_ARM64))
#  define HAVE_NEON(features)	1
#  define HAVE_NEON_NATIVE	1
#else
#  define HAVE_NEON(features)	((features) & ARM_CPU_FEATURE_NEON)
#  define HAVE_NEON_NATIVE	0
#endif

#if (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
	(HAVE_NEON_NATIVE || (GCC_PREREQ(6, 1) && defined(__ARM_FP)))
#  define HAVE_NEON_INTRIN	1
#  include <arm_neon.h>
#else
#  define HAVE_NEON_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRYPTO
#  define HAVE_PMULL(features)	1
#else
#  define HAVE_PMULL(features)	((features) & ARM_CPU_FEATURE_PMULL)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(7, 1) || defined(__clang__) || defined(_MSC_VER)) && \
	CPU_IS_LITTLE_ENDIAN() 
#  define HAVE_PMULL_INTRIN	1
   
#  ifdef _MSC_VER
#    define compat_vmull_p64(a, b)  vmull_p64(vcreate_p64(a), vcreate_p64(b))
#  else
#    define compat_vmull_p64(a, b)  vmull_p64((a), (b))
#  endif
#else
#  define HAVE_PMULL_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRC32
#  define HAVE_CRC32(features)	1
#else
#  define HAVE_CRC32(features)	((features) & ARM_CPU_FEATURE_CRC32)
#endif
#if defined(ARCH_ARM64) && \
	(defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))
#  define HAVE_CRC32_INTRIN	1
#  if defined(__GNUC__) || defined(__clang__)
#    include <arm_acle.h>
#  endif
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_CRC32)
#    undef __crc32b
#    define __crc32b(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32b %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32h
#    define __crc32h(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32h %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32w
#    define __crc32w(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32w %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32d
#    define __crc32d(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32x %w0, %w1, %2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_CRC32_INTRIN	0
#endif


#ifdef __ARM_FEATURE_SHA3
#  define HAVE_SHA3(features)	1
#else
#  define HAVE_SHA3(features)	((features) & ARM_CPU_FEATURE_SHA3)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(9, 1)  || \
	 CLANG_PREREQ(7, 0, 10010463) )
#  define HAVE_SHA3_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_SHA3)
#    undef veor3q_u8
#    define veor3q_u8(a, b, c)					\
	({ uint8x16_t res;					\
	   __asm__("eor3 %0.16b, %1.16b, %2.16b, %3.16b"	\
		   : "=w" (res) : "w" (a), "w" (b), "w" (c));	\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_SHA3_INTRIN	0
#endif


#ifdef __ARM_FEATURE_DOTPROD
#  define HAVE_DOTPROD(features)	1
#else
#  define HAVE_DOTPROD(features)	((features) & ARM_CPU_FEATURE_DOTPROD)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(8, 1) || CLANG_PREREQ(7, 0, 10010000) || defined(_MSC_VER))
#  define HAVE_DOTPROD_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_DOTPROD)
#    undef vdotq_u32
#    define vdotq_u32(a, b, c)					\
	({ uint32x4_t res = (a);				\
	   __asm__("udot %0.4s, %1.16b, %2.16b"			\
		   : "+w" (res) : "w" (b), "w" (c));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_DOTPROD_INTRIN	0
#endif

#endif 

#endif 


#if HAVE_NEON_NATIVE
static forceinline void
matchfinder_init_neon(mf_pos_t *data, size_t size)
{
	int16x8_t *p = (int16x8_t *)data;
	int16x8_t v = vdupq_n_s16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_neon

static forceinline void
matchfinder_rebase_neon(mf_pos_t *data, size_t size)
{
	int16x8_t *p = (int16x8_t *)data;
	int16x8_t v = vdupq_n_s16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = vqaddq_s16(p[0], v);
		p[1] = vqaddq_s16(p[1], v);
		p[2] = vqaddq_s16(p[2], v);
		p[3] = vqaddq_s16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_neon

#endif 

#endif 

#  elif defined(ARCH_RISCV)
#    include "riscv/matchfinder_impl.h"
#  elif defined(ARCH_X86_32) || defined(ARCH_X86_64)
/* #    include "x86/matchfinder_impl.h" */


#ifndef LIB_X86_MATCHFINDER_IMPL_H
#define LIB_X86_MATCHFINDER_IMPL_H

/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 


#ifdef __AVX2__
static forceinline void
matchfinder_init_avx2(mf_pos_t *data, size_t size)
{
	__m256i *p = (__m256i *)data;
	__m256i v = _mm256_set1_epi16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_avx2

static forceinline void
matchfinder_rebase_avx2(mf_pos_t *data, size_t size)
{
	__m256i *p = (__m256i *)data;
	__m256i v = _mm256_set1_epi16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		
		p[0] = _mm256_adds_epi16(p[0], v);
		p[1] = _mm256_adds_epi16(p[1], v);
		p[2] = _mm256_adds_epi16(p[2], v);
		p[3] = _mm256_adds_epi16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_avx2

#elif HAVE_SSE2_NATIVE
static forceinline void
matchfinder_init_sse2(mf_pos_t *data, size_t size)
{
	__m128i *p = (__m128i *)data;
	__m128i v = _mm_set1_epi16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_sse2

static forceinline void
matchfinder_rebase_sse2(mf_pos_t *data, size_t size)
{
	__m128i *p = (__m128i *)data;
	__m128i v = _mm_set1_epi16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		
		p[0] = _mm_adds_epi16(p[0], v);
		p[1] = _mm_adds_epi16(p[1], v);
		p[2] = _mm_adds_epi16(p[2], v);
		p[3] = _mm_adds_epi16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_sse2
#endif 

#endif 

#  endif
#else
#  define MATCHFINDER_ALIGNED
#endif


#ifndef matchfinder_init
static forceinline void
matchfinder_init(mf_pos_t *data, size_t size)
{
	size_t num_entries = size / sizeof(*data);
	size_t i;

	for (i = 0; i < num_entries; i++)
		data[i] = MATCHFINDER_INITVAL;
}
#endif


#ifndef matchfinder_rebase
static forceinline void
matchfinder_rebase(mf_pos_t *data, size_t size)
{
	size_t num_entries = size / sizeof(*data);
	size_t i;

	if (MATCHFINDER_WINDOW_SIZE == 32768) {
		
		for (i = 0; i < num_entries; i++)
			data[i] = 0x8000 | (data[i] & ~(data[i] >> 15));
	} else {
		for (i = 0; i < num_entries; i++) {
			if (data[i] >= 0)
				data[i] -= (mf_pos_t)-MATCHFINDER_WINDOW_SIZE;
			else
				data[i] = (mf_pos_t)-MATCHFINDER_WINDOW_SIZE;
		}
	}
}
#endif


static forceinline u32
lz_hash(u32 seq, unsigned num_bits)
{
	return (u32)(seq * 0x1E35A7BD) >> (32 - num_bits);
}


static forceinline u32
lz_extend(const u8 * const strptr, const u8 * const matchptr,
	  const u32 start_len, const u32 max_len)
{
	u32 len = start_len;
	machine_word_t v_word;

	if (UNALIGNED_ACCESS_IS_FAST) {

		if (likely(max_len - len >= 4 * WORDBYTES)) {

		#define COMPARE_WORD_STEP				\
			v_word = load_word_unaligned(&matchptr[len]) ^	\
				 load_word_unaligned(&strptr[len]);	\
			if (v_word != 0)				\
				goto word_differs;			\
			len += WORDBYTES;				\

			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
		#undef COMPARE_WORD_STEP
		}

		while (len + WORDBYTES <= max_len) {
			v_word = load_word_unaligned(&matchptr[len]) ^
				 load_word_unaligned(&strptr[len]);
			if (v_word != 0)
				goto word_differs;
			len += WORDBYTES;
		}
	}

	while (len < max_len && matchptr[len] == strptr[len])
		len++;
	return len;

word_differs:
	if (CPU_IS_LITTLE_ENDIAN())
		len += (bsfw(v_word) >> 3);
	else
		len += (WORDBITS - 1 - bsrw(v_word)) >> 3;
	return len;
}

#endif 


#define HT_MATCHFINDER_HASH_ORDER	15
#define HT_MATCHFINDER_BUCKET_SIZE	2

#define HT_MATCHFINDER_MIN_MATCH_LEN	4

#define HT_MATCHFINDER_REQUIRED_NBYTES	5

struct MATCHFINDER_ALIGNED ht_matchfinder {
	mf_pos_t hash_tab[1UL << HT_MATCHFINDER_HASH_ORDER]
			 [HT_MATCHFINDER_BUCKET_SIZE];
};

static forceinline void
ht_matchfinder_init(struct ht_matchfinder *mf)
{
	STATIC_ASSERT(sizeof(*mf) % MATCHFINDER_SIZE_ALIGNMENT == 0);

	matchfinder_init((mf_pos_t *)mf, sizeof(*mf));
}

static forceinline void
ht_matchfinder_slide_window(struct ht_matchfinder *mf)
{
	matchfinder_rebase((mf_pos_t *)mf, sizeof(*mf));
}


static forceinline u32
ht_matchfinder_longest_match(struct ht_matchfinder * const mf,
			     const u8 ** const in_base_p,
			     const u8 * const in_next,
			     const u32 max_len,
			     const u32 nice_len,
			     u32 * const next_hash,
			     u32 * const offset_ret)
{
	u32 best_len = 0;
	const u8 *best_matchptr = in_next;
	u32 cur_pos = in_next - *in_base_p;
	const u8 *in_base;
	mf_pos_t cutoff;
	u32 hash;
	u32 seq;
	mf_pos_t cur_node;
	const u8 *matchptr;
#if HT_MATCHFINDER_BUCKET_SIZE > 1
	mf_pos_t to_insert;
	u32 len;
#endif
#if HT_MATCHFINDER_BUCKET_SIZE > 2
	int i;
#endif

	
	STATIC_ASSERT(HT_MATCHFINDER_MIN_MATCH_LEN == 4);

	if (cur_pos == MATCHFINDER_WINDOW_SIZE) {
		ht_matchfinder_slide_window(mf);
		*in_base_p += MATCHFINDER_WINDOW_SIZE;
		cur_pos = 0;
	}
	in_base = *in_base_p;
	cutoff = cur_pos - MATCHFINDER_WINDOW_SIZE;

	hash = *next_hash;
	STATIC_ASSERT(HT_MATCHFINDER_REQUIRED_NBYTES == 5);
	*next_hash = lz_hash(get_unaligned_le32(in_next + 1),
			     HT_MATCHFINDER_HASH_ORDER);
	seq = load_u32_unaligned(in_next);
	prefetchw(&mf->hash_tab[*next_hash]);
#if HT_MATCHFINDER_BUCKET_SIZE == 1
	
	cur_node = mf->hash_tab[hash][0];
	mf->hash_tab[hash][0] = cur_pos;
	if (cur_node <= cutoff)
		goto out;
	matchptr = &in_base[cur_node];
	if (load_u32_unaligned(matchptr) == seq) {
		best_len = lz_extend(in_next, matchptr, 4, max_len);
		best_matchptr = matchptr;
	}
#elif HT_MATCHFINDER_BUCKET_SIZE == 2
	
	cur_node = mf->hash_tab[hash][0];
	mf->hash_tab[hash][0] = cur_pos;
	if (cur_node <= cutoff)
		goto out;
	matchptr = &in_base[cur_node];

	to_insert = cur_node;
	cur_node = mf->hash_tab[hash][1];
	mf->hash_tab[hash][1] = to_insert;

	if (load_u32_unaligned(matchptr) == seq) {
		best_len = lz_extend(in_next, matchptr, 4, max_len);
		best_matchptr = matchptr;
		if (cur_node <= cutoff || best_len >= nice_len)
			goto out;
		matchptr = &in_base[cur_node];
		if (load_u32_unaligned(matchptr) == seq &&
		    load_u32_unaligned(matchptr + best_len - 3) ==
		    load_u32_unaligned(in_next + best_len - 3)) {
			len = lz_extend(in_next, matchptr, 4, max_len);
			if (len > best_len) {
				best_len = len;
				best_matchptr = matchptr;
			}
		}
	} else {
		if (cur_node <= cutoff)
			goto out;
		matchptr = &in_base[cur_node];
		if (load_u32_unaligned(matchptr) == seq) {
			best_len = lz_extend(in_next, matchptr, 4, max_len);
			best_matchptr = matchptr;
		}
	}
#else
	
	to_insert = cur_pos;
	for (i = 0; i < HT_MATCHFINDER_BUCKET_SIZE; i++) {
		cur_node = mf->hash_tab[hash][i];
		mf->hash_tab[hash][i] = to_insert;
		if (cur_node <= cutoff)
			goto out;
		matchptr = &in_base[cur_node];
		if (load_u32_unaligned(matchptr) == seq) {
			len = lz_extend(in_next, matchptr, 4, max_len);
			if (len > best_len) {
				best_len = len;
				best_matchptr = matchptr;
				if (best_len >= nice_len)
					goto out;
			}
		}
		to_insert = cur_node;
	}
#endif
out:
	*offset_ret = in_next - best_matchptr;
	return best_len;
}

static forceinline void
ht_matchfinder_skip_bytes(struct ht_matchfinder * const mf,
			  const u8 ** const in_base_p,
			  const u8 *in_next,
			  const u8 * const in_end,
			  const u32 count,
			  u32 * const next_hash)
{
	s32 cur_pos = in_next - *in_base_p;
	u32 hash;
	u32 remaining = count;
	int i;

	if (unlikely(count + HT_MATCHFINDER_REQUIRED_NBYTES > in_end - in_next))
		return;

	if (cur_pos + count - 1 >= MATCHFINDER_WINDOW_SIZE) {
		ht_matchfinder_slide_window(mf);
		*in_base_p += MATCHFINDER_WINDOW_SIZE;
		cur_pos -= MATCHFINDER_WINDOW_SIZE;
	}

	hash = *next_hash;
	do {
		for (i = HT_MATCHFINDER_BUCKET_SIZE - 1; i > 0; i--)
			mf->hash_tab[hash][i] = mf->hash_tab[hash][i - 1];
		mf->hash_tab[hash][0] = cur_pos;

		hash = lz_hash(get_unaligned_le32(++in_next),
			       HT_MATCHFINDER_HASH_ORDER);
		cur_pos++;
	} while (--remaining);

	prefetchw(&mf->hash_tab[hash]);
	*next_hash = hash;
}

#endif 

#if SUPPORT_NEAR_OPTIMAL_PARSING
/* #  include "bt_matchfinder.h" */


#ifndef LIB_BT_MATCHFINDER_H
#define LIB_BT_MATCHFINDER_H

/* #include "matchfinder_common.h" */


#ifndef LIB_MATCHFINDER_COMMON_H
#define LIB_MATCHFINDER_COMMON_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#ifndef MATCHFINDER_WINDOW_ORDER
#  error "MATCHFINDER_WINDOW_ORDER must be defined!"
#endif


static forceinline u32
loaded_u32_to_u24(u32 v)
{
	if (CPU_IS_LITTLE_ENDIAN())
		return v & 0xFFFFFF;
	else
		return v >> 8;
}


static forceinline u32
load_u24_unaligned(const u8 *p)
{
#if UNALIGNED_ACCESS_IS_FAST
	return loaded_u32_to_u24(load_u32_unaligned(p));
#else
	if (CPU_IS_LITTLE_ENDIAN())
		return ((u32)p[0] << 0) | ((u32)p[1] << 8) | ((u32)p[2] << 16);
	else
		return ((u32)p[2] << 0) | ((u32)p[1] << 8) | ((u32)p[0] << 16);
#endif
}

#define MATCHFINDER_WINDOW_SIZE (1UL << MATCHFINDER_WINDOW_ORDER)

typedef s16 mf_pos_t;

#define MATCHFINDER_INITVAL ((mf_pos_t)-MATCHFINDER_WINDOW_SIZE)


#define MATCHFINDER_MEM_ALIGNMENT	32


#define MATCHFINDER_SIZE_ALIGNMENT	1024

#undef matchfinder_init
#undef matchfinder_rebase
#ifdef _aligned_attribute
#  define MATCHFINDER_ALIGNED _aligned_attribute(MATCHFINDER_MEM_ALIGNMENT)
#  if defined(ARCH_ARM32) || defined(ARCH_ARM64)
/* #    include "arm/matchfinder_impl.h" */


#ifndef LIB_ARM_MATCHFINDER_IMPL_H
#define LIB_ARM_MATCHFINDER_IMPL_H

/* #include "arm-cpu_features.h" */


#ifndef LIB_ARM_CPU_FEATURES_H
#define LIB_ARM_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_ARM32) || defined(ARCH_ARM64)

#define ARM_CPU_FEATURE_NEON		(1 << 0)
#define ARM_CPU_FEATURE_PMULL		(1 << 1)

#define ARM_CPU_FEATURE_PREFER_PMULL	(1 << 2)
#define ARM_CPU_FEATURE_CRC32		(1 << 3)
#define ARM_CPU_FEATURE_SHA3		(1 << 4)
#define ARM_CPU_FEATURE_DOTPROD		(1 << 5)

#if !defined(FREESTANDING) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
    (defined(__linux__) || \
     (defined(__APPLE__) && defined(ARCH_ARM64)) || \
     (defined(_WIN32) && defined(ARCH_ARM64)))

#  define ARM_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_arm_cpu_features;

void libdeflate_init_arm_cpu_features(void);

static inline u32 get_arm_cpu_features(void)
{
	if (libdeflate_arm_cpu_features == 0)
		libdeflate_init_arm_cpu_features();
	return libdeflate_arm_cpu_features;
}
#else
static inline u32 get_arm_cpu_features(void) { return 0; }
#endif


#if defined(__ARM_NEON) || (defined(_MSC_VER) && defined(ARCH_ARM64))
#  define HAVE_NEON(features)	1
#  define HAVE_NEON_NATIVE	1
#else
#  define HAVE_NEON(features)	((features) & ARM_CPU_FEATURE_NEON)
#  define HAVE_NEON_NATIVE	0
#endif

#if (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
	(HAVE_NEON_NATIVE || (GCC_PREREQ(6, 1) && defined(__ARM_FP)))
#  define HAVE_NEON_INTRIN	1
#  include <arm_neon.h>
#else
#  define HAVE_NEON_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRYPTO
#  define HAVE_PMULL(features)	1
#else
#  define HAVE_PMULL(features)	((features) & ARM_CPU_FEATURE_PMULL)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(7, 1) || defined(__clang__) || defined(_MSC_VER)) && \
	CPU_IS_LITTLE_ENDIAN() 
#  define HAVE_PMULL_INTRIN	1
   
#  ifdef _MSC_VER
#    define compat_vmull_p64(a, b)  vmull_p64(vcreate_p64(a), vcreate_p64(b))
#  else
#    define compat_vmull_p64(a, b)  vmull_p64((a), (b))
#  endif
#else
#  define HAVE_PMULL_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRC32
#  define HAVE_CRC32(features)	1
#else
#  define HAVE_CRC32(features)	((features) & ARM_CPU_FEATURE_CRC32)
#endif
#if defined(ARCH_ARM64) && \
	(defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))
#  define HAVE_CRC32_INTRIN	1
#  if defined(__GNUC__) || defined(__clang__)
#    include <arm_acle.h>
#  endif
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_CRC32)
#    undef __crc32b
#    define __crc32b(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32b %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32h
#    define __crc32h(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32h %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32w
#    define __crc32w(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32w %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32d
#    define __crc32d(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32x %w0, %w1, %2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_CRC32_INTRIN	0
#endif


#ifdef __ARM_FEATURE_SHA3
#  define HAVE_SHA3(features)	1
#else
#  define HAVE_SHA3(features)	((features) & ARM_CPU_FEATURE_SHA3)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(9, 1)  || \
	 CLANG_PREREQ(7, 0, 10010463) )
#  define HAVE_SHA3_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_SHA3)
#    undef veor3q_u8
#    define veor3q_u8(a, b, c)					\
	({ uint8x16_t res;					\
	   __asm__("eor3 %0.16b, %1.16b, %2.16b, %3.16b"	\
		   : "=w" (res) : "w" (a), "w" (b), "w" (c));	\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_SHA3_INTRIN	0
#endif


#ifdef __ARM_FEATURE_DOTPROD
#  define HAVE_DOTPROD(features)	1
#else
#  define HAVE_DOTPROD(features)	((features) & ARM_CPU_FEATURE_DOTPROD)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(8, 1) || CLANG_PREREQ(7, 0, 10010000) || defined(_MSC_VER))
#  define HAVE_DOTPROD_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_DOTPROD)
#    undef vdotq_u32
#    define vdotq_u32(a, b, c)					\
	({ uint32x4_t res = (a);				\
	   __asm__("udot %0.4s, %1.16b, %2.16b"			\
		   : "+w" (res) : "w" (b), "w" (c));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_DOTPROD_INTRIN	0
#endif

#endif 

#endif 


#if HAVE_NEON_NATIVE
static forceinline void
matchfinder_init_neon(mf_pos_t *data, size_t size)
{
	int16x8_t *p = (int16x8_t *)data;
	int16x8_t v = vdupq_n_s16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_neon

static forceinline void
matchfinder_rebase_neon(mf_pos_t *data, size_t size)
{
	int16x8_t *p = (int16x8_t *)data;
	int16x8_t v = vdupq_n_s16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = vqaddq_s16(p[0], v);
		p[1] = vqaddq_s16(p[1], v);
		p[2] = vqaddq_s16(p[2], v);
		p[3] = vqaddq_s16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_neon

#endif 

#endif 

#  elif defined(ARCH_RISCV)
#    include "riscv/matchfinder_impl.h"
#  elif defined(ARCH_X86_32) || defined(ARCH_X86_64)
/* #    include "x86/matchfinder_impl.h" */


#ifndef LIB_X86_MATCHFINDER_IMPL_H
#define LIB_X86_MATCHFINDER_IMPL_H

/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 


#ifdef __AVX2__
static forceinline void
matchfinder_init_avx2(mf_pos_t *data, size_t size)
{
	__m256i *p = (__m256i *)data;
	__m256i v = _mm256_set1_epi16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_avx2

static forceinline void
matchfinder_rebase_avx2(mf_pos_t *data, size_t size)
{
	__m256i *p = (__m256i *)data;
	__m256i v = _mm256_set1_epi16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		
		p[0] = _mm256_adds_epi16(p[0], v);
		p[1] = _mm256_adds_epi16(p[1], v);
		p[2] = _mm256_adds_epi16(p[2], v);
		p[3] = _mm256_adds_epi16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_avx2

#elif HAVE_SSE2_NATIVE
static forceinline void
matchfinder_init_sse2(mf_pos_t *data, size_t size)
{
	__m128i *p = (__m128i *)data;
	__m128i v = _mm_set1_epi16(MATCHFINDER_INITVAL);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		p[0] = v;
		p[1] = v;
		p[2] = v;
		p[3] = v;
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_init matchfinder_init_sse2

static forceinline void
matchfinder_rebase_sse2(mf_pos_t *data, size_t size)
{
	__m128i *p = (__m128i *)data;
	__m128i v = _mm_set1_epi16((u16)-MATCHFINDER_WINDOW_SIZE);

	STATIC_ASSERT(MATCHFINDER_MEM_ALIGNMENT % sizeof(*p) == 0);
	STATIC_ASSERT(MATCHFINDER_SIZE_ALIGNMENT % (4 * sizeof(*p)) == 0);
	STATIC_ASSERT(sizeof(mf_pos_t) == 2);

	do {
		
		p[0] = _mm_adds_epi16(p[0], v);
		p[1] = _mm_adds_epi16(p[1], v);
		p[2] = _mm_adds_epi16(p[2], v);
		p[3] = _mm_adds_epi16(p[3], v);
		p += 4;
		size -= 4 * sizeof(*p);
	} while (size != 0);
}
#define matchfinder_rebase matchfinder_rebase_sse2
#endif 

#endif 

#  endif
#else
#  define MATCHFINDER_ALIGNED
#endif


#ifndef matchfinder_init
static forceinline void
matchfinder_init(mf_pos_t *data, size_t size)
{
	size_t num_entries = size / sizeof(*data);
	size_t i;

	for (i = 0; i < num_entries; i++)
		data[i] = MATCHFINDER_INITVAL;
}
#endif


#ifndef matchfinder_rebase
static forceinline void
matchfinder_rebase(mf_pos_t *data, size_t size)
{
	size_t num_entries = size / sizeof(*data);
	size_t i;

	if (MATCHFINDER_WINDOW_SIZE == 32768) {
		
		for (i = 0; i < num_entries; i++)
			data[i] = 0x8000 | (data[i] & ~(data[i] >> 15));
	} else {
		for (i = 0; i < num_entries; i++) {
			if (data[i] >= 0)
				data[i] -= (mf_pos_t)-MATCHFINDER_WINDOW_SIZE;
			else
				data[i] = (mf_pos_t)-MATCHFINDER_WINDOW_SIZE;
		}
	}
}
#endif


static forceinline u32
lz_hash(u32 seq, unsigned num_bits)
{
	return (u32)(seq * 0x1E35A7BD) >> (32 - num_bits);
}


static forceinline u32
lz_extend(const u8 * const strptr, const u8 * const matchptr,
	  const u32 start_len, const u32 max_len)
{
	u32 len = start_len;
	machine_word_t v_word;

	if (UNALIGNED_ACCESS_IS_FAST) {

		if (likely(max_len - len >= 4 * WORDBYTES)) {

		#define COMPARE_WORD_STEP				\
			v_word = load_word_unaligned(&matchptr[len]) ^	\
				 load_word_unaligned(&strptr[len]);	\
			if (v_word != 0)				\
				goto word_differs;			\
			len += WORDBYTES;				\

			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
			COMPARE_WORD_STEP
		#undef COMPARE_WORD_STEP
		}

		while (len + WORDBYTES <= max_len) {
			v_word = load_word_unaligned(&matchptr[len]) ^
				 load_word_unaligned(&strptr[len]);
			if (v_word != 0)
				goto word_differs;
			len += WORDBYTES;
		}
	}

	while (len < max_len && matchptr[len] == strptr[len])
		len++;
	return len;

word_differs:
	if (CPU_IS_LITTLE_ENDIAN())
		len += (bsfw(v_word) >> 3);
	else
		len += (WORDBITS - 1 - bsrw(v_word)) >> 3;
	return len;
}

#endif 


#define BT_MATCHFINDER_HASH3_ORDER 16
#define BT_MATCHFINDER_HASH3_WAYS  2
#define BT_MATCHFINDER_HASH4_ORDER 16

#define BT_MATCHFINDER_TOTAL_HASH_SIZE		\
	(((1UL << BT_MATCHFINDER_HASH3_ORDER) * BT_MATCHFINDER_HASH3_WAYS + \
	  (1UL << BT_MATCHFINDER_HASH4_ORDER)) * sizeof(mf_pos_t))


struct lz_match {

	
	u16 length;

	
	u16 offset;
};

struct MATCHFINDER_ALIGNED bt_matchfinder {

	
	mf_pos_t hash3_tab[1UL << BT_MATCHFINDER_HASH3_ORDER][BT_MATCHFINDER_HASH3_WAYS];

	
	mf_pos_t hash4_tab[1UL << BT_MATCHFINDER_HASH4_ORDER];

	
	mf_pos_t child_tab[2UL * MATCHFINDER_WINDOW_SIZE];
};


static forceinline void
bt_matchfinder_init(struct bt_matchfinder *mf)
{
	STATIC_ASSERT(BT_MATCHFINDER_TOTAL_HASH_SIZE %
		      MATCHFINDER_SIZE_ALIGNMENT == 0);

	matchfinder_init((mf_pos_t *)mf, BT_MATCHFINDER_TOTAL_HASH_SIZE);
}

static forceinline void
bt_matchfinder_slide_window(struct bt_matchfinder *mf)
{
	STATIC_ASSERT(sizeof(*mf) % MATCHFINDER_SIZE_ALIGNMENT == 0);

	matchfinder_rebase((mf_pos_t *)mf, sizeof(*mf));
}

static forceinline mf_pos_t *
bt_left_child(struct bt_matchfinder *mf, s32 node)
{
	return &mf->child_tab[2 * (node & (MATCHFINDER_WINDOW_SIZE - 1)) + 0];
}

static forceinline mf_pos_t *
bt_right_child(struct bt_matchfinder *mf, s32 node)
{
	return &mf->child_tab[2 * (node & (MATCHFINDER_WINDOW_SIZE - 1)) + 1];
}


#define BT_MATCHFINDER_REQUIRED_NBYTES	5


static forceinline struct lz_match *
bt_matchfinder_advance_one_byte(struct bt_matchfinder * const mf,
				const u8 * const in_base,
				const ptrdiff_t cur_pos,
				const u32 max_len,
				const u32 nice_len,
				const u32 max_search_depth,
				u32 * const next_hashes,
				struct lz_match *lz_matchptr,
				const bool record_matches)
{
	const u8 *in_next = in_base + cur_pos;
	u32 depth_remaining = max_search_depth;
	const s32 cutoff = cur_pos - MATCHFINDER_WINDOW_SIZE;
	u32 next_hashseq;
	u32 hash3;
	u32 hash4;
	s32 cur_node;
#if BT_MATCHFINDER_HASH3_WAYS >= 2
	s32 cur_node_2;
#endif
	const u8 *matchptr;
	mf_pos_t *pending_lt_ptr, *pending_gt_ptr;
	u32 best_lt_len, best_gt_len;
	u32 len;
	u32 best_len = 3;

	STATIC_ASSERT(BT_MATCHFINDER_HASH3_WAYS >= 1 &&
		      BT_MATCHFINDER_HASH3_WAYS <= 2);

	next_hashseq = get_unaligned_le32(in_next + 1);

	hash3 = next_hashes[0];
	hash4 = next_hashes[1];

	next_hashes[0] = lz_hash(next_hashseq & 0xFFFFFF, BT_MATCHFINDER_HASH3_ORDER);
	next_hashes[1] = lz_hash(next_hashseq, BT_MATCHFINDER_HASH4_ORDER);
	prefetchw(&mf->hash3_tab[next_hashes[0]]);
	prefetchw(&mf->hash4_tab[next_hashes[1]]);

	cur_node = mf->hash3_tab[hash3][0];
	mf->hash3_tab[hash3][0] = cur_pos;
#if BT_MATCHFINDER_HASH3_WAYS >= 2
	cur_node_2 = mf->hash3_tab[hash3][1];
	mf->hash3_tab[hash3][1] = cur_node;
#endif
	if (record_matches && cur_node > cutoff) {
		u32 seq3 = load_u24_unaligned(in_next);
		if (seq3 == load_u24_unaligned(&in_base[cur_node])) {
			lz_matchptr->length = 3;
			lz_matchptr->offset = in_next - &in_base[cur_node];
			lz_matchptr++;
		}
	#if BT_MATCHFINDER_HASH3_WAYS >= 2
		else if (cur_node_2 > cutoff &&
			seq3 == load_u24_unaligned(&in_base[cur_node_2]))
		{
			lz_matchptr->length = 3;
			lz_matchptr->offset = in_next - &in_base[cur_node_2];
			lz_matchptr++;
		}
	#endif
	}

	cur_node = mf->hash4_tab[hash4];
	mf->hash4_tab[hash4] = cur_pos;

	pending_lt_ptr = bt_left_child(mf, cur_pos);
	pending_gt_ptr = bt_right_child(mf, cur_pos);

	if (cur_node <= cutoff) {
		*pending_lt_ptr = MATCHFINDER_INITVAL;
		*pending_gt_ptr = MATCHFINDER_INITVAL;
		return lz_matchptr;
	}

	best_lt_len = 0;
	best_gt_len = 0;
	len = 0;

	for (;;) {
		matchptr = &in_base[cur_node];

		if (matchptr[len] == in_next[len]) {
			len = lz_extend(in_next, matchptr, len + 1, max_len);
			if (!record_matches || len > best_len) {
				if (record_matches) {
					best_len = len;
					lz_matchptr->length = len;
					lz_matchptr->offset = in_next - matchptr;
					lz_matchptr++;
				}
				if (len >= nice_len) {
					*pending_lt_ptr = *bt_left_child(mf, cur_node);
					*pending_gt_ptr = *bt_right_child(mf, cur_node);
					return lz_matchptr;
				}
			}
		}

		if (matchptr[len] < in_next[len]) {
			*pending_lt_ptr = cur_node;
			pending_lt_ptr = bt_right_child(mf, cur_node);
			cur_node = *pending_lt_ptr;
			best_lt_len = len;
			if (best_gt_len < len)
				len = best_gt_len;
		} else {
			*pending_gt_ptr = cur_node;
			pending_gt_ptr = bt_left_child(mf, cur_node);
			cur_node = *pending_gt_ptr;
			best_gt_len = len;
			if (best_lt_len < len)
				len = best_lt_len;
		}

		if (cur_node <= cutoff || !--depth_remaining) {
			*pending_lt_ptr = MATCHFINDER_INITVAL;
			*pending_gt_ptr = MATCHFINDER_INITVAL;
			return lz_matchptr;
		}
	}
}


static forceinline struct lz_match *
bt_matchfinder_get_matches(struct bt_matchfinder *mf,
			   const u8 *in_base,
			   ptrdiff_t cur_pos,
			   u32 max_len,
			   u32 nice_len,
			   u32 max_search_depth,
			   u32 next_hashes[2],
			   struct lz_match *lz_matchptr)
{
	return bt_matchfinder_advance_one_byte(mf,
					       in_base,
					       cur_pos,
					       max_len,
					       nice_len,
					       max_search_depth,
					       next_hashes,
					       lz_matchptr,
					       true);
}


static forceinline void
bt_matchfinder_skip_byte(struct bt_matchfinder *mf,
			 const u8 *in_base,
			 ptrdiff_t cur_pos,
			 u32 nice_len,
			 u32 max_search_depth,
			 u32 next_hashes[2])
{
	bt_matchfinder_advance_one_byte(mf,
					in_base,
					cur_pos,
					nice_len,
					nice_len,
					max_search_depth,
					next_hashes,
					NULL,
					false);
}

#endif 


#define MAX_MATCHES_PER_POS	\
	(DEFLATE_MAX_MATCH_LEN - DEFLATE_MIN_MATCH_LEN + 1)
#endif


#define MAX_BLOCK_LENGTH	\
	MAX(SOFT_MAX_BLOCK_LENGTH + MIN_BLOCK_LENGTH - 1,	\
	    SOFT_MAX_BLOCK_LENGTH + 1 + DEFLATE_MAX_MATCH_LEN)

static forceinline void
check_buildtime_parameters(void)
{
	
	STATIC_ASSERT(SOFT_MAX_BLOCK_LENGTH >= MIN_BLOCK_LENGTH);
	STATIC_ASSERT(FAST_SOFT_MAX_BLOCK_LENGTH >= MIN_BLOCK_LENGTH);
	STATIC_ASSERT(SEQ_STORE_LENGTH * DEFLATE_MIN_MATCH_LEN >=
		      MIN_BLOCK_LENGTH);
	STATIC_ASSERT(FAST_SEQ_STORE_LENGTH * HT_MATCHFINDER_MIN_MATCH_LEN >=
		      MIN_BLOCK_LENGTH);
#if SUPPORT_NEAR_OPTIMAL_PARSING
	STATIC_ASSERT(MIN_BLOCK_LENGTH * MAX_MATCHES_PER_POS <=
		      MATCH_CACHE_LENGTH);
#endif

	
	STATIC_ASSERT(FAST_SOFT_MAX_BLOCK_LENGTH <= SOFT_MAX_BLOCK_LENGTH);

	
	STATIC_ASSERT(SEQ_STORE_LENGTH * DEFLATE_MIN_MATCH_LEN <=
		      SOFT_MAX_BLOCK_LENGTH + MIN_BLOCK_LENGTH);
	STATIC_ASSERT(FAST_SEQ_STORE_LENGTH * HT_MATCHFINDER_MIN_MATCH_LEN <=
		      FAST_SOFT_MAX_BLOCK_LENGTH + MIN_BLOCK_LENGTH);

	
	STATIC_ASSERT(
		MAX_LITLEN_CODEWORD_LEN <= DEFLATE_MAX_LITLEN_CODEWORD_LEN);
	STATIC_ASSERT(
		MAX_OFFSET_CODEWORD_LEN <= DEFLATE_MAX_OFFSET_CODEWORD_LEN);
	STATIC_ASSERT(
		MAX_PRE_CODEWORD_LEN <= DEFLATE_MAX_PRE_CODEWORD_LEN);
	STATIC_ASSERT(
		(1U << MAX_LITLEN_CODEWORD_LEN) >= DEFLATE_NUM_LITLEN_SYMS);
	STATIC_ASSERT(
		(1U << MAX_OFFSET_CODEWORD_LEN) >= DEFLATE_NUM_OFFSET_SYMS);
	STATIC_ASSERT(
		(1U << MAX_PRE_CODEWORD_LEN) >= DEFLATE_NUM_PRECODE_SYMS);
}




static const u32 deflate_length_slot_base[] = {
	3,    4,    5,    6,    7,    8,    9,    10,
	11,   13,   15,   17,   19,   23,   27,   31,
	35,   43,   51,   59,   67,   83,   99,   115,
	131,  163,  195,  227,  258,
};


static const u8 deflate_extra_length_bits[] = {
	0,    0,    0,    0,    0,    0,    0,    0,
	1,    1,    1,    1,    2,    2,    2,    2,
	3,    3,    3,    3,    4,    4,    4,    4,
	5,    5,    5,    5,    0,
};


static const u32 deflate_offset_slot_base[] = {
	1,     2,     3,     4,     5,     7,     9,     13,
	17,    25,    33,    49,    65,    97,    129,   193,
	257,   385,   513,   769,   1025,  1537,  2049,  3073,
	4097,  6145,  8193,  12289, 16385, 24577,
};


static const u8 deflate_extra_offset_bits[] = {
	0,     0,     0,     0,     1,     1,     2,     2,
	3,     3,     4,     4,     5,     5,     6,     6,
	7,     7,     8,     8,     9,     9,     10,    10,
	11,    11,    12,    12,    13,    13,
};


static const u8 deflate_length_slot[DEFLATE_MAX_MATCH_LEN + 1] = {
	0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 12,
	12, 13, 13, 13, 13, 14, 14, 14, 14, 15, 15, 15, 15, 16, 16, 16, 16, 16,
	16, 16, 16, 17, 17, 17, 17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18,
	18, 19, 19, 19, 19, 19, 19, 19, 19, 20, 20, 20, 20, 20, 20, 20, 20, 20,
	20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
	21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22,
	22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
	23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
	24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 25, 25, 25,
	25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
	25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 26,
	26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
	26, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
	27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
	27, 27, 28,
};


static const u8 deflate_offset_slot[256] = {
	0, 1, 2, 3, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7,
	8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9,
	10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
	11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
	12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
	12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
	13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
	14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
	14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
	14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
	14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
	15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
	15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
};


static const u8 deflate_precode_lens_permutation[DEFLATE_NUM_PRECODE_SYMS] = {
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
};


static const u8 deflate_extra_precode_bits[DEFLATE_NUM_PRECODE_SYMS] = {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 7
};


struct deflate_codewords {
	u32 litlen[DEFLATE_NUM_LITLEN_SYMS];
	u32 offset[DEFLATE_NUM_OFFSET_SYMS];
};


struct deflate_lens {
	u8 litlen[DEFLATE_NUM_LITLEN_SYMS];
	u8 offset[DEFLATE_NUM_OFFSET_SYMS];
};


struct deflate_codes {
	struct deflate_codewords codewords;
	struct deflate_lens lens;
};


struct deflate_freqs {
	u32 litlen[DEFLATE_NUM_LITLEN_SYMS];
	u32 offset[DEFLATE_NUM_OFFSET_SYMS];
};


struct deflate_sequence {

	
#define SEQ_LENGTH_SHIFT 23
#define SEQ_LITRUNLEN_MASK (((u32)1 << SEQ_LENGTH_SHIFT) - 1)
	u32 litrunlen_and_length;

	
	u16 offset;

	
	u16 offset_slot;
};

#if SUPPORT_NEAR_OPTIMAL_PARSING


struct deflate_costs {

	
	u32 literal[DEFLATE_NUM_LITERALS];

	
	u32 length[DEFLATE_MAX_MATCH_LEN + 1];

	
	u32 offset_slot[DEFLATE_NUM_OFFSET_SYMS];
};


struct deflate_optimum_node {

	u32 cost_to_end;

	
#define OPTIMUM_OFFSET_SHIFT 9
#define OPTIMUM_LEN_MASK (((u32)1 << OPTIMUM_OFFSET_SHIFT) - 1)
	u32 item;

};

#endif 


#define NUM_LITERAL_OBSERVATION_TYPES 8
#define NUM_MATCH_OBSERVATION_TYPES 2
#define NUM_OBSERVATION_TYPES (NUM_LITERAL_OBSERVATION_TYPES + \
			       NUM_MATCH_OBSERVATION_TYPES)
#define NUM_OBSERVATIONS_PER_BLOCK_CHECK 512
struct block_split_stats {
	u32 new_observations[NUM_OBSERVATION_TYPES];
	u32 observations[NUM_OBSERVATION_TYPES];
	u32 num_new_observations;
	u32 num_observations;
};

struct deflate_output_bitstream;


struct libdeflate_compressor {

	
	void (*impl)(struct libdeflate_compressor *restrict c, const u8 *in,
		     size_t in_nbytes, struct deflate_output_bitstream *os);

	
	free_func_t free_func;

	
	unsigned compression_level;

	
	size_t max_passthrough_size;

	
	u32 max_search_depth;

	
	u32 nice_match_length;

	
	struct deflate_freqs freqs;

	
	struct block_split_stats split_stats;

	
	struct deflate_codes codes;

	
	struct deflate_codes static_codes;

	
	union {
		
		struct {
			u32 freqs[DEFLATE_NUM_PRECODE_SYMS];
			u32 codewords[DEFLATE_NUM_PRECODE_SYMS];
			u8 lens[DEFLATE_NUM_PRECODE_SYMS];
			unsigned items[DEFLATE_NUM_LITLEN_SYMS +
				       DEFLATE_NUM_OFFSET_SYMS];
			unsigned num_litlen_syms;
			unsigned num_offset_syms;
			unsigned num_explicit_lens;
			unsigned num_items;
		} precode;
		
		struct {
			u32 codewords[DEFLATE_MAX_MATCH_LEN + 1];
			u8 lens[DEFLATE_MAX_MATCH_LEN + 1];
		} length;
	} o;

	union {
		
		struct {
			
			struct hc_matchfinder hc_mf;

			
			struct deflate_sequence sequences[SEQ_STORE_LENGTH + 1];

		} g; 

		
		struct {
			
			struct ht_matchfinder ht_mf;

			
			struct deflate_sequence sequences[
						FAST_SEQ_STORE_LENGTH + 1];

		} f; 

	#if SUPPORT_NEAR_OPTIMAL_PARSING
		
		struct {

			
			struct bt_matchfinder bt_mf;

			
			struct lz_match match_cache[MATCH_CACHE_LENGTH +
						    MAX_MATCHES_PER_POS +
						    DEFLATE_MAX_MATCH_LEN - 1];

			
			struct deflate_optimum_node optimum_nodes[
				MAX_BLOCK_LENGTH + 1];

			
			struct deflate_costs costs;

			
			struct deflate_costs costs_saved;

			
			u8 offset_slot_full[DEFLATE_MAX_MATCH_OFFSET + 1];

			
			u32 prev_observations[NUM_OBSERVATION_TYPES];
			u32 prev_num_observations;

			
			u32 new_match_len_freqs[DEFLATE_MAX_MATCH_LEN + 1];
			u32 match_len_freqs[DEFLATE_MAX_MATCH_LEN + 1];

			
			unsigned max_optim_passes;

			
			u32 min_improvement_to_continue;

			
			u32 min_bits_to_use_nonfinal_path;

			
			u32 max_len_to_optimize_static_block;

		} n; 
	#endif 

	} p; 
};


typedef machine_word_t bitbuf_t;


#define COMPRESS_BITBUF_NBITS	(8 * sizeof(bitbuf_t) - 1)


#define CAN_BUFFER(n)	(7 + (n) <= COMPRESS_BITBUF_NBITS)


struct deflate_output_bitstream {

	
	bitbuf_t bitbuf;

	
	unsigned bitcount;

	
	u8 *next;

	
	u8 *end;

	
	bool overflow;
};


#define ADD_BITS(bits, n)			\
do {						\
	bitbuf |= (bitbuf_t)(bits) << bitcount;	\
	bitcount += (n);			\
	ASSERT(bitcount <= COMPRESS_BITBUF_NBITS);	\
} while (0)


#define FLUSH_BITS()							\
do {									\
	if (UNALIGNED_ACCESS_IS_FAST && likely(out_next < out_fast_end)) { \
				\
		put_unaligned_leword(bitbuf, out_next);			\
		bitbuf >>= bitcount & ~7;				\
		out_next += bitcount >> 3;				\
		bitcount &= 7;						\
	} else {							\
						\
		while (bitcount >= 8) {					\
			ASSERT(out_next < os->end);			\
			*out_next++ = bitbuf;				\
			bitcount -= 8;					\
			bitbuf >>= 8;					\
		}							\
	}								\
} while (0)


static void
heapify_subtree(u32 A[], unsigned length, unsigned subtree_idx)
{
	unsigned parent_idx;
	unsigned child_idx;
	u32 v;

	v = A[subtree_idx];
	parent_idx = subtree_idx;
	while ((child_idx = parent_idx * 2) <= length) {
		if (child_idx < length && A[child_idx + 1] > A[child_idx])
			child_idx++;
		if (v >= A[child_idx])
			break;
		A[parent_idx] = A[child_idx];
		parent_idx = child_idx;
	}
	A[parent_idx] = v;
}


static void
heapify_array(u32 A[], unsigned length)
{
	unsigned subtree_idx;

	for (subtree_idx = length / 2; subtree_idx >= 1; subtree_idx--)
		heapify_subtree(A, length, subtree_idx);
}


static void
heap_sort(u32 A[], unsigned length)
{
	A--; 

	heapify_array(A, length);

	while (length >= 2) {
		u32 tmp = A[length];

		A[length] = A[1];
		A[1] = tmp;
		length--;
		heapify_subtree(A, length, 1);
	}
}

#define NUM_SYMBOL_BITS 10
#define NUM_FREQ_BITS	(32 - NUM_SYMBOL_BITS)
#define SYMBOL_MASK	((1 << NUM_SYMBOL_BITS) - 1)
#define FREQ_MASK	(~SYMBOL_MASK)

#define GET_NUM_COUNTERS(num_syms)	(num_syms)


static unsigned
sort_symbols(unsigned num_syms, const u32 freqs[], u8 lens[], u32 symout[])
{
	unsigned sym;
	unsigned i;
	unsigned num_used_syms;
	unsigned num_counters;
	unsigned counters[GET_NUM_COUNTERS(DEFLATE_MAX_NUM_SYMS)];

	

	num_counters = GET_NUM_COUNTERS(num_syms);

	memset(counters, 0, num_counters * sizeof(counters[0]));

	
	for (sym = 0; sym < num_syms; sym++)
		counters[MIN(freqs[sym], num_counters - 1)]++;

	
	num_used_syms = 0;
	for (i = 1; i < num_counters; i++) {
		unsigned count = counters[i];

		counters[i] = num_used_syms;
		num_used_syms += count;
	}

	
	for (sym = 0; sym < num_syms; sym++) {
		u32 freq = freqs[sym];

		if (freq != 0) {
			symout[counters[MIN(freq, num_counters - 1)]++] =
				sym | (freq << NUM_SYMBOL_BITS);
		} else {
			lens[sym] = 0;
		}
	}

	
	heap_sort(symout + counters[num_counters - 2],
		  counters[num_counters - 1] - counters[num_counters - 2]);

	return num_used_syms;
}


static void
build_tree(u32 A[], unsigned sym_count)
{
	const unsigned last_idx = sym_count - 1;

	
	unsigned i = 0;

	
	unsigned b = 0;

	
	unsigned e = 0;

	do {
		u32 new_freq;

		
		if (i + 1 <= last_idx &&
		    (b == e || (A[i + 1] & FREQ_MASK) <= (A[b] & FREQ_MASK))) {
			
			new_freq = (A[i] & FREQ_MASK) + (A[i + 1] & FREQ_MASK);
			i += 2;
		} else if (b + 2 <= e &&
			   (i > last_idx ||
			    (A[b + 1] & FREQ_MASK) < (A[i] & FREQ_MASK))) {
			
			new_freq = (A[b] & FREQ_MASK) + (A[b + 1] & FREQ_MASK);
			A[b] = (e << NUM_SYMBOL_BITS) | (A[b] & SYMBOL_MASK);
			A[b + 1] = (e << NUM_SYMBOL_BITS) |
				   (A[b + 1] & SYMBOL_MASK);
			b += 2;
		} else {
			
			new_freq = (A[i] & FREQ_MASK) + (A[b] & FREQ_MASK);
			A[b] = (e << NUM_SYMBOL_BITS) | (A[b] & SYMBOL_MASK);
			i++;
			b++;
		}
		A[e] = new_freq | (A[e] & SYMBOL_MASK);
		
	} while (++e < last_idx);
}


static void
compute_length_counts(u32 A[], unsigned root_idx, unsigned len_counts[],
		      unsigned max_codeword_len)
{
	unsigned len;
	int node;

	

	for (len = 0; len <= max_codeword_len; len++)
		len_counts[len] = 0;
	len_counts[1] = 2;

	
	A[root_idx] &= SYMBOL_MASK;

	for (node = root_idx - 1; node >= 0; node--) {

		

		unsigned parent = A[node] >> NUM_SYMBOL_BITS;
		unsigned parent_depth = A[parent] >> NUM_SYMBOL_BITS;
		unsigned depth = parent_depth + 1;

		
		A[node] = (A[node] & SYMBOL_MASK) | (depth << NUM_SYMBOL_BITS);

		
		if (depth >= max_codeword_len) {
			depth = max_codeword_len;
			do {
				depth--;
			} while (len_counts[depth] == 0);
		}

		
		len_counts[depth]--;
		len_counts[depth + 1] += 2;
	}
}



#ifdef rbit32
static forceinline u32 reverse_codeword(u32 codeword, u8 len)
{
	return rbit32(codeword) >> ((32 - len) & 31);
}
#else

static const u8 bitreverse_tab[256] = {
	0x00, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0,
	0x10, 0x90, 0x50, 0xd0, 0x30, 0xb0, 0x70, 0xf0,
	0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8,
	0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8,
	0x04, 0x84, 0x44, 0xc4, 0x24, 0xa4, 0x64, 0xe4,
	0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4,
	0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec,
	0x1c, 0x9c, 0x5c, 0xdc, 0x3c, 0xbc, 0x7c, 0xfc,
	0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2,
	0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2,
	0x0a, 0x8a, 0x4a, 0xca, 0x2a, 0xaa, 0x6a, 0xea,
	0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa,
	0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6,
	0x16, 0x96, 0x56, 0xd6, 0x36, 0xb6, 0x76, 0xf6,
	0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee,
	0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe,
	0x01, 0x81, 0x41, 0xc1, 0x21, 0xa1, 0x61, 0xe1,
	0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1,
	0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9,
	0x19, 0x99, 0x59, 0xd9, 0x39, 0xb9, 0x79, 0xf9,
	0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5,
	0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5,
	0x0d, 0x8d, 0x4d, 0xcd, 0x2d, 0xad, 0x6d, 0xed,
	0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd,
	0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3,
	0x13, 0x93, 0x53, 0xd3, 0x33, 0xb3, 0x73, 0xf3,
	0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb,
	0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb,
	0x07, 0x87, 0x47, 0xc7, 0x27, 0xa7, 0x67, 0xe7,
	0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7,
	0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef,
	0x1f, 0x9f, 0x5f, 0xdf, 0x3f, 0xbf, 0x7f, 0xff,
};

static forceinline u32 reverse_codeword(u32 codeword, u8 len)
{
	STATIC_ASSERT(DEFLATE_MAX_CODEWORD_LEN <= 16);
	codeword = ((u32)bitreverse_tab[codeword & 0xff] << 8) |
		   bitreverse_tab[codeword >> 8];
	return codeword >> (16 - len);
}
#endif 


static void
gen_codewords(u32 A[], u8 lens[], const unsigned len_counts[],
	      unsigned max_codeword_len, unsigned num_syms)
{
	u32 next_codewords[DEFLATE_MAX_CODEWORD_LEN + 1];
	unsigned i;
	unsigned len;
	unsigned sym;

	
	for (i = 0, len = max_codeword_len; len >= 1; len--) {
		unsigned count = len_counts[len];

		while (count--)
			lens[A[i++] & SYMBOL_MASK] = len;
	}

	
	next_codewords[0] = 0;
	next_codewords[1] = 0;
	for (len = 2; len <= max_codeword_len; len++)
		next_codewords[len] =
			(next_codewords[len - 1] + len_counts[len - 1]) << 1;

	for (sym = 0; sym < num_syms; sym++) {
		
		A[sym] = reverse_codeword(next_codewords[lens[sym]]++,
					  lens[sym]);
	}
}


static void
deflate_make_huffman_code(unsigned num_syms, unsigned max_codeword_len,
			  const u32 freqs[], u8 lens[], u32 codewords[])
{
	u32 *A = codewords;
	unsigned num_used_syms;

	STATIC_ASSERT(DEFLATE_MAX_NUM_SYMS <= 1 << NUM_SYMBOL_BITS);
	STATIC_ASSERT(MAX_BLOCK_LENGTH <= ((u32)1 << NUM_FREQ_BITS) - 1);

	
	num_used_syms = sort_symbols(num_syms, freqs, lens, A);
	

	
	if (unlikely(num_used_syms < 2)) {
		unsigned sym = num_used_syms ? (A[0] & SYMBOL_MASK) : 0;
		unsigned nonzero_idx = sym ? sym : 1;

		codewords[0] = 0;
		lens[0] = 1;
		codewords[nonzero_idx] = 1;
		lens[nonzero_idx] = 1;
		return;
	}

	

	build_tree(A, num_used_syms);

	{
		unsigned len_counts[DEFLATE_MAX_CODEWORD_LEN + 1];

		compute_length_counts(A, num_used_syms - 2,
				      len_counts, max_codeword_len);

		gen_codewords(A, lens, len_counts, max_codeword_len, num_syms);
	}
}


static void
deflate_reset_symbol_frequencies(struct libdeflate_compressor *c)
{
	memset(&c->freqs, 0, sizeof(c->freqs));
}


static void
deflate_make_huffman_codes(const struct deflate_freqs *freqs,
			   struct deflate_codes *codes)
{
	deflate_make_huffman_code(DEFLATE_NUM_LITLEN_SYMS,
				  MAX_LITLEN_CODEWORD_LEN,
				  freqs->litlen,
				  codes->lens.litlen,
				  codes->codewords.litlen);

	deflate_make_huffman_code(DEFLATE_NUM_OFFSET_SYMS,
				  MAX_OFFSET_CODEWORD_LEN,
				  freqs->offset,
				  codes->lens.offset,
				  codes->codewords.offset);
}


static void
deflate_init_static_codes(struct libdeflate_compressor *c)
{
	unsigned i;

	for (i = 0; i < 144; i++)
		c->freqs.litlen[i] = 1 << (9 - 8);
	for (; i < 256; i++)
		c->freqs.litlen[i] = 1 << (9 - 9);
	for (; i < 280; i++)
		c->freqs.litlen[i] = 1 << (9 - 7);
	for (; i < 288; i++)
		c->freqs.litlen[i] = 1 << (9 - 8);

	for (i = 0; i < 32; i++)
		c->freqs.offset[i] = 1 << (5 - 5);

	deflate_make_huffman_codes(&c->freqs, &c->static_codes);
}


static forceinline unsigned
deflate_get_offset_slot(u32 offset)
{
	
	unsigned n = (256 - offset) >> 29;

	ASSERT(offset >= 1 && offset <= 32768);

	return deflate_offset_slot[(offset - 1) >> n] + (n << 1);
}

static unsigned
deflate_compute_precode_items(const u8 lens[], const unsigned num_lens,
			      u32 precode_freqs[], unsigned precode_items[])
{
	unsigned *itemptr;
	unsigned run_start;
	unsigned run_end;
	unsigned extra_bits;
	u8 len;

	memset(precode_freqs, 0,
	       DEFLATE_NUM_PRECODE_SYMS * sizeof(precode_freqs[0]));

	itemptr = precode_items;
	run_start = 0;
	do {
		

		
		len = lens[run_start];

		
		run_end = run_start;
		do {
			run_end++;
		} while (run_end != num_lens && len == lens[run_end]);

		if (len == 0) {
			

			
			while ((run_end - run_start) >= 11) {
				extra_bits = MIN((run_end - run_start) - 11,
						 0x7F);
				precode_freqs[18]++;
				*itemptr++ = 18 | (extra_bits << 5);
				run_start += 11 + extra_bits;
			}

			
			if ((run_end - run_start) >= 3) {
				extra_bits = MIN((run_end - run_start) - 3,
						 0x7);
				precode_freqs[17]++;
				*itemptr++ = 17 | (extra_bits << 5);
				run_start += 3 + extra_bits;
			}
		} else {

			

			
			if ((run_end - run_start) >= 4) {
				precode_freqs[len]++;
				*itemptr++ = len;
				run_start++;
				do {
					extra_bits = MIN((run_end - run_start) -
							 3, 0x3);
					precode_freqs[16]++;
					*itemptr++ = 16 | (extra_bits << 5);
					run_start += 3 + extra_bits;
				} while ((run_end - run_start) >= 3);
			}
		}

		
		while (run_start != run_end) {
			precode_freqs[len]++;
			*itemptr++ = len;
			run_start++;
		}
	} while (run_start != num_lens);

	return itemptr - precode_items;
}




static void
deflate_precompute_huffman_header(struct libdeflate_compressor *c)
{
	

	for (c->o.precode.num_litlen_syms = DEFLATE_NUM_LITLEN_SYMS;
	     c->o.precode.num_litlen_syms > 257;
	     c->o.precode.num_litlen_syms--)
		if (c->codes.lens.litlen[c->o.precode.num_litlen_syms - 1] != 0)
			break;

	for (c->o.precode.num_offset_syms = DEFLATE_NUM_OFFSET_SYMS;
	     c->o.precode.num_offset_syms > 1;
	     c->o.precode.num_offset_syms--)
		if (c->codes.lens.offset[c->o.precode.num_offset_syms - 1] != 0)
			break;

	
	STATIC_ASSERT(offsetof(struct deflate_lens, offset) ==
		      DEFLATE_NUM_LITLEN_SYMS);
	if (c->o.precode.num_litlen_syms != DEFLATE_NUM_LITLEN_SYMS) {
		memmove((u8 *)&c->codes.lens + c->o.precode.num_litlen_syms,
			(u8 *)&c->codes.lens + DEFLATE_NUM_LITLEN_SYMS,
			c->o.precode.num_offset_syms);
	}

	
	c->o.precode.num_items =
		deflate_compute_precode_items((u8 *)&c->codes.lens,
					      c->o.precode.num_litlen_syms +
					      c->o.precode.num_offset_syms,
					      c->o.precode.freqs,
					      c->o.precode.items);

	
	deflate_make_huffman_code(DEFLATE_NUM_PRECODE_SYMS,
				  MAX_PRE_CODEWORD_LEN,
				  c->o.precode.freqs, c->o.precode.lens,
				  c->o.precode.codewords);

	
	for (c->o.precode.num_explicit_lens = DEFLATE_NUM_PRECODE_SYMS;
	     c->o.precode.num_explicit_lens > 4;
	     c->o.precode.num_explicit_lens--)
		if (c->o.precode.lens[deflate_precode_lens_permutation[
				c->o.precode.num_explicit_lens - 1]] != 0)
			break;

	
	if (c->o.precode.num_litlen_syms != DEFLATE_NUM_LITLEN_SYMS) {
		memmove((u8 *)&c->codes.lens + DEFLATE_NUM_LITLEN_SYMS,
			(u8 *)&c->codes.lens + c->o.precode.num_litlen_syms,
			c->o.precode.num_offset_syms);
	}
}


static void
deflate_compute_full_len_codewords(struct libdeflate_compressor *c,
				   const struct deflate_codes *codes)
{
	u32 len;

	STATIC_ASSERT(MAX_LITLEN_CODEWORD_LEN +
		      DEFLATE_MAX_EXTRA_LENGTH_BITS <= 32);

	for (len = DEFLATE_MIN_MATCH_LEN; len <= DEFLATE_MAX_MATCH_LEN; len++) {
		unsigned slot = deflate_length_slot[len];
		unsigned litlen_sym = DEFLATE_FIRST_LEN_SYM + slot;
		u32 extra_bits = len - deflate_length_slot_base[slot];

		c->o.length.codewords[len] =
			codes->codewords.litlen[litlen_sym] |
			(extra_bits << codes->lens.litlen[litlen_sym]);
		c->o.length.lens[len] = codes->lens.litlen[litlen_sym] +
					deflate_extra_length_bits[slot];
	}
}


#define WRITE_MATCH(c_, codes_, length_, offset_, offset_slot_)		\
do {									\
	const struct libdeflate_compressor *c__ = (c_);			\
	const struct deflate_codes *codes__ = (codes_);			\
	u32 length__ = (length_);					\
	u32 offset__ = (offset_);					\
	unsigned offset_slot__ = (offset_slot_);			\
									\
				\
	STATIC_ASSERT(CAN_BUFFER(MAX_LITLEN_CODEWORD_LEN +		\
				 DEFLATE_MAX_EXTRA_LENGTH_BITS));	\
	ADD_BITS(c__->o.length.codewords[length__],			\
		 c__->o.length.lens[length__]);				\
									\
	if (!CAN_BUFFER(MAX_LITLEN_CODEWORD_LEN +			\
			DEFLATE_MAX_EXTRA_LENGTH_BITS +			\
			MAX_OFFSET_CODEWORD_LEN +			\
			DEFLATE_MAX_EXTRA_OFFSET_BITS))			\
		FLUSH_BITS();						\
									\
							\
	ADD_BITS(codes__->codewords.offset[offset_slot__],		\
		 codes__->lens.offset[offset_slot__]);			\
									\
	if (!CAN_BUFFER(MAX_OFFSET_CODEWORD_LEN +			\
			DEFLATE_MAX_EXTRA_OFFSET_BITS))			\
		FLUSH_BITS();						\
									\
							\
	ADD_BITS(offset__ - deflate_offset_slot_base[offset_slot__],	\
		 deflate_extra_offset_bits[offset_slot__]);		\
									\
	FLUSH_BITS();							\
} while (0)


static void
deflate_flush_block(struct libdeflate_compressor *c,
		    struct deflate_output_bitstream *os,
		    const u8 *block_begin, u32 block_length,
		    const struct deflate_sequence *sequences,
		    bool is_final_block)
{
	
	const u8 *in_next = block_begin;
	const u8 * const in_end = block_begin + block_length;
	bitbuf_t bitbuf = os->bitbuf;
	unsigned bitcount = os->bitcount;
	u8 *out_next = os->next;
	u8 * const out_fast_end =
		os->end - MIN(WORDBYTES - 1, os->end - out_next);
	
	u32 dynamic_cost = 3;
	u32 static_cost = 3;
	u32 uncompressed_cost = 3;
	u32 best_cost;
	struct deflate_codes *codes;
	unsigned sym;

	ASSERT(block_length >= MIN_BLOCK_LENGTH ||
	       (is_final_block && block_length > 0));
	ASSERT(block_length <= MAX_BLOCK_LENGTH);
	ASSERT(bitcount <= 7);
	ASSERT((bitbuf & ~(((bitbuf_t)1 << bitcount) - 1)) == 0);
	ASSERT(out_next <= os->end);
	ASSERT(!os->overflow);

	
	deflate_precompute_huffman_header(c);

	
	dynamic_cost += 5 + 5 + 4 + (3 * c->o.precode.num_explicit_lens);
	for (sym = 0; sym < DEFLATE_NUM_PRECODE_SYMS; sym++) {
		u32 extra = deflate_extra_precode_bits[sym];

		dynamic_cost += c->o.precode.freqs[sym] *
				(extra + c->o.precode.lens[sym]);
	}

	
	for (sym = 0; sym < 144; sym++) {
		dynamic_cost += c->freqs.litlen[sym] *
				c->codes.lens.litlen[sym];
		static_cost += c->freqs.litlen[sym] * 8;
	}
	for (; sym < 256; sym++) {
		dynamic_cost += c->freqs.litlen[sym] *
				c->codes.lens.litlen[sym];
		static_cost += c->freqs.litlen[sym] * 9;
	}

	
	dynamic_cost += c->codes.lens.litlen[DEFLATE_END_OF_BLOCK];
	static_cost += 7;

	
	for (sym = DEFLATE_FIRST_LEN_SYM;
	     sym < DEFLATE_FIRST_LEN_SYM + ARRAY_LEN(deflate_extra_length_bits);
	     sym++) {
		u32 extra = deflate_extra_length_bits[
					sym - DEFLATE_FIRST_LEN_SYM];

		dynamic_cost += c->freqs.litlen[sym] *
				(extra + c->codes.lens.litlen[sym]);
		static_cost += c->freqs.litlen[sym] *
				(extra + c->static_codes.lens.litlen[sym]);
	}

	
	for (sym = 0; sym < ARRAY_LEN(deflate_extra_offset_bits); sym++) {
		u32 extra = deflate_extra_offset_bits[sym];

		dynamic_cost += c->freqs.offset[sym] *
				(extra + c->codes.lens.offset[sym]);
		static_cost += c->freqs.offset[sym] * (extra + 5);
	}

	
	uncompressed_cost += (-(bitcount + 3) & 7) + 32 +
			     (40 * (DIV_ROUND_UP(block_length,
						 UINT16_MAX) - 1)) +
			     (8 * block_length);

	

	best_cost = MIN(dynamic_cost, MIN(static_cost, uncompressed_cost));

	
	if (DIV_ROUND_UP(bitcount + best_cost, 8) > os->end - out_next) {
		os->overflow = true;
		return;
	}
	

	if (best_cost == uncompressed_cost) {
		
		do {
			u8 bfinal = 0;
			size_t len = UINT16_MAX;

			if (in_end - in_next <= UINT16_MAX) {
				bfinal = is_final_block;
				len = in_end - in_next;
			}
			
			ASSERT(os->end - out_next >=
			       DIV_ROUND_UP(bitcount + 3, 8) + 4 + len);
			
			STATIC_ASSERT(DEFLATE_BLOCKTYPE_UNCOMPRESSED == 0);
			*out_next++ = (bfinal << bitcount) | bitbuf;
			if (bitcount > 5)
				*out_next++ = 0;
			bitbuf = 0;
			bitcount = 0;
			
			put_unaligned_le16(len, out_next);
			out_next += 2;
			put_unaligned_le16(~len, out_next);
			out_next += 2;
			memcpy(out_next, in_next, len);
			out_next += len;
			in_next += len;
		} while (in_next != in_end);
		
		goto out;
	}

	if (best_cost == static_cost) {
		
		codes = &c->static_codes;
		ADD_BITS(is_final_block, 1);
		ADD_BITS(DEFLATE_BLOCKTYPE_STATIC_HUFFMAN, 2);
		FLUSH_BITS();
	} else {
		const unsigned num_explicit_lens = c->o.precode.num_explicit_lens;
		const unsigned num_precode_items = c->o.precode.num_items;
		unsigned precode_sym, precode_item;
		unsigned i;

		

		codes = &c->codes;
		STATIC_ASSERT(CAN_BUFFER(1 + 2 + 5 + 5 + 4 + 3));
		ADD_BITS(is_final_block, 1);
		ADD_BITS(DEFLATE_BLOCKTYPE_DYNAMIC_HUFFMAN, 2);
		ADD_BITS(c->o.precode.num_litlen_syms - 257, 5);
		ADD_BITS(c->o.precode.num_offset_syms - 1, 5);
		ADD_BITS(num_explicit_lens - 4, 4);

		
		if (CAN_BUFFER(3 * (DEFLATE_NUM_PRECODE_SYMS - 1))) {
			
			precode_sym = deflate_precode_lens_permutation[0];
			ADD_BITS(c->o.precode.lens[precode_sym], 3);
			FLUSH_BITS();
			i = 1; 
			do {
				precode_sym =
					deflate_precode_lens_permutation[i];
				ADD_BITS(c->o.precode.lens[precode_sym], 3);
			} while (++i < num_explicit_lens);
			FLUSH_BITS();
		} else {
			FLUSH_BITS();
			i = 0;
			do {
				precode_sym =
					deflate_precode_lens_permutation[i];
				ADD_BITS(c->o.precode.lens[precode_sym], 3);
				FLUSH_BITS();
			} while (++i < num_explicit_lens);
		}

		
		i = 0;
		do {
			precode_item = c->o.precode.items[i];
			precode_sym = precode_item & 0x1F;
			STATIC_ASSERT(CAN_BUFFER(MAX_PRE_CODEWORD_LEN + 7));
			ADD_BITS(c->o.precode.codewords[precode_sym],
				 c->o.precode.lens[precode_sym]);
			ADD_BITS(precode_item >> 5,
				 deflate_extra_precode_bits[precode_sym]);
			FLUSH_BITS();
		} while (++i < num_precode_items);
	}

	
	ASSERT(bitcount <= 7);
	deflate_compute_full_len_codewords(c, codes);
#if SUPPORT_NEAR_OPTIMAL_PARSING
	if (sequences == NULL) {
		
		struct deflate_optimum_node *cur_node =
			&c->p.n.optimum_nodes[0];
		struct deflate_optimum_node * const end_node =
			&c->p.n.optimum_nodes[block_length];
		do {
			u32 length = cur_node->item & OPTIMUM_LEN_MASK;
			u32 offset = cur_node->item >> OPTIMUM_OFFSET_SHIFT;

			if (length == 1) {
				
				ADD_BITS(codes->codewords.litlen[offset],
					 codes->lens.litlen[offset]);
				FLUSH_BITS();
			} else {
				
				WRITE_MATCH(c, codes, length, offset,
					    c->p.n.offset_slot_full[offset]);
			}
			cur_node += length;
		} while (cur_node != end_node);
	} else
#endif 
	{
		
		const struct deflate_sequence *seq;

		for (seq = sequences; ; seq++) {
			u32 litrunlen = seq->litrunlen_and_length &
					SEQ_LITRUNLEN_MASK;
			u32 length = seq->litrunlen_and_length >>
				     SEQ_LENGTH_SHIFT;
			unsigned lit;

			
			if (CAN_BUFFER(4 * MAX_LITLEN_CODEWORD_LEN)) {
				for (; litrunlen >= 4; litrunlen -= 4) {
					lit = *in_next++;
					ADD_BITS(codes->codewords.litlen[lit],
						 codes->lens.litlen[lit]);
					lit = *in_next++;
					ADD_BITS(codes->codewords.litlen[lit],
						 codes->lens.litlen[lit]);
					lit = *in_next++;
					ADD_BITS(codes->codewords.litlen[lit],
						 codes->lens.litlen[lit]);
					lit = *in_next++;
					ADD_BITS(codes->codewords.litlen[lit],
						 codes->lens.litlen[lit]);
					FLUSH_BITS();
				}
				if (litrunlen-- != 0) {
					lit = *in_next++;
					ADD_BITS(codes->codewords.litlen[lit],
						 codes->lens.litlen[lit]);
					if (litrunlen-- != 0) {
						lit = *in_next++;
						ADD_BITS(codes->codewords.litlen[lit],
							 codes->lens.litlen[lit]);
						if (litrunlen-- != 0) {
							lit = *in_next++;
							ADD_BITS(codes->codewords.litlen[lit],
								 codes->lens.litlen[lit]);
						}
					}
					FLUSH_BITS();
				}
			} else {
				while (litrunlen--) {
					lit = *in_next++;
					ADD_BITS(codes->codewords.litlen[lit],
						 codes->lens.litlen[lit]);
					FLUSH_BITS();
				}
			}

			if (length == 0) { 
				ASSERT(in_next == in_end);
				break;
			}

			
			WRITE_MATCH(c, codes, length, seq->offset,
				    seq->offset_slot);
			in_next += length;
		}
	}

	
	ASSERT(bitcount <= 7);
	ADD_BITS(codes->codewords.litlen[DEFLATE_END_OF_BLOCK],
		 codes->lens.litlen[DEFLATE_END_OF_BLOCK]);
	FLUSH_BITS();
out:
	ASSERT(bitcount <= 7);
	
	ASSERT(8 * (out_next - os->next) + bitcount - os->bitcount == best_cost);
	os->bitbuf = bitbuf;
	os->bitcount = bitcount;
	os->next = out_next;
}

static void
deflate_finish_block(struct libdeflate_compressor *c,
		     struct deflate_output_bitstream *os,
		     const u8 *block_begin, u32 block_length,
		     const struct deflate_sequence *sequences,
		     bool is_final_block)
{
	c->freqs.litlen[DEFLATE_END_OF_BLOCK]++;
	deflate_make_huffman_codes(&c->freqs, &c->codes);
	deflate_flush_block(c, os, block_begin, block_length, sequences,
			    is_final_block);
}






static void
init_block_split_stats(struct block_split_stats *stats)
{
	int i;

	for (i = 0; i < NUM_OBSERVATION_TYPES; i++) {
		stats->new_observations[i] = 0;
		stats->observations[i] = 0;
	}
	stats->num_new_observations = 0;
	stats->num_observations = 0;
}


static forceinline void
observe_literal(struct block_split_stats *stats, u8 lit)
{
	stats->new_observations[((lit >> 5) & 0x6) | (lit & 1)]++;
	stats->num_new_observations++;
}


static forceinline void
observe_match(struct block_split_stats *stats, u32 length)
{
	stats->new_observations[NUM_LITERAL_OBSERVATION_TYPES +
				(length >= 9)]++;
	stats->num_new_observations++;
}

static void
merge_new_observations(struct block_split_stats *stats)
{
	int i;

	for (i = 0; i < NUM_OBSERVATION_TYPES; i++) {
		stats->observations[i] += stats->new_observations[i];
		stats->new_observations[i] = 0;
	}
	stats->num_observations += stats->num_new_observations;
	stats->num_new_observations = 0;
}

static bool
do_end_block_check(struct block_split_stats *stats, u32 block_length)
{
	if (stats->num_observations > 0) {
		
		u32 total_delta = 0;
		u32 num_items;
		u32 cutoff;
		int i;

		for (i = 0; i < NUM_OBSERVATION_TYPES; i++) {
			u32 expected = stats->observations[i] *
				       stats->num_new_observations;
			u32 actual = stats->new_observations[i] *
				     stats->num_observations;
			u32 delta = (actual > expected) ? actual - expected :
							  expected - actual;

			total_delta += delta;
		}

		num_items = stats->num_observations +
			    stats->num_new_observations;
		
		cutoff = stats->num_new_observations * 200 / 512 *
			 stats->num_observations;
		
		if (block_length < 10000 && num_items < 8192)
			cutoff += (u64)cutoff * (8192 - num_items) / 8192;

		
		if (total_delta +
		    (block_length / 4096) * stats->num_observations >= cutoff)
			return true;
	}
	merge_new_observations(stats);
	return false;
}

static forceinline bool
ready_to_check_block(const struct block_split_stats *stats,
		     const u8 *in_block_begin, const u8 *in_next,
		     const u8 *in_end)
{
	return stats->num_new_observations >= NUM_OBSERVATIONS_PER_BLOCK_CHECK
		&& in_next - in_block_begin >= MIN_BLOCK_LENGTH
		&& in_end - in_next >= MIN_BLOCK_LENGTH;
}

static forceinline bool
should_end_block(struct block_split_stats *stats,
		 const u8 *in_block_begin, const u8 *in_next, const u8 *in_end)
{
	
	if (!ready_to_check_block(stats, in_block_begin, in_next, in_end))
		return false;

	return do_end_block_check(stats, in_next - in_block_begin);
}



static void
deflate_begin_sequences(struct libdeflate_compressor *c,
			struct deflate_sequence *first_seq)
{
	deflate_reset_symbol_frequencies(c);
	first_seq->litrunlen_and_length = 0;
}

static forceinline void
deflate_choose_literal(struct libdeflate_compressor *c, unsigned literal,
		       bool gather_split_stats, struct deflate_sequence *seq)
{
	c->freqs.litlen[literal]++;

	if (gather_split_stats)
		observe_literal(&c->split_stats, literal);

	STATIC_ASSERT(MAX_BLOCK_LENGTH <= SEQ_LITRUNLEN_MASK);
	seq->litrunlen_and_length++;
}

static forceinline void
deflate_choose_match(struct libdeflate_compressor *c,
		     u32 length, u32 offset, bool gather_split_stats,
		     struct deflate_sequence **seq_p)
{
	struct deflate_sequence *seq = *seq_p;
	unsigned length_slot = deflate_length_slot[length];
	unsigned offset_slot = deflate_get_offset_slot(offset);

	c->freqs.litlen[DEFLATE_FIRST_LEN_SYM + length_slot]++;
	c->freqs.offset[offset_slot]++;
	if (gather_split_stats)
		observe_match(&c->split_stats, length);

	seq->litrunlen_and_length |= length << SEQ_LENGTH_SHIFT;
	seq->offset = offset;
	seq->offset_slot = offset_slot;

	seq++;
	seq->litrunlen_and_length = 0;
	*seq_p = seq;
}


static forceinline void
adjust_max_and_nice_len(u32 *max_len, u32 *nice_len, size_t remaining)
{
	if (unlikely(remaining < DEFLATE_MAX_MATCH_LEN)) {
		*max_len = remaining;
		*nice_len = MIN(*nice_len, *max_len);
	}
}


static u32
choose_min_match_len(u32 num_used_literals, u32 max_search_depth)
{
	
	static const u8 min_lens[] = {
		9, 9, 9, 9, 9, 9, 8, 8, 7, 7, 6, 6, 6, 6, 6, 6,
		5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
		5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
		
	};
	u32 min_len;

	STATIC_ASSERT(DEFLATE_MIN_MATCH_LEN <= 3);
	STATIC_ASSERT(ARRAY_LEN(min_lens) <= DEFLATE_NUM_LITERALS + 1);

	if (num_used_literals >= ARRAY_LEN(min_lens))
		return 3;
	min_len = min_lens[num_used_literals];
	
	if (max_search_depth < 16) {
		if (max_search_depth < 5)
			min_len = MIN(min_len, 4);
		else if (max_search_depth < 10)
			min_len = MIN(min_len, 5);
		else
			min_len = MIN(min_len, 7);
	}
	return min_len;
}

static u32
calculate_min_match_len(const u8 *data, size_t data_len, u32 max_search_depth)
{
	u8 used[256] = { 0 };
	u32 num_used_literals = 0;
	size_t i;

	
	if (data_len < 512)
		return DEFLATE_MIN_MATCH_LEN;

	
	data_len = MIN(data_len, 4096);
	for (i = 0; i < data_len; i++)
		used[data[i]] = 1;
	for (i = 0; i < 256; i++)
		num_used_literals += used[i];
	return choose_min_match_len(num_used_literals, max_search_depth);
}


static u32
recalculate_min_match_len(const struct deflate_freqs *freqs,
			  u32 max_search_depth)
{
	u32 literal_freq = 0;
	u32 cutoff;
	u32 num_used_literals = 0;
	int i;

	for (i = 0; i < DEFLATE_NUM_LITERALS; i++)
		literal_freq += freqs->litlen[i];

	cutoff = literal_freq >> 10; 

	for (i = 0; i < DEFLATE_NUM_LITERALS; i++) {
		if (freqs->litlen[i] > cutoff)
			num_used_literals++;
	}
	return choose_min_match_len(num_used_literals, max_search_depth);
}

static forceinline const u8 *
choose_max_block_end(const u8 *in_block_begin, const u8 *in_end,
		     size_t soft_max_len)
{
	if (in_end - in_block_begin < soft_max_len + MIN_BLOCK_LENGTH)
		return in_end;
	return in_block_begin + soft_max_len;
}


static size_t
deflate_compress_none(const u8 *in, size_t in_nbytes,
		      u8 *out, size_t out_nbytes_avail)
{
	const u8 *in_next = in;
	const u8 * const in_end = in + in_nbytes;
	u8 *out_next = out;
	u8 * const out_end = out + out_nbytes_avail;

	
	if (unlikely(in_nbytes == 0)) {
		if (out_nbytes_avail < 5)
			return 0;
		
		*out_next++ = 1 | (DEFLATE_BLOCKTYPE_UNCOMPRESSED << 1);
		
		put_unaligned_le32(0xFFFF0000, out_next);
		return 5;
	}

	do {
		u8 bfinal = 0;
		size_t len = UINT16_MAX;

		if (in_end - in_next <= UINT16_MAX) {
			bfinal = 1;
			len = in_end - in_next;
		}
		if (out_end - out_next < 5 + len)
			return 0;
		
		*out_next++ = bfinal | (DEFLATE_BLOCKTYPE_UNCOMPRESSED << 1);

		
		put_unaligned_le16(len, out_next);
		out_next += 2;
		put_unaligned_le16(~len, out_next);
		out_next += 2;
		memcpy(out_next, in_next, len);
		out_next += len;
		in_next += len;
	} while (in_next != in_end);

	return out_next - out;
}


static void
deflate_compress_fastest(struct libdeflate_compressor * restrict c,
			 const u8 *in, size_t in_nbytes,
			 struct deflate_output_bitstream *os)
{
	const u8 *in_next = in;
	const u8 *in_end = in_next + in_nbytes;
	const u8 *in_cur_base = in_next;
	u32 max_len = DEFLATE_MAX_MATCH_LEN;
	u32 nice_len = MIN(c->nice_match_length, max_len);
	u32 next_hash = 0;

	ht_matchfinder_init(&c->p.f.ht_mf);

	do {
		

		const u8 * const in_block_begin = in_next;
		const u8 * const in_max_block_end = choose_max_block_end(
				in_next, in_end, FAST_SOFT_MAX_BLOCK_LENGTH);
		struct deflate_sequence *seq = c->p.f.sequences;

		deflate_begin_sequences(c, seq);

		do {
			u32 length;
			u32 offset;
			size_t remaining = in_end - in_next;

			if (unlikely(remaining < DEFLATE_MAX_MATCH_LEN)) {
				max_len = remaining;
				if (max_len < HT_MATCHFINDER_REQUIRED_NBYTES) {
					do {
						deflate_choose_literal(c,
							*in_next++, false, seq);
					} while (--max_len);
					break;
				}
				nice_len = MIN(nice_len, max_len);
			}
			length = ht_matchfinder_longest_match(&c->p.f.ht_mf,
							      &in_cur_base,
							      in_next,
							      max_len,
							      nice_len,
							      &next_hash,
							      &offset);
			if (length) {
				
				deflate_choose_match(c, length, offset, false,
						     &seq);
				ht_matchfinder_skip_bytes(&c->p.f.ht_mf,
							  &in_cur_base,
							  in_next + 1,
							  in_end,
							  length - 1,
							  &next_hash);
				in_next += length;
			} else {
				
				deflate_choose_literal(c, *in_next++, false,
						       seq);
			}

			
		} while (in_next < in_max_block_end &&
			 seq < &c->p.f.sequences[FAST_SEQ_STORE_LENGTH]);

		deflate_finish_block(c, os, in_block_begin,
				     in_next - in_block_begin,
				     c->p.f.sequences, in_next == in_end);
	} while (in_next != in_end && !os->overflow);
}


static void
deflate_compress_greedy(struct libdeflate_compressor * restrict c,
			const u8 *in, size_t in_nbytes,
			struct deflate_output_bitstream *os)
{
	const u8 *in_next = in;
	const u8 *in_end = in_next + in_nbytes;
	const u8 *in_cur_base = in_next;
	u32 max_len = DEFLATE_MAX_MATCH_LEN;
	u32 nice_len = MIN(c->nice_match_length, max_len);
	u32 next_hashes[2] = {0, 0};

	hc_matchfinder_init(&c->p.g.hc_mf);

	do {
		

		const u8 * const in_block_begin = in_next;
		const u8 * const in_max_block_end = choose_max_block_end(
				in_next, in_end, SOFT_MAX_BLOCK_LENGTH);
		struct deflate_sequence *seq = c->p.g.sequences;
		u32 min_len;

		init_block_split_stats(&c->split_stats);
		deflate_begin_sequences(c, seq);
		min_len = calculate_min_match_len(in_next,
						  in_max_block_end - in_next,
						  c->max_search_depth);
		do {
			u32 length;
			u32 offset;

			adjust_max_and_nice_len(&max_len, &nice_len,
						in_end - in_next);
			length = hc_matchfinder_longest_match(
						&c->p.g.hc_mf,
						&in_cur_base,
						in_next,
						min_len - 1,
						max_len,
						nice_len,
						c->max_search_depth,
						next_hashes,
						&offset);

			if (length >= min_len &&
			    (length > DEFLATE_MIN_MATCH_LEN ||
			     offset <= 4096)) {
				
				deflate_choose_match(c, length, offset, true,
						     &seq);
				hc_matchfinder_skip_bytes(&c->p.g.hc_mf,
							  &in_cur_base,
							  in_next + 1,
							  in_end,
							  length - 1,
							  next_hashes);
				in_next += length;
			} else {
				
				deflate_choose_literal(c, *in_next++, true,
						       seq);
			}

			
		} while (in_next < in_max_block_end &&
			 seq < &c->p.g.sequences[SEQ_STORE_LENGTH] &&
			 !should_end_block(&c->split_stats,
					   in_block_begin, in_next, in_end));

		deflate_finish_block(c, os, in_block_begin,
				     in_next - in_block_begin,
				     c->p.g.sequences, in_next == in_end);
	} while (in_next != in_end && !os->overflow);
}

static forceinline void
deflate_compress_lazy_generic(struct libdeflate_compressor * restrict c,
			      const u8 *in, size_t in_nbytes,
			      struct deflate_output_bitstream *os, bool lazy2)
{
	const u8 *in_next = in;
	const u8 *in_end = in_next + in_nbytes;
	const u8 *in_cur_base = in_next;
	u32 max_len = DEFLATE_MAX_MATCH_LEN;
	u32 nice_len = MIN(c->nice_match_length, max_len);
	u32 next_hashes[2] = {0, 0};

	hc_matchfinder_init(&c->p.g.hc_mf);

	do {
		

		const u8 * const in_block_begin = in_next;
		const u8 * const in_max_block_end = choose_max_block_end(
				in_next, in_end, SOFT_MAX_BLOCK_LENGTH);
		const u8 *next_recalc_min_len =
			in_next + MIN(in_end - in_next, 10000);
		struct deflate_sequence *seq = c->p.g.sequences;
		u32 min_len;

		init_block_split_stats(&c->split_stats);
		deflate_begin_sequences(c, seq);
		min_len = calculate_min_match_len(in_next,
						  in_max_block_end - in_next,
						  c->max_search_depth);
		do {
			u32 cur_len;
			u32 cur_offset;
			u32 next_len;
			u32 next_offset;

			
			if (in_next >= next_recalc_min_len) {
				min_len = recalculate_min_match_len(
						&c->freqs,
						c->max_search_depth);
				next_recalc_min_len +=
					MIN(in_end - next_recalc_min_len,
					    in_next - in_block_begin);
			}

			
			adjust_max_and_nice_len(&max_len, &nice_len,
						in_end - in_next);
			cur_len = hc_matchfinder_longest_match(
						&c->p.g.hc_mf,
						&in_cur_base,
						in_next,
						min_len - 1,
						max_len,
						nice_len,
						c->max_search_depth,
						next_hashes,
						&cur_offset);
			if (cur_len < min_len ||
			    (cur_len == DEFLATE_MIN_MATCH_LEN &&
			     cur_offset > 8192)) {
				
				deflate_choose_literal(c, *in_next++, true,
						       seq);
				continue;
			}
			in_next++;

have_cur_match:
			
			if (cur_len >= nice_len) {
				deflate_choose_match(c, cur_len, cur_offset,
						     true, &seq);
				hc_matchfinder_skip_bytes(&c->p.g.hc_mf,
							  &in_cur_base,
							  in_next,
							  in_end,
							  cur_len - 1,
							  next_hashes);
				in_next += cur_len - 1;
				continue;
			}

			
			adjust_max_and_nice_len(&max_len, &nice_len,
						in_end - in_next);
			next_len = hc_matchfinder_longest_match(
						&c->p.g.hc_mf,
						&in_cur_base,
						in_next++,
						cur_len - 1,
						max_len,
						nice_len,
						c->max_search_depth >> 1,
						next_hashes,
						&next_offset);
			if (next_len >= cur_len &&
			    4 * (int)(next_len - cur_len) +
			    ((int)bsr32(cur_offset) -
			     (int)bsr32(next_offset)) > 2) {
				
				deflate_choose_literal(c, *(in_next - 2), true,
						       seq);
				cur_len = next_len;
				cur_offset = next_offset;
				goto have_cur_match;
			}

			if (lazy2) {
				
				adjust_max_and_nice_len(&max_len, &nice_len,
							in_end - in_next);
				next_len = hc_matchfinder_longest_match(
						&c->p.g.hc_mf,
						&in_cur_base,
						in_next++,
						cur_len - 1,
						max_len,
						nice_len,
						c->max_search_depth >> 2,
						next_hashes,
						&next_offset);
				if (next_len >= cur_len &&
				    4 * (int)(next_len - cur_len) +
				    ((int)bsr32(cur_offset) -
				     (int)bsr32(next_offset)) > 6) {
					
					deflate_choose_literal(
						c, *(in_next - 3), true, seq);
					deflate_choose_literal(
						c, *(in_next - 2), true, seq);
					cur_len = next_len;
					cur_offset = next_offset;
					goto have_cur_match;
				}
				
				deflate_choose_match(c, cur_len, cur_offset,
						     true, &seq);
				if (cur_len > 3) {
					hc_matchfinder_skip_bytes(&c->p.g.hc_mf,
								  &in_cur_base,
								  in_next,
								  in_end,
								  cur_len - 3,
								  next_hashes);
					in_next += cur_len - 3;
				}
			} else { 
				
				deflate_choose_match(c, cur_len, cur_offset,
						     true, &seq);
				hc_matchfinder_skip_bytes(&c->p.g.hc_mf,
							  &in_cur_base,
							  in_next,
							  in_end,
							  cur_len - 2,
							  next_hashes);
				in_next += cur_len - 2;
			}
			
		} while (in_next < in_max_block_end &&
			 seq < &c->p.g.sequences[SEQ_STORE_LENGTH] &&
			 !should_end_block(&c->split_stats,
					   in_block_begin, in_next, in_end));

		deflate_finish_block(c, os, in_block_begin,
				     in_next - in_block_begin,
				     c->p.g.sequences, in_next == in_end);
	} while (in_next != in_end && !os->overflow);
}


static void
deflate_compress_lazy(struct libdeflate_compressor * restrict c,
		      const u8 *in, size_t in_nbytes,
		      struct deflate_output_bitstream *os)
{
	deflate_compress_lazy_generic(c, in, in_nbytes, os, false);
}


static void
deflate_compress_lazy2(struct libdeflate_compressor * restrict c,
		       const u8 *in, size_t in_nbytes,
		       struct deflate_output_bitstream *os)
{
	deflate_compress_lazy_generic(c, in, in_nbytes, os, true);
}

#if SUPPORT_NEAR_OPTIMAL_PARSING


static void
deflate_tally_item_list(struct libdeflate_compressor *c, u32 block_length)
{
	struct deflate_optimum_node *cur_node = &c->p.n.optimum_nodes[0];
	struct deflate_optimum_node *end_node =
		&c->p.n.optimum_nodes[block_length];

	do {
		u32 length = cur_node->item & OPTIMUM_LEN_MASK;
		u32 offset = cur_node->item >> OPTIMUM_OFFSET_SHIFT;

		if (length == 1) {
			
			c->freqs.litlen[offset]++;
		} else {
			
			c->freqs.litlen[DEFLATE_FIRST_LEN_SYM +
					deflate_length_slot[length]]++;
			c->freqs.offset[c->p.n.offset_slot_full[offset]]++;
		}
		cur_node += length;
	} while (cur_node != end_node);

	
	c->freqs.litlen[DEFLATE_END_OF_BLOCK]++;
}

static void
deflate_choose_all_literals(struct libdeflate_compressor *c,
			    const u8 *block, u32 block_length)
{
	u32 i;

	deflate_reset_symbol_frequencies(c);
	for (i = 0; i < block_length; i++)
		c->freqs.litlen[block[i]]++;
	c->freqs.litlen[DEFLATE_END_OF_BLOCK]++;

	deflate_make_huffman_codes(&c->freqs, &c->codes);
}


static u32
deflate_compute_true_cost(struct libdeflate_compressor *c)
{
	u32 cost = 0;
	unsigned sym;

	deflate_precompute_huffman_header(c);

	memset(&c->codes.lens.litlen[c->o.precode.num_litlen_syms], 0,
	       DEFLATE_NUM_LITLEN_SYMS - c->o.precode.num_litlen_syms);

	cost += 5 + 5 + 4 + (3 * c->o.precode.num_explicit_lens);
	for (sym = 0; sym < DEFLATE_NUM_PRECODE_SYMS; sym++) {
		cost += c->o.precode.freqs[sym] *
			(c->o.precode.lens[sym] +
			 deflate_extra_precode_bits[sym]);
	}

	for (sym = 0; sym < DEFLATE_FIRST_LEN_SYM; sym++)
		cost += c->freqs.litlen[sym] * c->codes.lens.litlen[sym];

	for (; sym < DEFLATE_FIRST_LEN_SYM +
	       ARRAY_LEN(deflate_extra_length_bits); sym++)
		cost += c->freqs.litlen[sym] *
			(c->codes.lens.litlen[sym] +
			 deflate_extra_length_bits[sym - DEFLATE_FIRST_LEN_SYM]);

	for (sym = 0; sym < ARRAY_LEN(deflate_extra_offset_bits); sym++)
		cost += c->freqs.offset[sym] *
			(c->codes.lens.offset[sym] +
			 deflate_extra_offset_bits[sym]);
	return cost;
}


static void
deflate_set_costs_from_codes(struct libdeflate_compressor *c,
			     const struct deflate_lens *lens)
{
	unsigned i;

	
	for (i = 0; i < DEFLATE_NUM_LITERALS; i++) {
		u32 bits = (lens->litlen[i] ?
			    lens->litlen[i] : LITERAL_NOSTAT_BITS);

		c->p.n.costs.literal[i] = bits * BIT_COST;
	}

	
	for (i = DEFLATE_MIN_MATCH_LEN; i <= DEFLATE_MAX_MATCH_LEN; i++) {
		unsigned length_slot = deflate_length_slot[i];
		unsigned litlen_sym = DEFLATE_FIRST_LEN_SYM + length_slot;
		u32 bits = (lens->litlen[litlen_sym] ?
			    lens->litlen[litlen_sym] : LENGTH_NOSTAT_BITS);

		bits += deflate_extra_length_bits[length_slot];
		c->p.n.costs.length[i] = bits * BIT_COST;
	}

	
	for (i = 0; i < ARRAY_LEN(deflate_offset_slot_base); i++) {
		u32 bits = (lens->offset[i] ?
			    lens->offset[i] : OFFSET_NOSTAT_BITS);

		bits += deflate_extra_offset_bits[i];
		c->p.n.costs.offset_slot[i] = bits * BIT_COST;
	}
}


static const struct {
	u8 used_lits_to_lit_cost[257];
	u8 len_sym_cost;
} default_litlen_costs[] = {
	{ 
		.used_lits_to_lit_cost = {
			6, 6, 22, 32, 38, 43, 48, 51,
			54, 57, 59, 61, 64, 65, 67, 69,
			70, 72, 73, 74, 75, 76, 77, 79,
			80, 80, 81, 82, 83, 84, 85, 85,
			86, 87, 88, 88, 89, 89, 90, 91,
			91, 92, 92, 93, 93, 94, 95, 95,
			96, 96, 96, 97, 97, 98, 98, 99,
			99, 99, 100, 100, 101, 101, 101, 102,
			102, 102, 103, 103, 104, 104, 104, 105,
			105, 105, 105, 106, 106, 106, 107, 107,
			107, 108, 108, 108, 108, 109, 109, 109,
			109, 110, 110, 110, 111, 111, 111, 111,
			112, 112, 112, 112, 112, 113, 113, 113,
			113, 114, 114, 114, 114, 114, 115, 115,
			115, 115, 115, 116, 116, 116, 116, 116,
			117, 117, 117, 117, 117, 118, 118, 118,
			118, 118, 118, 119, 119, 119, 119, 119,
			120, 120, 120, 120, 120, 120, 121, 121,
			121, 121, 121, 121, 121, 122, 122, 122,
			122, 122, 122, 123, 123, 123, 123, 123,
			123, 123, 124, 124, 124, 124, 124, 124,
			124, 125, 125, 125, 125, 125, 125, 125,
			125, 126, 126, 126, 126, 126, 126, 126,
			127, 127, 127, 127, 127, 127, 127, 127,
			128, 128, 128, 128, 128, 128, 128, 128,
			128, 129, 129, 129, 129, 129, 129, 129,
			129, 129, 130, 130, 130, 130, 130, 130,
			130, 130, 130, 131, 131, 131, 131, 131,
			131, 131, 131, 131, 131, 132, 132, 132,
			132, 132, 132, 132, 132, 132, 132, 133,
			133, 133, 133, 133, 133, 133, 133, 133,
			133, 134, 134, 134, 134, 134, 134, 134,
			134,
		},
		.len_sym_cost = 109,
	}, { 
		.used_lits_to_lit_cost = {
			16, 16, 32, 41, 48, 53, 57, 60,
			64, 66, 69, 71, 73, 75, 76, 78,
			80, 81, 82, 83, 85, 86, 87, 88,
			89, 90, 91, 92, 92, 93, 94, 95,
			96, 96, 97, 98, 98, 99, 99, 100,
			101, 101, 102, 102, 103, 103, 104, 104,
			105, 105, 106, 106, 107, 107, 108, 108,
			108, 109, 109, 110, 110, 110, 111, 111,
			112, 112, 112, 113, 113, 113, 114, 114,
			114, 115, 115, 115, 115, 116, 116, 116,
			117, 117, 117, 118, 118, 118, 118, 119,
			119, 119, 119, 120, 120, 120, 120, 121,
			121, 121, 121, 122, 122, 122, 122, 122,
			123, 123, 123, 123, 124, 124, 124, 124,
			124, 125, 125, 125, 125, 125, 126, 126,
			126, 126, 126, 127, 127, 127, 127, 127,
			128, 128, 128, 128, 128, 128, 129, 129,
			129, 129, 129, 129, 130, 130, 130, 130,
			130, 130, 131, 131, 131, 131, 131, 131,
			131, 132, 132, 132, 132, 132, 132, 133,
			133, 133, 133, 133, 133, 133, 134, 134,
			134, 134, 134, 134, 134, 134, 135, 135,
			135, 135, 135, 135, 135, 135, 136, 136,
			136, 136, 136, 136, 136, 136, 137, 137,
			137, 137, 137, 137, 137, 137, 138, 138,
			138, 138, 138, 138, 138, 138, 138, 139,
			139, 139, 139, 139, 139, 139, 139, 139,
			140, 140, 140, 140, 140, 140, 140, 140,
			140, 141, 141, 141, 141, 141, 141, 141,
			141, 141, 141, 142, 142, 142, 142, 142,
			142, 142, 142, 142, 142, 142, 143, 143,
			143, 143, 143, 143, 143, 143, 143, 143,
			144,
		},
		.len_sym_cost = 93,
	}, { 
		.used_lits_to_lit_cost = {
			32, 32, 48, 57, 64, 69, 73, 76,
			80, 82, 85, 87, 89, 91, 92, 94,
			96, 97, 98, 99, 101, 102, 103, 104,
			105, 106, 107, 108, 108, 109, 110, 111,
			112, 112, 113, 114, 114, 115, 115, 116,
			117, 117, 118, 118, 119, 119, 120, 120,
			121, 121, 122, 122, 123, 123, 124, 124,
			124, 125, 125, 126, 126, 126, 127, 127,
			128, 128, 128, 129, 129, 129, 130, 130,
			130, 131, 131, 131, 131, 132, 132, 132,
			133, 133, 133, 134, 134, 134, 134, 135,
			135, 135, 135, 136, 136, 136, 136, 137,
			137, 137, 137, 138, 138, 138, 138, 138,
			139, 139, 139, 139, 140, 140, 140, 140,
			140, 141, 141, 141, 141, 141, 142, 142,
			142, 142, 142, 143, 143, 143, 143, 143,
			144, 144, 144, 144, 144, 144, 145, 145,
			145, 145, 145, 145, 146, 146, 146, 146,
			146, 146, 147, 147, 147, 147, 147, 147,
			147, 148, 148, 148, 148, 148, 148, 149,
			149, 149, 149, 149, 149, 149, 150, 150,
			150, 150, 150, 150, 150, 150, 151, 151,
			151, 151, 151, 151, 151, 151, 152, 152,
			152, 152, 152, 152, 152, 152, 153, 153,
			153, 153, 153, 153, 153, 153, 154, 154,
			154, 154, 154, 154, 154, 154, 154, 155,
			155, 155, 155, 155, 155, 155, 155, 155,
			156, 156, 156, 156, 156, 156, 156, 156,
			156, 157, 157, 157, 157, 157, 157, 157,
			157, 157, 157, 158, 158, 158, 158, 158,
			158, 158, 158, 158, 158, 158, 159, 159,
			159, 159, 159, 159, 159, 159, 159, 159,
			160,
		},
		.len_sym_cost = 84,
	},
};


static void
deflate_choose_default_litlen_costs(struct libdeflate_compressor *c,
				    const u8 *block_begin, u32 block_length,
				    u32 *lit_cost, u32 *len_sym_cost)
{
	u32 num_used_literals = 0;
	u32 literal_freq = block_length;
	u32 match_freq = 0;
	u32 cutoff;
	u32 i;

	
	memset(c->freqs.litlen, 0,
	       DEFLATE_NUM_LITERALS * sizeof(c->freqs.litlen[0]));
	cutoff = literal_freq >> 11; 
	for (i = 0; i < block_length; i++)
		c->freqs.litlen[block_begin[i]]++;
	for (i = 0; i < DEFLATE_NUM_LITERALS; i++) {
		if (c->freqs.litlen[i] > cutoff)
			num_used_literals++;
	}
	if (num_used_literals == 0)
		num_used_literals = 1;

	
	match_freq = 0;
	i = choose_min_match_len(num_used_literals, c->max_search_depth);
	for (; i < ARRAY_LEN(c->p.n.match_len_freqs); i++) {
		match_freq += c->p.n.match_len_freqs[i];
		literal_freq -= i * c->p.n.match_len_freqs[i];
	}
	if ((s32)literal_freq < 0) 
		literal_freq = 0;

	if (match_freq > literal_freq)
		i = 2; 
	else if (match_freq * 4 > literal_freq)
		i = 1; 
	else
		i = 0; 

	STATIC_ASSERT(BIT_COST == 16);
	*lit_cost = default_litlen_costs[i].used_lits_to_lit_cost[
							num_used_literals];
	*len_sym_cost = default_litlen_costs[i].len_sym_cost;
}

static forceinline u32
deflate_default_length_cost(u32 len, u32 len_sym_cost)
{
	unsigned slot = deflate_length_slot[len];
	u32 num_extra_bits = deflate_extra_length_bits[slot];

	return len_sym_cost + (num_extra_bits * BIT_COST);
}

static forceinline u32
deflate_default_offset_slot_cost(unsigned slot)
{
	u32 num_extra_bits = deflate_extra_offset_bits[slot];
	
	u32 offset_sym_cost = 4*BIT_COST + (907*BIT_COST)/1000;

	return offset_sym_cost + (num_extra_bits * BIT_COST);
}


static void
deflate_set_default_costs(struct libdeflate_compressor *c,
			  u32 lit_cost, u32 len_sym_cost)
{
	u32 i;

	
	for (i = 0; i < DEFLATE_NUM_LITERALS; i++)
		c->p.n.costs.literal[i] = lit_cost;

	
	for (i = DEFLATE_MIN_MATCH_LEN; i <= DEFLATE_MAX_MATCH_LEN; i++)
		c->p.n.costs.length[i] =
			deflate_default_length_cost(i, len_sym_cost);

	
	for (i = 0; i < ARRAY_LEN(deflate_offset_slot_base); i++)
		c->p.n.costs.offset_slot[i] =
			deflate_default_offset_slot_cost(i);
}

static forceinline void
deflate_adjust_cost(u32 *cost_p, u32 default_cost, int change_amount)
{
	if (change_amount == 0)
		
		*cost_p = (default_cost + 3 * *cost_p) / 4;
	else if (change_amount == 1)
		*cost_p = (default_cost + *cost_p) / 2;
	else if (change_amount == 2)
		*cost_p = (5 * default_cost + 3 * *cost_p) / 8;
	else
		
		*cost_p = (3 * default_cost + *cost_p) / 4;
}

static forceinline void
deflate_adjust_costs_impl(struct libdeflate_compressor *c,
			  u32 lit_cost, u32 len_sym_cost, int change_amount)
{
	u32 i;

	
	for (i = 0; i < DEFLATE_NUM_LITERALS; i++)
		deflate_adjust_cost(&c->p.n.costs.literal[i], lit_cost,
				    change_amount);

	
	for (i = DEFLATE_MIN_MATCH_LEN; i <= DEFLATE_MAX_MATCH_LEN; i++)
		deflate_adjust_cost(&c->p.n.costs.length[i],
				    deflate_default_length_cost(i,
								len_sym_cost),
				    change_amount);

	
	for (i = 0; i < ARRAY_LEN(deflate_offset_slot_base); i++)
		deflate_adjust_cost(&c->p.n.costs.offset_slot[i],
				    deflate_default_offset_slot_cost(i),
				    change_amount);
}


static void
deflate_adjust_costs(struct libdeflate_compressor *c,
		     u32 lit_cost, u32 len_sym_cost)
{
	u64 total_delta = 0;
	u64 cutoff;
	int i;

	
	for (i = 0; i < NUM_OBSERVATION_TYPES; i++) {
		u64 prev = (u64)c->p.n.prev_observations[i] *
			    c->split_stats.num_observations;
		u64 cur = (u64)c->split_stats.observations[i] *
			  c->p.n.prev_num_observations;

		total_delta += prev > cur ? prev - cur : cur - prev;
	}
	cutoff = ((u64)c->p.n.prev_num_observations *
		  c->split_stats.num_observations * 200) / 512;

	if (total_delta > 3 * cutoff)
		
		deflate_set_default_costs(c, lit_cost, len_sym_cost);
	else if (4 * total_delta > 9 * cutoff)
		deflate_adjust_costs_impl(c, lit_cost, len_sym_cost, 3);
	else if (2 * total_delta > 3 * cutoff)
		deflate_adjust_costs_impl(c, lit_cost, len_sym_cost, 2);
	else if (2 * total_delta > cutoff)
		deflate_adjust_costs_impl(c, lit_cost, len_sym_cost, 1);
	else
		deflate_adjust_costs_impl(c, lit_cost, len_sym_cost, 0);
}

static void
deflate_set_initial_costs(struct libdeflate_compressor *c,
			  const u8 *block_begin, u32 block_length,
			  bool is_first_block)
{
	u32 lit_cost, len_sym_cost;

	deflate_choose_default_litlen_costs(c, block_begin, block_length,
					    &lit_cost, &len_sym_cost);
	if (is_first_block)
		deflate_set_default_costs(c, lit_cost, len_sym_cost);
	else
		deflate_adjust_costs(c, lit_cost, len_sym_cost);
}


static void
deflate_find_min_cost_path(struct libdeflate_compressor *c,
			   const u32 block_length,
			   const struct lz_match *cache_ptr)
{
	struct deflate_optimum_node *end_node =
		&c->p.n.optimum_nodes[block_length];
	struct deflate_optimum_node *cur_node = end_node;

	cur_node->cost_to_end = 0;
	do {
		unsigned num_matches;
		u32 literal;
		u32 best_cost_to_end;

		cur_node--;
		cache_ptr--;

		num_matches = cache_ptr->length;
		literal = cache_ptr->offset;

		
		best_cost_to_end = c->p.n.costs.literal[literal] +
				   (cur_node + 1)->cost_to_end;
		cur_node->item = (literal << OPTIMUM_OFFSET_SHIFT) | 1;

		
		if (num_matches) {
			const struct lz_match *match;
			u32 len;
			u32 offset;
			u32 offset_slot;
			u32 offset_cost;
			u32 cost_to_end;

			
			match = cache_ptr - num_matches;
			len = DEFLATE_MIN_MATCH_LEN;
			do {
				offset = match->offset;
				offset_slot = c->p.n.offset_slot_full[offset];
				offset_cost =
					c->p.n.costs.offset_slot[offset_slot];
				do {
					cost_to_end = offset_cost +
						c->p.n.costs.length[len] +
						(cur_node + len)->cost_to_end;
					if (cost_to_end < best_cost_to_end) {
						best_cost_to_end = cost_to_end;
						cur_node->item = len |
							(offset <<
							 OPTIMUM_OFFSET_SHIFT);
					}
				} while (++len <= match->length);
			} while (++match != cache_ptr);
			cache_ptr -= num_matches;
		}
		cur_node->cost_to_end = best_cost_to_end;
	} while (cur_node != &c->p.n.optimum_nodes[0]);

	deflate_reset_symbol_frequencies(c);
	deflate_tally_item_list(c, block_length);
	deflate_make_huffman_codes(&c->freqs, &c->codes);
}


static void
deflate_optimize_and_flush_block(struct libdeflate_compressor *c,
				 struct deflate_output_bitstream *os,
				 const u8 *block_begin, u32 block_length,
				 const struct lz_match *cache_ptr,
				 bool is_first_block, bool is_final_block,
				 bool *used_only_literals)
{
	unsigned num_passes_remaining = c->p.n.max_optim_passes;
	u32 best_true_cost = UINT32_MAX;
	u32 true_cost;
	u32 only_lits_cost;
	u32 static_cost = UINT32_MAX;
	struct deflate_sequence seq_;
	struct deflate_sequence *seq = NULL;
	u32 i;

	
	deflate_choose_all_literals(c, block_begin, block_length);
	only_lits_cost = deflate_compute_true_cost(c);

	
	for (i = block_length;
	     i <= MIN(block_length - 1 + DEFLATE_MAX_MATCH_LEN,
		      ARRAY_LEN(c->p.n.optimum_nodes) - 1); i++)
		c->p.n.optimum_nodes[i].cost_to_end = 0x80000000;

	
	if (block_length <= c->p.n.max_len_to_optimize_static_block) {
		
		c->p.n.costs_saved = c->p.n.costs;

		deflate_set_costs_from_codes(c, &c->static_codes.lens);
		deflate_find_min_cost_path(c, block_length, cache_ptr);
		static_cost = c->p.n.optimum_nodes[0].cost_to_end / BIT_COST;
		static_cost += 7; 

		
		c->p.n.costs = c->p.n.costs_saved;
	}

	
	deflate_set_initial_costs(c, block_begin, block_length, is_first_block);

	do {
		
		deflate_find_min_cost_path(c, block_length, cache_ptr);

		
		true_cost = deflate_compute_true_cost(c);

		
		if (true_cost + c->p.n.min_improvement_to_continue >
		    best_true_cost)
			break;

		best_true_cost = true_cost;

		
		c->p.n.costs_saved = c->p.n.costs;

		
		deflate_set_costs_from_codes(c, &c->codes.lens);

	} while (--num_passes_remaining);

	*used_only_literals = false;
	if (MIN(only_lits_cost, static_cost) < best_true_cost) {
		if (only_lits_cost < static_cost) {
			
			deflate_choose_all_literals(c, block_begin, block_length);
			deflate_set_costs_from_codes(c, &c->codes.lens);
			seq_.litrunlen_and_length = block_length;
			seq = &seq_;
			*used_only_literals = true;
		} else {
			
			deflate_set_costs_from_codes(c, &c->static_codes.lens);
			deflate_find_min_cost_path(c, block_length, cache_ptr);
		}
	} else if (true_cost >=
		   best_true_cost + c->p.n.min_bits_to_use_nonfinal_path) {
		
		c->p.n.costs = c->p.n.costs_saved;
		deflate_find_min_cost_path(c, block_length, cache_ptr);
		deflate_set_costs_from_codes(c, &c->codes.lens);
	}
	deflate_flush_block(c, os, block_begin, block_length, seq,
			    is_final_block);
}

static void
deflate_near_optimal_init_stats(struct libdeflate_compressor *c)
{
	init_block_split_stats(&c->split_stats);
	memset(c->p.n.new_match_len_freqs, 0,
	       sizeof(c->p.n.new_match_len_freqs));
	memset(c->p.n.match_len_freqs, 0, sizeof(c->p.n.match_len_freqs));
}

static void
deflate_near_optimal_merge_stats(struct libdeflate_compressor *c)
{
	unsigned i;

	merge_new_observations(&c->split_stats);
	for (i = 0; i < ARRAY_LEN(c->p.n.match_len_freqs); i++) {
		c->p.n.match_len_freqs[i] += c->p.n.new_match_len_freqs[i];
		c->p.n.new_match_len_freqs[i] = 0;
	}
}


static void
deflate_near_optimal_save_stats(struct libdeflate_compressor *c)
{
	int i;

	for (i = 0; i < NUM_OBSERVATION_TYPES; i++)
		c->p.n.prev_observations[i] = c->split_stats.observations[i];
	c->p.n.prev_num_observations = c->split_stats.num_observations;
}

static void
deflate_near_optimal_clear_old_stats(struct libdeflate_compressor *c)
{
	int i;

	for (i = 0; i < NUM_OBSERVATION_TYPES; i++)
		c->split_stats.observations[i] = 0;
	c->split_stats.num_observations = 0;
	memset(c->p.n.match_len_freqs, 0, sizeof(c->p.n.match_len_freqs));
}


static void
deflate_compress_near_optimal(struct libdeflate_compressor * restrict c,
			      const u8 *in, size_t in_nbytes,
			      struct deflate_output_bitstream *os)
{
	const u8 *in_next = in;
	const u8 *in_block_begin = in_next;
	const u8 *in_end = in_next + in_nbytes;
	const u8 *in_cur_base = in_next;
	const u8 *in_next_slide =
		in_next + MIN(in_end - in_next, MATCHFINDER_WINDOW_SIZE);
	u32 max_len = DEFLATE_MAX_MATCH_LEN;
	u32 nice_len = MIN(c->nice_match_length, max_len);
	struct lz_match *cache_ptr = c->p.n.match_cache;
	u32 next_hashes[2] = {0, 0};
	bool prev_block_used_only_literals = false;

	bt_matchfinder_init(&c->p.n.bt_mf);
	deflate_near_optimal_init_stats(c);

	do {
		
		const u8 * const in_max_block_end = choose_max_block_end(
				in_block_begin, in_end, SOFT_MAX_BLOCK_LENGTH);
		const u8 *prev_end_block_check = NULL;
		bool change_detected = false;
		const u8 *next_observation = in_next;
		u32 min_len;

		
		if (prev_block_used_only_literals)
			min_len = DEFLATE_MAX_MATCH_LEN + 1;
		else
			min_len = calculate_min_match_len(
					in_block_begin,
					in_max_block_end - in_block_begin,
					c->max_search_depth);

		
		for (;;) {
			struct lz_match *matches;
			u32 best_len;
			size_t remaining = in_end - in_next;

			
			if (in_next == in_next_slide) {
				bt_matchfinder_slide_window(&c->p.n.bt_mf);
				in_cur_base = in_next;
				in_next_slide = in_next +
					MIN(remaining, MATCHFINDER_WINDOW_SIZE);
			}

			
			matches = cache_ptr;
			best_len = 0;
			adjust_max_and_nice_len(&max_len, &nice_len, remaining);
			if (likely(max_len >= BT_MATCHFINDER_REQUIRED_NBYTES)) {
				cache_ptr = bt_matchfinder_get_matches(
						&c->p.n.bt_mf,
						in_cur_base,
						in_next - in_cur_base,
						max_len,
						nice_len,
						c->max_search_depth,
						next_hashes,
						matches);
				if (cache_ptr > matches)
					best_len = cache_ptr[-1].length;
			}
			if (in_next >= next_observation) {
				if (best_len >= min_len) {
					observe_match(&c->split_stats,
						      best_len);
					next_observation = in_next + best_len;
					c->p.n.new_match_len_freqs[best_len]++;
				} else {
					observe_literal(&c->split_stats,
							*in_next);
					next_observation = in_next + 1;
				}
			}

			cache_ptr->length = cache_ptr - matches;
			cache_ptr->offset = *in_next;
			in_next++;
			cache_ptr++;

			
			if (best_len >= DEFLATE_MIN_MATCH_LEN &&
			    best_len >= nice_len) {
				--best_len;
				do {
					remaining = in_end - in_next;
					if (in_next == in_next_slide) {
						bt_matchfinder_slide_window(
							&c->p.n.bt_mf);
						in_cur_base = in_next;
						in_next_slide = in_next +
							MIN(remaining,
							    MATCHFINDER_WINDOW_SIZE);
					}
					adjust_max_and_nice_len(&max_len,
								&nice_len,
								remaining);
					if (max_len >=
					    BT_MATCHFINDER_REQUIRED_NBYTES) {
						bt_matchfinder_skip_byte(
							&c->p.n.bt_mf,
							in_cur_base,
							in_next - in_cur_base,
							nice_len,
							c->max_search_depth,
							next_hashes);
					}
					cache_ptr->length = 0;
					cache_ptr->offset = *in_next;
					in_next++;
					cache_ptr++;
				} while (--best_len);
			}
			
			if (in_next >= in_max_block_end)
				break;
			
			if (cache_ptr >=
			    &c->p.n.match_cache[MATCH_CACHE_LENGTH])
				break;
			
			if (!ready_to_check_block(&c->split_stats,
						  in_block_begin, in_next,
						  in_end))
				continue;
			
			if (do_end_block_check(&c->split_stats,
					       in_next - in_block_begin)) {
				change_detected = true;
				break;
			}
			
			deflate_near_optimal_merge_stats(c);
			prev_end_block_check = in_next;
		}
		
		if (change_detected && prev_end_block_check != NULL) {
			
			struct lz_match *orig_cache_ptr = cache_ptr;
			const u8 *in_block_end = prev_end_block_check;
			u32 block_length = in_block_end - in_block_begin;
			bool is_first = (in_block_begin == in);
			bool is_final = false;
			u32 num_bytes_to_rewind = in_next - in_block_end;
			size_t cache_len_rewound;

			
			do {
				cache_ptr--;
				cache_ptr -= cache_ptr->length;
			} while (--num_bytes_to_rewind);
			cache_len_rewound = orig_cache_ptr - cache_ptr;

			deflate_optimize_and_flush_block(
						c, os, in_block_begin,
						block_length, cache_ptr,
						is_first, is_final,
						&prev_block_used_only_literals);
			memmove(c->p.n.match_cache, cache_ptr,
				cache_len_rewound * sizeof(*cache_ptr));
			cache_ptr = &c->p.n.match_cache[cache_len_rewound];
			deflate_near_optimal_save_stats(c);
			
			deflate_near_optimal_clear_old_stats(c);
			in_block_begin = in_block_end;
		} else {
			
			u32 block_length = in_next - in_block_begin;
			bool is_first = (in_block_begin == in);
			bool is_final = (in_next == in_end);

			deflate_near_optimal_merge_stats(c);
			deflate_optimize_and_flush_block(
						c, os, in_block_begin,
						block_length, cache_ptr,
						is_first, is_final,
						&prev_block_used_only_literals);
			cache_ptr = &c->p.n.match_cache[0];
			deflate_near_optimal_save_stats(c);
			deflate_near_optimal_init_stats(c);
			in_block_begin = in_next;
		}
	} while (in_next != in_end && !os->overflow);
}


static void
deflate_init_offset_slot_full(struct libdeflate_compressor *c)
{
	u32 offset_slot;
	u32 offset;
	u32 offset_end;

	for (offset_slot = 0; offset_slot < ARRAY_LEN(deflate_offset_slot_base);
	     offset_slot++) {
		offset = deflate_offset_slot_base[offset_slot];
		offset_end = offset +
			     (1 << deflate_extra_offset_bits[offset_slot]);
		do {
			c->p.n.offset_slot_full[offset] = offset_slot;
		} while (++offset != offset_end);
	}
}

#endif 

LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options)
{
	struct libdeflate_compressor *c;
	size_t size = offsetof(struct libdeflate_compressor, p);

	check_buildtime_parameters();

	
	if (options->sizeof_options != sizeof(*options))
		return NULL;

	if (compression_level < 0 || compression_level > 12)
		return NULL;

#if SUPPORT_NEAR_OPTIMAL_PARSING
	if (compression_level >= 10)
		size += sizeof(c->p.n);
	else
#endif
	{
		if (compression_level >= 2)
			size += sizeof(c->p.g);
		else if (compression_level == 1)
			size += sizeof(c->p.f);
	}

	c = libdeflate_aligned_malloc(options->malloc_func ?
				      options->malloc_func :
				      libdeflate_default_malloc_func,
				      MATCHFINDER_MEM_ALIGNMENT, size);
	if (!c)
		return NULL;
	c->free_func = options->free_func ?
		       options->free_func : libdeflate_default_free_func;

	c->compression_level = compression_level;

	
	c->max_passthrough_size = 55 - (compression_level * 4);

	switch (compression_level) {
	case 0:
		c->max_passthrough_size = SIZE_MAX;
		c->impl = NULL; 
		break;
	case 1:
		c->impl = deflate_compress_fastest;
		
		c->nice_match_length = 32;
		break;
	case 2:
		c->impl = deflate_compress_greedy;
		c->max_search_depth = 6;
		c->nice_match_length = 10;
		break;
	case 3:
		c->impl = deflate_compress_greedy;
		c->max_search_depth = 12;
		c->nice_match_length = 14;
		break;
	case 4:
		c->impl = deflate_compress_greedy;
		c->max_search_depth = 16;
		c->nice_match_length = 30;
		break;
	case 5:
		c->impl = deflate_compress_lazy;
		c->max_search_depth = 16;
		c->nice_match_length = 30;
		break;
	case 6:
		c->impl = deflate_compress_lazy;
		c->max_search_depth = 35;
		c->nice_match_length = 65;
		break;
	case 7:
		c->impl = deflate_compress_lazy;
		c->max_search_depth = 100;
		c->nice_match_length = 130;
		break;
	case 8:
		c->impl = deflate_compress_lazy2;
		c->max_search_depth = 300;
		c->nice_match_length = DEFLATE_MAX_MATCH_LEN;
		break;
	case 9:
#if !SUPPORT_NEAR_OPTIMAL_PARSING
	default:
#endif
		c->impl = deflate_compress_lazy2;
		c->max_search_depth = 600;
		c->nice_match_length = DEFLATE_MAX_MATCH_LEN;
		break;
#if SUPPORT_NEAR_OPTIMAL_PARSING
	case 10:
		c->impl = deflate_compress_near_optimal;
		c->max_search_depth = 35;
		c->nice_match_length = 75;
		c->p.n.max_optim_passes = 2;
		c->p.n.min_improvement_to_continue = 32;
		c->p.n.min_bits_to_use_nonfinal_path = 32;
		c->p.n.max_len_to_optimize_static_block = 0;
		deflate_init_offset_slot_full(c);
		break;
	case 11:
		c->impl = deflate_compress_near_optimal;
		c->max_search_depth = 100;
		c->nice_match_length = 150;
		c->p.n.max_optim_passes = 4;
		c->p.n.min_improvement_to_continue = 16;
		c->p.n.min_bits_to_use_nonfinal_path = 16;
		c->p.n.max_len_to_optimize_static_block = 1000;
		deflate_init_offset_slot_full(c);
		break;
	case 12:
	default:
		c->impl = deflate_compress_near_optimal;
		c->max_search_depth = 300;
		c->nice_match_length = DEFLATE_MAX_MATCH_LEN;
		c->p.n.max_optim_passes = 10;
		c->p.n.min_improvement_to_continue = 1;
		c->p.n.min_bits_to_use_nonfinal_path = 1;
		c->p.n.max_len_to_optimize_static_block = 10000;
		deflate_init_offset_slot_full(c);
		break;
#endif 
	}

	deflate_init_static_codes(c);

	return c;
}


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level)
{
	static const struct libdeflate_options defaults = {
		.sizeof_options = sizeof(defaults),
	};
	return libdeflate_alloc_compressor_ex(compression_level, &defaults);
}

LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *c,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail)
{
	struct deflate_output_bitstream os;

	
	if (unlikely(in_nbytes <= c->max_passthrough_size))
		return deflate_compress_none(in, in_nbytes,
					     out, out_nbytes_avail);

	
	os.bitbuf = 0;
	os.bitcount = 0;
	os.next = out;
	os.end = os.next + out_nbytes_avail;
	os.overflow = false;

	
	(*c->impl)(c, in, in_nbytes, &os);

	
	if (os.overflow)
		return 0;

	
	ASSERT(os.bitcount <= 7);
	if (os.bitcount) {
		ASSERT(os.next < os.end);
		*os.next++ = os.bitbuf;
	}

	
	return os.next - (u8 *)out;
}

LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *c)
{
	if (c)
		libdeflate_aligned_free(c->free_func, c);
}

unsigned int
libdeflate_get_compression_level(struct libdeflate_compressor *c)
{
	return c->compression_level;
}

LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *c,
				  size_t in_nbytes)
{
	size_t max_blocks;

	

	
	STATIC_ASSERT(2 * MIN_BLOCK_LENGTH <= UINT16_MAX);
	max_blocks = MAX(DIV_ROUND_UP(in_nbytes, MIN_BLOCK_LENGTH), 1);

	
	return (5 * max_blocks) + in_nbytes;
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/deflate_decompress.c */


/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 

/* #include "deflate_constants.h" */


#ifndef LIB_DEFLATE_CONSTANTS_H
#define LIB_DEFLATE_CONSTANTS_H


#define DEFLATE_BLOCKTYPE_UNCOMPRESSED		0
#define DEFLATE_BLOCKTYPE_STATIC_HUFFMAN	1
#define DEFLATE_BLOCKTYPE_DYNAMIC_HUFFMAN	2


#define DEFLATE_MIN_MATCH_LEN			3
#define DEFLATE_MAX_MATCH_LEN			258


#define DEFLATE_MAX_MATCH_OFFSET		32768


#define DEFLATE_WINDOW_ORDER			15


#define DEFLATE_NUM_PRECODE_SYMS		19
#define DEFLATE_NUM_LITLEN_SYMS			288
#define DEFLATE_NUM_OFFSET_SYMS			32


#define DEFLATE_MAX_NUM_SYMS			288


#define DEFLATE_NUM_LITERALS			256
#define DEFLATE_END_OF_BLOCK			256
#define DEFLATE_FIRST_LEN_SYM			257


#define DEFLATE_MAX_PRE_CODEWORD_LEN		7
#define DEFLATE_MAX_LITLEN_CODEWORD_LEN		15
#define DEFLATE_MAX_OFFSET_CODEWORD_LEN		15


#define DEFLATE_MAX_CODEWORD_LEN		15


#define DEFLATE_MAX_LENS_OVERRUN		137


#define DEFLATE_MAX_EXTRA_LENGTH_BITS		5
#define DEFLATE_MAX_EXTRA_OFFSET_BITS		13

#endif 



#if 0
#  pragma message("UNSAFE DECOMPRESSION IS ENABLED. THIS MUST ONLY BE USED IF THE DECOMPRESSOR INPUT WILL ALWAYS BE TRUSTED!")
#  define SAFETY_CHECK(expr)	(void)(expr)
#else
#  define SAFETY_CHECK(expr)	if (unlikely(!(expr))) return LIBDEFLATE_BAD_DATA
#endif






/* typedef machine_word_t bitbuf_t; */
#define DECOMPRESS_BITBUF_NBITS	(8 * (int)sizeof(bitbuf_t))


#define BITMASK(n)	(((bitbuf_t)1 << (n)) - 1)


#define MAX_BITSLEFT	\
	(UNALIGNED_ACCESS_IS_FAST ? DECOMPRESS_BITBUF_NBITS - 1 : DECOMPRESS_BITBUF_NBITS)


#define CONSUMABLE_NBITS	(MAX_BITSLEFT - 7)


#define FASTLOOP_PRELOADABLE_NBITS	\
	(UNALIGNED_ACCESS_IS_FAST ? DECOMPRESS_BITBUF_NBITS : CONSUMABLE_NBITS)


#define PRELOAD_SLACK	MAX(0, FASTLOOP_PRELOADABLE_NBITS - MAX_BITSLEFT)


#define CAN_CONSUME(n)	(CONSUMABLE_NBITS >= (n))


#define CAN_CONSUME_AND_THEN_PRELOAD(consume_nbits, preload_nbits)	\
	(CONSUMABLE_NBITS >= (consume_nbits) &&				\
	 FASTLOOP_PRELOADABLE_NBITS >= (consume_nbits) + (preload_nbits))


#define REFILL_BITS_BRANCHLESS()					\
do {									\
	bitbuf |= get_unaligned_leword(in_next) << (u8)bitsleft;	\
	in_next += sizeof(bitbuf_t) - 1;				\
	in_next -= (bitsleft >> 3) & 0x7;				\
	bitsleft |= MAX_BITSLEFT & ~7;					\
} while (0)


#define REFILL_BITS()							\
do {									\
	if (UNALIGNED_ACCESS_IS_FAST &&					\
	    likely(in_end - in_next >= sizeof(bitbuf_t))) {		\
		REFILL_BITS_BRANCHLESS();				\
	} else {							\
		while ((u8)bitsleft < CONSUMABLE_NBITS) {		\
			if (likely(in_next != in_end)) {		\
				bitbuf |= (bitbuf_t)*in_next++ <<	\
					  (u8)bitsleft;			\
			} else {					\
				overread_count++;			\
				SAFETY_CHECK(overread_count <=		\
					     sizeof(bitbuf_t));		\
			}						\
			bitsleft += 8;					\
		}							\
	}								\
} while (0)


#define REFILL_BITS_IN_FASTLOOP()					\
do {									\
	STATIC_ASSERT(UNALIGNED_ACCESS_IS_FAST ||			\
		      FASTLOOP_PRELOADABLE_NBITS == CONSUMABLE_NBITS);	\
	if (UNALIGNED_ACCESS_IS_FAST) {					\
		REFILL_BITS_BRANCHLESS();				\
	} else {							\
		while ((u8)bitsleft < CONSUMABLE_NBITS) {		\
			bitbuf |= (bitbuf_t)*in_next++ << (u8)bitsleft;	\
			bitsleft += 8;					\
		}							\
	}								\
} while (0)


#define FASTLOOP_MAX_BYTES_WRITTEN	\
	(2 + DEFLATE_MAX_MATCH_LEN + (5 * WORDBYTES) - 1)


#define FASTLOOP_MAX_BYTES_READ					\
	(DIV_ROUND_UP(MAX_BITSLEFT + (2 * LITLEN_TABLEBITS) +	\
		      LENGTH_MAXBITS + OFFSET_MAXBITS, 8) +	\
	 sizeof(bitbuf_t))







#define PRECODE_TABLEBITS	7
#define PRECODE_ENOUGH		128	
#define LITLEN_TABLEBITS	11
#define LITLEN_ENOUGH		2342	
#define OFFSET_TABLEBITS	8
#define OFFSET_ENOUGH		402	


static forceinline u32
make_decode_table_entry(const u32 decode_results[], u32 sym, u32 len)
{
	return decode_results[sym] + (len << 8) + len;
}


static const u32 precode_decode_results[] = {
#define ENTRY(presym)	((u32)presym << 16)
	ENTRY(0)   , ENTRY(1)   , ENTRY(2)   , ENTRY(3)   ,
	ENTRY(4)   , ENTRY(5)   , ENTRY(6)   , ENTRY(7)   ,
	ENTRY(8)   , ENTRY(9)   , ENTRY(10)  , ENTRY(11)  ,
	ENTRY(12)  , ENTRY(13)  , ENTRY(14)  , ENTRY(15)  ,
	ENTRY(16)  , ENTRY(17)  , ENTRY(18)  ,
#undef ENTRY
};




#define HUFFDEC_LITERAL			0x80000000


#define HUFFDEC_EXCEPTIONAL		0x00008000


#define HUFFDEC_SUBTABLE_POINTER	0x00004000


#define HUFFDEC_END_OF_BLOCK		0x00002000


#define LENGTH_MAXBITS		(DEFLATE_MAX_LITLEN_CODEWORD_LEN + \
				 DEFLATE_MAX_EXTRA_LENGTH_BITS)
#define LENGTH_MAXFASTBITS	(LITLEN_TABLEBITS  + \
				 DEFLATE_MAX_EXTRA_LENGTH_BITS)


static const u32 litlen_decode_results[] = {

	
#define ENTRY(literal)	(HUFFDEC_LITERAL | ((u32)literal << 16))
	ENTRY(0)   , ENTRY(1)   , ENTRY(2)   , ENTRY(3)   ,
	ENTRY(4)   , ENTRY(5)   , ENTRY(6)   , ENTRY(7)   ,
	ENTRY(8)   , ENTRY(9)   , ENTRY(10)  , ENTRY(11)  ,
	ENTRY(12)  , ENTRY(13)  , ENTRY(14)  , ENTRY(15)  ,
	ENTRY(16)  , ENTRY(17)  , ENTRY(18)  , ENTRY(19)  ,
	ENTRY(20)  , ENTRY(21)  , ENTRY(22)  , ENTRY(23)  ,
	ENTRY(24)  , ENTRY(25)  , ENTRY(26)  , ENTRY(27)  ,
	ENTRY(28)  , ENTRY(29)  , ENTRY(30)  , ENTRY(31)  ,
	ENTRY(32)  , ENTRY(33)  , ENTRY(34)  , ENTRY(35)  ,
	ENTRY(36)  , ENTRY(37)  , ENTRY(38)  , ENTRY(39)  ,
	ENTRY(40)  , ENTRY(41)  , ENTRY(42)  , ENTRY(43)  ,
	ENTRY(44)  , ENTRY(45)  , ENTRY(46)  , ENTRY(47)  ,
	ENTRY(48)  , ENTRY(49)  , ENTRY(50)  , ENTRY(51)  ,
	ENTRY(52)  , ENTRY(53)  , ENTRY(54)  , ENTRY(55)  ,
	ENTRY(56)  , ENTRY(57)  , ENTRY(58)  , ENTRY(59)  ,
	ENTRY(60)  , ENTRY(61)  , ENTRY(62)  , ENTRY(63)  ,
	ENTRY(64)  , ENTRY(65)  , ENTRY(66)  , ENTRY(67)  ,
	ENTRY(68)  , ENTRY(69)  , ENTRY(70)  , ENTRY(71)  ,
	ENTRY(72)  , ENTRY(73)  , ENTRY(74)  , ENTRY(75)  ,
	ENTRY(76)  , ENTRY(77)  , ENTRY(78)  , ENTRY(79)  ,
	ENTRY(80)  , ENTRY(81)  , ENTRY(82)  , ENTRY(83)  ,
	ENTRY(84)  , ENTRY(85)  , ENTRY(86)  , ENTRY(87)  ,
	ENTRY(88)  , ENTRY(89)  , ENTRY(90)  , ENTRY(91)  ,
	ENTRY(92)  , ENTRY(93)  , ENTRY(94)  , ENTRY(95)  ,
	ENTRY(96)  , ENTRY(97)  , ENTRY(98)  , ENTRY(99)  ,
	ENTRY(100) , ENTRY(101) , ENTRY(102) , ENTRY(103) ,
	ENTRY(104) , ENTRY(105) , ENTRY(106) , ENTRY(107) ,
	ENTRY(108) , ENTRY(109) , ENTRY(110) , ENTRY(111) ,
	ENTRY(112) , ENTRY(113) , ENTRY(114) , ENTRY(115) ,
	ENTRY(116) , ENTRY(117) , ENTRY(118) , ENTRY(119) ,
	ENTRY(120) , ENTRY(121) , ENTRY(122) , ENTRY(123) ,
	ENTRY(124) , ENTRY(125) , ENTRY(126) , ENTRY(127) ,
	ENTRY(128) , ENTRY(129) , ENTRY(130) , ENTRY(131) ,
	ENTRY(132) , ENTRY(133) , ENTRY(134) , ENTRY(135) ,
	ENTRY(136) , ENTRY(137) , ENTRY(138) , ENTRY(139) ,
	ENTRY(140) , ENTRY(141) , ENTRY(142) , ENTRY(143) ,
	ENTRY(144) , ENTRY(145) , ENTRY(146) , ENTRY(147) ,
	ENTRY(148) , ENTRY(149) , ENTRY(150) , ENTRY(151) ,
	ENTRY(152) , ENTRY(153) , ENTRY(154) , ENTRY(155) ,
	ENTRY(156) , ENTRY(157) , ENTRY(158) , ENTRY(159) ,
	ENTRY(160) , ENTRY(161) , ENTRY(162) , ENTRY(163) ,
	ENTRY(164) , ENTRY(165) , ENTRY(166) , ENTRY(167) ,
	ENTRY(168) , ENTRY(169) , ENTRY(170) , ENTRY(171) ,
	ENTRY(172) , ENTRY(173) , ENTRY(174) , ENTRY(175) ,
	ENTRY(176) , ENTRY(177) , ENTRY(178) , ENTRY(179) ,
	ENTRY(180) , ENTRY(181) , ENTRY(182) , ENTRY(183) ,
	ENTRY(184) , ENTRY(185) , ENTRY(186) , ENTRY(187) ,
	ENTRY(188) , ENTRY(189) , ENTRY(190) , ENTRY(191) ,
	ENTRY(192) , ENTRY(193) , ENTRY(194) , ENTRY(195) ,
	ENTRY(196) , ENTRY(197) , ENTRY(198) , ENTRY(199) ,
	ENTRY(200) , ENTRY(201) , ENTRY(202) , ENTRY(203) ,
	ENTRY(204) , ENTRY(205) , ENTRY(206) , ENTRY(207) ,
	ENTRY(208) , ENTRY(209) , ENTRY(210) , ENTRY(211) ,
	ENTRY(212) , ENTRY(213) , ENTRY(214) , ENTRY(215) ,
	ENTRY(216) , ENTRY(217) , ENTRY(218) , ENTRY(219) ,
	ENTRY(220) , ENTRY(221) , ENTRY(222) , ENTRY(223) ,
	ENTRY(224) , ENTRY(225) , ENTRY(226) , ENTRY(227) ,
	ENTRY(228) , ENTRY(229) , ENTRY(230) , ENTRY(231) ,
	ENTRY(232) , ENTRY(233) , ENTRY(234) , ENTRY(235) ,
	ENTRY(236) , ENTRY(237) , ENTRY(238) , ENTRY(239) ,
	ENTRY(240) , ENTRY(241) , ENTRY(242) , ENTRY(243) ,
	ENTRY(244) , ENTRY(245) , ENTRY(246) , ENTRY(247) ,
	ENTRY(248) , ENTRY(249) , ENTRY(250) , ENTRY(251) ,
	ENTRY(252) , ENTRY(253) , ENTRY(254) , ENTRY(255) ,
#undef ENTRY

	
	HUFFDEC_EXCEPTIONAL | HUFFDEC_END_OF_BLOCK,

	
#define ENTRY(length_base, num_extra_bits)	\
	(((u32)(length_base) << 16) | (num_extra_bits))
	ENTRY(3  , 0) , ENTRY(4  , 0) , ENTRY(5  , 0) , ENTRY(6  , 0),
	ENTRY(7  , 0) , ENTRY(8  , 0) , ENTRY(9  , 0) , ENTRY(10 , 0),
	ENTRY(11 , 1) , ENTRY(13 , 1) , ENTRY(15 , 1) , ENTRY(17 , 1),
	ENTRY(19 , 2) , ENTRY(23 , 2) , ENTRY(27 , 2) , ENTRY(31 , 2),
	ENTRY(35 , 3) , ENTRY(43 , 3) , ENTRY(51 , 3) , ENTRY(59 , 3),
	ENTRY(67 , 4) , ENTRY(83 , 4) , ENTRY(99 , 4) , ENTRY(115, 4),
	ENTRY(131, 5) , ENTRY(163, 5) , ENTRY(195, 5) , ENTRY(227, 5),
	ENTRY(258, 0) , ENTRY(258, 0) , ENTRY(258, 0) ,
#undef ENTRY
};


#define OFFSET_MAXBITS		(DEFLATE_MAX_OFFSET_CODEWORD_LEN + \
				 DEFLATE_MAX_EXTRA_OFFSET_BITS)
#define OFFSET_MAXFASTBITS	(OFFSET_TABLEBITS  + \
				 DEFLATE_MAX_EXTRA_OFFSET_BITS)


static const u32 offset_decode_results[] = {
#define ENTRY(offset_base, num_extra_bits)	\
	(((u32)(offset_base) << 16) | (num_extra_bits))
	ENTRY(1     , 0)  , ENTRY(2     , 0)  , ENTRY(3     , 0)  , ENTRY(4     , 0)  ,
	ENTRY(5     , 1)  , ENTRY(7     , 1)  , ENTRY(9     , 2)  , ENTRY(13    , 2) ,
	ENTRY(17    , 3)  , ENTRY(25    , 3)  , ENTRY(33    , 4)  , ENTRY(49    , 4)  ,
	ENTRY(65    , 5)  , ENTRY(97    , 5)  , ENTRY(129   , 6)  , ENTRY(193   , 6)  ,
	ENTRY(257   , 7)  , ENTRY(385   , 7)  , ENTRY(513   , 8)  , ENTRY(769   , 8)  ,
	ENTRY(1025  , 9)  , ENTRY(1537  , 9)  , ENTRY(2049  , 10) , ENTRY(3073  , 10) ,
	ENTRY(4097  , 11) , ENTRY(6145  , 11) , ENTRY(8193  , 12) , ENTRY(12289 , 12) ,
	ENTRY(16385 , 13) , ENTRY(24577 , 13) , ENTRY(24577 , 13) , ENTRY(24577 , 13) ,
#undef ENTRY
};


struct libdeflate_decompressor {

	

	union {
		u8 precode_lens[DEFLATE_NUM_PRECODE_SYMS];

		struct {
			u8 lens[DEFLATE_NUM_LITLEN_SYMS +
				DEFLATE_NUM_OFFSET_SYMS +
				DEFLATE_MAX_LENS_OVERRUN];

			u32 precode_decode_table[PRECODE_ENOUGH];
		} l;

		u32 litlen_decode_table[LITLEN_ENOUGH];
	} u;

	u32 offset_decode_table[OFFSET_ENOUGH];

	
	u16 sorted_syms[DEFLATE_MAX_NUM_SYMS];

	bool static_codes_loaded;
	unsigned litlen_tablebits;

	
	free_func_t free_func;
};


static bool
build_decode_table(u32 decode_table[],
		   const u8 lens[],
		   const unsigned num_syms,
		   const u32 decode_results[],
		   unsigned table_bits,
		   unsigned max_codeword_len,
		   u16 *sorted_syms,
		   unsigned *table_bits_ret)
{
	unsigned len_counts[DEFLATE_MAX_CODEWORD_LEN + 1];
	unsigned offsets[DEFLATE_MAX_CODEWORD_LEN + 1];
	unsigned sym;		
	unsigned codeword;	
	unsigned len;		
	unsigned count;		
	u32 codespace_used;	
	unsigned cur_table_end; 
	unsigned subtable_prefix; 
	unsigned subtable_start;  
	unsigned subtable_bits;   

	
	for (len = 0; len <= max_codeword_len; len++)
		len_counts[len] = 0;
	for (sym = 0; sym < num_syms; sym++)
		len_counts[lens[sym]]++;

	
	while (max_codeword_len > 1 && len_counts[max_codeword_len] == 0)
		max_codeword_len--;
	if (table_bits_ret != NULL) {
		table_bits = MIN(table_bits, max_codeword_len);
		*table_bits_ret = table_bits;
	}

	

	
	STATIC_ASSERT(sizeof(codespace_used) == 4);
	STATIC_ASSERT(UINT32_MAX / (1U << (DEFLATE_MAX_CODEWORD_LEN - 1)) >=
		      DEFLATE_MAX_NUM_SYMS);

	offsets[0] = 0;
	offsets[1] = len_counts[0];
	codespace_used = 0;
	for (len = 1; len < max_codeword_len; len++) {
		offsets[len + 1] = offsets[len] + len_counts[len];
		codespace_used = (codespace_used << 1) + len_counts[len];
	}
	codespace_used = (codespace_used << 1) + len_counts[len];

	for (sym = 0; sym < num_syms; sym++)
		sorted_syms[offsets[lens[sym]]++] = sym;

	sorted_syms += offsets[0]; 

	

	

	
	if (unlikely(codespace_used > (1U << max_codeword_len)))
		return false;

	
	if (unlikely(codespace_used < (1U << max_codeword_len))) {
		u32 entry;
		unsigned i;

		
		if (codespace_used == 0) {
			sym = 0; 
		} else {
			if (codespace_used != (1U << (max_codeword_len - 1)) ||
			    len_counts[1] != 1)
				return false;
			sym = sorted_syms[0];
		}
		entry = make_decode_table_entry(decode_results, sym, 1);
		for (i = 0; i < (1U << table_bits); i++)
			decode_table[i] = entry;
		return true;
	}

	
	codeword = 0;
	len = 1;
	while ((count = len_counts[len]) == 0)
		len++;
	cur_table_end = 1U << len;
	while (len <= table_bits) {
		
		do {
			unsigned bit;

			
			decode_table[codeword] =
				make_decode_table_entry(decode_results,
							*sorted_syms++, len);

			if (codeword == cur_table_end - 1) {
				
				for (; len < table_bits; len++) {
					memcpy(&decode_table[cur_table_end],
					       decode_table,
					       cur_table_end *
						sizeof(decode_table[0]));
					cur_table_end <<= 1;
				}
				return true;
			}
			
			bit = 1U << bsr32(codeword ^ (cur_table_end - 1));
			codeword &= bit - 1;
			codeword |= bit;
		} while (--count);

		
		do {
			if (++len <= table_bits) {
				memcpy(&decode_table[cur_table_end],
				       decode_table,
				       cur_table_end * sizeof(decode_table[0]));
				cur_table_end <<= 1;
			}
		} while ((count = len_counts[len]) == 0);
	}

	
	cur_table_end = 1U << table_bits;
	subtable_prefix = -1;
	subtable_start = 0;
	for (;;) {
		u32 entry;
		unsigned i;
		unsigned stride;
		unsigned bit;

		
		if ((codeword & ((1U << table_bits) - 1)) != subtable_prefix) {
			subtable_prefix = (codeword & ((1U << table_bits) - 1));
			subtable_start = cur_table_end;
			
			subtable_bits = len - table_bits;
			codespace_used = count;
			while (codespace_used < (1U << subtable_bits)) {
				subtable_bits++;
				codespace_used = (codespace_used << 1) +
					len_counts[table_bits + subtable_bits];
			}
			cur_table_end = subtable_start + (1U << subtable_bits);

			
			decode_table[subtable_prefix] =
				((u32)subtable_start << 16) |
				HUFFDEC_EXCEPTIONAL |
				HUFFDEC_SUBTABLE_POINTER |
				(subtable_bits << 8) | table_bits;
		}

		
		entry = make_decode_table_entry(decode_results, *sorted_syms++,
						len - table_bits);
		i = subtable_start + (codeword >> table_bits);
		stride = 1U << (len - table_bits);
		do {
			decode_table[i] = entry;
			i += stride;
		} while (i < cur_table_end);

		
		if (codeword == (1U << len) - 1) 
			return true;
		bit = 1U << bsr32(codeword ^ ((1U << len) - 1));
		codeword &= bit - 1;
		codeword |= bit;
		count--;
		while (count == 0)
			count = len_counts[++len];
	}
}


static bool
build_precode_decode_table(struct libdeflate_decompressor *d)
{
	
	STATIC_ASSERT(PRECODE_TABLEBITS == 7 && PRECODE_ENOUGH == 128);

	STATIC_ASSERT(ARRAY_LEN(precode_decode_results) ==
		      DEFLATE_NUM_PRECODE_SYMS);

	return build_decode_table(d->u.l.precode_decode_table,
				  d->u.precode_lens,
				  DEFLATE_NUM_PRECODE_SYMS,
				  precode_decode_results,
				  PRECODE_TABLEBITS,
				  DEFLATE_MAX_PRE_CODEWORD_LEN,
				  d->sorted_syms,
				  NULL);
}


static bool
build_litlen_decode_table(struct libdeflate_decompressor *d,
			  unsigned num_litlen_syms, unsigned num_offset_syms)
{
	
	STATIC_ASSERT(LITLEN_TABLEBITS == 11 && LITLEN_ENOUGH == 2342);

	STATIC_ASSERT(ARRAY_LEN(litlen_decode_results) ==
		      DEFLATE_NUM_LITLEN_SYMS);

	return build_decode_table(d->u.litlen_decode_table,
				  d->u.l.lens,
				  num_litlen_syms,
				  litlen_decode_results,
				  LITLEN_TABLEBITS,
				  DEFLATE_MAX_LITLEN_CODEWORD_LEN,
				  d->sorted_syms,
				  &d->litlen_tablebits);
}


static bool
build_offset_decode_table(struct libdeflate_decompressor *d,
			  unsigned num_litlen_syms, unsigned num_offset_syms)
{
	
	STATIC_ASSERT(OFFSET_TABLEBITS == 8 && OFFSET_ENOUGH == 402);

	STATIC_ASSERT(ARRAY_LEN(offset_decode_results) ==
		      DEFLATE_NUM_OFFSET_SYMS);

	return build_decode_table(d->offset_decode_table,
				  d->u.l.lens + num_litlen_syms,
				  num_offset_syms,
				  offset_decode_results,
				  OFFSET_TABLEBITS,
				  DEFLATE_MAX_OFFSET_CODEWORD_LEN,
				  d->sorted_syms,
				  NULL);
}



typedef enum libdeflate_result (*decompress_func_t)
	(struct libdeflate_decompressor * restrict d,
	 const void * restrict in, size_t in_nbytes,
	 void * restrict out, size_t out_nbytes_avail,
	 size_t *actual_in_nbytes_ret, size_t *actual_out_nbytes_ret);

#define FUNCNAME deflate_decompress_default
#undef ATTRIBUTES
#undef EXTRACT_VARBITS
#undef EXTRACT_VARBITS8
/* #include "decompress_template.h" */




#ifndef ATTRIBUTES
#  define ATTRIBUTES
#endif
#ifndef EXTRACT_VARBITS
#  define EXTRACT_VARBITS(word, count)	((word) & BITMASK(count))
#endif
#ifndef EXTRACT_VARBITS8
#  define EXTRACT_VARBITS8(word, count)	((word) & BITMASK((u8)(count)))
#endif

static ATTRIBUTES MAYBE_UNUSED enum libdeflate_result
FUNCNAME(struct libdeflate_decompressor * restrict d,
	 const void * restrict in, size_t in_nbytes,
	 void * restrict out, size_t out_nbytes_avail,
	 size_t *actual_in_nbytes_ret, size_t *actual_out_nbytes_ret)
{
	u8 *out_next = out;
	u8 * const out_end = out_next + out_nbytes_avail;
	u8 * const out_fastloop_end =
		out_end - MIN(out_nbytes_avail, FASTLOOP_MAX_BYTES_WRITTEN);

	
	const u8 *in_next = in;
	const u8 * const in_end = in_next + in_nbytes;
	const u8 * const in_fastloop_end =
		in_end - MIN(in_nbytes, FASTLOOP_MAX_BYTES_READ);
	bitbuf_t bitbuf = 0;
	bitbuf_t saved_bitbuf;
	u32 bitsleft = 0;
	size_t overread_count = 0;

	bool is_final_block;
	unsigned block_type;
	unsigned num_litlen_syms;
	unsigned num_offset_syms;
	bitbuf_t litlen_tablemask;
	u32 entry;

next_block:
	
	;

	STATIC_ASSERT(CAN_CONSUME(1 + 2 + 5 + 5 + 4 + 3));
	REFILL_BITS();

	
	is_final_block = bitbuf & BITMASK(1);

	
	block_type = (bitbuf >> 1) & BITMASK(2);

	if (block_type == DEFLATE_BLOCKTYPE_DYNAMIC_HUFFMAN) {

		

		
		static const u8 deflate_precode_lens_permutation[DEFLATE_NUM_PRECODE_SYMS] = {
			16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
		};

		unsigned num_explicit_precode_lens;
		unsigned i;

		

		STATIC_ASSERT(DEFLATE_NUM_LITLEN_SYMS == 257 + BITMASK(5));
		num_litlen_syms = 257 + ((bitbuf >> 3) & BITMASK(5));

		STATIC_ASSERT(DEFLATE_NUM_OFFSET_SYMS == 1 + BITMASK(5));
		num_offset_syms = 1 + ((bitbuf >> 8) & BITMASK(5));

		STATIC_ASSERT(DEFLATE_NUM_PRECODE_SYMS == 4 + BITMASK(4));
		num_explicit_precode_lens = 4 + ((bitbuf >> 13) & BITMASK(4));

		d->static_codes_loaded = false;

		
		STATIC_ASSERT(DEFLATE_MAX_PRE_CODEWORD_LEN == (1 << 3) - 1);
		if (CAN_CONSUME(3 * (DEFLATE_NUM_PRECODE_SYMS - 1))) {
			d->u.precode_lens[deflate_precode_lens_permutation[0]] =
				(bitbuf >> 17) & BITMASK(3);
			bitbuf >>= 20;
			bitsleft -= 20;
			REFILL_BITS();
			i = 1;
			do {
				d->u.precode_lens[deflate_precode_lens_permutation[i]] =
					bitbuf & BITMASK(3);
				bitbuf >>= 3;
				bitsleft -= 3;
			} while (++i < num_explicit_precode_lens);
		} else {
			bitbuf >>= 17;
			bitsleft -= 17;
			i = 0;
			do {
				if ((u8)bitsleft < 3)
					REFILL_BITS();
				d->u.precode_lens[deflate_precode_lens_permutation[i]] =
					bitbuf & BITMASK(3);
				bitbuf >>= 3;
				bitsleft -= 3;
			} while (++i < num_explicit_precode_lens);
		}
		for (; i < DEFLATE_NUM_PRECODE_SYMS; i++)
			d->u.precode_lens[deflate_precode_lens_permutation[i]] = 0;

		
		SAFETY_CHECK(build_precode_decode_table(d));

		
		i = 0;
		do {
			unsigned presym;
			u8 rep_val;
			unsigned rep_count;

			if ((u8)bitsleft < DEFLATE_MAX_PRE_CODEWORD_LEN + 7)
				REFILL_BITS();

			
			STATIC_ASSERT(PRECODE_TABLEBITS == DEFLATE_MAX_PRE_CODEWORD_LEN);

			
			entry = d->u.l.precode_decode_table[
				bitbuf & BITMASK(DEFLATE_MAX_PRE_CODEWORD_LEN)];
			bitbuf >>= (u8)entry;
			bitsleft -= entry; 
			presym = entry >> 16;

			if (presym < 16) {
				
				d->u.l.lens[i++] = presym;
				continue;
			}

			

			
			STATIC_ASSERT(DEFLATE_MAX_LENS_OVERRUN == 138 - 1);

			if (presym == 16) {
				
				SAFETY_CHECK(i != 0);
				rep_val = d->u.l.lens[i - 1];
				STATIC_ASSERT(3 + BITMASK(2) == 6);
				rep_count = 3 + (bitbuf & BITMASK(2));
				bitbuf >>= 2;
				bitsleft -= 2;
				d->u.l.lens[i + 0] = rep_val;
				d->u.l.lens[i + 1] = rep_val;
				d->u.l.lens[i + 2] = rep_val;
				d->u.l.lens[i + 3] = rep_val;
				d->u.l.lens[i + 4] = rep_val;
				d->u.l.lens[i + 5] = rep_val;
				i += rep_count;
			} else if (presym == 17) {
				
				STATIC_ASSERT(3 + BITMASK(3) == 10);
				rep_count = 3 + (bitbuf & BITMASK(3));
				bitbuf >>= 3;
				bitsleft -= 3;
				d->u.l.lens[i + 0] = 0;
				d->u.l.lens[i + 1] = 0;
				d->u.l.lens[i + 2] = 0;
				d->u.l.lens[i + 3] = 0;
				d->u.l.lens[i + 4] = 0;
				d->u.l.lens[i + 5] = 0;
				d->u.l.lens[i + 6] = 0;
				d->u.l.lens[i + 7] = 0;
				d->u.l.lens[i + 8] = 0;
				d->u.l.lens[i + 9] = 0;
				i += rep_count;
			} else {
				
				STATIC_ASSERT(11 + BITMASK(7) == 138);
				rep_count = 11 + (bitbuf & BITMASK(7));
				bitbuf >>= 7;
				bitsleft -= 7;
				memset(&d->u.l.lens[i], 0,
				       rep_count * sizeof(d->u.l.lens[i]));
				i += rep_count;
			}
		} while (i < num_litlen_syms + num_offset_syms);

		
		SAFETY_CHECK(i == num_litlen_syms + num_offset_syms);

	} else if (block_type == DEFLATE_BLOCKTYPE_UNCOMPRESSED) {
		u16 len, nlen;

		

		bitsleft -= 3; 

		
		bitsleft = (u8)bitsleft;
		SAFETY_CHECK(overread_count <= (bitsleft >> 3));
		in_next -= (bitsleft >> 3) - overread_count;
		overread_count = 0;
		bitbuf = 0;
		bitsleft = 0;

		SAFETY_CHECK(in_end - in_next >= 4);
		len = get_unaligned_le16(in_next);
		nlen = get_unaligned_le16(in_next + 2);
		in_next += 4;

		SAFETY_CHECK(len == (u16)~nlen);
		if (unlikely(len > out_end - out_next))
			return LIBDEFLATE_INSUFFICIENT_SPACE;
		SAFETY_CHECK(len <= in_end - in_next);

		memcpy(out_next, in_next, len);
		in_next += len;
		out_next += len;

		goto block_done;

	} else {
		unsigned i;

		SAFETY_CHECK(block_type == DEFLATE_BLOCKTYPE_STATIC_HUFFMAN);

		

		bitbuf >>= 3; 
		bitsleft -= 3;

		if (d->static_codes_loaded)
			goto have_decode_tables;

		d->static_codes_loaded = true;

		STATIC_ASSERT(DEFLATE_NUM_LITLEN_SYMS == 288);
		STATIC_ASSERT(DEFLATE_NUM_OFFSET_SYMS == 32);

		for (i = 0; i < 144; i++)
			d->u.l.lens[i] = 8;
		for (; i < 256; i++)
			d->u.l.lens[i] = 9;
		for (; i < 280; i++)
			d->u.l.lens[i] = 7;
		for (; i < 288; i++)
			d->u.l.lens[i] = 8;

		for (; i < 288 + 32; i++)
			d->u.l.lens[i] = 5;

		num_litlen_syms = 288;
		num_offset_syms = 32;
	}

	

	SAFETY_CHECK(build_offset_decode_table(d, num_litlen_syms, num_offset_syms));
	SAFETY_CHECK(build_litlen_decode_table(d, num_litlen_syms, num_offset_syms));
have_decode_tables:
	litlen_tablemask = BITMASK(d->litlen_tablebits);

	
	if (in_next >= in_fastloop_end || out_next >= out_fastloop_end)
		goto generic_loop;
	REFILL_BITS_IN_FASTLOOP();
	entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
	do {
		u32 length, offset, lit;
		const u8 *src;
		u8 *dst;

		
		saved_bitbuf = bitbuf;
		bitbuf >>= (u8)entry;
		bitsleft -= entry; 

		
		if (entry & HUFFDEC_LITERAL) {
			
			if (
			    CAN_CONSUME_AND_THEN_PRELOAD(2 * LITLEN_TABLEBITS +
							 LENGTH_MAXBITS,
							 OFFSET_TABLEBITS) &&
			    
			    CAN_CONSUME_AND_THEN_PRELOAD(2 * LITLEN_TABLEBITS +
							 DEFLATE_MAX_LITLEN_CODEWORD_LEN,
							 LITLEN_TABLEBITS)) {
				
				lit = entry >> 16;
				entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
				saved_bitbuf = bitbuf;
				bitbuf >>= (u8)entry;
				bitsleft -= entry;
				*out_next++ = lit;
				if (entry & HUFFDEC_LITERAL) {
					
					lit = entry >> 16;
					entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
					saved_bitbuf = bitbuf;
					bitbuf >>= (u8)entry;
					bitsleft -= entry;
					*out_next++ = lit;
					if (entry & HUFFDEC_LITERAL) {
						
						lit = entry >> 16;
						entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
						REFILL_BITS_IN_FASTLOOP();
						*out_next++ = lit;
						continue;
					}
				}
			} else {
				
				STATIC_ASSERT(CAN_CONSUME_AND_THEN_PRELOAD(
						LITLEN_TABLEBITS, LITLEN_TABLEBITS));
				lit = entry >> 16;
				entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
				REFILL_BITS_IN_FASTLOOP();
				*out_next++ = lit;
				continue;
			}
		}

		
		if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
			

			if (unlikely(entry & HUFFDEC_END_OF_BLOCK))
				goto block_done;

			
			entry = d->u.litlen_decode_table[(entry >> 16) +
				EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			saved_bitbuf = bitbuf;
			bitbuf >>= (u8)entry;
			bitsleft -= entry;

			
			if (!CAN_CONSUME_AND_THEN_PRELOAD(DEFLATE_MAX_LITLEN_CODEWORD_LEN,
							  LITLEN_TABLEBITS) ||
			    !CAN_CONSUME_AND_THEN_PRELOAD(LENGTH_MAXBITS,
							  OFFSET_TABLEBITS))
				REFILL_BITS_IN_FASTLOOP();
			if (entry & HUFFDEC_LITERAL) {
				
				lit = entry >> 16;
				entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
				REFILL_BITS_IN_FASTLOOP();
				*out_next++ = lit;
				continue;
			}
			if (unlikely(entry & HUFFDEC_END_OF_BLOCK))
				goto block_done;
			
		}

		
		length = entry >> 16;
		length += EXTRACT_VARBITS8(saved_bitbuf, entry) >> (u8)(entry >> 8);

		
		STATIC_ASSERT(CAN_CONSUME_AND_THEN_PRELOAD(LENGTH_MAXFASTBITS,
							   OFFSET_TABLEBITS));
		entry = d->offset_decode_table[bitbuf & BITMASK(OFFSET_TABLEBITS)];
		if (CAN_CONSUME_AND_THEN_PRELOAD(OFFSET_MAXBITS,
						 LITLEN_TABLEBITS)) {
			
			if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
				
				if (unlikely((u8)bitsleft < OFFSET_MAXBITS +
					     LITLEN_TABLEBITS - PRELOAD_SLACK))
					REFILL_BITS_IN_FASTLOOP();
				bitbuf >>= OFFSET_TABLEBITS;
				bitsleft -= OFFSET_TABLEBITS;
				entry = d->offset_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			} else if (unlikely((u8)bitsleft < OFFSET_MAXFASTBITS +
					    LITLEN_TABLEBITS - PRELOAD_SLACK))
				REFILL_BITS_IN_FASTLOOP();
		} else {
			
			REFILL_BITS_IN_FASTLOOP();
			if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
				
				bitbuf >>= OFFSET_TABLEBITS;
				bitsleft -= OFFSET_TABLEBITS;
				entry = d->offset_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
				REFILL_BITS_IN_FASTLOOP();
				
				STATIC_ASSERT(CAN_CONSUME(
					OFFSET_MAXBITS - OFFSET_TABLEBITS));
			} else {
				
				STATIC_ASSERT(CAN_CONSUME(OFFSET_MAXFASTBITS));
			}
		}
		saved_bitbuf = bitbuf;
		bitbuf >>= (u8)entry;
		bitsleft -= entry; 
		offset = entry >> 16;
		offset += EXTRACT_VARBITS8(saved_bitbuf, entry) >> (u8)(entry >> 8);

		
		SAFETY_CHECK(offset <= out_next - (const u8 *)out);
		src = out_next - offset;
		dst = out_next;
		out_next += length;

		
		if (!CAN_CONSUME_AND_THEN_PRELOAD(
			MAX(OFFSET_MAXBITS - OFFSET_TABLEBITS,
			    OFFSET_MAXFASTBITS),
			LITLEN_TABLEBITS) &&
		    unlikely((u8)bitsleft < LITLEN_TABLEBITS - PRELOAD_SLACK))
			REFILL_BITS_IN_FASTLOOP();
		entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
		REFILL_BITS_IN_FASTLOOP();

		
		if (UNALIGNED_ACCESS_IS_FAST && offset >= WORDBYTES) {
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			while (dst < out_next) {
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
			}
		} else if (UNALIGNED_ACCESS_IS_FAST && offset == 1) {
			machine_word_t v;

			
			v = (machine_word_t)0x0101010101010101 * src[0];
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			while (dst < out_next) {
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
			}
		} else if (UNALIGNED_ACCESS_IS_FAST) {
			store_word_unaligned(load_word_unaligned(src), dst);
			src += offset;
			dst += offset;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += offset;
			dst += offset;
			do {
				store_word_unaligned(load_word_unaligned(src), dst);
				src += offset;
				dst += offset;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += offset;
				dst += offset;
			} while (dst < out_next);
		} else {
			*dst++ = *src++;
			*dst++ = *src++;
			do {
				*dst++ = *src++;
			} while (dst < out_next);
		}
	} while (in_next < in_fastloop_end && out_next < out_fastloop_end);

	
generic_loop:
	for (;;) {
		u32 length, offset;
		const u8 *src;
		u8 *dst;

		REFILL_BITS();
		entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
		saved_bitbuf = bitbuf;
		bitbuf >>= (u8)entry;
		bitsleft -= entry;
		if (unlikely(entry & HUFFDEC_SUBTABLE_POINTER)) {
			entry = d->u.litlen_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			saved_bitbuf = bitbuf;
			bitbuf >>= (u8)entry;
			bitsleft -= entry;
		}
		length = entry >> 16;
		if (entry & HUFFDEC_LITERAL) {
			if (unlikely(out_next == out_end))
				return LIBDEFLATE_INSUFFICIENT_SPACE;
			*out_next++ = length;
			continue;
		}
		if (unlikely(entry & HUFFDEC_END_OF_BLOCK))
			goto block_done;
		length += EXTRACT_VARBITS8(saved_bitbuf, entry) >> (u8)(entry >> 8);
		if (unlikely(length > out_end - out_next))
			return LIBDEFLATE_INSUFFICIENT_SPACE;

		if (!CAN_CONSUME(LENGTH_MAXBITS + OFFSET_MAXBITS))
			REFILL_BITS();
		entry = d->offset_decode_table[bitbuf & BITMASK(OFFSET_TABLEBITS)];
		if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
			bitbuf >>= OFFSET_TABLEBITS;
			bitsleft -= OFFSET_TABLEBITS;
			entry = d->offset_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			if (!CAN_CONSUME(OFFSET_MAXBITS))
				REFILL_BITS();
		}
		offset = entry >> 16;
		offset += EXTRACT_VARBITS8(bitbuf, entry) >> (u8)(entry >> 8);
		bitbuf >>= (u8)entry;
		bitsleft -= entry;

		SAFETY_CHECK(offset <= out_next - (const u8 *)out);
		src = out_next - offset;
		dst = out_next;
		out_next += length;

		STATIC_ASSERT(DEFLATE_MIN_MATCH_LEN == 3);
		*dst++ = *src++;
		*dst++ = *src++;
		do {
			*dst++ = *src++;
		} while (dst < out_next);
	}

block_done:
	

	if (!is_final_block)
		goto next_block;

	

	bitsleft = (u8)bitsleft;

	
	SAFETY_CHECK(overread_count <= (bitsleft >> 3));

	
	if (actual_in_nbytes_ret) {
		
		in_next -= (bitsleft >> 3) - overread_count;

		*actual_in_nbytes_ret = in_next - (u8 *)in;
	}

	
	if (actual_out_nbytes_ret) {
		*actual_out_nbytes_ret = out_next - (u8 *)out;
	} else {
		if (out_next != out_end)
			return LIBDEFLATE_SHORT_OUTPUT;
	}
	return LIBDEFLATE_SUCCESS;
}

#undef FUNCNAME
#undef ATTRIBUTES
#undef EXTRACT_VARBITS
#undef EXTRACT_VARBITS8



#undef DEFAULT_IMPL
#undef arch_select_decompress_func
#if defined(ARCH_X86_32) || defined(ARCH_X86_64)
/* #  include "x86/decompress_impl.h" */
#ifndef LIB_X86_DECOMPRESS_IMPL_H
#define LIB_X86_DECOMPRESS_IMPL_H

/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 



#if defined(__GNUC__) || defined(__clang__) || MSVC_PREREQ(1930)
#  define deflate_decompress_bmi2	deflate_decompress_bmi2
#  define FUNCNAME			deflate_decompress_bmi2
#  define ATTRIBUTES			_target_attribute("bmi2")
   
#  ifndef __clang__
#    ifdef ARCH_X86_64
#      define EXTRACT_VARBITS(word, count)  _bzhi_u64((word), (count))
#      define EXTRACT_VARBITS8(word, count) _bzhi_u64((word), (count))
#    else
#      define EXTRACT_VARBITS(word, count)  _bzhi_u32((word), (count))
#      define EXTRACT_VARBITS8(word, count) _bzhi_u32((word), (count))
#    endif
#  endif
/* #include "decompress_template.h" */




#ifndef ATTRIBUTES
#  define ATTRIBUTES
#endif
#ifndef EXTRACT_VARBITS
#  define EXTRACT_VARBITS(word, count)	((word) & BITMASK(count))
#endif
#ifndef EXTRACT_VARBITS8
#  define EXTRACT_VARBITS8(word, count)	((word) & BITMASK((u8)(count)))
#endif

static ATTRIBUTES MAYBE_UNUSED enum libdeflate_result
FUNCNAME(struct libdeflate_decompressor * restrict d,
	 const void * restrict in, size_t in_nbytes,
	 void * restrict out, size_t out_nbytes_avail,
	 size_t *actual_in_nbytes_ret, size_t *actual_out_nbytes_ret)
{
	u8 *out_next = out;
	u8 * const out_end = out_next + out_nbytes_avail;
	u8 * const out_fastloop_end =
		out_end - MIN(out_nbytes_avail, FASTLOOP_MAX_BYTES_WRITTEN);

	
	const u8 *in_next = in;
	const u8 * const in_end = in_next + in_nbytes;
	const u8 * const in_fastloop_end =
		in_end - MIN(in_nbytes, FASTLOOP_MAX_BYTES_READ);
	bitbuf_t bitbuf = 0;
	bitbuf_t saved_bitbuf;
	u32 bitsleft = 0;
	size_t overread_count = 0;

	bool is_final_block;
	unsigned block_type;
	unsigned num_litlen_syms;
	unsigned num_offset_syms;
	bitbuf_t litlen_tablemask;
	u32 entry;

next_block:
	
	;

	STATIC_ASSERT(CAN_CONSUME(1 + 2 + 5 + 5 + 4 + 3));
	REFILL_BITS();

	
	is_final_block = bitbuf & BITMASK(1);

	
	block_type = (bitbuf >> 1) & BITMASK(2);

	if (block_type == DEFLATE_BLOCKTYPE_DYNAMIC_HUFFMAN) {

		

		
		static const u8 deflate_precode_lens_permutation[DEFLATE_NUM_PRECODE_SYMS] = {
			16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
		};

		unsigned num_explicit_precode_lens;
		unsigned i;

		

		STATIC_ASSERT(DEFLATE_NUM_LITLEN_SYMS == 257 + BITMASK(5));
		num_litlen_syms = 257 + ((bitbuf >> 3) & BITMASK(5));

		STATIC_ASSERT(DEFLATE_NUM_OFFSET_SYMS == 1 + BITMASK(5));
		num_offset_syms = 1 + ((bitbuf >> 8) & BITMASK(5));

		STATIC_ASSERT(DEFLATE_NUM_PRECODE_SYMS == 4 + BITMASK(4));
		num_explicit_precode_lens = 4 + ((bitbuf >> 13) & BITMASK(4));

		d->static_codes_loaded = false;

		
		STATIC_ASSERT(DEFLATE_MAX_PRE_CODEWORD_LEN == (1 << 3) - 1);
		if (CAN_CONSUME(3 * (DEFLATE_NUM_PRECODE_SYMS - 1))) {
			d->u.precode_lens[deflate_precode_lens_permutation[0]] =
				(bitbuf >> 17) & BITMASK(3);
			bitbuf >>= 20;
			bitsleft -= 20;
			REFILL_BITS();
			i = 1;
			do {
				d->u.precode_lens[deflate_precode_lens_permutation[i]] =
					bitbuf & BITMASK(3);
				bitbuf >>= 3;
				bitsleft -= 3;
			} while (++i < num_explicit_precode_lens);
		} else {
			bitbuf >>= 17;
			bitsleft -= 17;
			i = 0;
			do {
				if ((u8)bitsleft < 3)
					REFILL_BITS();
				d->u.precode_lens[deflate_precode_lens_permutation[i]] =
					bitbuf & BITMASK(3);
				bitbuf >>= 3;
				bitsleft -= 3;
			} while (++i < num_explicit_precode_lens);
		}
		for (; i < DEFLATE_NUM_PRECODE_SYMS; i++)
			d->u.precode_lens[deflate_precode_lens_permutation[i]] = 0;

		
		SAFETY_CHECK(build_precode_decode_table(d));

		
		i = 0;
		do {
			unsigned presym;
			u8 rep_val;
			unsigned rep_count;

			if ((u8)bitsleft < DEFLATE_MAX_PRE_CODEWORD_LEN + 7)
				REFILL_BITS();

			
			STATIC_ASSERT(PRECODE_TABLEBITS == DEFLATE_MAX_PRE_CODEWORD_LEN);

			
			entry = d->u.l.precode_decode_table[
				bitbuf & BITMASK(DEFLATE_MAX_PRE_CODEWORD_LEN)];
			bitbuf >>= (u8)entry;
			bitsleft -= entry; 
			presym = entry >> 16;

			if (presym < 16) {
				
				d->u.l.lens[i++] = presym;
				continue;
			}

			

			
			STATIC_ASSERT(DEFLATE_MAX_LENS_OVERRUN == 138 - 1);

			if (presym == 16) {
				
				SAFETY_CHECK(i != 0);
				rep_val = d->u.l.lens[i - 1];
				STATIC_ASSERT(3 + BITMASK(2) == 6);
				rep_count = 3 + (bitbuf & BITMASK(2));
				bitbuf >>= 2;
				bitsleft -= 2;
				d->u.l.lens[i + 0] = rep_val;
				d->u.l.lens[i + 1] = rep_val;
				d->u.l.lens[i + 2] = rep_val;
				d->u.l.lens[i + 3] = rep_val;
				d->u.l.lens[i + 4] = rep_val;
				d->u.l.lens[i + 5] = rep_val;
				i += rep_count;
			} else if (presym == 17) {
				
				STATIC_ASSERT(3 + BITMASK(3) == 10);
				rep_count = 3 + (bitbuf & BITMASK(3));
				bitbuf >>= 3;
				bitsleft -= 3;
				d->u.l.lens[i + 0] = 0;
				d->u.l.lens[i + 1] = 0;
				d->u.l.lens[i + 2] = 0;
				d->u.l.lens[i + 3] = 0;
				d->u.l.lens[i + 4] = 0;
				d->u.l.lens[i + 5] = 0;
				d->u.l.lens[i + 6] = 0;
				d->u.l.lens[i + 7] = 0;
				d->u.l.lens[i + 8] = 0;
				d->u.l.lens[i + 9] = 0;
				i += rep_count;
			} else {
				
				STATIC_ASSERT(11 + BITMASK(7) == 138);
				rep_count = 11 + (bitbuf & BITMASK(7));
				bitbuf >>= 7;
				bitsleft -= 7;
				memset(&d->u.l.lens[i], 0,
				       rep_count * sizeof(d->u.l.lens[i]));
				i += rep_count;
			}
		} while (i < num_litlen_syms + num_offset_syms);

		
		SAFETY_CHECK(i == num_litlen_syms + num_offset_syms);

	} else if (block_type == DEFLATE_BLOCKTYPE_UNCOMPRESSED) {
		u16 len, nlen;

		

		bitsleft -= 3; 

		
		bitsleft = (u8)bitsleft;
		SAFETY_CHECK(overread_count <= (bitsleft >> 3));
		in_next -= (bitsleft >> 3) - overread_count;
		overread_count = 0;
		bitbuf = 0;
		bitsleft = 0;

		SAFETY_CHECK(in_end - in_next >= 4);
		len = get_unaligned_le16(in_next);
		nlen = get_unaligned_le16(in_next + 2);
		in_next += 4;

		SAFETY_CHECK(len == (u16)~nlen);
		if (unlikely(len > out_end - out_next))
			return LIBDEFLATE_INSUFFICIENT_SPACE;
		SAFETY_CHECK(len <= in_end - in_next);

		memcpy(out_next, in_next, len);
		in_next += len;
		out_next += len;

		goto block_done;

	} else {
		unsigned i;

		SAFETY_CHECK(block_type == DEFLATE_BLOCKTYPE_STATIC_HUFFMAN);

		

		bitbuf >>= 3; 
		bitsleft -= 3;

		if (d->static_codes_loaded)
			goto have_decode_tables;

		d->static_codes_loaded = true;

		STATIC_ASSERT(DEFLATE_NUM_LITLEN_SYMS == 288);
		STATIC_ASSERT(DEFLATE_NUM_OFFSET_SYMS == 32);

		for (i = 0; i < 144; i++)
			d->u.l.lens[i] = 8;
		for (; i < 256; i++)
			d->u.l.lens[i] = 9;
		for (; i < 280; i++)
			d->u.l.lens[i] = 7;
		for (; i < 288; i++)
			d->u.l.lens[i] = 8;

		for (; i < 288 + 32; i++)
			d->u.l.lens[i] = 5;

		num_litlen_syms = 288;
		num_offset_syms = 32;
	}

	

	SAFETY_CHECK(build_offset_decode_table(d, num_litlen_syms, num_offset_syms));
	SAFETY_CHECK(build_litlen_decode_table(d, num_litlen_syms, num_offset_syms));
have_decode_tables:
	litlen_tablemask = BITMASK(d->litlen_tablebits);

	
	if (in_next >= in_fastloop_end || out_next >= out_fastloop_end)
		goto generic_loop;
	REFILL_BITS_IN_FASTLOOP();
	entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
	do {
		u32 length, offset, lit;
		const u8 *src;
		u8 *dst;

		
		saved_bitbuf = bitbuf;
		bitbuf >>= (u8)entry;
		bitsleft -= entry; 

		
		if (entry & HUFFDEC_LITERAL) {
			
			if (
			    CAN_CONSUME_AND_THEN_PRELOAD(2 * LITLEN_TABLEBITS +
							 LENGTH_MAXBITS,
							 OFFSET_TABLEBITS) &&
			    
			    CAN_CONSUME_AND_THEN_PRELOAD(2 * LITLEN_TABLEBITS +
							 DEFLATE_MAX_LITLEN_CODEWORD_LEN,
							 LITLEN_TABLEBITS)) {
				
				lit = entry >> 16;
				entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
				saved_bitbuf = bitbuf;
				bitbuf >>= (u8)entry;
				bitsleft -= entry;
				*out_next++ = lit;
				if (entry & HUFFDEC_LITERAL) {
					
					lit = entry >> 16;
					entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
					saved_bitbuf = bitbuf;
					bitbuf >>= (u8)entry;
					bitsleft -= entry;
					*out_next++ = lit;
					if (entry & HUFFDEC_LITERAL) {
						
						lit = entry >> 16;
						entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
						REFILL_BITS_IN_FASTLOOP();
						*out_next++ = lit;
						continue;
					}
				}
			} else {
				
				STATIC_ASSERT(CAN_CONSUME_AND_THEN_PRELOAD(
						LITLEN_TABLEBITS, LITLEN_TABLEBITS));
				lit = entry >> 16;
				entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
				REFILL_BITS_IN_FASTLOOP();
				*out_next++ = lit;
				continue;
			}
		}

		
		if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
			

			if (unlikely(entry & HUFFDEC_END_OF_BLOCK))
				goto block_done;

			
			entry = d->u.litlen_decode_table[(entry >> 16) +
				EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			saved_bitbuf = bitbuf;
			bitbuf >>= (u8)entry;
			bitsleft -= entry;

			
			if (!CAN_CONSUME_AND_THEN_PRELOAD(DEFLATE_MAX_LITLEN_CODEWORD_LEN,
							  LITLEN_TABLEBITS) ||
			    !CAN_CONSUME_AND_THEN_PRELOAD(LENGTH_MAXBITS,
							  OFFSET_TABLEBITS))
				REFILL_BITS_IN_FASTLOOP();
			if (entry & HUFFDEC_LITERAL) {
				
				lit = entry >> 16;
				entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
				REFILL_BITS_IN_FASTLOOP();
				*out_next++ = lit;
				continue;
			}
			if (unlikely(entry & HUFFDEC_END_OF_BLOCK))
				goto block_done;
			
		}

		
		length = entry >> 16;
		length += EXTRACT_VARBITS8(saved_bitbuf, entry) >> (u8)(entry >> 8);

		
		STATIC_ASSERT(CAN_CONSUME_AND_THEN_PRELOAD(LENGTH_MAXFASTBITS,
							   OFFSET_TABLEBITS));
		entry = d->offset_decode_table[bitbuf & BITMASK(OFFSET_TABLEBITS)];
		if (CAN_CONSUME_AND_THEN_PRELOAD(OFFSET_MAXBITS,
						 LITLEN_TABLEBITS)) {
			
			if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
				
				if (unlikely((u8)bitsleft < OFFSET_MAXBITS +
					     LITLEN_TABLEBITS - PRELOAD_SLACK))
					REFILL_BITS_IN_FASTLOOP();
				bitbuf >>= OFFSET_TABLEBITS;
				bitsleft -= OFFSET_TABLEBITS;
				entry = d->offset_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			} else if (unlikely((u8)bitsleft < OFFSET_MAXFASTBITS +
					    LITLEN_TABLEBITS - PRELOAD_SLACK))
				REFILL_BITS_IN_FASTLOOP();
		} else {
			
			REFILL_BITS_IN_FASTLOOP();
			if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
				
				bitbuf >>= OFFSET_TABLEBITS;
				bitsleft -= OFFSET_TABLEBITS;
				entry = d->offset_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
				REFILL_BITS_IN_FASTLOOP();
				
				STATIC_ASSERT(CAN_CONSUME(
					OFFSET_MAXBITS - OFFSET_TABLEBITS));
			} else {
				
				STATIC_ASSERT(CAN_CONSUME(OFFSET_MAXFASTBITS));
			}
		}
		saved_bitbuf = bitbuf;
		bitbuf >>= (u8)entry;
		bitsleft -= entry; 
		offset = entry >> 16;
		offset += EXTRACT_VARBITS8(saved_bitbuf, entry) >> (u8)(entry >> 8);

		
		SAFETY_CHECK(offset <= out_next - (const u8 *)out);
		src = out_next - offset;
		dst = out_next;
		out_next += length;

		
		if (!CAN_CONSUME_AND_THEN_PRELOAD(
			MAX(OFFSET_MAXBITS - OFFSET_TABLEBITS,
			    OFFSET_MAXFASTBITS),
			LITLEN_TABLEBITS) &&
		    unlikely((u8)bitsleft < LITLEN_TABLEBITS - PRELOAD_SLACK))
			REFILL_BITS_IN_FASTLOOP();
		entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
		REFILL_BITS_IN_FASTLOOP();

		
		if (UNALIGNED_ACCESS_IS_FAST && offset >= WORDBYTES) {
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += WORDBYTES;
			dst += WORDBYTES;
			while (dst < out_next) {
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += WORDBYTES;
				dst += WORDBYTES;
			}
		} else if (UNALIGNED_ACCESS_IS_FAST && offset == 1) {
			machine_word_t v;

			
			v = (machine_word_t)0x0101010101010101 * src[0];
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			store_word_unaligned(v, dst);
			dst += WORDBYTES;
			while (dst < out_next) {
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
				store_word_unaligned(v, dst);
				dst += WORDBYTES;
			}
		} else if (UNALIGNED_ACCESS_IS_FAST) {
			store_word_unaligned(load_word_unaligned(src), dst);
			src += offset;
			dst += offset;
			store_word_unaligned(load_word_unaligned(src), dst);
			src += offset;
			dst += offset;
			do {
				store_word_unaligned(load_word_unaligned(src), dst);
				src += offset;
				dst += offset;
				store_word_unaligned(load_word_unaligned(src), dst);
				src += offset;
				dst += offset;
			} while (dst < out_next);
		} else {
			*dst++ = *src++;
			*dst++ = *src++;
			do {
				*dst++ = *src++;
			} while (dst < out_next);
		}
	} while (in_next < in_fastloop_end && out_next < out_fastloop_end);

	
generic_loop:
	for (;;) {
		u32 length, offset;
		const u8 *src;
		u8 *dst;

		REFILL_BITS();
		entry = d->u.litlen_decode_table[bitbuf & litlen_tablemask];
		saved_bitbuf = bitbuf;
		bitbuf >>= (u8)entry;
		bitsleft -= entry;
		if (unlikely(entry & HUFFDEC_SUBTABLE_POINTER)) {
			entry = d->u.litlen_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			saved_bitbuf = bitbuf;
			bitbuf >>= (u8)entry;
			bitsleft -= entry;
		}
		length = entry >> 16;
		if (entry & HUFFDEC_LITERAL) {
			if (unlikely(out_next == out_end))
				return LIBDEFLATE_INSUFFICIENT_SPACE;
			*out_next++ = length;
			continue;
		}
		if (unlikely(entry & HUFFDEC_END_OF_BLOCK))
			goto block_done;
		length += EXTRACT_VARBITS8(saved_bitbuf, entry) >> (u8)(entry >> 8);
		if (unlikely(length > out_end - out_next))
			return LIBDEFLATE_INSUFFICIENT_SPACE;

		if (!CAN_CONSUME(LENGTH_MAXBITS + OFFSET_MAXBITS))
			REFILL_BITS();
		entry = d->offset_decode_table[bitbuf & BITMASK(OFFSET_TABLEBITS)];
		if (unlikely(entry & HUFFDEC_EXCEPTIONAL)) {
			bitbuf >>= OFFSET_TABLEBITS;
			bitsleft -= OFFSET_TABLEBITS;
			entry = d->offset_decode_table[(entry >> 16) +
					EXTRACT_VARBITS(bitbuf, (entry >> 8) & 0x3F)];
			if (!CAN_CONSUME(OFFSET_MAXBITS))
				REFILL_BITS();
		}
		offset = entry >> 16;
		offset += EXTRACT_VARBITS8(bitbuf, entry) >> (u8)(entry >> 8);
		bitbuf >>= (u8)entry;
		bitsleft -= entry;

		SAFETY_CHECK(offset <= out_next - (const u8 *)out);
		src = out_next - offset;
		dst = out_next;
		out_next += length;

		STATIC_ASSERT(DEFLATE_MIN_MATCH_LEN == 3);
		*dst++ = *src++;
		*dst++ = *src++;
		do {
			*dst++ = *src++;
		} while (dst < out_next);
	}

block_done:
	

	if (!is_final_block)
		goto next_block;

	

	bitsleft = (u8)bitsleft;

	
	SAFETY_CHECK(overread_count <= (bitsleft >> 3));

	
	if (actual_in_nbytes_ret) {
		
		in_next -= (bitsleft >> 3) - overread_count;

		*actual_in_nbytes_ret = in_next - (u8 *)in;
	}

	
	if (actual_out_nbytes_ret) {
		*actual_out_nbytes_ret = out_next - (u8 *)out;
	} else {
		if (out_next != out_end)
			return LIBDEFLATE_SHORT_OUTPUT;
	}
	return LIBDEFLATE_SUCCESS;
}

#undef FUNCNAME
#undef ATTRIBUTES
#undef EXTRACT_VARBITS
#undef EXTRACT_VARBITS8

#endif

#if defined(deflate_decompress_bmi2) && HAVE_BMI2_NATIVE
#define DEFAULT_IMPL	deflate_decompress_bmi2
#else
static inline decompress_func_t
arch_select_decompress_func(void)
{
#ifdef deflate_decompress_bmi2
	if (HAVE_BMI2(get_x86_cpu_features()))
		return deflate_decompress_bmi2;
#endif
	return NULL;
}
#define arch_select_decompress_func	arch_select_decompress_func
#endif

#endif 

#endif

#ifndef DEFAULT_IMPL
#  define DEFAULT_IMPL deflate_decompress_default
#endif

#ifdef arch_select_decompress_func
static enum libdeflate_result
dispatch_decomp(struct libdeflate_decompressor *d,
		const void *in, size_t in_nbytes,
		void *out, size_t out_nbytes_avail,
		size_t *actual_in_nbytes_ret, size_t *actual_out_nbytes_ret);

static volatile decompress_func_t decompress_impl = dispatch_decomp;


static enum libdeflate_result
dispatch_decomp(struct libdeflate_decompressor *d,
		const void *in, size_t in_nbytes,
		void *out, size_t out_nbytes_avail,
		size_t *actual_in_nbytes_ret, size_t *actual_out_nbytes_ret)
{
	decompress_func_t f = arch_select_decompress_func();

	if (f == NULL)
		f = DEFAULT_IMPL;

	decompress_impl = f;
	return f(d, in, in_nbytes, out, out_nbytes_avail,
		 actual_in_nbytes_ret, actual_out_nbytes_ret);
}
#else

#  define decompress_impl DEFAULT_IMPL
#endif


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *d,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret)
{
	return decompress_impl(d, in, in_nbytes, out, out_nbytes_avail,
			       actual_in_nbytes_ret, actual_out_nbytes_ret);
}

LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *d,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret)
{
	return libdeflate_deflate_decompress_ex(d, in, in_nbytes,
						out, out_nbytes_avail,
						NULL, actual_out_nbytes_ret);
}

LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options)
{
	struct libdeflate_decompressor *d;

	
	if (options->sizeof_options != sizeof(*options))
		return NULL;

	d = (options->malloc_func ? options->malloc_func :
	     libdeflate_default_malloc_func)(sizeof(*d));
	if (d == NULL)
		return NULL;
	
	memset(d, 0, sizeof(*d));
	d->free_func = options->free_func ?
		       options->free_func : libdeflate_default_free_func;
	return d;
}

LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void)
{
	static const struct libdeflate_options defaults = {
		.sizeof_options = sizeof(defaults),
	};
	return libdeflate_alloc_decompressor_ex(&defaults);
}

LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *d)
{
	if (d)
		d->free_func(d);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/gzip_compress.c */


/* #include "deflate_compress.h" */
#ifndef LIB_DEFLATE_COMPRESS_H
#define LIB_DEFLATE_COMPRESS_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 




struct libdeflate_compressor;

unsigned int libdeflate_get_compression_level(struct libdeflate_compressor *c);

#endif 

/* #include "gzip_constants.h" */


#ifndef LIB_GZIP_CONSTANTS_H
#define LIB_GZIP_CONSTANTS_H

#define GZIP_MIN_HEADER_SIZE	10
#define GZIP_FOOTER_SIZE	8
#define GZIP_MIN_OVERHEAD	(GZIP_MIN_HEADER_SIZE + GZIP_FOOTER_SIZE)

#define GZIP_ID1		0x1F
#define GZIP_ID2		0x8B

#define GZIP_CM_DEFLATE		8

#define GZIP_FTEXT		0x01
#define GZIP_FHCRC		0x02
#define GZIP_FEXTRA		0x04
#define GZIP_FNAME		0x08
#define GZIP_FCOMMENT		0x10
#define GZIP_FRESERVED		0xE0

#define GZIP_MTIME_UNAVAILABLE	0

#define GZIP_XFL_SLOWEST_COMPRESSION	0x02
#define GZIP_XFL_FASTEST_COMPRESSION	0x04

#define GZIP_OS_FAT		0
#define GZIP_OS_AMIGA		1
#define GZIP_OS_VMS		2
#define GZIP_OS_UNIX		3
#define GZIP_OS_VM_CMS		4
#define GZIP_OS_ATARI_TOS	5
#define GZIP_OS_HPFS		6
#define GZIP_OS_MACINTOSH	7
#define GZIP_OS_Z_SYSTEM	8
#define GZIP_OS_CP_M		9
#define GZIP_OS_TOPS_20		10
#define GZIP_OS_NTFS		11
#define GZIP_OS_QDOS		12
#define GZIP_OS_RISCOS		13
#define GZIP_OS_UNKNOWN		255

#endif 


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *c,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail)
{
	u8 *out_next = out;
	unsigned compression_level;
	u8 xfl;
	size_t deflate_size;

	if (out_nbytes_avail <= GZIP_MIN_OVERHEAD)
		return 0;

	
	*out_next++ = GZIP_ID1;
	
	*out_next++ = GZIP_ID2;
	
	*out_next++ = GZIP_CM_DEFLATE;
	
	*out_next++ = 0;
	
	put_unaligned_le32(GZIP_MTIME_UNAVAILABLE, out_next);
	out_next += 4;
	
	xfl = 0;
	compression_level = libdeflate_get_compression_level(c);
	if (compression_level < 2)
		xfl |= GZIP_XFL_FASTEST_COMPRESSION;
	else if (compression_level >= 8)
		xfl |= GZIP_XFL_SLOWEST_COMPRESSION;
	*out_next++ = xfl;
	
	*out_next++ = GZIP_OS_UNKNOWN;	

	
	deflate_size = libdeflate_deflate_compress(c, in, in_nbytes, out_next,
					out_nbytes_avail - GZIP_MIN_OVERHEAD);
	if (deflate_size == 0)
		return 0;
	out_next += deflate_size;

	
	put_unaligned_le32(libdeflate_crc32(0, in, in_nbytes), out_next);
	out_next += 4;

	
	put_unaligned_le32((u32)in_nbytes, out_next);
	out_next += 4;

	return out_next - (u8 *)out;
}

LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *c,
			       size_t in_nbytes)
{
	return GZIP_MIN_OVERHEAD +
	       libdeflate_deflate_compress_bound(c, in_nbytes);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/gzip_decompress.c */


/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 

/* #include "gzip_constants.h" */


#ifndef LIB_GZIP_CONSTANTS_H
#define LIB_GZIP_CONSTANTS_H

#define GZIP_MIN_HEADER_SIZE	10
#define GZIP_FOOTER_SIZE	8
#define GZIP_MIN_OVERHEAD	(GZIP_MIN_HEADER_SIZE + GZIP_FOOTER_SIZE)

#define GZIP_ID1		0x1F
#define GZIP_ID2		0x8B

#define GZIP_CM_DEFLATE		8

#define GZIP_FTEXT		0x01
#define GZIP_FHCRC		0x02
#define GZIP_FEXTRA		0x04
#define GZIP_FNAME		0x08
#define GZIP_FCOMMENT		0x10
#define GZIP_FRESERVED		0xE0

#define GZIP_MTIME_UNAVAILABLE	0

#define GZIP_XFL_SLOWEST_COMPRESSION	0x02
#define GZIP_XFL_FASTEST_COMPRESSION	0x04

#define GZIP_OS_FAT		0
#define GZIP_OS_AMIGA		1
#define GZIP_OS_VMS		2
#define GZIP_OS_UNIX		3
#define GZIP_OS_VM_CMS		4
#define GZIP_OS_ATARI_TOS	5
#define GZIP_OS_HPFS		6
#define GZIP_OS_MACINTOSH	7
#define GZIP_OS_Z_SYSTEM	8
#define GZIP_OS_CP_M		9
#define GZIP_OS_TOPS_20		10
#define GZIP_OS_NTFS		11
#define GZIP_OS_QDOS		12
#define GZIP_OS_RISCOS		13
#define GZIP_OS_UNKNOWN		255

#endif 


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *d,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret)
{
	const u8 *in_next = in;
	const u8 * const in_end = in_next + in_nbytes;
	u8 flg;
	size_t actual_in_nbytes;
	size_t actual_out_nbytes;
	enum libdeflate_result result;

	if (in_nbytes < GZIP_MIN_OVERHEAD)
		return LIBDEFLATE_BAD_DATA;

	
	if (*in_next++ != GZIP_ID1)
		return LIBDEFLATE_BAD_DATA;
	
	if (*in_next++ != GZIP_ID2)
		return LIBDEFLATE_BAD_DATA;
	
	if (*in_next++ != GZIP_CM_DEFLATE)
		return LIBDEFLATE_BAD_DATA;
	flg = *in_next++;
	
	in_next += 4;
	
	in_next += 1;
	
	in_next += 1;

	if (flg & GZIP_FRESERVED)
		return LIBDEFLATE_BAD_DATA;

	
	if (flg & GZIP_FEXTRA) {
		u16 xlen = get_unaligned_le16(in_next);
		in_next += 2;

		if (in_end - in_next < (u32)xlen + GZIP_FOOTER_SIZE)
			return LIBDEFLATE_BAD_DATA;

		in_next += xlen;
	}

	
	if (flg & GZIP_FNAME) {
		while (*in_next++ != 0 && in_next != in_end)
			;
		if (in_end - in_next < GZIP_FOOTER_SIZE)
			return LIBDEFLATE_BAD_DATA;
	}

	
	if (flg & GZIP_FCOMMENT) {
		while (*in_next++ != 0 && in_next != in_end)
			;
		if (in_end - in_next < GZIP_FOOTER_SIZE)
			return LIBDEFLATE_BAD_DATA;
	}

	
	if (flg & GZIP_FHCRC) {
		in_next += 2;
		if (in_end - in_next < GZIP_FOOTER_SIZE)
			return LIBDEFLATE_BAD_DATA;
	}

	
	result = libdeflate_deflate_decompress_ex(d, in_next,
					in_end - GZIP_FOOTER_SIZE - in_next,
					out, out_nbytes_avail,
					&actual_in_nbytes,
					actual_out_nbytes_ret);
	if (result != LIBDEFLATE_SUCCESS)
		return result;

	if (actual_out_nbytes_ret)
		actual_out_nbytes = *actual_out_nbytes_ret;
	else
		actual_out_nbytes = out_nbytes_avail;

	in_next += actual_in_nbytes;

	
	if (libdeflate_crc32(0, out, actual_out_nbytes) !=
	    get_unaligned_le32(in_next))
		return LIBDEFLATE_BAD_DATA;
	in_next += 4;

	
	if ((u32)actual_out_nbytes != get_unaligned_le32(in_next))
		return LIBDEFLATE_BAD_DATA;
	in_next += 4;

	if (actual_in_nbytes_ret)
		*actual_in_nbytes_ret = in_next - (u8 *)in;

	return LIBDEFLATE_SUCCESS;
}

LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *d,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret)
{
	return libdeflate_gzip_decompress_ex(d, in, in_nbytes,
					     out, out_nbytes_avail,
					     NULL, actual_out_nbytes_ret);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/utils.c */


/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#ifdef FREESTANDING
#  define malloc NULL
#  define free NULL
#else
#  include <stdlib.h>
#endif

malloc_func_t libdeflate_default_malloc_func = malloc;
free_func_t libdeflate_default_free_func = free;

void *
libdeflate_aligned_malloc(malloc_func_t malloc_func,
			  size_t alignment, size_t size)
{
	void *ptr = (*malloc_func)(sizeof(void *) + alignment - 1 + size);

	if (ptr) {
		void *orig_ptr = ptr;

		ptr = (void *)ALIGN((uintptr_t)ptr + sizeof(void *), alignment);
		((void **)ptr)[-1] = orig_ptr;
	}
	return ptr;
}

void
libdeflate_aligned_free(free_func_t free_func, void *ptr)
{
	(*free_func)(((void **)ptr)[-1]);
}

LIBDEFLATEAPI void
libdeflate_set_memory_allocator(malloc_func_t malloc_func,
				free_func_t free_func)
{
	libdeflate_default_malloc_func = malloc_func;
	libdeflate_default_free_func = free_func;
}


#ifdef FREESTANDING
#undef memset
void * __attribute__((weak))
memset(void *s, int c, size_t n)
{
	u8 *p = s;
	size_t i;

	for (i = 0; i < n; i++)
		p[i] = c;
	return s;
}

#undef memcpy
void * __attribute__((weak))
memcpy(void *dest, const void *src, size_t n)
{
	u8 *d = dest;
	const u8 *s = src;
	size_t i;

	for (i = 0; i < n; i++)
		d[i] = s[i];
	return dest;
}

#undef memmove
void * __attribute__((weak))
memmove(void *dest, const void *src, size_t n)
{
	u8 *d = dest;
	const u8 *s = src;
	size_t i;

	if (d <= s)
		return memcpy(d, s, n);

	for (i = n; i > 0; i--)
		d[i - 1] = s[i - 1];
	return dest;
}

#undef memcmp
int __attribute__((weak))
memcmp(const void *s1, const void *s2, size_t n)
{
	const u8 *p1 = s1;
	const u8 *p2 = s2;
	size_t i;

	for (i = 0; i < n; i++) {
		if (p1[i] != p2[i])
			return (int)p1[i] - (int)p2[i];
	}
	return 0;
}
#endif 

#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
#include <stdio.h>
#include <stdlib.h>
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line)
{
	fprintf(stderr, "Assertion failed: %s at %s:%d\n", expr, file, line);
	abort();
}
#endif 
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/zlib_compress.c */


/* #include "deflate_compress.h" */
#ifndef LIB_DEFLATE_COMPRESS_H
#define LIB_DEFLATE_COMPRESS_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 




struct libdeflate_compressor;

unsigned int libdeflate_get_compression_level(struct libdeflate_compressor *c);

#endif 

/* #include "zlib_constants.h" */


#ifndef LIB_ZLIB_CONSTANTS_H
#define LIB_ZLIB_CONSTANTS_H

#define ZLIB_MIN_HEADER_SIZE	2
#define ZLIB_FOOTER_SIZE	4
#define ZLIB_MIN_OVERHEAD	(ZLIB_MIN_HEADER_SIZE + ZLIB_FOOTER_SIZE)

#define ZLIB_CM_DEFLATE		8

#define ZLIB_CINFO_32K_WINDOW	7

#define ZLIB_FASTEST_COMPRESSION	0
#define ZLIB_FAST_COMPRESSION		1
#define ZLIB_DEFAULT_COMPRESSION	2
#define ZLIB_SLOWEST_COMPRESSION	3

#endif 


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *c,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail)
{
	u8 *out_next = out;
	u16 hdr;
	unsigned compression_level;
	unsigned level_hint;
	size_t deflate_size;

	if (out_nbytes_avail <= ZLIB_MIN_OVERHEAD)
		return 0;

	
	hdr = (ZLIB_CM_DEFLATE << 8) | (ZLIB_CINFO_32K_WINDOW << 12);
	compression_level = libdeflate_get_compression_level(c);
	if (compression_level < 2)
		level_hint = ZLIB_FASTEST_COMPRESSION;
	else if (compression_level < 6)
		level_hint = ZLIB_FAST_COMPRESSION;
	else if (compression_level < 8)
		level_hint = ZLIB_DEFAULT_COMPRESSION;
	else
		level_hint = ZLIB_SLOWEST_COMPRESSION;
	hdr |= level_hint << 6;
	hdr |= 31 - (hdr % 31);

	put_unaligned_be16(hdr, out_next);
	out_next += 2;

	
	deflate_size = libdeflate_deflate_compress(c, in, in_nbytes, out_next,
					out_nbytes_avail - ZLIB_MIN_OVERHEAD);
	if (deflate_size == 0)
		return 0;
	out_next += deflate_size;

	
	put_unaligned_be32(libdeflate_adler32(1, in, in_nbytes), out_next);
	out_next += 4;

	return out_next - (u8 *)out;
}

LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *c,
			       size_t in_nbytes)
{
	return ZLIB_MIN_OVERHEAD +
	       libdeflate_deflate_compress_bound(c, in_nbytes);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/zlib_decompress.c */


/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 

/* #include "zlib_constants.h" */


#ifndef LIB_ZLIB_CONSTANTS_H
#define LIB_ZLIB_CONSTANTS_H

#define ZLIB_MIN_HEADER_SIZE	2
#define ZLIB_FOOTER_SIZE	4
#define ZLIB_MIN_OVERHEAD	(ZLIB_MIN_HEADER_SIZE + ZLIB_FOOTER_SIZE)

#define ZLIB_CM_DEFLATE		8

#define ZLIB_CINFO_32K_WINDOW	7

#define ZLIB_FASTEST_COMPRESSION	0
#define ZLIB_FAST_COMPRESSION		1
#define ZLIB_DEFAULT_COMPRESSION	2
#define ZLIB_SLOWEST_COMPRESSION	3

#endif 


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *d,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret)
{
	const u8 *in_next = in;
	const u8 * const in_end = in_next + in_nbytes;
	u16 hdr;
	size_t actual_in_nbytes;
	size_t actual_out_nbytes;
	enum libdeflate_result result;

	if (in_nbytes < ZLIB_MIN_OVERHEAD)
		return LIBDEFLATE_BAD_DATA;

	
	hdr = get_unaligned_be16(in_next);
	in_next += 2;

	
	if ((hdr % 31) != 0)
		return LIBDEFLATE_BAD_DATA;

	
	if (((hdr >> 8) & 0xF) != ZLIB_CM_DEFLATE)
		return LIBDEFLATE_BAD_DATA;

	
	if ((hdr >> 12) > ZLIB_CINFO_32K_WINDOW)
		return LIBDEFLATE_BAD_DATA;

	
	if ((hdr >> 5) & 1)
		return LIBDEFLATE_BAD_DATA;

	
	result = libdeflate_deflate_decompress_ex(d, in_next,
					in_end - ZLIB_FOOTER_SIZE - in_next,
					out, out_nbytes_avail,
					&actual_in_nbytes, actual_out_nbytes_ret);
	if (result != LIBDEFLATE_SUCCESS)
		return result;

	if (actual_out_nbytes_ret)
		actual_out_nbytes = *actual_out_nbytes_ret;
	else
		actual_out_nbytes = out_nbytes_avail;

	in_next += actual_in_nbytes;

	
	if (libdeflate_adler32(1, out, actual_out_nbytes) !=
	    get_unaligned_be32(in_next))
		return LIBDEFLATE_BAD_DATA;
	in_next += 4;

	if (actual_in_nbytes_ret)
		*actual_in_nbytes_ret = in_next - (u8 *)in;

	return LIBDEFLATE_SUCCESS;
}

LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *d,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret)
{
	return libdeflate_zlib_decompress_ex(d, in, in_nbytes,
					     out, out_nbytes_avail,
					     NULL, actual_out_nbytes_ret);
}
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/arm/cpu_features.c */




#ifdef __APPLE__
#  undef _ANSI_SOURCE
#  undef _DARWIN_C_SOURCE
#  define _DARWIN_C_SOURCE 
#endif

/* #include "cpu_features_common.h" */


#ifndef LIB_CPU_FEATURES_COMMON_H
#define LIB_CPU_FEATURES_COMMON_H

#if defined(TEST_SUPPORT__DO_NOT_USE) && !defined(FREESTANDING)
   
#  undef _ANSI_SOURCE
#  ifndef __APPLE__
#    undef _GNU_SOURCE
#    define _GNU_SOURCE
#  endif
#  include <stdio.h>
#  include <stdlib.h>
#  include <string.h>
#endif

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


struct cpu_feature {
	u32 bit;
	const char *name;
};

#if defined(TEST_SUPPORT__DO_NOT_USE) && !defined(FREESTANDING)

static inline void
disable_cpu_features_for_testing(u32 *features,
				 const struct cpu_feature *feature_table,
				 size_t feature_table_length)
{
	char *env_value, *strbuf, *p, *saveptr = NULL;
	size_t i;

	env_value = getenv("LIBDEFLATE_DISABLE_CPU_FEATURES");
	if (!env_value)
		return;
	strbuf = strdup(env_value);
	if (!strbuf)
		abort();
	p = strtok_r(strbuf, ",", &saveptr);
	while (p) {
		for (i = 0; i < feature_table_length; i++) {
			if (strcmp(p, feature_table[i].name) == 0) {
				*features &= ~feature_table[i].bit;
				break;
			}
		}
		if (i == feature_table_length) {
			fprintf(stderr,
				"unrecognized feature in LIBDEFLATE_DISABLE_CPU_FEATURES: \"%s\"\n",
				p);
			abort();
		}
		p = strtok_r(NULL, ",", &saveptr);
	}
	free(strbuf);
}
#else 
static inline void
disable_cpu_features_for_testing(u32 *features,
				 const struct cpu_feature *feature_table,
				 size_t feature_table_length)
{
}
#endif 

#endif 
 
/* #include "arm-cpu_features.h" */


#ifndef LIB_ARM_CPU_FEATURES_H
#define LIB_ARM_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_ARM32) || defined(ARCH_ARM64)

#define ARM_CPU_FEATURE_NEON		(1 << 0)
#define ARM_CPU_FEATURE_PMULL		(1 << 1)

#define ARM_CPU_FEATURE_PREFER_PMULL	(1 << 2)
#define ARM_CPU_FEATURE_CRC32		(1 << 3)
#define ARM_CPU_FEATURE_SHA3		(1 << 4)
#define ARM_CPU_FEATURE_DOTPROD		(1 << 5)

#if !defined(FREESTANDING) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
    (defined(__linux__) || \
     (defined(__APPLE__) && defined(ARCH_ARM64)) || \
     (defined(_WIN32) && defined(ARCH_ARM64)))

#  define ARM_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_arm_cpu_features;

void libdeflate_init_arm_cpu_features(void);

static inline u32 get_arm_cpu_features(void)
{
	if (libdeflate_arm_cpu_features == 0)
		libdeflate_init_arm_cpu_features();
	return libdeflate_arm_cpu_features;
}
#else
static inline u32 get_arm_cpu_features(void) { return 0; }
#endif


#if defined(__ARM_NEON) || (defined(_MSC_VER) && defined(ARCH_ARM64))
#  define HAVE_NEON(features)	1
#  define HAVE_NEON_NATIVE	1
#else
#  define HAVE_NEON(features)	((features) & ARM_CPU_FEATURE_NEON)
#  define HAVE_NEON_NATIVE	0
#endif

#if (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)) && \
	(HAVE_NEON_NATIVE || (GCC_PREREQ(6, 1) && defined(__ARM_FP)))
#  define HAVE_NEON_INTRIN	1
#  include <arm_neon.h>
#else
#  define HAVE_NEON_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRYPTO
#  define HAVE_PMULL(features)	1
#else
#  define HAVE_PMULL(features)	((features) & ARM_CPU_FEATURE_PMULL)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(7, 1) || defined(__clang__) || defined(_MSC_VER)) && \
	CPU_IS_LITTLE_ENDIAN() 
#  define HAVE_PMULL_INTRIN	1
   
#  ifdef _MSC_VER
#    define compat_vmull_p64(a, b)  vmull_p64(vcreate_p64(a), vcreate_p64(b))
#  else
#    define compat_vmull_p64(a, b)  vmull_p64((a), (b))
#  endif
#else
#  define HAVE_PMULL_INTRIN	0
#endif


#ifdef __ARM_FEATURE_CRC32
#  define HAVE_CRC32(features)	1
#else
#  define HAVE_CRC32(features)	((features) & ARM_CPU_FEATURE_CRC32)
#endif
#if defined(ARCH_ARM64) && \
	(defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))
#  define HAVE_CRC32_INTRIN	1
#  if defined(__GNUC__) || defined(__clang__)
#    include <arm_acle.h>
#  endif
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_CRC32)
#    undef __crc32b
#    define __crc32b(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32b %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32h
#    define __crc32h(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32h %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32w
#    define __crc32w(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32w %w0, %w1, %w2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    undef __crc32d
#    define __crc32d(a, b)					\
	({ uint32_t res;					\
	   __asm__("crc32x %w0, %w1, %2"			\
		   : "=r" (res) : "r" (a), "r" (b));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_CRC32_INTRIN	0
#endif


#ifdef __ARM_FEATURE_SHA3
#  define HAVE_SHA3(features)	1
#else
#  define HAVE_SHA3(features)	((features) & ARM_CPU_FEATURE_SHA3)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(9, 1)  || \
	 CLANG_PREREQ(7, 0, 10010463) )
#  define HAVE_SHA3_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_SHA3)
#    undef veor3q_u8
#    define veor3q_u8(a, b, c)					\
	({ uint8x16_t res;					\
	   __asm__("eor3 %0.16b, %1.16b, %2.16b, %3.16b"	\
		   : "=w" (res) : "w" (a), "w" (b), "w" (c));	\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_SHA3_INTRIN	0
#endif


#ifdef __ARM_FEATURE_DOTPROD
#  define HAVE_DOTPROD(features)	1
#else
#  define HAVE_DOTPROD(features)	((features) & ARM_CPU_FEATURE_DOTPROD)
#endif
#if defined(ARCH_ARM64) && HAVE_NEON_INTRIN && \
	(GCC_PREREQ(8, 1) || CLANG_PREREQ(7, 0, 10010000) || defined(_MSC_VER))
#  define HAVE_DOTPROD_INTRIN	1
   
#  if defined(__clang__) && !CLANG_PREREQ(16, 0, 16000000) && \
	!defined(__ARM_FEATURE_DOTPROD)
#    undef vdotq_u32
#    define vdotq_u32(a, b, c)					\
	({ uint32x4_t res = (a);				\
	   __asm__("udot %0.4s, %1.16b, %2.16b"			\
		   : "+w" (res) : "w" (b), "w" (c));		\
	   res; })
#    pragma clang diagnostic ignored "-Wgnu-statement-expression"
#  endif
#else
#  define HAVE_DOTPROD_INTRIN	0
#endif

#endif 

#endif 


#ifdef ARM_CPU_FEATURES_KNOWN


#ifdef __linux__


#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

#define AT_HWCAP	16
#define AT_HWCAP2	26

static void scan_auxv(unsigned long *hwcap, unsigned long *hwcap2)
{
	int fd;
	unsigned long auxbuf[32];
	int filled = 0;
	int i;

	fd = open("/proc/self/auxv", O_RDONLY);
	if (fd < 0)
		return;

	for (;;) {
		do {
			int ret = read(fd, &((char *)auxbuf)[filled],
				       sizeof(auxbuf) - filled);
			if (ret <= 0) {
				if (ret < 0 && errno == EINTR)
					continue;
				goto out;
			}
			filled += ret;
		} while (filled < 2 * sizeof(long));

		i = 0;
		do {
			unsigned long type = auxbuf[i];
			unsigned long value = auxbuf[i + 1];

			if (type == AT_HWCAP)
				*hwcap = value;
			else if (type == AT_HWCAP2)
				*hwcap2 = value;
			i += 2;
			filled -= 2 * sizeof(long);
		} while (filled >= 2 * sizeof(long));

		memmove(auxbuf, &auxbuf[i], filled);
	}
out:
	close(fd);
}

static u32 query_arm_cpu_features(void)
{
	u32 features = 0;
	unsigned long hwcap = 0;
	unsigned long hwcap2 = 0;

	scan_auxv(&hwcap, &hwcap2);

#ifdef ARCH_ARM32
	STATIC_ASSERT(sizeof(long) == 4);
	if (hwcap & (1 << 12))	
		features |= ARM_CPU_FEATURE_NEON;
#else
	STATIC_ASSERT(sizeof(long) == 8);
	if (hwcap & (1 << 1))	
		features |= ARM_CPU_FEATURE_NEON;
	if (hwcap & (1 << 4))	
		features |= ARM_CPU_FEATURE_PMULL;
	if (hwcap & (1 << 7))	
		features |= ARM_CPU_FEATURE_CRC32;
	if (hwcap & (1 << 17))	
		features |= ARM_CPU_FEATURE_SHA3;
	if (hwcap & (1 << 20))	
		features |= ARM_CPU_FEATURE_DOTPROD;
#endif
	return features;
}

#elif defined(__APPLE__)


#include <sys/types.h>
#include <sys/sysctl.h>
#include <TargetConditionals.h>

static const struct {
	const char *name;
	u32 feature;
} feature_sysctls[] = {
	{ "hw.optional.neon",		  ARM_CPU_FEATURE_NEON },
	{ "hw.optional.AdvSIMD",	  ARM_CPU_FEATURE_NEON },
	{ "hw.optional.arm.FEAT_PMULL",	  ARM_CPU_FEATURE_PMULL },
	{ "hw.optional.armv8_crc32",	  ARM_CPU_FEATURE_CRC32 },
	{ "hw.optional.armv8_2_sha3",	  ARM_CPU_FEATURE_SHA3 },
	{ "hw.optional.arm.FEAT_SHA3",	  ARM_CPU_FEATURE_SHA3 },
	{ "hw.optional.arm.FEAT_DotProd", ARM_CPU_FEATURE_DOTPROD },
};

static u32 query_arm_cpu_features(void)
{
	u32 features = 0;
	size_t i;

	for (i = 0; i < ARRAY_LEN(feature_sysctls); i++) {
		const char *name = feature_sysctls[i].name;
		u32 val = 0;
		size_t valsize = sizeof(val);

		if (sysctlbyname(name, &val, &valsize, NULL, 0) == 0 &&
		    valsize == sizeof(val) && val == 1)
			features |= feature_sysctls[i].feature;
	}
	return features;
}
#elif defined(_WIN32)

#include <windows.h>

#ifndef PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE 
#  define PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE 43
#endif

static u32 query_arm_cpu_features(void)
{
	u32 features = ARM_CPU_FEATURE_NEON;

	if (IsProcessorFeaturePresent(PF_ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE))
		features |= ARM_CPU_FEATURE_PMULL;
	if (IsProcessorFeaturePresent(PF_ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE))
		features |= ARM_CPU_FEATURE_CRC32;
	if (IsProcessorFeaturePresent(PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE))
		features |= ARM_CPU_FEATURE_DOTPROD;

	

	return features;
}
#else
#error "unhandled case"
#endif

static const struct cpu_feature arm_cpu_feature_table[] = {
	{ARM_CPU_FEATURE_NEON,		"neon"},
	{ARM_CPU_FEATURE_PMULL,		"pmull"},
	{ARM_CPU_FEATURE_PREFER_PMULL,  "prefer_pmull"},
	{ARM_CPU_FEATURE_CRC32,		"crc32"},
	{ARM_CPU_FEATURE_SHA3,		"sha3"},
	{ARM_CPU_FEATURE_DOTPROD,	"dotprod"},
};

volatile u32 libdeflate_arm_cpu_features = 0;

void libdeflate_init_arm_cpu_features(void)
{
	u32 features = query_arm_cpu_features();

	
#if (defined(__APPLE__) && TARGET_OS_OSX) || defined(TEST_SUPPORT__DO_NOT_USE)
	features |= ARM_CPU_FEATURE_PREFER_PMULL;
#endif

	disable_cpu_features_for_testing(&features, arm_cpu_feature_table,
					 ARRAY_LEN(arm_cpu_feature_table));

	libdeflate_arm_cpu_features = features | ARM_CPU_FEATURES_KNOWN;
}

#endif 
/* /usr/home/ben/projects/gzip-libdeflate/../../software/libdeflate/libdeflate-1.24/lib/x86/cpu_features.c */


/* #include "cpu_features_common.h" - no include guard */ 
/* #include "x86-cpu_features.h" */


#ifndef LIB_X86_CPU_FEATURES_H
#define LIB_X86_CPU_FEATURES_H

/* #include "lib_common.h" */


#ifndef LIB_LIB_COMMON_H
#define LIB_LIB_COMMON_H

#ifdef LIBDEFLATE_H
 
#  error "lib_common.h must always be included before libdeflate.h"
#endif

#if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#  define LIBDEFLATE_EXPORT_SYM  __declspec(dllexport)
#elif defined(__GNUC__)
#  define LIBDEFLATE_EXPORT_SYM  __attribute__((visibility("default")))
#else
#  define LIBDEFLATE_EXPORT_SYM
#endif


#if defined(__GNUC__) && defined(__i386__)
#  define LIBDEFLATE_ALIGN_STACK  __attribute__((force_align_arg_pointer))
#else
#  define LIBDEFLATE_ALIGN_STACK
#endif

#define LIBDEFLATEAPI	LIBDEFLATE_EXPORT_SYM LIBDEFLATE_ALIGN_STACK

/* #include "../common_defs.h" */


#ifndef COMMON_DEFS_H
#define COMMON_DEFS_H

/* #include "libdeflate.h" */


#ifndef LIBDEFLATE_H
#define LIBDEFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define LIBDEFLATE_VERSION_MAJOR	1
#define LIBDEFLATE_VERSION_MINOR	24
#define LIBDEFLATE_VERSION_STRING	"1.24"


#ifndef LIBDEFLATEAPI
#  if defined(LIBDEFLATE_DLL) && (defined(_WIN32) || defined(__CYGWIN__))
#    define LIBDEFLATEAPI	__declspec(dllimport)
#  else
#    define LIBDEFLATEAPI
#  endif
#endif





struct libdeflate_compressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor(int compression_level);


LIBDEFLATEAPI struct libdeflate_compressor *
libdeflate_alloc_compressor_ex(int compression_level,
			       const struct libdeflate_options *options);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress(struct libdeflate_compressor *compressor,
			    const void *in, size_t in_nbytes,
			    void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_deflate_compress_bound(struct libdeflate_compressor *compressor,
				  size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_zlib_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress(struct libdeflate_compressor *compressor,
			 const void *in, size_t in_nbytes,
			 void *out, size_t out_nbytes_avail);


LIBDEFLATEAPI size_t
libdeflate_gzip_compress_bound(struct libdeflate_compressor *compressor,
			       size_t in_nbytes);


LIBDEFLATEAPI void
libdeflate_free_compressor(struct libdeflate_compressor *compressor);





struct libdeflate_decompressor;
struct libdeflate_options;


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor(void);


LIBDEFLATEAPI struct libdeflate_decompressor *
libdeflate_alloc_decompressor_ex(const struct libdeflate_options *options);


enum libdeflate_result {
	
	LIBDEFLATE_SUCCESS = 0,

	
	LIBDEFLATE_BAD_DATA = 1,

	
	LIBDEFLATE_SHORT_OUTPUT = 2,

	
	LIBDEFLATE_INSUFFICIENT_SPACE = 3,
};


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_deflate_decompress_ex(struct libdeflate_decompressor *decompressor,
				 const void *in, size_t in_nbytes,
				 void *out, size_t out_nbytes_avail,
				 size_t *actual_in_nbytes_ret,
				 size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_zlib_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress(struct libdeflate_decompressor *decompressor,
			   const void *in, size_t in_nbytes,
			   void *out, size_t out_nbytes_avail,
			   size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI enum libdeflate_result
libdeflate_gzip_decompress_ex(struct libdeflate_decompressor *decompressor,
			      const void *in, size_t in_nbytes,
			      void *out, size_t out_nbytes_avail,
			      size_t *actual_in_nbytes_ret,
			      size_t *actual_out_nbytes_ret);


LIBDEFLATEAPI void
libdeflate_free_decompressor(struct libdeflate_decompressor *decompressor);






LIBDEFLATEAPI uint32_t
libdeflate_adler32(uint32_t adler, const void *buffer, size_t len);



LIBDEFLATEAPI uint32_t
libdeflate_crc32(uint32_t crc, const void *buffer, size_t len);






LIBDEFLATEAPI void
libdeflate_set_memory_allocator(void *(*malloc_func)(size_t),
				void (*free_func)(void *));


struct libdeflate_options {

	
	size_t sizeof_options;

	
	void *(*malloc_func)(size_t);
	void (*free_func)(void *);
};

#ifdef __cplusplus
}
#endif

#endif 


#include <stdbool.h>
#include <stddef.h>	
#include <stdint.h>
#ifdef _MSC_VER
#  include <intrin.h>	
#  include <stdlib.h>	
   
   
#  pragma warning(disable : 4146) 
   
#  pragma warning(disable : 4018) 
#  pragma warning(disable : 4244) 
#  pragma warning(disable : 4267) 
#  pragma warning(disable : 4310) 
   
#  pragma warning(disable : 4100) 
#  pragma warning(disable : 4127) 
#  pragma warning(disable : 4189) 
#  pragma warning(disable : 4232) 
#  pragma warning(disable : 4245) 
#  pragma warning(disable : 4295) 
#endif
#ifndef FREESTANDING
#  include <string.h>	
#endif






#undef ARCH_X86_64
#undef ARCH_X86_32
#undef ARCH_ARM64
#undef ARCH_ARM32
#undef ARCH_RISCV
#ifdef _MSC_VER
   
#  if defined(_M_X64) && !defined(_M_ARM64EC)
#    define ARCH_X86_64
#  elif defined(_M_IX86)
#    define ARCH_X86_32
#  elif defined(_M_ARM64)
#    define ARCH_ARM64
#  elif defined(_M_ARM)
#    define ARCH_ARM32
#  endif
#else
#  if defined(__x86_64__)
#    define ARCH_X86_64
#  elif defined(__i386__)
#    define ARCH_X86_32
#  elif defined(__aarch64__)
#    define ARCH_ARM64
#  elif defined(__arm__)
#    define ARCH_ARM32
#  elif defined(__riscv)
#    define ARCH_RISCV
#  endif
#endif






typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef int8_t s8;
typedef int16_t s16;
typedef int32_t s32;
typedef int64_t s64;


#ifdef _MSC_VER
#  ifdef _WIN64
     typedef long long ssize_t;
#  else
     typedef long ssize_t;
#  endif
#endif


typedef size_t machine_word_t;


#define WORDBYTES	((int)sizeof(machine_word_t))


#define WORDBITS	(8 * WORDBYTES)






#if defined(__GNUC__) && !defined(__clang__) && !defined(__INTEL_COMPILER)
#  define GCC_PREREQ(major, minor)		\
	(__GNUC__ > (major) ||			\
	 (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
#  if !GCC_PREREQ(4, 9)
#    error "gcc versions older than 4.9 are no longer supported"
#  endif
#else
#  define GCC_PREREQ(major, minor)	0
#endif
#ifdef __clang__
#  ifdef __apple_build_version__
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__apple_build_version__ >= (apple_version))
#  else
#    define CLANG_PREREQ(major, minor, apple_version)	\
	(__clang_major__ > (major) ||			\
	 (__clang_major__ == (major) && __clang_minor__ >= (minor)))
#  endif
#  if !CLANG_PREREQ(3, 9, 8000000)
#    error "clang versions older than 3.9 are no longer supported"
#  endif
#else
#  define CLANG_PREREQ(major, minor, apple_version)	0
#endif
#ifdef _MSC_VER
#  define MSVC_PREREQ(version)	(_MSC_VER >= (version))
#  if !MSVC_PREREQ(1900)
#    error "MSVC versions older than Visual Studio 2015 are no longer supported"
#  endif
#else
#  define MSVC_PREREQ(version)	0
#endif


#ifndef __has_attribute
#  define __has_attribute(attribute)	0
#endif


#ifndef __has_builtin
#  define __has_builtin(builtin)	0
#endif


#ifdef _MSC_VER
#  define inline		__inline
#endif 


#if defined(__GNUC__) || __has_attribute(always_inline)
#  define forceinline		inline __attribute__((always_inline))
#elif defined(_MSC_VER)
#  define forceinline		__forceinline
#else
#  define forceinline		inline
#endif


#if defined(__GNUC__) || __has_attribute(unused)
#  define MAYBE_UNUSED		__attribute__((unused))
#else
#  define MAYBE_UNUSED
#endif


#if defined(__GNUC__) || __has_attribute(noreturn)
#  define NORETURN		__attribute__((noreturn))
#else
#  define NORETURN
#endif


#if !defined(__STDC_VERSION__) || (__STDC_VERSION__ < 201112L)
#  if defined(__GNUC__) || defined(__clang__)
#    define restrict		__restrict__
#  else
#    define restrict
#  endif
#endif 


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define likely(expr)		__builtin_expect(!!(expr), 1)
#else
#  define likely(expr)		(expr)
#endif


#if defined(__GNUC__) || __has_builtin(__builtin_expect)
#  define unlikely(expr)	__builtin_expect(!!(expr), 0)
#else
#  define unlikely(expr)	(expr)
#endif


#undef prefetchr
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchr(addr)	__builtin_prefetch((addr), 0)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchr(addr)	_mm_prefetch((addr), _MM_HINT_T0)
#  elif defined(ARCH_ARM64)
#    define prefetchr(addr)	__prefetch2((addr), 0x00 )
#  elif defined(ARCH_ARM32)
#    define prefetchr(addr)	__prefetch(addr)
#  endif
#endif
#ifndef prefetchr
#  define prefetchr(addr)
#endif


#undef prefetchw
#if defined(__GNUC__) || __has_builtin(__builtin_prefetch)
#  define prefetchw(addr)	__builtin_prefetch((addr), 1)
#elif defined(_MSC_VER)
#  if defined(ARCH_X86_32) || defined(ARCH_X86_64)
#    define prefetchw(addr)	_m_prefetchw(addr)
#  elif defined(ARCH_ARM64)
#    define prefetchw(addr)	__prefetch2((addr), 0x10 )
#  elif defined(ARCH_ARM32)
#    define prefetchw(addr)	__prefetchw(addr)
#  endif
#endif
#ifndef prefetchw
#  define prefetchw(addr)
#endif


#undef _aligned_attribute
#if defined(__GNUC__) || __has_attribute(aligned)
#  define _aligned_attribute(n)	__attribute__((aligned(n)))
#elif defined(_MSC_VER)
#  define _aligned_attribute(n)	__declspec(align(n))
#endif


#if defined(__GNUC__) || __has_attribute(target)
#  define _target_attribute(attrs)	__attribute__((target(attrs)))
#else
#  define _target_attribute(attrs)
#endif





#define ARRAY_LEN(A)		(sizeof(A) / sizeof((A)[0]))
#define MIN(a, b)		((a) <= (b) ? (a) : (b))
#define MAX(a, b)		((a) >= (b) ? (a) : (b))
#define DIV_ROUND_UP(n, d)	(((n) + (d) - 1) / (d))
#define STATIC_ASSERT(expr)	((void)sizeof(char[1 - 2 * !(expr)]))
#define ALIGN(n, a)		(((n) + (a) - 1) & ~((a) - 1))
#define ROUND_UP(n, d)		((d) * DIV_ROUND_UP((n), (d)))






#if defined(__BYTE_ORDER__) 
#  define CPU_IS_LITTLE_ENDIAN()  (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
#elif defined(_MSC_VER)
#  define CPU_IS_LITTLE_ENDIAN()  true
#else
static forceinline bool CPU_IS_LITTLE_ENDIAN(void)
{
	union {
		u32 w;
		u8 b;
	} u;

	u.w = 1;
	return u.b;
}
#endif


static forceinline u16 bswap16(u16 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap16)
	return __builtin_bswap16(v);
#elif defined(_MSC_VER)
	return _byteswap_ushort(v);
#else
	return (v << 8) | (v >> 8);
#endif
}


static forceinline u32 bswap32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap32)
	return __builtin_bswap32(v);
#elif defined(_MSC_VER)
	return _byteswap_ulong(v);
#else
	return ((v & 0x000000FF) << 24) |
	       ((v & 0x0000FF00) << 8) |
	       ((v & 0x00FF0000) >> 8) |
	       ((v & 0xFF000000) >> 24);
#endif
}


static forceinline u64 bswap64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_bswap64)
	return __builtin_bswap64(v);
#elif defined(_MSC_VER)
	return _byteswap_uint64(v);
#else
	return ((v & 0x00000000000000FF) << 56) |
	       ((v & 0x000000000000FF00) << 40) |
	       ((v & 0x0000000000FF0000) << 24) |
	       ((v & 0x00000000FF000000) << 8) |
	       ((v & 0x000000FF00000000) >> 8) |
	       ((v & 0x0000FF0000000000) >> 24) |
	       ((v & 0x00FF000000000000) >> 40) |
	       ((v & 0xFF00000000000000) >> 56);
#endif
}

#define le16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap16(v))
#define le32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap32(v))
#define le64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? (v) : bswap64(v))
#define be16_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap16(v) : (v))
#define be32_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap32(v) : (v))
#define be64_bswap(v) (CPU_IS_LITTLE_ENDIAN() ? bswap64(v) : (v))






#if (defined(__GNUC__) || defined(__clang__)) && \
	(defined(ARCH_X86_64) || defined(ARCH_X86_32) || \
	 defined(__ARM_FEATURE_UNALIGNED) || defined(__powerpc64__) || \
	 defined(__riscv_misaligned_fast) || \
	  defined(__wasm__))
#  define UNALIGNED_ACCESS_IS_FAST	1
#elif defined(_MSC_VER)
#  define UNALIGNED_ACCESS_IS_FAST	1
#else
#  define UNALIGNED_ACCESS_IS_FAST	0
#endif



#ifdef FREESTANDING
#  define MEMCOPY	__builtin_memcpy
#else
#  define MEMCOPY	memcpy
#endif



#define DEFINE_UNALIGNED_TYPE(type)				\
static forceinline type						\
load_##type##_unaligned(const void *p)				\
{								\
	type v;							\
								\
	MEMCOPY(&v, p, sizeof(v));				\
	return v;						\
}								\
								\
static forceinline void						\
store_##type##_unaligned(type v, void *p)			\
{								\
	MEMCOPY(p, &v, sizeof(v));				\
}

DEFINE_UNALIGNED_TYPE(u16)
DEFINE_UNALIGNED_TYPE(u32)
DEFINE_UNALIGNED_TYPE(u64)
DEFINE_UNALIGNED_TYPE(machine_word_t)

#undef MEMCOPY

#define load_word_unaligned	load_machine_word_t_unaligned
#define store_word_unaligned	store_machine_word_t_unaligned



static forceinline u16
get_unaligned_le16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[1] << 8) | p[0];
}

static forceinline u16
get_unaligned_be16(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be16_bswap(load_u16_unaligned(p));
	else
		return ((u16)p[0] << 8) | p[1];
}

static forceinline u32
get_unaligned_le32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[3] << 24) | ((u32)p[2] << 16) |
			((u32)p[1] << 8) | p[0];
}

static forceinline u32
get_unaligned_be32(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return be32_bswap(load_u32_unaligned(p));
	else
		return ((u32)p[0] << 24) | ((u32)p[1] << 16) |
			((u32)p[2] << 8) | p[3];
}

static forceinline u64
get_unaligned_le64(const u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST)
		return le64_bswap(load_u64_unaligned(p));
	else
		return ((u64)p[7] << 56) | ((u64)p[6] << 48) |
			((u64)p[5] << 40) | ((u64)p[4] << 32) |
			((u64)p[3] << 24) | ((u64)p[2] << 16) |
			((u64)p[1] << 8) | p[0];
}

static forceinline machine_word_t
get_unaligned_leword(const u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return get_unaligned_le32(p);
	else
		return get_unaligned_le64(p);
}



static forceinline void
put_unaligned_le16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(le16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
	}
}

static forceinline void
put_unaligned_be16(u16 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u16_unaligned(be16_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 8);
		p[1] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(le32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
	}
}

static forceinline void
put_unaligned_be32(u32 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u32_unaligned(be32_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 24);
		p[1] = (u8)(v >> 16);
		p[2] = (u8)(v >> 8);
		p[3] = (u8)(v >> 0);
	}
}

static forceinline void
put_unaligned_le64(u64 v, u8 *p)
{
	if (UNALIGNED_ACCESS_IS_FAST) {
		store_u64_unaligned(le64_bswap(v), p);
	} else {
		p[0] = (u8)(v >> 0);
		p[1] = (u8)(v >> 8);
		p[2] = (u8)(v >> 16);
		p[3] = (u8)(v >> 24);
		p[4] = (u8)(v >> 32);
		p[5] = (u8)(v >> 40);
		p[6] = (u8)(v >> 48);
		p[7] = (u8)(v >> 56);
	}
}

static forceinline void
put_unaligned_leword(machine_word_t v, u8 *p)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		put_unaligned_le32(v, p);
	else
		put_unaligned_le64(v, p);
}







static forceinline unsigned
bsr32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clz)
	return 31 - __builtin_clz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanReverse(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsr64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_clzll)
	return 63 - __builtin_clzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanReverse64(&i, v);
	return i;
#else
	unsigned i = 0;

	while ((v >>= 1) != 0)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsrw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsr32(v);
	else
		return bsr64(v);
}



static forceinline unsigned
bsf32(u32 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctz)
	return __builtin_ctz(v);
#elif defined(_MSC_VER)
	unsigned long i;

	_BitScanForward(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsf64(u64 v)
{
#if defined(__GNUC__) || __has_builtin(__builtin_ctzll)
	return __builtin_ctzll(v);
#elif defined(_MSC_VER) && defined(_WIN64)
	unsigned long i;

	_BitScanForward64(&i, v);
	return i;
#else
	unsigned i = 0;

	for (; (v & 1) == 0; v >>= 1)
		i++;
	return i;
#endif
}

static forceinline unsigned
bsfw(machine_word_t v)
{
	STATIC_ASSERT(WORDBITS == 32 || WORDBITS == 64);
	if (WORDBITS == 32)
		return bsf32(v);
	else
		return bsf64(v);
}


#undef rbit32
#if (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM32) && \
	(__ARM_ARCH >= 7 || (__ARM_ARCH == 6 && defined(__ARM_ARCH_6T2__)))
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %0, %1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#elif (defined(__GNUC__) || defined(__clang__)) && defined(ARCH_ARM64)
static forceinline u32
rbit32(u32 v)
{
	__asm__("rbit %w0, %w1" : "=r" (v) : "r" (v));
	return v;
}
#define rbit32 rbit32
#endif

#endif 


typedef void *(*malloc_func_t)(size_t);
typedef void (*free_func_t)(void *);

extern malloc_func_t libdeflate_default_malloc_func;
extern free_func_t libdeflate_default_free_func;

void *libdeflate_aligned_malloc(malloc_func_t malloc_func,
				size_t alignment, size_t size);
void libdeflate_aligned_free(free_func_t free_func, void *ptr);

#ifdef FREESTANDING

void *memset(void *s, int c, size_t n);
#define memset(s, c, n)		__builtin_memset((s), (c), (n))

void *memcpy(void *dest, const void *src, size_t n);
#define memcpy(dest, src, n)	__builtin_memcpy((dest), (src), (n))

void *memmove(void *dest, const void *src, size_t n);
#define memmove(dest, src, n)	__builtin_memmove((dest), (src), (n))

int memcmp(const void *s1, const void *s2, size_t n);
#define memcmp(s1, s2, n)	__builtin_memcmp((s1), (s2), (n))

#undef LIBDEFLATE_ENABLE_ASSERTIONS
#else
#  include <string.h>
   
#  ifdef __clang_analyzer__
#    define LIBDEFLATE_ENABLE_ASSERTIONS
#  endif
#endif


#ifdef LIBDEFLATE_ENABLE_ASSERTIONS
NORETURN void
libdeflate_assertion_failed(const char *expr, const char *file, int line);
#define ASSERT(expr) { if (unlikely(!(expr))) \
	libdeflate_assertion_failed(#expr, __FILE__, __LINE__); }
#else
#define ASSERT(expr) (void)(expr)
#endif

#define CONCAT_IMPL(a, b)	a##b
#define CONCAT(a, b)		CONCAT_IMPL(a, b)
#define ADD_SUFFIX(name)	CONCAT(name, SUFFIX)

#endif 


#if defined(ARCH_X86_32) || defined(ARCH_X86_64)

#define X86_CPU_FEATURE_SSE2		(1 << 0)
#define X86_CPU_FEATURE_PCLMULQDQ	(1 << 1)
#define X86_CPU_FEATURE_AVX		(1 << 2)
#define X86_CPU_FEATURE_AVX2		(1 << 3)
#define X86_CPU_FEATURE_BMI2		(1 << 4)

#define X86_CPU_FEATURE_ZMM		(1 << 5)
#define X86_CPU_FEATURE_AVX512BW	(1 << 6)
#define X86_CPU_FEATURE_AVX512VL	(1 << 7)
#define X86_CPU_FEATURE_VPCLMULQDQ	(1 << 8)
#define X86_CPU_FEATURE_AVX512VNNI	(1 << 9)
#define X86_CPU_FEATURE_AVXVNNI		(1 << 10)

#if defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER)

#  define X86_CPU_FEATURES_KNOWN	(1U << 31)
extern volatile u32 libdeflate_x86_cpu_features;

void libdeflate_init_x86_cpu_features(void);

static inline u32 get_x86_cpu_features(void)
{
	if (libdeflate_x86_cpu_features == 0)
		libdeflate_init_x86_cpu_features();
	return libdeflate_x86_cpu_features;
}

#  include <immintrin.h>
#  if defined(_MSC_VER) && defined(__clang__)
#    include <tmmintrin.h>
#    include <smmintrin.h>
#    include <wmmintrin.h>
#    include <avxintrin.h>
#    include <avx2intrin.h>
#    include <avx512fintrin.h>
#    include <avx512bwintrin.h>
#    include <avx512vlintrin.h>
#    if __has_include(<avx512vlbwintrin.h>)
#      include <avx512vlbwintrin.h>
#    endif
#    if __has_include(<vpclmulqdqintrin.h>)
#      include <vpclmulqdqintrin.h>
#    endif
#    if __has_include(<avx512vnniintrin.h>)
#      include <avx512vnniintrin.h>
#    endif
#    if __has_include(<avx512vlvnniintrin.h>)
#      include <avx512vlvnniintrin.h>
#    endif
#    if __has_include(<avxvnniintrin.h>)
#      include <avxvnniintrin.h>
#    endif
#  endif
#else
static inline u32 get_x86_cpu_features(void) { return 0; }
#endif

#if defined(__SSE2__) || \
	(defined(_MSC_VER) && \
	 (defined(ARCH_X86_64) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2)))
#  define HAVE_SSE2(features)		1
#  define HAVE_SSE2_NATIVE		1
#else
#  define HAVE_SSE2(features)		((features) & X86_CPU_FEATURE_SSE2)
#  define HAVE_SSE2_NATIVE		0
#endif

#if (defined(__PCLMUL__) && defined(__SSE4_1__)) || \
	(defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_PCLMULQDQ(features)	1
#else
#  define HAVE_PCLMULQDQ(features)	((features) & X86_CPU_FEATURE_PCLMULQDQ)
#endif

#ifdef __AVX__
#  define HAVE_AVX(features)		1
#else
#  define HAVE_AVX(features)		((features) & X86_CPU_FEATURE_AVX)
#endif

#ifdef __AVX2__
#  define HAVE_AVX2(features)		1
#else
#  define HAVE_AVX2(features)		((features) & X86_CPU_FEATURE_AVX2)
#endif

#if defined(__BMI2__) || (defined(_MSC_VER) && defined(__AVX2__))
#  define HAVE_BMI2(features)		1
#  define HAVE_BMI2_NATIVE		1
#else
#  define HAVE_BMI2(features)		((features) & X86_CPU_FEATURE_BMI2)
#  define HAVE_BMI2_NATIVE		0
#endif

#ifdef __AVX512BW__
#  define HAVE_AVX512BW(features)	1
#else
#  define HAVE_AVX512BW(features)	((features) & X86_CPU_FEATURE_AVX512BW)
#endif

#ifdef __AVX512VL__
#  define HAVE_AVX512VL(features)	1
#else
#  define HAVE_AVX512VL(features)	((features) & X86_CPU_FEATURE_AVX512VL)
#endif

#ifdef __VPCLMULQDQ__
#  define HAVE_VPCLMULQDQ(features)	1
#else
#  define HAVE_VPCLMULQDQ(features)	((features) & X86_CPU_FEATURE_VPCLMULQDQ)
#endif

#ifdef __AVX512VNNI__
#  define HAVE_AVX512VNNI(features)	1
#else
#  define HAVE_AVX512VNNI(features)	((features) & X86_CPU_FEATURE_AVX512VNNI)
#endif

#ifdef __AVXVNNI__
#  define HAVE_AVXVNNI(features)	1
#else
#  define HAVE_AVXVNNI(features)	((features) & X86_CPU_FEATURE_AVXVNNI)
#endif

#if (GCC_PREREQ(14, 0) || CLANG_PREREQ(18, 0, 18000000)) \
	&& !defined(__EVEX512__) 
#  define EVEX512	",evex512"	
#  define NO_EVEX512	",no-evex512"
#else
#  define EVEX512	""
#  define NO_EVEX512	""
#endif

#endif 

#endif 


#ifdef X86_CPU_FEATURES_KNOWN



static inline void
cpuid(u32 leaf, u32 subleaf, u32 *a, u32 *b, u32 *c, u32 *d)
{
#ifdef _MSC_VER
	int result[4];

	__cpuidex(result, leaf, subleaf);
	*a = result[0];
	*b = result[1];
	*c = result[2];
	*d = result[3];
#else
	__asm__ volatile("cpuid" : "=a" (*a), "=b" (*b), "=c" (*c), "=d" (*d)
			 : "a" (leaf), "c" (subleaf));
#endif
}


static inline u64
read_xcr(u32 index)
{
#ifdef _MSC_VER
	return _xgetbv(index);
#else
	u32 d, a;

	
	__asm__ volatile(".byte 0x0f, 0x01, 0xd0" :
			 "=d" (d), "=a" (a) : "c" (index));

	return ((u64)d << 32) | a;
#endif
}

static const struct cpu_feature x86_cpu_feature_table[] = {
	{X86_CPU_FEATURE_SSE2,		"sse2"},
	{X86_CPU_FEATURE_PCLMULQDQ,	"pclmulqdq"},
	{X86_CPU_FEATURE_AVX,		"avx"},
	{X86_CPU_FEATURE_AVX2,		"avx2"},
	{X86_CPU_FEATURE_BMI2,		"bmi2"},
	{X86_CPU_FEATURE_ZMM,		"zmm"},
	{X86_CPU_FEATURE_AVX512BW,	"avx512bw"},
	{X86_CPU_FEATURE_AVX512VL,	"avx512vl"},
	{X86_CPU_FEATURE_VPCLMULQDQ,	"vpclmulqdq"},
	{X86_CPU_FEATURE_AVX512VNNI,	"avx512_vnni"},
	{X86_CPU_FEATURE_AVXVNNI,	"avx_vnni"},
};

volatile u32 libdeflate_x86_cpu_features = 0;

static inline bool
os_supports_avx512(u64 xcr0)
{
#ifdef __APPLE__
	
	return false;
#else
	return (xcr0 & 0xe6) == 0xe6;
#endif
}


static inline bool
allow_512bit_vectors(const u32 manufacturer[3], u32 family, u32 model)
{
#ifdef TEST_SUPPORT__DO_NOT_USE
	return true;
#endif
	if (memcmp(manufacturer, "GenuineIntel", 12) != 0)
		return true;
	if (family != 6)
		return true;
	switch (model) {
	case 85: 
	case 106: 
	case 108: 
	case 126: 
	case 140: 
	case 141: 
		return false;
	}
	return true;
}


void libdeflate_init_x86_cpu_features(void)
{
	u32 max_leaf;
	u32 manufacturer[3];
	u32 family, model;
	u32 a, b, c, d;
	u64 xcr0 = 0;
	u32 features = 0;

	
	cpuid(0, 0, &max_leaf, &manufacturer[0], &manufacturer[2],
	      &manufacturer[1]);
	if (max_leaf < 1)
		goto out;

	
	cpuid(1, 0, &a, &b, &c, &d);
	family = (a >> 8) & 0xf;
	model = (a >> 4) & 0xf;
	if (family == 6 || family == 0xf)
		model += (a >> 12) & 0xf0;
	if (family == 0xf)
		family += (a >> 20) & 0xff;
	if (d & (1 << 26))
		features |= X86_CPU_FEATURE_SSE2;
	
	if ((c & (1 << 1)) && (c & (1 << 19)))
		features |= X86_CPU_FEATURE_PCLMULQDQ;
	if (c & (1 << 27))
		xcr0 = read_xcr(0);
	if ((c & (1 << 28)) && ((xcr0 & 0x6) == 0x6))
		features |= X86_CPU_FEATURE_AVX;

	if (max_leaf < 7)
		goto out;

	
	cpuid(7, 0, &a, &b, &c, &d);
	if (b & (1 << 8))
		features |= X86_CPU_FEATURE_BMI2;
	if ((xcr0 & 0x6) == 0x6) {
		if (b & (1 << 5))
			features |= X86_CPU_FEATURE_AVX2;
		if (c & (1 << 10))
			features |= X86_CPU_FEATURE_VPCLMULQDQ;
	}
	if (os_supports_avx512(xcr0)) {
		if (allow_512bit_vectors(manufacturer, family, model))
			features |= X86_CPU_FEATURE_ZMM;
		if (b & (1 << 30))
			features |= X86_CPU_FEATURE_AVX512BW;
		if (b & (1U << 31))
			features |= X86_CPU_FEATURE_AVX512VL;
		if (c & (1 << 11))
			features |= X86_CPU_FEATURE_AVX512VNNI;
	}

	
	cpuid(7, 1, &a, &b, &c, &d);
	if ((a & (1 << 4)) && ((xcr0 & 0x6) == 0x6))
		features |= X86_CPU_FEATURE_AVXVNNI;

out:
	disable_cpu_features_for_testing(&features, x86_cpu_feature_table,
					 ARRAY_LEN(x86_cpu_feature_table));

	libdeflate_x86_cpu_features = features | X86_CPU_FEATURES_KNOWN;
}

#endif 
