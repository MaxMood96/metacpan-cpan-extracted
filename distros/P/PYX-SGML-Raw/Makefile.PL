use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Processing PYX data or file and write as SGML.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0.07;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'PYX-SGML-Raw';
readme_from 'Raw.pm';
recursive_author_tests('xt');
requires 'Class::Utils' => 0.05;
requires 'PYX::Parser' => 0.01;
requires 'PYX::Utils' => 0.01;
requires 'perl' => '5.6.2';
resources 'bugtracker' => 'https://github.com/michal-josef-spacek/PYX-SGML-Raw/issues';
resources 'homepage' => 'https://github.com/michal-josef-spacek/PYX-SGML-Raw';
resources 'repository' => 'git://github.com/michal-josef-spacek/PYX-SGML-Raw';
test_requires 'File::Object' => 0.07;
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
test_requires 'Test::Output' => 1.02;
tests_recursive;
version '0.05';

# Run.
WriteAll();
