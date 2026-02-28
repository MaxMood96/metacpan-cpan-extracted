use lib '.';
use inc::Module::Install;

name('Time-ParseDate');
all_from('lib/Time/ParseDate.pm');
readme_from('lib/Time/ParseDate.pm');
repository('https://github.com/bestpractical/time-parsedate');
license('perl_5');

build_requires('Time::Piece');

sign;
WriteAll;
