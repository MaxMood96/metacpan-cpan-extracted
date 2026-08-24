#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;
use File::Temp ();

# The `layout` render override: a page without its wrapper, or inside a
# different one.
#
# Template::Stencil has taken { wrapper => $name | undef } per render since
# its C ABI arrived, and Punk::View::Stencil passed it through untouched -
# but Punk::Views read only status, type and engine off the overrides and
# dropped everything else on the floor. So `layout => undef` rendered WITH
# the layout and said nothing, and the one production app that needed a
# bare panel built a second Stencil engine per worker to get one - losing
# the CSP nonce, the I18n catalogue and the application's filters on the
# way, because none of those reach a private engine.
#
# Three things are pinned here: the override reaches the engine, an override
# Punk does not know croaks instead of vanishing, and the per-request
# bindings are present in a bare render exactly as in a page.

BEGIN {
    eval { require Template::Stencil; 1 }
        or plan skip_all => 'Template::Stencil required';
}

my $dir = File::Temp->newdir;
sub write_tmpl {
    my ($name, $body) = @_;
    open my $fh, '>:raw', "$dir/$name.tmpl" or die $!;
    print $fh $body;
    close $fh;
}
write_tmpl(layout     => '<html>{% content %}</html>');
write_tmpl(mail       => 'MAIL[{% content %}]');
write_tmpl(hello      => '<p>{% name | shout %}</p>');
write_tmpl(hascontent => 'X{% content %}');
write_tmpl(nonce      => '<script nonce="{% csp_nonce %}"></script>');
write_tmpl(greet      => '{% locale.plain %}');

# An engine that records what render was called with, to prove the
# contract: no third argument unless a layout was given, and exactly
# { wrapper => ... } when one was.
{
    package Recording::View;
    our @CALLS;
    sub new    { bless {}, $_[0] }
    sub render { my ($self, @args) = @_; push @CALLS, [@args]; "rec:$args[0]" }
}

