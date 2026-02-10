#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 1;

BEGIN
{
use_ok('Image::APNG') || print "Bail out!\n" ;
}

diag("Testing Image::APNG $Image::APNG::VERSION, Perl $], $^X") ;
