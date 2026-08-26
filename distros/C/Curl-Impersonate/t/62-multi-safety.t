use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Curl::Impersonate;

# local echo origin (one fixed response per connection)
socket(my $srv, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
setsockopt($srv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($srv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
listen($srv, 5) or die "listen: $!";
my $port = (sockaddr_in(getsockname($srv)))[0];
my $pid = fork // die "fork: $!";
if (!$pid) {
    for (1..8) {
        accept(my $c, $srv) or last;
        my $req = ''; while (index($req, "\r\n\r\n") < 0) { sysread($c, my $b, 4096) or last; $req .= $b }
        syswrite($c, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nhi");
        close $c;
    }
    exit 0;
}
close $srv;

# 1. a callback that undef's the multi (dropping its last Perl ref) mid-drive must
# not crash: the drive holds its own ref to the multi's blessed guts until it
# returns, so DESTROY (curl_multi_cleanup + reap) defers to the safe point.
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    my $got;
    $m->add($h, { url => "http://127.0.0.1:$port/" }, sub { $got = $_[0]{status}; undef $m });
    $m->perform_blocking;
    is($got, 200, 'callback that undef-ed the multi still ran and saw the result');
    ok(1, 'survived undef-ing the multi from inside its own callback (no UAF/crash)');
}

# 2. one handle, one in-flight request: a sync request (or a second add) on a
# handle already queued on a multi croaks instead of corrupting memory.
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    $m->add($h, { url => "http://127.0.0.1:$port/" }, sub {});
    eval { $h->get("http://127.0.0.1:$port/") };
    like($@, qr/in use by a Multi/, 'a sync request on a handle in a Multi croaks');
    eval { $m->add($h, { url => "http://127.0.0.1:$port/" }, sub {}) };
    like($@, qr/already in use/, 'a second Multi add on the same handle croaks');
    $m->perform_blocking;   # drain the one real request
}

# 3. a request with no on_done callback completes silently (the guard skips the
# completion call rather than warning "Not a CODE reference" on every finish).
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
    $m->add($h, { url => "http://127.0.0.1:$port/" }, undef);
    $m->perform_blocking;
    is_deeply(\@w, [], 'a request with an undef callback completes without warning');
}

# 4. curl fires the timer/socket callback synchronously INSIDE curl_multi_add_handle
# and curl_multi_remove_handle; a callback that undef's the multi there must not
# free it mid-call -- the same guts-guard as the drive methods (else UAF / double-
# free). These add-but-don't-drive, so they make no upstream connection.
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    $m->set_timer_callback(sub { undef $m });   # drops the last ref when curl arms the timer during add
    $m->add($h, { url => "http://127.0.0.1:$port/" }, sub {});
    ok(1, 'add with a timer-callback that undef-ed the multi survives (guts guarded, no UAF)');
}
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    $m->add($h, { url => "http://127.0.0.1:$port/" }, sub {});
    $m->set_timer_callback(sub { undef $m });
    $m->remove($h);
    ok(1, 'remove with a timer-callback that undef-ed the multi survives (no double-free)');
}

# 6. the idiomatic crawler: a completion callback re-adds the next request on the
# same handle; a single perform_blocking must drive ALL of them, not strand after
# the first (the drive loop must keep going while requests remain tracked).
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    my @urls = map { "http://127.0.0.1:$port/p$_" } 1 .. 3;
    my @got;
    my $next; $next = sub {
        my ($res, $err) = @_;
        push @got, $res->{status} if $res;
        $m->add($h, { url => shift @urls }, $next) if @urls;
    };
    $m->add($h, { url => shift @urls }, $next);
    $m->perform_blocking;
    is(scalar @got, 3, 'crawler: all 3 callback-re-added requests were driven (not stranded after #1)');
}

# 7. re-entering perform_blocking from a completion callback must RETURN, not hang:
# the completing request is unlinked from m->reqs before its callback runs, so the
# inner drive does not see it (else `while (still || m->reqs)` spins at 100% CPU).
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    my $reentered = 0;
    local $SIG{ALRM} = sub { die "re-entrant perform_blocking hung\n" };
    alarm 20;
    my $ok = eval {
        $m->add($h, { url => "http://127.0.0.1:$port/re" }, sub {
            $reentered = 1;
            $m->perform_blocking;   # re-enter: its own (finished) request must be gone from m->reqs
        });
        $m->perform_blocking;
        1;
    };
    alarm 0;
    ok($ok && !$@, 'perform_blocking re-entered from a completion callback returns (no 100% CPU hang)')
        or diag($@);
    ok($reentered, 'the completion callback ran');
}

kill 'TERM', $pid; waitpid($pid, 0);
done_testing;
