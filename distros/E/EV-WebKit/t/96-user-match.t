use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# navigate $url on $b, return window.__m (the flag an injected script would set).
sub flag_at {
    my ($b, $url) = @_;
    my ($got, $nav_err);
    $b->go($url, sub {
        my (undef, $err) = @_;
        return do { $nav_err = $err; EV::break } if $err;   # a nav failure must not pass as 'scoped out'
        $b->script('return window.__m || null', sub { $got = $_[0]; EV::break });
    });
    TWK::run_with_timeout(15);
    die "flag_at: navigation to $url failed: $nav_err" if defined $nav_err;
    return $got;
}

# allow: runs only on the allow-listed origin. WebKit URL patterns need a path
# component (scheme://host/*) and the page URL must carry a path.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('aok', sub { ('<html><body>aok</body></html>','text/html') });
    $b->mock_scheme('ano', sub { ('<html><body>ano</body></html>','text/html') });
    $b->add_user_script('window.__m = 1;', at => 'start', allow => ['aok://host/*']);
    is(flag_at($b, 'aok://host/p'), 1,     'allow: runs on the allow-listed origin');
    is(flag_at($b, 'ano://host/p'), undef, 'allow: does NOT run on a different origin');
    $b->quit;
}

# deny: runs everywhere EXCEPT the denied origin.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('dno', sub { ('<html><body>dno</body></html>','text/html') });
    $b->mock_scheme('dok', sub { ('<html><body>dok</body></html>','text/html') });
    $b->add_user_script('window.__m = 1;', at => 'start', deny => ['dno://host/*']);
    is(flag_at($b, 'dno://host/p'), undef, 'deny: does NOT run on the denied origin');
    is(flag_at($b, 'dok://host/p'), 1,     'deny: runs on a non-denied origin');
    $b->quit;
}

# allow + deny combined: deny wins WITHIN the allowed set.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('cmb', sub { ('<html><body>cmb</body></html>','text/html') });
    $b->add_user_script('window.__m = 1;', at => 'start',
        allow => ['cmb://host/*'], deny => ['cmb://host/blocked/*']);
    is(flag_at($b, 'cmb://host/ok/p'),      1,     'allow+deny: runs on an allowed, non-denied path');
    is(flag_at($b, 'cmb://host/blocked/p'), undef, 'allow+deny: deny wins within the allowed set');
    $b->quit;
}

# validation: allow/deny must be non-empty arrayrefs of defined plain strings,
# and unknown option keys are rejected (a typo must not silently fall back to a
# more permissive default -- e.g. a dropped world/allow/deny).
{
    my $b = EV::WebKit->new(window => [200,150]);
    eval { $b->add_user_script('x', allow => 'aok://host/*') };
    like($@, qr/allow => .* must be an arrayref/, 'non-arrayref allow croaks');
    eval { $b->add_user_script('x', deny => [ {} ]) };
    like($@, qr/deny entries must be/,            'ref deny entry croaks');
    eval { $b->add_user_script('x', deny => ['ok://host/*', undef]) };
    like($@, qr/deny entries must be/,            'undef deny entry croaks (GStrv-truncation guard)');
    eval { $b->add_user_script('x', deny => ['ok://host/*', '']) };
    like($@, qr/deny entries must be non-empty/,  'empty-string deny entry croaks');
    eval { $b->add_user_script('x', allow => []) };
    like($@, qr/allow => \[\] is empty/,          'empty allow croaks (empty list means match-all, not nothing)');
    eval { $b->add_user_script('x', wrld => 'isolated') };
    like($@, qr/unknown option.*wrld/,            'unknown option key croaks (no silent permissive fallback)');
    eval { $b->add_user_style('h1{}', world => 'main') };
    like($@, qr/unknown option.*world/,           'option valid for scripts but not styles is rejected');
    $b->quit;
}

done_testing;
