# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.020000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "tie xscreensaver into dbus",
  "AUTHOR" => "Gianni Ceccarelli <dakkar\@thenautilus.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-XScreenSaver-DBus",
  "EXE_FILES" => [
    "scripts/xscreensaver-dbus"
  ],
  "LICENSE" => "open_source",
  "MIN_PERL_VERSION" => "5.020000",
  "NAME" => "App::XScreenSaver::DBus",
  "PREREQ_PM" => {
    "IPC::Run" => 0,
    "Log::Any" => 0,
    "Log::Any::Adapter" => 0,
    "Moo" => 0,
    "Net::DBus" => 0,
    "Net::DBus::Exporter" => 0,
    "Net::DBus::ProxyObject" => 0,
    "Net::DBus::Reactor" => 0,
    "Try::Tiny" => 0,
    "curry" => 0,
    "experimental" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.0.5",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "IPC::Run" => 0,
  "Log::Any" => 0,
  "Log::Any::Adapter" => 0,
  "Moo" => 0,
  "Net::DBus" => 0,
  "Net::DBus::Exporter" => 0,
  "Net::DBus::ProxyObject" => 0,
  "Net::DBus::Reactor" => 0,
  "Test::More" => 0,
  "Try::Tiny" => 0,
  "curry" => 0,
  "experimental" => 0,
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

WriteMakefile(%WriteMakefileArgs);
