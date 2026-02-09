use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "nulls.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "v\n";
print {$fh} "\n";     # empty string
print {$fh} "x\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

# Default: null_empty => 1
my $r_default = $profiler->profile_file(
    path       => $file,
    has_header => 1,
);

is($r_default->{columns}[0]{count_null}, 1, "empty string counted as null by default");
is($r_default->{columns}[0]{count_nonnull}, 1, "one non-null value");

# Explicit: null_empty => 0
my $r_strict = $profiler->profile_file(
    path        => $file,
    has_header  => 1,
    null_empty  => 0,
);

is($r_strict->{columns}[0]{count_null}, 0, "empty string NOT counted as null when null_empty=0");
is($r_strict->{columns}[0]{count_nonnull}, 2, "empty string counted as non-null");

done_testing;
