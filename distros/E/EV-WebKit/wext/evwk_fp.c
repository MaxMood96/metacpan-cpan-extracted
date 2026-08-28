/* EV::WebKit fingerprint web-process extension.
 * Built WITHOUT webkit/jsc dev headers: the webkit/jsc functions are
 * hand-declared with opaque types and left unresolved at link time; they
 * resolve at dlopen inside the web process (which has libwebkitgtk +
 * libjavascriptcore loaded). glib/gobject come from real headers. */
#include <glib.h>
#include <glib-object.h>

typedef struct _WebKitWebProcessExtension WebKitWebProcessExtension;
typedef struct _WebKitScriptWorld          WebKitScriptWorld;
typedef struct _WebKitWebPage              WebKitWebPage;
typedef struct _WebKitFrame                WebKitFrame;
typedef struct _JSCContext                 JSCContext;
typedef struct _JSCValue                   JSCValue;

extern WebKitScriptWorld *webkit_script_world_get_default (void);
extern JSCContext        *webkit_frame_get_js_context_for_script_world (WebKitFrame *, WebKitScriptWorld *);
extern JSCValue          *jsc_context_get_global_object (JSCContext *);
extern JSCValue          *jsc_context_evaluate (JSCContext *, const char *, gssize);
/* Frame addressing over WebKitUserMessage. Declared here rather than included
   for the same reason as everything above: this file is built without webkit
   dev headers and these resolve at dlopen inside the web process. */
typedef struct _WebKitUserMessage           WebKitUserMessage;
typedef struct _JSCException                JSCException;
extern guint64            webkit_frame_get_id (WebKitFrame *);
extern const char        *webkit_frame_get_uri (WebKitFrame *);
extern gboolean           webkit_frame_is_main_frame (WebKitFrame *);
extern const char        *webkit_user_message_get_name (WebKitUserMessage *);
extern GVariant          *webkit_user_message_get_parameters (WebKitUserMessage *);
extern void               webkit_user_message_send_reply (WebKitUserMessage *, WebKitUserMessage *);
extern WebKitUserMessage *webkit_user_message_new (const char *, GVariant *);
extern JSCException      *jsc_context_get_exception (JSCContext *);
extern void               jsc_context_clear_exception (JSCContext *);
extern const char        *jsc_exception_get_message (JSCException *);
extern char              *jsc_value_to_string (JSCValue *);
extern gboolean           jsc_value_is_string (JSCValue *);
extern gboolean           jsc_value_to_boolean (JSCValue *);
extern WebKitScriptWorld *webkit_script_world_new_with_name (const char *);
static void               frames_remember (WebKitFrame *);
static char              *EVWK_BOOT;   /* the find() registry bootstrap, handed over by the UI process */
extern void               jsc_value_object_define_property_accessor (
                              JSCValue *, const char *name, int flags, GType type,
                              GCallback getter, GCallback setter, gpointer user_data, GDestroyNotify destroy);
extern JSCValue          *jsc_value_new_string (JSCContext *, const char *);
extern void               jsc_value_object_set_property (JSCValue *, const char *, JSCValue *);
#define JSC_VALUE_PROPERTY_CONFIGURABLE 1
#define JSC_VALUE_PROPERTY_ENUMERABLE   2
/* Real WebIDL attributes (navigator.platform, screen.width, ...) are enumerable
 * AND configurable getters on their PROTOTYPE. We redefine them there with the
 * same flags so the spoof is indistinguishable: not an own property of the
 * instance (hasOwnProperty stays false), enumerable in for-in/Object.keys, and
 * -- because we replace the prototype getter itself -- not recoverable via
 * Object.getOwnPropertyDescriptor(proto,name).get.call(navigator). */
#define EVWK_FLAGS (JSC_VALUE_PROPERTY_CONFIGURABLE | JSC_VALUE_PROPERTY_ENUMERABLE)

/* WebGL getParameter is a METHOD; a native replacement cannot delegate the
 * non-spoofed pnames because a pure-C JSC function never receives `this`. So we
 * install a thin JS wrapper (which captures `this` and delegates correctly),
 * defined as a method shorthand so it has NO `.prototype` (matching a real
 * native method). It carries NO own `toString` mask: such a mask defeats only a
 * plain fn.toString() check -- Function.prototype.toString.call bypasses an own
 * property and reveals the wrapper anyway -- while leaving an artifact no real
 * function has, which Object.keys enumerates across the whole JS layer with no
 * false positives. Values are spoofed and WebGL stays usable; either form of
 * toString check can spot the wrapper (documented ceiling). The two
 * spoofed strings arrive via temporary globals we set from C and the wrapper
 * deletes. UNMASKED_VENDOR_WEBGL=0x9245, RENDERER=0x9246. */
static const char *WEBGL_WRAPPER_JS =
    "(function(){"
    "  var V=window.__evwk_wv, R=window.__evwk_wr;"
    "  delete window.__evwk_wv; delete window.__evwk_wr;"
    "  var W=null; try{ W=JSON.parse(window.__evwk_cfg).webgl||null; }catch(e){}"
    "  function bind(w){ return w; }"
    "  var stubs=new WeakMap(), enabled=new WeakMap();"
    "  function markEnabled(ctx,key){ var s=enabled.get(ctx); if(!s){ s=Object.create(null); enabled.set(ctx,s); } s[key]=1; }"
    "  function enabledOn(ctx,key){ var s=enabled.get(ctx); return !!(s && s[key]); }"
    /* Spoofed precision values are stored per returned object and served by
     * accessors redefined on WebGLShaderPrecisionFormat.PROTOTYPE. Defining them
     * as own properties on the instance left rangeMin/rangeMax/precision visible
     * to getOwnPropertyNames (real: []) and, being non-enumerable own properties,
     * made for..in skip them entirely (real: all three). */
    "  var precOver=new WeakMap();"
    /* Built with get-shorthand so each replacement getter has the real one's
     * `name` ("get rangeMin") and NO .prototype -- a plain function expression
     * has name "" and carries a .prototype, both cheaper tells than the toString
     * mask exists to defeat. Installed lazily so a page that never calls
     * getShaderPrecisionFormat leaves the native prototype pristine. */
    "  var precPatched=false;"
    "  function patchPrec(){"
    "    if(precPatched) return; precPatched=true;"
    "    var S=window.WebGLShaderPrecisionFormat; if(!S||!S.prototype) return;"
    "    [['rangeMin',0],['rangeMax',1],['precision',2]].forEach(function(kv){"
    "      var k=kv[0], idx=kv[1];"
    "      var d=Object.getOwnPropertyDescriptor(S.prototype,k); if(!d||!d.get) return;"
    "      var og=d.get, holder;"
    "      if(idx===0) holder={ get rangeMin(){ var v=precOver.get(this); return v ? v[0] : og.call(this); } };"
    "      else if(idx===1) holder={ get rangeMax(){ var v=precOver.get(this); return v ? v[1] : og.call(this); } };"
    "      else holder={ get precision(){ var v=precOver.get(this); return v ? v[2] : og.call(this); } };"
    "      var ng=Object.getOwnPropertyDescriptor(holder,k).get;"
    "      Object.defineProperty(S.prototype,k,{enumerable:d.enumerable,configurable:true,get:ng}); }); }"
    "  function conv(p,val){"                       /* typed-array class is per-PNAME, not per-value */
    "    if(!Array.isArray(val)) return val;"
    "    var isF = (p===33901 || p===33902 || p===2928);"  /* ALIASED_POINT/LINE_WIDTH_RANGE, DEPTH_RANGE -> Float32Array */
    "    return isF ? new Float32Array(val) : new Int32Array(val); }"  /* MAX_VIEWPORT_DIMS etc -> Int32Array */
    "  function patch(proto, isGL2){"
    "    if(!proto||!proto.getParameter) return;"
    "    var pm = W ? Object.assign({}, W.params1, isGL2?W.params2:null) : null;"
    "    var gp=proto.getParameter;"
    "    proto.getParameter=bind(({ getParameter(p){"
    /* GLenum is WebIDL `unsigned long`, so the engine applies ToUint32 and
     * p + 2**32 IS p. Comparing the RAW argument let an aliased enum miss every
     * table and fall through to the real host value -- a one-line, total bypass
     * of the spoof. Normalize exactly as the engine does. */
    "      p = p >>> 0;"
    "      if(this.isContextLost && this.isContextLost()) return gp.apply(this, arguments);"  /* a lost context returns null for everything */
    /* An extension's pnames are only valid once getExtension() has enabled it on
     * this context; answering earlier both leaks a value a real context withholds
     * and suppresses the INVALID_ENUM it would set. Delegating reproduces both. */
    "      if((p===37445||p===37446) && !enabledOn(this,'webgl_debug_renderer_info')) return gp.apply(this, arguments);"
    "      if(p===34047 && !enabledOn(this,'ext_texture_filter_anisotropic')) return gp.apply(this, arguments);"
    "      if(R!==undefined && p===37446) return R;"
    "      if(V!==undefined && p===37445) return V;"
    "      if(pm && Object.prototype.hasOwnProperty.call(pm,p)){ var v=pm[p];"
    "        return (typeof v==='number'||typeof v==='string') ? v : conv(p,v); }"
    "      return gp.apply(this, arguments);"
    "    } }).getParameter, gp);"
    "    if(W && W.extensions1){ var exts=(isGL2?W.extensions2:W.extensions1)||[];"
    "      var gse=proto.getSupportedExtensions;"
    "      proto.getSupportedExtensions=bind(({ getSupportedExtensions(){"
    "        if(this.isContextLost && this.isContextLost()) return gse.apply(this, arguments);"
    "        return exts.slice(); } }).getSupportedExtensions, gse);"
    "      var ge=proto.getExtension;"
    /* WebGL matches extension names ASCII case-INSENSITIVELY, so normalize before
     * both the advertised-list check and the memo key -- an exact-case match made
     * getExtension('oes_texture_float') return null while getSupportedExtensions()
     * listed it, which no real browser does. */
    "      var lc={}; exts.forEach(function(n){ lc[String(n).toLowerCase()]=n; });"
    "      proto.getExtension=bind(({ getExtension(name){"
    "        if(arguments.length===0) throw new TypeError(\"Failed to execute 'getExtension' on 'WebGLRenderingContext': 1 argument required, but only 0 present.\");"
    "        if(this.isContextLost && this.isContextLost()) return ge.apply(this, arguments);"
    "        var key=String(name).toLowerCase();"
    /* The ADVERTISED list is authoritative and must be consulted FIRST. Asking the
     * host first leaks extensions getSupportedExtensions() denies -- e.g. an
     * "Apple GPU" profile handing out S3TC/BPTC, or Chrome-only WEBGL_debug_shaders
     * on a Safari profile -- which is both impossible for the claimed device and a
     * direct self-contradiction. */
    "        if(!Object.prototype.hasOwnProperty.call(lc,key)) return null;"
    "        markEnabled(this,key);"
    "        var real=ge.apply(this, arguments); if(real) return real;"
    /* The spec requires repeated getExtension() calls to return the SAME object,
     * so memoize per context+normalized name rather than minting a fresh stub. */
    "        var byName=stubs.get(this); if(!byName){ byName=Object.create(null); stubs.set(this, byName); }"
    "        if(byName[key]) return byName[key];"
    "        var stub;"
    "        if(key==='webgl_debug_renderer_info') stub={UNMASKED_VENDOR_WEBGL:37445, UNMASKED_RENDERER_WEBGL:37446};"
    "        else if(key==='ext_texture_filter_anisotropic'||key==='moz_ext_texture_filter_anisotropic'||key==='webkit_ext_texture_filter_anisotropic')"
    "          stub={TEXTURE_MAX_ANISOTROPY_EXT:34046, MAX_TEXTURE_MAX_ANISOTROPY_EXT:34047};"
    "        else if(key==='webgl_depth_texture'||key==='webkit_webgl_depth_texture') stub={UNSIGNED_INT_24_8_WEBGL:34042};"
    "        else if(key==='ovr_multiview2') stub={FRAMEBUFFER_ATTACHMENT_TEXTURE_NUM_VIEWS_OVR:38448, FRAMEBUFFER_ATTACHMENT_TEXTURE_BASE_VIEW_INDEX_OVR:38450, MAX_VIEWS_OVR:38449, FRAMEBUFFER_INCOMPLETE_VIEW_TARGETS_OVR:38451};"
    "        else stub={};"                                                  /* advertised but absent: see the Ceiling POD */
    "        byName[key]=stub; return stub;"
    "      } }).getExtension, ge);"
    "    }"
    "    if(W && W.precision && proto.getShaderPrecisionFormat){"
    "      var ST={35633:'VERTEX',35632:'FRAGMENT'}, PT={36336:'LOW_FLOAT',36337:'MEDIUM_FLOAT',36338:'HIGH_FLOAT',36339:'LOW_INT',36340:'MEDIUM_INT',36341:'HIGH_INT'};"
    "      var gspf=proto.getShaderPrecisionFormat;"
    "      proto.getShaderPrecisionFormat=bind(({ getShaderPrecisionFormat(shadertype,precisiontype){"
    "        var r=gspf.apply(this, arguments);"
    "        var key=(ST[shadertype>>>0]||'')+'.'+(PT[precisiontype>>>0]||''); var v=W.precision[key];"   /* ToUint32, as GLenum requires */
    /* Shadow the values on the REAL object: returning a plain {} here while the
     * fall-through path returned a WebGLShaderPrecisionFormat made the same method
     * return two different types depending on its arguments. */
    "        if(!r || !v) return r;"
    "        patchPrec();"                           /* install the prototype accessors on first real use */
    "        precOver.set(r, v);"                    /* no own properties on the instance */
    "        return r;"
    "      } }).getShaderPrecisionFormat, gspf);"
    "    }"
    "  }"
    "  patch(window.WebGLRenderingContext && window.WebGLRenderingContext.prototype, false);"
    "  patch(window.WebGL2RenderingContext && window.WebGL2RenderingContext.prototype, true);"
    "})();";

