#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PunkTest;
use File::Temp ();

# Directory index and listing: the `index` and `list` options a static mount
# needs before a tree of index.html files - a docs site, a generated manual -
# is servable at all. Both spellings of a directory URL, `/sub` and `/sub/`,
# name the same directory and must answer the same way.

my $dir = File::Temp->newdir;
{
    open my $fh, '>', "$dir/index.html" or die $!;
    print $fh "<h1>root</h1>";
    close $fh;
    mkdir "$dir/sub";
    open $fh, '>', "$dir/sub/index.html" or die $!;
    print $fh "<h1>sub</h1>";
    close $fh;
    mkdir "$dir/bare";                       # no index in here
    open $fh, '>', "$dir/bare/a & b <c>.txt" or die $!;
    print $fh "awkward";
    close $fh;
    mkdir "$dir/bare/deeper";
}

sub body_of {
    my ($r) = @_;
    return '' unless $r->[2];
    return $r->[2][0] // '' if ref $r->[2] eq 'ARRAY';
    local $/;
    my $fh = $r->[2];
    return <$fh>;
}

# ---- index off (the behaviour every existing mount has) ----------------------

{
    my $app = Punk::Static->app("$dir");
    is(hit($app, path => '/')->[0],     404, 'no index option: / is a 404');
    is(hit($app, path => '/sub/')->[0], 404, 'no index option: a directory is a 404');
    is(hit($app, path => '/index.html')->[0], 200, 'the file itself still serves');
}

# ---- index on ----------------------------------------------------------------

{
    my $app = Punk::Static->app("$dir", index => 'index.html');

    my $root = hit($app, path => '/');
    is($root->[0], 200, '/ serves the index');
    like(body_of($root), qr/<h1>root<\/h1>/, '... and it is the right file');
    my %h = @{ $root->[1] };
    is($h{'Content-Type'}, 'text/html; charset=utf-8', 'index content type');

    my $slash = hit($app, path => '/sub/');
    is($slash->[0], 200, '/sub/ serves the index');
    like(body_of($slash), qr/<h1>sub<\/h1>/, '... the nested one');

    my $bare = hit($app, path => '/sub');
    is($bare->[0], 200, '/sub with no trailing slash serves it too');
    like(body_of($bare), qr/<h1>sub<\/h1>/, '... the same file');

    is(hit($app, path => '/bare/')->[0], 404,
        'a directory with no index is still a 404 without --list');
    is(hit($app, path => '/nope/')->[0], 404, 'a missing directory is a 404');

    # the index is a filename, and the guard that makes that true runs before
    # any request does
    my $r = hit($app, path => '/sub', method => 'HEAD');
    is($r->[0], 200, 'HEAD on a directory index');
    is(body_of($r), '', '... with no body');
}

{
    my $app = Punk::Static->app("$dir", index => 1);
    is(hit($app, path => '/')->[0], 200, 'index => 1 means index.html');
}

{
    my $err = do { local $@; eval { Punk::Static->app("$dir", index => 'a/b') }; $@ };
    like($err, qr/not a path/, 'an index with a separator is refused at boot');
    $err = do { local $@; eval { Punk::Static->app("$dir", index => 'a\\b') }; $@ };
    like($err, qr/not a path/, '... a backslash too');
}

# ---- listing -----------------------------------------------------------------

{
    my $app = Punk::Static->app("$dir", index => 'index.html', list => 1);

    is(hit($app, path => '/')->[0], 200, 'an index still wins over a listing');
    like(body_of(hit($app, path => '/')), qr/<h1>root<\/h1>/, '... it is the file');

    my $r = hit($app, path => '/bare/');
    is($r->[0], 200, 'a directory with no index is listed');
    my %h = @{ $r->[1] };
    is($h{'Content-Type'}, 'text/html; charset=utf-8', 'listing is html');
    is($h{'Cache-Control'}, 'no-store', 'a listing is never cached');
    my $body = body_of($r);
    ok($h{'Content-Length'} == length($body), 'content length matches the body');

    like($body, qr/Index of \/bare\//, 'the listing names the path');
    like($body, qr{href="deeper/">deeper/<}, 'a subdirectory gets a trailing slash');
    like($body, qr{href="\.\."},             'a parent link away from the root');

    # a filename is not markup and it is not a URL
    like($body, qr/a &amp; b &lt;c&gt;\.txt/, 'the link text is html-escaped');
    # everything html-special is also url-unreserved, so the percent encoding
    # is what makes the attribute safe - there is nothing left for the html
    # escaper to do inside a href
    like($body, qr/href="a%20%26%20b%20%3Cc%3E\.txt"/,
        'the href is percent-encoded');
    unlike($body, qr/<c>/, 'nothing raw from a filename reaches the markup');

    my $root = hit($app, path => '/bare/deeper/');
    like(body_of($root), qr/href="\.\."/, 'a nested empty directory still lists');

    my $head = hit($app, path => '/bare/', method => 'HEAD');
    is($head->[0], 200, 'HEAD on a listing');
    is(body_of($head), '', '... with no body');
}

{
    # a listing with no index option at all
    my $app = Punk::Static->app("$dir", list => 1);
    like(body_of(hit($app, path => '/')), qr/Index of \//,
        'list without index lists the root');
    unlike(body_of(hit($app, path => '/')), qr/href="\.\."/,
        '... with no parent link out of the mount');
}

# ---- the guards that ran before still run ------------------------------------

{
    my $app = Punk::Static->app("$dir", index => 'index.html', list => 1);
    is(hit($app, path => '/../../etc/passwd')->[0], 404, 'traversal is a 404');
    is(hit($app, path => '/..\\..\\x')->[0],        404, 'backslash traversal too');
    is(hit($app, path => '/', method => 'POST')->[0], 405,
        'a directory index is still GET/HEAD only');
}

# ---- through the keyword, which is how anyone will actually reach it ----------

{
    package IndexApp;
    use Punk;
    package main;
    IndexApp::static('/site' => "$dir", index => 'index.html', list => 1);
}

{
    my $app = IndexApp->to_app;
    is(hit($app, path => '/site/')->[0],    200, 'the static keyword takes index');
    is(hit($app, path => '/site/sub')->[0], 200, '... for a nested directory');
    like(body_of(hit($app, path => '/site/bare/')), qr/Index of/,
        '... and list');
}

done_testing;
