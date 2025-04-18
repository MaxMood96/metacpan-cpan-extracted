# -*- Mode: Makefile -*-
#
# Makefile.am - automake file for Raptor Turtle tests
#
# $Id: Makefile.am 10751 2006-04-04 06:09:13Z dajobe $
#
# Copyright (C) 2003-2006, David Beckett http://purl.org/net/dajobe/
# Copyright (C) 2003-2004, University of Bristol, UK http://www.bristol.ac.uk/
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

TEST_FILES=test-00.ttl test-01.ttl test-02.ttl test-03.ttl \
test-04.ttl test-05.ttl test-06.ttl test-07.ttl test-08.ttl \
test-09.ttl test-10.ttl test-11.ttl test-12.ttl test-13.ttl \
test-14.ttl test-15.ttl test-16.ttl test-17.ttl test-18.ttl \
test-19.ttl test-20.ttl test-21.ttl test-22.ttl test-23.ttl \
test-24.ttl test-25.ttl \
rdf-schema.ttl \
rdfs-namespace.ttl \
rdfq-results.ttl

TEST_BAD_FILES=bad-00.ttl bad-01.ttl bad-02.ttl bad-03.ttl \
bad-04.ttl bad-05.ttl bad-06.ttl bad-07.ttl bad-08.ttl bad-09.ttl \
bad-10.ttl bad-11.ttl bad-12.ttl bad-13.ttl bad-14.ttl

TEST_WARN_FILES=

TEST_OUT_FILES=test-00.out test-01.out test-02.out test-03.out \
test-04.out test-05.out test-06.out test-07.out test-08.out \
test-09.out test-10.out test-11.out test-12.out test-13.out \
test-14.out test-15.out test-16.out test-17.out test-18.out \
test-19.out test-20.out test-21.out test-22.out test-23.out \
test-24.out test-25.out \
rdf-schema.out \
rdfs-namespace.out \
rdfq-results.out

TEST_WARN_OUT_FILES=

TEST_MANIFEST_FILES=manifest.ttl manifest-bad.ttl

# Used to make N-triples output consistent
BASE_URI=http://www.w3.org/2001/sw/DataAccess/df1/tests/

ALL_TEST_FILES= README.txt \
	$(TEST_FILES) \
	$(TEST_BAD_FILES) \
	$(TEST_WARN_FILES) \
	$(TEST_OUT_FILES) \
	$(TEST_WARN_OUT_FILES) \
	$(TEST_MANIFEST_FILES)

EXTRA_DIST = $(ALL_TEST_FILES)

build-rapper:
	@(cd $(top_builddir)/utils ; $(MAKE) rapper)

check-local: check-rdf check-bad-rdf
# check-warn-rdf

check-rdf: build-rapper $(TEST_FILES)
	@result=0; \
	$(ECHO) "Testing legal Turtle"; \
	for test in $(TEST_FILES); do \
	  name=`basename $$test .ttl` ; \
	  baseuri=$(BASE_URI)$$test; \
	  $(ECHO) $(ECHO_N) "Checking $$test $(ECHO_C)"; \
	  $(top_builddir)/utils/rapper -q -i turtle -o ntriples $(srcdir)/$$test $$baseuri > $$name.res 2> $$name.err; \
	  status=$$?; \
	  if test $$status != 0 -a $$status != 2 ; then \
	    $(ECHO) FAILED returned status $$status; result=1; \
	  elif cmp $(srcdir)/$$name.out $$name.res >/dev/null 2>&1; then \
	    if test $$status = 2 ; then \
	      $(ECHO) "ok with warnings"; grep Warning $$name.err; \
	    else \
	      $(ECHO) "ok"; \
	    fi; \
	  else \
	    $(ECHO) "FAILED"; \
	    diff $(srcdir)/$$name.out $$name.res; result=1; \
	  fi; \
	  rm -f $$name.res $$name.err; \
	done; \
	exit $$result

check-bad-rdf: build-rapper $(TEST_BAD_FILES)
	@set +e; result=0; \
	$(ECHO) "Testing bad Turtle fails"; \
	for test in $(TEST_BAD_FILES); do \
	  name=`basename $$test .ttl` ; \
	  baseuri=$(BASE_URI)$$test; \
	  $(ECHO) $(ECHO_N) "Checking $$test $(ECHO_C)"; \
	  $(top_builddir)/utils/rapper -q -i turtle -o ntriples file:$(srcdir)/$$test $$baseuri > $$name.res 2> $$name.err; \
	  status=$$?; \
	  if test $$status -eq 1 ; then \
	    $(ECHO) "ok"; \
	  elif test $$status -eq 2 ; then \
	    $(ECHO) "FAILED - parsing succeeded with a warning"; \
	    cat $$name.res; grep Warning $$name.err; result=1; \
	  elif test $$status -eq 0 ; then \
	    $(ECHO) "FAILED - parsing succeeded but should have failed"; \
	    cat $$name.res; result=1; \
	  else \
	    $(ECHO) "FAILED - parsing failed with unknown status $$status"; \
	    cat $$name.res; result=1; \
	  fi; \
	  rm -f $$name.res $$name.err ; \
	done; \
	set -e; exit $$result

check-warn-rdf: build-rapper $(TEST_WARN_FILES)
	@set +e; result=0; \
	$(ECHO) "Testing Turtle with warnings"; \
	for test in $(TEST_WARN_FILES); do \
	  name=`basename $$test .ttl` ; \
	  baseuri=$(BASE_URI)$$test; \
	  $(ECHO) $(ECHO_N) "Checking $$test $(ECHO_C)"; \
	  $(top_builddir)/utils/rapper -q -i turtle -o ntriples file:$(srcdir)/$$test $$baseuri > $$name.res 2> $$name.err; \
	  status=$$?; \
	  if test $$status -eq 1 ; then \
	    $(ECHO) "FAILED - parsing failed when should have warned"; \
	    cat $$name.res; grep Error $$name.err; result=1; \
	  elif test $$status -eq 2 ; then \
	    $(ECHO) "ok"; \
	  else \
	    $(ECHO) "FAILED - parsing failed with unknown status $$status"; \
	    cat $$name.res; result=1; \
	  fi; \
	  rm -f $$name.res $$name.err ; \
	done; \
	set -e; exit $$result

if MAINTAINER_MODE
zip: tests.zip

tests.zip: $(ALL_TEST_FILES)
	rm -f $@
	zip $@ $(ALL_TEST_FILES)

endif
