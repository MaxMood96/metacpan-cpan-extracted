use v5.36;
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);

my $file = "$Bin/../bench/run-reactor-comparison.pl";
open my $fh, '<', $file or die "open $file: $!";
local $/;
my $src = <$fh>;
close $fh;

like(
    $src,
    qr/my \$systems = 'linuxevent,ev,anyevent-ae,uv,ioasync-epoll,mojo-epoll';/,
    'default leaderboard contains the six intended reactor systems',
);
like($src, qr/my \$repeats = 6;/, 'default repeats match six-system balanced rotation');
like($src, qr/sub setup_uv \(/, 'UV::Poll setup is implemented');
like($src, qr/sub setup_ioasync_epoll \(/, 'IO::Async::Loop::Epoll setup is implemented');
like($src, qr/sub setup_mojo_epoll \(/, 'Mojo::Reactor::Epoll setup is implemented');
like($src, qr/anyevent-method/, 'AnyEvent method diagnostic remains available');
like($src, qr/anyevent-ae-evrun/, 'AnyEvent direct EV::run diagnostic remains available');
like($src, qr/not a multiple of the selected system count/, 'unbalanced repeat count warning is implemented');

done_testing;
