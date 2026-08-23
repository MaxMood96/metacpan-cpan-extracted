#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event::Loop;
use Linux::Event::Process;

{
    package Example::CapturedProcess;
    use parent 'Linux::Event::Process';

    sub on_stdout ($process, $bytes) {
        $process->data->{stdout} .= $bytes;
    }

    sub on_stderr ($process, $bytes) {
        $process->data->{stderr} .= $bytes;
    }

    sub on_error ($process, $error) {
        warn "$error\n";
    }

    sub on_exit ($process) {
        my $result = $process->data;
        print "stdout:\n$result->{stdout}" if length $result->{stdout};
        print STDERR "stderr:\n$result->{stderr}" if length $result->{stderr};
        if (defined(my $code = $process->exit_code)) {
            say "exit code: $code";
        } else {
            say 'terminated by signal: ' . $process->term_signal;
        }
        $process->loop->stop;
    }
}

my @command = @ARGV
    ? @ARGV
    : ($^X, '-e', 'print "captured output\n"; warn "captured warning\n"');

my $loop = Linux::Event::Loop->new;
$loop->add(Example::CapturedProcess->spawn(
    command => \@command,
    stdin   => 'null',
    stdout  => 'pipe',
    stderr  => 'pipe',
    data    => { stdout => '', stderr => '' },
));
$loop->run;
