#!/usr/bin/perl -w
#########################################################
# Sample Program for Perl Module "Shell::POSIX::Select" #
#  tim@TeachMePerl.com  (888) DOC-PERL  (888) DOC-UNIX  #
#  Copyright 2002-2003, Tim Maher. All Rights Reserved  #
#########################################################
use Shell::POSIX::Select ;

BEGIN {
    if (@ARGV) {
        @choices=@ARGV ;
    }
    else { # if no args, get choices from input
        @choices=<STDIN>  or  die "$0: No data\n";
        chomp @choices ;
        # STDIN already returned EOF,
        # so must reopen for terminal before menu interaction
        open STDIN, "/dev/tty"  or  die ;  # UNIX example
    }
}
select ( @choices ) { }   # prints selections to output
