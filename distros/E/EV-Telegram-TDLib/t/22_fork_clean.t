use strict;
use warnings;
use Config;
use POSIX ();
use Test::More;
use File::Path ();
use File::Temp ();
use EV;
use EV::Telegram::TDLib;

plan skip_all => 'no fork on this platform' unless $Config::Config{d_fork};

# This file must never create a client in the parent: a child forked before
# the process ever made one inherits a pump that was never used -- no reader,
# no held mutex, no loop refs, and TDLib itself has spawned nothing -- so it
# is as clean as a fresh process. The Cookbook's fork-then-create-per-worker
# recipe depends on that being allowed.

my $pid = fork;
defined $pid or die "fork: $!";
if (!$pid) {
    alarm 30;
    # CLEANUP would run at exit, and this child leaves through
    # POSIX::_exit, which skips it: remove the directory by hand instead
    my $dir = File::Temp::tempdir('ev-td-forkclean-XXXXXX', TMPDIR => 1);
    my $got = 0;
    my $ok = eval {
        my $td = EV::Telegram::TDLib->new(
            api_id => 1, api_hash => 'x',
            database_directory => $dir,
            on_error => sub { },
        );
        # a real round trip, so this proves the child's own reader works and
        # not merely that the constructor returned
        $td->send({ '@type' => 'getOption', name => 'version' }, sub {
            my ($res) = @_;
            $got = 1 if $res && defined $res->{value};
            $td->close(sub { EV::break });
        });
        my $w = EV::timer 20, 0, sub { EV::break };
        EV::run;
        1;
    };
    File::Path::rmtree($dir, 0, 0);
    POSIX::_exit($ok && $got ? 0 : 1);
}

my $status;
eval {
    local $SIG{ALRM} = sub { die "waitpid timed out\n" };
    alarm 40;
    waitpid $pid, 0;
    $status = $?;
    alarm 0;
    1;
} or do { kill 9, $pid; waitpid $pid, 0 };

is $status, 0, 'a child forked before any client completes a TDLib round trip';

done_testing;
