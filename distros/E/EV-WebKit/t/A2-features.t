use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use EV::WebKit::Fingerprint;
plan skip_all => 'web-process extension not built' unless EV::WebKit::Fingerprint::available();

# NB: body uses `return await` (script wraps it in an async IIFE + JSON.stringify).
sub feat {
    my ($name) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = {
            connection: 'connection' in navigator,
            usb: 'usb' in navigator, bluetooth: 'bluetooth' in navigator,
            hid: 'hid' in navigator, serial: 'serial' in navigator,
            battery: typeof navigator.getBattery === 'function',
            scheduling: 'scheduling' in navigator,
            rtc: 'RTCPeerConnection' in window,
            storage: !!(navigator.storage && navigator.storage.estimate),
            effType: navigator.connection ? navigator.connection.effectiveType : null,
            cfgGone: !('__evwk_cfg' in window),   // the config blob must leave no window tell
            estimateOk: false, batteryLevel: null,
          };
          try {
            if (navigator.storage && navigator.storage.estimate) {
              const est = await navigator.storage.estimate();
              res.estimateOk = est && typeof est.quota === 'number';
            }
            if (typeof navigator.getBattery === 'function') {
              const bat = await navigator.getBattery();
              res.batteryLevel = bat ? bat.level : null;
            }
          } catch (e) {}
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}

