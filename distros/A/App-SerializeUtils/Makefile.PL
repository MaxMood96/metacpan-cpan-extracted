# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Utilities for serialization tasks",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-SerializeUtils",
  "EXE_FILES" => [
    "script/check-json",
    "script/check-phpser",
    "script/check-yaml",
    "script/json2json",
    "script/json2perl",
    "script/json2perlcolor",
    "script/json2phpser",
    "script/json2sereal",
    "script/json2sexp",
    "script/json2storable",
    "script/json2yaml",
    "script/perl2json",
    "script/perl2perl",
    "script/perl2perlcolor",
    "script/perl2phpser",
    "script/perl2sereal",
    "script/perl2sexp",
    "script/perl2storable",
    "script/perl2yaml",
    "script/phpser2json",
    "script/phpser2perl",
    "script/phpser2perlcolor",
    "script/phpser2sereal",
    "script/phpser2sexp",
    "script/phpser2storable",
    "script/phpser2yaml",
    "script/pp-json",
    "script/pp-perl",
    "script/pp-yaml",
    "script/sereal2json",
    "script/sereal2perl",
    "script/sereal2perlcolor",
    "script/sereal2phpser",
    "script/sereal2sexp",
    "script/sereal2storable",
    "script/sereal2yaml",
    "script/serializeutils-convert",
    "script/sexp2json",
    "script/sexp2perl",
    "script/sexp2perlcolor",
    "script/sexp2phpser",
    "script/sexp2sereal",
    "script/sexp2storable",
    "script/sexp2yaml",
    "script/storable2json",
    "script/storable2perl",
    "script/storable2perlcolor",
    "script/storable2phpser",
    "script/storable2sereal",
    "script/storable2sexp",
    "script/storable2yaml",
    "script/yaml2json",
    "script/yaml2perl",
    "script/yaml2perlcolor",
    "script/yaml2phpser",
    "script/yaml2sereal",
    "script/yaml2sexp",
    "script/yaml2storabls",
    "script/yaml2yaml"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::SerializeUtils",
  "PREREQ_PM" => {
    "Cpanel::JSON::XS" => 0,
    "Data::Dmp" => "0.241",
    "Data::Dump" => 0,
    "Data::Dump::Color" => "0.246",
    "Data::Dump::SExpression" => 0,
    "Data::Dumper" => 0,
    "Data::Dumper::Compact" => 0,
    "Data::Undump" => 0,
    "Getopt::Long" => "2.50",
    "Getopt::Long::Complete" => 0,
    "JSON::Color" => 0,
    "JSON::MaybeXS" => 0,
    "JSON::PP" => 0,
    "PHP::Serialization" => 0,
    "SExpression::Decode::Marpa" => 0,
    "Sereal::Decoder" => 0,
    "Sereal::Encoder" => 0,
    "Storable" => "3.08",
    "YAML::Old" => 0,
    "YAML::Syck" => 0,
    "YAML::Tiny::Color" => 0,
    "YAML::XS" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.165",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Cpanel::JSON::XS" => 0,
  "Data::Dmp" => "0.241",
  "Data::Dump" => 0,
  "Data::Dump::Color" => "0.246",
  "Data::Dump::SExpression" => 0,
  "Data::Dumper" => 0,
  "Data::Dumper::Compact" => 0,
  "Data::Undump" => 0,
  "File::Spec" => 0,
  "Getopt::Long" => "2.50",
  "Getopt::Long::Complete" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON::Color" => 0,
  "JSON::MaybeXS" => 0,
  "JSON::PP" => 0,
  "PHP::Serialization" => 0,
  "SExpression::Decode::Marpa" => 0,
  "Sereal::Decoder" => 0,
  "Sereal::Encoder" => 0,
  "Storable" => "3.08",
  "Test::More" => 0,
  "YAML::Old" => 0,
  "YAML::Syck" => 0,
  "YAML::Tiny::Color" => 0,
  "YAML::XS" => 0,
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
