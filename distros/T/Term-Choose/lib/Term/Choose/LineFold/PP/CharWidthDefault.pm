package Term::Choose::LineFold::PP::CharWidthDefault;

use warnings;
use strict;
use 5.10.1;

our $VERSION = '1.775';

use Exporter qw( import );

our @EXPORT_OK = qw( table_char_width );


# test with gnome-terminal - ambiguous characters set to narrow

# Control characters, non-characters and surrogates are removed before using this table.


sub table_char_width { [
#[     0x0,     0x1f, -1],
[    0x20,     0x7e, 1],
#[    0x7f,     0x9f, -1],
[    0xa0,    0x2ff, 1],
[   0x300,    0x36f, 0],
[   0x370,    0x482, 1],
[   0x483,    0x489, 0],
[   0x48a,    0x590, 1],
[   0x591,    0x5bd, 0],
[   0x5be,    0x5be, 1],
[   0x5bf,    0x5bf, 0],
[   0x5c0,    0x5c0, 1],
[   0x5c1,    0x5c2, 0],
[   0x5c3,    0x5c3, 1],
[   0x5c4,    0x5c5, 0],
[   0x5c6,    0x5c6, 1],
[   0x5c7,    0x5c7, 0],
[   0x5c8,    0x60f, 1],
[   0x610,    0x61a, 0],
[   0x61b,    0x61b, 1],
[   0x61c,    0x61c, 0],
[   0x61d,    0x64a, 1],
[   0x64b,    0x65f, 0],
[   0x660,    0x66f, 1],
[   0x670,    0x670, 0],
[   0x671,    0x6d5, 1],
[   0x6d6,    0x6dc, 0],
[   0x6dd,    0x6de, 1],
[   0x6df,    0x6e4, 0],
[   0x6e5,    0x6e6, 1],
[   0x6e7,    0x6e8, 0],
[   0x6e9,    0x6e9, 1],
[   0x6ea,    0x6ed, 0],
[   0x6ee,    0x70e, 1],
[   0x70f,    0x70f, 0],
[   0x710,    0x710, 1],
[   0x711,    0x711, 0],
[   0x712,    0x72f, 1],
[   0x730,    0x74a, 0],
[   0x74b,    0x7a5, 1],
[   0x7a6,    0x7b0, 0],
[   0x7b1,    0x7ea, 1],
[   0x7eb,    0x7f3, 0],
[   0x7f4,    0x7fc, 1],
[   0x7fd,    0x7fd, 0],
[   0x7fe,    0x815, 1],
[   0x816,    0x819, 0],
[   0x81a,    0x81a, 1],
[   0x81b,    0x823, 0],
[   0x824,    0x824, 1],
[   0x825,    0x827, 0],
[   0x828,    0x828, 1],
[   0x829,    0x82d, 0],
[   0x82e,    0x858, 1],
[   0x859,    0x85b, 0],
[   0x85c,    0x896, 1],
[   0x897,    0x89f, 0],
[   0x8a0,    0x8c9, 1],
[   0x8ca,    0x8e1, 0],
[   0x8e2,    0x8e2, 1],
[   0x8e3,    0x902, 0],
[   0x903,    0x939, 1],
[   0x93a,    0x93a, 0],
[   0x93b,    0x93b, 1],
[   0x93c,    0x93c, 0],
[   0x93d,    0x940, 1],
[   0x941,    0x948, 0],
[   0x949,    0x94c, 1],
[   0x94d,    0x94d, 0],
[   0x94e,    0x950, 1],
[   0x951,    0x957, 0],
[   0x958,    0x961, 1],
[   0x962,    0x963, 0],
[   0x964,    0x980, 1],
[   0x981,    0x981, 0],
[   0x982,    0x9bb, 1],
[   0x9bc,    0x9bc, 0],
[   0x9bd,    0x9c0, 1],
[   0x9c1,    0x9c4, 0],
[   0x9c5,    0x9cc, 1],
[   0x9cd,    0x9cd, 0],
[   0x9ce,    0x9e1, 1],
[   0x9e2,    0x9e3, 0],
[   0x9e4,    0x9fd, 1],
[   0x9fe,    0x9fe, 0],
[   0x9ff,    0xa00, 1],
[   0xa01,    0xa02, 0],
[   0xa03,    0xa3b, 1],
[   0xa3c,    0xa3c, 0],
[   0xa3d,    0xa40, 1],
[   0xa41,    0xa42, 0],
[   0xa43,    0xa46, 1],
[   0xa47,    0xa48, 0],
[   0xa49,    0xa4a, 1],
[   0xa4b,    0xa4d, 0],
[   0xa4e,    0xa50, 1],
[   0xa51,    0xa51, 0],
[   0xa52,    0xa6f, 1],
[   0xa70,    0xa71, 0],
[   0xa72,    0xa74, 1],
[   0xa75,    0xa75, 0],
[   0xa76,    0xa80, 1],
[   0xa81,    0xa82, 0],
[   0xa83,    0xabb, 1],
[   0xabc,    0xabc, 0],
[   0xabd,    0xac0, 1],
[   0xac1,    0xac5, 0],
[   0xac6,    0xac6, 1],
[   0xac7,    0xac8, 0],
[   0xac9,    0xacc, 1],
[   0xacd,    0xacd, 0],
[   0xace,    0xae1, 1],
[   0xae2,    0xae3, 0],
[   0xae4,    0xaf9, 1],
[   0xafa,    0xaff, 0],
[   0xb00,    0xb00, 1],
[   0xb01,    0xb01, 0],
[   0xb02,    0xb3b, 1],
[   0xb3c,    0xb3c, 0],
[   0xb3d,    0xb3e, 1],
[   0xb3f,    0xb3f, 0],
[   0xb40,    0xb40, 1],
[   0xb41,    0xb44, 0],
[   0xb45,    0xb4c, 1],
[   0xb4d,    0xb4d, 0],
[   0xb4e,    0xb54, 1],
[   0xb55,    0xb56, 0],
[   0xb57,    0xb61, 1],
[   0xb62,    0xb63, 0],
[   0xb64,    0xb81, 1],
[   0xb82,    0xb82, 0],
[   0xb83,    0xbbf, 1],
[   0xbc0,    0xbc0, 0],
[   0xbc1,    0xbcc, 1],
[   0xbcd,    0xbcd, 0],
[   0xbce,    0xbff, 1],
[   0xc00,    0xc00, 0],
[   0xc01,    0xc03, 1],
[   0xc04,    0xc04, 0],
[   0xc05,    0xc3b, 1],
[   0xc3c,    0xc3c, 0],
[   0xc3d,    0xc3d, 1],
[   0xc3e,    0xc40, 0],
[   0xc41,    0xc45, 1],
[   0xc46,    0xc48, 0],
[   0xc49,    0xc49, 1],
[   0xc4a,    0xc4d, 0],
[   0xc4e,    0xc54, 1],
[   0xc55,    0xc56, 0],
[   0xc57,    0xc61, 1],
[   0xc62,    0xc63, 0],
[   0xc64,    0xc80, 1],
[   0xc81,    0xc81, 0],
[   0xc82,    0xcbb, 1],
[   0xcbc,    0xcbc, 0],
[   0xcbd,    0xcbe, 1],
[   0xcbf,    0xcbf, 0],
[   0xcc0,    0xcc5, 1],
[   0xcc6,    0xcc6, 0],
[   0xcc7,    0xccb, 1],
[   0xccc,    0xccd, 0],
[   0xcce,    0xce1, 1],
[   0xce2,    0xce3, 0],
[   0xce4,    0xcff, 1],
[   0xd00,    0xd01, 0],
[   0xd02,    0xd3a, 1],
[   0xd3b,    0xd3c, 0],
[   0xd3d,    0xd40, 1],
[   0xd41,    0xd44, 0],
[   0xd45,    0xd4c, 1],
[   0xd4d,    0xd4d, 0],
[   0xd4e,    0xd61, 1],
[   0xd62,    0xd63, 0],
[   0xd64,    0xd80, 1],
[   0xd81,    0xd81, 0],
[   0xd82,    0xdc9, 1],
[   0xdca,    0xdca, 0],
[   0xdcb,    0xdd1, 1],
[   0xdd2,    0xdd4, 0],
[   0xdd5,    0xdd5, 1],
[   0xdd6,    0xdd6, 0],
[   0xdd7,    0xe30, 1],
[   0xe31,    0xe31, 0],
[   0xe32,    0xe33, 1],
[   0xe34,    0xe3a, 0],
[   0xe3b,    0xe46, 1],
[   0xe47,    0xe4e, 0],
[   0xe4f,    0xeb0, 1],
[   0xeb1,    0xeb1, 0],
[   0xeb2,    0xeb3, 1],
[   0xeb4,    0xebc, 0],
[   0xebd,    0xec7, 1],
[   0xec8,    0xece, 0],
[   0xecf,    0xf17, 1],
[   0xf18,    0xf19, 0],
[   0xf1a,    0xf34, 1],
[   0xf35,    0xf35, 0],
[   0xf36,    0xf36, 1],
[   0xf37,    0xf37, 0],
[   0xf38,    0xf38, 1],
[   0xf39,    0xf39, 0],
[   0xf3a,    0xf70, 1],
[   0xf71,    0xf7e, 0],
[   0xf7f,    0xf7f, 1],
[   0xf80,    0xf84, 0],
[   0xf85,    0xf85, 1],
[   0xf86,    0xf87, 0],
[   0xf88,    0xf8c, 1],
[   0xf8d,    0xf97, 0],
[   0xf98,    0xf98, 1],
[   0xf99,    0xfbc, 0],
[   0xfbd,    0xfc5, 1],
[   0xfc6,    0xfc6, 0],
[   0xfc7,   0x102c, 1],
[  0x102d,   0x1030, 0],
[  0x1031,   0x1031, 1],
[  0x1032,   0x1037, 0],
[  0x1038,   0x1038, 1],
[  0x1039,   0x103a, 0],
[  0x103b,   0x103c, 1],
[  0x103d,   0x103e, 0],
[  0x103f,   0x1057, 1],
[  0x1058,   0x1059, 0],
[  0x105a,   0x105d, 1],
[  0x105e,   0x1060, 0],
[  0x1061,   0x1070, 1],
[  0x1071,   0x1074, 0],
[  0x1075,   0x1081, 1],
[  0x1082,   0x1082, 0],
[  0x1083,   0x1084, 1],
[  0x1085,   0x1086, 0],
[  0x1087,   0x108c, 1],
[  0x108d,   0x108d, 0],
[  0x108e,   0x109c, 1],
[  0x109d,   0x109d, 0],
[  0x109e,   0x10ff, 1],
[  0x1100,   0x115f, 2],
[  0x1160,   0x11ff, 0],
[  0x1200,   0x135c, 1],
[  0x135d,   0x135f, 0],
[  0x1360,   0x1711, 1],
[  0x1712,   0x1714, 0],
[  0x1715,   0x1731, 1],
[  0x1732,   0x1733, 0],
[  0x1734,   0x1751, 1],
[  0x1752,   0x1753, 0],
[  0x1754,   0x1771, 1],
[  0x1772,   0x1773, 0],
[  0x1774,   0x17b3, 1],
[  0x17b4,   0x17b5, 0],
[  0x17b6,   0x17b6, 1],
[  0x17b7,   0x17bd, 0],
[  0x17be,   0x17c5, 1],
[  0x17c6,   0x17c6, 0],
[  0x17c7,   0x17c8, 1],
[  0x17c9,   0x17d3, 0],
[  0x17d4,   0x17dc, 1],
[  0x17dd,   0x17dd, 0],
[  0x17de,   0x180a, 1],
[  0x180b,   0x180f, 0],
[  0x1810,   0x1884, 1],
[  0x1885,   0x1886, 0],
[  0x1887,   0x18a8, 1],
[  0x18a9,   0x18a9, 0],
[  0x18aa,   0x191f, 1],
[  0x1920,   0x1922, 0],
[  0x1923,   0x1926, 1],
[  0x1927,   0x1928, 0],
[  0x1929,   0x1931, 1],
[  0x1932,   0x1932, 0],
[  0x1933,   0x1938, 1],
[  0x1939,   0x193b, 0],
[  0x193c,   0x1a16, 1],
[  0x1a17,   0x1a18, 0],
[  0x1a19,   0x1a1a, 1],
[  0x1a1b,   0x1a1b, 0],
[  0x1a1c,   0x1a55, 1],
[  0x1a56,   0x1a56, 0],
[  0x1a57,   0x1a57, 1],
[  0x1a58,   0x1a5e, 0],
[  0x1a5f,   0x1a5f, 1],
[  0x1a60,   0x1a60, 0],
[  0x1a61,   0x1a61, 1],
[  0x1a62,   0x1a62, 0],
[  0x1a63,   0x1a64, 1],
[  0x1a65,   0x1a6c, 0],
[  0x1a6d,   0x1a72, 1],
[  0x1a73,   0x1a7c, 0],
[  0x1a7d,   0x1a7e, 1],
[  0x1a7f,   0x1a7f, 0],
[  0x1a80,   0x1aaf, 1],
[  0x1ab0,   0x1ace, 0],
[  0x1acf,   0x1aff, 1],
[  0x1b00,   0x1b03, 0],
[  0x1b04,   0x1b33, 1],
[  0x1b34,   0x1b34, 0],
[  0x1b35,   0x1b35, 1],
[  0x1b36,   0x1b3a, 0],
[  0x1b3b,   0x1b3b, 1],
[  0x1b3c,   0x1b3c, 0],
[  0x1b3d,   0x1b41, 1],
[  0x1b42,   0x1b42, 0],
[  0x1b43,   0x1b6a, 1],
[  0x1b6b,   0x1b73, 0],
[  0x1b74,   0x1b7f, 1],
[  0x1b80,   0x1b81, 0],
[  0x1b82,   0x1ba1, 1],
[  0x1ba2,   0x1ba5, 0],
[  0x1ba6,   0x1ba7, 1],
[  0x1ba8,   0x1ba9, 0],
[  0x1baa,   0x1baa, 1],
[  0x1bab,   0x1bad, 0],
[  0x1bae,   0x1be5, 1],
[  0x1be6,   0x1be6, 0],
[  0x1be7,   0x1be7, 1],
[  0x1be8,   0x1be9, 0],
[  0x1bea,   0x1bec, 1],
[  0x1bed,   0x1bed, 0],
[  0x1bee,   0x1bee, 1],
[  0x1bef,   0x1bf1, 0],
[  0x1bf2,   0x1c2b, 1],
[  0x1c2c,   0x1c33, 0],
[  0x1c34,   0x1c35, 1],
[  0x1c36,   0x1c37, 0],
[  0x1c38,   0x1ccf, 1],
[  0x1cd0,   0x1cd2, 0],
[  0x1cd3,   0x1cd3, 1],
[  0x1cd4,   0x1ce0, 0],
[  0x1ce1,   0x1ce1, 1],
[  0x1ce2,   0x1ce8, 0],
[  0x1ce9,   0x1cec, 1],
[  0x1ced,   0x1ced, 0],
[  0x1cee,   0x1cf3, 1],
[  0x1cf4,   0x1cf4, 0],
[  0x1cf5,   0x1cf7, 1],
[  0x1cf8,   0x1cf9, 0],
[  0x1cfa,   0x1dbf, 1],
[  0x1dc0,   0x1dff, 0],
[  0x1e00,   0x200a, 1],
[  0x200b,   0x200f, 0],
[  0x2010,   0x2029, 1],
[  0x202a,   0x202e, 0],
[  0x202f,   0x205f, 1],
[  0x2060,   0x2064, 0],
[  0x2065,   0x2065, 1],
[  0x2066,   0x206f, 0],
[  0x2070,   0x20cf, 1],
[  0x20d0,   0x20f0, 0],
[  0x20f1,   0x2319, 1],
[  0x231a,   0x231b, 2],
[  0x231c,   0x2328, 1],
[  0x2329,   0x232a, 2],
[  0x232b,   0x23e8, 1],
[  0x23e9,   0x23ec, 2],
[  0x23ed,   0x23ef, 1],
[  0x23f0,   0x23f0, 2],
[  0x23f1,   0x23f2, 1],
[  0x23f3,   0x23f3, 2],
[  0x23f4,   0x25fc, 1],
[  0x25fd,   0x25fe, 2],
[  0x25ff,   0x2613, 1],
[  0x2614,   0x2615, 2],
[  0x2616,   0x262f, 1],
[  0x2630,   0x2637, 2],
[  0x2638,   0x2647, 1],
[  0x2648,   0x2653, 2],
[  0x2654,   0x267e, 1],
[  0x267f,   0x267f, 2],
[  0x2680,   0x2689, 1],
[  0x268a,   0x268f, 2],
[  0x2690,   0x2692, 1],
[  0x2693,   0x2693, 2],
[  0x2694,   0x26a0, 1],
[  0x26a1,   0x26a1, 2],
[  0x26a2,   0x26a9, 1],
[  0x26aa,   0x26ab, 2],
[  0x26ac,   0x26bc, 1],
[  0x26bd,   0x26be, 2],
[  0x26bf,   0x26c3, 1],
[  0x26c4,   0x26c5, 2],
[  0x26c6,   0x26cd, 1],
[  0x26ce,   0x26ce, 2],
[  0x26cf,   0x26d3, 1],
[  0x26d4,   0x26d4, 2],
[  0x26d5,   0x26e9, 1],
[  0x26ea,   0x26ea, 2],
[  0x26eb,   0x26f1, 1],
[  0x26f2,   0x26f3, 2],
[  0x26f4,   0x26f4, 1],
[  0x26f5,   0x26f5, 2],
[  0x26f6,   0x26f9, 1],
[  0x26fa,   0x26fa, 2],
[  0x26fb,   0x26fc, 1],
[  0x26fd,   0x26fd, 2],
[  0x26fe,   0x2704, 1],
[  0x2705,   0x2705, 2],
[  0x2706,   0x2709, 1],
[  0x270a,   0x270b, 2],
[  0x270c,   0x2727, 1],
[  0x2728,   0x2728, 2],
[  0x2729,   0x274b, 1],
[  0x274c,   0x274c, 2],
[  0x274d,   0x274d, 1],
[  0x274e,   0x274e, 2],
[  0x274f,   0x2752, 1],
[  0x2753,   0x2755, 2],
[  0x2756,   0x2756, 1],
[  0x2757,   0x2757, 2],
[  0x2758,   0x2794, 1],
[  0x2795,   0x2797, 2],
[  0x2798,   0x27af, 1],
[  0x27b0,   0x27b0, 2],
[  0x27b1,   0x27be, 1],
[  0x27bf,   0x27bf, 2],
[  0x27c0,   0x2b1a, 1],
[  0x2b1b,   0x2b1c, 2],
[  0x2b1d,   0x2b4f, 1],
[  0x2b50,   0x2b50, 2],
[  0x2b51,   0x2b54, 1],
[  0x2b55,   0x2b55, 2],
[  0x2b56,   0x2cee, 1],
[  0x2cef,   0x2cf1, 0],
[  0x2cf2,   0x2d7e, 1],
[  0x2d7f,   0x2d7f, 0],
[  0x2d80,   0x2ddf, 1],
[  0x2de0,   0x2dff, 0],
[  0x2e00,   0x2e7f, 1],
[  0x2e80,   0x2e99, 2],
[  0x2e9a,   0x2e9a, 1],
[  0x2e9b,   0x2ef3, 2],
[  0x2ef4,   0x2eff, 1],
[  0x2f00,   0x2fd5, 2],
[  0x2fd6,   0x2fef, 1],
[  0x2ff0,   0x3029, 2],
[  0x302a,   0x302d, 0],
[  0x302e,   0x303e, 2],
[  0x303f,   0x3040, 1],
[  0x3041,   0x3096, 2],
[  0x3097,   0x3098, 1],
[  0x3099,   0x309a, 0],
[  0x309b,   0x30ff, 2],
[  0x3100,   0x3104, 1],
[  0x3105,   0x312f, 2],
[  0x3130,   0x3130, 1],
[  0x3131,   0x318e, 2],
[  0x318f,   0x318f, 1],
[  0x3190,   0x31e5, 2],
[  0x31e6,   0x31ee, 1],
[  0x31ef,   0x321e, 2],
[  0x321f,   0x321f, 1],
[  0x3220,   0x3247, 2],
[  0x3248,   0x324f, 1],
[  0x3250,   0xa48c, 2],
[  0xa48d,   0xa48f, 1],
[  0xa490,   0xa4c6, 2],
[  0xa4c7,   0xa66e, 1],
[  0xa66f,   0xa672, 0],
[  0xa673,   0xa673, 1],
[  0xa674,   0xa67d, 0],
[  0xa67e,   0xa69d, 1],
[  0xa69e,   0xa69f, 0],
[  0xa6a0,   0xa6ef, 1],
[  0xa6f0,   0xa6f1, 0],
[  0xa6f2,   0xa801, 1],
[  0xa802,   0xa802, 0],
[  0xa803,   0xa805, 1],
[  0xa806,   0xa806, 0],
[  0xa807,   0xa80a, 1],
[  0xa80b,   0xa80b, 0],
[  0xa80c,   0xa824, 1],
[  0xa825,   0xa826, 0],
[  0xa827,   0xa82b, 1],
[  0xa82c,   0xa82c, 0],
[  0xa82d,   0xa8c3, 1],
[  0xa8c4,   0xa8c5, 0],
[  0xa8c6,   0xa8df, 1],
[  0xa8e0,   0xa8f1, 0],
[  0xa8f2,   0xa8fe, 1],
[  0xa8ff,   0xa8ff, 0],
[  0xa900,   0xa925, 1],
[  0xa926,   0xa92d, 0],
[  0xa92e,   0xa946, 1],
[  0xa947,   0xa951, 0],
[  0xa952,   0xa95f, 1],
[  0xa960,   0xa97c, 2],
[  0xa97d,   0xa97f, 1],
[  0xa980,   0xa982, 0],
[  0xa983,   0xa9b2, 1],
[  0xa9b3,   0xa9b3, 0],
[  0xa9b4,   0xa9b5, 1],
[  0xa9b6,   0xa9b9, 0],
[  0xa9ba,   0xa9bb, 1],
[  0xa9bc,   0xa9bd, 0],
[  0xa9be,   0xa9e4, 1],
[  0xa9e5,   0xa9e5, 0],
[  0xa9e6,   0xaa28, 1],
[  0xaa29,   0xaa2e, 0],
[  0xaa2f,   0xaa30, 1],
[  0xaa31,   0xaa32, 0],
[  0xaa33,   0xaa34, 1],
[  0xaa35,   0xaa36, 0],
[  0xaa37,   0xaa42, 1],
[  0xaa43,   0xaa43, 0],
[  0xaa44,   0xaa4b, 1],
[  0xaa4c,   0xaa4c, 0],
[  0xaa4d,   0xaa7b, 1],
[  0xaa7c,   0xaa7c, 0],
[  0xaa7d,   0xaaaf, 1],
[  0xaab0,   0xaab0, 0],
[  0xaab1,   0xaab1, 1],
[  0xaab2,   0xaab4, 0],
[  0xaab5,   0xaab6, 1],
[  0xaab7,   0xaab8, 0],
[  0xaab9,   0xaabd, 1],
[  0xaabe,   0xaabf, 0],
[  0xaac0,   0xaac0, 1],
[  0xaac1,   0xaac1, 0],
[  0xaac2,   0xaaeb, 1],
[  0xaaec,   0xaaed, 0],
[  0xaaee,   0xaaf5, 1],
[  0xaaf6,   0xaaf6, 0],
[  0xaaf7,   0xabe4, 1],
[  0xabe5,   0xabe5, 0],
[  0xabe6,   0xabe7, 1],
[  0xabe8,   0xabe8, 0],
[  0xabe9,   0xabec, 1],
[  0xabed,   0xabed, 0],
[  0xabee,   0xabff, 1],
[  0xac00,   0xd7a3, 2],
[  0xd7a4,   0xd7af, 1],
[  0xd7b0,   0xd7ff, 0],
#[  0xd800,   0xdfff, -1],
[  0xe000,   0xf8ff, 1],
[  0xf900,   0xfaff, 2],
[  0xfb00,   0xfb1d, 1],
[  0xfb1e,   0xfb1e, 0],
[  0xfb1f,   0xfdff, 1],
[  0xfe00,   0xfe0f, 0],
[  0xfe10,   0xfe19, 2],
[  0xfe1a,   0xfe1f, 1],
[  0xfe20,   0xfe2f, 0],
[  0xfe30,   0xfe52, 2],
[  0xfe53,   0xfe53, 1],
[  0xfe54,   0xfe66, 2],
[  0xfe67,   0xfe67, 1],
[  0xfe68,   0xfe6b, 2],
[  0xfe6c,   0xfefe, 1],
[  0xfeff,   0xfeff, 0],
[  0xff00,   0xff00, 1],
[  0xff01,   0xff60, 2],
[  0xff61,   0xffdf, 1],
[  0xffe0,   0xffe6, 2],
[  0xffe7,   0xfff8, 1],
[  0xfff9,   0xfffb, 0],
[  0xfffc,  0x101fc, 1],
[ 0x101fd,  0x101fd, 0],
[ 0x101fe,  0x102df, 1],
[ 0x102e0,  0x102e0, 0],
[ 0x102e1,  0x10375, 1],
[ 0x10376,  0x1037a, 0],
[ 0x1037b,  0x10a00, 1],
[ 0x10a01,  0x10a03, 0],
[ 0x10a04,  0x10a04, 1],
[ 0x10a05,  0x10a06, 0],
[ 0x10a07,  0x10a0b, 1],
[ 0x10a0c,  0x10a0f, 0],
[ 0x10a10,  0x10a37, 1],
[ 0x10a38,  0x10a3a, 0],
[ 0x10a3b,  0x10a3e, 1],
[ 0x10a3f,  0x10a3f, 0],
[ 0x10a40,  0x10ae4, 1],
[ 0x10ae5,  0x10ae6, 0],
[ 0x10ae7,  0x10d23, 1],
[ 0x10d24,  0x10d27, 0],
[ 0x10d28,  0x10d68, 1],
[ 0x10d69,  0x10d6d, 0],
[ 0x10d6e,  0x10eaa, 1],
[ 0x10eab,  0x10eac, 0],
[ 0x10ead,  0x10efb, 1],
[ 0x10efc,  0x10eff, 0],
[ 0x10f00,  0x10f45, 1],
[ 0x10f46,  0x10f50, 0],
[ 0x10f51,  0x10f81, 1],
[ 0x10f82,  0x10f85, 0],
[ 0x10f86,  0x11000, 1],
[ 0x11001,  0x11001, 0],
[ 0x11002,  0x11037, 1],
[ 0x11038,  0x11046, 0],
[ 0x11047,  0x1106f, 1],
[ 0x11070,  0x11070, 0],
[ 0x11071,  0x11072, 1],
[ 0x11073,  0x11074, 0],
[ 0x11075,  0x1107e, 1],
[ 0x1107f,  0x11081, 0],
[ 0x11082,  0x110b2, 1],
[ 0x110b3,  0x110b6, 0],
[ 0x110b7,  0x110b8, 1],
[ 0x110b9,  0x110ba, 0],
[ 0x110bb,  0x110bc, 1],
[ 0x110bd,  0x110bd, 0],
[ 0x110be,  0x110c1, 1],
[ 0x110c2,  0x110c2, 0],
[ 0x110c3,  0x110cc, 1],
[ 0x110cd,  0x110cd, 0],
[ 0x110ce,  0x110ff, 1],
[ 0x11100,  0x11102, 0],
[ 0x11103,  0x11126, 1],
[ 0x11127,  0x1112b, 0],
[ 0x1112c,  0x1112c, 1],
[ 0x1112d,  0x11134, 0],
[ 0x11135,  0x11172, 1],
[ 0x11173,  0x11173, 0],
[ 0x11174,  0x1117f, 1],
[ 0x11180,  0x11181, 0],
[ 0x11182,  0x111b5, 1],
[ 0x111b6,  0x111be, 0],
[ 0x111bf,  0x111c8, 1],
[ 0x111c9,  0x111cc, 0],
[ 0x111cd,  0x111ce, 1],
[ 0x111cf,  0x111cf, 0],
[ 0x111d0,  0x1122e, 1],
[ 0x1122f,  0x11231, 0],
[ 0x11232,  0x11233, 1],
[ 0x11234,  0x11234, 0],
[ 0x11235,  0x11235, 1],
[ 0x11236,  0x11237, 0],
[ 0x11238,  0x1123d, 1],
[ 0x1123e,  0x1123e, 0],
[ 0x1123f,  0x11240, 1],
[ 0x11241,  0x11241, 0],
[ 0x11242,  0x112de, 1],
[ 0x112df,  0x112df, 0],
[ 0x112e0,  0x112e2, 1],
[ 0x112e3,  0x112ea, 0],
[ 0x112eb,  0x112ff, 1],
[ 0x11300,  0x11301, 0],
[ 0x11302,  0x1133a, 1],
[ 0x1133b,  0x1133c, 0],
[ 0x1133d,  0x1133f, 1],
[ 0x11340,  0x11340, 0],
[ 0x11341,  0x11365, 1],
[ 0x11366,  0x1136c, 0],
[ 0x1136d,  0x1136f, 1],
[ 0x11370,  0x11374, 0],
[ 0x11375,  0x113ba, 1],
[ 0x113bb,  0x113c0, 0],
[ 0x113c1,  0x113cd, 1],
[ 0x113ce,  0x113ce, 0],
[ 0x113cf,  0x113cf, 1],
[ 0x113d0,  0x113d0, 0],
[ 0x113d1,  0x113d1, 1],
[ 0x113d2,  0x113d2, 0],
[ 0x113d3,  0x113e0, 1],
[ 0x113e1,  0x113e2, 0],
[ 0x113e3,  0x11437, 1],
[ 0x11438,  0x1143f, 0],
[ 0x11440,  0x11441, 1],
[ 0x11442,  0x11444, 0],
[ 0x11445,  0x11445, 1],
[ 0x11446,  0x11446, 0],
[ 0x11447,  0x1145d, 1],
[ 0x1145e,  0x1145e, 0],
[ 0x1145f,  0x114b2, 1],
[ 0x114b3,  0x114b8, 0],
[ 0x114b9,  0x114b9, 1],
[ 0x114ba,  0x114ba, 0],
[ 0x114bb,  0x114be, 1],
[ 0x114bf,  0x114c0, 0],
[ 0x114c1,  0x114c1, 1],
[ 0x114c2,  0x114c3, 0],
[ 0x114c4,  0x115b1, 1],
[ 0x115b2,  0x115b5, 0],
[ 0x115b6,  0x115bb, 1],
[ 0x115bc,  0x115bd, 0],
[ 0x115be,  0x115be, 1],
[ 0x115bf,  0x115c0, 0],
[ 0x115c1,  0x115db, 1],
[ 0x115dc,  0x115dd, 0],
[ 0x115de,  0x11632, 1],
[ 0x11633,  0x1163a, 0],
[ 0x1163b,  0x1163c, 1],
[ 0x1163d,  0x1163d, 0],
[ 0x1163e,  0x1163e, 1],
[ 0x1163f,  0x11640, 0],
[ 0x11641,  0x116aa, 1],
[ 0x116ab,  0x116ab, 0],
[ 0x116ac,  0x116ac, 1],
[ 0x116ad,  0x116ad, 0],
[ 0x116ae,  0x116af, 1],
[ 0x116b0,  0x116b5, 0],
[ 0x116b6,  0x116b6, 1],
[ 0x116b7,  0x116b7, 0],
[ 0x116b8,  0x1171c, 1],
[ 0x1171d,  0x1171d, 0],
[ 0x1171e,  0x1171e, 1],
[ 0x1171f,  0x1171f, 0],
[ 0x11720,  0x11721, 1],
[ 0x11722,  0x11725, 0],
[ 0x11726,  0x11726, 1],
[ 0x11727,  0x1172b, 0],
[ 0x1172c,  0x1182e, 1],
[ 0x1182f,  0x11837, 0],
[ 0x11838,  0x11838, 1],
[ 0x11839,  0x1183a, 0],
[ 0x1183b,  0x1193a, 1],
[ 0x1193b,  0x1193c, 0],
[ 0x1193d,  0x1193d, 1],
[ 0x1193e,  0x1193e, 0],
[ 0x1193f,  0x11942, 1],
[ 0x11943,  0x11943, 0],
[ 0x11944,  0x119d3, 1],
[ 0x119d4,  0x119d7, 0],
[ 0x119d8,  0x119d9, 1],
[ 0x119da,  0x119db, 0],
[ 0x119dc,  0x119df, 1],
[ 0x119e0,  0x119e0, 0],
[ 0x119e1,  0x11a00, 1],
[ 0x11a01,  0x11a0a, 0],
[ 0x11a0b,  0x11a32, 1],
[ 0x11a33,  0x11a38, 0],
[ 0x11a39,  0x11a3a, 1],
[ 0x11a3b,  0x11a3e, 0],
[ 0x11a3f,  0x11a46, 1],
[ 0x11a47,  0x11a47, 0],
[ 0x11a48,  0x11a50, 1],
[ 0x11a51,  0x11a56, 0],
[ 0x11a57,  0x11a58, 1],
[ 0x11a59,  0x11a5b, 0],
[ 0x11a5c,  0x11a89, 1],
[ 0x11a8a,  0x11a96, 0],
[ 0x11a97,  0x11a97, 1],
[ 0x11a98,  0x11a99, 0],
[ 0x11a9a,  0x11c2f, 1],
[ 0x11c30,  0x11c36, 0],
[ 0x11c37,  0x11c37, 1],
[ 0x11c38,  0x11c3d, 0],
[ 0x11c3e,  0x11c3e, 1],
[ 0x11c3f,  0x11c3f, 0],
[ 0x11c40,  0x11c91, 1],
[ 0x11c92,  0x11ca7, 0],
[ 0x11ca8,  0x11ca9, 1],
[ 0x11caa,  0x11cb0, 0],
[ 0x11cb1,  0x11cb1, 1],
[ 0x11cb2,  0x11cb3, 0],
[ 0x11cb4,  0x11cb4, 1],
[ 0x11cb5,  0x11cb6, 0],
[ 0x11cb7,  0x11d30, 1],
[ 0x11d31,  0x11d36, 0],
[ 0x11d37,  0x11d39, 1],
[ 0x11d3a,  0x11d3a, 0],
[ 0x11d3b,  0x11d3b, 1],
[ 0x11d3c,  0x11d3d, 0],
[ 0x11d3e,  0x11d3e, 1],
[ 0x11d3f,  0x11d45, 0],
[ 0x11d46,  0x11d46, 1],
[ 0x11d47,  0x11d47, 0],
[ 0x11d48,  0x11d8f, 1],
[ 0x11d90,  0x11d91, 0],
[ 0x11d92,  0x11d94, 1],
[ 0x11d95,  0x11d95, 0],
[ 0x11d96,  0x11d96, 1],
[ 0x11d97,  0x11d97, 0],
[ 0x11d98,  0x11ef2, 1],
[ 0x11ef3,  0x11ef4, 0],
[ 0x11ef5,  0x11eff, 1],
[ 0x11f00,  0x11f01, 0],
[ 0x11f02,  0x11f35, 1],
[ 0x11f36,  0x11f3a, 0],
[ 0x11f3b,  0x11f3f, 1],
[ 0x11f40,  0x11f40, 0],
[ 0x11f41,  0x11f41, 1],
[ 0x11f42,  0x11f42, 0],
[ 0x11f43,  0x11f59, 1],
[ 0x11f5a,  0x11f5a, 0],
[ 0x11f5b,  0x1342f, 1],
[ 0x13430,  0x13440, 0],
[ 0x13441,  0x13446, 1],
[ 0x13447,  0x13455, 0],
[ 0x13456,  0x1611d, 1],
[ 0x1611e,  0x16129, 0],
[ 0x1612a,  0x1612c, 1],
[ 0x1612d,  0x1612f, 0],
[ 0x16130,  0x16aef, 1],
[ 0x16af0,  0x16af4, 0],
[ 0x16af5,  0x16b2f, 1],
[ 0x16b30,  0x16b36, 0],
[ 0x16b37,  0x16f4e, 1],
[ 0x16f4f,  0x16f4f, 0],
[ 0x16f50,  0x16f8e, 1],
[ 0x16f8f,  0x16f92, 0],
[ 0x16f93,  0x16fdf, 1],
[ 0x16fe0,  0x16fe3, 2],
[ 0x16fe4,  0x16fe4, 0],
[ 0x16fe5,  0x16fef, 1],
[ 0x16ff0,  0x16ff1, 2],
[ 0x16ff2,  0x16fff, 1],
[ 0x17000,  0x187f7, 2],
[ 0x187f8,  0x187ff, 1],
[ 0x18800,  0x18cd5, 2],
[ 0x18cd6,  0x18cfe, 1],
[ 0x18cff,  0x18d08, 2],
[ 0x18d09,  0x1afef, 1],
[ 0x1aff0,  0x1aff3, 2],
[ 0x1aff4,  0x1aff4, 1],
[ 0x1aff5,  0x1affb, 2],
[ 0x1affc,  0x1affc, 1],
[ 0x1affd,  0x1affe, 2],
[ 0x1afff,  0x1afff, 1],
[ 0x1b000,  0x1b122, 2],
[ 0x1b123,  0x1b131, 1],
[ 0x1b132,  0x1b132, 2],
[ 0x1b133,  0x1b14f, 1],
[ 0x1b150,  0x1b152, 2],
[ 0x1b153,  0x1b154, 1],
[ 0x1b155,  0x1b155, 2],
[ 0x1b156,  0x1b163, 1],
[ 0x1b164,  0x1b167, 2],
[ 0x1b168,  0x1b16f, 1],
[ 0x1b170,  0x1b2fb, 2],
[ 0x1b2fc,  0x1bc9c, 1],
[ 0x1bc9d,  0x1bc9e, 0],
[ 0x1bc9f,  0x1bc9f, 1],
[ 0x1bca0,  0x1bca3, 0],
[ 0x1bca4,  0x1ceff, 1],
[ 0x1cf00,  0x1cf2d, 0],
[ 0x1cf2e,  0x1cf2f, 1],
[ 0x1cf30,  0x1cf46, 0],
[ 0x1cf47,  0x1d166, 1],
[ 0x1d167,  0x1d169, 0],
[ 0x1d16a,  0x1d172, 1],
[ 0x1d173,  0x1d182, 0],
[ 0x1d183,  0x1d184, 1],
[ 0x1d185,  0x1d18b, 0],
[ 0x1d18c,  0x1d1a9, 1],
[ 0x1d1aa,  0x1d1ad, 0],
[ 0x1d1ae,  0x1d241, 1],
[ 0x1d242,  0x1d244, 0],
[ 0x1d245,  0x1d2ff, 1],
[ 0x1d300,  0x1d356, 2],
[ 0x1d357,  0x1d35f, 1],
[ 0x1d360,  0x1d376, 2],
[ 0x1d377,  0x1d9ff, 1],
[ 0x1da00,  0x1da36, 0],
[ 0x1da37,  0x1da3a, 1],
[ 0x1da3b,  0x1da6c, 0],
[ 0x1da6d,  0x1da74, 1],
[ 0x1da75,  0x1da75, 0],
[ 0x1da76,  0x1da83, 1],
[ 0x1da84,  0x1da84, 0],
[ 0x1da85,  0x1da9a, 1],
[ 0x1da9b,  0x1da9f, 0],
[ 0x1daa0,  0x1daa0, 1],
[ 0x1daa1,  0x1daaf, 0],
[ 0x1dab0,  0x1dfff, 1],
[ 0x1e000,  0x1e006, 0],
[ 0x1e007,  0x1e007, 1],
[ 0x1e008,  0x1e018, 0],
[ 0x1e019,  0x1e01a, 1],
[ 0x1e01b,  0x1e021, 0],
[ 0x1e022,  0x1e022, 1],
[ 0x1e023,  0x1e024, 0],
[ 0x1e025,  0x1e025, 1],
[ 0x1e026,  0x1e02a, 0],
[ 0x1e02b,  0x1e08e, 1],
[ 0x1e08f,  0x1e08f, 0],
[ 0x1e090,  0x1e12f, 1],
[ 0x1e130,  0x1e136, 0],
[ 0x1e137,  0x1e2ad, 1],
[ 0x1e2ae,  0x1e2ae, 0],
[ 0x1e2af,  0x1e2eb, 1],
[ 0x1e2ec,  0x1e2ef, 0],
[ 0x1e2f0,  0x1e4eb, 1],
[ 0x1e4ec,  0x1e4ef, 0],
[ 0x1e4f0,  0x1e5ed, 1],
[ 0x1e5ee,  0x1e5ef, 0],
[ 0x1e5f0,  0x1e8cf, 1],
[ 0x1e8d0,  0x1e8d6, 0],
[ 0x1e8d7,  0x1e943, 1],
[ 0x1e944,  0x1e94a, 0],
[ 0x1e94b,  0x1f003, 1],
[ 0x1f004,  0x1f004, 2],
[ 0x1f005,  0x1f0ce, 1],
[ 0x1f0cf,  0x1f0cf, 2],
[ 0x1f0d0,  0x1f18d, 1],
[ 0x1f18e,  0x1f18e, 2],
[ 0x1f18f,  0x1f190, 1],
[ 0x1f191,  0x1f19a, 2],
[ 0x1f19b,  0x1f1ff, 1],
[ 0x1f200,  0x1f202, 2],
[ 0x1f203,  0x1f20f, 1],
[ 0x1f210,  0x1f23b, 2],
[ 0x1f23c,  0x1f23f, 1],
[ 0x1f240,  0x1f248, 2],
[ 0x1f249,  0x1f24f, 1],
[ 0x1f250,  0x1f251, 2],
[ 0x1f252,  0x1f25f, 1],
[ 0x1f260,  0x1f265, 2],
[ 0x1f266,  0x1f2ff, 1],
[ 0x1f300,  0x1f320, 2],
[ 0x1f321,  0x1f32c, 1],
[ 0x1f32d,  0x1f335, 2],
[ 0x1f336,  0x1f336, 1],
[ 0x1f337,  0x1f37c, 2],
[ 0x1f37d,  0x1f37d, 1],
[ 0x1f37e,  0x1f393, 2],
[ 0x1f394,  0x1f39f, 1],
[ 0x1f3a0,  0x1f3ca, 2],
[ 0x1f3cb,  0x1f3ce, 1],
[ 0x1f3cf,  0x1f3d3, 2],
[ 0x1f3d4,  0x1f3df, 1],
[ 0x1f3e0,  0x1f3f0, 2],
[ 0x1f3f1,  0x1f3f3, 1],
[ 0x1f3f4,  0x1f3f4, 2],
[ 0x1f3f5,  0x1f3f7, 1],
[ 0x1f3f8,  0x1f43e, 2],
[ 0x1f43f,  0x1f43f, 1],
[ 0x1f440,  0x1f440, 2],
[ 0x1f441,  0x1f441, 1],
[ 0x1f442,  0x1f4fc, 2],
[ 0x1f4fd,  0x1f4fe, 1],
[ 0x1f4ff,  0x1f53d, 2],
[ 0x1f53e,  0x1f54a, 1],
[ 0x1f54b,  0x1f54e, 2],
[ 0x1f54f,  0x1f54f, 1],
[ 0x1f550,  0x1f567, 2],
[ 0x1f568,  0x1f579, 1],
[ 0x1f57a,  0x1f57a, 2],
[ 0x1f57b,  0x1f594, 1],
[ 0x1f595,  0x1f596, 2],
[ 0x1f597,  0x1f5a3, 1],
[ 0x1f5a4,  0x1f5a4, 2],
[ 0x1f5a5,  0x1f5fa, 1],
[ 0x1f5fb,  0x1f64f, 2],
[ 0x1f650,  0x1f67f, 1],
[ 0x1f680,  0x1f6c5, 2],
[ 0x1f6c6,  0x1f6cb, 1],
[ 0x1f6cc,  0x1f6cc, 2],
[ 0x1f6cd,  0x1f6cf, 1],
[ 0x1f6d0,  0x1f6d2, 2],
[ 0x1f6d3,  0x1f6d4, 1],
[ 0x1f6d5,  0x1f6d7, 2],
[ 0x1f6d8,  0x1f6db, 1],
[ 0x1f6dc,  0x1f6df, 2],
[ 0x1f6e0,  0x1f6ea, 1],
[ 0x1f6eb,  0x1f6ec, 2],
[ 0x1f6ed,  0x1f6f3, 1],
[ 0x1f6f4,  0x1f6fc, 2],
[ 0x1f6fd,  0x1f7df, 1],
[ 0x1f7e0,  0x1f7eb, 2],
[ 0x1f7ec,  0x1f7ef, 1],
[ 0x1f7f0,  0x1f7f0, 2],
[ 0x1f7f1,  0x1f90b, 1],
[ 0x1f90c,  0x1f93a, 2],
[ 0x1f93b,  0x1f93b, 1],
[ 0x1f93c,  0x1f945, 2],
[ 0x1f946,  0x1f946, 1],
[ 0x1f947,  0x1f9ff, 2],
[ 0x1fa00,  0x1fa6f, 1],
[ 0x1fa70,  0x1fa7c, 2],
[ 0x1fa7d,  0x1fa7f, 1],
[ 0x1fa80,  0x1fa89, 2],
[ 0x1fa8a,  0x1fa8e, 1],
[ 0x1fa8f,  0x1fac6, 2],
[ 0x1fac7,  0x1facd, 1],
[ 0x1face,  0x1fadc, 2],
[ 0x1fadd,  0x1fade, 1],
[ 0x1fadf,  0x1fae9, 2],
[ 0x1faea,  0x1faef, 1],
[ 0x1faf0,  0x1faf8, 2],
[ 0x1faf9,  0x1ffff, 1],
[ 0x20000,  0x2fffd, 2],
[ 0x2fffe,  0x2ffff, 1],
[ 0x30000,  0x3fffd, 2],
[ 0x3fffe,  0xe0000, 1],
[ 0xe0001,  0xe0001, 0],
[ 0xe0002,  0xe001f, 1],
[ 0xe0020,  0xe007f, 0],
[ 0xe0080,  0xe00ff, 1],
[ 0xe0100,  0xe01ef, 0],
[ 0xe01f0, 0x10ffff, 1],
]
}


1;
