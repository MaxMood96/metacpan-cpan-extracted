use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Process;

{
    package T::LimitedStdinProcess;
    use parent 'Linux::Event::Process';
    sub process_options ($class) {
        return max_pending_stdin => 4096,
            stdin_high_watermark => 2048,
            stdin_low_watermark => 1024;
    }
    sub on_error ($process, $error) {
        $process->data->{error} = $error;
    }
    sub on_exit ($process) {
        $process->data->{exit}++;
        $process->loop->stop if $process->loop;
    }
}

my $loop = Linux::Event::Loop->new;
my $state = { error => undef, exit => 0 };
my $process = T::LimitedStdinProcess->spawn(
    loop => $loop,
    command => [
        $^X, '-e',
        '$SIG{TERM} = sub { exit 0 }; sleep 5',
    ],
    stdin => 'pipe', stdout => 'null', stderr => 'null',
    data => $state,
);

my $accepted = $process->write_stdin('x' x (1024 * 1024));
ok(!defined($accepted), 'hard pending-input limit rejects unsent remainder');
isa_ok($state->{error}, 'Linux::Event::Error');
is($state->{error}->type, 'output_limit',
    'stdin overflow reports a distinct output_limit error');
is($state->{error}->operation, 'write_stdin',
    'stdin overflow identifies its operation');
like(exception(sub { $process->write_stdin('later') }),
    qr/(?:closing|closed)/,
    'stdin becomes terminal after a partially delivered overflow');
is($process->pending_stdin_bytes, 0,
    'terminal stdin does not retain an ambiguous queued remainder');

$process->signal(15) if $process->is_running;
$loop->run_for(1);
is($state->{exit}, 1, 'child is reaped after the regression case');
done_testing;

sub exception ($code) {
    my $error = '';
    eval { $code->(); 1 } or $error = $@;
    return $error;
}
