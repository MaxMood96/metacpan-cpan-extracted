# DO NOT EDIT! This file is written by perl_setup_dist.
# If needed, you can add content at the end of the file.

## no critic (Policy)

use 5.014;
use strict;
use warnings;
use ExtUtils::MakeMaker::CPANfile;

WriteMakefile(
    NAME             => 'Future::IO::Impl::AnyEvent',
    DISTNAME         => 'Future-IO-Impl-AnyEvent',
    AUTHOR           => q{Mathias Kende <mathias@cpan.org>},
    VERSION_FROM     => 'lib/Future/IO/Impl/AnyEvent.pm',
    ABSTRACT         => q{Future::IO implementation using AnyEvent},
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.014',
    MAN3PODS         => {},
    # Directories in which we look for Makefile.PL. In general could be omitted but is needed in case there
    # is a file named Makefile.PL in a sub-directory. Should be customized if such a file needs to be
    # processed by ExtUtils.
    DIR              => [],
    NO_MYMETA => 1,
    META_MERGE => {
      'meta-spec' => { version => 2 },
      # Goes with NO_MYMETA (which would provide the dynamic config).
      dynamic_config => 0,
      no_index => {
        directory => [ 'local', 'vendor', 't' ],
      },
      keywords => ['future','io','anyevent','async','fs',],
      resources => {
        repository => {
          type => 'git',
          url => 'git@github.com:mkende/perl_future_io_impl_any_event.git',
          web => 'https://github.com/mkende/perl_future_io_impl_any_event',
        },
        bugtracker => {
          web => 'https://github.com/mkende/perl_future_io_impl_any_event/issues',
        },
      },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => '.gz', },
    clean => { FILES => 'Future-IO-Impl-AnyEvent-*' },
);

# These platforms (usually) have GNU Make by default so the syntax that we use
# for our custom targets below will work (especially to export environment
# variables).
# On other platforms, we disable the custom parts of our Makefile generation, as
# the generated Makefile would otherwise not parse correctly.
sub supported_platform {
  return $^O =~ m/^(?:linux|cygwin|MSWin32)$/;
}

sub MY::postamble {
  my ($self) = @_;

  my @postamble;
  push @postamble, ::postamble() if *::postamble{CODE};

  push @postamble, <<"MAKE_FRAGMENT" if supported_platform();
ALL_PM := \$(shell find lib -name "*.pm")
TEST_PM := \$(shell find t -name "*.pm")
ALL_EXE :=

.PHONY: distupload cover critic rawcritic tidy spelling alltest clean clean_coverdb pod2html exe

distupload: distcheck disttest
\t\$(MAKE) tardist
\tcpan-upload --directory Dist-Setup \$(DISTVNAME).tar\$(SUFFIX)

cover:
\tcover -test

critic: export EXTENDED_TESTING = 1
critic: all
\tperl -Ilib t/001-perlcritic.t 2>&1 | less

rawcritic:
\tperlcritic lib 

tidy:
\tperltidy -b -bext='/' \$(ALL_PM) \$(TEST_PM) \$(ALL_EXE)

spelling: export EXTENDED_TESTING = 1
spelling:
\t\$(PERLRUN) t/001-spelling.t --interactive

alltest: export EXTENDED_TESTING = 1
alltest: test

clean:: clean_coverdb clean_build clean_pod2html

clean_coverdb:
\trm -fr cover_db

clean_build:
\trm -fr build

clean_pod2html:
\trm -fr pod2html

PM_HTML := \$(patsubst %.pm, pod2html/%.html, \$(ALL_PM))
EXE_HTML := \$(patsubst %, pod2html/%.html, \$(ALL_EXE))
pod2html: \$(PM_HTML) \$(EXE_HTML)

\$(PM_HTML): pod2html/%.html: %.pm
\tmkdir -p \$(shell dirname \$@)
\tpod2html --infile \$< --outfile \$@

\$(EXE_HTML): pod2html/%.html: %
\tmkdir -p \$(shell dirname \$@)
\tpod2html --infile \$< --outfile \$@

EXE_EXE := \$(patsubst %, build/%\$(EXE_EXT), \$(ALL_EXE))

exe: export PAR_VERBATIM=1
exe: build \$(EXE_EXE)

build:
\tmkdir -p build

\$(EXE_EXE): build/%\$(EXE_EXT): %
\tpp -o \$@ -cd build/pp.cache -I lib -F "PodStrip=.*\\bFuture/IO/Impl/AnyEvent\\b(*COMMIT)(*FAIL)|.*" \$<

MAKE_FRAGMENT

  return join "\n", @postamble;
}

# You can add below this template a `postamble` sub that returns more content to
# add to the generated Makefile.

# End of the template. You can add custom content below this line.
