use v5.36;
use strict;
use warnings;

use Test::More;
use IO::Socket::IP;
use Linux::Event;
use Linux::Event::Listen;

my $loop = Linux::Event->new;

local $SIG{ALRM} = sub { die "timeout\n" };
alarm 10;

my $accepted = 0;

my $listen = Linux::Event::Listen->new(
  loop => $loop,
  host => '127.0.0.1',
  port => 0,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    $accepted++;
    close $client_fh;
    $listen->cancel;
    $loop->stop;
  },
);

my $port = $listen->fh->sockport;

ok(!$listen->is_paused, 'not paused');

$listen->pause;
ok($listen->is_paused, 'paused');

# Try to connect while paused.
my $c1 = IO::Socket::IP->new(PeerHost=>'127.0.0.1', PeerPort=>$port, Proto=>'tcp');
ok($c1, 'client connected while paused (connect succeeds; accept is deferred)');
close $c1;

# Resume and then connect again; accept should happen now.
$listen->resume;
ok(!$listen->is_paused, 'resumed');

my $c2 = IO::Socket::IP->new(PeerHost=>'127.0.0.1', PeerPort=>$port, Proto=>'tcp');
ok($c2, 'client connected after resume');
close $c2;

$loop->run;

# There might be 1 or 2 accepts depending on backlog/when pause happened; ensure at least one.
ok($accepted >= 1, 'accepted at least one after resume');

alarm 0;
done_testing;
