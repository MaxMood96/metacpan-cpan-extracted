use strict;
use warnings;
use Test::More;
use File::Spec;

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

my @examples = glob('eg/*.pl');
plan tests => scalar @examples;

for my $eg (@examples) {
    my $out = `"$^X" -Mblib -c $eg 2>&1`;
    my $ok = $? == 0 && $out =~ /syntax OK/;
    ok($ok, "$eg compiles");
    diag($out) unless $ok;
}
