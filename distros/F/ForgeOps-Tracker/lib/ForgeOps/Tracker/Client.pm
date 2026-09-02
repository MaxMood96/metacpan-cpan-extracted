package ForgeOps::Tracker::Client;

use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP qw(encode_json);

# Delivers one payload over HTTP. Every failure mode -- DNS, connection, timeout, a non-2xx
# response -- is caught here and turned into a false return rather than a thrown exception, since
# a broken or unreachable tracker must never be able to break the host app. Uses HTTP::Tiny and
# JSON::PP, both core since Perl 5.14 -- same reasoning as every other SDK in this repo (see e.g.
# sdks/node/src/client.js): this has to work in any host app without adding a dependency of its
# own for something as simple as one POST request.
sub new {
    my ($class, $configuration) = @_;
    return bless {
        configuration => $configuration,
        http          => HTTP::Tiny->new(timeout => $configuration->{timeout}),
    }, $class;
}

sub deliver {
    my ($self, $payload) = @_;
    my $config = $self->{configuration};

    my $uri = $config->ingestion_uri;
    my $api_key = $config->api_key;
    return 0 unless $uri && defined $api_key;

    my $response = eval {
        $self->{http}->post(
            $uri,
            {
                headers => {
                    'Authorization' => "Bearer $api_key",
                    'Content-Type'  => 'application/json',
                },
                content => encode_json($payload),
            },
        );
    };

    if (!$response) {
        $config->log("[forge-ops-tracker] delivery failed: $@") if $@;
        return 0;
    }

    unless ($response->{success}) {
        $config->log(
            "[forge-ops-tracker] delivery failed: $response->{status} $response->{reason}"
        );
        return 0;
    }

    return 1;
}

1;
