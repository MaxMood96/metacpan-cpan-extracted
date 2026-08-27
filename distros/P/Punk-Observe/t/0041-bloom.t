#!perl
# The bloom filter.
#
# ONE ASSERTION MATTERS MORE THAN THE REST: zero false negatives. A false
# positive costs a decompression; a false negative loses a log line, and
# nothing anywhere reports it.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $L = 'Punk::Observe::Log';
sub probe { $L->can('bloom_probe')->($_[0], $_[1]) }

# Realistic log text, generated so the corpus is reproducible.
sub gen_block {
    my ($seed, $lines) = @_;
    my @svc  = qw(checkout payments inventory shipping auth);
    my @lvl  = qw(INFO WARN ERROR DEBUG);
    my @msg  = ('connection refused', 'request completed', 'cache miss',
                'retrying upstream', 'timeout waiting for lock',
                'user session expired', 'payload too large');
    my $x = $seed;
    my $r = sub { $x = ($x * 1103515245 + 12345) % 2147483648; return $x };
    my $out = '';
    for (1 .. $lines) {
        $out .= sprintf("%s [%s] svc=%s trace=%08x %s id=%d\n",
                        '2026-08-25T10:' . sprintf('%02d:%02d', $r->() % 60, $r->() % 60),
                        $lvl[ $r->() % @lvl ], $svc[ $r->() % @svc ],
                        $r->(), $msg[ $r->() % @msg ], $r->() % 100000);
    }
    return $out;
}

# --- ZERO FALSE NEGATIVES ---------------------------------------------------

# For every trigram actually present in a block, the filter must say possible.
# One failure here fails the suite.
{
    my $false_neg = 0;
    my $checked   = 0;
    my $blocks    = 200;

    for my $b (1 .. $blocks) {
        my $text = gen_block($b * 7717, 40);

        # every distinct trigram genuinely in the text, case-folded the way
        # the filter folds
        my %tri;
        my $lc = lc $text;
        for my $i (0 .. length($lc) - 3) { $tri{ substr($lc, $i, 3) } = 1 }
        my @tris = keys %tri;

        my $r = probe($text, \@tris);
        for my $i (0 .. $#tris) {
            $checked++;
            $false_neg++ unless $r->{possible}[$i];
        }
    }
    diag("checked $checked present trigrams across $blocks blocks");
    is($false_neg, 0,
       "ZERO false negatives over $checked trigrams actually present");
}

# The same for whole search terms, which is what a user actually types.
{
    my $text = gen_block(31337, 500);
    my @present = ('connection refused', 'timeout waiting for lock',
                   'cache miss', 'checkout', 'payments', 'ERROR', 'svc=',
                   'user session expired', 'payload too large');
    my $r = probe($text, \@present);
    my @missed = grep { !$r->{possible}[$_] } 0 .. $#present;
    is(scalar @missed, 0, 'every term genuinely present is reported possible')
        or diag('missed: ' . join(', ', @present[@missed]));
}

# Case-insensitivity, both directions. Folding only at query time would skip
# blocks holding the term in another case - a false negative in disguise.
{
    my $text = "The Quick Brown FOX jumps\nCONNECTION REFUSED by upstream\n";
    my $r = probe($text, [ 'quick brown', 'QUICK BROWN', 'Quick Brown',
                           'connection refused', 'Connection Refused' ]);
    is(scalar(grep { !$_ } @{ $r->{possible} }), 0,
       'a term is found whatever case it is indexed or queried in');
}

# --- false positives are bounded and measured -------------------------------

{
    my $text = gen_block(999, 500);
    # Terms constructed so they cannot appear: random 12-char strings.
    my @absent;
    my $x = 4242;
    for (1 .. 2000) {
        my $s = '';
        for (1 .. 12) {
            $x = ($x * 1103515245 + 12345) % 2147483648;
            $s .= chr(ord('a') + $x % 26);
        }
        push @absent, $s unless index(lc $text, $s) >= 0;
    }
    my $r = probe($text, \@absent);
    my $fp = grep { $_ } @{ $r->{possible} };
    my $rate = $fp / scalar(@absent);
    diag(sprintf('false positives: %d of %d absent terms = %.4f%%  (%d bits, %d distinct trigrams)',
                 $fp, scalar @absent, $rate * 100, $r->{bits}, $r->{distinct}));
    cmp_ok($rate, '<', 0.02,
           'the false-positive rate on absent terms is under 2 per cent');
}

