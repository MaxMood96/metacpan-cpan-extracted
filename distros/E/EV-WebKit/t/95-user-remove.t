use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# handle->remove stops injection from the NEXT navigation; a second remove()
# is a harmless no-op.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('rem', sub { ('<html><body>rem</body></html>','text/html') });
    my $h = $b->add_user_script('window.__rem = 1;', at => 'start');
    my %g;
    $b->go('rem://host/1', sub {
        $b->script('return window.__rem || null', sub {
            $g{before} = $_[0];
            # assert idempotency DIRECTLY (not via the timeout): a throw from the
            # second remove would otherwise only surface as a timeout failure.
            $g{no_throw} = eval { $h->remove; $h->remove; 1 } ? 1 : 0;
            $g{ret}      = $h->remove;      # returns the handle (chainable), still a no-op
            $b->go('rem://host/2', sub {
                $b->script('return window.__rem || null', sub { $g{after} = $_[0]; EV::break });
            });
        });
    });
    TWK::run_with_timeout(20);
    is($g{before},   1,     'user script injected before remove');
    ok($g{no_throw},        'double-remove is a no-op that does not throw');
    is($g{ret},      $h,    'remove() returns the handle (chainable) even after removal');
    is($g{after},    undef, 'no injection after remove');
    $b->quit;
}

# remove_all_user_scripts removes the caller's scripts but must NOT wipe the
# module's own BOOT: find() (which needs the isolated-world registry) still works.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('clob', sub { ('<html><body><div id=x>X</div></body></html>','text/html') });
    $b->add_user_script('window.__a = 1;', at => 'start');
    $b->add_user_script('window.__b = 1;', at => 'start');
    $b->remove_all_user_scripts;
    my %g;
    $b->go('clob://host/p', sub {
        $b->script('return (window.__a||0) + (window.__b||0)', sub {
            $g{sum} = $_[0];
            $b->find('#x', sub { $g{el} = $_[0]; EV::break });
        });
    });
    TWK::run_with_timeout(20);
    is($g{sum}, 0, 'remove_all_user_scripts removed every user script');
    ok($g{el}, 'find() still works -- BOOT was NOT clobbered by remove_all_user_scripts')
        or diag('remove_all_user_scripts must loop remove_script over the user registry, not call remove_all_scripts');
    $b->quit;
}

# remove_all_user_scripts with nothing added is a safe no-op.
{
    my $b = EV::WebKit->new(window => [200,150]);
    my $ok = eval { $b->remove_all_user_scripts; 1 };
    ok($ok, 'remove_all_user_scripts with no scripts is a no-op');
    $b->quit;
}

done_testing;
