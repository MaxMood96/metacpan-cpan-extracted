use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window=>[300,200]);
my ($h1, $missing, $missing_err, $count, $empty, $empty_err, $h1a_text, $h1b_text);
$b->load_html('<h1 class=x>A</h1><h1 class=x>B</h1><p>p</p>', sub {
    my $n=0; my $want=5; my $done = sub { EV::break if ++$n==$want };
    $b->find('h1', sub { $h1 = $_[0]; $done->() });
    $b->find('.none', sub { ($missing, $missing_err) = @_; $missing='SENTINEL' unless defined $missing; $done->() });
    $b->find_all('h1', sub {
        my $els = $_[0];
        $count = @$els;
        # identity, not just count: each returned handle must be wired to its
        # own distinct node, in document order -- not N aliases of one match.
        $els->[0]->text(sub { $h1a_text = $_[0]; $done->() });
        $els->[1]->text(sub { $h1b_text = $_[0]; $done->() });
    });
    $b->find_all('.none', sub { ($empty, $empty_err) = @_; $done->() });
});
TWK::run_with_timeout(10);
isa_ok($h1, 'EV::WebKit::Element', 'find returns Element');
is($missing, 'SENTINEL', 'missing selector -> undef element');
ok(!defined $missing_err, 'missing selector -> no error (not-found is not an error)');
is($count, 2, 'find_all count');
is($h1a_text, 'A', 'find_all[0] is the first element in document order');
is($h1b_text, 'B', 'find_all[1] is the second element in document order (distinct identity)');
is_deeply($empty, [], 'find_all no match -> empty arrayref');
ok(!defined $empty_err, 'find_all no match -> no error');

# A bad selector must croak on BOTH sides, and say the same thing. querySelector
# coerces a JSON null to the TYPE selector "null", so an unguarded find(undef)
# answers "not found" -- indistinguishable from a selector that simply did not
# match, and the one wrong answer this API must not give. The browser had the
# guard; the element atoms did not, so $el->find(undef) reported not-found while
# $b->find(undef) croaked. Reachable over the control socket too: el.find with
# a:[null] is ONE argument, so the arity guard passes it through.
{
    my @bad = ( [ undef, qr/a selector is required/ ],
                [ '',    qr/must not be empty/      ],
                [ sub {}, qr/did you omit the selector/ ] );
    # Carp appends " at FILE line N." -- strip it, so the two sides can be
    # compared as the strings they are. Matching each against the same fragment
    # would NOT do it: the fragment omits the method-name prefix, so an element
    # side croaking 'elem_find: a selector is required' would pass a `like` that
    # the browser's 'find: ...' also passes.
    my $msg = sub { my $e = shift; $e =~ s/ at \S+ line \d+\.?\s*\z//; $e };
    for my $case (@bad) {
        my ($sel, $want) = @$case;
        my $label = !defined $sel ? 'undef' : (ref $sel ? 'a coderef' : 'the empty string');
        for my $m (qw(find find_all)) {
            ok(!eval { $b->$m($sel, sub {}); 1 }, "browser $m($label) croaks");
            my $bmsg = $msg->($@);
            like($bmsg, $want, "...saying why");
            ok(!eval { $h1->$m($sel, sub {}); 1 }, "element $m($label) croaks too");
            is($msg->($@), $bmsg, "...with the SAME message, byte for byte");
        }
    }
}
done_testing;
