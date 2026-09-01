#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Spec ();

# The support headers in include/pak/ are copies of Punk-DIY's include/pdiy/
# ones, renamed. Copied rather than shared because sharing them would make
# Punk-DIY unable to compile Feature without this distribution installed, and
# would turn boot-time static helpers into a versioned ABI - see
# plan_punk_apikey/00-overview.md, decision 1.
#
# The cost of that decision is drift: a fix to pdiy_hget has to be made twice.
# This is what makes the second time visible. It is an author test, in xt/,
# because it is a check on the tree and not on the distribution - somebody who
# installed from CPAN has no sibling to compare against.
#
# The comparison is at function level rather than by line diff, so that the
# differences this move made deliberately can be NAMED instead of approximated
# by a line range that quietly widens.

my $sibling = File::Spec->catdir(File::Spec->updir, 'Punk-DIY', 'include',
                                 'pdiy');
plan skip_all => 'no Punk-DIY checkout beside this one' unless -d $sibling;

# What each copy is allowed to be missing, and what it is allowed to have
# that Punk-DIY does not. Both directions, because each distribution dropped
# the helpers its own plugins do not call - and a helper with no caller is a
# warning on every compiler the smokers run.
my %MISSING = (
    clos => [qw(pdiy_app_has pdiy_app_of)],   # Feature's, and its only caller
    reg  => [],
    hash => [qw(pdiy_fnv1a pdiy_bucket)],     # Feature's rollout bucket
);
my %EXTRA = (
    clos => [],
    reg  => [qw(pdiy_try_model)],   # APIKey's only, so Punk-DIY dropped it
    # The two hash headers are DISJOINT: Punk-DIY kept the FNV half for
    # Feature's rollout bucket and dropped the checksum, this one did the
    # reverse. So nothing here has a body to compare and the set assertions
    # are the whole check - which is still worth making, because it is what
    # would notice CRC32 reappearing in Punk-DIY.
    hash => [qw(pdiy_b62_6 pdiy_crc32 pdiy_crc32_init)],
);

# Every `static TYPE name(args)` followed by a brace block at column 0. The
# headers are written in one style throughout, which is what makes this
# possible; a body that stopped starting its brace at column 0 would show up
# as a function this cannot see, and the name-set assertions would catch it.
sub funcs {
    my ($text) = @_;
    my %f;
    while ($text =~ /^static \s+ [^\n(]*? (\w+) \s* \( ([^;{]*?) \)
                     \s* \n \{ (.*?) ^\}/gmsx) {
        $f{$1} = "($2)\n{$3}";
    }
    return \%f;
}

for my $h (sort keys %MISSING) {
    my $ours   = _slurp(File::Spec->catfile('include', 'pak', "pak_$h.h"));
    my $theirs = _slurp(File::Spec->catfile($sibling, "pdiy_$h.h"));

    # Undo this distribution's two deliberate textual changes: the prefix, and
    # the croak strings, which name the distribution the reader installed and
    # so cannot be the same in both trees.
    $ours =~ s/\bpak_/pdiy_/g;
    $ours =~ s/\bPAK_/PDIY_/g;
    $ours =~ s/croak\("Punk::APIKey: /croak("Punk::DIY: /g;

    my $o = funcs($ours);
    my $t = funcs($theirs);

    my @missing = sort grep { !$o->{$_} } keys %$t;
    my @extra   = sort grep { !$t->{$_} } keys %$o;

    is_deeply(\@missing, [ sort @{ $MISSING{$h} } ],
        "pak_$h.h is missing exactly the functions it is meant to be missing");

    is_deeply(\@extra, [ sort @{ $EXTRA{$h} } ],
        "pak_$h.h keeps exactly the helpers Punk-DIY dropped and invents "
      . "nothing - anything this distribution owns goes in its own header");

    # Only the functions both trees have: an allowed extra has nothing on the
    # other side to be identical to.
    my @differ = sort grep { $t->{$_} && $o->{$_} ne $t->{$_} } keys %$o;
    is_deeply(\@differ, [],
        "and every function it kept is byte-identical to Punk-DIY's")
        or diag("drifted: @differ\n"
              . "one of the two trees has a fix the other does not");
}

sub _slurp {
    my ($f) = @_;
    open my $fh, '<', $f or die "$f: $!";
    local $/;
    return <$fh>;
}

done_testing();
