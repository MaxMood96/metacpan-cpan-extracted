# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "See What I Mean?!",
  "AUTHOR" => "Ingy d\x{f6}t Net <ingy\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "Swim",
  "EXE_FILES" => [
    "bin/swim"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "Swim",
  "PREREQ_PM" => {
    "HTML::Escape" => 0,
    "Hash::Merge" => 0,
    "IPC::Run" => 0,
    "Pegex" => "0.41",
    "Text::Autoformat" => 0,
    "YAML::XS" => 0
  },
  "TEST_REQUIRES" => {
    "JSON::PP" => 0
  },
  "VERSION" => "0.1.48",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "HTML::Escape" => 0,
  "Hash::Merge" => 0,
  "IPC::Run" => 0,
  "JSON::PP" => 0,
  "Pegex" => "0.41",
  "Text::Autoformat" => 0,
  "YAML::XS" => 0
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

use Config;
use File::Find;

my $file = 'inc/bin/testml-cpan';
open IN, '<', $file or die "Can't open '$file' for input";
my @bin = <IN>;
close IN;

shift @bin;
unshift @bin, "#!$Config{perlpath}\n";
open OUT, '>', $file or die "Can't open '$file' for output";
print OUT @bin;
close OUT;

chmod 0755, 'inc/bin/testml-cpan';

if ($^O eq 'MSWin32') {
  my $file = 'inc/bin/testml-cpan.cmd';
  open OUT, '>', $file or die "Can't open '$file' for output";
  print OUT 'if exist "%~dpn0" perl %0 %*', "\r\n";
  close OUT;

  find sub {
    return unless -f && /\.t$/;
    my $file = $_;
    open IN, '<', $file or die "Can't open '$file' for input";
    return unless <IN> =~ /testml-cpan/;
    my $text = do {local $/; <IN>};
    close IN;
    open OUT, '>', $file or die "Can't open '$file' for output";
    print OUT '#!inc\\bin\\testml-cpan', "\r\n";
    print OUT $text;
    close OUT;
  }, 't';
}
