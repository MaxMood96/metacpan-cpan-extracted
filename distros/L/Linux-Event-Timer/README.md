# Linux-Event-Timer

Thin, event-loop-neutral wrapper around `Linux::FD::Timer` (timerfd).

## Install

```bash
perl Makefile.PL
make
make test
make install
```

## Quick start

```perl
use Linux::Event::Timer;

my $t = Linux::Event::Timer->new(after => 0.25);

my $rin = '';
vec($rin, $t->fd, 1) = 1;

select($rin, undef, undef, undef);
my $ticks = $t->read_ticks;
```

## Platform

Linux only.
