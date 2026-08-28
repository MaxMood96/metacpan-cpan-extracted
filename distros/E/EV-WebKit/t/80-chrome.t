use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window=>[400,300], chrome => 1);
my $c = $b->{chrome};
ok($c, 'chrome hash present');
isa_ok($c->{$_}, 'Gtk4::Button', "chrome '$_' button") for qw/back forward reload/;
isa_ok($c->{entry}, 'Gtk4::Entry', 'address entry');
ok(!$c->{back}->get_sensitive,    'back button starts insensitive');
ok(!$c->{forward}->get_sensitive, 'forward button starts insensitive');

$b->mock_scheme('mock', sub {
    my ($uri) = @_;
    my ($n) = $uri =~ m{mock://(\w+)};
    return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
});

my %g;
my $t;
$b->go('mock://one', sub {
    $b->go('mock://two', sub {
        # give the chrome's own settle refresh (NAV_SETTLE_DELAY after 'finished')
        # time to land before sampling widget state
        $t = EV::timer(0.05, 0, sub {
            undef $t;
            $g{entry}          = $c->{entry}->get_text;
            $g{title}          = $b->{win}->get_title;
            $g{back_sensitive} = $c->{back}->get_sensitive;
            $g{fwd_sensitive}  = $c->{forward}->get_sensitive;
            $g{reload_icon}    = $c->{reload}->get_icon_name;
            EV::break;
        });
    });
});
TWK::run_with_timeout(20);
is($g{entry}, 'mock://two', 'address entry tracks current uri');
is($g{title}, 'two', 'window title tracks page title');
ok($g{back_sensitive}, 'back button sensitive after two navigations');
ok(!$g{fwd_sensitive}, 'forward button insensitive at newest entry');
is($g{reload_icon}, 'view-refresh-symbolic', 'reload icon restored after load');

# focus guard: while the address entry has keyboard focus, a chrome refresh
# (triggered here by navigating) must not clobber what the user is typing --
# and must resume tracking the uri once focus is released. Requires real
# keyboard focus, which needs a window manager; xvfb-run's private display
# has none, so this degrades to an honest SKIP rather than a fake pass (a
# plain, non-composite widget was confirmed unable to acquire has_focus in
# this same environment -- not specific to Gtk4::Entry's delegate widget).
$c->{entry}->grab_focus;
my $got_focus = $c->{entry}->has_focus ? 1 : 0;
SKIP: {
    skip 'address entry could not acquire keyboard focus (no window manager on the xvfb-run display)', 2
        unless $got_focus;

    $c->{entry}->set_text('user typing');
    my ($t3, %g2);
    $b->go('mock://three', sub {
        $t3 = EV::timer(0.05, 0, sub { undef $t3; $g2{focused_text} = $c->{entry}->get_text; EV::break });
    });
    TWK::run_with_timeout(20);
    is($g2{focused_text}, 'user typing',
        'entry keeps user-typed text across a navigation while focused (focus guard honored)');

    $b->{win}->set_focus(undef);   # relinquish focus
    my $t4;
    $b->go('mock://four', sub {
        $t4 = EV::timer(0.05, 0, sub { undef $t4; $g2{blurred_text} = $c->{entry}->get_text; EV::break });
    });
    TWK::run_with_timeout(20);
    is($g2{blurred_text}, 'mock://four', 'entry tracks the uri again once focus is released');
}

$b->quit;
pass('quit with chrome does not crash');
# The address bar must track a single-page-app (history.pushState) navigation,
# not just full page loads. Clicking a link on a real SPA (Reddit, etc.) changes
# the URL via pushState with NO load-changed cycle -- the chrome only refreshed
# on load-changed, so the bar showed a stale URL while the page had moved on.
{
    my $sb = EV::WebKit->new(window => [500,350], chrome => 1);
    $sb->mock_scheme('spa', sub { ('<html><body><h1>spa</h1></body></html>', 'text/html') });
    $sb->go('spa://start', sub { EV::break });
    TWK::run_with_timeout(15);
    { my $t = EV::timer(0.2, 0, sub { EV::break }); EV::run }
    is($sb->{chrome}{entry}->get_text, 'spa://start', 'address bar shows the loaded url');

    # a client-side navigation: no load-changed, only the view's notify::uri
    $sb->script('history.pushState({}, "", "/deep/page2"); return 1', sub { EV::break });
    TWK::run_with_timeout(10);
    { my $t = EV::timer(0.3, 0, sub { EV::break }); EV::run }

    is($sb->uri, 'spa://start/deep/page2', 'the view really navigated via pushState');
    is($sb->{chrome}{entry}->get_text, 'spa://start/deep/page2',
        'the address bar tracks a pushState navigation (not just load-changed)')
        or diag('the bar is stale -- chrome only refreshes on load-changed, not on notify::uri');
    $sb->quit;
}

done_testing;
