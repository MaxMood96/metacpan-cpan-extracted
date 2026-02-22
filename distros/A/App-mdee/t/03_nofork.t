use strict;
use warnings;
use Test::More;
use open qw(:std :encoding(utf-8));

use lib '.';
use t::Util;

my $test_md = 't/test.md';

SKIP: {
    skip "$test_md not found", 4 unless -f $test_md;

    # Table formatting: nofork (default) vs fork
    my $nofork = run("'-Mmd::config(table=1,rule=1)' $test_md")->stdout;
    my $fork   = run("'-Mmd::config(table=1,rule=1,nofork=0)' $test_md")->stdout;
    ok(length($nofork) > 0, "nofork table output is not empty");
    ok(length($fork) > 0, "fork table output is not empty");
    is($nofork, $fork, "table formatting: nofork and fork produce same result");

    # Without table: nofork setting should not affect output
    my $no_table_nf = run("'-Mmd::config(table=0)' $test_md")->stdout;
    my $no_table_fk = run("'-Mmd::config(table=0,nofork=0)' $test_md")->stdout;
    is($no_table_nf, $no_table_fk,
       "without table: nofork setting has no effect");
}

done_testing;
