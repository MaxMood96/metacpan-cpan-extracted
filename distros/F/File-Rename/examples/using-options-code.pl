# examples of using the options HASH from C<File::Rename::Options::GetOptions>
# based on code from "Craig Sanders" <cas@taz.net.au>
# Bug #146138 for File-Rename: how to access options hash in rename script? 
# [rt.cpan.org #146138]
#
# with user code from command line
# 
use strict;
use warnings;
use File::Rename qw(rename);
use File::Basename qw(dirname);
use File::Path qw(make_path);

my $options = File::Rename::Options::GetOptions() or 
    die "Bad options\n";
@ARGV = map {glob} @ARGV if $^O =~ m{Win}msx;

my $expr = delete $options->{_code} or die "No code\n";
my $eval = eval qq( sub { $expr } ) or die $@;

my %seen;
my $code = sub {
    &$eval;
    my $dir = dirname($_);    
    if (! -e $dir) {
      if ($options->{no_action}) {
        print "#mkdir($dir)\n" unless $seen{"$dir"}++;
      } else {
        make_path("$dir", { verbose => 1 });
      };

    } elsif (! -d "$dir") {
      print STDERR "$_: $dir exists but is not a directory!\n";
      return
    }
};

rename(\@ARGV, $code, $options);

