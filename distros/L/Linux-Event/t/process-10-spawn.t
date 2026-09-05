use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::Loop;
use Linux::Event::Kernel::Process;

our ($STDOUT, $STDERR, @EVENTS, @ERRORS);
$STDOUT = '';
$STDERR = '';

{
    package T::Process::Echo;
    use parent 'Linux::Event::Kernel::Process';
    sub on_stdout ($self, $bytes) {
        $main::STDOUT .= $bytes;
        push @main::EVENTS, 'stdout';
    }
    sub on_stderr ($self, $bytes) {
        $main::STDERR .= $bytes;
        push @main::EVENTS, 'stderr';
    }
    sub on_stdout_eof ($self) { push @main::EVENTS, 'stdout_eof' }
    sub on_stderr_eof ($self) { push @main::EVENTS, 'stderr_eof' }
    sub on_error ($self, $error) { push @main::ERRORS, $error }
    sub on_exit ($self) {
        push @main::EVENTS, 'exit';
        main::ok($self->loop, 'Process retains Loop during on_exit');
        $self->loop->stop;
    }
}

my $loop = Linux::Event::Loop->new;
my $process = T::Process::Echo->spawn(
    command => [
        $^X, '-e',
        'my $line = <STDIN>; print uc($line); print STDERR "warning\n"; exit 7',
    ],              # required
    stdin  => 'pipe', # optional
    stdout => 'pipe', # optional
    stderr => 'pipe', # optional
    env    => { TEST_PROCESS_ENV => 'present' }, # optional
);
is($process->write_stdin("hello\n"), 1,
    'stdin can queue before Process attachment');
cmp_ok($process->pending_stdin_bytes, '>', 0,
    'pre-attachment stdin is observable');
is($process->close_stdin, $process,
    'close_stdin preserves queued input before attachment');
is($loop->add($process), $process, 'Loop add returns exact Process');
cmp_ok($process->pid, '>', 0, 'spawn assigns PID during attachment');
ok($process->is_running, 'Process is running after attachment');
$loop->run;

is($STDOUT, "HELLO\n", 'stdout is delivered asynchronously');
is($STDERR, "warning\n", 'stderr is delivered asynchronously');
is_deeply(\@ERRORS, [], 'normal process produces no errors');
ok($process->exited, 'Process reports exited state');
is($process->exit_code, 7, 'normal exit code is decoded');
is($process->term_signal, undef, 'normal exit has no terminating signal');
is($process->raw_status, 7 << 8, 'raw wait status remains available');
ok(!$process->core_dumped, 'normal exit did not dump core');
is($process->loop, undef, 'completed Process releases Loop after callback');
is($EVENTS[-1], 'exit', 'on_exit follows all pipe delivery');
ok((grep { $_ eq 'stdout_eof' } @EVENTS), 'stdout EOF callback ran');
ok((grep { $_ eq 'stderr_eof' } @EVENTS), 'stderr EOF callback ran');

done_testing;
