use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use Scalar::Util qw(weaken);
use EV; use EV::WebKit; use File::Temp 'tempdir';

# pdf() serializes its PrintOperations: two (or more) running on one view at
# once race at the WebKit level (the failing one can fire 'finished' as a
# false success, or clobber the other), making concurrent pdf() outcomes
# non-deterministic. The queue runs exactly one at a time, so every concurrent
# request resolves correctly and deterministically.

# a value whose stringification dies -- used to force a setup-phase throw.
{ package DieStr; use overload '""' => sub { die "stringify boom\n" }, fallback => 1; sub new { bless {}, shift } }

sub is_pdf {
    my $p = shift;
    return 0 unless defined $p && -s $p;
    open my $fh, '<:raw', $p or return 0;
    read $fh, my $m, 5; close $fh;
    return $m eq '%PDF-';
}

my $dir = tempdir(CLEANUP => 1);
my $b = EV::WebKit->new(window => [400,300]);
$b->mock_scheme('pq', sub {
    ('<html><body><h1>Queue</h1>' . ('<p>lorem ipsum dolor sit amet</p>' x 40) . '</body></html>', 'text/html')
});
my $ready;
$b->go('pq://p', sub { $ready = 1; EV::break });
TWK::run_with_timeout(15);
ok($ready, 'setup: page loaded') or BAIL_OUT('no page');

# Time ONE print, and scale every budget below off it. Each block ends when its
# last callback fires; the watchdog is only a failsafe. A FIXED one doubles as
# the loop-exit on a loaded machine -- EV::run returns before the prints finish
# and the assertions then judge an unfinished run (mutation testing caught the
# pristine suite failing exactly this way under 3-way CPU load, reporting "only
# 0/12 ok"). So: scale generously off the measured cost, and SAY SO when a
# failsafe fires rather than silently asserting on half a run.
my $t_print;
{
    my $t0 = EV::time;
    $b->pdf("$dir/measure.pdf", sub { EV::break });
    TWK::run_with_timeout(60);
    $t_print = EV::time - $t0;
    ok(is_pdf("$dir/measure.pdf"), 'setup: timed a single print') or BAIL_OUT('cannot print at all');
    note(sprintf('one print costs %.3fs on this machine', $t_print));
}

# budget for $n prints, with a floor that tolerates the machine getting slower
# after the measurement.
sub budget { my $n = shift; return 60 + 30 * $n * ($t_print || 0.1) }

# run the loop until its callbacks are done, or the failsafe blows (and complain).
sub run_or_blame {
    my ($n, $what) = @_;
    my $blew = 0;
    my $wd = EV::timer(budget($n), 0, sub { $blew = 1; EV::break });
    EV::run; undef $wd;
    diag(sprintf('FAILSAFE FIRED after %.0fs waiting for %s -- this machine is too loaded to '
        . 'finish %d prints; the assertions below are judging an unfinished run',
        budget($n), $what, $n)) if $blew;
    return !$blew;
}

