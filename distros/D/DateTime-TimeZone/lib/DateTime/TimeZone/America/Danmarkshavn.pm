# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.08) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/nUm_LjpJ6O/europe.  Olson data version 2025b
#
# Do not edit this file directly.
#
package DateTime::TimeZone::America::Danmarkshavn;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '2.65';

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::America::Danmarkshavn::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
60449591680, #      utc_end 1916-07-28 01:14:40 (Fri)
DateTime::TimeZone::NEG_INFINITY, #  local_start
60449587200, #    local_end 1916-07-28 00:00:00 (Fri)
-4480,
0,
'LMT',
    ],
    [
60449591680, #    utc_start 1916-07-28 01:14:40 (Fri)
62459528400, #      utc_end 1980-04-06 05:00:00 (Sun)
60449580880, #  local_start 1916-07-27 22:14:40 (Thu)
62459517600, #    local_end 1980-04-06 02:00:00 (Sun)
-10800,
0,
'-03',
    ],
    [
62459528400, #    utc_start 1980-04-06 05:00:00 (Sun)
62474634000, #      utc_end 1980-09-28 01:00:00 (Sun)
62459521200, #  local_start 1980-04-06 03:00:00 (Sun)
62474626800, #    local_end 1980-09-27 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62474634000, #    utc_start 1980-09-28 01:00:00 (Sun)
62490358800, #      utc_end 1981-03-29 01:00:00 (Sun)
62474623200, #  local_start 1980-09-27 22:00:00 (Sat)
62490348000, #    local_end 1981-03-28 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62490358800, #    utc_start 1981-03-29 01:00:00 (Sun)
62506083600, #      utc_end 1981-09-27 01:00:00 (Sun)
62490351600, #  local_start 1981-03-28 23:00:00 (Sat)
62506076400, #    local_end 1981-09-26 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62506083600, #    utc_start 1981-09-27 01:00:00 (Sun)
62521808400, #      utc_end 1982-03-28 01:00:00 (Sun)
62506072800, #  local_start 1981-09-26 22:00:00 (Sat)
62521797600, #    local_end 1982-03-27 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62521808400, #    utc_start 1982-03-28 01:00:00 (Sun)
62537533200, #      utc_end 1982-09-26 01:00:00 (Sun)
62521801200, #  local_start 1982-03-27 23:00:00 (Sat)
62537526000, #    local_end 1982-09-25 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62537533200, #    utc_start 1982-09-26 01:00:00 (Sun)
62553258000, #      utc_end 1983-03-27 01:00:00 (Sun)
62537522400, #  local_start 1982-09-25 22:00:00 (Sat)
62553247200, #    local_end 1983-03-26 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62553258000, #    utc_start 1983-03-27 01:00:00 (Sun)
62568982800, #      utc_end 1983-09-25 01:00:00 (Sun)
62553250800, #  local_start 1983-03-26 23:00:00 (Sat)
62568975600, #    local_end 1983-09-24 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62568982800, #    utc_start 1983-09-25 01:00:00 (Sun)
62584707600, #      utc_end 1984-03-25 01:00:00 (Sun)
62568972000, #  local_start 1983-09-24 22:00:00 (Sat)
62584696800, #    local_end 1984-03-24 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62584707600, #    utc_start 1984-03-25 01:00:00 (Sun)
62601037200, #      utc_end 1984-09-30 01:00:00 (Sun)
62584700400, #  local_start 1984-03-24 23:00:00 (Sat)
62601030000, #    local_end 1984-09-29 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62601037200, #    utc_start 1984-09-30 01:00:00 (Sun)
62616762000, #      utc_end 1985-03-31 01:00:00 (Sun)
62601026400, #  local_start 1984-09-29 22:00:00 (Sat)
62616751200, #    local_end 1985-03-30 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62616762000, #    utc_start 1985-03-31 01:00:00 (Sun)
62632486800, #      utc_end 1985-09-29 01:00:00 (Sun)
62616754800, #  local_start 1985-03-30 23:00:00 (Sat)
62632479600, #    local_end 1985-09-28 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62632486800, #    utc_start 1985-09-29 01:00:00 (Sun)
62648211600, #      utc_end 1986-03-30 01:00:00 (Sun)
62632476000, #  local_start 1985-09-28 22:00:00 (Sat)
62648200800, #    local_end 1986-03-29 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62648211600, #    utc_start 1986-03-30 01:00:00 (Sun)
62663936400, #      utc_end 1986-09-28 01:00:00 (Sun)
62648204400, #  local_start 1986-03-29 23:00:00 (Sat)
62663929200, #    local_end 1986-09-27 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62663936400, #    utc_start 1986-09-28 01:00:00 (Sun)
62679661200, #      utc_end 1987-03-29 01:00:00 (Sun)
62663925600, #  local_start 1986-09-27 22:00:00 (Sat)
62679650400, #    local_end 1987-03-28 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62679661200, #    utc_start 1987-03-29 01:00:00 (Sun)
62695386000, #      utc_end 1987-09-27 01:00:00 (Sun)
62679654000, #  local_start 1987-03-28 23:00:00 (Sat)
62695378800, #    local_end 1987-09-26 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62695386000, #    utc_start 1987-09-27 01:00:00 (Sun)
62711110800, #      utc_end 1988-03-27 01:00:00 (Sun)
62695375200, #  local_start 1987-09-26 22:00:00 (Sat)
62711100000, #    local_end 1988-03-26 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62711110800, #    utc_start 1988-03-27 01:00:00 (Sun)
62726835600, #      utc_end 1988-09-25 01:00:00 (Sun)
62711103600, #  local_start 1988-03-26 23:00:00 (Sat)
62726828400, #    local_end 1988-09-24 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62726835600, #    utc_start 1988-09-25 01:00:00 (Sun)
62742560400, #      utc_end 1989-03-26 01:00:00 (Sun)
62726824800, #  local_start 1988-09-24 22:00:00 (Sat)
62742549600, #    local_end 1989-03-25 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62742560400, #    utc_start 1989-03-26 01:00:00 (Sun)
62758285200, #      utc_end 1989-09-24 01:00:00 (Sun)
62742553200, #  local_start 1989-03-25 23:00:00 (Sat)
62758278000, #    local_end 1989-09-23 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62758285200, #    utc_start 1989-09-24 01:00:00 (Sun)
62774010000, #      utc_end 1990-03-25 01:00:00 (Sun)
62758274400, #  local_start 1989-09-23 22:00:00 (Sat)
62773999200, #    local_end 1990-03-24 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62774010000, #    utc_start 1990-03-25 01:00:00 (Sun)
62790339600, #      utc_end 1990-09-30 01:00:00 (Sun)
62774002800, #  local_start 1990-03-24 23:00:00 (Sat)
62790332400, #    local_end 1990-09-29 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62790339600, #    utc_start 1990-09-30 01:00:00 (Sun)
62806064400, #      utc_end 1991-03-31 01:00:00 (Sun)
62790328800, #  local_start 1990-09-29 22:00:00 (Sat)
62806053600, #    local_end 1991-03-30 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62806064400, #    utc_start 1991-03-31 01:00:00 (Sun)
62821789200, #      utc_end 1991-09-29 01:00:00 (Sun)
62806057200, #  local_start 1991-03-30 23:00:00 (Sat)
62821782000, #    local_end 1991-09-28 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62821789200, #    utc_start 1991-09-29 01:00:00 (Sun)
62837514000, #      utc_end 1992-03-29 01:00:00 (Sun)
62821778400, #  local_start 1991-09-28 22:00:00 (Sat)
62837503200, #    local_end 1992-03-28 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62837514000, #    utc_start 1992-03-29 01:00:00 (Sun)
62853238800, #      utc_end 1992-09-27 01:00:00 (Sun)
62837506800, #  local_start 1992-03-28 23:00:00 (Sat)
62853231600, #    local_end 1992-09-26 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62853238800, #    utc_start 1992-09-27 01:00:00 (Sun)
62868963600, #      utc_end 1993-03-28 01:00:00 (Sun)
62853228000, #  local_start 1992-09-26 22:00:00 (Sat)
62868952800, #    local_end 1993-03-27 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62868963600, #    utc_start 1993-03-28 01:00:00 (Sun)
62884688400, #      utc_end 1993-09-26 01:00:00 (Sun)
62868956400, #  local_start 1993-03-27 23:00:00 (Sat)
62884681200, #    local_end 1993-09-25 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62884688400, #    utc_start 1993-09-26 01:00:00 (Sun)
62900413200, #      utc_end 1994-03-27 01:00:00 (Sun)
62884677600, #  local_start 1993-09-25 22:00:00 (Sat)
62900402400, #    local_end 1994-03-26 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62900413200, #    utc_start 1994-03-27 01:00:00 (Sun)
62916138000, #      utc_end 1994-09-25 01:00:00 (Sun)
62900406000, #  local_start 1994-03-26 23:00:00 (Sat)
62916130800, #    local_end 1994-09-24 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62916138000, #    utc_start 1994-09-25 01:00:00 (Sun)
62931862800, #      utc_end 1995-03-26 01:00:00 (Sun)
62916127200, #  local_start 1994-09-24 22:00:00 (Sat)
62931852000, #    local_end 1995-03-25 22:00:00 (Sat)
-10800,
0,
'-03',
    ],
    [
62931862800, #    utc_start 1995-03-26 01:00:00 (Sun)
62947587600, #      utc_end 1995-09-24 01:00:00 (Sun)
62931855600, #  local_start 1995-03-25 23:00:00 (Sat)
62947580400, #    local_end 1995-09-23 23:00:00 (Sat)
-7200,
1,
'-02',
    ],
    [
62947587600, #    utc_start 1995-09-24 01:00:00 (Sun)
62956148400, #      utc_end 1996-01-01 03:00:00 (Mon)
62947576800, #  local_start 1995-09-23 22:00:00 (Sat)
62956137600, #    local_end 1996-01-01 00:00:00 (Mon)
-10800,
0,
'-03',
    ],
    [
62956148400, #    utc_start 1996-01-01 03:00:00 (Mon)
DateTime::TimeZone::INFINITY, #      utc_end
62956148400, #  local_start 1996-01-01 03:00:00 (Mon)
DateTime::TimeZone::INFINITY, #    local_end
0,
0,
'GMT',
    ],
];

sub olson_version {'2025b'}

sub has_dst_changes {16}

sub _max_year {2035}

sub _new_instance {
    return shift->_init( @_, spans => $spans );
}



1;

