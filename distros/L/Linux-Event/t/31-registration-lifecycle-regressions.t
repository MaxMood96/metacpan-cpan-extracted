use v5.36;
use strict;
use warnings;
use Test::More;
use POSIX ();
use Scalar::Util qw(weaken);

use Linux::Event::Loop;

{
    package T::RegistrationPayload;
    our $destroyed = 0;
    sub new ($class) { bless {}, $class }
    sub DESTROY ($self) { $destroyed++ }
}

subtest 'cancel releases retained Perl state and Loop ownership' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $loop = Linux::Event::Loop->new;
    my $weak_loop = $loop;
    weaken($weak_loop);

    $T::RegistrationPayload::destroyed = 0;
    my $payload = T::RegistrationPayload->new;
    my $registration = $loop->watch(
        fd   => fileno($reader),
        data => $payload,
        read => sub ($watcher) { return },
    );

    $registration->cancel;
    undef $payload;
    is($T::RegistrationPayload::destroyed, 1,
        'cancel immediately releases registration data');

    undef $registration;
    undef $loop;
    ok(!defined($weak_loop),
        'cancelled registration does not keep its Loop alive');

    close $reader;
    close $writer;
};

subtest 'obsolete handle cannot cancel recycled replacement' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $loop = Linux::Event::Loop->new;
    $loop->enable_watcher_reclaim(1);

    my $obsolete = $loop->watch(
        fd   => fileno($reader),
        read => sub ($watcher) { return },
    );
    $obsolete->cancel;

    my $calls = 0;
    my $replacement = $loop->watch(
        fd   => fileno($reader),
        read => sub ($watcher) {
            sysread($reader, my $buffer, 16);
            $calls++;
        },
    );

    $obsolete->cancel;
    syswrite($writer, 'x');
    $loop->run_once(100);
    is($calls, 1,
        'cancelling obsolete handle leaves recycled replacement active');

    $replacement->cancel;
    close $reader;
    close $writer;
};

subtest 'lean handle is inert after Loop destruction' => sub {
    pipe(my $reader, my $writer) or die "pipe: $!";
    my $pid = fork();
    die "fork: $!" if !defined $pid;
    if ($pid == 0) {
        close $writer;
        my $loop = Linux::Event::Loop->new;
        my $registration = $loop->watch(
            fd      => fileno($reader),
            read    => sub { return },
            no_args => 1,
            lean    => 1,
        );
        undef $loop;
        my $safe = eval { $registration->cancel; 1 };
        POSIX::_exit($safe ? 0 : 2);
    }

    close $reader;
    close $writer;
    waitpid($pid, 0);
    is($?, 0, 'stale lean handle can be cancelled safely');
};

done_testing;
