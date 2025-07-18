use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Tags helper for Tree.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0.03;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'Tags-HTML-Tree';
readme_from 'lib/Tags/HTML/Tree.pm';
recursive_author_tests('xt');
requires 'Class::Utils' => 0;
requires 'English' => 0;
requires 'Error::Pure' => 0;
requires 'Mo::utils' => 0.01;
requires 'Mo::utils::CSS' => 0.07;
requires 'Scalar::Util' => 0;
requires 'Tags::HTML' => 0.10;
requires 'Unicode::UTF8' => 0;
requires 'perl' => '5.8.0';
resources 'bugtracker' => 'https://github.com/michal-josef-spacek/Tags-HTML-Tree/issues';
resources 'homepage' => 'https://github.com/michal-josef-spacek/Tags-HTML-Tree';
resources 'repository' => 'git://github.com/michal-josef-spacek/Tags-HTML-Tree';
test_requires 'CSS::Struct::Output::Structure' => 0;
test_requires 'English' => 0;
test_requires 'Error::Pure::Utils' => 0;
test_requires 'Tags::Output::Structure' => 0;
test_requires 'Test::MockObject' => 0;
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
test_requires 'Tree' => 0;
test_requires 'Unicode::UTF8' => 0;
tests_recursive;
version '0.07';

# Run.
WriteAll();
