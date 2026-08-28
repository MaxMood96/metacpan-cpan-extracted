use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use EV::WebKit::Fingerprint;
plan skip_all => 'web-process extension not built' unless EV::WebKit::Fingerprint::available();

sub caps {
    my ($name) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          var c=document.createElement('canvas'); var gl=c.getContext('webgl')||c.getContext('experimental-webgl');
          if(!gl) return JSON.stringify({hasGL:false});
          var dbg=gl.getExtension('WEBGL_debug_renderer_info');
          var vp=gl.getParameter(3386), pr=gl.getParameter(33901);
          return JSON.stringify({
            hasGL:true,
            maxTex: gl.getParameter(3379),
            viewport: Array.from(vp),
            vpIsInt32: vp instanceof Int32Array,          // real getParameter returns Int32Array here
            ptRange: Array.from(pr),
            prIsFloat32: pr instanceof Float32Array,      // ...and Float32Array here
            attribs: gl.getParameter(34921),
            combined: gl.getParameter(35661),
            version: gl.getParameter(7938),
            renderer: dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : null,
            exts: gl.getSupportedExtensions(),
            prec: (function(){ var p=gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
                               return p ? [p.rangeMin,p.rangeMax,p.precision] : null; })(),
          });
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}

for my $name (qw(windows-chrome macos-safari pixel-chrome)) {
    my $p = EV::WebKit::Fingerprint::resolve($name);
    my $r = caps($name);
    # Without this, a browser/probe failure makes every assertion below skip and
    # the whole file still reports PASS.
    ok(exists $r->{hasGL}, "$name probe ran (WebGL assertions are meaningful)")
        or diag('probe returned nothing');
    SKIP: { skip "no WebGL for $name", 9 unless $r->{hasGL};
        is($r->{maxTex}, $p->{webgl}{params1}{3379}, "$name MAX_TEXTURE_SIZE matches profile");
        is_deeply($r->{viewport}, $p->{webgl}{params1}{3386}, "$name MAX_VIEWPORT_DIMS matches");
        ok($r->{vpIsInt32}, "$name MAX_VIEWPORT_DIMS is an Int32Array (correct typed-array class)");
        is_deeply($r->{ptRange}, $p->{webgl}{params1}{33901}, "$name ALIASED_POINT_SIZE_RANGE matches");
        ok($r->{prIsFloat32}, "$name ALIASED_POINT_SIZE_RANGE is a Float32Array (not Int32Array)");
        is($r->{attribs}, $p->{webgl}{params1}{34921}, "$name MAX_VERTEX_ATTRIBS matches");
        is($r->{version}, $p->{webgl}{params1}{7938}, "$name VERSION string matches");
        is($r->{renderer}, $p->{webgl_renderer}, "$name UNMASKED_RENDERER is coherent with the caps");
        is_deeply($r->{exts}, $p->{webgl}{extensions1}, "$name getSupportedExtensions returns the profile list");
    }
}

# shader precision comes from the profile
{
    my $p = EV::WebKit::Fingerprint::resolve('windows-chrome');
    my $r = caps('windows-chrome');
    SKIP: { skip 'no WebGL', 1 unless $r->{hasGL};
        is_deeply($r->{prec}, $p->{webgl}{precision}{'FRAGMENT.HIGH_FLOAT'},
                  'getShaderPrecisionFormat returns the profile values');
    }
}

