use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Loop;

pipe(my $r, my $w) or die "pipe: $!";
my $loop = Linux::Event::Loop->new;

my $fh_watcher = $loop->watch(
    fh   => $r,
    read => sub ($watcher) {
        sysread($watcher->fh, my $buf, 16);
        $loop->stop;
    },
);

is($fh_watcher->fd, fileno($r), 'watch(fh => ...) derives fd');
is($fh_watcher->fh, $r, 'watch(fh => ...) retains handle');
syswrite($w, 'x');
$loop->run;
$fh_watcher->cancel;

my $fd_watcher = $loop->watch(
    fd   => fileno($r),
    read => sub ($watcher) { },
);
is($fd_watcher->fd, fileno($r), 'watch(fd => ...) stores raw fd');
ok(!defined($fd_watcher->fh), 'watch(fd => ...) has no filehandle');
$fd_watcher->cancel;

like(
    exception(sub { $loop->watch(read => sub { }) }),
    qr/exactly one of fh or fd/,
    'watch requires fh or fd',
);
like(
    exception(sub { $loop->watch(fh => $r, fd => fileno($r), read => sub { }) }),
    qr/exactly one of fh or fd/,
    'watch rejects both fh and fd',
);
like(
    exception(sub { $loop->watch(fd => -1, read => sub { }) }),
    qr/non-negative integer/,
    'watch rejects negative fd',
);
like(
    exception(sub {
        $loop->watch_fd('99999999999999999999', read => sub { });
    }),
    qr/non-negative integer/,
    'watch_fd rejects an fd outside the native integer range',
);
like(
    exception(sub { $loop->watch_fd(1.5, read => sub { }) }),
    qr/non-negative integer/,
    'watch_fd rejects a fractional fd',
);
like(
    exception(sub { $loop->unwatch_fd('99999999999999999999') }),
    qr/non-negative integer/,
    'unwatch_fd cannot wrap an oversized fd onto another registration',
);

close $r;
close $w;

done_testing;

sub exception ($cb) {
    my $error = '';
    eval { $cb->(); 1 } or $error = $@;
    return $error;
}
