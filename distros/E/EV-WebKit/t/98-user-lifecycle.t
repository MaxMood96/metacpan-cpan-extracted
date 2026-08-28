use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use Scalar::Util qw(weaken);
use EV; use EV::WebKit;

sub spin { for (1..4) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run } }

# a still-held handle must NOT keep its browser alive after the browser is
# dropped (the handle's browser ref is weak).
{
    my $h; my $wb;
    {
        my $b = EV::WebKit->new(window => [200,150]);
        weaken($wb = $b);
        $h = $b->add_user_script('window.__x = 1;');
    }   # $b dropped; $h still in scope
    spin();
    ok(!defined $wb, 'a dangling user-content handle does not keep the browser alive');
    my $ok = eval { $h->remove; 1 };
    ok($ok, 'handle->remove after the browser is gone is a safe no-op');
}

# remove() after quit() is a no-op, and quit() cleared the registry.
{
    my $b = EV::WebKit->new(window => [200,150]);
    my $h = $b->add_user_script('window.__x = 1;');
    $b->quit;
    my $ok = eval { $h->remove; 1 };
    ok($ok, 'handle->remove after quit() is a safe no-op');
    is($b->{_user_scripts}, undef, 'quit cleared the user-script registry');
}

# adding to an already-closed browser croaks (synchronous call, no callback to
# carry a 'browser closed' error, so croak rather than drop silently).
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->quit;
    eval { $b->add_user_script('window.__x=1') };
    like($@, qr/browser closed/, 'add_user_script on a closed browser croaks');
}

done_testing;
