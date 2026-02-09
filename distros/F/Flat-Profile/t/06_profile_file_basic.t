use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "profile.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "h1,h2\n";
print {$fh} "a,\n";
print {$fh} "ccc,dd\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $report = $profiler->profile_file(
    path        => $file,
    delimiter   => ",",
    has_header  => 1,
    example_cap => 10,
);

ok($report, "got report");
is($report->{rows}, 2, "rows excludes header");
is_deeply($report->{header}, ["h1", "h2"], "header captured");

is(scalar @{$report->{columns}}, 2, "two columns present");

my $c0 = $report->{columns}[0];
is($c0->{count_values}, 2, "col0 values");
is($c0->{count_null}, 0, "col0 null");
is($c0->{count_nonnull}, 2, "col0 nonnull");
is($c0->{min_length}, 1, "col0 min length");
is($c0->{max_length}, 3, "col0 max length");

my $c1 = $report->{columns}[1];
is($c1->{count_values}, 2, "col1 values");
is($c1->{count_null}, 1, "col1 null (empty string)");
is($c1->{count_nonnull}, 1, "col1 nonnull");
is($c1->{min_length}, 2, "col1 min length");
is($c1->{max_length}, 2, "col1 max length");

done_testing;
