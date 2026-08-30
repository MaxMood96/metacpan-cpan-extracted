#!perl
# The alert rule editor: the writers, the form, and the silences.
#
# The gate for this file is the same as the dashboard editor's: an install
# configured with nothing but a path can create a rule on the screen, and
# everything refused is refused with the field it is about - because "that
# query does not parse" beside the query box is an instruction, and the same
# words over the whole form are a hunt.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

BEGIN {
    eval { require Template::Stencil; 1 }
        or plan skip_all => 'Template::Stencil not installed';
}
use Punk::Observe ();
use Punk::Observe::Backend ();
use Punk::Observe::Config ();
use Punk::Observe::View ();
use Punk::Plugin::Observe ();

my $C = 'Punk::Observe::Config';

sub fresh {
    my $dir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$dir/c.db");
    $db->migrate;
    return $db;
}

# --- the writers refuse with the field they are about ------------------------

{
    my $db = fresh();

    my $ok = $C->can('save_alert')->($db, 'default', {
        name => 'error rate',
        query => 'spans | where status = 2 | bucket(30s) count by service',
        op => '>', threshold => 5, for => '30s', every => '30s' });
    ok($ok->{ok}, 'a good rule saves');
    ok($ok->{id}, '  and comes back with its id');

    for my $bad (
        [ { query => 'spans | bucket(30s) count', op => '>', threshold => 1 },
          'name',      'no name' ],
        [ { name => 'x', query => 'spans %%%', op => '>', threshold => 1 },
          'query',     'a query that does not parse' ],
        [ { name => 'x', query => 'spans | count by service', op => '>',
            threshold => 1 },
          'query',     'an UNBUCKETED query - for cannot be measured over '
                     . 'one number' ],
        [ { name => 'x', query => 'spans | bucket(30s) count', op => '~',
            threshold => 1 },
          'op',        'an operator the machine does not speak' ],
        [ { name => 'x', query => 'spans | bucket(30s) count', op => '>',
            threshold => 'soon' },
          'threshold', 'a threshold that is not a number' ],
        [ { name => 'x', query => 'spans | bucket(30s) count', op => '>',
            threshold => 1, for => 'shortly' },
          'for',       'a duration that is not one' ],
    ) {
        my ($in, $field, $what) = @$bad;
        my $r = $C->can('save_alert')->($db, 'default', $in);
        ok(!$r->{ok} && $r->{refused}, "refused: $what");
        is($r->{field}, $field, "  naming the $field field");
    }

    # `every` is clamped, not refused: below the pass cadence it cannot be
    # honoured anyway, and a zero is an empty form field, not an intention.
    $C->can('save_alert')->($db, 'default', {
        id => $ok->{id}, name => 'error rate',
        query => 'spans | bucket(30s) count',
        op => '>', threshold => 5, for => '30s', every => '1s' });
    my $row = $C->can('alert')->($db, 'default', $ok->{id});
    cmp_ok($row->{every_ns}, '>=', 10_000_000_000,
           'every is clamped to something the pass can honour');

    # Saving resets the schedule, so an edited threshold is judged on the
    # NEXT pass rather than whenever the old cadence came round.
    my ($next) = $db->dbh->selectrow_array(
        'SELECT next_eval_at FROM alert_rules WHERE id = ?', undef, $ok->{id});
    is($next, 0, 'an edit resets the evaluation schedule');
}

# --- the form round-trips its own durations ----------------------------------

{
    my $db = fresh();
    my $r = $C->can('save_alert')->($db, 'default', {
        name => 'slow', query => 'spans | bucket(30s) p95',
        op => '>', threshold => 5e8, for => '90s', every => '5m' });
    my $rule = $C->can('alert')->($db, 'default', $r->{id});

    # The store holds nanoseconds; the form shows the duration the UI's own
    # formatter writes, and the UI's own parser reads it back to the same
    # count. If these two ever disagree, saving an untouched form would
    # silently change the rule.
    my %v = Punk::Plugin::Observe::_alert_form_vars($rule);
    for my $f (qw(for every)) {
        my ($ns) = Punk::Observe::View::min_duration($v{rule}{$f});
        is($ns, $rule->{"${f}_ns"},
           "$f survives store -> form -> store unchanged ($v{rule}{$f})");
    }
    my ($cur) = grep { $_->{current} } @{ $v{op_options} };
    is($cur->{name}, '>', 'the stored operator is the selected one');
}

# --- the editor renders, with exactly one token per form ---------------------

