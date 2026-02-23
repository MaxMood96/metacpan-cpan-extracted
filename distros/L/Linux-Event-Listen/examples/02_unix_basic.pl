#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Listen;

my $loop = Linux::Event->new;

my $path = "/tmp/linux-event-listen.sock";

my $listen = Linux::Event::Listen->new(
  loop   => $loop,
  path   => $path,
  unlink => 1,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    print "accepted unix client\n";

    $loop->watch($client_fh,
      read => sub ($loop, $fh, $w) {
        my $buf;
        my $n = sysread($fh, $buf, 8192);
        if (!defined $n || $n == 0) {
          $w->cancel;
          close $fh;
          return;
        }
        syswrite($fh, $buf);
      },
    );
  },

  on_error => sub ($loop, $err, $listen) {
    warn "listener error ($err->{op}): $err->{error}\n";
  },
);

print "listening on $path\n";
$loop->run;
