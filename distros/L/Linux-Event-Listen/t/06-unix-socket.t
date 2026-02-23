use v5.36;
use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use IO::Socket::UNIX;
use Linux::Event;
use Linux::Event::Listen;

my $dir = tempdir(CLEANUP => 1);
my $path = "$dir/test.sock";

my $loop = Linux::Event->new;

local $SIG{ALRM} = sub { die "timeout\n" };
alarm 10;

my $accepted = 0;

my $listen = Linux::Event::Listen->new(
  loop => $loop,
  path => $path,
  unlink => 1,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    $accepted++;
    is($peer->{family}, 'unix', 'peer family unix');
    close $client_fh;

    $listen->cancel;
    $loop->stop;
  },

  on_error => sub ($loop, $err, $listen) {
    fail("unexpected on_error: $err->{op} $err->{error}");
    $listen->cancel if $listen;
    $loop->stop;
  },
);

ok(-S $path, 'unix socket file exists after listen');

my $c = IO::Socket::UNIX->new(Peer => $path, Type => Socket::SOCK_STREAM());
ok($c, 'unix client connected');
close $c;

$loop->run;

is($accepted, 1, 'accepted one unix client');

# unlink_on_cancel defaults true for internally-created unix sockets
ok(!-e $path, 'unix socket file removed on cancel');

alarm 0;
done_testing;
