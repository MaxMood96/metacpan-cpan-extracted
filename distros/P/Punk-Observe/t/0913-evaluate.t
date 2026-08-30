#!perl
# The evaluation pass, and the delivery pipeline behind it.
#
# THIS IS THE LOOP EVERY HOST USED TO WRITE, and the demo's copy carried the
# two bugs this file pins: a transaction with no rollback that wedged the
# SQLite write lock for the life of the process, and an INSERT missing a NOT
# NULL column that killed every transition. Neither may come back.
#
# The store is SCRIPTED, not sampled: each pass hands the evaluator exactly
# the buckets that select the branch under test, because a corpus that
# happens to exercise a branch stops exercising it the day the numbers
# drift.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe ();
use Punk::Observe::Backend ();
use Punk::Observe::Config ();
use Punk::Observe::Evaluate ();
use Punk::Observe::Store ();

my $E = 'Punk::Observe::Evaluate';
my $C = 'Punk::Observe::Config';

# --- fixtures ----------------------------------------------------------------

my $T0 = q{1787000000000000000};
# nadd takes unsigned decimal strings - a negative offset must go through
# nsub, or it is quietly ignored and every "earlier" instant collapses onto
# T0, which turns two ticks into one and pending into a mystery.
sub at {
    my ($s) = @_;
    return $s >= 0
        ? Punk::Observe::Store::nadd($T0, $s * 1_000_000_000)
        : Punk::Observe::Store::nsub($T0, -$s * 1_000_000_000);
}

sub fresh_db {
    my $dir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$dir/c.db");
    $db->migrate;
    return $db;
}

# A store whose next answer is whatever the test says it is. `undef` scripts
# a query failure, which is how the fail-tick branch is selected on purpose.
{
    package Scripted::Store;
    sub new { return bless { answers => [] }, shift }
    sub will { push @{ $_[0]{answers} }, $_[1]; return $_[0] }
    sub query {
        my ($self) = @_;
        my $a = shift @{ $self->{answers} };
        die "scripted failure\n" unless defined $a;
        return $a;
    }
}

# One bucketed answer: values per instant, single unnamed series.
sub buckets {
    my (@pairs) = @_;
    return { ok => 1, shape => 'buckets', bucket_ns => '30000000000',
             series => [ { key => '',
                           points => [ map { [ $_->[0], $_->[1], 1 ] } @pairs ] } ],
             meta => {} };
}

sub rule {
    my ($db, %over) = @_;
    my $r = $C->can('save_alert')->($db, 'default', {
        name => 'error rate', query => 'spans | bucket(30s) count',
        op => '>', threshold => 2, for => '30s', every => '30s', %over });
    die $r->{error} unless $r->{ok};
    return $r->{id};
}

sub state_of {
    my ($db, $id) = @_;
    return $db->dbh->selectall_arrayref(
        'SELECT series, state FROM alert_state WHERE rule_id = ? ORDER BY series',
        { Slice => {} }, $id);
}

# --- a fire is recorded, grouped and delivered -------------------------------

