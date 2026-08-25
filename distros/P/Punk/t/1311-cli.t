#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use File::Temp ();
use Test::More;
use Punk::Command;

# The CLI's registry and dispatcher, driven IN-PROCESS through the documented
# capture seam: $Punk::Command::OUT/$ERR replace the streams and main()
# returns the exit code, so these tests cost no process spawns. Commands that
# load an application still go through a subprocess elsewhere (t/1310 and t/1301) -
# to_app is once per class.

sub run_punk {
    my (@argv) = @_;
    my ($out, $err) = ('', '');
    open my $ofh, '>', \$out or die $!;
    open my $efh, '>', \$err or die $!;
    local $Punk::Command::OUT = $ofh;
    local $Punk::Command::ERR = $efh;
    my $code = Punk::Command->main(@argv);
    close $ofh; close $efh;
    return ($code, $out, $err);
}

# ---- the registry contract -----------------------------------------------------

{
    Punk::Command->register('t57-once' => { hidden => 1, code => sub { 0 } },
                            'Owner::One');
    my $err = '';
    eval {
        Punk::Command->register('t57-once' => { code => sub { 0 } },
                                'Owner::Two');
    } or $err = $@;
    like($err, qr/'t57-once' is registered by both Owner::One and Owner::Two/,
        'a name collision croaks naming both owners');
}
{
    my $err = '';
    eval { Punk::Command->register('t57-bad') } or $err = $@;
    like($err, qr/needs a name and a spec hashref/, 'and a bad call croaks');
}
{
    Punk::Command->register_doctor('t57-row' => sub { (1, 'fine') },
                                   'Owner::One');
    my $err = '';
    eval {
        Punk::Command->register_doctor('t57-row' => sub { }, 'Owner::Two');
    } or $err = $@;
    like($err, qr/doctor row 't57-row' is registered by both/,
        'doctor rows collide by label too');
}

# ---- doctor finds a plugin's row without being told the plugin exists --------
#
# A command module registers at load, and nothing loads it until somebody
# types its name. That is right everywhere except here: `doctor` is the
# command whose job is "what have I got", so it loads every Punk::Command::*
# on @INC before printing the rows.
#
# In a subprocess, because the point is a module that has NOT been loaded and
# this file loads the fixture a few tests further down.
{
    my $code = 'require Punk::Command; '
             . 'my $o = q{}; open my $fh, q{>}, \\$o or die; '
             . 'local $Punk::Command::OUT = $fh; '
             . 'local $Punk::Command::ERR = $fh; '
             . 'Punk::Command->main(q{doctor}); close $fh; print $o;';
    my @inc = map { "-I$_" } ('blib/lib', 'blib/arch', 't/lib');
    my $out = qx{"$^X" @inc -e '$code' 2>&1};

    like($out, qr/\bFakecmd\b/,
        'doctor reports a plugin row from a module nothing had loaded');
    like($out, qr/the fixture is installed/, 'with what the probe returned');
}

{
    my $unused = 1;
}

# ---- generated help ------------------------------------------------------------

{
    my ($code, $out, $err) = run_punk();
    is($code, 0, 'bare punk exits 0');
    like($out, qr/^usage: punk <command> \[options\]$/m, 'with the usage line');
    like($out, qr/^  new <AppName>\s/m,        'new is listed');
    like($out, qr/^  generate <what>\s/m,      'generate is listed');
    like($out, qr/^  api sync\s/m,             'api sync shows its verb');
    like($out, qr/^  secret\s/m,               'secret is listed');
    unlike($out, qr/^  version\s/m,            'version is hidden from the list');
    is($err, '', 'nothing on stderr');
}
{
    my ($code, $out) = run_punk('help', 'routes');
    is($code, 0, 'help routes exits 0');
    like($out, qr/^usage: punk routes \[options\]/, 'usage first');
    like($out, qr/^  --method NAME\s/m, 'declared options appear');
    like($out, qr/^  --json\s/m,        'all of them');
    like($out, qr/^  --dir PATH\s/m,    'including the shared --dir');
    like($out, qr/^  --help\s/m,        'and --help');
}
{
    my ($c1, $o1) = run_punk('help', 'generate', 'model');
    is($c1, 0, 'help descends nested verbs');
    like($o1, qr/^usage: punk generate model <Name>/, 'to the leaf usage');
    like($o1, qr/--table NAME/, 'with its options');
}
{
    my ($code, $out, $err) = run_punk('help', 'nonsense');
    is($code, 2, 'help for an unknown command is a usage error');
    like($err, qr/no such command 'nonsense'/, 'named on stderr');
}

# ---- dispatch paths ------------------------------------------------------------

