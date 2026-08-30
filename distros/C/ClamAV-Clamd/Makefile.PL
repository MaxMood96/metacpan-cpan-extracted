use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

my %WriteMakefileArgs = (
    NAME             => 'ClamAV::Clamd',
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/ClamAV/Clamd.pm',
    ABSTRACT_FROM    => 'lib/ClamAV/Clamd.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        # None. This speaks a protocol; it does not link libclamav.
    },
    INC   => '-I.  -Iinclude',
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    macro => { TARFLAGS => "--format=ustar -c -v -f" },
    clean => { FILES => 'ClamAV-Clamd-* Install '
                      . 't/abi_consumer/blib '
                      . 't/abi_consumer/Makefile t/abi_consumer/pm_to_blib' },
);

# --- the C ABI ---------------------------------------------------------
#
# ExtUtils::Depends lets a consumer compile against include/clamav/
# clamd_abi.h without linking against this .so. It is a CONFIGURE-time
# dependency only - nothing is required at runtime, and a build without
# it still produces a fully working module. Only the consumer wiring is
# lost, so it degrades rather than failing.
if (eval { require ExtUtils::Depends; 1 }) {
    my $pkg = ExtUtils::Depends->new('ClamAV::Clamd');
    $pkg->install('include/clamav/clamd_abi.h');
    mkdir 'Install' unless -d 'Install';
    $pkg->save_config('Install/Files.pm');

    my %dep = $pkg->get_makefile_vars;

    # GOTCHA 1: EU::Depends hands back empty LIBS/LDFROM that clobber
    # MakeMaker's own defaults. This dist links nothing, so they go.
    delete $dep{LIBS};
    delete $dep{LDFROM};

    # GOTCHA 2: its PM map REPLACES MakeMaker's auto-detected one, so
    # everything under lib/ has to be put back by hand or the module
    # itself stops being installed.
    if ($dep{PM}) {
        require File::Find;
        File::Find::find(sub {
            return unless -f $_;
            my $from = $File::Find::name;
            (my $to = $from) =~ s{^lib/}{\$(INST_LIB)/};
            $dep{PM}{$from} = $to;
        }, 'lib');
    }

    # GOTCHA 3: merge its INC into ours rather than letting it win.
    $dep{INC} = join ' ', ($WriteMakefileArgs{INC} || ''), ($dep{INC} || '');

    %WriteMakefileArgs = (%WriteMakefileArgs, %dep);
    $WriteMakefileArgs{CONFIGURE_REQUIRES}{'ExtUtils::Depends'} = '0.302';
}
else {
    warn <<'NOTE';
ExtUtils::Depends is not installed. ClamAV::Clamd will build and work
normally; only the C ABI wiring for other XS distributions is skipped.
NOTE
}

# --- clock_gettime: needs -lrt on old glibc (< 2.17) ---------------------
#
# clamd_compat.h's deadline clock is clock_gettime(CLOCK_MONOTONIC). Before
# glibc 2.17 that symbol lives in librt, so the .so loads with "undefined
# symbol: clock_gettime" unless we link -lrt (CPAN Testers, glibc 2.13).
# Newer glibc folds it into libc, and macOS/BSD have no librt, so only add
# it when a link probe needs it.
{
    my $inc  = '#include <time.h>';
    my $body = 'struct timespec ts; return clock_gettime(CLOCK_MONOTONIC, &ts);';
    if (!probe('rt', $inc, $body, '') && probe('rt', $inc, $body, '-lrt')) {
        $WriteMakefileArgs{LIBS} = ['-lrt'];
        print "clock_gettime needs -lrt (old glibc): linking it.\n";
    }
}

# --- SCM_RIGHTS: the XPG4.2 headers, on the platforms that hide them ------
#
# CPAN Testers, OmniOS (illumos) on three perls: struct msghdr has no
# msg_control and CMSG_SPACE, CMSG_LEN, CMSG_FIRSTHDR and CMSG_DATA do not
# exist. Solaris and its descendants keep the 4.3BSD msghdr - the one with
# msg_accrights - until _XPG4_2 is defined, and perl.h has already pulled
# in <sys/socket.h> before any header of ours is read. The define has to be
# on the command line or it arrives too late to matter.
#
# Which spelling works is a property of the box, so it is measured rather
# than guessed: each candidate compiles the real thing - perl.h first, then
# the struct member and the macros - and the first that builds wins. The
# empty set is tried first, so nothing changes anywhere it already works.
#
# A set that adds flags must LINK as well as compile, because _XPG4_2 also
# redirects sendmsg to __xnet_sendmsg on Solaris: a define that compiles but
# leaves an unresolved symbol has traded a build error for a load error.
#
# If nothing works the platform loses FILDES, not the build - cc_scan_fd
# falls back to INSTREAM.
unless ($^O eq 'MSWin32') {
    my $core = "$Config{archlibexp}/CORE";
    my $base = $WriteMakefileArgs{CCFLAGS};
    $base = $Config{ccflags} unless defined $base;
    $base = '' unless defined $base;

    my $compile = <<'PROBE_C';
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <string.h>
#if !defined(SCM_RIGHTS) || !defined(CMSG_SPACE) || !defined(CMSG_LEN) \
 || !defined(CMSG_FIRSTHDR) || !defined(CMSG_DATA)
#  error "no control-message macros"
#endif
int cc_probe_send(int fd) {
    struct msghdr msg;
    struct cmsghdr *cm;
    struct iovec iov;
    char ctl[512], pad = 0;
    memset(&msg, 0, sizeof msg);
    iov.iov_base = &pad; iov.iov_len = 1;
    msg.msg_iov = &iov; msg.msg_iovlen = 1;
    msg.msg_control = ctl;
    msg.msg_controllen = CMSG_SPACE(sizeof(int));
    cm = CMSG_FIRSTHDR(&msg);
    cm->cmsg_level = SOL_SOCKET;
    cm->cmsg_type  = SCM_RIGHTS;
    cm->cmsg_len   = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(cm), &fd, sizeof(int));
    return (int)sendmsg(fd, &msg, 0);
}
PROBE_C

    # The link half deliberately leaves perl.h out: all it has to answer is
    # whether the sendmsg these flags select is in the libraries perl itself
    # linked, which is what will be in the process when the .so is loaded.
    my $link = $compile;
    $link =~ s/^#include "(EXTERN|perl|XSUB)\.h"\n//mg;
    $link .= "int main(void){ return cc_probe_send(-1) < 0 ? 1 : 0; }\n";

    # ... and it only gets a vote if a link probe means anything here at
    # all. A plain sendmsg, no flags and no macros, is the control: if even
    # that will not link - a library in perl's own list is gone, the
    # toolchain wants an argument nobody passed - then a failure below is
    # evidence about the box and not about the flags, and it is ignored.
    my $ref = <<'REF_C';
