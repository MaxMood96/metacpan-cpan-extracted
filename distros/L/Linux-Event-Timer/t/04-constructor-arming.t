use strict;
use warnings;
use Test::More;

plan skip_all => "Linux only" unless $^O eq 'linux';

use Linux::Event::Timer;

my $t = Linux::Event::Timer->new(after => 0.05);

my $rin = '';
vec($rin, $t->fd, 1) = 1;

my $n = select($rin, undef, undef, 1.0);
ok($n == 1, "constructor-armed timer became readable");
ok($t->read_ticks >= 1, "read_ticks >= 1");

done_testing;
