use v5.40;
use blib;
use FindBin qw[$RealBin];
use Affix   qw[:all];
use File::Spec;
use File::Temp qw[tempdir tempfile];
use File::Copy qw[copy];
use Cwd        qw[getcwd];
use Alien::Xmake;
my $_start_cwd = getcwd;

# nuklear window-flags
use constant {
    NK_WINDOW_BORDER      => 0x01,
    NK_WINDOW_MOVABLE     => 0x02,
    NK_WINDOW_SCALABLE    => 0x04,
    NK_WINDOW_CLOSABLE    => 0x08,
    NK_WINDOW_MINIMIZABLE => 0x10,
    NK_WINDOW_TITLE       => 0x40,
    NK_TEXT_LEFT          => 0x11,
    NK_TEXT_CENTERED      => 0x12,
    NK_TEXT_RIGHT         => 0x14
};

# Builds the small C shim (nk_win.c) into a shared library, installing the result into this
# script's own directory so it is found deterministically. The build runs in a temp directory
# (never in place) so xmake does not walk up and mistake a parent xmake.lua for the project root.
# Because Capture::Tiny swallows xmake's interactive "y/n/m" prompt for first-time package
# installs, we feed a stream of "y" answers to stdin and pass --yes / --confirm=yes so nothing ever
# hangs waiting on a TTY. Well, that's the plan anyway...
my $src_dir  = $RealBin;
my $dest_dir = $RealBin;                                                         # install the .dll/.so next to this script
my $ext      = $^O eq 'MSWin32' ? '.dll' : $^O eq 'darwin' ? '.dylib' : '.so';
my $artifact = File::Spec->catfile( $dest_dir, "nk_win$ext" );
my $tool     = Alien::Xmake->new( verbose => 0, yes => 1 );
die 'no xmake available via Alien::Xmake' unless $tool->exe;

# Run `xmake <action>` in $dir (a temp copy of the project), feeding repeated "y" answers on stdin.
# xmake's first-run package install reads io.read() and ignores the global --yes/-y flag, so a
# piped/redirected "y" is the only way to answer it without a TTY. We redirect stdin from a temp
# file of "y"s via the shell; stdout/stderr are inherited so the user sees xmake's progress.
sub run_xmake ( $dir, @args ) {
    local $ENV{XMAKE_THEME} = 'plain';
    my ( $fh, $yfile ) = tempfile( SUFFIX => '.in', UNLINK => 0 );
    print {$fh} ("y\n") x 16;
    close $fh  or die "close $yfile: $!";
    chdir $dir or die "chdir $dir: $!";
    my $cmd = join ' ', map { /\s/ ? '"' . $_ . '"' : $_ } ( $tool->exe, @args );
    return system("$cmd < $yfile") == 0;
}

# ensure the shim sources are present
die "Missing $src_dir/nk_win.c\n" unless -f File::Spec->catfile( $src_dir, 'nk_win.c' );
if ( !-f $artifact ) {
    say 'Building nk_win shim (this installs nuklear on first run)...';
    my $work = tempdir( CLEANUP => 1 );
    copy( File::Spec->catfile( $src_dir, $_ ), $work ) for qw[ nk_win.c nuklear_gdi.h nuklear_xlib.h xmake.lua ];

    # configure step; this is where the nuklear package is fetched/installed
    run_xmake( $work, 'f', '-m', 'release' ) or die 'xmake config failed';

    # build the shared library
    run_xmake( $work, 'build' ) or die 'xmake build failed';

    # locate the produced shared library
    my ( $plat, $arch ) = ( $^O eq 'MSWin32' ? ( 'windows', 'x64' ) : ( 'linux', 'x86_64' ) );
    ( $plat, $arch ) = ( 'macosx', 'x86_64' ) if $^O eq 'darwin';
    my $built = File::Spec->catfile( $work, 'build', $plat, $arch, 'release', "nk_win$ext" );
    die "built library not found: $built" unless -f $built;
    copy( $built, $artifact ) or die "copy to $artifact: $!";
    chdir $_start_cwd;    # leave the temp dir so File::Temp can clean it up
    say "Installed $artifact";
}
my $dll = $artifact;
die "nk_win$ext not found at $dll" unless -f $dll;

# wrapper (single window, message pump)
affix $dll, 'nk_win_init',     [ WString, Int, Int, String, Int ]                           => Int;
affix $dll, 'nk_win_poll',     []                                                           => Void;
affix $dll, 'nk_win_running',  []                                                           => Int;
affix $dll, 'nk_win_render',   [ Int, Int, Int, Int ]                                       => Void;
affix $dll, 'nk_win_shutdown', []                                                           => Void;
affix $dll, 'nk_win_context',  []                                                           => Pointer [Void];
affix $dll, 'nk_win_begin',    [ Pointer [Void], String, Float, Float, Float, Float, UInt ] => Int;

