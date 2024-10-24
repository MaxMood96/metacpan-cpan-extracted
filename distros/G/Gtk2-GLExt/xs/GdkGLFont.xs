/*
 * $Id$
 */

#include "gtkglextperl.h"

MODULE = Gtk2::Gdk::GLExt::Font	PACKAGE = Gtk2::Gdk::GLExt::Font	PREFIX = gdk_gl_font_

PangoFont *
gdk_gl_font_use_pango_font (class, font_desc, first, count, list_base)
	PangoFontDescription * font_desc
	int                    first
	int                    count
	int                    list_base
    C_ARGS:
	font_desc, first, count, list_base

#if GTK_CHECK_VERSION(2,2,0)

PangoFont *
gdk_gl_font_use_pango_font_for_display (class, display, font_desc, first, count, list_base)
	GdkDisplay           * display
	PangoFontDescription * font_desc
	int                    first
	int                    count
	int                    list_base
    C_ARGS:
	display, font_desc, first, count, list_base

#endif
