use strict;
use warnings;
use Test::More;
use POSIX ":sys_wait_h";
use IO::Socket::INET;

# Integration tests for Hypersonic::UA using real HTTP requests
# Note: UA currently returns hash refs, not Response objects


# Helper to get status/body from response (hash or object)
sub res_status { my $r = shift; ref($r) eq 'HASH' ? $r->{status} : $r->status }
sub res_body   { my $r = shift; ref($r) eq 'HASH' ? $r->{body}   : $r->body }

# Start a test server
my $PORT = 31000 + ($$ % 1000);
my $server_pid;

sub start_test_server {
    $server_pid = fork();
    die "Fork failed" unless defined $server_pid;

    if ($server_pid == 0) {
        require Hypersonic;
        my $server = Hypersonic->new(cache_dir => "_test_ua_server_$$");

        # Simple GET endpoints
        $server->get('/hello' => sub { 'Hello, World!' });
        $server->get('/json' => sub { '{"status":"ok","message":"Hello"}' });

        # POST endpoint
        $server->post('/post' => sub { 'POST received' });

        # PUT endpoint
        $server->put('/put' => sub { 'PUT received' });

        # DELETE endpoint
        $server->del('/delete' => sub { 'DELETE received' });

        $server->compile();
        $server->run(port => $PORT, workers => 1);
        exit(0);
    }

    # Wait for server to start
    for (1..50) {
        my $sock = IO::Socket::INET->new(
            PeerAddr => '127.0.0.1',
            PeerPort => $PORT,
            Proto    => 'tcp',
            Timeout  => 0.1,
        );
        if ($sock) {
            close($sock);
            return 1;
        }
        select(undef, undef, undef, 0.1);
    }
    die "Server failed to start";
}

sub stop_test_server {
    if ($server_pid) {
        kill('TERM', $server_pid);
        waitpid($server_pid, 0);
    }
    system("rm -rf _test_ua_server_*");
}

END { stop_test_server() }

# Start test server
start_test_server();
pass('Test server started');

# Compile UA
use_ok('Hypersonic::UA');

# Compile with async support for callback tests
eval { Hypersonic::UA->compile(cache_dir => "_test_ua_client_$$", async => 1) };
ok(!$@, 'UA compiled successfully') or diag $@;

# Create UA instance
my $ua = Hypersonic::UA->new();
ok($ua, 'Created UA instance');

subtest 'GET /hello' => sub {
    my $res = $ua->get("http://127.0.0.1:$PORT/hello");
    ok($res, 'Got response');
    is(res_status($res), 200, 'Status 200');
    is(res_body($res), 'Hello, World!', 'Body matches');
};

subtest 'GET /json' => sub {
    my $res = $ua->get("http://127.0.0.1:$PORT/json");
    ok($res, 'Got response');
    is(res_status($res), 200, 'Status 200');
    like(res_body($res), qr/"status":"ok"/, 'JSON body');
};

subtest 'POST request' => sub {
    my $res = $ua->post("http://127.0.0.1:$PORT/post", '');
    ok($res, 'Got response');
    is(res_status($res), 200, 'Status 200');
    is(res_body($res), 'POST received', 'POST body');
};

subtest 'PUT request' => sub {
    my $res = $ua->put("http://127.0.0.1:$PORT/put", '');
    ok($res, 'Got response');
    is(res_status($res), 200, 'Status 200');
    is(res_body($res), 'PUT received', 'PUT body');
};

subtest 'DELETE request' => sub {
    my $res = $ua->delete("http://127.0.0.1:$PORT/delete");
    ok($res, 'Got response');
    is(res_status($res), 200, 'Status 200');
    is(res_body($res), 'DELETE received', 'DELETE body');
};

subtest 'Multiple sequential requests' => sub {
    for my $i (1..5) {
        my $res = $ua->get("http://127.0.0.1:$PORT/hello");
        is(res_status($res), 200, "Request $i status 200");
    }
};

# Cleanup
system("rm -rf _test_ua_client_*");

done_testing();
