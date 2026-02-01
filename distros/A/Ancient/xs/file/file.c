/*
 * file.c - Fast IO operations using direct system calls
 *
 * Features:
 * - slurp/spew with minimal overhead
 * - Memory-mapped file access (mmap)
 * - Efficient line iteration
 * - Direct stat access
 * - Windows and POSIX support
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "file_compat.h"

#include <fcntl.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>

#ifdef _WIN32
    #include <io.h>
    #include <windows.h>
    #include <direct.h>
    /* Windows compatibility macros */
    #define open _open
    #define read _read
    #define write _write
    #define close _close
    #define stat _stat
    #define fstat _fstat
    #define access _access
    #define O_RDONLY _O_RDONLY
    #define O_WRONLY _O_WRONLY
    #define O_RDWR _O_RDWR
    #define O_CREAT _O_CREAT
    #define O_TRUNC _O_TRUNC
    #define O_APPEND _O_APPEND
    #define O_BINARY _O_BINARY
    #define S_ISREG(m) (((m) & _S_IFMT) == _S_IFREG)
    #define S_ISDIR(m) (((m) & _S_IFMT) == _S_IFDIR)
    #define R_OK 4
    #define W_OK 2
    /* ssize_t for Windows */
    #ifndef ssize_t
        #ifdef _WIN64
            typedef __int64 ssize_t;
        #else
            typedef int ssize_t;
        #endif
    #endif
#else
    #include <unistd.h>
    #include <sys/mman.h>
    #include <utime.h>      /* For utime - more portable than utimes */
    #include <dirent.h>     /* For readdir */
#endif

/* Default buffer size for reads - 64KB is optimal for most systems */
#define FILE_BUFFER_SIZE 65536

/* Larger buffer for bulk operations */
#define FILE_BULK_BUFFER_SIZE 262144

/* ============================================
   Custom op support for compile-time optimization
   ============================================ */

/* Custom op registrations */
static XOP file_slurp_xop;
static XOP file_spew_xop;
static XOP file_exists_xop;
static XOP file_size_xop;
static XOP file_is_file_xop;
static XOP file_is_dir_xop;
static XOP file_lines_xop;
static XOP file_unlink_xop;
static XOP file_mkdir_xop;
static XOP file_rmdir_xop;
static XOP file_basename_xop;
static XOP file_dirname_xop;
static XOP file_extname_xop;
static XOP file_touch_xop;
static XOP file_mtime_xop;
static XOP file_atime_xop;
static XOP file_ctime_xop;
static XOP file_mode_xop;
static XOP file_is_link_xop;
static XOP file_is_readable_xop;
static XOP file_is_writable_xop;
static XOP file_is_executable_xop;
static XOP file_readdir_xop;
static XOP file_slurp_raw_xop;
static XOP file_copy_xop;
static XOP file_move_xop;
static XOP file_chmod_xop;
static XOP file_append_xop;
static XOP file_atomic_spew_xop;

/* Forward declarations for internal functions */
static SV* file_slurp_internal(pTHX_ const char *path);
static int file_spew_internal(pTHX_ const char *path, SV *data);
static int file_append_internal(pTHX_ const char *path, SV *data);
static IV file_size_internal(const char *path);
static IV file_mtime_internal(const char *path);
static IV file_atime_internal(const char *path);
static IV file_ctime_internal(const char *path);
static IV file_mode_internal(const char *path);
static int file_exists_internal(const char *path);
static int file_is_file_internal(const char *path);
static int file_is_dir_internal(const char *path);
static int file_is_link_internal(const char *path);
static int file_is_readable_internal(const char *path);
static int file_is_writable_internal(const char *path);
static int file_is_executable_internal(const char *path);
static AV* file_split_lines(pTHX_ SV *content);
static int file_unlink_internal(const char *path);
static int file_copy_internal(pTHX_ const char *src, const char *dst);
static int file_move_internal(pTHX_ const char *src, const char *dst);
static int file_mkdir_internal(const char *path, int mode);
static int file_rmdir_internal(const char *path);
static int file_touch_internal(const char *path);
static int file_chmod_internal(const char *path, int mode);
static AV* file_readdir_internal(pTHX_ const char *path);
static int file_atomic_spew_internal(pTHX_ const char *path, SV *data);
static SV* file_basename_internal(pTHX_ const char *path);
static SV* file_dirname_internal(pTHX_ const char *path);
static SV* file_extname_internal(pTHX_ const char *path);

/* Typedef for pp functions */
typedef OP* (*file_ppfunc)(pTHX);

/* ============================================
   Custom OP implementations - fastest path
   ============================================ */

/* pp_file_slurp: single path arg on stack */
static OP* pp_file_slurp(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    SV *result = file_slurp_internal(aTHX_ path);
    PUSHs(sv_2mortal(result));
    PUTBACK;
    return NORMAL;
}

/* pp_file_spew: path and data on stack */
static OP* pp_file_spew(pTHX) {
    dSP;
    SV *data = POPs;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    if (file_spew_internal(aTHX_ path, data)) {
        PUSHs(&PL_sv_yes);
    } else {
        PUSHs(&PL_sv_no);
    }
    PUTBACK;
    return NORMAL;
}

/* pp_file_exists: single path arg on stack */
static OP* pp_file_exists(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_exists_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_size: single path arg on stack */
static OP* pp_file_size(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(newSViv(file_size_internal(path))));
    PUTBACK;
    return NORMAL;
}

/* pp_file_is_file: single path arg on stack */
static OP* pp_file_is_file(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_is_file_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_is_dir: single path arg on stack */
static OP* pp_file_is_dir(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_is_dir_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_lines: single path arg on stack */
static OP* pp_file_lines(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    SV *content = file_slurp_internal(aTHX_ path);
    AV *lines;

    if (content == &PL_sv_undef) {
        lines = newAV();
    } else {
        lines = file_split_lines(aTHX_ content);
        SvREFCNT_dec(content);
    }

    PUSHs(sv_2mortal(newRV_noinc((SV*)lines)));
    PUTBACK;
    return NORMAL;
}

/* pp_file_unlink: single path arg on stack */
static OP* pp_file_unlink(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_unlink_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_mkdir: single path arg on stack (mode defaults to 0755) */
static OP* pp_file_mkdir(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_mkdir_internal(path, 0755) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_rmdir: single path arg on stack */
static OP* pp_file_rmdir(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_rmdir_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_touch: single path arg on stack */
static OP* pp_file_touch(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_touch_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_basename: single path arg on stack */
static OP* pp_file_basename(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(file_basename_internal(aTHX_ path)));
    PUTBACK;
    return NORMAL;
}

/* pp_file_dirname: single path arg on stack */
static OP* pp_file_dirname(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(file_dirname_internal(aTHX_ path)));
    PUTBACK;
    return NORMAL;
}

/* pp_file_extname: single path arg on stack */
static OP* pp_file_extname(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(file_extname_internal(aTHX_ path)));
    PUTBACK;
    return NORMAL;
}

/* pp_file_mtime: single path arg on stack */
static OP* pp_file_mtime(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(newSViv(file_mtime_internal(path))));
    PUTBACK;
    return NORMAL;
}

/* pp_file_atime: single path arg on stack */
static OP* pp_file_atime(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(newSViv(file_atime_internal(path))));
    PUTBACK;
    return NORMAL;
}

/* pp_file_ctime: single path arg on stack */
static OP* pp_file_ctime(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(newSViv(file_ctime_internal(path))));
    PUTBACK;
    return NORMAL;
}

/* pp_file_mode: single path arg on stack */
static OP* pp_file_mode(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(sv_2mortal(newSViv(file_mode_internal(path))));
    PUTBACK;
    return NORMAL;
}

