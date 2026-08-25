#!perl
use 5.010;
use strict;
use warnings;

# The STAT cache, and the window it opens.
#
# stat was the last file syscall left on a static hit - 15% of it, plus the
# sibling probes that go looking for a .gz that is usually not there - and
# holding it removes them. What it costs is exactness: inside the TTL a change
# on disk is not looked for, so it is not seen.
#
# That is a real trade, so it gets a test that states it rather than a comment
# claiming it is unlikely. Both halves are asserted here: a change is NOT
# visible inside the window, and IS visible after it.
#
# A short TTL so the test does not spend a second sleeping. Set in BEGIN
# because it is read once and cached.
my $TTL;
BEGIN { $TTL = 0.4; $ENV{PUNK_STATIC_STAT_TTL} = $TTL }

use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;
use File::Temp ();
use Time::HiRes ();

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

write_file("$dir/app.css", "ONE\n");

{
    package StatCacheApp;
    use Punk;
    package main;
    StatCacheApp::static('/s' => "$dir");
}
my $app = StatCacheApp->to_app;

is(body_of(hit($app, path => '/s/app.css')), "ONE\n", 'the first read');

# ---- inside the window: the change is not looked for ------------------------
#
# The documented cost. A file replaced right after a request is served from
# what the last stat said until the TTL runs out.

{
    write_file("$dir/app.css", "TWO-IS-LONGER\n");
    my $got = body_of(hit($app, path => '/s/app.css'));
    is($got, "ONE\n",
       'inside the TTL a replaced file is NOT seen - the documented window');
}

# ---- past the window: the change is seen ------------------------------------

{
    Time::HiRes::sleep($TTL + 0.15);
    my $got = body_of(hit($app, path => '/s/app.css'));
    is($got, "TWO-IS-LONGER\n", 'once the TTL lapses the new bytes are served');
    my %h = @{ hit($app, path => '/s/app.css')->[1] };
    is($h{'Content-Length'}, length "TWO-IS-LONGER\n",
       '...and the headers describe the new file, not the old one');
}

# ---- a deletion is seen once the window lapses ------------------------------

{
    unlink "$dir/app.css" or die $!;
    Time::HiRes::sleep($TTL + 0.15);
    is(hit($app, path => '/s/app.css')->[0], 404,
       'a deleted file 404s once the stat is looked at again');
}

# ---- a remembered ABSENCE is still an absence -------------------------------
#
# The negative half: a path that has never existed must keep 404ing, and then
# must start serving once it does exist and the window has lapsed. If negative
# entries were never revalidated, a newly deployed file would 404 forever.

{
    is(hit($app, path => '/s/late.css')->[0], 404, 'a file that is not there');
    write_file("$dir/late.css", "LATE\n");
    Time::HiRes::sleep($TTL + 0.15);
    is(hit($app, path => '/s/late.css')->[0], 200,
       'a remembered absence is re-checked, so a new file starts serving');
    is(body_of(hit($app, path => '/s/late.css')), "LATE\n",
       '...with its own bytes');
}

# The exact mode - PUNK_STATIC_STAT_TTL=0, no window at all - is what
# t/0315-static-filecache.t runs under, so it is asserted there rather than
# faked here.

done_testing;
