use v5.36;
use strict;
use warnings;

use POSIX qw(_exit);
use Test::More;

use Linux::Event::Loop;
use Linux::Event::Kernel::Event;

{
    package T::ForkWakeup;
    use parent 'Linux::Event::Kernel::Event';
    sub on_event ($self, $count) {
        ${ $self->data } = $count;
        $self->loop->stop;
    }
}

my $loop = Linux::Event::Loop->new;
my $count = 0;
my $wakeup = $loop->add(T::ForkWakeup->new(data => \$count));

my $pid = fork();
if (!defined $pid) {
    plan skip_all => "fork unavailable: $!";
}
if ($pid == 0) {
    my $ok = eval { $wakeup->signal(7); 1 };
    _exit($ok ? 0 : 1);
}

$loop->run;
waitpid($pid, 0);
is($?, 0, 'child signalled inherited eventfd');
is($count, 7, 'parent Loop received child wakeup');
$wakeup->cancel;

done_testing;
