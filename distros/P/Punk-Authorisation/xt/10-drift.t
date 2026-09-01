#!perl
use 5.010;
use strict;
use warnings;
use File::Spec ();
use Test::More;

# include/pau/pau_clos.h and pau_reg.h are copies of Punk-DIY's pdiy_clos.h
# and pdiy_reg.h. A bug fixed in one has to be fixed in the other, and
# nothing but this test makes that visible.
#
# It lives in xt/ because it fails for a legitimate reason - somebody
# deliberately diverged - and that should not fail a smoker or a
# `make disttest`. Run it by hand before a release, and when it fails decide
# which copy is right rather than making the test agree with the code.
#
# The comparison undoes the rename this distribution applied when it copied:
# the pau_ prefix, the PAU_ macro prefix, and the three croak strings that
# named the distribution the code was in.

my $sibling = File::Spec->catdir(File::Spec->updir, 'Punk-DIY', 'include', 'pdiy');
plan skip_all => "no Punk-DIY checkout at $sibling"
    unless -d $sibling;

my %PAIR = (
    'pau_clos.h' => 'pdiy_clos.h',
    'pau_reg.h'  => 'pdiy_reg.h',
);

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or return undef;
    local $/;
    return <$fh>;
}

# Where they first differ, because a diff of 630 lines in a TAP comment is
# unreadable and the line number is the whole answer.
sub first_difference {
    my ($a, $b) = @_;
    my @a = split /\n/, $a, -1;
    my @b = split /\n/, $b, -1;
    # Parenthesised: `..` binds tighter than `?:`, so the obvious spelling
    # is a flip-flop against $. and returns nothing.
    my $last = ($#a > $#b) ? $#a : $#b;
    for my $i (0 .. $last) {
        my ($x, $y) = ($a[$i], $b[$i]);
        next if defined $x && defined $y && $x eq $y;
        return ($i + 1, defined $x ? $x : '(end of file)',
                        defined $y ? $y : '(end of file)');
    }
    return ();
}

for my $mine (sort keys %PAIR) {
    my $theirs = $PAIR{$mine};
    my $here   = slurp(File::Spec->catfile('include', 'pau', $mine));
    my $there  = slurp(File::Spec->catfile($sibling, $theirs));

    ok(defined $here,  "$mine is readable")   or next;
    ok(defined $there, "$theirs is readable") or next;

    (my $undone = $here) =~ s/\bpau_/pdiy_/g;
    $undone =~ s/\bPAU_/PDIY_/g;
    $undone =~ s/\bPunk::Authorisation\b/Punk::DIY/g;

    if ($undone eq $there) {
        pass("$mine has not drifted from $theirs");
    }
    else {
        my ($line, $ours, $upstream) = first_difference($undone, $there);
        fail("$mine has drifted from $theirs");
        diag("first difference at line $line");
        diag("  here:     $ours");
        diag("  Punk-DIY: $upstream");
    }
}

done_testing();
