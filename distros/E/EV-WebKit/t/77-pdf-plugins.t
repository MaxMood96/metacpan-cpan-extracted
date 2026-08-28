use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use EV::WebKit::Fingerprint;
plan skip_all => 'needs the fingerprint web-process extension'
    unless EV::WebKit::Fingerprint::available();

# navigator.pdfViewerEnabled / plugins / mimeTypes.
#
# The HTML spec hardcodes both states: a browser with inline PDF viewing reports
# pdfViewerEnabled true plus five fixed plugin names; one without reports false
# and EMPTY lists. WebKitGTK reports the viewer-present state, which is right for
# every preset EXCEPT Chrome for Android at 131 -- that build had no inline PDF
# viewer at all (Chrome 131 Android shipped 2024-11-06; the Android viewer first
# appeared behind a flag in 2024-12 and became default-on only in Chrome 135,
# 2025-04). So pixel-chrome must report the empty state.

sub probe {
    my ($profile) = @_;
    my $b = EV::WebKit->new(window => [200,150], fingerprint => $profile);
    $b->mock_scheme('pp', sub { ('<html><body>p</body></html>','text/html') });
    my $out;
    $b->go('pp://host/p', sub {
        $b->script(<<'JS', sub { $out = $_[0]; EV::break });
          const own = (o,k) => { const x = Object.getOwnPropertyDescriptor(o,k);
                                 return x ? (x.get ? 'accessor' : 'data') : 'absent' };
          let err = null, item0, named, refreshed = 'not-called';
          try { item0 = navigator.plugins.item(0); } catch(e) { err = 'item:' + e.name }
          try { named = navigator.plugins.namedItem('PDF Viewer'); }
          catch(e) { err = (err || '') + ' named:' + e.name }
          // refresh() brand-checks like the rest, and a plugin-probing script
          // calls it. Left unpatched it threw "Can only call PluginArray.refresh
          // on instances of PluginArray" -- breaking the page AND announcing the
          // spoof in one call, where real Chrome returns undefined.
          try { refreshed = String(navigator.plugins.refresh()); }
          catch(e) { refreshed = 'THREW:' + e.name }
          return JSON.stringify({
            pdf:      navigator.pdfViewerEnabled,
            plugins:  navigator.plugins.length,
            mimes:    navigator.mimeTypes.length,
            tagP:     Object.prototype.toString.call(navigator.plugins),
            tagM:     Object.prototype.toString.call(navigator.mimeTypes),
            same:     navigator.plugins === navigator.plugins,
            sameM:    navigator.mimeTypes === navigator.mimeTypes,
            ownLen:   own(navigator.plugins, 'length'),
            protoLen: own(PluginArray.prototype, 'length'),
            item0:    item0 === null ? 'null' : typeof item0,
            named:    named === null ? 'null' : typeof named,
            refreshed: refreshed,
            // a replacement function inherits neither the original's name nor
            // its arity; both read without Function.prototype.toString, so they
            // sit outside the documented detection ceiling
            itemName:  navigator.plugins.item.name,
            itemLen:   navigator.plugins.item.length,
            namedName: navigator.plugins.namedItem.name,
            lenGetName: (Object.getOwnPropertyDescriptor(PluginArray.prototype,'length').get || {}).name,
            mimeItemName: navigator.mimeTypes.item.name,
            // an ordinary function expression has an own `prototype`; a real
            // WebIDL method does not. Compared against a native method rather
            // than a hardcoded false, so the assertion tracks the engine.
            itemProto:   Object.prototype.hasOwnProperty.call(navigator.plugins.item, 'prototype'),
            nativeProto: Object.prototype.hasOwnProperty.call(Document.prototype.getElementById, 'prototype'),
            err:      err,
          });
JS
    });
    TWK::run_with_timeout(20);
    $b->quit;
    require Cpanel::JSON::XS;
    return eval { Cpanel::JSON::XS::decode_json($out // '{}') } || {};
}

# --- pixel-chrome: Chrome 131 for Android had NO inline PDF viewer ---
{
    my $r = probe('pixel-chrome');
    is($r->{pdf}, 0,     'pixel-chrome: pdfViewerEnabled is false');
    is($r->{plugins}, 0, 'pixel-chrome: navigator.plugins is empty');
    is($r->{mimes}, 0,   'pixel-chrome: navigator.mimeTypes is empty');
    # the empty lists must still be REAL platform objects, not arrays or literals
    is($r->{tagP}, '[object PluginArray]',   '...and is still a PluginArray');
    is($r->{tagM}, '[object MimeTypeArray]', '...and mimeTypes a MimeTypeArray');
    ok($r->{same},  'plugins returns the SAME object each read (as a real browser caches it)');
    ok($r->{sameM}, 'mimeTypes likewise');
    # length lives on the PROTOTYPE in a real browser; shadowing it as an own
    # property would be a one-call tell, so this is the load-bearing assertion
    is($r->{ownLen}, 'absent',    'length is NOT an own property of the empty list');
    is($r->{protoLen}, 'accessor','...it stays a prototype accessor, where a real browser keeps it');
    # brand-checking members must answer rather than throw
    is($r->{err}, undef,        'item()/namedItem() do not throw on the empty list');
    is($r->{item0}, 'null',     'item(0) is null on an empty list');
    is($r->{named}, 'null',     'namedItem() is null on an empty list');
    is($r->{refreshed}, 'undefined',
       'refresh() returns undefined rather than throwing a brand-check TypeError');
    # ...and the replacements are indistinguishable from the natives by the two
    # properties a probe can read without Function.prototype.toString
    is($r->{itemName},   'item',       'item keeps its name');
    is($r->{itemLen},    1,            '...and its arity');
    is($r->{namedName},  'namedItem',  'namedItem keeps its name');
    is($r->{lenGetName}, 'get length', "the length accessor keeps its 'get length' name");
    is($r->{mimeItemName}, 'item',     'the same holds for MimeTypeArray');
    is($r->{itemProto}, $r->{nativeProto},
       'a patched member has an own "prototype" exactly as a native method does (neither)');
}

# --- every other preset keeps WebKit's own viewer-present state ---
for my $p (qw(windows-chrome macos-safari iphone-safari)) {
    my $r = probe($p);
    is($r->{pdf}, 1,     "$p: pdfViewerEnabled stays true");
    is($r->{plugins}, 5, "$p: the five spec-hardcoded plugins are still reported");
    is($r->{mimes}, 2,   "$p: both PDF mime types are still reported");
    # the shared prototype must NOT be left patched for a profile that opted out
    is($r->{item0}, 'object', "$p: item(0) still returns a real Plugin");
    is($r->{err}, undef,      "$p: no brand-check breakage");
}

# --- pure-Perl: the profile data and its plumbing ---
{
    my $px = EV::WebKit::Fingerprint::resolve('pixel-chrome');
    is($px->{pdf_viewer}, 0, 'pixel-chrome carries pdf_viewer => 0');
    my $c = EV::WebKit::Fingerprint::_coherence($px);
    ok($c->{no_pdf_viewer}, 'the coherence blob asks the JS layer to empty the lists');

    for my $p (qw(windows-chrome macos-safari iphone-safari)) {
        my $r = EV::WebKit::Fingerprint::resolve($p);
        ok(!exists $r->{pdf_viewer}, "$p does not set pdf_viewer");
        my $cc = EV::WebKit::Fingerprint::_coherence($r);
        ok(!$cc->{no_pdf_viewer}, "$p emits no no_pdf_viewer flag");
    }

    # overridable, and validated as a bool like every other flag
    my $ov = EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', pdf_viewer => 0 });
    is($ov->{pdf_viewer}, 0, 'pdf_viewer can be overridden per instance');
    eval { EV::WebKit::Fingerprint::resolve({ profile => 'windows-chrome', pdf_viewer => 'yes' }) };
    like($@, qr/pdf_viewer/, 'a non-bool pdf_viewer croaks');
}

done_testing;
