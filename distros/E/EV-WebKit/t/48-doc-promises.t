use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use IO::Socket::INET;
use File::Temp qw(tempdir);
use EV; use EV::WebKit;

# Promises the POD makes that nothing else in the suite exercises. Each block
# here was chosen because stubbing the method out entirely left the rest of the
# suite green.

my $dir = tempdir(CLEANUP => 1);

# --- is_loading / stop ------------------------------------------------------
# stop() is documented to abort the current load. Every other use of it in the
# suite runs against a browser that never navigated, where stop_loading is a
# no-op -- so `sub stop { $_[0] }` passed the whole suite.
{
    my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0,
                                    Listen => 5, ReuseAddr => 1);
    SKIP: {
        skip 'cannot bind a test server socket', 4 unless $srv;
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
                push @held, $c;   # headers and body both withheld: the load stays in flight
            });
            $conns{$c} = [$c, $rw];
        });

        my $b = EV::WebKit->new(window => [300,200], timeout => 20);
        my (%g, $settled);
        # No EV::break here: stop() resolves this callback, and breaking from it
        # would end the loop before the check below could run.
        $b->go("http://127.0.0.1:$port/held", sub { $g{err} = $_[1] // '(ok)'; $settled = 1 });
        # Poll for the nav to have SEEN ITS OWN 'started', rather than assuming
        # a fixed delay is enough. stop() before that leaves the cancel's
        # load-failed discarded by the stray gate (which requires the started
        # flag), so is_loading stays 1 and go() is never resolved -- the two
        # assertions below fail. Measured: started lands at 0.16-0.23s, but
        # under full-suite load a hard 1.2s still lost once in five runs of the
        # shipped tarball, i.e. a CPAN Testers FAIL. `$b->{pending}[4]` is the
        # started flag, the same precondition t/65-nav-overlap.t polls on.
        my $t1; $t1 = EV::timer(0.05, 0.05, sub {
            return unless ($b->{pending} || [])->[4];
            undef $t1;
            $g{during} = $b->is_loading;
            $b->stop;
            my $t2; $t2 = EV::timer(1.5, 0, sub { undef $t2; $g{after} = $b->is_loading; EV::break });
        });
        TWK::run_with_timeout(25);

        is($g{during}, 1, 'is_loading is true while a navigation is in flight');
        ok(defined $g{after}, 'precondition: the stop block ran') or diag 'the load settled before stop()';
        is($g{after}, 0, 'stop aborts the load: is_loading goes false');
        ok($settled, 'the navigation callback was resolved, not dropped')
            or diag 'stop() left go() hanging';
        $b->quit;
        undef $accept; %conns = (); @held = ();
    }
}

# --- show_devtools ----------------------------------------------------------
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 10);
    ok(!$b->{view}->get_settings->get('enable-developer-extras'), 'developer extras start off');
    my $ret = $b->show_devtools;
    ok($b->{view}->get_settings->get('enable-developer-extras'), 'show_devtools enables developer extras');
    is($ret, $b, 'show_devtools returns the browser');
    $b->quit;
    is($b->show_devtools, $b, 'show_devtools after quit is a no-op that still returns the browser');
}

