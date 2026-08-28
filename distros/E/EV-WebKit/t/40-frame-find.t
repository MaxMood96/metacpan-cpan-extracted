use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# find/find_all/wait_for can address a same-origin iframe through a frame =>
# SELECTOR. (The frame => { url => ... } form, which is not limited to
# same-origin, is t/41-frame-ipc.t.)
# Cross-origin is a hard stop -- contentDocument is null there and nothing in
# the UI process can reach past it -- so that case must say so rather than
# report the element as merely absent.

my $b = EV::WebKit->new(window => [500,400], timeout => 10);
my $html = q{<html><body><h1 id=top>TOP</h1>}
         . q{<iframe id=f1 srcdoc='<p id=deep>INNER-TEXT</p>'></iframe></body></html>};

my (%got, $phase);
$b->load_html($html, sub {
    my $t; $t = EV::timer(1.2, 0, sub {
        undef $t;
        # a script-created about:blank iframe inherits the parent origin, which
        # is how the nested case gets a genuinely same-origin inner frame
        $b->script(q{
            const d = document.querySelector('#f1').contentDocument;
            const f2 = d.createElement('iframe'); f2.id = 'f2';
            d.body.appendChild(f2);
            f2.contentDocument.body.innerHTML = '<span id="d2">DEEPEST</span>';
            return 1;
        }, sub {
            my $t2; $t2 = EV::timer(0.5, 0, sub { undef $t2; one_level() });
        });
    });
});

sub one_level {
    $b->find('#deep', frame => '#f1', sub {
        my ($el, $err) = @_;
        return finish("one_level: $err") if $err;
        return finish('one_level: not found') unless $el;
        $el->text(sub { $got{one} = $_[0]; nested() });
    });
}
sub nested {
    $b->find('#d2', frame => ['#f1', '#f2'], sub {
        my ($el, $err) = @_;
        return finish("nested: " . ($err // 'not found')) if $err || !$el;
        $el->text(sub { $got{nested} = $_[0]; missing() });
    });
}
sub missing {
    $b->find('#x', frame => '#nope', sub {
        my (undef, $err) = @_; $got{missing_err} = $err; plural();
    });
}
sub plural {
    $b->find_all('p', frame => '#f1', sub {
        my ($els, $err) = @_;
        $got{all} = $err ? undef : scalar @$els;
        $b->find('#top', sub { $got{main} = $_[0] ? 1 : 0; finish() });
    });
}
sub finish { $got{fatal} = $_[0] if defined $_[0]; EV::break }

TWK::run_with_timeout(40);
is($got{fatal}, undef, 'no fatal error walking the frames') or diag $got{fatal};
is($got{one}, 'INNER-TEXT', 'find reaches into a same-origin iframe');
is($got{nested}, 'DEEPEST', 'a frame chain reaches a nested iframe');
like($got{missing_err} // '', qr/frame not found/, 'a missing frame is an error, not "not found"');
is($got{all}, 1, 'find_all is scoped to the frame');
is($got{main}, 1, 'the main frame still resolves afterwards');
$b->quit;

# a cross-origin frame says so, rather than reporting the element absent
{
    my $c = EV::WebKit->new(window => [400,300], timeout => 10);
    $c->mock_scheme('mock', sub {
        my ($uri) = @_;
        return ('<html><body><iframe id=x src="mock://inner"></iframe></body></html>', 'text/html')
            if $uri =~ m{mock://start};
        return ('<html><body><p id=p>hi</p></body></html>', 'text/html');
    });
    my $err;
    $c->go('mock://start', sub {
        my $t; $t = EV::timer(1.2, 0, sub {
            undef $t;
            $c->find('#p', frame => '#x', sub { $err = $_[1]; EV::break });
        });
    });
    TWK::run_with_timeout(30);
    like($err // '', qr/cross-origin/, 'an unreachable frame names cross-origin as the reason');
    $c->quit;
}

# the option is validated
{
    my $d = EV::WebKit->new(window => [200,200], timeout => 5);
    ok(eval { $d->find('#a', frame => [], sub {}); 1 }, 'an empty chain is accepted (no frames)');
    ok(!eval { $d->find('#a', frame => \1, sub {}); 1 }, 'a non-string frame croaks');
    ok(!eval { $d->find('#a', frame => '', sub {}); 1 }, 'an empty frame selector croaks');
    ok(!eval { $d->find('#a', bogus => 1, sub {}); 1 }, 'an unknown option croaks');
    $d->quit;
}

# A handle into a frame that is REMOVED must stop answering. isConnected alone
# does not detect that: the node is still connected to its own document, which
# is merely detached from the parent. Measured before the registry learned to
# check the browsing context: three seconds after the iframe was removed the
# handle still read the old text and reported click() as HAVING SUCCEEDED --
# a wrong answer delivered as success, which is the one outcome this API must
# never produce. The signal that works is ownerDocument.defaultView, the same
# one the web-process extension uses for zombie frames.
{
    my $rb = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 10);
    $rb->mock_scheme('rf', sub {
        my $u = shift;
        return ('<html><body><p id=c>childtext</p></body></html>', 'text/html')
            if $u =~ m{/inner};
        return ('<html><body><iframe id=f src="rf://host/inner"></iframe></body></html>',
                'text/html');
    });
    my $el;
    $rb->go('rf://host/outer', sub {
        $rb->find('#c', frame => '#f', sub { $el = $_[0]; EV::break });
    });
    TWK::run_with_timeout(25);
    ok($el, 'premise: a selector-reached handle inside the iframe') or diag 'no element';

  SKIP: {
        skip 'no handle', 4 unless $el;
        my ($t1, $e1) = (undef, undef);
        $el->text(sub { ($t1, $e1) = @_; EV::break });
        TWK::run_with_timeout(15);
        is($t1, 'childtext', 'premise: it reads the frame content while the frame is there')
            or diag($e1 // 'no error');

        $rb->script('document.getElementById("f").remove(); return 1;', sub { EV::break });
        TWK::run_with_timeout(15);
        { my $settle = EV::timer(1.0, 0, sub { EV::break }); EV::run }

        my ($t2, $e2) = (undef, undef);
        $el->text(sub { ($t2, $e2) = @_; EV::break });
        TWK::run_with_timeout(15);
        like($e2 // '', qr/stale element/,
             'once the frame is removed the handle reports stale, not the old text')
            or diag('text=' . ($t2 // 'undef') . ' err=' . ($e2 // 'NONE'));

        my ($r3, $e3) = (undef, undef);
        $el->click(sub { ($r3, $e3) = @_; EV::break });
        TWK::run_with_timeout(15);
        like($e3 // '', qr/stale element/, '...and a click on it is refused')
            or diag('res=' . ($r3 // 'undef') . ' err=' . ($e3 // 'NONE'));
        is($r3, undef, '...rather than reported as having worked');
    }
    $rb->quit;
}

done_testing;
