# -*- Mode: Makefile -*-
#
# Makefile.am - top level automake file for Redland Bindings
#
# $Id: Makefile.am 11653 2006-11-30 05:34:14Z dajobe $
#
# Copyright (C) 2000-2006, David Beckett http://purl.org/net/dajobe/
# Copyright (C) 2000-2005  University of Bristol, UK http://www.bristol.ac.uk/
# 
# This package is Free Software and part of Redland http://librdf.org/
# 
# It is licensed under the following three licenses as alternatives:
#   1. GNU Lesser General Public License (LGPL) V2.1 or any newer version
#   2. GNU General Public License (GPL) V2 or any newer version
#   3. Apache License, V2.0 or any newer version
# 
# You may not use this file except in compliance with at least one of
# the above three licenses.
# 
# See LICENSE.html or LICENSE.txt at the top of this package for the
# complete terms and further detail along with the license texts for
# the licenses in COPYING.LIB, COPYING and LICENSE-2.0.txt respectively.
# 
# 

# Subdirectories to build/install etc.
SUBDIRS=@LOCAL_SUBDIRS@ perl data docs demos
# Subdirectories to use for distribution
DIST_SUBDIRS=@LOCAL_SUBDIRS@ perl data docs demos

EXTRA_DIST=ChangeLog  ChangeLog.1 ChangeLog.2 \
ChangeLog.3 ChangeLog.4 ChangeLog.5 ChangeLog.6 \
README      NEWS      LICENSE.txt  \
README.html NEWS.html LICENSE.html \
RELEASE.html INSTALL.html \
LICENSE-2.0.txt NOTICE \
redland-perl.rdf.in \
autogen.sh \
Makefile.PL \
redland-perl.spec redland-perl.spec.in \
MANIFEST.SKIP

CLEANFILES=perl-config-stamp

if MAINTAINER_MODE
# Create some text files from HTML sources
LYNX=lynx

HTML_TO_TEXT=TERM=vt100 $(LYNX) -dump $< | sed -e 's,file://localhost.*bindings/,,' > $@

SUFFIXES = .html .txt

.html.txt:
	$(HTML_TO_TEXT)

README: README.html
	$(HTML_TO_TEXT)

NEWS: NEWS.html
	$(HTML_TO_TEXT)

endif

test: clean

@SET_MAKE@
