# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.08) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/nUm_LjpJ6O/southamerica.  Olson data version 2025b
#
# Do not edit this file directly.
#
package DateTime::TimeZone::America::Lima;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '2.65';

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::America::Lima::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
59611180092, #      utc_end 1890-01-01 05:08:12 (Wed)
DateTime::TimeZone::NEG_INFINITY, #  local_start
59611161600, #    local_end 1890-01-01 00:00:00 (Wed)
-18492,
0,
'LMT',
    ],
    [
59611180092, #    utc_start 1890-01-01 05:08:12 (Wed)
60197144916, #      utc_end 1908-07-28 05:08:36 (Tue)
59611161576, #  local_start 1889-12-31 23:59:36 (Tue)
60197126400, #    local_end 1908-07-28 00:00:00 (Tue)
-18516,
0,
'LMT',
    ],
    [
60197144916, #    utc_start 1908-07-28 05:08:36 (Tue)
61125858000, #      utc_end 1938-01-01 05:00:00 (Sat)
60197126916, #  local_start 1908-07-28 00:08:36 (Tue)
61125840000, #    local_end 1938-01-01 00:00:00 (Sat)
-18000,
0,
'-05',
    ],
    [
61125858000, #    utc_start 1938-01-01 05:00:00 (Sat)
61133630400, #      utc_end 1938-04-01 04:00:00 (Fri)
61125843600, #  local_start 1938-01-01 01:00:00 (Sat)
61133616000, #    local_end 1938-04-01 00:00:00 (Fri)
-14400,
1,
'-04',
    ],
    [
61133630400, #    utc_start 1938-04-01 04:00:00 (Fri)
61148926800, #      utc_end 1938-09-25 05:00:00 (Sun)
61133612400, #  local_start 1938-03-31 23:00:00 (Thu)
61148908800, #    local_end 1938-09-25 00:00:00 (Sun)
-18000,
0,
'-05',
    ],
    [
61148926800, #    utc_start 1938-09-25 05:00:00 (Sun)
61164648000, #      utc_end 1939-03-26 04:00:00 (Sun)
61148912400, #  local_start 1938-09-25 01:00:00 (Sun)
61164633600, #    local_end 1939-03-26 00:00:00 (Sun)
-14400,
1,
'-04',
    ],
    [
61164648000, #    utc_start 1939-03-26 04:00:00 (Sun)
61180376400, #      utc_end 1939-09-24 05:00:00 (Sun)
61164630000, #  local_start 1939-03-25 23:00:00 (Sat)
61180358400, #    local_end 1939-09-24 00:00:00 (Sun)
-18000,
0,
'-05',
    ],
    [
61180376400, #    utc_start 1939-09-24 05:00:00 (Sun)
61196097600, #      utc_end 1940-03-24 04:00:00 (Sun)
61180362000, #  local_start 1939-09-24 01:00:00 (Sun)
61196083200, #    local_end 1940-03-24 00:00:00 (Sun)
-14400,
1,
'-04',
    ],
    [
61196097600, #    utc_start 1940-03-24 04:00:00 (Sun)
62640622800, #      utc_end 1986-01-01 05:00:00 (Wed)
61196079600, #  local_start 1940-03-23 23:00:00 (Sat)
62640604800, #    local_end 1986-01-01 00:00:00 (Wed)
-18000,
0,
'-05',
    ],
    [
62640622800, #    utc_start 1986-01-01 05:00:00 (Wed)
62648395200, #      utc_end 1986-04-01 04:00:00 (Tue)
62640608400, #  local_start 1986-01-01 01:00:00 (Wed)
62648380800, #    local_end 1986-04-01 00:00:00 (Tue)
-14400,
1,
'-04',
    ],
    [
62648395200, #    utc_start 1986-04-01 04:00:00 (Tue)
62672158800, #      utc_end 1987-01-01 05:00:00 (Thu)
62648377200, #  local_start 1986-03-31 23:00:00 (Mon)
62672140800, #    local_end 1987-01-01 00:00:00 (Thu)
-18000,
0,
'-05',
    ],
    [
62672158800, #    utc_start 1987-01-01 05:00:00 (Thu)
62679931200, #      utc_end 1987-04-01 04:00:00 (Wed)
62672144400, #  local_start 1987-01-01 01:00:00 (Thu)
62679916800, #    local_end 1987-04-01 00:00:00 (Wed)
-14400,
1,
'-04',
    ],
    [
62679931200, #    utc_start 1987-04-01 04:00:00 (Wed)
62766853200, #      utc_end 1990-01-01 05:00:00 (Mon)
62679913200, #  local_start 1987-03-31 23:00:00 (Tue)
62766835200, #    local_end 1990-01-01 00:00:00 (Mon)
-18000,
0,
'-05',
    ],
    [
62766853200, #    utc_start 1990-01-01 05:00:00 (Mon)
62774625600, #      utc_end 1990-04-01 04:00:00 (Sun)
62766838800, #  local_start 1990-01-01 01:00:00 (Mon)
62774611200, #    local_end 1990-04-01 00:00:00 (Sun)
-14400,
1,
'-04',
    ],
    [
62774625600, #    utc_start 1990-04-01 04:00:00 (Sun)
62893083600, #      utc_end 1994-01-01 05:00:00 (Sat)
62774607600, #  local_start 1990-03-31 23:00:00 (Sat)
62893065600, #    local_end 1994-01-01 00:00:00 (Sat)
-18000,
0,
'-05',
    ],
    [
62893083600, #    utc_start 1994-01-01 05:00:00 (Sat)
62900856000, #      utc_end 1994-04-01 04:00:00 (Fri)
62893069200, #  local_start 1994-01-01 01:00:00 (Sat)
62900841600, #    local_end 1994-04-01 00:00:00 (Fri)
-14400,
1,
'-04',
    ],
    [
62900856000, #    utc_start 1994-04-01 04:00:00 (Fri)
DateTime::TimeZone::INFINITY, #      utc_end
62900838000, #  local_start 1994-03-31 23:00:00 (Thu)
DateTime::TimeZone::INFINITY, #    local_end
-18000,
0,
'-05',
    ],
];

sub olson_version {'2025b'}

sub has_dst_changes {7}

sub _max_year {2035}

sub _new_instance {
    return shift->_init( @_, spans => $spans );
}



1;

