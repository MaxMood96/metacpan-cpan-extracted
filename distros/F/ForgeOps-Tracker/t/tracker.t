use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/..";
use ForgeOps::Tracker;
use t::lib::EchoServer;

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

my $server = t::lib::EchoServer->start;

subtest 'init configures and returns the configuration' => sub {
    ForgeOps::Tracker::_reset_for_testing();
    my $config = ForgeOps::Tracker::init(
        dsn     => 'https://key@tracker.example.com/api/v1/events',
        release => 'abc123',
    );

    is($config->{dsn}, 'https://key@tracker.example.com/api/v1/events');
    is($config->{release}, 'abc123');
};

subtest 'init dies on an unknown configuration property' => sub {
    ForgeOps::Tracker::_reset_for_testing();

    eval { ForgeOps::Tracker::init(not_a_real_setting => 1) };
    like($@, qr/no property/);
};

subtest 'report delivers through the full stack' => sub {
    ForgeOps::Tracker::_reset_for_testing();
    ForgeOps::Tracker::init(
        dsn                  => 'http://key@127.0.0.1:' . $server->{port} . '/api/v1/events',
        enabled_environments => { production => 1 },
        environment          => 'production',
    );

    eval { die "boom\n" };
    ForgeOps::Tracker::report($@);

    ok(wait_until(sub { scalar(@{ $server->requests }) >= 1 }));
    my $requests = $server->requests;
    is($requests->[-1]{headers}{AUTHORIZATION}, 'Bearer key');
};

END { $server->stop if $server }

done_testing;
