# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.028.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Backend for Bencher",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Bencher-Backend",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Bencher::Backend",
  "PREREQ_PM" => {
    "Acme::CPANModulesUtil::Bencher" => 0,
    "Benchmark::Dumb" => 0,
    "Browser::Open" => 0,
    "Capture::Tiny" => 0,
    "Chart::Gnuplot" => 0,
    "Complete::Module" => "0.263",
    "Complete::Util" => "0.616",
    "Data::Clean::ForJSON" => 0,
    "Data::Clone" => 0,
    "Data::Dmp" => "0.242",
    "Data::Dump" => 0,
    "Data::TableData::Object::aohos" => "0.116",
    "Devel::Platform::Info" => 0,
    "Devel::Size" => 0,
    "Exporter" => "5.57",
    "ExtUtils::MakeMaker" => 0,
    "File::Digest" => "0.009",
    "File::Slurper" => 0,
    "File::Temp" => "0.2307",
    "IPC::System::Options" => "0.339",
    "JSON::MaybeXS" => 0,
    "List::MoreUtils" => 0,
    "List::Util" => "1.54",
    "List::Util::Uniq" => "0.005",
    "Log::ger" => "0.038",
    "Math::ScientificNotation::Util" => 0,
    "Module::Load" => 0,
    "Module::Path::More" => "0.32",
    "Module::XSOrPP" => 0,
    "PERLANCAR::Module::List" => "0.004004",
    "POSIX" => 0,
    "Perinci::Result::Format::Lite" => "0.286",
    "Permute::Named::Iter" => 0,
    "Proc::ChildError" => 0,
    "Role::Tiny" => 0,
    "Role::Tiny::With" => 0,
    "Scalar::Util" => 0,
    "Sort::BySpec" => "0.03",
    "String::ShellQuote" => 0,
    "Sys::Info" => 0,
    "Text::Table::More" => 0,
    "Time::HiRes" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Sah::Coerce" => "0.050",
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.063",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Acme::CPANModulesUtil::Bencher" => 0,
  "Benchmark::Dumb" => 0,
  "Browser::Open" => 0,
  "Capture::Tiny" => 0,
  "Chart::Gnuplot" => 0,
  "Complete::Module" => "0.263",
  "Complete::Util" => "0.616",
  "Data::Clean::ForJSON" => 0,
  "Data::Clone" => 0,
  "Data::Dmp" => "0.242",
  "Data::Dump" => 0,
  "Data::Sah::Coerce" => "0.050",
  "Data::TableData::Object::aohos" => "0.116",
  "Devel::Platform::Info" => 0,
  "Devel::Size" => 0,
  "Exporter" => "5.57",
  "ExtUtils::MakeMaker" => 0,
  "File::Digest" => "0.009",
  "File::Slurper" => 0,
  "File::Spec" => 0,
  "File::Temp" => "0.2307",
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "IPC::System::Options" => "0.339",
  "JSON::MaybeXS" => 0,
  "List::MoreUtils" => 0,
  "List::Util" => "1.54",
  "List::Util::Uniq" => "0.005",
  "Log::ger" => "0.038",
  "Math::ScientificNotation::Util" => 0,
  "Module::Load" => 0,
  "Module::Path::More" => "0.32",
  "Module::XSOrPP" => 0,
  "PERLANCAR::Module::List" => "0.004004",
  "POSIX" => 0,
  "Perinci::Result::Format::Lite" => "0.286",
  "Permute::Named::Iter" => 0,
  "Proc::ChildError" => 0,
  "Role::Tiny" => 0,
  "Role::Tiny::With" => 0,
  "Scalar::Util" => 0,
  "Sort::BySpec" => "0.03",
  "String::ShellQuote" => 0,
  "Sys::Info" => 0,
  "Test::More" => 0,
  "Text::Table::More" => 0,
  "Time::HiRes" => 0,
  "parent" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

if ( $^O !~ /win/i ) {
	$WriteMakefileArgs{PREREQ_PM}{'Sys::Load'} = $FallbackPrereqs{'Sys::Load'} = '0';
}

WriteMakefile(%WriteMakefileArgs);