/* Readback noise (opt-in via seed). A content-INDEPENDENT perturbation keyed on
 * ABSOLUTE canvas/GL coordinates (pixels) or the absolute frame index (audio), so
 * the same sample re-read through any API, rectangle or offset yields the same
 * value, yet the LSBs no longer match the true host output (hides llvmpipe).
 *
 * This string contains NO printf conversions and must never contain any: it is
 * passed as a %s ARGUMENT to a literal format (see on_window_object_cleared), and
 * the seed arrives as the function parameter SEED. That keeps a future edit --
 * e.g. writing `i % 4` in the JS -- from being read as a format specifier. */
static const char *NOISE_JS_BODY =
    "  SEED=SEED>>>0;"
    "  function mix(a){"                             /* mulberry32 step -> 0 or 1 */
    "    var t=a|0;"
    "    t=Math.imul(t ^ (t>>>15), t|1);"
    "    t ^= t + Math.imul(t ^ (t>>>7), t|61);"
    "    return ((t ^ (t>>>14))>>>0) & 1; }"
    "  function nz(i){ return mix(SEED + Math.imul(i,0x6D2B79F5)); }"   /* 1-D: absolute audio frame index */
    "  function nzxy(x,y,c){"                        /* 2-D: absolute pixel coordinate + channel */
    "    return mix(SEED + Math.imul(x,0x6D2B79F5) + Math.imul(y,0x85EBCA6B) + Math.imul(c,0x27D4EB2F)); }"
    "  function bind(w){ return w; }"
    /* Only fully OPAQUE pixels may be perturbed. Canvas backing stores are
     * premultiplied, so getImageData un-premultiplies and, for alpha a, the only
     * reachable channel values are {round(p*255/a)} -- a lattice that grows
     * sparser as a falls. Flipping an LSB lands off that lattice for most
     * partial-alpha pixels, which any antialiased edge or text glyph produces, so
     * a detector can test lattice membership with no knowledge of the content.
     * alpha==255 is the one case where every 0..255 value is reachable.
     * `flip` keys by DESCENDING row: WebGL readPixels is bottom-left origin while
     * canvas 2D is top-left, and the same physical pixel must get the same bit
     * through either API. */
    /* For alpha a, un-premultiplying makes only {round(p*255/a) : 0<=p<=a}
     * reachable, so flipping an LSB would land off that lattice. Skipping those
     * pixels instead left the classic canvas fingerprint (text on a transparent
     * canvas is ~90% antialiased edge) completely unprotected -- its hash was
     * identical with and without a seed. So perturb by stepping to an ADJACENT
     * LATTICE POINT: always a value the device could really produce. */
    /* step a PREMULTIPLIED byte (0..a) by one -- the WebGL readback path */
    "  function stepP(p,a,d){"
    "    if(!d) return p;"
    "    if(a===255) return p ^ 1;"
    "    var q=(p<a)?p+1:p-1;"
    "    return q<0 ? 0 : q; }"
    "  function step(v,a,d){"
    "    if(!d) return v;"
    "    if(a===255) return v ^ 1;"
    "    var p=Math.round(v*a/255);"
    "    p = (p<a) ? p+1 : p-1;"
    "    if(p<0) p=0;"
    "    return Math.round(p*255/a); }"
    "  function perturbRect(data,ox,oy,w,h,off,flip){"   /* perturb R,G,B; never A */
    "    off=off||0;"
    "    for(var py=0;py<h;py++){ var ry = flip ? (oy-py) : (oy+py);"
    "      for(var px=0;px<w;px++){ var i=off+(py*w+px)*4, a=data[i+3];"
    "        if(a===0) continue;"                          /* premultiplied: alpha 0 forces rgb 0 */
    /* `flip` marks the WebGL path, whose bytes ARE the premultiplied values --
     * exactly the `p` that the 2-D path recovers with round(v*a/255). So step p
     * by one directly here and let the 2-D path step its recovered p by one:
     * both perturb the same underlying quantity, which keeps
     * getImageData(drawImage(glCanvas)) consistent with readPixels for the same
     * physical pixel. (Applying the 2-D lattice formula to a premultiplied byte
     * was wrong -- step 255/a, up to a full byte -- and skipping partial alpha
     * here instead broke that cross-API invariant the other way.) */
    "        if(flip){"
    "          data[i]=stepP(data[i],a,nzxy(ox+px,ry,0));"
    "          data[i+1]=stepP(data[i+1],a,nzxy(ox+px,ry,1));"
    "          data[i+2]=stepP(data[i+2],a,nzxy(ox+px,ry,2));"
    "          continue; }"
    "        data[i]=step(data[i],a,nzxy(ox+px,ry,0));"
    "        data[i+1]=step(data[i+1],a,nzxy(ox+px,ry,1));"
    "        data[i+2]=step(data[i+2],a,nzxy(ox+px,ry,2)); } }"
    "    return data; }"
    "  var C2 = window.CanvasRenderingContext2D && window.CanvasRenderingContext2D.prototype;"
    "  var OC2 = window.OffscreenCanvasRenderingContext2D && window.OffscreenCanvasRenderingContext2D.prototype;"
    "  function wrapGID(proto){"                     /* OffscreenCanvas is a SEPARATE interface -- wrapping only */
    "    if(!proto || !proto.getImageData) return;"  /* the HTML one leaves a complete, diffable bypass */
    "    var o=proto.getImageData;"
    "    proto.getImageData=bind(({ getImageData(sx,sy,sw,sh){ var im=o.apply(this,arguments);"
    "      sx=sx|0; sy=sy|0; sw=sw|0; sh=sh|0;"      /* WebIDL truncates to long BEFORE a negative extent is normalized */
    "      perturbRect(im.data, (sw<0?sx+sw:sx), (sh<0?sy+sh:sy), im.width, im.height); return im; } }).getImageData, o);"
    "  }"
    "  wrapGID(C2); wrapGID(OC2);"
    /* Encode through an offscreen copy read back with the ALREADY-WRAPPED
     * getImageData, so the encoded image carries exactly the noise a direct
     * getImageData reports -- the two can never disagree. Covers WebGL sources. */
    "  function noisyCopy(canvas){"
    "    var w=canvas.width, h=canvas.height;"
    "    var off=(window.OffscreenCanvas && canvas instanceof window.OffscreenCanvas)"
    "      ? new OffscreenCanvas(w,h)"
    "      : (function(){ var c=document.createElement('canvas'); c.width=w; c.height=h; return c; })();"
    "    var octx=off.getContext('2d');"
    "    octx.drawImage(canvas,0,0);"
    "    octx.putImageData(octx.getImageData(0,0,w,h),0,0); return off; }"
    "  var HC = window.HTMLCanvasElement && window.HTMLCanvasElement.prototype;"
    "  if(HC && HC.toDataURL){"
    "    var tdu=HC.toDataURL;"
    "    HC.toDataURL=bind(({ toDataURL(){ try{ return tdu.apply(noisyCopy(this),arguments); }catch(e){ return tdu.apply(this,arguments); } } }).toDataURL, tdu);"
    "  }"
    "  if(HC && HC.toBlob){"
    "    var tb=HC.toBlob;"                          /* callback named so Function.length matches the real 1 */
    "    HC.toBlob=bind(({ toBlob(callback){ try{ return tb.apply(noisyCopy(this),arguments); }catch(e){ return tb.apply(this,arguments); } } }).toBlob, tb);"
    "  }"
    "  var OCp = window.OffscreenCanvas && window.OffscreenCanvas.prototype;"
    "  if(OCp && OCp.convertToBlob){"
    "    var ctb=OCp.convertToBlob;"
    "    OCp.convertToBlob=bind(({ convertToBlob(){ try{ return ctb.apply(noisyCopy(this),arguments); }catch(e){ return ctb.apply(this,arguments); } } }).convertToBlob, ctb);"
    "  }"
    "  function sgn(i){ return nz(i) ? 1 : -1; }"
    /* ONLY buffers the engine RENDERED are noised -- never one the page authored.
     * Perturbing an author's buffer made a fresh createBuffer() read non-zero
     * (spec says all-zero) and broke copyToChannel/copyFromChannel round-tripping,
     * i.e. it silently corrupted real audio data. The fingerprinting vector is the
     * rendered output, so mark buffers from startRendering/decodeAudioData. */
    "  var rendered=new WeakSet();"
    "  function markRendered(p){ return (p && typeof p.then==='function')"
    "    ? p.then(function(b){ if(b) rendered.add(b); return b; }) : p; }"
    "  var OACp = window.OfflineAudioContext && window.OfflineAudioContext.prototype;"
    "  if(OACp && OACp.startRendering){ var sr=OACp.startRendering;"
    "    OACp.startRendering=bind(({ startRendering(){ return markRendered(sr.apply(this,arguments)); } }).startRendering, sr); }"
    "  var BACp = window.BaseAudioContext && window.BaseAudioContext.prototype;"
    "  if(BACp && BACp.decodeAudioData){ var dad=BACp.decodeAudioData;"
    "    BACp.decodeAudioData=bind(({ decodeAudioData(audioData){ return markRendered(dad.apply(this,arguments)); } }).decodeAudioData, dad); }"
    /* Noise the live channel ONCE, then let both read APIs observe that same
     * buffer. Adding noise separately in copyFromChannel would double-apply it
     * (order-dependent) and ignore bufferOffset, so the two APIs would disagree
     * about the same frame. */
    "  var AB = window.AudioBuffer && window.AudioBuffer.prototype;"
    "  if(AB && AB.getChannelData){"
    "    var gcd=AB.getChannelData, noised=new WeakSet();"
    "    var ensure=function(buf,ch){ var a=gcd.call(buf,ch);"
    "      if(rendered.has(buf) && !noised.has(a)){ noised.add(a); for(var i=0;i<a.length;i++) a[i]+=sgn(i)*1e-7; } return a; };"
    "    AB.getChannelData=bind(({ getChannelData(channel){ return ensure(this,channel); } }).getChannelData, gcd);"
    "    if(AB.copyFromChannel){ var cfc=AB.copyFromChannel;"
    "      AB.copyFromChannel=bind(({ copyFromChannel(destination,channelNumber){ ensure(this,channelNumber);"
    "        return cfc.apply(this,arguments); } }).copyFromChannel, cfc); }"
    "  }"
    "  var AN = window.AnalyserNode && window.AnalyserNode.prototype;"
    "  if(AN){"
    "    if(AN.getFloatFrequencyData){ var gff=AN.getFloatFrequencyData;"   /* -Infinity + eps stays -Infinity */
    "      AN.getFloatFrequencyData=bind(({ getFloatFrequencyData(array){ gff.apply(this,arguments); for(var i=0;i<array.length;i++) array[i]+=sgn(i)*1e-4; } }).getFloatFrequencyData, gff); }"
    /* The time-domain reader is an equivalent readback path on the SAME node;
     * leaving it raw both hands back un-noised samples and makes one interface
     * internally asymmetric. The byte variant stays derived, as for frequency. */
    "    if(AN.getFloatTimeDomainData){ var gft=AN.getFloatTimeDomainData;"
    "      AN.getFloatTimeDomainData=bind(({ getFloatTimeDomainData(array){ gft.apply(this,arguments); for(var i=0;i<array.length;i++) array[i]+=sgn(i)*1e-7; } }).getFloatTimeDomainData, gft); }"
    /* The byte reader is deliberately NOT perturbed independently: the spec ties
     * it to the float spectrum (byte = floor(255/(max-min)*(dB-min))), so an
     * independent LSB draw made the two readers contradict each other on ~half the
     * bins carrying signal. The float perturbation is far below byte quantization,
     * so leaving the byte path alone keeps them consistent. */
    "  }"
    "  function patchRP(proto){"
    "    if(!proto||!proto.readPixels) return; var rp=proto.readPixels;"
    "    proto.readPixels=bind(({ readPixels(x,y,width,height,format,type,pixels){ rp.apply(this,arguments);"
    "      var dstOffset=arguments.length>7 ? (arguments[7]|0) : 0;"        /* WebGL2 overload writes at an offset */
    "      if(pixels && pixels.BYTES_PER_ELEMENT===1 && (format>>>0)===6408 && pixels.length>=dstOffset+width*height*4){"  /* ToUint32: format+2**32 is format */
    "        var H=this.drawingBufferHeight|0;"                             /* GL y is bottom-left; convert to canvas rows */
    "        perturbRect(pixels, x|0, H-1-(y|0), width|0, height|0, dstOffset, true); } } }).readPixels, rp); }"
    "  patchRP(window.WebGLRenderingContext && window.WebGLRenderingContext.prototype);"
    "  patchRP(window.WebGL2RenderingContext && window.WebGL2RenderingContext.prototype);";

/* JS-layer coherence (window.chrome, navigator.userAgentData, matchMedia,
 * ontouchstart) installed from a JSON config the extension evals. These are
 * JS objects / method wrappers (not native getters) -- same detectability
 * ceiling as the WebGL wrapper: JS source under either form of toString check,
 * and no own-toString mask (see the WEBGL_WRAPPER_JS comment for why). */
