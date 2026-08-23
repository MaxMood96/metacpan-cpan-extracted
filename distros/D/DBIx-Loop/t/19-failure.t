#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;
use File::Temp ();

# A statement that fails IN THE DATABASE fails its future, whatever the
# handle's RaiseError says.
#
# DBI reports a failure two ways: a croak when the handle was opened with
# RaiseError, or a false return - undef from do, false from execute - when it
# was not. The runner trapped the croak and ignored the return, so on a
# handle without RaiseError an INSERT into a NOT NULL column resolved DONE
# with rows_affected => 0, and a transaction built on it COMMITTED. The
# pinned transaction path, the plain pool path and the synchronous bare-dbh
# path all share the runner, so all three are pinned here; the native Pg
# path has its own check on pg_result and a test in t/04.

BEGIN {
    plan skip_all => 'DBD::SQLite required' unless eval { require DBI; require DBD::SQLite; 1 };
}
use DBIx::Loop;

my $dir  = File::Temp->newdir;
my $file = "$dir/fail.db";
{
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file", '', '', { RaiseError => 1 });
    $dbh->do('CREATE TABLE t (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
    $dbh->disconnect;
}

# ---- the synchronous backend, no RaiseError ----------------------------------
{
    package DBIx::Loop::TestLoop;
    sub new { bless {}, shift }
    sub watch_read { }  sub unwatch_read { }  sub defer { $_[1]->() }
    sub timer { }       sub cancel_timer { }
    sub await { }
}
{
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file", '', '',
        { RaiseError => 0, PrintError => 0 });
    my $db  = DBIx::Loop->new(dbh => $dbh, loop => DBIx::Loop::TestLoop->new);

    my $f = $db->do('INSERT INTO t (name) VALUES (NULL)');
    ok($f->is_failed, 'sync: a do that violates a constraint fails the future');
    like($f->failure, qr/NOT NULL constraint failed: t\.name/,
        'sync: with the driver\'s own message');

    $f = $db->query('INSERT INTO t (name) VALUES (NULL) RETURNING *');
    ok($f->is_failed, 'sync: a query whose execute fails fails the future');
    like($f->failure, qr/NOT NULL constraint/, 'sync: same message');

    $f = $db->do('INSERT INTO t (name) VALUES (?)', 'ok');
    ok($f->is_done, 'sync: a good do still resolves');
    is(($f->get)[0]{rows_affected}, 1, 'sync: with its row count');

    $f = $db->do('UPDATE t SET name = ? WHERE id = 999', 'nobody');
    ok($f->is_done, 'sync: a do touching no rows is not a failure');
    is(($f->get)[0]{rows_affected}, 0, 'sync: it is zero rows ("0E0" is true)');
}

# ---- the pool, and a transaction on it ---------------------------------------
SKIP: {
    skip 'IO::Async required for the pool half', 9
        unless eval { require IO::Async::Loop; require DBIx::Loop::Loop::IOAsync; 1 };

    my $ad = DBIx::Loop::Loop::IOAsync->new;
    my $db = DBIx::Loop->connect("dbi:SQLite:dbname=$file", '', '',
        { RaiseError => 0, PrintError => 0 }, loop => $ad, workers => 2);
    is($db->capability, 'pool', 'pool backend');

    my $f = $db->do('INSERT INTO t (name) VALUES (NULL)');
    $ad->await($f);
    ok($f->is_failed, 'pool: a failing do fails the future');
    like($f->failure, qr/NOT NULL constraint failed: t\.name/, 'pool: with the message');

    $f = $db->query('INSERT INTO t (name) VALUES (NULL) RETURNING *');
    $ad->await($f);
    ok($f->is_failed, 'pool: a failing execute on the query path fails the future');

    # the case that matters: a transaction whose write fails must ROLL BACK
    my $count_before = do {
        my $c = $db->query('SELECT COUNT(*) FROM t'); $ad->await($c); ($c->get)[0]{rows}[0][0] };
    $f = $db->txn(sub {
        my ($tx) = @_;
        return $tx->do('INSERT INTO t (name) VALUES (?)', 'doomed')
          ->then(sub { $tx->do('INSERT INTO t (name) VALUES (NULL)') });
    });
    $ad->await($f);
    ok($f->is_failed, 'pool: a transaction whose second write fails, fails');
    like($f->failure, qr/NOT NULL constraint/, 'pool: carrying the statement\'s error');
    my $count_after = do {
        my $c = $db->query('SELECT COUNT(*) FROM t'); $ad->await($c); ($c->get)[0]{rows}[0][0] };
    is($count_after, $count_before,
        'pool: and the first write rolled back with it - nothing committed');

    $f = $db->txn(sub { $_[0]->do('INSERT INTO t (name) VALUES (?)', 'fine') });
    $ad->await($f);
    ok($f->is_done, 'pool: a transaction whose writes succeed still commits');
    my $count_end = do {
        my $c = $db->query('SELECT COUNT(*) FROM t'); $ad->await($c); ($c->get)[0]{rows}[0][0] };
    is($count_end, $count_before + 1, 'pool: by exactly its one row');
}

done_testing();
