/*
 *
 * Copyright (C) 2003 by the gtk2-perl team (see the file AUTHORS for the full
 * list)
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Library General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; if not, see
 * <https://www.gnu.org/licenses/>.
 *
 * $Id$
 */

#ifndef _GTK2PERL_SPELL_H_
#define _GTK2PERL_SPELL_H_

#include <gtk2perl.h>

#include <gtkspell/gtkspell.h>

SV * newSVGtkSpell (GtkSpell * spell);
GtkSpell * SvGtkSpell (SV * sv);

#endif /* _GTK2PERL_SPELL_H_ */
