#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use lib "$Bin/../lib";

use Yote::Spiderpup;

my $www_dir = File::Spec->catdir($Bin, '..', 'www');

#
# Constructor: base_url_path
#

subtest 'base_url_path defaults to empty string' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir);
    is($sp->{base_url_path}, '', 'base_url_path defaults to empty string');
};

subtest 'base_url_path is set from constructor' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, base_url_path => '/myapp');
    is($sp->{base_url_path}, '/myapp', 'base_url_path set to /myapp');
};

#
# Constructor: webroot_dir
#

subtest 'webroot_dir defaults to www_dir/webroot' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir);
    my $expected = File::Spec->catdir($www_dir, 'webroot');
    is($sp->{webroot_dir}, $expected, 'webroot_dir defaults to www/webroot');
};

subtest 'webroot_dir is set from constructor' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, webroot_dir => $tmpdir);
    is($sp->{webroot_dir}, $tmpdir, 'webroot_dir set to custom path');
};

subtest 'js_dir is derived from webroot_dir' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, webroot_dir => $tmpdir);
    my $expected_js = File::Spec->catdir($tmpdir, 'js');
    is($sp->{js_dir}, $expected_js, 'js_dir is webroot_dir/js');
    ok(-d $expected_js, 'js_dir was created');
};

subtest 'custom webroot_dir does not affect pages_dir or recipes_dir' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, webroot_dir => $tmpdir);
    is($sp->{pages_dir}, File::Spec->catdir($www_dir, 'pages'), 'pages_dir still under www_dir');
    is($sp->{recipes_dir}, File::Spec->catdir($www_dir, 'recipes'), 'recipes_dir still under www_dir');
};

#
# base_url_path affects generated HTML
#

subtest 'build_html includes base_url_path in script paths' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, base_url_path => '/myapp');

    my $page_data = {
        title => 'Test Page',
        html  => '<p>hello</p>',
    };
    my $html = $sp->build_html($page_data, 'index');

    like($html, qr{src="/myapp/js/spiderpup\.js"}, 'spiderpup.js src has base_url_path prefix');
    like($html, qr{from '/myapp/js/pages/index\.js'}, 'page module import has base_url_path prefix');
    like($html, qr{SPIDERPUP_BASE_PATH = '/myapp'}, 'SPIDERPUP_BASE_PATH set to base_url_path');
};

subtest 'build_html without base_url_path uses root paths' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir);

    my $page_data = {
        title => 'Test Page',
        html  => '<p>hello</p>',
    };
    my $html = $sp->build_html($page_data, 'index');

    like($html, qr{src="/js/spiderpup\.js"}, 'spiderpup.js src at root');
    like($html, qr{from '/js/pages/index\.js'}, 'page module import at root');
    like($html, qr{SPIDERPUP_BASE_PATH = ''}, 'SPIDERPUP_BASE_PATH is empty');
};

#
# base_url_path affects SSR link rendering
#

subtest 'link tag SSR renders with base_url_path' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, base_url_path => '/myapp');

    my $structure = {
        children => [
            {
                tag        => 'link',
                attributes => { to => '/about' },
                children   => [ { content => 'About' } ],
            },
        ],
    };

    my $html = $sp->render_ssr_body($structure, {}, {});
    like($html, qr{href="/myapp/about\.html"}, 'link href includes base_url_path');
    like($html, qr{>About<}, 'link text rendered');
};

subtest 'link tag SSR renders without base_url_path' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir);

    my $structure = {
        children => [
            {
                tag        => 'link',
                attributes => { to => '/about' },
                children   => [ { content => 'About' } ],
            },
        ],
    };

    my $html = $sp->render_ssr_body($structure, {}, {});
    like($html, qr{href="/about\.html"}, 'link href has no prefix');
};

subtest 'link to root with base_url_path' => sub {
    my $sp = Yote::Spiderpup->new(www_dir => $www_dir, base_url_path => '/app');

    my $structure = {
        children => [
            {
                tag        => 'link',
                attributes => { to => '/' },
                children   => [ { content => 'Home' } ],
            },
        ],
    };

    my $html = $sp->render_ssr_body($structure, {}, {});
    like($html, qr{href="/app/"}, 'root link includes base_url_path');
};

done_testing();
