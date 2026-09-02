package ForgeOps::Tracker;

use strict;
use warnings;
use ForgeOps::Tracker::Client;
use ForgeOps::Tracker::Configuration;
use ForgeOps::Tracker::DeliveryQueue;
use ForgeOps::Tracker::EventBuilder;
use ForgeOps::Tracker::Reporter;

our $VERSION = '0.1.0';

my $configuration;
my $reporter;

sub _configuration {
    $configuration ||= ForgeOps::Tracker::Configuration->new;
    return $configuration;
}

sub _reporter {
    unless ($reporter) {
        my $config = _configuration();
        my $client = ForgeOps::Tracker::Client->new($config);
        my $delivery_queue = ForgeOps::Tracker::DeliveryQueue->new($config, $client);
        $reporter = ForgeOps::Tracker::Reporter->new($config, ForgeOps::Tracker::EventBuilder->new($config), $delivery_queue);
    }
    return $reporter;
}

# init(%overrides) -- configure the client. Call once at startup, e.g.:
#
#   ForgeOps::Tracker::init(dsn => 'https://<api_key>@your-forgeops-host/api/v1/events');
#
# Any Configuration field can be overridden by name.
sub init {
    my (%overrides) = @_;
    my $config = _configuration();

    for my $key (keys %overrides) {
        die "Configuration has no property '$key'" unless exists $config->{$key};
        $config->{$key} = $overrides{$key};
    }

    return $config;
}

# report($error, \%context) -- report an exception you've already caught, e.g.:
#
#   eval { risky_operation() };
#   if ($@) {
#       ForgeOps::Tracker::report($@, { order_id => $order->id });
#   }
sub report {
    my ($error, $context) = @_;
    _reporter()->report($error, $context);
    return;
}

# @internal not part of the public API -- resets module state between test cases
sub _reset_for_testing {
    $configuration = undef;
    $reporter = undef;
    return;
}

1;

__END__

=head1 NAME

ForgeOps::Tracker - error reporting client for a self-hosted ForgeOps instance

=head1 SYNOPSIS

    use ForgeOps::Tracker;

    ForgeOps::Tracker::init(
        dsn         => 'https://<api_key>@your-forgeops-host/api/v1/events',
        environment => 'production',
    );

    eval { risky_operation() };
    if ($@) {
        ForgeOps::Tracker::report($@, { order_id => $order->id });
    }

See L<sdks/perl/README.md|../README.md> for PSGI/Plack and Dancer2 integrations, the delivery
model, and PII scrubbing.

=cut