{
    my $db = fresh_db();
    my $id = rule($db);

    # Two breaching buckets thirty seconds apart: the condition has held
    # `for`, so this pass lands on firing.
    my $store = Scripted::Store->new->will(
        buckets([ at(-60), 5 ], [ at(-30), 5 ]));
    my $out = $E->can('run')->(db => $db, store => $store, now => at(0));

    is($out->{evaluated}, 1, 'the rule was evaluated');
    ok($out->{transitions} >= 1, '  and moved');
    is_deeply([ map { $_->{state} } @{ state_of($db, $id) } ], ['firing'],
              '  to firing');

    my ($ev) = $db->dbh->selectrow_hashref(
        'SELECT kind, from_state, to_state FROM alert_events
          WHERE rule_id = ? ORDER BY id DESC', undef, $id);
    is($ev->{to_state}, 'firing', 'the transition is an event');
    is($ev->{kind}, 1, '  of the firing kind - the NOT NULL column that used '
                     . 'to be omitted, killing every transition');

    my ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ?', undef, $id);
    is($n, 1, 'one outbox row');
    my ($g) = $db->dbh->selectrow_hashref(
        "SELECT * FROM notification_groups WHERE rule_id = ?", undef, $id);
    is($g->{state}, 'open', '  in an open group');

    # NOT due yet: group_wait holds it. The claimed list is empty.
    is(scalar @{ $out->{groups} }, 0, 'group_wait holds the first send');

    # A later pass, past the wait, claims it - and an unchanged state
    # produces no second outbox row on the way.
    my $store2 = Scripted::Store->new->will(
        buckets([ at(0), 5 ], [ at(30), 5 ]));
    my $out2 = $E->can('run')->(db => $db, store => $store2, now => at(60),
                                force => 1);
    is(scalar @{ $out2->{groups} }, 1, 'past group_wait the group is claimed');
    ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ?', undef, $id);
    is($n, 1, '  and a still-firing rule did not enqueue a duplicate');

    # Delivery: one callback, the documented context.
    my $got;
    my $r = $E->can('notify')->(
        db => $db, group => $out2->{groups}[0]{id},
        token => $out2->{groups}[0]{token},
        on_alert => sub { $got = $_[0] }, prefix => '/observe',
        app => 'My::App', now => at(61));
    is($r->{status}, 'sent', 'the group delivers');
    ok($got, 'the callback fired') or BAIL_OUT('no event');
    is($got->{kind}, 'firing', '  kind');
    is($got->{rule}{name}, 'error rate', '  the rule');
    is($got->{rule}{op}, '>', '  with its operator');
    is($got->{series}[0]{series}, 'all',
       '  an ungrouped query is one series called all');
    is($got->{series}[0]{value}, 5, '  carrying the raw value');
    is($got->{path}, "/observe/alerts/$id", '  and the way back to the screen');
    like($got->{delivery_key}, qr/\Ag\d+\.s1\z/,
       '  and an idempotency key for the host');

    my ($gs) = $db->dbh->selectrow_array(
        'SELECT state FROM notification_groups WHERE id = ?',
        undef, $out2->{groups}[0]{id});
    is($gs, 'sent', 'the group is marked sent');

    # A STALE TOKEN IS A LOUD NO-OP, NOT A DIE. Dying would spend five
    # retries delivering nothing.
    my $again;
    my $r2 = $E->can('notify')->(
        db => $db, group => $out2->{groups}[0]{id}, token => '999',
        on_alert => sub { $again = 1 });
    is($r2->{status}, 'stale', 'a stale token is refused');
    ok(!$again, '  without invoking the callback');
}

# --- resolve, and refire, are their own notifications ------------------------

{
    my $db = fresh_db();
    my $id = rule($db);

    my $fire = sub {
        my ($t) = @_;
        $E->can('run')->(db => $db, store => Scripted::Store->new->will(
            buckets([ Punk::Observe::Store::nsub($t, 60_000_000_000), 5 ],
                    [ Punk::Observe::Store::nsub($t, 30_000_000_000), 5 ])),
            now => $t, force => 1);
    };
    my $calm = sub {
        my ($t) = @_;
        $E->can('run')->(db => $db, store => Scripted::Store->new->will(
            buckets([ Punk::Observe::Store::nsub($t, 60_000_000_000), 0 ],
                    [ Punk::Observe::Store::nsub($t, 30_000_000_000), 0 ])),
            now => $t, force => 1);
    };

    $fire->(at(0));
    $calm->(at(60));
    is_deeply([ map { $_->{state} } @{ state_of($db, $id) } ], ['ok'],
              'the rule resolves');
    my $kinds = $db->dbh->selectcol_arrayref(
        'SELECT kind FROM notifications WHERE rule_id = ? ORDER BY id',
        undef, $id);
    is_deeply($kinds, [ 1, 2 ], 'fire then resolve, each its own row');

    # Refire: a NEW notification, not a duplicate refused by the dedupe.
    $fire->(at(120));
    $kinds = $db->dbh->selectcol_arrayref(
        'SELECT kind FROM notifications WHERE rule_id = ? ORDER BY id',
        undef, $id);
    is_deeply($kinds, [ 1, 2, 1 ], 'a resolve-and-refire is a third row');
}

# --- a failed query is the machine's error, and every episode notifies -------

{
    my $db = fresh_db();
    my $id = rule($db);

    # The scripted store with no answers DIES, which becomes a fail tick -
    # the machine's own latch then owns notify-once, rather than the caller
    # hand-recording error states beside it.
    my $fail = sub { $E->can('run')->(db => $db,
        store => Scripted::Store->new, now => $_[0], force => 1) };
    my $good = sub { $E->can('run')->(db => $db,
        store => Scripted::Store->new->will(buckets([ $_[0], 0 ])),
        now => $_[0], force => 1) };

    $fail->(at(0));
    is_deeply([ map { $_->{state} } @{ state_of($db, $id) } ], ['error'],
              'a query that cannot run is an error state, not ok');
    my ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ? AND kind = 4',
        undef, $id);
    is($n, 1, '  and it notifies');

    $fail->(at(30));
    ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ? AND kind = 4',
        undef, $id);
    is($n, 1, '  ONCE - a broken rule does not page every tick');

    # Re-armed by success, a second episode is a second notification. Keyed
    # on fired_at alone it would have collided with the first - an error has
    # no fired_at - and been silently dropped for ever.
    $good->(at(60));
    $fail->(at(120));
    ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ? AND kind = 4',
        undef, $id);
    is($n, 2, 'a second error episode is a second notification');
}

