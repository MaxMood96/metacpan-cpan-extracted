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
    ok($peer->{family} eq 'inet' || $peer->{family} eq 'inet6', 'peer family present');
    ok(defined $peer->{host}, 'peer host present');
    ok(defined $peer->{port}, 'peer port present');
    close $client_fh;

    # Stop after one accept.
    $listen->cancel;
    $loop->stop;
  },

  on_error => sub ($loop, $err, $listen) {
    fail("unexpected on_error: $err->{op} $err->{error}");
    $listen->cancel if $listen;
    $loop->stop;
  },
);

ok($listen->fd, 'listener has fd');

my $port = $listen->fh->sockport;
ok($port > 0, 'listener has ephemeral port');

my $c = IO::Socket::IP->new(
  PeerHost => '127.0.0.1',
  PeerPort => $port,
  Proto    => 'tcp',
);
ok($c, 'client connected');
close $c;

# Run loop until listener cancels itself.
$loop->run;

is($accepted, 1, 'accepted exactly one connection');

alarm 0;
done_testing;