/* pp_file_is_link: single path arg on stack */
static OP* pp_file_is_link(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_is_link_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_is_readable: single path arg on stack */
static OP* pp_file_is_readable(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_is_readable_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_is_writable: single path arg on stack */
static OP* pp_file_is_writable(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_is_writable_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_is_executable: single path arg on stack */
static OP* pp_file_is_executable(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_is_executable_internal(path) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_readdir: single path arg on stack */
static OP* pp_file_readdir(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    AV *result = file_readdir_internal(aTHX_ path);
    PUSHs(sv_2mortal(newRV_noinc((SV*)result)));
    PUTBACK;
    return NORMAL;
}

/* pp_file_slurp_raw: single path arg on stack (same as slurp) */
static OP* pp_file_slurp_raw(pTHX) {
    dSP;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    SV *result = file_slurp_internal(aTHX_ path);
    PUSHs(sv_2mortal(result));
    PUTBACK;
    return NORMAL;
}

/* pp_file_copy: src and dst on stack */
static OP* pp_file_copy(pTHX) {
    dSP;
    SV *dst_sv = POPs;
    SV *src_sv = POPs;
    const char *src = SvPV_nolen(src_sv);
    const char *dst = SvPV_nolen(dst_sv);
    PUSHs(file_copy_internal(aTHX_ src, dst) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_move: src and dst on stack */
static OP* pp_file_move(pTHX) {
    dSP;
    SV *dst_sv = POPs;
    SV *src_sv = POPs;
    const char *src = SvPV_nolen(src_sv);
    const char *dst = SvPV_nolen(dst_sv);
    PUSHs(file_move_internal(aTHX_ src, dst) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_chmod: path and mode on stack */
static OP* pp_file_chmod(pTHX) {
    dSP;
    SV *mode_sv = POPs;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    int mode = SvIV(mode_sv);
    PUSHs(file_chmod_internal(path, mode) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_append: path and data on stack */
static OP* pp_file_append(pTHX) {
    dSP;
    SV *data = POPs;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_append_internal(aTHX_ path, data) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* pp_file_atomic_spew: path and data on stack */
static OP* pp_file_atomic_spew(pTHX) {
    dSP;
    SV *data = POPs;
    SV *path_sv = POPs;
    const char *path = SvPV_nolen(path_sv);
    PUSHs(file_atomic_spew_internal(aTHX_ path, data) ? &PL_sv_yes : &PL_sv_no);
    PUTBACK;
    return NORMAL;
}

/* ============================================
   Call checkers for compile-time optimization
   ============================================ */

/* 
 * Check if an op is accessing $_ (the default variable).
 * This indicates we're likely in map/grep context where custom ops
 * don't work correctly due to how the op tree is evaluated.
 * Returns TRUE if the op is rv2sv -> gv for "_".
 */
static bool file_op_is_dollar_underscore(pTHX_ OP *op) {
    if (!op) return FALSE;
    
    /* Check for $_ access: rv2sv -> gv for "_" */
    if (op->op_type == OP_RV2SV) {
        OP *gvop = cUNOPx(op)->op_first;
        if (gvop && gvop->op_type == OP_GV) {
            GV *gv = cGVOPx_gv(gvop);
            if (gv && GvNAMELEN(gv) == 1 && GvNAME(gv)[0] == '_') {
                return TRUE;
            }
        }
    }
    
    return FALSE;
}

/* 1-arg call checker (slurp, exists, size, is_file, is_dir, lines) */
static OP* file_call_checker_1arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    file_ppfunc ppfunc = (file_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *argop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get the args: pushmark -> arg -> cv */
    argop = OpSIBLING(pushop);
    if (!argop) return entersubop;

    cvop = OpSIBLING(argop);
    if (!cvop) return entersubop;

    /* Verify exactly 1 arg */
    if (OpSIBLING(argop) != cvop) return entersubop;

    /* If arg is $_, fall back to XS (map/grep context) */
    if (file_op_is_dollar_underscore(aTHX_ argop)) {
        return entersubop;
    }

    /* Detach arg from tree */
    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(argop, NULL);

    /* Create unary custom op with arg as child */
    newop = newUNOP(OP_CUSTOM, 0, argop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

/* 2-arg call checker (spew, append) */
static OP* file_call_checker_2arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    file_ppfunc ppfunc = (file_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *pathop, *dataop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get the args: pushmark -> path -> data -> cv */
    pathop = OpSIBLING(pushop);
    if (!pathop) return entersubop;

    dataop = OpSIBLING(pathop);
    if (!dataop) return entersubop;

    cvop = OpSIBLING(dataop);
    if (!cvop) return entersubop;

    /* Verify exactly 2 args */
    if (OpSIBLING(dataop) != cvop) return entersubop;

    /* If path is $_, fall back to XS (map/grep context) */
    if (file_op_is_dollar_underscore(aTHX_ pathop)) {
        return entersubop;
    }

    /* Detach args from tree */
    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(pathop, NULL);
    OpLASTSIB_set(dataop, NULL);

    /* Create binary custom op */
    newop = newBINOP(OP_CUSTOM, 0, pathop, dataop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

/* Install 1-arg function with call checker */
static void install_file_func_1arg(pTHX_ const char *pkg, const char *name,
                                    XSUBADDR_t xsub, file_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);

    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, file_call_checker_1arg, ckobj);
}

/* Install 2-arg function with call checker */
static void install_file_func_2arg(pTHX_ const char *pkg, const char *name,
                                    XSUBADDR_t xsub, file_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);

    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, file_call_checker_2arg, ckobj);
}

/* ============================================
   Memory-mapped file registry
   ============================================ */

typedef struct {
    void *addr;         /* Mapped address */
    size_t len;         /* Mapped length */
    int refcount;       /* Reference count */
#ifdef _WIN32
    HANDLE file_handle; /* Windows file handle */
    HANDLE map_handle;  /* Windows mapping handle */
#else
    int fd;             /* File descriptor (POSIX) */
#endif
} MmapEntry;

static MmapEntry *g_mmaps = NULL;
static IV g_mmaps_size = 0;
static IV g_mmaps_count = 0;

/* Free list for mmap reuse */
static IV *g_free_mmaps = NULL;
static IV g_free_mmaps_size = 0;
static IV g_free_mmaps_count = 0;

/* ============================================
   Line iterator registry
   ============================================ */

typedef struct {
    int fd;             /* File descriptor */
    char *buffer;       /* Read buffer */
    size_t buf_size;    /* Buffer size */
    size_t buf_pos;     /* Current position in buffer */
    size_t buf_len;     /* Valid data length in buffer */
    int eof;            /* End of file reached */
    int refcount;       /* Reference count */
    char *path;         /* File path (for reopening) */
} LineIterEntry;

static LineIterEntry *g_iters = NULL;
static IV g_iters_size = 0;
static IV g_iters_count = 0;

static IV *g_free_iters = NULL;
static IV g_free_iters_size = 0;
static IV g_free_iters_count = 0;

/* ============================================
   Initialization
   ============================================ */

static int file_initialized = 0;

/* Forward declaration for callback registry init */
static void file_init_callback_registry(pTHX);

static void file_init(pTHX) {
    if (file_initialized) return;

    g_mmaps_size = 16;
    Newxz(g_mmaps, g_mmaps_size, MmapEntry);
    g_free_mmaps_size = 16;
    Newxz(g_free_mmaps, g_free_mmaps_size, IV);

    g_iters_size = 16;
    Newxz(g_iters, g_iters_size, LineIterEntry);
    g_free_iters_size = 16;
    Newxz(g_free_iters, g_free_iters_size, IV);

    /* Initialize callback registry with built-in predicates */
    file_init_callback_registry(aTHX);

    file_initialized = 1;
}

/* ============================================
   Fast slurp - read entire file into SV
   ============================================ */

static SV* file_slurp_internal(pTHX_ const char *path) {
    int fd;
    struct stat st;
    SV *result;
    char *buf;
    ssize_t total = 0, n;
#ifdef _WIN32
    int open_flags = O_RDONLY | O_BINARY;
#else
    int open_flags = O_RDONLY;
#endif

    fd = open(path, open_flags);
    if (fd < 0) {
        return &PL_sv_undef;
    }

    if (fstat(fd, &st) < 0) {
        close(fd);
        return &PL_sv_undef;
    }

    /* Pre-allocate exact size for regular files */
    if (S_ISREG(st.st_mode) && st.st_size > 0) {
        result = newSV(st.st_size + 1);
        SvPOK_on(result);
        buf = SvPVX(result);

        /* Read in one shot if possible */
        while (total < st.st_size) {
            n = read(fd, buf + total, st.st_size - total);
            if (n < 0) {
                if (errno == EINTR) continue;
                close(fd);
                SvREFCNT_dec(result);
                return &PL_sv_undef;
            }
            if (n == 0) break;
            total += n;
        }

        buf[total] = '\0';
        SvCUR_set(result, total);
    } else {
        /* Stream or unknown size - read in chunks */
        size_t capacity = FILE_BUFFER_SIZE;
        result = newSV(capacity);
        SvPOK_on(result);
        buf = SvPVX(result);

        while (1) {
            if (total >= (ssize_t)capacity - 1) {
                capacity *= 2;
                SvGROW(result, capacity);
                buf = SvPVX(result);
            }

            n = read(fd, buf + total, capacity - total - 1);
            if (n < 0) {
                if (errno == EINTR) continue;
                close(fd);
                SvREFCNT_dec(result);
                return &PL_sv_undef;
            }
            if (n == 0) break;
            total += n;
        }

        buf[total] = '\0';
        SvCUR_set(result, total);
    }

    close(fd);
    return result;
}

/* ============================================
   Fast slurp binary - same as slurp but explicit
   ============================================ */

static SV* file_slurp_raw(pTHX_ const char *path) {
    return file_slurp_internal(aTHX_ path);
}

/* ============================================
   Fast spew - write SV to file
   ============================================ */

static int file_spew_internal(pTHX_ const char *path, SV *data) {
    int fd;
    const char *buf;
    STRLEN len;
    ssize_t written = 0, n;
#ifdef _WIN32
    int open_flags = O_WRONLY | O_CREAT | O_TRUNC | O_BINARY;
#else
    int open_flags = O_WRONLY | O_CREAT | O_TRUNC;
#endif

    buf = SvPV(data, len);

    fd = open(path, open_flags, 0644);
    if (fd < 0) {
        return 0;
    }

    while ((size_t)written < len) {
        n = write(fd, buf + written, len - written);
        if (n < 0) {
            if (errno == EINTR) continue;
            close(fd);
            return 0;
        }
        written += n;
    }

    close(fd);
    return 1;
}

/* ============================================
   Fast append - append SV to file
   ============================================ */

static int file_append_internal(pTHX_ const char *path, SV *data) {
    int fd;
    const char *buf;
    STRLEN len;
    ssize_t written = 0, n;
#ifdef _WIN32
    int open_flags = O_WRONLY | O_CREAT | O_APPEND | O_BINARY;
#else
    int open_flags = O_WRONLY | O_CREAT | O_APPEND;
#endif

    buf = SvPV(data, len);

    fd = open(path, open_flags, 0644);
    if (fd < 0) {
        return 0;
    }

    while ((size_t)written < len) {
        n = write(fd, buf + written, len - written);
        if (n < 0) {
            if (errno == EINTR) continue;
            close(fd);
            return 0;
        }
        written += n;
    }

    close(fd);
    return 1;
}

/* ============================================
   Memory-mapped file operations
   ============================================ */

static void ensure_mmaps_capacity(IV needed) {
    if (needed >= g_mmaps_size) {
        IV new_size = g_mmaps_size ? g_mmaps_size * 2 : 16;
        IV i;
        while (new_size <= needed) new_size *= 2;
        Renew(g_mmaps, new_size, MmapEntry);
        for (i = g_mmaps_size; i < new_size; i++) {
            g_mmaps[i].addr = NULL;
            g_mmaps[i].len = 0;
            g_mmaps[i].refcount = 0;
#ifdef _WIN32
            g_mmaps[i].file_handle = INVALID_HANDLE_VALUE;
            g_mmaps[i].map_handle = INVALID_HANDLE_VALUE;
#else
            g_mmaps[i].fd = -1;
#endif
        }
        g_mmaps_size = new_size;
    }
}

static IV alloc_mmap_slot(void) {
    IV idx;

    if (g_free_mmaps_count > 0) {
        return g_free_mmaps[--g_free_mmaps_count];
    }

    ensure_mmaps_capacity(g_mmaps_count);
    idx = g_mmaps_count++;
    return idx;
}

static void free_mmap_slot(IV idx) {
    MmapEntry *entry;

    if (idx < 0 || idx >= g_mmaps_count) return;

    entry = &g_mmaps[idx];
#ifdef _WIN32
    if (entry->addr) {
        UnmapViewOfFile(entry->addr);
    }
    if (entry->map_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(entry->map_handle);
    }
    if (entry->file_handle != INVALID_HANDLE_VALUE) {
        CloseHandle(entry->file_handle);
    }
    entry->file_handle = INVALID_HANDLE_VALUE;
    entry->map_handle = INVALID_HANDLE_VALUE;
#else
    if (entry->addr && entry->addr != MAP_FAILED) {
        munmap(entry->addr, entry->len);
    }
    if (entry->fd >= 0) {
        close(entry->fd);
    }
    entry->fd = -1;
#endif
    entry->addr = NULL;
    entry->len = 0;
    entry->refcount = 0;

    if (g_free_mmaps_count >= g_free_mmaps_size) {
        g_free_mmaps_size *= 2;
        Renew(g_free_mmaps, g_free_mmaps_size, IV);
    }
    g_free_mmaps[g_free_mmaps_count++] = idx;
}

static IV file_mmap_open(pTHX_ const char *path, int writable) {
    IV idx;
    void *addr;
    size_t file_size;

#ifdef _WIN32
    HANDLE file_handle;
    HANDLE map_handle;
    LARGE_INTEGER size;
    DWORD access = writable ? GENERIC_READ | GENERIC_WRITE : GENERIC_READ;
    DWORD share = FILE_SHARE_READ;
    DWORD protect = writable ? PAGE_READWRITE : PAGE_READONLY;
    DWORD map_access = writable ? FILE_MAP_WRITE : FILE_MAP_READ;

    file_handle = CreateFileA(path, access, share, NULL, OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL, NULL);
    if (file_handle == INVALID_HANDLE_VALUE) {
        return -1;
    }

    if (!GetFileSizeEx(file_handle, &size)) {
        CloseHandle(file_handle);
        return -1;
    }

    if (size.QuadPart == 0) {
        CloseHandle(file_handle);
        return -1;
    }

    file_size = (size_t)size.QuadPart;

    map_handle = CreateFileMappingA(file_handle, NULL, protect, 0, 0, NULL);
    if (map_handle == NULL) {
        CloseHandle(file_handle);
        return -1;
    }

    addr = MapViewOfFile(map_handle, map_access, 0, 0, 0);
    if (addr == NULL) {
        CloseHandle(map_handle);
        CloseHandle(file_handle);
        return -1;
    }

    idx = alloc_mmap_slot();
    g_mmaps[idx].addr = addr;
    g_mmaps[idx].len = file_size;
    g_mmaps[idx].file_handle = file_handle;
    g_mmaps[idx].map_handle = map_handle;
    g_mmaps[idx].refcount = 1;

#else
    int fd;
    struct stat st;
    int flags = writable ? O_RDWR : O_RDONLY;
    int prot = writable ? (PROT_READ | PROT_WRITE) : PROT_READ;

    fd = open(path, flags);
    if (fd < 0) {
        return -1;
    }

    if (fstat(fd, &st) < 0) {
        close(fd);
        return -1;
    }

    if (st.st_size == 0) {
        /* Can't mmap empty file */
        close(fd);
        return -1;
    }

    file_size = st.st_size;

    addr = mmap(NULL, st.st_size, prot, MAP_SHARED, fd, 0);
    if (addr == MAP_FAILED) {
        close(fd);
        return -1;
    }

    idx = alloc_mmap_slot();
    g_mmaps[idx].addr = addr;
    g_mmaps[idx].len = file_size;
    g_mmaps[idx].fd = fd;
    g_mmaps[idx].refcount = 1;
#endif

    return idx;
}

static SV* file_mmap_get_sv(pTHX_ IV idx) {
    MmapEntry *entry;
    SV *sv;

    if (idx < 0 || idx >= g_mmaps_count) {
        return &PL_sv_undef;
    }

    entry = &g_mmaps[idx];
#ifdef _WIN32
    if (!entry->addr) {
        return &PL_sv_undef;
    }
#else
    if (!entry->addr || entry->addr == MAP_FAILED) {
        return &PL_sv_undef;
    }
#endif

    /* Create an SV that points directly to the mapped memory */
    sv = newSV(0);
    SvUPGRADE(sv, SVt_PV);
    SvPV_set(sv, (char*)entry->addr);
    SvCUR_set(sv, entry->len);
    SvLEN_set(sv, 0);  /* Don't free this memory! */
    SvPOK_on(sv);
    SvREADONLY_on(sv);

    return sv;
}

static void file_mmap_close(IV idx) {
    if (idx < 0 || idx >= g_mmaps_count) return;

    MmapEntry *entry = &g_mmaps[idx];
    entry->refcount--;
    if (entry->refcount <= 0) {
        free_mmap_slot(idx);
    }
}

static void file_mmap_sync(IV idx) {
    MmapEntry *entry;

    if (idx < 0 || idx >= g_mmaps_count) return;

    entry = &g_mmaps[idx];
#ifdef _WIN32
    if (entry->addr) {
        FlushViewOfFile(entry->addr, entry->len);
    }
#else
    if (entry->addr && entry->addr != MAP_FAILED) {
        msync(entry->addr, entry->len, MS_SYNC);
    }
#endif
}

/* ============================================
   Line iterator operations
   ============================================ */

static void ensure_iters_capacity(IV needed) {
    if (needed >= g_iters_size) {
        IV new_size = g_iters_size ? g_iters_size * 2 : 16;
        IV i;
        while (new_size <= needed) new_size *= 2;
        Renew(g_iters, new_size, LineIterEntry);
        for (i = g_iters_size; i < new_size; i++) {
            g_iters[i].fd = -1;
            g_iters[i].buffer = NULL;
            g_iters[i].buf_size = 0;
            g_iters[i].buf_pos = 0;
            g_iters[i].buf_len = 0;
            g_iters[i].eof = 0;
            g_iters[i].refcount = 0;
            g_iters[i].path = NULL;
        }
        g_iters_size = new_size;
    }
}

static IV alloc_iter_slot(void) {
    IV idx;

    if (g_free_iters_count > 0) {
        return g_free_iters[--g_free_iters_count];
    }

    ensure_iters_capacity(g_iters_count);
    idx = g_iters_count++;
    return idx;
}

static void free_iter_slot(IV idx) {
    LineIterEntry *entry;

    if (idx < 0 || idx >= g_iters_count) return;

    entry = &g_iters[idx];
    if (entry->fd >= 0) {
        close(entry->fd);
    }
    if (entry->buffer) {
        Safefree(entry->buffer);
    }
    if (entry->path) {
        Safefree(entry->path);
    }

    entry->fd = -1;
    entry->buffer = NULL;
    entry->buf_size = 0;
    entry->buf_pos = 0;
    entry->buf_len = 0;
    entry->eof = 0;
    entry->refcount = 0;
    entry->path = NULL;

    if (g_free_iters_count >= g_free_iters_size) {
        g_free_iters_size *= 2;
        Renew(g_free_iters, g_free_iters_size, IV);
    }
    g_free_iters[g_free_iters_count++] = idx;
}

static IV file_lines_open(pTHX_ const char *path) {
    int fd;
    IV idx;
    LineIterEntry *entry;
    size_t path_len;
#ifdef _WIN32
    int open_flags = O_RDONLY | O_BINARY;
#else
    int open_flags = O_RDONLY;
#endif

    fd = open(path, open_flags);
    if (fd < 0) {
        return -1;
    }

    idx = alloc_iter_slot();
    entry = &g_iters[idx];

    entry->fd = fd;
    entry->buf_size = FILE_BUFFER_SIZE;
    Newx(entry->buffer, entry->buf_size, char);
    entry->buf_pos = 0;
    entry->buf_len = 0;
    entry->eof = 0;
    entry->refcount = 1;

    path_len = strlen(path);
    Newx(entry->path, path_len + 1, char);
    memcpy(entry->path, path, path_len + 1);

    return idx;
}

static SV* file_lines_next(pTHX_ IV idx) {
    LineIterEntry *entry;
    char *line_start;
    char *newline;
    size_t line_len;
    SV *result;
    ssize_t n;

    if (idx < 0 || idx >= g_iters_count) {
        return &PL_sv_undef;
    }

    entry = &g_iters[idx];
    if (entry->fd < 0) {
        return &PL_sv_undef;
    }

    while (1) {
        /* Look for newline in current buffer */
        if (entry->buf_pos < entry->buf_len) {
            line_start = entry->buffer + entry->buf_pos;
            newline = memchr(line_start, '\n', entry->buf_len - entry->buf_pos);

            if (newline) {
                line_len = newline - line_start;
                result = newSVpvn(line_start, line_len);
                entry->buf_pos += line_len + 1;
                return result;
            }
        }

        /* No newline found, need more data */
        if (entry->eof) {
            /* Return remaining data if any */
            if (entry->buf_pos < entry->buf_len) {
                line_len = entry->buf_len - entry->buf_pos;
                result = newSVpvn(entry->buffer + entry->buf_pos, line_len);
                entry->buf_pos = entry->buf_len;
                return result;
            }
            return &PL_sv_undef;
        }

        /* Move remaining data to start of buffer */
        if (entry->buf_pos > 0) {
            size_t remaining = entry->buf_len - entry->buf_pos;
            if (remaining > 0) {
                memmove(entry->buffer, entry->buffer + entry->buf_pos, remaining);
            }
            entry->buf_len = remaining;
            entry->buf_pos = 0;
        }

        /* Expand buffer if needed */
        if (entry->buf_len >= entry->buf_size - 1) {
            entry->buf_size *= 2;
            Renew(entry->buffer, entry->buf_size, char);
        }

        /* Read more data */
        n = read(entry->fd, entry->buffer + entry->buf_len,
                 entry->buf_size - entry->buf_len - 1);
        if (n < 0) {
            if (errno == EINTR) continue;
            return &PL_sv_undef;
        }
        if (n == 0) {
            entry->eof = 1;
        } else {
            entry->buf_len += n;
        }
    }
}

static int file_lines_eof(IV idx) {
    LineIterEntry *entry;

    if (idx < 0 || idx >= g_iters_count) {
        return 1;
    }

    entry = &g_iters[idx];
    return entry->eof && entry->buf_pos >= entry->buf_len;
}

static void file_lines_close(IV idx) {
    if (idx < 0 || idx >= g_iters_count) return;

    LineIterEntry *entry = &g_iters[idx];
    entry->refcount--;
    if (entry->refcount <= 0) {
        free_iter_slot(idx);
    }
}

/* ============================================
   Fast stat operations
   ============================================ */

static IV file_size_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) {
        return -1;
    }
    return st.st_size;
}

static int file_exists_internal(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

static int file_is_file_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) return 0;
    return S_ISREG(st.st_mode);
}

static int file_is_dir_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) return 0;
    return S_ISDIR(st.st_mode);
}

static int file_is_readable_internal(const char *path) {
    return access(path, R_OK) == 0;
}

static int file_is_writable_internal(const char *path) {
    return access(path, W_OK) == 0;
}

static IV file_mtime_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) {
        return -1;
    }
    return st.st_mtime;
}

static IV file_atime_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) {
        return -1;
    }
    return st.st_atime;
}

static IV file_ctime_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) {
        return -1;
    }
    return st.st_ctime;
}

