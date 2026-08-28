use v5.10; use strict; use warnings;
use Test::More;
use File::Temp 'tempdir';
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# Cookie hybrid:
#
# Part 1 -- native persistence (primary mechanism). cookie_jar => $file wires
# WebKitCookieManager::set_persistent_storage; WebKit itself writes/reads the
# jar, no explicit save/load call needed. Only non-session cookies (a real
# max_age) are ever written -- session cookies (no max_age) are correctly
# EXCLUDED by design (RFC 6265, same as every real browser). The investigation
# proved the "broken" verdict from an earlier attempt was a test bug: that
# test's cookie had no max_age, so it was a session cookie all along.
#
# Part 2 -- save_cookies/load_cookies remain as an explicit, opt-in JSON
# snapshot (per-URI get_cookies enumeration/replay -- get_all_cookies is
# still avoided: a real memory-safety bug was valgrind-confirmed when that
# call is left in-flight at teardown). Snapshots are the only way to capture
# SESSION cookies; expiry is not part of the snapshot (loaded back as session
# cookies).
#
# Two independent EV::WebKit instances per part simulate a save-then-restart
# cycle -- safe to run sequentially in one process thanks to the EV::Glib
# wedge fix (task 13a).
my $dir = tempdir(CLEANUP=>1);

# ===========================================================================
# Part 1: native persistence
# ===========================================================================
my $native_jar = "$dir/jar.sqlite";

# --- Instance A: one persistent cookie (max_age), one session cookie (no
#     max_age); tear down. ---
my $A = EV::WebKit->new(window=>[300,200], cookie_jar=>$native_jar);
my ($keep_err, $sess_err, $sess_ran);
$A->set_cookie({ name=>'keep', value=>'1', domain=>'jar.test', path=>'/', max_age=>3600 }, sub {
    (undef, $keep_err) = @_;
    if ($keep_err) { EV::break; return }
    $A->set_cookie({ name=>'sess', value=>'x', domain=>'jar.test', path=>'/' }, sub {
        (undef, $sess_err) = @_;
        $sess_ran = 1;
        EV::break;
    });
});
TWK::run_with_timeout(10);
ok(!$keep_err, 'set_cookie (persistent, max_age=>3600) did not error') or diag($keep_err);
ok(!$sess_err, 'set_cookie (session, no max_age) did not error') or diag($sess_err);
ok($sess_ran, 'session set_cookie callback ran');
$A->quit;
ok(-s $native_jar, 'native jar file exists and is non-empty after quit (no explicit save call)');

# --- Instance B: fresh browser, same jar -- native persistence auto-restores. ---
my $B = EV::WebKit->new(window=>[300,200], cookie_jar=>$native_jar);
my ($list, $list_err);
# cookies load asynchronously from disk; poll briefly (as in the original
# task-13 recipe -- see cookie-investigation-report.md Hypothesis B).
my $poll = EV::timer(0.5, 0, sub {
    $B->cookies('http://jar.test/', sub { ($list, $list_err) = @_; EV::break });
});
TWK::run_with_timeout(10);
ok(!$list_err, 'cookies() on instance B did not error') or diag($list_err);
my ($keep) = grep { $_->{name} eq 'keep' } @{ $list || [] };
my ($sess) = grep { $_->{name} eq 'sess' } @{ $list || [] };
ok($keep && $keep->{value} eq '1', 'keep=1 persisted natively, no explicit load call')
    or diag(explain($list));
ok(!$sess, 'sess (session cookie) is NOT present -- excluded from native persistence by design');
$B->quit;

# ===========================================================================
# Part 2: snapshot save/load (explicit, opt-in; captures session cookies too)
# ===========================================================================
my $snap = "$dir/snap.json";

