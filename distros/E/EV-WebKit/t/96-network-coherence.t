use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;
plan skip_all => 'live coherence test; set CI_LIVE=1' unless $ENV{CI_LIVE};
plan skip_all => 'needs Proxy::Impersonate' unless eval { require Proxy::Impersonate; 1 };
plan skip_all => 'needs the fingerprint web-process extension'
    unless EV::WebKit->fingerprint_available;

# Fetch tls.peet.ws/api/all in a browser and return {ua, ja4, ohua} the origin saw.
sub probe {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [1200,800], fingerprint => 'windows-chrome', %opt);
    my ($ua, $body, $err);
    $b->go('https://tls.peet.ws/api/all', sub {
        my (undef, $e) = @_;
        if ($e) { $err = $e; EV::break(); return }
        $b->script('return JSON.stringify({ua: navigator.userAgent, body: document.body.innerText});', sub {
            my ($json, $se) = @_;
            if ($se) { $err = $se }
            else { require JSON::PP; my $d = eval { JSON::PP::decode_json($json) };
                   ($ua, $body) = ($d->{ua}, $d->{body}) if $d }
            EV::break();
        });
    });
    my $t = EV::timer(45, 0, sub { $err //= 'timeout'; EV::break() });
    EV::run;
    $b->quit;
    my ($ja4)    = ($body // '') =~ /"ja4":\s*"([^"]+)"/;
    my ($ohua)   = ($body // '') =~ /"user_agent":\s*"([^"]+)"/;
    my ($akamai) = ($body // '') =~ /"akamai_fingerprint":\s*"([^"]+)"/;
    my ($al)     = ($body // '') =~ /accept-language:\s*([^"\\]+)/;
    my ($uir)    = ($body // '') =~ /upgrade-insecure-requests:\s*(\d)/;
    return { err => $err, ua => $ua, ja4 => $ja4, ohua => $ohua, akamai => $akamai,
             accept_language => $al, uir => $uir };
}

my $CHROME131_JA4 = 't13d1516h2_8daaf6152771_02713d6af862';   # the exact chrome131 JA4

# with network_fingerprint: the origin must see EXACTLY Chrome 131's JA4
my $on = probe(network_fingerprint => 1);
ok(!$on->{err}, 'navigated with network_fingerprint') or diag($on->{err});
like($on->{ua}, qr{Chrome/131}, 'JS navigator.userAgent is Chrome 131');
like($on->{ua}, qr{Windows NT},  'JS navigator.userAgent is Windows');
is($on->{ja4}, $CHROME131_JA4,
   'origin-seen JA4 is EXACTLY chrome131 (not merely t13d-shaped)');
like($on->{ohua}, qr{Windows NT.*Chrome/131}, 'origin-seen User-Agent is Windows Chrome 131');
is($on->{uir}, '1',
   'origin-seen Upgrade-Insecure-Requests is 1 (synthesized for the Chrome navigation)')
    or diag('UIR seen: ' . ($on->{uir} // '(none)'));
# the HTTP/2 layer is coherent too, not only TLS: the origin sees an Akamai
# fingerprint, and the Accept-Language is Chrome's exact format (the identity
# header), not WebKit/libsoup's rendering.
ok($on->{akamai}, 'origin saw an HTTP/2 Akamai fingerprint via network_fingerprint')
    or diag('no akamai_fingerprint in the peet response');
is($on->{accept_language}, 'en-US,en;q=0.9',
   'origin-seen Accept-Language is Chrome format (en-US,en;q=0.9), not libsoup-flavored')
    or diag("accept-language seen: " . ($on->{accept_language} // '(none)'));

# negative control: WITHOUT network_fingerprint the origin sees WebKit's own
# (GnuTLS) JA4 -- proving the proxy is what changed the connection fingerprint,
# not the JS/UA spoof (which is identical in both runs).
my $off = probe();
ok(!$off->{err}, 'navigated without network_fingerprint (direct)') or diag($off->{err});
ok($off->{ja4}, 'direct probe reported a JA4') or diag('no ja4 -- controls below would be vacuous');
like($off->{ua}, qr{Chrome/131}, 'JS UA is still Chrome 131 (JS spoof active either way)');
isnt($off->{ja4}, $CHROME131_JA4,
     "direct WebKit does NOT produce Chrome's JA4 ($off->{ja4})");
isnt($on->{ja4}, $off->{ja4},
     'network_fingerprint changed the origin-seen JA4 vs direct WebKit');
# the HTTP/2 fingerprint changed too (both speak h2 to peet, so both report one)
isnt($on->{akamai}, $off->{akamai},
     'network_fingerprint changed the origin-seen Akamai HTTP/2 fingerprint vs direct WebKit')
    if $on->{akamai} && $off->{akamai};

done_testing;