#include <sys/types.h>
#include <sys/socket.h>
int main(void) { struct msghdr m; return sendmsg(0, &m, 0) < 0 ? 1 : 0; }
REF_C

    my @candidates = (
        '',
        '-D_XPG4_2 -D__EXTENSIONS__',
        '-D__EXTENSIONS__',
        '-D_XOPEN_SOURCE=600 -D__EXTENSIONS__',
    );

    my ($found, $link_speaks);
    for my $extra (@candidates) {
        next unless cc_probe("fdpass", $compile, "$base $extra -I$core", 0);
        if ($extra ne '') {
            # Only asked where a candidate wants to add flags, which on
            # everything that already works is never.
            $link_speaks = cc_probe("fdref", $ref, $base, 1)
                unless defined $link_speaks;
            next if $link_speaks
                and !cc_probe("fdlink", $link, "$base $extra", 1);
        }
        $found = $extra;
        last;
    }

    # Nothing is forced off here. The headers decide that themselves, at
    # the compile that matters, from the macros they do or do not define -
    # so a probe that cannot run for some unrelated reason costs a
    # diagnostic and not the feature.
    if (!defined $found) {
        print "No flags reveal SCM_RIGHTS here; FILDES may fall back to "
            . "INSTREAM.\n";
    }
    elsif ($found ne '') {
        $WriteMakefileArgs{CCFLAGS} = "$base $found";
        print "Descriptor passing needs $found: adding it.\n";
    }
}

# Compile (and optionally link) a source string with the given flags.
sub cc_probe {
    my ($name, $src, $flags, $do_link) = @_;
    my $dir = "cc_probe_${name}_$$";
    mkdir $dir or return 0;
    my ($c, $out, $ok) = ("$dir/p.c", "$dir/p", 0);
    if (open my $fh, '>', $c) {
        print $fh $src;
        close $fh;
        my $cc  = $Config{cc} || 'cc';
        my $cmd = $do_link
            ? "$cc $flags $c -o $out " . ($Config{perllibs} || '')
            : "$cc $flags -c $c -o $out";
        $ok = system("$cmd >/dev/null 2>&1") == 0;
    }
    unlink $c, $out; rmdir $dir;
    return $ok;
}

sub probe {
    my ($name, $includes, $body, $libs) = @_;
    my $dir = "cc_probe_${name}_$$";
    mkdir $dir or return 0;
    my ($src, $bin, $ok) = ("$dir/p.c", "$dir/p", 0);
    if (open my $fh, '>', $src) {
        print $fh "$includes\nint main(void){ $body }\n";
        close $fh;
        my $cc = $Config{cc} || 'cc';
        $ok = system("$cc $src -o $bin $libs >/dev/null 2>&1") == 0;
    }
    unlink $src, $bin; rmdir $dir;
    return $ok;
}

# MakeMaker tracks neither include/*.h nor anything an XS file pulls in,
# so editing a header rebuilds nothing and the .so keeps the old code.
# Name them as dependencies or lose an afternoon to a stale object.
sub MY::postamble {
    return <<'MAKE_FRAG';
CLAMD_HEADERS = include/clamav/clamd_compat.h include/clamav/clamd_conn.h \
                include/clamav/clamd_stream.h include/clamav/clamd_scan.h \
                include/clamav/clamd_verdict.h include/clamav/clamd_async.h \
                include/clamav/clamd_abi.h include/clamav/clamd_abi_impl.h

Clamd.c : Clamd.xs $(CLAMD_HEADERS)

$(OBJECT) : $(CLAMD_HEADERS)
MAKE_FRAG
}

# Compatibility with old versions of ExtUtils::MakeMaker
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 }) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$build_requires} = values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
