use strict;
use warnings;
use threads;
use threads::shared;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use ForgeOps::Tracker::Configuration;
use ForgeOps::Tracker::DeliveryQueue;

sub new_configuration {
    my ($queue_size) = @_;
    my $config = ForgeOps::Tracker::Configuration->new;
    $config->{queue_size} = $queue_size // 10;
    return $config;
}

sub wait_until {
    my ($predicate, $timeout) = @_;
    $timeout //= 2;
    my $deadline = time + $timeout;
    while (time < $deadline) {
        return 1 if $predicate->();
        select(undef, undef, undef, 0.02);
    }
    return 0;
}

package Fake::Client {
    sub new {
        my ($class, %args) = @_;
        return bless { %args }, $class;
    }
    sub deliver {
        my ($self, $payload) = @_;
        if ($self->{die_on_first} && !$self->{called}++) {
            die "boom\n";
        }
        {
            lock(@{ $self->{delivered} });
            push @{ $self->{delivered} }, $payload->{n};
        }
        return 1;
    }
}

subtest 'delivers a pushed payload via the client on its background thread' => sub {
    my @delivered :shared;
    my $client = Fake::Client->new(delivered => \@delivered);
    my $queue = ForgeOps::Tracker::DeliveryQueue->new(new_configuration(10), $client);

    $queue->push({ n => 1 });

    ok(wait_until(sub { scalar(@delivered) == 1 }), 'delivered within timeout');
    is($delivered[0], 1);
};

subtest 'drops a payload without blocking when the queue is already full' => sub {
    # A client that never actually completes delivery (sleeps far longer than this test runs), so
    # nothing drains the queue and capacity stays exactly at queue_size (1) for a deterministic
    # full-queue test.
    package Fake::NeverDelivers {
        sub new { return bless {}, shift }
        sub deliver { sleep 5; return 1; }
    }
    my $client = Fake::NeverDelivers->new;
    my $queue = ForgeOps::Tracker::DeliveryQueue->new(new_configuration(1), $client);

    is($queue->push({ n => 1 }), 1);

    # The first push may already have been dequeued by the worker thread (draining the queue
    # before it observes "full"), so retry briefly rather than asserting on a single racy attempt.
    my $deadline = time + 2;
    my $second_push_result = 1;
    while (time < $deadline) {
        $second_push_result = $queue->push({ n => 2 });
        last unless $second_push_result;
    }

    is($second_push_result, 0);
};

subtest 'recovers from the client dying instead of returning' => sub {
    my @delivered :shared;
    my $client = Fake::Client->new(delivered => \@delivered, die_on_first => 1);
    my $queue = ForgeOps::Tracker::DeliveryQueue->new(new_configuration(10), $client);

    $queue->push({ n => 1 }); # dies inside the worker thread; must not kill it
    $queue->push({ n => 2 });

    ok(wait_until(sub { scalar(@delivered) == 1 }), 'delivered within timeout');
    is($delivered[0], 2);
};

done_testing;
