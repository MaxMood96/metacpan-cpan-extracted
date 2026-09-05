use v5.36;
use strict;
use warnings;

use Test::More;

use Linux::Event::Loop;
use Linux::Event::Kernel::Process;

{
    package T::NativePipeDrain;
    use parent 'Linux::Event::Kernel::Process';

    sub on_stdout ($process, $bytes) {
        my $state = $process->data;
        $state->{stdout} .= $bytes;
        push @{ $state->{stdout_chunks} }, length($bytes);
    }

    sub on_stderr ($process, $bytes) {
        my $state = $process->data;
        $state->{stderr} .= $bytes;
        push @{ $state->{stderr_chunks} }, length($bytes);
    }

    sub on_stdout_eof ($process) {
        push @{ $process->data->{events} }, 'stdout_eof';
    }

    sub on_stderr_eof ($process) {
        push @{ $process->data->{events} }, 'stderr_eof';
    }

    sub on_exit ($process) {
        push @{ $process->data->{events} }, 'exit';
        $process->loop->stop;
    }

    sub on_error ($process, $error) {
        push @{ $process->data->{errors} }, $error;
    }
}

sub run_engine ($engine) {
    local $Linux::Event::Kernel::Process::_PIPE_DRAIN_ENGINE = $engine;
    my $state = {
        stdout => '', stderr => '', stdout_chunks => [], stderr_chunks => [],
        events => [], errors => [],
    };
    my $loop = Linux::Event::Loop->new;
    my $process = $loop->add(T::NativePipeDrain->spawn(
        command => [
            $^X, '-e',
            'my $out = "o" x 10000; my $err = "e" x 10000;'
                . ' syswrite STDOUT, $out; syswrite STDERR, $err',
        ],
        stdout => 'pipe',
        stderr => 'pipe',
        read_size => 1024,
        max_reads_per_tick => 2,
        data => $state,
    ));
    $loop->run;
    is($process->exit_code, 0, "$engine drain observes successful exit");
    return $state;
}

my $perl = run_engine('perl');
my $native = run_engine('native');

for my $case ([perl => $perl], [native => $native]) {
    my ($engine, $state) = @$case;
    is($state->{stdout}, 'o' x 10000,
        "$engine drain delivers exact stdout bytes");
    is($state->{stderr}, 'e' x 10000,
        "$engine drain delivers exact stderr bytes");
    ok(@{ $state->{stdout_chunks} } > 1,
        "$engine drain performs repeated stdout reads");
    ok(@{ $state->{stderr_chunks} } > 1,
        "$engine drain performs repeated stderr reads");
    ok(!(grep { $_ < 1 || $_ > 1024 } @{ $state->{stdout_chunks} }),
        "$engine stdout chunks honor read_size");
    ok(!(grep { $_ < 1 || $_ > 1024 } @{ $state->{stderr_chunks} }),
        "$engine stderr chunks honor read_size");
    is_deeply($state->{errors}, [], "$engine drain reports no errors");
    is($state->{events}[-1], 'exit',
        "$engine drain delivers pipe EOF before exit");
}

done_testing;