static IV file_mode_internal(const char *path) {
    struct stat st;
    if (stat(path, &st) < 0) {
        return -1;
    }
    return st.st_mode & 07777;  /* Return permission bits only */
}

static int file_is_link_internal(const char *path) {
#ifdef _WIN32
    /* Windows: check for reparse point */
    DWORD attrs = GetFileAttributesA(path);
    if (attrs == INVALID_FILE_ATTRIBUTES) return 0;
    return (attrs & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
#else
    struct stat st;
    if (lstat(path, &st) < 0) return 0;
    return S_ISLNK(st.st_mode);
#endif
}

static int file_is_executable_internal(const char *path) {
#ifdef _WIN32
    /* Windows: check file extension */
    const char *ext = strrchr(path, '.');
    if (ext) {
        if (_stricmp(ext, ".exe") == 0 || _stricmp(ext, ".bat") == 0 ||
            _stricmp(ext, ".cmd") == 0 || _stricmp(ext, ".com") == 0) {
            return 1;
        }
    }
    return 0;
#else
    return access(path, X_OK) == 0;
#endif
}

/* ============================================
   File manipulation operations
   ============================================ */

static int file_unlink_internal(const char *path) {
#ifdef _WIN32
    return _unlink(path) == 0;
#else
    return unlink(path) == 0;
#endif
}

static int file_copy_internal(pTHX_ const char *src, const char *dst) {
    int fd_src, fd_dst;
    char *buffer;
    ssize_t n_read, n_written, written;
    struct stat st;
    int result = 0;
#ifdef _WIN32
    int open_flags_r = O_RDONLY | O_BINARY;
    int open_flags_w = O_WRONLY | O_CREAT | O_TRUNC | O_BINARY;
#else
    int open_flags_r = O_RDONLY;
    int open_flags_w = O_WRONLY | O_CREAT | O_TRUNC;
#endif

    fd_src = open(src, open_flags_r);
    if (fd_src < 0) return 0;

    if (fstat(fd_src, &st) < 0) {
        close(fd_src);
        return 0;
    }

    fd_dst = open(dst, open_flags_w, st.st_mode & 07777);
    if (fd_dst < 0) {
        close(fd_src);
        return 0;
    }

    Newx(buffer, FILE_BULK_BUFFER_SIZE, char);

    while (1) {
        n_read = read(fd_src, buffer, FILE_BULK_BUFFER_SIZE);
        if (n_read < 0) {
            if (errno == EINTR) continue;
            goto cleanup;
        }
        if (n_read == 0) break;

        written = 0;
        while (written < n_read) {
            n_written = write(fd_dst, buffer + written, n_read - written);
            if (n_written < 0) {
                if (errno == EINTR) continue;
                goto cleanup;
            }
            written += n_written;
        }
    }

    result = 1;

cleanup:
    Safefree(buffer);
    close(fd_src);
    close(fd_dst);
    return result;
}

static int file_move_internal(pTHX_ const char *src, const char *dst) {
    /* Try rename first (fast path for same filesystem) */
    if (rename(src, dst) == 0) {
        return 1;
    }

    /* If EXDEV, copy then delete (cross-device move) */
    if (errno == EXDEV) {
        if (file_copy_internal(aTHX_ src, dst)) {
            return file_unlink_internal(src);
        }
    }

    return 0;
}

static int file_touch_internal(const char *path) {
#ifdef _WIN32
    HANDLE h;
    FILETIME ft;
    SYSTEMTIME st;
    int result = 0;

    /* Try to open existing file */
    h = CreateFileA(path, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                    NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) {
        return 0;
    }

    GetSystemTime(&st);
    SystemTimeToFileTime(&st, &ft);
    result = SetFileTime(h, NULL, &ft, &ft) != 0;
    CloseHandle(h);
    return result;
#else
    int fd;
    /* Try to update times on existing file - utime(path, NULL) sets to current time */
    if (utime(path, NULL) == 0) {
        return 1;
    }

    /* File doesn't exist, create it */
    fd = open(path, O_WRONLY | O_CREAT, 0644);
    if (fd < 0) return 0;
    close(fd);
    return 1;
#endif
}

static int file_chmod_internal(const char *path, int mode) {
#ifdef _WIN32
    return _chmod(path, mode) == 0;
#else
    return chmod(path, mode) == 0;
#endif
}

static int file_mkdir_internal(const char *path, int mode) {
#ifdef _WIN32
    PERL_UNUSED_VAR(mode);
    return _mkdir(path) == 0;
#else
    return mkdir(path, mode) == 0;
#endif
}

static int file_rmdir_internal(const char *path) {
#ifdef _WIN32
    return _rmdir(path) == 0;
#else
    return rmdir(path) == 0;
#endif
}

/* ============================================
   Directory listing
   ============================================ */

static AV* file_readdir_internal(pTHX_ const char *path) {
    AV *result = newAV();

#ifdef _WIN32
    WIN32_FIND_DATAA fd;
    HANDLE h;
    char pattern[MAX_PATH];
    size_t len = strlen(path);

    if (len + 3 > MAX_PATH) return result;

    memcpy(pattern, path, len);
    if (len > 0 && path[len-1] != '\\' && path[len-1] != '/') {
        pattern[len++] = '\\';
    }
    pattern[len++] = '*';
    pattern[len] = '\0';

    h = FindFirstFileA(pattern, &fd);
    if (h == INVALID_HANDLE_VALUE) return result;

    do {
        /* Skip . and .. */
        if (strcmp(fd.cFileName, ".") != 0 && strcmp(fd.cFileName, "..") != 0) {
            av_push(result, newSVpv(fd.cFileName, 0));
        }
    } while (FindNextFileA(h, &fd));

    FindClose(h);
#else
    DIR *dir;
    struct dirent *entry;

    dir = opendir(path);
    if (!dir) return result;

    while ((entry = readdir(dir)) != NULL) {
        /* Skip . and .. */
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
            av_push(result, newSVpv(entry->d_name, 0));
        }
    }

    closedir(dir);
#endif

    return result;
}

