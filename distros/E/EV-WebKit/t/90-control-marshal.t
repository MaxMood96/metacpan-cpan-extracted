use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available(); use TCTL;
use File::Temp qw(tempdir);
use MIME::Base64 ();
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Protocol;

# Results that are not plain data. Everything here was a live bug: the server
# happily handed a blessed Element, or raw PNG octets, to a JSON encoder.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/m.sock";

my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('m', sub { ('<html><body><h1>hi</h1></body></html>', 'text/html') });
my $ctl = EV::WebKit::Control->listen($b, path => $path);
my $cl  = TCTL->new($path);
$cl->pump(1);   # hello
$cl->reply({ i => 1, m => 'go', a => ['m://p'] }, 25);

# 1) wait_for resolves with an ELEMENT, exactly as find/find_all do -- an easy
#    one to miss, because it reads like a plain "wait until" call. Handed to the
#    JSON codec it dies INSIDE EV::WebKit's _defer timer, where $EV::DIED merely
#    warns: the browser lives, and the request is never answered at all. A client
#    hung forever is the one failure mode this protocol must not have.
{
    my $r = $cl->reply({ i => 2, m => 'wait_for', a => ['h1'] }, 25);
    ok($r, 'wait_for is ANSWERED (it used to hang the request forever)')
        or diag('no response at all -- the result was an object the codec could not encode');
    ok($r && !exists $r->{e}, '...without an error') or diag('err=' . ($r->{e} // ''));
    ok($r && ref $r->{r} eq 'HASH' && defined $r->{r}{h},
        '...with an element HANDLE, like find') or diag(explain $r);

    # and the handle actually works
    my $h = $r->{r}{h};
    is($cl->reply({ i => 3, m => 'el.text', h => $h })->{r}, 'hi',
        '...and the handle reads its element');
}

# 2) NOTHING may answer with silence. Any result the codec cannot encode must
#    come back as an error -- this is the general guard, and the reason the next
#    method to return an object will be an error instead of a hung client.
{
    my $r = $cl->reply({ i => 4, m => 'wait_for', a => ['#never'], o => { timeout => 1 } }, 15);
    ok($r, 'a wait_for that times out is answered too');
    is($r && $r->{e}, 'timeout', "...with the module's uniform 'timeout' error");
}

# 3) screenshot's first argument is a PATH or an options HASHREF, and flattening
#    options destroys the distinction: {"o":{"bytes":1}} became
#    screenshot('bytes', 1), which took 'bytes' for a path, wrote a real PNG to a
#    file of that name in the server's working directory, and reported success.
{
    my $cwd_before = -e 'bytes' ? 1 : 0;
    my $r = $cl->reply({ i => 5, m => 'screenshot', o => { bytes => 1 } }, 25);
    ok($r && !exists $r->{e}, 'screenshot(bytes => 1) succeeds') or diag('err=' . ($r->{e} // ''));
    ok(!(-e 'bytes') || $cwd_before,
        '...and does NOT write a stray file called "bytes" into the working directory')
        or do { diag('the server wrote a PNG to a file literally named "bytes"'); unlink 'bytes' };

    # 4) raw PNG octets cannot live in a JSON string: they come back base64'd
    ok($r && ref $r->{r} eq 'HASH' && exists $r->{r}{b64},
        '...and the image comes back base64-encoded, as documented')
        or diag('the raw bytes went straight into the JSON encoder');
    my $png = MIME::Base64::decode_base64($r->{r}{b64} // '');
    is(substr($png, 0, 8), "\x89PNG\r\n\x1a\n", '...and it decodes to a real PNG');
}

# 5) path mode still works, and the result is still the path
{
    my $r = $cl->reply({ i => 6, m => 'screenshot', a => ["$dir/shot.png"] }, 25);
    is($r && $r->{r}, "$dir/shot.png", 'screenshot($path) still answers with the path');
    ok(-s "$dir/shot.png", '...and really wrote the file');
}

# 6) A request PIPELINED behind quit in one write must leave nothing behind:
#    no answer, and no side effect.
#
#    What this can and cannot pin, measured rather than assumed. Control's own
#    `last unless exists $s->{clients}{$id}` guard is NOT independently
#    observable: with it deleted, frame 3 IS dispatched, but every browser method
#    dead-gates on {_dead} and resolves 'browser closed' without touching
#    anything, and the reply then finds no client and is dropped. So both worlds
#    look identical from out here, and an assertion claiming to catch the
#    dispatch would be claiming something it cannot see. What IS pinned is the
#    outcome a client depends on -- silence, and an unwritten file -- which is
#    the browser-side dead-gating (t/21-teardown covers that directly) with the
#    Control guard as defence in depth behind it.
#
#    On its OWN browser+server: quit here tears down that browser, and a second
#    teardown of the shared one (its own quit here, then global destruction)
#    double-frees the native session.
{
    my $qb = EV::WebKit->new(window => [200,150], ephemeral => 1);
    my $qctl = EV::WebKit::Control->listen($qb, path => "$dir/q.sock");
    my $c2 = TCTL->new("$dir/q.sock");
    $c2->pump(1);
    # The third frame asks for something with an OBSERVABLE side effect. `title`
    # cannot show anything: on a torn-down browser it returns undef without
    # dying and the reply goes nowhere, so "no answer" is equally true whether
    # the request was refused or dispatched-and-dropped -- measured, by deleting
    # the guard in Control::_dispatch and watching every assertion here stay
    # green while the request was in fact dispatched. A screenshot either writes
    # its file or does not.
    my $shot = "$dir/after-quit.png";
    $c2->send_raw(
        EV::WebKit::Protocol::encode({ i => 1, m => 'title' }) .
        EV::WebKit::Protocol::encode({ i => 2, m => 'quit' }) .
        EV::WebKit::Protocol::encode({ i => 3, m => 'screenshot', a => [$shot] })
    );
    my @f = $c2->pump(6, 10);
    my %ans = map { $_->{i} => $_ } grep { !defined $_->{ev} && defined $_->{i} } @f;
    ok($ans{1}, 'the request before quit is answered');
    ok($ans{2}, 'the quit itself is answered');
    ok(!exists $ans{3}, 'a request pipelined AFTER quit is not answered')
        or diag('unexpected answer: ' . join(',', map { "$_=" . ($ans{3}{$_} // 'undef') } sort keys %{$ans{3}}));
    # ...and left no side effect. A settle first, so this is "it did not happen"
    # rather than "it has not happened yet".
    my $settle = EV::timer(1, 0, sub { EV::break }); EV::run; undef $settle;
    ok(!-e $shot, '...and wrote nothing -- a screenshot pipelined after quit leaves no file')
        or diag("$shot exists (" . (-s $shot) . " bytes)");
    $c2->close;
    $qctl->close;   # quit already tore qb down; this is a no-op, but be explicit
}

$ctl->close;
$b->quit;
# The server works out whether bytes were asked for by parsing the client's
# argument list the same way screenshot() does. An EVEN `a` whose first element
# is not a hashref -- which is what $c->screenshot(bytes => 1) sends, the
# spelling screenshot itself now croaks on -- used to warn "Odd number of
# elements in hash assignment" from inside the SERVER. Every other screenshot
# frame in this suite takes one of the three shapes that never reach it.
{
    # its own server: the one above has been quit by now
    my $sb = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 10);
    my $sp = "$dir/shotarg.sock";
    my $sctl = EV::WebKit::Control->listen($sb, path => $sp);
    my $cl = TCTL->new($sp);
    $cl->pump(1);
    my @w; local $SIG{__WARN__} = sub { push @w, $_[0] };
    my $r = $cl->reply({ i => 9100, m => 'screenshot', a => ['bytes', 1] }, 15);
    ok($r, 'an even, non-hashref screenshot argument list is answered')
        or diag('no answer -- the client would hang here');
    ok($r && defined $r->{e}, '...with an error (screenshot croaks on that spelling)');
    is(scalar(grep { /Odd number of elements/ } @w), 0,
       '...and the server did not warn from inside itself while working it out');
    $cl->close;
    $sctl->close;
    $sb->quit;
    for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

done_testing;
