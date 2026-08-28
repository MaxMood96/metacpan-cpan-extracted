use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# find_js/find_all_js: the bridge from your own JavaScript back to an element
# handle. CSS cannot express XPath, "the row whose cell says X", or anything
# inside a shadow root -- querySelector does not cross one at all -- and the
# snippet runs in the same isolated world as the registry, which is what makes
# handing the node back possible.

my $b = EV::WebKit->new(window => [600,400], timeout => 15);
my $HTML = <<'H';
<html><body>
<table><tr><td>Invoice 41</td><td><a class=go href="#">open41</a></td></tr>
       <tr><td>Invoice 42</td><td><a class=go href="#">open42</a></td></tr></table>
<button>Cancel</button><button>Next</button>
<div id=host></div>
<script>
const r = document.getElementById('host').attachShadow({mode:'open'});
r.innerHTML = '<p class="deep">SHADOW-TEXT</p><p class="deep">TWO</p>';
</script>
</body></html>
H

my (%g, @steps);
sub nxt { my $s = shift @steps or return EV::break; $s->() }

@steps = (
    sub {
        $b->find_js('return document.evaluate("//tr[td[contains(.,\'Invoice 42\')]]//a",'
                  . ' document, null, 9, null).singleNodeValue;', sub {
            my ($el, $e) = @_;
            return do { $g{xpath} = "ERR $e"; nxt() } if $e;
            return do { $g{xpath} = '(no match)'; nxt() } unless $el;
            $el->text(sub { $g{xpath} = $_[0]; nxt() });
        });
    },
    sub {
        $b->find_js('return [...document.querySelectorAll("button")]'
                  . '.find(x => x.textContent.trim() === A.want);', args => { want => 'Next' }, sub {
            my ($el, $e) = @_;
            return do { $g{bytext} = "ERR $e"; nxt() } if $e;
            return do { $g{bytext} = '(no match)'; nxt() } unless $el;
            $el->text(sub { $g{bytext} = $_[0]; nxt() });
        });
    },
    sub {
        # the one CSS has no workaround for
        $b->find_js('return document.getElementById("host").shadowRoot.querySelector(".deep");', sub {
            my ($el, $e) = @_;
            return do { $g{shadow} = "ERR $e"; nxt() } if $e;
            return do { $g{shadow} = '(no match)'; nxt() } unless $el;
            $el->text(sub { $g{shadow} = $_[0]; nxt() });
        });
    },
    sub {
        # ...and the same node is genuinely operable, not just readable
        $b->find_js('return document.getElementById("host").shadowRoot.querySelector(".deep");', sub {
            my ($el) = @_;
            return nxt() unless $el;
            $el->attr('class', sub { $g{shadow_attr} = $_[0]; nxt() });
        });
    },
    sub {
        $b->find_all_js('return [...document.getElementById(A.id).shadowRoot.querySelectorAll(".deep")];',
                        args => { id => 'host' }, sub {
            my ($els, $e) = @_;
            $g{shadow_all} = $e ? "ERR $e" : scalar @$els;
            nxt();
        });
    },
    sub {   # CSS still works through this door, and finds the same node find() would
        $b->find_all_js('return document.querySelectorAll("a.go");', sub {
            my ($els, $e) = @_;
            $g{css_all} = $e ? "ERR $e" : scalar @$els;
            nxt();
        });
    },
    sub { $b->find_js('return 42;',   sub { $g{badtype}  = $_[1] // 'NO ERROR'; nxt() }) },
    sub { $b->find_js('return null;', sub { $g{nomatch}  = defined $_[1] ? "ERR $_[1]"
                                                        : defined $_[0] ? 'AN ELEMENT' : 'undef, no error'; nxt() }) },
    sub { $b->find_all_js('return 42;', sub { $g{badlist} = $_[1] // 'NO ERROR'; nxt() }) },
    sub { $b->find_all_js('return [document.body, 42];', sub { $g{badentry} = $_[1] // 'NO ERROR'; nxt() }) },
    sub { $b->find_js('throw new Error("boom");', sub { $g{threw} = $_[1] // 'NO ERROR'; nxt() }) },
);

$b->load_html($HTML, sub { my $t; $t = EV::timer(0.6, 0, sub { undef $t; nxt() }) });
TWK::run_with_timeout(60);

is($g{xpath},       'open42',       'an XPath snippet finds the row CSS cannot name');
is($g{bytext},      'Next',         'a by-visible-text snippet finds the right button');
is($g{shadow},      'SHADOW-TEXT',  'a snippet reaches inside an open shadow root');
is($g{shadow_attr}, 'deep',         '...and the handle it gives back really operates on that node');
is($g{shadow_all},  2,              'find_all_js returns every node in the shadow root');
is($g{css_all},     2,              'a NodeList is accepted as well as an array');
like($g{badtype} // '', qr/must return a DOM node/,        'a snippet returning a non-node is an error');
like($g{badlist} // '', qr/must return an array or NodeList/, 'find_all_js says so too');
like($g{badentry} // '', qr/every entry must be a DOM node/, 'a list with a non-node entry is an error, not a handle to nothing');
is($g{nomatch}, 'undef, no error',  'null is not-found, not an error');
like($g{threw} // '', qr/boom/,     'an exception in the snippet reaches the callback');
$b->quit;

# validation, synchronous
{
    my $d = EV::WebKit->new(window => [200,200], timeout => 5);
    ok(!eval { $d->find_js(undef, sub {}); 1 },              'a missing snippet croaks');
    ok(!eval { $d->find_js('', sub {}); 1 },                 'an empty snippet croaks');
    ok(!eval { $d->find_js('return null;', bogus => 1, sub {}); 1 }, 'an unknown option croaks');
    ok(!eval { $d->find_js('return null;', args => [], sub {}); 1 }, 'a non-hash args croaks');
    ok(!eval { $d->find_js('return null;', 'not a sub'); 1 },        'a non-coderef callback croaks');
    ok(!eval { $d->find_js('return null;', frame => '#f', sub {}); 1 },
       'the selector form of frame => is refused rather than ignored');
    ok(eval { $d->find_js('return null;', frame => { url => 'x' }, sub {}); 1 },
       'the url form of frame => is accepted');
    $d->quit;
}

done_testing;
