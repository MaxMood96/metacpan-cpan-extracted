#!/usr/bin/perl

# Copyright PROCURA B.V. (c) 2006-2025 H.Merijn Brand

require 5.006001; # <- also see postamble at the bottom for META.yml
use strict;
use charnames ":full";

if ($ENV{PERLBREW_HOME} and $ENV{PERLBREW_HOME} eq "/home/njh/.perlbrew") {
     warn "Your smokers have been blocked because of consistent failures that\n";
     warn " are all caused by the smoking setup and not by module errors.  If\n";
     warn " you have fixed that all, please inform the authors, so this block\n";
     warn " can be lifted again.\n";
     exit 0;
     }

use ExtUtils::MakeMaker;

my %wm = (
    NAME         => "Text::CSV_XS",
    DISTNAME     => "Text-CSV_XS",
    ABSTRACT     => "Comma-Separated Values manipulation routines",
    AUTHOR       => "H.Merijn Brand <hmbrand\@cpan.org>",
    VERSION_FROM => "CSV_XS.pm",
    PREREQ_PM	 => { "XSLoader"	=> 0,
		      "Config"		=> 0,
		      "IO::Handle"	=> 0,
		      "Test::More"	=> 0,
		      },
    clean        => { FILES => join " ", qw(
			 CSV_XS.c.gcov
			 CSV_XS.gcda
			 CSV_XS.gcno
			 CSV_XS.xs.gcov
			 cover_db
			 valgrind.log
			 pod2htmd.tmp
			 MYMETA.json
			 MYMETA.yml
			 )
		      },

    macro        => { GCC_WALL => (join " " => qw(
			-Wall -Wextra -Wbad-function-cast -Wcomment -Wcomments
			-Wformat -Wdisabled-optimization -Wmissing-prototypes
			-Werror-implicit-function-declaration -Wmissing-noreturn
			-Wmissing-format-attribute -Wno-cast-qual -Wunused-value
			-Wno-sign-compare -Wpointer-arith -Wreturn-type -Wshadow
			-Wswitch-default -Wuninitialized -Wunreachable-code
			-Wundef
			)),
		      TARFLAGS   => "--format=ustar -c -v -f",
		     "#OPTIMIZE" => "-O2 \$(GCC_WALL)",
		    },
    );
$ExtUtils::MakeMaker::VERSION > 6.30 and $wm{LICENSE} = "perl";

my $rv = WriteMakefile (%wm);

# perlcriticrc uses Config::Tiny, which does not support nesting
-f ".perlcriticrc" && -s "$ENV{HOME}/.perlcriticrc" and eval {
    open my $fh, ">", ".perlcriticrc";

    require Config::Tiny;
    my $cnf = Config::Tiny->read ("$ENV{HOME}/.perlcriticrc");
    for ("ControlStructures::ProhibitPostfixControls",	# postfix if in diag
         "Freenode::PackageMatchesFilename",		# XS
	 "Subroutines::ProhibitBuiltinHomonyms",	# eof, say
	 "ErrorHandling::RequireCarping",		# for autodie
	 "BuiltinFunctions::ProhibitBooleanGrep",
	 "Variables::RequireLocalizedPunctuationVars",	# *_, %_
	 ) {
	delete $cnf->{$_};
	$cnf->{"-$_"} = {};
	}
    $cnf->{"Compatibility::PodMinimumVersion"}
	{above_version} = "5.012";	# For L<> and =head3
    $cnf->write (".perlcriticrc");
    };

1;

package MY;

sub postamble {
    if ($^O eq "os390") { # Re-write test files
	if (open my $fh, ">:encoding(utf-8)", "files/utf8.csv") {
	    print $fh qq{"\N{LATIN CAPITAL LETTER O WITH STROKE}l/Vin",0\n};
	    close $fh;
	    }
	}
    my $make_sep = $^O eq "VMS" ? "," : "";
    my $valgrind = join " ", qw(
	PERL_DESTRUCT_LEVEL=2 PERL_DL_NONLAZY=1
	    valgrind
		--suppressions=sandbox/perl.supp
		--leak-check=yes
		--leak-resolution=high
		--show-reachable=yes
		--num-callers=50
		--log-fd=3
		$(FULLPERLRUN)
		    "-MPerl::Destruct::Level=level,2"
		    "-MExtUtils::Command::MM" "-e"
		    "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')"
		    $(TEST_FILES) 3>valgrind.log
		    );

    my $min_vsn = ($] >= 5.010 && -d "xt" && -d "sandbox" && ($ENV{AUTOMATED_TESTING} || 0) != 1)
	? join "\n" =>
	    'test ::',
	    '	perl doc/make-doc.pl examples/csv*',
	    '	-@env TEST_FILES="xt/*.t" make -e test_dynamic',
	    ''
	: "";
    my $no_inc = join " " => map { "-ignore $_" } grep { -s $_ }
	map { "$_/CORE/inline.h" } @INC;
    join "\n" =>
	'cover $make_sep test_cover:',
	'	ccache -C',
	'	-@rm -f *.gc??',
	'	cover -test',
	"	cover -report html_basic $no_inc",
	'',
	'leakrun:',
	'	env HARNESS_PERL=sandbox/leakperl make test',
	'	-@tail -14 valgrind.log',
	'',
	'leakcheck:',
	"	$valgrind",
	'	-@tail -14 valgrind.log',
	'',
	'leaktest:',
	q{	sandbox/leaktest  $(FULLPERLRUN) "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)},
	'',
	'leaktrace:',
	q{	sandbox/leaktrace $(FULLPERLRUN) "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)},
	'',
	'spellcheck:',
	'	pod-spell-check --aspell --ispell',
	'',
	'ppport:	ppport.h',
	'	perl ppport.h --compat-version=5.6.1 CSV_XS.xs',
	'',
	'checkmeta:	spellcheck ppport.h',
	'	perl sandbox/genPPPort_h.pl',
	'	perl sandbox/genMETA.pl -c',
	'',
	'fixmeta:	distmeta',
	'	perl sandbox/genMETA.pl',
	'',
	'tgzdist:	checkmeta fixmeta $(DISTVNAME).tar.gz distcheck',
	'	-@mv -f $(DISTVNAME).tar.gz $(DISTVNAME).tgz',
	'	-@cpants_lint.pl $(DISTVNAME).tgz',
	'	-@rm -f Debian_CPANTS.txt',
	'	-@echo "Consider running sandbox/used-by.pl now"',
	'',
	'test_speed: pure_all',
	'	PERL_DL_NONLAZY=1 $(FULLPERLRUN) -I"$(INST_LIB)" -I"$(INST_ARCHLIB)" examples/speed.pl',
	'',
	'test_used:	test',
	'	prove -vwb sandbox/used-by.pl',
	'',
	'doc docs:		doc/Text-CSV_XS.md',
	'doc/Text-CSV_XS.md:	CSV_XS.pm',
	'	perl doc/make-doc.pl examples/csv* --pod',
	'',
	$min_vsn;
    } # postamble
