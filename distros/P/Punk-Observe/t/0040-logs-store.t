#!perl
# Log blocks: round-trip, compression, corruption, pruning, and the label
# allowlist that keeps a request id out of the stream key.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use POWire;

my $L = 'Punk::Observe::Log';
sub rt { $L->can('block_roundtrip')->($_[0], $_[1] // '1') }

diag($L->can('have_zlib')->() ? 'zlib: raw deflate'
                              : 'zlib: ABSENT, blocks stored uncompressed');

# --- round trip -------------------------------------------------------------

{
    my $lines = [
        { t => '1774224000000000000', severity => 9,  body => 'request started' },
        { t => '1774224000001000000', severity => 17, body => 'connection refused' },
        { t => '1774224000002000000', severity => 9,  body => 'retrying' },
    ];
    my $r = rt($lines);
    is($r->{count}, 3, 'three lines in the block');
    is(scalar @{ $r->{lines} }, 3, '  and three come back');
    is($r->{lines}[0]{body}, 'request started', '  body 0');
    is($r->{lines}[1]{body}, 'connection refused', '  body 1');
    is($r->{lines}[1]{severity}, 17, '  severity on the 24-point scale');
    is("$r->{lines}[0]{t}", '1774224000000000000',
       '  and a nanosecond timestamp above 2^53 is bit-exact');
    is("$r->{lines}[2]{t}", '1774224000002000000',
       '  including after two delta steps');
    is("$r->{t_min}", '1774224000000000000', 't_min bounds the block');
    is("$r->{t_max}", '1774224000002000000', 't_max bounds the block');
}

# Bodies that would break a naive line format.
{
    my $lines = [
        { t => 1000, severity => 9, body => '' },
        { t => 2000, severity => 9, body => "with\na newline" },
        { t => 3000, severity => 9, body => "with\0a nul" },
        { t => 4000, severity => 9, body => "caf\xc3\xa9 non-ascii" },
        { t => 5000, severity => 9, body => 'x' x 10000 },
    ];
    my $r = rt($lines);
    is(scalar @{ $r->{lines} }, 5, 'five awkward bodies round-trip');
    is($r->{lines}[0]{body}, '', '  an empty body stays empty');
    is($r->{lines}[1]{body}, "with\na newline", '  an embedded newline survives');
    is($r->{lines}[2]{body}, "with\0a nul", '  an embedded NUL survives');
    is($r->{lines}[3]{body}, "caf\xc3\xa9 non-ascii", '  non-ASCII survives');
    is(length($r->{lines}[4]{body}), 10000, '  and a 10KB body survives');
}

# --- trace correlation, which | logs depends on ----------------------------

{
    my $lines = [
        { t => 1000, severity => 17, body => 'failed',
          trace_hi => '1234567890123456789', trace_lo => '9876543210987654321',
          span_id  => '1111111111111111111' },
        { t => 2000, severity => 9, body => 'no trace here' },
    ];
    my $r = rt($lines);
    is("$r->{lines}[0]{trace_hi}", '1234567890123456789',
       'a trace id survives, in full 64-bit halves');
    is("$r->{lines}[0]{trace_lo}", '9876543210987654321', '  both halves');
    is("$r->{lines}[0]{span_id}",  '1111111111111111111', '  and the span id');
    is("$r->{lines}[1]{trace_hi}", '0',
       'a line with no trace carries none, and costs no bytes for it');
}

# An all-zero trace id is not a trace id, so it is not stored as one.
{
    my $r = rt([ { t => 1000, severity => 9, body => 'x',
                   trace_hi => '0', trace_lo => '0', span_id => '5' } ]);
    is("$r->{lines}[0]{trace_hi}", '0', 'an all-zero trace id is not recorded');
    is("$r->{lines}[0]{span_id}", '5', '  but a span id alone still is');
}

# --- out-of-order lines -----------------------------------------------------

# Lines can arrive out of order. The delta encoding must not corrupt them, and
# t_min/t_max must still bound the block - a wrong span means a time filter
# skips exactly the wrong block.
{
    my $r = rt([ map { { t => "$_", severity => 9, body => "line $_" } }
                 (5000, 3000, 9000, 1000, 7000) ]);
    is($r->{count}, 5, 'out-of-order lines are stored');
    is("$r->{t_min}", '1000', 't_min is the earliest, not the first');
    is("$r->{t_max}", '9000', 't_max is the latest, not the last');
    is($r->{lines}[0]{body}, 'line 5000', 'the lines keep their order');
    is($r->{lines}[3]{body}, 'line 1000', '  as written');
}

# --- compression, MEASURED --------------------------------------------------

SKIP: {
    skip 'no zlib', 4 unless $L->can('have_zlib')->();

    # Realistic log text: the redundancy in logs is BETWEEN lines, which is
    # why a block is compressed as a whole rather than line by line.
    my @svc = qw(checkout payments inventory);
    my @lines;
    for my $i (1 .. 3000) {
        push @lines, {
            t => "" . (1_000_000_000 + $i * 1_000_000),
            severity => ($i % 10 == 0 ? 17 : 9),
            body => sprintf('svc=%s method=POST path=/api/v1/orders status=%d '
                          . 'duration_ms=%d msg="request completed"',
                            $svc[$i % 3], ($i % 10 == 0 ? 500 : 200), $i % 400),
        };
    }
    my $r = rt(\@lines);
    is($r->{count}, 3000, '3000 realistic log lines');
    is(scalar @{ $r->{lines} }, 3000, '  all decompress back');
    ok(!$r->{stored}, '  and the block was actually compressed');

    my $ratio = $r->{raw_len} / $r->{comp_len};
    diag(sprintf('realistic logs: %d raw -> %d deflated = %.1fx  (%.1f bytes/line)',
                 $r->{raw_len}, $r->{comp_len}, $ratio,
                 $r->{comp_len} / $r->{count}));
    cmp_ok($ratio, '>', 5.0, 'realistic log text compresses better than 5x');
}

# Incompressible content must be STORED and say so, not claimed compressed.
# A block that claimed compression and was not would inflate to nothing.
SKIP: {
    skip 'no zlib', 2 unless $L->can('have_zlib')->();
    my $x = 12345;
    my @lines = map {
        my $s = '';
        for (1 .. 40) { $x = ($x * 1103515245 + 12345) % 2147483648;
                        $s .= chr(32 + $x % 95) }
        { t => "" . (1000 + $_), severity => 9, body => $s }
    } 1 .. 20;
    my $r = rt(\@lines);
    is(scalar @{ $r->{lines} }, 20, 'incompressible lines round-trip');
    ok($r->{comp_len} <= $r->{raw_len},
       '  and the stored length never exceeds the raw length');
}

# --- corruption is caught ---------------------------------------------------

# The CRC is over the RAW bytes, so a bad decompress is caught rather than fed
# onward as plausible garbage.
{
    my @bodies = map { "log line number $_ with some repeated text" } 1 .. 200;
    my $detected = 0;
    my $tried    = 0;
    for my $at (0, 5, 17, 40, 99, 150) {
        $tried++;
        $detected += $L->can('block_corrupt_detected')->(\@bodies, $at);
    }
    is($detected, $tried, "corruption at $tried different offsets is detected");
}

{
    # A byte past the end changes nothing, so it must NOT be reported as
    # corruption - otherwise the test above would pass vacuously.
    my @bodies = map { "line $_" } 1 .. 10;
    is($L->can('block_corrupt_detected')->(\@bodies, -1), 0,
       'an uncorrupted block inflates cleanly, so the check is not vacuous');
}

# --- the label allowlist ----------------------------------------------------

# A stream is a label set. A label set with a request id in it is one stream
# per request, which is the cardinality explosion in a different costume.
{
    my @defaults = $L->can('default_labels')->();
    ok(scalar @defaults >= 3, 'there is a default label allowlist');
    diag('default labels: ' . join(', ', @defaults));

    ok($L->can('is_label')->('service.name'), 'service.name is a label');
    ok($L->can('is_label')->('severity'),     'severity is a label');

    # The ones that would kill the store.
    for my $bad (qw(user_id request_id trace_id http.url session.id
                    http.request.header.authorization)) {
        ok(!$L->can('is_label')->($bad),
           "$bad is NOT a label, so it cannot multiply the stream count");
    }
}

# --- pruning ----------------------------------------------------------------

# Three tests in increasing cost order: stream, time, bloom. Only a survivor
# is decompressed.
{
    my $blocks = [
        { t_min => '1000', t_max => '2000', text => 'connection refused here' },
        { t_min => '3000', t_max => '4000', text => 'everything is fine' },
        { t_min => '5000', t_max => '6000', text => 'connection refused again' },
        { t_min => '7000', t_max => '8000', text => 'all quiet' },
    ];

    # Time alone.
    my $r = $L->can('prune')->($blocks, '3000', '4500', '');
    is_deeply($r->{kept}, [ 1 ], 'a time range keeps only the overlapping block');
    is($r->{skipped_time}, 3, '  skipping three on time alone, uninflated');

    # Time plus a search term.
    $r = $L->can('prune')->($blocks, '0', '9999', 'connection refused');
    is_deeply($r->{kept}, [ 0, 2 ],
              'a search term keeps only the blocks that can contain it');
    is($r->{skipped_bloom}, 2, '  the bloom pruned the other two');

    # A term present nowhere prunes everything.
    $r = $L->can('prune')->($blocks, '0', '9999', 'zebra stampede');
    is_deeply($r->{kept}, [], 'an absent term prunes every block');
    is($r->{skipped_bloom}, 4, '  all four, on the bloom');

    # A sub-trigram query cannot prune, so everything in range survives to be
    # scanned - it must not silently return nothing.
    $r = $L->can('prune')->($blocks, '0', '9999', 'is');
    is(scalar @{ $r->{kept} }, 4,
       'a two-byte query prunes nothing and falls through to scanning');
    is($r->{skipped_bloom}, 0, '  the bloom was not consulted at all');
}

done_testing();
