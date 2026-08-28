package TCTL;
use v5.10; use strict; use warnings;
use EV;
use IO::Socket::UNIX;
use EV::WebKit::Protocol;

# A raw-socket harness for the control-server tests. Deliberately raw: the
# server must be correct on its own terms, not merely agree with a client module
# that shares its bugs.
#
#     my $cl = TCTL->new($path);
#     $cl->send_frame({ i => 1, m => 'title' });
#     my @f = $cl->pump(1);          # run the loop until 1 frame arrives (or time out)

sub new {
    my ($class, $path, %o) = @_;
    my $sock = IO::Socket::UNIX->new(Peer => $path)
        or die "TCTL: cannot connect to '$path': $!\n";
    $sock->blocking(0);
    my $self = bless {
        sock   => $sock,
        dec    => EV::WebKit::Protocol::decoder(),
        in     => [],
        events => [],
        eof    => 0,
    }, $class;
    # STOP the watcher on EOF, do not merely record it. An EOF-ed descriptor is
    # permanently readable, so a live watcher on one turns every later EV::run
    # in this process into an immediate return -- which silently defeats any
    # settle a test arms afterwards ("wait a second, then check nothing
    # happened" measured 0.000s), and used to spin pump() to its deadline.
    my $stop = sub { $self->{eof} = 1; $self->{rw} = undef; EV::break };
    $self->{rw} = EV::io($sock, EV::READ, sub {
        my $n = sysread($sock, my $buf, 65536);
        if (!defined $n) { return if $!{EAGAIN} || $!{EINTR}; return $stop->() }
        if (!$n)         { return $stop->() }
        push @{ $self->{in} }, $self->{dec}->($buf);
        EV::break;
    });
    return $self;
}

sub send_frame {
    my ($self, $frame) = @_;
    my $line = EV::WebKit::Protocol::encode($frame);
    syswrite($self->{sock}, $line);
    return;
}

sub send_raw { syswrite($_[0]{sock}, $_[1]); return }

# Run the browser's own EV loop until we have $want frames buffered, or $secs
# elapse. Returns (and clears) whatever arrived.
sub pump {
    my ($self, $want, $secs) = @_;
    $want //= 1;
    $secs //= 15;
    my $deadline = EV::time + $secs;
    while (@{ $self->{in} } < $want) {
        # Once the socket is at EOF nothing further can arrive, whether or not
        # frames are already buffered. The old spelling only stopped when the
        # buffer was EMPTY, and an EOF-ed fd stays permanently readable, so
        # EV::run returned instantly and this spun to the deadline -- measured
        # at 10.0s wall / 10.0s CPU in t/90-control-marshal.t alone.
        last if $self->{eof};
        my $left = $deadline - EV::time;
        last if $left <= 0;
        my $wd = EV::timer($left, 0, sub { EV::break });
        EV::run;
        undef $wd;
        last if EV::time >= $deadline && @{ $self->{in} } < $want;
    }
    my @got = @{ $self->{in} };
    $self->{in} = [];
    return @got;
}

# Send a request and return ITS response, skipping any events that arrive first.
# This is not a convenience: it is the protocol. Events are unsolicited and can
# land at any moment, and responses can arrive out of order (a script issued
# after a pdf will answer first), so a client matches on the request id and
# never on arrival order. A test that assumes "the next frame is my answer" is
# testing something the protocol does not promise.
sub reply {
    my ($self, $frame, $secs) = @_;
    $secs //= 20;
    $self->send_frame($frame);
    my $deadline = EV::time + $secs;
    while (EV::time < $deadline) {
        my @f = $self->pump(1, $deadline - EV::time);
        last unless @f;
        push @{ $self->{events} }, grep { defined $_->{ev} } @f;
        my ($r) = grep { !defined $_->{ev} && defined $_->{i} && defined $frame->{i}
                         && $_->{i} == $frame->{i} } @f;
        return $r if $r;
        # a null-id error (a malformed line) answers no particular request
        my ($bad) = grep { !defined $_->{ev} && !defined $_->{i} } @f;
        return $bad if $bad && !defined $frame->{i};
    }
    return undef;
}

# Pump until an event of this type shows up, and CONSUME it. Events already
# buffered count -- they may have arrived while an earlier reply() was waiting.
# Consuming matters: without it, "wait for a navigate" keeps handing back the
# same stale one an earlier navigation caused.
sub wait_event {
    my ($self, $ev, $secs) = @_;
    $secs //= 20;
    my $deadline = EV::time + $secs;
    while (1) {
        my $q = $self->{events} ||= [];
        for my $i (0 .. $#$q) {
            return splice(@$q, $i, 1) if $q->[$i]{ev} eq $ev;
        }
        last if EV::time >= $deadline;
        my @f = $self->pump(1, $deadline - EV::time);
        last unless @f;
        push @$q, grep { defined $_->{ev} } @f;
    }
    return undef;
}

sub events { @{ $_[0]{events} || [] } }

sub eof { $_[0]{eof} }

sub close {
    my $self = shift;
    delete $self->{rw};
    close $self->{sock} if $self->{sock};
    delete $self->{sock};
    return;
}

sub DESTROY { local $@; eval { $_[0]->close } }

1;
