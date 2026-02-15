#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test::More;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Linux::Event::Loop;

# Regression: stop() must prevent entering backend wait when running is cleared
# during callback dispatch in the same run_once() iteration.

{
  package t::MockClock;
  sub new { bless { now => 0 }, shift }
  sub tick { return }
  sub now_ns { return 0 }
  sub deadline_in_ns ($self, $delta) { return int($delta) } # now=0
  sub remaining_ns ($self, $deadline) { return int($deadline) } # unused in this test
}

{
  package t::MockTimer;
  sub new {
    my ($class) = @_;
    pipe(my $r, my $w) or die "pipe: $!";
    return bless { fh => $r }, $class;
  }
  sub fh { return $_[0]{fh} }
  sub after { return 1 }
  sub disarm { return 1 }
  sub read_ticks { return 0 }
}

{
  package t::MockBackend;
  sub new { bless { run_once_calls => 0, watched => 0 }, shift }
  sub watch   { $_[0]{watched}++; return 1 }
  sub unwatch { return 1 }
  sub run_once ($self, $loop, $timeout_s = undef) {
    $self->{run_once_calls}++;
    die "backend wait entered after stop()" if !$loop->{running};
    return 0;
  }
  sub run_once_calls { return $_[0]{run_once_calls} }
}

my $backend = t::MockBackend->new;
my $loop = Linux::Event::Loop->new(
  backend => $backend,
  clock   => t::MockClock->new,
  timer   => t::MockTimer->new,
);

$loop->{running} = 1;

# Schedule an immediate timer that stops the loop.
$loop->sched->after_ns(0, sub ($loop) { $loop->stop });

# If the regression is present, run_once will call backend->run_once even though stop()
# ran during _dispatch_due. Our mock backend will die in that case.
ok(eval { $loop->run_once(10); 1 }, "run_once does not enter backend wait after stop()");
is($backend->run_once_calls, 0, "backend run_once was not called");

done_testing;
