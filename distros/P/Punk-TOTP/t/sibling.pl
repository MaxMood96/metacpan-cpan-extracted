# Development fallback: the monorepo runs tests against sibling working
# copies before File::Raw::Hash is installed (and the perl5-brew File/
# tree is root-owned, so installing is not always possible). On a CPAN
# install PREREQ_PM guarantees the real thing and this never fires.
BEGIN {
    unless (eval { require File::Raw::Hash; 1 }) {
        unshift @INC, map {("$_/blib/lib", "$_/blib/arch")}
            grep { -d } '../File-Raw-Hash', '../../File-Raw-Hash';
    }
}
1;
