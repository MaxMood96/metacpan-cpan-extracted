# -*- Mode: Makefile -*-
#
# Makefile.am - automake file for Rasqal SPARQL tests
#
# $Id: Makefile.am 5445 2006-01-23 06:20:38Z dajobe $
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
boolean-0.n3 \
extendedType-0.n3 \
typePromotion-0.n3

SPARQL_TEST_FILES= \
boolean-EBV-canonical.rq \
boolean-equiv-FALSE.rq \
boolean-equiv-TRUE.rq \
boolean-equiv-xsdType.rq \
boolean-false-canonical.rq \
boolean-logical-OR.rq \
boolean-true-canonical.rq \
extendedType-eq-pass.rq \
extendedType-graph.rq \
extendedType-literal-eq.rq \
extendedType-literal-ne.rq \
extendedType-ne-fail.rq \
typePromotion-decimal-decimal-fail.rq \
typePromotion-decimal-decimal-pass.rq

# This file is not used in the tests and has old syntax:
# extendedType-ne-pass.rq

# Test failures
EXPECTED_SPARQL_CORRECT_FAILURES= \
extendedType-ne-fail \
extendedType-literal-ne \
typePromotion-decimal-decimal-pass \
boolean-false-canonical \
boolean-true-canonical \
boolean-EBV-canonical

SPARQL_RESULT_FILES= \
boolean-EBV-canonical-result.n3 \
boolean-equiv-FALSE-result.n3 \
boolean-equiv-TRUE-result.n3 \
boolean-equiv-xsdType-result.n3 \
boolean-false-canonical-result.n3 \
boolean-logical-OR-result.n3 \
boolean-true-canonical-result.n3 \
extendedType-eq-pass-result.n3 \
extendedType-graph-result.n3 \
extendedType-literal-eq-result.n3 \
extendedType-literal-ne-result.n3 \
extendedType-ne-fail-result.n3 \
typePromotion-decimal-decimal-fail-result.n3 \
typePromotion-decimal-decimal-pass-result.n3

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


check-local: check-sparql-lexer check-sparql-parser \
check-sparql-correct

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
	    echo "OK: Ignoring $$expect expected test failures"; result=0; \
          else \
	    echo "FAILED: $$result failures does not match expected $$expect"; result=1; \
          fi; \
	fi; \
	set -e; exit $$result
