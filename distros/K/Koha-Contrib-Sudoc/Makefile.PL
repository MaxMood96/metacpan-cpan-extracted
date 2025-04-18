# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;



use ExtUtils::MakeMaker;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "Chargeur Koha par Tamil",
  "AUTHOR" => "Fr\x{e9}d\x{e9}ric Demians <f.demians\@tamil.fr>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "Koha-Contrib-Sudoc",
  "EXE_FILES" => [
    "bin/sudoc",
    "bin/sudoc-localisation",
    "bin/sudoc-ppnize",
    "bin/sudoc-trans"
  ],
  "LICENSE" => "gpl",
  "NAME" => "Koha::Contrib::Sudoc",
  "PREREQ_PM" => {
    "AnyEvent::Processor" => 0,
    "Business::ISBN" => 0,
    "Carp" => 0,
    "Class::Load" => 0,
    "DBI" => 0,
    "DateTime" => 0,
    "Encode" => 0,
    "File::Copy" => 0,
    "File::ShareDir" => 0,
    "Format::Human::Bytes" => 0,
    "Getopt::Long" => 0,
    "List::Util" => 0,
    "Log::Dispatch" => 0,
    "Log::Dispatch::File" => 0,
    "Log::Dispatch::Screen" => 0,
    "Log::Dispatch::Syslog" => 0,
    "MARC::Moose::Field::Control" => 0,
    "MARC::Moose::Field::Std" => 0,
    "MARC::Moose::Parser::Iso2709" => 0,
    "MARC::Moose::Reader::File::Iso2709" => 0,
    "MARC::Moose::Record" => 0,
    "MIME::Base64" => 0,
    "Mail::Box::Manager" => 0,
    "Modern::Perl" => 0,
    "Moose" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::RW::Reader" => 0,
    "MooseX::RW::Reader::File" => 0,
    "Net::FTP" => 0,
    "Net::SFTP::Foreign" => 0,
    "Path::Tiny" => 0,
    "Pod::Usage" => 0,
    "Search::Elasticsearch" => 0,
    "Sys::Syslog" => 0,
    "Try::Tiny" => 0,
    "XML::Simple" => 0,
    "YAML" => 0,
    "YAML::Tiny" => 0,
    "ZOOM" => 0,
    "utf8" => 0
  },
  "VERSION" => "2.47",
  "test" => {
    "TESTS" => ""
  }
);


my %FallbackPrereqs = (
  "AnyEvent::Processor" => 0,
  "Business::ISBN" => 0,
  "Carp" => 0,
  "Class::Load" => 0,
  "DBI" => 0,
  "DateTime" => 0,
  "Encode" => 0,
  "File::Copy" => 0,
  "File::ShareDir" => 0,
  "Format::Human::Bytes" => 0,
  "Getopt::Long" => 0,
  "List::Util" => 0,
  "Log::Dispatch" => 0,
  "Log::Dispatch::File" => 0,
  "Log::Dispatch::Screen" => 0,
  "Log::Dispatch::Syslog" => 0,
  "MARC::Moose::Field::Control" => 0,
  "MARC::Moose::Field::Std" => 0,
  "MARC::Moose::Parser::Iso2709" => 0,
  "MARC::Moose::Reader::File::Iso2709" => 0,
  "MARC::Moose::Record" => 0,
  "MIME::Base64" => 0,
  "Mail::Box::Manager" => 0,
  "Modern::Perl" => 0,
  "Moose" => 0,
  "Moose::Util::TypeConstraints" => 0,
  "MooseX::RW::Reader" => 0,
  "MooseX::RW::Reader::File" => 0,
  "Net::FTP" => 0,
  "Net::SFTP::Foreign" => 0,
  "Path::Tiny" => 0,
  "Pod::Usage" => 0,
  "Search::Elasticsearch" => 0,
  "Sys::Syslog" => 0,
  "Try::Tiny" => 0,
  "XML::Simple" => 0,
  "YAML" => 0,
  "YAML::Tiny" => 0,
  "ZOOM" => 0,
  "utf8" => 0
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
