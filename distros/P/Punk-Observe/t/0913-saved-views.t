#!perl
# Saved views: a name on a URL.
#
# All view state in this UI travels in the query string, deliberately -
# brush.js gives the reason, which is that an incident gets shared by pasting
# a URL into a chat window. A saved view must not become a second source of
# state the URL does not reflect, or that property is lost for exactly the
# views somebody cared enough to save.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe::Backend ();
use Punk::Observe::Config ();

my $C = 'Punk::Observe::Config';

sub fresh {
    my $dir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$dir/c.db");
    $db->migrate;
    return $db;
}

# --- a view is the query string, and only that ------------------------------

{
    my $db = fresh();
    my $r = $C->can('save_view')->($db, 'default', {
        name => 'errors', page => 'logs',
        q => 'log | where severity >= error', range => '1h' });
    ok($r->{ok}, 'a view saves') or diag $r->{error};

    my $v = $C->can('saved_views')->($db, 'default', 'logs')->[0];
    is($v->{name}, 'errors', 'and comes back by name');

    # THE MOUNT PREFIX IS NOT IN IT. The prefix is configuration, so a view
    # saved under /observe has to open under /telemetry.
    unlike($v->{params}, qr{/observe}, 'the mount prefix is not stored');
    unlike($v->{params}, qr{^/},       '  nor any path at all');

    # Nor is anything that addresses one particular thing rather than
    # describing a view of many.
    unlike($v->{params}, qr/\bslug=/, 'a slug is not part of a view');
    unlike($v->{params}, qr/\bid=/,   '  nor a record id');

    like($v->{params}, qr/\bq=/,     'the query is');
    like($v->{params}, qr/\brange=/, '  and the window');
}

# --- relative and frozen are different things -------------------------------
#
# "errors in the last hour" and "errors between 03:00 and 04:00 last Tuesday"
# are both worth saving and are not the same kind of thing. The range control
# already draws the distinction; flattening a preset into the two instants it
# resolved to would make "the last 15 minutes" stop meaning that, fifteen
# minutes later.
{
    my $db = fresh();
    $C->can('save_view')->($db, 'default', { name => 'live', page => 'logs',
                                             q => 'log', range => '15m' });
    $C->can('save_view')->($db, 'default', { name => 'frozen', page => 'logs',
                                             q => 'log',
                                             from => '1787000000000000000',
                                             to   => '1787003600000000000' });

    my %by = map { $_->{name} => $_ }
             @{ $C->can('saved_views')->($db, 'default', 'logs') };

    ok(!$by{live}{frozen}, 'a preset window stays relative');
    like($by{live}{params}, qr/range=15m/, '  stored as the preset it was');
    unlike($by{live}{params}, qr/\bfrom=/,
           '  and NOT flattened into the instants it resolved to');

    ok($by{frozen}{frozen}, 'an explicit pair is frozen');
    like($by{frozen}{params}, qr/from=1787000000000000000/,
         '  and keeps both instants exactly');
    like($by{frozen}{params}, qr/to=1787003600000000000/, '  including the end');

    # The list says which, because a frozen view read as a live one is the
    # wrong answer at the worst moment.
    isnt($by{live}{window}, $by{frozen}{window},
         'the list distinguishes them without opening either');
}

# --- validated by the parser that will run it -------------------------------
{
    my $db = fresh();

    my $bad = $C->can('save_view')->($db, 'default',
        { name => 'nope', page => 'logs', q => 'log | wat' });
    ok($bad->{refused}, 'a query that does not parse cannot be saved');
    is($bad->{field}, 'q', '  and the refusal blames the query box');
    like($bad->{error}, qr/stage/, '  with the parser\'s own message');

    my $noname = $C->can('save_view')->($db, 'default',
        { page => 'logs', q => 'log' });
    is($noname->{field}, 'name', 'a view with no name blames the name box');

    my $empty = $C->can('save_view')->($db, 'default',
        { name => 'x', page => 'logs' });
    ok($empty->{refused}, 'a view with nothing on it is refused');
}

# --- the round trip ---------------------------------------------------------
#
# Save a view, reopen it, and land on a URL that produces the same result set.
# The point of the whole feature is that this is still a link.
{
    my $db = fresh();
    my %spec = (name => 'checkout errors', page => 'logs',
                q => 'log | where severity >= error', range => '6h',
                service => 'shop');
    ok($C->can('save_view')->($db, 'default', \%spec)->{ok}, 'saved');

    my $v = $C->can('saved_views')->($db, 'default', 'logs')->[0];

    # Parse the stored query string back and assert it says what went in.
    my %got;
    for my $pair (split /&/, $v->{params}) {
        my ($k, $val) = split /=/, $pair, 2;
        $val =~ tr/+/ /;
        $val =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
        $got{$k} = $val;
    }
    is($got{q}, $spec{q},             'the query round trips exactly');
    is($got{range}, '6h',             '  and the window');
    is($got{service}, 'shop',         '  and the filter');

    # The same view under a different mount is the same view: nothing about
    # the prefix was stored, so the caller composes it.
    for my $prefix ('/observe', '/telemetry') {
        my $url = "$prefix/logs?$v->{params}";
        like($url, qr/\Q$spec{q}\E|q=log/, "opens under $prefix");
    }
}

# --- naming is per page ------------------------------------------------------
#
# `errors` on the logs screen and `errors` on the traces screen are different
# views of different things, and both are a reasonable thing to call it.
{
    my $db = fresh();
    ok($C->can('save_view')->($db, 'default',
        { name => 'errors', page => 'logs', q => 'log' })->{ok},
       'errors on the logs screen');
    ok($C->can('save_view')->($db, 'default',
        { name => 'errors', page => 'trace', q => 'trace' })->{ok},
       'and errors on the traces screen');

    is(scalar @{ $C->can('saved_views')->($db, 'default', 'logs') }, 1,
       'the logs screen shows one');
    is(scalar @{ $C->can('saved_views')->($db, 'default', 'trace') }, 1,
       '  and the traces screen its own');
    is(scalar @{ $C->can('saved_views')->($db, 'default') }, 2,
       '  and both are there without a page');

    # Saving the same name on the same page updates rather than duplicating.
    $C->can('save_view')->($db, 'default',
        { name => 'errors', page => 'logs', q => 'log | count' });
    my $vs = $C->can('saved_views')->($db, 'default', 'logs');
    is(scalar @$vs, 1, 'saving the same name again updates it');
    like($vs->[0]{params}, qr/count/, '  with the new query');
}

# --- delete ------------------------------------------------------------------
{
    my $db = fresh();
    $C->can('save_view')->($db, 'default',
        { name => 'x', page => 'logs', q => 'log' });
    my $v = $C->can('saved_views')->($db, 'default', 'logs')->[0];

    ok($C->can('delete_view')->($db, 'default', $v->{id})->{ok}, 'a view deletes');
    is(scalar @{ $C->can('saved_views')->($db, 'default', 'logs') }, 0,
       '  and is gone');
    ok($C->can('delete_view')->($db, 'default', $v->{id})->{refused},
       'deleting it twice is refused, not silently fine');
}

done_testing();
