requires 'perl', '5.010';

requires 'Class::Tiny';
requires 'File::Share';
requires 'version';
requires 'YAML::XS';

on configure => sub {
    requires 'Module::Build::Tiny';
};

on develop => sub {
    requires 'Spellunker',                 '== v0.4.0';
    requires 'CPAN::Uploader',             '== 0.103018';
    requires 'Minilla',                    '== v3.1.29';
    requires 'Perl::Tidy',                 '== 20260109';
    requires 'Software::License::MIT',     '== 0.104007';
    requires 'Test::CPAN::Meta',           '== 0.25';
    requires 'Test::MinimumVersion::Fast', '== 0.04';
    requires 'Test::PAUSE::Permissions',   '== 0.07';
    requires 'Test::Pod',                  '== 1.52';
    requires 'Test::Spellunker',           '== v0.4.0';
    requires 'Version::Next',              '== 1,000';

    requires 'Reply',               '== 0.42';
    requires 'Term::ReadLine::Gnu', '== 1.47';
};

on test => sub {
    requires 'List::Util', '>= 1.33';    # for any function
    requires 'Test2::V1';
};
