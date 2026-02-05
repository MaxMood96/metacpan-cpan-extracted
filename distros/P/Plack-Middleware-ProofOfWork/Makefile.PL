use 5.008001;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

# Install share files
install_share 'share';

WriteMakefile(
    NAME             => 'Plack::Middleware::ProofOfWork',
    AUTHOR           => 'Oliver Paukstadt <cpan@sourcentral.org>',
    VERSION_FROM     => 'lib/Plack/Middleware/ProofOfWork.pm',
    ABSTRACT         => 'Proof-of-Work based bot protection for Plack applications',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.008001',
    
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.64',
        'File::ShareDir::Install' => '0.06',
    },
    
    PREREQ_PM => {
        'Plack'           => '1.0000',
        'Plack::Middleware' => 0,
        'Plack::Request'  => 0,
        'Plack::Response' => 0,
        'Digest::SHA'     => 0,
        'MIME::Base64'    => 0,
        'File::ShareDir'  => '1.00',
        'File::Spec'      => 0,
        'parent'          => 0,
    },
    
    TEST_REQUIRES => {
        'Test::More'     => '0.98',
        'HTTP::Request::Common' => 0,
        'Plack::Test'    => 0,
    },
    
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/pstadt/Plack-Middleware-ProofOfWork.git',
                web  => 'https://github.com/pstadt/Plack-Middleware-ProofOfWork',
            },
            bugtracker => {
                web => 'https://github.com/pstadt/Plack-Middleware-ProofOfWork/issues',
            },
        },
    },
    
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Plack-Middleware-ProofOfWork-*' },
);

package MY;
use File::ShareDir::Install qw(postamble);