static const char *COHERENCE_JS =
    "(function(){"
    "  var cfg; try { cfg=JSON.parse(window.__evwk_cfg); } catch(e){ return; }"
    "  function bindTS(w){ return w; }"
    "  if(cfg.chrome){ try{ window.chrome={"       /* the three properties a real Chrome page exposes (no bare runtime:{} tell) */
    "    app:{isInstalled:false,InstallState:{DISABLED:'disabled',INSTALLED:'installed',NOT_INSTALLED:'not_installed'},RunningState:{CANNOT_RUN:'cannot_run',READY_TO_RUN:'ready_to_run',RUNNING:'running'}},"
    "    csi(){ return {onloadT:Date.now(),startE:Date.now(),pageT:0,tran:15}; },"   /* shorthand -> no .prototype, like the real native binding */
    "    loadTimes(){ var t=Date.now()/1000; return {requestTime:t,startLoadTime:t,commitLoadTime:t,finishDocumentLoadTime:t,finishLoadTime:t,firstPaintTime:t,firstPaintAfterLoadTime:0,navigationType:'Other',wasFetchedViaSpdy:true,wasNpnNegotiated:true,npnNegotiatedProtocol:'h2',wasAlternateProtocolAvailable:false,connectionInfo:'h2'}; }"
    "  }; }catch(e){} }"
    "  if(cfg.ua_data){"
    /* Real Chrome returns a FrozenArray of frozen dictionaries; ours was mutable
     * and shared, so a script that merely sorted or normalised the list poisoned
     * the spoof permanently for every later read. */
    "    var froz=function(a){ try{ (a||[]).forEach(function(e){ Object.freeze(e); }); return Object.freeze(a); }catch(e){ return a; } };"
    "    var u=cfg.ua_data, brands=froz(u.brands||[]), fvl=froz(u.fullVersionList||u.brands||[]);"
    "    var low={brands:brands,mobile:!!u.mobile,platform:u.platform||''};"
    "    var high={architecture:u.architecture||'',bitness:u.bitness||'',model:u.model||'',"
    "      platformVersion:u.platformVersion||'',uaFullVersion:u.uaFullVersion||'',fullVersionList:fvl,wow64:false};"
    /* Shaped as a real WebIDL interface, not an object literal: a plain literal
     * reported [object Object] instead of [object NavigatorUAData], exposed its
     * members as own enumerable keys (real: all on the prototype, Object.keys []),
     * and left window.NavigatorUAData undefined -- on the single most-probed
     * Chrome-only object. */
    "    var UAD=function NavigatorUAData(){ throw new TypeError('Illegal constructor'); };"
    "    UAD.prototype=Object.create(Object.prototype,{constructor:{value:UAD,writable:true,configurable:true}});"
    "    try{ Object.defineProperty(UAD.prototype,Symbol.toStringTag,{value:'NavigatorUAData',configurable:true}); }catch(e){}"
    "    [['brands',brands],['mobile',!!u.mobile],['platform',u.platform||'']].forEach(function(kv){"
    "      Object.defineProperty(UAD.prototype,kv[0],{get:function(){ return kv[1]; },enumerable:true,configurable:true}); });"
    /* method shorthand -> no .prototype, matching a real native method */
    /* A promise-returning WebIDL operation converts a throw into a REJECTION; a
     * synchronous throw escapes .catch() and is a one-line tell besides. The
     * required-argument check has to reject for the same reason. */
    "    var uaM={ getHighEntropyValues(hints){"
    "        if(arguments.length===0) return Promise.reject(new TypeError(\"Failed to execute 'getHighEntropyValues' on 'NavigatorUAData': 1 argument required, but only 0 present.\"));"
    /* `hints` is a required sequence<DOMString>: a falsy non-iterable must
     * REJECT, not be quietly coerced to []. `(hints||[])` made
     * getHighEntropyValues(undefined) resolve while the 0-argument call
     * rejected -- impossible under WebIDL. Array.from accepts a string or any
     * iterable, as Chrome does. */
    "        try{ if(hints===null||hints===undefined||typeof hints[Symbol.iterator]!=='function')"
    "               return Promise.reject(new TypeError(\"Failed to execute 'getHighEntropyValues' on 'NavigatorUAData': The provided value cannot be converted to a sequence.\"));"
    "             var out=Object.assign({},low); Array.from(hints).forEach(function(h){ if(h in high) out[h]=high[h]; }); return Promise.resolve(out); }"
    "        catch(e){ return Promise.reject(e); } },"
    "              toJSON(){ return Object.assign({},low); } };"
    "    Object.defineProperty(UAD.prototype,'getHighEntropyValues',{value:uaM.getHighEntropyValues,enumerable:true,writable:true,configurable:true});"
    "    Object.defineProperty(UAD.prototype,'toJSON',{value:uaM.toJSON,enumerable:true,writable:true,configurable:true});"
    "    try{ if(!('NavigatorUAData' in window)) Object.defineProperty(window,'NavigatorUAData',{value:UAD,writable:true,enumerable:false,configurable:true}); }catch(e){}"
    "    var uaData=Object.create(UAD.prototype);"
    "    try{ Object.defineProperty(Navigator.prototype,'userAgentData',{get(){return uaData;},enumerable:true,configurable:true}); }catch(e){}"
    "  }"
    "  if(cfg.media){"
    "    var m=cfg.media;"
    "    var has=function(o,k){ return Object.prototype.hasOwnProperty.call(o,k); };"
    /* Tokenize on the LIGHTLY normalized query (lowercased, whitespace collapsed
     * but PRESERVED). Stripping whitespace outright welds 'screen and (...)' into
     * 'screenand(...)' so no word-boundary split can find the keyword -- and
     * splitting on the bare substring instead shreds values that legitimately
     * contain "and" (landscape, standard, standalone). Every clause we delegate
     * is delegated in THIS form, never a space-stripped one, so
     * `calc(50px + 10px)` survives. */
    "    var lite=function(q){ return String(q).toLowerCase().replace(/\\s+/g,' ').trim(); };"
    /* Split only at PAREN DEPTH 0. A plain split cut inside a nested condition,
     * so '((hover: none) or (hover: hover))' -- a tautology -- was shredded into
     * fragments and a conjunction containing it went false. The comma/or level,
     * the `and` level and the range-operator tokenizer below all need this; a
     * depth-blind split is what made every earlier tokenizer fix regress
     * something. */
    "    var splitTop=function(s,re){"
    "      var out=[], buf='', d=0, i=0;"
    "      while(i<s.length){"
    "        var ch=s.charAt(i);"
    "        if(ch==='('){ d++; }"
    "        else if(ch===')'){ if(d>0) d--; }"
    "        else if(d===0){"
    "          var mt=re.exec(s.slice(i));"
    "          if(mt && mt.index===0 && mt[0].length){ out.push(buf); buf=''; i+=mt[0].length; continue; } }"
    "        buf+=ch; i++; }"
    "      out.push(buf); return out; };"
    /* ---- the spoofed device ----
     * Read the SPOOFED accessors (they are the native C ones), never a second
     * copy of the profile: screen.width/height and devicePixelRatio are already
     * installed, and re-deriving them here is how the two layers drift apart.
     * dppx falls back to devicePixelRatio so a profile that pins a dpr without a
     * media block still answers resolution queries coherently instead of handing
     * back the host's. */
    "    var sdim=function(k){ var s=window.screen; if(!s) return null;"
    "      var v=(k==='width')?s.width:s.height;"
    "      return (typeof v==='number'&&isFinite(v)&&v>0)?v:null; };"
    "    var dppx=function(){ var d=m.dppx;"
    "      if(typeof d!=='number'||!isFinite(d)||d<=0) d=window.devicePixelRatio;"
    "      return (typeof d==='number'&&isFinite(d)&&d>0)?d:null; };"
    /* ---- <length> resolution ----
     * Hard-coding `px` let an em/pt/in/rem binary search over device-width walk
     * straight past the spoof and recover the REAL host geometry. The absolute
     * units are a fixed table; anything else (em/rem/ex/ch/vw..., calc(), min(),
     * max()) is resolved BY THE ENGINE with the oracle below, and a value the
     * engine cannot resolve either yields null -- delegate -- rather than an
     * answer that is confidently wrong. */
    "    var ABS={px:1,pt:96/72,pc:16,in:96,cm:96/2.54,mm:96/25.4,q:96/101.6};"
    "    var vpKey='', lenC={}, lenN=0, unitC={}, zero;"
    /* Lengths are cached, but vw/vh (and the viewport baseline the oracle
     * subtracts) move with the window, so the caches are keyed to the viewport
     * size and dropped when it changes. */
    "    var fresh=function(){ var k=window.innerWidth+'x'+window.innerHeight;"
    "      if(k!==vpKey){ vpKey=k; lenC={}; lenN=0; unitC={}; zero=undefined; } };"
    /* '(max-width: calc(E - Npx))' matches exactly while N <= E - viewport, so
     * the largest such N is E minus the viewport and the DIFFERENCE of two
     * probes is E in px -- computed by the engine itself, which is why every
     * unit and every math function it understands resolves and nothing has to be
     * re-implemented here. A value it rejects has no such N (the probe is
     * constant), and thr returns null. */
    "    var pr=function(e,n){ var r;"
    "      try{ r=orig.call(window,'(max-width:calc('+e+' - '+n.toFixed(6)+'px))'); }catch(x){ return false; }"
    "      return !!(r&&r.matches); };"
    "    var thr=function(e){ var lo=-1, hi=1, i;"
    "      for(i=0;i<44&&!pr(e,lo);i++) lo*=2;"
    "      if(!pr(e,lo)) return null;"
    "      for(i=0;i<44&&pr(e,hi);i++) hi*=2;"
    "      if(pr(e,hi)) return null;"
    "      for(i=0;i<44;i++){ var mid=(lo+hi)/2; if(pr(e,mid)) lo=mid; else hi=mid; }"
    "      return lo; };"
    "    var pxOf=function(e){ if(zero===undefined) zero=thr('0px');"
    "      if(zero===null) return null;"
    "      var v=thr(e); return v===null?null:v-zero; };"
    /* Only a single, fully balanced function token is ever interpolated into the
     * probe query -- otherwise a crafted value could close the parenthesis and
     * rewrite the query we are asking the engine. */
    "    var okFn=function(v){"
    "      if(!/^[a-z-]+\\([\\s\\S]*\\)$/.test(v)) return false;"
    "      if(/[;{}@\"'\\\\]/.test(v)) return false;"
    "      var d=0,i;"
    "      for(i=0;i<v.length;i++){ var c=v.charAt(i);"
    "        if(c==='(') d++;"
    "        else if(c===')'){ d--; if(d<0) return false; if(d===0&&i!==v.length-1) return false; } }"
    "      return d===0; };"
    "    var lenOf=function(v){"
    "      fresh();"
    "      if(has(lenC,v)) return lenC[v];"
    "      var r=null, s=v.match(/^([+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:e[+-]?\\d+)?)([a-z]*)$/);"
    "      if(s){ var n=parseFloat(s[1]), u=s[2];"
    "        if(!isFinite(n)) r=null;"
    "        else if(!u) r=(n===0)?0:null;"          /* a unitless non-zero length is invalid CSS */
    "        else if(has(ABS,u)) r=n*ABS[u];"
    "        else { if(!has(unitC,u)) unitC[u]=pxOf('1'+u);"   /* every unit is linear: calibrate once */
    "               r=(unitC[u]===null)?null:n*unitC[u]; } }"
    "      else if(okFn(v)) r=pxOf(v);"
    "      if(lenN>=256){ lenC={}; lenN=0; }"
    "      lenC[v]=r; lenN++;"
    "      return r; };"
    "    var numOf=function(v){ return /^[+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:e[+-]?\\d+)?$/.test(v)?parseFloat(v):null; };"
    "    var resOf=function(v){"
    "      if(v==='infinite') return Infinity;"
    "      var s=v.match(/^([+-]?(?:\\d+\\.?\\d*|\\.\\d+)(?:e[+-]?\\d+)?)(dppx|x|dpi|dpcm)$/);"
    "      if(!s) return null; var n=parseFloat(s[1]);"
    "      return s[2]==='dpi'?n/96:s[2]==='dpcm'?n/37.795275590551:n; };"
    /* A <ratio> is `<number> [ / <number> ]?`: the denominator is OPTIONAL and
     * both parts may be decimals. Accepting only `<int>/<int>` left three of the
     * four spellings of the same query answered by the host. */
    "    var ratOf=function(v){"
    "      var i=v.indexOf('/'), a=v, b='1';"
    "      if(i>=0){ a=v.slice(0,i); b=v.slice(i+1); if(b.indexOf('/')>=0) return null; }"
    "      var n=numOf(a.trim()), d=numOf(b.trim());"
    "      if(n===null||d===null||!(n>=0)||!(d>0)) return null;"
    "      return n/d; };"
    /* ONE comparator for every operator, so the relations cannot contradict each
     * other: a fuzzy `=` beside exact `>=`/`<=` made `x = y` true while `x >= y`
     * was false. Here `=` is exactly `>= and <=`, `>=` is exactly `not <`, and
     * the tolerance band is shared by all five. */
    "    var cmp=function(h,op,w){"
    "      var e=(isFinite(h)&&isFinite(w))?1e-9*Math.max(1,Math.abs(h),Math.abs(w)):0;"
    "      return op==='<'?h<w-e:op==='>'?h>w+e:op==='<='?h<=w+e:op==='>='?h>=w-e:(h>=w-e&&h<=w+e); };"
    /* ---- the feature table: one entry per feature we can answer, keyed by the
     * feature NAME. Dispatching on the name (rather than on a literal spelling of
     * the whole clause) is the point of this rewrite: a new syntactic form of an
     * existing feature now costs nothing, where every previous round had to add
     * another regex and forgot one. */
    "    var ptr=function(){ return m.pointer||null; }, hov=function(){ return m.hover||null; };"
    "    var PV={none:1,coarse:1,fine:1}, HV={none:1,hover:1};"
    "    var kwf=function(g,v){ return {k:1,get:g,vals:v}; };"
    "    var nmf=function(g,v){ return {k:0,get:g,val:v}; };"
    "    var FEAT={"
    "      'pointer':kwf(ptr,PV), 'any-pointer':kwf(ptr,PV),"
    "      'hover':kwf(hov,HV), 'any-hover':kwf(hov,HV),"
    "      'resolution':nmf(dppx,resOf), 'device-pixel-ratio':nmf(dppx,numOf),"
    /* device-width/height/aspect-ratio are derived from the SCREEN, so on any real
     * device they are true by construction of our own spoofed screen. Delegating
     * them left matchMedia contradicting it. */
    "      'device-width':nmf(function(){ return sdim('width'); },lenOf),"
    "      'device-height':nmf(function(){ return sdim('height'); },lenOf),"
    "      'device-aspect-ratio':nmf(function(){ var w=sdim('width'), h=sdim('height');"
    "        return (w===null||h===null||h<=0)?null:w/h; },ratOf) };"
    /* ---- parse ONE clause into (feature, [[operator, value], ...]) ----
     * The vendor prefix comes off first, then min-/max-, which is the only order
     * that recognises `-webkit-min-device-pixel-ratio`. min-/max- is a MQ3
     * spelling of the colon form ONLY: it is invalid in the boolean and range
     * forms, which is why featOf rejects it there. */
    "    var canon=function(t){"
    "      var v=t.replace(/^-(?:webkit|moz|o|ms)-/,''), p='';"
    "      var s=v.match(/^(min|max)-([\\s\\S]+)$/); if(s){ p=s[1]; v=s[2]; }"
    "      return [v,p]; };"
    "    var featOf=function(t){"
    "      if(!/^-?[a-z][a-z0-9-]*$/.test(t)) return null;"
    "      var c=canon(t); return (!c[1]&&has(FEAT,c[0]))?c[0]:null; };"
    "    var FLIP={'<':'>','>':'<','<=':'>=','>=':'<=','=':'='};"
    /* Split the test at its depth-0 comparison operators. `f op v`, `v op f` and
     * `v op f op v` then all fall out of one tokenizer, so the reversed-operand
     * range -- which leaked both the geometry and the real DPR -- cannot be
     * forgotten the way each hand-written regex forgot it. */
    "    var tokens=function(s){"
    "      var out=[], buf='', d=0, i=0;"
    "      while(i<s.length){ var c=s.charAt(i);"
    "        if(c==='(') d++; else if(c===')') d--;"
    "        if(d===0&&(c==='<'||c==='>'||c==='=')){"
    "          var op=c; if(s.charAt(i+1)==='='){ op+='='; i++; }"
    "          out.push(buf.trim()); out.push(op); buf=''; i++; continue; }"
    "        buf+=c; i++; }"
    "      out.push(buf.trim()); return out; };"
    "    var parse=function(s){"
    "      var p=s.match(/^(-?[a-z][a-z0-9-]*)\\s*:\\s*([\\s\\S]+)$/);"
    "      if(p){ var c=canon(p[1]);"
    "        return has(FEAT,c[0])?[c[0],[[c[1]==='min'?'>=':c[1]==='max'?'<=':'=',p[2].trim()]]]:null; }"
    "      var t=tokens(s), f;"
    "      if(t.length===1){ f=featOf(t[0]); return f?[f,[['b','']]]:null; }"
    "      if(t.length===3){"
    "        f=featOf(t[0]); if(f) return [f,[[t[1],t[2]]]];"
    "        f=featOf(t[2]); return f?[f,[[FLIP[t[1]],t[0]]]]:null; }"
    "      if(t.length===5){"
    "        if((t[1]==='<'||t[1]==='<=')!==(t[3]==='<'||t[3]==='<=')) return null;"   /* MQ4: both bounds face the same way */
    "        f=featOf(t[2]); return f?[f,[[FLIP[t[1]],t[0]],[t[3],t[4]]]]:null; }"
    "      return null; };"
    /* Answer one clause from the spoofed device, or null when this profile does
     * not spoof that feature, when the value does not belong to it, or when the
     * value cannot be resolved -- all three mean DELEGATE, never guess.
     * The boolean form `(hover)` is `hover != none`, the same question the colon
     * form asks; answering only the colon form let the two contradict. */
    "    var featVal=function(s){"
    "      var p=parse(s); if(!p) return null;"
    "      var F=FEAT[p[0]], h=F.get(); if(h===null) return null;"
    "      var ts=p[1], i, t, w;"
    "      for(i=0;i<ts.length;i++){ t=ts[i];"
    "        if(t[0]==='b'){ if(F.k?h==='none':h===0) return false; continue; }"
    "        if(F.k){ if(t[0]!=='='||!has(F.vals,t[1])) return null;"   /* discrete features have no range form */
    "                 if(h!==t[1]) return false; continue; }"
    /* A NEGATIVE bound is answered here like any other, deliberately: it is below
     * every possible width, so the answer cannot depend on the spoofed value --
     * whereas delegating it would hand `(-5px < device-width < Npx)` to the host
     * and put the whole geometry back on the wire through a bound that carries no
     * information. (WebKitGTK evaluates such a bound rather than voiding it, so
     * this also agrees with the engine.) */
    "        w=F.val(t[1]); if(w===null) return null;"
    "        if(!cmp(h,t[0],w)) return false; }"
    "      return true; };"
    /* ---- the condition tree ----
     * {v: value, s: does a spoofed feature back it?}. Keeping the two apart is
     * what lets `(not X)` be computed here while still counting as UNspoofed when
     * X is: claiming every negated clause dragged queries with no spoofed content
     * at all into the wrapper, and delegating the whole `(not X)` instead answers
     * a query form the engine may not accept. */
    "    var deleg=function(t){ var r=orig.call(window,t); return !!(r&&r.matches); };"
    "    var bal=function(t){ var d=0, i;"
    "      for(i=0;i<t.length;i++){ var c=t.charAt(i);"
    "        if(c==='(') d++;"
    "        else if(c===')'){ d--; if(d===0) return i===t.length-1; if(d<0) return false; } }"
    "      return false; };"
    /* unit/cond recurse once per paren group and per `not`, on query text the
     * page controls, so unbounded nesting overflows the JS stack and matchMedia
     * throws a RangeError where a real engine simply answers. Two guards, and
     * the ORDER of preference between them matters:
     *
     * First, collapse redundant parens. '((((X))))' is just '(X)', and
     * collapsing costs one pass instead of a stack frame per level, so the
     * cheap pathological case never approaches the cap and still gets the
     * correct SPOOFED answer at any depth.
     *
     * Only a genuinely structured query -- hundreds of real nested conditions,
     * which no page emits -- can still reach the cap. Such a breach must NOT be
     * delegated to the engine: delegation was tried, and it re-opened the exact
     * leak this evaluator exists to close, because the host answers a
     * device-width probe with the REAL geometry. Measured on a pixel-chrome
     * profile: a plain binary search returned the spoofed 412, the same search
     * wrapped in 300 parens returned the host's true 1280. Answering false and
     * claiming it as ours is a tell for an absurd query but discloses nothing,
     * which is the right way round. */
    "    var MAXDEPTH=256, TOODEEP={v:false,s:true};"
    "    var unit=function(t,dep){"
    "      t=t.trim();"
    "      while(t.charAt(0)==='('&&bal(t)){"
    "        var q=t.slice(1,t.length-1).trim();"
    "        if(q.charAt(0)==='('&&bal(q)) t=q; else break; }"
    "      if(dep>MAXDEPTH) return TOODEEP;"
    "      var n=t.match(/^not\\b\\s*([\\s\\S]+)$/);"
    "      if(n){ var r=unit(n[1],dep+1); return {v:!r.v,s:r.s}; }"
    "      if(t.charAt(0)!=='('||!bal(t)) return {v:deleg(t),s:false};"
    "      var inner=t.slice(1,t.length-1).trim();"
    "      if(!inner) return {v:deleg(t),s:false};"
    /* A parenthesised GROUP is a condition, not a feature test: evaluating it
     * recursively is what makes '((A) or (B))' agree with 'A or B' instead of
     * being handed to the host whole. */
    "      if(inner.charAt(0)==='('||/^not\\b/.test(inner)) return cond(inner,dep+1);"
    "      var fv=featVal(inner);"
    "      return fv===null?{v:deleg(t),s:false}:{v:fv,s:true}; };"
    "    var cond=function(s,dep){"
    "      var ps=splitTop(s,/^\\s*\\bor\\b\\s*/), i, r, v, sp=false;"
    "      if(ps.length>1){ v=false;"
    "        for(i=0;i<ps.length;i++){ r=unit(ps[i],dep+1); if(r.s) sp=true; if(r.v) v=true; }"
    "        return {v:v,s:sp}; }"
    "      ps=splitTop(s,/^\\s+and\\s+/);"
    "      if(ps.length>1){ v=true;"
    "        for(i=0;i<ps.length;i++){ r=unit(ps[i],dep+1); if(r.s) sp=true; if(!r.v) v=false; }"
    "        return {v:v,s:sp}; }"
    "      return unit(s,dep); };"
    /* Evaluate a COMPOUND query branch by branch and clause by clause: a spoofed
     * clause uses our answer, any other is delegated to the real engine and the
     * results combined. Matching whole literal strings meant
     * '(pointer:coarse) and (min-width:1px)' and comma lists silently reported the
     * real desktop answer. */
    "    var evalQuery=function(lq){"
    "      var ors=splitTop(lq, /^\\s*(?:,|\\bor\\b)\\s*/), spoofed=false, result=false, i, j;"
    "      for(i=0;i<ors.length;i++){"
    /* `only <type>` is semantically identical to `<type>` (the keyword only hides
     * the query from prehistoric parsers), and `not` negates the whole branch.
     * Treating either as unparseable abandoned the spoof and returned the
     * contradicting host answer for the most common real-world form. */
    "        var branch=ors[i].trim(), negate=false;"
    "        if(/^only\\s+/.test(branch)) branch=branch.replace(/^only\\s+/,'');"
    "        else if(/^not\\s+/.test(branch)){ negate=true; branch=branch.replace(/^not\\s+/,''); }"
    "        var parts=splitTop(branch, /^\\s+and\\s+/), all=true, usable=true, got=[];"
    "        for(j=0;j<parts.length;j++){"
    "          var c=parts[j].trim();"
    "          if(!c){ usable=false; break; }"
    "          if(c.charAt(0)!=='('){"
    "            if(c==='screen'||c==='all') continue;"     /* always true in a screen browsing context */
    "            usable=false; break; }"                    /* print/speech/... -> let the host answer */
    "          got.push(c); }"
    /* A branch we cannot tokenize is delegated ON ITS OWN and OR-ed in. Bailing
     * out for the whole query let one unhandleable alternative disable every
     * spoofed one beside it: appending ', print' to any query handed the real
     * device's answer back, reopening the geometry leak in the very form the
     * tests pin. A disjunction is per-branch, so treat it that way. */
    "        if(!usable){"
    "          var um=orig.call(window, ors[i]);"
    "          if(um && um.matches) result=true;"
    "          continue; }"
    "        for(j=0;j<got.length;j++){ var rv=unit(got[j],0); if(rv.s) spoofed=true; if(!rv.v) all=false; }"
    "        if(negate) all=!all;"
    "        if(all) result=true; }"
    "      return spoofed ? result : null; };"
    "    var orig=window.matchMedia;"
    /* Redefine `matches` ONCE on MediaQueryList.prototype, backed by a WeakMap of
     * spoofed instances. A Proxy minted a fresh bound function per access (so
     * m.addEventListener !== m.addEventListener) and failed the platform-object
     * brand check; an own property on the instance would instead show up under
     * getOwnPropertyDescriptor/hasOwnProperty where the real one is inherited.
     * A prototype accessor has neither tell. */
    "    var mqOver=new WeakMap();"
    "    (function(){ var M=window.MediaQueryList; if(!M||!M.prototype) return;"
    "      var d=Object.getOwnPropertyDescriptor(M.prototype,'matches'); if(!d||!d.get) return;"
    "      var og=d.get;"
    /* Store the QUERY and re-evaluate on every read. Caching the boolean froze a
     * spoofed MediaQueryList at its creation-time answer, so a retained object
     * contradicted a freshly created one for the same string and `change` never
     * fired -- responsive pages stuck at their initial breakpoint. */
    "      var g=({ get matches(){ var q=mqOver.get(this);"
    "        if(q===undefined) return og.call(this);"
    "        var ev=evalQuery(q); return ev===null ? og.call(this) : ev; } });"
    "      var gd=Object.getOwnPropertyDescriptor(g,'matches').get;"
    "      Object.defineProperty(M.prototype,'matches',{enumerable:d.enumerable,configurable:true,"
    "        get:gd}); })();"
    /* The engine serialises an unparseable query to media "not all", and such a
     * MediaQueryList can NEVER match. Our looser tokenizer accepts some of those
     * (e.g. 'only (pointer:coarse)' -- `only` requires a media type; or a
     * trailing type), so without this check we reported matches:true beside
     * media:"not all", a self-contradiction inside one object. */
    "    var mk=function(q,nq){"
    "      var real=orig.call(window,q);"
    "      try{ if(real && real.media==='not all') return real; }catch(e){}"
    "      try{ mqOver.set(real, nq); }catch(e){}"
    "      return real; };"
    "    var w=({ matchMedia(query){"
    "      if(arguments.length===0) throw new TypeError(\"Failed to execute 'matchMedia' on 'Window': 1 argument required, but only 0 present.\");"
    "      var q=query, lq=lite(q);"
    "      if(evalQuery(lq)!==null) return mk(q,lq);"       /* spoofed: re-evaluated live on each .matches read */
    "      return orig.call(window,q);"
    "    }}).matchMedia;"
    "    window.matchMedia=w;"
    "  }"
    /* Event-handler IDL attributes are ALWAYS accessors; a writable data property
     * is a one-line tell on the two properties mobile detection reads first. */
    /* All four touch handlers or none: no real touch-capable browser exposes
     * ontouchstart alone, and a partial set beside maxTouchPoints>0 is a
     * contradiction. */
    "  if(cfg.touch){"
    "    ['ontouchstart','ontouchend','ontouchmove','ontouchcancel'].forEach(function(h){"
    "      try{ if(h in window) return; var slot=null;"
    "        Object.defineProperty(window,h,{enumerable:true,configurable:true,"
    "          get(){ return slot; },"
    "          set(v){ slot = ((typeof v==='object'&&v!==null)||typeof v==='function') ? v : null; }}); }catch(e){} });"
    "  }"
    "  if(cfg.orientation){"
    /* window.orientation is MOBILE-ONLY (and legacy); screen.orientation is
     * universal. Emitting the orientation config for desktop profiles so they
     * get screen.orientation must not also hand them window.orientation beside
     * maxTouchPoints:0 and pointer:fine. Gate it on touch, and give it the
     * onorientationchange sibling no real mobile browser omits. */
    "    if(cfg.touch){"
    "      try{ Object.defineProperty(window,'orientation',{enumerable:true,configurable:true,"
    "        get(){ return cfg.orientation.angle; }}); }catch(e){}"
    "      try{ if(!('onorientationchange' in window)){ var _ooc=null;"
    "        Object.defineProperty(window,'onorientationchange',{enumerable:true,configurable:true,"
    "          get(){ return _ooc; },"
    "          set(v){ _ooc=((typeof v==='object'&&v!==null)||typeof v==='function')?v:null; }}); } }catch(e){}"
    "    }"
    "    try{ var so=window.screen&&window.screen.orientation;"
    "      if(so){ var sp=Object.getPrototypeOf(so);"        /* redefine on the existing ScreenOrientation.prototype */
    "        Object.defineProperty(sp,'type',{get(){return cfg.orientation.type;},enumerable:true,configurable:true});"
    "        Object.defineProperty(sp,'angle',{get(){return cfg.orientation.angle;},enumerable:true,configurable:true});"
    "      } else if(window.screen){"                        /* WebKitGTK exposes no screen.orientation -- stub it (mobile has one) */
    /* Shaped as a real WebIDL interface for the same reasons NavigatorUAData was:
     * a bare literal reported [object Object], exposed 8 own enumerable keys
     * (real: none), was not an EventTarget, and left window.ScreenOrientation
     * undefined -- and it sat as an own property of `screen` rather than an
     * accessor on Screen.prototype. */
    "        var SO=function ScreenOrientation(){ throw new TypeError('Illegal constructor'); };"
    "        Object.setPrototypeOf(SO, EventTarget);"
    "        SO.prototype=Object.create(EventTarget.prototype,{constructor:{value:SO,writable:true,configurable:true}});"
    "        try{ Object.defineProperty(SO.prototype,Symbol.toStringTag,{value:'ScreenOrientation',configurable:true}); }catch(e){}"
    "        Object.defineProperty(SO.prototype,'type',{get(){ return cfg.orientation.type; },enumerable:true,configurable:true});"
    "        Object.defineProperty(SO.prototype,'angle',{get(){ return cfg.orientation.angle; },enumerable:true,configurable:true});"
    "        var _oc=null;"
    "        Object.defineProperty(SO.prototype,'onchange',{enumerable:true,configurable:true,"
    "          get(){ return _oc; }, set(v){ _oc=((typeof v==='object'&&v!==null)||typeof v==='function')?v:null; }});"
    "        var soM={ lock(){ return Promise.reject(new DOMException('lock not available','NotSupportedError')); }, unlock(){} };"
    "        Object.defineProperty(SO.prototype,'lock',{value:soM.lock,writable:true,enumerable:true,configurable:true});"
    "        Object.defineProperty(SO.prototype,'unlock',{value:soM.unlock,writable:true,enumerable:true,configurable:true});"
    "        try{ Object.defineProperty(SO,'prototype',{writable:false}); }catch(e){}"
    "        try{ if(!('ScreenOrientation' in window)) Object.defineProperty(window,'ScreenOrientation',{value:SO,writable:true,enumerable:false,configurable:true}); }catch(e){}"
    "        var soInst=Reflect.construct(EventTarget, [], SO);"
    "        var sproto=window.Screen ? window.Screen.prototype : window.screen;"
    "        Object.defineProperty(sproto,'orientation',{get(){ return soInst; },enumerable:true,configurable:true});"
    "      } }catch(e){}"
    "  }"
    "})();";