# nuklear API (direct exports)
affix $dll, 'nk_end',                [ Pointer [Void] ]                                => Void;
affix $dll, 'nk_label',              [ Pointer [Void], String, Int ]                   => Void;
affix $dll, 'nk_button_label',       [ Pointer [Void], String ]                        => Int;
affix $dll, 'nk_layout_row_dynamic', [ Pointer [Void], Float, Int ]                    => Void;
affix $dll, 'nk_slide_float',        [ Pointer [Void], Float, Float, Float, Float ]    => Float;
affix $dll, 'nk_checkbox_label',     [ Pointer [Void], String, Pointer [Int] ]         => Int;
affix $dll, 'nk_option_label',       [ Pointer [Void], String, Int ]                   => Int;
affix $dll, 'nk_progress',           [ Pointer [Void], Pointer [Size_t], Size_t, Int ] => Int;
affix $dll, 'nk_group_begin',        [ Pointer [Void], String, Int ]                   => Int;
affix $dll, 'nk_group_end',          [ Pointer [Void] ]                                => Void;
affix $dll, 'nk_spacing',            [ Pointer [Void], Int ]                           => Void;
die 'failed to open window' unless nk_win_init( 'Affix + Nuklear', 900, 640, 'Arial', 14 );
my $ctx = nk_win_context();

# Idempotent teardown: nk_win_shutdown() is unsafe to call twice, and the END block runs it again
# at exit, so route every shutdown through this flag.
my $shut_down = 0;
sub _nk_shutdown { nk_win_shutdown(); $shut_down = 1 }
END { nk_win_shutdown() if !$shut_down && defined &nk_win_shutdown; }
my $clicks_a = 0;
my $clicks_b = 0;
my $red      = 20;
my $green    = 60;
my $show_bar = 1;
my $progress = 25;
my $choice   = 0;
my @log      = ('window opened');

sub log_line ($text) {
    push @log, $text;
    shift @log while @log > 8;
}
my $WIN_FLAGS = NK_WINDOW_TITLE | NK_WINDOW_BORDER | NK_WINDOW_MOVABLE | NK_WINDOW_SCALABLE | NK_WINDOW_CLOSABLE;

# non-interactive smoke test (set NK_SMOKE=1): bind, render one frame, exit
if ( $ENV{NK_SMOKE} ) {
    nk_win_begin( $ctx, 'Smoke', 40, 40, 480, 480, $WIN_FLAGS );
    nk_layout_row_dynamic( $ctx, 25, 1 );
    nk_label( $ctx, 'smoke ok', NK_TEXT_LEFT );
    nk_end($ctx);
    nk_win_render( 20, 60, 40, 255 );
    _nk_shutdown();
    say 'NK_SMOKE OK';
    exit 0;
}
while ( nk_win_running() ) {
    nk_win_poll();
    if ( nk_win_begin( $ctx, 'Demo', 40, 40, 480, 480, $WIN_FLAGS ) ) {
        nk_layout_row_dynamic( $ctx, 25, 1 );
        nk_label( $ctx, 'Nuklear driven from Perl via Affix', NK_TEXT_LEFT );
        nk_layout_row_dynamic( $ctx, 30, 2 );
        if ( nk_button_label( $ctx, 'Button A' ) ) { $clicks_a++; log_line 'pressed Button A' }
        if ( nk_button_label( $ctx, 'Button B' ) ) { $clicks_b++; log_line 'pressed Button B' }
        nk_layout_row_dynamic( $ctx, 25, 1 );
        nk_label( $ctx, sprintf( 'A:%d  B:%d', $clicks_a, $clicks_b ), NK_TEXT_LEFT );
        nk_layout_row_dynamic( $ctx, 25, 2 );
        nk_label( $ctx, 'Red', NK_TEXT_LEFT );
        $red = nk_slide_float( $ctx, 0, $red, 255, 1 );
        nk_label( $ctx, 'Green', NK_TEXT_LEFT );
        $green = nk_slide_float( $ctx, 0, $green, 255, 1 );
        nk_layout_row_dynamic( $ctx, 25, 1 );

        if ( nk_checkbox_label( $ctx, 'Show progress bar', \$show_bar ) ) {
            log_line $show_bar ? 'progress bar on' : 'progress bar off';
        }
        if ($show_bar) {
            nk_progress( $ctx, \$progress, 100, 1 );
        }
        nk_layout_row_dynamic( $ctx, 25, 1 );
        if ( nk_option_label( $ctx, 'Option 1', $choice == 0 ) ) { $choice = 0 }
        if ( nk_option_label( $ctx, 'Option 2', $choice == 1 ) ) { $choice = 1 }
        if ( nk_option_label( $ctx, 'Option 3', $choice == 2 ) ) { $choice = 2 }
        nk_spacing( $ctx, 1 );
        nk_layout_row_dynamic( $ctx, 20, 1 );
        if ( nk_group_begin( $ctx, 'Log', 0 ) ) {
            nk_layout_row_dynamic( $ctx, 18, 1 );
            nk_label( $ctx, $_, NK_TEXT_LEFT ) for @log;
            nk_group_end($ctx);
        }
    }
    nk_end($ctx);
    nk_win_render( int($red), int($green), 40, 255 );
}
