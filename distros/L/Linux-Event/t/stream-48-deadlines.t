use v5.36;
use strict;
use warnings;

use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM SOL_SOCKET SO_SNDBUF);

use Linux::Event::Loop;
use Linux::Event::Stream;
use Linux::Event::Timer;

{
    package T::DeadlineStream;
    use parent 'Linux::Event::Stream';

    sub on_data ($stream, $bytes) {
        $stream->data->{bytes} .= $bytes;
        return;
    }

    sub on_error ($stream, $error) {
        push @{ $stream->data->{errors} }, $error;
        return;
    }

    sub on_close ($stream) {
        $stream->data->{closes}++;
        return;
    }
}

sub pair () {
    socketpair(my $left, my $right, AF_UNIX, SOCK_STREAM, 0)
        or die "socketpair: $!";
    return ($left, $right);
}

sub new_state () { return { bytes => '', errors => [], closes => 0 } }

sub timeout_case (%option) {
    my ($left, $right) = pair();
    my $loop = Linux::Event::Loop->new;
    my $state = new_state();
    my $stream = $loop->add(T::DeadlineStream->new(
        fh => $left, data => $state, %option,
    ));
    return ($loop, $stream, $right, $state);
}

{
    my ($loop, $stream, $peer, $state)
        = timeout_case(idle_timeout => 0.04);
    $loop->run_for(0.15);
    ok $stream->is_closed, 'idle timeout closes inactive Stream';
    is scalar(@{ $state->{errors} }), 1, 'idle timeout reports one error';
    is $state->{errors}[0]->type, 'timeout', 'idle error has timeout type';
    is $state->{errors}[0]->operation, 'idle', 'idle operation is identified';
    cmp_ok $state->{errors}[0]->timeout, '==', 0.04,
        'idle duration is retained on Error';
    ok defined($state->{errors}[0]->deadline),
        'idle absolute deadline is retained on Error';
    is $state->{closes}, 1, 'idle timeout closes exactly once';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state)
        = timeout_case(read_timeout => 0.06);
    $loop->run_for(0.035);
    syswrite($peer, 'x') == 1 or die "syswrite: $!";
    $loop->run_for(0.035);
    ok !$stream->is_closed, 'successful input resets read inactivity time';
    is $state->{bytes}, 'x', 'read activity was delivered';
    $loop->run_for(0.08);
    ok $stream->is_closed, 'read timeout expires after reset interval';
    is $state->{errors}[0]->operation, 'read', 'read timeout is identified';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state)
        = timeout_case(idle_timeout => 0.06);
    $loop->run_for(0.035);
    syswrite($peer, 'a') == 1 or die "syswrite: $!";
    $loop->run_for(0.035);
    ok !$stream->is_closed, 'input progress resets idle timeout';
    $stream->write('b');
    $loop->run_for(0.035);
    ok !$stream->is_closed, 'output progress also resets idle timeout';
    $loop->run_for(0.08);
    ok $stream->is_closed, 'idle timeout expires after final activity';
    is $state->{errors}[0]->operation, 'idle',
        'reset idle timeout retains idle operation';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state)
        = timeout_case(read_timeout => 0.04);
    $stream->pause_read;
    $loop->run_for(0.08);
    ok !$stream->is_closed, 'pause_read suspends the read timeout';
    $stream->resume_read;
    $loop->run_for(0.08);
    ok $stream->is_closed, 'resume_read starts a fresh read interval';
    is $state->{errors}[0]->operation, 'read',
        'resumed read timeout reports read operation';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state) = timeout_case(
        deadline => { after => 0.04, operation => 'response' },
    );
    $loop->run_for(0.12);
    ok $stream->is_closed, 'constructor operation deadline closes Stream';
    is $state->{errors}[0]->operation, 'response',
        'constructor operation label is retained';
    is $state->{errors}[0]->type, 'timeout',
        'operation deadline uses timeout error type';
    close $peer;
}

