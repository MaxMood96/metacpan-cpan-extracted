# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Perl API for MaxMind's GeoIP2 web services and databases",
  "AUTHOR" => "Dave Rolsky <drolsky\@maxmind.com>, Greg Oschwald <goschwald\@maxmind.com>, Mark Fowler <mfowler\@maxmind.com>, Olaf Alders <oalders\@maxmind.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "GeoIP2",
  "EXE_FILES" => [
    "bin/web-service-request"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "GeoIP2",
  "PREREQ_PM" => {
    "B" => 0,
    "Data::Dumper" => 0,
    "Data::Validate::IP" => "0.25",
    "Exporter" => 0,
    "Getopt::Long" => 0,
    "HTTP::Headers" => 0,
    "HTTP::Request" => 0,
    "JSON::MaybeXS" => 0,
    "LWP::Protocol::https" => 0,
    "LWP::UserAgent" => 0,
    "List::SomeUtils" => 0,
    "List::Util" => 0,
    "MIME::Base64" => 0,
    "MaxMind::DB::Reader" => "1.000000",
    "Moo" => 0,
    "Moo::Role" => 0,
    "Params::Validate" => 0,
    "Scalar::Util" => 0,
    "Sub::Quote" => 0,
    "Throwable::Error" => 0,
    "Try::Tiny" => 0,
    "URI" => 0,
    "lib" => 0,
    "namespace::clean" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "HTTP::Response" => 0,
    "HTTP::Status" => 0,
    "IO::Compress::Gzip" => 0,
    "MaxMind::DB::Metadata" => 0,
    "Path::Class" => 0,
    "Test::Builder" => 0,
    "Test::Fatal" => 0,
    "Test::More" => "0.96",
    "Test::Number::Delta" => 0,
    "base" => 0,
    "utf8" => 0
  },
  "VERSION" => "2.006002",
  "test" => {
    "TESTS" => "t/*.t t/GeoIP2/*.t t/GeoIP2/Database/*.t t/GeoIP2/Error/*.t t/GeoIP2/Model/*.t t/GeoIP2/WebService/*.t"
  }
);


my %FallbackPrereqs = (
  "B" => 0,
  "Data::Dumper" => 0,
  "Data::Validate::IP" => "0.25",
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Getopt::Long" => 0,
  "HTTP::Headers" => 0,
  "HTTP::Request" => 0,
  "HTTP::Response" => 0,
  "HTTP::Status" => 0,
  "IO::Compress::Gzip" => 0,
  "JSON::MaybeXS" => 0,
  "LWP::Protocol::https" => 0,
  "LWP::UserAgent" => 0,
  "List::SomeUtils" => 0,
  "List::Util" => 0,
  "MIME::Base64" => 0,
  "MaxMind::DB::Metadata" => 0,
  "MaxMind::DB::Reader" => "1.000000",
  "Moo" => 0,
  "Moo::Role" => 0,
  "Params::Validate" => 0,
  "Path::Class" => 0,
  "Scalar::Util" => 0,
  "Sub::Quote" => 0,
  "Test::Builder" => 0,
  "Test::Fatal" => 0,
  "Test::More" => "0.96",
  "Test::Number::Delta" => 0,
  "Throwable::Error" => 0,
  "Try::Tiny" => 0,
  "URI" => 0,
  "base" => 0,
  "lib" => 0,
  "namespace::clean" => 0,
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
