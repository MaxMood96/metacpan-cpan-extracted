BEGIN { push @INC, q[.] }
use inc::Module::Install;

version_from('lib/Text/Password/Pronounceable.pm');
name('Text-Password-Pronounceable');
license('perl');
requires('Crypt::URandom' => '0.55');
readme_from('lib/Text/Password/Pronounceable.pm');

WriteAll;
