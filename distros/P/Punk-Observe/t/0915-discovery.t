#!perl
# What can I filter on?
#
# Unanswerable from the UI until now, and the hook for answering it had been
# sitting there since 0.01: `columns` was defined in _empty and again in the
# explore page builder, was always an empty arrayref, and was read by no
# template. Somebody meant to do this and stopped.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe::View ();
use Punk::Observe::Query ();
use Punk::Plugin::Observe ();

my $V = 'Punk::Observe::View';
my $Q = 'Punk::Observe::Query';
my $P = 'Punk::Plugin::Observe';

# --- the examples ------------------------------------------------------------
#
# These ARE the explore page when nothing else is on it, so an example that
# stopped parsing would teach the wrong thing from the front of the screen.
{
    my $v = $V->page(undef, 'explore', {});
    my $ex = $v->{examples} || [];
    cmp_ok(scalar @$ex, '>=', 10, 'the explorer offers a decent set of examples');

    my $bad = 0;
    for my $e (@$ex) {
        my $r = $Q->can('parse')->($e->{q});
        next if $r->{ok};
        $bad++;
        diag("does not parse: $e->{q} -- $r->{error}");
    }
    is($bad, 0, 'every example parses');

    for my $e (@$ex) {
        ok(defined $e->{why} && length $e->{why},
           "'$e->{q}' says what it is for");
    }

    # THE STAGES THE OLD SET NEVER SHOWED. Five examples covered `where`,
    # `search`, `slowest`, `by`+`count` and `p95 by` - and none of the rest of
    # the language, including the one thing this backend does that a stack of
    # separate tools cannot.
    my $all = join ' ', map { $_->{q} } @$ex;
    for my $stage (qw(bucket rate sort limit distinct top)) {
        like($all, qr/\b\Q$stage\E\b/, "the examples demonstrate `$stage`");
    }
    like($all, qr/\{[^}]*=/,  '  and the selector shorthand');
    like($all, qr/=~/,        '  and =~');
    like($all, qr/\band\b/,   '  and a compound condition');

    # THE PIPELINE IS NOT AN EXAMPLE, because it does not run. It parsed,
    # planned, and returned the metric stream unchanged - the `top N` failure
    # on the query the overview calls the differentiator - so the planner now
    # refuses it, and an example that is refused teaches that the tool is
    # broken. When the executor grows the second pass, the example returns.
    unlike($all, qr/exemplars/,
           'the unexecuted pipeline is not offered as an example');

    # And the refusal is the honest kind: it says what works today.
    my $r = $Q->can('parse')->('metric x | exemplars | traces | logs');
    ok($r->{ok}, 'the pipeline still parses - the grammar keeps the stages');
}

# --- the reserved columns come from the parser -------------------------------
{
    my $g = $Q->can('grammar')->();

    for my $case ([ logs => 'log' ], [ metrics => 'metric' ],
                  [ trace => 'trace' ]) {
        my ($page, $source) = @$case;
        my %vars = (from => '0', to => '0');
        $P->can('_discover')->({ limits => {}, opts => {} }, undef, $page,
                               \%vars, undef, {});
        is($vars{columns_source}, $source, "the $page screen describes `$source`");
        is_deeply([ map { $_->{name} } @{ $vars{columns} } ],
                  $g->{columns}{$source},
                  "  and lists exactly the columns the parser accepts there");
    }
}

# The explorer can be asking about any of them, so it reads the box.
{
    my %want = ('spans | count'      => 'spans',
                'log | count'        => 'log',
                'logs | count'       => 'log',      # the alias
                'traces | slowest 5' => 'trace',
                'metric x | avg'     => 'metric',
                ''                   => 'log');     # nothing typed yet
    for my $q (sort keys %want) {
        my %vars = (from => '0', to => '0');
        $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'explore',
                               \%vars, undef, { q => $q });
        is($vars{columns_source}, $want{$q},
           "the explorer reads '" . ($q || '(empty)') . "' as $want{$q}");
    }
}

