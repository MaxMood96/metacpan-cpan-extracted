use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();

# Children must load the same lib the parent was told to use: under `make
# test` that is blib, under a mutation check some copy in /tmp. A hardcoded
# -Ilib made the child quietly test a different tree -- or, run from a
# directory without one, the INSTALLED module.
my $EVWK_INC = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" }
                        grep { !ref && length } @INC;   # shell-quoted: a path with a space would otherwise split into broken flags

use File::Temp qw(tempdir);
use IO::Socket::UNIX;
use POSIX ();
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Client; use EV::WebKit::Protocol;

# The client's failure paths. Every bug here presented as a HANG or a dead
# process, which is why they run in children under a shell timeout: a hung client
# would otherwise hang the suite instead of reporting.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/r.sock";

my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('r', sub { ('<html><body><h1>hi</h1></body></html>', 'text/html') });
my $ctl = EV::WebKit::Control->listen($b, path => $path);

# run a child that talks to our server, while WE keep the browser's loop turning
sub child {
    my ($code, $secs) = (@_, 60);
    state $seq = 0;
    my $script = "$dir/c" . (++$seq) . ".$$.pl";
    open my $fh, '>', $script or die $!;
    print $fh "use v5.10; use strict; use warnings; \$| = 1;\n"
            . "use EV::WebKit::Client;\nmy \$PATH = '$path';\n$code\n";
    close $fh;
    my $out = '';
    open my $ph, '-|', "timeout -k 5 $secs '$^X' $EVWK_INC '$script' 2>&1" or die $!;
    my $iow = EV::io($ph, EV::READ, sub {
        my $n = sysread($ph, my $buf, 8192);
        return EV::break if !defined $n || !$n;
        $out .= $buf;
    });
    my $wd = EV::timer($secs + 10, 0, sub { EV::break });
    EV::run; undef $iow; undef $wd;
    close $ph;
    my $rc = $? >> 8;
    return ($out, $rc);
}

# 1) The browser goes away, and the client makes one more call. Writing to a
#    closed peer raises SIGPIPE, whose default is to KILL THE PROCESS -- and no
#    eval can catch a signal. The client used to simply die, exit 141.
{
    my ($out, $rc) = child(<<'CODE');
my $c = EV::WebKit::Client->connect($PATH);
$c->go('r://p');
# rip the socket away underneath: the same thing the browser dying does
close $c->{sock};
open my $null, '<', '/dev/null'; $c->{sock} = $null;   # a handle that is not the browser
my $ok = eval { $c->title; 1 };
print "SURVIVED\n";
print "CROAKED ", ($ok ? 'no' : 'yes'), "\n";
CODE
    like($out, qr/^SURVIVED$/m, 'a client writing to a dead peer is not KILLED by SIGPIPE')
        or diag($rc == 141 ? 'the client died of SIGPIPE (exit 141)' : "rc=$rc out=$out");
    like($out, qr/^CROAKED yes$/m, '...it croaks, like every other error in blocking mode');
}

# 2) ev mode: one throwing callback must not swallow its siblings. Several
#    responses can land in a single read, and a die used to abort the whole
#    batch -- the same bug quit()'s flush loops had.
{
    my ($out, $rc) = child(<<'CODE');
use EV;
my $fired = 0;
my $c = EV::WebKit::Client->connect($PATH, ev => 1);
$c->script('return 1', sub { $fired++; die "boom from the first callback\n" });
$c->script('return 2', sub { $fired++ });
$c->script('return 3', sub { $fired++; EV::break });
local $SIG{__WARN__} = sub {};
my $wd = EV::timer(20, 0, sub { EV::break }); EV::run;
print "FIRED $fired\n";
CODE
    like($out, qr/^FIRED 3$/m, 'ev mode: a throwing callback does not drop its siblings')
        or diag("only some callbacks fired: $out");
}

