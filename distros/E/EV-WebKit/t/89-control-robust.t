use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available(); use TCTL;

# Children must load the same lib the parent was told to use: under `make
# test` that is blib, under a mutation check some copy in /tmp. A hardcoded
# -Ilib made the child quietly test a different tree -- or, run from a
# directory without one, the INSTALLED module.
my $EVWK_INC = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" }
                        grep { !ref && length } @INC;   # shell-quoted: a path with a space would otherwise split into broken flags

use File::Temp qw(tempdir);
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Protocol;

# Many clients, dead clients, hostile clients. The server is inside the browser
# process, so anything that takes IT down takes the browser with it.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/rb.sock";

my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('rb', sub {
    my $uri = shift;
    # a deliberately slow page, so a second navigation can supersede the first
    return ('<html><body><h1>slow</h1></body></html>', 'text/html') if $uri =~ /slow/;
    return ('<html><body><h1>hi</h1><p>x</p></body></html>', 'text/html');
});
my $ctl = EV::WebKit::Control->listen($b, path => $path);

# collect the response to id $id on this client, pumping until it turns up
sub answer_to {
    my ($cl, $id, $secs) = @_;
    $secs //= 25;
    my $deadline = EV::time + $secs;
    while (EV::time < $deadline) {
        my @f = $cl->pump(1, $deadline - EV::time);
        last unless @f;
        my ($r) = grep { !defined $_->{ev} && ($_->{i} // -1) == $id } @f;
        return $r if $r;
    }
    return undef;
}

# 1) TWO CLIENTS AT ONCE, with NO CROSS-TALK. Each must get its OWN answer -- the
#    failure this rules out is a server that writes one client's result to
#    another's socket, which is the classic multiplexing bug.
{
    my $a = TCTL->new($path); $a->pump(1);
    my $c = TCTL->new($path); $c->pump(1);

    # deliberately the SAME request id on both connections: ids are per-client,
    # so a server that mixed them up would answer the wrong socket
    $a->send_frame({ i => 1, m => 'script', a => ['return "AAA"'] });
    $c->send_frame({ i => 1, m => 'script', a => ['return "CCC"'] });

    my $ra = answer_to($a, 1);
    my $rc = answer_to($c, 1);
    is($ra && $ra->{r}, 'AAA', "client A gets A's answer");
    is($rc && $rc->{r}, 'CCC', "client C gets C's answer, on its own connection (no cross-talk)");

    $a->close; $c->close;
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# 2) SUPERSEDED NAVIGATION, REPORTED HONESTLY. A second go() supersedes the
#    first -- that is what two go() calls do in one process, and the protocol
#    reports it rather than faking exclusivity, queueing, or (worst) claiming
#    success for a navigation the browser abandoned.
#
#    Deterministically: two go() frames in ONE write, so the server reads them in
#    a single chunk and the second supersedes the first before it can finish.
{
    my $cl = TCTL->new($path); $cl->pump(1);
    $cl->send_raw(
        EV::WebKit::Protocol::encode({ i => 1, m => 'go', a => ['rb://slow'] }) .
        EV::WebKit::Protocol::encode({ i => 2, m => 'go', a => ['rb://other'] })
    );

    my $first  = answer_to($cl, 1);
    my $second = answer_to($cl, 2);

    ok($first, 'the superseded navigation IS answered (never left hanging)');
    is($first && $first->{e}, 'superseded',
        "...and told the truth: 'superseded', the browser's own word for it")
        or diag('got: ' . ($first->{e} // ('success r=' . ($first->{r} // '?'))));
    ok($second && !defined $second->{e}, 'the navigation that won succeeds');
    is($cl->reply({ i => 3, m => 'uri' })->{r}, 'rb://other',
        '...and the browser really is where the winner sent it');

    $cl->close;
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# 3) A CLIENT KILLED MID-REQUEST. The server must drop it, free its handles, and
#    keep serving everybody else. A control server that dies with its client
#    takes the browser down with it.
#
#    The precondition -- the dead client actually HELD a handle -- is VERIFIED,
#    not assumed: an earlier version of this test asserted "0 handles after the
#    kill" while the handle had simply never been created (the find never
#    completed in the sleep window), so it passed for the wrong reason. Here the
#    parent pumps until the handle really exists, THEN kills the child, THEN
#    confirms it goes away -- and it tracks the specific client, not a stale id.
{
    my $survivor = TCTL->new($path); $survivor->pump(1);
    $survivor->reply({ i => 1, m => 'go', a => ['rb://p'] }, 25);
    my $handles_before  = scalar keys %{ $ctl->{handles} };
    my $clients_before  = scalar keys %{ $ctl->{clients} };

    # a raw socket we control, so we can find() (server takes a handle) and then
    # vanish without a clean close
    my $victim = IO::Socket::UNIX->new(Peer => $path) or die "connect: $!";
    $victim->syswrite(EV::WebKit::Protocol::encode({ i => 1, m => 'find', a => ['h1'] }));

    # pump until the server has actually taken the handle -- with a deadline, so
    # a server that never does fails here rather than sailing past
    my $deadline = EV::time + 20;
    while (scalar(keys %{ $ctl->{handles} }) <= $handles_before && EV::time < $deadline) {
        my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run;
    }
    cmp_ok(scalar keys %{ $ctl->{handles} }, '>', $handles_before,
        'the victim client really did take a handle (precondition verified, not assumed)')
        or diag('the find never produced a handle -- the rest of this block would prove nothing');
    is(scalar keys %{ $ctl->{clients} }, $clients_before + 1, '...and the server sees it connected');

    close $victim;   # vanish. no quit, no graceful anything.

    # pump until the server has reaped it (bounded)
    $deadline = EV::time + 10;
    while (scalar(keys %{ $ctl->{clients} }) > $clients_before && EV::time < $deadline) {
        my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run;
    }

    my $r = $survivor->reply({ i => 2, m => 'script', a => ['return "alive"'] }, 20);
    is($r && $r->{r}, 'alive', 'a client that vanished mid-request does not take the browser down');
    is(scalar keys %{ $ctl->{handles} }, $handles_before,
        "...and its handle is freed (back to exactly what it was before -- no leak)");
    is(scalar keys %{ $ctl->{clients} }, $clients_before,
        '...and it is dropped from the client table (tracked precisely, not a stale id)');

    # A client that connects and vanishes having asked for NOTHING must still be
    # reaped -- by noticing EOF on the read side. The victim above was reaped
    # incidentally, by the find-response write failing; a client with no pending
    # write can ONLY be cleaned up on read-EOF, and if that is missing the dead
    # fd's watcher busy-loops forever (a live CPU leak the suite is otherwise
    # blind to). So: connect, read the greeting, close, and confirm reaping.
    {
        my $idle = IO::Socket::UNIX->new(Peer => $path) or die "connect: $!";
        my $wait = EV::time + 5;
        while (EV::time < $wait) { my $t = EV::timer(0.1, 0, sub { EV::break }); EV::run;
                                   last if scalar(keys %{ $ctl->{clients} }) > $clients_before }
        is(scalar keys %{ $ctl->{clients} }, $clients_before + 1, 'an idle client connected');
        # DRAIN the greeting before closing. A client that closes with unread
        # data makes the kernel send RST, which the server sees as a read ERROR
        # (a different, unmutated drop path) -- so leaving the hello unread would
        # reap it regardless and prove nothing. Read it, so the close is a clean
        # EOF and the read-EOF path is the only thing that can reap it.
        sysread($idle, my $hello, 65536);
        close $idle;
        my $dl2 = EV::time + 10;
        while (scalar(keys %{ $ctl->{clients} }) > $clients_before && EV::time < $dl2) {
            my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run;
        }
        is(scalar keys %{ $ctl->{clients} }, $clients_before,
            'an idle client that vanishes is reaped on read-EOF (no leak, no busy-loop on the dead fd)');
    }

    $survivor->close;
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# 4) A HOSTILE CLIENT. Garbage, then a line that never ends. The browser must
#    still be there afterwards, serving everybody else.
{
    my $good = TCTL->new($path); $good->pump(1);

    my $bad = TCTL->new($path); $bad->pump(1);
    $bad->send_raw("garbage garbage\n" x 3);
    $bad->send_raw('x' x (1024 * 1024));       # a megabyte with no newline in it
    for (1 .. 10) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }

    my $r = $good->reply({ i => 9, m => 'script', a => ['return "still here"'] }, 20);
    is($r && $r->{r}, 'still here',
        'a client sending garbage does not disturb the browser or anybody else');
    $bad->close; $good->close;
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
}

# 5) THE WEDGE. A client command triggers a page dialog, which the browser answers
#    LOCALLY (a network round-trip inside WebKit's dispatch frame is the one thing
#    this design refuses to do). Afterwards a fresh EV::run must still complete.
#
#    In a CHILD under a shell timeout: a wedge SPINS rather than fails, so an
#    in-process test would hang the suite instead of reporting -- see
#    t/05-wedge-ops.t.
{
    my $script = "$dir/wedge.pl";
    open my $fh, '>', $script or die $!;
    print $fh <<'CHILD';
use v5.10; use strict; use warnings; $| = 1;
use File::Temp qw(tempdir);
use IO::Socket::UNIX;
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Protocol;
my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/w.sock";
my $dialogs = 0;
my $b = EV::WebKit->new(window => [300,200], ephemeral => 1,
                        on_dialog => sub { $dialogs++; $_[0]->accept });
$b->mock_scheme('w', sub { ('<html><body>hi</body></html>', 'text/html') });
my $ctl = EV::WebKit::Control->listen($b, path => $path);

my $s = IO::Socket::UNIX->new(Peer => $path) or die "connect: $!";
$s->blocking(0);
my $dec = EV::WebKit::Protocol::decoder();
my @in;
my $rw = EV::io($s, EV::READ, sub {
    my $n = sysread($s, my $buf, 65536);
    return unless $n;
    push @in, $dec->($buf);
    EV::break;
});
syswrite($s, EV::WebKit::Protocol::encode({ i => 1, m => 'go', a => ['w://p'] }));
# a client command that makes the PAGE raise a dialog. The browser answers it
# itself; the client never sees a decision request, because answering one would
# mean holding WebKit's dispatch frame open across a socket round-trip.
syswrite($s, EV::WebKit::Protocol::encode({ i => 2, m => 'script', a => ['confirm("x"); return 1'] }));
my $wd = EV::timer(25, 0, sub { EV::break });
for (1 .. 40) { last if grep { ($_->{i} // 0) == 2 } @in; EV::run }
undef $wd;
print "DIALOGS $dialogs\n";
print "ANSWERED ", (scalar(grep { ($_->{i} // 0) == 2 } @in) ? 'yes' : 'no'), "\n";
# The proof: a fresh, independent EV::run must still complete. Under an armed
# wedge the first call never returns and the parent's `timeout` kills us.
#
# Looping rather than a single EV::run, because the socket read watcher above
# calls EV::break on ANY incoming frame -- a stray event would otherwise end the
# run before the timer could fire, and we would report a wedge that is not there.
my $alive = 0;
my $t = EV::timer(0.05, 0, sub { $alive = 1; EV::break });
for (1 .. 50) { last if $alive; EV::run }
print "WEDGE-FREE\n" if $alive;
CHILD
    close $fh;

    my $out = `timeout -k 5 90 '$^X' $EVWK_INC '$script' 2>/dev/null`;
    my $rc  = $? >> 8;
    like($out, qr/^DIALOGS 1$/m, 'a dialog raised by a client command is answered LOCALLY by the browser');
    like($out, qr/^ANSWERED yes$/m, '...and the client still gets its answer');
    ok($out =~ /^WEDGE-FREE$/m && $rc == 0,
        '...without wedging the loop (no round-trip inside a dispatch frame)')
        or diag($rc == 124 || $rc == 137
            ? 'child had to be KILLED: the loop wedged'
            : "child exit=$rc, output: $out");
}

# --- a frame whose fields are valid JSON but the wrong SHAPE ---
#
# `// []` guards a MISSING field and does nothing about a present one of the
# wrong type: @{ $hashref } is a fatal "Not an ARRAY reference", thrown inside
# the read watcher where nothing catches it. So {"a":{}} -- a plausible bug in
# any client -- went unanswered AND took every request decoded from the same
# sysread with it. One bad frame poisoning a batch of good ones is the
# never-answered-request class this protocol must not have.
{
    my $c = IO::Socket::UNIX->new(Peer => $path) or die "connect: $!";
    # both frames in ONE write, so they decode from a single sysread
    $c->syswrite(EV::WebKit::Protocol::encode({ i => 901, m => 'title', a => {} })
               . EV::WebKit::Protocol::encode({ i => 902, m => 'title' }));
    $c->blocking(0);
    my $buf = '';
    my $deadline = EV::time + 20;
    until (($buf =~ /"i":901/ && $buf =~ /"i":902/) || EV::time > $deadline) {
        my $n = sysread($c, my $chunk, 4096);
        $buf .= $chunk if defined $n && $n;
        my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run;
    }
    like($buf, qr/"i":901/, 'a frame with a wrong-shaped field is answered, not dropped');
    like($buf, qr/'a' must be an array/, '...saying which field and what it should be');
    like($buf, qr/"i":902/, '...and the valid frame behind it in the same batch still answers')
        or diag('one bad frame poisoned the whole read');
    close $c;
}

# --- a client must not be able to release another client's handle ---
#
# The ownership check further down names el.release as a case it covers -- but
# el.release returned before reaching it. Handle ids are small sequential
# integers, so guessing takes no effort.
{
    my $owner = IO::Socket::UNIX->new(Peer => $path) or die "connect: $!";
    my $other = IO::Socket::UNIX->new(Peer => $path) or die "connect: $!";
    $owner->syswrite(EV::WebKit::Protocol::encode({ i => 910, m => 'find', a => ['h1'] }));
    my $before = scalar keys %{ $ctl->{handles} };
    my $deadline = EV::time + 20;
    while (scalar(keys %{ $ctl->{handles} }) <= $before && EV::time < $deadline) {
        my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run;
    }
    # A plain loop, not sort: this file has a lexical $b (the browser) that
    # shadows sort's own $b, so `sort { $b <=> $a }` here compared against undef
    # and picked an arbitrary key -- it passed only because exactly one handle
    # exists at this point.
    my $h;
    for my $k (keys %{ $ctl->{handles} }) { $h = $k if !defined $h || $k > $h }
    ok(defined $h, 'precondition: the owning client took a handle')
        or diag('no handle was created -- the rest of this block would prove nothing');

    $other->syswrite(EV::WebKit::Protocol::encode({ i => 911, m => 'el.release', h => $h }));
    my $reply = '';
    $other->blocking(0);
    $deadline = EV::time + 20;
    until ($reply =~ /"i":911/ || EV::time > $deadline) {
        my $n = sysread($other, my $chunk, 4096);
        $reply .= $chunk if defined $n && $n;
        my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run;
    }
    like($reply, qr/stale element/, "a client cannot release another client's handle");
    ok(exists $ctl->{handles}{$h}, "...and the owner's handle is still there")
        or diag('the handle was released out from under its owner');
    close $owner; close $other;
}

$ctl->close;
$b->quit;
done_testing;
