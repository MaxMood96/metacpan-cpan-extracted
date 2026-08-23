#!perl
# A sendmail stand-in for t/08: copies its standard input to the file
# named by its first argument, and writes the rest of its arguments, one
# per line, to that name with ".argv" appended. Exits 0.
use strict;
use warnings;

my $file = shift @ARGV or die "sink.pl needs a file\n";
open my $out, '>', $file or die "$file: $!";
binmode $out;
binmode STDIN;
local $/;
print $out <STDIN>;
close $out;
open my $argv, '>', "$file.argv" or die "$file.argv: $!";
print $argv "$_\n" for @ARGV;
close $argv;
exit 0;
