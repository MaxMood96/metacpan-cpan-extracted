use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use Scalar::Util qw(weaken);
use EV; use EV::WebKit;

# An instance must be garbage-collected by a bare drop (undef / scope exit),
# NOT only after an explicit quit(). Its native GObject signal handlers
# (load-changed/load-failed/console/dialog/policy) and the mock_scheme
# uri-scheme handler must hold only a WEAK reference to $self; otherwise the
# $self <-> {view}/{context} <-> handler cycle keeps every instance (and its
# native window/view/session) alive for the life of the process. quit()
# still collects too (it breaks the cycle by deleting the natives).

sub spin { for (1..4) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run } }

# runs $build->() which returns a weakened ref to a browser it then drops;
# after settling, that ref must be undef (collected).
sub collects_ok {
    my ($name, $build) = @_;
    my $w = $build->();
    spin();
    ok(!defined $w, "$name: collected by a bare drop (no quit)");
}

collects_ok('bare new + drop' => sub {
    my $b = EV::WebKit->new(window => [200,150]);
    weaken(my $w = $b); undef $b; $w;
});

collects_ok('new + mock_scheme + navigate + drop' => sub {
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('drop1', sub { ('<html><body><div id=x>X</div></body></html>','text/html') });
    my ($done); my $wd = EV::timer(10,0,sub{EV::break});
    $b->go('drop1://p', sub { $done = defined $_[1] ? "failed: $_[1]" : 1; EV::break }); EV::run; undef $wd;
    is($done, 1, 'setup: the instance navigated (not merely resolved) before it was dropped');
    weaken(my $w = $b); undef $b; $w;
});

collects_ok('new(on_console/on_dialog/on_policy) + navigate + drop' => sub {
    my $b = EV::WebKit->new(window => [200,150],
                            on_console => sub {}, on_dialog => sub {}, on_policy => sub {});
    $b->mock_scheme('drop2', sub { ('<html><body>hi</body></html>','text/html') });
    my ($done); my $wd = EV::timer(10,0,sub{EV::break});
    $b->go('drop2://p', sub { $done = defined $_[1] ? "failed: $_[1]" : 1; EV::break }); EV::run; undef $wd;
    is($done, 1, 'setup: the instance navigated (not merely resolved) before it was dropped');
    weaken(my $w = $b); undef $b; $w;
});

collects_ok('new(chrome=>1) + navigate + drop' => sub {
    my $b = EV::WebKit->new(window => [300,200], chrome => 1);
    $b->mock_scheme('drop3', sub { ('<html><body>hi</body></html>','text/html') });
    my ($done); my $wd = EV::timer(10,0,sub{EV::break});
    $b->go('drop3://p', sub { $done = defined $_[1] ? "failed: $_[1]" : 1; EV::break }); EV::run; undef $wd;
    is($done, 1, 'setup: the instance navigated (not merely resolved) before it was dropped');
    weaken(my $w = $b); undef $b; $w;
});

# explicit quit() before drop must STILL collect (no regression)
collects_ok('new + quit + drop' => sub {
    my $b = EV::WebKit->new(window => [200,150]);
    $b->quit;
    weaken(my $w = $b); undef $b; $w;
});

# Dropping WHILE a navigation is pending must also collect. The per-nav
# timeout timer lives inside $self->{pending}, so a strong $self there would
# defer collection until the nav resolved or timed out (up to {timeout}s).
# With the weak timer, dropping the last reference runs DESTROY synchronously,
# so the weakref is already cleared before we even spin the loop -- a
# deterministic check that needs no timing/network.
{
    my $b = EV::WebKit->new(window => [200,150], timeout => 30);
    $b->mock_scheme('droppending', sub { ('<html><body>hi</body></html>','text/html') });
    $b->go('droppending://p');   # nav armed and pending; never awaited
    weaken(my $w = $b);
    undef $b;                     # synchronous DESTROY iff the pending timer is weak
    ok(!defined $w, 'collected immediately on drop while a navigation is pending (per-nav timer is weak, not a 30s defer)');
}

# a live Element handle keeps its browser reachable (documented), but once the
# Element is dropped too, both collect -- even without quit().
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('drop4', sub { ('<html><body><div id=x>X</div></body></html>','text/html') });
    my ($el, $done); my $wd = EV::timer(10,0,sub{EV::break});
    $b->go('drop4://p', sub {
        $b->find('#x', sub { ($el) = @_; $done = 1; EV::break });
    });
    EV::run; undef $wd;
    ok($el, 'setup: got an element handle');
    weaken(my $wb = $b);
    weaken(my $we = $el);
    undef $b; undef $el;
    spin();
    ok(!defined $we, 'element handle collected once dropped');
    ok(!defined $wb, 'browser collected by a bare drop even after holding an element');
}

