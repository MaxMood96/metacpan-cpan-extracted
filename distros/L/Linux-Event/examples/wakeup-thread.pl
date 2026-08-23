#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use threads;
use Thread::Queue;

use Linux::Event::Loop;
use Linux::Event::Wakeup;

{
    package Example::ResultsReady;
    use parent 'Linux::Event::Wakeup';

    sub on_wakeup ($wakeup, $count) {
        my $queue = $wakeup->data;
        while (defined(my $item = $queue->dequeue_nb)) {
            if ($item eq '__DONE__') {
                $wakeup->loop->stop;
                next;
            }
            say "result: $item";
        }
    }
}

my $loop = Linux::Event::Loop->new;
my $results = Thread::Queue->new;
my $wakeup = $loop->add(Example::ResultsReady->new(data => $results));

my $worker = threads->create(sub {
    for my $number (1 .. 5) {
        $results->enqueue($number * $number);
        $wakeup->signal;
    }
    $results->enqueue('__DONE__');
    $wakeup->signal;
    return 1;
});

$loop->run;
$worker->join == 1 or die "worker did not complete\n";
$wakeup->cancel;
