use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Genealogy::Relationship',
    VERSION_FROM      => 'lib/Genealogy/Relationship.pm',
    PREREQ_PM         => {
        Moo             => 0,
        Types::Standard => 0,
        List::Util      => 0,
        List::MoreUtils => 0,
        Lingua::EN::Numbers => 0,
    },
    BUILD_REQUIRES    => {
        Test::More      => 0,
	Test::Exception => 0,
    },
    ABSTRACT_FROM     => 'lib/Genealogy/Relationship.pm',
    AUTHOR            => 'Dave Cross <dave@perlhacks.com>',
    LICENSE           => 'perl',
    MIN_PERL_VERSION  => '5.6.0',
    META_MERGE        => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url => 'git://github.com/davorg/genealogy-relationship.git',
                web => 'https://github.com/davorg/genealogy-relationship',
            },
            bugtracker => {
                web => 'https://github.com/davorg/genealogy-relationship/issues',
            },
        },

    },
);

