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
  max_accept_per_tick => 3,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    $accepted++;
    close $client_fh;
    # cancel after we accept enough overall; loop fairness is exercised by the cap
    $listen->cancel if $accepted >= 10;
    $loop->stop if $accepted >= 10;
  },

  on_error => sub ($loop, $err, $listen) {
    fail("unexpected on_error: $err->{op} $err->{error}");
    $listen->cancel if $listen;
    $loop->stop;
  },
);

my $port = $listen->fh->sockport;

# Burst-connect 10 clients quickly.
my @c;
for (1..10) {
  my $c = IO::Socket::IP->new(PeerHost=>'127.0.0.1', PeerPort=>$port, Proto=>'tcp');
  ok($c, "client $_ connected");
  push @c, $c;
}

# Close them; server side already closed accepted sockets.
close $_ for @c;

$loop->run;

cmp_ok($accepted, '==', 10, 'accepted all connections');

alarm 0;
done_testing;