/* ============================================
   Path manipulation
   ============================================ */

static SV* file_basename_internal(pTHX_ const char *path) {
    const char *p;
    size_t len = strlen(path);

    if (len == 0) return newSVpvs("");

    /* Skip trailing slashes */
    while (len > 0 && (path[len-1] == '/' || path[len-1] == '\\')) {
        len--;
    }
    if (len == 0) return newSVpvs("");

    /* Find last separator */
    p = path + len - 1;
    while (p > path && *p != '/' && *p != '\\') {
        p--;
    }
    if (*p == '/' || *p == '\\') p++;

    return newSVpvn(p, (path + len) - p);
}

static SV* file_dirname_internal(pTHX_ const char *path) {
    const char *end;
    size_t len = strlen(path);

    if (len == 0) return newSVpvs(".");

    /* Skip trailing slashes */
    end = path + len - 1;
    while (end > path && (*end == '/' || *end == '\\')) {
        end--;
    }

    /* Find last separator */
    while (end > path && *end != '/' && *end != '\\') {
        end--;
    }

    if (end == path) {
        if (*end == '/' || *end == '\\') {
            return newSVpvn(path, 1);
        }
        return newSVpvs(".");
    }

    /* Skip multiple trailing slashes in dirname */
    while (end > path && (*(end-1) == '/' || *(end-1) == '\\')) {
        end--;
    }

    return newSVpvn(path, end - path);
}

static SV* file_extname_internal(pTHX_ const char *path) {
    const char *dot;
    const char *basename;
    size_t len = strlen(path);

    if (len == 0) return newSVpvs("");

    /* Find basename first */
    basename = path + len - 1;
    while (basename > path && *basename != '/' && *basename != '\\') {
        basename--;
    }
    if (*basename == '/' || *basename == '\\') basename++;

    /* Find last dot in basename */
    dot = strrchr(basename, '.');
    if (!dot || dot == basename) return newSVpvs("");

    return newSVpv(dot, 0);
}

static SV* file_join_internal(pTHX_ AV *parts) {
    SV *result;
    SSize_t i, len;
    STRLEN total_len = 0;
    char *buf, *p;
    int need_sep;

    len = av_len(parts) + 1;
    if (len == 0) return newSVpvs("");

    /* Calculate total length */
    for (i = 0; i < len; i++) {
        SV **sv = av_fetch(parts, i, 0);
        if (sv && SvPOK(*sv)) {
            total_len += SvCUR(*sv) + 1;  /* +1 for separator */
        }
    }

    result = newSV(total_len + 1);
    SvPOK_on(result);
    buf = SvPVX(result);
    p = buf;
    need_sep = 0;

    for (i = 0; i < len; i++) {
        SV **sv = av_fetch(parts, i, 0);
        if (sv && SvPOK(*sv)) {
            STRLEN part_len;
            const char *part = SvPV(*sv, part_len);

            if (part_len == 0) continue;

            /* Skip leading separator if we already have one */
            while (part_len > 0 && (*part == '/' || *part == '\\')) {
                if (!need_sep && p == buf) break;  /* Keep root slash */
                part++;
                part_len--;
            }

            if (need_sep && part_len > 0) {
#ifdef _WIN32
                *p++ = '\\';
#else
                *p++ = '/';
#endif
            }

            if (part_len > 0) {
                memcpy(p, part, part_len);
                p += part_len;

                /* Check if ends with separator */
                need_sep = (*(p-1) != '/' && *(p-1) != '\\');
            }
        }
    }

    *p = '\0';
    SvCUR_set(result, p - buf);
    return result;
}

/* ============================================
   Head and Tail operations
   ============================================ */

static AV* file_head_internal(pTHX_ const char *path, IV n) {
    AV *result = newAV();
    IV idx;
    SV *line;
    IV count = 0;

    if (n <= 0) return result;

    idx = file_lines_open(aTHX_ path);
    if (idx < 0) return result;

    while (count < n && (line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
        av_push(result, line);
        count++;
    }

    file_lines_close(idx);
    return result;
}

static AV* file_tail_internal(pTHX_ const char *path, IV n) {
    AV *result = newAV();
    AV *buffer;
    SV *line;
    IV idx;
    SSize_t i, buf_len;

    if (n <= 0) return result;

    idx = file_lines_open(aTHX_ path);
    if (idx < 0) return result;

    /* Use circular buffer to keep last N lines */
    buffer = newAV();
    av_extend(buffer, n - 1);

    while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
        if (av_len(buffer) + 1 >= n) {
            SV *old = av_shift(buffer);
            SvREFCNT_dec(old);
        }
        av_push(buffer, line);
    }

    file_lines_close(idx);

    /* Copy buffer to result */
    buf_len = av_len(buffer) + 1;
    for (i = 0; i < buf_len; i++) {
        SV **sv = av_fetch(buffer, i, 0);
        if (sv) {
            av_push(result, newSVsv(*sv));
        }
    }

    SvREFCNT_dec((SV*)buffer);
    return result;
}

/* ============================================
   Atomic spew - write to temp file then rename
   ============================================ */

static int file_atomic_spew_internal(pTHX_ const char *path, SV *data) {
    char temp_path[4096];
    int fd;
    const char *buf;
    STRLEN len;
    ssize_t written = 0, n;
    static int counter = 0;
#ifdef _WIN32
    int open_flags = O_WRONLY | O_CREAT | O_TRUNC | O_BINARY;
    int pid = (int)GetCurrentProcessId();
#else
    int open_flags = O_WRONLY | O_CREAT | O_TRUNC;
    int pid = (int)getpid();
#endif

    /* Create temp file name in same directory */
    snprintf(temp_path, sizeof(temp_path), "%s.tmp.%d.%d", path, pid, counter++);

    buf = SvPV(data, len);

    fd = open(temp_path, open_flags, 0644);
    if (fd < 0) {
        return 0;
    }

    while ((size_t)written < len) {
        n = write(fd, buf + written, len - written);
        if (n < 0) {
            if (errno == EINTR) continue;
            close(fd);
            file_unlink_internal(temp_path);
            return 0;
        }
        written += n;
    }

#ifdef _WIN32
    /* Sync to disk on Windows */
    _commit(fd);
#else
    /* Sync to disk on POSIX */
    fsync(fd);
#endif

    close(fd);

    /* Atomic rename */
    if (rename(temp_path, path) != 0) {
        file_unlink_internal(temp_path);
        return 0;
    }

    return 1;
}

/* ============================================
   Split lines utility
   ============================================ */

static AV* file_split_lines(pTHX_ SV *content) {
    AV *lines;
    const char *start, *end, *p;
    STRLEN len;

    start = SvPV(content, len);
    end = start + len;
    lines = newAV();

    while (start < end) {
        p = memchr(start, '\n', end - start);
        if (p) {
            av_push(lines, newSVpvn(start, p - start));
            start = p + 1;
        } else {
            if (start < end) {
                av_push(lines, newSVpvn(start, end - start));
            }
            break;
        }
    }

    return lines;
}

/* ============================================
   XS Functions
   ============================================ */

static XS(xs_slurp) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::slurp(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_slurp_internal(aTHX_ path));
    XSRETURN(1);
}

static XS(xs_slurp_raw) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::slurp_raw(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_slurp_raw(aTHX_ path));
    XSRETURN(1);
}

