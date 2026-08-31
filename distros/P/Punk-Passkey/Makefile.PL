use 5.010000;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

# Punk::Passkey is an XS dist: the CBOR/COSE decoding, the key and
# signature conversions and the two ceremonies run in C over the house
# ABIs - jws_abi.h (Crypt::JWS) for signature verification and the
# primitives, frj_abi.h (File::Raw::JSON) for clientDataJSON. Perl
# remains the keyword/registration glue and the POD.
#
# The floor is 5.010, not the 5.008003 a fresh Module::Starter writes:
# nothing in this tree has ever been built against 5.8, the ABIs it
# consumes do not support it, and a floor that is WRONG is worse than
# one that is merely high - it promises a smoker a build that cannot
# work and reports the failure as this dist's bug.

my $INC = '-Iinclude';

my $pkg;
my @deps = ('Crypt::JWS', 'File::Raw::JSON');
eval { $pkg = ExtUtils::Depends->new('Punk::Passkey', @deps); 1 };
if (!$pkg) {
    # sibling-directory fallbacks for the uninstalled-ABI case
    my %sibling = (
        'Crypt::JWS'      => '../Crypt-JWS/include',
        'File::Raw::JSON' => '../File-Raw-JSON/include',
    );
    my @found;
    for my $dep (@deps) {
        if (eval { ExtUtils::Depends->new('Punk::Passkey', $dep); 1 }) {
            push @found, $dep;
        }
        elsif (-d $sibling{$dep}) {
            # absolute, because a relative -I loses when MakeMaker
            # prepends the outer INC to a disttest build in distdir
            require Cwd;
            $INC .= ' -I' . Cwd::abs_path($sibling{$dep});
        }
        else {
            die "Cannot find the $dep dependency (install it, or place "
              . "it as a sibling directory).\n";
        }
    }
    $pkg = ExtUtils::Depends->new('Punk::Passkey', @found);
}
my %dep = $pkg->get_makefile_vars;
$INC = join ' ', grep { defined && length } $INC, delete $dep{INC};
delete $dep{LDFROM};
delete $dep{LIBS};

# EU::Depends' PM map replaces MakeMaker's auto-detected PM, so lib/ is
# re-added here - and every FILE under it, not only .pm: the
# punk_passkey Sqitch project ships as a plan, a conf and nine SQL
# scripts under lib/Punk/Plugin/Passkey/sqitch, and a schema that is
# not installed is a schema the application cannot deploy.
require File::Find;
File::Find::find(sub {
    return unless -f $_;
    (my $rel = $File::Find::name) =~ s{^lib/}{};
    $dep{PM}{$File::Find::name} = "\$(INST_LIB)/$rel";
}, 'lib');

# MakeMaker tracks neither include/*.h nor an INCLUDE:'d xs/*.xs, so
# without this an edit to either builds nothing and the .so keeps the
# code that was there before - a green suite testing the old object.
my $hdeps = join ' ', glob('include/ppk/*.h xs/*.xs');

WriteMakefile(
    NAME             => 'Punk::Passkey',
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Punk/Passkey.pm',
    ABSTRACT_FROM    => 'lib/Punk/Passkey.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
        'ExtUtils::Depends'   => '0.404',
        'Crypt::JWS'          => '0.05',
        'File::Raw::JSON'     => '0.07',
    },
    TEST_REQUIRES => {
        'Test::More'   => '0.98',
        'MIME::Base64' => '3.11',   # 3.11: encode_base64url
    },
    PREREQ_PM => {
        'Crypt::JWS'      => '0.05',
        'File::Raw::JSON' => '0.07',
        # 0.29: $c->origin, which is where the rpId and the origin
        # check come from. An older Punk has no canonical origin to
        # read, and the alternative - the Host header - is the bug the
        # whole ceremony exists to avoid, so this is a floor and not a
        # preference.
        'Punk'            => '0.29',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        prereqs => {
            test => { recommends => {
                'DBI'         => '0',   # t/07: the credential table
                'DBD::SQLite' => '0',
            } },
        },
    },
    INC    => $INC,
    XS     => { 'Passkey.xs' => 'Passkey.c' },
    OBJECT => 'Passkey$(OBJ_EXT)',
    depend => {
        'Passkey.c'         => $hdeps,
        'Passkey$(OBJ_EXT)' => $hdeps,
    },
    macro => { TARFLAGS => "--format=ustar -c -v -f" },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'Punk-Passkey-* Passkey.c Passkey.o Passkey.bs' },
    %dep,
);
