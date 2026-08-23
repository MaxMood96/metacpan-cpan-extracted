use v5.36;
use Test::More;
use Linux::Event::Loop;
use IO::Handle;

pipe(my $r, my $w) or die $!;
$r->blocking(0);
$w->blocking(0);

my $loop = Linux::Event::Loop->new;
my $got = 0;
my $watcher = $loop->watch_fd(fileno($r), fh => $r, read => sub ($watcher) {
    my $fh = $watcher->fh;
    sysread($fh, my $buf, 16);
    $got++ if $buf eq 'x';
    $watcher->cancel;
    $watcher->loop->stop;
});

syswrite($w, 'x');
$loop->run;
is($got, 1, 'read callback fired');
done_testing;
