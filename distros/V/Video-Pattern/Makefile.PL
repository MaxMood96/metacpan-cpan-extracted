use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Perl class for video frames pattern generating.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0.05;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'Video-Pattern';
readme_from 'Pattern.pm';
recursive_author_tests('xt');
requires 'Class::Utils' => 0.03;
requires 'Error::Pure' => 0.22;
requires 'File::Basename' => 0;
requires 'File::Spec::Functions' => 0;
requires 'Image::Random' => 0.06;
requires 'Readonly' => 0;
requires 'Video::Delay::Const' => 0;
requires 'perl' => '5.6.0';
resources 'bugtracker' => 'https://rt.cpan.org/Public/Dist/Display.html'.
	'?Name=Video-Pattern';
resources 'homepage' => 'https://github.com/michal-josef-spacek/Video-Pattern';
resources 'repository' => 'git://github.com/michal-josef-spacek/Video-Pattern';
test_requires 'English' => 0;
test_requires 'Error::Pure::Utils' => '0.17';
test_requires 'File::Temp' => 0;
test_requires 'Image::Random' => 0;
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
tests_recursive;
version '0.09';

# Run.
WriteAll();
