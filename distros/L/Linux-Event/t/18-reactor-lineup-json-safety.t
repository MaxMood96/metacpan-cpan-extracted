use v5.36;
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);

my $file = "$Bin/../bench/run-reactor-comparison.pl";
open my $fh, '<', $file or die "open $file: $!";
local $/;
my $src = <$fh>;
close $fh;

like(
    $src,
    qr/my \$reactor_iterations = defined\(\$reactor_after\) && defined\(\$reactor_before\)/,
    'missing backend iteration counters are handled without numeric warnings',
);

for my $field (qw(
    ev_version
    uv_version
    libuv_version
    ioasync_loop_epoll_version
    mojo_reactor_epoll_version
    anyevent_version
)) {
    like(
        $src,
        qr/\Q$field\E\s*=>\s*version_text\(/,
        "$field is normalized to a plain JSON string",
    );
}

like(
    $src,
    qr/defined \$r->\{median_reactor_iterations\}.*?'n\/a'/s,
    'HTML reports unavailable cross-framework iteration counters as n/a',
);

done_testing;
