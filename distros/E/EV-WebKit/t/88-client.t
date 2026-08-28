use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use File::Temp qw(tempdir);
use EV; use EV::WebKit; use EV::WebKit::Control; use EV::WebKit::Client;

# The client. Blocking by default -- `say $c->title` -- because that is what you
# want from a shell or a one-off script. EV-native with ev => 1, because that is
# what you want inside an event loop.
#
# The browser and the server live in THIS process, and the blocking client talks
# to them over a real socket. That works only because blocking mode is plain
# socket I/O and never runs the event loop: if it did, it would be re-entering
# the very loop the browser is using, which is how EV::Glib gets wedged.
#
# ...which is also why the blocking half runs in a CHILD: this process's EV loop
# has to keep turning for the browser to answer at all.

my $dir  = tempdir(CLEANUP => 1);
my $path = "$dir/cl.sock";

my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('cl', sub {
    my $uri = shift;
    return ('<html><head><title>Page</title></head><body><h1>hi</h1>'
          . '<a id="lnk" href="cl://second">go</a><p>a</p><p>b</p></body></html>', 'text/html')
        if $uri =~ /first/;
    return ('<html><head><title>Second</title></head><body><h1>SECOND</h1></body></html>', 'text/html');
});
my $ctl = EV::WebKit::Control->listen($b, path => $path);

