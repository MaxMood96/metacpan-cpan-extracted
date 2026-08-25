#!perl
use 5.010;
use strict;
use warnings;

# The CONTENT cache on its own, with the stat cache turned off.
#
# The two caches make different bargains and are tested apart. The content
# cache is EXACTLY correct - it re-reads the moment the file's identity
# changes, and it learns that from a stat the request had to do anyway - so
# everything below asserts an immediate answer, with no window anywhere in it.
# The stat cache's bounded staleness is t/0316's subject.
#
# In BEGIN, because the setting is read once and cached: after the first
# request it would be too late.
BEGIN { $ENV{PUNK_STATIC_STAT_TTL} = 0 }

use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;
use File::Temp ();
use File::Copy ();
use Time::HiRes ();

# The content cache behind static files.
#
# x# 33x cheaper, so a hit reuses the open descriptor. Everything that can go
# wrong with that is here, because none of it is visible in the response of a
# single request:
#
#   - a second request must get the WHOLE file, not the remainder after the
#     first one read it (a dup SHARES the file offset with its original)
#   - a file replaced on disk must stop being served from the old descriptor
#
# The second is the one that decides whether this feature can ship: a cache
# that serves last week's CSS forever is worse than the syscall it saved.

my $dir = File::Temp->newdir;

sub write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die $!;
    print {$fh} $content;
    close $fh;
}

sub body_of {
    my ($r) = @_;
    return join '', @{ $r->[2] } if ref $r->[2] eq 'ARRAY';
    my $fh = $r->[2];
    my $out = '';
    if (ref $fh && eval { $fh->can('getline') }) {
        while (defined(my $c = $fh->getline)) { $out .= $c }
    }
    else { local $/; $out = <$fh> }
    return $out;
}

write_file("$dir/app.css", "body { color: red }\n");

{
    package FdCacheApp;
    use Punk;
    package main;
    FdCacheApp::static('/s' => "$dir");
}
my $app = FdCacheApp->to_app;

# ---- the same file, many times over -----------------------------------------
#
# THE regression this guards. A dup shares the file offset with the descriptor
# it was made from, so without an explicit rewind the second request starts
# reading where the first one stopped and serves an empty body - and the
# Content-Length header, computed from the stat, still says otherwise.

my $want = "body { color: red }\n";
for my $i (1 .. 5) {
    my $r = hit($app, path => '/s/app.css');
    is($r->[0], 200, "request $i serves 200");
    is(body_of($r), $want, "request $i gets the WHOLE file, not a remainder");
}

# ---- replaced file: new inode ------------------------------------------------
#
# How every sane deploy publishes a file - write beside, rename into place.
# The path is the same and the cached descriptor still points at the old
# inode, which is precisely what a stat of the PATH catches and an fstat of
# the descriptor cannot.

{
    write_file("$dir/app.css.new", "body { color: blue }\n");
    File::Copy::move("$dir/app.css.new", "$dir/app.css") or die $!;
    my $r = hit($app, path => '/s/app.css');
    is(body_of($r), "body { color: blue }\n",
       'a file replaced by rename is served fresh, not from the cached fd');
}

# ---- rewritten in place: same inode, different size -------------------------

{
    write_file("$dir/app.css", "body { color: green } /* longer than before */\n");
    my $r = hit($app, path => '/s/app.css');
    is(body_of($r), "body { color: green } /* longer than before */\n",
       'an in-place rewrite of a different size is served fresh');
}

# ---- rewritten in place: same inode, SAME size, different mtime -------------
#
# The narrowest case the validator still has to catch: only the mtime moved.
# Sleep past the filesystem's mtime granularity first, or the write lands in
# the same tick and the test asserts something it cannot know.

{
    my $before = (stat "$dir/app.css")[9];
    my $same_size = "body { color: WHITE } /* longer than before */\n";
    is(length $same_size, length "body { color: green } /* longer than before */\n",
       'the replacement really is the same size');
    for (1 .. 40) {
        write_file("$dir/app.css", $same_size);
        last if (stat "$dir/app.css")[9] != $before;
        Time::HiRes::sleep(0.05);
    }
    SKIP: {
        skip 'filesystem mtime did not advance', 1
            if (stat "$dir/app.css")[9] == $before;
        my $r = hit($app, path => '/s/app.css');
        is(body_of($r), $same_size,
           'a same-size in-place rewrite is caught by mtime');
    }
}

# ---- a file that goes away --------------------------------------------------
#
# The cache must not resurrect it from the descriptor it still holds.

{
    unlink "$dir/app.css" or die $!;
    my $r = hit($app, path => '/s/app.css');
    is($r->[0], 404, 'a deleted file 404s rather than serving from the cache');
}

# ---- two different files do not collide -------------------------------------

{
    write_file("$dir/a.txt", 'AAA');
    write_file("$dir/b.txt", 'BBBB');
    for (1 .. 3) {
        is(body_of(hit($app, path => '/s/a.txt')), 'AAA', 'a.txt stays a.txt');
        is(body_of(hit($app, path => '/s/b.txt')), 'BBBB', 'b.txt stays b.txt');
    }
}

done_testing;