/* DOM feature-presence stubs. Each is installed ONLY if the target does not
 * already expose it (in-guarded), so a WebKitGTK build that ships a real API
 * keeps the real one. Functional where feasible -- but there is no real ICE /
 * device access behind them, and like the other JS-installed layers they are
 * Function.prototype.toString.call-detectable (documented ceiling). Driven by
 * cfg.features, an array of group names chosen per profile in Fingerprint.pm. */
/* navigator.plugins / mimeTypes / pdfViewerEnabled for a profile with NO inline
 * PDF viewer -- currently only Chrome for Android, which had none at 131.
 *
 * The HTML spec hardcodes both states: a browser with inline PDF viewing reports
 * pdfViewerEnabled true and five fixed plugin names, one without reports false
 * and EMPTY lists. WebKitGTK reports the viewer-present state, so a Chrome 131
 * Android profile contradicted itself in one property read.
 *
 * Faking the empty list is fiddly for one reason: PluginArray.prototype.length
 * (and item/namedItem) BRAND-CHECK -- calling them on an Object.create(
 * PluginArray.prototype) throws TypeError, so the obvious fake breaks on the
 * first length read. Nor can length be shadowed as an own property: on a real
 * PluginArray it lives on the prototype, and getOwnPropertyDescriptor would show
 * the difference. So the prototype accessor itself is patched to answer for OUR
 * one cached instance and delegate for everything else. length stays exactly
 * where a real browser keeps it. */
