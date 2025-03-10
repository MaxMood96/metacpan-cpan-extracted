use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Create and manipulate character widgets.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0.08;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'Curses-UI-Char';
requires 'Curses::UI' => 0;
requires 'Readonly' => 0;
requires 'Unicode::UTF8' => 0;
requires 'perl' => '5.6.0';
readme_from 'Char.pm';
recursive_author_tests('xt');
resources 'bugtracker' => 'https://github.com/michal-josef-spacek/Curses-UI-Char';
resources 'homepage' => 'https://github.com/michal-josef-spacek/Curses-UI-Char';
resources 'repository' => 'git://github.com/michal-josef-spacek/Curses-UI-Char';
test_requires 'Carp' => 0;
test_requires 'DynaLoader' => 0;
test_requires 'Exporter' => 0;
test_requires 'Curses::UI' => 0;
test_requires 'FindBin' => 0;
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
tests_recursive;
version '0.02';

# Run.
WriteAll();