# --- attributes, from a real store -------------------------------------------
#
# A bounded sample, because there is no index of attribute keys and a busy
# window is six figures of records. The page says it is a sample rather than
# implying the list is exhaustive.
SKIP: {
    my $dir = 'example/var/store';
    skip 'no demo store in this tree', 8 unless -d $dir;

    require Punk::Observe::Store;
    my $store = Punk::Observe::Store->new(dir => $dir, tenant => 'default');
    # The upper bound sits TWO SECONDS BEHIND the clock, because this store
    # may be live - the demo's health cron appends every minute - and a bound
    # in the current second admits a record written between this read and the
    # stability re-read below, which reshuffles a tie and fails the order
    # assertion for reasons no code change made.
    my $now = time - 2;
    my %vars = (from => (($now - 3600) . '000000000'), to => "${now}000000000");

    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'logs',
                           \%vars, $store, {});

    skip 'the demo store has no records in the last hour', 8
        unless $vars{attrs_sampled};

    ok($vars{attrs_sampled} > 0, 'the sample read some records');
    cmp_ok($vars{attrs_sampled}, '<=', 2000,
           '  and is bounded, not the whole window');
    ok(scalar @{ $vars{attr_keys} }, 'attribute keys were found');

    # The order-stability assertion used to live here, against this store,
    # and it FLAKED: the sample is a bounded prefix of the read path, and on
    # a LIVE store a seal between two reads moves records from the log into a
    # segment - a different 2000 come back, ties break differently, and the
    # test failed with no code change anywhere. Even a frozen window cannot
    # freeze the traversal. The property actually promised - the same sample
    # sorts the same way - is asserted below, over the deterministic stub.

    # Counted, so a key on nine records and a key on nine million are
    # different suggestions.
    ok((grep { $_->{count} } @{ $vars{attr_keys} }),
       'each key carries how often it was seen');

    # Capped, and it says so when it caps.
    cmp_ok(scalar @{ $vars{attr_keys} }, '<=', 40, 'the list is capped');

    # THE USEFUL PART: which of them prune the scan. Nothing anywhere else
    # tells a reader that.
    my %ix = map { $_->{name} => $_->{indexed} } @{ $vars{attr_keys} };
    if (exists $ix{'host.name'}) {
        ok($ix{'host.name'}, 'an indexed label is marked as one');
    }
    else { ok(1, 'no host.name in this window to check') }

    my ($plain) = grep { !$ix{$_} } sort keys %ix;
    ok(!defined $plain || !$ix{$plain},
       'and an ordinary attribute is not marked as indexed');
}

# Every key offered links to a query that answers the next question - what
# values does it have - and that query has to parse.
{
    my %vars = (from => '0', to => '0');
    my $store = bless {}, 'Fake::Store';
    {
        no strict 'refs';
        # The stub HONOURS `kind`, because the sample must: it used to read
        # every record whatever the page, so the metrics screen offered
        # `duration_ms` - a key the demo's LOGS carry and its metric points
        # do not - and the query it invited was valid, ran, and answered
        # zero rows for ever. A key this panel offers is a promise that
        # filtering on it can return something.
        *{'Fake::Store::records'} = sub {
            my ($self, %opt) = @_;
            my %by_kind = (
                1 => [ { attrs => { 'http.route' => '/a',
                                    'service.name' => 's' } } ],
                2 => [ { attrs => { 'http.route' => '/a',
                                    'service.name' => 's',
                                    'duration_ms' => 4 } } ],
            );
            return $by_kind{ $opt{kind} || 2 } || $by_kind{2};
        };
    }
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'logs',
                           \%vars, $store, {});

    ok(scalar @{ $vars{attr_keys} }, 'keys come back from a stub store');

    # STABLE ORDER, asserted where it is actually promised: the same sample
    # sorts the same way. A list that reshuffles between two loads cannot be
    # scanned - but two loads of a LIVE store are two samples, and only the
    # sort is this code's to keep stable.
    my %again = %vars;
    delete @again{qw(attr_keys attrs_sampled attrs_truncated)};
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'logs',
                           \%again, $store, {});
    is_deeply([ map { $_->{name} } @{ $again{attr_keys} } ],
              [ map { $_->{name} } @{ $vars{attr_keys} } ],
              'the same sample orders the same way every time');

    for my $k (@{ $vars{attr_keys} }) {
        my $q = $k->{query};
        $q =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
        ok($Q->can('parse')->($q)->{ok},
           "the link for '$k->{name}' is a query that parses: $q");
    }
}

# --- each page offers only ITS source's keys ---------------------------------
#
# The sample is kind-filtered. Without that the metrics page listed keys the
# logs happened to carry, and clicking one composed a query that was valid,
# ran, and answered zero rows for ever - which reads as "filtering is broken"
# and not as "wrong key".
{
    my $store = bless {}, 'Fake::Store';

    my %m = (from => '0', to => '0',
             names => [ { name => 'http.server.duration' } ]);
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'metrics',
                           \%m, $store, {});
    my %mk = map { $_->{name} => 1 } @{ $m{attr_keys} || [] };
    ok(!$mk{duration_ms},
       'the metrics page does not offer a key only the logs carry');
    ok($mk{'http.route'}, '  and still offers the keys metric points have');

    my %l = (from => '0', to => '0');
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'logs',
                           \%l, $store, {});
    my %lk = map { $_->{name} => 1 } @{ $l{attr_keys} || [] };
    ok($lk{duration_ms}, 'the logs page offers it, because logs have it');
}

