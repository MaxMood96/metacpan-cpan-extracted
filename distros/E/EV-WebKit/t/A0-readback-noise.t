use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use EV::WebKit::Fingerprint;
plan skip_all => 'web-process extension not built' unless EV::WebKit::Fingerprint::available();

# Drive a data: canvas in the web process and return a JSON blob of readback probes.
sub probe {
    my (%opt) = @_;                       # seed => N (or none)
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', %opt);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          var c = document.createElement('canvas'); c.width=32; c.height=32;
          var g = c.getContext('2d');
          g.fillStyle = '#4080c0'; g.fillRect(0,0,32,32);
          var d1 = g.getImageData(0,0,32,32).data;
          var url1 = c.toDataURL();
          var url2 = c.toDataURL();               // same content -> must equal url1
          // sample the fill pixel (LSB-only: within 1 of the true channel)
          return JSON.stringify({ url1:url1, url2:url2, r:d1[0], g:d1[1], b:d1[2], a:d1[3] });
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}

my $s1 = probe(seed => 111);
my $s1b = probe(seed => 111);
my $s2 = probe(seed => 222);
my $none = probe();

ok($s1->{url1} eq $s1->{url2}, 'same seed, same content: toDataURL is stable within a call');
is($s1->{url1}, $s1b->{url1}, 'same seed across instances: identical encoded output');
isnt($s1->{url1}, $s2->{url1}, 'different seed: different encoded output');
isnt($s1->{url1}, $none->{url1}, 'seeded output differs from the un-noised host output');
# LSB-only: fill was #4080c0 = (64,128,192); each channel within 1 of the truth.
ok(abs($s1->{r}-64) <= 1 && abs($s1->{g}-128) <= 1 && abs($s1->{b}-192) <= 1,
   'getImageData noise is LSB-only (canvas still renders the fill)');
is($s1->{a}, 255, 'alpha channel is never perturbed');

