#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More;
use FindBin;
use File::Spec;
use File::Temp qw(tempdir);
use Time::HiRes ();

use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use Local::BoundedCommand qw(run_bounded);

# A command that finishes normally must be unaffected: same exit status, no
# waiting for the bound to expire. A bound that changes the answer for healthy
# commands would be a cure worse than the disease.
{
    my $started = Time::HiRes::time();
    my $result  = run_bounded( command => [ 'sh', '-c', 'exit 0' ], seconds => 30 );
    my $elapsed = Time::HiRes::time() - $started;

    is( $result->{timed_out}, 0,  'a command that finishes is not reported as timed out' );
    is( $result->{exit},      0,  'a successful command reports exit 0' );
    ok( $elapsed < 10, "a successful command returns immediately rather than waiting for the bound (took ${\ sprintf '%.1f', $elapsed }s)" );
}

{
    my $result = run_bounded( command => [ 'sh', '-c', 'exit 3' ], seconds => 30 );
    is( $result->{timed_out}, 0, 'a failing command is a failure, not a timeout' );
    is( $result->{exit},      3, 'a failing command reports its own exit status' );
}

# The case this whole file exists for. On 11 August a browser fetch hung and the
# suite sat on it for 1 day 20 hours: no failure, no exit, no last line. The bound
# must end that, and it must end it QUICKLY - a bound that eventually works is
# still a gate nobody can read.
{
    my $started = Time::HiRes::time();
    my $result  = run_bounded( command => [ 'sleep', '600' ], seconds => 2 );
    my $elapsed = Time::HiRes::time() - $started;

    is( $result->{timed_out}, 1, 'a command that outlives its bound is reported as timed out' );
    isnt( $result->{exit}, 0, 'a timed-out command does not report success' );
    ok( $elapsed < 30, "the bound is enforced in about the time requested, not eventually (took ${\ sprintf '%.1f', $elapsed }s)" );
}

# AC-3: the 11 August wedge left seven processes alive for two days - a perl
# parent, a Devel::Cover child, a web server, a starman master and worker, and a
# browser tree. Killing only the direct child would have left most of that. The
# runner puts the child in its own process group and signals the GROUP, so a
# process tree dies with it.
{
    my $scratch = tempdir( 'dd-bounded-XXXXXX', CLEANUP => 1, TMPDIR => 1 );
    my $marker  = File::Spec->catfile( $scratch, 'grandchild.pid' );

    # A child that spawns a grandchild and then waits: killing the child alone
    # leaves the grandchild running, exactly as the wedge did.
    my $script = qq{sh -c 'sleep 600 & echo \$! > "$marker"; sleep 600'};
    my $result = run_bounded( command => [ 'sh', '-c', $script ], seconds => 2 );

    is( $result->{timed_out}, 1, 'the process-tree case times out as expected' );

    open my $fh, '<', $marker or die "Unable to read $marker: $!";
    my $grandchild = <$fh>;
    close $fh or die "Unable to close $marker: $!";
    chomp $grandchild if defined $grandchild;

  SKIP: {
        skip 'the fixture grandchild never recorded its pid', 1
          if !defined $grandchild || $grandchild !~ /\A[0-9]+\z/;

        # Give the signal a moment to be delivered before asking.
        Time::HiRes::sleep(0.5);
        my $alive = kill 0, $grandchild;
        is( $alive, 0, 'a grandchild of the timed-out command is killed too, so no tree survives the bound' );
    }
}

# The message is part of the fix. The wedge was unreadable because there was
# nothing to read; a timeout that says only "failed" repeats that in miniature.
{
    my $result = run_bounded( command => [ 'sleep', '600' ], seconds => 2, label => 'browser fetch' );
    like( $result->{message}, qr/browser fetch/, 'the failure message names what timed out' );
    like( $result->{message}, qr/\b2\b/,         'the failure message states the bound that was exceeded' );
}

done_testing;

__END__

=head1 NAME

t/152-bounded-command.t - the spec for the bounded command runner

=head1 PURPOSE

Verify that C<Local::BoundedCommand::run_bounded> ends a command that outlives
its time budget, reports the timeout as a loud, named failure, and leaves no
process tree behind - while changing nothing about commands that finish
normally.

=head1 WHY IT EXISTS

On 11 August 2026 a coverage run was started and did not finish. It was found
two days later still wedged in the SSL browser smoke test, on a headless Chrome
fetch of a loopback URL that never answered. Seven processes had been alive the
whole time: the C<prove> parent, its Devel::Cover child, a dashboard web server,
a starman master and worker, and a browser tree.

Nothing failed. Nothing exited. No error was printed. The run's log was read at
82 files with nothing failing and reported as healthy progress, because a log
that has stopped growing is indistinguishable from a log between two slow tests.

The browser fault itself is a separate ticket. This file is about the shape of
the failure: an unbounded wait reports nothing, and silence reads exactly like
slow work. A bounded failure is legible.

=head1 WHEN TO USE

Run it whenever the bounded runner or any caller of it changes, and whenever a
test that drives an external program is added.

=head1 HOW TO USE

    PERL5LIB="$HOME/perl5/lib/perl5" prove -lv t/152-bounded-command.t

=head1 WHAT USES IT

C<Local::BoundedCommand>, which is used by C<t/33-web-server-ssl-browser.t> for
every external command it runs, including the browser.

=head1 EXAMPLES

A command that outlives its bound is reported rather than waited on:

    my $result = run_bounded( command => [ 'sleep', '600' ], seconds => 2 );
    # $result->{timed_out} == 1, and $result->{message} names both the label
    # and the bound that was exceeded.

=cut