# --- Instance C: plain ephemeral, no cookie_jar -- set a session cookie,
#     snapshot it to a file. ---
my $C = EV::WebKit->new(window=>[300,200]);
my ($save_count, $save_err);
$C->set_cookie({ name=>'snap', value=>'2', domain=>'jar.test', path=>'/' }, sub {
    my (undef, $set_err) = @_;
    if ($set_err) { $save_err = $set_err; EV::break; return }
    $C->save_cookies($snap, ['http://jar.test/'], sub { ($save_count, $save_err) = @_; EV::break });
});
TWK::run_with_timeout(10);
ok(!$save_err, 'set_cookie/save_cookies did not error') or diag($save_err);
ok($save_count, 'save_cookies reported a truthy count');
is($save_count, 1, 'save_cookies saved exactly the one cookie we set');
ok(-s $snap, 'snapshot file is non-empty');
$C->quit;

# --- Instance D: plain ephemeral -- load the snapshot; the session cookie
#     comes back (snapshots capture what native persistence excludes). ---
my $D = EV::WebKit->new(window=>[300,200]);
my ($loaded, $load_err, $list2, $cookies_err);
$D->load_cookies($snap, sub {
    ($loaded, $load_err) = @_;
    $D->cookies('http://jar.test/', sub { ($list2, $cookies_err) = @_; EV::break });
});
TWK::run_with_timeout(10);
ok(!$load_err, 'load_cookies did not error') or diag($load_err);
ok($loaded, 'load_cookies reported a truthy loaded count');
ok(!$cookies_err, 'cookies() did not error') or diag($cookies_err);
my ($snapc) = grep { $_->{name} eq 'snap' } @{ $list2 || [] };
ok($snapc && $snapc->{value} eq '2', 'snap=2 round-tripped through save_cookies/load_cookies (session cookie captured)');
$D->quit;

# ===========================================================================
# Part 3: native persistence with jar_format => 'text' (compact variant of
# Part 1 -- proves the format option is actually honored rather than always
# falling back to the sqlite default; a plain round-trip alone wouldn't
# distinguish the two, since sqlite would also round-trip the cookie).
# ===========================================================================
my $text_jar = "$dir/jar.txt";

my $F = EV::WebKit->new(window=>[300,200], cookie_jar=>$text_jar, jar_format=>'text');
my $tkeep_err;
$F->set_cookie({ name=>'tkeep', value=>'3', domain=>'jar.test', path=>'/', max_age=>3600 }, sub {
    (undef, $tkeep_err) = @_;
    EV::break;
});
TWK::run_with_timeout(10);
ok(!$tkeep_err, 'set_cookie (persistent, jar_format=>text) did not error') or diag($tkeep_err);
$F->quit;
ok(-s $text_jar, 'text-format jar file exists and is non-empty after quit');
open my $tfh, '<:raw', $text_jar or die "open $text_jar: $!";
my $text_bytes = do { local $/; <$tfh> };
close $tfh;
unlike($text_bytes, qr/^SQLite format 3/, 'text-format jar is not a sqlite file (format actually honored)');

my $G = EV::WebKit->new(window=>[300,200], cookie_jar=>$text_jar, jar_format=>'text');
my ($tlist, $tlist_err);
my $tpoll = EV::timer(0.5, 0, sub {
    $G->cookies('http://jar.test/', sub { ($tlist, $tlist_err) = @_; EV::break });
});
TWK::run_with_timeout(10);
ok(!$tlist_err, 'cookies() on fresh text-format instance did not error') or diag($tlist_err);
my ($tkeep) = grep { $_->{name} eq 'tkeep' } @{ $tlist || [] };
ok($tkeep && $tkeep->{value} eq '3', 'tkeep=3 persisted via text-format jar, no explicit load call')
    or diag(explain($tlist));
$G->quit;

# ===========================================================================
# Part 4: malformed snapshot rows are skipped (degrade), never fatal -- the
# comment on load_cookies promises "treat garbage as empty, not fatal", but
# that used to only cover the outer arrayref shape; individual rows that are
# non-hashref or missing a required key must be filtered out too, routing
# only well-formed rows through set_cookie.
# ===========================================================================
my $malformed_file = "$dir/malformed.json";
open my $mfh, '>:utf8', $malformed_file or die "open $malformed_file: $!";
print $mfh '["a","b",42]';   # every row is a non-hashref -- none of them loadable
close $mfh;

