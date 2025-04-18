# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.008.
use strict;
use warnings;

use 5.008005;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "a modular logfile analyzer",
  "AUTHOR" => "Markus Benning <ich\@markusbenning.de>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Log-Saftpresse",
  "EXE_FILES" => [
    "bin/saftpresse",
    "bin/saftsumm"
  ],
  "LICENSE" => "gpl",
  "MIN_PERL_VERSION" => "5.008005",
  "NAME" => "Log::Saftpresse",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Config::General" => 0,
    "Data::Dumper" => 0,
    "Exporter" => 0,
    "File::Slurp" => 0,
    "File::stat" => 0,
    "Geo::IP" => 0,
    "Getopt::Long" => 0,
    "HTTP::BrowserDetect" => 0,
    "IO::File" => 0,
    "IO::Handle" => 0,
    "IO::Select" => 0,
    "IO::Socket::INET" => 0,
    "JSON" => 0,
    "Log::Log4perl" => 0,
    "Log::Log4perl::Appender::ScreenColoredLevels" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Net::Lumberjack" => 0,
    "Pod::Usage" => 0,
    "Redis" => 0,
    "Search::Elasticsearch" => 0,
    "Sys::Hostname" => 0,
    "Template" => 0,
    "Template::Stash" => 0,
    "Tie::IxHash" => 0,
    "Time::HiRes" => 0,
    "Time::Piece" => 0,
    "Time::Seconds" => 0,
    "URI" => 0,
    "UUID" => 0,
    "base" => 0,
    "locale" => 0,
    "strict" => 0,
    "vars" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Find" => 0,
    "Test::More" => 0,
    "Test::Pod" => 0
  },
  "VERSION" => "1.6",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Config::General" => 0,
  "Data::Dumper" => 0,
  "Exporter" => 0,
  "File::Find" => 0,
  "File::Slurp" => 0,
  "File::stat" => 0,
  "Geo::IP" => 0,
  "Getopt::Long" => 0,
  "HTTP::BrowserDetect" => 0,
  "IO::File" => 0,
  "IO::Handle" => 0,
  "IO::Select" => 0,
  "IO::Socket::INET" => 0,
  "JSON" => 0,
  "Log::Log4perl" => 0,
  "Log::Log4perl::Appender::ScreenColoredLevels" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "Net::Lumberjack" => 0,
  "Pod::Usage" => 0,
  "Redis" => 0,
  "Search::Elasticsearch" => 0,
  "Sys::Hostname" => 0,
  "Template" => 0,
  "Template::Stash" => 0,
  "Test::More" => 0,
  "Test::Pod" => 0,
  "Tie::IxHash" => 0,
  "Time::HiRes" => 0,
  "Time::Piece" => 0,
  "Time::Seconds" => 0,
  "URI" => 0,
  "UUID" => 0,
  "base" => 0,
  "locale" => 0,
  "strict" => 0,
  "vars" => 0,
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