# 1) N concurrent pdf() to distinct good paths -- ALL must produce valid PDFs.
{
    my $N = 6;
    my @paths = map { "$dir/c$_.pdf" } 1 .. $N;
    my (@err, $pending);
    $pending = $N;
    for my $i (0 .. $N-1) {
        $b->pdf($paths[$i], sub { $err[$i] = $_[1]; EV::break unless --$pending });
    }
    run_or_blame($N, "$N concurrent pdfs");
    my $good = grep { !$err[$_] && is_pdf($paths[$_]) } 0 .. $N-1;
    is($good, $N, "all $N concurrent pdf() calls produced a valid PDF (serialized, no race)")
        or diag("only $good/$N ok; errors: " . join(' | ', map { $err[$_] // '(ok)' } 0 .. $N-1));
}

# 2) concurrent good + doomed (unwritable dir): deterministic, every time --
#    the doomed one fails, the good one succeeds, no false success either way.
SKIP: {
    skip 'cannot force a write failure via perms as root', 2 if $> == 0;
    my $rodir = "$dir/ro";
    mkdir $rodir or die $!;
    chmod 0500, $rodir or die $!;
    my ($ge, $be, $pending) = (undef, undef, 2);
    $b->pdf("$rodir/bad.pdf", sub { $be = $_[1]; EV::break unless --$pending });
    $b->pdf("$dir/good.pdf",  sub { $ge = $_[1]; EV::break unless --$pending });
    run_or_blame(2, "a good + a doomed pdf");
    chmod 0700, $rodir;
    ok(defined $be, 'concurrent doomed pdf() fails (no false success)')
        or diag('doomed delivered no error');
    ok(!$ge && is_pdf("$dir/good.pdf"), 'concurrent good pdf() succeeds deterministically')
        or diag("good err=" . ($ge // '(none)'));
}

# 3) quit() while pdf jobs are queued: every callback (active + queued)
#    resolves exactly once with 'browser closed'.
{
    my $qdir = tempdir(CLEANUP => 1);
    my $b2 = EV::WebKit->new(window => [300,200]);
    $b2->mock_scheme('pq2', sub { ('<html><body>hi</body></html>', 'text/html') });
    my $r2;
    $b2->go('pq2://p', sub { $r2 = 1; EV::break });
    TWK::run_with_timeout(10);
    my @errs;
    $b2->pdf("$qdir/a.pdf", sub { push @errs, $_[1] });   # becomes active
    $b2->pdf("$qdir/b.pdf", sub { push @errs, $_[1] });   # queued
    $b2->pdf("$qdir/c.pdf", sub { push @errs, $_[1] });   # queued
    $b2->quit;                                            # flush all three
    my $wd = EV::timer(3, 0, sub { EV::break });
    EV::run; undef $wd;
    is(scalar(@errs), 3, 'quit() resolved all three pdf callbacks (active + 2 queued)');
    is(scalar(grep { ($_ // '') =~ /browser closed/ } @errs), 3, "...each exactly once with 'browser closed'");
}

# 4) pdf() before ANY navigation must NOT segfault WebKit's print path -- it
#    must deliver a clean error. (A native crash would abort the process, so
#    prove reports the file failed; reaching done_testing is the pass.)
{
    my $pb = EV::WebKit->new(window => [200,150]);
    my ($err, $fired);
    my $wd = EV::timer(6, 0, sub { EV::break });
    $pb->pdf("$dir/pristine.pdf", sub { $err = $_[1]; $fired = 1; EV::break });
    EV::run; undef $wd;
    ok($fired, 'pdf() on a pristine (never-navigated) view fired its callback (no crash)');
    like($err // '', qr/no page loaded/, 'pdf() before any load: clean error, not a SIGSEGV');
    ok(!-e "$dir/pristine.pdf", 'pdf() before any load: no file written');
    $pb->quit;
}

# 5) a setup-phase throw (a $path/opt whose stringify dies) must reach the
#    callback and NOT throw synchronously out of pdf() nor wedge the queue
#    (leaving _pdf_active stuck so later jobs are starved).
{
    my ($e1, $f1, $e2, $f2);
    my $threw = !eval { $b->pdf(DieStr->new, sub { $e1 = $_[1]; $f1 = 1 }); 1 };
    ok(!$threw, 'pdf() with a dying-stringify path does not throw synchronously')
        or diag("threw: $@");
    # a well-formed job queued right behind it must still run
    $b->pdf("$dir/afterthrow.pdf", sub { $e2 = $_[1]; $f2 = 1; EV::break });
    run_or_blame(1, "a pdf after a setup-throw");
    ok($f1 && ($e1 // '') =~ /boom|stringify/, 'the dying-path pdf resolved via its callback with the error')
        or diag("f1=" . ($f1 // 0) . " e1=" . ($e1 // '(none)'));
    ok($f2 && !$e2 && is_pdf("$dir/afterthrow.pdf"),
        'a valid pdf() after the throw still runs (queue not wedged, _pdf_active freed)')
        or diag("f2=" . ($f2 // 0) . " e2=" . ($e2 // '(none)'));
}

# 6) The watchdog bounds the CALLER's wait -- but must NOT release the queue
#    slot. WebKit gives no way to force a print to stop (cancel() is advisory),
#    so a "timed out" operation is still running; handing the view to the next
#    job would put two PrintOperations on one view, which SEGFAULTS the engine
#    -- the exact race the queue exists to prevent. So: the caller gets
#    'timed out' promptly, the queue waits for the engine to really finish that
#    op, and every job behind it then runs correctly.
#
#    SEVERAL jobs must be queued behind: with only one, the overlap window is
#    too small to crash -- which is precisely how this defect slipped through.
{
    my $N = 4;
    my @err;
    my $pending = 1 + $N;
    $b->pdf("$dir/to.pdf", timeout => 0.001, sub { $err[0] = $_[1]; EV::break unless --$pending });
    for my $i (1 .. $N) {
        $b->pdf("$dir/g$i.pdf", sub { $err[$i] = $_[1]; EV::break unless --$pending });
    }
    run_or_blame(1 + $N, "a timed-out pdf plus $N queued behind it");
    is($err[0], 'timeout',
        "pdf(timeout => 0.001): the caller is bounded with the module's uniform 'timeout' error")
        or diag("err0=" . ($err[0] // '(none)'));
    my $good = grep { !$err[$_] && is_pdf("$dir/g$_.pdf") } 1 .. $N;
    is($good, $N,
        "all $N jobs queued behind a timed-out one run correctly (queue never overlaps a live print)")
        or diag("only $good/$N ok: " . join(' | ', map { $err[$_] // '(ok)' } 1 .. $N));
}

# 7) The watchdog must not form a reference cycle. Holding it in a lexical that
#    the resolution sub closes over would make
#        $finish -> $timer -> watchdog-closure -> $finish
#    and, since the watchdog holds the PrintOperation whose signal closures hold
#    $finish,  $timer -> $op -> finished-closure -> $finish -> $timer
#    -- trapping the callback, the timer and the native PrintOperation forever.
#    Canary: the caller's callback closes over an object we then drop; once the
#    pdf has resolved, nothing in the module may still be holding it.
{
    my $wcanary;
    {
        my $canary = { id => 'canary' };
        weaken($wcanary = $canary);
        my $wd = EV::timer(20, 0, sub { EV::break });
        $b->pdf("$dir/canary.pdf", sub { my $keep = $canary; EV::break });
        EV::run; undef $wd;
    }
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }   # settle deferred releases
    ok(!defined $wcanary,
        'pdf watchdog does not retain the callback after the op resolves (no refcount cycle)')
        or diag('the callback (and with it $finish/$timer/the PrintOperation) is still held');
}

# 8) The deadline runs from the pdf() CALL, not from the moment the job reaches
#    the head of the queue. Otherwise `timeout` cannot bound a queued call at
#    all: behind a slow -- or genuinely stuck -- print, a job given an explicit
#    timeout would simply never fire (only quit() would ever resolve it), which
#    is the exact hang the timeout exists to prevent.
#
#    Timed off a MEASURED print so the window holds on fast and slow machines
#    alike: deadline = 3 prints (comfortably longer than one print, so an
#    at-start watchdog would NOT fire), queued behind 12 (so ~9 are still
#    unprinted when the deadline lands and the job is provably still waiting).
{
    my $AHEAD = 12;
    my $TO    = 3 * $t_print;      # > one print, << the queue wait
    my ($qerr, $qfired, $qt);
    my $pending = $AHEAD + 1;
    my @aerr;
    for my $i (1 .. $AHEAD) {
        $b->pdf("$dir/q$i.pdf", sub { $aerr[$i] = $_[1]; EV::break unless --$pending });
    }
    my $tq = EV::time;
    $b->pdf("$dir/queued.pdf", timeout => $TO, sub {
        ($qfired, $qerr, $qt) = (1, $_[1], EV::time - $tq);
        EV::break unless --$pending;
    });
    run_or_blame(1 + $AHEAD, "$AHEAD prints plus one queued behind them");

    is($qerr, 'timeout', 'a pdf() queued behind slow prints times out on ITS OWN deadline')
        or diag("fired=" . ($qfired // 0) . " err=" . ($qerr // '(none)')
              . sprintf(" at t=%.2fs (timeout=%.2fs, t_print=%.2fs)", $qt // -1, $TO, $t_print));
    ok(defined $qt && $qt < $TO + 2 * $t_print + 0.5,
        '...measured from the call, not from when its turn came')
        or diag(sprintf("resolved at %.2fs, deadline was %.2fs", $qt // -1, $TO));
    # Grace period before checking. EV::run returns as soon as the last callback
    # fires, which races whatever the queue does with the abandoned job -- so
    # checking straight away, a stray print that HAD been wrongly started would
    # not have hit disk yet, and this assertion would pass anyway. (Mutation
    # testing caught exactly that: with _pdf_pump's skip removed, the file was
    # absent at this point and a full valid PDF appeared moments later.)
    { my $g = EV::timer(2 + 3 * $t_print, 0, sub { EV::break }); EV::run }
    ok(!-e "$dir/queued.pdf",
        '...and a job whose caller gave up while still queued is never printed')
        or diag('the queue spent a print on a document nobody was waiting for');
    my $good = grep { !$aerr[$_] && is_pdf("$dir/q$_.pdf") } 1 .. $AHEAD;
    is($good, $AHEAD, "all $AHEAD prints ahead of it still completed (queue intact)")
        or diag("only $good/$AHEAD ok");
}

$b->quit;
done_testing;