# Dropped with a callback delivery still pending. _defer/_defer_final were the
# only two closure sites in the module that captured $self STRONGLY -- and they
# are the two every async completion and every early-error guard funnels
# through, so the cycle (self -> {_defer}{id} -> timer -> closure -> self) was
# armed constantly. It self-heals one tick later (the one-shot fires, deletes
# itself, drops the last ref), which is exactly why every collectability test
# here missed it: they all spin() first. Check BEFORE spinning.
{
    my $wb;
    {
        my $b = EV::WebKit->new(window => [200,150]);
        weaken($wb = $b);
        $b->_defer(sub { }, 1);          # a completion delivery, still pending
    }
    ok(!defined $wb, 'browser collected AT the drop with a deferred callback pending (no spin)')
        or do { spin(); diag(defined $wb ? 'still alive even after spinning' : 'only collected after a tick -- the cycle is back') };
}

# ...and the same for _defer_final, whose callbacks (the early-error guards)
# are in no registry at all: quit() has nothing to flush for them, so delivery
# must not depend on the instance surviving the tick. It is kept off $self
# entirely -- so the browser collects immediately AND the callback still fires.
{
    my ($wb, $err, $fired) = (undef, undef, 0);
    {
        my $b = EV::WebKit->new(window => [200,150]);
        weaken($wb = $b);
        $b->go(undef, sub { $fired++; $err = $_[1] });   # early error -> _defer_final
    }
    ok(!defined $wb, 'browser collected AT the drop with a final callback pending (no spin)');
    spin();
    is($fired, 1, '...and that callback still fires exactly once after the browser is gone');
    like($err // '', qr/uri required/, '...with its real error, not silence');
}

# The chrome widgets must not form a cycle among THEMSELVES. quit() deletes
# {chrome}, which severs the browser's link to them -- so every existing
# collectability check here still passes even if the chrome hash and its GTK
# widgets are an island leaking forever (the reload button's handler holding the
# hash that holds the button; the entry's handler holding the entry). Weak-check
# the chrome hash itself, not just the browser.
{
    my ($wb, $wc);
    {
        my $b = EV::WebKit->new(window => [400,300], chrome => 1);
        weaken($wb = $b);
        weaken($wc = $b->{chrome});
        ok($wc, 'setup: chrome built');
        my $done;
        $b->load_html('<title>chrome</title><p>x</p>', sub { $done = defined $_[1] ? "failed: $_[1]" : 1; EV::break });
        TWK::run_with_timeout(15);
        is($done, 1, 'setup: chrome instance navigated (not merely resolved)');
        $b->quit;
    }
    spin();
    ok(!defined $wc, 'the chrome widgets are collected too (no cycle island left behind by quit)')
        or diag('quit() cut {chrome} loose from the browser, but the hash and its GTK widgets still hold each other');
    ok(!defined $wb, 'and the browser itself');
}

# ...and weak-check each WIDGET, not just the hash that holds them. A widget
# whose own handler closes over it ($entry -> activate closure -> $entry) is a
# self-cycle that does NOT include the chrome hash -- so the browser and the
# hash both still collect, and the check above passes while a Gtk4::Entry (and
# its native GtkEntry) leaks for the life of the process. Sweep every widget
# that has a handler attached.
{
    my %w;
    {
        my $b = EV::WebKit->new(window => [400,300], chrome => 1);
        my $c = $b->{chrome};
        weaken($w{$_} = $c->{$_}) for qw(entry back forward reload);
        ok($w{entry} && $w{reload}, 'setup: chrome widgets built');
        my $done;
        $b->load_html('<title>w</title><p>x</p>', sub { $done = defined $_[1] ? "failed: $_[1]" : 1; EV::break });
        TWK::run_with_timeout(15);
        is($done, 1, 'setup: the instance navigated (not merely resolved) before it was dropped');
        $b->quit;
    }
    spin();
    my @leaked = sort grep { defined $w{$_} } keys %w;
    is(scalar(@leaked), 0, 'every chrome widget is collected (none held by its own handler closure)')
        or diag('leaked widgets: ' . join(', ', @leaked)
              . ' -- a handler closure captures its own widget strongly');
}

done_testing;
