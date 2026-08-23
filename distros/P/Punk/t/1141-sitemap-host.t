#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use Punk ();
use Punk::Plugin::Sitemap;

# Sitemap's `base` defaulting to the application's `host`.
#
# The base is one fact about the application, and before `host` existed every
# plugin needing it asked for its own copy. Now it is declared once and the
# plugin picks it up - resolved at to_app rather than at the `plugin` line,
# because the two declarations may legitimately appear in either order.
#
# What has NOT changed: the value is configuration, never the request's Host
# header, and an application with neither still refuses to start.

# ---- plugin BEFORE host: the ordering claim ---------------------------------
{
    package OrderApp;
    use Punk;
    plugin 'Sitemap';                       # no base, and no host yet
    get '/' => sub { $_[0]->text('home') };
    host 'https://after.example';           # declared below the plugin
    package main;

    OrderApp->to_app;
    is(Punk::Plugin::Sitemap->_base(OrderApp->punk_app),
       'https://after.example',
       'a host declared BELOW the plugin line still supplies the base, '
     . 'because resolution happens at to_app and not at registration');
}

# ---- an explicit base wins ---------------------------------------------------
{
    package ExplicitApp;
    use Punk;
    host 'https://host.example';
    plugin 'Sitemap' => { base => 'https://explicit.example' };
    get '/' => sub { $_[0]->text('home') };
    package main;

    ExplicitApp->to_app;
    is(Punk::Plugin::Sitemap->_base(ExplicitApp->punk_app),
       'https://explicit.example',
       'an explicit base beats the host - the specific option wins over '
     . 'the app-wide default');
}

# ---- neither: still a boot croak, now at to_app -----------------------------
{
    my $body_err = do { local $@; eval {
        package NeitherApp;
        use Punk;
        plugin 'Sitemap';
        get '/' => sub { $_[0]->text('x') };
    }; $@ };
    is($body_err, '',
        'the plugin line itself no longer croaks - a host may still be '
      . 'coming');

    my $boot_err = do { local $@; eval { NeitherApp->to_app }; $@ };
    like($boot_err, qr/\Q`base` is required\E/,
        'but starting with neither still croaks, the way session refuses '
      . 'to start without a secret');
    like($boot_err, qr/somebody else's hostname/,
        'and the message still says WHY there is no request-Host fallback');
    like($boot_err, qr/`host`/,
        'and now names the keyword that fixes it');
}

# ---- a trailing slash on the host does not double up -------------------------
{
    package SlashApp;
    use Punk;
    host 'https://slash.example/';
    plugin 'Sitemap';
    get '/about' => sub { $_[0]->text('about') };
    package main;

    SlashApp->to_app;
    my $doc = Punk::Plugin::Sitemap->_doc(SlashApp->punk_app);
    like($doc, qr{<loc>https://slash\.example/about</loc>},
        'host + rooted path joins with one slash');
    unlike($doc, qr{slash\.example//},
        'never two - https://x//about is a different URL to a crawler');
}

# ---- robots.txt advertises the same origin ----------------------------------
{
    package RobotApp;
    use Punk;
    host 'https://robot.example';
    plugin 'Sitemap';
    get '/' => sub { $_[0]->text('home') };
    package main;

    RobotApp->to_app;
    my $robots = Punk::Plugin::Sitemap->_robots(RobotApp->punk_app);
    like($robots, qr{^Sitemap: https://robot\.example/sitemap\.xml$}m,
        'the Sitemap: line names the host, from the same resolved base');
}

# ---- the all-yml application -------------------------------------------------
# host and the plugin both from punk.yml: a deployment can point an
# application at its origin with no code change at all.
SKIP: {
    skip 'YAML::XS required for the config half', 1
        unless eval { require YAML::XS; 1 };

    my $dir = File::Temp->newdir;
    open my $fh, '>', "$dir/punk.yml" or die $!;
    print $fh <<'YAML';
host: https://yml.example
plugins:
  Sitemap: {}
YAML
    close $fh;

    {
        package YmlApp;
        use Punk;
        config "$dir/punk.yml";
        get '/' => sub { $_[0]->text('home') };
        package main;
    }
    YmlApp->to_app;
    is(Punk::Plugin::Sitemap->_base(YmlApp->punk_app),
       'https://yml.example',
       'host + Sitemap declared entirely in punk.yml resolves the base '
     . 'with zero Perl-side configuration');
}

done_testing;
