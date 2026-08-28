use v5.10; use strict; use warnings;
use Test::More;
use EV::WebKit::Fingerprint;

is(EV::WebKit::Fingerprint::curl_target('windows-chrome'), 'chrome131',        'windows-chrome -> chrome131');
is(EV::WebKit::Fingerprint::curl_target('macos-safari'),   'safari18_0',       'macos-safari -> safari18_0');
is(EV::WebKit::Fingerprint::curl_target('iphone-safari'),  'safari18_0_ios',   'iphone-safari -> safari18_0_ios');
is(EV::WebKit::Fingerprint::curl_target('pixel-chrome'),   'chrome131_android','pixel-chrome -> chrome131_android');
is(EV::WebKit::Fingerprint::curl_target('nope'), undef, 'unknown profile -> undef');
is(EV::WebKit::Fingerprint::curl_target(undef),  undef, 'undef profile -> undef');

# every preset has a curl target (coherence)
ok(EV::WebKit::Fingerprint::curl_target($_), "preset $_ maps to a target")
    for EV::WebKit::Fingerprint::profiles();

# refreshed versions
my $wc = EV::WebKit::Fingerprint::resolve('windows-chrome');
like($wc->{user_agent}, qr{Chrome/131\.}, 'windows-chrome UA is Chrome 131');
like($wc->{user_agent}, qr{Windows NT}, 'windows-chrome stays Windows');
like($wc->{ua_data}{uaFullVersion}, qr{^131\.}, 'windows-chrome uaFullVersion is 131');
my $ms = EV::WebKit::Fingerprint::resolve('macos-safari');
like($ms->{user_agent}, qr{Version/18\.}, 'macos-safari UA is Safari 18');
my $is = EV::WebKit::Fingerprint::resolve('iphone-safari');
like($is->{user_agent}, qr{Version/18\.}, 'iphone-safari UA is Safari 18');
like($is->{user_agent}, qr{iPhone OS 18}, 'iphone-safari is iOS 18');
my $pc = EV::WebKit::Fingerprint::resolve('pixel-chrome');
like($pc->{user_agent}, qr{Chrome/131\.}, 'pixel-chrome UA is Chrome 131');
like($pc->{ua_data}{uaFullVersion}, qr{^131\.}, 'pixel-chrome uaFullVersion is 131');
like($pc->{user_agent}, qr{Android 10; K\)}, 'pixel-chrome UA is the REDUCED Chrome 131 Android form (Android 10; K)');
unlike($pc->{user_agent}, qr{Pixel 8|Android 14}, 'the raw device/OS version is NOT in the UA string (UA reduction)');
is($pc->{ua_data}{model}, 'Pixel 8', 'the real device rides in ua_data.model -> Sec-CH-UA-Model');

# --- identity headers: UA + Chrome-format Accept-Language (+ low-entropy hints) ---
{
    my $id = EV::WebKit::Fingerprint::identity_headers($wc);
    like($id->{'user-agent'}, qr{Chrome/131}, 'identity_headers carries the UA');
    is($id->{'accept-language'}, 'en-US,en;q=0.9',
       'identity Accept-Language is Chrome format (en-US,en;q=0.9), not libsoup-flavored');
    is($id->{'sec-ch-ua'}, '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
       'sec-ch-ua brand ORDER matches real Chrome 131 (GREASE last), not GREASE-first');
    is($id->{'sec-ch-ua-mobile'}, '?0', 'sec-ch-ua-mobile ?0 for a desktop profile');

    # a Safari profile has no ua_data: UA + Accept-Language, but no sec-ch-ua
    my $sid = EV::WebKit::Fingerprint::identity_headers($ms);
    is($sid->{'accept-language'}, 'en-US,en;q=0.9', 'Safari identity still carries Chrome-format Accept-Language');
    ok(!exists $sid->{'sec-ch-ua'}, 'Safari identity has no sec-ch-ua (no ua_data)');

    # the q-weight sequence for 3+ languages: 0.9, 0.8, ...
    my $three = EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', languages => ['de-DE','de','en'] });
    is(EV::WebKit::Fingerprint::identity_headers($three)->{'accept-language'},
       'de-DE,de;q=0.9,en;q=0.8', 'Accept-Language q-weights decrement (0.9, 0.8) for three languages');
}

# --- high-entropy hints must match what JS getHighEntropyValues() reports, or an
# Accept-CH'ing origin that cross-checks the two channels sees a contradiction ---
{
    my $he = EV::WebKit::Fingerprint::high_entropy_headers($wc);
    is($he->{'sec-ch-ua-wow64'}, '?0',
       'high-entropy carries Sec-CH-UA-WoW64: ?0 (matches JS wow64:false)');
    is($he->{'sec-ch-ua-full-version'}, '"131.0.6778.86"',
       'high-entropy carries the deprecated singular Sec-CH-UA-Full-Version (JS exposes uaFullVersion)');
    is($he->{'sec-ch-ua-full-version-list'},
       '"Google Chrome";v="131.0.6778.86", "Chromium";v="131.0.6778.86", "Not_A Brand";v="24.0.0.0"',
       'Sec-CH-UA-Full-Version-List brand order matches real Chrome 131');
    is($he->{'sec-ch-ua-platform-version'}, '"10.0.0"', 'and Sec-CH-UA-Platform-Version');

    # Safari profiles (no ua_data) expose no client hints on either layer
    is_deeply(EV::WebKit::Fingerprint::high_entropy_headers($ms), {},
       'a Safari profile has no high-entropy hints (no ua_data)');
}
done_testing;