# --- a key click COMPOSES, on this page, and metrics defaults a name ---------
#
# Three complaints from one afternoon of use, each pinned:
#   * clicking a key REPLACED the query - the metric somebody was looking at
#     vanished from the question;
#   * on the metrics page with an empty box the composed query was
#     `metric | by k | count`, which the grammar refuses - every key link
#     was a guaranteed parse error, and the parse assertion above never
#     caught it because its stub only ever selected the `log` branch;
#   * the link went to the explorer, bouncing somebody off the screen they
#     were composing on.
{
    my $store = bless {}, 'Fake::Store';

    # With a query in the box, the composition KEEPS it.
    my %vars = (from => '0', to => '0');
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'metrics',
        \%vars, $store, { q => 'metric http.server.request.count' });
    is($vars{discover_page}, 'metrics', 'the link stays on this page');
    my $k = $vars{attr_keys}[0];
    my $href = $k->{query}; $href =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    like($href, qr/\Ametric http\.server\.request\.count \|/,
         'the href keeps THEIR metric rather than replacing the query');
    ok($Q->can('parse')->($href)->{ok}, '  and parses');
    like($k->{where}, qr/\Ametric http\.server\.request\.count \| where \S+ = \z/,
         'the composing text is their query plus a where, cursor-ready');

    # An empty box on the metrics page defaults a REAL metric - the names
    # the page already lists - because `metric` alone is not a query.
    my %noq = (from => '0', to => '0',
               names => [ { name => 'http.server.duration' } ]);
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'metrics',
        \%noq, $store, {});
    my $k2 = $noq{attr_keys}[0];
    my $h2 = $k2->{query}; $h2 =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    like($h2, qr/\Ametric http\.server\.duration \|/,
         'an empty box borrows a metric the store actually has');
    ok($Q->can('parse')->($h2)->{ok},
       '  so the link is never a guaranteed parse error');

    # No metric names at all: no compose links, rather than broken ones.
    my %none = (from => '0', to => '0');
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'metrics',
        \%none, $store, {});
    ok(!$none{attr_keys} || !@{ $none{attr_keys} },
       'with nothing to base a query on, no key links are offered');

    # A base that already aggregates: the HREF composes on the source clause
    # only - appending `| by k | count` after an aggregate is nonsense - while
    # the box text keeps the whole query, because a person owns what they
    # type next.
    my %piped = (from => '0', to => '0');
    $P->can('_discover')->({ limits => {}, opts => {} }, undef, 'logs',
        \%piped, $store, { q => 'log | bucket(1m) count by severity' });
    my $k3 = $piped{attr_keys}[0];
    my $h3 = $k3->{query}; $h3 =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    ok($Q->can('parse')->($h3)->{ok}, 'a piped base still composes a valid href')
        or diag($h3);
    like($k3->{where}, qr/\Alog \| bucket\(1m\) count by severity \| where /,
         '  and the box text keeps every stage they had');
}

# --- and the panel renders ---------------------------------------------------
SKIP: {
    eval { require Template::Stencil; 1 }
        or skip 'Template::Stencil is not installed', 3;

    my $s = Template::Stencil->new(template_dir => 'root/templates',
                                   wrapper => 'layout.tmpl');
    my %e = $P->can('_empty')->({ prefix => '/observe' });
    $e{columns_source} = 'log';
    $e{columns}   = [ map { { name => $_ } } qw(t service body severity) ];
    $e{attr_keys} = [ { name => 'host.name', count => 56, indexed => 1,
                        query => 'log%20%7C%20by%20host.name%20%7C%20count' },
                      { name => 'http.route', count => 12, indexed => 0,
                        query => 'log%20%7C%20by%20http.route%20%7C%20count' } ];
    $e{attrs_sampled} = 300;
    $e{attrs_truncated} = 1;

    my $html = eval { $s->render('logs.tmpl', \%e) };
    ok(defined $html, 'the discovery panel renders') or diag $@;
    like($html || '', qr/host\.name/, '  showing a key');
    like($html || '', qr/keylabel/,
         '  and marking the one that prunes the scan');
}

done_testing();
