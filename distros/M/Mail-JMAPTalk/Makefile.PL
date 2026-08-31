use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Mail::JMAPTalk',
    VERSION_FROM      => 'lib/Mail/JMAPTalk.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
        'MIME::Base64'    => 0,
        'JSON'            => 0,
        'HTTP::Tiny'      => 0,
    },
    TEST_REQUIRES     => {
        'Test::More'      => 0,
    },
    ABSTRACT_FROM     => 'lib/Mail/JMAPTalk.pm', # retrieve abstract from module
    AUTHOR            => 'Bron Gondwana <brong@cpan.org>',
    LICENSE           => 'Perl_5',
    META_MERGE        => {
        'meta-spec' => { version => 2 },
        prereqs => {
            runtime => {
                # only needed to guess the type of an Upload() with no
                # explicit mimetype; needs the C libmagic library
                recommends => {
                    'File::LibMagic' => 0,
                },
            },
        },
    },
);
