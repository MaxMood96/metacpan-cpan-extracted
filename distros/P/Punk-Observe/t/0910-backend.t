#!perl
# The configuration store this distribution now ships.
#
# Before 0.02 it shipped DDL and no database code, so every host had to write
# a seam to reach it - and the result was that dashboards had a renderer, a
# validator, two tables and no reader, because nobody wrote one. The gate for
# this file is that an install configured with nothing but a path can save a
# dashboard and read it back.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use DBI ();

use Punk::Observe::Backend ();
use Punk::Observe::Config ();

my $B = 'Punk::Observe::Backend';
my $C = 'Punk::Observe::Config';

sub fresh {
    my $dir = tempdir(CLEANUP => 1);
    my $db = $B->new(dsn => "dbi:SQLite:dbname=$dir/config.db");
    $db->migrate;
    return ($db, $dir);
}

# --- the factory ------------------------------------------------------------

{
    my $dir = tempdir(CLEANUP => 1);
    my $db = $B->new(dsn => "dbi:SQLite:dbname=$dir/x.db");
    is(ref $db, 'Punk::Observe::Backend::SQLite',
       'the backend is inferred from the dsn');

    # THE DSN IS THE THING THE OPERATOR TYPED. A second option saying the same
    # thing again is a second thing to get wrong.
    my $err = !eval { $B->new(dsn => 'dbi:Oracle:whatever'); 1 } ? $@ : '';
    like($err, qr/SQLite and Pg/,
         'an unknown driver refuses, and names what is shipped');
    like($err, qr/backend => '\+/, '  and names the escape hatch');
}

# --- migrate ----------------------------------------------------------------

{
    my ($db) = fresh();
    # THE REGISTRY RECORDS CHANGE NAMES, not a version integer: an integer
    # cannot survive a change being inserted before another one, and the
    # sqitch plan is the ordering.
    is($db->schema_version, $db->LATEST,
       'migrate deploys through to the last change in the plan');
    ok(defined $db->LATEST, '  and there is a change to deploy');

    # Idempotent, because every worker calls it at boot.
    my $again = $db->migrate;
    is($again, $db->LATEST, 'migrate twice lands on the same change');

    my $t = $db->dbh->selectall_arrayref(
        "SELECT name FROM sqlite_master
          WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
    my %have = map { $_->[0] => 1 } @$t;
    for my $want (qw(dashboards dashboard_panels alert_rules alert_state
                     alert_events notification_channels route_rules silences
                     notifications)) {
        ok($have{$want}, "the schema has $want");
    }

    # A version row, not several. Two would mean two writers each thought
    # they were first, which is the race this is locked against.
    my ($rows) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM punk_observe_schema');
    is($rows, scalar @{ $db->_plan_changes($db->_project_dir) },
       'one registry row per change in the plan, and no more');
}

# THE REFERENCES ARE REAL. SQLite leaves foreign keys off for compatibility,
# so without the pragma every one of them in the schema is decoration - and a
# panel outliving its deleted dashboard surfaces as a render failure a long
# way from the delete that caused it.
{
    my ($db) = fresh();
    my $dbh = $db->dbh;
    $dbh->do("INSERT INTO dashboards (tenant, slug, title)
              VALUES ('default', 'a', 'A')");
    my ($id) = $dbh->selectrow_array("SELECT id FROM dashboards");

    my $orphan = eval {
        $dbh->do("INSERT INTO dashboard_panels (dashboard_id, title, query)
                  VALUES (99999, 'o', 'log')"); 1 };
    ok(!$orphan, 'a panel cannot reference a dashboard that is not there');

    $dbh->do("INSERT INTO dashboard_panels (dashboard_id, title, query)
              VALUES (?, 'p', 'log')", undef, $id);
    $dbh->do('DELETE FROM dashboards WHERE id = ?', undef, $id);
    my ($left) = $dbh->selectrow_array('SELECT COUNT(*) FROM dashboard_panels');
    is($left, 0, '  and deleting the dashboard takes its panels with it');
}

# --- four workers boot together ---------------------------------------------
#
# This is the ordinary case, not an edge one: the plugin migrates in every
# worker at registration, and a worker pool starts them at once. The same
# forked shape t/0902-quotas.t uses.
{
    my $dir = tempdir(CLEANUP => 1);
    my $dsn = "dbi:SQLite:dbname=$dir/race.db";

    my @pid;
    for my $n (1 .. 4) {
        my $p = fork;
        BAIL_OUT("fork: $!") unless defined $p;
        if (!$p) {
            my $ok = eval {
                my $d = $B->new(dsn => $dsn);
                defined $d->migrate && $d->migrate eq $d->LATEST;
            };
            exit($ok ? 0 : 1);
        }
        push @pid, $p;
    }
    my $failed = 0;
    for my $p (@pid) { waitpid $p, 0; $failed++ if $? }
    is($failed, 0, 'four workers migrating together all succeed');

    my $db = $B->new(dsn => $dsn);
    my ($rows) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM punk_observe_schema');
    is($rows, scalar @{ $db->_plan_changes($db->_project_dir) },
       '  and leave one row per change, not four');
    is($db->schema_version, $db->LATEST, '  at the right change');
}

# THE POOL CARRIES THE PID. A handle made before a fork and used after it is
# shared by two processes that both believe they own it, which corrupts the
# wire protocol under load rather than failing in a test.
{
    my ($db, $dir) = fresh();
    $db->dbh;                                  # connect in the parent

    my $p = fork;
    BAIL_OUT("fork: $!") unless defined $p;
    if (!$p) {
        my $ok = eval {
            $db->dbh->do("INSERT INTO dashboards (tenant, slug, title)
                          VALUES ('default', 'child', 'C')");
            1;
        };
        exit($ok ? 0 : 1);
    }
    waitpid $p, 0;
    is($?, 0, 'a child inherits the object and gets its own handle');

    my ($n) = $db->dbh->selectrow_array(
        "SELECT COUNT(*) FROM dashboards WHERE slug = 'child'");
    is($n, 1, '  and its write is visible to the parent');
}

# --- the three outcomes -----------------------------------------------------
#
# Worked, refused for a reason you can act on, failed for one you cannot.
# Collapsing the middle two gives an editor that says "something went wrong"
# when the real answer was "that query does not parse".
{
    my ($db) = fresh();

    my $r = $C->can('save_dashboard')->($db, 'default',
                                        { slug => 'ops', title => 'Ops', cols => 3 });
    ok($r->{ok}, 'a good dashboard saves');
    ok($r->{id}, '  and comes back with its id');

    for my $bad ([ { title => 'X' },                      qr/slug/,  'no slug' ],
                 [ { slug => 'a/b', title => 'X' },        qr/slug/,  'a slug with a slash' ],
                 [ { slug => 'ok' },                       qr/title/, 'no title' ]) {
        my ($spec, $re, $what) = @$bad;
        my $x = $C->can('save_dashboard')->($db, 'default', $spec);
        ok(!$x->{ok},      "$what is not saved");
        ok($x->{refused},  "  and is REFUSED, not failed");
        like($x->{error}, $re, "  with a reason naming the field");
    }

    # cols is clamped to what the stylesheet has rules for.
    $C->can('save_dashboard')->($db, 'default', { slug => 'w', title => 'W', cols => 99 });
    my $w = $C->can('dashboards')->($db, 'default', 'w');
    cmp_ok($w->{cols}, '<=', 6, 'cols is clamped to a grid that exists');
}

# A PANEL IS VALIDATED BY THE PARSER THAT WILL RUN IT, before it is stored, so
# the dashboard page never has to apologise for a panel it saved.
{
    my ($db) = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops' });

    my $good = $C->can('save_panel')->($db, 'default', 'ops', {
        title => 'errors', viz => 'bar', span => 2,
        query => 'log | where severity >= error | count' });
    ok($good->{ok}, 'a panel with a valid query saves');

    my $bad = $C->can('save_panel')->($db, 'default', 'ops',
                                      { title => 'x', query => 'log | wat' });
    ok($bad->{refused}, 'a panel whose query does not parse is refused');
    like($bad->{error}, qr/stage/,
         "  with the PARSER's own message, not a generic one");

    my $nodash = $C->can('save_panel')->($db, 'default', 'nope',
                                         { title => 'x', query => 'log' });
    ok($nodash->{refused}, 'a panel on a dashboard that is not there is refused');

    # Round trip, with viz and span intact - the two the renderer reads.
    my $d = $C->can('dashboards')->($db, 'default', 'ops');
    is(scalar @{ $d->{panels} }, 1, 'the panel is read back');
    is($d->{panels}[0]{viz},  'bar', '  with its visualisation');
    is($d->{panels}[0]{span}, 2,     '  and its span');
    is($d->{panels}[0]{query}, 'log | where severity >= error | count',
       '  and its query, unchanged');
}

# --- the two engines describe the same schema -------------------------------
#
# The DDL used to live here as well as in sqitch/, and this asserted the two
# agreed - which was an admission rather than a solution: it existed because
# they could disagree, and a third copy in the demo had already drifted to
# five of the nine tables it should have had.
#
# There is one description now, but there are two ENGINES, and PostgreSQL and
# SQLite cannot share a script: BIGSERIAL and JSONB have no SQLite spelling.
# So the drift that remains possible is between them, and that is what is
# asserted here. A column added to one engine only is a failing build.
{
    my %tables;
    my %cols;
    for my $engine (qw(pg sqlite)) {
        my $f = "sqitch/$engine/deploy/alerts.sql";
        ok(-f $f, "the $engine change script ships");
        my $sql = do { open my $fh, '<', $f or die "$f: $!"; local $/; <$fh> };

        while ($sql =~ /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)\s*\((.*?)\n\s*\);/gis) {
            my ($t, $body) = (lc $1, $2);
            $tables{$engine}{$t} = 1;
            # A column is a name at the start of a line followed by a type.
            # The words below start a CONTINUATION - a REFERENCES clause
            # wrapping onto `ON DELETE CASCADE` reads as a column called `on`
            # otherwise, which is a failing test with no bug behind it.
            my @kw = qw(unique primary foreign check references constraint
                        on default not null cascade);
            my %c = map { lc $_ => 1 } $body =~ /^\s+(\w+)\s+\S/gm;
            delete @c{@kw};
            $cols{$engine}{$t} = \%c;
        }
    }

    is_deeply([ sort keys %{ $tables{pg} } ], [ sort keys %{ $tables{sqlite} } ],
              'both engines describe the same tables')
        or diag("pg only:     @{[ grep { !$tables{sqlite}{$_} } sort keys %{$tables{pg}} ]}\n"
              . "sqlite only: @{[ grep { !$tables{pg}{$_} } sort keys %{$tables{sqlite}} ]}");

    my $bad = '';
    for my $t (sort keys %{ $tables{pg} }) {
        next unless $tables{sqlite}{$t};
        my $p = $cols{pg}{$t}     || {};
        my $s = $cols{sqlite}{$t} || {};
        my @only_p = grep { !$s->{$_} } sort keys %$p;
        my @only_s = grep { !$p->{$_} } sort keys %$s;
        $bad .= "$t: pg only @only_p; sqlite only @only_s\n"
            if @only_p || @only_s;
    }
    is($bad, '', '  with the same columns on every one of them') or diag($bad);
}

done_testing();
