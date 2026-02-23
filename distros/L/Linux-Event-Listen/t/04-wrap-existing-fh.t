use v5.36;
use strict;
use warnings;

use Test::More;
use IO::Socket::IP;
use Linux::Event;
use Linux::Event::Listen;

my $server = IO::Socket::IP->new(
  LocalHost => '127.0.0.1',
  LocalPort => 0,
  Listen    => 10,
  Proto     => 'tcp',
  ReuseAddr => 1,
);
ok($server, 'created server socket');
my $port = $server->sockport;
ok($port > 0, 'server has port');

my $loop = Linux::Event->new;

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

ok(!$listen->{owns_socket}, 'wrap mode does not own socket');
ok($listen->sockport == $port, 'sockport matches');

my $c = IO::Socket::IP->new(PeerHost=>'127.0.0.1', PeerPort=>$port, Proto=>'tcp');
ok($c, 'client connected');
close $c;

$loop->run;

is($accepted, 1, 'accepted one');
ok(fileno($server), 'server fh still open after cancel (wrap mode)');

done_testing;
