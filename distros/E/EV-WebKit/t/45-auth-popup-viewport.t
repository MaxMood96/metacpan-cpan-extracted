use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use IO::Socket::INET;
use EV; use EV::WebKit;

# on_authenticate, window.open, resize and zoom.

my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0,
                                Listen => 5, ReuseAddr => 1)
    or plan skip_all => "cannot bind a test server socket: $!";
my $port = $srv->sockport;
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
        delete $conns{$c};
        my ($path) = $buf =~ m{^\S+\s+(\S+)};
        $path //= '/';
        my ($code, $extra, $title) = (200, '', 'POPUP');
        if ($path =~ m{/secret}) {
            if ($buf =~ /Authorization:\s*Basic\s+(\S+)/i) { $title = 'AUTHED' }
            else { ($code, $extra, $title) = (401, "WWW-Authenticate: Basic realm=\"probe\"\r\n", 'DENIED') }
        }
        my $body = "<html><head><title>$title</title></head><body>b</body></html>";
        $c->blocking(1);
        print $c "HTTP/1.1 $code X\r\nContent-Type: text/html\r\n$extra"
               . 'Content-Length: ' . length($body) . "\r\nConnection: close\r\n\r\n$body";
        $c->flush;
        close $c;
    });
    $conns{$c} = $rw;
});

