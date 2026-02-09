use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "null_tokens.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "v\n";
print {$fh} "NULL\n";
print {$fh} " \n";
print {$fh} "x\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

# With null_tokens: "NULL" counts as null; space does not (exact match only).
my $r = $profiler->profile_file(
    path        => $file,
    has_header  => 1,
    null_empty  => 1,
    null_tokens => ["NULL"],
);

is($r->{columns}[0]{count_null}, 1, "NULL token counts as null");
is($r->{columns}[0]{count_nonnull}, 2, "space and x are non-null (exact match policy)");

# Without null_tokens: NULL is just a value
my $r2 = $profiler->profile_file(
    path       => $file,
    has_header => 1,
    null_empty => 1,
);

is($r2->{columns}[0]{count_null}, 0, "without null_tokens, NULL is not treated as null");
is($r2->{columns}[0]{count_nonnull}, 3, "three non-null values");

done_testing;
