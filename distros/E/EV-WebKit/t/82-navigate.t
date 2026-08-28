use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# on_load fires only for navigations the API started. A page that navigates
# ITSELF -- which is what a human clicking a link in a visible window looks like
# -- changed the page and told nobody: _finish_nav returns early when there is
# no pending nav. So the module could not report the one thing an interactive
# browser most obviously does.
#
# on_navigate reports every committed navigation, whoever caused it.

my (@nav, @load);
my $b = EV::WebKit->new(
    window      => [300,200], ephemeral => 1,
    on_navigate => sub { push @nav,  $_[0] },
    on_load     => sub { push @load, 'load' },
);
$b->mock_scheme('nv', sub {
    my $uri = shift;
    return ('<html><body><a id="lnk" href="nv://second">go</a></body></html>', 'text/html')
        if $uri =~ /first/;
    return ('<html><body><h1>SECOND</h1></body></html>', 'text/html');
});

# 1) an API navigation fires BOTH -- on_navigate is additive, on_load unchanged
$b->go('nv://first', sub { EV::break });
TWK::run_with_timeout(15);
for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }   # let the settle tick land
is(scalar(@nav), 1, 'an API navigation fires on_navigate');
is($nav[0], 'nv://first', '...with the uri');
is(scalar(@load), 1, '...and on_load still fires (unchanged)');

# 2) a navigation the PAGE starts -- the human clicking a link
@nav = (); @load = ();
$b->script('document.getElementById("lnk").click()', sub { });
{ my $t = EV::timer(3, 0, sub { EV::break }); EV::run }
is(scalar(@nav), 1, 'a link click fires on_navigate (nothing used to fire at all)')
    or diag('the page changed and the caller was never told');
is($nav[0], 'nv://second', '...with the new uri');
is(scalar(@load), 0, '...and on_load does NOT (it means "the nav I started finished")');
is($b->uri, 'nv://second', 'sanity: the browser really did navigate');

# 3) load_html is a navigation too
@nav = ();
$b->load_html('<p>x</p>', sub { EV::break });
TWK::run_with_timeout(15);
is(scalar(@nav), 1, 'load_html fires on_navigate');

# 4) nothing after quit
@nav = ();
$b->quit;
for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
is(scalar(@nav), 0, 'no on_navigate after quit');

# A target=_blank click asks WebKit for a NEW WINDOW. WebKit allows it and then
# emits 'create' to get one; a single-view browser answers nothing, so the click
# used to do nothing at all -- no navigation, no error, no event. popups
# defaults to 'follow', which takes it in this view instead.
{
    my $b = EV::WebKit->new(window => [400,300], timeout => 8);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        return ('<html><body><a id="x" href="mock://target" target="_blank">go</a></body></html>',
                'text/html') if $uri =~ m{mock://start};
        return ('<html><head><title>TARGET</title></head><body>arrived</body></html>', 'text/html');
    });
    my ($uri, $title);
    $b->go('mock://start', sub {
        $b->find('#x', sub {
            my ($el) = @_;
            $el->click(sub {
                my $t; $t = EV::timer(2.5, 0, sub {
                    undef $t; $uri = $b->uri; $title = $b->title; EV::break });
            });
        });
    });
    TWK::run_with_timeout(20);
    is($uri, 'mock://target', 'a target=_blank click navigates this view');
    is($title, 'TARGET', '...and the page really loaded');
    $b->quit;
}

# popups => 'block' keeps the drop, for a caller that wants it.
{
    my $b = EV::WebKit->new(window => [400,300], timeout => 8, popups => 'block');
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        return ('<html><body><a id="x" href="mock://target" target="_blank">go</a></body></html>',
                'text/html') if $uri =~ m{mock://start};
        return ('<html><head><title>TARGET</title></head><body>arrived</body></html>', 'text/html');
    });
    my $uri;
    $b->go('mock://start', sub {
        $b->find('#x', sub {
            my ($el) = @_;
            $el->click(sub {
                my $t; $t = EV::timer(2.5, 0, sub { undef $t; $uri = $b->uri; EV::break });
            });
        });
    });
    TWK::run_with_timeout(20);
    is($uri, 'mock://start', "popups => 'block' leaves the view where it was");
    $b->quit;
}

# and the option is validated rather than silently ignored
{
    my $bad = eval { EV::WebKit->new(window => [200,200], popups => 'maybe'); 1 };
    ok(!$bad, 'an unknown popups value croaks');
    like($@, qr/popups must be/, '...naming the option');
}


done_testing;
