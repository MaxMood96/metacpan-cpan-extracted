use v5.36;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use IO::Socket::UNIX;
use Linux::Event;
use Linux::Event::Listen;

my $dir = tempdir(CLEANUP => 1);
my $path = "$dir/wrap.sock";

my $server = IO::Socket::UNIX->new(
  Type   => Socket::SOCK_STREAM(),
  Local  => $path,
  Listen => 10,
);
ok($server, 'created unix server socket');
ok(-S $path, 'socket file exists');

my $loop = Linux::Event->new;

local $SIG{ALRM} = sub { die "timeout\n" };
alarm 10;

my $accepted = 0;
my $listen = Linux::Event::Listen->new(
  loop => $loop,
  fh   => $server,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    $accepted++;
    close $client_fh;
    $listen->cancel;
    $loop->stop;
  },
);

is($listen->family, 'unknown', 'wrap unix fh has unknown family (no path info)');

my $c = IO::Socket::UNIX->new(Peer => $path, Type => Socket::SOCK_STREAM());
ok($c, 'unix client connected');
close $c;

$loop->run;

is($accepted, 1, 'accepted one');
ok(-S $path, 'socket file still exists after cancel (wrap mode)');

alarm 0;
done_testing;
