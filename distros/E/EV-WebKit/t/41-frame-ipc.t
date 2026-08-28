use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use EV::WebKit::Fingerprint;
plan skip_all => 'web-process extension not built' unless EV::WebKit::Fingerprint::available();

# frame => { url => ... } addresses a frame through the web-process extension,
# which is not bound by the same-origin policy -- so unlike the selector form
# (t/40-frame-find.t) it reaches a CROSS-ORIGIN frame, and the handles it
# returns stay bound to that frame for every later call.

# A die inside a deferred callback goes to $EV::DIED, which by default only
# warns -- so a callback-less call that dereferences undef would leave the
# suite green and the user with a hang. Collect them and assert none.
my @died;
$EV::DIED = sub { push @died, "$@" };

my $b = EV::WebKit->new(window => [500,400], timeout => 10);
my $twin = 0;
$b->mock_scheme('mock', sub {
    my ($u) = @_;
    return ('<html><body><h1 id=top>TOP</h1>'
          . '<iframe id=x src="mock://inner"></iframe>'
          . '<iframe id=y src="mock://twin"></iframe>'
          . '<iframe id=z src="mock://twin"></iframe></body></html>', 'text/html')
        if $u =~ m{mock://start};
    # the two twins share a url and differ only in what they were served, which
    # is the only way to prove an id addressed the frame it named
    return ('<html><body><p id=t>' . (++$twin == 1 ? 'ONE' : 'TWO') . '</p></body></html>', 'text/html')
        if $u =~ m{mock://twin};
    return ('<html><body><h1 id=top>TOP</h1></body></html>', 'text/html') if $u =~ m{mock://other};
    return ('<html><body><div id=box><b class=k>NESTED</b></div><p class=k>TWO</p>'
          . '<input id=i value="">'
          . '<script>setTimeout(function(){var d=document.createElement("div");'
          . 'd.id="late";d.textContent="LATE";document.body.appendChild(d)},500)</script>'
          . '</body></html>', 'text/html');
});

my (%g, @steps, $el);
sub next_step { my $s = shift @steps; return EV::break unless $s; $s->() }
sub bail { $g{fatal} = $_[0]; EV::break }

@steps = (
    sub {
        $b->frames(sub {
            my ($l, $e) = @_;
            return bail("frames: $e") if $e;
            $g{n_frames} = scalar @$l;
            $g{n_main}   = scalar grep { $_->{main} } @$l;
            $g{urls}     = join ',', sort map { $_->{url} } @$l;
            next_step();
        });
    },
    sub {
        $b->find('#box', frame => { url => 'mock://inner' }, sub {
            my ($e, $err) = @_;
            return bail("find: " . ($err // 'not found')) if $err || !$e;
            $el = $e;
            $g{bound} = defined $e->frame_id ? 1 : 0;
            $e->find('.k', sub {
                my ($k, $err2) = @_;
                return bail("child: " . ($err2 // 'not found')) if $err2 || !$k;
                $g{child_bound} = ($k->frame_id // '') eq ($e->frame_id // 'x') ? 1 : 0;
                $k->text(sub { $g{child_text} = $_[0]; next_step() });
            });
        });
    },
    sub {
        $b->find('#i', frame => { url => qr{inner$} }, sub {
            my ($i, $err) = @_;
            return bail("input: " . ($err // 'not found')) if $err || !$i;
            $i->type('typed', sub {
                my (undef, $e2) = @_;
                return bail("type: $e2") if $e2;
                $i->value(sub { $g{typed} = $_[0]; next_step() });
            });
        });
    },
    sub {
        $b->find_all('.k', frame => { url => 'mock://inner' }, sub {
            my ($els, $err) = @_;
            return bail("find_all: $err") if $err;
            $g{n_k} = scalar @$els;
            $g{all_bound} = (grep { defined $_->frame_id } @$els) == @$els ? 1 : 0;
            next_step();
        });
    },
    sub {
        $b->wait_for('#late', frame => { url => 'mock://inner' }, timeout => 8, sub {
            my ($e, $err) = @_;
            return bail("wait_for: $err") if $err;
            $e->text(sub { $g{late} = $_[0]; next_step() });
        });
    },
    sub {
        $b->find('#top', sub {
            my ($e, $err) = @_;
            return bail("main: " . ($err // 'not found')) if $err || !$e;
            $g{main_unbound} = defined $e->frame_id ? 0 : 1;
            next_step();
        });
    },
    sub { $b->find('#t', frame => { url => 'mock://nope' },  sub { $g{no_match}  = $_[1]; next_step() }) },
    sub { $b->find('#t', frame => { url => 'mock://twin' },  sub { $g{ambiguous} = $_[1]; next_step() }) },
    sub {
        # ...and an id from frames() is how you get past that ambiguity
        $b->frames(sub {
            my ($l, $e) = @_;
            return bail("frames: $e") if $e;
            my @twins = grep { $_->{url} eq 'mock://twin' } @$l;
            return bail('expected two frames on the twin url') unless @twins == 2;
            my (@txt, $read);
            $read = sub {
                my $t = shift @twins;
                unless ($t) { $g{twins} = join '+', sort @txt; return next_step() }
                $b->find('#t', frame => { id => $t->{id} }, sub {
                    my ($el2, $err) = @_;
                    return bail('by id: ' . ($err // 'not found')) if $err || !$el2;
                    $el2->text(sub { push @txt, $_[0] // ''; $read->() });
                });
            };
            $read->();
        });
    },
    sub {
        # a callback-less call still has to complete cleanly in a frame
        $b->find('#i', frame => { url => 'mock://inner' }, sub {
            my ($i, $err) = @_;
            return bail("cbless: " . ($err // 'not found')) if $err || !$i;
            $i->click;
            my $t; $t = EV::timer(0.5, 0, sub { undef $t; next_step() });
        });
    },
    sub {
        # the frame the handle belongs to dies with the page: the handle must
        # say so, not answer out of a document that is no longer displayed
        $b->go('mock://other', sub {
            my $t; $t = EV::timer(0.8, 0, sub {
                undef $t;
                $el->text(sub {
                    $g{stale} = $_[1] // 'NO ERROR';
                    $b->frames(sub { $g{after} = join(',', map { $_->{url} } @{ $_[0] || [] }); next_step() });
                });
            });
        });
    },
);

$b->go('mock://start', sub { my $t; $t = EV::timer(1.5, 0, sub { undef $t; next_step() }) });
TWK::run_with_timeout(60);

is($g{fatal}, undef, 'no fatal error addressing frames') or diag $g{fatal};
is($g{n_frames}, 4, 'frames() lists the main frame and all three children');
is($g{n_main}, 1, 'exactly one frame is the main frame');
is($g{urls}, 'mock://inner,mock://start,mock://twin,mock://twin', 'frames() reports each frame url');
is($g{bound}, 1, 'an element found through a frame carries its frame id');
is($g{child_text}, 'NESTED', 'find on that element searches inside the frame');
is($g{child_bound}, 1, 'a child element inherits the frame');
is($g{typed}, 'typed', 'type/value round-trip through the frame');
is($g{n_k}, 2, 'find_all is scoped to the frame');
is($g{all_bound}, 1, 'every find_all handle is bound to the frame');
is($g{late}, 'LATE', 'wait_for polls inside the frame');
is($g{main_unbound}, 1, 'a main-frame element carries no frame id');
like($g{no_match} // '', qr/no frame matched/, 'a url matching nothing is an error');
like($g{ambiguous} // '', qr/must identify one/, 'a url matching two frames is an error');
is($g{twins}, 'ONE+TWO', 'an id from frames() addresses each of two same-url frames');
like($g{stale} // '', qr/frame is gone/, 'a handle into a frame that has gone says so');
unlike($g{after} // 'mock://inner', qr{mock://inner}, 'frames() drops a frame that has gone');
$b->quit;

# the option is validated up front, synchronously
{
    my $d = EV::WebKit->new(window => [200,200], timeout => 5);
    ok(!eval { $d->find('#a', frame => {}, sub {}); 1 },                'frame => {} croaks (neither url nor id)');
    ok(!eval { $d->find('#a', frame => { name => 'f' }, sub {}); 1 },   'an unknown frame key croaks');
    ok(!eval { $d->find('#a', frame => { url => '' }, sub {}); 1 },     'an empty frame url croaks');
    ok(!eval { $d->find('#a', frame => { url => [] }, sub {}); 1 },     'a non-string frame url croaks');
    ok(!eval { $d->find('#a', frame => { url => 'u', id => 1 }, sub {}); 1 }, 'url and id together croak');
    ok(!eval { $d->find('#a', frame => { id => 'abc' }, sub {}); 1 },   'a non-integer frame id croaks');
    ok(eval { $d->find_all('#a', frame => { url => qr/x/ }, sub {}); 1 }, 'a regexp url is accepted');
    ok(eval { $d->find_all('#a', frame => { id => 0 }, sub {}); 1 },     'a zero frame id is accepted');
    $d->quit;
}

is_deeply(\@died, [], 'nothing died inside a deferred callback') or diag explain \@died;

# The extension is loaded for EVERY browser now (frame addressing needs it, and
# nothing says in advance whether a caller will ask). It must therefore stay
# inert without a profile: the presets set platform to one of these strings, and
# no host reports any of them.
#
# navigator.platform ALONE is not enough of a probe. Every native-getter block
# is gated on its own profile field, but the JS-coherence blob was emitted for
# an empty profile too -- the orientation entry is deliberately not keyed off
# `mobile`, so it was always set -- and the extension gates both COHERENCE_JS
# and the WebGL getParameter wrapper on that blob merely EXISTING. A default
# browser therefore advertised window.ScreenOrientation, which stock WebKitGTK
# does not expose, and answered a Function.prototype.toString native-code check
# on getParameter with wrapper source.
#
# The getParameter check is the durable half: no engine ships a non-native
# getParameter, so it cannot go stale the way asserting the ABSENCE of a DOM
# feature would when a future WebKitGTK grows it. The exact config is pinned as
# a unit assertion in t/99-fingerprint.t, where it is engine-independent.
{
    my $e = EV::WebKit->new(window => [200,150], timeout => 10);
    my ($plat, $perr, $env);
    $e->load_html('<html><body>x</body></html>', sub {
        $e->script('return navigator.platform;', sub {
            ($plat, $perr) = @_;
            $e->script(
                'return (typeof WebGLRenderingContext === "undefined") ? "no-webgl"'
              . ' : (/\[native code\]/.test(WebGLRenderingContext.prototype.getParameter.toString()) ? "native" : "wrapped");',
                sub { $env = $_[0]; EV::break });
        });
    });
    TWK::run_with_timeout(25);
    is($perr, undef, 'a browser with no fingerprint still runs script') or diag $perr;
    ok(defined $plat && length $plat, 'navigator.platform is readable');
    # Three of the four preset values, not four: `Linux armv8l` is what a 32-bit
    # ARM userland genuinely reports, so asserting against it would fail there
    # with nothing spoofed at all. The other three no Linux/GTK host can report.
    unlike($plat // '', qr/\A(?:Win32|MacIntel|iPhone)\z/,
           'loading the extension spoofs nothing when no profile was asked for');
    # `is`, not `isnt`: isnt('wrapped') also passes when the probe ERRORED and
    # $env came back undef, which is a silent pass under a name that claims a
    # measurement was made.
    if (($env // '') eq 'no-webgl') {
        ok(1, '...(this build exposes no WebGLRenderingContext, so there is nothing to wrap)');
    }
    else {
        is($env, 'native',
           '...and does not wrap WebGL getParameter either (it would fail a native-code check)');
    }
    $e->quit;
}

done_testing;