# --- on_authenticate --------------------------------------------------------
# Nothing answered a challenge before: WebKit simply waited, so a 401 resolved
# 'timeout' after the full instance timeout with status undef -- a private site
# was indistinguishable from an unreachable one.
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 8);
    my ($err, $secs);
    my $t0 = EV::time;
    $b->go("http://127.0.0.1:$port/secret", sub { $err = $_[1]; $secs = EV::time - $t0; EV::break });
    TWK::run_with_timeout(30);
    ok(defined $err, 'with no handler a challenge fails rather than hanging');
    like($err // '', qr/authentication/i, '...with a message that names authentication as the cause');
    cmp_ok($secs // 99, '<', 5, '...promptly, not after the instance timeout');
    $b->quit;
}
{
    my @info;
    my $b = EV::WebKit->new(window => [300,200], timeout => 10,
        on_authenticate => sub {
            my ($a) = @_;
            push @info, { host => $a->host, port => $a->port, realm => $a->realm,
                          scheme => $a->scheme, proxy => $a->for_proxy, retry => $a->is_retry };
            $a->login('u', 'p');
        });
    my ($err, $title, $status);
    $b->go("http://127.0.0.1:$port/secret", sub {
        $err = $_[1]; $title = $b->title; $status = $b->status; EV::break });
    TWK::run_with_timeout(30);
    is($err, undef, 'a handler that supplies credentials lets the load through') or diag $err;
    is($title, 'AUTHED', '...and the server accepted them');
    is($status, 200, '...reporting a 200, not the 401');
    is(scalar @info, 1, 'the handler ran once');
    is($info[0]{host},   '127.0.0.1', 'host is reported');
    is($info[0]{port},   $port,       'port is reported');
    is($info[0]{realm},  'probe',     'realm is reported');
is($info[0]{scheme}, 'http-basic','scheme is reported');
    is($info[0]{proxy},  0,           'for_proxy is false for an origin challenge');
    is($info[0]{retry},  0,           'is_retry is false on the first ask');
    $b->quit;
}
{
    # credentials in the URI are WebKit's own business and must not reach us
    my $fired = 0;
    my $b = EV::WebKit->new(window => [300,200], timeout => 10,
                            on_authenticate => sub { $fired++; $_[0]->cancel });
    my ($err, $title);
    $b->go("http://u:p\@127.0.0.1:$port/secret", sub { $err = $_[1]; $title = $b->title; EV::break });
    TWK::run_with_timeout(30);
    is($err, undef, 'credentials in the URI still work') or diag $err;
    is($title, 'AUTHED', '...reaching the protected page');
    is($fired, 0, '...without the handler being consulted');
    $b->quit;
}
# Fail-closed, and the three unanswered routes each name themselves. Without
# the cancel these still resolve -- with 'timeout', after the full instance
# timeout -- so the elapsed time is what actually pins "failed closed".
for my $case ([die => sub { die "handler exploded\n" }, qr/handler died/],
              [undecided => sub { return },             qr/answered nothing/],
              [cancel => sub { $_[0]->cancel },          qr/handler cancelled it/]) {
    my ($name, $handler, $want) = @$case;
    my $b = EV::WebKit->new(window => [300,200], timeout => 10, on_authenticate => $handler);
    my ($err, $secs);
    my $t0 = EV::time;
    $b->go("http://127.0.0.1:$port/secret", sub { $err = $_[1]; $secs = EV::time - $t0; EV::break });
    TWK::run_with_timeout(30);
    ok(defined $err, "on_authenticate that $name: the navigation fails");
    cmp_ok($secs // 99, '<', 5, "on_authenticate that $name: ...promptly, not at the instance timeout");
    like($err // '', $want, "on_authenticate that $name: ...saying which route it took");
    $b->quit;
}

# --- window.open ------------------------------------------------------------
# window.open is NOT a policy decision in WebKitGTK: decide-policy never fires
# for it, so the popups option had to be honoured on 'create' as well. Before
# that it did nothing at all -- no navigation, no error, no event.
for my $case ([follow => 'POPUP'], [block => undef]) {
    my ($mode, $want) = @$case;
    my $b = EV::WebKit->new(window => [400,300], timeout => 15, popups => $mode);
    # window.open's return value is recorded in a page global, so the 'block'
    # case can assert the call was actually MADE -- otherwise "the title is not
    # POPUP" is equally true of a page where the click never happened.
    $b->load_html('<html><body><button id=x onclick=\'window.opened = window.open('
                . '"http://127.0.0.1:' . $port . '/pop","_blank") ? "won" : "null"\'>go</button></body></html>', sub {
        $b->find('#x', sub {
            $_[0]->click(sub { my $t; $t = EV::timer(2.5, 0, sub { undef $t; EV::break }) });
        });
    });
    TWK::run_with_timeout(30);
    if (defined $want) {
        is($b->title, $want, "popups => $mode follows window.open in this view");
        like($b->uri // '', qr{/pop$}, "...landing on the requested uri");
    }
    else {
        my $opened;
        $b->script('return String(window.opened);', sub { $opened = $_[0]; EV::break });
        TWK::run_with_timeout(20);
        is($opened, 'null', "popups => $mode: window.open was called and returned null");
        isnt($b->title // '', 'POPUP', "popups => $mode drops window.open");
    }
    $b->quit;
}

# --- resize / zoom ----------------------------------------------------------
{
    my $b = EV::WebKit->new(window => [800,600], timeout => 15);
    my (%g, @steps);
    my $nxt; $nxt = sub { my $s = shift @steps or return EV::break; $s->() };
    @steps = (
        sub { $b->script('return [innerWidth, innerHeight];', sub { $g{before} = $_[0]; $nxt->() }) },
        sub { $b->resize(375, 500, sub { ($g{size}, $g{err}) = @_; $nxt->() }) },
        sub { $b->script('return [innerWidth, innerHeight];', sub { $g{after} = $_[0]; $nxt->() }) },
    );
    $b->load_html('<html><body>x</body></html>', sub { $nxt->() });
    TWK::run_with_timeout(40);

    is($g{err}, undef, 'resize succeeds') or diag $g{err};
    isnt(join('x', @{ $g{before} || [] }), '375x500', 'precondition: the window did not start at the target size');
    is_deeply($g{after}, [375, 500], 'the page really sees the new viewport');
    is($g{size}{width},  375, 'resize reports the width the page has');
    is($g{size}{height}, 500, 'resize reports the height the page has');

    is($b->zoom, 1, 'zoom starts at 1');
    is($b->zoom(2), $b, 'setting zoom returns the browser');
    is($b->zoom, 2, 'zoom reads back what was set');
    my $dpr;
    $b->script('return window.devicePixelRatio;', sub { $dpr = $_[0]; EV::break });
    TWK::run_with_timeout(20);
    cmp_ok($dpr, '>', 1, 'the page sees the zoom');
    ok(!eval { $b->zoom(0); 1 },  'a zero zoom croaks');
    ok(!eval { $b->zoom(-1); 1 }, 'a negative zoom croaks');
    ok(!eval { $b->resize(0, 100, sub {}); 1 }, 'a zero width croaks');
    ok(!eval { $b->resize(100, 'wide', sub {}); 1 }, 'a non-numeric height croaks');
    $b->quit;
    is($b->zoom, undef, 'zoom after quit reads undef');
}

# resize with chrome => 1: the header bar and GTK4's decorations take their own
# share, so the viewport is NOT the size requested -- which is the whole reason
# resize reads the number back instead of echoing the request. Without a chromed
# case, `$cb->({width => $w, height => $h})` passes every other resize test.
{
    my $b = EV::WebKit->new(window => [800,600], timeout => 15, chrome => 1);
    my ($size, $err, $seen);
    $b->load_html('<html><body>x</body></html>', sub {
        $b->resize(400, 320, sub {
            ($size, $err) = @_;
            $b->script('return [innerWidth, innerHeight];', sub { $seen = $_[0]; EV::break });
        });
    });
    TWK::run_with_timeout(40);
    is($err, undef, 'resize succeeds with chrome') or diag $err;
    is_deeply($size, { width => $seen->[0], height => $seen->[1] },
              'resize reports the viewport the page has, not the size requested')
        or diag explain { reported => $size, page => $seen };
    cmp_ok($size->{height}, '<', 320, '...which with a header bar is smaller than the request')
        if $size;
    $b->quit;
}

# login()'s own validation, driven synchronously through a live challenge
{
    my @errs;
    my $b = EV::WebKit->new(window => [300,200], timeout => 10, on_authenticate => sub {
        my ($a) = @_;
        push @errs, [ 'no args',      (eval { $a->login;             1 } ? undef : "$@") ];
        push @errs, [ 'ref user',     (eval { $a->login([], 'p');    1 } ? undef : "$@") ];
        push @errs, [ 'bad persist',  (eval { $a->login('u','p', persist => 'forever'); 1 } ? undef : "$@") ];
        push @errs, [ 'unknown opt',  (eval { $a->login('u','p', bogus => 1);           1 } ? undef : "$@") ];
        push @errs, [ 'persist none', (eval { $a->login('u','p', persist => 'none');    1 } ? undef : "$@") ];
        1;
    });
    my ($err, $title);
    $b->go("http://127.0.0.1:$port/secret", sub { $err = $_[1]; $title = $b->title; EV::break });
    TWK::run_with_timeout(30);
    my %e = map { $_->[0] => $_->[1] } @errs;
    is(scalar @errs, 5, 'the validation handler ran') or diag explain \@errs;
    like($e{'no args'}     // '', qr/username and password are required/, 'login with no arguments croaks');
    like($e{'ref user'}    // '', qr/username and password are required/, 'login with a reference croaks');
    like($e{'bad persist'} // '', qr/persist must be/,                    'an unknown persist value croaks');
    like($e{'unknown opt'} // '', qr/unknown option/,                     'an unknown login option croaks');
    is($e{'persist none'}, undef, "persist => 'none' is accepted");
    is($title, 'AUTHED', '...and the accepted call really authenticated');
    $b->quit;
}

# login was the last option-taking public method without a pairs-up check: an
# odd list warned "Odd number of elements in hash assignment" from inside
# WebKit.pm and then silently defaulted persist, and the 'permanent' spelling
# warned from in there BEFORE croaking about the unknown option.
{
    my $auth = bless { r => undef, done => 0 }, 'EV::WebKit::Auth';   # 'r' is the field _new uses
    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
    ok(!eval { $auth->login('u', 'p', 'persist'); 1 }, 'login croaks on an odd option list');
    like($@, qr/name => value pairs/, '...rather than defaulting persist silently');
    ok(!eval { $auth->login('u', 'p', 'permanent'); 1 }, 'login croaks on a bare option value too');
    like($@, qr/name => value pairs/, '...with the same message');
    is(scalar(@w), 0, '...and neither warned from inside the module');
    ok(!eval { $auth->login('u', 'p', persist => 'forever'); 1 }, 'a bad persist value still croaks');
    like($@, qr/persist must be/, '...saying the allowed values');
}

# window.open is not a WINDOW request WebKitGTK asks about, so no
# new-window-action ever arrives for it -- but under the default
# popups => 'follow' the popup is re-issued in this view as an ordinary
# navigation, which on_policy DOES see and can refuse. The POD used to say it
# "never reaches on_policy at all", which talks a user out of selective popup
# filtering entirely.
#
# The open must come from a real user gesture: WebKit's popup blocker drops a
# window.open called from an inline script, and then nothing reaches policy at
# all (measured -- that is why this clicks a button rather than running script).
{
    our @POL;
    my $pb = EV::WebKit->new(window => [300,200], ephemeral => 1, timeout => 10,
        on_policy => sub {
            my ($p) = @_;
            push @POL, ($p->{type} // '?') . '(' . ($p->{uri} // '?') . ')';
            $p->allow;
        });
    $pb->mock_scheme('pw', sub {
        my $u = shift;
        return ('<html><body>TARGET</body></html>', 'text/html') if $u =~ m{target};
        return ('<html><body><button id=go onclick="window.open(\'pw://host/target\')">go</button>'
              . '</body></html>', 'text/html');
    });
    my $el;
    $pb->go('pw://host/main', sub { $pb->find('#go', sub { $el = $_[0]; EV::break }) });
    TWK::run_with_timeout(30);
    ok($el, 'premise: the opener page loaded and its button was found');

  SKIP: {
        skip 'no button', 2 unless $el;
        @POL = ();
        $el->click(sub { EV::break });
        TWK::run_with_timeout(20);
        { my $settle = EV::timer(2.0, 0, sub { EV::break }); EV::run }
        my $seen = join ' ', @POL;
        like($seen, qr{navigation-action\(pw://host/target\)},
             'a window.open popup reaches on_policy as a navigation-action')
            or diag("policy events: $seen");
        unlike($seen, qr{new-window-action\(pw://host/target\)},
               '...and never as a new-window-action, which is what "not a policy decision" meant');
    }
    $pb->quit;
}

done_testing;
