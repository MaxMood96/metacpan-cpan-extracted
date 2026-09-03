use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV::WebKit::Fingerprint;

plan skip_all => 'web-process extension not built (no cc/glib at install)'
    unless EV::WebKit::Fingerprint::available();

my $dir = EV::WebKit::Fingerprint::_so_dir();
ok(-e "$dir/evwk_fp.so", "the .so exists in the located dir ($dir)");

# --- resolution + validation (pure Perl, no browser) ---
my @names = EV::WebKit::Fingerprint::profiles();
ok(scalar(@names) >= 4, 'at least four presets');
ok((grep { $_ eq 'windows-chrome' } @names), 'windows-chrome preset present');

my $p = EV::WebKit::Fingerprint::resolve('windows-chrome');
is(ref $p, 'HASH', 'resolve(name) -> hashref');
is($p->{platform}, 'Win32', 'windows-chrome platform');
like($p->{user_agent}, qr/Windows NT/, 'windows-chrome UA looks like Windows');

my $o = EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', deviceMemory => 16, screen => [1920,1080] });
is($o->{deviceMemory}, 16,             'override applied (deviceMemory)');
is_deeply($o->{screen}, [1920,1080],   'override applied (screen)');
is($o->{platform}, 'Win32',            'non-overridden field kept from preset');

eval { EV::WebKit::Fingerprint::resolve('no-such-device') };
like($@, qr/unknown fingerprint profile/, 'unknown preset croaks');
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', bogus => 1 }) };
like($@, qr/unknown fingerprint field/,   'unknown override field croaks');
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', platform => ['x'] }) };
like($@, qr/platform.*must be a string/,  'wrong-typed override croaks');
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', platform => "Win32\0evil" }) };
like($@, qr/platform.*NUL/,               'NUL in a string field croaks (silent-truncation guard)');
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', languages => [] }) };
like($@, qr/languages.*non-empty/,        'empty languages arrayref croaks');
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', languages => ["en\0x"] }) };
like($@, qr/languages.*NUL-free/,         'NUL in a languages entry croaks');

my $gv = EV::WebKit::Fingerprint::gvariant($o);
isa_ok($gv, 'Glib::Variant', 'gvariant() returns a Glib::Variant');
my $printed = $gv->print(1);
like($printed, qr/'platform'/,   'gvariant carries platform');
unlike($printed, qr/user_agent/, 'gvariant does NOT carry user_agent (goes via set_user_agent)');
like($printed, qr/screen_width/, 'gvariant flattens screen to screen_width');

# --- end to end via the real constructor ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome');
    is_deeply($b->fingerprint, EV::WebKit::Fingerprint::resolve('windows-chrome'), '$b->fingerprint returns the resolved profile');
    $b->mock_scheme('fp', sub { ('<html><body>fp</body></html>','text/html') });
    my %g;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $g{r} = $_[0]; EV::break });
          const pd = Object.getOwnPropertyDescriptor(Navigator.prototype, 'platform');
          return JSON.stringify({
            platform:   navigator.platform,
            ua:         navigator.userAgent,
            hasOwn:     navigator.hasOwnProperty('platform'),         // false: on the prototype, like a real browser
            reversible: pd.get.call(navigator),                       // Win32, NOT the real value -> spoof unrecoverable
            enumerable: pd.enumerable,                                // true, matches a real attribute
            native:     pd.get.toString().includes('[native code]'),  // native accessor (defeats toString detection)
            langOK:     navigator.language === navigator.languages[0], // singular consistent with plural
          });
JS
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    is($r->{platform}, 'Win32', 'navigator.platform spoofed via the constructor');
    like($r->{ua}, qr/Windows NT/, 'navigator.userAgent matches the profile (set_user_agent path)');
    ok($r->{native}, 'the platform getter is NATIVE (defeats toString detection)');
    ok(!$r->{hasOwn}, 'platform is NOT an instance own-property (hasOwnProperty false -- prototype-installed, undetectable)');
    is($r->{reversible}, 'Win32', 'the prototype getter returns the spoof -- the REAL value is not recoverable via the descriptor');
    ok($r->{enumerable}, 'the spoofed accessor is enumerable, matching a real WebIDL attribute');
    ok($r->{langOK}, 'navigator.language === navigator.languages[0] (singular/plural consistent)');
    $b->quit;
}

# conflict + availability errors
{
    eval { EV::WebKit->new(window=>[100,80], fingerprint=>'windows-chrome', user_agent=>'x') };
    like($@, qr/fingerprint.*user_agent/, 'fingerprint + user_agent croaks');
    ok(EV::WebKit::fingerprint_available(), 'fingerprint_available() true when built');
    is_deeply([EV::WebKit->fingerprint_profiles], [EV::WebKit::Fingerprint::profiles()], 'fingerprint_profiles lists presets');
}

