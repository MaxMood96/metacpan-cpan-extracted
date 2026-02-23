use v5.36;
use strict;
use warnings;

use Test::More;
use Linux::Event;
use Linux::Event::Listen;

my $loop = Linux::Event->new;

my $listen = Linux::Event::Listen->new(
  loop => $loop,
  host => '127.0.0.1',
  port => 0,
  on_accept => sub ($loop, $client_fh, $peer, $listen) {
    close $client_fh;
    $listen->cancel;
    $loop->stop;
  },
);

ok($listen->is_running, 'running before cancel');

$listen->cancel;
ok(!$listen->is_running, 'not running after cancel');

# Idempotent: cancel again should not die.
ok(eval { $listen->cancel; 1 }, 'cancel is idempotent');

# DESTROY after cancel should not die.
ok(eval { undef $listen; 1 }, 'destroy after cancel is safe');

done_testing;
