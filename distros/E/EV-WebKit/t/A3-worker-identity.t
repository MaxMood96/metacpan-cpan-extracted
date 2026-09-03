use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib';
use TWK;
use EV;
use EV::WebKit;
use EV::WebKit::Fingerprint;

# A Worker global scope is a separate JS context, and the web-process extension
# has no hook for one -- window-object-cleared never fires for a worker. So the
# C spoof cannot reach WorkerNavigator, and before this was wrapped a worker
# answered with the REAL platform and core count beside a spoofed page:
# navigator.platform 'Win32' on the page and 'Linux x86_64' in its own worker.
# That contradiction is the whole of what a live bot detector was firing on.
#
# vendor/vendorSub/productSub are checked too: the spec puts NavigatorID on
# WorkerNavigator and both Chrome and Safari expose them there, but WebKitGTK
# does not, so they are supplied by the same wrapper.
plan skip_all => 'web-process extension absent -- the profile spoof needs it'
    unless EV::WebKit::Fingerprint::available();

my $KICK = <<'JS';
window.__w = null; window.__werr = null;
var fields = ['userAgent','platform','hardwareConcurrency','deviceMemory','language',
              'languages','vendor','vendorSub','productSub'];
function vals(nav) {
  var o = {};
  fields.forEach(function (f) {
    var v = nav[f];
    o[f] = (v && v.join) ? v.join(',') : (v === undefined ? '(undef)' : String(v));
  });
  return o;
}
window.__main = vals(navigator);
var src = 'var fields=' + JSON.stringify(fields) + ';' +
  'function vals(nav){var o={};fields.forEach(function(f){var v=nav[f];' +
  'o[f]=(v&&v.join)?v.join(","):(v===undefined?"(undef)":String(v))});return o}' +
  'self.onmessage=function(e){postMessage({vals:vals(navigator),echo:e.data})};';
try {
  var w = new Worker(URL.createObjectURL(new Blob([src], { type: 'text/javascript' })));
  w.onmessage = function (e) { window.__w = e.data };
  w.onerror = function (e) { window.__werr = String(e.message || e) };
  w.postMessage('ping');
} catch (e) { window.__werr = 'throw: ' + String(e) }
return 1;
JS

for my $prof (qw(windows-chrome macos-safari)) {
    my $b = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 20,
                            fingerprint => $prof);
    $b->mock_scheme('wid', sub { ('<html><body><p>w</p></body></html>', 'text/html') });
    my $nav_err;
    $b->go('wid://host/p', sub { $nav_err = $_[1]; EV::break });
    TWK::run_with_timeout(25);
    is($nav_err, undef, "$prof: page loaded") or do { $b->quit; next };

    my $kerr;
    $b->script($KICK, sub { $kerr = $_[1]; EV::break });
    TWK::run_with_timeout(20);
    is($kerr, undef, "$prof: worker started") or do { $b->quit; next };

    # the worker answers on its own turn of the loop
    my ($got, $tries) = (undef, 0);
    while (!$got && $tries++ < 40) {
        $b->script('return { w: window.__w, main: window.__main, err: window.__werr }',
                   sub { $got = $_[0]->{w} ? $_[0] : undef; EV::break });
        TWK::run_with_timeout(10);
        last if $got;
        my $t = EV::timer(0.1, 0, sub { EV::break }); EV::run;
    }
    ok($got, "$prof: the worker replied") or do {
        diag "worker error: " . ($got->{err} // 'none'); $b->quit; next;
    };

    is($got->{w}{echo}, 'ping', "$prof: the wrapped Worker still round-trips a message");

    my ($main, $worker) = ($got->{main}, $got->{w}{vals});
    for my $f (sort keys %$main) {
        is($worker->{$f}, $main->{$f}, "$prof: worker navigator.$f agrees with the page");
    }
    # and the spoof is actually in effect, so the comparison is not vacuous
    like($main->{platform}, qr/^(Win32|MacIntel)$/, "$prof: the page really is spoofed");
    isnt($main->{platform}, 'Linux x86_64', "$prof: ...not the host platform");

    $b->quit;
}

done_testing;