static const char *PLUGINS_JS =
    "(function(){"
    "  var C; try{ C=JSON.parse(window.__evwk_cfg); }catch(e){ return; }"
    "  if(!C || !C.no_pdf_viewer) return;"
    /* A replacement inherits neither the original's name nor its arity, and a
     * function expression carries an own `prototype` where a real WebIDL method
     * has none. All three are plain property reads -- no
     * Function.prototype.toString -- so they sit OUTSIDE the documented ceiling.
     * Method SHORTHAND fixes the prototype; the two defineProperty calls fix the
     * rest. The wrapper forwards `this`, so the brand check still sees the real
     * receiver. */
    "  var mimic=function(fn,orig,name){"
    "    var m=({ m(){ return fn.apply(this,arguments); } }).m;"
    "    try{ Object.defineProperty(m,'name',{value:name,configurable:true}); }catch(e){}"
    "    try{ Object.defineProperty(m,'length',{value:orig.length,configurable:true}); }catch(e){}"
    "    return m; };"
    "  var mk=function(ctor){"
    "    if(typeof ctor!=='function'||!ctor.prototype) return null;"
    "    var inst=Object.create(ctor.prototype);"
    /* Patch each brand-checking member once: answer the empty-list value for
     * `inst`, delegate to the original for every real instance.
     *
     * refresh() brand-checks like the rest: on the fake it threw "Can only call
     * PluginArray.refresh on instances of PluginArray" where Chrome returns
     * undefined -- breaking page JS and announcing the spoof in one call, and
     * calling it is what a plugin-probing script does. (MimeTypeArray has none;
     * the getOwnPropertyDescriptor guard below skips it there.) */
    "    ['length','item','namedItem','refresh'].forEach(function(k){"
    "      var d=Object.getOwnPropertyDescriptor(ctor.prototype,k); if(!d) return;"
    "      if(d.get){"
    "        var og=d.get;"
    "        var g=mimic(function(){ return this===inst ? 0 : og.call(this); }, og, 'get '+k);"
    "        Object.defineProperty(ctor.prototype,k,{enumerable:d.enumerable,configurable:true,get:g});"
    "      } else if(typeof d.value==='function'){"
    "        var ov=d.value;"
    /* refresh returns undefined; item/namedItem return null on an empty list. */
    "        var v=mimic(function(){"
    "          if(this!==inst) return ov.apply(this,arguments);"
    "          return k==='refresh' ? undefined : null; }, ov, k);"
    "        Object.defineProperty(ctor.prototype,k,{enumerable:d.enumerable,configurable:true,"
    "          writable:d.writable,value:v});"
    "      } });"
    "    return inst; };"
    "  var pa=mk(window.PluginArray), ma=mk(window.MimeTypeArray);"
    /* Cache: a real browser returns the SAME object on every read, so minting a
     * fresh one per access would fail `navigator.plugins === navigator.plugins`
     * -- the identity check that already caught navigator.languages. */
    "  var def=function(name,val){"
    "    if(val===null) return;"
    "    try{ Object.defineProperty(Navigator.prototype,name,{enumerable:true,configurable:true,"
    "      get:function(){ return val; }}); }catch(e){} };"
    "  def('plugins', pa); def('mimeTypes', ma);"
    "  try{ Object.defineProperty(Navigator.prototype,'pdfViewerEnabled',"
    "    {enumerable:true,configurable:true,get:function(){ return false; }}); }catch(e){}"
    "})();";

