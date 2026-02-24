#!/usr/bin/env perl

use v5.26.0;
use strict;
use warnings;
use feature "signatures";
use experimental "signatures";
use lib qw( lib t/lib );

use File::Temp qw( tempdir );
use PPI        ();
use Test2::V0  qw( done_testing is ok skip subtest );

use Perl::Critic::Policy::CodeLayout::ProhibitLongLines ();

my $Long_line = 'my $var = "' . ("x" x 68) . '";';  # 81 chars

sub git_available () {
  open my $fh, "-|", "git", "--version" or return 0;
  my $out = do { local $/ = undef; <$fh> };
  close $fh or return 0;
  defined $out && $out =~ /git version/
}

sub setup_git_repo () {
  my $dir = tempdir(CLEANUP => 1);

  local $ENV{GIT_CONFIG_GLOBAL} = "/dev/null";
  local $ENV{GIT_CONFIG_SYSTEM} = "/dev/null";

  system("git", "-C", $dir, "init", "-q") == 0 or return;

  # Write .gitattributes
  open my $fh, ">", "$dir/.gitattributes" or die "open: $!";
  print $fh "ignore.t custom-line-length=ignore\n";
  print $fh "wide.t custom-line-length=200\n";
  close $fh or die "close: $!";

  $dir
}

sub write_perl_file ($dir, $name, $code) {
  my $path = "$dir/$name";
  open my $fh, ">", $path or die "open $path: $!";
  print $fh $code;
  close $fh or die "close $path: $!";
  $path
}

sub violations_for_file ($policy, $path) {
  my $doc = PPI::Document->new($path);
  $policy->violates($doc, $doc)
}

sub require_git () {
  skip "git not available" unless git_available();
  my $dir = setup_git_repo();
  skip "could not initialise git repo" unless $dir;
  $dir
}

sub test_ignore_attribute () {
  my $dir = require_git();

  my $policy = Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new;
  my $path   = write_perl_file($dir, "ignore.t", "$Long_line\n");

  my @v = violations_for_file($policy, $path);
  is scalar @v, 0, "no violations when attribute is ignore";
}

sub test_numeric_attribute () {
  my $dir = require_git();

  my $policy = Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new;

  # 81-char line is fine under limit of 200
  my $path = write_perl_file($dir, "wide.t", "$Long_line\n");
  my @v    = violations_for_file($policy, $path);
  is scalar @v, 0, "81-char line within 200-char override";

  # A 201-char line should still violate
  my $very_long = "x" x 201;
  $path = write_perl_file($dir, "wide.t", "$very_long\n");
  @v    = violations_for_file($policy, $path);
  is scalar @v, 1, "201-char line exceeds 200-char override";
}

sub test_unspecified_attribute () {
  my $dir = require_git();

  my $policy = Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new;

  # normal.t has no gitattributes entry, so default 80 applies
  my $path = write_perl_file($dir, "normal.t", "$Long_line\n");
  my @v    = violations_for_file($policy, $path);
  is scalar @v, 1, "81-char line violates default 80-char limit";
}

sub test_no_filename () {
  # PPI::Document from string ref has no filename
  my $policy = Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new;
  my $doc    = PPI::Document->new(\$Long_line);
  my @v      = $policy->violates($doc, $doc);
  is scalar @v, 1, "string input (no filename) uses default limit";
}

sub test_feature_disabled () {
  my $dir = require_git();

  my $policy = Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new;
  $policy->{_gitattributes_line_length} = "";

  # ignore.t would be ignored if the feature were active
  my $path = write_perl_file($dir, "ignore.t", "$Long_line\n");
  my @v    = violations_for_file($policy, $path);
  is scalar @v, 1, "violations reported when feature is disabled";
}

sub test_get_gitattr_line_length () {
  my $dir = require_git();

  my $policy = Perl::Critic::Policy::CodeLayout::ProhibitLongLines->new;

  # Need actual files for git check-attr
  write_perl_file($dir, "ignore.t", "1;\n");
  write_perl_file($dir, "wide.t",   "1;\n");
  write_perl_file($dir, "normal.t", "1;\n");

  is $policy->_get_gitattr_line_length("$dir/ignore.t"), "ignore",
    "ignore attribute";
  is $policy->_get_gitattr_line_length("$dir/wide.t"), 200, "numeric attribute";
  ok !defined $policy->_get_gitattr_line_length("$dir/normal.t"),
    "unspecified attribute returns undef";
  ok !defined $policy->_get_gitattr_line_length(undef),
    "undef filename returns undef";
  ok !defined $policy->_get_gitattr_line_length(""),
    "empty filename returns undef";
}

subtest "ignore attribute suppresses violations" => \&test_ignore_attribute;
subtest "numeric attribute overrides limit"      => \&test_numeric_attribute;
subtest "unspecified attribute uses default"    => \&test_unspecified_attribute;
subtest "no filename falls back to default"     => \&test_no_filename;
subtest "feature disabled when parameter empty" => \&test_feature_disabled;
subtest "_get_gitattr_line_length values" => \&test_get_gitattr_line_length;

done_testing;