static XS(xs_spew) {
    dXSARGS;
    const char *path;

    if (items != 2) croak("Usage: file::spew(path, data)");

    path = SvPV_nolen(ST(0));
    if (file_spew_internal(aTHX_ path, ST(1))) {
        ST(0) = &PL_sv_yes;
    } else {
        ST(0) = &PL_sv_no;
    }
    XSRETURN(1);
}

static XS(xs_append) {
    dXSARGS;
    const char *path;

    if (items != 2) croak("Usage: file::append(path, data)");

    path = SvPV_nolen(ST(0));
    if (file_append_internal(aTHX_ path, ST(1))) {
        ST(0) = &PL_sv_yes;
    } else {
        ST(0) = &PL_sv_no;
    }
    XSRETURN(1);
}

static XS(xs_size) {
    dXSARGS;
    const char *path;
    IV size;

    if (items != 1) croak("Usage: file::size(path)");

    path = SvPV_nolen(ST(0));
    size = file_size_internal(path);
    ST(0) = sv_2mortal(newSViv(size));
    XSRETURN(1);
}

static XS(xs_mtime) {
    dXSARGS;
    const char *path;
    IV mtime;

    if (items != 1) croak("Usage: file::mtime(path)");

    path = SvPV_nolen(ST(0));
    mtime = file_mtime_internal(path);
    ST(0) = sv_2mortal(newSViv(mtime));
    XSRETURN(1);
}

static XS(xs_exists) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::exists(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = file_exists_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_is_file) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::is_file(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = file_is_file_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_is_dir) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::is_dir(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = file_is_dir_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_is_readable) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::is_readable(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = file_is_readable_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_is_writable) {
    dXSARGS;
    const char *path;

    if (items != 1) croak("Usage: file::is_writable(path)");

    path = SvPV_nolen(ST(0));
    ST(0) = file_is_writable_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_lines) {
    dXSARGS;
    const char *path;
    SV *content;
    AV *lines;

    if (items != 1) croak("Usage: file::lines(path)");

    path = SvPV_nolen(ST(0));
    content = file_slurp_internal(aTHX_ path);

    if (content == &PL_sv_undef) {
        ST(0) = sv_2mortal(newRV_noinc((SV*)newAV()));
        XSRETURN(1);
    }

    lines = file_split_lines(aTHX_ content);
    SvREFCNT_dec(content);

    ST(0) = sv_2mortal(newRV_noinc((SV*)lines));
    XSRETURN(1);
}

static XS(xs_mmap_open) {
    dXSARGS;
    const char *path;
    int writable;
    IV idx;
    HV *hash;

    if (items < 1 || items > 2) croak("Usage: file::mmap_open(path, [writable])");

    path = SvPV_nolen(ST(0));
    writable = (items > 1 && SvTRUE(ST(1))) ? 1 : 0;

    idx = file_mmap_open(aTHX_ path, writable);
    if (idx < 0) {
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }

    hash = newHV();
    hv_store(hash, "_idx", 4, newSViv(idx), 0);
    hv_store(hash, "_writable", 9, newSViv(writable), 0);

    ST(0) = sv_2mortal(sv_bless(newRV_noinc((SV*)hash), gv_stashpv("file::mmap", GV_ADD)));
    XSRETURN(1);
}

static XS(xs_mmap_data) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    if (items != 1) croak("Usage: $mmap->data");

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        croak("Invalid mmap object");
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    ST(0) = sv_2mortal(file_mmap_get_sv(aTHX_ idx));
    XSRETURN(1);
}

static XS(xs_mmap_sync) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    if (items != 1) croak("Usage: $mmap->sync");

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        croak("Invalid mmap object");
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    file_mmap_sync(idx);
    XSRETURN_EMPTY;
}

static XS(xs_mmap_close) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    if (items != 1) croak("Usage: $mmap->close");

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        croak("Invalid mmap object");
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    file_mmap_close(idx);
    hv_store(hash, "_idx", 4, newSViv(-1), 0);
    XSRETURN_EMPTY;
}

static XS(xs_mmap_DESTROY) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    PERL_UNUSED_VAR(items);

    if (PL_dirty) XSRETURN_EMPTY;

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        XSRETURN_EMPTY;
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    if (idx >= 0) {
        file_mmap_close(idx);
    }
    XSRETURN_EMPTY;
}

static XS(xs_lines_iter) {
    dXSARGS;
    const char *path;
    IV idx;
    HV *hash;

    if (items != 1) croak("Usage: file::lines_iter(path)");

    path = SvPV_nolen(ST(0));
    idx = file_lines_open(aTHX_ path);

    if (idx < 0) {
        ST(0) = &PL_sv_undef;
        XSRETURN(1);
    }

    hash = newHV();
    hv_store(hash, "_idx", 4, newSViv(idx), 0);

    ST(0) = sv_2mortal(sv_bless(newRV_noinc((SV*)hash), gv_stashpv("file::lines", GV_ADD)));
    XSRETURN(1);
}

static XS(xs_lines_iter_next) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;
    SV *line;

    if (items != 1) croak("Usage: $iter->next");

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        croak("Invalid lines iterator object");
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    line = file_lines_next(aTHX_ idx);
    if (line == &PL_sv_undef) {
        ST(0) = &PL_sv_undef;
    } else {
        ST(0) = sv_2mortal(line);
    }
    XSRETURN(1);
}

static XS(xs_lines_iter_eof) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    if (items != 1) croak("Usage: $iter->eof");

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        croak("Invalid lines iterator object");
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    ST(0) = file_lines_eof(idx) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_lines_iter_close) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    if (items != 1) croak("Usage: $iter->close");

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        croak("Invalid lines iterator object");
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    file_lines_close(idx);
    hv_store(hash, "_idx", 4, newSViv(-1), 0);
    XSRETURN_EMPTY;
}

static XS(xs_lines_iter_DESTROY) {
    dXSARGS;
    HV *hash;
    SV **idx_sv;
    IV idx;

    PERL_UNUSED_VAR(items);

    if (PL_dirty) XSRETURN_EMPTY;

    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVHV) {
        XSRETURN_EMPTY;
    }

    hash = (HV*)SvRV(ST(0));
    idx_sv = hv_fetch(hash, "_idx", 4, 0);
    idx = idx_sv ? SvIV(*idx_sv) : -1;

    if (idx >= 0) {
        file_lines_close(idx);
    }
    XSRETURN_EMPTY;
}

/* ============================================
   Callback registry for line processing
   Allows C-level predicates for maximum speed
   ============================================ */

/* Predicate function type for line processing */
typedef bool (*file_line_predicate)(pTHX_ SV *line);

/* Registered callback entry */
typedef struct {
    file_line_predicate predicate;  /* C function pointer (NULL for Perl-only) */
    SV *perl_callback;              /* Perl callback (for fallback or custom) */
} FileLineCallback;

/* Global callback registry */
static HV *g_file_callback_registry = NULL;

/* Built-in C predicates */
static bool pred_is_blank(pTHX_ SV *line) {
    STRLEN len;
    const char *s = SvPV(line, len);
    STRLEN i;
    for (i = 0; i < len; i++) {
        if (s[i] != ' ' && s[i] != '\t' && s[i] != '\r' && s[i] != '\n') {
            return FALSE;
        }
    }
    return TRUE;
}

static bool pred_is_not_blank(pTHX_ SV *line) {
    return !pred_is_blank(aTHX_ line);
}

static bool pred_is_empty(pTHX_ SV *line) {
    return SvCUR(line) == 0;
}

static bool pred_is_not_empty(pTHX_ SV *line) {
    return SvCUR(line) > 0;
}

static bool pred_is_comment(pTHX_ SV *line) {
    STRLEN len;
    const char *s = SvPV(line, len);
    /* Skip leading whitespace */
    while (len > 0 && (*s == ' ' || *s == '\t')) {
        s++;
        len--;
    }
    return len > 0 && *s == '#';
}

static bool pred_is_not_comment(pTHX_ SV *line) {
    return !pred_is_comment(aTHX_ line);
}

static void file_init_callback_registry(pTHX) {
    SV *sv;
    FileLineCallback *cb;

    if (g_file_callback_registry) return;
    g_file_callback_registry = newHV();

    /* Register built-in predicates with both naming conventions */
    /* blank / is_blank */
    Newxz(cb, 1, FileLineCallback);
    cb->predicate = pred_is_blank;
    cb->perl_callback = NULL;
    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, "blank", 5, sv, 0);
    hv_store(g_file_callback_registry, "is_blank", 8, SvREFCNT_inc(sv), 0);

    /* not_blank / is_not_blank */
    Newxz(cb, 1, FileLineCallback);
    cb->predicate = pred_is_not_blank;
    cb->perl_callback = NULL;
    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, "not_blank", 9, sv, 0);
    hv_store(g_file_callback_registry, "is_not_blank", 12, SvREFCNT_inc(sv), 0);

    /* empty / is_empty */
    Newxz(cb, 1, FileLineCallback);
    cb->predicate = pred_is_empty;
    cb->perl_callback = NULL;
    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, "empty", 5, sv, 0);
    hv_store(g_file_callback_registry, "is_empty", 8, SvREFCNT_inc(sv), 0);

    /* not_empty / is_not_empty */
    Newxz(cb, 1, FileLineCallback);
    cb->predicate = pred_is_not_empty;
    cb->perl_callback = NULL;
    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, "not_empty", 9, sv, 0);
    hv_store(g_file_callback_registry, "is_not_empty", 12, SvREFCNT_inc(sv), 0);

    /* comment / is_comment */
    Newxz(cb, 1, FileLineCallback);
    cb->predicate = pred_is_comment;
    cb->perl_callback = NULL;
    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, "comment", 7, sv, 0);
    hv_store(g_file_callback_registry, "is_comment", 10, SvREFCNT_inc(sv), 0);

    /* not_comment / is_not_comment */
    Newxz(cb, 1, FileLineCallback);
    cb->predicate = pred_is_not_comment;
    cb->perl_callback = NULL;
    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, "not_comment", 11, sv, 0);
    hv_store(g_file_callback_registry, "is_not_comment", 14, SvREFCNT_inc(sv), 0);
}

static FileLineCallback* file_get_callback(pTHX_ const char *name) {
    SV **svp;
    if (!g_file_callback_registry) return NULL;
    svp = hv_fetch(g_file_callback_registry, name, strlen(name), 0);
    if (svp && SvIOK(*svp)) {
        return INT2PTR(FileLineCallback*, SvIVX(*svp));
    }
    return NULL;
}

/* Process lines with callback - MULTICALL optimized */
static XS(xs_each_line) {
    dXSARGS;
    const char *path;
    SV *callback;
    IV idx;
    SV *line;
    CV *block_cv;

    if (items != 2) croak("Usage: file::each_line(path, callback)");

    path = SvPV_nolen(ST(0));
    callback = ST(1);

    if (!SvROK(callback) || SvTYPE(SvRV(callback)) != SVt_PVCV) {
        croak("Second argument must be a code reference");
    }

    block_cv = (CV*)SvRV(callback);
    idx = file_lines_open(aTHX_ path);
    if (idx < 0) {
        XSRETURN_EMPTY;
    }

    /* Process each line with the callback */
    /* Set both $_ and pass as argument so callbacks can use either style */
    {
        SV *old_defsv = DEFSV;
        SAVESPTR(DEFSV);  /* Automatically restore $_ on scope exit */

        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            dSP;
            ENTER;
            SAVETMPS;
            DEFSV_set(line);  /* Set $_ */
            PUSHMARK(SP);
            XPUSHs(line);  /* Don't mortalise - line is freed by file_lines_close or DEFSV restore */
            PUTBACK;
            call_sv(callback, G_DISCARD);
            FREETMPS;
            LEAVE;
            SvREFCNT_dec(line);  /* Release our reference after callback completes */
        }
    }

    file_lines_close(idx);
    XSRETURN_EMPTY;
}

