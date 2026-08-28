use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use File::Temp qw(tempdir);
use File::Path ();
use EV; use EV::WebKit;

# data_dir makes a session persistent AND isolated: WebKit writes cookies,
# localStorage, IndexedDB and cache under the directory, and restores them when
# a later instance is built with the same directory. Without it, every
# non-ephemeral session used WebKit's default shared dir, which the caller could
# not point anywhere -- so a login living in localStorage was unrecoverable.
#
# localStorage needs a real origin: a mock_scheme page has persistent storage
# (spike-confirmed), about:blank and bare load_html do not.

# a mock producer reused across instances
sub app_html { ('<html><body><h1>app</h1></body></html>', 'text/html') }

# 1) ROUND-TRIP: set localStorage in one instance, read it back in the next
{
    my $dir = tempdir(CLEANUP => 1);

    {
        my $a = EV::WebKit->new(window => [200,150], data_dir => "$dir/s");
        $a->mock_scheme('app', \&app_html);
        $a->go('app://x', sub { EV::break });
        TWK::run_with_timeout(15);
        my ($r, $e);
        $a->script('localStorage.setItem("token", "abc123"); return localStorage.getItem("token")',
                   sub { ($r, $e) = @_; EV::break });
        TWK::run_with_timeout(10);
        is($r, 'abc123', 'localStorage set in instance A') or diag("err=" . ($e // ''));
        $a->quit;
    }
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }   # let WebKit flush to disk

    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => "$dir/s");
        $b->mock_scheme('app', \&app_html);
        $b->go('app://x', sub { EV::break });
        TWK::run_with_timeout(15);
        my ($r, $e);
        $b->script('return localStorage.getItem("token")', sub { ($r, $e) = @_; EV::break });
        TWK::run_with_timeout(10);
        is($r, 'abc123', 'a new instance with the same data_dir reads localStorage back')
            or diag("the full session did not persist: err=" . ($e // '') . " got=" . ($r // '(undef)'));
        $b->quit;
    }
}

# 2) ISOLATION: two instances with DIFFERENT data_dirs share nothing
{
    my $d1 = tempdir(CLEANUP => 1);
    my $d2 = tempdir(CLEANUP => 1);

    my $one = EV::WebKit->new(window => [200,150], data_dir => "$d1/s");
    $one->mock_scheme('app', \&app_html);
    $one->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
    $one->script('localStorage.setItem("who","ONE"); return 1', sub { EV::break });
    TWK::run_with_timeout(10);

    my $two = EV::WebKit->new(window => [200,150], data_dir => "$d2/s");
    $two->mock_scheme('app', \&app_html);
    $two->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
    my ($r, $e);
    $two->script('return localStorage.getItem("who")', sub { ($r, $e) = @_; EV::break });
    TWK::run_with_timeout(10);
    is($r, undef, 'a different data_dir sees none of the first instance\'s localStorage')
        or diag("isolation broken: got " . ($r // '(undef)'));
    $one->quit; $two->quit;
}

# 3) the data_dir is actually populated on disk (cookies/storage/cache subtrees)
{
    my $dir = tempdir(CLEANUP => 1);
    my $c = EV::WebKit->new(window => [200,150], data_dir => "$dir/s");
    $c->mock_scheme('app', \&app_html);
    $c->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
    $c->script('localStorage.setItem("x","1"); return 1', sub { EV::break });
    TWK::run_with_timeout(10);
    $c->quit;
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    ok(-d "$dir/s", 'data_dir is created on disk');
    ok(-d "$dir/s/cache", '...with the derived cache subdirectory inside it');
}

# 5) cache_dir OVERRIDE: cache goes to the override path, not $data_dir/cache
{
    my $dir  = tempdir(CLEANUP => 1);
    my $cdir = tempdir(CLEANUP => 1);
    my $c = EV::WebKit->new(window => [200,150], data_dir => "$dir/s", cache_dir => "$cdir/mycache");
    $c->mock_scheme('app', \&app_html);
    $c->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
    $c->script('localStorage.setItem("x","1"); return 1', sub { EV::break });
    TWK::run_with_timeout(10);
    $c->quit;
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    ok(-d "$cdir/mycache", 'cache_dir override: the cache is created at the override path');
    ok(!-d "$dir/s/cache", '...and NOT at the derived $data_dir/cache');
}

# 6) a RELATIVE data_dir is resolved against cwd, not WebKit's cwd (rel2abs)
{
    my $base = tempdir(CLEANUP => 1);
    my $cwd  = do { require Cwd; Cwd::getcwd() };
    chdir $base or die $!;
    {
        my $a = EV::WebKit->new(window => [200,150], data_dir => 'reldir');   # relative
        $a->mock_scheme('app', \&app_html);
        $a->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $a->script('localStorage.setItem("rel","yes"); return 1', sub { EV::break });
        TWK::run_with_timeout(10);
        $a->quit;
    }
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    ok(-d "$base/reldir", 'a relative data_dir resolves against the cwd at construction (rel2abs)');
    my ($r);
    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => 'reldir');
        $b->mock_scheme('app', \&app_html);
        $b->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $b->script('return localStorage.getItem("rel")', sub { ($r) = @_; EV::break });
        TWK::run_with_timeout(10);
        $b->quit;
    }
    chdir $cwd or die $!;   # restore before the next test / tempdir cleanup
    is($r, 'yes', '...and it persists correctly through the relative path');
}

# 7) COMPOSABILITY: data_dir + cookie_jar -- localStorage persists AND cookies
#    land in the queryable sqlite file
# No DBD::SQLite guard: this block asserts the jar file exists and that
# localStorage survived, neither of which opens the database. Guarding it on
# SQLite silently deleted the only composability coverage on any host without
# that module.
{
    my $dir = tempdir(CLEANUP => 1);
    my $jar = "$dir/cookies.sqlite";
    my $c = EV::WebKit->new(window => [200,150], data_dir => "$dir/s", cookie_jar => $jar);
    $c->mock_scheme('app', \&app_html);
    $c->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
    $c->script('localStorage.setItem("k","compose"); return 1', sub { EV::break });
    TWK::run_with_timeout(10);
    my ($se);
    $c->set_cookie({ name => 'sid', value => '9', domain => 'example.com', path => '/', max_age => 3600 },
                   sub { (undef, $se) = @_; EV::break });
    TWK::run_with_timeout(10);
    $c->quit;
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    ok(-s $jar, 'data_dir + cookie_jar: cookies go to the queryable sqlite jar')
        or diag("cookie set err: " . ($se // '(none)'));

    my $r;
    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => "$dir/s", cookie_jar => $jar);
        $b->mock_scheme('app', \&app_html);
        $b->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $b->script('return localStorage.getItem("k")', sub { ($r) = @_; EV::break });
        TWK::run_with_timeout(10);
        $b->quit;
    }
    is($r, 'compose', '...and localStorage persisted through data_dir at the same time');
}

# 8) COLLECTABILITY is unaffected: a data_dir instance is collectable by a bare
#    drop, the module's standing bar (see t/55-drop-collect.t).
{
    require Scalar::Util;
    my $dir = tempdir(CLEANUP => 1);
    my $wb;
    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => "$dir/s");
        Scalar::Util::weaken($wb = $b);
    }
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
    ok(!defined $wb, 'a data_dir instance is collectable by a bare drop');
}

