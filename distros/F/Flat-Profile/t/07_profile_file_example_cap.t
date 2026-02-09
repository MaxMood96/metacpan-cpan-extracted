use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "examples.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "v\n";
print {$fh} "a\n";
print {$fh} "b\n";
print {$fh} "c\n";
print {$fh} "d\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $report = $profiler->profile_file(
    path        => $file,
    delimiter   => ",",
    has_header  => 1,
    example_cap => 2,
);

my $c0 = $report->{columns}[0];
is_deeply($c0->{sample_values}, ["a", "b"], "example_cap limits sample values");

done_testing;
