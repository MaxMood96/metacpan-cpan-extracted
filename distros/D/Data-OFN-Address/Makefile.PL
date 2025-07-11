use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Data objects for OFN address.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'Data-OFN-Address';
perl_version 5.008;
readme_from 'lib/Data/OFN/Address.pm';
recursive_author_tests('xt');
requires 'Class::Utils' => 0;
requires 'Data::Text::Simple' => 0;
requires 'Error::Pure' => 0;
requires 'Mo' => 0;
requires 'Mo::utils' => 0.31;
requires 'Mo::utils::Number' => 0;
requires 'Readonly' => 0;
requires 'Unicode::UTF8' => 0;
resources 'bugtracker' => 'https://github.com/michal-josef-spacek/Data-OFN-Address/issues';
resources 'homepage' => 'https://github.com/michal-josef-spacek/Data-OFN-Address';
resources 'repository' => 'git://github.com/michal-josef-spacek/Data-OFN-Address';
test_requires 'Data::Text::Simple' => 0;
test_requires 'English' => 0;
test_requires 'Error::Pure::Utils' => 0;
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
test_requires 'Unicode::UTF8' => 0;
tests_recursive;
version '0.01';

# Run.
WriteAll();
