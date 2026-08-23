use v5.36;
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use File::Spec;

my $root = File::Spec->catdir($Bin, '..');

for my $required (
    'README.md',
    'LICENSE',
    'docs/CORE.md',
    'docs/ARCHITECTURE.md',
    'docs/XS-ROADMAP.md',
    'docs/DEVELOPMENT-HISTORY.md',
    'docs/STREAM-DESIGN.md',
    'docs/TRANSPORT-BOUNDARY.md',
    'docs/OBJECT-LIFECYCLE.md',
    'docs/STREAM-CONNECTIONS.md',
    'docs/LISTENER-DESIGN.md',
    'docs/TIMER-DESIGN.md',
    'docs/SIGNAL-DESIGN.md',
    'docs/WAKEUP-DESIGN.md',
    'docs/SOCKET-CONFIGURATION.md',
    'docs/DATAGRAM-DESIGN.md',
    'docs/PROCESS-DESIGN.md',
    'docs/CHOOSING-A-FRAMER.md',
    'docs/FRAMING.md',
    'bench/README.md',
    'bench/run-connect-microbench.pl',
    'bench/run-listen-microbench.pl',
    'bench/run-reactor-comparison.pl',
    'bench/run-resolver-microbench.pl',
    'bench/run-signal-microbench.pl',
    'bench/run-wakeup-microbench.pl',
    'bench/run-datagram-microbench.pl',
    'bench/run-process-microbench.pl',
    'bench/run-callback-ceiling.pl',
    'bench/run-stream-lifecycle-bench.pl',
    'bench/run-stream-microbench.pl',
    'bench/run-tls-microbench.pl',
    'bench/run-stream-transition-bench.pl',
    'bench/run-framing-microbench.pl',
    'bench/run-native-framers-microbench.pl',
    'bench/run-performance-regression.pl',
    'bench/run-timer-microbench.pl',
    'bench/archive/README.md',
    'lib/Linux/Event.pm',
    'lib/Linux/Event/Address.pm',
    'lib/Linux/Event/Error.pm',
    'lib/Linux/Event/Framer.pm',
    'lib/Linux/Event/Framer/DecimalLength.pm',
    'lib/Linux/Event/Framer/Delimiter.pm',
    'lib/Linux/Event/Framer/Fixed.pm',
    'lib/Linux/Event/Framer/LengthPrefix.pm',
    'lib/Linux/Event/Framer/Netstring.pm',
    'lib/Linux/Event/Framer/U32BE.pm',
    'lib/Linux/Event/Framer/Varint.pm',
    'lib/Linux/Event/TLS.pm',
    'lib/Linux/Event/Loop.pm',
    'lib/Linux/Event/Signal.pm',
    'lib/Linux/Event/Wakeup.pm',
    'lib/Linux/Event/Listener.pm',
    'lib/Linux/Event/Listener/_Engine.pm',
    'lib/Linux/Event/Stream.pm',
    'lib/Linux/Event/Stream/_Connection.pm',
    'lib/Linux/Event/Stream/_Resolver.pm',
    'lib/Linux/Event/Timer.pm',
    'lib/Linux/Event/Datagram.pm',
    'lib/Linux/Event/Process.pm',
    'lib/Linux/Event/_SocketConfig.pm',
    'xstls/Makefile.PL',
    'xstls/TLS.xs',
    'xstls/check_openssl.c',
    'xsconnection/Makefile.PL',
    'xsconnection/Connection.xs',
    'xsresolver/Makefile.PL',
    'xsresolver/Resolver.xs',
    'xssignal/Makefile.PL',
    'xssignal/Signal.xs',
    'xswakeup/Makefile.PL',
    'xswakeup/Wakeup.xs',
    'xsdatagram/Makefile.PL',
    'xsdatagram/Datagram.xs',
    'xsprocess/Makefile.PL',
    'xsprocess/Process.xs',
    'xsprocess/check_spawn_chdir.c',
    'xslistener/Makefile.PL',
    'xslistener/Listener.xs',
    'examples/line-echo-server.pl',
    'examples/line-echo-client.pl',
    'examples/udp-echo-server.pl',
    'examples/udp-echo-client.pl',
    'examples/wakeup-thread.pl',
    'examples/process-capture.pl',
) {
    ok(-s File::Spec->catfile($root, split m{/}, $required), "$required is present");
}

