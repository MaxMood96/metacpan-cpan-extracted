use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# main-world script at document-start runs BEFORE the page's own inline script
# and its global is visible to the main world (and to script()).
{
    my $b = EV::WebKit->new(window => [200,150]);
    # the page's inline script records whether our injected global existed yet.
    $b->mock_scheme('us', sub {
        ('<html><head><script>window.__saw = (typeof window.__injected)</script></head><body>x</body></html>',
         'text/html');
    });
    my $h = $b->add_user_script('window.__injected = 42;', at => 'start', world => 'main');
    isa_ok($h, 'EV::WebKit::UserContent', 'add_user_script returns a handle');
    my %g;
    $b->go('us://host/p', sub {
        $b->script('return window.__injected', sub {
            $g{val} = $_[0];
            $b->script('return window.__saw', sub { $g{saw} = $_[0]; EV::break });
        });
    });
    TWK::run_with_timeout(15);
    is($g{val}, 42,        'main-world user script global visible to script()');
    is($g{saw}, 'number',  'document-start injection ran before the page inline script');
    $b->quit;
}

# isolated-world script (at document-end so document.body exists): its window
# global is INVISIBLE to the main world, but it shares the DOM.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('iso', sub { ('<html><body>iso</body></html>','text/html') });
    # the isolated script records (into the shared DOM) whether it can see the
    # module's OWN registry (window.__evwk, injected into the private EVWebKit
    # world). A correct isolated user script lives in a DEDICATED world distinct
    # from EVWebKit, so it must see __evwk as 'undefined' -- if it wrongly landed
    # in EVWebKit it could read/corrupt find()'s registry.
    $b->add_user_script(
        'window.__iso = 1;'
      . ' if (document.body) {'
      . '   document.body.setAttribute("data-iso","yes");'
      . '   document.body.setAttribute("data-evwk", typeof window.__evwk);'
      . ' }',
        at => 'end', world => 'isolated');
    my %g;
    $b->go('iso://host/p', sub {
        $b->script('return window.__iso || null', sub {           # main world
            $g{global} = $_[0];
            $b->script('return document.body.getAttribute("data-iso")', sub {
                $g{dom} = $_[0];
                $b->script('return document.body.getAttribute("data-evwk")', sub {
                    $g{evwk} = $_[0]; EV::break;
                });
            });
        });
    });
    TWK::run_with_timeout(15);
    is($g{global}, undef,        'isolated-world global is NOT visible to the main world');
    is($g{dom},    'yes',        'isolated-world script ran and shares the DOM');
    is($g{evwk},   'undefined',  'isolated user world is distinct from the module EVWebKit world (cannot see __evwk)');
    $b->quit;
}

# frames => 'top' vs 'all', on a page that HAS a frame -- the only way the two
# can be told apart. Tested on a frameless page they are indistinguishable, and
# swapping the two nicks in %USER_FRAMES left the whole suite green.
for my $case ([top => 0], [all => 1]) {
    my ($nick, $want_in_frame) = @$case;
    my $b = EV::WebKit->new(window => [300,200], timeout => 10);
    $b->mock_scheme('topf', sub {
        my ($u) = @_;
        return ('<html><body>inner</body></html>', 'text/html') if $u =~ m{topf://host/inner};
        return ('<html><body>top<iframe id=f src="topf://host/inner"></iframe></body></html>', 'text/html');
    });
    $b->add_user_script("window.__mark = '$nick';", at => 'start', frames => $nick);
    my %g;
    $b->go('topf://host/p', sub {
        my $t; $t = EV::timer(1.0, 0, sub {
            undef $t;
            $b->script('return String(window.__mark)', sub {
                $g{top} = $_[0];
                # the frame is same-origin, so main-world script can reach it
                $b->script('const w = document.getElementById("f").contentWindow;'
                         . 'return String(w.__mark);', sub { $g{frame} = $_[0]; EV::break });
            });
        });
    });
    TWK::run_with_timeout(25);
    is($g{top}, $nick, "frames => $nick injects into the top document");
    if ($want_in_frame) {
        is($g{frame}, $nick, "frames => $nick injects into the subframe too");
    }
    else {
        is($g{frame}, 'undefined', "frames => $nick leaves the subframe alone");
    }
    $b->quit;
}

# validation: bad option values and a missing source croak.
{
    my $b = EV::WebKit->new(window => [200,150]);
    eval { $b->add_user_script(undef) };
    like($@, qr/source is required/,          'undef source croaks');
    eval { $b->add_user_script([1,2]) };
    like($@, qr/source must be a string/,     'ref source croaks (no silent stringified-ref injection)');
    eval { $b->add_user_script("good();\0evil();") };
    like($@, qr/NUL byte/,                    'NUL byte in source croaks (would silently truncate)');
    eval { $b->add_user_script('x', allow => ['']) };
    like($@, qr/allow entries must be non-empty/, 'empty-string allow entry croaks');
    # A NUL truncates the pattern WebKit stores, so it stops matching. On deny
    # that is a bypass, not a narrowing: measured, "mk://blocked\0zz/*" became
    # "mk://blocked", matched nothing, and the script it should have denied RAN
    # on the denied url. The source is checked for the same byte a few lines up;
    # the patterns were not.
    for my $k (qw(allow deny)) {
        eval { $b->add_user_script('x', $k => ["mk://blocked\0zz/*"]) };
        like($@, qr/$k entry contains a NUL byte/,
             "NUL in a $k pattern croaks (it would truncate, and stop matching)");
    }
    eval { $b->add_user_script('x', at => 'whenever') };
    like($@, qr/at => 'whenever' is invalid/, 'bad at croaks');
    eval { $b->add_user_script('x', world => 'parallel') };
    like($@, qr/world => 'parallel' is invalid/, 'bad world croaks');
    eval { $b->add_user_script('x', frames => 'some') };
    like($@, qr/frames => 'some' is invalid/, 'bad frames croaks');
    $b->quit;
}

done_testing;