{
    my ($left, $peer) = pair();
    my $state = new_state();
    my $stream = T::DeadlineStream->new(
        fh => $left,
        data => $state,
        deadline => { after => 0.05, operation => 'attached-session' },
    );
    select undef, undef, undef, 0.07;
    my $loop = Linux::Event::Loop->new;
    $loop->add($stream);
    $loop->run_for(0.025);
    ok !$stream->is_closed,
        'detached time does not consume a relative established deadline';
    $loop->run_for(0.06);
    ok $stream->is_closed, 'relative deadline expires after attachment';
    is $state->{errors}[0]->operation, 'attached-session',
        'post-attachment deadline retains operation label';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state) = timeout_case();
    $stream->set_deadline(after => 0.06, operation => 'fixed');
    $loop->run_for(0.035);
    syswrite($peer, 'activity') == 8 or die "syswrite: $!";
    $loop->run_for(0.06);
    ok $stream->is_closed, 'I/O does not extend an overall operation deadline';
    is $state->{errors}[0]->operation, 'fixed',
        'fixed operation deadline remains distinguishable';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state) = timeout_case();
    my $at = Linux::Event::Timer->now + 0.04;
    $stream->set_deadline(at => $at, operation => 'absolute');
    cmp_ok abs($stream->deadline - $at), '<', 0.000_001,
        'absolute operation deadline is retained';
    $loop->run_for(0.1);
    ok $stream->is_closed, 'absolute operation deadline expires';
    is $state->{errors}[0]->operation, 'absolute',
        'absolute deadline operation is reported';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state) = timeout_case();
    $stream->set_deadline(after => 0.03, operation => 'cancelled');
    $stream->clear_deadline;
    $loop->run_for(0.07);
    ok !$stream->is_closed, 'clear_deadline cancels an operation deadline';
    $stream->set_deadline(after => 0.03, operation => 'replacement');
    $loop->run_for(0.08);
    ok $stream->is_closed, 'replacement operation deadline expires';
    is $state->{errors}[0]->operation, 'replacement',
        'replacement operation label is reported';
    close $peer;
}

{
    my ($left, $right) = pair();
    setsockopt($left, SOL_SOCKET, SO_SNDBUF, pack('i', 4096))
        or die "setsockopt SO_SNDBUF: $!";
    my $loop = Linux::Event::Loop->new;
    my $state = new_state();
    my $stream = $loop->add(T::DeadlineStream->new(
        fh => $left, data => $state, write_timeout => 0.04,
    ));
    $stream->write('x' x (4 * 1024 * 1024));
    cmp_ok $stream->pending_bytes, '>', 0,
        'write timeout case has native queued output';
    $loop->run_for(0.15);
    ok $stream->is_closed, 'stalled queued output reaches write timeout';
    is $state->{errors}[0]->operation, 'write',
        'write timeout is identified';
    close $right;
}

{
    my ($left_a, $right_a) = pair();
    my ($left_b, $right_b) = pair();
    my $loop = Linux::Event::Loop->new;
    my $a = $loop->add(T::DeadlineStream->new(
        fh => $left_a, data => new_state(), idle_timeout => 10,
    ));
    my $b = $loop->add(T::DeadlineStream->new(
        fh => $left_b, data => new_state(), read_timeout => 10,
    ));
    my $stats = $loop->stats;
    is $stats->{timerfd_create_calls}, 1,
        'multiple Stream deadlines share one Loop timerfd';
    is $stats->{active_timers}, 2,
        'each deadline-enabled Stream contributes one heap entry';
    $a->close;
    $b->close;
    is $loop->stats->{active_timers}, 0,
        'closing Streams cancels shared-scheduler entries';
    close $right_a;
    close $right_b;
}

{
    my ($loop, $stream, $peer, $state) = timeout_case(
        idle_timeout => 0.04, read_timeout => 0.02,
    );
    $stream->pause_read;
    $loop->run_for(0.08);
    ok $stream->is_closed,
        'pause_read suspends read timeout but not whole-connection idle timeout';
    is $state->{errors}[0]->operation, 'idle',
        'idle policy wins while application reads are paused';
    close $peer;
}

{
    my ($loop, $stream, $peer, $state)
        = timeout_case(read_timeout => 0.03);
    close $peer;
    $loop->run_for(0.08);
    ok !$stream->is_closed, 'peer EOF disarms established read timeout';
    ok $stream->is_read_eof, 'peer EOF remains visible after disarming timeout';
    is scalar(@{ $state->{errors} }), 0,
        'EOF does not become a read-timeout error';
    $stream->close;
}

{
    my ($loop, $stream, $peer, $state) = timeout_case();
    my $stats = $stream->{xs_state}->stats;
    is $stats->{activity_tracking}, 0,
        'ordinary Stream leaves native activity tracking disabled';
    is $stats->{activity_clock_calls}, 0,
        'ordinary Stream performs no activity clock reads';
    syswrite($peer, 'plain') == 5 or die "syswrite: $!";
    $loop->run_for(0.02);
    is $stream->{xs_state}->stats->{activity_clock_calls}, 0,
        'disabled fast path records no timestamps during input';
    $stream->close;
    close $peer;
}

done_testing;