# 3) ev mode: disconnect() must resolve what is still in flight. Walking away
#    from a pending callback is a hung caller -- and disconnect is an ordinary
#    documented call, not an error path.
{
    my ($out, $rc) = child(<<'CODE');
use EV;
my ($fired, $err) = (0, undef);
my $c = EV::WebKit::Client->connect($PATH, ev => 1);
$c->script('return 1', sub { $fired++; $err = $_[1] });
$c->disconnect;                       # while it is still in flight
print "FIRED $fired\n";
print "ERR ", ($err // '(none)'), "\n";
CODE
    like($out, qr/^FIRED 1$/m, 'ev mode: disconnect() answers the requests still in flight');
    like($out, qr/^ERR disconnected$/m, '...saying why, instead of dropping them');
}

# 4) ev mode: ->hello. The greeting is an event, and in ev mode it went to the
#    event queue and never populated the accessor -- so re-attaching to a
#    long-lived session, the entire point of the greeting, silently did not work.
{
    my ($out, $rc) = child(<<'CODE');
use EV;
my $c = EV::WebKit::Client->connect($PATH, ev => 1);
$c->title(sub { EV::break });          # pump once
my $wd = EV::timer(20, 0, sub { EV::break }); EV::run;
print "HELLO ", ($c->hello && $c->hello->{proto} ? 'yes' : 'no'), "\n";
CODE
    like($out, qr/^HELLO yes$/m, 'ev mode: ->hello is populated (it used to be undef forever)');
}

# 5) A blocking call made from inside on_event must not eat the OUTER call's
#    answer. on_event is invoked from inside the blocking read loop, so a handler
#    that makes its own call nests a second read inside the first -- and that
#    nested read can pull the outer call's response off the socket. Discarding it
#    leaves the outer caller waiting forever for an answer that already arrived.
#
#    Driven against a FAKE server: the bug needs BOTH responses to land in ONE
#    read, which is an interleaving a real server produces under load and which
#    a test cannot get by hoping for it. (No browser needed -- this is entirely
#    about the client's read loop.)
{
    my $fpath = "$dir/fake.sock";
    unlink $fpath;
    my $srv = IO::Socket::UNIX->new(Local => $fpath, Listen => 1) or die "fake server: $!";
    my $outfile = "$dir/reentrant.out";

    my $pid = fork();
    die "fork: $!" unless defined $pid;
    unless ($pid) {                                  # ---- the client
        close $srv;
        open my $o, '>', $outfile;
        eval {
            local $SIG{ALRM} = sub { die "HUNG\n" };
            alarm 20;
            my ($nested, $c) = (0, undef);
            $c = EV::WebKit::Client->connect($fpath, on_event => sub {
                my ($ev) = @_;
                return if $nested++ || $ev ne 'navigate';
                $c->uri;                             # a blocking call, from inside an event
            });
            my $t = $c->title;                       # the OUTER call
            alarm 0;
            print $o "OUTER $t\n";
            1;
        } or print $o "FAILED: $@";
        close $o;
        POSIX::_exit(0);
    }

    my $cl = $srv->accept;                           # ---- the fake server
    $cl->autoflush(1);
    print $cl EV::WebKit::Protocol::encode({ ev => 'hello', proto => 1 });
    my $req1 = <$cl>;                                # the OUTER request (title, i=1)
    print $cl EV::WebKit::Protocol::encode({ ev => 'navigate', uri => 'x://y' });
    my $req2 = <$cl>;                                # the NESTED request (uri, i=2)
    # Both answers in ONE write, nested first: the nested read sees the outer's
    # frame too, and must keep it rather than bin it.
    print $cl EV::WebKit::Protocol::encode({ i => 2, r => 'x://y' })
            . EV::WebKit::Protocol::encode({ i => 1, r => 'TITLE' });
    waitpid $pid, 0;
    close $cl; close $srv;

    my $got = do { open my $i, '<', $outfile or die $!; local $/; <$i> } // '';
    like($got, qr/^OUTER TITLE$/m,
        'a blocking call from inside on_event does not eat the outer call\'s answer')
        or diag($got =~ /HUNG/
            ? 'the client HUNG: the nested read took the outer response and threw it away'
            : "got: $got");
}

# 6) The most basic thing of all: a blocking connect() must RETURN. The greeting
#    is an event, and if _read_until tests the event branch before its predicate
#    it buffers the hello and waits forever for it. In a CHILD under a hard
#    timeout, because that hang cannot be caught in-process (the parent's own
#    close($ph) waits on the child) -- a broken predicate must fail in seconds,
#    not hang the file.
{
    my ($out, $rc) = child(<<'CODE', 20);
my $c = EV::WebKit::Client->connect($PATH);
print "CONNECTED proto=", ($c->hello->{proto} // '?'), "\n";
CODE
    like($out, qr/^CONNECTED proto=1$/m, 'a blocking connect() returns (the greeting is not swallowed as an event)')
        or diag($rc == 124 || $rc == 137
            ? 'connect() HUNG: _read_until buffered the hello instead of returning it'
            : "rc=$rc out=$out");
}

$ctl->close;
$b->quit;
done_testing;
