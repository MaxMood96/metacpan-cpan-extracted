#!/usr/bin/env perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;
use Test::More;
use Test::Pod ();
use Pod::Checker;
use File::Temp qw( tempdir );

# k98 -- Test::Pod (the xt/author/pod-syntax.t that
# [PodSyntaxTests] generates at build time) checks POD SYNTAX only: it
# never resolves an L<> target, so a link to a section that does not
# exist passes it silently. That is exactly how two dead links
# (L</_deserialize_value>, L</use File::SOPS;>) sat in the tree unseen
# until someone ran podchecker by hand. Pod::Checker's "unresolved
# internal link" check is the same check podchecker(1) runs, and it
# catches that class of error. Test::Pod stays; this is additional
# coverage, not a replacement.
#
# This only means anything against WOVEN pod. =method/=attr/=opt are
# Pod::Weaver directives, not standard POD -- a L</some_method> link
# resolves only once weaving has turned the directive into a real
# =head2 under =head1 METHODS. Checking lib/ before a build gives
# nothing but noise (podchecker reports "Unknown directive: =method" on
# every one, dozens of false positives per file) -- it cannot tell a
# real dead link from a section that simply has not been woven in yet.
#
# k170 -- that noise is not hypothetical: `prove -lr xt/`, run
# directly against the checked-out source tree rather than through
# `dzil test`, hits it on every file, every time. The design above
# assumed this file only ever runs from inside a dzil build (promoted
# to t/author-pod-links.t by [ExtraTests], reading the lib/ that same
# build already wove) -- true for `dzil test`, false for a bare `prove`.
#
# The fix is NOT to teach podchecker that =method/=attr/... are valid
# directives. That would silence the "Unknown directive" error but
# leave every L</method_name> pointing at a heading that still does not
# exist until weaving creates it -- still noise, just relabelled, and
# still blind to a real dead link. So: detect the unwoven case and weave
# a throwaway copy before checking it, the same way `dzil test` would.
#
# .git is the detection signal, not a guess: Git::GatherDir gathers
# dist.ini into a build but never .git (see the "no recursive dzil
# build" reasoning below, which still holds for the promoted-copy case),
# so its presence means this is the real source tree, unwoven; its
# absence means we are already running from inside a build -- either
# the promoted t/author-pod-links.t under `dzil test`, or this file
# itself invoked a second time inside the throwaway copy it just built
# (which cannot happen: the throwaway copy is never added to @INC or
# executed, only read by podchecker).
#
# No recursive dzil build in the ALREADY-WOVEN case, and none is needed:
# like xt/author/pod-syntax.t itself, this file lives under xt/author/,
# so [ExtraTests] (already part of [@Author::GETTY]'s @Basic-derived
# plugin list, no dist.ini change needed) moves it to
# t/author-pod-links.t and adds the AUTHOR_TESTING guard at build time.
# The same `dzil build`/`dzil test` step that promotes it also weaves
# the POD in lib/ it goes on to check -- there is no second build to
# recurse into. That path is untouched below.
#
# File discovery reuses Test::Pod's own all_pod_files(), so in the
# already-woven case this checks exactly the files
# xt/author/pod-syntax.t already checks: blib/ if `make`/`Build` has
# run, lib/ otherwise -- both already woven by the time this test can
# see them.

my $tempdir;   # keeps the throwaway build alive for the length of the run
my @files;

if (-d '.git') {
  $tempdir = tempdir( CLEANUP => 1 );
  my $build_log = `dzil build --in "$tempdir" 2>&1`;
  if ($? != 0) {
    plan skip_all => "dzil build failed, cannot weave POD to check it:\n$build_log";
  }
  @files = Test::Pod::all_pod_files("$tempdir/lib");
} else {
  @files = Test::Pod::all_pod_files();
}

plan skip_all => 'no POD files found (blib/lib)' unless @files;
plan tests => scalar @files;

for my $file (@files) {
  my $report = '';
  open my $out, '>', \$report or die "can't open in-memory filehandle: $!";
  my $errors = podchecker($file, $out, -warnings => 0);
  close $out;
  my $display_file = $file;
  $display_file =~ s{\Q$tempdir\E/lib/}{lib/} if $tempdir;
  ok($errors < 1, "$display_file: no unresolved POD links or syntax errors")
    or diag($report);
}