# --- the reason is captured, not just the count ------------------------------

# "1 rule(s) could not be evaluated" with nothing to say what was wrong is
# what these pin against: each failure class writes WHY onto the state row,
# and recovery clears it so the explanation can never be stale.

{
    my $db = fresh_db();
    my $id = rule($db);

    my $reason_of = sub { ($db->dbh->selectrow_array(
        'SELECT reason FROM alert_state WHERE rule_id = ? AND series = ?',
        undef, $id, 'all'))[0] };

    $E->can('run')->(db => $db, store => Scripted::Store->new,
                     now => at(0), force => 1);
    like($reason_of->(), qr/scripted failure/,
         'a died query writes its message as the reason');

    # A die WITHOUT a trailing newline gains ` at ... line N` - which names
    # this module's line, not the rule's problem, and must not reach the
    # screen.
    { no warnings 'once';
      *Croaky::Store::query = sub { die 'connection refused' }; }
    $E->can('run')->(db => $db, store => (bless {}, 'Croaky::Store'),
                     now => at(15), force => 1);
    is($reason_of->(), 'connection refused',
         '  stripped of the croak location perl appended');

    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        { ok => 0, error => 'query budget refused' }), now => at(30),
        force => 1);
    like($reason_of->(), qr/query budget refused/,
         'a store refusal carries the store\'s own error');

    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        { ok => 1, shape => 'rows', rows => [] }), now => at(60), force => 1);
    like($reason_of->(), qr/shape 'rows'.*bucket stage/,
         'an unbucketed answer says to add a bucket stage - the one a user '
       . 'writes by accident');

    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        buckets([ at(90), 0 ])), now => at(90), force => 1);
    is($reason_of->(), undef, 'recovery clears the reason with the state');
}

# --- an empty successful answer is stale, not error ---------------------------

# The misclassification behind "the alerts page says broken, the metrics
# page runs the query fine": a query that ANSWERED with nothing in the
# window is every series vanishing, which is the machine's stale semantics,
# never its error latch.

{
    my $db = fresh_db();
    my $id = rule($db);

    # Fire first, so there is a row to retire.
    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        buckets([ at(-60), 5 ], [ at(-30), 5 ])), now => at(0), force => 1);
    is_deeply([ map { $_->{state} } @{ state_of($db, $id) } ], ['firing'],
              'the rule fires');

    my $empty = { ok => 1, shape => 'buckets', bucket_ns => '30000000000',
                  series => [], meta => {} };
    $E->can('run')->(db => $db, store => Scripted::Store->new->will($empty),
                     now => at(60), force => 1);
    is_deeply([ map { $_->{state} } @{ state_of($db, $id) } ], ['stale'],
              'an empty success retires the series instead of erroring');
    my ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ? AND kind = 3',
        undef, $id);
    is($n, 1, '  and a firing series going stale notifies as vanished');
    ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ? AND kind = 4',
        undef, $id);
    is($n, 0, '  with no error episode invented');
}

# --- a row this evaluation did not mention is reconciled ----------------------

# The immortal-row bug: a fail tick records error under the synthetic series
# `all`; the rule's query is then fixed to group by service, and no
# evaluation ever mentions `all` again - so the error outlived its cause by
# days, and the screen counted a broken rule whose query ran fine.

sub grouped {
    my (%s) = @_;
    return { ok => 1, shape => 'buckets', bucket_ns => '30000000000',
             series => [ map { { key => $_,
                                 points => [ map { [ @$_, 1 ] } @{ $s{$_} } ] } }
                         sort keys %s ],
             meta => {} };
}

