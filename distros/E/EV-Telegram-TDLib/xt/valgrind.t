use strict;
use warnings;
use Test::More;
use Config;

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};
plan skip_all => 'valgrind not found'
    unless `which valgrind 2>/dev/null` =~ /\S/;

my @tests = qw(
    t/00_use.t
    t/01_execute.t
    t/02_transport.t
    t/03_pump_lifecycle.t
    t/07_close.t
    t/08_multi_client.t
);
plan tests => scalar @tests;

for my $t (@tests) {
    my $cmd = "valgrind --error-exitcode=99 --leak-check=full"
        . " --show-leak-kinds=definite --errors-for-leak-kinds=definite"
        . " --num-callers=20"
        . " \"$Config{perlpath}\" -Iblib/lib -Iblib/arch $t 2>&1";
    my $out = `$cmd`;
    my $rc = $? >> 8;

    my ($invalid) = $out =~ /Invalid (read|write)/;

    # TDLib is a large C++ library with its own allocation habits, and which
    # of them valgrind calls a definite leak varies by build -- the prebuilt
    # and from-source Aliens disagree. Chasing those is a treadmill, so
    # attribute each leak instead: a record is ours only if the allocation
    # happens in one of our own C functions, which are plain C names. A
    # frame in the td:: namespace is TDLib allocating for itself.
    my @ours;
    for my $rec (split /^==\d+==\s*$/m, $out) {
        next unless $rec =~ /definitely lost in loss record/;
        my @frames = $rec =~ /^==\d+==\s+(?:at|by) 0x[0-9A-F]+: (.+?) \(/mg;
        # skip valgrind's own interceptors to reach the real allocation site
        shift @frames while @frames && $frames[0] =~ /^(?:operator new|malloc|calloc|realloc|strdup)/;
        next unless @frames;
        push @ours, $frames[0] if $frames[0] =~ /^(?:td_|XS_EV__Telegram)/;
    }

    if ($invalid) {
        fail "$t: valgrind reported an invalid access";
        diag $out =~ s/^/  /gmr;
    } elsif (@ours) {
        fail "$t: leaked from our own code (@ours)";
        diag $out =~ s/^/  /gmr;
    } elsif ($rc != 0 && $rc != 99) {
        fail "$t: test failure under valgrind (rc=$rc)";
        diag $out =~ s/^/  /gmr;
    } else {
        pass "$t: no leak attributable to our code";
    }
}