# --- regressions from the round-1 adversarial review ---
sub shape {
    my ($name) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res={ran:1};
          const n=navigator;
          // each device API must expose its OWN method set, not a merged union
          res.serialHasGetPorts   = !!(n.serial && 'getPorts' in n.serial);
          res.serialHasGetDevices = !!(n.serial && 'getDevices' in n.serial);
          res.usbHasRequestPort   = !!(n.usb && 'requestPort' in n.usb);
          res.usbHasRequestDevice = !!(n.usb && 'requestDevice' in n.usb);
          res.btHasAvailability   = !!(n.bluetooth && 'getAvailability' in n.bluetooth);
          res.storageHasGetDir    = !!(n.storage && 'getDirectory' in n.storage);
          // the interface objects must exist alongside their navigator members
          res.ifaces={}; ['NetworkInformation','USB','HID','Serial','Bluetooth','StorageManager',
                         'BatteryManager','RTCPeerConnection','RTCDataChannel'].forEach(function(k){
            res.ifaces[k] = (k in window); });
          // instances must look like WebIDL objects, not plain literals
          if(n.connection){
            res.connTag = Object.prototype.toString.call(n.connection);
            res.connOwnKeys = Object.keys(n.connection).length;      // real: 0 (all on the prototype)
            res.connIsET = n.connection instanceof EventTarget;
            res.connSame = n.connection === n.connection;            // same object every access
          }
          // RTCPeerConnection must require `new` and not pollute window
          try { RTCPeerConnection(); res.rtcNoNewThrew=false; }
          catch(e){ res.rtcNoNewThrew = (e instanceof TypeError); }
          res.windowPolluted = ('iceGatheringState' in window) || ('signalingState' in window);
          // getBattery must resolve the SAME BatteryManager each call
          if(typeof n.getBattery==='function'){
            const b1=await n.getBattery(), b2=await n.getBattery();
            res.batterySame = (b1===b2);
            res.batteryTag = Object.prototype.toString.call(b1);
          }
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
{
    my $s = shape('windows-chrome');
    ok($s->{ran}, 'shape probe ran') or diag('probe returned nothing');
    ok($s->{serialHasGetPorts},    'navigator.serial has getPorts (its real primary method)');
    ok(!$s->{serialHasGetDevices}, 'navigator.serial does NOT have getDevices (that is WebUSB/WebHID)');
    ok(!$s->{usbHasRequestPort},   'navigator.usb does NOT have requestPort (WebUSB has no such method)');
    ok($s->{usbHasRequestDevice},  'navigator.usb has requestDevice');
    ok($s->{btHasAvailability},    'navigator.bluetooth has getAvailability');
    ok($s->{storageHasGetDir},     'navigator.storage has getDirectory');
    is($s->{ifaces}{$_}, 1, "window.$_ interface object exists")
        for qw(NetworkInformation USB HID Serial Bluetooth StorageManager BatteryManager RTCPeerConnection);
    is($s->{connTag}, '[object NetworkInformation]', 'connection reports its interface name via toStringTag');
    is($s->{connOwnKeys}, 0, 'connection has no own enumerable keys (attributes live on the prototype)');
    ok($s->{connIsET}, 'connection is a real EventTarget');
    ok($s->{connSame}, 'connection returns the same object on every access');
    ok($s->{rtcNoNewThrew}, 'RTCPeerConnection() without new throws TypeError, as the real one does');
    ok(!$s->{windowPolluted}, 'calling RTCPeerConnection() does not leak state onto window');
    ok($s->{batterySame}, 'getBattery() resolves the same BatteryManager each call');
    is($s->{batteryTag}, '[object BatteryManager]', 'battery object reports its interface name');
}

my $c = feat('windows-chrome');
ok($c->{connection}, 'Chrome: navigator.connection present');
ok($c->{usb} && $c->{bluetooth} && $c->{hid} && $c->{serial}, 'Chrome desktop: usb/bluetooth/hid/serial present');
ok($c->{battery}, 'Chrome: navigator.getBattery present');
ok($c->{scheduling} && $c->{rtc} && $c->{storage}, 'Chrome: scheduling/rtc/storage present');
is($c->{effType}, '4g', 'connection.effectiveType is functional');
ok($c->{estimateOk}, 'storage.estimate() resolves a StorageEstimate');
is($c->{batteryLevel}, 1, 'getBattery() resolves a BatteryManager');
ok($c->{cfgGone}, '__evwk_cfg is deleted after injection (no window tell)');

my $s = feat('macos-safari');
# guard: feat() yields {} on any failure, which would make every absence
# assertion below pass vacuously.
ok(exists $s->{connection}, 'macos-safari probe ran (absence assertions are meaningful)');
ok(!$s->{connection}, 'Safari: no navigator.connection');
ok(!$s->{usb} && !$s->{bluetooth} && !$s->{battery}, 'Safari: no usb/bluetooth/battery');
ok(!$s->{scheduling}, 'Safari: no navigator.scheduling');
ok($s->{rtc} && $s->{storage}, 'Safari: rtc + storage present');

my $px = feat('pixel-chrome');
ok(exists $px->{hid}, 'pixel-chrome probe ran (absence assertions are meaningful)');
ok($px->{usb} && $px->{bluetooth}, 'Android Chrome: usb + bluetooth present');
ok(!$px->{hid} && !$px->{serial}, 'Android Chrome: no hid/serial (desktop-only)');
ok($px->{connection} && $px->{battery}, 'Android Chrome: connection + battery present');

# --- regressions from the round-2 adversarial review ---
sub coh {
    my ($name) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res={ran:1};
          const u=navigator.userAgentData;
          res.hasUAD=!!u;
          if(u){
            res.uadTag=Object.prototype.toString.call(u);
            res.uadOwnKeys=Object.keys(u).length;          // real: 0, all on the prototype
            res.uadIfaceGlobal=('NavigatorUAData' in window);
            res.uadNoProto=(typeof u.getHighEntropyValues==='function' &&
                            u.getHighEntropyValues.prototype===undefined);
            res.uadBrands=Array.isArray(u.brands);
            res.uadFrozen=Object.isFrozen(u.brands);
            // a promise-returning operation must REJECT, never throw synchronously
            try { const p=u.getHighEntropyValues();
                  res.hevSyncThrew=false;
                  res.hevRejected=await p.then(()=>false,()=>true); }
            catch(e){ res.hevSyncThrew=true; res.hevRejected=false; }
          }
          // screen.orientation.type must match the profile's orientation
          res.orientType = (screen.orientation && screen.orientation.type) || null;
          // RTCPeerConnection members must be enumerable like real WebIDL
          if('RTCPeerConnection' in window){
            const d=Object.getOwnPropertyDescriptor(RTCPeerConnection.prototype,'createOffer');
            res.rtcEnumerable = !!(d && d.enumerable);
          }
          // matchMedia: method identity, brand check, compound + unit-alias queries
          const m=window.matchMedia('(pointer: coarse)');
          res.mqlIdentity = (m.addEventListener === m.addEventListener);
          try { const g=Object.getOwnPropertyDescriptor(MediaQueryList.prototype,'matches').get;
                res.mqlBrand = (typeof g.call(m) === 'boolean'); }
          catch(e){ res.mqlBrand=false; }
          res.mqlOwnMatches = Object.prototype.hasOwnProperty.call(m,'matches');
          res.mqSimple   = window.matchMedia('(pointer: coarse)').matches;
          res.mqCompound = window.matchMedia('(pointer: coarse) and (min-width: 1px)').matches;
          res.mqList     = window.matchMedia('(hover: none), (pointer: coarse)').matches;
          res.mqAliasX   = window.matchMedia('(min-resolution: 2x)').matches;
          res.mqRange    = window.matchMedia('(resolution >= 2dppx)').matches;
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
{
    my $r = coh('windows-chrome');
    ok($r->{ran}, 'coherence probe ran') or diag('probe returned nothing');
    SKIP: { skip 'no userAgentData', 8 unless $r->{hasUAD};
        is($r->{uadTag}, '[object NavigatorUAData]', 'userAgentData reports its real interface name');
        is($r->{uadOwnKeys}, 0, 'userAgentData has no own enumerable keys (attributes on the prototype)');
        ok($r->{uadIfaceGlobal}, 'window.NavigatorUAData interface object exists');
        ok($r->{uadNoProto}, 'getHighEntropyValues has no .prototype (native-method-like)');
        ok($r->{uadBrands}, 'userAgentData.brands is still a real array');
        ok($r->{uadFrozen}, 'userAgentData.brands is frozen, as real Chrome returns it');
        ok(!$r->{hevSyncThrew},
           'getHighEntropyValues() with no argument does not throw synchronously');
        ok($r->{hevRejected},
           'getHighEntropyValues() with no argument returns a rejected promise');
    }
    # windows-chrome is a desktop profile: landscape-primary, never the mobile value
    is($r->{orientType}, 'landscape-primary',
       'desktop screen.orientation.type comes from the profile');
    ok($r->{rtcEnumerable}, 'RTCPeerConnection members are enumerable, like real WebIDL and the sibling stubs');
}
{
    my $r = coh('pixel-chrome');   # mobile: pointer coarse, hover none, dppx 2.625
    ok($r->{mqlIdentity}, 'MediaQueryList method identity is stable (no per-access Proxy binding)');
    ok($r->{mqlBrand}, 'MediaQueryList passes the platform-object brand check');
    ok(!$r->{mqlOwnMatches}, 'matches stays a prototype accessor, not an own property');
    ok($r->{mqSimple},   'mobile: (pointer: coarse) matches');
    ok($r->{mqCompound}, 'compound query with an unspoofed clause still matches');
    ok($r->{mqList},     'comma-separated query list matches');
    ok($r->{mqAliasX},   'the x unit alias for dppx is handled');
    ok($r->{mqRange},    'range syntax (resolution >= 2dppx) is handled');
}

# --- round-3: matchMedia must stay live and handle real-world query forms ---
{
    my $b = EV::WebKit->new(window => [400,300], fingerprint => 'pixel-chrome');
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res={ran:1}, mm=(q)=>window.matchMedia(q).matches;
          res.simple   = mm('(pointer: coarse)');
          // a media type must not abandon the spoof: X and 'screen and X' must agree
          res.screenAnd = mm('screen and (pointer: coarse)');
          res.allAnd    = mm('all and (pointer: coarse)');
          // 'and' also occurs INSIDE real values (landscape, standard, standalone)
          res.dynRange  = mm('(dynamic-range: standard)');
          res.withValueAnd = mm('(pointer: coarse) and (dynamic-range: standard)');
          res.landscape = mm('(orientation: landscape), (pointer: coarse)');
          // a retained MediaQueryList must re-evaluate, not serve a frozen snapshot
          const held = window.matchMedia('(min-resolution: 2dppx) and (min-width: 300px)');
          res.heldBefore = held.matches;
          const fresh = window.matchMedia('(min-resolution: 2dppx) and (min-width: 300px)');
          res.freshAgrees = (held.matches === fresh.matches);
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20); $b->quit;
    require Cpanel::JSON::XS; my $r = Cpanel::JSON::XS::decode_json($out // '{}');
    ok($r->{ran}, 'matchMedia probe ran') or diag('probe returned nothing');
    ok($r->{simple}, 'mobile: (pointer: coarse) matches');
    is($r->{screenAnd}, $r->{simple}, '"screen and (X)" agrees with "(X)" -- a media type keeps the spoof');
    is($r->{allAnd},    $r->{simple}, '"all and (X)" agrees with "(X)"');
    ok($r->{withValueAnd},
       'a conjunction whose value contains the substring "and" is not shredded by the splitter');
    ok($r->{landscape}, 'a comma list keeps a spoofed alternative even when another contains "and"');
    ok($r->{freshAgrees},
       'a retained MediaQueryList agrees with a freshly created one (matches is re-evaluated, not frozen)');
}

# --- round-4: the accessor-name enumeration must find nothing ---
# Every real WebKitGTK accessor is named exactly "get <prop>". Ours were named
# "get" (C layer) or "" (JS), so one loop listed the entire spoof with zero false
# positives -- including the native getters that are meant to be undetectable.
sub enum_probe {
    my ($profile) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $profile, seed => 111);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const odd=[], protoProto=[], srcOdd=[], ownTS=[];
          // the accessors installed natively from C -- these must STAY native
          const nativeNames=['Navigator.platform','Navigator.vendor','Navigator.languages',
            'Navigator.language','Navigator.hardwareConcurrency','Navigator.deviceMemory',
            'Navigator.maxTouchPoints','Screen.width','Screen.height','Screen.availWidth',
            'Screen.availHeight','Screen.colorDepth','Screen.pixelDepth','window.devicePixelRatio'];
          const targets=[[window,'window'],[Navigator.prototype,'Navigator'],[Screen.prototype,'Screen']];
          ['NetworkInformation','USB','HID','Serial','Bluetooth','StorageManager','BatteryManager',
           'NavigatorUAData','ScreenOrientation','RTCPeerConnection','MediaQueryList',
           'WebGLShaderPrecisionFormat'].forEach(function(n){
             if (window[n] && window[n].prototype) targets.push([window[n].prototype, n]); });
          for (const [o,label] of targets) {
            for (const k of Object.getOwnPropertyNames(o)) {
              let d; try { d = Object.getOwnPropertyDescriptor(o,k); } catch(e){ continue; }
              if (!d || typeof d.get !== 'function') continue;
              const g = d.get;
              if (g.name !== 'get '+k) odd.push(label+'.'+k+'='+JSON.stringify(g.name));
              // a real native accessor never carries a .prototype
              if (Object.prototype.hasOwnProperty.call(g,'prototype')) protoProto.push(label+'.'+k);
              // nor an own toString -- that alone enumerates the spoof
              if (Object.prototype.hasOwnProperty.call(g,'toString')) ownTS.push(label+'.'+k);
              // the NATIVE accessors must still report [native code] under FPT.call
              if (nativeNames.indexOf(label+'.'+k) >= 0) {
                let src; try { src = Function.prototype.toString.call(g); } catch(e){ src=''; }
                if (src.indexOf('[native code]') < 0) srcOdd.push(label+'.'+k);
              }
            } }
          return JSON.stringify({ran:1, odd:odd, protoProto:protoProto, srcOdd:srcOdd,
                                 ownTS:ownTS, checked:targets.length});
JS
    });
    TWK::run_with_timeout(20); $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
