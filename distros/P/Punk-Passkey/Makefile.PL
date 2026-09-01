use 5.010000;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

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

require File::Find;
File::Find::find(sub {
    return unless -f $_;
    (my $rel = $File::Find::name) =~ s{^lib/}{};
    $dep{PM}{$File::Find::name} = "\$(INST_LIB)/$rel";
}, 'lib');

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
        'Punk'            => '0.39',
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
