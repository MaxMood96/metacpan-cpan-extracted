#!perl
# The segment, the symbol table, and the manifest.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;

my $S = 'Punk::Observe::Segment';
my $dir = tempdir(CLEANUP => 1);
sub path { File::Spec->catfile($dir, $_[0]) }
sub slurp {
    open my $fh, '<', $_[0] or return '';
    binmode $fh; local $/; return scalar <$fh>;
}
sub spew {
    open my $fh, '>', $_[0] or die; binmode $fh; print $fh $_[1]; close $fh;
}

# --- the symbol table -------------------------------------------------------

{
    my $r = $S->can('intern_strings')->([
        qw(checkout checkout api checkout GET POST GET), '', 'checkout' ]);
    # checkout, api, GET, POST and the empty string: five distinct.
    is($r->{count}, 5, 'nine strings intern to five distinct symbols');
    is($r->{ids}[0], $r->{ids}[1], 'the same string gets the same id');
    is($r->{ids}[0], $r->{ids}[3], '  however far apart');
    isnt($r->{ids}[0], $r->{ids}[2], 'different strings get different ids');
    is($r->{ids}[4], $r->{ids}[6], 'and again for GET');

    # The round trip through the SERIALISED form is what a reader sees out of
    # an mmap, so that is what gets asserted rather than the in-memory table.
    is($r->{decoded}[ $r->{ids}[0] ], 'checkout', 'a symbol resolves back');
    is($r->{decoded}[ $r->{ids}[4] ], 'GET', '  and another');
    is($r->{decoded}[ $r->{ids}[7] ], '', 'the empty string is a real symbol');
}

# Symbols are where the compression comes from, so the size claim is measured
# rather than asserted in prose.
{
    my @many = ('checkout') x 1000;
    my $r = $S->can('intern_strings')->(\@many);
    is($r->{count}, 1, '1000 copies of one string are one symbol');
    cmp_ok($r->{bytes}, '<', 100,
           '  and the serialised table is under 100 bytes');
}

# --- writing and reading a segment ------------------------------------------

{
    my $p = path('a.seg');
    my $specs = [
        { t => '1774224000000000000', body => 'GET /a',
          labels => "service\0api" },
        { t => '1774224000000000500', body => 'GET /b',
          labels => "service\0api" },
        { t => '1774224000000000100', body => 'GET /a',
          labels => "service\0web" },
    ];
    is($S->can('write')->($p, $specs, 'acme', 0), $p, 'a segment is written');
    ok(-f $p, '  and exists');
    ok(!-f "$p.tmp", '  with no .tmp left behind');

    my $r = $S->can('read')->($p);
    ok($r, 'it mmaps and parses');
    is(scalar @{ $r->{records} }, 3, '  three records');
    is($r->{records}[0]{body}, 'GET /a', '  bodies resolve through the symbols');
    is($r->{records}[2]{body}, 'GET /a', '  including a repeated one');
    is("$r->{records}[0]{t}", '1774224000000000000',
       '  and a timestamp above 2^53 is bit-exact');

    # The footer's span must bound every record. This is the field the whole
    # pruning story rests on.
    is("$r->{t_min}", '1774224000000000000', 't_min is the earliest record');
    is("$r->{t_max}", '1774224000000000500', 't_max is the latest');

    # Two records with the SAME label block share a series; a third does not.
    is("$r->{records}[0]{series}", "$r->{records}[1]{series}",
       'the same label block gives the same series');
    isnt("$r->{records}[0]{series}", "$r->{records}[2]{series}",
         'a different one does not');
}

# --- a torn segment is refused ---------------------------------------------

