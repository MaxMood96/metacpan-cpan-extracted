# This Makefile.PL for HTTP-Daemon was generated by
# Dist::Zilla::Plugin::MakeMaker::Fallback 0.032
# and Dist::Zilla::Plugin::MakeMaker::Awesome 0.49.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use 5.006;
use ExtUtils::MakeMaker;

BEGIN {
my %configure_requires = (
    'ExtUtils::MakeMaker' => '0',
    'Module::Build::Tiny' => '0.034',
);

my %errors = map {
    eval "require $_; $_->VERSION($configure_requires{$_}); 1";
    $_ => $@,
} keys %configure_requires;

if (grep $_, values %errors)
{
    warn "Errors from configure prereqs:\n"
        . do {
            require Data::Dumper; Data::Dumper->new([ \%errors ])->Indent(2)->Terse(1)->Sortkeys(1)->Dump;
        };
}

if (not $ENV{PERL_MM_FALLBACK_SILENCE_WARNING})
{
    warn <<'EOW';
*** WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING ***

If you're seeing this warning, your toolchain is really, really old* and
you'll almost certainly have problems installing CPAN modules from this
century. But never fear, dear user, for we have the technology to fix this!

If you're using CPAN.pm to install things, then you can upgrade it using:

    cpan CPAN

If you're using CPANPLUS to install things, then you can upgrade it using:

    cpanp CPANPLUS

If you're using cpanminus, you shouldn't be seeing this message in the first
place, so please file an issue on github.

If you're using a packaging tool through a unix distribution, this issue
should be reported to the package manager.

If you're installing manually, please retrain your fingers to run Build.PL
when present instead of Makefile.PL.

This public service announcement was brought to you by the Perl Toolchain
Gang, the irc.perl.org #toolchain IRC channel, and the number 42.

----

* Alternatively, you are doing something overly clever, in which case you
should consider setting the 'prefer_installer' config option in CPAN.pm, or
'prefer_makefile' in CPANPLUS, to 'mb" and '0' respectively.

You can also silence this warning for future installations by setting the
PERL_MM_FALLBACK_SILENCE_WARNING environment variable.
EOW
    sleep 10 if -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));
}
} # end BEGIN

my %WriteMakefileArgs = (
  "ABSTRACT" => "A simple http server class",
  "AUTHOR" => "Gisle Aas <gisle\@activestate.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build::Tiny" => "0.034"
  },
  "DISTNAME" => "HTTP-Daemon",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "HTTP::Daemon",
  "PL_FILES" => {},
  "PREREQ_PM" => {
    "Carp" => 0,
    "HTTP::Date" => 6,
    "HTTP::Request" => 6,
    "HTTP::Response" => 6,
    "HTTP::Status" => 6,
    "IO::Socket::IP" => "0.32",
    "LWP::MediaTypes" => 6,
    "Socket" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "File::Temp" => 0,
    "IO::Select" => 0,
    "MIME::Base64" => 0,
    "Module::Metadata" => 0,
    "Test::More" => "0.98",
    "Test::Needs" => 0,
    "lib" => 0
  },
  "VERSION" => "6.16",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Carp" => 0,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "HTTP::Date" => 6,
  "HTTP::Request" => 6,
  "HTTP::Response" => 6,
  "HTTP::Status" => 6,
  "IO::Select" => 0,
  "IO::Socket::IP" => "0.32",
  "LWP::MediaTypes" => 6,
  "MIME::Base64" => 0,
  "Module::Metadata" => 0,
  "Socket" => 0,
  "Test::More" => "0.98",
  "Test::Needs" => 0,
  "lib" => 0,
  "strict" => 0,
  "warnings" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
