#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Listen;

my $loop = Linux::Event->new;

my $listen = Linux::Event::Listen->new(
  loop => $loop,
  host => '127.0.0.1',
  port => 3000,

  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    print "accepted from $peer->{host}:$peer->{port}\n";

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

print "listening on 127.0.0.1:3000\n";
$loop->run;
