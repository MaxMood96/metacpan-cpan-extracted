use Test::More;
use strict;
use warnings;
require "./t/80-multi-tests.pl";

my $fa = "t/81a-$$.out";
my $fb = "t/81b-$$.out";

unlink $fa,$fb;

$ENV{MULTI_DIR_FILE} = "t/81-$$.dir";

if (fork() == 0) {
    $ENV{MULTI_DIR_OUTPUT} = $fa;
    exit system($^X, "-Iblib/lib", "-Ilib", "t/80a-multi.tt") >> 8;
}

if (fork() == 0) {
    $ENV{MULTI_DIR_OUTPUT} = $fb;
    exit system($^X, "-Iblib/lib", "-Ilib", "t/80b-multi.tt") >> 8;
}
wait;
wait;
ok_multi( $fa, $fb );

done_testing;
unlink $fa,$fb;

