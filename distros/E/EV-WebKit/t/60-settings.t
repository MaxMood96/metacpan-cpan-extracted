use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# ctor-time options: user_agent, title, devtools
my $b = EV::WebKit->new(window=>[300,200], user_agent=>'UA-init/1.0', title=>'My Window', devtools=>1);

is($b->user_agent, 'UA-init/1.0', 'ctor user_agent applied');
is($b->{win}->get_title, 'My Window', 'ctor title applied to window');
ok($b->{view}->get_settings->get('enable-developer-extras'), 'ctor devtools=>1 enables developer extras');
ok(EV::WebKit->can('show_devtools'), 'show_devtools method exists');

# set_user_agent + settings(), verified for real via a page load/script round-trip
$b->set_user_agent('UA-set/2.0');
# Set it OFF, not on: enable-javascript DEFAULTS to true, so asserting it is
# true after settings({enable_javascript => 1}) passes with settings() stubbed
# out entirely.
$b->settings({ enable_javascript => 0 });
ok(!$b->{view}->get_settings->get('enable-javascript'), 'settings() underscore->hyphen applied enable-javascript');
$b->settings({ enable_javascript => 1 });   # the rest of this file needs it back

my $seen;
$b->load_html('<title>t</title>', sub {
    $b->script('return navigator.userAgent', sub { $seen = $_[0]; EV::break });
});
TWK::run_with_timeout(10);
is($seen, 'UA-set/2.0', 'navigator.userAgent reflects set_user_agent');

# Finding 4 (r12) + minor: bad input to settings()/set_user_agent() must
# croak cleanly and consistently instead of dying with a raw GLib/strict-refs
# error (settings) or silently accepting a reference (set_user_agent).
eval { $b->settings({ bogus_key_xyz => 1 }) };
like($@, qr/cannot set|unknown|bogus/, 'settings() with an unknown key croaks cleanly');

eval { $b->settings('x') };
like($@, qr/hash reference/, 'settings() with a non-hashref arg croaks cleanly');

eval { $b->set_user_agent({}) };
like($@, qr/expected a string/, 'set_user_agent() rejects a reference');

done_testing;