# A single absent trigram is enough to prune, so a long absent term is very
# unlikely to false-positive. Short ones are the harder case.
{
    my $text = gen_block(555, 200);
    my @three;
    my $x = 77;
    for (1 .. 500) {
        my $s = '';
        for (1 .. 3) {
            $x = ($x * 1103515245 + 12345) % 2147483648;
            $s .= chr(ord('a') + $x % 26);
        }
        push @three, $s unless index(lc $text, $s) >= 0;
    }
    my $r = probe($text, \@three);
    my $fp = grep { $_ } @{ $r->{possible} };
    diag(sprintf('3-byte absent terms: %d of %d false positive',
                 $fp, scalar @three));
    cmp_ok($fp / (scalar(@three) || 1), '<', 0.10,
           'even single-trigram terms false-positive under 10 per cent');
}

# --- the sizing -------------------------------------------------------------

# The filter is sized from the MEASURED distinct-trigram count, so a bigger
# block gets more bits rather than a worse rate.
{
    my $small = probe(gen_block(1, 20),  [ 'x' ]);
    my $big   = probe(gen_block(1, 2000), [ 'x' ]);
    cmp_ok($big->{distinct}, '>', $small->{distinct},
           'a bigger block has more distinct trigrams');
    cmp_ok($big->{bits}, '>', $small->{bits},
           '  and is given more bits, rather than a worse rate');
    is($small->{bits} & ($small->{bits} - 1), 0,
       'the bit count is a power of two, so the index masks');
}

# --- queries shorter than a trigram -----------------------------------------

# A query under three bytes has NO trigrams. Pruning on it would test nothing
# and exclude every block, so a search for "ok" must fall through to scanning
# rather than silently returning empty. This is the bug that would make short
# searches quietly wrong.
{
    ok(!$L->can('query_usable')->(''),   'an empty query cannot use the filter');
    ok(!$L->can('query_usable')->('o'),  'one byte cannot');
    ok(!$L->can('query_usable')->('ok'), 'two bytes cannot');
    ok($L->can('query_usable')->('ok!'), 'three bytes can');

    my $text = "everything is ok here\n";
    my $r = probe($text, [ 'ok', 'x', '' ]);
    is(scalar(grep { !$_ } @{ $r->{possible} }), 0,
       'a sub-trigram query is reported POSSIBLE, never pruned away');
}

# --- the exact match after the filter --------------------------------------

# The filter prunes; this decides. Case-folded to agree with the filter.
{
    my $hay = "Connection REFUSED by upstream service\n";
    ok($L->can('contains')->($hay, 'connection refused'), 'exact match, folded');
    ok($L->can('contains')->($hay, 'CONNECTION REFUSED'), '  either case');
    ok($L->can('contains')->($hay, 'upstream'),           '  mid-string');
    ok(!$L->can('contains')->($hay, 'connection  refused'),
       '  and does not match across a different spacing');
    ok(!$L->can('contains')->($hay, 'zebra'), '  absent term is absent');
}

# Non-ASCII: a trigram may split a codepoint, which is harmless because the
# query splits the same way and the survivor is matched exactly.
{
    my $text = "caf\xc3\xa9 serving na\xc3\xafve users\n";
    my $r = probe($text, [ "caf\xc3\xa9", "na\xc3\xafve" ]);
    is(scalar(grep { !$_ } @{ $r->{possible} }), 0,
       'multi-byte UTF-8 terms are found despite byte-level trigrams');
    ok($L->can('contains')->($text, "caf\xc3\xa9"),
       '  and the exact match confirms them');
}

done_testing();