# 4) the guard croaks -- contradictions, misconfigurations, and unusable paths.
#    A path that is merely "defined" is not enough: an empty string, a file where
#    a directory belongs, or an uncreatable path each has to fail loudly at
#    new(), because WebKit defers the directory setup to the first navigation
#    inside its sandbox, where a bad path is a process ABORT or a silent
#    total-loss-of-persistence, neither catchable by the caller.
{
    my $dir = tempdir(CLEANUP => 1);

    my $ok1 = eval { EV::WebKit->new(window => [200,150], data_dir => "$dir/s", ephemeral => 1); 1 };
    ok(!$ok1, 'data_dir + ephemeral => 1 croaks (a persistent ephemeral session is a contradiction)');
    like($@, qr/data_dir.*ephemeral|ephemeral.*data_dir/i, '...saying why');

    my $ok2 = eval { EV::WebKit->new(window => [200,150], cache_dir => "$dir/c"); 1 };
    ok(!$ok2, 'cache_dir without data_dir croaks (an isolated cache with a shared data dir defeats isolation)');
    like($@, qr/cache_dir.*data_dir|data_dir.*cache_dir/i, '...saying why');

    my $ok3 = eval { EV::WebKit->new(window => [200,150], data_dir => ''); 1 };
    ok(!$ok3, 'data_dir => "" croaks (rel2abs("") is the cwd -- a silent misdirect)');
    like($@, qr/empty path/i, '...saying why');

    # a file where the data dir should be: this used to construct fine and then
    # SIGABRT deep in WebKit's sandbox on the first navigation (uncatchable).
    my $filepath = "$dir/imafile";
    open my $fh, '>', $filepath or die $!; print $fh "not a dir\n"; close $fh;
    my $ok4 = eval { EV::WebKit->new(window => [200,150], data_dir => $filepath); 1 };
    ok(!$ok4, 'data_dir pointing at an existing FILE croaks at new() (not a SIGABRT on first nav)');
    like($@, qr/not a directory/i, '...saying why');

    # an unwritable parent: this used to construct AND navigate fine, reporting
    # success for every set_cookie/localStorage, while nothing reached disk.
  SKIP: {
        skip 'running as root: permission checks do not apply', 2 if $> == 0;
        my $ro = "$dir/ro"; mkdir $ro or die $!; chmod 0500, $ro or die $!;
        my $ok5 = eval { EV::WebKit->new(window => [200,150], data_dir => "$ro/sub"); 1 };
        chmod 0700, $ro;
        ok(!$ok5, 'data_dir under an unwritable parent croaks (not a silent total non-persistence)');
        like($@, qr/cannot create/i, '...saying why');
    }
}

