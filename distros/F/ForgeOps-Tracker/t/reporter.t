use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use ForgeOps::Tracker::Configuration;
use ForgeOps::Tracker::Reporter;

sub enabled_configuration {
    my $config = ForgeOps::Tracker::Configuration->new;
    $config->{dsn} = 'https://key@tracker.example.com/api/v1/events';
    $config->{enabled_environments} = { production => 1 };
    $config->{environment} = 'production';
    return $config;
}

package Fake::EventBuilder {
    sub new { my ($class, %args) = @_; return bless { %args }, $class; }
    sub build {
        my ($self, $error, $context) = @_;
        push @{ $self->{calls} }, [$error, $context];
        return $self->{payload};
    }
}
package Fake::DeliveryQueue {
    sub new { my ($class, %args) = @_; return bless { %args }, $class; }
    sub push { my ($self, $payload) = @_; push @{ $self->{pushed} }, $payload; }
}
package Fake::ExplodingEventBuilder {
    sub new { return bless {}, shift }
    sub build { die "event builder exploded\n" }
}
package Fake::ExplodingDeliveryQueue {
    sub new { return bless {}, shift }
    sub push { die "queue exploded\n" }
}

subtest 'builds and enqueues a payload when reporting is enabled' => sub {
    my $configuration = enabled_configuration();
    my $built_payload = { exception_class => 'RuntimeError' };
    my $event_builder = Fake::EventBuilder->new(calls => [], payload => $built_payload);
    my $delivery_queue = Fake::DeliveryQueue->new(pushed => []);

    my $reporter = ForgeOps::Tracker::Reporter->new($configuration, $event_builder, $delivery_queue);
    my $error = "boom\n";
    my $context = { a => 1 };

    $reporter->report($error, $context);

    is_deeply($event_builder->{calls}, [[$error, $context]]);
    is_deeply($delivery_queue->{pushed}, [$built_payload]);
};

subtest 'does nothing when reporting is disabled' => sub {
    my $configuration = enabled_configuration();
    $configuration->{environment} = 'development'; # not in enabled_environments
    my $event_builder = Fake::EventBuilder->new(calls => [], payload => {});
    my $delivery_queue = Fake::DeliveryQueue->new(pushed => []);

    ForgeOps::Tracker::Reporter->new($configuration, $event_builder, $delivery_queue)->report("boom\n");

    is(scalar(@{ $delivery_queue->{pushed} }), 0);
};

subtest 'never dies even if building the event fails' => sub {
    my $configuration = enabled_configuration();
    my $event_builder = Fake::ExplodingEventBuilder->new;
    my $delivery_queue = Fake::DeliveryQueue->new(pushed => []);

    eval {
        ForgeOps::Tracker::Reporter->new($configuration, $event_builder, $delivery_queue)->report("boom\n");
    };
    ok(!$@, 'report must not die') or diag $@;
};

subtest 'never dies even if enqueueing fails' => sub {
    my $configuration = enabled_configuration();
    my $event_builder = Fake::EventBuilder->new(calls => [], payload => {});
    my $delivery_queue = Fake::ExplodingDeliveryQueue->new;

    eval {
        ForgeOps::Tracker::Reporter->new($configuration, $event_builder, $delivery_queue)->report("boom\n");
    };
    ok(!$@, 'report must not die') or diag $@;
};

done_testing;