# negative control: no fingerprint -> host caps, NOT the spoofed VERSION string
{
    my $b = EV::WebKit->new(window => [200,150]);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $ver;
    $b->go('fp://host/p', sub {
        $b->script('var c=document.createElement("canvas");var gl=c.getContext("webgl")||c.getContext("experimental-webgl");return gl?gl.getParameter(7938):"nogl";',
                   sub { $ver = $_[0]; EV::break });
    });
    TWK::run_with_timeout(20); $b->quit;
    # Anchored, unlike the version this replaces: without it a browser or probe
    # failure made the whole control disappear and the file still reported PASS
    # -- the exact hazard this file warns about at the top.
    ok(defined $ver, 'no fingerprint: the WebGL probe ran');
    SKIP: {
        skip 'no WebGL on this host', 1 if !defined $ver || $ver eq 'nogl';
        unlike($ver, qr/Chromium/, 'no fingerprint: VERSION is the host string, not the spoof');
    }
}
# --- regressions from the round-1 adversarial review ---
# The whole WebGL2 path (params2/extensions2/the isGL2 branch) had NO coverage,
# which is why the 1.0-version-string and ES3-arithmetic defects survived.
sub caps2 {
    my ($name) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          var c=document.createElement('canvas'); var gl=c.getContext('webgl2');
          if(!gl) return JSON.stringify({hasGL2:false});
          var lose=gl.getExtension('WEBGL_lose_context');
          var res={
            hasGL2:true,
            version: gl.getParameter(7938),
            glsl: gl.getParameter(35724),
            fragVec: gl.getParameter(36349), fragComp: gl.getParameter(35657),
            vertVec: gl.getParameter(36347), vertComp: gl.getParameter(35658),
            varyVec: gl.getParameter(36348), varyComp: gl.getParameter(35659),
            exts: gl.getSupportedExtensions(),
            // getExtension must agree with the advertised list, and be identical across calls
            sameObject: gl.getExtension('WEBGL_debug_renderer_info') === gl.getExtension('WEBGL_debug_renderer_info'),
            unadvertised: (function(){ var leaked=[];
              ['WEBGL_compressed_texture_astc','WEBGL_compressed_texture_etc','WEBGL_compressed_texture_etc1',
               'WEBGL_compressed_texture_s3tc','EXT_texture_compression_bptc','WEBGL_debug_shaders'].forEach(function(n){
                if(gl.getSupportedExtensions().indexOf(n)<0 && gl.getExtension(n)) leaked.push(n); });
              return leaked; })(),
            // a precision hit must still be a real WebGLShaderPrecisionFormat
            precIsReal: (function(){ var p=gl.getShaderPrecisionFormat(gl.FRAGMENT_SHADER, gl.HIGH_FLOAT);
              return !!(p && (typeof WebGLShaderPrecisionFormat==='undefined' || p instanceof WebGLShaderPrecisionFormat)); })(),
            precMedInt: (function(){ var p=gl.getShaderPrecisionFormat(gl.VERTEX_SHADER, gl.MEDIUM_INT);
              return p ? [p.rangeMin,p.rangeMax,p.precision] : null; })(),
          };
          if(lose){ lose.loseContext();
            res.lostParam = gl.getParameter(3379);            // a lost context reports null
            res.lostExts  = gl.getSupportedExtensions(); }
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}

for my $name (qw(windows-chrome macos-safari pixel-chrome)) {
    my $p = EV::WebKit::Fingerprint::resolve($name);
    my $r = caps2($name);
    ok(exists $r->{hasGL2}, "$name WebGL2 probe ran");   # anchor: without it a failed probe skips the block and the file still passes
    SKIP: { skip "no WebGL2 for $name", 8 unless $r->{hasGL2};
        is($r->{version}, $p->{webgl}{params2}{7938}, "$name WebGL2 VERSION says 2.0, not 1.0");
        is($r->{glsl}, $p->{webgl}{params2}{35724},   "$name WebGL2 GLSL version is the ES 3.00 string");
        # ES3 mandates *_VECTORS == *_COMPONENTS/4 -- a one-line spec check any page can run
        is($r->{fragComp}, $r->{fragVec}*4, "$name MAX_FRAGMENT_UNIFORM_COMPONENTS == VECTORS*4");
        is($r->{vertComp}, $r->{vertVec}*4, "$name MAX_VERTEX_UNIFORM_COMPONENTS == VECTORS*4");
        is($r->{varyComp}, $r->{varyVec}*4, "$name MAX_VARYING_COMPONENTS == VARYING_VECTORS*4");
        is_deeply($r->{unadvertised}, [], "$name getExtension returns nothing getSupportedExtensions denies");
        ok($r->{sameObject}, "$name getExtension returns the SAME object across calls (spec identity)");
        ok($r->{precIsReal}, "$name getShaderPrecisionFormat still returns a real WebGLShaderPrecisionFormat");
    }
}
{
    my $p = EV::WebKit::Fingerprint::resolve('windows-chrome');
    my $r = caps2('windows-chrome');
    ok(exists $r->{hasGL2}, 'the WebGL2 precision probe ran');   # anchor: without it a failed probe skips the block and the file still passes
    SKIP: { skip 'no WebGL2', 3 unless $r->{hasGL2};
        is_deeply($r->{precMedInt}, $p->{webgl}{precision}{'VERTEX.MEDIUM_INT'},
                  'MEDIUM_INT precision comes from the profile, not the host');
        skip 'no WEBGL_lose_context', 2 unless exists $r->{lostParam};
        is($r->{lostParam}, undef, 'a lost context reports null for getParameter, not the spoof');
        is($r->{lostExts},  undef, 'a lost context reports null for getSupportedExtensions');
    }
}
# Hard-coded expectations: t/A1's other assertions read both sides from %PRESET,
# so a wrong-but-consistent value would pass. These pin actual numbers.
{
    my $r = caps('windows-chrome');
    ok(exists $r->{hasGL}, 'the literal-values probe ran');   # anchor: without it a failed probe skips the block and the file still passes
    SKIP: { skip 'no WebGL', 2 unless $r->{hasGL};
        is($r->{maxTex}, 16384, 'windows-chrome MAX_TEXTURE_SIZE is literally 16384');
        is_deeply($r->{viewport}, [32767,32767], 'windows-chrome MAX_VIEWPORT_DIMS is literally [32767,32767]');
    }
}

