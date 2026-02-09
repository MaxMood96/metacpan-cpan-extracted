use strict;
use warnings;
use Test::More;

plan skip_all => "Linux only" unless $^O eq 'linux';

use Linux::Event::Timer;

my $t = Linux::Event::Timer->new(after => 0.2);

$t->disarm;

my $rin = '';
vec($rin, $t->fd, 1) = 1;

my $n = select($rin, undef, undef, 0.1);
ok($n == 0, "no readability after disarm within timeout");

my $ticks = $t->read_ticks;
ok($ticks == 0, "read_ticks is 0 after disarm (nonblocking)");

done_testing;
