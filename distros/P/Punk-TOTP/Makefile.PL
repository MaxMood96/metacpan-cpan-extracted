use 5.010000;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use Config;

# Punk::TOTP takes its HMAC from File::Raw::Hash through frh_abi at
# runtime, so the dist links nothing: no libcrypto, no libsodium, and
# the only C dependency is the header this consumes at build time.

my $DEFINE = '';

my $pkg;
eval { $pkg = ExtUtils::Depends->new('Punk::TOTP', 'File::Raw::Hash'); 1 };
if (!$pkg) {
    die "Cannot find the File::Raw::Hash dependency.\n"
      . "Install File::Raw::Hash 0.04+, or place it as a sibling "
      . "directory.\n"
        unless -d '../File-Raw-Hash/include'
            || -d '../../File-Raw-Hash/include';
    $pkg = ExtUtils::Depends->new('Punk::TOTP');
    $pkg->set_inc('-Iinclude -I../File-Raw-Hash/include '
                 . '-I../../File-Raw-Hash/include');
} else {
    my %vars = $pkg->get_makefile_vars;
    $pkg->set_inc('-Iinclude ' . ($vars{INC} || ''));
}

# The header matters as much as the symbol: macOS and glibc declare
# getentropy in <sys/random.h>, the BSDs in <unistd.h>. Without the right
# one the probe "succeeds" through an implicit declaration - the same
# warning the real build then prints, or an error on a compiler that
# makes it one - so implicit declarations are fatal here, and whichever
# header set linked is what ptotp_rand.h includes.
{
    my $dir = "ptotp_probe_$$";
    mkdir $dir;
    my $cc  = $Config{cc} || 'cc';
    my $try = sub {
        my ($extra) = @_;
        my ($src, $bin) = ("$dir/p.c", "$dir/p");
        open my $fh, '>', $src or return 0;
        print $fh "#include <unistd.h>\n$extra"
                . "int main(void){ unsigned char b[16]; "
                . "return getentropy(b, sizeof b); }\n";
        close $fh;
        my $ok = system("$cc -Werror=implicit-function-declaration "
                      . "$src -o $bin >/dev/null 2>&1") == 0;
        unlink $src, $bin;
        return $ok;
    };
    my $sysrandom = $try->("#include <sys/random.h>\n");
    my $ok = $sysrandom || $try->('');
    rmdir $dir;
    if ($ok) {
        $DEFINE .= ' -DPTOTP_HAVE_GETENTROPY';
        $DEFINE .= ' -DPTOTP_HAVE_SYS_RANDOM_H' if $sysrandom;
        print "Found getentropy (linked, not just compiled).\n";
    } else {
        print "No getentropy; using /dev/urandom.\n";
    }
}

# qr_abi.h, for the plugin's enrolment QR. A sibling working copy wins
# over an installed QR::Code because it carries the newest ABI; failing
# both, the build cannot proceed.
my @qr_inc = map { "-I$_/include" }
             grep { -f "$_/include/qr_abi.h" } '../QR-Code', '../../QR-Code';
if (!@qr_inc) {
    my $qr = eval { ExtUtils::Depends::load('QR::Code') };
    die "Cannot find the QR::Code dependency.\n"
      . "Install QR::Code 0.03+, or place it as a sibling directory.\n"
        unless $qr && $qr->{inc};
    @qr_inc = ($qr->{inc});
}

my %dep = $pkg->get_makefile_vars;
my $INC = join ' ', grep { defined && length } '-Iinclude',
                    (grep { -d (my $d = "$_/include") } '../File-Raw-Hash', '../../File-Raw-Hash')
                        ? map { "-I$_/include" } grep { -d "$_/include" } '../File-Raw-Hash', '../../File-Raw-Hash'
                        : (),
                    @qr_inc,
                    delete $dep{INC};
delete $dep{LIBS};    # nothing links; an empty LIBS would clobber defaults
delete $dep{LDFROM};

# EU::Depends' PM map would otherwise replace MakeMaker's auto-detected
# PM (house gotcha); this dist provides no header yet, but the map is
# still active from the consumer side on some EU::Depends versions, so
# re-add lib/ unconditionally.
{
    require File::Find;
    File::Find::find(sub {
        # every file, not only .pm: the punk_totp Sqitch project ships under
        # lib/Punk/Plugin/TOTP/sqitch (a plan, a conf and SQL scripts)
        return unless -f $_;
        (my $rel = $File::Find::name) =~ s{^lib/}{};
        $dep{PM}{$File::Find::name} = "\$(INST_LIB)/$rel";
    }, 'lib');
}

# MakeMaker tracks nothing under include/, so header edits would not
# rebuild without this (house gotcha).
my $deps = join ' ', glob('include/ptotp/*.h'), glob('xs/*.xs');

WriteMakefile(
    NAME             => 'Punk::TOTP',
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Punk/TOTP.pm',
    ABSTRACT_FROM    => 'lib/Punk/TOTP.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
        'ExtUtils::Depends'   => '0.404',
        'File::Raw::Hash'     => '0.05',   # frh_abi.h at build time
        'QR::Code'            => '0.03',   # qr_abi.h v2 at build time
    },
    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },
    PREREQ_PM => {
        'ExtUtils::Depends' => '0.404',
        'File::Raw::Hash'   => '0.05',     # the hmac provider at runtime
        'QR::Code'          => '0.03',     # qr_abi v2: the enrolment QR
        'XSLoader'          => '0',
    },
    INC    => $INC,
    DEFINE => $DEFINE,
    XS     => { 'TOTP.xs' => 'TOTP.c' },
    OBJECT => 'TOTP$(OBJ_EXT)',
    depend => {
        'TOTP.c'         => $deps,
        'TOTP$(OBJ_EXT)' => $deps,
    },
    macro => { TARFLAGS => "--format=ustar -c -v -f" },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'Punk-TOTP-* TOTP.c TOTP.o TOTP.bs' },
    %dep,
);
