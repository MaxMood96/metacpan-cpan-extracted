#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use threads;
use Thread::Queue;
use HTTP::Tiny;

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

my $jobs = Thread::Queue->new(@urls);
my $results = Thread::Queue->new;

my $NTHREADS = 3;

sub worker ($tid) {
  my $http = HTTP::Tiny->new(
    timeout    => 12,
    verify_SSL => 1,
    user_agent => "threads-demo/0.1 (HTTP::Tiny)",
  );

  while (defined(my $url = $jobs->dequeue_nb)) {
    my $res = $http->get($url);

    if ($res->{success}) {
      $results->enqueue({
        url     => $url,
        ok      => 1,
        status  => $res->{status},
        reason  => $res->{reason},
      });
    } else {
      $results->enqueue({
        url     => $url,
        ok      => 0,
        status  => $res->{status} // 0,
        reason  => $res->{reason} // "unknown",
      });
    }
  }

  return;
}

my @thr = map { threads->create(\&worker, $_) } 1..$NTHREADS;

# Wait for workers, but also print results as they come in.
# Since we know how many URLs we submitted, we can block until we collect them all.
my $pending = @urls;

while ($pending > 0) {
  my $r = $results->dequeue;  # blocks
  if ($r->{ok}) {
    print "[stdout] downloaded $r->{url} (status=$r->{status})\n";
    print "[exit]   $r->{url} code=0\n";
  } else {
    print "[stderr] failed $r->{url}\n";
    print "[stderr] status=$r->{status} reason=$r->{reason}\n";
    print "[exit]   $r->{url} code=1\n";
  }
  $pending--;
}

$_->join for @thr;
