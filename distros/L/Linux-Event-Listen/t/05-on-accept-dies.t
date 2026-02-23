use v5.36;
use strict;
use warnings;

use Test::More;
use IO::Socket::IP;
use Linux::Event;
use Linux::Event::Listen;

my $loop = Linux::Event->new;

my $saw_error = 0;

my $listen = Linux::Event::Listen->new(
  loop => $loop,
  host => '127.0.0.1',
  port => 0,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    close $client_fh;
    die "boom\n";
  },

  on_error => sub ($loop, $err, $listen) {
    $saw_error++ if $err->{op} eq 'on_accept';
    $listen->cancel;
    $loop->stop;
  },
);

my $port = $listen->sockport;

my $c = IO::Socket::IP->new(PeerHost=>'127.0.0.1', PeerPort=>$port, Proto=>'tcp');
ok($c, 'client connected');
close $c;

$loop->run;

is($saw_error, 1, 'on_error saw on_accept die');

done_testing;
