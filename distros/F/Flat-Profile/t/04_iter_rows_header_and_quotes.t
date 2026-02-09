use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "hdr_quotes.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "h1,h2\n";
print {$fh} "\"a,a\",\"b\nb\"\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $it = $profiler->iter_rows(
    path       => $file,
    delimiter  => ",",
    has_header => 1,
);

my $row = $it->next_row;

my $header = $it->get_Header;
is_deeply($header, ["h1", "h2"], "header captured");

is_deeply($row, ["a,a", "b\nb"], "quoted comma and embedded newline");

my $eof = $it->next_row;
ok(!defined $eof, "EOF returns undef");

done_testing;
