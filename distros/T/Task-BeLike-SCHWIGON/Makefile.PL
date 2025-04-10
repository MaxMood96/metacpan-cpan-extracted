# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.041.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Modules SCHWIGON uses",
  "AUTHOR" => "Steffen Schwigon <ss5\@renormalist.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Task-BeLike-SCHWIGON",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Task::BeLike::SCHWIGON",
  "PREREQ_PM" => {
    "App::Ack" => 0,
    "App::Cmd" => 0,
    "App::DPath" => 0,
    "App::Nopaste" => 0,
    "App::Rad" => 0,
    "App::Software::License" => 0,
    "App::cpanminus" => 0,
    "App::cpanoutdated" => 0,
    "Archive::Tar::Wrapper" => 0,
    "CPAN::Reporter" => 0,
    "CPAN::Uploader" => 0,
    "Cache::Cache" => 0,
    "Cache::FileCache" => 0,
    "DBD::Pg" => 0,
    "DBD::SQLite" => 0,
    "DBD::mysql" => 0,
    "DBI" => 0,
    "DBIx::Class" => 0,
    "DBIx::Class::Schema::Loader" => 0,
    "DBIx::Class::Schema::Versioned" => 0,
    "DBIx::Class::TimeStamp" => 0,
    "Data::DPath" => 0,
    "Data::Visitor" => 0,
    "Data::YAML" => 0,
    "DateTime" => 0,
    "DateTime::Format::Builder" => 0,
    "DateTime::Format::Mail" => 0,
    "DateTime::Format::MySQL" => 0,
    "DateTime::Format::Natural" => 0,
    "DateTime::Format::Strptime" => 0,
    "Devel::Backtrace" => 0,
    "Devel::Cover" => 0,
    "Devel::NYTProf" => 0,
    "Digest::SHA1" => 0,
    "Directory::Scratch" => 0,
    "Dist::Zilla" => 0,
    "Dist::Zilla::PluginBundle::SCHWIGON" => 0,
    "Dist::Zilla::PluginBundle::TAPPER" => 0,
    "File::Rsync::Mirror::Recent" => 0,
    "File::ShareDir" => 0,
    "File::Slurper" => 0,
    "File::Type" => 0,
    "Git::Repository" => 0,
    "Hash::Merge" => 0,
    "JSON" => 0,
    "JSON::Syck" => 0,
    "JSON::XS" => 0,
    "List::AllUtils" => 0,
    "List::MoreUtils" => 0,
    "Log::Log4perl" => 0,
    "Module::Install" => "0.95",
    "Module::Install::AuthorRequires" => 0,
    "Module::Install::AuthorTests" => 0,
    "Module::Install::CheckConflicts" => 0,
    "Module::Install::ExtraTests" => 0,
    "Net::SSH" => 0,
    "Net::SSH::Expect" => 0,
    "Net::TFTP" => 0,
    "PAR::Packer" => 0,
    "PadWalker" => 0,
    "Parse::RecDescent" => 0,
    "Perl::Tidy" => 0,
    "Perl::Version" => "1.010",
    "Pod::Coverage::TrustPod" => 0,
    "Pod::Weaver::PluginBundle::SCHWIGON" => 0,
    "Pod::Weaver::PluginBundle::TAPPER" => 0,
    "TAP::DOM" => 0,
    "TAP::Formatter::HTML" => 0,
    "TAP::Parser::Aggregator" => 0,
    "Task::PerlFormance" => 0,
    "Template" => 0,
    "Term::ReadLine::Gnu" => 0,
    "Term::ReadLine::Perl" => 0,
    "Test::Aggregate" => 0,
    "Test::Deep" => 0,
    "Test::Fixture::DBIC::Schema" => 0,
    "Test::MockModule" => 0,
    "Test::Pod" => 0,
    "Test::Pod::Coverage" => 0,
    "Test::Reporter" => 0,
    "Test::Reporter::Transport::Socket" => 0,
    "Test::WWW::Mechanize::Catalyst" => 0,
    "TryCatch" => 0,
    "URI" => 0,
    "URI::Escape" => 0,
    "V" => 0,
    "XML::Mini::Document" => 0,
    "YAML" => 0,
    "YAML::Syck" => 0,
    "YAML::XS" => 0,
    "bareword::filehandles" => 0,
    "indirect" => 0,
    "multidimensional" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0,
    "blib" => "1.01"
  },
  "VERSION" => "0.007",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "App::Ack" => 0,
  "App::Cmd" => 0,
  "App::DPath" => 0,
  "App::Nopaste" => 0,
  "App::Rad" => 0,
  "App::Software::License" => 0,
  "App::cpanminus" => 0,
  "App::cpanoutdated" => 0,
  "Archive::Tar::Wrapper" => 0,
  "CPAN::Reporter" => 0,
  "CPAN::Uploader" => 0,
  "Cache::Cache" => 0,
  "Cache::FileCache" => 0,
  "DBD::Pg" => 0,
  "DBD::SQLite" => 0,
  "DBD::mysql" => 0,
  "DBI" => 0,
  "DBIx::Class" => 0,
  "DBIx::Class::Schema::Loader" => 0,
  "DBIx::Class::Schema::Versioned" => 0,
  "DBIx::Class::TimeStamp" => 0,
  "Data::DPath" => 0,
  "Data::Visitor" => 0,
  "Data::YAML" => 0,
  "DateTime" => 0,
  "DateTime::Format::Builder" => 0,
  "DateTime::Format::Mail" => 0,
  "DateTime::Format::MySQL" => 0,
  "DateTime::Format::Natural" => 0,
  "DateTime::Format::Strptime" => 0,
  "Devel::Backtrace" => 0,
  "Devel::Cover" => 0,
  "Devel::NYTProf" => 0,
  "Digest::SHA1" => 0,
  "Directory::Scratch" => 0,
  "Dist::Zilla" => 0,
  "Dist::Zilla::PluginBundle::SCHWIGON" => 0,
  "Dist::Zilla::PluginBundle::TAPPER" => 0,
  "File::Rsync::Mirror::Recent" => 0,
  "File::ShareDir" => 0,
  "File::Slurper" => 0,
  "File::Spec" => 0,
  "File::Type" => 0,
  "Git::Repository" => 0,
  "Hash::Merge" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON" => 0,
  "JSON::Syck" => 0,
  "JSON::XS" => 0,
  "List::AllUtils" => 0,
  "List::MoreUtils" => 0,
  "Log::Log4perl" => 0,
  "Module::Install" => "0.95",
  "Module::Install::AuthorRequires" => 0,
  "Module::Install::AuthorTests" => 0,
  "Module::Install::CheckConflicts" => 0,
  "Module::Install::ExtraTests" => 0,
  "Net::SSH" => 0,
  "Net::SSH::Expect" => 0,
  "Net::TFTP" => 0,
  "PAR::Packer" => 0,
  "PadWalker" => 0,
  "Parse::RecDescent" => 0,
  "Perl::Tidy" => 0,
  "Perl::Version" => "1.010",
  "Pod::Coverage::TrustPod" => 0,
  "Pod::Weaver::PluginBundle::SCHWIGON" => 0,
  "Pod::Weaver::PluginBundle::TAPPER" => 0,
  "TAP::DOM" => 0,
  "TAP::Formatter::HTML" => 0,
  "TAP::Parser::Aggregator" => 0,
  "Task::PerlFormance" => 0,
  "Template" => 0,
  "Term::ReadLine::Gnu" => 0,
  "Term::ReadLine::Perl" => 0,
  "Test::Aggregate" => 0,
  "Test::Deep" => 0,
  "Test::Fixture::DBIC::Schema" => 0,
  "Test::MockModule" => 0,
  "Test::More" => 0,
  "Test::Pod" => 0,
  "Test::Pod::Coverage" => 0,
  "Test::Reporter" => 0,
  "Test::Reporter::Transport::Socket" => 0,
  "Test::WWW::Mechanize::Catalyst" => 0,
  "TryCatch" => 0,
  "URI" => 0,
  "URI::Escape" => 0,
  "V" => 0,
  "XML::Mini::Document" => 0,
  "YAML" => 0,
  "YAML::Syck" => 0,
  "YAML::XS" => 0,
  "bareword::filehandles" => 0,
  "blib" => "1.01",
  "indirect" => 0,
  "multidimensional" => 0,
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
