use v5.36;
use Test::More;
use Linux::Event::Loop;
use IO::Handle;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

sub make_pair {
    socketpair(my $server, my $client, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die $!;
    $server->blocking(0);
    $client->blocking(0);
    return ($server, $client);
}

{
    my ($server, $client) = make_pair();
    my $loop = Linux::Event::Loop->new;
    my $watcher = $loop->watch_fd(
        fileno($server),
        no_args => 1,
        lean => 1,
        _bench_native_echo => 1,
        error => sub { },
    );

    is(syswrite($client, 'native-a!'), 9, 'mode A client write completed');
    $loop->run_once(1000);

    my $n = sysread($client, my $buf, 64);
    is($n, 9, 'mode A echoed expected byte count');
    is($buf, 'native-a!', 'mode A native XS echo returned payload');

    my $stats = $loop->stats;
    is($stats->{read_callback_calls}, 0, 'mode A invokes no Perl read callback');
    is($stats->{bench_native_echo_read_events}, 1, 'mode A records one native read event');
    is($stats->{bench_native_echo_perl_read_callbacks}, 0, 'mode A records zero benchmark Perl read callbacks');
    is($stats->{bench_native_echo_bytes_read}, 9, 'mode A records native bytes read');
    is($stats->{bench_native_echo_bytes_written}, 9, 'mode A records native bytes written');
    is($stats->{bench_native_echo_errors}, 0, 'mode A reports no native echo errors');

    $watcher->cancel;
    close $client;
    close $server;
}

{
    my ($server, $client) = make_pair();
    my $loop = Linux::Event::Loop->new;
    my $empty_calls = 0;
    my $watcher = $loop->watch_fd(
        fileno($server),
        no_args => 1,
        lean => 1,
        _bench_native_echo => 2,
        read => sub { $empty_calls++ },
        error => sub { },
    );

    is(syswrite($client, 'native-b!'), 9, 'mode B client write completed');
    $loop->run_once(1000);

    my $n = sysread($client, my $buf, 64);
    is($n, 9, 'mode B echoed expected byte count');
    is($buf, 'native-b!', 'mode B native XS echo returned payload');
    is($empty_calls, 1, 'mode B invokes one empty Perl read callback');

    my $stats = $loop->stats;
    is($stats->{read_callback_calls}, 1, 'mode B stats count the Perl read callback');
    is($stats->{callback_calls}, 1, 'mode B callback counter records the empty callback');
    is($stats->{bench_native_echo_read_events}, 1, 'mode B records the same native read event');
    is($stats->{bench_native_echo_perl_read_callbacks}, 1, 'mode B records one benchmark Perl read callback');
    is($stats->{bench_native_echo_bytes_read}, 9, 'mode B records native bytes read');
    is($stats->{bench_native_echo_bytes_written}, 9, 'mode B records native bytes written');
    is($stats->{bench_native_echo_errors}, 0, 'mode B reports no native echo errors');

    $watcher->cancel;
    close $client;
    close $server;
}

{
    my ($server, $client) = make_pair();
    my $loop = Linux::Event::Loop->new;
    my $ok = eval {
        $loop->watch_fd(
            fileno($server),
            no_args => 1,
            lean => 1,
            _bench_native_echo => 3,
            error => sub { },
        );
        1;
    };
    ok(!$ok, 'invalid benchmark native echo mode is rejected');
    like($@, qr/_bench_native_echo must be 0, 1, or 2/, 'invalid mode error is specific');
    close $client;
    close $server;
}

done_testing;
