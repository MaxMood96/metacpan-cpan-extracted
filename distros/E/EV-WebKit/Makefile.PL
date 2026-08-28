use v5.10; use strict; use warnings;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;
use Config;
use File::Path;

# The web-process extension is compiled at install if the toolchain is present.
# It needs ONLY cc + glib/gobject (NOT webkit/jsc dev headers -- symbols resolve
# at dlopen in the web process). If unavailable, we warn and ship without it;
# the module stays fully usable and fingerprint => croaks at runtime.
my $so_built = build_wext();
install_share dist => 'share' if $so_built;

WriteMakefile(
    NAME             => 'EV::WebKit',
    VERSION_FROM     => 'lib/EV/WebKit.pm',
    ABSTRACT         => 'Async WebKitGTK 6.0 (GTK4) browser automation on EV',
    AUTHOR           => 'vividsnow',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    PREREQ_PM        => {
        'EV' => 0, 'EV::Glib' => 0, 'Glib' => 0,
        'Glib::Object::Introspection' => 0, 'Cpanel::JSON::XS' => 0,
        'Glib::IO' => 0, 'File::ShareDir' => 0,
    },
    CONFIGURE_REQUIRES => { 'File::ShareDir::Install' => 0 },
    TEST_REQUIRES    => { 'Test::More' => 0 },
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/vividsnow/perl5-ev-webkit.git',
                web  => 'https://github.com/vividsnow/perl5-ev-webkit',
            },
            bugtracker => { web => 'https://github.com/vividsnow/perl5-ev-webkit/issues' },
        },
        # Loaded only when network_fingerprint/on_request/on_response is asked
        # for, and croaks legibly when absent -- so a recommendation, not a
        # requirement that would drag a libcurl build into every install.
        prereqs => { runtime => { recommends => { 'Proxy::Impersonate' => '0.01' } } },
        # Generated from lib/ rather than hand-listed, so it cannot go stale as
        # packages are added -- and six of the thirteen are declared INSIDE
        # WebKit.pm (Auth, Dialog, Download, FileChooser, Policy, UserContent),
        # which is exactly what a hand-written list forgets. Soft-guarded rather than
        # a CONFIGURE_REQUIRES: Module::Metadata is core since 5.14 but this
        # dist still declares 5.010, and provides is author-side metadata that
        # only has to be right in the tarball that gets uploaded.
        (eval { require Module::Metadata; 1 }
            ? (provides => Module::Metadata->provides(version => 2, dir => 'lib'))
            : ()),
    },
);

package MY;
use File::ShareDir::Install;
# The extension is compiled below at Makefile.PL time, but WITHOUT a make rule
# `make` would only copy the already-built .so into blib: editing
# wext/evwk_fp.c and running `make test` then silently tested the stale
# binary -- a mutation that should have failed the suite passed instead.
# Emitting the same command as a real dependency rule makes the edit/test loop
# honest. Only emitted when the compile above actually succeeded, so a host
# without the toolchain still installs (fingerprint disabled) rather than
# failing at make time.
sub postamble {
    my $self = shift;
    my $out  = '';
    # Emitted BEFORE the File::ShareDir::Install rule: `config` is a
    # double-colon target and make runs its rules in makefile order, so the
    # dependency must be declared ahead of the rule that copies the .so into
    # blib -- otherwise the copy still takes the stale binary and the rebuild
    # lands one `make` too late.
    $out .= "share/wext/evwk_fp.so :: wext/evwk_fp.c\n\t$main::WEXT_CMD\n\n"
          . "config :: share/wext/evwk_fp.so\n\n" if $main::WEXT_CMD;
    # README is generated, never edited: a hand-kept one drifts from the POD.
    # create_distdir, not distdir -- distdir builds its prerequisites left to
    # right, so create_distdir would copy the files before README was remade.
    $out .= "\nreadme : README\n\n"
          . "README : lib/EV/WebKit.pm\n"
          . "\t\$(PERLRUN) -MPod::Text -e \"Pod::Text->new->parse_from_file(q{lib/EV/WebKit.pm}, q{README})\"\n\n"
          . "create_distdir : README\n\n";
    return $out . File::ShareDir::Install::postamble($self);
}

package main;
our $WEXT_CMD;   # the compile command, set by build_wext on success
# Compile wext/evwk_fp.c -> share/wext/evwk_fp.so. Returns 1 on success.
sub build_wext {
    my $cc = $Config{cc} || 'cc';
    system("pkg-config --exists gobject-2.0 glib-2.0") == 0
        or do { warn "EV::WebKit: pkg-config gobject-2.0/glib-2.0 not found -- fingerprint disabled\n"; return 0 };
    my $cflags = `pkg-config --cflags gobject-2.0 glib-2.0`; chomp $cflags;
    my $libs   = `pkg-config --libs gobject-2.0 glib-2.0`;   chomp $libs;
    File::Path::make_path('share/wext');
    # webkit/jsc symbols are left unresolved at link (they resolve at dlopen in
    # the web process). macOS ld64 spells this differently from GNU ld / lld.
    my $undef = $^O eq 'darwin' ? '-Wl,-undefined,dynamic_lookup'
                                : '-Wl,--unresolved-symbols=ignore-all';
    my $cmd = "$cc -shared -fPIC -o share/wext/evwk_fp.so wext/evwk_fp.c "
            . "$cflags $libs $undef";
    warn "EV::WebKit: building web-process extension:\n  $cmd\n";
    if (system($cmd) == 0 && -e 'share/wext/evwk_fp.so') { $WEXT_CMD = $cmd; return 1 }
    warn "EV::WebKit: web-process extension build FAILED -- fingerprint disabled (module still installs)\n";
    return 0;
}