for my $profile (qw(windows-chrome pixel-chrome)) {
    my $r = enum_probe($profile);
    ok($r->{ran}, "$profile: accessor-name enumeration probe ran") or diag('probe returned nothing');
    cmp_ok($r->{checked}, '>=', 3, "$profile: the probe walked the spoofed prototypes");
    is_deeply($r->{odd}, [],
              "$profile: no accessor is detectable by a wrong getter name")
        or diag('detectable: ' . join(', ', @{$r->{odd} || []}));
    is_deeply($r->{protoProto}, [],
              "$profile: no spoofed accessor getter carries a .prototype")
        or diag('carries .prototype: ' . join(', ', @{$r->{protoProto} || []}));
    is_deeply($r->{ownTS}, [],
              "$profile: no spoofed accessor getter carries an own toString")
        or diag('own toString: ' . join(', ', @{$r->{ownTS} || []}));
    # The C-installed accessors must remain genuinely native: renaming them in
    # place is fine, replacing them with a JS wrapper is not.
    is_deeply($r->{srcOdd}, [],
              "$profile: the native navigator/screen getters still report [native code]")
        or diag('no longer native: ' . join(', ', @{$r->{srcOdd} || []}));
}

# --- round-7 regressions ---
# window.orientation is mobile-only; screen.orientation is universal. Emitting
# the orientation config for desktop (so it gets screen.orientation) must not
# also hand it window.orientation beside maxTouchPoints:0.
# And a (not X) clause must delegate the RAW inner text, or the calc() welding
# bug returns and a query and its negation are both true.
for my $prof (qw(windows-chrome pixel-chrome)) {
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $prof);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $o;
    $b->go('fp://host/p', sub { $b->script(<<'JS', sub { $o = $_[0]; EV::break }) });
      const mm = q => window.matchMedia(q).matches;
      return JSON.stringify({
        ran: 1,
        winOrient:    ('orientation' in window),
        onOrient:     ('onorientationchange' in window),
        screenOrient: !!(screen.orientation && screen.orientation.type),
        calcPos:      mm('(min-width: calc(50px + 10px))'),
        calcNeg:      mm('(not (min-width: calc(50px + 10px)))'),
        // The pair above only disagrees if BOTH round-7 media fixes are present,
        // so reverting either one alone escapes it. This compound query pins them
        // separately: the window is 200px wide so the inner clause is true and the
        // whole query must be false, but either bug alone flips it to true.
        calcCompound: mm('(pointer: coarse) and (not (min-width: calc(50px + 10px)))'),
      });
