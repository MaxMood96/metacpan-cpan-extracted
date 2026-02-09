use strict;
use warnings;
use Test::More;

plan skip_all => "Linux only" unless $^O eq 'linux';

use Linux::Event::Timer;

my $t = Linux::Event::Timer->new(every => 0.02);

my $rin = '';
vec($rin, $t->fd, 1) = 1;

# wait for at least one tick
my $n = select($rin, undef, undef, 1.0);
ok($n == 1, "timer became readable");

my $ticks1 = $t->read_ticks;
ok($ticks1 >= 1, "first read_ticks >= 1");

# wait again
$rin = '';
vec($rin, $t->fd, 1) = 1;
$n = select($rin, undef, undef, 1.0);
ok($n == 1, "timer became readable again");

my $ticks2 = $t->read_ticks;
ok($ticks2 >= 1, "second read_ticks >= 1");

done_testing;