# --- full core coverage + the sparse rule ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'macos-safari');  # omits deviceMemory
    $b->mock_scheme('fp2', sub { ('<html><body>fp2</body></html>','text/html') });
    my %g;
    my $read = sub {
        my ($key, $js, $next) = @_;
        $b->script($js, sub { $g{$key} = $_[0]; $next->() });
    };
    $b->go('fp2://host/p', sub {
        $read->('vendor', 'return navigator.vendor', sub {
        $read->('langs',  'return JSON.stringify(navigator.languages)', sub {
        $read->('cores',  'return navigator.hardwareConcurrency', sub {
        $read->('touch',  'return navigator.maxTouchPoints', sub {
        $read->('devmem', 'return navigator.deviceMemory === undefined ? "UNDEF" : navigator.deviceMemory', sub {
        $read->('sw',     'return screen.width', sub {
        $read->('dpr',    'return window.devicePixelRatio', sub {
        $read->('lnative','return Object.getOwnPropertyDescriptor(Navigator.prototype,"languages").get.toString()', sub {
            EV::break;
        }); }); }); }); }); }); }); });
    });
    TWK::run_with_timeout(25);
    is($g{vendor}, 'Apple Computer, Inc.',         'navigator.vendor spoofed');
    is($g{langs},  '["en-US","en"]',               'navigator.languages spoofed (array)');
    is($g{cores},  10,                             'navigator.hardwareConcurrency spoofed');
    is($g{touch},  0,                              'navigator.maxTouchPoints spoofed');
    is($g{devmem}, 'UNDEF',                        'deviceMemory absent (sparse rule: macos-safari omits it)');
    is($g{sw},     1512,                           'screen.width spoofed');
    is($g{dpr},    2,                              'window.devicePixelRatio spoofed');
    like($g{lnative}, qr/\[native code\]/,         'the languages getter is native too');
    $b->quit;
}