static const char *FEATURES_JS =
    "(function(){"
    "  var F; try{ F=JSON.parse(window.__evwk_cfg).features; }catch(e){ return; }"
    "  if(!F || !F.length) return;"
    "  var has=function(n){ return F.indexOf(n)>=0; };"
    "  var EH=new WeakMap();"
    /* EventHandler is [LegacyTreatNonObjectAsNull]: a non-Object coerces to null,
     * an Object (even a non-callable one) is stored as-is. Storing anything made
     * `o.onchange = 42` read back 42 where every real browser gives null.
     *
     * Storing alone is not enough: nothing invoked the stored handler, so an
     * event we dispatch ourselves (RTCDataChannel.close -> 'close') reached an
     * addEventListener listener but never the onclose one -- an asymmetry no
     * real EventTarget has. A trampoline listener invoking the CURRENT value
     * at dispatch fixes that, and preserves the HTML setter algorithm's
     * position rule in BOTH directions: re-assigning over a non-null handler
     * keeps the listener's original slot (so it must NOT be removed and
     * re-added), while assigning null REMOVES the listener outright, so a
     * handler set again later re-queues at the END -- behind listeners added
     * in the meantime. Registering once unconditionally kept the original
     * slot even across a null interlude, firing the re-set handler ahead of
     * listeners a real browser would run first. */
    "  function defHandlers(P, keys){ (keys||[]).forEach(function(k){"
    "    Object.defineProperty(P,k,{enumerable:true,configurable:true,"
    "      get:function(){ var m=EH.get(this); return (m && m[k]) || null; },"
    "      set:function(v){ var m=EH.get(this); if(!m){ m={}; EH.set(this,m); }"
    "        v=((typeof v==='object'&&v!==null)||typeof v==='function') ? v : null;"
    "        if(typeof this.addEventListener!=='function'){ m[k]=v; return; }"
    "        if(v===null){"
    "          if(m['@'+k]){ this.removeEventListener(k.slice(2), m['@'+k]); m['@'+k]=null; }"
    "          m[k]=null; return; }"
    "        m[k]=v;"
    "        if(!m['@'+k]){ var self=this;"
    "          var tr=function(e){ var h=EH.get(self); h = h && h[k];"
    "            if(typeof h==='function') h.call(self,e); };"
    "          m['@'+k]=tr;"
    "          this.addEventListener(k.slice(2), tr); } }}); }); }"
    /* Build a WebIDL-shaped interface: a throwing constructor exposed as a global
     * interface object, readonly attributes as PROTOTYPE getters (so Object.keys
     * on an instance is [] like the real thing), a Symbol.toStringTag so
     * Object.prototype.toString reports the interface name, and -- unless
     * plain -- a real EventTarget base so addEventListener is genuinely native. */
    "  function iface(name, ro, methods, handlers, plain){"
    "    var C=function(){ throw new TypeError('Illegal constructor'); };"
    "    try{ Object.defineProperty(C,'name',{value:name,configurable:true}); }catch(e){}"
    "    var base = plain ? Object.prototype : EventTarget.prototype;"
    "    if(!plain) Object.setPrototypeOf(C, EventTarget);"
    "    C.prototype=Object.create(base,{constructor:{value:C,writable:true,configurable:true}});"
    "    var P=C.prototype;"
    "    try{ Object.defineProperty(P, Symbol.toStringTag, {value:name, configurable:true}); }catch(e){}"
    "    Object.keys(ro||{}).forEach(function(k){ var v=ro[k];"
    "      Object.defineProperty(P,k,{get:function(){ return v; },enumerable:true,configurable:true}); });"
    "    Object.keys(methods||{}).forEach(function(k){"
    "      Object.defineProperty(P,k,{value:methods[k],writable:true,enumerable:true,configurable:true}); });"
    "    defHandlers(P, handlers);"
    "    try{ Object.defineProperty(C,'prototype',{writable:false}); }catch(e){}"   /* real WebIDL interface objects have a non-writable prototype */
    "    if(!(name in window)) Object.defineProperty(window,name,{value:C,writable:true,enumerable:false,configurable:true});"
    "    return C; }"
    "  function inst(C,plain){ return plain ? Object.create(C.prototype) : Reflect.construct(EventTarget, [], C); }"
    /* Named via a shorthand holder: defineProperty({value:...}) performs no
     * NamedEvaluation, so an anonymous function kept name "" -- which made
     * navigator.usb.requestDevice.name differ from navigator.hid.requestDevice.name,
     * two of our own stubs disagreeing on the same method. */
    "  function rej(fname,msg,nm){"
    "    var h={ requestDevice(){ return Promise.reject(new DOMException(msg,nm)); },"
    "            requestPort(){ return Promise.reject(new DOMException(msg,nm)); } };"
    "    return h[fname]; }"
    "  function defNav(name,getter){ try{ if(!(name in Navigator.prototype) && !(name in navigator))"
    "    Object.defineProperty(Navigator.prototype,name,{get:getter,enumerable:true,configurable:true}); }catch(e){} }"
    "  function once(make){ var v; return function(){ if(!v) v=make(); return v; }; }"
    "  if(has('connection')){"
    "    var NI=iface('NetworkInformation',{effectiveType:'4g',rtt:50,downlink:10,saveData:false},{},['onchange']);"
    "    var ni=once(function(){ return inst(NI); }); defNav('connection', function(){ return ni(); });"
    "  }"
    "  if(has('storage')){ try{ if(!(navigator.storage && navigator.storage.estimate)){"
    "    var SM=iface('StorageManager',{},{"
    "      estimate(){ return Promise.resolve({quota:Math.pow(2,41), usage:0, usageDetails:{}}); },"
    "      persist(){ return Promise.resolve(false); }, persisted(){ return Promise.resolve(false); },"
    "      getDirectory(){ return Promise.reject(new DOMException('Not available.','SecurityError')); }},[],true);"
    "    var sm=once(function(){ return inst(SM,true); }); defNav('storage', function(){ return sm(); });"
    "  } }catch(e){} }"
    "  if(has('battery')){"                          /* real Chrome resolves the SAME BatteryManager every call */
    "    var BM=iface('BatteryManager',{charging:true,chargingTime:0,dischargingTime:Infinity,level:1},{},"
    "      ['onchargingchange','onchargingtimechange','ondischargingtimechange','onlevelchange']);"
    "    var bm=once(function(){ return inst(BM); });"
    "    try{ if(!('getBattery' in Navigator.prototype) && !('getBattery' in navigator))"
    "      Object.defineProperty(Navigator.prototype,'getBattery',{value:function getBattery(){ return Promise.resolve(bm()); },"
    "        writable:true,enumerable:true,configurable:true}); }catch(e){} }"
    /* Each of these has its OWN method set in real Chrome; giving all four the
     * merged union made `'getPorts' in navigator.serial` false and
     * `'requestPort' in navigator.usb` true -- the exact inverse of the truth. */
    "  function devIface(feat, prop, name, methods, handlers){"
    "    if(!has(feat)) return;"
    "    var C=iface(name, {}, methods, handlers);"
    "    var i=once(function(){ return inst(C); }); defNav(prop, function(){ return i(); }); }"
    "  devIface('usb','usb','USB',{ getDevices(){ return Promise.resolve([]); },"
    "    requestDevice: rej('requestDevice','No device selected.','NotFoundError') },['onconnect','ondisconnect']);"
    "  devIface('hid','hid','HID',{ getDevices(){ return Promise.resolve([]); },"
    "    requestDevice(){ return Promise.resolve([]); } },['onconnect','ondisconnect']);"
    "  devIface('serial','serial','Serial',{ getPorts(){ return Promise.resolve([]); },"
    "    requestPort: rej('requestPort','No port selected.','NotFoundError') },['onconnect','ondisconnect']);"
    "  devIface('bluetooth','bluetooth','Bluetooth',{ getDevices(){ return Promise.resolve([]); },"
    "    getAvailability(){ return Promise.resolve(false); },"
    "    requestDevice: rej('requestDevice','User cancelled the requestDevice() chooser.','NotFoundError') },"
    "    ['onadvertisementreceived','onavailabilitychanged']);"
    "  if(has('scheduling')){"
    "    var SC=iface('Scheduling',{},{ isInputPending(){ return false; } },[],true);"
    "    var sc=once(function(){ return inst(SC,true); }); defNav('scheduling', function(){ return sc(); });"
    "  }"
    "  if(has('rtc') && !('RTCPeerConnection' in window)){ try{"
    /* A plain function would bind `this` to window when called without `new`,
     * silently publishing iceGatheringState/signalingState/... as globals. A
     * class throws, exactly as the real constructor does. */
    /* Per-instance state. iface()'s `ro` values are captured once and shared by
     * every instance, so createDataChannel('chat').label read back '' -- both a
     * break for page code and a one-line inconsistency to probe. Real WebIDL
     * attributes are prototype accessors over per-instance state, which is also
     * what keeps Object.keys(channel) empty like the real thing. */
    "    var dcState=new WeakMap();"
    "    var DC=iface('RTCDataChannel',{},{"
    /* WebIDL checks the required-argument count in the binding layer, before
     * the method body runs: send() with no argument is a TypeError even on a
     * channel whose state would make it fail, and a real browser never
     * reaches the readyState check first -- the two error classes are a
     * one-call probe. */
    /* A real channel that never opens throws on send(); a silent no-op is the
     * detectable answer, not the safe one -- a page that reaches send() on a
     * channel with no ICE behind it is already broken either way. */
    "      send(){ if(arguments.length===0) throw new TypeError("
    "        \"Failed to execute 'send' on 'RTCDataChannel': 1 argument required, but only 0 present.\");"
    "        var s=dcState.get(this);"
    "        if(!s || s.readyState!=='open') throw new DOMException("
    "          \"Failed to execute 'send' on 'RTCDataChannel': RTCDataChannel.readyState is not 'open'\","
    "          'InvalidStateError'); },"
    /* The closing procedure fires `closing` when readyState moves, then
     * `close` once it settles -- the stub advertises onclosing in its handler
     * list, so skipping the first event contradicts the stub's own surface. */
    "      close(){ var s=dcState.get(this);"
    "        if(!s || s.readyState==='closing' || s.readyState==='closed') return;"
    "        s.readyState='closing'; var self=this;"
    "        Promise.resolve().then(function(){ try{ self.dispatchEvent(new Event('closing')); }catch(e){}"
    "          s.readyState='closed';"
    "          try{ self.dispatchEvent(new Event('close')); }catch(e){} }); }},"
    "      ['onopen','onbufferedamountlow','onerror','onclosing','onclose','onmessage']);"
    "    var DCDEF={label:'',ordered:true,maxPacketLifeTime:null,maxRetransmits:null,"
    "      protocol:'',negotiated:false,id:null,readyState:'connecting',bufferedAmount:0};"
    "    Object.keys(DCDEF).forEach(function(k){"
    "      Object.defineProperty(DC.prototype,k,{enumerable:true,configurable:true,"
    "        get(){ var s=dcState.get(this); return s ? s[k] : DCDEF[k]; }}); });"
    /* The two WRITABLE attributes. Chrome rejects an out-of-enum binaryType with
     * a TypeError rather than silently keeping it, and runs the threshold
     * through ToUint32. */
    "    Object.defineProperty(DC.prototype,'binaryType',{enumerable:true,configurable:true,"
    "      get(){ var s=dcState.get(this); return s ? s.binaryType : 'blob'; },"
    "      set(v){ v=String(v); if(v!=='blob' && v!=='arraybuffer') throw new TypeError("
    "        \"Failed to set the 'binaryType' property on 'RTCDataChannel': The provided value '\""
    "        +v+\"' is not a valid enum value of type BinaryType.\");"
    "        var s=dcState.get(this); if(s) s.binaryType=v; }});"
    "    Object.defineProperty(DC.prototype,'bufferedAmountLowThreshold',{enumerable:true,configurable:true,"
    "      get(){ var s=dcState.get(this); return s ? s.bufferedAmountLowThreshold : 0; },"
    "      set(v){ var s=dcState.get(this); if(s) s.bufferedAmountLowThreshold=(Number(v)||0)>>>0; }});"
    /* These two ARE constructible in every real browser and appear in essentially
     * every signaling implementation, so iface()'s always-throwing constructor
     * turned `new RTCSessionDescription(answer)` into a TypeError in page code. */
    /* Attributes live on the PROTOTYPE (per-instance values in a WeakMap) so
     * Object.keys(instance) is [] as in every real browser and as every other
     * stub in this file already does; and calling without `new` throws, matching
     * both real WebIDL and the sibling RTCPeerConnection stub. */
    "    var dictVals=new WeakMap();"
    "    var mkDict=function(name,fields){"
    "      var C=function(init){"
    "        if(!(this instanceof C)) throw new TypeError(\"Failed to construct '\"+name+\"': Please use the 'new' operator.\");"
    "        init=init||{}; var v={};"
    /* A field flagged required (f[2]) is a WebIDL `required` member:
     * RTCSessionDescriptionInit.type is one, so a real browser throws during
     * dictionary conversion when it is absent -- new RTCSessionDescription({})
     * and new RTCSessionDescription() are both a TypeError, not an object
     * carrying type ''. The message follows Blink's standard required-member
     * template. */
    "        fields.forEach(function(f){"
    "          if(f[2] && init[f[0]]===undefined) throw new TypeError(\"Failed to construct '\"+name"
    "            +\"': Failed to read the '\"+f[0]+\"' property from '\"+name+\"Init': Required member is undefined.\");"
    "          v[f[0]]=(init[f[0]]!==undefined?init[f[0]]:f[1]); });"
    "        dictVals.set(this,v); };"
    "      fields.forEach(function(f){"
    "        Object.defineProperty(C.prototype,f[0],{enumerable:true,configurable:true,"
    "          get(){ var v=dictVals.get(this); return v ? v[f[0]] : undefined; }}); });"
    "      try{ Object.defineProperty(C,'name',{value:name,configurable:true}); }catch(e){}"
    "      try{ Object.defineProperty(C.prototype,Symbol.toStringTag,{value:name,configurable:true}); }catch(e){}"
    "      var h={ toJSON(){ var o={}; fields.forEach(function(f){ o[f[0]]=this[f[0]]; },this); return o; } };"
    "      Object.defineProperty(C.prototype,'toJSON',{value:h.toJSON,writable:true,enumerable:true,configurable:true});"
    "      try{ Object.defineProperty(C,'prototype',{writable:false}); }catch(e){}"
    "      if(!(name in window)) Object.defineProperty(window,name,{value:C,writable:true,enumerable:false,configurable:true});"
    "      return C; };"
    "    mkDict('RTCSessionDescription',[['type','',1],['sdp','']]);"   /* type is a REQUIRED WebIDL member */
    "    mkDict('RTCIceCandidate',[['candidate',''],['sdpMid',null],['sdpMLineIndex',null],['usernameFragment',null]]);"
    "    var RPC=class RTCPeerConnection extends EventTarget {"
    "      constructor(){ super(); }"
    "      get localDescription(){ return null; } get remoteDescription(){ return null; }"
    "      get iceGatheringState(){ return 'new'; } get iceConnectionState(){ return 'new'; }"
    "      get connectionState(){ return 'new'; } get signalingState(){ return 'stable'; }"
    "      createOffer(){ return Promise.resolve({type:'offer',sdp:''}); }"
    "      createAnswer(){ return Promise.resolve({type:'answer',sdp:''}); }"
    "      setLocalDescription(){ return Promise.resolve(); }"
    "      setRemoteDescription(){ return Promise.resolve(); }"
    "      addIceCandidate(){ return Promise.resolve(); }"
    "      createDataChannel(label, opts){"
    "        if(arguments.length<1) throw new TypeError(\"Failed to execute 'createDataChannel' on \""
    "          +\"'RTCPeerConnection': 1 argument required, but only 0 present.\");"
    /* maxPacketLifeTime/maxRetransmits/id are unsigned short in
     * RTCDataChannelInit, so the coercion is ToUint16: >>>0 (ToUint32) let
     * {maxPacketLifeTime:70000} read back 70000 where a real binding wraps to
     * 4464. The createDataChannel steps also throw a TypeError when BOTH
     * retransmission bounds are present -- the stub accepted a combination
     * every real browser rejects. */
    "        opts=opts||{};"
    "        if(opts.maxPacketLifeTime!==undefined&&opts.maxRetransmits!==undefined) throw new TypeError("
    "          \"Failed to execute 'createDataChannel' on 'RTCPeerConnection': \""
    "          +\"Both maxPacketLifeTime and maxRetransmits cannot be provided.\");"
    "        var ch=Reflect.construct(EventTarget, [], DC);"
    "        dcState.set(ch,{ label:String(label),"
    "          ordered: opts.ordered===undefined ? true : !!opts.ordered,"
    "          maxPacketLifeTime: opts.maxPacketLifeTime===undefined ? null : opts.maxPacketLifeTime&65535,"
    "          maxRetransmits: opts.maxRetransmits===undefined ? null : opts.maxRetransmits&65535,"
    "          protocol: opts.protocol===undefined ? '' : String(opts.protocol),"
    "          negotiated: !!opts.negotiated,"
    "          id: opts.id===undefined ? null : opts.id&65535,"
    "          readyState:'connecting', bufferedAmount:0, bufferedAmountLowThreshold:0,"
    "          binaryType:'blob' });"
    "        return ch; }"
    "      getStats(){ return Promise.resolve(new Map()); }"
    "      getSenders(){ return []; } getReceivers(){ return []; } getTransceivers(){ return []; }"
    /* Without these the canonical WebRTC opener --
     * stream.getTracks().forEach(t => pc.addTrack(t, stream)) -- throws a
     * TypeError into page code, which is worse than being detectable. */
    "      addTrack(){ return { track:null, getParameters(){ return {}; }, setParameters(){ return Promise.resolve(); }, replaceTrack(){ return Promise.resolve(); } }; }"
    "      removeTrack(){} addTransceiver(){ return { sender:{}, receiver:{}, direction:'sendrecv', stop(){} }; }"
    "      getConfiguration(){ return {}; } setConfiguration(){} restartIce(){}"
    "      get canTrickleIceCandidates(){ return null; }"
    "      get currentLocalDescription(){ return null; } get currentRemoteDescription(){ return null; }"
    "      get pendingLocalDescription(){ return null; } get pendingRemoteDescription(){ return null; }"
    "      get sctp(){ return null; }"
    "      close(){} };"
    "    defHandlers(RPC.prototype,"
    "      ['onicecandidate','ontrack','ondatachannel','onconnectionstatechange','oniceconnectionstatechange',"
    "       'onsignalingstatechange','onnegotiationneeded','onicecandidateerror','onicegatheringstatechange']);"
    /* class members are non-enumerable, but WebIDL operations/attributes are
     * enumerable -- and the iface() stubs in this same file already define theirs
     * that way, so leaving these non-enumerable split the file into two
     * disagreeing conventions, each detectable against the other. */
    "    Object.getOwnPropertyNames(RPC.prototype).forEach(function(k){ if(k==='constructor') return;"
    "      var d=Object.getOwnPropertyDescriptor(RPC.prototype,k); if(!d||d.enumerable) return;"
    "      d.enumerable=true; try{ Object.defineProperty(RPC.prototype,k,d); }catch(e){} });"
    "    try{ Object.defineProperty(RPC.prototype, Symbol.toStringTag, {value:'RTCPeerConnection', configurable:true}); }catch(e){}"
    "    try{ Object.defineProperty(RPC,'prototype',{writable:false}); }catch(e){}"
    "    Object.defineProperty(window,'RTCPeerConnection',{value:RPC,writable:true,enumerable:false,configurable:true});"
    "    Object.defineProperty(window,'webkitRTCPeerConnection',{value:RPC,writable:true,enumerable:false,configurable:true});"
    "  }catch(e){} }"
    "})();";

