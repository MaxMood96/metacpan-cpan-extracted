use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib';
use TWK;
use EV;
use EV::WebKit;
use EV::WebKit::Fingerprint;

# A live audit of what the fingerprint profiles actually present, against third
# party detectors. Network, slow, and dependent on sites that change under it,
# so it never runs by default and it asserts only what is ours to keep true:
# the three layers agreeing with each other, and the worker agreeing with its
# page. Everything a detector says about us is reported with diag, because a
# verdict is evidence, not a contract.
#
#   EVWK_AUDIT=1 xvfb-run -a prove -b xt/fingerprint-audit.t
plan skip_all => 'live fingerprint audit; set EVWK_AUDIT=1 to run'
    unless $ENV{EVWK_AUDIT};
plan skip_all => 'web-process extension absent -- profiles need it'
    unless EV::WebKit::Fingerprint::available();
eval { require JSON::PP; 1 } or plan skip_all => 'JSON::PP required';

# TLS and HTTP/2 impersonation is a separate opt-in with its own prerequisites.
my $net = eval { require Proxy::Impersonate; require Curl::Impersonate; 1 } ? 1 : 0;
diag 'Proxy::Impersonate/Curl::Impersonate absent -- auditing the JS layer only'
    unless $net;

sub visit {
    my ($b, $url, $settle, $js) = @_;
    my ($nav_err, $out, $err);
    $b->go($url, sub { $nav_err = $_[1]; EV::break });
    TWK::run_with_timeout(60);
    return (undef, "navigation: $nav_err") if $nav_err;
    my $t = EV::timer($settle, 0, sub { EV::break }); EV::run;
    $b->script($js, sub { ($out, $err) = @_; EV::break });
    TWK::run_with_timeout(45);
    return (undef, "script: $err") if $err;
    return ($out, undef);
}

my %EXPECT = (
    'windows-chrome'  => { platform => 'Win32',        family => 'chrome'  },
    'macos-safari'    => { platform => 'MacIntel',     family => 'safari'  },
    'iphone-safari'   => { platform => 'iPhone',       family => 'safari'  },
    'pixel-chrome'    => { platform => 'Linux armv8l', family => 'chrome'  },
    'windows-firefox' => { platform => 'Win32',        family => 'firefox' },
);
# The families differ in the SETTINGS frame they open with, which is the
# cheapest stable way to tell the H2 fingerprints apart without pinning a whole
# string that upstream curl-impersonate may re-tune. Chrome and Firefox both
# start at 1:65536, so Firefox is told apart by its INITIAL_WINDOW_SIZE.
my %H2_HEAD = (chrome  => qr/^1:65536;2:0;4:6291456/,
               safari  => qr/^2:0/,
               firefox => qr/^1:65536;2:0;4:131072/);