{
    my ($code, $out, $err) = run_punk('no-such-command');
    is($code, 2, 'an unknown command exits 2');
    like($err, qr/unknown command 'no-such-command'/, 'and says so');
    like($err, qr/usage: punk <command>/, 'with the usage on stderr');
}
{
    # the plugin seam: an unknown token gets one require attempt against
    # Punk::Command::<Ucfirst>, whose load registers it
    my ($code, $out) = run_punk('fakecmd', '--shout');
    is($code, 42, 'a plugin-registered command dispatches after the probe');
    like($out, qr/^FAKE$/m, 'with its options parsed');
}
{
    my ($code, undef, $err) = run_punk('routes', '--nope');
    is($code, 2, 'an unknown option is a usage error');
    like($err, qr/punk routes: Unknown option/, 'prefixed with the command');
    like($err, qr/usage: punk routes/, 'usage follows');
}
{
    my ($code, undef, $err) = run_punk('new');
    is($code, 2, 'a missing required argument is a usage error');
    like($err, qr/punk new: an application name is required/,
        'the usage_error die surfaces with the command prefix');
}

# ---- the kit seam --------------------------------------------------------------
# `punk new X --kit NAME` loads Punk::Kit::<Ucfirst> and generates through it.
# The options it declares are resolved out of argv before Getopt runs, so they
# parse and appear in help like the command's own.

{
    my ($code, $out) = run_punk('new', 'X', '--kit', 'fakekit', '--help');
    is($code, 0, '--help with a kit exits 0');
    like($out, qr/kit options \(fakekit\):/,
        "the kit's options get their own heading");
    like($out, qr/--shout\s+upper case the note/,
        'and are listed with the doc the kit declared');
    like($out, qr/--force\s/, "beside the command's own");
}
{
    # help without a kit must not load one, and must not advertise its options
    my ($code, $out) = run_punk('new', '--help');
    is($code, 0, 'plain --help exits 0');
    unlike($out, qr/--shout/, 'no kit is loaded, so no kit options');
    like($out, qr/--kit NAME/, 'but --kit is offered');
}
{
    my ($code, undef, $err) = run_punk('new', 'X', '--kit', 'nope');
    is($code, 1, 'a kit that is not installed exits 1');
    like($err, qr/kit 'nope' is not installed \(no Punk::Kit::Nope on \@INC\)/,
        'naming the class it looked for');
    like($err, qr/kits ship in their own distributions/,
        'with the hint about where kits come from');
}
{
    my ($code, undef, $err) = run_punk('new', 'X', '--kit', 'Bad Name');
    is($code, 2, 'a kit name that is not a kit name is misuse');
    like($err, qr/--kit takes a name like 'diy'/, 'and says what one looks like');
}
{
    # --kit=NAME and --kit NAME are one option, and the pre-scan reads both
    my ($code, $out) = run_punk('new', 'X', '--kit=fakekit', '--help');
    is($code, 0, 'the = spelling works too');
    like($out, qr/--shout/, 'and finds the same kit');
}
{
    # an option the command already declares is refused rather than ordered:
    # whichever Getopt bound would decide what the command does
    my ($code, undef, $err) = run_punk('new', 'X', '--kit', 'fakeclash', '--help');
    is($code, 1, 'a kit option colliding with one of new\'s exits 1');
    like($err, qr/option '--force' is defined by both 'new' and Punk::Kit::Fakeclash/,
        'naming both owners');
    unlike($err, qr/ at \S+ line \d+/, 'as one line, not a raw croak');
}

# ---- version -------------------------------------------------------------------

{
    my ($c1, $flag) = run_punk('--version');
    my ($c2, $sub)  = run_punk('version');
    is($c1, 0, '--version exits 0');
    is($c2, 0, 'so does the subcommand');
    is($flag, $sub, 'and they print the same line');
    like($flag, qr/^punk \Q$Punk::VERSION\E$/, 'which is $Punk::VERSION alone');
}

# ---- secret --------------------------------------------------------------------

{
    my ($code, $out) = run_punk('secret');
    is($code, 0, 'secret exits 0');
    chomp $out;
    like($out, qr/^[A-Za-z0-9_-]{43}$/,
        'default: 32 bytes as unpadded url-safe base64, one line');
}
{
    my ($code, $out) = run_punk('secret', '--hex', '--bytes', '16');
    chomp $out;
    like($out, qr/^[0-9a-f]{32}$/, '--hex --bytes 16 is 32 hex chars');
}
{
    my ($c1, $o1) = run_punk('secret');
    my ($c2, $o2) = run_punk('secret');
    isnt($o1, $o2, 'two secrets differ');
}
{
    my ($code, undef, $err) = run_punk('secret', '--bytes', '4');
    is($code, 2, 'too little entropy is refused');
    like($err, qr/between 16 and 256/, 'with the bounds');
}

done_testing;
