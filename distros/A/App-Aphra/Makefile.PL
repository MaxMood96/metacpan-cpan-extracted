use ExtUtils::MakeMaker;

my $mm_ver = $ExtUtils::MakeMaker::VERSION;
if ($mm_ver =~ /_/) { # developer release/version
  $mm_ver = eval $mm_ver;
  die $@ if $@;
}

WriteMakefile(
  NAME         => 'App::Aphra',
  VERSION_FROM => 'lib/App/Aphra.pm',
  LICENSE      => 'perl_5',

  EXE_FILES    => [ 'bin/aphra' ],

  PREREQ_PM    => {
    Clone    => 0,
    Template => 0,
    Moose    => 0,
    'Template::Provider::Pandoc' => '0.1.0', # For STRIP_FRONT_MATTER
    'Text::FrontMatter::YAML' => 0,
    'Path::Tiny' => 0,
    'YAML::XS' => 0,
    'Sys::Hostname' => 0,
    URI      => 0,
  },

  META_MERGE    => {
    'meta-spec' => { version => 2 },
    resources => {
      repository => {
        type => 'git',
        url  => 'https://github.com/davorg-cpan/app-aphra.git',
        web  => 'https://github.com/davorg-cpan/app-aphra',
      },
      bugtracker => {
        web  => 'https://github.com/davorg-cpan/app-aphra/issues',
      },
    },
  },
  ($mm_ver >= 6.48
    ? (MIN_PERL_VERSION => 5.014)
    : ()
  ),
);