# 9) M2 (found by mutation testing): the existence assertions in test 3/5 cannot
#    tell data_dir from cache_dir -- WebKit creates BOTH regardless of role, so
#    swapping the two args survives them. Assert on CONTENT: the real persisted
#    storage must survive deleting only the cache dir. If the args were swapped
#    (real storage in the cache dir), clearing the cache would lose the session.
{
    my $ddir = tempdir(CLEANUP => 1);
    my $cdir = tempdir(CLEANUP => 1);
    {
        my $a = EV::WebKit->new(window => [200,150], data_dir => "$ddir/s", cache_dir => "$cdir/c");
        $a->mock_scheme('app', \&app_html);
        $a->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $a->script('localStorage.setItem("keep","REAL"); return 1', sub { EV::break });
        TWK::run_with_timeout(10);
        $a->quit;
    }
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    File::Path::remove_tree("$cdir/c");   # wipe ONLY the cache (as a tmpfs clear would)
    my ($r);
    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => "$ddir/s", cache_dir => "$cdir/c");
        $b->mock_scheme('app', \&app_html);
        $b->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $b->script('return localStorage.getItem("keep")', sub { ($r) = @_; EV::break });
        TWK::run_with_timeout(10);
        $b->quit;
    }
    is($r, 'REAL', 'persisted storage survives wiping the cache dir (real data is under data_dir, not cache_dir)')
        or diag('the session was lost when only the cache was cleared -- data and cache dirs are swapped');
}

# 10) M3 (mutation): the relative-path test only proves rel2abs if cwd actually
#     MOVES between the two instances -- otherwise "resolved against cwd" and
#     "cwd never moved" are indistinguishable. chdir away in between.
{
    my $home = tempdir(CLEANUP => 1);
    my $away = tempdir(CLEANUP => 1);
    my $cwd  = do { require Cwd; Cwd::getcwd() };
    chdir $home or die $!;
    {
        my $a = EV::WebKit->new(window => [200,150], data_dir => 'rel');   # relative to $home
        $a->mock_scheme('app', \&app_html);
        $a->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $a->script('localStorage.setItem("m3","yes"); return 1', sub { EV::break });
        TWK::run_with_timeout(10);
        $a->quit;
    }
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    chdir $away or die $!;      # <-- cwd MOVES; a raw relative path would now miss
    my ($r);
    {
        chdir $home or die $!;  # instance B constructed from $home again, so 'rel' is the same dir
        my $b = EV::WebKit->new(window => [200,150], data_dir => 'rel');
        chdir $away or die $!;  # ...but move away again immediately after construction
        $b->mock_scheme('app', \&app_html);
        $b->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $b->script('return localStorage.getItem("m3")', sub { ($r) = @_; EV::break });
        TWK::run_with_timeout(10);
        $b->quit;
    }
    chdir $cwd or die $!;
    is($r, 'yes', 'a relative data_dir is pinned to cwd-at-construction (rel2abs), across a chdir')
        or diag('rel2abs is not resolving the relative data_dir at construction time');
}

