#!/usr/bin/perl -w
#########################################################
# Sample Program for Perl Module "Shell::POSIX::Select" #
#  tim@TeachMePerl.com  (888) DOC-PERL  (888) DOC-UNIX  #
#  Copyright 2002-2003, Tim Maher. All Rights Reserved  #
#########################################################

use Shell::POSIX::Select  (
    prompt => 'Pick File(s):' ,
    style  => 'Korn'  # for automatic prompting
);

select ( <*> ) { }
