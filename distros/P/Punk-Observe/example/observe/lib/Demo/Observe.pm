package Demo::Observe;

use strict;
use warnings;
use Punk;
use Punk::Plugin::Observe;
use Punk::Plugin::Queue;
use Punk::Observe::Store ();
use Demo::DB ();

our $VERSION = '0.01';

session secret => 'demo-only-not-a-secret', samesite => 'Lax';
csrf;

config 'config/punk.yml';

plugin 'Queue' => {
    dsn => 'dbi:SQLite:dbname=' . (($ENV{DEMO_STORE} || 'var/store')
                                   . '/queue.db'),
    auto_migrate => 1,
};

plugin 'Observe' => {
    prefix => '/observe',
    guard  => \&_demo_guard,
    store  => $ENV{DEMO_STORE} || 'var/store',
    ingest => {
        prefix => '/v1',
        # keys => 'etc/keys',   # uncomment to require a bearer token
    },

    limits => {
        series     => 100_000,
        attributes => [ qw(service.name severity http.route
                           deployment.environment) ],
    },
    health_allow => ['127.0.0.1'],

    # The demo writes something over a gigabyte an hour, so the budget is
    # what actually decides how much history there is to look at - the 48h
    # window never gets a chance to. Raised to 10G to leave room for a real
    # amount of data to test against.
    retain => { keep => '48h', bytes => '10G' },
};

get '/' => sub {
    my ($c) = @_;
    $c->text("Punk::Observe demo receiver.\n\n"
           . "  POST /v1/traces    OTLP/protobuf or OTLP/JSON\n"
           . "  POST /v1/metrics\n"
           . "  POST /v1/logs\n\n"
           . "  GET  /observe          the UI (guarded)\n"
           . "  GET  /observe/logs     search, and click a line\n"
           . "  GET  /observe/traces   the slowest, and one assembled\n"
           . "  GET  /observe/map      the service graph\n"
           . "  GET  /observe/explore  one box over every signal\n"
           . "  GET  /observe/alerts   two rules, from the demo's database\n");
};

sub _demo_guard {
    my ($c) = @_;
    return;
}

1;
