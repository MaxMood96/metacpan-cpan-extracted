# This Build.PL for Thread-GoChannel was generated by Dist::Zilla::Plugin::ModuleBuildTiny 0.017.
use strict;
use warnings;

use Config;
if (not $Config{useithreads}) {
    print STDERR "Can't use Thread::GoChannel without threading support";
    exit 0;
}
use 5.006;
use Module::Build::Tiny 0.046;
Build_PL();

