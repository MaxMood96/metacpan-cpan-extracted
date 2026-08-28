use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# read is_visible('#h') after loading $url on $b.
sub visible_at {
    my ($b, $url) = @_;
    my $vis;
    $b->go($url, sub { $b->find('#h', sub { $_[0]->is_visible(sub { $vis = $_[0]; EV::break }) }) });
    TWK::run_with_timeout(15);
    return $vis;
}

# a user-level stylesheet beats the page's own CSS and hides the element;
# ->remove restores it on the next navigation.
{
    my $b = EV::WebKit->new(window => [200,150]);
    # the page rule is author-origin !important, so ONLY a user-origin !important
    # (level => 'user') can override it in the cascade. This makes the test
    # actually distinguish user from author: a user->author regression leaves the
    # element visible and fails here.
    $b->mock_scheme('sty', sub {
        ('<html><head><style>h1{display:block !important}</style></head><body><h1 id=h>Hi</h1></body></html>','text/html');
    });
    my $h = $b->add_user_style('h1 { display:none !important }', level => 'user');
    isa_ok($h, 'EV::WebKit::UserContent', 'add_user_style returns a handle');
    is(visible_at($b, 'sty://host/p'), 0, 'user-level style beat an author !important rule (proves level=user, not author)');
    $h->remove;
    ok(visible_at($b, 'sty://host/p2'), 'element visible again after the style was removed');
    $b->quit;
}

# a stylesheet honours allow/deny URL scoping (same plumbing as scripts).
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('syok', sub { ('<html><body><h1 id=h>Hi</h1></body></html>','text/html') });
    $b->mock_scheme('syno', sub { ('<html><body><h1 id=h>Hi</h1></body></html>','text/html') });
    $b->add_user_style('h1 { display:none !important }', level => 'user', allow => ['syok://host/*']);
    is(visible_at($b, 'syok://host/p'), 0, 'style applies on the allow-listed origin');
    ok(visible_at($b, 'syno://host/p'),    'style does NOT apply on a non-allowed origin');
    $b->quit;
}

# remove_all_user_styles clears every user style.
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('sty2', sub { ('<html><body><h1 id=h>Hi</h1></body></html>','text/html') });
    $b->add_user_style('h1 { display:none !important }', level => 'user');
    $b->remove_all_user_styles;
    ok(visible_at($b, 'sty2://host/p'), 'remove_all_user_styles cleared the hiding style');
    $b->quit;
}

# validation: bad level croaks.
{
    my $b = EV::WebKit->new(window => [200,150]);
    eval { $b->add_user_style('h1{}', level => 'important') };
    like($@, qr/level => 'important' is invalid/, 'bad level croaks');
    $b->quit;
}

done_testing;