{
    my $p = path('torn.seg');
    $S->can('write')->($p, [ { t => 1, body => 'x', labels => 'l' } ], 'acme', 0);
    my $full = slurp($p);

    ok($S->can('parse')->($full), 'the whole image parses');

    # Every truncation must be REFUSED, not half-read. The trailing magic is
    # what makes this one cheap check rather than a scan.
    my $accepted = 0;
    for my $n (0 .. length($full) - 1) {
        $accepted++ if defined $S->can('parse')->(substr($full, 0, $n));
    }
    is($accepted, 0,
       'not one of ' . length($full) . ' truncations is accepted');
}

# A segment whose body is corrupted but whose magic survives must still be
# refused - the trailing magic answers "is it whole", the CRC answers "is it
# what was written", and both are needed.
{
    my $p = path('corrupt.seg');
    $S->can('write')->($p, [ map { { t => $_, body => "b$_", labels => 'l' } }
                             1 .. 20 ], 'acme', 0);
    my $full = slurp($p);
    my $bad = $full;
    substr($bad, 100, 1) = chr(ord(substr($bad, 100, 1)) ^ 0xFF);
    ok(!defined $S->can('parse')->($bad),
       'a corrupted body is refused even with the magic intact');

    # And a footer pointing outside the file is a corrupt footer, not a big
    # segment.
    my $bogus = $full;
    substr($bogus, length($bogus) - 64 + 12, 8) = pack('a8', "\xff" x 8);
    ok(!defined $S->can('parse')->($bogus),
       'a footer whose regions escape the file is refused');
}

# --- pruning ----------------------------------------------------------------

{
    my $p = path('span.seg');
    $S->can('write')->($p, [
        { t => '2000', body => 'a', labels => 'l' },
        { t => '3000', body => 'b', labels => 'l' } ], 'acme', 0);

    ok($S->can('overlaps')->($p, '1000', '2500'), 'overlapping range matches');
    ok($S->can('overlaps')->($p, '2500', '9000'), 'the other side matches');
    ok($S->can('overlaps')->($p, '0', '9999'),    'an enclosing range matches');
    ok(!$S->can('overlaps')->($p, '0', '1999'),   'a range before does not');
    ok(!$S->can('overlaps')->($p, '3001', '9999'),'a range after does not');
    ok($S->can('overlaps')->($p, '2000', '2000'), 'the exact boundary matches');
}

# --- the manifest -----------------------------------------------------------

{
    my $m = path('MANIFEST');
    ok($S->can('manifest_append')->($m, 1, ['w0-a.seg', 'w1-b.seg']),
       'generation 1 appends');
    ok($S->can('manifest_append')->($m, 2, ['merged-c.seg']),
       'generation 2 appends');

    my $r = $S->can('manifest_latest')->(slurp($m));
    is("$r->{generation}", '2', 'the newest generation wins');
    is_deeply($r->{names}, ['merged-c.seg'], '  with its names');
}

# A torn last line is IGNORED, and the previous generation stands. That is the
# whole point of append-only: there is no window in which the file is neither
# the old state nor the new one.
{
    my $m = path('MANIFEST2');
    $S->can('manifest_append')->($m, 1, ['a.seg', 'b.seg']);
    $S->can('manifest_append')->($m, 2, ['c.seg', 'd.seg']);
    my $full = slurp($m);

    for my $cut (1 .. 12) {
        my $torn = substr($full, 0, length($full) - $cut);
        my $r = $S->can('manifest_latest')->($torn);
        cmp_ok(0 + $r->{generation}, '<=', 2, "cut $cut: never invents a generation");
        if (0 + $r->{generation} == 1) {
            is_deeply($r->{names}, ['a.seg', 'b.seg'],
                      "  cut $cut falls back to generation 1 intact");
        }
    }
}

{
    my $r = $S->can('manifest_latest')->('');
    is("$r->{generation}", '0', 'an empty manifest has no generation');
    is_deeply($r->{names}, [], '  and no names');
}

{
    # Garbage that is not a manifest at all.
    my $r = $S->can('manifest_latest')->("nonsense\nwithout\nstructure\n");
    is("$r->{generation}", '0', 'garbage yields no generation');
}

done_testing();
