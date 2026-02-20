#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;
my $forker = Linux::Event::Fork->new($loop);

my @urls = (
"https://www.wikipedia.org",
"https://www.google.com",
"https://www.github.com",
"https://www.stackoverflow.com",
"https://www.reddit.com",
"https://www.bbc.co.uk",
"https://www.nasa.gov",
"https://www.python.org",
"https://www.microsoft.com",
"https://www.apple.com",
);

my $pending = @urls;

for my $url (@urls) {
  $forker->spawn(
    data => $url,

    child => sub {
      require HTTP::Tiny;

      my $http = HTTP::Tiny->new(
        timeout    => 12,
        user_agent => "Linux-Event-Fork/0.001 (HTTP::Tiny)",
        verify_SSL => 1,
      );

      my $res = $http->get($url);

      if ($res->{success}) {
        print "downloaded $url (status=$res->{status})\n";
        exit 0;
      }

      my $status = $res->{status} // 0;
      my $reason = $res->{reason} // "unknown";
      print STDERR "failed $url\n";
      print STDERR "status=$status reason=$reason\n";
      exit 1;
    },

    on_stdout => sub ($child, $chunk) {
      # $chunk is raw bytes; may be partial lines.
      print "[stdout] $chunk";
    },

    on_stderr => sub ($child, $chunk) {
      print "[stderr] $chunk";
    },

    on_exit => sub ($child, $exit) {
      my $u = $child->data;

      if ($exit->exited) {
        print "[exit] $u pid=" . $child->pid . " code=" . $exit->code . "\n";
      } elsif ($exit->signaled) {
        print "[exit] $u pid=" . $child->pid . " signal=" . $exit->signal .
              " core=" . ($exit->core_dump ? 1 : 0) . "\n";
      } else {
        print "[exit] $u pid=" . $child->pid . " raw=" . ($exit->raw // 'undef') . "\n";
      }

      $pending--;
      $loop->stop if $pending == 0;
    },
  );
}

$loop->run;
