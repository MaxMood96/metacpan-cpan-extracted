#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";


use Linux::Event;

pipe(my $r, my $w) or die "pipe failed: $!";

my $loop = Linux::Event->new( backend => 'epoll' );

$loop->watch($r,
  read => sub ($loop, $fh, $watcher) {
    my $buf = '';
    my $n = sysread($fh, $buf, 4096);
    if (defined $n && $n > 0) {
      chomp $buf;
      say "watch_read_pipe: read='$buf'";
      $watcher->cancel;
      $loop->stop;
    }
  },
);

$loop->after(0.020, sub ($loop) {
  syswrite($w, "hello\n");
});

$loop->run;
say "watch_read_pipe: done";