# --- overrides reach the browser end-to-end. These values differ from BOTH the
# base preset AND real WebKitGTK, so (unlike the macos coincidences above) they
# genuinely discriminate, and they exercise the resolve->gvariant->C-getter path
# for an ADDED field (deviceMemory onto a Safari base). ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => {
        profile => 'macos-safari', vendor => 'Google Inc.', maxTouchPoints => 9, deviceMemory => 16,
    });
    $b->mock_scheme('ov', sub { ('<html><body>ov</body></html>','text/html') });
    my %g;
    $b->go('ov://host/p', sub {
        $b->script('return JSON.stringify({vendor:navigator.vendor, touch:navigator.maxTouchPoints, mem:navigator.deviceMemory})',
            sub { $g{r} = $_[0]; EV::break });
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    is($r->{vendor}, 'Google Inc.', 'override reaches the browser (vendor, discriminating: preset is Apple)');
    is($r->{touch},  9,             'override reaches the browser (maxTouchPoints=9, discriminating)');
    is($r->{mem},    16,            'override ADDS a preset-omitted field: deviceMemory reaches navigator');
    $b->quit;
}

# --- negative control: a browser WITHOUT fingerprint reports the REAL platform.
# Guards against the process-global extension leaking into a non-fp instance. ---
#
# It also samples this HOST's pointer media. A desktop profile deliberately does
# NOT override pointer/hover, so those queries fall through to the engine -- which
# on a touchscreen machine legitimately answers (pointer: coarse). Hardcoding
# "fine matches" would therefore assert a property of the test machine, not of the
# spoof: green here, red there, and either way it never pinned "no flip". The
# desktop assertions below compare against these control values instead.
my ($HOST_FINE, $HOST_COARSE) = (1, 0);   # fallback if the control cannot be read
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('real', sub { ('<html><body>real</body></html>','text/html') });
    my %g;
    $b->go('real://host/p', sub {
        $b->script('return JSON.stringify({platform:navigator.platform, chrome:typeof window.chrome, uaData:typeof navigator.userAgentData, mmNative:window.matchMedia.toString().includes("[native code]"), ptrFine:matchMedia("(pointer: fine)").matches, ptrCoarse:matchMedia("(pointer: coarse)").matches})',
            sub { $g{r} = $_[0]; EV::break });
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    unlike($r->{platform} // '', qr/Win32|MacIntel|iPhone/, "a non-fingerprint browser reports the real platform ($r->{platform}) -- no spoof leakage");
    is($r->{chrome}, 'undefined', 'no window.chrome leaked into a non-fingerprint browser');
    is($r->{uaData}, 'undefined', 'no userAgentData leaked into a non-fingerprint browser');
    ok($r->{mmNative}, 'matchMedia is the real native one (not wrapped) in a non-fingerprint browser');
    ($HOST_FINE, $HOST_COARSE) = ($r->{ptrFine} ? 1 : 0, $r->{ptrCoarse} ? 1 : 0)
        if exists $r->{ptrFine};
    $b->quit;
}

# --- navigator.languages. Real browsers expose it as a FrozenArray, so the SAME
# frozen array comes back on every read; the GStrv marshalling here builds a
# fresh mutable one, and identity/frozenness are a KNOWN, documented gap (see
# the Ceiling POD -- closing it leaked a JSCContext per navigation). The
# identity/frozen assertions below deliberately pin the gap rather than the
# ideal: if a future WebKitGTK or a future fix changes it, this test says so
# instead of silently agreeing. ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => {
        profile => 'windows-chrome', languages => ['en-US','en','x"y\\z'] });
    $b->mock_scheme('lg', sub { ('<html><body>lg</body></html>','text/html') });
    my %g;
    $b->go('lg://host/p', sub {
        $b->script(<<'JS', sub { $g{r} = $_[0]; EV::break });
          const d = Object.getOwnPropertyDescriptor(Navigator.prototype,'languages');
          const v = navigator.languages;
          return JSON.stringify({
            isArray:   Array.isArray(v),
            json:      JSON.stringify(v),
            identical: navigator.languages === navigator.languages,
            frozen:    Object.isFrozen(v),
            lenAfter:  navigator.languages.length,
            native:    !!(d && d.get && d.get.toString().includes('[native code]')),
            language:  navigator.language,
          });
JS
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    ok($r->{isArray},   'navigator.languages is a real Array');
    is($r->{json}, '["en-US","en","x\\"y\\\\z"]',
       'navigator.languages carries the profile tags verbatim, quote/backslash intact');
    is($r->{lenAfter},  3, 'it has the profile length');
    ok($r->{native},    'the languages getter is NATIVE (not a JS wrapper)');
    is($r->{language}, 'en-US', 'navigator.language agrees with languages[0]');
    # the documented gap, pinned so a change surfaces as a test failure
    ok(!$r->{identical}, 'KNOWN GAP: languages !== languages (real browsers cache one FrozenArray)');
    ok(!$r->{frozen},    'KNOWN GAP: the returned array is not frozen (real browsers freeze it)');
    $b->quit;
}

# --- WebGL getParameter: spoof GPU strings (JS wrapper), delegate everything else ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome');
    $b->mock_scheme('fp3', sub { ('<html><body><canvas id=c></canvas></body></html>','text/html') });
    my %g;
    my $js = <<'JS';
      const gl = document.getElementById('c').getContext('webgl');
      if (!gl) return JSON.stringify({ no_gl: true });
      const ext = gl.getExtension('WEBGL_debug_renderer_info');
      return JSON.stringify({
        renderer: gl.getParameter(ext.UNMASKED_RENDERER_WEBGL),
        vendor:   gl.getParameter(ext.UNMASKED_VENDOR_WEBGL),
        real_ver: typeof gl.getParameter(gl.VERSION),           // delegation still works
        ownTS:    Object.prototype.hasOwnProperty.call(gl.getParameter, 'toString'),
        ownKeys:  Object.keys(gl.getParameter).length,
        leaked:   ('__evwk_wv' in window) || ('__evwk_wr' in window),   // temp globals must be gone
      });
JS
    $b->go('fp3://host/p', sub { $b->script($js, sub { $g{r} = $_[0]; EV::break }) });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    SKIP: {
        skip 'no WebGL context in this headless GL environment', 6 if $r->{no_gl};
        like($r->{renderer}, qr/RTX 3060/,   'WebGL UNMASKED_RENDERER spoofed');
        like($r->{vendor},   qr/NVIDIA/,      'WebGL UNMASKED_VENDOR spoofed');
        is($r->{real_ver},   'string',        'a non-spoofed getParameter still delegates (returns the real VERSION string)');
        # The wrapper deliberately carries NO own toString. Masking it defeated
        # only a naive fn.toString() check -- Function.prototype.toString.call
        # bypasses an own property and reveals the wrapper regardless -- while
        # handing over a zero-false-positive enumeration: Object.keys() returned
        # ['toString'] on precisely the wrapped methods and on no real one.
        ok(!$r->{ownTS},                      'getParameter carries no own toString (no enumerable-artifact tell)');
        is($r->{ownKeys}, 0,                  'getParameter has no own enumerable keys, like every real method');
        ok(!$r->{leaked},                     'the temporary __evwk_wv/__evwk_wr globals were deleted (no injection tell)');
    }
    $b->quit;
}

# --- stage 2: Chrome coherence (window.chrome + navigator.userAgentData) ---
{
    my $b = EV::WebKit->new(fingerprint => 'windows-chrome');
    $b->mock_scheme('ch', sub { ('<html><body>ch</body></html>','text/html') });
    my %g;
    $b->go('ch://host/p', sub {
        $b->script(<<'JS', sub { $g{r} = $_[0]; EV::break });
          const u = navigator.userAgentData;
          // request ONLY architecture -- a hints-ignoring impl would also return platformVersion
          return u.getHighEntropyValues(['architecture']).then(h => JSON.stringify({
            chrome:      typeof window.chrome,
            chrome_app:  typeof window.chrome.app,        // real Chrome page has app/csi/loadTimes
            chrome_csi:  typeof window.chrome.csi,
            chrome_load: typeof window.chrome.loadTimes,
            chrome_rt:   ('runtime' in window.chrome),    // must be false (empty runtime is a tell)
            brands:      u.brands.map(b => b.brand).join(','),
            uaPlatform:  u.platform,
            uaMobile:    u.mobile,
            hevArch:     h.architecture,
            hevHasPV:    ('platformVersion' in h),        // NOT requested -> must be absent
            ghevProto:   ('prototype' in u.getHighEntropyValues),  // native-method-like: no .prototype
            desktopPtr:  matchMedia('(pointer: fine)').matches,    // desktop chrome: media unchanged
            desktopPtrC: matchMedia('(pointer: coarse)').matches,  // ... in both directions
          }));
JS
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    is($r->{chrome},     'object',   'window.chrome present for a Chrome profile');
    is($r->{chrome_app}, 'object',   'window.chrome.app present (real-Chrome shape)');
    is($r->{chrome_csi}, 'function', 'window.chrome.csi present');
    is($r->{chrome_load},'function', 'window.chrome.loadTimes present');
    ok(!$r->{chrome_rt},             'window.chrome has no bare runtime:{} (the puppeteer-stealth tell)');
    # Order AND the GREASE entry are curl-impersonate's chrome150 template, not
    # a constant: 131 sent "Not_A Brand";v="24" last, 150 sends
    # "Not;A=Brand";v="8" first.
    is($r->{brands}, 'Not;A=Brand,Chromium,Google Chrome',
       'userAgentData.brands order matches real Chrome 150 (same source as the wire sec-ch-ua)');
    is($r->{uaPlatform}, 'Windows',  'userAgentData.platform matches the profile');
    ok(!$r->{uaMobile},              'userAgentData.mobile false for a desktop profile');
    is($r->{hevArch}, 'x86',         'getHighEntropyValues resolves the requested architecture');
    ok(!$r->{hevHasPV},              'getHighEntropyValues RESPECTS hints (unrequested platformVersion absent)');
    ok(!$r->{ghevProto},             'getHighEntropyValues has no .prototype (native-method-like)');
    is($r->{desktopPtr}  ? 1 : 0, $HOST_FINE,
       'a desktop Chrome profile leaves (pointer: fine) exactly as the engine answers it');
    is($r->{desktopPtrC} ? 1 : 0, $HOST_COARSE,
       'a desktop Chrome profile does NOT flip pointer media to coarse');
    $b->quit;
}

# --- stage 2: mobile coherence (iphone-safari): geometry, touch, media, and
# correctly NO chrome/userAgentData (it is Safari) ---
{
    my $b = EV::WebKit->new(fingerprint => 'iphone-safari');
    $b->mock_scheme('mob', sub { ('<html><body>mob</body></html>','text/html') });
    my %g;
    $b->go('mob://host/p', sub {
        $b->script(<<'JS', sub { $g{r} = $_[0]; EV::break });
          const mq = matchMedia('(pointer: coarse)');
          return JSON.stringify({
            innerLEscreen: window.innerWidth <= screen.width,   // the geometric-impossibility fix
            innerW:    window.innerWidth, screenW: screen.width,
            ontouch:   ('ontouchstart' in window),
            maxTouch:  navigator.maxTouchPoints,
            coarse:    mq.matches,
            coarse_ns: matchMedia('(pointer:coarse)').matches,   // no space -> normalization
            coarse_uc: matchMedia('(POINTER: COARSE)').matches,  // case -> normalization
            fine:      matchMedia('(pointer: fine)').matches,
            hoverNone: matchMedia('(hover: none)').matches,
            dppx3:     matchMedia('(min-resolution: 3dppx)').matches,   // range query, from dpr
            isMQL:     (mq instanceof MediaQueryList),          // real MediaQueryList shape
            ownMatches:mq.hasOwnProperty('matches'),            // matches is on the prototype (own=false)
            orient:    window.orientation,
            delegated: matchMedia('(min-width: 1px)').matches,   // non-overridden query still delegates
            uaData:    typeof navigator.userAgentData,
            chrome:    typeof window.chrome,
          });
JS
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    ok($r->{innerLEscreen}, "mobile geometry coherent: innerWidth ($r->{innerW}) <= screen.width ($r->{screenW})");
    ok($r->{ontouch},    'ontouchstart present on a mobile profile');
    is($r->{maxTouch}, 5, 'maxTouchPoints spoofed');
    ok($r->{coarse},     'pointer:coarse matches on mobile');
    ok(!$r->{fine},      'pointer:fine does not match on mobile');
    ok($r->{hoverNone},  'hover:none matches on mobile');
    ok($r->{dppx3},      'min-resolution:3dppx matches (a RANGE query derived from devicePixelRatio)');
    ok($r->{coarse_ns},  'matchMedia normalizes whitespace ((pointer:coarse) with no space matches)');
    ok($r->{coarse_uc},  'matchMedia normalizes case ((POINTER: COARSE) matches)');
    ok($r->{isMQL},      'the override returns a real MediaQueryList (instanceof)');
    ok(!$r->{ownMatches},'.matches is on the prototype, not an own property (correct shape)');
    is($r->{orient}, 0,  'window.orientation present (0) on a mobile profile');
    ok($r->{delegated},  'a non-overridden matchMedia query still delegates to the real one');
    is($r->{uaData}, 'undefined', 'iphone-safari has NO userAgentData (Safari -- correct)');
    is($r->{chrome}, 'undefined', 'iphone-safari has NO window.chrome (Safari -- correct)');
    $b->quit;
}

# --- stage 2: a non-mobile Retina profile (macos-safari, dpr 2) must make its
# resolution media queries agree with the spoofed devicePixelRatio ---
{
    my $b = EV::WebKit->new(fingerprint => 'macos-safari');
    $b->mock_scheme('ret', sub { ('<html><body>ret</body></html>','text/html') });
    my %g;
    $b->go('ret://host/p', sub {
        $b->script('return JSON.stringify({ dpr:window.devicePixelRatio, minRes:matchMedia("(min-resolution: 2dppx)").matches, exact:matchMedia("(resolution:2dppx)").matches, maxRes1:matchMedia("(max-resolution: 1dppx)").matches, coarse:matchMedia("(pointer: coarse)").matches })',
            sub { $g{r} = $_[0]; EV::break });
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    is($r->{dpr}, 2,      'macos-safari devicePixelRatio 2');
    ok($r->{minRes},      'min-resolution:2dppx matches dpr=2 (resolution coherence on a NON-mobile Retina profile)');
    ok($r->{exact},       'exact resolution:2dppx matches');
    ok(!$r->{maxRes1},    'max-resolution:1dppx does NOT match dpr=2');
    is($r->{coarse} ? 1 : 0, $HOST_COARSE,
       'a desktop Retina profile does not touch pointer media (matches the unspoofed control)');
    $b->quit;
}

# --- stage 2: pixel-chrome is BOTH mobile AND Chrome -- exercise the combination ---
{
    my $b = EV::WebKit->new(fingerprint => 'pixel-chrome');
    $b->mock_scheme('px', sub { ('<html><body>px</body></html>','text/html') });
    my %g;
    $b->go('px://host/p', sub {
        $b->script('return JSON.stringify({ platform:navigator.platform, uaMobile:navigator.userAgentData.mobile, uaPlatform:navigator.userAgentData.platform, chrome:typeof window.chrome, ontouch:("ontouchstart" in window), coarse:matchMedia("(pointer: coarse)").matches, innerLE:window.innerWidth<=screen.width })',
            sub { $g{r} = $_[0]; EV::break });
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    ok($r->{uaMobile},              'pixel-chrome userAgentData.mobile is true (mobile Chrome)');
    is($r->{uaPlatform}, 'Android', 'pixel-chrome userAgentData.platform Android');
    is($r->{chrome}, 'object',      'pixel-chrome has window.chrome (it is Chrome)');
    ok($r->{ontouch},               'pixel-chrome has touch (it is mobile)');
    ok($r->{coarse},                'pixel-chrome pointer:coarse (mobile)');
    ok($r->{innerLE},               'pixel-chrome geometry coherent');
    $b->quit;
}

# --- stage 2: desktop geometry -- a large window is capped to the spoofed screen
# so window.innerWidth never exceeds screen.width (the desktop impossibility) ---
{
    my $b = EV::WebKit->new(window => [3000,2000], fingerprint => 'windows-chrome');  # window > screen (1920x1080)
    $b->mock_scheme('dg', sub { ('<html><body>dg</body></html>','text/html') });
    my %g;
    $b->go('dg://host/p', sub {
        $b->script('return JSON.stringify({ innerLEw:window.innerWidth<=screen.width, innerLEh:window.innerHeight<=screen.height, innerW:window.innerWidth, screenW:screen.width })',
            sub { $g{r} = $_[0]; EV::break });
    });
    TWK::run_with_timeout(20);
    my $r = eval { require Cpanel::JSON::XS; Cpanel::JSON::XS::decode_json($g{r}) } || {};
    ok($r->{innerLEw}, "desktop window capped to screen: innerWidth ($r->{innerW}) <= screen.width ($r->{screenW})");
    ok($r->{innerLEh}, 'desktop window height capped to screen too');
    $b->quit;
}

# every preset loads and reports its own platform natively (coherence smoke).
for my $name (EV::WebKit::Fingerprint::profiles()) {
    my $want = EV::WebKit::Fingerprint::resolve($name)->{platform};
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('sm', sub { ('<html><body>x</body></html>','text/html') });
    my $got;
    $b->go('sm://host/p', sub { $b->script('return navigator.platform', sub { $got = $_[0]; EV::break }) });
    TWK::run_with_timeout(20);
    is($got, $want, "preset '$name' applies its platform ($want)");
    $b->quit;
}

# --- seed plumbing (pure Perl) ---
my $gv_seed = EV::WebKit::Fingerprint::gvariant(
    EV::WebKit::Fingerprint::resolve('windows-chrome'), 12345);
like($gv_seed->print(1), qr/'seed'/, 'gvariant carries seed when given');
my $gv_noseed = EV::WebKit::Fingerprint::gvariant(
    EV::WebKit::Fingerprint::resolve('windows-chrome'));
unlike($gv_noseed->print(1), qr/'seed'/, 'gvariant omits seed when not given');

eval { EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', seed => -1) };
like($@, qr/seed must be a non-negative integer/, 'negative seed croaks');
eval { EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', seed => 'x') };
like($@, qr/seed must be a non-negative integer/, 'non-integer seed croaks');
eval { EV::WebKit->new(window => [200,150], seed => 5) };
like($@, qr/seed requires fingerprint/, 'seed without fingerprint croaks');

# The seed is reduced to 32 bits so the extension's cast to guint32 is defined,
# and the reduction must give the SAME residue on every perl. Done with `%` on
# the whole number it would not: `%` is exact only while the operand fits a UV,
# so a seed above 2**53 -- exactly what a digest-derived seed is, the case the
# reduction exists for -- numifies first on a perl without 64-bit integers and
# lands on a different value than on a 64-bit one. Reducing digit by digit keeps
# every intermediate under 2**36 (worst case 4294967295*10+9), exact in an NV.
# Note honestly what these do and do not cover: on a perl WITH 64-bit integers
# (this one) `%= 2**32` gives the same answers, so no assertion here can tell the
# two implementations apart. They pin the intended values against the real
# function -- not a copy of it -- so a 32-bit tester diverging shows up as a
# failure there rather than as silently different noise.
{
    is(EV::WebKit::_reduce32('9007199254740993'), 1, 'a seed above 2**53 reduces exactly (2**53+1 -> 1)');
    is(EV::WebKit::_reduce32('4294967296'), 0,       '2**32 reduces to 0');
    is(EV::WebKit::_reduce32('4294967297'), 1,       '2**32+1 reduces to 1');
    is(EV::WebKit::_reduce32('12345'), 12345,        'a small seed is unchanged');
    # and the constructor really uses it: a huge seed must be accepted and
    # reduced, not rejected or passed through
    my $big = eval { EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome',
                                     seed => '9007199254740993') };
    is($@, '', 'a >2**53 seed is accepted by the constructor') or diag $@;
    $big->quit if $big;
}

# --- webgl capability data (pure Perl) ---
for my $name (EV::WebKit::Fingerprint::profiles()) {
    my $p = EV::WebKit::Fingerprint::resolve($name);
    is(ref $p->{webgl}, 'HASH', "$name has a webgl block");
    is($p->{webgl}{params1}{3379}, 16384, "$name MAX_TEXTURE_SIZE = 16384");
    is(ref $p->{webgl}{extensions1}, 'ARRAY', "$name has a WebGL1 extension list");
    ok(scalar(@{$p->{webgl}{extensions2}}) > 0, "$name has a WebGL2 extension list");
    ok((grep { $_ eq 'WEBGL_debug_renderer_info' } @{$p->{webgl}{extensions1}}),
       "$name advertises WEBGL_debug_renderer_info");
}
# folded into the coherence JSON
my $coh = EV::WebKit::Fingerprint::gvariant(EV::WebKit::Fingerprint::resolve('windows-chrome'))->print(1);
# NB: match a key unique to the webgl BLOCK. A bare /webgl/ also matches the
# long-standing top-level 'webgl_vendor'/'webgl_renderer' keys, so it stayed
# green even with the whole block removed.
like($coh, qr/params1/,     'coherence JSON carries the webgl params block');
like($coh, qr/extensions1/, 'coherence JSON carries the webgl extension list');
# validator: a non-hash webgl override croaks
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', webgl => [1] }) };
like($@, qr/webgl.*must be a hashref/, 'non-hash webgl override croaks');

# --- feature-presence data (pure Perl) ---
my %want = (
    'windows-chrome' => [qw(connection storage battery usb bluetooth hid serial scheduling rtc)],
    'pixel-chrome'   => [qw(connection storage battery usb bluetooth scheduling rtc)],
    'macos-safari'   => [qw(storage rtc)],
    'iphone-safari'  => [qw(storage rtc)],
);
for my $name (sort keys %want) {
    my $p = EV::WebKit::Fingerprint::resolve($name);
    is_deeply($p->{features}, $want{$name}, "$name has the expected feature list");
}
ok(!grep({ $_ eq 'usb' } @{EV::WebKit::Fingerprint::resolve('macos-safari')->{features}}),
   'Safari does not advertise WebUSB');
ok(!grep({ $_ eq 'serial' } @{EV::WebKit::Fingerprint::resolve('pixel-chrome')->{features}}),
   'Android Chrome does not advertise Web Serial');
my $cj = EV::WebKit::Fingerprint::gvariant(EV::WebKit::Fingerprint::resolve('windows-chrome'))->print(1);
like($cj, qr/features/, 'coherence JSON carries the features list');
eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', features => 'x' }) };
like($@, qr/features.*arrayref/, 'non-arrayref features override croaks');

eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', features => ['webusb'] }) };
like($@, qr/unknown features group/, 'a mistyped features group croaks (never a silent no-op stub)');

# --- screen.orientation.type follows the spoofed SCREEN, not the mobile flag.
# Keyed off `mobile` it contradicted the profile's own screen.width/height on any
# portrait desktop or landscape tablet -- a two-property probe. ---
for my $case (
    [ 'a landscape screen'          => [1920,1080], 0, 'landscape-primary' ],
    [ 'a portrait screen'           => [1080,1920], 0, 'portrait-primary'  ],
    [ 'a portrait MOBILE screen'    => [ 390, 844], 1, 'portrait-primary'  ],
    # the case the old mobile-keyed rule got backwards in both directions
    [ 'a LANDSCAPE mobile screen'   => [ 844, 390], 1, 'landscape-primary' ],
    [ 'a PORTRAIT desktop screen'   => [1200,1600], 0, 'portrait-primary'  ],
    [ 'a square screen'             => [1000,1000], 0, 'landscape-primary' ],
) {
    my ($what, $screen, $mobile, $want) = @$case;
    my $p = EV::WebKit::Fingerprint::resolve({
        profile => $mobile ? 'iphone-safari' : 'windows-chrome', screen => $screen });
    my $c = EV::WebKit::Fingerprint::_coherence($p);
    is($c->{orientation}{type}, $want, "$what ($screen->[0]x$screen->[1]) reports $want");
}

# --- an EMPTY profile must produce NO coherence blob at all -----------------
# The extension is loaded for every browser, and new() promises it then "defines
# nothing, leaving a plain instance exactly as it was". Every native-getter
# field is gated individually, but the orientation entry deliberately does not
# key off `mobile` -- so an empty profile still emitted a blob, and the
# extension gates both COHERENCE_JS and the WebGL getParameter wrapper on that
# blob merely existing. Measured against the extension forced off, a default
# browser gained window.ScreenOrientation and lost getParameter's [native code].
#
# Asserted here rather than in the browser because it is engine-independent: a
# future WebKitGTK that ships ScreenOrientation natively would make the DOM-side
# absence check stale, but this stays exact.
is(EV::WebKit::Fingerprint::_coherence({}), undef,
   'an empty profile produces no coherence blob');
is(EV::WebKit::Fingerprint::_coherence(undef), undef,
   '...and neither does no profile at all');
{
    my $v = EV::WebKit::Fingerprint::gvariant(undef, undef, { boot => Glib::Variant->new('s', 'x') });
    my %keys;
    for my $i (0 .. $v->n_children - 1) {
        my $pair = $v->get_child_value($i);
        $keys{ $pair->get_child_value(0)->get_string } = 1;
    }
    ok(!$keys{coherence}, 'a plain instance carries no coherence key into the extension');
    ok($keys{boot}, '...while the caller-supplied entries still get through');
}

# --- round-3: pin the capability-table invariants in pure Perl ---
# The live t/A1 checks compare browser output against the same %PRESET data, and
# the real driver satisfies the ES3 identities too, so they pass even with the
# spoof removed. These assert the DATA directly.
for my $name (EV::WebKit::Fingerprint::profiles()) {
    my $w = EV::WebKit::Fingerprint::resolve($name)->{webgl};
    my ($p1, $p2) = ($w->{params1}, $w->{params2});
    is($p2->{35658}, $p1->{36347}*4, "$name MAX_VERTEX_UNIFORM_COMPONENTS == VECTORS*4");
    is($p2->{35657}, $p1->{36349}*4, "$name MAX_FRAGMENT_UNIFORM_COMPONENTS == VECTORS*4");
    is($p2->{35659}, $p1->{36348}*4, "$name MAX_VARYING_COMPONENTS == VARYING_VECTORS*4");
    cmp_ok($p2->{35374}, '>=', $p2->{35371} + $p2->{35373},
           "$name combined uniform blocks >= vertex+fragment");
    cmp_ok($p2->{35375}, '>=', $p2->{35374}, "$name uniform buffer bindings >= combined blocks");
    cmp_ok($p1->{35661}, '>=', $p1->{35660} + $p1->{34930},
           "$name combined texture image units >= vertex+fragment");
    cmp_ok($p2->{37157}, '>=', $p2->{35659}, "$name fragment input components >= varying components");
    # every shader/precision combination must be present or it falls through to the host
    is(scalar(keys %{$w->{precision}}), 12, "$name precision table covers all 12 combinations");
    # An fp16 mediump/lowp float pairs with a 16-bit int range; fp32 pairs with
    # 32-bit. Mixing them is a contradiction, and reverting either half of that
    # sweep previously left the suite green.
    my $f = $w->{precision}{'FRAGMENT.MEDIUM_FLOAT'};
    my $i = $w->{precision}{'FRAGMENT.MEDIUM_INT'};
    if ($f->[2] == 10) { is_deeply($i, [15,14,0], "$name fp16 mediump pairs with a 16-bit int range") }
    else               { is_deeply($i, [31,30,0], "$name fp32 mediump pairs with a 32-bit int range") }
    is_deeply($w->{precision}{'FRAGMENT.HIGH_INT'}, [31,30,0], "$name highp int is always 32-bit");
    # Compressed-texture and debug extensions are hardware/browser properties and
    # cannot appear at one API level only.
    my %e1 = map { $_ => 1 } @{$w->{extensions1}};
    my %e2 = map { $_ => 1 } @{$w->{extensions2}};
    for my $ext (qw(WEBGL_debug_shaders WEBGL_multi_draw WEBGL_compressed_texture_pvrtc
                    WEBGL_compressed_texture_astc WEBGL_compressed_texture_etc)) {
        next unless $e1{$ext} || $e2{$ext};
        ok($e1{$ext} && $e2{$ext}, "$name advertises $ext at both API levels or neither");
    }
}

# --- round-3: the webgl validator (added in round 2, previously untested) ---
{
    my $base = EV::WebKit::Fingerprint::resolve('windows-chrome')->{webgl};
    eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', webgl => { %$base, bogus => 1 } }) };
    like($@, qr/unknown webgl key/, 'an unknown webgl key croaks');
    my %missing = %$base; delete $missing{precision};
    eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', webgl => \%missing }) };
    like($@, qr/webgl\.precision is required/, 'a missing webgl sub-key croaks');
    eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', webgl => { %$base, params1 => 'x' } }) };
    like($@, qr/webgl\.params1 must be a hashref/, 'a wrong-typed webgl sub-key croaks');
    eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', webgl => {} }) };
    like($@, qr/webgl\./, 'an empty webgl block croaks rather than silently disabling the spoof');
}

# --- round-3: resolve() must hand back a private deep copy ---
{
    my $a = EV::WebKit::Fingerprint::resolve('macos-safari');
    $a->{webgl}{params1}{3379} = 4096;
    $a->{languages}[0] = 'zz-ZZ';
    my $b = EV::WebKit::Fingerprint::resolve('iphone-safari');   # shares the same tables
    is($b->{webgl}{params1}{3379}, 16384, 'editing one resolved profile does not re-fingerprint its sibling');
    my $c = EV::WebKit::Fingerprint::resolve('macos-safari');
    is($c->{languages}[0], 'en-US', 'nested arrayrefs are copied too, not shared');
    # NESTED under a KNOWN key: `webgl => $cyc` croaks at the unknown-webgl-key
    # check, which runs before _clone -- so it never reached the depth guard at
    # all, and deleting that guard left this green.
    # The cycle has to be reachable by _clone: a bare `webgl => $cyc` croaks at
    # the unknown-webgl-key check and `{ params1 => $cyc }` at the required-key
    # check, both of which run first -- so neither ever reached the depth guard,
    # and deleting that guard left this green.
    my $cyc = {}; $cyc->{self} = $cyc;
    my $base = EV::WebKit::Fingerprint::resolve('windows-chrome')->{webgl};
    eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome',
                                             webgl => { %$base, params1 => $cyc } }) };
    like($@, qr/nested too deeply/, 'cyclic override data croaks instead of exhausting the stack');
}

# Both of these are documented: fingerprint may be a hashref with a `profile`
# base, and network_fingerprint => 1 derives the curl target from the profile.
# Together they croaked, because the raw hashref was handed to curl_target and
# looked up its stringified address.
SKIP: {
    skip 'Proxy::Impersonate not installed', 3
        unless eval { require Proxy::Impersonate; 1 };
    my $h = eval {
        EV::WebKit->new(window => [100,80], ephemeral => 1, timeout => 5,
                        fingerprint => { profile => 'windows-chrome', hardwareConcurrency => 4 },
                        network_fingerprint => 1);
    };
    ok($h, 'a hashref profile plus network_fingerprint => 1 constructs') or diag $@;
    is($h && $h->network_fingerprint, 'chrome150',
       '...deriving the curl target from the profile inside the hashref');
    $h->quit if $h;

    my $s = eval {
        EV::WebKit->new(window => [100,80], ephemeral => 1, timeout => 5,
                        fingerprint => 'windows-chrome', network_fingerprint => 1);
    };
    is($s && $s->network_fingerprint, 'chrome150', '...same target as the string form');
    $s->quit if $s;

    # on_request ALONE takes the same derivation, and this branch is the
    # dangerous one: it does not croak on a miss, it falls back to desktop
    # Chrome. So a hashref profile used to present a Safari (or Android Chrome)
    # identity in JS and headers over a Chrome JA3/JA4 -- silently, and
    # network_fingerprint() reported 'chrome131' as if that were the default.
    for my $case (['macos-safari', 'safari26_0'], ['pixel-chrome', 'chrome131_android']) {
        my ($preset, $want) = @$case;
        my %made;
        for my $form (['string',  $preset],
                      ['hashref', { profile => $preset }]) {
            my ($name, $fp) = @$form;
            my $r = eval {
                EV::WebKit->new(window => [100,80], ephemeral => 1, timeout => 5,
                                fingerprint => $fp, on_request => sub { undef });
            };
            ok($r, "on_request alone with a $name $preset fingerprint constructs") or diag $@;
            $made{$name} = $r && $r->network_fingerprint;
            $r->quit if $r;
        }
        is($made{hashref}, $want,
           "on_request alone: a hashref $preset derives $want, not a silent chrome150");
        is($made{hashref}, $made{string}, '...the same target the string form gets');
    }
}

done_testing;
