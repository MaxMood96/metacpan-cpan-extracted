use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use ForgeOps::Tracker::Configuration;

sub new_configuration {
    my $config = ForgeOps::Tracker::Configuration->new;
    $config->{dsn} = undef;
    $config->{enabled_environments} = { production => 1, staging => 1 };
    $config->{environment} = 'production';
    return $config;
}

subtest 'extracts api_key and a credential-free ingestion_uri from the DSN' => sub {
    my $config = new_configuration();
    $config->{dsn} = 'https://secret-key@tracker.example.com/api/v1/events';

    is($config->api_key, 'secret-key');
    is($config->ingestion_uri, 'https://tracker.example.com/api/v1/events');
};

subtest 'percent-decodes the api_key' => sub {
    my $config = new_configuration();
    $config->{dsn} = 'https://secret%2Bkey@tracker.example.com/api/v1/events';

    is($config->api_key, 'secret+key');
};

subtest 'returns undef for both when there is no DSN' => sub {
    my $config = new_configuration();
    $config->{dsn} = undef;

    is($config->api_key, undef);
    is($config->ingestion_uri, undef);
};

subtest 'returns undef for both when the DSN is malformed' => sub {
    my $config = new_configuration();
    $config->{dsn} = 'not a uri :: at all';

    is($config->api_key, undef);
    is($config->ingestion_uri, undef);
};

subtest 'is_enabled is true with a valid DSN in an enabled environment' => sub {
    my $config = new_configuration();
    $config->{dsn} = 'https://key@tracker.example.com/api/v1/events';
    $config->{environment} = 'production';

    is($config->is_enabled, 1);
};

subtest 'is_enabled is false with no DSN configured' => sub {
    my $config = new_configuration();
    $config->{dsn} = undef;

    is($config->is_enabled, 0);
};

subtest 'is_enabled is false when the DSN has no api key' => sub {
    my $config = new_configuration();
    $config->{dsn} = 'https://tracker.example.com/api/v1/events';

    is($config->is_enabled, 0);
};

subtest 'is_enabled is false outside the configured enabled_environments' => sub {
    my $config = new_configuration();
    $config->{dsn} = 'https://key@tracker.example.com/api/v1/events';
    $config->{environment} = 'development';

    is($config->is_enabled, 0);
};

done_testing;
