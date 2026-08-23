use v5.36;
use strict;
use warnings;
use Test::More;

use Linux::Event::Loop;

pipe(my $read_fh, my $write_fh) or die "pipe: $!";
my $loop = Linux::Event::Loop->new;
my $old_calls = 0;
my $new_calls = 0;

my $old = $loop->watch(
    fh   => $read_fh,
    read => sub ($watcher) { $old_calls++ },
);

$loop->reset_stats;
my $new = $loop->watch(
    fh   => $read_fh,
    read => sub ($watcher) {
        sysread($watcher->fh, my $bytes, 16);
        $new_calls++;
        $loop->stop;
    },
);

my $replace_stats = $loop->stats;
is($replace_stats->{epoll_ctl_mod_calls}, 1,
    'same-fd watcher replacement uses one epoll MOD');
is($replace_stats->{epoll_ctl_del_calls}, 0,
    'same-fd watcher replacement does not delete registration');
is($replace_stats->{epoll_ctl_add_calls}, 0,
    'same-fd watcher replacement does not add registration again');

$old->cancel;
syswrite($write_fh, 'x');
$loop->run;
is($old_calls, 0, 'replaced watcher is inert');
is($new_calls, 1, 'cancelling replaced handle does not remove new watcher');

$new->cancel;
close $read_fh;
close $write_fh;

# Closing a watched file description removes it from epoll immediately. Linux
# may reuse the descriptor number inside that callback before the old watcher
# is cancelled. Registry replacement must then recover from MOD/ENOENT with
# ADD, while preserving the same inert-old-handle semantics.
pipe(my $reuse_read, my $reuse_write) or die "pipe: $!";
my $reuse_loop = Linux::Event::Loop->new;
my $old_fd = fileno($reuse_read);
my ($replacement, $replacement_read, $replacement_write);
my $replacement_calls = 0;
my $reuse_old = $reuse_loop->watch(
    fh => $reuse_read,
    read => sub ($watcher) {
        sysread($reuse_read, my $byte, 1);
        close $reuse_read;
        pipe($replacement_read, $replacement_write) or die "pipe: $!";
        is(fileno($replacement_read), $old_fd,
            'kernel reuses watched descriptor number inside callback');
        $replacement = $reuse_loop->watch(
            fh => $replacement_read,
            read => sub ($new_watcher) {
                sysread($replacement_read, my $bytes, 1);
                $replacement_calls++;
                $reuse_loop->stop;
            },
        );
        syswrite($replacement_write, 'y');
    },
);
$reuse_loop->reset_stats;
syswrite($reuse_write, 'x');
$reuse_loop->run;
my $reuse_stats = $reuse_loop->stats;
is($reuse_stats->{epoll_ctl_mod_calls}, 1,
    'descriptor reuse first attempts registry replacement with MOD');
is($reuse_stats->{epoll_ctl_add_calls}, 1,
    'MOD ENOENT falls back to ADD for the reused file description');
is($replacement_calls, 1, 'replacement watcher receives readiness');
$reuse_old->cancel;
$replacement->cancel;
close $reuse_write;
close $replacement_read;
close $replacement_write;

done_testing;
