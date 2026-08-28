use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use IO::Socket::INET;
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window=>[300,200]);
$b->mock_scheme('mock', sub {
    my ($uri) = @_;
    my ($n) = $uri =~ m{mock://(\w+)};
    return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
});

ok(!$b->can_go_back,    'fresh: cannot go back');
ok(!$b->can_go_forward, 'fresh: cannot go forward');
is($b->stop, $b, 'stop is callable and returns self');

my %g;
$b->back(sub {                                # nothing to go back to -> error, not a hang
    $g{noback_err} = $_[1];
    $b->go('mock://one', sub {
        $b->go('mock://two', sub {
            $g{cgb_after_two} = $b->can_go_back;
            $g{cgf_after_two} = $b->can_go_forward;
            $b->back(sub {
                my (undef, $err) = @_;
                $g{back_err}       = $err;
                $g{uri_after_back} = $b->uri;
                $g{cgf_after_back} = $b->can_go_forward;
                $b->forward(sub {
                    $g{uri_after_forward} = $b->uri;
                    $b->reload(sub {
                        my (undef, $rerr) = @_;
                        $g{reload_err}       = $rerr;
                        $g{uri_after_reload} = $b->uri;
                        $b->forward(sub { $g{nofwd_err} = $_[1]; EV::break });
                    });
                });
            });
        });
    });
});
TWK::run_with_timeout(25);
is($g{noback_err}, 'cannot go back', 'back with empty history -> error');
ok($g{cgb_after_two},  'can_go_back after two navigations');
ok(!$g{cgf_after_two}, 'cannot go forward at newest entry');
is($g{back_err}, undef, 'back resolved without error');
is($g{uri_after_back}, 'mock://one', 'back landed on first page');
ok($g{cgf_after_back}, 'can_go_forward true after going back');
is($g{uri_after_forward}, 'mock://two', 'forward landed on second page');
is($g{reload_err}, undef, 'reload resolved without error');
is($g{uri_after_reload}, 'mock://two', 'reload stays on second page');
is($g{nofwd_err}, 'cannot go forward', 'forward at newest entry -> error');

# overlapping navigations: issuing a second go() before the first settles
# supersedes the first. Deterministic -- the supersede happens synchronously
# inside _start_nav (called from go(), before EV::run is ever entered here),
# not dependent on WebKit's own load timing.
my ($sup_result, $sup_err, $two_result, $two_err, $two_uri);
$b->go('mock://three', sub { ($sup_result, $sup_err) = @_ });
$b->go('mock://four', sub {
    ($two_result, $two_err) = @_;
    $two_uri = $b->uri;
    EV::break;
});
TWK::run_with_timeout(10);
is($sup_err, 'superseded', 'overlapping nav: superseded callback receives err eq superseded');
is($sup_result, undef, 'overlapping nav: superseded callback result is undef');
is($two_err, undef, 'overlapping nav: second (superseding) callback completes without error');
is($two_uri, 'mock://four', 'overlapping nav: second callback lands on the second uri');

# Same-document navigation, and the retry-after-timeout pattern.
#
# A fragment-only navigation loads nothing and emits no load-changed cycle at
# all (measured: plain -> #a and #a -> #b emit only notify::uri), so nothing can
# tell this module it happened and the pending runs out its timeout. That is the
# documented behaviour, and it is deliberate: resolving it would mean PREDICTING
# which navigations will not reload, and every such rule is falsifiable -- by the
# outgoing page touching its own hash mid-load, by pushState, by a web-process
# crash -- with each falsification reporting SUCCESS for a page that never
# loaded. An honest timeout is the better failure.
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 2);
    $b->mock_scheme('fg', sub { ('<html><head><title>F</title></head><body>x</body></html>', 'text/html') });
    my %g;
    $b->go('fg://p', sub {
        $g{plain} = $_[1];
        $b->go('fg://p#one', sub {
            $g{frag} = $_[1];
            $g{frag_uri} = $b->uri;
            # ...and the page-side spelling, which is not a guess, works
            $b->script('location.hash = "two"; return String(location.href);', sub {
                $g{scripted} = $_[0]; EV::break });
        });
    });
    TWK::run_with_timeout(30);
    is($g{plain}, undef, 'an ordinary navigation resolves') or diag $g{plain};
    is($g{frag}, 'timeout', 'a fragment-only navigation reports timeout, never a false success');
    is($g{frag_uri}, 'fg://p#one', '...though the uri really did move');
    is($g{scripted}, 'fg://p#two', 'the documented page-side spelling navigates the fragment');
    $b->quit;
}

