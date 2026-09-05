use strict;
use warnings;
use ExtUtils::CBuilder;
use ExtUtils::MakeMaker;

my $builder = ExtUtils::CBuilder->new(quiet => 1);
my ($object, $executable);
my $openssl_ok = eval {
    $object = $builder->compile(source => 'check_openssl.c');
    $executable = $builder->link_executable(
        objects            => $object,
        extra_linker_flags => '-lssl -lcrypto',
    );
    1;
};
my $openssl_error = $@;
unlink grep { defined && -e } $object, $executable;

die "Linux::Event TLS support requires OpenSSL 1.1.1 or newer, including "
    . "development headers and libssl/libcrypto.\n$openssl_error"
    if !$openssl_ok;

WriteMakefile(
    NAME             => 'Linux::Event::TLS',
    VERSION_FROM     => '../lib/Linux/Event/TLS.pm',
    ABSTRACT         => 'OpenSSL transport for Linux::Event stream sockets',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'TLS.xs' => 'TLS.c' },
    OBJECT           => 'TLS$(OBJ_EXT)',
    INC              => '-I../xsbytestream',
    LIBS             => ['-lssl -lcrypto'],
    clean            => { FILES => 'TLS.c' },
);