# --- screenshot(transparent => 1) -------------------------------------------
{
    my $b = EV::WebKit->new(window => [200,150], timeout => 10);
    my ($clear, $opaque, $err, $err2);
    $b->load_html('<html><body style="background:transparent"><p>t</p></body></html>', sub {
        $b->screenshot({ bytes => 1, transparent => 1 }, sub {
            ($clear, $err) = @_;
            $b->screenshot({ bytes => 1 }, sub { ($opaque, $err2) = @_; EV::break });
        });
    });
    TWK::run_with_timeout(30);
    is($err,  undef, 'screenshot(transparent => 1) succeeds') or diag $err;
    is($err2, undef, 'and the opaque one too')                or diag $err2;
    is(substr($clear // '', 0, 8), "\x89PNG\r\n\x1a\n", '...returning PNG bytes');
    # The option maps to WebKit's 'transparent-background' snapshot flag. Mapping
    # it to 'none' unconditionally still yields a valid PNG, so compare the two
    # captures of the SAME page: they must differ.
    isnt($clear, $opaque, 'transparent => 1 produces a different image from the opaque capture');
    $b->quit;
}

# --- set_cookie secure/http_only round-trip ---------------------------------
# Both flags are documented on set_cookie and on what cookies() gives back. A
# set_cookie that accepted and discarded them passed every existing test.
{
    my $b = EV::WebKit->new(window => [200,150], timeout => 10, ephemeral => 1);
    my ($got, $err);
    $b->set_cookie({ name => 'flagged', value => 'v', domain => '127.0.0.1', path => '/',
                     secure => 1, http_only => 1 }, sub {
        my (undef, $e) = @_;
        return do { $err = $e; EV::break } if $e;
        $b->cookies('https://127.0.0.1/', sub { ($got, $err) = @_; EV::break });
    });
    TWK::run_with_timeout(20);
    is($err, undef, 'set_cookie with secure/http_only succeeds') or diag $err;
    my ($c) = grep { $_->{name} eq 'flagged' } @{ $got || [] };
    ok($c, 'the cookie comes back') or diag explain $got;
    is($c && $c->{secure},    1, 'secure survives the round trip');
    is($c && $c->{http_only}, 1, 'http_only survives the round trip');
    $b->quit;
}

# --- load_cookies honours a hand-written expires ----------------------------
# The observable difference between "restored with its remaining lifetime" and
# "restored as a session cookie" is not visible through cookies() -- which
# deliberately reports no expiry -- but it decides whether a cookie_jar keeps
# the cookie across a restart. RFC 6265: session cookies are never persisted.
{
    my $jar  = "$dir/expiring.sqlite";
    my $snap = "$dir/snap.json";
    my $when = time + 3600;
    open my $fh, '>', $snap or die "open $snap: $!";
    print $fh qq([{"name":"keeper","value":"v","domain":"127.0.0.1","path":"/","expires":$when},)
            . qq({"name":"sessiony","value":"v","domain":"127.0.0.1","path":"/"}]);
    close $fh;

    my ($loaded, $err);
    {
        my $b = EV::WebKit->new(window => [200,150], timeout => 10, cookie_jar => $jar);
        $b->load_cookies($snap, sub { ($loaded, $err) = @_; EV::break });
        TWK::run_with_timeout(20);
        $b->quit;
    }
    is($err, undef, 'load_cookies accepts a snapshot carrying expires') or diag $err;
    is($loaded, 2, 'both rows loaded');

    my ($got, $err2);
    {
        my $b = EV::WebKit->new(window => [200,150], timeout => 10, cookie_jar => $jar);
        $b->cookies('http://127.0.0.1/', sub { ($got, $err2) = @_; EV::break });
        TWK::run_with_timeout(20);
        $b->quit;
    }
    is($err2, undef, 'the jar is readable in a second instance') or diag $err2;
    my %by = map { $_->{name} => $_ } @{ $got || [] };
    ok($by{keeper},   'a row with expires persists across a restart')       or diag explain $got;
    ok(!$by{sessiony}, '...and one without it does not, as a session cookie');
}

# --- on_policy sees the documented type nick --------------------------------
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 10);
    $b->mock_scheme('pol', sub { ('<html><body>p</body></html>', 'text/html') });
    my @types;
    $b->on_policy(sub { my ($p) = @_; push @types, $p->type; $p->allow; 1 });
    $b->go('pol://one', sub { EV::break });
    TWK::run_with_timeout(20);
    ok(scalar @types, 'on_policy fired') or diag 'no policy decision was seen';
    is($types[0], 'navigation-action', 'a plain navigation reports type navigation-action');
    $b->quit;
}

# --- Dialog dismiss actually resolves confirm() false -----------------------
# Only the accept direction was covered; a dismiss that silently behaved like
# accept would have passed.
{
    my $b = EV::WebKit->new(window => [300,200], timeout => 10);
    my @seen;
    $b->on_dialog(sub { my ($d) = @_; push @seen, $d->type; $d->dismiss; 1 });
    my ($answer, $err);
    $b->load_html('<html><body>c</body></html>', sub {
        $b->script('return confirm("really?");', sub { ($answer, $err) = @_; EV::break });
    });
    TWK::run_with_timeout(20);
    is($err, undef, 'the confirm round-trip completed') or diag $err;
    is(scalar @seen, 1, 'on_dialog saw exactly one dialog') or diag explain \@seen;
    ok(defined $answer && !$answer, 'dismiss resolves confirm() to false');
    $b->quit;
}

done_testing;