# Retrying the SAME uri after a timeout must not be handed the abandoned load's
# cancellation as its own failure. The abandoned load stays in flight; the retry
# cancels it, and that cancellation's load-failed carries the retry's target
# exactly -- so the matching-uri exemption in the load-failed handler has to
# require that the retry has STARTED before it can own a failure. Nothing else
# in the suite navigates twice to one uri, so nothing else pins that term.
{
    my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0,
                                    Listen => 5, ReuseAddr => 1);
    SKIP: {
        skip 'cannot bind a test server socket', 3 unless $srv;
        my $port = $srv->sockport;
        my (%conns, @held);
        my $accept = EV::io($srv, EV::READ, sub {
            my $c = $srv->accept or return;
            $c->blocking(0);
            my $buf = '';
            my $rw; $rw = EV::io($c, EV::READ, sub {
                my $n = sysread($c, my $chunk, 4096);
                if (!defined $n) { return if $!{EAGAIN} || $!{EWOULDBLOCK}; delete $conns{$c}; return }
                return delete $conns{$c} unless $n;
                $buf .= $chunk;
                return unless $buf =~ /\r?\n\r?\n/;
                delete $conns{$c};
                push @held, $c;          # accepted, never answered
            });
            $conns{$c} = [$c, $rw];
        });

        my $b = EV::WebKit->new(window => [300,200], timeout => 2);
        my %g;
        my $url = "http://127.0.0.1:$port/same";
        $b->go($url, sub {
            $g{first} = $_[1];
            my $t0 = EV::time;
            $b->go($url, sub { $g{retry} = [ $_[1], EV::time - $t0 ]; EV::break });
        });
        TWK::run_with_timeout(30);

        is($g{first}, 'timeout', 'precondition: the first load stalled to its timeout');
        is($g{retry}[0], 'timeout', 'the retry gets its own outcome, not the abandoned load\'s cancellation')
            or diag "resolved '" . ($g{retry}[0] // 'ok') . "' after $g{retry}[1]s";
        cmp_ok($g{retry}[1], '>', 1, '...after waiting for it, rather than failing instantly');
        $b->quit;
        undef $accept; %conns = (); @held = ();
    }
}

# A page that moves its OWN url DURING the initial load -- an inline
# history.pushState / replaceState, an SPA router settling its route, a
# location.hash restoring an anchor -- used to make go() run out the FULL
# instance timeout and report 'timeout' for a page that had loaded perfectly.
#
# Cause: the view's uri changes between load-changed 'committed' and
# 'finished' with no new load-changed cycle at all, so _finished_is_stray's
# committed-uri gate compared the pending's captured uri against a uri that had
# legitimately moved on, judged the navigation's OWN 'finished' stray, and
# consumed it. Nothing else could then resolve the pending. Measured on all
# three spellings, at exactly the instance timeout.
#
# A real HTTP server, not mock_scheme: pushState must be able to move to a
# same-origin path, which needs a real origin.
{
    my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0,
                                    Listen => 10, ReuseAddr => 1);
  SKIP: {
        skip 'cannot bind a local test server', 8 unless $srv;
        my $port = $srv->sockport;
        my %body = (
            '/plain'   => '<html><body>plain</body></html>',
            '/push'    => '<html><body>p<script>history.pushState({},"","/moved-push")</script></body></html>',
            '/replace' => '<html><body>r<script>history.replaceState({},"","/moved-replace")</script></body></html>',
            '/hash'    => '<html><body>h<script>location.hash="sec"</script></body></html>',
        );
        my %conns;
        my $accept = EV::io($srv, EV::READ, sub {
            my $c = $srv->accept or return;
            $c->blocking(0);
            my $buf = '';
            my $rw; $rw = EV::io($c, EV::READ, sub {
                my $n = sysread($c, my $chunk, 4096);
                if (!defined $n) { return if $!{EAGAIN} || $!{EWOULDBLOCK}; delete $conns{$c}; return }
                return delete $conns{$c} unless $n;
                $buf .= $chunk;
                return unless $buf =~ /\r?\n\r?\n/;
                my ($path) = $buf =~ m{^GET (\S+)};
                my $b = $body{$path} // '<html><body>x</body></html>';
                syswrite $c, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n"
                           . 'Content-Length: ' . length($b) . "\r\nConnection: close\r\n\r\n$b";
                delete $conns{$c};
            });
            $conns{$c} = [$c, $rw];
        });

        my $sb = EV::WebKit->new(window => [300,200], ephemeral => 1, timeout => 6);
        for my $case (['/plain', qr{/plain\z}], ['/push', qr{/moved-push\z}],
                      ['/replace', qr{/moved-replace\z}], ['/hash', qr{\#sec\z}]) {
            my ($path, $want) = @$case;
            my ($ok, $err, $done) = (undef, undef, 0);
            my $t0 = EV::time;
            $sb->go("http://127.0.0.1:$port$path", sub { ($ok, $err) = @_; $done = 1; EV::break });
            my $wd = EV::timer(20, 0, sub { EV::break });
            EV::run; undef $wd;
            my $took = EV::time - $t0;
            ok($done && $ok && !$err, "go($path) resolves as a success")
                or diag("err=" . ($err // 'none') . " after ${took}s -- a same-document move "
                      . 'during the load must not make the load look stray');
            like($sb->uri // '', $want, "...and the uri is where the page moved to");
        }
        $sb->quit;
        undef $accept; %conns = ();
    }
}

done_testing;