{
    my $db = fresh_db();
    my $id = rule($db);

    $E->can('run')->(db => $db, store => Scripted::Store->new,
                     now => at(0), force => 1);
    is_deeply([ map { [ @$_{qw(series state)} ] } @{ state_of($db, $id) } ],
              [ [ 'all', 'error' ] ], 'a fail tick errors under `all`');

    # A grouped answer: `all` is never mentioned again. Without the
    # reconcile this row was immortal.
    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        grouped(shop => [ [ at(30), 0 ] ])), now => at(30), force => 1);
    is_deeply([ map { [ @$_{qw(series state)} ] } @{ state_of($db, $id) } ],
              [ [ 'all', 'ok' ], [ 'shop', 'ok' ] ],
              'a successful evaluation resolves the error row it did not '
            . 'mention');
    my ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ? AND kind = 2',
        undef, $id);
    is($n, 1, '  and the recovery notifies as resolved');

    # A firing series that stops being mentioned goes stale across passes,
    # exactly as it does within one run.
    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        grouped(shop => [ [ at(60), 5 ], [ at(90), 5 ] ])),
        now => at(90), force => 1);
    my %st = map { $_->{series} => $_->{state} } @{ state_of($db, $id) };
    is($st{shop}, 'firing', 'shop fires');

    $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        grouped(cards => [ [ at(120), 0 ] ])), now => at(120), force => 1);
    %st = map { $_->{series} => $_->{state} } @{ state_of($db, $id) };
    is($st{shop}, 'stale', 'a firing series absent from the next window '
                         . 'goes stale');
    ($n) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM notifications WHERE rule_id = ?
          AND series = ? AND kind = 3', undef, $id, 'shop');
    is($n, 1, '  and notifies as vanished');

    # A FAILED PASS RECONCILES NOTHING: a query that could not run says
    # nothing about which series exist.
    $E->can('run')->(db => $db, store => Scripted::Store->new,
                     now => at(150), force => 1);
    %st = map { $_->{series} => $_->{state} } @{ state_of($db, $id) };
    is($st{cards}, 'ok', 'a fail tick does not retire the rows it cannot '
                       . 'see');
}

# --- a silence suppresses delivery, never state ------------------------------

{
    my $db = fresh_db();
    my $id = rule($db);

    $C->can('save_silence')->($db, 'default',
        { pattern => 'error rate/', until => '1h' });

    my $out = $E->can('run')->(db => $db, store => Scripted::Store->new->will(
        buckets([ at(-60), 5 ], [ at(-30), 5 ])), now => at(0),
        group_wait_ns => 0, force => 1);
    is_deeply([ map { $_->{state} } @{ state_of($db, $id) } ], ['firing'],
              'a silenced rule still reaches firing - state is never touched');
    is(scalar @{ $out->{groups} }, 1, '  and its group still comes due');

    my $called;
    my $r = $E->can('notify')->(db => $db, group => $out->{groups}[0]{id},
        token => $out->{groups}[0]{token}, on_alert => sub { $called = 1 });
    ok(!$called, 'nobody is paged');
    is($r->{suppressed}, 1, '  and the suppression is COUNTED');
    my ($sup) = $db->dbh->selectrow_array(
        'SELECT suppressed FROM notifications WHERE rule_id = ?', undef, $id);
    is($sup, 1, '  and recorded on the row, so the screen can say why');
}

# --- the cadence is the rule's own -------------------------------------------

{
    my $db = fresh_db();
    rule($db, every => '60s');

    my $store = Scripted::Store->new->will(buckets([ at(-30), 0 ]))
                                   ->will(buckets([ at(0),   0 ]));
    my $a = $E->can('run')->(db => $db, store => $store, now => at(0));
    is($a->{evaluated}, 1, 'the first pass evaluates');
    my $b = $E->can('run')->(db => $db, store => $store, now => at(30));
    is($b->{evaluated}, 0, 'a pass before the rule is due skips it');
    my $c = $E->can('run')->(db => $db, store => $store, now => at(90));
    is($c->{evaluated}, 1, '  and one after its every runs it again');
}

# --- a crashed write cannot wedge the store ----------------------------------

{
    my $db = fresh_db();
    my $id = rule($db);

    # Force a die inside the recording transaction: delete the rule from
    # under the pass, so the alert_state insert hits the foreign key.
    my $store = Scripted::Store->new->will(
        buckets([ at(-60), 5 ], [ at(-30), 5 ]));
    my $rules = $db->dbh->selectall_arrayref(
        'SELECT * FROM alert_rules', { Slice => {} });
    $db->dbh->do('DELETE FROM alert_rules WHERE id = ?', undef, $id);

    my $died = !eval {
        # _record on the stale rule row: the FK refuses, and the guard must
        # roll back rather than leave the transaction holding the lock.
        Punk::Observe::Evaluate::_record($db->dbh, $rules->[0],
            { states => [ { series => 'all', state => 'firing',
                            since => at(-30), fired_at => at(-30) } ] },
            { '' => 5 }, at(0), 0);
        1;
    };
    ok($died, 'a write into a vanished rule dies');

    # THE LOCK IS FREE. This exact shape - die inside begin_work, no
    # rollback, evaluator sleeps holding the write lock - took down every
    # writer in the demo for a week.
    my $ok = eval {
        $db->dbh->do("INSERT INTO dashboards (tenant, slug, title)
                      VALUES ('default','x','X')");
        1;
    };
    ok($ok, '  and the next writer proceeds immediately')
        or diag($@);
}

done_testing();
