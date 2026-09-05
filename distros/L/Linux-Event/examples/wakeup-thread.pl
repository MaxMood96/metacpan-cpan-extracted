#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use threads;
use Thread::Queue;

use Linux::Event::Kernel::Event;
use Linux::Event::Loop;

{
    package Example::ResultsReady;
    use parent 'Linux::Event::Kernel::Event';

    sub on_event ($event, $count) {
        my $queue = $event->data;
        while (defined(my $item = $queue->dequeue_nb)) {
            if ($item eq '__DONE__') {
                $event->loop->stop;
                next;
            }
            say "result: $item";
        }
    }
}

my $loop = Linux::Event::Loop->new;
my $results = Thread::Queue->new;
my $event = $loop->add(Example::ResultsReady->new(data => $results));

my $worker = threads->create(sub {
    for my $number (1 .. 5) {
        $results->enqueue($number * $number);
        $event->signal;
    }
    $results->enqueue('__DONE__');
    $event->signal;
    return 1;
});

$loop->run;
$worker->join == 1 or die "worker did not complete\n";
$event->cancel;
