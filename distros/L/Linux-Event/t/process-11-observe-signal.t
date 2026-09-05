use v5.36;
use strict;
use warnings;

use POSIX qw(SIGTERM _exit);
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Kernel::Process;

our @EXIT;

{
    package T::Process::Observed;
    use parent 'Linux::Event::Kernel::Process';
    sub on_exit ($self) {
        push @main::EXIT, [$self->exit_code, $self->term_signal];
        $self->loop->stop;
    }
}

my $pid = fork();
if (!defined $pid) {
    plan skip_all => "fork unavailable: $!";
}
if ($pid == 0) {
    _exit(23);
}

my $loop = Linux::Event::Loop->new;
my $observed = $loop->add(T::Process::Observed->new(
    pid  => $pid, # required
    reap => 1,    # default
));
$loop->run;
is_deeply($EXIT[0], [23, undef], 'existing child is reaped through pidfd');

@EXIT = ();
my $signal_loop = Linux::Event::Loop->new;
my $running = $signal_loop->add(T::Process::Observed->spawn(
    command => [$^X, '-e', 'sleep 30'], # required
));
is($running->signal(SIGTERM), $running,
    'signal returns Process and uses pidfd identity');
$signal_loop->run;
is($EXIT[0][0], undef, 'signalled process has no exit code');
is($EXIT[0][1], SIGTERM, 'terminating signal is decoded');

done_testing;