my $partial_file = "$dir/partial.json";
open my $pfh, '>:utf8', $partial_file or die "open $partial_file: $!";
print $pfh '[{"name":"good","value":"v","domain":"d.test","path":"/"},{"name":"bad","value":"v"}]';   # 2nd row missing domain
close $pfh;

my $H = EV::WebKit->new(window=>[300,200]);

my ($mcount, $merr);
$H->load_cookies($malformed_file, sub { ($mcount, $merr) = @_; EV::break });
TWK::run_with_timeout(10);
ok(!$merr, 'load_cookies on all-non-hashref rows did not error') or diag($merr);
is($mcount, 0, 'load_cookies skipped every non-hashref row (count=0)');

my ($pcount, $perr);
$H->load_cookies($partial_file, sub { ($pcount, $perr) = @_; EV::break });
TWK::run_with_timeout(10);
ok(!$perr, 'load_cookies on partially-malformed rows did not error') or diag($perr);
is($pcount, 1, 'load_cookies loaded only the one good row, skipped the row missing domain');

$H->quit;

# --- error paths (fresh instance, never navigated) ---
my $E = EV::WebKit->new(window=>[300,200]);

my $file_required_err;
my $file_required_ret = $E->save_cookies(undef, sub { $file_required_err = $_[1]; EV::break });
is($file_required_ret, $E, 'save_cookies without a file returns $b');
TWK::run_with_timeout(5);   # error delivery is deferred to a clean tick (uniform with every other early-error guard)
is($file_required_err, 'snapshot file required', 'save_cookies without a file errors');

my $no_uris_err;
$E->save_cookies("$dir/x.json", sub { $no_uris_err = $_[1]; EV::break });
TWK::run_with_timeout(5);
is($no_uris_err, 'no URIs to save (navigate first or pass a URI list)',
    'save_cookies with no URIs (fresh instance, no go()) errors');
$E->quit;