/* Injected LAST. Every real WebKitGTK accessor is named exactly "get <prop>";
 * ours were named "get" (the C accessors, which JSC names after the callback
 * slot) or "" (JS getters defined via a descriptor object, which get no
 * NamedEvaluation). That made ONE loop over Navigator.prototype/Screen.prototype/
 * window enumerate the entire spoof -- including the native C layer that was
 * supposed to be indistinguishable -- with zero false positives and without
 * needing Function.prototype.toString. Function.name is configurable, so the
 * names can simply be corrected after the fact. Also strips the stray .prototype
 * that a plain function expression carries and a native accessor never has. */
static const char *NAMEFIX_JS =
    "(function(){"
    /* A NATIVE accessor (the C ones) is left strictly alone apart from its name:
     * Function.name is configurable, so it can be corrected in place, and the
     * function stays genuinely native -- Function.prototype.toString.call still
     * reports [native code] and it gains no own `toString` property. Replacing it
     * with a JS wrapper (as an earlier attempt did) fixed the name but destroyed
     * exactly the property that makes these getters worth having, and added an
     * own toString that no real function has -- three tells for one.
     * A JS-defined accessor (ours) IS replaced, via get/set shorthand, which
     * fixes the name and drops the stray .prototype. No toString mask is added:
     * an own toString is itself a zero-false-positive tell, and these already
     * show JS source under FPT.call (the documented ceiling). */
    "  function isNative(f){"
    "    try{ return Function.prototype.toString.call(f).indexOf('[native code]')>=0; }catch(e){ return false; } }"
    "  function fixName(f,want){"
    "    try{ if(f.name!==want) Object.defineProperty(f,'name',{value:want,configurable:true}); }catch(e){} }"
    "  function reget(f,want){"
    "    var h={ get v(){ return f.call(this); } };"
    "    var g=Object.getOwnPropertyDescriptor(h,'v').get;"
    "    fixName(g,want); return g; }"
    "  function reset_(f,want){"
    "    var h={ set v(x){ f.call(this,x); } };"
    "    var s=Object.getOwnPropertyDescriptor(h,'v').set;"
    "    fixName(s,want); return s; }"
    "  function needs(f,want){"
    "    return typeof f==='function' &&"
    "      (f.name!==want || Object.prototype.hasOwnProperty.call(f,'prototype')); }"
    "  function fix(o){"
    "    if(!o) return;"
    "    Object.getOwnPropertyNames(o).forEach(function(k){"
    "      var d; try{ d=Object.getOwnPropertyDescriptor(o,k); }catch(e){ return; }"
    "      if(!d || (!d.get && !d.set) || !d.configurable) return;"
    "      var gN=needs(d.get,'get '+k), sN=needs(d.set,'set '+k);"
    "      if(!gN && !sN) return;"
    /* native: rename in place and keep it native */
    "      if(gN && isNative(d.get)){ fixName(d.get,'get '+k); gN=false; }"
    "      if(sN && isNative(d.set)){ fixName(d.set,'set '+k); sN=false; }"
    "      if(!gN && !sN) return;"
    "      var nd={enumerable:d.enumerable, configurable:true};"
    "      if(d.get) nd.get=gN ? reget(d.get,'get '+k) : d.get;"
    "      if(d.set) nd.set=sN ? reset_(d.set,'set '+k) : d.set;"
    "      try{ Object.defineProperty(o,k,nd); }catch(e){} }); }"
    "  fix(window);"
    "  fix(window.Navigator && Navigator.prototype);"
    "  fix(window.Screen && Screen.prototype);"
    "  ['NetworkInformation','USB','HID','Serial','Bluetooth','StorageManager','BatteryManager',"
    "   'NavigatorUAData','ScreenOrientation','RTCPeerConnection','RTCDataChannel','Scheduling',"
    "   'MediaQueryList','WebGLShaderPrecisionFormat','RTCSessionDescription','RTCIceCandidate'].forEach(function(n){"
    "    try{ var C=window[n]; if(C && C.prototype) fix(C.prototype); }catch(e){} });"
    "})();";

/* The profile, parsed once from the GVariant and read by the getters. */
typedef struct {
    char *platform, *vendor, *webgl_vendor, *webgl_renderer, *coherence;
    char **languages;                                  /* NULL-terminated, or NULL */
    gboolean has_hwc, has_devmem, has_touch, has_dpr;
    double hwc, devmem, touch, dpr;
    gboolean has_sw, has_sh, has_aw, has_ah, has_cd, has_pd;
    double sw, sh, aw, ah, cd, pd;
    gboolean has_seed; guint32 seed;
} Profile;
static Profile P;

/* strings return char* (JSC copies); numbers return gdouble by value. */
static char *g_platform (void*a,void*b){(void)a;(void)b; return g_strdup(P.platform);}
static char *g_vendor   (void*a,void*b){(void)a;(void)b; return g_strdup(P.vendor);}
/* navigator.language (singular) must equal languages[0] or a real browser mismatch shows. */
static char *g_language (void*a,void*b){(void)a;(void)b; return g_strdup(P.languages && P.languages[0] ? P.languages[0] : "");}
static gdouble g_hwc    (void*a,void*b){(void)a;(void)b; return P.hwc;}
static gdouble g_devmem (void*a,void*b){(void)a;(void)b; return P.devmem;}
static gdouble g_touch  (void*a,void*b){(void)a;(void)b; return P.touch;}
static gdouble g_dpr    (void*a,void*b){(void)a;(void)b; return P.dpr;}
static gdouble g_sw(void*a,void*b){(void)a;(void)b; return P.sw;}
static gdouble g_sh(void*a,void*b){(void)a;(void)b; return P.sh;}
static gdouble g_aw(void*a,void*b){(void)a;(void)b; return P.aw;}
static gdouble g_ah(void*a,void*b){(void)a;(void)b; return P.ah;}
static gdouble g_cd(void*a,void*b){(void)a;(void)b; return P.cd;}
static gdouble g_pd(void*a,void*b){(void)a;(void)b; return P.pd;}
/* languages: return a GStrv by value (property_type G_TYPE_STRV); JSC converts
 * it to a JS array. Same return-by-value shape as the string/number getters.
 *
 * KNOWN GAP, deliberately left open. navigator.languages is a
 * FrozenArray<DOMString>, so a real browser returns the SAME frozen array
 * object on every read; this returns a fresh mutable one, and both
 * `navigator.languages === navigator.languages` and
 * Object.isFrozen(navigator.languages) therefore answer false where a real
 * browser answers true. Closing it was implemented and then reverted: caching
 * one frozen array per context and handing it to the getter as user_data works
 * (the getter receives user_data as its first and only argument -- the instance
 * is not passed), but a JSCValue holds a STRONG ref on its JSCContext, so
 * cache -> array -> context -> cache is a refcount cycle and the accessor's
 * GDestroyNotify never runs. Measured against libjavascriptcoregtk-6.0: context
 * refcount 1 -> 2 on evaluate, and destroy_calls still 0 after the final unref.
 * That leaks a whole JSCContext per navigation -- unbounded in exactly the
 * long-running automation this module exists for. Anchoring the array on the JS
 * side instead would make `languages` a DATA property where every real browser
 * has an accessor, which is a louder tell than the one being fixed. A leak and
 * a worse tell are both worse than the gap, so the gap stays, documented in the
 * Ceiling POD.
 *
 * A SECOND route was then tried and abandoned, recorded so nobody spends
 * another day on it: root the array at the VM level rather than the GObject
 * level, holding no strong JSCValue at all -- a JSCWeakValue plus a
 * JSValueProtect'd JSValueRef, reaching the raw context through
 * webkit_frame_get_js_context. The lifetime reasoning survives scrutiny in
 * isolation: the context is never referenced, freeing is safe in either order,
 * and the protect root is genuinely required (without it GC collects the
 * array). It still does not work. On WebCore's own VM inside the web process,
 * JSGlobalContextCreateInGroup crashes, and so does JSValueMakeString on the
 * context window-object-cleared hands you -- both take the whole web process
 * down, not merely the getter. Some 200 lines of raw JSC C API, crashing twice,
 * to close one obscure identity check is a bad trade for a module whose point
 * is surviving long automation runs. If anyone revisits this, start by
 * establishing what locking the JSC C API requires on that context: that is the
 * part still unexplained. */
static char **g_langs (void*a,void*b){(void)a;(void)b; return g_strdupv (P.languages);}

static void def_str  (JSCValue *o, const char *n, GCallback g) {
    jsc_value_object_define_property_accessor (o, n, EVWK_FLAGS, G_TYPE_STRING, g, NULL, NULL, NULL);
}
static void def_num  (JSCValue *o, const char *n, GCallback g) {
    jsc_value_object_define_property_accessor (o, n, EVWK_FLAGS, G_TYPE_DOUBLE, g, NULL, NULL, NULL);
}
static void def_strv (JSCValue *o, const char *n, GCallback g) {
    jsc_value_object_define_property_accessor (o, n, EVWK_FLAGS, G_TYPE_STRV, g, NULL, NULL, NULL);
}

static void on_window_object_cleared (WebKitScriptWorld *world, WebKitWebPage *page,
                                      WebKitFrame *frame, gpointer ud)
{
    (void)page;(void)ud;
    frames_remember (frame);   /* every frame, spoofed or not -- see frame addressing */
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world (frame, world);
    if (!ctx) return;
    JSCValue *global = jsc_context_get_global_object (ctx);
    if (!global) { g_object_unref (ctx); return; }

    /* navigator props live on Navigator.prototype -- redefine them there. */
    JSCValue *navproto = jsc_context_evaluate (ctx, "Navigator.prototype", -1);
    if (navproto) {
        if (P.platform) def_str (navproto, "platform", G_CALLBACK (g_platform));
        if (P.vendor)   def_str (navproto, "vendor",   G_CALLBACK (g_vendor));
        if (P.has_hwc)    def_num (navproto, "hardwareConcurrency", G_CALLBACK (g_hwc));
        if (P.has_devmem) def_num (navproto, "deviceMemory",        G_CALLBACK (g_devmem));
        if (P.has_touch)  def_num (navproto, "maxTouchPoints",      G_CALLBACK (g_touch));
        if (P.languages) {
            def_strv (navproto, "languages", G_CALLBACK (g_langs));
            def_str  (navproto, "language",  G_CALLBACK (g_language));
        }
        g_object_unref (navproto);
    }

    /* screen props live on Screen.prototype. */
    JSCValue *scrproto = jsc_context_evaluate (ctx, "Screen.prototype", -1);
    if (scrproto) {
        if (P.has_sw) def_num (scrproto, "width",       G_CALLBACK (g_sw));
        if (P.has_sh) def_num (scrproto, "height",      G_CALLBACK (g_sh));
        if (P.has_aw) def_num (scrproto, "availWidth",  G_CALLBACK (g_aw));
        if (P.has_ah) def_num (scrproto, "availHeight", G_CALLBACK (g_ah));
        if (P.has_cd) def_num (scrproto, "colorDepth",  G_CALLBACK (g_cd));
        if (P.has_pd) def_num (scrproto, "pixelDepth",  G_CALLBACK (g_pd));
        g_object_unref (scrproto);
    }

    /* devicePixelRatio is genuinely an own property of window. */
    if (P.has_dpr) def_num (global, "devicePixelRatio", G_CALLBACK (g_dpr));

    if (P.has_seed) {
        /* The format is a LITERAL and the JS body is a %s ARGUMENT, so no edit to
         * that body can ever be interpreted as a printf conversion; the seed is
         * passed as a function parameter rather than spliced into the source. */
        char *js = g_strdup_printf ("(function(SEED){%s})(%u);", NOISE_JS_BODY, (unsigned) P.seed);
        JSCValue *r = jsc_context_evaluate (ctx, js, -1);
        if (r) g_object_unref (r);
        g_free (js);
    }

    /* The config blob is read by SEVERAL injected blocks (the WebGL wrapper's
     * numeric caps, COHERENCE_JS, FEATURES_JS), so publish it BEFORE the first
     * reader and delete it once after the last -- otherwise it lingers on window
     * as a tell. */
    if (P.coherence) {
        JSCValue *c = jsc_value_new_string (ctx, P.coherence);
        jsc_value_object_set_property (global, "__evwk_cfg", c);
        g_object_unref (c);
    }

    if (P.webgl_vendor || P.webgl_renderer || P.coherence) {
        if (P.webgl_vendor) {
            JSCValue *v = jsc_value_new_string (ctx, P.webgl_vendor);
            jsc_value_object_set_property (global, "__evwk_wv", v);
            g_object_unref (v);
        }
        if (P.webgl_renderer) {
            JSCValue *v = jsc_value_new_string (ctx, P.webgl_renderer);
            jsc_value_object_set_property (global, "__evwk_wr", v);
            g_object_unref (v);
        }
        JSCValue *r = jsc_context_evaluate (ctx, WEBGL_WRAPPER_JS, -1);
        if (r) g_object_unref (r);
    }

    if (P.coherence) {
        JSCValue *r = jsc_context_evaluate (ctx, COHERENCE_JS, -1);
        if (r) g_object_unref (r);
        JSCValue *f = jsc_context_evaluate (ctx, FEATURES_JS, -1);
        if (f) g_object_unref (f);
        /* before NAMEFIX, like the others: it renames whatever accessors exist */
        JSCValue *p = jsc_context_evaluate (ctx, PLUGINS_JS, -1);
        if (p) g_object_unref (p);
        /* after every accessor exists, including the native ones above */
        JSCValue *n = jsc_context_evaluate (ctx, NAMEFIX_JS, -1);
        if (n) g_object_unref (n);
        JSCValue *d = jsc_context_evaluate (ctx, "delete window.__evwk_cfg;", -1);
        if (d) g_object_unref (d);
    }

    g_object_unref (global);
    g_object_unref (ctx);
}

