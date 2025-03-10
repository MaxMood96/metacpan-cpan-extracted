use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;
use open IO => ':utf8';

use lib '.';
use t::Util;

sub lines {
    my $re = join('', '\A', map("$_:.*\\n", @_), '\\z');
    qr/$re/;
}

$ENV{NO_COLOR} = 1;

like(run('--norc -ML -n -L 2 t/SAMPLE.txt')->stdout,
     lines(2), "-L 2");

like(run('--norc -ML -n -L 2,4 t/SAMPLE.txt')->stdout,
     lines(2,4), "-L 2,4");

like(run('--norc -ML -n -L 2 -L 4 --need 1 t/SAMPLE.txt')->stdout,
     lines(2,4), "-L 2 -L 4 --need 1");

like(run('--norc -ML -n -L 2:4 t/SAMPLE.txt')->stdout,
     lines(2..4), "-L 2:4");

like(run('--norc -ML -n -L 2:+2 t/SAMPLE.txt')->stdout,
     lines(2..4), "-L 2:+2");

like(run('--norc -ML -n -L -26:4 t/SAMPLE.txt')->stdout,
     lines(2..4), "-L -26:4");

like(run('--norc -ML -n -L -26:+2 t/SAMPLE.txt')->stdout,
     lines(2..4), "-L -26:+2");

like(run('--norc -ML -n -L :: t/SAMPLE.txt')->stdout,
     lines(1..28), "-L ::");

like(run('--norc -ML -n -L :-8: t/SAMPLE.txt')->stdout,
     lines(1..28-8), "-L :-8:");

like(run('--norc -ML -n -L ::2 t/SAMPLE.txt')->stdout,
     lines(map $_ * 2 - 1, 1..14), "-L ::2");

like(run('--norc -ML -n -L 2::2 t/SAMPLE.txt')->stdout,
     lines(map $_ * 2, 1..14), "-L 2::2");

like(run('--norc -ML -n --inside L=2:4 a t/SAMPLE.txt')->stdout,
     lines(3), "--inside L=2:4");

like(run('--norc -ML 2::2 -n t/SAMPLE.txt')->stdout,
     lines(map $_ * 2, 1..14), "-ML 2::2");

# w/o -L
like(run('--norc -ML 1:5 11:15 21:25 -n t/SAMPLE.txt')->stdout,
     lines(1..5,11..15,21..25), "-ML 1:5 11:15 21:25");

# offload
like(run('--norc -ML --offload "seq 2 4" -n t/SAMPLE.txt')->stdout,
     lines(2..4), '-ML --offload "seq 2 4"');

done_testing;