/* Grep lines with callback or registered predicate name */
static XS(xs_grep_lines) {
    dXSARGS;
    const char *path;
    SV *predicate;
    IV idx;
    SV *line;
    AV *result;
    CV *block_cv = NULL;
    FileLineCallback *fcb = NULL;

    if (items != 2) croak("Usage: file::grep_lines(path, &predicate or $name)");

    path = SvPV_nolen(ST(0));
    predicate = ST(1);
    result = newAV();

    /* Check if predicate is a name or coderef */
    if (SvROK(predicate) && SvTYPE(SvRV(predicate)) == SVt_PVCV) {
        block_cv = (CV*)SvRV(predicate);
    } else {
        const char *name = SvPV_nolen(predicate);
        fcb = file_get_callback(aTHX_ name);
        if (!fcb) {
            croak("file::grep_lines: unknown predicate '%s'", name);
        }
    }

    idx = file_lines_open(aTHX_ path);
    if (idx < 0) {
        ST(0) = sv_2mortal(newRV_noinc((SV*)result));
        XSRETURN(1);
    }

    /* C predicate path - fastest */
    if (fcb && fcb->predicate) {
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            if (fcb->predicate(aTHX_ line)) {
                av_push(result, line);
            } else {
                SvREFCNT_dec(line);
            }
        }
        file_lines_close(idx);
        ST(0) = sv_2mortal(newRV_noinc((SV*)result));
        XSRETURN(1);
    }

    /* Call Perl callback - set both $_ and pass as argument */
    {
        SV *cb_sv = fcb ? fcb->perl_callback : (SV*)block_cv;
        SV *old_defsv = DEFSV;
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            dSP;
            IV count;
            DEFSV_set(line);  /* Set $_ */
            PUSHMARK(SP);
            XPUSHs(line);
            PUTBACK;
            count = call_sv(cb_sv, G_SCALAR);
            SPAGAIN;
            if (count > 0 && SvTRUE(POPs)) {
                av_push(result, line);
            } else {
                SvREFCNT_dec(line);
            }
            PUTBACK;
        }
        DEFSV_set(old_defsv);
    }

    file_lines_close(idx);
    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

/* Count lines matching predicate */
static XS(xs_count_lines) {
    dXSARGS;
    const char *path;
    SV *predicate = NULL;
    IV idx;
    SV *line;
    IV count = 0;
    CV *block_cv = NULL;
    FileLineCallback *fcb = NULL;

    if (items < 1 || items > 2) croak("Usage: file::count_lines(path, [&predicate or $name])");

    path = SvPV_nolen(ST(0));

    /* If no predicate, just count all lines */
    if (items == 1) {
        idx = file_lines_open(aTHX_ path);
        if (idx < 0) {
            ST(0) = sv_2mortal(newSViv(0));
            XSRETURN(1);
        }
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            count++;
            SvREFCNT_dec(line);
        }
        file_lines_close(idx);
        ST(0) = sv_2mortal(newSViv(count));
        XSRETURN(1);
    }

    predicate = ST(1);

    /* Check if predicate is a name or coderef */
    if (SvROK(predicate) && SvTYPE(SvRV(predicate)) == SVt_PVCV) {
        block_cv = (CV*)SvRV(predicate);
    } else {
        const char *name = SvPV_nolen(predicate);
        fcb = file_get_callback(aTHX_ name);
        if (!fcb) {
            croak("file::count_lines: unknown predicate '%s'", name);
        }
    }

    idx = file_lines_open(aTHX_ path);
    if (idx < 0) {
        ST(0) = sv_2mortal(newSViv(0));
        XSRETURN(1);
    }

    /* C predicate path - fastest */
    if (fcb && fcb->predicate) {
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            if (fcb->predicate(aTHX_ line)) {
                count++;
            }
            SvREFCNT_dec(line);
        }
        file_lines_close(idx);
        ST(0) = sv_2mortal(newSViv(count));
        XSRETURN(1);
    }

    /* Call Perl callback - set both $_ and pass as argument */
    {
        SV *cb_sv = fcb ? fcb->perl_callback : (SV*)block_cv;
        SV *old_defsv = DEFSV;
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            dSP;
            IV n;
            DEFSV_set(line);  /* Set $_ */
            PUSHMARK(SP);
            XPUSHs(line);
            PUTBACK;
            n = call_sv(cb_sv, G_SCALAR);
            SPAGAIN;
            if (n > 0 && SvTRUE(POPs)) {
                count++;
            }
            SvREFCNT_dec(line);
            PUTBACK;
        }
        DEFSV_set(old_defsv);
    }

    file_lines_close(idx);
    ST(0) = sv_2mortal(newSViv(count));
    XSRETURN(1);
}

/* Find first line matching predicate */
static XS(xs_find_line) {
    dXSARGS;
    const char *path;
    SV *predicate;
    IV idx;
    SV *line;
    CV *block_cv = NULL;
    FileLineCallback *fcb = NULL;

    if (items != 2) croak("Usage: file::find_line(path, &predicate or $name)");

    path = SvPV_nolen(ST(0));
    predicate = ST(1);

    /* Check if predicate is a name or coderef */
    if (SvROK(predicate) && SvTYPE(SvRV(predicate)) == SVt_PVCV) {
        block_cv = (CV*)SvRV(predicate);
    } else {
        const char *name = SvPV_nolen(predicate);
        fcb = file_get_callback(aTHX_ name);
        if (!fcb) {
            croak("file::find_line: unknown predicate '%s'", name);
        }
    }

    idx = file_lines_open(aTHX_ path);
    if (idx < 0) {
        XSRETURN_UNDEF;
    }

    /* C predicate path - fastest */
    if (fcb && fcb->predicate) {
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            if (fcb->predicate(aTHX_ line)) {
                file_lines_close(idx);
                ST(0) = sv_2mortal(line);
                XSRETURN(1);
            }
            SvREFCNT_dec(line);
        }
        file_lines_close(idx);
        XSRETURN_UNDEF;
    }

    /* Call Perl callback - set both $_ and pass as argument */
    {
        SV *cb_sv = fcb ? fcb->perl_callback : (SV*)block_cv;
        SV *old_defsv = DEFSV;
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            dSP;
            IV n;
            DEFSV_set(line);  /* Set $_ */
            PUSHMARK(SP);
            XPUSHs(line);
            PUTBACK;
            n = call_sv(cb_sv, G_SCALAR);
            SPAGAIN;
            if (n > 0 && SvTRUE(POPs)) {
                DEFSV_set(old_defsv);
                file_lines_close(idx);
                ST(0) = sv_2mortal(line);
                XSRETURN(1);
            }
            SvREFCNT_dec(line);
            PUTBACK;
        }
        DEFSV_set(old_defsv);
    }

    file_lines_close(idx);
    XSRETURN_UNDEF;
}

/* Map lines with callback */
static XS(xs_map_lines) {
    dXSARGS;
    const char *path;
    SV *callback;
    IV idx;
    SV *line;
    AV *result;
    CV *block_cv;

    if (items != 2) croak("Usage: file::map_lines(path, &callback)");

    path = SvPV_nolen(ST(0));
    callback = ST(1);
    result = newAV();

    if (!SvROK(callback) || SvTYPE(SvRV(callback)) != SVt_PVCV) {
        croak("Second argument must be a code reference");
    }

    block_cv = (CV*)SvRV(callback);
    idx = file_lines_open(aTHX_ path);
    if (idx < 0) {
        ST(0) = sv_2mortal(newRV_noinc((SV*)result));
        XSRETURN(1);
    }

    /* Call Perl callback - set both $_ and pass as argument */
    {
        SV *old_defsv = DEFSV;
        while ((line = file_lines_next(aTHX_ idx)) != &PL_sv_undef) {
            dSP;
            IV count;
            DEFSV_set(line);  /* Set $_ */
            PUSHMARK(SP);
            XPUSHs(sv_2mortal(line));
            PUTBACK;
            count = call_sv(callback, G_SCALAR);
            SPAGAIN;
            if (count > 0) {
                av_push(result, SvREFCNT_inc(POPs));
            }
            PUTBACK;
        }
        DEFSV_set(old_defsv);
    }

    file_lines_close(idx);
    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

/* Register a Perl callback */
static XS(xs_register_line_callback) {
    dXSARGS;
    const char *name;
    STRLEN name_len;
    SV *coderef;
    FileLineCallback *cb;
    SV *sv;

    if (items != 2) croak("Usage: file::register_line_callback($name, \\&coderef)");

    name = SvPV(ST(0), name_len);
    coderef = ST(1);

    if (!SvROK(coderef) || SvTYPE(SvRV(coderef)) != SVt_PVCV) {
        croak("file::register_line_callback: second argument must be a coderef");
    }

    file_init_callback_registry(aTHX);

    /* If already registered, just update the perl_callback in place */
    {
        FileLineCallback *existing = file_get_callback(aTHX_ name);
        if (existing) {
            /* Update existing - free old perl_callback and set new one */
            if (existing->perl_callback) {
                SvREFCNT_dec(existing->perl_callback);
            }
            existing->perl_callback = newSVsv(coderef);
            existing->predicate = NULL;  /* Clear any C predicate */
            XSRETURN_YES;
        }
    }

    Newxz(cb, 1, FileLineCallback);
    cb->predicate = NULL;  /* No C function */
    cb->perl_callback = newSVsv(coderef);

    sv = newSViv(PTR2IV(cb));
    hv_store(g_file_callback_registry, name, name_len, sv, 0);

    XSRETURN_YES;
}

/* List registered callbacks */
static XS(xs_list_line_callbacks) {
    dXSARGS;
    AV *result;
    HE *entry;

    PERL_UNUSED_VAR(items);

    result = newAV();
    if (g_file_callback_registry) {
        hv_iterinit(g_file_callback_registry);
        while ((entry = hv_iternext(g_file_callback_registry))) {
            av_push(result, newSVsv(hv_iterkeysv(entry)));
        }
    }

    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

/* New stat functions */
static XS(xs_atime) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::atime(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_atime_internal(path)));
    XSRETURN(1);
}

static XS(xs_ctime) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::ctime(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_ctime_internal(path)));
    XSRETURN(1);
}

static XS(xs_mode) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::mode(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_mode_internal(path)));
    XSRETURN(1);
}

