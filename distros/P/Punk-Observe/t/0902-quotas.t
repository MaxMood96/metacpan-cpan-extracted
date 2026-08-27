#!perl
# The three limits, and the allowlist that matters more than any of them.
#
# TREATING THESE AS ONE LIMIT IS THE MISTAKE. Each has a wrong answer that is
# worse than the limit itself, and the wrong answers are different:
#
#   rate        -> a partial success naming the rejected count, NOT a 429
#   cardinality -> the NEW series is dropped, NEVER an eviction
#   storage     -> retention SHORTENS, writes are never refused
#
# The rate section moves the clock rather than sleeping.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Config;
use Test::More;
use Punk::Observe;

my $L = 'Punk::Observe::Limit';
sub rate    { $L->can('rate')->($_[0], $_[1]) }
sub storage { $L->can('storage')->($_[0], $_[1]) }
sub attrs   { $L->can('attrs')->($_[0], $_[1]) }

use constant SEC => 1_000_000_000;
require Math::BigInt;
my $EPOCH = '1700000000000000000';
sub at { Math::BigInt->new($EPOCH)->badd(sprintf '%.0f', $_[0] * 1e9)->bstr }

# --- INGEST RATE: a partial success, not a refusal -------------------------

{
    my $r = rate({ records => 100 },
        [ { at => at(0),   records => 60, bytes => 6000 },
          { at => at(0.1), records => 60, bytes => 6000 } ]);
    my @b = @{ $r->{batches} };
    is("$b[0]{accepted}", '60', 'the first batch fits entirely');
    is("$b[0]{rejected}", '0',  '  and nothing is rejected');
    is("$b[1]{accepted}", '40',
       'the second is PARTIALLY accepted up to the limit');
    is("$b[1]{rejected}", '20',
       '  and the rejected count is exact, which is what OTLP carries');
}

# THE POINT OF A PARTIAL SUCCESS. A whole-batch refusal makes the exporter
# re-send everything, forever, at the moment the server is under pressure -
# the limit becomes an amplifier. So over quota is never zero-accepted while
# any room remains.
{
    my $r = rate({ records => 100 },
        [ { at => at(0), records => 90,  bytes => 9000 },
          { at => at(0), records => 500, bytes => 50_000 } ]);
    my @b = @{ $r->{batches} };
    is("$b[1]{accepted}", '10',
       'a batch far over the limit still has its remaining room filled');
    cmp_ok(0 + $b[1]{accepted}, '>', 0,
           '  rather than being refused whole');
}

# The window resets, or the limit is a total rather than a rate.
{
    my $r = rate({ records => 100 },
        [ { at => at(0), records => 100, bytes => 1000 },
          { at => at(0.5), records => 50, bytes => 500 },
          { at => at(1.5), records => 50, bytes => 500 } ]);
    my @b = @{ $r->{batches} };
    is("$b[1]{accepted}", '0', 'inside the window the limit holds');
    is("$b[2]{accepted}", '50', 'and the next window admits again');
}

# Bytes and records are separate limits, because a thousand tiny records and
# one enormous one are different problems.
{
    my $r = rate({ bytes => 1000 },
        [ { at => at(0), records => 10, bytes => 2000 } ]);
    my @b = @{ $r->{batches} };
    is("$b[0]{accepted}", '5',
       'a byte limit admits as many records as the bytes allow');
}

{
    my $r = rate({ records => 100, bytes => 100 },
        [ { at => at(0), records => 100, bytes => 10_000 } ]);
    my @b = @{ $r->{batches} };
    cmp_ok(0 + $b[0]{accepted}, '<', 100,
           'when both are set the TIGHTER one governs');
}

# UNCONFIGURED IS OFF, not zero.
{
    my $r = rate({}, [ { at => at(0), records => 1_000_000, bytes => 1e9 } ]);
    my @b = @{ $r->{batches} };
    is("$b[0]{accepted}", '1000000',
       'an unconfigured limit admits everything rather than nothing');
}

# --- the boundary, and one either side -------------------------------------

{
    for my $c ([ 99, 99 ], [ 100, 100 ], [ 101, 100 ]) {
        my $r = rate({ records => 100 },
            [ { at => at(0), records => $c->[0], bytes => $c->[0] * 10 } ]);
        is("$r->{batches}[0]{accepted}", "$c->[1]",
           "offering $c->[0] against a limit of 100 accepts $c->[1]");
    }
}

# --- CARDINALITY: exact across forked workers ------------------------------
#
# An arena mapped AFTER the fork is private per worker, and the symptom is a
# limit silently N times what was configured - which looks like the limit not
# working rather than like a fork bug.

SKIP: {
    my $forked = $L->can('cardinality_forked');
    skip 'no cardinality_forked in this build', 6 unless $forked;
    skip 'no fork on this platform', 6 unless $Config{d_fork};

    {
        # Well under the cap: every series is admitted and the count is exact.
        my $r = $forked->('10000', 4, 250);
        skip 'no shared arena on this platform', 6 unless $r->{shared};
        is("$r->{admitted}", '1000',
           'four workers each admitting 250 series total EXACTLY 1000');
        is("$r->{rejected}", '0', '  with none rejected under the cap');
    }

    {
        # Over the cap: the total admitted is the cap, not four times it.
        my $r = $forked->('100', 4, 250);
        is("$r->{admitted}", '100',
           'over the cap, four workers admit the CAP and not four times it');
        is("$r->{rejected}", '900', '  and the rest are counted as rejected');
        is(0 + $r->{admitted} + 0 + $r->{rejected}, 1000,
           '  admitted plus rejected accounts for everything offered');
        cmp_ok(0 + $r->{admitted}, '<=', 100,
               'THE ARENA IS SHARED: a per-worker counter would give 400');
    }
}