# ---- blocking client, in a child (this process must keep running the loop) ----
{
    my $script = "$dir/blocking.pl";
    open my $fh, '>', $script or die $!;
    print $fh <<"CHILD";
use v5.10; use strict; use warnings; \$| = 1;
use EV::WebKit::Client;
my \$c = EV::WebKit::Client->connect('$path');
print "HELLO ", (\$c->hello && \$c->hello->{proto} ? 'yes' : 'no'), "\\n";
\$c->go('cl://first');
print "TITLE ", \$c->title, "\\n";
print "SCRIPT ", \$c->script('return 40 + 2'), "\\n";
my \$el = \$c->find('h1');
print "FIND ", \$el->text, "\\n";
print "TAG ", \$el->tag, "\\n";
my \$all = \$c->find_all('p');
print "FINDALL ", scalar(\@\$all), "\\n";
print "URI ", \$c->uri, "\\n";
# The later surface. Client's POD promises that the EV::WebKit methods listed
# under its own METHODS head are here, with the same names and arguments -- and
# none of the later-surface calls in the next block were,
# so the promise shipped false and the whole feature set was unreachable from
# the mirror layer.
# wait_for(gone => 1) resolves with a plain TRUE, not an element -- there is
# no node left to hand back. Marshalled as one it became an element proxy
# wrapping the scalar 1; unmarshalled but still unwrapped on this side it
# died dereferencing 1->{h}, which in ev mode is a dropped callback.
print "GONE ", (\$c->wait_for('#never-there', gone => 1) // 'undef'), "\\n";
print "STATUS ", (\$c->status // 'undef'), "\\n";
print "PRESS ", (\$c->press('Enter') ? 'ok' : 'false'), "\\n";
print "SCROLL ", (ref \$c->scroll(y => 10) eq 'HASH' ? 'hash' : 'not-hash'), "\\n";
print "WAITJS ", \$c->wait_for_js('1 + 1'), "\\n";
print "BOX ", (ref \$el->box eq 'HASH' ? 'hash' : 'not-hash'), "\\n";
print "SIV ", (\$el->scroll_into_view ? 'ok' : 'false'), "\\n";
print "HOVER ", (\$el->hover ? 'ok' : 'false'), "\\n";
# send_keys is a glob alias of type, and the only alias in the distribution --
# which is why it was missing from the mirror since Control was written:
# enumerating the methods someone wrote out by hand does not turn up a symbol
# created by *x = \\&y.
# The page has nothing editable, so what is asserted is that the call REACHES
# the real method -- "element is not editable" comes from Element::type itself,
# whereas the gap produced "unknown method: el.send_keys" from the server.
# #lnk is an anchor, so Element::type refuses it -- and that refusal is the
# proof the REAL method ran. Reporting merely "not unknown method" also passed
# on a dropped connection, an undef handle or a stale one.
my \$sk = eval { \$c->find('#lnk')->send_keys('x'); 'NO-ERROR' }
        || (\$@ =~ /not editable/      ? 'reached'
          : \$@ =~ /unknown method/    ? 'UNKNOWN-METHOD'
          :                              "OTHER: \$@");
\$sk =~ s/\\s+/ /g;
print "SENDKEYS \$sk\\n";
# Too MANY arguments must error, not hang. These methods bind positionally, so a
# spare argument lands in the callback slot: most then croak, but uncheck's
# my (\$s, \$cb) = \@_ takes it silently, passes undef down, and nothing ever
# answers -- the client blocks until the socket closes.
my \$over = eval { \$el->hover('extra'); 1 } ? 'no' : 'yes';
print "ARITY \$over\\n";
# an error CROAKS in blocking mode: synchronous code has no callback to hand it to
my \$ok = eval { \$c->go(undef); 1 };
print "CROAK ", (\$ok ? 'no' : 'yes'), " ", (\$@ =~ /uri required/ ? 'right-error' : "wrong: \$@"), "\\n";
# a stale handle after navigating
\$c->go('cl://second');
my \$stale = eval { \$el->text; 1 } ? 'no' : 'yes';
print "STALE \$stale\\n";
# events arrived while we were working
my \@ev = \$c->events;
print "EVENTS ", scalar(grep { \$_->{ev} eq 'navigate' } \@ev), "\\n";
\$c->disconnect;

# RE-ATTACH. This is use case 2: the browser holds expensive state (a login, a
# warmed-up page), a script does its work and leaves, and the next one picks up
# where it left off. The greeting is what tells it where the browser already is.
my \$c2 = EV::WebKit::Client->connect('$path');
print "REATTACH ", (\$c2->hello->{uri} // '(none)'), "\\n";
print "REATTACH_TITLE ", (\$c2->hello->{title} // '(none)'), "\\n";
\$c2->disconnect;
CHILD
    close $fh;

    # run the child while THIS process keeps the browser's loop turning
    my $out = '';
    # Inherit the parent's @INC, not a hardcoded -Ilib: run under -I some
    # other copy (a mutation check, a staged tree) and the child would
    # otherwise keep testing lib/ while the parent tested the copy.
    my $inc = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" }
                        grep { !ref && length } @INC;   # shell-quoted, as the child is run through a shell
    open my $ph, '-|', "'$^X' $inc '$script' 2>/dev/null" or die $!;
    my $iow = EV::io($ph, EV::READ, sub {
        my $n = sysread($ph, my $buf, 8192);
        if (!defined $n or !$n) { return EV::break }
        $out .= $buf;
    });
    my $wd = EV::timer(60, 0, sub { EV::break });
    EV::run;
    undef $iow; undef $wd;
    close $ph;

    like($out, qr/^HELLO yes$/m,   'the client is greeted on connect (it learns where the browser already is)');
    like($out, qr/^TITLE Page$/m,  'a blocking call returns the value: say $c->title');
    like($out, qr/^SCRIPT 42$/m,   'script() runs in the browser and the value comes back');
    like($out, qr/^FIND hi$/m,     'find() returns an element proxy, and its text reads');
    like($out, qr/^TAG h1$/m,      '...and its other methods work');
    like($out, qr/^FINDALL 2$/m,   'find_all() returns a proxy per match');
    like($out, qr/^GONE 1$/m,     'wait_for(gone => 1) answers a plain true, not an element proxy');
    # --- the later surface, reachable over the socket at last ---
    # WebKit synthesises a response for a custom-scheme load, and it carries a
    # 200 -- so this pins the value crossing the socket, not just the plumbing
    like($out, qr/^STATUS 200$/m,   'status() is mirrored');
    like($out, qr/^PRESS ok$/m,     'press() is mirrored');
    like($out, qr/^SCROLL hash$/m,  'scroll() is mirrored (both callback spellings reach it, so this cannot say which)');
    like($out, qr/^WAITJS 2$/m,     'wait_for_js() is mirrored and returns the value');
    like($out, qr/^BOX hash$/m,     'Element->box is mirrored');
    like($out, qr/^SIV ok$/m,       'Element->scroll_into_view is mirrored');
    like($out, qr/^HOVER ok$/m,     'Element->hover is mirrored');
    like($out, qr/^SENDKEYS reached$/m,
         'Element->send_keys is mirrored (the dist\'s only glob alias, missing since Control was written)');
    like($out, qr/^ARITY yes$/m,
         'too many arguments to an element method errors rather than hanging the client');
    like($out, qr/^URI cl:\/\/first$/m, 'uri() reflects where the client sent the browser');
    like($out, qr/^CROAK yes right-error$/m,
        'an error croaks in blocking mode, with the browser\'s own error string')
        or diag($out);
    like($out, qr/^STALE yes$/m,
        'a handle from the previous page is stale after navigating (it does not read the wrong node)');
    like($out, qr/^EVENTS [1-9]/m,
        'events that arrived while working are collected, not lost');
    like($out, qr{^REATTACH cl://second$}m,
        'a NEW client attaching later is told where the browser already is (session reuse)')
        or diag($out);
    like($out, qr/^REATTACH_TITLE Second$/m, '...including the title');
}

# ---- EV-native client, in this process ----
{
    my $c = EV::WebKit::Client->connect($path, ev => 1);

    my ($r, $e, $fired) = (undef, undef, 0);
    $c->go('cl://first', sub { ($r, $e) = @_; $fired++; EV::break });
    { my $wd = EV::timer(25, 0, sub { EV::break }); EV::run; undef $wd }
    is($fired, 1, 'ev mode: the callback fires exactly once');
    is($e, undef, '...with no error');

    my $title;
    $c->title(sub { $title = $_[0]; EV::break });
    { my $wd = EV::timer(10, 0, sub { EV::break }); EV::run; undef $wd }
    is($title, 'Page', 'ev mode: a value comes back through the callback');

    # errors are DELIVERED, not croaked -- the same ($result, $err) shape as
    # EV::WebKit itself, so code moves between local and remote unchanged
    my ($er, $ee);
    $c->go(undef, sub { ($er, $ee) = @_; EV::break });
    { my $wd = EV::timer(10, 0, sub { EV::break }); EV::run; undef $wd }
    like($ee // '', qr/uri required/, 'ev mode: an error is delivered to the callback, not croaked');
    is($er, undef, '...with no result');

    # the same plain-true result, through the ev path: here the failure was
    # silent -- _deliver's eval swallowed the die and the callback never ran
    my ($gr, $ge, $gfired) = (undef, undef, 0);
    $c->go('cl://first', sub {
        $c->wait_for('#never-there', gone => 1, sub { ($gr, $ge) = @_; $gfired++; EV::break });
    });
    { my $wd = EV::timer(25, 0, sub { EV::break }); EV::run; undef $wd }
    is($gfired, 1, 'ev mode: wait_for(gone => 1) fires its callback exactly once');
    is($ge, undef, '...with no error');
    ok($gr && !ref $gr, '...and a plain true, not an element proxy')
        or diag('got: ' . (ref($gr) || ($gr // 'undef')));

    # an element proxy in ev mode
    my $el;
    $c->find('h1', sub { $el = $_[0]; EV::break });
    { my $wd = EV::timer(10, 0, sub { EV::break }); EV::run; undef $wd }
    isa_ok($el, 'EV::WebKit::Client::Element', 'ev mode: find gives an element proxy, which');

    # calling without a callback in ev mode croaks: it cannot block, you own the loop
    my $ok = eval { $c->title; 1 };
    ok(!$ok && $@ =~ /callback is required/, 'ev mode: a call with no callback croaks');

    $c->disconnect;
}

$ctl->close;
$b->quit;
# scroll is the only remotely dispatched method with a coderef-valued OPTION,
# and both its documented spellings have to survive the round trip. _cb popped
# any trailing coderef, including the value of `cb =>`, so the orphan key
# travelled alone, the server appended its own `cb =>`, and the method saw an
# odd option list: the named spelling worked locally and croaked remotely with
# "options must be name => value pairs".
{
    my $sb = EV::WebKit->new(window => [300,200], ephemeral => 1, timeout => 10);
    $sb->mock_scheme('scr', sub { ('<html><body style="height:3000px">x</body></html>', 'text/html') });
    my $sp = "$dir/scroll.sock";
    my $sctl = EV::WebKit::Control->listen($sb, path => $sp);
    my $ready = 0;
    $sb->go('scr://a', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(25);
    ok($ready, 'premise: a scrollable page is served');

    my $sc = EV::WebKit::Client->connect($sp, ev => 1);
    for my $case (['cb => ...', 300, sub { my ($cl, $cb) = @_; $cl->scroll(y => 300, cb => $cb) }],
                  ['trailing',  700, sub { my ($cl, $cb) = @_; $cl->scroll(y => 700, $cb) }]) {
        my ($name, $want, $call) = @$case;
        my ($r, $e, $d) = (undef, undef, 0);
        $call->($sc, sub { ($r, $e) = @_; $d = 1; EV::break });
        TWK::run_with_timeout(15);
        ok($d, "scroll($name) over the socket answers") or diag 'no callback';
        is($e, undef, "...without an error") or diag $e;
        # the page really moved, not just a truthy reply
        my ($y, $yd) = (undef, 0);
        $sb->script('return window.scrollY;', sub { $y = $_[0]; $yd = 1; EV::break });
        TWK::run_with_timeout(15);
        is($y, $want, "...and the page actually scrolled to $want");
    }
    $sc->disconnect;
    $sctl->close;
    $sb->quit;
}

done_testing;