# --- regressions from the round-2 adversarial review ---
sub gl_r2 {
    my ($name) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $name);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          var c=document.createElement('canvas'); var gl=c.getContext('webgl');
          if(!gl) return JSON.stringify({hasGL:false});
          var res={hasGL:true};
          // extension names match ASCII case-INSENSITIVELY
          var lcName='oes_texture_float', ucName='OES_TEXTURE_FLOAT';
          var listed=gl.getSupportedExtensions().indexOf('OES_texture_float')>=0;
          res.caseListed=listed;
          res.caseLower=!!gl.getExtension(lcName);
          res.caseUpper=!!gl.getExtension(ucName);
          res.caseSameObj=(gl.getExtension(lcName)===gl.getExtension('OES_texture_float'));
          // an extension pname is invalid until getExtension enables it
          var fresh=document.createElement('canvas').getContext('webgl');
          res.anisoBefore=fresh.getParameter(34047);
          res.errBefore=fresh.getError();
          fresh.getExtension('EXT_texture_filter_anisotropic');
          res.anisoAfter=fresh.getParameter(34047);
          // precision object must have no own properties and stay for..in visible
          var p=gl.getShaderPrecisionFormat(gl.VERTEX_SHADER, gl.HIGH_FLOAT);
          res.precOwn=Object.getOwnPropertyNames(p).length;
          var seen=[]; for(var k in p) seen.push(k);
          res.precForIn=seen.length;
          res.precVals=[p.rangeMin,p.rangeMax,p.precision];
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS; return Cpanel::JSON::XS::decode_json($out // '{}');
}
{
    my $r = gl_r2('windows-chrome');
    ok(exists $r->{hasGL}, 'the readback probe ran');   # anchor: without it a failed probe skips the block and the file still passes
    SKIP: { skip 'no WebGL', 8 unless $r->{hasGL};
        SKIP: { skip 'OES_texture_float not advertised', 3 unless $r->{caseListed};
            ok($r->{caseLower}, 'getExtension matches a lowercase name (spec: ASCII case-insensitive)');
            ok($r->{caseUpper}, 'getExtension matches an uppercase name');
            ok($r->{caseSameObj}, 'casing variants share one memoized object');
        }
        is($r->{anisoBefore}, undef, 'MAX_TEXTURE_MAX_ANISOTROPY_EXT is null before getExtension enables it');
        isnt($r->{errBefore}, 0,     'reading it early still raises INVALID_ENUM as a real context does');
        is($r->{anisoAfter}, 16,     'after getExtension it returns the profile value');
        is($r->{precOwn}, 0,   'precision object has no own properties (values come from the prototype)');
        is($r->{precForIn}, 3, 'precision object still enumerates its three attributes under for..in');
    }
}
# Literal per-family version strings: the assertions above read both sides from
# %PRESET, so a Chromium-flavoured string on a Safari profile would pass.
{
    my %want = (
        'windows-chrome' => ['WebGL 1.0 (OpenGL ES 2.0 Chromium)', 'WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.0 Chromium)'],
        'macos-safari'   => ['WebGL 1.0', 'WebGL GLSL ES 1.0 (1.0)'],
        'iphone-safari'  => ['WebGL 1.0', 'WebGL GLSL ES 1.0 (1.0)'],
        'pixel-chrome'   => ['WebGL 1.0 (OpenGL ES 2.0 Chromium)', 'WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.0 Chromium)'],
    );
    for my $name (sort keys %want) {
        my $p = EV::WebKit::Fingerprint::resolve($name);
        is($p->{webgl}{params1}{7938},  $want{$name}[0], "$name WebGL1 VERSION is the exact real string");
        is($p->{webgl}{params1}{35724}, $want{$name}[1], "$name WebGL1 GLSL version is the exact real string");
    }
    # iphone-safari is otherwise never driven in this file
    my $ip = caps('iphone-safari');
    ok(exists $ip->{hasGL}, 'the iphone-safari probe ran');   # anchor: without it a failed probe skips the block and the file still passes
    SKIP: { skip 'no WebGL for iphone-safari', 1 unless $ip->{hasGL};
        is($ip->{version}, 'WebGL 1.0', 'iphone-safari reports the Apple WebGL1 VERSION live');
    }
}

