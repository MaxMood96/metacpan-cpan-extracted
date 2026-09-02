package Local::BoundedCommand;

use strict;
use warnings;
use utf8;

use Exporter qw(import);
use POSIX qw(:sys_wait_h);
use Time::HiRes ();

our @EXPORT_OK = qw(run_bounded);

# How often the parent asks whether the child has finished. Short enough that a
# command which exits normally is not delayed noticeably, long enough that
# waiting costs nothing measurable.
my $POLL_SECONDS = 0.05;

# How long a signalled process group is given to die politely before it is killed
# outright. The wedge this module exists to prevent held a browser tree open for
# two days, so the escalation is not optional - but a browser asked to stop does
# usually stop, and a TERM lets it close its own children.
my $GRACE_SECONDS = 2;

# run_bounded(%args)
# Runs one command with a wall-clock bound and reports what happened, instead of
# waiting for a command that may never return.
# Input: hash with command arrayref, seconds number, and optional label string.
# Output: hashref with timed_out, exit, and message fields.
#
# WHY IT SIGNALS A PROCESS GROUP RATHER THAN A PID
#   The failure that produced this module left seven processes alive for two
#   days: a perl parent, its Devel::Cover child, a web server, a starman master
#   and worker, and a browser tree. Killing the direct child would have reaped
#   one of them. The child is therefore given its own process group and the GROUP
#   is signalled, so everything the command started dies with it.
#
# WHY IT RETURNS A VERDICT INSTEAD OF DYING
#   The caller knows what the command was for and can say so; this only knows
#   that a bound was exceeded. Returning lets the caller fail in its own words,
#   and lets a test assert the timeout without trapping an exception.
sub run_bounded {
    my (%args) = @_;
    my $command = $args{command} || [];
    my $seconds = $args{seconds};
    my $label   = $args{label} || 'command';

    die 'run_bounded requires a command array reference' if ref($command) ne 'ARRAY' || !@{$command};
    die 'run_bounded requires a positive seconds bound' if !defined $seconds || $seconds <= 0;

    my $pid = fork();
    die "run_bounded could not fork for $label: $!" if !defined $pid;

    if ( !$pid ) {
        # Own process group, so the parent can signal this command and everything
        # it starts without touching itself or its siblings.
        setpgrp( 0, 0 );
        exec { $command->[0] } @{$command};

        # exec only returns on failure, and the child must not fall through into
        # the caller's test code.
        exit 127;
    }

    my $deadline = Time::HiRes::time() + $seconds;
    while (1) {
        my $reaped = waitpid( $pid, WNOHANG );
        if ( $reaped == $pid ) {
            return {
                timed_out => 0,
                exit      => $? >> 8,
                message   => '',
            };
        }

        last if Time::HiRes::time() >= $deadline;
        Time::HiRes::sleep($POLL_SECONDS);
    }

    _terminate_group($pid);

    return {
        timed_out => 1,
        exit      => -1,
        message   => sprintf(
            '%s exceeded its %s second bound and was killed with its whole process group; '
              . 'it was not waited on further, because an unbounded wait reports nothing at all',
            $label, $seconds
        ),
    };
}

# _terminate_group($pid)
# Ends one process group politely, then without asking.
# Input: process id that is also its own group leader.
# Output: none.
sub _terminate_group {
    my ($pid) = @_;

    kill 'TERM', -$pid;

    my $deadline = Time::HiRes::time() + $GRACE_SECONDS;
    while ( Time::HiRes::time() < $deadline ) {
        return if waitpid( $pid, WNOHANG ) == $pid;
        Time::HiRes::sleep($POLL_SECONDS);
    }

    kill 'KILL', -$pid;
    waitpid( $pid, 0 );
    return;
}

1;

__END__

=head1 NAME

Local::BoundedCommand - run an external command under a wall-clock bound

=head1 PURPOSE

Give the test suite a way to run an external program that cannot hang the run.
The command is given a time budget; if it outlives it, the command and every
process it started are killed and the caller is told, in words, what exceeded
what.

=head1 WHY IT EXISTS

On 11 August 2026 a coverage run wedged in the SSL browser smoke test on a
headless Chrome fetch of a loopback URL that never answered, and sat there for
one day and twenty hours. Nothing failed, nothing exited, and no error was
printed; the run's log simply stopped growing, which looks exactly like a log
between two slow tests. Two days of wall clock were lost, and seven processes
stayed alive the whole time.

The browser fault itself is tracked separately and this module does not fix it.
What it fixes is the shape of the failure. An unbounded wait produces no
failure, no exit status and no last line - and silence from a gate is
indistinguishable from a gate that is still working. A bounded failure is
legible, and legibility is what makes a gate a check rather than a hope.

=head1 WHEN TO USE

For any external program a test runs whose completion is not guaranteed -
browsers, servers, network clients, anything that talks to something else.
Ordinary fast local commands do not need it, though nothing breaks if they use
it.

=head1 HOW TO USE

    use Local::BoundedCommand qw(run_bounded);

    my $result = run_bounded(
        command => [ $browser, '--dump-dom', $url ],
        seconds => 120,
        label   => "browser fetch of $url",
    );
    die $result->{message} if $result->{timed_out};

=head1 WHAT USES IT

C<t/33-web-server-ssl-browser.t> for every external command it runs, and
C<t/152-bounded-command.t> which is its spec.

=head1 EXAMPLES

A command that finishes is unaffected and reports its own status:

    run_bounded( command => [ 'sh', '-c', 'exit 3' ], seconds => 30 );
    # { timed_out => 0, exit => 3, message => '' }

A command that outlives its bound is killed with its process group:

    run_bounded( command => [ 'sleep', '600' ], seconds => 2 );
    # { timed_out => 1, exit => -1, message => 'command exceeded its 2 second bound ...' }

=cut
