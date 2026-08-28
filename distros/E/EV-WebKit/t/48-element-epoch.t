use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# Element handles are per-document (the __evwk registry restarts at id 0 on
# every navigation, since the boot UserScript re-injects a fresh one into
# each new document). A handle obtained on page A must never silently
# resolve against page B's element occupying the same numeric slot -- see
# EV::WebKit::Element's POD: "navigation has replaced the page" -> stale
# element. This regression pins that down across an actual navigation.

my $b = EV::WebKit->new(window=>[300,200]);
$b->mock_scheme('mockep', sub {
    my ($uri) = @_;
    return ('<html><body><div id="a">PAGE-A</div></body></html>', 'text/html')
        if $uri =~ /page-a/;
    return ('<html><body><div id="b">PAGE-B</div><div id="mut">before</div></body></html>', 'text/html');
});

my %g;
$b->go('mockep://page-a', sub {
    my (undef, $err) = @_;
    return do { $g{err} = $err // 'load a failed'; EV::break } if $err;
    $b->find('#a', sub {
        my ($elA, $err) = @_;
        return do { $g{err} = $err // 'find a failed'; EV::break } if $err || !$elA;
        $b->go('mockep://page-b', sub {
            my (undef, $err) = @_;
            return do { $g{err} = $err // 'load b failed'; EV::break } if $err;
            $b->find('#b', sub {
                my ($elB, $err) = @_;
                return do { $g{err} = $err // 'find b failed'; EV::break } if $err || !$elB;
                # precondition: page B's registry reused the same numeric id
                # page A's handle had -- this is what makes the bug silent
                # rather than an obvious out-of-range failure.
                $g{same_id} = ($elA->{id} == $elB->{id}) ? 1 : 0;

                # 1) a handle from the OLD page must error, not silently
                #    read the NEW page's element occupying the same slot.
                $elA->text(sub {
                    my ($t, $err) = @_;
                    $g{stale_text} = $t; $g{stale_err} = $err;

                    # 2) a SAME-page handle keeps working after a DOM
                    #    mutation that doesn't remove it (epoch check must
                    #    not be over-broad).
                    $b->find('#mut', sub {
                        my ($elMut, $err) = @_;
                        return do { $g{err} = $err // 'find mut failed'; EV::break } if $err || !$elMut;
                        $b->script('document.getElementById("mut").textContent = "after"; return true;', sub {
                            my (undef, $err) = @_;
                            return do { $g{err} = $err // 'mutate failed'; EV::break } if $err;
                            $elMut->text(sub {
                                my ($t, $err) = @_;
                                $g{mut_text} = $t; $g{mut_err} = $err;

                                # 3) a removed-node handle (same page/epoch)
                                #    still errors -- the pre-existing
                                #    isConnected check must survive intact.
                                $b->script('document.getElementById("b").remove(); return true;', sub {
                                    my (undef, $err) = @_;
                                    return do { $g{err} = $err // 'remove failed'; EV::break } if $err;
                                    $elB->text(sub {
                                        my ($t, $err) = @_;
                                        $g{removed_text} = $t; $g{removed_err} = $err;
                                        EV::break;
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    });
});
TWK::run_with_timeout(15);

ok(!defined $g{err}, 'setup navigated/found elements without error') or diag($g{err});
ok($g{same_id}, 'precondition: page B reused the same numeric registry id as the stale page-A handle');

ok(!defined $g{stale_text}, 'stale cross-navigation handle: no result');
like($g{stale_err} // '', qr/stale element/, 'stale cross-navigation handle: error mentions stale element');

is($g{mut_text}, 'after', 'same-page handle still resolves correctly after an unrelated DOM mutation');
ok(!defined $g{mut_err}, 'same-page handle: no error after unrelated mutation') or diag($g{mut_err});

ok(!defined $g{removed_text}, 'removed-node handle: no result');
like($g{removed_err} // '', qr/stale element/, 'removed-node handle: error still mentions stale element (isConnected path intact)');

$b->quit;
done_testing;
