## 
##  Perl makefile for CQi reference implementation
##

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => "CWB::CQI",
  VERSION_FROM => "lib/CWB/CQI/Client.pm",
  LICENSE      => 'perl',
  META_MERGE   => {
    resources => {
      homepage => 'https://cwb.sourceforge.io/',
      repository => 'http://svn.code.sf.net/p/cwb/code/perl/trunk',
    },
  },
);
