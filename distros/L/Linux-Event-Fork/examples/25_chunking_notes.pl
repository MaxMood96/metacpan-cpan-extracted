#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

# WHAT THIS EXAMPLE SHOWS
# -----------------------
# * stdout/stderr callbacks receive CHUNKS, not "lines"
# * a line may arrive split across chunks; multiple lines may arrive together
#
# IF YOU HAVE A LINE PROTOCOL
# ---------------------------
# Implement buffering in user code:
#
#   my $buf = '';
#   on_stdout => sub ($child, $chunk) {
#     $buf .= $chunk;
#     while ($buf =~ s/^(.*?\n)//) {
#       my $line = $1;
#       ...
#     }
#   }
#
# This example prints chunk boundaries so you can see the behavior.

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

$loop->fork(
  tag => 'chunk-demo',

  cmd => [ $^X, '-we', q{ print "line1
"; print "line2
"; print "line3
"; } ],

  on_stdout => sub ($child, $chunk) {
    $chunk =~ s/\n/\\n\n/g;
    print "[chunk] $chunk";
  },

  on_exit => sub ($child, $exit) {
    $loop->stop;
  },
);

$loop->run;
