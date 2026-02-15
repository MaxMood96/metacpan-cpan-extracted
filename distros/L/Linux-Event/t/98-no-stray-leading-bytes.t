use v5.36;
use strict;
use warnings;

use Test::More;

# Guard against files starting with a stray "\" line (from bad escaping)
# or UTF-8 BOM, which can cause confusing parse errors like:
#   "use" not allowed in expression at line 2
#
# This test is intentionally simple and always runs.

my @paths;

opendir(my $tdh, "t") or die "opendir t failed: $!";
push @paths, map { "t/$_" } grep { /\.t\z/ } readdir($tdh);
closedir $tdh;

if (-d "examples") {
    opendir(my $edh, "examples") or die "opendir examples failed: $!";
    push @paths, map { "examples/$_" } grep { /\.pl\z/ } readdir($edh);
    closedir $edh;
}

plan tests => scalar(@paths);

for my $path (sort @paths) {
    open(my $fh, "<:raw", $path) or do {
    ok(0, "$path readable");
    next;
};

my $buf = '';
    read($fh, $buf, 8);
    close $fh;

    my $ok = 1;

    # UTF-8 BOM
    $ok = 0 if substr($buf, 0, 3) eq "\xEF\xBB\xBF";

    # Leading backslash line (the bug we hit)
    $ok = 0 if substr($buf, 0, 2) eq "\\\n";

    # Leading NUL / weird control bytes
    $ok = 0 if substr($buf, 0, 1) eq "\x00";

    ok($ok, "$path has no stray leading bytes");
}
