use v5.10; use strict; use warnings;
use Test::More;
use File::Temp 'tempdir';
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# UTF-8 round-trip across the JS bridge. Strings are built with \x{...}
# escapes (not `use utf8` + literal source bytes) so this test is unambiguous
# regardless of the source file's own encoding.
#
# (a)/(c) exercise JS -> Perl (script/element accessor results); (b) exercises
# Perl -> JS -> Perl (args in, DOM value out); (d) exercises the cookie
# snapshot file, which goes through the same _enc/_dec codec but via a
# filehandle rather than the GI JS bridge.

my $b = EV::WebKit->new(window=>[300,200]);
my %g;

# (a) entity-encoded non-ASCII text (avoids any source-encoding ambiguity)
# must read back as the exact CHARACTER string.
$b->load_html('<html><body><p id="u">h&#233;llo &#x65e5;&#x672c;</p></body></html>', sub {
    my (undef, $err) = @_;
    return do { $g{a_err} = $err // 'load failed'; EV::break } if $err;
    $b->find('#u', sub {
        my ($el, $err) = @_;
        return do { $g{a_err} = $err // 'find failed'; EV::break } if $err || !$el;
        $el->text(sub {
            my ($text, $err) = @_;
            $g{a_text} = $text; $g{a_text_err} = $err;
            test_b();
        });
    });
});

sub test_b {
    # (b0) isolate the OUTBOUND (Perl -> JS args) leg on its own, the same
    # way the reviewer's utf8_probe2.pl T4b/T4c do: JS reports back the
    # CODE POINTS it received (plain numbers), sidestepping the return-leg
    # string marshalling entirely so a mismatch here can only be the args
    # leg. This matters because (b)'s full round trip below can happen to
    # come back equal to the original even when the args leg mangles it --
    # a broken outbound leg (bytes upgraded as Latin-1) and a broken return
    # leg (characters mis-decoded as bytes) are not necessarily each other's
    # inverse, but for some inputs the two bugs can cancel out.
    my $msg = "caf\x{e9}\x{65e5}";
    $b->script_async('return [...A.msg].map(c => c.codePointAt(0));', { msg => $msg }, sub {
        my ($cps, $err) = @_;
        $g{b_cps} = $cps; $g{b_cps_err} = $err;

        # (b) type() a non-ASCII string (Perl -> JS args leg) into an input,
        # read the DOM's own value back out (JS -> Perl leg) -- full round trip.
        $b->script('document.body.innerHTML = "<input id=inp>"; return true;', sub {
            my (undef, $err) = @_;
            return do { $g{b_err} = $err // 'script failed'; EV::break } if $err;
            $b->find('#inp', sub {
                my ($el, $err) = @_;
                return do { $g{b_err} = $err // 'find failed'; EV::break } if $err || !$el;
                $el->type($msg, sub {
                    my (undef, $err) = @_;
                    return do { $g{b_err} = $err // 'type failed'; EV::break } if $err;
                    $el->value(sub {
                        my ($val, $err) = @_;
                        $g{b_val} = $val; $g{b_val_err} = $err;
                        test_c();
                    });
                });
            });
        });
    });
}

sub test_c {
    # (c) script() returning a non-ASCII literal built entirely in JS
    # (String.fromCharCode) -- no args leg involved, isolates the return leg.
    $b->script('return String.fromCharCode(233, 26085);', sub {
        my ($r, $err) = @_;
        $g{c_val} = $r; $g{c_err} = $err;
        test_d();
    });
}

my $dir = tempdir(CLEANUP => 1);
sub test_d {
    # (d) cookie-snapshot file round-trip: a Latin-1-range char AND a CJK
    # char in the same cookie value, saved by one instance and loaded by a
    # fresh one (simulating a save-then-restart cycle, like t/62-cookiejar.t).
    my $snap = "$dir/snap.json";
    my $val  = "p\x{e9}\x{65e5}";
    $b->set_cookie({ name=>'u', value=>$val, domain=>'unicode.test', path=>'/' }, sub {
        my (undef, $err) = @_;
        return do { $g{d_err} = $err // 'set_cookie failed'; EV::break } if $err;
        $b->save_cookies($snap, ['http://unicode.test/'], sub {
            my (undef, $err) = @_;
            return do { $g{d_err} = $err // 'save_cookies failed'; EV::break } if $err;
            test_e($snap, $val);
        });
    });
}

sub test_e {
    my ($snap, $val) = @_;
    my $b2 = EV::WebKit->new(window=>[300,200]);
    $b2->load_cookies($snap, sub {
        my (undef, $err) = @_;
        return do { $g{d_err} = $err // 'load_cookies failed'; $b2->quit; EV::break } if $err;
        $b2->cookies('http://unicode.test/', sub {
            my ($list, $err) = @_;
            $g{d_list} = $list; $g{d_list_err} = $err;
            $b2->quit;
            test_f();
        });
    });
}

sub test_f {
    # (e) mock_scheme sibling site: a producer body built as a Perl character
    # string (utf8-flagged, non-ASCII) must be served/round-tripped correctly.
    # Glib::Bytes expects raw octets -- on unfixed code, handing it a
    # wide-flagged string is a confirmed-live CRASH inside the (eval-less)
    # register_uri_scheme callback, which unwinds destructively through the
    # GI/C call stack rather than surfacing as a clean Perl-level error. Run
    # the actual check in a bounded CHILD PROCESS so that crash (pre-fix)
    # shows up as a clean test failure here instead of taking down this
    # whole .t file.
    my $child_src = <<'PERL';
use v5.10; use strict; use warnings;
use EV; use EV::WebKit;
binmode(STDOUT, ':utf8');
my $b = EV::WebKit->new(window=>[300,200]);
$b->mock_scheme('mockuni', sub {
    # charset=utf-8 is required here: the body is a bare fragment with no
    # <meta charset> of its own, and WebKit's HTML parser falls back to
    # Latin-1 without an explicit declaration from one or the other --
    # exactly like any real HTTP server sending UTF-8 HTML must say so.
    return ("<html><body>caf\x{e9} \x{65e5}\x{672c}</body></html>", 'text/html; charset=utf-8');
});
my $guard = EV::timer(10, 0, sub { print "TIMEOUT\n"; EV::break });   # lexical: a void-context watcher is collected before it fires
$b->go('mockuni://x', sub {
    my (undef, $err) = @_;
    if (defined $err) { print "ERR:$err\n"; EV::break; return }
    $b->script('return document.body.textContent;', sub {
        my ($text, $err) = @_;
        print +(defined($err) ? "ERR:$err\n" : "OK:".($text // '')."\n");
        EV::break;
    });
});
EV::run;
PERL
    my $childfile = "$dir/mockuni_child.pl";
    open my $cfh, '>', $childfile or die "write $childfile: $!";
    print $cfh $child_src;
    close $cfh;
    my $out;
    my $ok = open(my $rfh, '-|', 'timeout', '-k', '5', '20', $^X,
                        (map { "-I$_" } grep { !ref && length } @INC),   # the same lib the parent was told to use
                        $childfile);
    if ($ok) {
        binmode($rfh, ':utf8');
        $out = do { local $/; <$rfh> };
        close $rfh;
    }
    $g{e_out} = $ok ? ($out // '(no output -- child crashed or was killed)') : "SPAWN-FAILED:$!";
    EV::break;
}

TWK::run_with_timeout(40);   # generous: test_f blocks on a child process bounded at 25s (20s + 5s kill-after)

is($g{a_text}, "h\x{e9}llo \x{65e5}\x{672c}", '(a) entity-encoded non-ASCII text round-trips as a character string');
ok(!defined $g{a_text_err}, '(a) no error reading non-ASCII text') or diag($g{a_text_err});

is_deeply($g{b_cps}, [99,97,102,233,26085], '(b0) outbound (Perl -> JS args) leg: JS receives the correct code points')
    or diag(explain($g{b_cps}));
ok(!defined $g{b_cps_err}, '(b0) no error running the code-point probe script') or diag($g{b_cps_err});

is($g{b_val}, "caf\x{e9}\x{65e5}", '(b) type() non-ASCII string round-trips via value()');
ok(!defined $g{b_val_err}, '(b) no error reading non-ASCII value') or diag($g{b_val_err});

is($g{c_val}, "\x{e9}\x{65e5}", '(c) script() non-ASCII String.fromCharCode literal round-trips');
ok(!defined $g{c_err}, '(c) no error running non-ASCII script') or diag($g{c_err});

ok(!defined $g{d_err}, '(d) no error in cookie snapshot save/load round-trip') or diag($g{d_err});
ok(!defined $g{d_list_err}, '(d) no error reading cookies after load') or diag($g{d_list_err});
my ($u) = grep { $_->{name} eq 'u' } @{ $g{d_list} || [] };
ok($u, '(d) unicode cookie found after snapshot round-trip');
is($u->{value}, "p\x{e9}\x{65e5}", '(d) cookie value round-trips exactly as a character string') if $u;

like($g{e_out} // '', qr/^OK:caf\x{e9} \x{65e5}\x{672c}\s*\z/,
    '(e) mock_scheme non-ASCII body served and round-tripped (child process -- a crash/mismatch fails cleanly here)')
    or diag($g{e_out});

$b->quit;
done_testing;
