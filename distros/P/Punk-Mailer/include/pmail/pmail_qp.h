#ifndef PMAIL_QP_H
#define PMAIL_QP_H

/* pmail_qp.h - quoted-printable (RFC 2045 6.7), for text that is mostly
 * ASCII with the odd accented character: readable on the wire, a third
 * the expansion of base64 on such text.
 *
 * The input has already been normalised to CRLF line endings by the
 * builder; a CRLF pair here is a line break and goes out literally. Every
 * other byte is either a literal - printable ASCII other than '=' - or
 * "=XX". Space and tab are literal except at the end of a line, where
 * they must be encoded or a transport may strip them. No output line is
 * longer than 76 characters: a soft break "=\r\n" is inserted before a
 * token that would overrun. */

static const char PMAIL_HEX[] = "0123456789ABCDEF";

/* a byte is safe to send as itself */
#define PMAIL_QP_LITERAL(c) ((c) >= 33 && (c) <= 126 && (c) != '=')

static int pmail_qp_flush(pmail_sink *s, char *buf, size_t *used)
{
    if (*used && pmail_put(s, buf, *used) != 0) return -1;
    *used = 0;
    return 0;
}

static int pmail_qp_encode(const unsigned char *in, size_t n, pmail_sink *s)
{
    char buf[4096];
    size_t used = 0, i;
    int col = 0;

    for (i = 0; i < n; i++) {
        unsigned char c = in[i];
        int width;
        int literal;

        if (c == '\r' && i + 1 < n && in[i + 1] == '\n') {
            buf[used++] = '\r'; buf[used++] = '\n';
            col = 0; i++;
            if (used > sizeof buf - 8 && pmail_qp_flush(s, buf, &used) != 0) return -1;
            continue;
        }

        if (c == ' ' || c == '\t') {
            /* literal unless it ends the line (or the input) */
            int at_eol = (i + 1 == n)
                      || (in[i + 1] == '\r' && i + 2 < n && in[i + 2] == '\n');
            literal = !at_eol;
        }
        else literal = PMAIL_QP_LITERAL(c);
        width = literal ? 1 : 3;

        /* the soft break: "=" is the 76th character at most */
        if (col + width > PMAIL_B64_LINE - 1) {
            buf[used++] = '='; buf[used++] = '\r'; buf[used++] = '\n';
            col = 0;
        }
        if (literal) buf[used++] = (char)c;
        else {
            buf[used++] = '=';
            buf[used++] = PMAIL_HEX[c >> 4];
            buf[used++] = PMAIL_HEX[c & 15];
        }
        col += width;
        if (used > sizeof buf - 8 && pmail_qp_flush(s, buf, &used) != 0) return -1;
    }
    return pmail_qp_flush(s, buf, &used);
}

/* What a text part looks like, in one pass: the facts the builder's
 * encoding choice is made on. `printable` counts bytes that would go out
 * as themselves under quoted-printable. */
typedef struct {
    int has_8bit;
    int has_nul;
    size_t longest_line;    /* bytes, measured between line breaks of any kind */
    size_t printable;
} pmail_text_scan;

static void pmail_scan_text(const unsigned char *in, size_t n, pmail_text_scan *sc)
{
    size_t i, line = 0;
    sc->has_8bit = 0; sc->has_nul = 0; sc->longest_line = 0; sc->printable = 0;
    for (i = 0; i < n; i++) {
        unsigned char c = in[i];
        if (c == '\n' || c == '\r') {
            if (line > sc->longest_line) sc->longest_line = line;
            line = 0;
            if (c == '\r' && i + 1 < n && in[i + 1] == '\n') i++;
            sc->printable++;
            continue;
        }
        line++;
        if (c == 0) sc->has_nul = 1;
        if (c >= 0x80) sc->has_8bit = 1;
        if (PMAIL_QP_LITERAL(c) || c == ' ' || c == '\t') sc->printable++;
    }
    if (line > sc->longest_line) sc->longest_line = line;
}

#endif /* PMAIL_QP_H */
