use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "empty.csv");

# Empty file is valid input; iterator should just return undef on first next_row
open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $iterator = $profiler->iter_rows(
    path       => $file,
    delimiter  => ",",
    has_header => 0,
);

ok($iterator, 'iter_rows() returned something');
ok(ref($iterator), 'iter_rows() returned a reference');
ok($iterator->can('next_row'), 'iterator has next_row()');

my $row = $iterator->next_row();
ok(!defined $row, 'next_row() returns undef on empty input');

done_testing;