# --- round-3: GLenum aliasing must not bypass the spoof ---
# GLenum is WebIDL `unsigned long`, so p + 2**32 IS p to the engine. Comparing
# the raw argument let an aliased enum fall through to the real host value.
{
    my $b = EV::WebKit->new(window => [200,150], fingerprint => 'windows-chrome', seed => 111);
    $b->mock_scheme('fp', sub { ('<html><body></body></html>','text/html') });
    my $out;
    $b->go('fp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          var c=document.createElement('canvas'); var gl=c.getContext('webgl');
          if(!gl) return JSON.stringify({hasGL:false});
          var A=4294967296;
          var res={hasGL:true,
            plain: gl.getParameter(7938), aliased: gl.getParameter(7938+A),
            plainTex: gl.getParameter(3379), aliasedTex: gl.getParameter(3379+A)};
          var cv=document.createElement('canvas'); cv.width=cv.height=8;
          var g2=cv.getContext('webgl');
          if(g2){ g2.clearColor(0.25,0.5,0.75,1); g2.clear(g2.COLOR_BUFFER_BIT);
            var h=function(buf){ var s=0; for(var i=0;i<buf.length;i++) s=(Math.imul(s,31)+buf[i])>>>0; return s; };
            var b1=new Uint8Array(8*8*4); g2.readPixels(0,0,8,8,g2.RGBA,g2.UNSIGNED_BYTE,b1);
            var b2=new Uint8Array(8*8*4); g2.readPixels(0,0,8,8,g2.RGBA+A,g2.UNSIGNED_BYTE,b2);
            res.hashPlain=h(b1); res.hashAliased=h(b2); }
          return JSON.stringify(res);
JS
    });
    TWK::run_with_timeout(20); $b->quit;
    require Cpanel::JSON::XS; my $r = Cpanel::JSON::XS::decode_json($out // '{}');
    ok(exists $r->{hasGL}, 'GLenum-aliasing probe ran');
    SKIP: { skip 'no WebGL', 3 unless $r->{hasGL};
        is($r->{aliased}, $r->{plain},       'getParameter(VERSION + 2**32) returns the spoof, not the host value');
        is($r->{aliasedTex}, $r->{plainTex}, 'getParameter(MAX_TEXTURE_SIZE + 2**32) returns the spoof');
        skip 'no readPixels hashes', 1 unless defined $r->{hashPlain};
        # Parity, not noising: both hashes are of a deterministic clear colour,
        # so removing the noise entirely leaves them equal. The noising itself
        # is covered in t/A0-readback-noise.t.
        is($r->{hashAliased}, $r->{hashPlain}, 'readPixels with an aliased format enum takes the same path as the plain one');
    }
}

done_testing;