for my $prof (sort keys %EXPECT) {
    my $b = eval {
        EV::WebKit->new(window => [1280,800], ephemeral => 1, timeout => 45,
                        fingerprint => $prof, ($net ? (network_fingerprint => 1) : ()));
    };
    ok($b, "$prof: browser created") or next;

    my ($js, $e1) = visit($b, 'https://example.com/', 1, <<'JS');
var n = navigator;
return { platform: n.platform, ua: n.userAgent, hw: n.hardwareConcurrency,
         langs: (n.languages||[]).join(','), vendor: n.vendor,
         uaData: n.userAgentData ? n.userAgentData.platform : null };
JS
    if ($e1) { diag "$prof: $e1"; $b->quit; next }
    is($js->{platform}, $EXPECT{$prof}{platform}, "$prof: navigator.platform is the profile's");
    diag "$prof: ua = $js->{ua}";

    if ($net) {
        my ($tls, $e2) = visit($b, 'https://tls.peet.ws/api/all', 1,
            'try { return JSON.parse(document.body.innerText) } catch (e) { return null }');
      SKIP: {
            skip "$prof: tls.peet.ws unreachable", 2 if $e2 || !$tls;
            my $ja4 = $tls->{tls}{ja4} // '';
            my $ak  = $tls->{http2}{akamai_fingerprint} // '';
            diag "$prof: ja4 = $ja4";
            diag "$prof: akamai = $ak";
            like($ak, $H2_HEAD{ $EXPECT{$prof}{family} },
                 "$prof: the HTTP/2 settings are the $EXPECT{$prof}{family} family's");
            is($tls->{user_agent}, $js->{ua},
               "$prof: the User-Agent the origin saw is the one the page reports");
        }
    }

    # Whatever a detector concludes, page and worker must not contradict each
    # other -- that contradiction is the one thing here that is purely our bug.
    my ($w, $e3) = visit($b, 'https://example.com/', 1, <<'JS');
window.__w = null;
var f = ['userAgent','platform','hardwareConcurrency','languages','vendor'];
function v(n){var o={};f.forEach(function(k){var x=n[k];o[k]=(x&&x.join)?x.join(','):String(x)});return o}
var src='var f='+JSON.stringify(f)+';function v(n){var o={};f.forEach(function(k){var x=n[k];'+
  'o[k]=(x&&x.join)?x.join(","):String(x)});return o}self.onmessage=function(){postMessage(v(navigator))};';
try { var w=new Worker(URL.createObjectURL(new Blob([src],{type:'text/javascript'})));
      w.onmessage=function(e){window.__w=e.data}; w.postMessage(1) } catch (e) {}
return v(navigator);
JS
    if ($e3) { diag "$prof: $e3"; $b->quit; next }
    my ($wv, $tries) = (undef, 0);
    while (!$wv && $tries++ < 40) {
        $b->script('return window.__w', sub { $wv = $_[0]; EV::break });
        TWK::run_with_timeout(10);
        last if $wv;
        my $t = EV::timer(0.1, 0, sub { EV::break }); EV::run;
    }
  SKIP: {
        skip "$prof: worker never answered", 1 unless $wv;
        my @bad = grep { ($wv->{$_} // '') ne ($w->{$_} // '') } sort keys %$w;
        is_deeply(\@bad, [], "$prof: the worker agrees with its page")
            or diag join "\n", map { "  $_: page=$w->{$_} worker=" . ($wv->{$_} // '(undef)') } @bad;
    }

    # Reported, never asserted: these are other people's verdicts.
    my ($bot) = visit($b, 'https://deviceandbrowserinfo.com/are_you_a_bot', 10, <<'JS');
var pre = document.querySelector('pre, code, textarea');
var raw = pre ? (pre.innerText || pre.value || '') : '';
var body = (document.body.innerText || '').replace(/\s+/g, ' ');
var i = body.indexOf('You are');
return { verdict: i >= 0 ? body.slice(i, i + 30) : '(none)', raw: raw.replace(/\s+/g,' ').slice(0, 1500) };
JS
    if ($bot) {
        my %f; $f{$1} = $2 while ($bot->{raw} // '') =~ /"(\w+)"\s*:\s*(true|false)/g;
        my @true = grep { $f{$_} eq 'true' && $_ ne 'isBot' } sort keys %f;
        diag "$prof: deviceandbrowserinfo -> $bot->{verdict}"
           . (@true ? " [" . join(', ', @true) . "]" : '');
    }

    my ($sanny) = visit($b, 'https://bot.sannysoft.com/', 8, <<'JS');
var out = {}, n = 0;
document.querySelectorAll('table tr').forEach(function (tr) {
  var td = tr.querySelectorAll('td'); if (td.length < 2) return; n++;
  var k = (td[0].innerText||'').trim();
  if (k && /fail/i.test(td[1].className||'')) out[k] = (td[1].innerText||'').trim().slice(0,40);
});
return { fails: out, rows: n };
JS
    if ($sanny) {
        # 0 rows means the page did not render -- historically a response the
        # browser could not decode, which is worth shouting about either way.
        diag "$prof: bot.sannysoft.com rendered NO rows (page broken?)" unless $sanny->{rows};
        diag "$prof: sannysoft rows=$sanny->{rows} fails: "
           . (join('; ', map { "$_=$sanny->{fails}{$_}" } sort keys %{ $sanny->{fails} }) || 'none');
    }

    $b->quit;
}

done_testing;