static XS(xs_is_link) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::is_link(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_link_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_is_executable) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::is_executable(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_executable_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

/* File manipulation functions */
static XS(xs_unlink) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::unlink(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_unlink_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_copy) {
    dXSARGS;
    const char *src;
    const char *dst;
    if (items != 2) croak("Usage: file::copy(src, dst)");
    src = SvPV_nolen(ST(0));
    dst = SvPV_nolen(ST(1));
    ST(0) = file_copy_internal(aTHX_ src, dst) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_move) {
    dXSARGS;
    const char *src;
    const char *dst;
    if (items != 2) croak("Usage: file::move(src, dst)");
    src = SvPV_nolen(ST(0));
    dst = SvPV_nolen(ST(1));
    ST(0) = file_move_internal(aTHX_ src, dst) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_touch) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::touch(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_touch_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_chmod) {
    dXSARGS;
    const char *path;
    int mode;
    if (items != 2) croak("Usage: file::chmod(path, mode)");
    path = SvPV_nolen(ST(0));
    mode = SvIV(ST(1));
    ST(0) = file_chmod_internal(path, mode) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_mkdir) {
    dXSARGS;
    const char *path;
    int mode = 0755;
    if (items < 1 || items > 2) croak("Usage: file::mkdir(path, [mode])");
    path = SvPV_nolen(ST(0));
    if (items > 1) mode = SvIV(ST(1));
    ST(0) = file_mkdir_internal(path, mode) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_rmdir) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::rmdir(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_rmdir_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

static XS(xs_readdir) {
    dXSARGS;
    const char *path;
    AV *result;
    if (items != 1) croak("Usage: file::readdir(path)");
    path = SvPV_nolen(ST(0));
    result = file_readdir_internal(aTHX_ path);
    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

/* Path manipulation functions */
static XS(xs_basename) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::basename(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_basename_internal(aTHX_ path));
    XSRETURN(1);
}

static XS(xs_dirname) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::dirname(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_dirname_internal(aTHX_ path));
    XSRETURN(1);
}

static XS(xs_extname) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file::extname(path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_extname_internal(aTHX_ path));
    XSRETURN(1);
}

static XS(xs_join) {
    dXSARGS;
    AV *parts;
    SSize_t i;

    if (items < 1) croak("Usage: file::join(part1, part2, ...)");

    parts = newAV();
    for (i = 0; i < items; i++) {
        av_push(parts, newSVsv(ST(i)));
    }

    ST(0) = sv_2mortal(file_join_internal(aTHX_ parts));
    SvREFCNT_dec((SV*)parts);
    XSRETURN(1);
}

