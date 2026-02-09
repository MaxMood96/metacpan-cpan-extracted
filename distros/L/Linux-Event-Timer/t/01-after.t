use strict;
use warnings;
use Test::More;
use Time::HiRes qw(time);

plan skip_all => "Linux only" unless $^O eq 'linux';

use Linux::Event::Timer;

my $t = Linux::Event::Timer->new;
$t->after(0.05);

my $rin = '';
vec($rin, $t->fd, 1) = 1;

my $t0 = time();
my $n = select($rin, undef, undef, 1.0);
ok($n == 1, "timer became readable");
my $ticks = $t->read_ticks;
ok($ticks >= 1, "read_ticks >= 1");

my $dt = time() - $t0;
ok($dt >= 0.01, "did not fire immediately");
ok($dt < 0.5, "did not take too long");

done_testing;
