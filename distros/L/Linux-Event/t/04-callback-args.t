use v5.36;
use Test::More;
use IO::Handle;
use Linux::Event::Loop;

pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $loop = Linux::Event::Loop->new;
my $argc = -1;
my $watcher = $loop->watch_fd(
    fileno($r),
    fh => $r,
    no_args => 1,
    read => sub {
        $argc = scalar @_;
        sysread($r, my $buf, 1);
        $loop->stop;
    },
);

syswrite($w, 'x');
$loop->run;

is($argc, 0, 'no_args => 1 invokes callback with no args');
my $st = $loop->stats;
is($st->{callback_noarg_calls}, 1, 'no-arg callback counted');
is($st->{callback_onearg_calls}, 0, 'one-arg callback not counted');
$watcher->cancel;

like(exception(sub { $loop->watch_fd(
    fileno($r), fh => $r, callback_args => 0, read => sub { },
) }), qr/unknown watch_fd option 'callback_args'/,
    'removed callback_args compatibility option is rejected');
like(exception(sub { $loop->watch_fd(
    fileno($r), fh => $r, no_args => 1, no_accessor_refs => 1,
    read => sub { },
) }), qr/unknown watch_fd option 'no_accessor_refs'/,
    'removed no_accessor_refs compatibility option is rejected');

done_testing;

sub exception ($code) {
    local $@;
    return eval { $code->(); 1 } ? '' : "$@";
}
