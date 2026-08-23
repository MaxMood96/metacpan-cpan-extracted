#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use Punk ();
use Punk::Plugin::Sitemap ();

# The `favicon` keyword: GET /favicon.ico from bytes frozen at to_app.
#
# A browser and a search engine's favicon crawler both ask at the site ROOT,
# where a /static mount does not answer - so every application was writing
# the same hand-rolled route: send_file, a Cache-Control, sitemap => 0. This
# keyword is that route, and these tests pin the parts the boilerplate got
# right: the caching headers, the 304, and staying out of the sitemap.

my $dir = File::Temp->newdir;

sub write_file {
    my ($name, $bytes) = @_;
    open my $fh, '>', "$dir/$name" or die $!;
    binmode $fh;
    print $fh $bytes;
    close $fh;
    return "$dir/$name";
}

my $ICO = "\x00\x00\x01\x00" . "not really an icon, but bytes are bytes";
my $ico_path = write_file('favicon.ico', $ICO);
my $png_path = write_file('mark.png', "\x89PNG\r\n\x1a\nfake");

sub hit {
    my ($app, $path, %env) = @_;
    open my $in, '<', \'';
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => $path,
        QUERY_STRING   => '',
        SERVER_NAME    => 'localhost', SERVER_PORT => 80,
        HTTP_HOST      => 'localhost', 'psgi.url_scheme' => 'http',
        'psgi.input'   => $in,
        %env,
    });
    my $body = ref $res->[2] eq 'ARRAY' ? join('', @{ $res->[2] }) : '';
    return ($res->[0], $body, { @{ $res->[1] } });
}

# ---- the 200: bytes, type, length, caching ----------------------------------
{
    package IcoApp;
    use Punk;
    favicon $ico_path;
    get '/' => sub { $_[0]->text('home') };
    package main;

    my $app = IcoApp->to_app;
    my ($st, $body, $h) = hit($app, '/favicon.ico');

    is($st, 200, 'the root /favicon.ico answers');
    is($body, $ICO, 'with exactly the frozen bytes');
    is($h->{'Content-Type'}, 'image/x-icon',
        'the content type follows the extension');
    is($h->{'Content-Length'}, length($ICO), 'and the length is declared');
    is($h->{'Cache-Control'}, 'public, max-age=86400',
        'a freshness lifetime by default - the header every hand-rolled '
      . 'version was adding by hand');
    like($h->{ETag} // '', qr/\A"[0-9a-f]{16}"\z/,
        'a strong content-derived ETag, so every worker in a pool agrees');

    # ---- the 304 ------------------------------------------------------------
    my ($st2, $body2, $h2) = hit($app, '/favicon.ico',
                                 HTTP_IF_NONE_MATCH => $h->{ETag});
    is($st2, 304, 'a request carrying the tag back is not re-sent the body');
    is($body2, '', 'a 304 has no body');
    ok(!exists $h2->{'Content-Length'},
        'and no Content-Length - a bodyless response that claims a length '
      . 'is how a client is taught to wait');
    ok(!exists $h2->{'Content-Type'}, 'no Content-Type either');
    is($h2->{ETag}, $h->{ETag}, 'the validator goes back');
    is($h2->{'Cache-Control'}, 'public, max-age=86400',
        'and so does the freshness lifetime, so the cache entry stays alive');

    my ($st3) = hit($app, '/favicon.ico',
                    HTTP_IF_NONE_MATCH => '"0000000000000000"');
    is($st3, 200, 'a stale tag gets the full 200');
}

# ---- max_age ----------------------------------------------------------------
{
    package AgeApp;
    use Punk;
    favicon $ico_path, max_age => 3600;
    package main;

    my (undef, undef, $h) = hit(AgeApp->to_app, '/favicon.ico');
    is($h->{'Cache-Control'}, 'public, max-age=3600',
        'max_age names the lifetime');
}

# ---- content type by extension ----------------------------------------------
{
    package PngApp;
    use Punk;
    favicon $png_path;
    package main;

    my ($st, $body, $h) = hit(PngApp->to_app, '/favicon.ico');
    is($st, 200, 'a .png serves at /favicon.ico');
    is($h->{'Content-Type'}, 'image/png', 'as itself');
}

# ---- a missing file croaks at BOOT, not at the keyword ----------------------
# The keyword only records the path; to_app slurps. That split is the point:
# a missing icon should stop a deploy, not 404 for as long as nobody
# notices, and it is also what makes the croak land at the same moment as
# every other boot failure rather than depending on declaration order.
{
    my $decl_err = do { local $@; eval {
        package MissingApp;
        use Punk;
        MissingApp->punk_app->favicon("$dir/not-there.ico");
    }; $@ };
    is($decl_err, '', 'the keyword line does not touch the filesystem');

    my $boot_err = do { local $@; eval { MissingApp->to_app }; $@ };
    like($boot_err, qr/favicon .* cannot be read/,
        'to_app croaks on a file it cannot read - fails at boot, not at 3am');
}

# ---- out of the sitemap ------------------------------------------------------
{
    package MapApp;
    use Punk;
    use Punk::Plugin::Sitemap;
    plugin 'Sitemap' => { base => 'https://example.com' };
    get '/' => sub { $_[0]->text('home') };
    favicon $ico_path;
    package main;

    MapApp->to_app;
    my %in = map { $_ => 1 }
             Punk::Plugin::Sitemap->_paths(MapApp->punk_app);
    ok($in{'/'}, 'an ordinary route is listed (so the exclusion below is '
                . 'a filter, not an empty document)');
    ok(!$in{'/favicon.ico'},
        'the favicon route is not - an icon is not a page');
}

# ---- adopting the keyword means deleting the hand-rolled route ---------------
{
    my $err = do { local $@; eval {
        package BothApp;
        use Punk;
        get '/favicon.ico' => sub { $_[0]->text('old hand-rolled route') };
        BothApp->punk_app->favicon($ico_path);
        BothApp->to_app;
    }; $@ };
    like($err, qr/duplicate route/,
        'keyword plus hand-rolled route croaks at boot rather than letting '
      . 'one of them silently win');
}

# ---- from punk.yml ----------------------------------------------------------
SKIP: {
    skip 'YAML::XS required for the config half', 3
        unless eval { require YAML::XS; 1 };

    write_file('punk.yml', "favicon: $ico_path\n");
    {
        package YmlScalarApp;
        use Punk;
        config "$dir/punk.yml";
        package main;
    }
    my ($st) = hit(YmlScalarApp->to_app, '/favicon.ico');
    is($st, 200, 'a scalar favicon block is the path');

    write_file('punk.yml',
               "favicon:\n  path: $ico_path\n  max_age: 60\n");
    {
        package YmlMapApp;
        use Punk;
        config "$dir/punk.yml";
        package main;
    }
    my (undef, undef, $h) = hit(YmlMapApp->to_app, '/favicon.ico');
    is($h->{'Cache-Control'}, 'public, max-age=60',
        'the mapping form carries max_age');

    write_file('punk.yml', "favicon:\n  max_age: 60\n");
    my $err = do { local $@; eval {
        package YmlBadApp;
        use Punk;
        config "$dir/punk.yml";
    }; $@ };
    like($err, qr/config favicon block needs a path/,
        'a mapping without a path croaks');
}

done_testing;