{
    package LayoutApp;
    use Punk;
    views Stencil => {
        template_dir => "$dir",
        wrapper      => 'layout.tmpl',
        filters      => { shout => sub { uc($_[0] // q{}) } },
    };
    views '+Recording::View' => {};
    get '/page'     => sub { $_[0]->render('hello', { name => 'n' }) };
    get '/bare'     => sub { $_[0]->render('hello', { name => 'n' }, layout => undef) };
    get '/mail'     => sub { $_[0]->render('hello', { name => 'n' }, layout => 'mail') };
    get '/mailext'  => sub { $_[0]->render('hello', { name => 'n' }, layout => 'mail.tmpl') };
    get '/typo'     => sub { $_[0]->render('hello', { name => 'n' }, Layout => undef) };
    get '/odd'      => sub { $_[0]->render('hello', { name => 'n' }, 'layout') };
    get '/content'  => sub { $_[0]->render('hascontent', {}, layout => undef) };
    get '/missing'  => sub { $_[0]->render('hello', { name => 'n' }, layout => 'nope') };
    get '/rec'      => sub { $_[0]->render('t', {}, engine => 'Recording::View') };
    get '/rec-bare' => sub { $_[0]->render('t', {}, engine => 'Recording::View',
                                                     layout => undef) };
    get '/rec-mail' => sub { $_[0]->render('t', {}, engine => 'Recording::View',
                                                     layout => 'mail') };
    get '/frag'        => sub { $_[0]->fragment('hello', { name => 'n' }) };
    get '/frag-nodata' => sub { $_[0]->fragment('hello') };
    get '/frag-status' => sub { $_[0]->fragment('hello', { name => 'n' }, status => 206) };
    get '/frag-cc'     => sub { my ($c) = @_;
                                $c->header('Cache-Control' => 'public, max-age=60');
                                $c->header('X-Panel' => 'logs');
                                $c->fragment('hello', { name => 'n' }) };
    get '/frag-layout' => sub { $_[0]->fragment('hello', { name => 'n' }, layout => 'mail') };
    package main;
}

my $app = LayoutApp->to_app;

# ---- the override reaches the engine ----------------------------------------
is(hit($app, path => '/page')->[2][0], '<html><p>N</p></html>',
    'no override: the configured wrapper, as before');
{
    my $r = hit($app, path => '/bare');
    is($r->[0], 200, 'layout => undef renders');
    is($r->[2][0], '<p>N</p>', 'without the wrapper');
    my %h = @{ $r->[1] };
    is($h{'Content-Type'}, 'text/html; charset=utf-8',
        'still html - a fragment is html without the chrome');
    is($h{'Content-Length'}, length $r->[2][0], 'content length is the bare length');
}
is(hit($app, path => '/mail')->[2][0], 'MAIL[<p>N</p>]',
    'layout => name renders inside that wrapper instead');
is(hit($app, path => '/mailext')->[2][0], 'MAIL[<p>N</p>]',
    'the name may carry its extension, as the views keyword spells it');
like(hit($app, path => '/bare')->[2][0], qr/N/,
    'the application filters still run in a bare render - one engine, not two');

# ---- an unknown override croaks instead of vanishing ------------------------
{
    my $r = hit($app, path => '/typo');
    is($r->[0], 500, 'an override Punk does not know is an error');
    like($r->[2][0], qr/unknown override 'Layout'/, 'naming the key');
    like($r->[2][0], qr/status, type, engine, layout/, 'and listing the four it knows');
}
{
    my $r = hit($app, path => '/odd');
    is($r->[0], 500, 'a dangling override name is an error');
    like($r->[2][0], qr/name => value pairs/, 'saying what the shape is');
}

# ---- the engine's own errors still surface ----------------------------------
{
    my $r = hit($app, path => '/content');
    is($r->[0], 500, 'a template holding {% content %} rendered bare is an error');
    like($r->[2][0], qr/hascontent\.tmpl.*content/, 'and the error names the template');
}
{
    my $r = hit($app, path => '/missing');
    is($r->[0], 500, 'a layout that does not exist is an error');
    like($r->[2][0], qr/cannot find template 'nope'/, 'naming the layout');
}

# ---- the engine contract: a third argument only when asked ------------------
{
    local @Recording::View::CALLS;
    hit($app, path => '/rec');
    is(scalar @{ $Recording::View::CALLS[0] }, 2,
        'no layout given: the engine sees the two-argument call it always did');
}
{
    local @Recording::View::CALLS;
    hit($app, path => '/rec-bare');
    my $call = $Recording::View::CALLS[0];
    is(scalar @$call, 3, 'layout => undef: a third argument');
    is_deeply($call->[2], { wrapper => undef },
        'which is { wrapper => undef } - the engine word for the framework word');
}
{
    local @Recording::View::CALLS;
    hit($app, path => '/rec-mail');
    is_deeply($Recording::View::CALLS[0][2], { wrapper => 'mail' },
        'layout => name: { wrapper => name }');
}

# ---- $c->fragment: render with an opinion -----------------------------------
{
    my $r = hit($app, path => '/frag');
    is($r->[0], 200, 'fragment renders');
    is($r->[2][0], '<p>N</p>', 'bare, through the application engine and its filters');
    my %h = @{ $r->[1] };
    is($h{'Cache-Control'}, 'private, no-store',
        'a fragment is one user\'s data: private, no-store by default');
    is($h{'Content-Type'}, 'text/html; charset=utf-8', 'html');
    is($h{'Content-Length'}, length $r->[2][0], 'length');
    my @cc = grep { $_ eq 'Cache-Control' } @{ $r->[1] };
    is(scalar @cc, 1, 'exactly one Cache-Control header');
}
is(hit($app, path => '/frag-nodata')->[2][0], '<p></p>',
    'the data hashref is optional, as it is for render');
is(hit($app, path => '/frag-status')->[0], 206,
    'the other render overrides pass through');
{
    my $r = hit($app, path => '/frag-cc');
    my %h = @{ $r->[1] };
    is($h{'Cache-Control'}, 'private, no-store',
        'a Cache-Control already pending on the context is replaced, not doubled');
    my @cc = grep { $_ eq 'Cache-Control' } @{ $r->[1] };
    is(scalar @cc, 1, 'still exactly one');
    is($h{'X-Panel'}, 'logs', 'other pending headers fold in untouched');
}
{
    my $r = hit($app, path => '/frag-layout');
    is($r->[0], 500, 'fragment with a layout is an error');
    like($r->[2][0], qr/a fragment has no layout/, 'saying to use render');
}

# ---- and through Punk::Test, the way an application test reads -------------
{
    require Punk::Test;
    my $t = Punk::Test->new($app);
    $t->get_ok('/frag')
      ->status_is(200)
      ->header_is('Cache-Control' => 'private, no-store')
      ->content_unlike(qr/<html/)
      ->content_like(qr{\A<p>N</p>\z});
}

# ---- the per-request bindings are present in a bare render ------------------
# This is the bug the second-engine workaround carries: a panel rendered
# through a private Template::Stencil has no nonce and no catalogue.
{
    package NonceApp;
    use Punk;
    plugin 'CSP';
    views Stencil => { template_dir => "$dir", wrapper => 'layout.tmpl' };
    get '/frag' => sub { $_[0]->render('nonce', {}, layout => undef) };
    package main;

    my $r = hit(NonceApp->to_app, path => '/frag');
    my %h = @{ $r->[1] };
    my ($policy_nonce) = ($h{'Content-Security-Policy'} // '') =~ /'nonce-([^']+)'/;
    ok($policy_nonce, 'the CSP policy carries a nonce');
    is($r->[2][0], qq{<script nonce="$policy_nonce"></script>},
        'and a bare render sees the same nonce the policy does');
    unlike($r->[2][0], qr/<html/, 'with no wrapper around it');
}
{
    my $cat = File::Temp->newdir;
    open my $fh, '>:raw', "$cat/en.json" or die $!;
    print $fh '{ "plain": "just words" }';
    close $fh;

    eval qq{
        package LocaleApp;
        use Punk;
        plugin 'I18n' => { dir => '$cat', default => 'en' };
        views Stencil => { template_dir => '$dir', wrapper => 'layout.tmpl' };
        get '/frag' => sub { \$_[0]->render('greet', {}, layout => undef) };
        1;
    } or die $@;

    my $r = hit(LocaleApp->to_app, path => '/frag');
    is($r->[2][0], 'just words',
        'the I18n catalogue resolves in a bare render, with no wrapper');
}

done_testing();
