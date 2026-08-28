use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# click / type / send_keys / clear / focus / submit -- one instance, one
# EV::run, one chain: each atom's effect is the precondition for the next
# assertion, and all results are captured into %g before we break the loop.
#
# submit() is deliberately the LAST step of this single chain (not a second
# instance / second EV::run): a prior version isolated submit() in its own
# EV::WebKit instance + separate EV::run, exactly as the task brief suggests
# guarding against a submit-triggered reload -- but that structure hit a
# separate, pre-existing bug (see task-7-report.md "Concerns"): invoking a
# *second* EV::run in the same process (whether via a new instance or by
# reusing this one) after this chain's ~13 sequential _call_js round trips
# reliably hung at 100% CPU, even with no submit/focus/click involved (13
# plain script() calls reproduce it too) -- i.e. it is unrelated to submit()
# or any write atom. Keeping everything in a single EV::run avoids that bug
# entirely, and still satisfies the spirit of "submit last": every other
# assertion's value is already captured in %g before submit() runs, so a
# possible post-submit reload cannot disturb them.
my $b = EV::WebKit->new(window=>[300,200]);
my %g;
my $fixture = '<input id=i>'
            . '<button id=btn onclick="window.__c=(window.__c||0)+1">go</button>'
            . '<form id=f><input name=x value=1></form>';
$b->load_html($fixture, sub {
    $b->find('#i', sub {
        my ($i) = @_;
        $i->type('abc', sub {
            $i->value(sub { $g{typed} = $_[0];
                $i->send_keys('def', sub {
                    $i->value(sub { $g{typed2} = $_[0];
                        $i->clear(sub {
                            $i->value(sub { $g{cleared} = $_[0];
                                # Move focus to the button first (explicitly, via
                                # raw script) so the later focus() assertion is
                                # meaningful rather than vacuously true.
                                $b->script(
                                    'document.getElementById("btn").focus();'
                                  . 'return document.activeElement && document.activeElement.id',
                                    sub { $g{prefocus} = $_[0];
                                        $b->find('#btn', sub {
                                            my ($btn) = @_;
                                            $btn->click(sub {
                                                $b->script('return window.__c', sub {
                                                    $g{clicks} = $_[0];
                                                    $i->focus(sub {
                                                        $b->script(
                                                            'return document.activeElement && document.activeElement.id',
                                                            sub { $g{focused} = $_[0];
                                                                # submit LAST: native form.submit() bypasses onsubmit
                                                                # handlers and may navigate, so only assert the
                                                                # callback fires cleanly (no error) -- no side effect
                                                                # is read afterward.
                                                                $b->find('#f', sub {
                                                                    $_[0]->submit(sub {
                                                                        (undef, $g{submit_err}) = @_;
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
                    });
                });
            });
        });
    });
});
TWK::run_with_timeout(10);
is($g{typed},      'abc',    'type sets value');
is($g{typed2},     'abcdef', 'send_keys appends like type (alias behaves identically)');
is($g{cleared},    '',       'clear empties value');
is($g{prefocus},   'btn',    'precondition: button focused before testing focus() atom');
is($g{clicks},     1,        'click fired onclick handler');
is($g{focused},    'i',      'focus() moves document.activeElement to the element');
ok(!defined $g{submit_err}, 'submit invokes and calls back with no error');
$b->quit;

# Finding 3 (r12): type()/clear() must not fake success on an element with no
# native .value (a contenteditable, or anything else) by stamping a bogus
# expando .value that never touches the actual visible content -- and must
# error out (not silently no-op) on an element that is neither a native form
# control nor contenteditable.
my $b2 = EV::WebKit->new(window=>[300,200]);
my %h;
my $fixture2 = '<div id=ce contenteditable="true">orig</div><span id=plain>plain</span>';
$b2->load_html($fixture2, sub {
    $b2->find('#ce', sub {
        my ($ce) = @_;
        $ce->type('X', sub {
            my (undef, $err) = @_;
            $h{ce_type_err} = $err;
            $ce->html(sub { $h{ce_html_after_type} = $_[0];
                $ce->value(sub { $h{ce_value_after_type} = $_[0];
                    $ce->clear(sub {
                        my (undef, $err2) = @_;
                        $h{ce_clear_err} = $err2;
                        $ce->html(sub { $h{ce_html_after_clear} = $_[0];
                            $b2->find('#plain', sub {
                                my ($plain) = @_;
                                $plain->type('X', sub {
                                    my (undef, $err3) = @_;
                                    $h{plain_type_err} = $err3;
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
TWK::run_with_timeout(10);
like($h{ce_html_after_type}, qr/X/,  'type() on a contenteditable div really changes its content');
ok(!defined $h{ce_type_err},         'type() on a contenteditable div resolves with no error');
is($h{ce_value_after_type}, undef,   'type() on a contenteditable div does not fake a .value property');
is($h{ce_html_after_clear}, '',      'clear() on a contenteditable div empties its content');
ok(!defined $h{ce_clear_err},        'clear() on a contenteditable div resolves with no error');
like($h{plain_type_err} // '', qr/not editable/, 'type() on a plain (non-editable) span resolves with an error');
$b2->quit;

done_testing;
