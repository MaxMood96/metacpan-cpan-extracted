use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib';
use TWK;
use EV;
use EV::WebKit;
use EV::WebKit::Fingerprint;

# The Firefox profile claims Gecko from a WebKit engine, so the navigator
# surface that only Gecko has must be supplied -- and, just as importantly,
# must NOT appear under the other profiles, where a real browser has none of
# it. productSub is the cheap engine check (Gecko 20100101 vs WebKit and
# Chromium 20030107); oscpu and buildID exist in no other engine at all, so
# their absence identifies the engine as surely as a wrong value would.
plan skip_all => 'web-process extension absent -- the profile spoof needs it'
    unless EV::WebKit::Fingerprint::available();

my $JS = <<'JS';
var n = navigator;
return {
  productSub: String(n.productSub),
  oscpu:      typeof n.oscpu      === 'undefined' ? '(absent)' : String(n.oscpu),
  buildID:    typeof n.buildID    === 'undefined' ? '(absent)' : String(n.buildID),
  mozX:       typeof window.mozInnerScreenX,
  vendor:     String(n.vendor),
  uaData:     typeof n.userAgentData,
  chrome:     typeof window.chrome
};
JS

sub probe {
    my ($profile) = @_;
    my $b = EV::WebKit->new(window => [400,300], ephemeral => 1, timeout => 20,
                            fingerprint => $profile);
    $b->mock_scheme('gk', sub { ('<html><body>g</body></html>', 'text/html') });
    my $nav_err;
    $b->go('gk://h/x', sub { $nav_err = $_[1]; EV::break });
    TWK::run_with_timeout(25);
    my ($r, $err);
    $b->script($JS, sub { ($r, $err) = @_; EV::break }) unless $nav_err;
    TWK::run_with_timeout(20) unless $nav_err;
    $b->quit;
    return ($nav_err || $err, $r);
}

{
    my ($e, $r) = probe('windows-firefox');
    is($e, undef, 'windows-firefox: measured') or BAIL_OUT('cannot measure');
    is($r->{productSub}, '20100101',                    'productSub is Gecko\'s, not WebKit\'s 20030107');
    is($r->{oscpu},      'Windows NT 10.0; Win64; x64',  'oscpu is present and matches the UA platform');
    is($r->{buildID},    '20181001000000',               'buildID is present and frozen, as Firefox has been since 64');
    is($r->{mozX},       'number',                       'window.mozInnerScreenX exists');
    is($r->{vendor},     '',                             'navigator.vendor is empty, as Gecko reports it');
    is($r->{uaData},     'undefined',                    'no userAgentData -- client hints are Chromium-only');
    is($r->{chrome},     'undefined',                    'no window.chrome');
}

# The other side of the same coin: these must not leak into a non-Gecko
# profile, where the correct answer is that they do not exist.
for my $p (qw(windows-chrome macos-safari)) {
    my ($e, $r) = probe($p);
  SKIP: {
        skip "$p: could not measure", 3 if $e;
        is($r->{productSub}, '20030107', "$p: productSub is the non-Gecko 20030107");
        is($r->{oscpu},      '(absent)', "$p: no navigator.oscpu");
        is($r->{buildID},    '(absent)', "$p: no navigator.buildID");
    }
}

done_testing;
