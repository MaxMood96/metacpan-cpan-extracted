/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2026 -- leonerd@leonerd.org.uk
 */
#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

struct SSD1306FrameBuffer
{
  U8 rows, columns;        /* size */
  U8 dirty_pages;          /* bitmask */
  U8 dirty_xlo, dirty_xhi;

  /* Data is stored in pages. Each page has all the columns of a set of 8
   * contigouous rows. All data is concatenated in one big byte buffer
   */
  U8 *pixels;
};

MODULE = Device::Chip::SSD1306    PACKAGE = Device::Chip::SSD1306

void
_framebuffer_new(SV *fbsv, U8 rows, U8 columns)
  CODE:
    struct SSD1306FrameBuffer *fb;
    Newx(fb, 1, struct SSD1306FrameBuffer);

    fb->rows    = rows;
    fb->columns = columns;

    U8 pages = (rows + 7) / 8;
    Newx(fb->pixels, pages * columns, char);
    Zero(fb->pixels, pages * columns, char);

    fb->dirty_pages = 0;
    fb->dirty_xlo   = columns;
    fb->dirty_xhi   = 0xFF;

    sv_setuv(fbsv, PTR2UV(fb));

void
_framebuffer_free(SV *fbsv)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    Safefree(fb->pixels);
    Safefree(fb);

void
_framebuffer_cleaned(SV *fbsv)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    fb->dirty_pages = 0;
    fb->dirty_xlo   = fb->columns;
    fb->dirty_xhi   = 0xFF;

SV *
_framebuffer_pagedata(SV *fbsv, U8 page, U8 xlo, U8 xhi)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    if(xlo >= fb->columns || xhi >= fb->columns)
      XSRETURN_UNDEF;

    if(xlo >= xhi)
      RETVAL = newSVpvs("");
    else
      RETVAL = newSVpvn(&fb->pixels[page*fb->columns + xlo], xhi - xlo + 1);
  OUTPUT:
    RETVAL

void
_framebuffer_dirty_xlohi(SV *fbsv)
  PPCODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    EXTEND(SP, 2);
    mPUSHi(fb->dirty_xlo);
    mPUSHi(fb->dirty_xhi);
    XSRETURN(2);

bool
_framebuffer_is_dirty_page(SV *fbsv, U8 page)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));
    RETVAL = (fb->dirty_pages & (1 << page));
  OUTPUT:
    RETVAL

void
_framebuffer_clear(SV *fbsv)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    U8 pages = (fb->rows + 7) / 8;
    Zero(fb->pixels, pages * fb->columns, char);

    fb->dirty_pages = (1 << fb->rows/8) - 1;
    fb->dirty_xlo = 0;
    fb->dirty_xhi = fb->columns - 1;

void
_framebuffer_draw_pixel(SV *fbsv, U8 x, U8 y, U8 val)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    if(x >= fb->columns || y >= fb->rows)
      return;

    U8 page = (y / 8); y %= 8;
    if(val)
      fb->pixels[page*fb->columns + x] |=  (1 << y);
    else
      fb->pixels[page*fb->columns + x] &= ~(1 << y);

    fb->dirty_pages |= (1 << page);
    if(fb->dirty_xlo > x) fb->dirty_xlo = x;
    if(fb->dirty_xhi == 0xFF || fb->dirty_xhi < x) fb->dirty_xhi = x;

void
_framebuffer_draw_hline(SV *fbsv, U8 x1, U8 x2, U8 y, U8 val)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    if(x1 >= fb->columns || y >= fb->rows)
      return;

    U8 page = (y / 8); y %= 8;
    for(U8 x = x1; x <= x2; x++) {
      if(x >= fb->columns)
        break;

      if(val)
        fb->pixels[page*fb->columns + x] |=  (1 << y);
      else
        fb->pixels[page*fb->columns + x] &= ~(1 << y);
    }

    fb->dirty_pages |= (1 << page);
    if(fb->dirty_xlo > x1) fb->dirty_xlo = x1;
    if(fb->dirty_xhi == 0xFF || fb->dirty_xhi < x2) fb->dirty_xhi = x2;

void
_framebuffer_draw_vline(SV *fbsv, U8 x, U8 y1, U8 y2, U8 val)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    if(x >= fb->columns || y1 >= fb->rows)
      return;

    for(U8 y = y1; y <= y2; y++) {
      if(y >= fb->rows)
        break;

      U8 page = (y / 8);

      if(val)
        fb->pixels[page*fb->columns + x] |=  (1 << (y%8));
      else
        fb->pixels[page*fb->columns + x] &= ~(1 << (y%8));

      fb->dirty_pages |= (1 << page);
    }

    if(fb->dirty_xlo > x) fb->dirty_xlo = x;
    if(fb->dirty_xhi == 0xFF || fb->dirty_xhi < x) fb->dirty_xhi = x;

void
_framebuffer_draw_rect(SV *fbsv, U8 x1, U8 y1, U8 x2, U8 y2, U8 val)
  CODE:
    struct SSD1306FrameBuffer *fb = INT2PTR(struct SSD1306FrameBuffer *, SvUV(fbsv));

    if(x1 >= fb->columns || y1 >= fb->rows)
      return;

    for(U8 y = y1; y <= y2; y++) {
      if(y >= fb->rows)
        break;

      U8 page = (y / 8);

      for(U8 x = x1; x <= x2; x++) {
        if(x >= fb->columns)
          break;

        if(val)
          fb->pixels[page*fb->columns + x] |=  (1 << (y%8));
        else
          fb->pixels[page*fb->columns + x] &= ~(1 << (y%8));
      }

      fb->dirty_pages |= (1 << page);
    }

    if(fb->dirty_xlo > x1) fb->dirty_xlo = x1;
    if(fb->dirty_xhi == 0xFF || fb->dirty_xhi < x2) fb->dirty_xhi = x2;