JS
    TWK::run_with_timeout(20); $b->quit;
    require Cpanel::JSON::XS; my $r = Cpanel::JSON::XS::decode_json($o // '{}');
    my $mobile = $prof eq 'pixel-chrome';
    ok($r->{ran}, "$prof: orientation/media probe ran") or diag('probe returned nothing');
    is($r->{winOrient}, $mobile ? 1 : 0, "$prof: window.orientation present only on mobile");
    is($r->{onOrient},  $mobile ? 1 : 0, "$prof: onorientationchange tracks window.orientation");
    ok($r->{screenOrient}, "$prof: screen.orientation is present on desktop and mobile alike");
    isnt($r->{calcPos}, $r->{calcNeg}, "$prof: a calc() query and its negation cannot both hold");
    is($r->{calcCompound}, 0,
       "$prof: (pointer: coarse) and (not <true clause>) is false (pins each media fix separately)");
}

# --- round-8: the screen must not be recoverable through ANY media-query form ---
# Handling only the min-/max- prefixes left the MQ4 range form delegated to the
# engine, so a binary search over '(device-width >= Npx)' still returned the real
# host geometry -- the exact leak the min-/max- branch was added to close.
for my $prof (qw(windows-chrome pixel-chrome)) {
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $prof);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $o;
    $b->go('fp://host/p', sub { $b->script(<<'JS', sub { $o = $_[0]; EV::break }) });
      const mm = q => window.matchMedia(q).matches;
      const search = suffix => { let lo=1, hi=8192;
        for (let i=0;i<14;i++){ const mid=(lo+hi)>>1;
          if (mm('(min-device-width: '+mid+'px)'+suffix)) lo=mid+1; else hi=mid; }
        return lo-1; };
      let lo=1, hi=8192;
      for (let i=0;i<14;i++){ const mid=(lo+hi)>>1;
        if (mm('(device-width >= '+mid+'px)')) lo=mid+1; else hi=mid; }
      return JSON.stringify({ ran:1, sw:screen.width, found:lo-1,
        // an untokenizable alternative must not disable the spoofed one beside it
        foundTail: search(', print'), foundPlain: search(''),
        aspect: mm('(device-aspect-ratio: '+screen.width+'/'+screen.height+')'),
        orQ:  mm('(hover: none) or (pointer: coarse)'),
        andQ: mm('(hover: none) and (pointer: coarse)'),
        // tokenizing must respect paren depth: a plain split shredded a nested
        // condition, so a conjunction containing a TAUTOLOGY went false
        taut: mm('((hover: none) or (hover: hover))'),
        nested: mm('(pointer: coarse) and ((hover: none) or (hover: hover))'),
        bare:   mm('(pointer: coarse)') });
JS
    TWK::run_with_timeout(20); $b->quit;
    require Cpanel::JSON::XS; my $r = Cpanel::JSON::XS::decode_json($o // '{}');
    ok($r->{ran}, "$prof: media-geometry probe ran") or diag('probe returned nothing');
    is($r->{found}, $r->{sw},
       "$prof: a binary search over the device-width RANGE form yields the spoofed width");
    is($r->{foundPlain}, $r->{sw}, "$prof: min-device-width search yields the spoofed width");
    is($r->{foundTail}, $r->{sw},
       "$prof: appending ', print' does not fall back to the real device geometry");
    ok($r->{aspect}, "$prof: device-aspect-ratio agrees with the spoofed screen");
    # MQ4 `or` is a disjunction: it cannot be false where `and` of the same two is true.
    ok(!$r->{andQ} || $r->{orQ}, "$prof: 'A or B' is not false while 'A and B' is true");
    ok($r->{taut}, "$prof: a nested (A or B) tautology is true");
    is($r->{nested}, $r->{bare},
       "$prof: conjoining a tautology changes nothing (tokenizer respects paren depth)");
}

