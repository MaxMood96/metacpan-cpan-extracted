# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.029.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker 7.64;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "Webservice to connect to Onfido API",
  "AUTHOR" => "DERIV <DERIV\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "7.64",
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "WebService-Async-Onfido",
  "EXE_FILES" => [
    "bin/mock_onfido.pl",
    "bin/onfido-tool"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "WebService::Async::Onfido",
  "PREREQ_PM" => {
    "Clone" => 0,
    "Data::UUID" => 0,
    "Date::Utility" => 0,
    "Dir::Self" => 0,
    "File::Basename" => 0,
    "File::ShareDir" => 0,
    "Future" => 0,
    "Future::Utils" => 0,
    "Getopt::Long" => 0,
    "HTML::TreeBuilder" => 0,
    "HTTP::Request::Common" => 0,
    "HTTP::Response" => 0,
    "IO::Async::Loop" => 0,
    "IO::Async::Notifier" => 0,
    "JSON::MaybeUTF8" => 0,
    "JSON::MaybeXS" => 0,
    "List::UtilsBy" => 0,
    "Log::Any" => 0,
    "Log::Any::Adapter" => 0,
    "MIME::Base64" => 0,
    "Net::Async::HTTP" => 0,
    "Net::Async::HTTP::Server" => 0,
    "Path::Tiny" => 0,
    "Ryu::Async" => 0,
    "Scalar::Util" => 0,
    "Syntax::Keyword::Try" => 0,
    "Template" => 0,
    "URI" => 0,
    "URI::Escape" => 0,
    "URI::QueryParam" => 0,
    "URI::Template" => 0,
    "constant" => 0,
    "indirect" => 0,
    "mro" => 0,
    "parent" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Clone" => 0,
    "Data::UUID" => 0,
    "Date::Utility" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "FindBin" => 0,
    "HTTP::Response" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Net::Async::HTTP::Server" => 0,
    "Path::Tiny" => 0,
    "Test::CheckDeps" => "0.010",
    "Test::Exception" => 0,
    "Test::MockModule" => 0,
    "Test::More" => "0.98",
    "Test::NoWarnings" => 0,
    "URI" => 0
  },
  "VERSION" => "0.007",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Clone" => 0,
  "Data::UUID" => 0,
  "Date::Utility" => 0,
  "Dir::Self" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Basename" => 0,
  "File::ShareDir" => 0,
  "File::Spec" => 0,
  "FindBin" => 0,
  "Future" => 0,
  "Future::Utils" => 0,
  "Getopt::Long" => 0,
  "HTML::TreeBuilder" => 0,
  "HTTP::Request::Common" => 0,
  "HTTP::Response" => 0,
  "IO::Async::Loop" => 0,
  "IO::Async::Notifier" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON::MaybeUTF8" => 0,
  "JSON::MaybeXS" => 0,
  "List::UtilsBy" => 0,
  "Log::Any" => 0,
  "Log::Any::Adapter" => 0,
  "MIME::Base64" => 0,
  "Net::Async::HTTP" => 0,
  "Net::Async::HTTP::Server" => 0,
  "Path::Tiny" => 0,
  "Ryu::Async" => 0,
  "Scalar::Util" => 0,
  "Syntax::Keyword::Try" => 0,
  "Template" => 0,
  "Test::CheckDeps" => "0.010",
  "Test::Exception" => 0,
  "Test::MockModule" => 0,
  "Test::More" => "0.98",
  "Test::NoWarnings" => 0,
  "URI" => 0,
  "URI::Escape" => 0,
  "URI::QueryParam" => 0,
  "URI::Template" => 0,
  "constant" => 0,
  "indirect" => 0,
  "mro" => 0,
  "parent" => 0,
  "strict" => 0,
  "utf8" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

{
package
MY;
use File::ShareDir::Install qw(postamble);
}