# The noise must key on ABSOLUTE canvas coordinates, not on the offset within the
# returned buffer: otherwise the same pixel reads differently depending on which
# rectangle was requested, which is both an inconsistency a detector probes for
# and a contradiction of the documented stable-within-a-session property.
sub probe_rect {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', %opt);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          var c=document.createElement('canvas'); c.width=32; c.height=32;
          var g=c.getContext('2d');
          for (var y=0;y<32;y++) for (var x=0;x<32;x++){        // vary pixels so a match is meaningful
            g.fillStyle='rgb('+((x*8)%256)+','+((y*8)%256)+',128)'; g.fillRect(x,y,1,1); }
          var full=g.getImageData(0,0,32,32).data;
          var i=(17*32+9)*4;                                     // pixel (9,17) in the full read
          var sub=g.getImageData(9,17,1,1).data;                 // ...and the same pixel alone
          var mid=g.getImageData(8,16,4,4).data;                 // ...and inside an offset 4x4 block
          var m=((17-16)*4+(9-8))*4;
          return JSON.stringify({
            full:[full[i],full[i+1],full[i+2]],
            sub:[sub[0],sub[1],sub[2]],
            mid:[mid[m],mid[m+1],mid[m+2]],
          });
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
my $rect = probe_rect(seed => 111);
is_deeply($rect->{sub}, $rect->{full}, 'same pixel reads identically via a 1x1 sub-rect and the full canvas');
is_deeply($rect->{mid}, $rect->{full}, 'same pixel reads identically via an offset sub-rect and the full canvas');

# --- audio + webgl readPixels ---
# NB: EV::WebKit::script wraps the body in `await (async()=>{ ... })()` and
# JSON-stringifies the returned value -- so the body uses `return await`, NOT a
# trailing done-callback.
sub probe_av {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', %opt);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = { hasAudio:false, hasGL:false, audio:null, px:[0,0,0,0], pxhash:0 };
          const OAC = window.OfflineAudioContext || window.webkitOfflineAudioContext;
          if (OAC) {
            res.hasAudio = true;
            const ac = new OAC(1, 4096, 44100);
            const osc = ac.createOscillator(); osc.type='triangle'; osc.frequency.value=440;
            osc.connect(ac.destination); osc.start(0);
            const buf = await ac.startRendering();
            const ch = buf.getChannelData(0);
            let sum = 0; for (let i=0;i<ch.length;i++) sum += Math.abs(ch[i]);
            res.audio = sum;
          }
          const cv = document.createElement('canvas'); cv.width=8; cv.height=8;
          const gl = cv.getContext('webgl') || cv.getContext('experimental-webgl');
          if (gl) { res.hasGL = true; gl.clearColor(0.25,0.5,0.75,1); gl.clear(gl.COLOR_BUFFER_BIT);
                    const b2 = new Uint8Array(8*8*4); gl.readPixels(0,0,8,8,gl.RGBA,gl.UNSIGNED_BYTE,b2);
                    res.px = [b2[0],b2[1],b2[2],b2[3]];
                    let s=0; for (let i=0;i<b2.length;i++) s=(Math.imul(s,31)+b2[i])>>>0; res.pxhash=s; }  // position-weighted hash: robust cross-seed compare
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(25);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}

my $a1 = probe_av(seed => 111);
my $a1b = probe_av(seed => 111);
my $a2 = probe_av(seed => 222);
my $an = probe_av();
# isnt($x, undef) passes, and probe_av() ends in decode_json($out // '{}') --
# so a probe browser that failed outright yields {} and every isnt below would
# have passed while measuring nothing. Establish the other side first.
SKIP: {
    skip 'no Web Audio in this build', 5 unless $a1->{hasAudio};
    ok(defined $a2->{audio}, 'premise: the other-seed probe produced an audio hash');
    ok(defined $an->{audio}, 'premise: the unseeded probe produced an audio hash');
    is($a1->{audio}, $a1b->{audio}, 'audio hash stable for a fixed seed');
    isnt($a1->{audio}, $a2->{audio}, 'audio hash differs across seeds');
    isnt($a1->{audio}, $an->{audio}, 'seeded audio hash differs from the host output');
}
SKIP: {
    skip 'no WebGL in this build', 4 unless $a1->{hasGL};
    ok(defined $a2->{pxhash}, 'premise: the other-seed probe produced a pixel hash');
    # clear was (0.25,0.5,0.75) = (64,128,191); LSB-only after readPixels noise.
    ok(abs($a1->{px}[0]-64) <= 1 && abs($a1->{px}[1]-128) <= 1 && abs($a1->{px}[2]-191) <= 2,
       'readPixels noise is LSB-only (still the clear color)');
    isnt($a1->{pxhash}, $a2->{pxhash}, 'readPixels differs across seeds (whole-buffer hash)');
    is($a1->{px}[3], 255, 'readPixels alpha not perturbed');
}

# --- regressions from the round-1 adversarial review ---
# Negative control: with NO seed the fill must read back EXACTLY, proving the
# noise is genuinely not installed (not merely seeded differently).
is($none->{r}, 64,  'no seed: red channel is the exact fill (noise not installed)');
is($none->{g}, 128, 'no seed: green channel is the exact fill');
is($none->{b}, 192, 'no seed: blue channel is the exact fill');

sub probe_inv {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', %opt);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res = {};
          // premultiplied-alpha invariant: alpha==0 implies r=g=b=0 in every real browser
          const c=document.createElement('canvas'); c.width=c.height=32;
          const g=c.getContext('2d');
          const d=g.getImageData(0,0,32,32).data;
          let bad=0; for(let i=0;i<d.length;i+=4) if(d[i+3]===0 && (d[i]|d[i+1]|d[i+2])) bad++;
          res.transparentBroken=bad;
          // OffscreenCanvas must be noised too, and identically to HTMLCanvasElement
          res.hasOffscreen=!!window.OffscreenCanvas;
          if(window.OffscreenCanvas){
            const oc=new OffscreenCanvas(16,16), og=oc.getContext('2d');
            og.fillStyle='#808080'; og.fillRect(0,0,16,16);
            const od=og.getImageData(0,0,16,16).data;
            const hc=document.createElement('canvas'); hc.width=hc.height=16;
            const hg=hc.getContext('2d'); hg.fillStyle='#808080'; hg.fillRect(0,0,16,16);
            const hd=hg.getImageData(0,0,16,16).data;
            let mis=0, pert=0;
            for(let i=0;i<od.length;i+=4){
              if(od[i]!==hd[i]||od[i+1]!==hd[i+1]||od[i+2]!==hd[i+2]) mis++;
              if(od[i]!==128||od[i+1]!==128||od[i+2]!==128) pert++; }
            res.offMismatch=mis; res.offPerturbed=pert;
          }
          // audio: both read APIs agree on a frame, and bufferOffset is honoured
          const OAC=window.OfflineAudioContext||window.webkitOfflineAudioContext;
          if(OAC){
            const ac=new OAC(1,512,44100);
            const osc=ac.createOscillator(); osc.connect(ac.destination); osc.start(0);
            const buf=await ac.startRendering();
            const f1=new Float32Array(8); buf.copyFromChannel(f1,0,100);
            const ch=buf.getChannelData(0);
            const f2=new Float32Array(8); buf.copyFromChannel(f2,0,100);
            res.audioApisAgree=(f1[0]===ch[100] && f2[0]===ch[100]);
            const a=new Float32Array(16); buf.copyFromChannel(a,0,200);
            const bb=new Float32Array(16); buf.copyFromChannel(bb,0,201);
            let dis=0; for(let i=0;i<15;i++) if(a[i+1]!==bb[i]) dis++;   // frame 201+i read two ways
            res.offsetDisagreements=dis;
          }
          // a silent analyser reads all-zero in every real browser
          const AC=window.AudioContext||window.webkitAudioContext;
          if(AC){ const ac2=new AC(), an=ac2.createAnalyser();
            const bins=new Uint8Array(an.frequencyBinCount); an.getByteFrequencyData(bins);
            let nzc=0; for(let i=0;i<bins.length;i++) if(bins[i]!==0) nzc++;
            res.silentNonZero=nzc; try{ac2.close();}catch(e){} }
          // WebGL2 readPixels(dstOffset) must not touch bytes before the offset
          const cv=document.createElement('canvas'); cv.width=cv.height=4;
          const gl=cv.getContext('webgl2');
          res.hasGL2=!!gl;
          if(gl){ gl.clearColor(0.25,0.5,0.75,1); gl.clear(gl.COLOR_BUFFER_BIT);
            const b2=new Uint8Array(16+4*4*4).fill(7);
            gl.readPixels(0,0,4,4,gl.RGBA,gl.UNSIGNED_BYTE,b2,16);
            let pre=0; for(let i=0;i<16;i++) if(b2[i]!==7) pre++;
            res.readPixelsPrefixTouched=pre; }
          // wrapper arity must match the real API (a cheap, deterministic probe)
          res.arity={ toBlob:HTMLCanvasElement.prototype.toBlob.length,
                      getImageData:CanvasRenderingContext2D.prototype.getImageData.length,
                      getChannelData:window.AudioBuffer?AudioBuffer.prototype.getChannelData.length:null,
                      copyFromChannel:window.AudioBuffer?AudioBuffer.prototype.copyFromChannel.length:null };
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(30);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
my $inv = probe_inv(seed => 111);
ok(exists $inv->{transparentBroken}, 'invariant probe ran') or diag('probe returned nothing');
is($inv->{transparentBroken}, 0, 'transparent pixels keep RGB 0 (premultiplied-alpha invariant holds)');
SKIP: {
    skip 'no OffscreenCanvas in this build', 2 unless $inv->{hasOffscreen};
    is($inv->{offMismatch}, 0, 'OffscreenCanvas readback matches HTMLCanvasElement for the same render');
    cmp_ok($inv->{offPerturbed}, '>', 0, 'OffscreenCanvas readback is actually noised (not a bypass)');
}
SKIP: {
    skip 'no Web Audio', 2 unless exists $inv->{audioApisAgree};
    ok($inv->{audioApisAgree}, 'getChannelData and copyFromChannel agree on the same frame');
    is($inv->{offsetDisagreements}, 0, 'copyFromChannel honours bufferOffset (same frame, same value)');
}
SKIP: {
    skip 'no AudioContext', 1 unless exists $inv->{silentNonZero};
    is($inv->{silentNonZero}, 0, 'a silent analyser reports all-zero byte bins');
}
SKIP: {
    skip 'no WebGL2', 1 unless $inv->{hasGL2};
    is($inv->{readPixelsPrefixTouched}, 0, 'readPixels(dstOffset) leaves bytes before the offset untouched');
}
is($inv->{arity}{toBlob}, 1,         'toBlob arity matches the real API');
is($inv->{arity}{getImageData}, 4,   'getImageData arity matches the real API');
SKIP: {
    skip 'no AudioBuffer', 2 unless defined $inv->{arity}{getChannelData};
    is($inv->{arity}{getChannelData}, 1,  'getChannelData arity matches the real API');
    is($inv->{arity}{copyFromChannel}, 2, 'copyFromChannel arity matches the real API');
}

# --- regressions from the round-2 adversarial review ---
sub probe_r2 {
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', seed => 111);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const res={ran:1};
          // partial-alpha pixels must stay on the reachable un-premultiply lattice
          const c=document.createElement('canvas'); c.width=c.height=16;
          const g=c.getContext('2d');
          g.fillStyle='rgba(255,64,32,0.5)'; g.fillRect(0,0,16,16);
          const d=g.getImageData(0,0,16,16).data;
          let offLattice=0;
          for(let i=0;i<d.length;i+=4){ const a=d[i+3]; if(a===0||a===255) continue;
            for(let k=0;k<3;k++){ const v=d[i+k];
              let ok=false; for(let p=0;p<=a;p++) if(Math.round(p*255/a)===v){ ok=true; break; }
              if(!ok) offLattice++; } }
          res.offLattice=offLattice;
          // readPixels and getImageData must agree about the same physical pixel
          const cv=document.createElement('canvas'); cv.width=cv.height=8;
          const gl=cv.getContext('webgl',{preserveDrawingBuffer:true});
          res.hasGL=!!gl;
          if(gl){
            gl.clearColor(0.25,0.5,0.75,1); gl.clear(gl.COLOR_BUFFER_BIT);
            const px=new Uint8Array(8*8*4); gl.readPixels(0,0,8,8,gl.RGBA,gl.UNSIGNED_BYTE,px);
            const t=document.createElement('canvas'); t.width=t.height=8;
            const tg=t.getContext('2d'); tg.drawImage(cv,0,0);
            const id=tg.getImageData(0,0,8,8).data;
            let mism=0;
            for(let row=0;row<8;row++) for(let col=0;col<8;col++){
              const gi=((7-row)*8+col)*4, ci=(row*8+col)*4;    // GL row 7-row == canvas row `row`
              for(let k=0;k<3;k++) if(px[gi+k]!==id[ci+k]) mism++; }
            res.glVs2dMismatch=mism;
          }
          // a buffer the PAGE authored must be untouched
          const AC=window.AudioContext||window.webkitAudioContext;
          if(AC){ const ac=new AC();
            const buf=ac.createBuffer(1,128,44100);
            const ch=buf.getChannelData(0);
            let nonZero=0; for(let i=0;i<ch.length;i++) if(ch[i]!==0) nonZero++;
            res.freshBufferNonZero=nonZero;
            const known=new Float32Array(128); for(let i=0;i<128;i++) known[i]=i/128;
            buf.copyToChannel(known,0);
            const back=new Float32Array(128); buf.copyFromChannel(back,0);
            let diff=0; for(let i=0;i<128;i++) if(back[i]!==known[i]) diff++;
            res.roundTripDiff=diff; try{ac.close();}catch(e){} }
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(30);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
my $r2 = probe_r2();
ok($r2->{ran}, 'round-2 probe ran') or diag('probe returned nothing');
is($r2->{offLattice}, 0,
   'partial-alpha pixels stay on the reachable un-premultiply lattice (antialiasing safe)');
SKIP: {
    skip 'no WebGL', 1 unless $r2->{hasGL};
    is($r2->{glVs2dMismatch}, 0,
       'readPixels and getImageData agree about the same physical pixel (y-origin handled)');
}
SKIP: {
    skip 'no AudioContext', 2 unless exists $r2->{freshBufferNonZero};
    is($r2->{freshBufferNonZero}, 0, 'a page-authored AudioBuffer still reads all zeros');
    is($r2->{roundTripDiff}, 0,      'copyToChannel/copyFromChannel round-trips exactly (audio not corrupted)');
}

# --- round-3: the CLASSIC canvas fingerprint must actually be protected ---
# Text on a transparent canvas is ~90% antialiased edge, so a partial-alpha-only
# hash was identical with and without a seed: the main vector was unprotected.
sub probe_text {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', %opt);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const c=document.createElement('canvas'); c.width=140; c.height=40;
          const g=c.getContext('2d');
          g.textBaseline='top'; g.font='14px "Arial"'; g.fillStyle='#f60';
          g.fillText('Cwm fjordbank glyphs vext quiz', 2, 2);
          const d=g.getImageData(0,0,140,40).data;
          let partial=0, opaque=0, hPartial=0, hAll=0, offLattice=0;
          for(let i=0;i<d.length;i+=4){
            const a=d[i+3];
            hAll=(Math.imul(hAll,31)+d[i]+d[i+1]+d[i+2]+a)>>>0;
            if(a===255) opaque++;
            else if(a>0){ partial++;
              hPartial=(Math.imul(hPartial,31)+d[i]+d[i+1]+d[i+2])>>>0;
              for(let k=0;k<3;k++){ const v=d[i+k];
                let ok=false; for(let p=0;p<=a;p++) if(Math.round(p*255/a)===v){ ok=true; break; }
                if(!ok) offLattice++; } }
          }
          return JSON.stringify({partial:partial, opaque:opaque, hPartial:hPartial, hAll:hAll, offLattice:offLattice});
JS
    });
    TWK::run_with_timeout(25);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
{
    my $t1 = probe_text(seed => 111);
    my $t2 = probe_text(seed => 222);
    my $tn = probe_text();
    ok(exists $t1->{partial}, 'canvas-text probe ran') or diag('probe returned nothing');
    cmp_ok($t1->{partial}, '>', 0, 'the text render really does produce partial-alpha pixels');
    # Compare against the un-seeded baseline: the engine's own un-premultiply
    # rounding may not match this scan exactly, so what matters is that the
    # perturbation introduces no NEW off-lattice values.
    cmp_ok($t1->{offLattice}, '<=', $tn->{offLattice},
           'perturbation introduces no off-lattice values beyond the host baseline');
    isnt($t1->{hPartial}, $tn->{hPartial},
         'the partial-alpha-only hash differs from the host (antialiased ink IS protected)');
    isnt($t1->{hPartial}, $t2->{hPartial}, 'the partial-alpha-only hash differs across seeds');
    isnt($t1->{hAll}, $tn->{hAll}, 'the whole-canvas fingerprint differs from the host');
}

# --- partial-alpha WebGL readback ---
# Every other GL probe in this file clears with alpha 1, where the premultiplied
# and un-premultiplied step sizes coincide. At LOW alpha they do not: applying the
# canvas-2D lattice formula to a raw framebuffer byte gives a step of 255/a, which
# moved a channel 200 -> 255 and corrupted RGBA-packed readbacks. premultipliedAlpha
# is off so the stored byte can exceed alpha, which is exactly the case that broke.
sub probe_gl_alpha {
    my (%opt) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', %opt);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const cv=document.createElement('canvas'); cv.width=cv.height=8;
          const gl=cv.getContext('webgl',{premultipliedAlpha:false,preserveDrawingBuffer:true});
          if(!gl) return JSON.stringify({hasGL:false});
          gl.clearColor(200/255,100/255,50/255,0.01);
          gl.clear(gl.COLOR_BUFFER_BIT);
          const b=new Uint8Array(8*8*4);
          gl.readPixels(0,0,8,8,gl.RGBA,gl.UNSIGNED_BYTE,b);
          return JSON.stringify({hasGL:true, px:Array.from(b)});
JS
    });
    TWK::run_with_timeout(25);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
{
    my $seeded = probe_gl_alpha(seed => 111);
    my $plain  = probe_gl_alpha();
    ok(exists $seeded->{hasGL}, 'partial-alpha GL probe ran') or diag('probe returned nothing');
    SKIP: {
        skip 'no WebGL in this build', 4 unless $seeded->{hasGL} && $plain->{hasGL};
        my ($s, $p) = ($seeded->{px}, $plain->{px});
        is(scalar(@$s), scalar(@$p), 'both readbacks are the same size');
        my ($maxDelta, $changed, $alphaMoved) = (0, 0, 0);
        for my $i (0 .. $#$p) {
            my $d = abs($s->[$i] - $p->[$i]);
            if ($i % 4 == 3) { $alphaMoved++ if $d; next }   # alpha channel
            $maxDelta = $d if $d > $maxDelta;
            $changed++ if $d;
        }
        # step() applied to a premultiplied byte gives 255/a -- at alpha 0.01 that
        # is a jump of ~55, not 1.
        cmp_ok($maxDelta, '<=', 1,
               'partial-alpha readPixels noise stays within 1 (premultiplied step, not the 2-D lattice step)');
        # ...and skipping partial alpha entirely would leave the readback pristine.
        cmp_ok($changed, '>', 0, 'partial-alpha GL pixels are actually perturbed (not skipped)');
        is($alphaMoved, 0, 'the alpha channel is never perturbed');
    }
}

done_testing;
