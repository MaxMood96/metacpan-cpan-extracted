# Note: this file was auto-generated by Module::Build::Compat version 0.4234
use ExtUtils::MakeMaker;
WriteMakefile
(
  'NAME' => 'App::zen',
  'VERSION_FROM' => 'lib/App/zen.pm',
  'PREREQ_PM' => {
                   'File::Basename' => 0,
                   'File::Path' => 0,
                   'File::Slurp' => 0,
                   'HTTP::Server::Simple' => 0,
                   'HTTP::Server::Simple::CGI' => 0,
                   'JSON' => 0,
                   'Test::More' => 0
                 },
  'INSTALLDIRS' => 'site',
  'EXE_FILES' => [
                   'bin/zen'
                 ],
  'PL_FILES' => {}
)
;
