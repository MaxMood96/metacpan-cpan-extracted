#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use Punk ();

# The `host` keyword: the application's canonical origin, declared once.
#
# It exists so that every plugin needing an absolute base URL - a sitemap,
# an OAuth redirect - can default to one fact stated in one place, instead
# of each asking for its own copy. The value is CONFIGURATION: the tempting
# alternative, the request's Host header, is attacker-supplied bytes, which
# is exactly why the consumers refuse to guess.

# ---- set and read back ------------------------------------------------------
{
    package SetApp;
    use Punk;
    host 'https://example.com';
    package main;

    is(SetApp->punk_app->host, 'https://example.com',
        'the declared origin reads back through $app->host');
}

# ---- normalization ----------------------------------------------------------
{
    package TrimApp;
    use Punk;
    host 'https://example.com///';
    package main;

    is(TrimApp->punk_app->host, 'https://example.com',
        'trailing slashes are trimmed on store, so a consumer joining a '
      . 'rooted path onto it produces one slash and not two');
}

{
    package PathApp;
    use Punk;
    host 'https://example.com/app/';
    package main;

    is(PathApp->punk_app->host, 'https://example.com/app',
        'a path is allowed - an application deployed under a prefix is '
      . 'still one origin - and its trailing slash is trimmed the same way');
}

# ---- last write wins --------------------------------------------------------
{
    package TwiceApp;
    use Punk;
    host 'https://first.example';
    host 'https://second.example';
    package main;

    is(TwiceApp->punk_app->host, 'https://second.example',
        'declared twice, the last declaration wins - the upload_dir rule');
}

# ---- unset is undef, not an error -------------------------------------------
{
    package UnsetApp;
    use Punk;
    package main;

    is(UnsetApp->punk_app->host, undef,
        'an application that never declared one reads back undef, which is '
      . 'what lets a plugin distinguish "not configured" from a value');
}

# ---- what is refused, and why ----------------------------------------------
# Every consumer joins paths onto this value trusting it blindly, so the
# validation happens once, here, at the keyword.

my $err = do { local $@; eval {
    package NoScheme; use Punk;
    host 'example.com';
}; $@ };
like($err, qr/host needs an absolute origin/,
    'a bare hostname croaks - the consumers need the scheme');

$err = do { local $@; eval {
    package BareScheme; use Punk;
    host 'https://';
}; $@ };
like($err, qr/host needs an absolute origin/,
    'a scheme with nothing after it croaks');

$err = do { local $@; eval {
    package EmptyHost; use Punk;
    host '';
}; $@ };
like($err, qr/host needs an absolute origin/, 'and so does an empty string');

$err = do { local $@; eval {
    package QueryHost; use Punk;
    host 'https://example.com?x=1';
}; $@ };
like($err, qr/host may not carry/,
    'a query croaks - an origin has no query, and one here is a mistake');

$err = do { local $@; eval {
    package FragHost; use Punk;
    host 'https://example.com#top';
}; $@ };
like($err, qr/host may not carry/, 'a fragment croaks the same way');

$err = do { local $@; eval {
    package SpaceHost; use Punk;
    host 'https://exa mple.com';
}; $@ };
like($err, qr/host may not carry/, 'whitespace croaks');

$err = do { local $@; eval {
    package SlashHost; use Punk;
    host 'https://example.com\\admin';
}; $@ };
like($err, qr/host may not carry/,
    'a backslash croaks, for the same reason $c->safe_path refuses one: '
  . 'browsers fold it to a slash');

# ---- from punk.yml ----------------------------------------------------------
# A config block that mirrors a DSL keyword registers for real, so a
# deployment sets the host with no code change - and the value goes through
# the same method, so it gets the same validation and normalization.

SKIP: {
    skip 'YAML::XS required for the config half', 2
        unless eval { require YAML::XS; 1 };

    my $dir = File::Temp->newdir;
    open my $fh, '>', "$dir/punk.yml" or die $!;
    print $fh "host: https://from-config.example/\n";
    close $fh;

    {
        package YmlApp;
        use Punk;
        config "$dir/punk.yml";
        package main;
    }
    is(YmlApp->punk_app->host, 'https://from-config.example',
        'a punk.yml host block registers for real, trimmed like the keyword');

    open $fh, '>', "$dir/punk.yml" or die $!;
    print $fh "host:\n  allow: [ x.example ]\n";
    close $fh;

    my $yerr = do { local $@; eval {
        package YmlBadApp;
        use Punk;
        config "$dir/punk.yml";
    }; $@ };
    like($yerr, qr/config host block needs an origin/,
        'a mapping without an origin croaks - the allowlist stands in for '
      . 'nothing');
}

done_testing;
