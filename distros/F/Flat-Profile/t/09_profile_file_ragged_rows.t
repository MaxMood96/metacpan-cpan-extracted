use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "ragged.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "h1,h2,h3\n";
print {$fh} "a,b,c\n";     # width 3 ok
print {$fh} "d,e\n";       # short (2)
print {$fh} "f,g,h,i\n";   # long (4)
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $r = $profiler->profile_file(
    path       => $file,
    delimiter  => ",",
    has_header => 1,
);

is($r->{rows}, 3, "data rows exclude header");
is($r->{expected_width}, 3, "expected width uses header width");
is($r->{max_observed_width}, 4, "max observed width tracked");

is($r->{ragged}{short_rows}, 1, "one short row");
is($r->{ragged}{long_rows}, 1, "one long row");

is_deeply(
    $r->{ragged}{short_examples}[0],
    { row_number => 2, width => 2 },
    "short example captures row number and width",
);

is_deeply(
    $r->{ragged}{long_examples}[0],
    { row_number => 3, width => 4 },
    "long example captures row number and width",
);

done_testing;