# 11) M10 (mutation): test 2's isolation check proves nothing on its own (two
#     separately-constructed sessions never share LIVE localStorage anyway). Make
#     it real: quit A, then a DIFFERENT data_dir must not see A's data, AND
#     re-opening A's dir must still find it (ruling out "nothing ever persisted").
{
    my $da = tempdir(CLEANUP => 1);
    my $db = tempdir(CLEANUP => 1);
    {
        my $a = EV::WebKit->new(window => [200,150], data_dir => "$da/s");
        $a->mock_scheme('app', \&app_html);
        $a->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $a->script('localStorage.setItem("owner","A"); return 1', sub { EV::break });
        TWK::run_with_timeout(10);
        $a->quit;
    }
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    my ($other, $reopen);
    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => "$db/s");   # DIFFERENT dir
        $b->mock_scheme('app', \&app_html);
        $b->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $b->script('return localStorage.getItem("owner")', sub { ($other) = @_; EV::break });
        TWK::run_with_timeout(10);
        $b->quit;
    }
    {
        my $c = EV::WebKit->new(window => [200,150], data_dir => "$da/s");   # A's dir again
        $c->mock_scheme('app', \&app_html);
        $c->go('app://x', sub { EV::break }); TWK::run_with_timeout(15);
        $c->script('return localStorage.getItem("owner")', sub { ($reopen) = @_; EV::break });
        TWK::run_with_timeout(10);
        $c->quit;
    }
    is($other, undef, 'a different data_dir sees none of another instance\'s persisted localStorage');
    is($reopen, 'A', '...while re-opening the original data_dir still finds it (so it really did persist)');
}

# There is ONE cookie store: cookie_jar REPLACES the file data_dir would have
# used, it does not add to it. The POD said they composed additively, so a user
# who followed it and later dropped cookie_jar would silently start logged out.
{
    my $cd  = tempdir(CLEANUP => 1);
    my $jar = "$cd/explicit.sqlite";
    my $dd  = "$cd/state";

    my $c1 = EV::WebKit->new(window => [200,150], data_dir => $dd, cookie_jar => $jar, timeout => 10);
    $c1->mock_scheme('cj', \&app_html);
    $c1->go('cj://x', sub { EV::break });
    TWK::run_with_timeout(20);
    my $set;
    $c1->set_cookie({ name => 'k', value => 'v', domain => 'cj', max_age => 3600 },
                    sub { $set = $_[0]; EV::break });
    TWK::run_with_timeout(20);
    ok($set, 'premise: a persistent cookie was set with both options given');
    $c1->quit;
    { my $s = EV::timer(1.0, 0, sub { EV::break }); EV::run }

    ok(-s $jar, 'cookie_jar got the cookie file');
    ok(!-e "$dd/cookies.sqlite", '...and data_dir did NOT also get one');
    ok(!-e "$dd/cookies.txt",    '...in either format');

    # ...which is exactly why reopening with data_dir alone finds nothing
    my $c2 = EV::WebKit->new(window => [200,150], data_dir => $dd, timeout => 10);
    $c2->mock_scheme('cj', \&app_html);
    $c2->go('cj://x', sub { EV::break });
    TWK::run_with_timeout(20);
    my $rows;
    $c2->cookies('cj://x', sub { $rows = $_[0]; EV::break });
    TWK::run_with_timeout(20);
    is(scalar @{ $rows || [] }, 0,
       'reopening with data_dir alone finds no cookies -- keep passing cookie_jar');
    $c2->quit;
}

done_testing;
