package Linux::Event::Clock;

use strict;
use warnings;

our $VERSION = '0.011';

use Carp qw(croak);
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

use constant NS_PER_S  => 1_000_000_000;
use constant NS_PER_MS => 1_000_000;
use constant NS_PER_US => 1_000;

sub new {
    my ($class, %opt) = @_;

    my $clock = $opt{clock} // 'monotonic';
    $clock eq 'monotonic'
        or croak "clock must be 'monotonic' (got '$clock')";

    my $self = bless {
        clock  => $clock,
        now_ns => 0,
        gen    => 0,
    }, $class;

    $self->tick; # prime cache
    return $self;
}

sub tick {
    my ($self) = @_;

    my $t  = clock_gettime(CLOCK_MONOTONIC);
    my $ns = int($t * NS_PER_S);

    $self->{now_ns} = $ns;
    $self->{gen}++;

    return $ns;
}

sub generation {
    my ($self) = @_;
    return $self->{gen};
}

sub now_ns {
    my ($self) = @_;
    return $self->{now_ns};
}

sub now_s {
    my ($self) = @_;
    return $self->{now_ns} / NS_PER_S;
}

sub monotonic_ns {
    my ($self) = @_;
    my $t = clock_gettime(CLOCK_MONOTONIC);
    return int($t * NS_PER_S);
}

sub deadline_after {
    my ($self, $seconds) = @_;
    defined $seconds or croak "deadline_after requires seconds";
    return $self->{now_ns} + int($seconds * NS_PER_S);
}

sub deadline_after_ms {
    my ($self, $ms) = @_;
    defined $ms or croak "deadline_after_ms requires ms";
    return $self->{now_ns} + ($ms * NS_PER_MS);
}

sub deadline_after_us {
    my ($self, $us) = @_;
    defined $us or croak "deadline_after_us requires us";
    return $self->{now_ns} + ($us * NS_PER_US);
}

sub deadline_in_ns {
    my ($self, $delta_ns) = @_;
    defined $delta_ns or croak "deadline_in_ns requires delta_ns";
    return $self->{now_ns} + $delta_ns;
}

sub expired_ns {
    my ($self, $deadline_ns) = @_;
    defined $deadline_ns or croak "expired_ns requires deadline_ns";
    return $deadline_ns <= $self->{now_ns} ? 1 : 0;
}

sub remaining_ns {
    my ($self, $deadline_ns) = @_;
    defined $deadline_ns or croak "remaining_ns requires deadline_ns";
    my $rem = $deadline_ns - $self->{now_ns};
    return $rem > 0 ? $rem : 0;
}

1;

__END__

=pod

=head1 NAME

Linux::Event::Clock - Cached monotonic time and deadline math for Linux::Event schedulers

=head1 SYNOPSIS

  use Linux::Event::Clock;

  my $clock = Linux::Event::Clock->new;

  while (1) {
      $clock->tick;              # one syscall per loop iteration/batch
      my $now = $clock->now_ns;  # cached, no syscall

      if ($deadline_ns <= $now) {
          # due
      }

      my $deadline2 = $clock->deadline_after_ms(50); # absolute ns, 50ms from cached now
  }

=head1 DESCRIPTION

Linux::Event::Clock provides a monotonic clock with an explicit cache refresh
via C<tick>. A scheduler can refresh the cache once per loop iteration (or once
per batch) and then perform thousands of deadline comparisons using cached
nanosecond integers without additional syscalls.

This module is intended to be the time/deadline math companion to a Linux-only
event framework that uses primitives like timerfd and epoll.

=head1 CONSTRUCTOR

=head2 new

  my $clock = Linux::Event::Clock->new(%opt);

Creates a new clock and primes the cached time by calling C<tick> once.

Options:

=over 4

=item * C<clock> => C<monotonic> (default)

Only C<monotonic> is supported in v0.1.

=back

=head1 METHODS

=head2 tick

  my $now_ns = $clock->tick;

Refreshes the cached monotonic time (one syscall) and increments C<generation>.
Returns the cached time in nanoseconds.

=head2 generation

  my $gen = $clock->generation;

Returns a monotonically increasing counter incremented by each C<tick>. Useful
for schedulers that cache derived state per tick.

=head2 now_ns

  my $now_ns = $clock->now_ns;

Returns the cached monotonic time in nanoseconds. No syscall.

=head2 now_s

  my $now_s = $clock->now_s;

Returns the cached monotonic time in seconds (floating point). Intended for
logging/UI rather than tight scheduling comparisons.

=head2 monotonic_ns

  my $ns = $clock->monotonic_ns;

Returns the current monotonic time in nanoseconds without using the cache (one
syscall). Intended for debugging/profiling rather than the scheduler hot path.

=head2 deadline_after

  my $deadline_ns = $clock->deadline_after($seconds);

Returns an absolute deadline in nanoseconds, computed from the cached time and
a relative duration in seconds. Conversion happens once per call.

=head2 deadline_after_ms

  my $deadline_ns = $clock->deadline_after_ms($ms);

Returns an absolute deadline in nanoseconds computed from cached now plus C<$ms>
milliseconds.

=head2 deadline_after_us

  my $deadline_ns = $clock->deadline_after_us($us);

Returns an absolute deadline in nanoseconds computed from cached now plus C<$us>
microseconds.

=head2 deadline_in_ns

  my $deadline_ns = $clock->deadline_in_ns($delta_ns);

Returns an absolute deadline in nanoseconds computed from cached now plus a
nanosecond delta.

=head2 expired_ns

  if ($clock->expired_ns($deadline_ns)) { ... }

Returns true if C<$deadline_ns> is less than or equal to cached C<now_ns>.

=head2 remaining_ns

  my $rem_ns = $clock->remaining_ns($deadline_ns);

Returns remaining nanoseconds until the deadline, clamped at 0.

=head1 PERFORMANCE NOTES

For tight loops, refresh once and compare integers:

  $clock->tick;
  my $now = $clock->now_ns;
  while ($next_deadline_ns <= $now) { ... }

C<deadline_after*> helpers are intended for timer setup, not the hot compare loop.

=head1 SEE ALSO

L<Linux::Event::Timer>, L<Time::HiRes>

=head1 AUTHOR

Joshua Day

=head1 LICENSE

Same terms as Perl itself.

=cut
