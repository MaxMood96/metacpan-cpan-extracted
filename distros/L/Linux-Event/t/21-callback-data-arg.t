use v5.36;
use strict;
use warnings;

use Test::More;
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);

use Linux::Event::Loop;

socketpair(my $a, my $b, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";

my $loop = Linux::Event::Loop->new;
my $data = { seen => 0 };
my $got;

my $watcher = $loop->watch_fd(
    fileno($a),
    fh   => $a,
    data => $data,
    read => sub ($arg) {
        $got = $arg;
        $arg->{seen}++;
        my $buf = '';
        sysread($a, $buf, 1);
    },
    _callback_data_arg => 1,
);

syswrite($b, "x");
$loop->run_once(1000);

is($got, $data, 'private callback-data hook passes watcher data directly');
is($data->{seen}, 1, 'callback received live data object');

my $ok = eval {
    $loop->watch_fd(
        fileno($b),
        fh   => $b,
        read => sub ($arg) { },
        _callback_data_arg => 1,
    );
    1;
};
ok(!$ok, 'callback-data hook requires data');
like($@, qr/_callback_data_arg requires data/, 'missing-data error is explicit');

$watcher->cancel;
close $a;
close $b;

done_testing;
