#!perl
# The postings index. `where a = 1 and b = 2` is an intersection of two sorted
# lists, and it must return exactly what a linear scan returns.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $M = 'Punk::Observe::Metric';
sub post { $M->can('postings')->(\@_) }

# --- round trip -------------------------------------------------------------

{
    my $r = post([ 12, 15, 16, 17, 88, 91 ]);
    is_deeply($r->{first}, [ 12, 15, 16, 17, 88, 91 ],
              'a sorted list round-trips through gap encoding');
}

# Unsorted input is sorted; duplicates are collapsed. A caller feeding one
# record per point would add the same series repeatedly, so the list is made a
# set here rather than trusting every caller to.
{
    my $r = post([ 91, 12, 16, 12, 88, 15, 91, 17, 16 ]);
    is_deeply($r->{first}, [ 12, 15, 16, 17, 88, 91 ],
              'unsorted input with duplicates becomes a sorted set');
}

{
    my $r = post([ 7 ]);
    is_deeply($r->{first}, [ 7 ], 'a single-element list works');
}

# --- gap encoding actually compresses --------------------------------------

# Dense consecutive ids are the case gap encoding exists for: every gap is 1,
# so every id after a skip anchor is one byte.
{
    my @dense = (1 .. 1000);
    my $r = post(\@dense);
    is_deeply($r->{first}, \@dense, '1000 consecutive ids round-trip');
    # 1000 raw u32 would be 4000 bytes. With gaps of 1 plus a skip table
    # every 128, this should be far smaller.
    cmp_ok($r->{sizes}[0], '<', 1200,
           '  and 1000 dense ids store in under 1200 bytes, not 4000');
    diag("1000 dense ids: $r->{sizes}[0] bytes");
}

# Sparse ids compress less, which is expected and is why a roaring bitmap is
# not used - postings here are sparse by construction.
{
    my @sparse = map { $_ * 977 } 1 .. 1000;
    my $r = post(\@sparse);
    is_deeply($r->{first}, \@sparse, '1000 sparse ids round-trip');
    diag("1000 sparse ids: $r->{sizes}[0] bytes");
}

# --- the skip table ---------------------------------------------------------

# A list longer than one skip block, so seeking has something to skip over.
{
    my @ids = map { $_ * 3 } 1 .. 1000;    # 3, 6, ... 3000
    my $r = post(\@ids);
    is_deeply($r->{first}, \@ids,
              'a list spanning many skip blocks decodes in full');
    is(scalar @{ $r->{first} }, 1000, '  with every element');
}

# --- intersection -----------------------------------------------------------

sub linear {
    my ($a, $b) = @_;
    my %in = map { $_ => 1 } @$a;
    return [ grep { $in{$_} } @$b ];
}

{
    my $a = [ 12, 15, 16, 17, 88, 91 ];
    my $b = [ 15, 91, 200 ];
    my $r = post($a, $b);
    is_deeply($r->{intersection}, [ 15, 91 ], 'a small intersection is right');
}

{
    my $r = post([ 1, 2, 3 ], [ 4, 5, 6 ]);
    is_deeply($r->{intersection}, [], 'disjoint lists intersect to nothing');
}

{
    my $r = post([ 1, 2, 3 ], [ 1, 2, 3 ]);
    is_deeply($r->{intersection}, [ 1, 2, 3 ], 'identical lists intersect to all');
}

# The one that matters: over a generated corpus, the intersection must equal
# what a linear scan returns. Exactly, every time.
{
    my $bad = 0;
    my $seed = 987654321;
    my $rand = sub { $seed = ($seed * 1103515245 + 12345) % 2147483648;
                     return $seed };
    for my $trial (1 .. 40) {
        my (%a, %b);
        $a{ $rand->() % 5000 } = 1 for 1 .. (100 + $trial * 20);
        $b{ $rand->() % 5000 } = 1 for 1 .. (100 + $trial * 13);
        my @A = sort { $a <=> $b } keys %a;
        my @B = sort { $a <=> $b } keys %b;
        my $r = post(\@A, \@B);
        my $want = linear(\@A, \@B);
        $bad++ if join(',', @{ $r->{intersection} }) ne join(',', @$want);
    }
    is($bad, 0, 'over 40 generated corpora the intersection equals a linear scan');
}

# Very different sizes, which is the case the skip table is for: a tiny list
# against a huge one should seek rather than walk.
{
    my @big   = map { $_ * 2 } 1 .. 20000;
    my @small = (4, 100, 39998);
    my $r = post(\@small, \@big);
    is_deeply($r->{intersection}, [ 4, 100, 39998 ],
              'a 3-element list intersects a 20000-element one correctly');

    my $r2 = post(\@big, \@small);
    is_deeply($r2->{intersection}, [ 4, 100, 39998 ],
              '  and the same the other way round');
}

# Boundary elements: first, last, and the element at a skip anchor.
{
    my @ids = map { $_ } 1 .. 500;
    for my $probe (1, 128, 129, 256, 500) {
        my $r = post(\@ids, [ $probe ]);
        is_deeply($r->{intersection}, [ $probe ],
                  "an intersection finds element $probe, at or near a skip anchor");
    }
}

done_testing();
