use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Plack::Test;
use HTTP::Request::Common qw(GET);
use ForgeOps::Tracker;

my @reported;
local *ForgeOps::Tracker::report = sub { push @reported, [@_]; };

package TestApp {
    use Dancer2;
    use ForgeOps::Tracker::Integrations::Dancer2;

    set apphandler => 'PSGI';
    set startup_info => 0;

    get '/boom' => sub { die "route exploded\n"; };
    get '/fine' => sub { return 'ok'; };
}

my $app = TestApp->to_app;

test_psgi $app, sub {
    my $cb = shift;

    subtest 'reports an exception thrown from a route via on_route_exception' => sub {
        @reported = ();
        my $res = $cb->(GET '/boom');

        is($res->code, 500, "Dancer2's own error handling still renders a 500");
        is(scalar(@reported), 1);
        like($reported[0][0], qr/route exploded/);
        is($reported[0][1]{path}, '/boom');
        is($reported[0][1]{method}, 'GET');
    };

    subtest 'does not report a route that completes normally' => sub {
        @reported = ();
        my $res = $cb->(GET '/fine');

        is($res->code, 200);
        is($res->content, 'ok');
        is(scalar(@reported), 0);
    };
};

done_testing;