# --- round-11: the media evaluator parses each clause into (feature, operator,
# value) and dispatches by FEATURE NAME. Every defect below was a syntactic form
# of an ALREADY-spoofed feature that the old spelling-matcher did not recognise,
# so it delegated the clause and the host answered -- handing back the real
# geometry or the real DPR. Each is pinned in both a desktop and a mobile profile.
for my $prof (qw(windows-chrome pixel-chrome)) {
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $prof);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $o;
    $b->go('fp://host/p', sub { $b->script(<<'JS', sub { $o = $_[0]; EV::break }) });
      const mm = q => window.matchMedia(q).matches;
      const R = { ran:1, sw: screen.width, sh: screen.height, dpr: window.devicePixelRatio };
      // 1em/1pt in px, resolved by the ENGINE (the viewport `width` feature is
      // never spoofed, so this is the host's real font size, not ours).
      const t = (e,n) => mm('(max-width:calc(' + e + ' - ' + n.toFixed(6) + 'px))');
      const thr = e => { let lo=-1, hi=1, i;
        for (i=0;i<44 && !t(e,lo);i++) lo*=2;   if (!t(e,lo)) return null;
        for (i=0;i<44 && t(e,hi);i++) hi*=2;    if (t(e,hi)) return null;
        for (i=0;i<44;i++){ const mid=(lo+hi)/2; if (t(e,mid)) lo=mid; else hi=mid; }
        return lo; };
      const z = thr('0px');
      R.emPx = z===null ? null : thr('1em') - z;
      R.ptPx = z===null ? null : thr('1pt') - z;
      // 1. a binary search over device-width must yield the SPOOFED width in
      //    EVERY length unit, not only px -- an em/pt/in search walked straight
      //    past the spoof and recovered the real host geometry.
      const search = (unit, per, tail) => { let lo=0, hi=16384;
        for (let i=0;i<28;i++){ const mid=(lo+hi)/2;
          if (mm('(min-device-width: ' + (mid/per).toFixed(6) + unit + ')' + (tail||''))) lo=mid; else hi=mid; }
        return Math.round(lo); };
      R.searchPx   = search('px', 1);
      R.searchEm   = R.emPx ? search('em', R.emPx) : null;
      R.searchPt   = R.ptPx ? search('pt', R.ptPx) : null;
      R.searchIn   = search('in', 96);
      R.searchEmT  = R.emPx ? search('em', R.emPx, ', print') : null;
      R.searchPtT  = R.ptPx ? search('pt', R.ptPx, ', print') : null;
      R.searchCalc = (() => { let lo=0, hi=16384;
        for (let i=0;i<28;i++){ const mid=(lo+hi)/2;
          if (mm('(min-device-width: calc(' + mid.toFixed(6) + 'px + 0px))')) lo=mid; else hi=mid; }
        return Math.round(lo); })();
      R.searchBadUnit = mm('(min-device-width: 1zz)');   // unresolvable -> delegate, never a wrong answer
      // A negative bound carries no information about the width, so it must not
      // be a way to force the clause back to the host: the search below still has
      // to yield the spoofed width.
      R.negTwoSided = (() => { let lo=0, hi=16384;
        for (let i=0;i<28;i++){ const mid=(lo+hi)/2;
          if (!mm('(-5px < device-width < ' + mid.toFixed(6) + 'px)')) lo=mid; else hi=mid; }
        return Math.round(lo); })();
      // 2. all four spellings of device-aspect-ratio ask the same question
      const ar = screen.width + '/' + screen.height;
      R.arColon  = mm('(device-aspect-ratio: ' + ar + ')');
      R.arRange  = mm('(device-aspect-ratio = ' + ar + ')');
      R.arSingle = mm('(device-aspect-ratio: ' + (screen.width/screen.height) + ')');
      R.arDec    = mm('(device-aspect-ratio: ' + (screen.width/10) + '/' + (screen.height/10) + ')');
      // 3. reversed-operand ranges
      R.revW = (() => { let lo=0, hi=16384;
        for (let i=0;i<28;i++){ const mid=(lo+hi)/2;
          if (mm('(' + mid.toFixed(6) + 'px <= device-width)')) lo=mid; else hi=mid; }
        return Math.round(lo); })();
      R.revDpr = (() => { let lo=0, hi=64;
        for (let i=0;i<30;i++){ const mid=(lo+hi)/2;
          if (mm('(' + mid.toFixed(6) + 'dppx <= resolution)')) lo=mid; else hi=mid; }
        return lo; })();
      R.twoSided = mm('(1px < device-width < 100000px)');
      // 4. equality and order must not contradict: one comparator, one tolerance
      R.eqGe = mm('(device-aspect-ratio: '+ar+')') && !mm('(device-aspect-ratio >= '+ar+')');
      R.eqLe = mm('(device-aspect-ratio: '+ar+')') && !mm('(device-aspect-ratio <= '+ar+')');
      R.eqGt = mm('(device-aspect-ratio: '+ar+')') && mm('(device-aspect-ratio > '+ar+')');
      // 5. the boolean form of a feature asks `feature != none`
      R.boolHover = mm('(hover)');     R.hoverNone = mm('(hover: none)');
      R.boolAnyH  = mm('(any-hover)'); R.anyHNone  = mm('(any-hover: none)');
      R.boolPtr   = mm('(pointer)');   R.ptrNone   = mm('(pointer: none)');
      // 6. -webkit-device-pixel-ratio in its RANGE form leaked the real DPR
      R.wkRange = (() => { let lo=0, hi=64;
        for (let i=0;i<30;i++){ const mid=(lo+hi)/2;
          if (mm('(-webkit-device-pixel-ratio >= ' + mid.toFixed(6) + ')')) lo=mid; else hi=mid; }
        return lo; })();
      R.wkMin = (() => { let lo=0, hi=64;
        for (let i=0;i<30;i++){ const mid=(lo+hi)/2;
          if (mm('(-webkit-min-device-pixel-ratio: ' + mid.toFixed(6) + ')')) lo=mid; else hi=mid; }
        return lo; })();
      // 7. a grouped condition is evaluated, not handed to the host whole
      R.grpDouble = mm('((pointer: coarse))');
      R.grpTriple = mm('(((pointer: coarse)))');
      R.grpPlain  = mm('(pointer: coarse)');
      R.grpNeg    = mm('(not ((hover: none) or (hover: hover)))');
      // the algebra, over a corpus: a disjunction, a conjunction, a comma list, a
      // negation, a media type and a parenthesised group must all agree with the
      // clauses they are built from.
      const CL = ['(pointer: coarse)','(pointer: fine)','(hover: none)','(hover: hover)',
                  '(any-pointer: coarse)','(min-width: 1px)','(min-width: 99999px)',
                  '(min-resolution: 2dppx)','(max-resolution: 1dppx)','(device-width >= 100px)',
                  '(device-width < 100000px)','(orientation: landscape)','(min-device-height: 1px)'];
      let checks = 0; const viol = [];
      for (let i=0;i<CL.length;i++) {
        const a = mm(CL[i]);
        checks++; if (mm('(' + CL[i] + ')') !== a)        viol.push('paren ' + CL[i]);
        checks++; if (mm('((' + CL[i] + '))') !== a)      viol.push('paren2 ' + CL[i]);
        checks++; if (mm('(not ' + CL[i] + ')') !== !a)   viol.push('not ' + CL[i]);
        checks++; if (mm('not screen and ' + CL[i]) !== !a) viol.push('nottype ' + CL[i]);
        checks++; if (mm('screen and ' + CL[i]) !== a)    viol.push('type ' + CL[i]);
        for (let j=i+1;j<CL.length;j++) {
          const b = mm(CL[j]);
          checks++; if (mm(CL[i]+' and '+CL[j]) !== (a && b)) viol.push('and ' + CL[i] + ' | ' + CL[j]);
          checks++; if (mm(CL[i]+' or ' +CL[j]) !== (a || b)) viol.push('or ' + CL[i] + ' | ' + CL[j]);
          checks++; if (mm(CL[i]+', '   +CL[j]) !== (a || b)) viol.push('comma ' + CL[i] + ' | ' + CL[j]);
          checks++; if (mm('('+CL[i]+' or '+CL[j]+')') !== (a || b)) viol.push('grp ' + CL[i] + ' | ' + CL[j]);
        } }
      R.checks = checks; R.nviol = viol.length; R.viol = viol.slice(0,8);
      return JSON.stringify(R);
