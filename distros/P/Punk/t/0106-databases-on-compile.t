#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;

# Two registrar methods for plugins: $app->databases reads the configured
# databases back (the `database` keyword was write-only), and
# $app->on_compile runs a callback at to_app after every keyword has
# recorded and before anything is compiled - so a plugin registered above
# the `database` line still sees the database, and what the callback adds
# to the registrar is compiled with the rest.
#
# Punk::Plugin::Queue faked the second with a middleware whose constructor
# runs once at compile, and said so in a comment; Punk-Sqitch's boot check
# needs the same moment for the same reason.

# ---- databases ------------------------------------------------------------------
{
    package DbApp;
    use Punk;
    database dsn => 'dbi:SQLite:dbname=:memory:', user => 'u', password => 'p';
    database analytics => { dsn => 'dbi:Pg:dbname=warehouse', attr => { pg_enable_utf8 => 1 } };
    package main;
}
{
    my $app = DbApp->punk_app;
    my $dbs = $app->databases;
    is_deeply([ sort keys %$dbs ], [qw(analytics default)], 'databases: every configured one, default for the unnamed');
    is_deeply($dbs->{default}, { dsn => 'dbi:SQLite:dbname=:memory:', user => 'u', password => 'p' },
        'the default one, as the keyword recorded it - password included, it is the application\'s own registrar');
    is($dbs->{analytics}{dsn}, 'dbi:Pg:dbname=warehouse', 'a named one');
    $dbs->{default}{dsn} = 'dbi:Pg:dbname=tampered';
    $dbs->{analytics}{attr}{pg_enable_utf8} = 0;
    is($app->databases->{default}{dsn}, 'dbi:SQLite:dbname=:memory:', 'a copy: editing it changes nothing');
    is($app->databases->{analytics}{attr}{pg_enable_utf8}, 1, 'deep: the nested attr hash is a copy too');
}
{
    package NoDbApp;
    use Punk;
    package main;
    is_deeply(NoDbApp->punk_app->databases, {}, 'no database keyword: an empty hash, not undef');
}

# ---- on_compile: sees the database declared after the plugin line ---------------------
{
    package Punk::Plugin::SeesDb;
    use parent 'Punk::Plugin';
    our %SAW;
    sub register {
        my ($class, $app, $opts) = @_;
        $SAW{at_plugin} = [ sort keys %{ $app->databases } ];
        $app->on_compile(sub {
            my ($a) = @_;
            $SAW{at_compile} = [ sort keys %{ $a->databases } ];
            $SAW{registrar_is_app} = ($a == $app) ? 1 : 0;
        }, __PACKAGE__);
        return;
    }
}
{
    package OrderApp;
    use Punk;
    plugin '+Punk::Plugin::SeesDb';
    database dsn => 'dbi:SQLite:dbname=:memory:';
    database later => { dsn => 'dbi:SQLite:dbname=:memory:' };
    get '/' => sub { $_[0]->text('ok') };
    package main;
}
{
    is_deeply($Punk::Plugin::SeesDb::SAW{at_plugin}, [], 'at the plugin line, above the database keyword, nothing is visible');
    OrderApp->to_app;
    is_deeply($Punk::Plugin::SeesDb::SAW{at_compile}, [qw(default later)],
        'at to_app the callback sees both databases declared below it');
    is($Punk::Plugin::SeesDb::SAW{registrar_is_app}, 1, 'the callback receives the registrar');
}

# ---- on_compile: what it adds is compiled; order; the owner on a die ------------------
{
    package AddsApp;
    use Punk;
    our @ORDER;
    get '/' => sub { $_[0]->text('root') };
    punk_app->on_compile(sub {
        my ($a) = @_;
        push @ORDER, 'first';
        $a->route(GET => '/from-compile', sub { $_[0]->text('added at compile') });
        $a->helper(compiled_helper => sub { 'helped' }, 'AddsApp');
    }, 'AddsApp');
    punk_app->on_compile(sub { push @ORDER, 'second' });
    get '/helper' => sub { $_[0]->text($_[0]->compiled_helper) };
    package main;
}
{
    my $app = AddsApp->to_app;
    is_deeply(\@AddsApp::ORDER, [qw(first second)], 'callbacks run in registration order');
    is(hit($app, path => '/from-compile')->[2][0], 'added at compile',
        'a route added in on_compile is in the compiled table');
    is(hit($app, path => '/helper')->[2][0], 'helped', 'and a helper added there is a real method');
    my $e = ''; eval { AddsApp->punk_app->on_compile(sub { 1 }) } or $e = $@;
    like($e, qr/on_compile after to_app - the application is already compiled/, 'on_compile after to_app croaks');
}
{
    package DiesApp;
    use Punk;
    punk_app->on_compile(sub { die "the schema is behind\n" }, 'Punk::Plugin::Whatever');
    package main;
    my $e = ''; eval { DiesApp->to_app } or $e = $@;
    like($e, qr/Punk: on_compile callback registered by Punk::Plugin::Whatever died: the schema is behind/,
        'a die in a callback is a to_app croak naming the owner');
}
{
    package DefaultOwnerApp;
    use Punk;
    punk_app->on_compile(sub { die "oops\n" });
    package main;
    my $e = ''; eval { DefaultOwnerApp->to_app } or $e = $@;
    like($e, qr/registered by DefaultOwnerApp died: oops/, 'the owner defaults to the registering package');
    $e = ''; eval { DefaultOwnerApp->punk_app->on_compile('not code') } or $e = $@;
    like($e, qr/on_compile takes a coderef/, 'a non-coderef croaks');
}

# ---- the callback runs before the framework's own extras ----------------------------------
{
    package BeforeExtrasApp;
    use Punk;
    our @ORDER;
    punk_app->on_compile(sub { push @ORDER, 'on_compile' });
    package main;
    no warnings 'redefine';
    my $orig = \&Punk::App::compile_extras;
    local *Punk::App::compile_extras = sub { push @BeforeExtrasApp::ORDER, 'compile_extras'; goto &$orig };
    BeforeExtrasApp->to_app;
    is_deeply(\@BeforeExtrasApp::ORDER, [qw(on_compile compile_extras)],
        'on_compile callbacks run before compile_extras, so the extras see what they added');
}

done_testing();
