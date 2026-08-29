use v5.36;
use strict;
use warnings;
use Test::More;
use POSIX qw(SIGUSR1);
use Scalar::Util qw(refaddr);
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Datagram;
use Linux::Event::Listener;
use Linux::Event::Loop;
use Linux::Event::Process;
use Linux::Event::Signal;
use Linux::Event::Stream;
use Linux::Event::Timer;
use Linux::Event::Wakeup;

{
    package T::InspectStream;
    use parent 'Linux::Event::Stream';
    sub on_data ($stream, $bytes) { }
}

{
    package T::InspectDatagram;
    use parent 'Linux::Event::Datagram';
    sub on_datagram ($socket, $payload, $peer) { }
}

{
    package T::InspectTimer;
    use parent 'Linux::Event::Timer';
    sub on_timer ($timer) { }
}

{
    package T::InspectSignal;
    use parent 'Linux::Event::Signal';
    sub on_signal ($signal, $number, $count) { }
}

{
    package T::InspectWakeup;
    use parent 'Linux::Event::Wakeup';
    sub on_wakeup ($wakeup, $count) { }
}

{
    package T::InspectProcess;
    use parent 'Linux::Event::Process';
    sub on_exit ($process) { $process->loop->stop }
}

my $loop = Linux::Event::Loop->new;
socketpair(my $stream_fh, my $peer_fh, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";

my %object;
$object{stream} = T::InspectStream->new(
    loop => $loop, fh => $stream_fh,
);
$object{listener} = Linux::Event::Listener->new(
    loop => $loop, stream_class => 'T::InspectStream',
    host => '127.0.0.1', port => 0,
);
$object{datagram} = T::InspectDatagram->new(
    loop => $loop, host => '127.0.0.1', port => 0,
);
$object{timer} = T::InspectTimer->new(
    loop => $loop, after => 60,
);
$object{signal} = T::InspectSignal->new(
    loop => $loop, signals => [SIGUSR1],
);
$object{wakeup} = T::InspectWakeup->new(loop => $loop);
$object{process} = T::InspectProcess->spawn(
    loop => $loop, command => [$^X, '-e', 'exit 0'],
);

is_deeply(
    $loop->census,
    { map { $_ => 1 } qw(stream listener datagram timer signal wakeup process) },
    'census discovers every managed public type from authoritative state',
);
is($loop->count, 7, 'count excludes private backing objects and registrations');

my %seen = map { refaddr($_) => 1 } @{ $loop->objects };
for my $type (sort keys %object) {
    ok($seen{ refaddr($object{$type}) }, "objects contains exact $type object");
    my $snapshot = $loop->inspect($object{$type});
    is($snapshot->{type}, $type, "$type inspection has canonical type");
    is($snapshot->{registered}, 1, "$type inspection is registered");
    ok(defined $snapshot->{state}, "$type inspection has state");
}

ok(exists $loop->inspect($object{stream})->{pending_bytes},
    'Stream inspection includes queue state');
ok(exists $loop->inspect($object{listener})->{accepted},
    'Listener inspection includes accept count');
ok(exists $loop->inspect($object{datagram})->{pending_datagrams},
    'Datagram inspection includes packet queue state');
is_deeply($loop->inspect($object{signal})->{signals}, [SIGUSR1],
    'Signal inspection includes subscribed numbers');
is($loop->inspect($object{process})->{pid}, $object{process}->pid,
    'Process inspection includes pid');

my %reason = map { $_->{type} => 1 } @{ $loop->why_alive };
ok($reason{$_}, "why_alive contains $_ reason")
    for sort keys %object;

$object{timer}->cancel;
$object{signal}->cancel;
$object{wakeup}->cancel;
$object{listener}->close;
$object{datagram}->close;
$object{stream}->close;
close $peer_fh;

$loop->run;
is($loop->count, 0, 'completed and closed objects leave no liveness reasons');
is_deeply($loop->why_alive, [], 'why_alive is empty after cleanup');

done_testing;