JS
    TWK::run_with_timeout(120); $b->quit;
    require Cpanel::JSON::XS; my $r = Cpanel::JSON::XS::decode_json($o // '{}');
    ok($r->{ran}, "$prof: media-form probe ran") or diag('probe returned nothing');
    my ($sw, $sh, $dpr) = @$r{qw(sw sh dpr)};
    ok($r->{emPx} && abs($r->{emPx} - 16) < 4, "$prof: the host font size resolved ($r->{emPx}px)");
    # 1. every unit, and the untokenizable ', print' alternative beside it
    my %form = (searchPx => 'px', searchEm => 'em', searchPt => 'pt', searchIn => 'in',
                searchCalc => 'calc()', searchEmT => "em beside ', print'",
                searchPtT => "pt beside ', print'", revW => 'a reversed-operand range');
    is($r->{$_}, $sw, "$prof: a device-width binary search in $form{$_} yields the spoofed width $sw")
        for qw(searchPx searchEm searchPt searchIn searchCalc searchEmT searchPtT revW);
    ok(!$r->{searchBadUnit}, "$prof: a length in an unresolvable unit is delegated, not guessed");
    is($r->{negTwoSided}, $sw,
       "$prof: a range with a negative lower bound still yields the spoofed width $sw");
    # 2. one question, four spellings
    ok($r->{arColon} && $r->{arRange} && $r->{arSingle} && $r->{arDec},
       "$prof: all four device-aspect-ratio spellings agree with the spoofed screen")
        or diag(join ' ', map { "$_=" . ($r->{$_} // 'u') } qw(arColon arRange arSingle arDec));
    # 3. reversed operands
    cmp_ok(abs($r->{revDpr} - $dpr), '<', 0.01,
           "$prof: '(Ndppx <= resolution)' yields the spoofed dpr $dpr, not the host's");
    ok($r->{twoSided}, "$prof: a two-sided range (a < device-width < b) is evaluated");
    # 4. one comparator: equality cannot hold where the order relations deny it
    ok(!$r->{eqGe} && !$r->{eqLe} && !$r->{eqGt},
       "$prof: device-aspect-ratio = X never contradicts >= X, <= X or > X");
    # 5. the boolean form
    is($r->{boolHover}, $r->{hoverNone} ? 0 : 1, "$prof: (hover) agrees with (hover: none)");
    is($r->{boolAnyH},  $r->{anyHNone}  ? 0 : 1, "$prof: (any-hover) agrees with (any-hover: none)");
    is($r->{boolPtr},   $r->{ptrNone}   ? 0 : 1, "$prof: (pointer) agrees with (pointer: none)");
    # 6. the range form of the vendor-prefixed dpr
    cmp_ok(abs($r->{wkRange} - $dpr), '<', 0.01,
           "$prof: -webkit-device-pixel-ratio RANGE form yields the spoofed dpr $dpr");
    cmp_ok(abs($r->{wkMin} - $dpr), '<', 0.01,
           "$prof: -webkit-min-device-pixel-ratio colon form yields the spoofed dpr $dpr");
    # 7. grouped conditions
    is($r->{grpDouble}, $r->{grpPlain}, "$prof: ((X)) agrees with (X)");
    is($r->{grpTriple}, $r->{grpPlain}, "$prof: (((X))) agrees with (X)");
    ok(!$r->{grpNeg},   "$prof: a negated (A or not-A) group is false");
    is($r->{nviol}, 0, "$prof: 0/$r->{checks} disjunction/conjunction/negation violations")
        or diag(join "\n", @{$r->{viol} || []});
}

# --- RTCDataChannel: per-instance state, the full attribute set, and the two
# behaviours a stub gets wrong by default (send() on a channel that never opens,
# and an onX handler that is stored but never invoked). ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome');
    $b->mock_scheme('dc', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('dc://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = {ran:1};
          if(!('RTCPeerConnection' in window)) return JSON.stringify(res);
          const pc = new RTCPeerConnection();
          const a = pc.createDataChannel('chat', {ordered:false, protocol:'x', negotiated:true, id:7});
          const b = pc.createDataChannel('other');
          res.label     = a.label;              // the ARGUMENT, not a class constant
          res.labelB    = b.label;              // ... and two channels must differ
          res.ordered   = a.ordered;            // false, from the options bag
          res.orderedB  = b.ordered;            // true, the default
          res.protocol  = a.protocol;
          res.negotiated= a.negotiated;
          res.id        = a.id;
          res.state     = a.readyState;
          res.attrs     = ['label','ordered','maxPacketLifeTime','maxRetransmits','protocol',
                           'negotiated','id','readyState','bufferedAmount',
                           'bufferedAmountLowThreshold','binaryType','send','close']
                          .filter(k => !(k in a));            // must be empty
          res.ownKeys   = Object.keys(a).length;              // real: 0 (all on the prototype)
          res.mplt      = a.maxPacketLifeTime; res.mr = a.maxRetransmits;
          res.buffered  = a.bufferedAmount;
          res.binary    = a.binaryType;
          a.binaryType  = 'arraybuffer'; res.binarySet = a.binaryType;
          try { a.binaryType = 'nope'; res.binaryBad = 'accepted'; }
          catch(e){ res.binaryBad = e.name; }
          res.binaryKept = a.binaryType;                      // the bad set must not stick
          a.bufferedAmountLowThreshold = 4096; res.thr = a.bufferedAmountLowThreshold;
          // a channel with no ICE behind it never opens, so send() must throw
          try { a.send('x'); res.sendThrew = false; }
          catch(e){ res.sendThrew = e.name; }
          // close(): synchronously 'closing', then 'closed' + a close event that
          // BOTH addEventListener and onclose see
          let viaHandler = 0, viaListener = 0;
          a.onclose = () => { viaHandler++; };
          a.addEventListener('close', () => { viaListener++; });
          res.handlerReadBack = (typeof a.onclose);
          a.onclose = 42; res.handlerNonObject = a.onclose;    // LegacyTreatNonObjectAsNull
          a.onclose = () => { viaHandler++; };
          a.close();
          res.closing = a.readyState;
          await new Promise(r => setTimeout(r, 0));
          res.closed  = a.readyState;
          res.viaHandler = viaHandler; res.viaListener = viaListener;
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS;
    my $r = Cpanel::JSON::XS::decode_json($out // '{}');
    ok($r->{ran}, 'RTCDataChannel probe ran') or diag('probe returned nothing');
    is($r->{label},  'chat',  'createDataChannel(label) is reflected on the channel');
    is($r->{labelB}, 'other', 'a second channel carries its OWN label (per-instance state)');
    is($r->{ordered},  0, 'ordered:false from the options bag');
    is($r->{orderedB}, 1, 'ordered defaults to true when the bag omits it');
    is($r->{protocol}, 'x', 'protocol comes from the options bag');
    is($r->{negotiated}, 1, 'negotiated comes from the options bag');
    is($r->{id}, 7,         'id comes from the options bag');
    is($r->{state}, 'connecting', 'a fresh channel is connecting');
    is_deeply($r->{attrs}, [], 'the full RTCDataChannel member set is present')
        or diag('missing: ' . join(', ', @{$r->{attrs}}));
    is($r->{ownKeys}, 0, 'no own enumerable keys (attributes live on the prototype)');
    is($r->{mplt}, undef, 'maxPacketLifeTime defaults to null');
    is($r->{mr},   undef, 'maxRetransmits defaults to null');
    is($r->{buffered}, 0, 'bufferedAmount is 0');
    is($r->{binary}, 'blob', 'binaryType defaults to blob');
    is($r->{binarySet}, 'arraybuffer', 'binaryType accepts arraybuffer');
    is($r->{binaryBad}, 'TypeError', 'an out-of-enum binaryType throws, as Chrome does');
    is($r->{binaryKept}, 'arraybuffer', 'the rejected binaryType did not stick');
    is($r->{thr}, 4096, 'bufferedAmountLowThreshold is writable');
    is($r->{sendThrew}, 'InvalidStateError',
       "send() on a never-opening channel throws InvalidStateError (a silent no-op is the tell)");
    is($r->{handlerReadBack}, 'function', 'onclose stores a function');
    is($r->{handlerNonObject}, undef, 'onclose = 42 reads back null ([LegacyTreatNonObjectAsNull])');
    is($r->{closing}, 'closing', 'close() moves readyState to closing synchronously');
    is($r->{closed},  'closed',  'readyState reaches closed');
    is($r->{viaListener}, 1, 'the close event reached an addEventListener listener');
    is($r->{viaHandler},  1, 'the close event ALSO reached the onclose handler (no handler/listener asymmetry)');
}

# --- matchMedia must survive pathological nesting WITHOUT throwing and WITHOUT
# falling back to the engine. Delegating on a depth breach was tried and it
# re-opened the device-width leak this evaluator exists to close: the host
# answers a geometry probe with the REAL screen, so wrapping the same binary
# search in parens recovered the true 1280 instead of the spoofed 412. ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'pixel-chrome');  # screen 412x915
    $b->mock_scheme('mq', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('mq://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = {};
          const nest = (q, n) => '('.repeat(n) + q + ')'.repeat(n);
          for (const n of [1, 100, 300, 5000]) {
            try { res['m'+n] = matchMedia(nest('hover: none', n)).matches; }
            catch (e) { res['m'+n] = 'THREW ' + e.name; }
          }
          // the leak: the same binary search, plain and paren-wrapped
          const search = n => {
            let lo = 1, hi = 5000;
            while (lo < hi) { const mid = (lo + hi) >> 1;
              if (matchMedia(nest('max-device-width: ' + mid + 'px', n)).matches) hi = mid; else lo = mid + 1; }
            return lo; };
          res.plain   = search(1);
          res.wrapped = search(300);
          res.screenW = screen.width;
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(30);
    $b->quit;
    require Cpanel::JSON::XS;
    my $r = Cpanel::JSON::XS::decode_json($out // '{}');
    # pixel-chrome is mobile: (hover: none) is TRUE, and must stay true at any depth
    for my $n (1, 100, 300, 5000) {
        is($r->{"m$n"}, 1, "(hover: none) nested $n deep still returns the SPOOFED answer");
    }
    is($r->{plain},   412, 'device-width binary search yields the spoofed screen width');
    is($r->{wrapped}, 412, 'the SAME search wrapped 300 parens deep does NOT leak the real width');
    is($r->{screenW}, 412, 'screen.width agrees');
}

# --- RTCDataChannel WebIDL details: binding-layer arity, unsigned short
# coercion, the mutually-exclusive retransmission bounds, and the closing event ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome');
    $b->mock_scheme('dc2', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('dc2://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = {ran:1};
          if (!('RTCPeerConnection' in window)) return JSON.stringify(res);
          const pc = new RTCPeerConnection();
          const ch = pc.createDataChannel('c');
          // arity is checked by the binding layer BEFORE the method body, so a
          // 0-arg send is a TypeError even though the state would also fail
          try { ch.send();    res.arity = 'no-throw'; } catch (e) { res.arity = e.name; }
          try { ch.send('x'); res.state = 'no-throw'; } catch (e) { res.state = e.name; }
          // unsigned short in RTCDataChannelInit: ToUint16, not ToUint32
          res.mplt = pc.createDataChannel('a', {maxPacketLifeTime:70000}).maxPacketLifeTime;
          res.id   = pc.createDataChannel('b', {id:70000, negotiated:true}).id;
          res.mr   = pc.createDataChannel('c3',{maxRetransmits:65536}).maxRetransmits;
          try { pc.createDataChannel('d', {maxPacketLifeTime:1, maxRetransmits:1});
                res.bothBounds = 'accepted'; } catch (e) { res.bothBounds = e.name; }
          // closing fires before close, and an onX set again after a null
          // interlude re-queues at the END (HTML event-handler setter algorithm)
          const seen = [];
          const c2 = pc.createDataChannel('e');
          c2.onclosing = () => seen.push('closing');
          c2.onclose   = () => seen.push('fn1');
          c2.addEventListener('close', () => seen.push('L'));
          c2.onclose   = null;
          c2.onclose   = () => seen.push('fn2');
          c2.close();
          await new Promise(r => setTimeout(r, 0));
          res.order = seen.join(',');
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(30);
    $b->quit;
    require Cpanel::JSON::XS;
    my $r = Cpanel::JSON::XS::decode_json($out // '{}');
    ok($r->{ran}, 'RTCDataChannel WebIDL probe ran') or diag('probe returned nothing');
    is($r->{arity}, 'TypeError',
       'send() with no argument is a TypeError (arity is checked before state)');
    is($r->{state}, 'InvalidStateError', 'send(data) on a connecting channel is InvalidStateError');
    is($r->{mplt}, 4464, 'maxPacketLifeTime 70000 wraps to 4464 (ToUint16, not ToUint32)');
    is($r->{id},   4464, 'id 70000 wraps to 4464');
    is($r->{mr},   0,    'maxRetransmits 65536 wraps to 0');
    is($r->{bothBounds}, 'TypeError',
       'createDataChannel rejects both retransmission bounds together');
    is($r->{order}, 'closing,L,fn2',
       'closing precedes close, and an onclose re-set after null runs AFTER a listener added meanwhile');
}

# --- RTCSessionDescription: `type` is a REQUIRED WebIDL member of
# RTCSessionDescriptionInit, so a spec-compliant browser throws during
# dictionary conversion when it is absent. Verified against the W3C WebRTC IDL
# (`required RTCSdpType type`) and MDN. RTCIceCandidate has no such required
# member and must stay lenient. ---
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome');
    $b->mock_scheme('sd', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('sd://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = {ran:1};
          if (!('RTCSessionDescription' in window)) return JSON.stringify(res);
          try { new RTCSessionDescription({}); res.empty = 'no-throw'; } catch(e){ res.empty = e.name; }
          try { new RTCSessionDescription();   res.noarg = 'no-throw'; } catch(e){ res.noarg = e.name; }
          try { const d = new RTCSessionDescription({type:'offer'});
                res.okType = d.type; res.okSdp = d.sdp; } catch(e){ res.okType = 'THREW '+e.name; }
          try { const d = new RTCSessionDescription({type:'answer', sdp:'v=0'});
                res.full = d.type + '/' + d.sdp; } catch(e){ res.full = 'THREW '+e.name; }
          // untouched: RTCIceCandidate has no required member
          try { const c = new RTCIceCandidate({}); res.ice = 'ok'; res.iceCand = c.candidate; }
          catch(e){ res.ice = 'THREW '+e.name; }
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS;
    my $r = Cpanel::JSON::XS::decode_json($out // '{}');
    ok($r->{ran}, 'RTCSessionDescription probe ran') or diag('probe returned nothing');
    is($r->{empty}, 'TypeError', 'new RTCSessionDescription({}) throws (required member type absent)');
    is($r->{noarg}, 'TypeError', 'new RTCSessionDescription() throws (required member type absent)');
    is($r->{okType}, 'offer', 'a valid {type} constructs and reflects type');
    is($r->{okSdp},  '',      'sdp defaults to the empty string');
    is($r->{full}, 'answer/v=0', '{type, sdp} both round-trip');
    is($r->{ice},  'ok',      'RTCIceCandidate({}) stays lenient (no required member) -- not over-restricted');
    is($r->{iceCand}, '',     'RTCIceCandidate candidate defaults to the empty string');
}

done_testing;
