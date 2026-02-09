use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "basic.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "a,b\n";
print {$fh} "c,d\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $it = $profiler->iter_rows(
    path       => $file,
    delimiter  => ",",
    has_header => 0,
);

my $row1 = $it->next_row;
is_deeply($row1, ["a", "b"], "row1 ok");

my $row2 = $it->next_row;
is_deeply($row2, ["c", "d"], "row2 ok");

my $row3 = $it->next_row;
ok(!defined $row3, "EOF returns undef");

done_testing;