{
    my $db = fresh();
    my $r = $C->can('save_alert')->($db, 'default', {
        name => 'error rate', query => 'spans | bucket(30s) count',
        op => '>', threshold => 5, for => '30s', every => '30s' });
    my $rule = $C->can('alert')->($db, 'default', $r->{id});

    my $st = Template::Stencil->new({ template_dir => 'root/templates' });
    my %v = Punk::Plugin::Observe::_alert_form_vars($rule);
    my $html = $st->render('alertedit.tmpl', {
        prefix => '/observe', range_qs => '', editing => 1, creating => 0,
        writable => 1, csrf_field => '<input name="_csrf" value="tok">',
        error => '', hint => '', %v,
    });

    like($html, qr/value="error rate"/, 'the rule loads into the form');
    like($html, qr/bucket\(30s\)/,      '  query included');
    like($html, qr/value="30s"/,        '  durations as durations, not ns');

    # One token per form: the save form and the delete form each carry one.
    my $toks = () = $html =~ /name="_csrf"/g;
    is($toks, 2, 'each form carries exactly one CSRF token');

    my $ro = $st->render('alertedit.tmpl', {
        prefix => '/observe', range_qs => '', editing => 1, creating => 0,
        writable => 0, csrf_field => '', error => '', hint => '', %v,
    });
    like($ro, qr/read-only/i, 'a read-only mount says so on the editor');
    unlike($ro, qr/name="_csrf"/, '  and carries no token at all');
}

# --- silences: scoped, expiring, and never erased ----------------------------

{
    my $db = fresh();
    my $r = $C->can('save_alert')->($db, 'default', {
        name => 'error rate', query => 'spans | bucket(30s) count',
        op => '>', threshold => 5, for => '30s', every => '30s' });

    my $s = $C->can('save_silence')->($db, 'default',
        { pattern => 'error rate/', until => '1h',
          by => 'lnation', reason => 'deploying' });
    ok($s->{ok}, 'a silence saves');

    my $a = $C->can('alerts')->($db, 'default', {});
    is($a->{rules}[0]{silenced}, 1,
       'the rule row is badged - the reader used to never set this');
    is($a->{silences}[0]{by}, 'lnation',
       '  and the operator column is no longer permanently empty');
    ok($a->{silences}[0]{id}, '  and the row carries the id a revoke needs');

    # The trailing slash means the whole rule; a full key means one series.
    ok($C->can('silence_match')->('error rate/', 1, 'error rate/cards'),
       'a rule-wide pattern covers every series');
    ok(!$C->can('silence_match')->('error rate/cards', 0, 'error rate/shop'),
       '  a series pattern covers only its own');

    # REVOKED MEANS EXPIRED, NOT ERASED: suppression stops now, the record
    # of who silenced what - and why - survives for the incident's story.
    $C->can('delete_silence')->($db, 'default', $s->{id});
    my $a2 = $C->can('alerts')->($db, 'default', {});
    is(scalar @{ $a2->{silences} }, 0, 'a revoked silence stops suppressing');
    is($a2->{rules}[0]{silenced}, 0, '  immediately');
    my ($kept) = $db->dbh->selectrow_array(
        'SELECT COUNT(*) FROM silences', undef);
    is($kept, 1, '  and the row survives as the record of what happened');

    my $bad = $C->can('save_silence')->($db, 'default',
        { pattern => 'x/', until => 'whenever' });
    ok(!$bad->{ok} && $bad->{field} eq 'until',
       'a silence with no readable duration is refused, naming the field');
}

# --- deleting a rule takes its whole story with it ---------------------------

{
    my $db = fresh();
    my $r = $C->can('save_alert')->($db, 'default', {
        name => 'gone', query => 'spans | bucket(30s) count',
        op => '>', threshold => 1, for => '30s', every => '30s' });
    my $dbh = $db->dbh;
    $dbh->do("INSERT INTO alert_state (rule_id, series, state, last_seen)
              VALUES (?, 'all', 'firing', 1)", undef, $r->{id});
    $dbh->do("INSERT INTO alert_events
                  (rule_id, series, kind, from_state, to_state, at)
              VALUES (?, 'all', 1, 'ok', 'firing', 1)", undef, $r->{id});
    $dbh->do("INSERT INTO notifications
                  (rule_id, series, kind, at, created_at)
              VALUES (?, 'all', 1, 1, 1)", undef, $r->{id});

    my $d = $C->can('delete_alert')->($db, 'default', $r->{id});
    ok($d->{ok}, 'the rule deletes');
    for my $t (qw(alert_state alert_events notifications)) {
        my ($n) = $dbh->selectrow_array("SELECT COUNT(*) FROM $t");
        is($n, 0, "  and $t went with it - the cascade is real because the "
                . 'backend turns foreign keys on');
    }
}

done_testing();