/* ---- frame addressing -------------------------------------------------
 * The UI process can only evaluate JavaScript in the main frame, and the
 * same-origin policy stops that script from reaching a cross-origin child.
 * Here in the web process there is no such wall: window-object-cleared fires
 * for EVERY frame, so keep what it hands us and let the UI ask by frame id.
 *
 * Frames are held through a GWeakRef, never a strong one: a frame that goes
 * away with its iframe must not be kept alive by this table, and a stale id
 * must answer "gone" rather than dereference freed memory.
 */
static GHashTable *FRAMES;   /* guint64 id -> GWeakRef* */

/* g_weak_ref_clear drops the REGISTRATION, not the struct it lives in: using it
   directly as the value destructor leaked one GWeakRef per entry removed. */
static void frames_ref_free (gpointer p)
{
    g_weak_ref_clear ((GWeakRef *) p);
    g_free (p);
}

/* Drop entries whose frame has been finalized. Frame ids are never reused, so
   without this the table keeps one key + GWeakRef + slot for every frame the
   page has ever created -- unbounded growth in the web process on any page that
   churns iframes, in a module whose point is surviving long runs. Swept from
   frames_remember (window-object-cleared) rather than lazily from the frame
   API, because automation that never calls frames() would otherwise never
   sweep at all. Measured: create 40 iframes and remove them, and the table
   holds 42 entries without this and 2 with it. Each sweep costs O(live
   frames) -- the previous sweep removed everything else -- and runs no script,
   so it cannot re-enter the table. */
static void frames_sweep (void)
{
    if (!FRAMES) return;
    GHashTableIter it; gpointer k, v;
    g_hash_table_iter_init (&it, FRAMES);
    while (g_hash_table_iter_next (&it, &k, &v)) {
        WebKitFrame *fr = (WebKitFrame *) g_weak_ref_get ((GWeakRef *) v);
        if (fr) { g_object_unref (fr); continue; }
        g_hash_table_iter_remove (&it);
    }
}

static void frames_remember (WebKitFrame *frame)
{
    if (!FRAMES)
        FRAMES = g_hash_table_new_full (g_int64_hash, g_int64_equal,
                                        g_free, frames_ref_free);
    frames_sweep ();
    guint64 id = webkit_frame_get_id (frame);
    GWeakRef *ref = g_hash_table_lookup (FRAMES, &id);
    if (ref) { g_weak_ref_set (ref, frame); return; }
    guint64 *key = g_new (guint64, 1); *key = id;
    ref = g_new0 (GWeakRef, 1);
    g_weak_ref_init (ref, frame);
    g_hash_table_insert (FRAMES, key, ref);
}

static WebKitFrame *frames_lookup (guint64 id)
{
    if (!FRAMES) return NULL;
    GWeakRef *ref = g_hash_table_lookup (FRAMES, &id);
    if (!ref) return NULL;
    return (WebKitFrame *) g_weak_ref_get (ref);   /* strong, or NULL if gone */
}

/* Worlds are keyed by name, so this yields the same isolated world the user
   script was injected into -- where window.__evwk actually lives. */
static WebKitScriptWorld *evwk_world (void)
{
    static WebKitScriptWorld *world;
    if (!world) world = webkit_script_world_new_with_name ("EVWebKit");
    return world;
}

/* A WebKitFrame outlives its browsing context: navigate the page away and the
   old child frame object is still alive, its GWeakRef still resolves, and it
   still answers script -- from a detached document that is no longer on screen.
   document.defaultView is the spec's signal for that (null once the context is
   discarded) and the only one that survives a cross-origin parent:
   window.frameElement reads null for a live cross-origin frame too. */
static gboolean frame_alive (WebKitFrame *frame)
{
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world (frame, evwk_world ());
    if (!ctx) return FALSE;
    JSCValue *v = jsc_context_evaluate (ctx, "document.defaultView !== null", -1);
    gboolean alive = v && jsc_value_to_boolean (v);
    if (jsc_context_get_exception (ctx)) { jsc_context_clear_exception (ctx); alive = FALSE; }
    if (v) g_object_unref (v);
    g_object_unref (ctx);
    return alive;
}

static void frames_forget (guint64 id)
{
    if (FRAMES) g_hash_table_remove (FRAMES, &id);
}

/* Evaluate BODY as a function body in FRAME's context, in our script world,
   and hand back its JSON. A JS exception becomes ok=FALSE plus the message --
   never a silent empty result, which would be indistinguishable from a
   function that legitimately returned undefined. */
static char *frame_eval_json (WebKitFrame *frame, const char *body, gboolean *ok)
{
    *ok = FALSE;
    /* The registry find() builds lives in the module's own isolated world, not
       the page's -- so evaluate there, or __evwk simply would not exist. Worlds
       are keyed by name, so asking for this one yields the same world the
       user script was injected into. */
    JSCContext *ctx = webkit_frame_get_js_context_for_script_world (frame, evwk_world ());
    if (!ctx) return g_strdup ("no javascript context for that frame");
    /* This world gets the registry the first time it is used in a given frame.
       Cheap to re-check: the bootstrap itself is idempotent (it keeps an
       existing window.__evwk), so a re-navigated frame simply gets a fresh one. */
    if (EVWK_BOOT) {
        JSCValue *have = jsc_context_evaluate (ctx, "typeof window.__evwk", -1);
        gboolean missing = TRUE;
        if (have) {
            char *t = jsc_value_to_string (have);
            missing = !t || g_strcmp0 (t, "object") != 0;
            g_free (t);
            g_object_unref (have);
        }
        jsc_context_clear_exception (ctx);
        if (missing) {
            JSCValue *bv = jsc_context_evaluate (ctx, EVWK_BOOT, -1);
            if (bv) g_object_unref (bv);
            jsc_context_clear_exception (ctx);
        }
    }
    /* The body does its own JSON.stringify, exactly as the UI-process path
       does, so the two produce identical results (surrogate repair included)
       and nothing is encoded twice. */
    char *src = g_strdup_printf ("(function(){%s})()", body);
    JSCValue *v = jsc_context_evaluate (ctx, src, -1);
    g_free (src);
    JSCException *ex = jsc_context_get_exception (ctx);
    if (ex) {
        const char *m = jsc_exception_get_message (ex);
        char *err = g_strdup (m ? m : "javascript exception");
        jsc_context_clear_exception (ctx);
        if (v) g_object_unref (v);
        g_object_unref (ctx);
        return err;
    }
    if (v && !jsc_value_is_string (v)) {
        g_object_unref (v); g_object_unref (ctx);
        return g_strdup ("frame evaluation did not return JSON");
    }
    char *out = v ? jsc_value_to_string (v) : g_strdup ("null");
    if (v) g_object_unref (v);
    g_object_unref (ctx);
    *ok = TRUE;
    return out;
}

static gboolean on_user_message (WebKitWebPage *page, WebKitUserMessage *msg, gpointer ud)
{
    (void)page;(void)ud;
    const char *name = webkit_user_message_get_name (msg);
    if (!name) return FALSE;

    if (g_strcmp0 (name, "evwk.frames") == 0) {
        GVariantBuilder b;
        g_variant_builder_init (&b, G_VARIANT_TYPE ("a(tsb)"));
        if (FRAMES) {
            GArray    *ids = g_array_new (FALSE, FALSE, sizeof (guint64));
            GPtrArray *fs  = g_ptr_array_new ();
            GHashTableIter it; gpointer k, v;
            g_hash_table_iter_init (&it, FRAMES);
            while (g_hash_table_iter_next (&it, &k, &v)) {
                WebKitFrame *fr = (WebKitFrame *) g_weak_ref_get ((GWeakRef *) v);
                if (!fr) continue;                       /* finalized: simply not listed */
                g_array_append_val (ids, *(guint64 *) k);
                g_ptr_array_add (fs, fr);
            }
            /* Script runs only once the iteration is over: evaluating inside it
               could re-enter this very table through window-object-cleared. */
            for (guint i = 0; i < fs->len; i++) {
                WebKitFrame *fr = g_ptr_array_index (fs, i);
                guint64 id = g_array_index (ids, guint64, i);
                if (frame_alive (fr)) {
                    const char *uri = webkit_frame_get_uri (fr);
                    g_variant_builder_add (&b, "(tsb)", id, uri ? uri : "",
                                           webkit_frame_is_main_frame (fr));
                } else {
                    frames_forget (id);
                }
                g_object_unref (fr);
            }
            g_array_free (ids, TRUE);
            g_ptr_array_free (fs, TRUE);
        }
        webkit_user_message_send_reply (msg, webkit_user_message_new ("evwk.frames", g_variant_builder_end (&b)));
        return TRUE;
    }

    if (g_strcmp0 (name, "evwk.eval") == 0) {
        GVariant *p = webkit_user_message_get_parameters (msg);
        guint64 id = 0; const char *body = NULL;
        if (!p || !g_variant_is_of_type (p, G_VARIANT_TYPE ("(ts)"))) {
            webkit_user_message_send_reply (msg,
                webkit_user_message_new ("evwk.eval", g_variant_new ("(bs)", FALSE, "bad request")));
            return TRUE;
        }
        g_variant_get (p, "(t&s)", &id, &body);
        WebKitFrame *fr = frames_lookup (id);
        if (fr && !frame_alive (fr)) { g_object_unref (fr); fr = NULL; }
        if (!fr) {
            frames_forget (id);   /* zombie or finalized: either way the id is dead */
            webkit_user_message_send_reply (msg,
                webkit_user_message_new ("evwk.eval", g_variant_new ("(bs)", FALSE, "frame is gone")));
            return TRUE;
        }
        gboolean ok = FALSE;
        char *out = frame_eval_json (fr, body ? body : "return null;", &ok);
        g_object_unref (fr);
        webkit_user_message_send_reply (msg,
            webkit_user_message_new ("evwk.eval", g_variant_new ("(bs)", ok, out ? out : "")));
        g_free (out);
        return TRUE;
    }
    return FALSE;
}

static void on_page_created (WebKitWebProcessExtension *ext, WebKitWebPage *page, gpointer ud)
{
    (void)ext;(void)ud;
    g_signal_connect (page, "user-message-received", G_CALLBACK (on_user_message), NULL);
}

void webkit_web_process_extension_initialize_with_user_data (WebKitWebProcessExtension *ext,
                                                             GVariant *ud)
{
    if (ud) {
        const char *s;
        if (g_variant_lookup (ud, "platform",       "&s", &s) && s) P.platform       = g_strdup (s);
        if (g_variant_lookup (ud, "vendor",         "&s", &s) && s) P.vendor         = g_strdup (s);
        if (g_variant_lookup (ud, "webgl_vendor",   "&s", &s) && s) P.webgl_vendor   = g_strdup (s);
        if (g_variant_lookup (ud, "webgl_renderer", "&s", &s) && s) P.webgl_renderer = g_strdup (s);
        if (g_variant_lookup (ud, "coherence",      "&s", &s) && s) P.coherence      = g_strdup (s);
        if (g_variant_lookup (ud, "boot",           "&s", &s) && s) EVWK_BOOT = g_strdup (s);
        GVariant *langs = g_variant_lookup_value (ud, "languages", G_VARIANT_TYPE ("as"));
        if (langs) { P.languages = g_variant_dup_strv (langs, NULL); g_variant_unref (langs); }
        double d;
        if (g_variant_lookup (ud, "hardwareConcurrency", "d", &d)) { P.has_hwc=TRUE;    P.hwc=d; }
        if (g_variant_lookup (ud, "deviceMemory",        "d", &d)) { P.has_devmem=TRUE; P.devmem=d; }
        if (g_variant_lookup (ud, "maxTouchPoints",      "d", &d)) { P.has_touch=TRUE;  P.touch=d; }
        if (g_variant_lookup (ud, "devicePixelRatio",    "d", &d)) { P.has_dpr=TRUE;    P.dpr=d; }
        if (g_variant_lookup (ud, "screen_width",        "d", &d)) { P.has_sw=TRUE; P.sw=d; }
        if (g_variant_lookup (ud, "screen_height",       "d", &d)) { P.has_sh=TRUE; P.sh=d; }
        if (g_variant_lookup (ud, "screen_availWidth",   "d", &d)) { P.has_aw=TRUE; P.aw=d; }
        if (g_variant_lookup (ud, "screen_availHeight",  "d", &d)) { P.has_ah=TRUE; P.ah=d; }
        if (g_variant_lookup (ud, "screen_colorDepth",   "d", &d)) { P.has_cd=TRUE; P.cd=d; }
        if (g_variant_lookup (ud, "screen_pixelDepth",   "d", &d)) { P.has_pd=TRUE; P.pd=d; }
        if (g_variant_lookup (ud, "seed", "d", &d)) { P.has_seed = TRUE; P.seed = (guint32) d; }
    }
    g_signal_connect (webkit_script_world_get_default (), "window-object-cleared",
                      G_CALLBACK (on_window_object_cleared), NULL);
    g_signal_connect (ext, "page-created", G_CALLBACK (on_page_created), NULL);
}
