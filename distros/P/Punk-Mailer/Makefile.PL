use 5.016000;
use strict;
use warnings;
use Config;                 # $Config{cc}, for the getentropy probe below
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

# Punk::Mailer is 100% XS. Its one C dependency is Fetch's fetch_abi.h,
# consumed at build time and resolved at runtime through Fetch::_abi_ptr:
# the HTTP transports go through Fetch's request table, and the SMTP
# transport speaks over its raw tunnel - TLS included - without this dist
# linking OpenSSL or anything else.
#
# A sibling working copy of Fetch wins over an installed one, because the
# sibling carries the newest ABI (Punk-TOTP does the same for qr_abi.h).

my @PROVIDERS = (
    [ 'Fetch'             => '../Fetch/include/fetch', '../../Fetch/include/fetch' ],
    [ 'File::Raw::JSON'   => '../File-Raw-JSON/include', '../../File-Raw-JSON/include' ],
    [ 'Template::Stencil' => '../Template-Stencil/include', '../../Template-Stencil/include' ],
);

my $INC = '-Iinclude';
my %dep;
{
    # glob in LIST context, deliberately: inside && it would be scalar, and a
    # scalar glob is an iterator whose state survives from one call to the
    # next - which directory counts as a sibling would then depend on the
    # previous pattern's leftover matches.
    #
    # ABSOLUTE paths, also deliberately: `make disttest` passes this
    # Makefile's INC through to the make it runs inside the distdir,
    # prepended to that directory's own. A relative -I../Fetch/... resolves
    # to nothing from there, and the next entry - the installed header,
    # possibly an older ABI - wins, so the tarball fails to build against
    # the very sibling the checkout built against.
    require Cwd;
    my @sibling = map { Cwd::abs_path($_) }
                  grep { -d $_ && scalar(my @h = glob("$_/*_abi.h")) }
                  map { @$_[1 .. $#$_] } @PROVIDERS;
    my $pkg;
    if (eval { $pkg = ExtUtils::Depends->new('Punk::Mailer',
                                              map { $_->[0] } @PROVIDERS); 1 }) {
        %dep = $pkg->get_makefile_vars;
        # sibling first: -I order decides which fetch_abi.h is found
        $INC .= join '', map { " -I$_" } @sibling;
        $INC .= ' ' . delete $dep{INC} if $dep{INC};
    }
    else {
        die "Cannot find the Fetch dependency.\n"
          . "Install Fetch 0.15+, or place it as a sibling directory.\n"
            unless @sibling;
        $pkg = ExtUtils::Depends->new('Punk::Mailer');
        %dep = $pkg->get_makefile_vars;
        delete $dep{INC};
        $INC .= join '', map { " -I$_" } @sibling;
    }
    delete $dep{LIBS};    # nothing links; an empty LIBS would clobber defaults
    delete $dep{LDFROM};
}

# getentropy(2), for MIME boundaries and Message-IDs. Probed through the
# LINK, not compile-only: a compile probe passes on boxes whose libc
# headers declare what the linker cannot deliver (FreeBSD before 12), and
# the built .so then fails to load. Without it, /dev/urandom.
my $DEFINE = '';
{
    my $dir = "pmail_probe_$$";
    if (mkdir $dir) {
        for my $try ( [ 'sys/random.h', ' -DPMAIL_GETENTROPY_SYS_RANDOM' ],
                      [ 'unistd.h',     ''                               ] ) {
            my ($header, $extra) = @$try;
            my $src = "$dir/probe.c";
            open my $fh, '>', $src or next;
            print $fh "#include <$header>\n"
                    . "int main(void) { unsigned char b[16]; "
                    . "return getentropy(b, sizeof b); }\n";
            close $fh;
            my $cc = $Config{cc} || 'cc';
            if (system("$cc $src -o $dir/probe >/dev/null 2>&1") == 0) {
                $DEFINE .= ' -DPMAIL_HAVE_GETENTROPY' . $extra;
                print "Found getentropy (linked, not just compiled).\n";
                last;
            }
        }
        unlink "$dir/probe.c", "$dir/probe";
        rmdir $dir;
    }
    print "No getentropy; using /dev/urandom.\n" unless $DEFINE =~ /GETENTROPY/;
}

# EU::Depends' PM map would otherwise replace MakeMaker's auto-detected PM
# (house gotcha), so re-add lib/ unconditionally.
{
    require File::Find;
    File::Find::find(sub {
        return unless /\.pm\z/;
        (my $rel = $File::Find::name) =~ s{^lib/}{};
        $dep{PM}{$File::Find::name} = "\$(INST_LIB)/$rel";
    }, 'lib');
}

# MakeMaker tracks nothing under include/ or xs/, so edits there would not
# rebuild without this (house gotcha).
my $deps = join ' ', glob('include/pmail/*.h'), glob('xs/*.xs');

WriteMakefile(
    NAME             => 'Punk::Mailer',
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Punk/Mailer.pm',
    ABSTRACT_FROM    => 'lib/Punk/Mailer.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.016000',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
        'ExtUtils::Depends'   => '0.404',
        'Fetch'               => '0.17',   # fetch_abi.h v3: tunnel_starttls
        'File::Raw::JSON'     => '0.06',   # frj_abi.h at build time
        'Template::Stencil'   => '0.10',   # st_abi.h: the plugin's mail templates
    },
    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },
    PREREQ_PM => {
        'ExtUtils::Depends' => '0.404',
        'Fetch'             => '0.17',     # the HTTP client and the TLS tunnel (ABI 3)
        'File::Raw::JSON'   => '0.06',     # the providers' JSON bodies
        'XSLoader'          => '0',
        'Template::Stencil' => '0.10',   # mail templates
    },
    INC    => $INC,
    DEFINE => $DEFINE,
    XS     => { 'Mailer.xs' => 'Mailer.c' },
    OBJECT => 'Mailer$(OBJ_EXT)',
    depend => {
        'Mailer.c'         => $deps,
        'Mailer$(OBJ_EXT)' => $deps,
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        prereqs => {
            runtime => {
                recommends => {
                    'Punk'              => '0.29',   # the plugin; the host keyword
                    'Punk::Queue'       => '0.05',   # later => 1
                },
            },
        },
    },
    macro => { TARFLAGS => "--format=ustar -c -v -f" },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'Punk-Mailer-* Mailer.c Mailer.o Mailer.bs' },
    %dep,
);