for my $live (
    'README.md',
    'docs/CORE.md',
    'docs/ARCHITECTURE.md',
    'docs/XS-ROADMAP.md',
    'docs/STREAM-DESIGN.md',
    'docs/TRANSPORT-BOUNDARY.md',
    'docs/OBJECT-LIFECYCLE.md',
    'docs/STREAM-CONNECTIONS.md',
    'docs/LISTENER-DESIGN.md',
    'docs/TIMER-DESIGN.md',
    'docs/SIGNAL-DESIGN.md',
    'docs/WAKEUP-DESIGN.md',
    'docs/SOCKET-CONFIGURATION.md',
    'docs/DATAGRAM-DESIGN.md',
    'docs/PROCESS-DESIGN.md',
    'docs/CHOOSING-A-FRAMER.md',
    'docs/FRAMING.md',
    'bench/README.md',
    'bench/run-connect-microbench.pl',
    'bench/run-listen-microbench.pl',
    'bench/run-reactor-comparison.pl',
    'bench/run-resolver-microbench.pl',
    'bench/run-signal-microbench.pl',
    'bench/run-wakeup-microbench.pl',
    'bench/run-datagram-microbench.pl',
    'bench/run-process-microbench.pl',
    'bench/run-callback-ceiling.pl',
    'bench/run-stream-lifecycle-bench.pl',
    'bench/run-stream-microbench.pl',
    'bench/run-tls-microbench.pl',
    'bench/run-stream-transition-bench.pl',
    'bench/run-framing-microbench.pl',
    'bench/run-native-framers-microbench.pl',
    'bench/run-performance-regression.pl',
    'bench/run-timer-microbench.pl',
) {
    my $path = File::Spec->catfile($root, split m{/}, $live);
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $src = <$fh>;
    close $fh;
    unlike($src, qr/\b(?:Phase|phase)\d+[A-Za-z]?\b/, "$live has no development-phase vocabulary");
}

my @bench_root = sort map { s{^.*/}{}r }
    grep { -f $_ }
    glob(File::Spec->catfile($root, 'bench', '*'));
my %allowed = map { $_ => 1 } qw(
    README.md
    STREAM-COMPETITOR-PLAN.md
    run-connect-microbench.pl
    run-listen-microbench.pl
    run-reactor-comparison.pl
    run-resolver-microbench.pl
    run-signal-microbench.pl
    run-wakeup-microbench.pl
    run-datagram-microbench.pl
    run-process-microbench.pl
    run-callback-ceiling.pl
    run-stream-lifecycle-bench.pl
    run-stream-microbench.pl
    run-tls-microbench.pl
    run-stream-transition-bench.pl
    run-framing-microbench.pl
    run-native-framers-microbench.pl
    run-performance-regression.pl
    run-timer-microbench.pl
);
is_deeply([grep { !$allowed{$_} } @bench_root], [], 'bench root contains only current public files');
ok(!-d File::Spec->catdir($root, 'tls'),
    'TLS does not have a nested distribution tree');

for my $removed (
    'lib/Linux/Event/Watcher.pm',
    'lib/Linux/Event/IO.pm',
    'lib/Linux/Event/XSLoop.pm',
    'lib/Linux/Event/XSWatcher.pm',
    'lib/Linux/Event/Connect.pm',
    'lib/Linux/Event/Connector.pm',
    'lib/Linux/Event/Listen.pm',
    'lib/Linux/Event/Stream/Error.pm',
    'lib/Linux/Event/Stream/Framer.pm',
) {
    ok(!-e File::Spec->catfile($root, split m{/}, $removed),
        "$removed is not part of the public surface");
}

done_testing;
