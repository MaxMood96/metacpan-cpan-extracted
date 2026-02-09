package Linux::Event::Timer;

use v5.36;
use strict;
use warnings;

our $VERSION = '0.010';

use Carp qw(croak);
use Scalar::Util qw(blessed);

use Linux::FD::Timer 0.015 ();
use Fcntl qw(FD_CLOEXEC F_GETFD F_SETFD);

# ------------------------------------------------------------------
# Constructor
# ------------------------------------------------------------------

sub new ($class, %opt) {

    croak "Linux::Event::Timer only works on Linux"
        unless $^O eq 'linux';

    my ($after, $every) = delete @opt{qw(after every)};

    my $mode_count = 0;
    $mode_count++ if defined $after;
    $mode_count++ if defined $every;
    croak "Only one of after/every may be supplied"
        if $mode_count > 1;

    my $self = bless {}, $class;

    if (defined $opt{timerfd}) {
        my $tfd = delete $opt{timerfd};

        croak "timerfd must be an object"
            unless blessed($tfd);

        # Linux::FD::Timer objects are filehandles with timer methods.
        # We only require the operations this wrapper exposes.
        for my $m (qw(set_timeout receive)) {
            croak "timerfd missing required method '$m'"
                unless $tfd->can($m);
        }

        $self->{tfd} = $tfd;
    }
    else {
        my $nonblocking = exists $opt{nonblocking} ? !!$opt{nonblocking} : 1;
        my $cloexec     = exists $opt{cloexec}     ? !!$opt{cloexec}     : 1;
        my $clock       = exists $opt{clock}       ? $opt{clock}         : 'monotonic';

        my @flags;
        push @flags, 'non-blocking' if $nonblocking;

        # Linux::FD::Timer currently documents 'non-blocking' as a supported flag.
        # We implement cloexec ourselves via fcntl if requested.
        my $tfd = Linux::FD::Timer->new($clock, @flags)
            or croak "Linux::FD::Timer->new('$clock') failed";

        $self->{tfd} = $tfd;

        if ($cloexec) {
            my $fd = fileno($tfd);
            if (defined $fd) {
                my $old = fcntl($tfd, F_GETFD, 0);
                fcntl($tfd, F_SETFD, ($old // 0) | FD_CLOEXEC);
            }
        }
    }

    if (keys %opt) {
        croak "Unknown option(s): " . join(", ", sort keys %opt);
    }

    # Optional constructor arming
    $self->after($after) if defined $after;
    $self->every($every) if defined $every;

    return $self;
}

# ------------------------------------------------------------------
# Event loop integration
# ------------------------------------------------------------------

sub fd ($self) { fileno($self->{tfd}) }

sub fh ($self) { $self->{tfd} }

sub read_ticks ($self) {
    my $n = $self->{tfd}->receive;
    return defined($n) ? $n : 0;
}

# ------------------------------------------------------------------
# Arming
# ------------------------------------------------------------------

sub disarm ($self) {
    $self->{tfd}->set_timeout(0, 0);
    return $self;
}

sub after ($self, $seconds) {
    _num($seconds, 'seconds');
    $seconds = 0 if $seconds < 0;
    $self->{tfd}->set_timeout($seconds, 0);
    return $self;
}

sub every ($self, $interval) {
    _num($interval, 'interval');
    croak "interval must be > 0"
        unless $interval > 0;

    $self->{tfd}->set_timeout($interval, $interval);
    return $self;
}

# ------------------------------------------------------------------
# Internal validation
# ------------------------------------------------------------------

sub _num ($v, $name) {
    croak "$name is required" unless defined $v;
    croak "$name must be numeric"
        if ref($v) || $v !~ /\A-?(?:\d+(?:\.\d*)?|\.\d+)\z/;
    return;
}

1;

__END__

=pod

=head1 NAME

Linux::Event::Timer - Thin wrapper around Linux::FD::Timer (timerfd)

=head1 SYNOPSIS

  use Linux::Event::Timer;

  # Create unarmed
  my $t = Linux::Event::Timer->new;

  # Arm one-shot
  $t->after(0.25);

  # Arm periodic
  $t->every(1.0);

  # Constructor arming
  my $t2 = Linux::Event::Timer->new(after => 0.5);
  my $t3 = Linux::Event::Timer->new(every => 2.0);

  # Integrate with event loop
  my $fd = $t->fd;
  my $fh = $t->fh;

  my $rin = '';
  vec($rin, $fd, 1) = 1;

  select($rin, undef, undef, undef);

  my $ticks = $t->read_ticks;

=head1 DESCRIPTION

This module provides a minimal, event-loop-neutral wrapper around
C<Linux::FD::Timer> (C<timerfd>).

It does not perform any waiting internally and does not provide
monotonic time helpers. Time math belongs in your scheduler layer.

=head1 CONSTRUCTOR

=head2 new

  my $t = Linux::Event::Timer->new(%options);

Options:

=over 4

=item * nonblocking (bool, default 1)

=item * cloexec (bool, default 1)

=item * clock (string, default 'monotonic')

Clock id passed to C<Linux::FD::Timer->new>. Typically C<monotonic> or
C<realtime>.

=item * timerfd (object)

Inject a pre-created timerfd-like object.

=item * after => $seconds

Arm a one-shot timer immediately after construction.

=item * every => $seconds

Arm a periodic timer immediately after construction.

Only one of C<after> or C<every> may be supplied.

=back

=head1 METHODS

=head2 fd

Returns the numeric file descriptor.

=head2 fh

Returns a filehandle.

=head2 read_ticks

Drain the timerfd and return the number of expirations.

=head2 after($seconds)

Arm a one-shot timer.

=head2 every($interval)

Arm a periodic timer.

=head2 disarm

Disable the timer.

=head1 PLATFORM

Linux only.

=head1 AUTHOR

Joshua Day

=head1 LICENSE

Same terms as Perl itself.

=cut
