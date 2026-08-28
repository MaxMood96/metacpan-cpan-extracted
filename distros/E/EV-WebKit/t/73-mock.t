use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window=>[300,200]);
$b->mock_scheme('mock', sub {
    my ($uri) = @_;
    return ("<html><body>served $uri</body></html>", 'text/html');
});
my $body;
$b->go('mock://hello', sub {
    my (undef,$err)=@_;
    return do { $body="ERR:$err"; EV::break } if $err;
    $b->script('return document.body.textContent', sub { $body=$_[0]; EV::break });
});
TWK::run_with_timeout(10);
like($body // '', qr/served mock:\/\/hello/, 'custom scheme served module data');

# Latin-1-range, utf8-flag-OFF body: "caf\x{e9}" has no CJK, so Perl keeps it
# as a plain byte scalar (utf8::is_utf8 is false for it) -- but it is still
# documented as character data, and mock_scheme must serve it as UTF-8
# regardless of the internal flag state, not as its raw single Latin-1 byte.
my $body2;
$b->mock_scheme('mockl1', sub {
    return ("<html><body>caf\x{e9}</body></html>", 'text/html; charset=utf-8');
});
$b->go('mockl1://x', sub {
    my (undef, $err) = @_;
    return do { $body2 = "ERR:$err"; EV::break } if $err;
    $b->find('body', sub {
        my ($el, $err) = @_;
        return do { $body2 = "ERR:$err"; EV::break } if $err || !$el;
        $el->text(sub { $body2 = $_[0]; EV::break });
    });
});
TWK::run_with_timeout(10);
is($body2, "caf\x{e9}", 'mock_scheme serves a Latin-1-range flag-off body as UTF-8, not mojibake');

# A producer that dies must not crash the whole process. register_uri_scheme's
# callback is invoked directly by WebKit's C code via a GI callback-argument
# (not a glib signal), so nothing upstream wraps it in an eval -- an uncaught
# die here previously unwound straight through WebKit's C stack and out past
# EV::run, killing this entire test process (confirmed: exit 255, never
# reaching this point). Post-fix, the load must fail cleanly instead.
my $crash_err;
$b->mock_scheme('boom', sub { die "producer boom\n" });
$b->go('boom://x', sub {
    my (undef, $err) = @_;
    $crash_err = $err;
    EV::break;
});
TWK::run_with_timeout(10);
ok(1, 'process survived a dying mock_scheme producer (reaching this line at all is the proof)');
ok(defined $crash_err, 'nav callback receives an error, rather than the process just vanishing');

# and the instance keeps working afterward -- the crash-safety fix must not
# leave the browser wedged. (Deliberately a script() check, not another
# go(): the placeholder body the fix finishes boom://x's request with is
# still settling asynchronously at the WebKit-engine level for a beat after
# our synthetic nav-error callback already fired, and starting a brand new
# navigation into that window races WebKit's own cancellation of the
# still-in-flight load -- a separate, pre-existing overlapping-navigation
# subtlety, not something this crash-safety fix needs to also solve.)
my $after;
$b->script('return 6*7', sub { $after = $_[0]; EV::break });
TWK::run_with_timeout(10);
is($after, 42, 'browser instance remains fully functional (JS bridge still responds) after a producer crash was handled safely');

# A self-referencing subresource that throws must NOT fail the navigation whose
# document already loaded. The scheme handler serves every request, and a page
# can legitimately fetch its own uri (a self <img>, or the <img src=""> footgun
# whose empty src resolves to the page's own url). Gating on "uri == the view's
# uri" alone treated that second, same-uri fetch as the document; only the FIRST
# matching request is the document.
{
    my $b = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 8);
    my $n = 0;
    $b->mock_scheme('sr', sub {
        my $uri = shift;
        die "boom on the self-fetch\n" if $n++ && $uri =~ /doc/;   # #1 = document (ok), #2 = self <img> (throws)
        return ('<html><body><h1>Real</h1><img src="sr://doc"></body></html>', 'text/html');
    });
    my ($err, $fired);
    $b->go('sr://doc', sub { ($err, $fired) = ($_[1], 1); EV::break });
    TWK::run_with_timeout(15);
    ok($fired, 'nav with a self-referencing subresource fired its callback');
    is($err, undef, '...and did NOT fail: the throw was a subresource, not the document')
        or diag("nav wrongly failed with: $err");

    # and the page really did load
    my $h1;
    $b->script('return document.querySelector("h1").textContent', sub { $h1 = $_[0]; EV::break });
    TWK::run_with_timeout(15);
    is($h1, 'Real', '...and the document really loaded');
    $b->quit;
}

# ...but a throw on the document ITSELF still fails the navigation -- including
# reload/back/forward, whose target uri is not known ahead of time.
{
    my $b = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 8);
    my $boom = 0;
    $b->mock_scheme('dt', sub { die "producer boom\n" if $boom; ('<html><body>ok</body></html>', 'text/html') });
    $b->go('dt://one', sub { EV::break });
    TWK::run_with_timeout(15);
    $boom = 1;
    my $err;
    $b->reload(sub { $err = $_[1]; EV::break });
    TWK::run_with_timeout(15);
    like($err // '', qr/scheme handler error/,
        'reload() whose document throws still fails the navigation (not a false success)');
    $b->quit;
}

done_testing;
