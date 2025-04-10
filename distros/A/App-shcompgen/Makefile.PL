# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Generate shell completion scripts",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-shcompgen",
  "EXE_FILES" => [
    "script/shcompgen"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::shcompgen",
  "PREREQ_PM" => {
    "Complete::File" => "0.440",
    "Complete::Fish::Gen::FromGetoptLongDescriptive" => 0,
    "Complete::Fish::Gen::FromPerinciCmdLine" => 0,
    "Complete::Program" => 0,
    "Complete::Util" => "0.608",
    "Complete::Zsh::Gen::FromGetoptLongDescriptive" => 0,
    "Complete::Zsh::Gen::FromPerinciCmdLine" => 0,
    "Data::Dmp" => "0.242",
    "Data::Sah::Compiler::perl::TH::array" => "0.911",
    "Data::Sah::Compiler::perl::TH::bool" => "0.911",
    "Data::Sah::Compiler::perl::TH::str" => "0.911",
    "File::Path" => "2.09",
    "File::Slurper" => 0,
    "File::Which" => 0,
    "Getopt::Long::Complete" => 0,
    "Getopt::Long::Dump" => "0.112",
    "Getopt::Long::EvenLess::Dump" => 0,
    "Getopt::Long::Util" => "0.896",
    "Getopt::Std::Dump" => 0,
    "Log::ger" => "0.038",
    "Perinci::CmdLine::Any" => "0.09",
    "Perinci::Object" => "0.311",
    "Perinci::Sub::Property::cmdline" => 0,
    "Perinci::Sub::Util" => "0.470",
    "Shell::Guess" => 0,
    "String::ShellQuote" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.325",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Complete::File" => "0.440",
  "Complete::Fish::Gen::FromGetoptLongDescriptive" => 0,
  "Complete::Fish::Gen::FromPerinciCmdLine" => 0,
  "Complete::Program" => 0,
  "Complete::Util" => "0.608",
  "Complete::Zsh::Gen::FromGetoptLongDescriptive" => 0,
  "Complete::Zsh::Gen::FromPerinciCmdLine" => 0,
  "Data::Dmp" => "0.242",
  "Data::Sah::Compiler::perl::TH::array" => "0.911",
  "Data::Sah::Compiler::perl::TH::bool" => "0.911",
  "Data::Sah::Compiler::perl::TH::str" => "0.911",
  "File::Path" => "2.09",
  "File::Slurper" => 0,
  "File::Spec" => 0,
  "File::Which" => 0,
  "Getopt::Long::Complete" => 0,
  "Getopt::Long::Dump" => "0.112",
  "Getopt::Long::EvenLess::Dump" => 0,
  "Getopt::Long::Util" => "0.896",
  "Getopt::Std::Dump" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.038",
  "Perinci::CmdLine::Any" => "0.09",
  "Perinci::Object" => "0.311",
  "Perinci::Sub::Property::cmdline" => 0,
  "Perinci::Sub::Util" => "0.470",
  "Shell::Guess" => 0,
  "String::ShellQuote" => 0,
  "Test::More" => 0,
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

# modify generated Makefile to run 'shcompgen init' & 'shcompgen generate'
# during installation. this piece is generated by Dist::Zilla::Plugin::For::App::shcompgen version 0.04.
SHCOMPGEN_INIT:
{
    print "Modifying Makefile to run 'shcompgen init' & 'shcompgen generate'\n";
    open my($fh), "<", "Makefile" or die "Can't open generated Makefile: $!";
    my $content = do { local $/; ~~<$fh> };

    $content =~ s/^(install :: pure_install doc_install)/$1 shcompgen_init/m
        or die "Can't find pattern in Makefile (1)";

    # apparently we can't put $ in the Makefile
    $content .= qq|\nshcompgen_init :\n\t| .
        q|$(PERLRUN) -E'require App::shcompgen; my %args; App::shcompgen::_set_args_defaults(\%args); say App::shcompgen::init(%args)->[2]; App::shcompgen::generate(%args, replace=>1, remove=>1)'| .
        qq|\n\n|;

    open $fh, ">", "Makefile" or die "Can't write modified Makefile: $!";
    print $fh $content;
}
