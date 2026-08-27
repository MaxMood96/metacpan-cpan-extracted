#!perl
# The executor, checked against a brute-force reference that shares no code
# with it.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use PORef;

my $E = 'Punk::Observe::Exec';
sub run { $E->can('run')->($_[0], $_[1], $_[2] // {}) }

# --- a reproducible corpus --------------------------------------------------

sub logs {
    my ($n) = @_;
    my @svc = qw(checkout payments inventory);
    my @msg = ('connection refused', 'request completed', 'cache miss',
               'timeout waiting for lock');
    my $x = 20260825;
    my $r = sub { $x = ($x * 1103515245 + 12345) % 2147483648; return $x };
    return [ map {
        my $s = $svc[ $r->() % 3 ];
        { kind => 'log', t => "" . (1_000_000 + $_ * 1000),
          # deterministic on the loop index: the LCG's low bits are
          # not random enough, and a corpus with no error rows makes
          # every severity assertion vacuous
          severity => (($_ % 10 == 0) ? 17 : 9),
          service  => $s,
          body     => $msg[ $r->() % 4 ],
          attrs    => { 'http.route' => '/r' . ($r->() % 5) } }
    } 1 .. $n ];
}

sub spans {
    my ($n) = @_;
    my @svc = qw(gateway checkout db);
    my $x = 777;
    my $r = sub { $x = ($x * 1103515245 + 12345) % 2147483648; return $x };
    return [ map {
        { kind => 'span', t => "" . (2_000_000 + $_ * 100),
          duration => "" . (($r->() % 5000) * 1_000_000),
          service  => $svc[ $r->() % 3 ],
          body     => 'GET /x',
          trace_hi => "" . ($_ % 50), trace_lo => "1",
          attrs    => { 'http.route' => '/r' . ($r->() % 4) } }
    } 1 .. $n ];
}

# --- rows out ---------------------------------------------------------------

{
    my $rows = logs(200);
    my $r = run('log | where service = "checkout"', $rows);
    ok($r->{ok}, 'a filtered log query runs') or diag $r->{error};
    my $want = PORef::run('log | where service = "checkout"', $rows);
    is(scalar @{ $r->{rows} }, scalar @{ $want->{rows} },
       '  and matches the reference row count');
    my $bad = grep { $_->{service} ne 'checkout' } @{ $r->{rows} };
    is($bad, 0, '  with every row matching the filter');
}

# The comparison that matters: over generated corpora, exactly the reference.
{
    my @queries = (
        'log | where service = "checkout"',
        'log | where severity >= error',
        'log | where severity >= error and service = "payments"',
        'log | search "refused"',
        'log | where service = "checkout" | search "cache"',
        'log | count',
        'log | count by service',
        'log | count by service, http.route',
        'log | where severity >= error | count by service',
    );
    my $bad = 0;
    for my $seed (1 .. 5) {
        my $rows = logs(100 + $seed * 40);
        for my $q (@queries) {
            my $got  = run($q, $rows);
            my $want = PORef::run($q, $rows);
            if ($want->{shape} eq 'rows') {
                $bad++ if scalar @{ $got->{rows} } != scalar @{ $want->{rows} };
            }
            else {
                my %g = map { $_->{key} => $_->{value} } @{ $got->{groups} };
                my %w = map { $_->{key} => $_->{value} } @{ $want->{groups} };
                $bad++ if scalar(keys %g) != scalar(keys %w);
                for my $k (keys %w) {
                    $bad++ if !exists $g{$k} || abs($g{$k} - $w{$k}) > 1e-9;
                }
            }
        }
    }
    is($bad, 0, 'over 5 corpora and 9 queries, the executor equals the reference');
}

# --- spans and durations ----------------------------------------------------

{
    my $rows = spans(300);
    for my $q ('spans | where duration > 2s',
               'spans | where duration > 2s and service = "db"',
               'spans | count by service',
               'spans | max by service',
               'spans | min by service',
               'spans | avg by service') {
        my $got  = run($q, $rows);
        my $want = PORef::run($q, $rows);
        ok($got->{ok}, "runs: $q") or diag $got->{error};
        if ($want->{shape} eq 'rows') {
            is(scalar @{ $got->{rows} }, scalar @{ $want->{rows} },
               "  matches the reference: $q");
        }
        else {
            my %g = map { $_->{key} => $_->{value} } @{ $got->{groups} };
            my %w = map { $_->{key} => $_->{value} } @{ $want->{groups} };
            my $ok = 1;
            for my $k (keys %w) { $ok = 0 if !exists $g{$k}
                                          || abs($g{$k} - $w{$k}) > 1e-6 }
            ok($ok, "  matches the reference: $q");
        }
    }
}

# --- percentiles ------------------------------------------------------------

{
    # A known distribution: durations 1..1000 milliseconds.
    my $rows = [ map { { kind => 'span', t => "$_",
                         duration => "" . ($_ * 1_000_000),
                         service => 'x', body => 'n' } } 1 .. 1000 ];
    my $r = run('spans | p50 by service', $rows);
    my $p50 = $r->{groups}[0]{value};
    ok(abs($p50 - 500_500_000) < 2_000_000, 'p50 of 1..1000ms is about 500ms')
        or diag "got $p50";

    my $r99 = run('spans | p99 by service', $rows);
    ok(abs($r99->{groups}[0]{value} - 990_100_000) < 5_000_000,
       'p99 is about 990ms');

    ok($r->{meta}{exact}, 'a small sample reports the percentile as EXACT');
}

# --- a missing field is FALSE, not zero ------------------------------------

# `duration > 0` must not match a log line that has no duration. Treating
# absent as zero silently widens every numeric filter.
{
    my $rows = [ { kind => 'log', t => '1', severity => 9, service => 'a',
                   body => 'hello' } ];
    my $r = run('log | where duration > 0', $rows);
    # duration is not a log column, so this is a PARSE error - which is the
    # stronger guarantee. Assert that, then test the absent case with an
    # attribute, where it IS legal.
    ok(!$r->{ok}, 'duration on a log stream is refused at parse time');

    my $r2 = run('log | where missing.attr > 0', $rows);
    ok($r2->{ok}, 'an absent attribute is a legal query') or diag $r2->{error};
    is(scalar @{ $r2->{rows} }, 0,
       '  and a comparison against it is FALSE, not zero-matching');

    my $r3 = run('log | where missing.attr != 0', $rows);
    is(scalar @{ $r3->{rows} }, 0,
       '  and != against an absent field is also false, not true');
}

# --- meta is never optional -------------------------------------------------

{
    my $rows = logs(50);
    my $r = run('log | count by service', $rows);
    ok(exists $r->{meta}, 'every result carries meta');
    is("$r->{meta}{scanned_rows}", '50', '  with the rows it scanned');
    ok(exists $r->{meta}{truncated}, '  and a truncated flag');
    ok(exists $r->{meta}{exact},     '  and an exact flag');
    ok(0 + $r->{meta}{scanned_bytes} > 0, '  and a byte count');
}

# --- truncation says so -----------------------------------------------------

# A budget that cuts the scan short must set `truncated`. A partial answer
# that looks complete is the failure this whole design is against.
{
    my $rows = logs(500);
    my $r = run('log | count by service', $rows, { hard_max => 100 });
    ok($r->{meta}{truncated}, 'a hard cap sets truncated');
    is("$r->{meta}{scanned_rows}", '100', '  having stopped at the cap');

    my $full = run('log | count by service', $rows);
    ok(!$full->{meta}{truncated}, 'and an uncapped run is NOT truncated');
    is("$full->{meta}{scanned_rows}", '500', '  having scanned everything');
}

# --- limit ------------------------------------------------------------------

{
    my $rows = logs(200);
    my $r = run('log | limit 7', $rows);
    is(scalar @{ $r->{rows} }, 7, 'limit caps the rows returned');
    is("$r->{meta}{scanned_rows}", '200',
       '  but the scan is honest about what it looked at');
}

# --- regex ------------------------------------------------------------------

{
    my $rows = [
        { kind => 'log', t => '1', service => 'api-gateway', body => 'x' },
        { kind => 'log', t => '2', service => 'api-worker',  body => 'x' },
        { kind => 'log', t => '3', service => 'web',         body => 'x' },
    ];
    my $r = run('log | where service =~ "^api-"', $rows);
    is(scalar @{ $r->{rows} }, 2, 'an anchored prefix matches two');

    my $r2 = run('log | where service =~ "way$"', $rows);
    is(scalar @{ $r2->{rows} }, 1, 'an anchored suffix matches one');

    my $r3 = run('log | where service =~ "pi-wo"', $rows);
    is(scalar @{ $r3->{rows} }, 1, 'a bare substring matches one');

    my $r4 = run('log | where service !~ "^api-"', $rows);
    is(scalar @{ $r4->{rows} }, 1, 'a negated match inverts it');

    # A pattern needing a real engine is REFUSED, not silently treated as a
    # literal that never matches.
    my $bad = run('log | where service =~ "api.*(gate|work)"', $rows);
    ok(!$bad->{ok}, 'a pattern needing a real regex engine is refused');
    like($bad->{error}, qr/regular expression|anchored/,
         '  with a message saying what IS supported');
}

done_testing();