# data_dir persists cookies too (no cookie_jar): a cookie with an expiry set in
# one instance is read back by the next instance with the same data_dir.
{
    require File::Temp;
    my $ddir = File::Temp::tempdir(CLEANUP => 1);
    {
        my $a = EV::WebKit->new(window => [200,150], data_dir => "$ddir/s");
        my $se;
        $a->set_cookie({ name => 'dd', value => '77', domain => 'example.com', path => '/', max_age => 3600 },
                       sub { (undef, $se) = @_; EV::break });
        TWK::run_with_timeout(10);
        is($se, undef, 'data_dir: cookie set') or diag("err=" . ($se // ''));
        $a->quit;
    }
    { my $t = EV::timer(0.5, 0, sub { EV::break }); EV::run }
    my ($list, $ce);
    {
        my $b = EV::WebKit->new(window => [200,150], data_dir => "$ddir/s");
        $b->cookies('http://example.com/', sub { ($list, $ce) = @_; EV::break });
        TWK::run_with_timeout(10);
        $b->quit;
    }
    ok(scalar(grep { $_->{name} eq 'dd' && $_->{value} eq '77' } @{ $list || [] }),
        'data_dir persists cookies across instances (no cookie_jar needed)')
        or diag("err=" . ($ce // '') . " got " . scalar(@{ $list || [] }) . " cookies");
}

# cookie_jar is tested for DEFINEDNESS, not truth. '0' is a perfectly good
# relative path and survives the empty-path croak, but it is Perl-false -- so
# tested for truth it left the session ephemeral, and set_persistent_storage
# silently bails on an ephemeral session. The caller asked for a persistent jar
# and got silent non-persistence.
{
    my $dir = tempdir(CLEANUP => 1);
    require Cwd;
    my $cwd = Cwd::getcwd();
    chdir $dir or die "chdir: $!";
    my $b = EV::WebKit->new(window => [200,150], cookie_jar => '0');
    ok(!$b->{session}->is_ephemeral, "cookie_jar => '0' still forces a persistent session")
        or diag('a falsy-but-valid path was treated as no jar at all');
    $b->quit;
    chdir $cwd or die "chdir back: $!";
}

# save_cookies with NO uri list defaults to "every uri this instance has gone
# to" -- the only consumer of {_seen_uris}, and every other call in the suite
# passes an explicit list, so deleting the one line that populates it left
# everything green.
{
    my $snap = "$dir/seen.json";
    my $S = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 3);
    my ($count, $err);
    $S->set_cookie({ name => 'seen', value => 'yes', domain => 'seen.test', path => '/' }, sub {
        # the navigation itself fails (seen.test resolves nowhere) -- the uri is
        # recorded when go() is CALLED, which is what feeds the default list
        $S->go('http://seen.test/page', sub {
            $S->save_cookies($snap, sub { ($count, $err) = @_; EV::break });
        });
    });
    TWK::run_with_timeout(25);
    is($err, undef, 'save_cookies with no uri list succeeds after navigating') or diag $err;
    is($count, 1, '...saving the cookie for the uri it went to');
    my $json = do { open my $fh, '<', $snap or die "open $snap: $!"; local $/; <$fh> };
    like($json, qr/"seen"/, '...and the snapshot really contains it');
    $S->quit;
}

# load_cookies documents "Returns $b", but its two BENIGN no-op paths -- no such
# file, and a file with no usable rows -- returned _defer's bare return, i.e.
# undef. The POD calls both "not an error", and the missing-file one is the
# ordinary FIRST RUN, so the documented chaining idiom died exactly there:
# $b->load_cookies($jar, $cb)->go(...) => Can't call method "go" on undefined.
{
    my $rb = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 8);
    my $tmp = File::Temp->newdir;

    my $missing = "$tmp/never-written.json";
    my $r1 = $rb->load_cookies($missing, sub { EV::break });
    TWK::run_with_timeout(15);
    is(ref $r1, 'EV::WebKit', 'load_cookies returns the browser when the jar does not exist yet');

    my $empty = "$tmp/empty.json";
    open my $eh, '>', $empty or die $!; print $eh '[]'; close $eh;
    my $r2 = $rb->load_cookies($empty, sub { EV::break });
    TWK::run_with_timeout(15);
    is(ref $r2, 'EV::WebKit', '...and when the jar holds no usable rows');

    # the documented idiom, which is what those returns are for
    my $chained = eval { $rb->load_cookies($missing, sub { EV::break })->uri; 1 };
    ok($chained, 'the documented chaining idiom works on a first run') or diag $@;
    $rb->quit;
}

# jar_format went straight to set_persistent_storage. GI croaks on an unknown
# enum nick, but the die-unwind frees a transient WebKitCookieManager whose
# unref inside libwebkitgtk SIGSEGVs -- so an invalid value killed the PROCESS,
# uncatchable by eval and with no message at all. 'txt' is the natural slip,
# because jar_format => 'text' writes a file literally named cookies.txt.
#
# In a child, because the regression it guards is a signal, not an exception:
# in-process the mutant would take this file down with no plan and no TAP.
{
    my $jf = tempdir(CLEANUP => 1);
    my $inc = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" } @INC;
    for my $case (['txt',    'invalid'], ['bogus',  'invalid'],
                  ['sqlite', 'valid'],   ['text',   'valid']) {
        my ($fmt, $kind) = @$case;
        my $prog = 'use EV; use EV::WebKit; '
                 . 'my $ok = eval { my $b = EV::WebKit->new(window=>[200,150], '
                 . "cookie_jar => q{$jf/j-$fmt.db}, jar_format => q{$fmt}); \$b->quit; 1 }; "
                 . 'print $ok ? "BUILT\n" : "CROAK\n";';
        my $out = `timeout -k 5 60 '$^X' $inc -e '$prog' 2>&1`;
        my $sig = $? & 127;
        is($sig, 0, "jar_format => '$fmt' does not kill the process with a signal")
            or diag("died on signal $sig -- the GI enum croak unwound through a live GObject");
        if ($kind eq 'invalid') {
            like($out, qr/CROAK/, "...it croaks cleanly instead");
        }
        else {
            like($out, qr/BUILT/, "...and a valid format still constructs");
        }
    }
}

done_testing;