# The counter never goes down, which is what makes "an existing series is
# never evicted" structural rather than a rule to remember.
{
    open my $fh, '<', 'include/punk_observe/po_shared.h' or die $!;
    my $src = do { local $/; <$fh> };
    close $fh;
    (my $code = $src) =~ s{/\*.*?\*/}{}gs;
    my ($fn) = $code =~ /(po_shared_admit_series.*?\n\})/s;
    ok($fn, 'the admit function was found');
    unlike($fn, qr/--|-=|\bevict|\bremove|\bdelete/i,
           'admission only ever increments, so nothing can be evicted');
}

# --- STORAGE: retention shortens, writes are never refused -----------------

{
    # Ten blocks of 100 bytes, oldest first, against a 550-byte budget.
    my @blocks = map { { age => "" . ($_ * 3600 * SEC), bytes => '100' } }
                 reverse 1 .. 10;
    my $r = storage(\@blocks, '550');
    is($r->{keep}, 5, 'a 550-byte budget keeps five 100-byte blocks');
    is("$r->{bytes}", '500', '  totalling 500 bytes');
    cmp_ok(0 + $r->{keep}, '<', 10, '  and drops the rest');
}

{
    my @blocks = map { { age => "" . ($_ * 3600 * SEC), bytes => '100' } }
                 reverse 1 .. 10;
    my $r = storage(\@blocks, '0');
    is($r->{keep}, 10, 'an unconfigured budget keeps everything');
}

{
    my @blocks = map { { age => "" . ($_ * 3600 * SEC), bytes => '100' } }
                 reverse 1 .. 10;
    my $r = storage(\@blocks, '10000');
    is($r->{keep}, 10, 'a budget larger than the store keeps everything');
}

# THE NEWEST BLOCK IS ALWAYS KEPT. A budget smaller than one block is a
# misconfiguration, and answering it by deleting the incident in progress
# would be the limiter doing more damage than the thing it limits.
{
    my @blocks = map { { age => "" . ($_ * 3600 * SEC), bytes => '100' } }
                 reverse 1 .. 10;
    my $r = storage(\@blocks, '10');
    is($r->{keep}, 1,
       'a budget smaller than one block still keeps the newest one');
    cmp_ok(0 + $r->{bytes}, '>', 10,
           '  deliberately over budget rather than deleting live data');
}

{
    my $r = storage([], '1000');
    is($r->{keep}, 0, 'an empty store keeps nothing and does not crash');
}

# The horizon reported is an AGE, which is what a retention job sets.
{
    my @blocks = map { { age => "" . ($_ * 3600 * SEC), bytes => '100' } }
                 reverse 1 .. 10;
    my $r = storage(\@blocks, '350');
    is($r->{keep}, 3, 'three blocks fit a 350-byte budget');
    is("$r->{horizon}", "" . (3 * 3600 * SEC),
       '  and the horizon is the age of the oldest one kept');
}

# --- THE ALLOWLIST THAT MATTERS MORE THAN ANY OF THE NUMBERS ---------------

{
    my $r = attrs([ 'service.name', 'severity' ],
                  [ 'service.name', 'severity', 'user_id', 'request_id' ]);
    is_deeply($r->{indexed}, [ 'service.name', 'severity' ],
              'only the allowlisted attributes become index dimensions');
    is_deeply($r->{residual}, [ 'user_id', 'request_id' ],
              'the rest are RESIDUAL - still in the record, just not indexed');
}

# NOTHING IS LOST. An unlisted attribute stays findable by residual filter;
# only the INDEX is bounded. Dropping it would be a different and much worse
# answer.
{
    my $r = attrs([ 'service.name' ], [ 'user_id' ]);
    is(scalar @{ $r->{indexed} }, 0, 'an unlisted attribute is not indexed');
    is(scalar @{ $r->{residual} }, 1, '  but it is still there');
    is($r->{residual}[0], 'user_id', '  and still named');
}

# THE OVERFLOW COUNTER NAMES THE ATTRIBUTE. The person who hits this first is
# a self-hoster with no support contract and no dashboard telling them which
# one did it, so "cardinality limit exceeded" is not an answer.
{
    my $r = attrs([ 'service.name' ],
                  [ ('user_id') x 5, ('trace_flags') x 2, 'service.name' ]);
    is($r->{worst}, 'user_id',
       'the overflow names the WORST attribute, not just a count');
    my ($u) = grep { $_->{name} eq 'user_id' } @{ $r->{overflow} };
    is("$u->{count}", '5', '  with how many times it was seen');
    my ($t) = grep { $_->{name} eq 'trace_flags' } @{ $r->{overflow} };
    is("$t->{count}", '2', '  and the runner-up counted too');
}

{
    # Past the naming cap, still counted rather than silently dropped.
    my @many = map { "attr_$_" } 1 .. 40;
    my $r = attrs([ 'service.name' ], \@many);
    is(scalar @{ $r->{overflow} }, 16, 'at most sixteen attributes are named');
    cmp_ok(0 + $r->{other}, '>', 0, '  and the rest are counted, not dropped');
    is(0 + $r->{other} + scalar @{ $r->{overflow} }, 40,
       '  so the total still accounts for every one');
}

{
    my $r = attrs(undef, [ 'service.name', 'severity', 'host.name', 'user_id' ]);
    cmp_ok(scalar @{ $r->{indexed} }, '>=', 3,
           'with no allowlist configured the default set applies');
    is_deeply($r->{residual}, [ 'user_id' ],
              '  and a request-scoped attribute is still kept out of the index');
}

done_testing();
