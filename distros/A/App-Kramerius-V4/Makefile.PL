use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Base class and script for fetching document from Kramerius system, version 4.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0.05;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
install_script 'bin/kramerius4';
license 'bsd';
name 'App-Kramerius-V4';
perl_version 5.006;
readme_from 'bin/kramerius4';
recursive_author_tests('xt');
requires 'Class::Utils' => 0;
requires 'Data::Kramerius' => 0;
requires 'Error::Pure' => 0;
requires 'Getopt::Std' => 0;
requires 'IO::Barf' => 0;
requires 'JSON::XS' => 0;
requires 'LWP::UserAgent' => 0;
resources 'bugtracker' => 'https://github.com/michal-josef-spacek/App-Kramerius-V4/issues',
resources 'homepage' => 'https://github.com/michal-josef-spacek/App-Kramerius-V4';
resources 'repository' => 'git://github.com/michal-josef-spacek/App-Kramerius-V4';
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
tests_recursive;
version '0.02';

# Run.
WriteAll();
