package #
Date::Manip::TZ::amswif00;
# Copyright (c) 2008-2025 Sullivan Beck.  All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

# This file was automatically generated.  Any changes to this file will
# be lost the next time 'tzdata' is run.
#    Generated on: Sun Jun  1 17:31:38 EDT 2025
#    Data version: tzdata2025b
#    Code version: tzcode2025b

# This module contains data from the zoneinfo time zone database.  The original
# data was obtained from the URL:
#    ftp://ftp.iana.org/tz

use strict;
use warnings;
require 5.010000;

our (%Dates,%LastRule);
END {
   undef %Dates;
   undef %LastRule;
}

our ($VERSION);
$VERSION='6.98';
END { undef $VERSION; }

%Dates         = (
   1    =>
     [
        [ [1,1,2,0,0,0],[1,1,1,16,48,40],'-07:11:20',[-7,-11,-20],
          'LMT',0,[1905,9,1,7,11,19],[1905,8,31,23,59,59],
          '0001010200:00:00','0001010116:48:40','1905090107:11:19','1905083123:59:59' ],
     ],
   1905 =>
     [
        [ [1905,9,1,7,11,20],[1905,9,1,0,11,20],'-07:00:00',[-7,0,0],
          'MST',0,[1918,4,14,8,59,59],[1918,4,14,1,59,59],
          '1905090107:11:20','1905090100:11:20','1918041408:59:59','1918041401:59:59' ],
     ],
   1918 =>
     [
        [ [1918,4,14,9,0,0],[1918,4,14,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1918,10,27,7,59,59],[1918,10,27,1,59,59],
          '1918041409:00:00','1918041403:00:00','1918102707:59:59','1918102701:59:59' ],
        [ [1918,10,27,8,0,0],[1918,10,27,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1942,2,9,8,59,59],[1942,2,9,1,59,59],
          '1918102708:00:00','1918102701:00:00','1942020908:59:59','1942020901:59:59' ],
     ],
   1942 =>
     [
        [ [1942,2,9,9,0,0],[1942,2,9,3,0,0],'-06:00:00',[-6,0,0],
          'MWT',1,[1945,8,14,22,59,59],[1945,8,14,16,59,59],
          '1942020909:00:00','1942020903:00:00','1945081422:59:59','1945081416:59:59' ],
     ],
   1945 =>
     [
        [ [1945,8,14,23,0,0],[1945,8,14,17,0,0],'-06:00:00',[-6,0,0],
          'MPT',1,[1945,9,30,7,59,59],[1945,9,30,1,59,59],
          '1945081423:00:00','1945081417:00:00','1945093007:59:59','1945093001:59:59' ],
        [ [1945,9,30,8,0,0],[1945,9,30,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1946,4,28,8,59,59],[1946,4,28,1,59,59],
          '1945093008:00:00','1945093001:00:00','1946042808:59:59','1946042801:59:59' ],
     ],
   1946 =>
     [
        [ [1946,4,28,9,0,0],[1946,4,28,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1946,10,13,7,59,59],[1946,10,13,1,59,59],
          '1946042809:00:00','1946042803:00:00','1946101307:59:59','1946101301:59:59' ],
        [ [1946,10,13,8,0,0],[1946,10,13,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1947,4,27,8,59,59],[1947,4,27,1,59,59],
          '1946101308:00:00','1946101301:00:00','1947042708:59:59','1947042701:59:59' ],
     ],
   1947 =>
     [
        [ [1947,4,27,9,0,0],[1947,4,27,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1947,9,28,7,59,59],[1947,9,28,1,59,59],
          '1947042709:00:00','1947042703:00:00','1947092807:59:59','1947092801:59:59' ],
        [ [1947,9,28,8,0,0],[1947,9,28,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1948,4,25,8,59,59],[1948,4,25,1,59,59],
          '1947092808:00:00','1947092801:00:00','1948042508:59:59','1948042501:59:59' ],
     ],
   1948 =>
     [
        [ [1948,4,25,9,0,0],[1948,4,25,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1948,9,26,7,59,59],[1948,9,26,1,59,59],
          '1948042509:00:00','1948042503:00:00','1948092607:59:59','1948092601:59:59' ],
        [ [1948,9,26,8,0,0],[1948,9,26,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1949,4,24,8,59,59],[1949,4,24,1,59,59],
          '1948092608:00:00','1948092601:00:00','1949042408:59:59','1949042401:59:59' ],
     ],
   1949 =>
     [
        [ [1949,4,24,9,0,0],[1949,4,24,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1949,9,25,7,59,59],[1949,9,25,1,59,59],
          '1949042409:00:00','1949042403:00:00','1949092507:59:59','1949092501:59:59' ],
        [ [1949,9,25,8,0,0],[1949,9,25,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1957,4,28,8,59,59],[1957,4,28,1,59,59],
          '1949092508:00:00','1949092501:00:00','1957042808:59:59','1957042801:59:59' ],
     ],
   1957 =>
     [
        [ [1957,4,28,9,0,0],[1957,4,28,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1957,10,27,7,59,59],[1957,10,27,1,59,59],
          '1957042809:00:00','1957042803:00:00','1957102707:59:59','1957102701:59:59' ],
        [ [1957,10,27,8,0,0],[1957,10,27,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1959,4,26,8,59,59],[1959,4,26,1,59,59],
          '1957102708:00:00','1957102701:00:00','1959042608:59:59','1959042601:59:59' ],
     ],
   1959 =>
     [
        [ [1959,4,26,9,0,0],[1959,4,26,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1959,10,25,7,59,59],[1959,10,25,1,59,59],
          '1959042609:00:00','1959042603:00:00','1959102507:59:59','1959102501:59:59' ],
        [ [1959,10,25,8,0,0],[1959,10,25,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1960,4,24,8,59,59],[1960,4,24,1,59,59],
          '1959102508:00:00','1959102501:00:00','1960042408:59:59','1960042401:59:59' ],
     ],
   1960 =>
     [
        [ [1960,4,24,9,0,0],[1960,4,24,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1960,9,25,7,59,59],[1960,9,25,1,59,59],
          '1960042409:00:00','1960042403:00:00','1960092507:59:59','1960092501:59:59' ],
        [ [1960,9,25,8,0,0],[1960,9,25,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1961,4,30,8,59,59],[1961,4,30,1,59,59],
          '1960092508:00:00','1960092501:00:00','1961043008:59:59','1961043001:59:59' ],
     ],
   1961 =>
     [
        [ [1961,4,30,9,0,0],[1961,4,30,3,0,0],'-06:00:00',[-6,0,0],
          'MDT',1,[1961,9,24,7,59,59],[1961,9,24,1,59,59],
          '1961043009:00:00','1961043003:00:00','1961092407:59:59','1961092401:59:59' ],
        [ [1961,9,24,8,0,0],[1961,9,24,1,0,0],'-07:00:00',[-7,0,0],
          'MST',0,[1972,4,30,8,59,59],[1972,4,30,1,59,59],
          '1961092408:00:00','1961092401:00:00','1972043008:59:59','1972043001:59:59' ],
     ],
   1972 =>
     [
        [ [1972,4,30,9,0,0],[1972,4,30,3,0,0],'-06:00:00',[-6,0,0],
          'CST',0,[9999,12,31,0,0,0],[9999,12,30,18,0,0],
          '1972043009:00:00','1972043003:00:00','9999123100:00:00','9999123018:00:00' ],
     ],
);

%LastRule      = (
);

1;
