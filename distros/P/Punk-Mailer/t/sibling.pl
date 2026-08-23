# Development fallback: the monorepo runs tests against a sibling working
# copy of Fetch before it is installed (the perl5-brew tree is part
# root-owned, so installing is not always possible), and a sibling carries
# the newest ABI. On a CPAN install PREREQ_PM guarantees the real thing.
BEGIN {
    for my $d (grep { -d "$_/blib/arch" } '../Fetch', '../../Fetch') {
        unshift @INC, "$d/blib/lib", "$d/blib/arch";
        last;
    }
}
1;
