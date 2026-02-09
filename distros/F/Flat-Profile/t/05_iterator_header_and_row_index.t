use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "hdr.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "h1,h2\n";
print {$fh} "a,b\n";
print {$fh} "c,d\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $it = $profiler->iter_rows(
    path       => $file,
    delimiter  => ",",
    has_header => 1,
);

is($it->get_Row_Index, 0, "row index starts at 0");
ok(!defined $it->get_Header, "header not available until iteration starts");

my $row1 = $it->next_row;
is_deeply($it->get_Header, ["h1", "h2"], "header captured after first next_row");
is_deeply($row1, ["a", "b"], "row1 ok");
is($it->get_Row_Index, 1, "row index increments after returning first data row");

my $row2 = $it->next_row;
is_deeply($row2, ["c", "d"], "row2 ok");
is($it->get_Row_Index, 2, "row index increments after returning second data row");

my $eof = $it->next_row;
ok(!defined $eof, "EOF returns undef");
is($it->get_Row_Index, 2, "row index does not increment at EOF");

done_testing;
