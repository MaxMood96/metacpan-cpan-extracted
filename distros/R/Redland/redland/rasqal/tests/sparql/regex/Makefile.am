# -*- Mode: Makefile -*-
#
# Makefile.am - automake file for Rasqal syntax SPARQL tests
#
# $Id: Makefile.am 5444 2006-01-23 06:18:50Z dajobe $
#
# Copyright (C) 2005-2006, David Beckett http://purl.org/net/dajobe/
# Copyright (C) 2005-2005, University of Bristol, UK http://www.bristol.ac.uk/
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

SPARQL_MANIFEST_FILES= manifest.n3

SPARQL_MODEL_FILES= \
regex-data-01.n3

SPARQL_TEST_FILES= \
regex-query-001.rq regex-query-002.rq regex-query-003.rq regex-query-004.rq

EXPECTED_SPARQL_CORRECT_FAILURES=


SPARQL_RESULT_FILES= \
regex-result-001.n3 \
regex-result-002.n3 \
regex-result-003.n3 \
regex-result-004.n3

EXTRA_DIST= \
$(SPARQL_MANIFEST_FILES) \
$(SPARQL_MODEL_FILES) \
$(SPARQL_TEST_FILES) \
$(SPARQL_RESULT_FILES)

build-roqet:
	@(cd $(top_builddir)/utils ; $(MAKE) roqet)

build-sparql-lexer-test:
	@(cd $(top_builddir)/src ; $(MAKE) sparql_lexer_test)

build-sparql-parser-test:
	@(cd $(top_builddir)/src ; $(MAKE) sparql_parser_test)


check-local: check-sparql-lexer check-sparql-parser check-sparql-correct

check-sparql-lexer: build-sparql-lexer-test
	@set +e; result=0; \
	$(ECHO) "Testing legal SPARQL lexing"; \
	for test in $(SPARQL_TEST_FILES); do \
	  $(ECHO) $(ECHO_N) "Checking $$test $(ECHO_C)"; \
	  $(top_builddir)/src/sparql_lexer_test $(srcdir)/$$test >/dev/null; \
	  status=$$?; \
	  if test $$status != 0 -a $$status != 2 ; then \
	    $(ECHO) FAILED returned status $$status; result=1; \
	  else \
	    $(ECHO) ok; \
	  fi; \
	done; \
	set -e; exit $$result

check-sparql-parser: build-sparql-parser-test
	@set +e; result=0; \
	$(ECHO) "Testing legal SPARQL parsing"; \
	for test in $(SPARQL_TEST_FILES); do \
	  $(ECHO) $(ECHO_N) "Checking $$test $(ECHO_C)"; \
	  $(top_builddir)/src/sparql_parser_test $(srcdir)/$$test >/dev/null; \
	  status=$$?; \
	  if test $$status != 0 -a $$status != 2 ; then \
	    $(ECHO) FAILED returned status $$status; result=1; \
	    fails="$$fails $$test"; \
	  else \
	    $(ECHO) ok; \
	  fi; \
	done; \
	if test $$result != 0 ; then \
	  echo "FAILED tests:$$fails"; \
	fi; \
	set -e; exit $$result

check-sparql-correct: build-roqet $(srcdir)/../check-sparql
	@set +e; \
	expect=`echo $(EXPECTED_SPARQL_CORRECT_FAILURES) | wc -w`; \
	$(ECHO) "Testing SPARQL correct"; \
	PATH=$(top_builddir)/utils:$(top_builddir)@RAPPER_PATH@:$$PATH \
	  perl $(srcdir)/../check-sparql -s $(srcdir); \
	result=$$?; \
	if test $$result != 0 ; then \
	  echo "Expecting test failures: $(EXPECTED_SPARQL_CORRECT_FAILURES)"; \
	  if test $$result = $$expect ; then \
	    echo "OK: Ignoring expected test failures"; result=0; \
          else \
	    echo "FAILED: $$result failures does not match expected $$expect"; result=1; \
	    fails="$$fails $$test"; \
          fi; \
	fi; \
	if test $$result != 0 ; then \
	  echo "FAILED tests:$$fails"; \
	fi; \
	set -e; exit $$result
