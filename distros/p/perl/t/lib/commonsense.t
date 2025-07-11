#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}
use Config;

plan( tests => 1);

if (($Config{'extensions'} !~ /\bFcntl\b/) ){
  BAIL_OUT("Perl configured without Fcntl module");
}
##Finds IO submodules when using \b
if (($Config{'extensions'} !~ /\bIO\s/) ){
  BAIL_OUT("Perl configured without IO module");
}
if (($Config{'extensions'} !~ /\bFile\/Glob\b/) ){
  BAIL_OUT("Perl configured without File::Glob module");
}

pass('common sense');

