use ExtUtils::MakeMaker;
use strict;
use warnings;

sub MY::distsignature
{
    return << 'EOT';
distsignature : distmeta
	$(NOECHO) ./dev/cleanup.pl
	$(NOECHO) cd $(DISTVNAME) && $(ABSPERLRUN) -MExtUtils::Manifest=maniadd -e 'eval { maniadd({q{SIGNATURE} => q{Public-key signature (added by MakeMaker)}}) }' \
	  -e '	  or die "Could not add SIGNATURE to MANIFEST: $${'\''@'\''}"' --
	$(NOECHO) cd $(DISTVNAME) && $(TOUCH) SIGNATURE
	cd $(DISTVNAME) && cpansign -s
EOT
}

my %WriteMakefileArgs = (
    NAME                => 'Net::API::REST',
    VERSION_FROM        => 'lib/Net/API/REST.pm',
    AUTHOR              => 'Jacques Deguest (jack@deguest.jp)',
    ABSTRACT            => 'Implementation of RESTful API',
    INSTALLDIRS         => ($] < 5.011 ? 'perl' : 'site'),
    PREREQ_PM           => {
        'common::sense'         => 0,
        'curry'                 => '1.001000',
        'parent'                => 0,
        'strict'                => 0,
        'utf8'                  => 0,
        'version'               => 0,
        'Apache2::API'          => 'v0.3.1',
        'Apache2::Reload'       => 0,
        'Compress::Raw::Zlib'   => '2.091',
        'Crypt::AuthEnc::GCM'   => '0.064',
        'Crypt::KeyWrap'        => '0.024',
        'Crypt::Mac::HMAC'      => '0.064',
        'Crypt::Misc'           => '0.064',
        'Crypt::PK::RSA'        => '0.064',
        'Crypt::PK::ECC'        => '0.064',
        'Crypt::PRNG'           => '0.064',
        # 'Devel::Confess'        => 0,
        'JSON'                  => 0,
        'MIME::Base64'          => '3.15',
        'Module::Generic'       => 'v0.37.5',
        'Regexp::Common'        => 0,
        'Scalar::Util'          => 0,
        'URI'                   => 0,
    },
    TEST_REQUIRES =>
    {
        'lib'                   => 0,
        'Test::Mock::Apache2'   => '0.05',
        'Test::MockObject'      => '1.20180705',
        'Test::More'            => 0,
        'Test::Pod'             => 0,
        'utf8'                  => 0,
    },
    LICENSE             => 'perl_5',
    MIN_PERL_VERSION    => 5.6.0,
    (MM->can('signature_target') ? (SIGN => 1) : ()),
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', DIST_CP => 'cp' },
    clean               => { FILES => 'Net-API-REST-*' },
    ( eval { ExtUtils::MakeMaker->VERSION(6.46) } ? ( META_MERGE => {
        'meta-spec' => { version => 2 },
        dynamic_config => 1,
        resources => {
        #    homepage    => undef,
            repository  => {
                url         => 'git@gitlab.com:jackdeguest/Net-API-REST.git',
                web         => 'https://gitlab.com/jackdeguest/Net-API-REST',
                type        => 'git',
            },
            bugtracker => {
                web         => 'https://gitlab.com/jackdeguest/Net-API-REST/issues',
            },
        },
    }) : ()),
);

WriteMakefile(%WriteMakefileArgs);
