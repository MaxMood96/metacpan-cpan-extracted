#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 4;

use_ok($_) for qw(
    Crypt::Image
    Crypt::Image::Axis
    Crypt::Image::Util
    Crypt::Image::Params
);

diag("Testing Crypt::Image $Crypt::Image::VERSION, Perl $], $^X");
