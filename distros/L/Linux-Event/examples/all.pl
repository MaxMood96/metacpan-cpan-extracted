#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";


use File::Basename qw(basename);
use IPC::Open3 qw(open3);
use Symbol qw(gensym);

my $dir = $0;
$dir =~ s{/[^/]+$}{};

opendir(my $dh, $dir) or die "opendir failed: $!";
my @files = sort grep { /\.pl\z/ && $_ ne 'all.pl' } readdir($dh);
closedir $dh;

for my $f (@files) {
  my $path = "$dir/$f";
  print "\n", ("=" x 72), "\n";
  print "EXAMPLE: $f\n";
  print ("=" x 72), "\n";

  my $err = gensym;
  my $pid = open3(my $in, my $out, $err, $^X, '-I', "$dir/../lib", $path);
  close $in;

  while (my $line = <$out>) { print $line }
  while (my $line = <$err>) { print $line }

  waitpid($pid, 0);
  my $code = $? >> 8;
  print "exit=$code\n";
}

print "\nAll examples complete.\n";

# 11_pid.pl
