use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# wait_for_navigation, and click's pointer press.
#
# Both exist for the same script: "fill the form, click Submit, scrape the next
# page". Before them the click resolved before the navigation had started, no
# completion signal followed, and a control listening on mousedown never fired
# at all while click() still reported success.

my $b = EV::WebKit->new(window => [500,400], timeout => 15);
$b->mock_scheme('nv', sub {
    my ($u) = @_;
    return ('<html><head><title>TWO</title></head><body>second</body></html>', 'text/html')
        if $u =~ m{nv://two};
    return ('<html><head><title>ONE</title></head><body>'
          . '<a id=go href="nv://two">next</a>'
          . '<button id=md>md</button>'
          . '<fieldset disabled><button id=fs>fs</button></fieldset>'
          . '<button id=dis disabled>dis</button>'
          . '<script>window.log = [];'
          . 'const rec = (el, t) => el.addEventListener(t, () => window.log.push(el.id + ":" + t));'
          . 'for (const id of ["md","dis","fs"])'
          . '  for (const t of ["pointerdown","mousedown","pointerup","mouseup","click"])'
          . '    rec(document.getElementById(id), t);'
          . '</script></body></html>', 'text/html');
});

my (%g, @steps);
sub nxt { my $s = shift @steps or return EV::break; $s->() }
sub log_now { my ($k, $next) = @_; $b->script('return window.log.join(",");', sub { $g{$k} = $_[0]; $next->() }) }

@steps = (
    sub { $b->find('#md',  sub { $_[0]->click(sub { log_now(md  => \&nxt) }) }) },
    sub { $b->find('#dis', sub { $_[0]->click(sub { log_now(dis => \&nxt) }) }) },
    sub { $b->find('#fs',  sub { $_[0]->click(sub { log_now(fs  => \&nxt) }) }) },
    sub {
        # armed BEFORE the click, which is the documented order
        $b->wait_for_navigation(sub {
            my ($uri, $err) = @_;
            $g{nav_uri}   = $err ? "ERR $err" : $uri;
            $g{nav_title} = $b->title;
            nxt();
        });
        $b->find('#go', sub { $_[0]->click });
    },
    sub { $b->wait_for_navigation(timeout => 1, sub { $g{nav_timeout} = $_[1] // 'NO ERROR'; nxt() }) },
    sub {
        # it also covers a navigation this API starts
        $b->wait_for_navigation(sub { $g{nav_api} = $_[1] ? "ERR $_[1]" : $_[0]; nxt() });
        $b->go('nv://one');
    },
);

$b->go('nv://one', sub { nxt() });
TWK::run_with_timeout(60);

is($g{md},  'md:pointerdown,md:mousedown,md:pointerup,md:mouseup,md:click',
   'click presses: pointerdown, mousedown, pointerup, mouseup, then click');
is($g{dis}, $g{md}, 'a disabled control gets no synthetic press (and no click either)');
is($g{fs},  $g{md}, 'a control inside a disabled fieldset likewise');
is($g{nav_uri},   'nv://two', 'wait_for_navigation resolves when a CLICKED link finishes loading');
is($g{nav_title}, 'TWO',      '...with the new document in place, not the old one');
is($g{nav_timeout}, 'timeout', 'it times out when nothing navigates');
is($g{nav_api}, 'nv://one',   'and covers a navigation this API started too');
$b->quit;

# The two shapes wait_for_navigation got wrong, both regression-tested here.
{
    my $c = EV::WebKit->new(window => [300,200], timeout => 10);
    my ($uri, $err, $go_err);
    # (1) a FAILING navigation this API started. The failure consumed the
    # pending, and the failed load's terminal 'finished' -- which arrives with
    # no pending -- then drained the waiter through the no-pending SUCCESS path:
    # a bogus success, with an empty uri, for a navigation that never happened.
    $c->wait_for_navigation(sub { ($uri, $err) = @_; EV::break });
    $c->go('zzz://nope', sub { $go_err = $_[1] });
    TWK::run_with_timeout(25);
    ok(defined $go_err, 'precondition: the navigation really failed') or diag 'it succeeded';
    ok(defined $err, 'a failing navigation resolves the waiter with an error, not a success')
        or diag "resolved with uri=" . ($uri // 'undef');
    is($uri, undef, '...and with no uri');
    is($err, $go_err, '...the same failure go() reported, as the POD says');
    $c->quit;
}
{
    my $c = EV::WebKit->new(window => [300,200], timeout => 10);
    $c->mock_scheme('w', sub { ('<html><head><title>W</title></head><body>w</body></html>', 'text/html') });
    my ($uri, $err, $fired);
    # (2) armed from inside a navigation callback -- the natural spelling of the
    # documented "arm it before you click". The drain ran after that same
    # navigation's callbacks, so it consumed the waiter immediately and handed
    # back the page the caller already had.
    $c->go('w://one', sub {
        $c->wait_for_navigation(sub { ($uri, $err) = @_; $fired = 1; EV::break });
        my $t; $t = EV::timer(1.5, 0, sub { undef $t; EV::break });   # nothing navigates
        $c->{_test_timer} = $t;
    });
    TWK::run_with_timeout(25);
    ok(!$fired, 'a waiter armed inside a navigation callback is NOT consumed by that navigation')
        or diag "resolved at once with uri=" . ($uri // 'undef') . " err=" . ($err // 'none');
    $c->quit;
}

# validation and teardown
{
    my $d = EV::WebKit->new(window => [200,200], timeout => 5);
    ok(!eval { $d->wait_for_navigation('not a sub'); 1 },          'a non-coderef callback croaks');
    ok(!eval { $d->wait_for_navigation(bogus => 1, sub {}); 1 },   'an unknown option croaks');
    ok(!eval { $d->wait_for_navigation(timeout => 0, sub {}); 1 }, 'a zero timeout croaks');
    # ...but an instance-wide timeout => 0 is INHERITED, and means what it
    # means everywhere else in this module: time out at once. Documented, and
    # previously claimed to mean the opposite ('unbounded'), which nothing
    # here would have caught.
    {
        my $z = EV::WebKit->new(window => [200,200], timeout => 0);
        my @got;
        my $t0 = EV::time;   # NOT `my (@got, $t0) = ...` -- the array slurps the list
        ok(eval { $z->wait_for_navigation(sub { @got = @_; EV::break }); 1 },
           'an instance-wide timeout => 0 does not croak');
        my $w = EV::timer(5, 0, sub { EV::break }); EV::run; undef $w;
        is($got[1], 'timeout', '...it is inherited as an immediate timeout');
        cmp_ok(EV::time - $t0, '<', 2, '...delivered at once, not after a wait');
        $z->quit;
    }
    my @got = ('never called');
    $d->wait_for_navigation(sub { @got = @_ });
    $d->quit;
    my $t = EV::timer(2, 0, sub { EV::break }); EV::run; undef $t;
    is($got[1], 'browser closed', 'quit resolves a waiting wait_for_navigation instead of dropping it')
        or diag explain \@got;
}

done_testing;
