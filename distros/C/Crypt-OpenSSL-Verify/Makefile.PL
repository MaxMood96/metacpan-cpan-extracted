# This Makefile.PL for Crypt-OpenSSL-Verify was generated by
# Dist::Zilla::Plugin::MakeMaker::Awesome 0.49.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use 5.008;
use ExtUtils::MakeMaker;

use Config;
use File::Spec;
use Crypt::OpenSSL::Guess;
my %args;

my ($major, $minor, $patch) = openssl_version();
print "Installed OpenSSL: $major.$minor.$patch\n";

$args{INC} =  openssl_inc_paths();
$args{LIBS} = [openssl_lib_paths() . ' -lssl -lcrypto'];

my $cc_option_flags = $major ge 3 ? ' -DOPENSSL_API_COMPAT=30000' : ' -DOPENSSL_API_COMPAT=10100';

if ($Config::Config{cc} =~ /gcc/i) {
  $cc_option_flags .= $ENV{AUTHOR_TESTING} ? ' -Wall -Werror' : ' -Wall';
} else {
  $cc_option_flags .= '';
}

if ($Config{gccversion} =~ /llvm/i) {
  if ( $^O eq 'darwin' && (
    $Config{gccversion} =~ /LLVM 1[2-9].\d.[5-9]/ ||
    $Config{gccversion} =~ /LLVM 1[3-9]/ ))
  {
    $cc_option_flags .= ' -Wno-deprecated-declarations -Wno-compound-token-split-by-macro';
  } else {
    $cc_option_flags .= ' -Wno-deprecated-declarations';
  }

  if ($Config{gccversion} =~ /llvm 13/i) {
      $cc_option_flags .= ' -Wno-compound-token-split-by-macro';
  }

  if ($Config{perl_version} <= 20) {
    $cc_option_flags .= ' -Wno-error=pointer-bool-conversion';
  }
}

if ($Config{myuname} =~ /sunos|solaris/i) {
  $args{OPTIMIZE} = $cc_option_flags;
} else {
  $args{OPTIMIZE} = $cc_option_flags;
}

my %WriteMakefileArgs = (
  "ABSTRACT" => "OpenSSL Verify certificate verification in XS.",
  "AUTHOR" => "Timothy Legge <timlegge\@cpan.org>, Wesley Schwengle <waterkip\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "Crypt::OpenSSL::Guess" => 0,
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Crypt-OpenSSL-Verify",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Crypt::OpenSSL::Verify",
  "PREREQ_PM" => {
    "Crypt::OpenSSL::X509" => 0
  },
  "TEST_REQUIRES" => {
    "File::Slurper" => "0.012",
    "Test::Exception" => 0
  },
  "VERSION" => "0.36",
  "test" => {
    "TESTS" => "t/*.t t/author/*.t"
  }
);

%WriteMakefileArgs = (
    %WriteMakefileArgs,
    %args,
);

my %FallbackPrereqs = (
  "Crypt::OpenSSL::X509" => 0,
  "File::Slurper" => "0.012",
  "Test::Exception" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
