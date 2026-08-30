use strict;
use warnings;
use Test::More;
use Path::Tiny;
use Cwd qw( abs_path );
use Module::Runtime qw( require_module );

# k91: `prove -l` PREPENDS "lib" to @INC, it does not replace it -- an
# installed copy of this distribution stays reachable right behind the
# checkout's own lib/. That is how a module k84 deleted from
# lib/API/Docker/Image.pm kept "loading": t/basic.t's use_ok stayed green
# because API::Docker::Image resolved from
# a local::lib copy (~/perl5/lib/perl5/API/Docker/Image.pm) instead. The installed
# copy reported the same $VERSION as the checkout, too -- a released 0.003
# and an unreleased 0.004 carry the identical literal under this repo's
# version discipline -- so a version check would not have caught the
# substitution either.
#
# This test requires every .pm file this checkout ships under lib/ -- both
# what is physically there right now and, wherever a checkout (not a build
# tree) makes it cheap to ask, whatever `git` still tracks there even if a
# file went missing from disk -- then asserts that whatever ended up in %INC
# for API::Docker::* came from a file inside this checkout. Anything under
# an installed site/vendor path fails it, by name. One assertion, three
# failure modes: a stale installed copy, a leftover blib/ picked up ahead of
# lib/, and a module gone from disk but still tracked (or still referenced
# by some other module this test loads) -- k84's shape exactly: t/basic.t's
# use_ok('API::Docker::Image') kept passing, silently sourced from the
# install, for as long as the file was merely deleted from the working tree
# and not yet un-tracked.
#
# API::Docker::{Container,Image,Network,Volume,Plugin,Secret,Config} are
# legacy CPAN-compatibility stubs (karr k92): they ship under lib/ again on
# purpose, but are allowed to croak on load rather than load silently, and
# t/basic.t deliberately carries no use_ok for them -- do not "fix" that by
# adding one. A module that dies while loading is not silently invisible in
# %INC, though: `require`/Module::Runtime still leave the key set, just with
# an undef value, as a guard against re-attempting a load that is known to
# fail -- and Cwd::abs_path(undef) resolves to the current directory rather
# than returning undef, which reads as a false "loaded from the checkout
# root" pass if that key is not screened out first. So a defined %INC value
# is what "actually loaded" means below; an undef one is treated as no entry
# at all, on purpose, and never checked. The question here is not "does
# everything compile" -- that is each module's own t/*.t -- only "whatever
# DID load, did it come from here".

my $dist_root = path(__FILE__)->parent->parent->realpath;
my $lib_dir   = $dist_root->child('lib');

my @acceptable_roots = ($lib_dir->stringify);

# `dzil test` builds and runs from a fresh temporary directory under
# <checkout>/.build/<random> -- created new for every run, so it can never
# hold a leftover -- and its TestRunner loads modules from that tree's
# blib/lib, not its lib/. `dzil release`'s [@Filter/TestRelease] instead
# builds the tarball and EXTRACTS it, so this test then runs one level
# deeper still: <checkout>/.build/<random>/<Dist-Version>/, with the
# extracted distribution's own directory as an extra ancestor between
# $dist_root and .build. Checking only the immediate parent (as this used
# to) catches the first shape and misses the second, so every release-time
# run of this test failed even though blib/lib held exactly the right
# modules. Recognise both shapes by walking $dist_root's ancestors for one
# named .build, and only that signal, as what makes blib/lib a second
# acceptable root -- so a blib/ sitting directly in a real, persistent
# checkout (the actual "leftover blib" failure mode, which has no .build
# ancestor at all) still fails this test rather than being waved through.
my $in_build_tree = 0;
my $ancestor       = $dist_root;
while ($ancestor->parent->stringify ne $ancestor->stringify) {
  $ancestor = $ancestor->parent;
  if ($ancestor->basename eq '.build') {
    $in_build_tree = 1;
    last;
  }
}
push @acceptable_roots, $dist_root->child('blib', 'lib')->stringify
  if $in_build_tree;

my %rel_paths;   # e.g. "API/Docker/Image.pm" => 1

$lib_dir->visit(
  sub {
    my ($path) = @_;
    return unless $path->is_file && "$path" =~ /\.pm\z/;
    $rel_paths{ $path->relative($lib_dir)->stringify } = 1;
  },
  { recurse => 1 },
);

# `git ls-files` answers from the index, not the working tree, so a file
# `mv`d or `rm`d out of lib/ without also being `git rm`d still comes back --
# which is exactly the shape of check this test exists for. Only meaningful
# in a checkout (a `dzil test` build tree has no .git of its own, but it only
# ever contains what Git::GatherDir already limited to tracked files, so the
# walk above already covers it there).
if ($dist_root->child('.git')->exists) {
  if (open my $fh, '-|', 'git', '-C', "$dist_root", 'ls-files', '--', 'lib') {
    while (my $line = <$fh>) {
      chomp $line;
      $line =~ s{\Alib/}{} or next;
      $rel_paths{$line} = 1 if $line =~ /\.pm\z/;
    }
    close $fh;
  }
}

ok(scalar(keys %rel_paths) > 0, 'found .pm files under lib/ to check')
  or diag("nothing found under $lib_dir -- is the checkout intact?");

for my $rel (sort keys %rel_paths) {
  ( my $pkg = $rel ) =~ s{\.pm\z}{};
  $pkg =~ s{/}{::}g;

  local $@;
  eval { require_module($pkg); 1 };
  # A load failure is tolerated here on purpose -- see the k92 note above --
  # and is out of this test's remit either way: it is covered, if at all, by
  # that module's own test file.
}

my @checked;
for my $key (sort keys %INC) {
  next unless $key =~ m{^API/Docker(?:\.pm\z|/)};
  next unless defined $INC{$key};

  my $resolved = abs_path($INC{$key});
  $resolved = $INC{$key} unless defined $resolved;

  my $from_checkout = grep { index($resolved, "$_/") == 0 } @acceptable_roots;

  push @checked, $key;
  ok($from_checkout, "$key resolved inside this checkout")
    or diag("  $key => $resolved");
}

ok(scalar(@checked) > 0, '%INC actually carried API::Docker entries to check')
  or diag('nothing under API/Docker/ ever made it into %INC -- this test asserted nothing');

done_testing;
