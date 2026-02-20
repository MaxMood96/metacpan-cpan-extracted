#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Linux::Event;
use Linux::Event::Fork;

# STRESS TEST: Fork timeout churn
# This stresses:
#   - fork/exit churn (many short-lived children)
#   - timeout timer scheduling + cancellation
#   - drain-first teardown stability under load
#
# Expected:
#   - loop stops cleanly after all children complete
#   - some children time out (timeout callback fires)
#   - child installs a TERM handler that exits 0, so a timed-out child may still be exit_ok

my $loop = Linux::Event->new;
my $forker = Linux::Event::Fork->new($loop);

my $N = $ENV{N} // 200;
my $TIMEOUT = 0.02;

my $done = 0;

my $timeout_fired = 0;          # count of timeout callbacks observed
my $exit_ok = 0;                # exit status == 0
my $exit_ok_timeout = 0;        # exit_ok where timeout fired
my $exit_ok_normal = 0;         # exit_ok where no timeout fired

my %timed_by_pid;

for my $i (1..$N) {
  $forker->spawn(
    tag => "job:$i",

    timeout => $TIMEOUT,
    on_timeout => sub ($child) {
      $timeout_fired++;
      $timed_by_pid{ $child->pid } = 1;
    },

    child => sub {
      $SIG{TERM} = sub { exit 0 };

      # Half the time, sleep longer than timeout.
      if ($i % 2 == 0) {
        select(undef, undef, undef, $TIMEOUT * 4);
      } else {
        select(undef, undef, undef, $TIMEOUT / 4);
      }
      exit 0;
    },

    on_exit => sub ($child, $exit) {
      $done++;

      if ($exit->exited && $exit->code == 0) {
        $exit_ok++;
        if ($timed_by_pid{ $child->pid }) {
          $exit_ok_timeout++;
        } else {
          $exit_ok_normal++;
        }
      }

      $loop->stop if $done == $N;
    },
  );
}

$loop->run;

print "DONE\n";
print "  N              = $N\n";
print "  timeout_fired   = $timeout_fired\n";
print "  exit_ok         = $exit_ok\n";
print "  exit_ok_normal  = $exit_ok_normal\n";
print "  exit_ok_timeout = $exit_ok_timeout\n";
