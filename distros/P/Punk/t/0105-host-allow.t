#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use Punk ();
use Punk::Plugin::Sitemap ();

# The host allowlist: which request hosts may stand in for the canonical one.
#
# One application serving several tenants by Host header has an origin per
# request, and the request's Host is attacker-supplied. The allowlist is what
# turns that header into configuration: $c->origin is the request's scheme
# and host ONLY when the host is the canonical one or matches an entry, and
# the canonical origin otherwise. These tests are mostly about what is NOT
# reflected, because that is the property that matters.

our $RUNS = 0;

sub hit {
    my ($app, $path, %env) = @_;
    open my $in, '<', \'';
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => $path,
        QUERY_STRING   => '',
        SERVER_NAME    => 'localhost', SERVER_PORT => 443,
        HTTP_HOST      => 'example.com', 'psgi.url_scheme' => 'https',
        'psgi.input'   => $in,
        %env,
    });
    my $body = ref $res->[2] eq 'ARRAY' ? join('', @{ $res->[2] }) : '';
    return ($res->[0], $body, { @{ $res->[1] } });
}

{
    package AllowApp;
    use Punk;
    use Punk::Plugin::Sitemap;

    host 'https://example.com',
         allow => [ '*.example.com', 'Shop.TLD', 'dev.local:5000' ];
    plugin 'Sitemap';

    get '/origin'  => sub { $_[0]->text($_[0]->origin // 'undef') };
    get '/allowed' => sub { $_[0]->text($_[0]->host_allowed ? 1 : 0) };
    get '/about'   => sub { $_[0]->text('about') };

    sitemap users => sub { $main::RUNS++; return ('/u/1') };

    package main;
}
my $app = AllowApp->to_app;

sub origin_for {
    my (%env) = @_;
    my (undef, $o) = hit($app, '/origin', %env);
    my (undef, $a) = hit($app, '/allowed', %env);
    return ($o, $a);
}

# ---- the canonical host, and the allowlist ----------------------------------
is_deeply([ origin_for(HTTP_HOST => 'example.com') ],
          [ 'https://example.com', 1 ],
          'the canonical host is its own origin, and needs no entry');

is_deeply([ origin_for(HTTP_HOST => 'acme.example.com') ],
          [ 'https://acme.example.com', 1 ],
          'a host under a *. entry is handed back as the origin');

is_deeply([ origin_for(HTTP_HOST => 'deep.acme.example.com') ],
          [ 'https://deep.acme.example.com', 1 ],
          'and so is one several labels deep - *. is a suffix, not one label');

is_deeply([ origin_for(HTTP_HOST => 'ACME.Example.COM') ],
          [ 'https://acme.example.com', 1 ],
          'matching is case-insensitive and the origin comes back lowercased');

is_deeply([ origin_for(HTTP_HOST => 'shop.tld') ],
          [ 'https://shop.tld', 1 ],
          'an exact entry matches (the entry was declared in mixed case)');

is_deeply([ origin_for(HTTP_HOST => 'shop.tld:8443') ],
          [ 'https://shop.tld:8443', 1 ],
          'an entry naming no port accepts any port, and the port is kept');

is_deeply([ origin_for(HTTP_HOST => 'dev.local:5000',
                       'psgi.url_scheme' => 'http') ],
          [ 'http://dev.local:5000', 1 ],
          'an entry naming a port matches that port, and the scheme is the '
        . 'request\'s');

# ---- what is never reflected -------------------------------------------------
is_deeply([ origin_for(HTTP_HOST => 'evil.example') ],
          [ 'https://example.com', 0 ],
          'an unknown host gets the canonical origin, not itself');

is_deeply([ origin_for(HTTP_HOST => 'example.com.evil.net') ],
          [ 'https://example.com', 0 ],
          'a host that merely STARTS with the canonical one is unknown');

is_deeply([ origin_for(HTTP_HOST => 'notexample.com') ],
          [ 'https://example.com', 0 ],
          'and so is one that merely ends with it - the match is whole');

is_deeply([ origin_for(HTTP_HOST => 'example.com.example.com.evil') ],
          [ 'https://example.com', 0 ],
          'a *. suffix has to be the END of the host');

is_deeply([ origin_for(HTTP_HOST => 'dev.local:6000',
                       'psgi.url_scheme' => 'http') ],
          [ 'https://example.com', 0 ],
          'the wrong port against an entry that names one is unknown');

is_deeply([ origin_for(HTTP_HOST => 'dev.local',
                       'psgi.url_scheme' => 'http') ],
          [ 'https://example.com', 0 ],
          'and so is no port at all against that entry');

is_deeply([ origin_for(HTTP_HOST => 'acme.example.com/evil') ],
          [ 'https://example.com', 0 ],
          'a Host with a slash in it is not a hostname and gets the canonical');

is_deeply([ origin_for(HTTP_HOST => 'acme.example.com:80x') ],
          [ 'https://example.com', 0 ],
          'nor is one with a port that is not digits');

is_deeply([ origin_for(HTTP_HOST => "acme.example.com\r\nX: y") ],
          [ 'https://example.com', 0 ],
          'control bytes never reach the origin');

is_deeply([ origin_for(HTTP_HOST => '') ],
          [ 'https://example.com', 0 ],
          'no Host at all is the canonical origin');

is_deeply([ origin_for(HTTP_HOST => 'acme.example.com',
                       'psgi.url_scheme' => 'gopher') ],
          [ 'https://acme.example.com', 1 ],
          'a scheme that is not http or https falls back to the canonical\'s');

# ---- the sitemap and robots, per tenant ------------------------------------
{
    my (undef, $doc) = hit($app, '/sitemap.xml', HTTP_HOST => 'acme.example.com');
    like($doc, qr{<loc>https://acme\.example\.com/about</loc>},
        'an allowlisted tenant gets a sitemap naming itself');
    like($doc, qr{<loc>https://acme\.example\.com/u/1</loc>},
        'including the dynamic sections');
    unlike($doc, qr{<loc>https://example\.com/},
        'and nothing naming the canonical host');

    my (undef, $canon) = hit($app, '/sitemap.xml');
    like($canon, qr{<loc>https://example\.com/about</loc>},
        'the canonical host gets the frozen canonical document');

    my (undef, $evil) = hit($app, '/sitemap.xml', HTTP_HOST => 'evil.example');
    like($evil, qr{<loc>https://example\.com/about</loc>},
        'an unknown host gets the canonical document too');
    unlike($evil, qr{evil}, 'and its name appears nowhere in it');

    (undef, my $other) = hit($app, '/sitemap.xml', HTTP_HOST => 'shop.tld');
    like($other, qr{<loc>https://shop\.tld/about</loc>}, 'a second tenant');

    is($RUNS, 1,
        'the dynamic section ran ONCE for four hosts - tenants render from '
      . 'the entries the build kept, not by running the section again');

    my (undef, $rb) = hit($app, '/robots.txt', HTTP_HOST => 'acme.example.com');
    like($rb, qr{^Sitemap: https://acme\.example\.com/sitemap\.xml$}m,
        'robots.txt advertises the tenant\'s own sitemap');
    (undef, $rb) = hit($app, '/robots.txt', HTTP_HOST => 'evil.example');
    like($rb, qr{^Sitemap: https://example\.com/sitemap\.xml$}m,
        'and the canonical one to an unknown host');
}

# ---- no path in an origin, no host means undef ------------------------------
{
    package PathApp;
    use Punk;
    host 'https://example.com/app', allow => [ 'x.example' ];
    get '/origin' => sub { $_[0]->text($_[0]->origin // 'undef') };
    package main;

    my $papp = PathApp->to_app;
    my (undef, $o) = hit($papp, '/origin', HTTP_HOST => 'x.example');
    is($o, 'https://x.example', 'an origin has no path');
    (undef, $o) = hit($papp, '/origin', HTTP_HOST => 'nope.example');
    is($o, 'https://example.com',
        'and the canonical fallback is the canonical ORIGIN, its path dropped');
}

{
    package NoHostApp;
    use Punk;
    get '/origin'  => sub { $_[0]->text($_[0]->origin // 'undef') };
    get '/allowed' => sub { $_[0]->text($_[0]->host_allowed ? 1 : 0) };
    package main;

    my $napp = NoHostApp->to_app;
    my (undef, $o) = hit($napp, '/origin', HTTP_HOST => 'anything.example');
    is($o, 'undef',
        'with no host declared there is nothing safe to say, so undef - '
      . 'never the header');
    (undef, my $a) = hit($napp, '/allowed', HTTP_HOST => 'anything.example');
    is($a, '0', 'and nothing is allowed');
}

# ---- what the keyword refuses ------------------------------------------------
my $err = do { local $@; eval {
    package BadAllow1; use Punk;
    host 'https://example.com', allow => 'x.example';
}; $@ };
like($err, qr/host allow needs an arrayref/, 'allow wants an arrayref');

$err = do { local $@; eval {
    package BadAllow2; use Punk;
    host 'https://example.com', allow => [ 'https://x.example' ];
}; $@ };
like($err, qr/is not a hostname/,
    'an entry with a scheme croaks - entries are hostnames, not origins');

$err = do { local $@; eval {
    package BadAllow3; use Punk;
    host 'https://example.com', allow => [ 'a.*.example' ];
}; $@ };
like($err, qr/is not a hostname/, 'a * anywhere but the front croaks');

$err = do { local $@; eval {
    package BadAllow4; use Punk;
    host 'https://example.com', allow => [ '' ];
}; $@ };
like($err, qr/host allow entries are hostnames/, 'an empty entry croaks');

$err = do { local $@; eval {
    package BadAllow5; use Punk;
    host 'https://example.com', allow => [ 'x.example:port' ];
}; $@ };
like($err, qr/is not a hostname/, 'a port that is not digits croaks');

$err = do { local $@; eval {
    package BadOpt; use Punk;
    host 'https://example.com', allowed => [ 'x.example' ];
}; $@ };
like($err, qr/host does not understand 'allowed'/,
    'an option it does not know croaks, so a typo cannot silently allow '
  . 'nothing');

# ---- last write wins wholly --------------------------------------------------
{
    package TwiceApp;
    use Punk;
    host 'https://a.example', allow => [ '*.a.example' ];
    host 'https://a.example';
    get '/allowed' => sub { $_[0]->text($_[0]->host_allowed ? 1 : 0) };
    package main;

    my (undef, $a) = hit(TwiceApp->to_app, '/allowed', HTTP_HOST => 'x.a.example');
    is($a, '0',
        'a second host declaration without allow drops the allowlist - '
      . 'the keyword is declarative, not additive');
}

# ---- from punk.yml ----------------------------------------------------------
SKIP: {
    skip 'YAML::XS required for the config half', 3
        unless eval { require YAML::XS; 1 };

    my $dir = File::Temp->newdir;
    open my $fh, '>', "$dir/punk.yml" or die $!;
    print $fh <<'YAML';
host:
  origin: https://yml.example
  allow:  [ '*.yml.example', other.tld ]
YAML
    close $fh;
    {
        package YmlApp;
        use Punk;
        config "$dir/punk.yml";
        get '/origin' => sub { $_[0]->text($_[0]->origin // 'undef') };
        package main;
    }
    my $yapp = YmlApp->to_app;
    my (undef, $o) = hit($yapp, '/origin', HTTP_HOST => 't.yml.example');
    is($o, 'https://t.yml.example', 'the mapping form carries the allowlist');
    (undef, $o) = hit($yapp, '/origin', HTTP_HOST => 'other.tld');
    is($o, 'https://other.tld', 'with more than one entry');

    open $fh, '>', "$dir/punk.yml" or die $!;
    print $fh "host:\n  origin: https://one.example\n  allow: only.tld\n";
    close $fh;
    {
        package YmlOneApp;
        use Punk;
        config "$dir/punk.yml";
        get '/origin' => sub { $_[0]->text($_[0]->origin // 'undef') };
        package main;
    }
    (undef, $o) = hit(YmlOneApp->to_app, '/origin', HTTP_HOST => 'only.tld');
    is($o, 'https://only.tld', 'a single entry may be written bare');
}

done_testing;
