use v5.36;
use strict;
use warnings;

use Test::More;

# Linux::Event depends on these runtime modules.
for my $m (qw(Linux::Epoll Linux::Event::Clock Linux::Event::Timer)) {
  eval "require $m; 1" or plan skip_all => "$m not available: $@";
}

my @mods = qw(
  Linux::Event
  Linux::Event::Loop
  Linux::Event::Signal
  Linux::Event::Watcher
  Linux::Event::Backend
  Linux::Event::Backend::Epoll
);

for my $m (@mods) {
  ok(eval "require $m; 1", "load $m") or diag $@;
}

done_testing;