/* Head and tail */
static XS(xs_head) {
    dXSARGS;
    const char *path;
    AV *result;
    IV n = 10;  /* Default to 10 lines */
    if (items < 1 || items > 2) croak("Usage: file::head(path, [n])");
    path = SvPV_nolen(ST(0));
    if (items > 1) n = SvIV(ST(1));
    result = file_head_internal(aTHX_ path, n);
    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

static XS(xs_tail) {
    dXSARGS;
    const char *path;
    AV *result;
    IV n = 10;  /* Default to 10 lines */
    if (items < 1 || items > 2) croak("Usage: file::tail(path, [n])");
    path = SvPV_nolen(ST(0));
    if (items > 1) n = SvIV(ST(1));
    result = file_tail_internal(aTHX_ path, n);
    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

/* Atomic spew */
static XS(xs_atomic_spew) {
    dXSARGS;
    const char *path;
    if (items != 2) croak("Usage: file::atomic_spew(path, data)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_atomic_spew_internal(aTHX_ path, ST(1)) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

/* ============================================
   Function-style XS (for import)
   ============================================ */

XS_EXTERNAL(XS_file_func_slurp) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_slurp($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_slurp_internal(aTHX_ path));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_spew) {
    dXSARGS;
    const char *path;
    if (items != 2) croak("Usage: file_spew($path, $data)");
    path = SvPV_nolen(ST(0));
    if (file_spew_internal(aTHX_ path, ST(1))) {
        ST(0) = &PL_sv_yes;
    } else {
        ST(0) = &PL_sv_no;
    }
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_exists) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_exists($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_exists_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_size) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_size($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_size_internal(path)));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_is_file) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_is_file($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_file_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_is_dir) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_is_dir($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_dir_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_lines) {
    dXSARGS;
    const char *path;
    SV *content;
    AV *lines;
    if (items != 1) croak("Usage: file_lines($path)");
    path = SvPV_nolen(ST(0));
    content = file_slurp_internal(aTHX_ path);

    if (content == &PL_sv_undef) {
        lines = newAV();
    } else {
        lines = file_split_lines(aTHX_ content);
        SvREFCNT_dec(content);
    }

    ST(0) = sv_2mortal(newRV_noinc((SV*)lines));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_unlink) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_unlink($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_unlink_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_mkdir) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_mkdir($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_mkdir_internal(path, 0755) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_rmdir) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_rmdir($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_rmdir_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_touch) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_touch($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_touch_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_basename) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_basename($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_basename_internal(aTHX_ path));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_dirname) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_dirname($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_dirname_internal(aTHX_ path));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_extname) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_extname($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_extname_internal(aTHX_ path));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_mtime) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_mtime($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_mtime_internal(path)));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_atime) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_atime($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_atime_internal(path)));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_ctime) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_ctime($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_ctime_internal(path)));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_mode) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_mode($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(newSViv(file_mode_internal(path)));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_is_link) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_is_link($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_link_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_is_readable) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_is_readable($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_readable_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_is_writable) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_is_writable($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_writable_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_is_executable) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_is_executable($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_is_executable_internal(path) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_readdir) {
    dXSARGS;
    const char *path;
    AV *result;
    if (items != 1) croak("Usage: file_readdir($path)");
    path = SvPV_nolen(ST(0));
    result = file_readdir_internal(aTHX_ path);
    ST(0) = sv_2mortal(newRV_noinc((SV*)result));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_slurp_raw) {
    dXSARGS;
    const char *path;
    if (items != 1) croak("Usage: file_slurp_raw($path)");
    path = SvPV_nolen(ST(0));
    ST(0) = sv_2mortal(file_slurp_internal(aTHX_ path));
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_copy) {
    dXSARGS;
    const char *src;
    const char *dst;
    if (items != 2) croak("Usage: file_copy($src, $dst)");
    src = SvPV_nolen(ST(0));
    dst = SvPV_nolen(ST(1));
    ST(0) = file_copy_internal(aTHX_ src, dst) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_move) {
    dXSARGS;
    const char *src;
    const char *dst;
    if (items != 2) croak("Usage: file_move($src, $dst)");
    src = SvPV_nolen(ST(0));
    dst = SvPV_nolen(ST(1));
    ST(0) = file_move_internal(aTHX_ src, dst) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_chmod) {
    dXSARGS;
    const char *path;
    int mode;
    if (items != 2) croak("Usage: file_chmod($path, $mode)");
    path = SvPV_nolen(ST(0));
    mode = SvIV(ST(1));
    ST(0) = file_chmod_internal(path, mode) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_append) {
    dXSARGS;
    const char *path;
    if (items != 2) croak("Usage: file_append($path, $data)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_append_internal(aTHX_ path, ST(1)) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

XS_EXTERNAL(XS_file_func_atomic_spew) {
    dXSARGS;
    const char *path;
    if (items != 2) croak("Usage: file_atomic_spew($path, $data)");
    path = SvPV_nolen(ST(0));
    ST(0) = file_atomic_spew_internal(aTHX_ path, ST(1)) ? &PL_sv_yes : &PL_sv_no;
    XSRETURN(1);
}

/* file::import - import function-style accessors with custom ops */
XS_EXTERNAL(XS_file_import) {
    dXSARGS;
    const char *pkg;
    int i;
    bool want_import = FALSE;

    /* Get caller's package */
    pkg = CopSTASHPV(PL_curcop);

    /* Check for 'import' in args */
    for (i = 1; i < items; i++) {
        STRLEN len;
        const char *arg = SvPV(ST(i), len);
        if (len == 6 && strEQ(arg, "import")) {
            want_import = TRUE;
        }
    }

    if (want_import) {
        /* Install 1-arg functions with custom op optimization */
        install_file_func_1arg(aTHX_ pkg, "file_slurp", XS_file_func_slurp, pp_file_slurp);
        install_file_func_1arg(aTHX_ pkg, "file_exists", XS_file_func_exists, pp_file_exists);
        install_file_func_1arg(aTHX_ pkg, "file_size", XS_file_func_size, pp_file_size);
        install_file_func_1arg(aTHX_ pkg, "file_is_file", XS_file_func_is_file, pp_file_is_file);
        install_file_func_1arg(aTHX_ pkg, "file_is_dir", XS_file_func_is_dir, pp_file_is_dir);
        install_file_func_1arg(aTHX_ pkg, "file_lines", XS_file_func_lines, pp_file_lines);
        /* New 1-arg functions with custom op optimization */
        install_file_func_1arg(aTHX_ pkg, "file_unlink", XS_file_func_unlink, pp_file_unlink);
        install_file_func_1arg(aTHX_ pkg, "file_mkdir", XS_file_func_mkdir, pp_file_mkdir);
        install_file_func_1arg(aTHX_ pkg, "file_rmdir", XS_file_func_rmdir, pp_file_rmdir);
        install_file_func_1arg(aTHX_ pkg, "file_touch", XS_file_func_touch, pp_file_touch);
        install_file_func_1arg(aTHX_ pkg, "file_basename", XS_file_func_basename, pp_file_basename);
        install_file_func_1arg(aTHX_ pkg, "file_dirname", XS_file_func_dirname, pp_file_dirname);
        install_file_func_1arg(aTHX_ pkg, "file_extname", XS_file_func_extname, pp_file_extname);
        /* Stat functions */
        install_file_func_1arg(aTHX_ pkg, "file_mtime", XS_file_func_mtime, pp_file_mtime);
        install_file_func_1arg(aTHX_ pkg, "file_atime", XS_file_func_atime, pp_file_atime);
        install_file_func_1arg(aTHX_ pkg, "file_ctime", XS_file_func_ctime, pp_file_ctime);
        install_file_func_1arg(aTHX_ pkg, "file_mode", XS_file_func_mode, pp_file_mode);
        /* Type check functions */
        install_file_func_1arg(aTHX_ pkg, "file_is_link", XS_file_func_is_link, pp_file_is_link);
        install_file_func_1arg(aTHX_ pkg, "file_is_readable", XS_file_func_is_readable, pp_file_is_readable);
        install_file_func_1arg(aTHX_ pkg, "file_is_writable", XS_file_func_is_writable, pp_file_is_writable);
        install_file_func_1arg(aTHX_ pkg, "file_is_executable", XS_file_func_is_executable, pp_file_is_executable);
        /* Directory operations */
        install_file_func_1arg(aTHX_ pkg, "file_readdir", XS_file_func_readdir, pp_file_readdir);
        /* Slurp raw */
        install_file_func_1arg(aTHX_ pkg, "file_slurp_raw", XS_file_func_slurp_raw, pp_file_slurp_raw);
        /* 2-arg functions */
        install_file_func_2arg(aTHX_ pkg, "file_spew", XS_file_func_spew, pp_file_spew);
        install_file_func_2arg(aTHX_ pkg, "file_copy", XS_file_func_copy, pp_file_copy);
        install_file_func_2arg(aTHX_ pkg, "file_move", XS_file_func_move, pp_file_move);
        install_file_func_2arg(aTHX_ pkg, "file_chmod", XS_file_func_chmod, pp_file_chmod);
        install_file_func_2arg(aTHX_ pkg, "file_append", XS_file_func_append, pp_file_append);
        install_file_func_2arg(aTHX_ pkg, "file_atomic_spew", XS_file_func_atomic_spew, pp_file_atomic_spew);
    }

    XSRETURN_EMPTY;
}

/* ============================================
   Boot
   ============================================ */

XS_EXTERNAL(boot_file) {
    dXSBOOTARGSXSAPIVERCHK;
    PERL_UNUSED_VAR(items);

    file_init(aTHX);

    /* Register custom ops */
    XopENTRY_set(&file_slurp_xop, xop_name, "file_slurp");
    XopENTRY_set(&file_slurp_xop, xop_desc, "file slurp");
    Perl_custom_op_register(aTHX_ pp_file_slurp, &file_slurp_xop);

    XopENTRY_set(&file_spew_xop, xop_name, "file_spew");
    XopENTRY_set(&file_spew_xop, xop_desc, "file spew");
    Perl_custom_op_register(aTHX_ pp_file_spew, &file_spew_xop);

    XopENTRY_set(&file_exists_xop, xop_name, "file_exists");
    XopENTRY_set(&file_exists_xop, xop_desc, "file exists");
    Perl_custom_op_register(aTHX_ pp_file_exists, &file_exists_xop);

    XopENTRY_set(&file_size_xop, xop_name, "file_size");
    XopENTRY_set(&file_size_xop, xop_desc, "file size");
    Perl_custom_op_register(aTHX_ pp_file_size, &file_size_xop);

    XopENTRY_set(&file_is_file_xop, xop_name, "file_is_file");
    XopENTRY_set(&file_is_file_xop, xop_desc, "file is_file");
    Perl_custom_op_register(aTHX_ pp_file_is_file, &file_is_file_xop);

    XopENTRY_set(&file_is_dir_xop, xop_name, "file_is_dir");
    XopENTRY_set(&file_is_dir_xop, xop_desc, "file is_dir");
    Perl_custom_op_register(aTHX_ pp_file_is_dir, &file_is_dir_xop);

    XopENTRY_set(&file_lines_xop, xop_name, "file_lines");
    XopENTRY_set(&file_lines_xop, xop_desc, "file lines");
    Perl_custom_op_register(aTHX_ pp_file_lines, &file_lines_xop);

    XopENTRY_set(&file_unlink_xop, xop_name, "file_unlink");
    XopENTRY_set(&file_unlink_xop, xop_desc, "file unlink");
    Perl_custom_op_register(aTHX_ pp_file_unlink, &file_unlink_xop);

    XopENTRY_set(&file_mkdir_xop, xop_name, "file_mkdir");
    XopENTRY_set(&file_mkdir_xop, xop_desc, "file mkdir");
    Perl_custom_op_register(aTHX_ pp_file_mkdir, &file_mkdir_xop);

    XopENTRY_set(&file_rmdir_xop, xop_name, "file_rmdir");
    XopENTRY_set(&file_rmdir_xop, xop_desc, "file rmdir");
    Perl_custom_op_register(aTHX_ pp_file_rmdir, &file_rmdir_xop);

    XopENTRY_set(&file_touch_xop, xop_name, "file_touch");
    XopENTRY_set(&file_touch_xop, xop_desc, "file touch");
    Perl_custom_op_register(aTHX_ pp_file_touch, &file_touch_xop);

    XopENTRY_set(&file_basename_xop, xop_name, "file_basename");
    XopENTRY_set(&file_basename_xop, xop_desc, "file basename");
    Perl_custom_op_register(aTHX_ pp_file_basename, &file_basename_xop);

    XopENTRY_set(&file_dirname_xop, xop_name, "file_dirname");
    XopENTRY_set(&file_dirname_xop, xop_desc, "file dirname");
    Perl_custom_op_register(aTHX_ pp_file_dirname, &file_dirname_xop);

    XopENTRY_set(&file_extname_xop, xop_name, "file_extname");
    XopENTRY_set(&file_extname_xop, xop_desc, "file extname");
    Perl_custom_op_register(aTHX_ pp_file_extname, &file_extname_xop);

    XopENTRY_set(&file_mtime_xop, xop_name, "file_mtime");
    XopENTRY_set(&file_mtime_xop, xop_desc, "file mtime");
    Perl_custom_op_register(aTHX_ pp_file_mtime, &file_mtime_xop);

    XopENTRY_set(&file_atime_xop, xop_name, "file_atime");
    XopENTRY_set(&file_atime_xop, xop_desc, "file atime");
    Perl_custom_op_register(aTHX_ pp_file_atime, &file_atime_xop);

    XopENTRY_set(&file_ctime_xop, xop_name, "file_ctime");
    XopENTRY_set(&file_ctime_xop, xop_desc, "file ctime");
    Perl_custom_op_register(aTHX_ pp_file_ctime, &file_ctime_xop);

    XopENTRY_set(&file_mode_xop, xop_name, "file_mode");
    XopENTRY_set(&file_mode_xop, xop_desc, "file mode");
    Perl_custom_op_register(aTHX_ pp_file_mode, &file_mode_xop);

    XopENTRY_set(&file_is_link_xop, xop_name, "file_is_link");
    XopENTRY_set(&file_is_link_xop, xop_desc, "file is_link");
    Perl_custom_op_register(aTHX_ pp_file_is_link, &file_is_link_xop);

    XopENTRY_set(&file_is_readable_xop, xop_name, "file_is_readable");
    XopENTRY_set(&file_is_readable_xop, xop_desc, "file is_readable");
    Perl_custom_op_register(aTHX_ pp_file_is_readable, &file_is_readable_xop);

    XopENTRY_set(&file_is_writable_xop, xop_name, "file_is_writable");
    XopENTRY_set(&file_is_writable_xop, xop_desc, "file is_writable");
    Perl_custom_op_register(aTHX_ pp_file_is_writable, &file_is_writable_xop);

    XopENTRY_set(&file_is_executable_xop, xop_name, "file_is_executable");
    XopENTRY_set(&file_is_executable_xop, xop_desc, "file is_executable");
    Perl_custom_op_register(aTHX_ pp_file_is_executable, &file_is_executable_xop);

    XopENTRY_set(&file_readdir_xop, xop_name, "file_readdir");
    XopENTRY_set(&file_readdir_xop, xop_desc, "file readdir");
    Perl_custom_op_register(aTHX_ pp_file_readdir, &file_readdir_xop);

    XopENTRY_set(&file_slurp_raw_xop, xop_name, "file_slurp_raw");
    XopENTRY_set(&file_slurp_raw_xop, xop_desc, "file slurp_raw");
    Perl_custom_op_register(aTHX_ pp_file_slurp_raw, &file_slurp_raw_xop);

    XopENTRY_set(&file_copy_xop, xop_name, "file_copy");
    XopENTRY_set(&file_copy_xop, xop_desc, "file copy");
    Perl_custom_op_register(aTHX_ pp_file_copy, &file_copy_xop);

    XopENTRY_set(&file_move_xop, xop_name, "file_move");
    XopENTRY_set(&file_move_xop, xop_desc, "file move");
    Perl_custom_op_register(aTHX_ pp_file_move, &file_move_xop);

    XopENTRY_set(&file_chmod_xop, xop_name, "file_chmod");
    XopENTRY_set(&file_chmod_xop, xop_desc, "file chmod");
    Perl_custom_op_register(aTHX_ pp_file_chmod, &file_chmod_xop);

    XopENTRY_set(&file_append_xop, xop_name, "file_append");
    XopENTRY_set(&file_append_xop, xop_desc, "file append");
    Perl_custom_op_register(aTHX_ pp_file_append, &file_append_xop);

    XopENTRY_set(&file_atomic_spew_xop, xop_name, "file_atomic_spew");
    XopENTRY_set(&file_atomic_spew_xop, xop_desc, "file atomic_spew");
    Perl_custom_op_register(aTHX_ pp_file_atomic_spew, &file_atomic_spew_xop);

    /* Core functions */
    newXS("file::slurp", xs_slurp, __FILE__);
    newXS("file::slurp_raw", xs_slurp_raw, __FILE__);
    newXS("file::spew", xs_spew, __FILE__);
    newXS("file::append", xs_append, __FILE__);
    newXS("file::lines", xs_lines, __FILE__);
    newXS("file::each_line", xs_each_line, __FILE__);
    newXS("file::grep_lines", xs_grep_lines, __FILE__);
    newXS("file::count_lines", xs_count_lines, __FILE__);
    newXS("file::find_line", xs_find_line, __FILE__);
    newXS("file::map_lines", xs_map_lines, __FILE__);
    newXS("file::register_line_callback", xs_register_line_callback, __FILE__);
    newXS("file::list_line_callbacks", xs_list_line_callbacks, __FILE__);

    /* Stat functions */
    newXS("file::size", xs_size, __FILE__);
    newXS("file::mtime", xs_mtime, __FILE__);
    newXS("file::atime", xs_atime, __FILE__);
    newXS("file::ctime", xs_ctime, __FILE__);
    newXS("file::mode", xs_mode, __FILE__);
    newXS("file::exists", xs_exists, __FILE__);
    newXS("file::is_file", xs_is_file, __FILE__);
    newXS("file::is_dir", xs_is_dir, __FILE__);
    newXS("file::is_link", xs_is_link, __FILE__);
    newXS("file::is_readable", xs_is_readable, __FILE__);
    newXS("file::is_writable", xs_is_writable, __FILE__);
    newXS("file::is_executable", xs_is_executable, __FILE__);

    /* File manipulation */
    newXS("file::unlink", xs_unlink, __FILE__);
    newXS("file::copy", xs_copy, __FILE__);
    newXS("file::move", xs_move, __FILE__);
    newXS("file::touch", xs_touch, __FILE__);
    newXS("file::chmod", xs_chmod, __FILE__);
    newXS("file::mkdir", xs_mkdir, __FILE__);
    newXS("file::rmdir", xs_rmdir, __FILE__);
    newXS("file::readdir", xs_readdir, __FILE__);
    newXS("file::atomic_spew", xs_atomic_spew, __FILE__);

    /* Path manipulation */
    newXS("file::basename", xs_basename, __FILE__);
    newXS("file::dirname", xs_dirname, __FILE__);
    newXS("file::extname", xs_extname, __FILE__);
    newXS("file::join", xs_join, __FILE__);

    /* Head and tail */
    newXS("file::head", xs_head, __FILE__);
    newXS("file::tail", xs_tail, __FILE__);

    /* Import function */
    newXS("file::import", XS_file_import, __FILE__);

    /* Memory-mapped files */
    newXS("file::mmap_open", xs_mmap_open, __FILE__);
    newXS("file::mmap::data", xs_mmap_data, __FILE__);
    newXS("file::mmap::sync", xs_mmap_sync, __FILE__);
    newXS("file::mmap::close", xs_mmap_close, __FILE__);
    newXS("file::mmap::DESTROY", xs_mmap_DESTROY, __FILE__);

    /* Line iterators */
    newXS("file::lines_iter", xs_lines_iter, __FILE__);
    newXS("file::lines::next", xs_lines_iter_next, __FILE__);
    newXS("file::lines::eof", xs_lines_iter_eof, __FILE__);
    newXS("file::lines::close", xs_lines_iter_close, __FILE__);
    newXS("file::lines::DESTROY", xs_lines_iter_DESTROY, __FILE__);

    Perl_xs_boot_epilog(aTHX_ ax);
}
