# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.08) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/nUm_LjpJ6O/northamerica.  Olson data version 2025b
#
# Do not edit this file directly.
#
package DateTime::TimeZone::America::Fort_Nelson;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '2.65';

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::America::Fort_Nelson::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
59421802247, #      utc_end 1884-01-01 08:10:47 (Tue)
DateTime::TimeZone::NEG_INFINITY, #  local_start
59421772800, #    local_end 1884-01-01 00:00:00 (Tue)
-29447,
0,
'LMT',
    ],
    [
59421802247, #    utc_start 1884-01-01 08:10:47 (Tue)
60503623200, #      utc_end 1918-04-14 10:00:00 (Sun)
59421773447, #  local_start 1884-01-01 00:10:47 (Tue)
60503594400, #    local_end 1918-04-14 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
60503623200, #    utc_start 1918-04-14 10:00:00 (Sun)
60520554000, #      utc_end 1918-10-27 09:00:00 (Sun)
60503598000, #  local_start 1918-04-14 03:00:00 (Sun)
60520528800, #    local_end 1918-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
60520554000, #    utc_start 1918-10-27 09:00:00 (Sun)
61255476000, #      utc_end 1942-02-09 10:00:00 (Mon)
60520525200, #  local_start 1918-10-27 01:00:00 (Sun)
61255447200, #    local_end 1942-02-09 02:00:00 (Mon)
-28800,
0,
'PST',
    ],
    [
61255476000, #    utc_start 1942-02-09 10:00:00 (Mon)
61366287600, #      utc_end 1945-08-14 23:00:00 (Tue)
61255450800, #  local_start 1942-02-09 03:00:00 (Mon)
61366262400, #    local_end 1945-08-14 16:00:00 (Tue)
-25200,
1,
'PWT',
    ],
    [
61366287600, #    utc_start 1945-08-14 23:00:00 (Tue)
61370298000, #      utc_end 1945-09-30 09:00:00 (Sun)
61366262400, #  local_start 1945-08-14 16:00:00 (Tue)
61370272800, #    local_end 1945-09-30 02:00:00 (Sun)
-25200,
1,
'PPT',
    ],
    [
61370298000, #    utc_start 1945-09-30 09:00:00 (Sun)
61419895200, #      utc_end 1947-04-27 10:00:00 (Sun)
61370269200, #  local_start 1945-09-30 01:00:00 (Sun)
61419866400, #    local_end 1947-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61419895200, #    utc_start 1947-04-27 10:00:00 (Sun)
61433197200, #      utc_end 1947-09-28 09:00:00 (Sun)
61419870000, #  local_start 1947-04-27 03:00:00 (Sun)
61433172000, #    local_end 1947-09-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61433197200, #    utc_start 1947-09-28 09:00:00 (Sun)
61451344800, #      utc_end 1948-04-25 10:00:00 (Sun)
61433168400, #  local_start 1947-09-28 01:00:00 (Sun)
61451316000, #    local_end 1948-04-25 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61451344800, #    utc_start 1948-04-25 10:00:00 (Sun)
61464646800, #      utc_end 1948-09-26 09:00:00 (Sun)
61451319600, #  local_start 1948-04-25 03:00:00 (Sun)
61464621600, #    local_end 1948-09-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61464646800, #    utc_start 1948-09-26 09:00:00 (Sun)
61482794400, #      utc_end 1949-04-24 10:00:00 (Sun)
61464618000, #  local_start 1948-09-26 01:00:00 (Sun)
61482765600, #    local_end 1949-04-24 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61482794400, #    utc_start 1949-04-24 10:00:00 (Sun)
61496096400, #      utc_end 1949-09-25 09:00:00 (Sun)
61482769200, #  local_start 1949-04-24 03:00:00 (Sun)
61496071200, #    local_end 1949-09-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61496096400, #    utc_start 1949-09-25 09:00:00 (Sun)
61514848800, #      utc_end 1950-04-30 10:00:00 (Sun)
61496067600, #  local_start 1949-09-25 01:00:00 (Sun)
61514820000, #    local_end 1950-04-30 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61514848800, #    utc_start 1950-04-30 10:00:00 (Sun)
61527546000, #      utc_end 1950-09-24 09:00:00 (Sun)
61514823600, #  local_start 1950-04-30 03:00:00 (Sun)
61527520800, #    local_end 1950-09-24 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61527546000, #    utc_start 1950-09-24 09:00:00 (Sun)
61546298400, #      utc_end 1951-04-29 10:00:00 (Sun)
61527517200, #  local_start 1950-09-24 01:00:00 (Sun)
61546269600, #    local_end 1951-04-29 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61546298400, #    utc_start 1951-04-29 10:00:00 (Sun)
61559600400, #      utc_end 1951-09-30 09:00:00 (Sun)
61546273200, #  local_start 1951-04-29 03:00:00 (Sun)
61559575200, #    local_end 1951-09-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61559600400, #    utc_start 1951-09-30 09:00:00 (Sun)
61577748000, #      utc_end 1952-04-27 10:00:00 (Sun)
61559571600, #  local_start 1951-09-30 01:00:00 (Sun)
61577719200, #    local_end 1952-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61577748000, #    utc_start 1952-04-27 10:00:00 (Sun)
61591050000, #      utc_end 1952-09-28 09:00:00 (Sun)
61577722800, #  local_start 1952-04-27 03:00:00 (Sun)
61591024800, #    local_end 1952-09-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61591050000, #    utc_start 1952-09-28 09:00:00 (Sun)
61609197600, #      utc_end 1953-04-26 10:00:00 (Sun)
61591021200, #  local_start 1952-09-28 01:00:00 (Sun)
61609168800, #    local_end 1953-04-26 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61609197600, #    utc_start 1953-04-26 10:00:00 (Sun)
61622499600, #      utc_end 1953-09-27 09:00:00 (Sun)
61609172400, #  local_start 1953-04-26 03:00:00 (Sun)
61622474400, #    local_end 1953-09-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61622499600, #    utc_start 1953-09-27 09:00:00 (Sun)
61640647200, #      utc_end 1954-04-25 10:00:00 (Sun)
61622470800, #  local_start 1953-09-27 01:00:00 (Sun)
61640618400, #    local_end 1954-04-25 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61640647200, #    utc_start 1954-04-25 10:00:00 (Sun)
61653949200, #      utc_end 1954-09-26 09:00:00 (Sun)
61640622000, #  local_start 1954-04-25 03:00:00 (Sun)
61653924000, #    local_end 1954-09-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61653949200, #    utc_start 1954-09-26 09:00:00 (Sun)
61672096800, #      utc_end 1955-04-24 10:00:00 (Sun)
61653920400, #  local_start 1954-09-26 01:00:00 (Sun)
61672068000, #    local_end 1955-04-24 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61672096800, #    utc_start 1955-04-24 10:00:00 (Sun)
61685398800, #      utc_end 1955-09-25 09:00:00 (Sun)
61672071600, #  local_start 1955-04-24 03:00:00 (Sun)
61685373600, #    local_end 1955-09-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61685398800, #    utc_start 1955-09-25 09:00:00 (Sun)
61704151200, #      utc_end 1956-04-29 10:00:00 (Sun)
61685370000, #  local_start 1955-09-25 01:00:00 (Sun)
61704122400, #    local_end 1956-04-29 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61704151200, #    utc_start 1956-04-29 10:00:00 (Sun)
61717453200, #      utc_end 1956-09-30 09:00:00 (Sun)
61704126000, #  local_start 1956-04-29 03:00:00 (Sun)
61717428000, #    local_end 1956-09-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61717453200, #    utc_start 1956-09-30 09:00:00 (Sun)
61735600800, #      utc_end 1957-04-28 10:00:00 (Sun)
61717424400, #  local_start 1956-09-30 01:00:00 (Sun)
61735572000, #    local_end 1957-04-28 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61735600800, #    utc_start 1957-04-28 10:00:00 (Sun)
61748902800, #      utc_end 1957-09-29 09:00:00 (Sun)
61735575600, #  local_start 1957-04-28 03:00:00 (Sun)
61748877600, #    local_end 1957-09-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61748902800, #    utc_start 1957-09-29 09:00:00 (Sun)
61767050400, #      utc_end 1958-04-27 10:00:00 (Sun)
61748874000, #  local_start 1957-09-29 01:00:00 (Sun)
61767021600, #    local_end 1958-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61767050400, #    utc_start 1958-04-27 10:00:00 (Sun)
61780352400, #      utc_end 1958-09-28 09:00:00 (Sun)
61767025200, #  local_start 1958-04-27 03:00:00 (Sun)
61780327200, #    local_end 1958-09-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61780352400, #    utc_start 1958-09-28 09:00:00 (Sun)
61798500000, #      utc_end 1959-04-26 10:00:00 (Sun)
61780323600, #  local_start 1958-09-28 01:00:00 (Sun)
61798471200, #    local_end 1959-04-26 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61798500000, #    utc_start 1959-04-26 10:00:00 (Sun)
61811802000, #      utc_end 1959-09-27 09:00:00 (Sun)
61798474800, #  local_start 1959-04-26 03:00:00 (Sun)
61811776800, #    local_end 1959-09-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61811802000, #    utc_start 1959-09-27 09:00:00 (Sun)
61829949600, #      utc_end 1960-04-24 10:00:00 (Sun)
61811773200, #  local_start 1959-09-27 01:00:00 (Sun)
61829920800, #    local_end 1960-04-24 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61829949600, #    utc_start 1960-04-24 10:00:00 (Sun)
61843251600, #      utc_end 1960-09-25 09:00:00 (Sun)
61829924400, #  local_start 1960-04-24 03:00:00 (Sun)
61843226400, #    local_end 1960-09-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61843251600, #    utc_start 1960-09-25 09:00:00 (Sun)
61862004000, #      utc_end 1961-04-30 10:00:00 (Sun)
61843222800, #  local_start 1960-09-25 01:00:00 (Sun)
61861975200, #    local_end 1961-04-30 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61862004000, #    utc_start 1961-04-30 10:00:00 (Sun)
61874701200, #      utc_end 1961-09-24 09:00:00 (Sun)
61861978800, #  local_start 1961-04-30 03:00:00 (Sun)
61874676000, #    local_end 1961-09-24 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61874701200, #    utc_start 1961-09-24 09:00:00 (Sun)
61893453600, #      utc_end 1962-04-29 10:00:00 (Sun)
61874672400, #  local_start 1961-09-24 01:00:00 (Sun)
61893424800, #    local_end 1962-04-29 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61893453600, #    utc_start 1962-04-29 10:00:00 (Sun)
61909174800, #      utc_end 1962-10-28 09:00:00 (Sun)
61893428400, #  local_start 1962-04-29 03:00:00 (Sun)
61909149600, #    local_end 1962-10-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61909174800, #    utc_start 1962-10-28 09:00:00 (Sun)
61924903200, #      utc_end 1963-04-28 10:00:00 (Sun)
61909146000, #  local_start 1962-10-28 01:00:00 (Sun)
61924874400, #    local_end 1963-04-28 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61924903200, #    utc_start 1963-04-28 10:00:00 (Sun)
61940624400, #      utc_end 1963-10-27 09:00:00 (Sun)
61924878000, #  local_start 1963-04-28 03:00:00 (Sun)
61940599200, #    local_end 1963-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61940624400, #    utc_start 1963-10-27 09:00:00 (Sun)
61956352800, #      utc_end 1964-04-26 10:00:00 (Sun)
61940595600, #  local_start 1963-10-27 01:00:00 (Sun)
61956324000, #    local_end 1964-04-26 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61956352800, #    utc_start 1964-04-26 10:00:00 (Sun)
61972074000, #      utc_end 1964-10-25 09:00:00 (Sun)
61956327600, #  local_start 1964-04-26 03:00:00 (Sun)
61972048800, #    local_end 1964-10-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
61972074000, #    utc_start 1964-10-25 09:00:00 (Sun)
61987802400, #      utc_end 1965-04-25 10:00:00 (Sun)
61972045200, #  local_start 1964-10-25 01:00:00 (Sun)
61987773600, #    local_end 1965-04-25 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
61987802400, #    utc_start 1965-04-25 10:00:00 (Sun)
62004128400, #      utc_end 1965-10-31 09:00:00 (Sun)
61987777200, #  local_start 1965-04-25 03:00:00 (Sun)
62004103200, #    local_end 1965-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62004128400, #    utc_start 1965-10-31 09:00:00 (Sun)
62019252000, #      utc_end 1966-04-24 10:00:00 (Sun)
62004099600, #  local_start 1965-10-31 01:00:00 (Sun)
62019223200, #    local_end 1966-04-24 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62019252000, #    utc_start 1966-04-24 10:00:00 (Sun)
62035578000, #      utc_end 1966-10-30 09:00:00 (Sun)
62019226800, #  local_start 1966-04-24 03:00:00 (Sun)
62035552800, #    local_end 1966-10-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62035578000, #    utc_start 1966-10-30 09:00:00 (Sun)
62051306400, #      utc_end 1967-04-30 10:00:00 (Sun)
62035549200, #  local_start 1966-10-30 01:00:00 (Sun)
62051277600, #    local_end 1967-04-30 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62051306400, #    utc_start 1967-04-30 10:00:00 (Sun)
62067027600, #      utc_end 1967-10-29 09:00:00 (Sun)
62051281200, #  local_start 1967-04-30 03:00:00 (Sun)
62067002400, #    local_end 1967-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62067027600, #    utc_start 1967-10-29 09:00:00 (Sun)
62082756000, #      utc_end 1968-04-28 10:00:00 (Sun)
62066998800, #  local_start 1967-10-29 01:00:00 (Sun)
62082727200, #    local_end 1968-04-28 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62082756000, #    utc_start 1968-04-28 10:00:00 (Sun)
62098477200, #      utc_end 1968-10-27 09:00:00 (Sun)
62082730800, #  local_start 1968-04-28 03:00:00 (Sun)
62098452000, #    local_end 1968-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62098477200, #    utc_start 1968-10-27 09:00:00 (Sun)
62114205600, #      utc_end 1969-04-27 10:00:00 (Sun)
62098448400, #  local_start 1968-10-27 01:00:00 (Sun)
62114176800, #    local_end 1969-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62114205600, #    utc_start 1969-04-27 10:00:00 (Sun)
62129926800, #      utc_end 1969-10-26 09:00:00 (Sun)
62114180400, #  local_start 1969-04-27 03:00:00 (Sun)
62129901600, #    local_end 1969-10-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62129926800, #    utc_start 1969-10-26 09:00:00 (Sun)
62145655200, #      utc_end 1970-04-26 10:00:00 (Sun)
62129898000, #  local_start 1969-10-26 01:00:00 (Sun)
62145626400, #    local_end 1970-04-26 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62145655200, #    utc_start 1970-04-26 10:00:00 (Sun)
62161376400, #      utc_end 1970-10-25 09:00:00 (Sun)
62145630000, #  local_start 1970-04-26 03:00:00 (Sun)
62161351200, #    local_end 1970-10-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62161376400, #    utc_start 1970-10-25 09:00:00 (Sun)
62177104800, #      utc_end 1971-04-25 10:00:00 (Sun)
62161347600, #  local_start 1970-10-25 01:00:00 (Sun)
62177076000, #    local_end 1971-04-25 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62177104800, #    utc_start 1971-04-25 10:00:00 (Sun)
62193430800, #      utc_end 1971-10-31 09:00:00 (Sun)
62177079600, #  local_start 1971-04-25 03:00:00 (Sun)
62193405600, #    local_end 1971-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62193430800, #    utc_start 1971-10-31 09:00:00 (Sun)
62209159200, #      utc_end 1972-04-30 10:00:00 (Sun)
62193402000, #  local_start 1971-10-31 01:00:00 (Sun)
62209130400, #    local_end 1972-04-30 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62209159200, #    utc_start 1972-04-30 10:00:00 (Sun)
62224880400, #      utc_end 1972-10-29 09:00:00 (Sun)
62209134000, #  local_start 1972-04-30 03:00:00 (Sun)
62224855200, #    local_end 1972-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62224880400, #    utc_start 1972-10-29 09:00:00 (Sun)
62240608800, #      utc_end 1973-04-29 10:00:00 (Sun)
62224851600, #  local_start 1972-10-29 01:00:00 (Sun)
62240580000, #    local_end 1973-04-29 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62240608800, #    utc_start 1973-04-29 10:00:00 (Sun)
62256330000, #      utc_end 1973-10-28 09:00:00 (Sun)
62240583600, #  local_start 1973-04-29 03:00:00 (Sun)
62256304800, #    local_end 1973-10-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62256330000, #    utc_start 1973-10-28 09:00:00 (Sun)
62272058400, #      utc_end 1974-04-28 10:00:00 (Sun)
62256301200, #  local_start 1973-10-28 01:00:00 (Sun)
62272029600, #    local_end 1974-04-28 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62272058400, #    utc_start 1974-04-28 10:00:00 (Sun)
62287779600, #      utc_end 1974-10-27 09:00:00 (Sun)
62272033200, #  local_start 1974-04-28 03:00:00 (Sun)
62287754400, #    local_end 1974-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62287779600, #    utc_start 1974-10-27 09:00:00 (Sun)
62303508000, #      utc_end 1975-04-27 10:00:00 (Sun)
62287750800, #  local_start 1974-10-27 01:00:00 (Sun)
62303479200, #    local_end 1975-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62303508000, #    utc_start 1975-04-27 10:00:00 (Sun)
62319229200, #      utc_end 1975-10-26 09:00:00 (Sun)
62303482800, #  local_start 1975-04-27 03:00:00 (Sun)
62319204000, #    local_end 1975-10-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62319229200, #    utc_start 1975-10-26 09:00:00 (Sun)
62334957600, #      utc_end 1976-04-25 10:00:00 (Sun)
62319200400, #  local_start 1975-10-26 01:00:00 (Sun)
62334928800, #    local_end 1976-04-25 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62334957600, #    utc_start 1976-04-25 10:00:00 (Sun)
62351283600, #      utc_end 1976-10-31 09:00:00 (Sun)
62334932400, #  local_start 1976-04-25 03:00:00 (Sun)
62351258400, #    local_end 1976-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62351283600, #    utc_start 1976-10-31 09:00:00 (Sun)
62366407200, #      utc_end 1977-04-24 10:00:00 (Sun)
62351254800, #  local_start 1976-10-31 01:00:00 (Sun)
62366378400, #    local_end 1977-04-24 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62366407200, #    utc_start 1977-04-24 10:00:00 (Sun)
62382733200, #      utc_end 1977-10-30 09:00:00 (Sun)
62366382000, #  local_start 1977-04-24 03:00:00 (Sun)
62382708000, #    local_end 1977-10-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62382733200, #    utc_start 1977-10-30 09:00:00 (Sun)
62398461600, #      utc_end 1978-04-30 10:00:00 (Sun)
62382704400, #  local_start 1977-10-30 01:00:00 (Sun)
62398432800, #    local_end 1978-04-30 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62398461600, #    utc_start 1978-04-30 10:00:00 (Sun)
62414182800, #      utc_end 1978-10-29 09:00:00 (Sun)
62398436400, #  local_start 1978-04-30 03:00:00 (Sun)
62414157600, #    local_end 1978-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62414182800, #    utc_start 1978-10-29 09:00:00 (Sun)
62429911200, #      utc_end 1979-04-29 10:00:00 (Sun)
62414154000, #  local_start 1978-10-29 01:00:00 (Sun)
62429882400, #    local_end 1979-04-29 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62429911200, #    utc_start 1979-04-29 10:00:00 (Sun)
62445632400, #      utc_end 1979-10-28 09:00:00 (Sun)
62429886000, #  local_start 1979-04-29 03:00:00 (Sun)
62445607200, #    local_end 1979-10-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62445632400, #    utc_start 1979-10-28 09:00:00 (Sun)
62461360800, #      utc_end 1980-04-27 10:00:00 (Sun)
62445603600, #  local_start 1979-10-28 01:00:00 (Sun)
62461332000, #    local_end 1980-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62461360800, #    utc_start 1980-04-27 10:00:00 (Sun)
62477082000, #      utc_end 1980-10-26 09:00:00 (Sun)
62461335600, #  local_start 1980-04-27 03:00:00 (Sun)
62477056800, #    local_end 1980-10-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62477082000, #    utc_start 1980-10-26 09:00:00 (Sun)
62492810400, #      utc_end 1981-04-26 10:00:00 (Sun)
62477053200, #  local_start 1980-10-26 01:00:00 (Sun)
62492781600, #    local_end 1981-04-26 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62492810400, #    utc_start 1981-04-26 10:00:00 (Sun)
62508531600, #      utc_end 1981-10-25 09:00:00 (Sun)
62492785200, #  local_start 1981-04-26 03:00:00 (Sun)
62508506400, #    local_end 1981-10-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62508531600, #    utc_start 1981-10-25 09:00:00 (Sun)
62524260000, #      utc_end 1982-04-25 10:00:00 (Sun)
62508502800, #  local_start 1981-10-25 01:00:00 (Sun)
62524231200, #    local_end 1982-04-25 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62524260000, #    utc_start 1982-04-25 10:00:00 (Sun)
62540586000, #      utc_end 1982-10-31 09:00:00 (Sun)
62524234800, #  local_start 1982-04-25 03:00:00 (Sun)
62540560800, #    local_end 1982-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62540586000, #    utc_start 1982-10-31 09:00:00 (Sun)
62555709600, #      utc_end 1983-04-24 10:00:00 (Sun)
62540557200, #  local_start 1982-10-31 01:00:00 (Sun)
62555680800, #    local_end 1983-04-24 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62555709600, #    utc_start 1983-04-24 10:00:00 (Sun)
62572035600, #      utc_end 1983-10-30 09:00:00 (Sun)
62555684400, #  local_start 1983-04-24 03:00:00 (Sun)
62572010400, #    local_end 1983-10-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62572035600, #    utc_start 1983-10-30 09:00:00 (Sun)
62587764000, #      utc_end 1984-04-29 10:00:00 (Sun)
62572006800, #  local_start 1983-10-30 01:00:00 (Sun)
62587735200, #    local_end 1984-04-29 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62587764000, #    utc_start 1984-04-29 10:00:00 (Sun)
62603485200, #      utc_end 1984-10-28 09:00:00 (Sun)
62587738800, #  local_start 1984-04-29 03:00:00 (Sun)
62603460000, #    local_end 1984-10-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62603485200, #    utc_start 1984-10-28 09:00:00 (Sun)
62619213600, #      utc_end 1985-04-28 10:00:00 (Sun)
62603456400, #  local_start 1984-10-28 01:00:00 (Sun)
62619184800, #    local_end 1985-04-28 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62619213600, #    utc_start 1985-04-28 10:00:00 (Sun)
62634934800, #      utc_end 1985-10-27 09:00:00 (Sun)
62619188400, #  local_start 1985-04-28 03:00:00 (Sun)
62634909600, #    local_end 1985-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62634934800, #    utc_start 1985-10-27 09:00:00 (Sun)
62650663200, #      utc_end 1986-04-27 10:00:00 (Sun)
62634906000, #  local_start 1985-10-27 01:00:00 (Sun)
62650634400, #    local_end 1986-04-27 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62650663200, #    utc_start 1986-04-27 10:00:00 (Sun)
62666384400, #      utc_end 1986-10-26 09:00:00 (Sun)
62650638000, #  local_start 1986-04-27 03:00:00 (Sun)
62666359200, #    local_end 1986-10-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62666384400, #    utc_start 1986-10-26 09:00:00 (Sun)
62680298400, #      utc_end 1987-04-05 10:00:00 (Sun)
62666355600, #  local_start 1986-10-26 01:00:00 (Sun)
62680269600, #    local_end 1987-04-05 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62680298400, #    utc_start 1987-04-05 10:00:00 (Sun)
62697834000, #      utc_end 1987-10-25 09:00:00 (Sun)
62680273200, #  local_start 1987-04-05 03:00:00 (Sun)
62697808800, #    local_end 1987-10-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62697834000, #    utc_start 1987-10-25 09:00:00 (Sun)
62711748000, #      utc_end 1988-04-03 10:00:00 (Sun)
62697805200, #  local_start 1987-10-25 01:00:00 (Sun)
62711719200, #    local_end 1988-04-03 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62711748000, #    utc_start 1988-04-03 10:00:00 (Sun)
62729888400, #      utc_end 1988-10-30 09:00:00 (Sun)
62711722800, #  local_start 1988-04-03 03:00:00 (Sun)
62729863200, #    local_end 1988-10-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62729888400, #    utc_start 1988-10-30 09:00:00 (Sun)
62743197600, #      utc_end 1989-04-02 10:00:00 (Sun)
62729859600, #  local_start 1988-10-30 01:00:00 (Sun)
62743168800, #    local_end 1989-04-02 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62743197600, #    utc_start 1989-04-02 10:00:00 (Sun)
62761338000, #      utc_end 1989-10-29 09:00:00 (Sun)
62743172400, #  local_start 1989-04-02 03:00:00 (Sun)
62761312800, #    local_end 1989-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62761338000, #    utc_start 1989-10-29 09:00:00 (Sun)
62774647200, #      utc_end 1990-04-01 10:00:00 (Sun)
62761309200, #  local_start 1989-10-29 01:00:00 (Sun)
62774618400, #    local_end 1990-04-01 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62774647200, #    utc_start 1990-04-01 10:00:00 (Sun)
62792787600, #      utc_end 1990-10-28 09:00:00 (Sun)
62774622000, #  local_start 1990-04-01 03:00:00 (Sun)
62792762400, #    local_end 1990-10-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62792787600, #    utc_start 1990-10-28 09:00:00 (Sun)
62806701600, #      utc_end 1991-04-07 10:00:00 (Sun)
62792758800, #  local_start 1990-10-28 01:00:00 (Sun)
62806672800, #    local_end 1991-04-07 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62806701600, #    utc_start 1991-04-07 10:00:00 (Sun)
62824237200, #      utc_end 1991-10-27 09:00:00 (Sun)
62806676400, #  local_start 1991-04-07 03:00:00 (Sun)
62824212000, #    local_end 1991-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62824237200, #    utc_start 1991-10-27 09:00:00 (Sun)
62838151200, #      utc_end 1992-04-05 10:00:00 (Sun)
62824208400, #  local_start 1991-10-27 01:00:00 (Sun)
62838122400, #    local_end 1992-04-05 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62838151200, #    utc_start 1992-04-05 10:00:00 (Sun)
62855686800, #      utc_end 1992-10-25 09:00:00 (Sun)
62838126000, #  local_start 1992-04-05 03:00:00 (Sun)
62855661600, #    local_end 1992-10-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62855686800, #    utc_start 1992-10-25 09:00:00 (Sun)
62869600800, #      utc_end 1993-04-04 10:00:00 (Sun)
62855658000, #  local_start 1992-10-25 01:00:00 (Sun)
62869572000, #    local_end 1993-04-04 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62869600800, #    utc_start 1993-04-04 10:00:00 (Sun)
62887741200, #      utc_end 1993-10-31 09:00:00 (Sun)
62869575600, #  local_start 1993-04-04 03:00:00 (Sun)
62887716000, #    local_end 1993-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62887741200, #    utc_start 1993-10-31 09:00:00 (Sun)
62901050400, #      utc_end 1994-04-03 10:00:00 (Sun)
62887712400, #  local_start 1993-10-31 01:00:00 (Sun)
62901021600, #    local_end 1994-04-03 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62901050400, #    utc_start 1994-04-03 10:00:00 (Sun)
62919190800, #      utc_end 1994-10-30 09:00:00 (Sun)
62901025200, #  local_start 1994-04-03 03:00:00 (Sun)
62919165600, #    local_end 1994-10-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62919190800, #    utc_start 1994-10-30 09:00:00 (Sun)
62932500000, #      utc_end 1995-04-02 10:00:00 (Sun)
62919162000, #  local_start 1994-10-30 01:00:00 (Sun)
62932471200, #    local_end 1995-04-02 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62932500000, #    utc_start 1995-04-02 10:00:00 (Sun)
62950640400, #      utc_end 1995-10-29 09:00:00 (Sun)
62932474800, #  local_start 1995-04-02 03:00:00 (Sun)
62950615200, #    local_end 1995-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62950640400, #    utc_start 1995-10-29 09:00:00 (Sun)
62964554400, #      utc_end 1996-04-07 10:00:00 (Sun)
62950611600, #  local_start 1995-10-29 01:00:00 (Sun)
62964525600, #    local_end 1996-04-07 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62964554400, #    utc_start 1996-04-07 10:00:00 (Sun)
62982090000, #      utc_end 1996-10-27 09:00:00 (Sun)
62964529200, #  local_start 1996-04-07 03:00:00 (Sun)
62982064800, #    local_end 1996-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
62982090000, #    utc_start 1996-10-27 09:00:00 (Sun)
62996004000, #      utc_end 1997-04-06 10:00:00 (Sun)
62982061200, #  local_start 1996-10-27 01:00:00 (Sun)
62995975200, #    local_end 1997-04-06 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
62996004000, #    utc_start 1997-04-06 10:00:00 (Sun)
63013539600, #      utc_end 1997-10-26 09:00:00 (Sun)
62995978800, #  local_start 1997-04-06 03:00:00 (Sun)
63013514400, #    local_end 1997-10-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63013539600, #    utc_start 1997-10-26 09:00:00 (Sun)
63027453600, #      utc_end 1998-04-05 10:00:00 (Sun)
63013510800, #  local_start 1997-10-26 01:00:00 (Sun)
63027424800, #    local_end 1998-04-05 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63027453600, #    utc_start 1998-04-05 10:00:00 (Sun)
63044989200, #      utc_end 1998-10-25 09:00:00 (Sun)
63027428400, #  local_start 1998-04-05 03:00:00 (Sun)
63044964000, #    local_end 1998-10-25 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63044989200, #    utc_start 1998-10-25 09:00:00 (Sun)
63058903200, #      utc_end 1999-04-04 10:00:00 (Sun)
63044960400, #  local_start 1998-10-25 01:00:00 (Sun)
63058874400, #    local_end 1999-04-04 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63058903200, #    utc_start 1999-04-04 10:00:00 (Sun)
63077043600, #      utc_end 1999-10-31 09:00:00 (Sun)
63058878000, #  local_start 1999-04-04 03:00:00 (Sun)
63077018400, #    local_end 1999-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63077043600, #    utc_start 1999-10-31 09:00:00 (Sun)
63090352800, #      utc_end 2000-04-02 10:00:00 (Sun)
63077014800, #  local_start 1999-10-31 01:00:00 (Sun)
63090324000, #    local_end 2000-04-02 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63090352800, #    utc_start 2000-04-02 10:00:00 (Sun)
63108493200, #      utc_end 2000-10-29 09:00:00 (Sun)
63090327600, #  local_start 2000-04-02 03:00:00 (Sun)
63108468000, #    local_end 2000-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63108493200, #    utc_start 2000-10-29 09:00:00 (Sun)
63121802400, #      utc_end 2001-04-01 10:00:00 (Sun)
63108464400, #  local_start 2000-10-29 01:00:00 (Sun)
63121773600, #    local_end 2001-04-01 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63121802400, #    utc_start 2001-04-01 10:00:00 (Sun)
63139942800, #      utc_end 2001-10-28 09:00:00 (Sun)
63121777200, #  local_start 2001-04-01 03:00:00 (Sun)
63139917600, #    local_end 2001-10-28 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63139942800, #    utc_start 2001-10-28 09:00:00 (Sun)
63153856800, #      utc_end 2002-04-07 10:00:00 (Sun)
63139914000, #  local_start 2001-10-28 01:00:00 (Sun)
63153828000, #    local_end 2002-04-07 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63153856800, #    utc_start 2002-04-07 10:00:00 (Sun)
63171392400, #      utc_end 2002-10-27 09:00:00 (Sun)
63153831600, #  local_start 2002-04-07 03:00:00 (Sun)
63171367200, #    local_end 2002-10-27 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63171392400, #    utc_start 2002-10-27 09:00:00 (Sun)
63185306400, #      utc_end 2003-04-06 10:00:00 (Sun)
63171363600, #  local_start 2002-10-27 01:00:00 (Sun)
63185277600, #    local_end 2003-04-06 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63185306400, #    utc_start 2003-04-06 10:00:00 (Sun)
63202842000, #      utc_end 2003-10-26 09:00:00 (Sun)
63185281200, #  local_start 2003-04-06 03:00:00 (Sun)
63202816800, #    local_end 2003-10-26 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63202842000, #    utc_start 2003-10-26 09:00:00 (Sun)
63216756000, #      utc_end 2004-04-04 10:00:00 (Sun)
63202813200, #  local_start 2003-10-26 01:00:00 (Sun)
63216727200, #    local_end 2004-04-04 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63216756000, #    utc_start 2004-04-04 10:00:00 (Sun)
63234896400, #      utc_end 2004-10-31 09:00:00 (Sun)
63216730800, #  local_start 2004-04-04 03:00:00 (Sun)
63234871200, #    local_end 2004-10-31 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63234896400, #    utc_start 2004-10-31 09:00:00 (Sun)
63248205600, #      utc_end 2005-04-03 10:00:00 (Sun)
63234867600, #  local_start 2004-10-31 01:00:00 (Sun)
63248176800, #    local_end 2005-04-03 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63248205600, #    utc_start 2005-04-03 10:00:00 (Sun)
63266346000, #      utc_end 2005-10-30 09:00:00 (Sun)
63248180400, #  local_start 2005-04-03 03:00:00 (Sun)
63266320800, #    local_end 2005-10-30 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63266346000, #    utc_start 2005-10-30 09:00:00 (Sun)
63279655200, #      utc_end 2006-04-02 10:00:00 (Sun)
63266317200, #  local_start 2005-10-30 01:00:00 (Sun)
63279626400, #    local_end 2006-04-02 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63279655200, #    utc_start 2006-04-02 10:00:00 (Sun)
63297795600, #      utc_end 2006-10-29 09:00:00 (Sun)
63279630000, #  local_start 2006-04-02 03:00:00 (Sun)
63297770400, #    local_end 2006-10-29 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63297795600, #    utc_start 2006-10-29 09:00:00 (Sun)
63309290400, #      utc_end 2007-03-11 10:00:00 (Sun)
63297766800, #  local_start 2006-10-29 01:00:00 (Sun)
63309261600, #    local_end 2007-03-11 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63309290400, #    utc_start 2007-03-11 10:00:00 (Sun)
63329850000, #      utc_end 2007-11-04 09:00:00 (Sun)
63309265200, #  local_start 2007-03-11 03:00:00 (Sun)
63329824800, #    local_end 2007-11-04 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63329850000, #    utc_start 2007-11-04 09:00:00 (Sun)
63340740000, #      utc_end 2008-03-09 10:00:00 (Sun)
63329821200, #  local_start 2007-11-04 01:00:00 (Sun)
63340711200, #    local_end 2008-03-09 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63340740000, #    utc_start 2008-03-09 10:00:00 (Sun)
63361299600, #      utc_end 2008-11-02 09:00:00 (Sun)
63340714800, #  local_start 2008-03-09 03:00:00 (Sun)
63361274400, #    local_end 2008-11-02 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63361299600, #    utc_start 2008-11-02 09:00:00 (Sun)
63372189600, #      utc_end 2009-03-08 10:00:00 (Sun)
63361270800, #  local_start 2008-11-02 01:00:00 (Sun)
63372160800, #    local_end 2009-03-08 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63372189600, #    utc_start 2009-03-08 10:00:00 (Sun)
63392749200, #      utc_end 2009-11-01 09:00:00 (Sun)
63372164400, #  local_start 2009-03-08 03:00:00 (Sun)
63392724000, #    local_end 2009-11-01 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63392749200, #    utc_start 2009-11-01 09:00:00 (Sun)
63404244000, #      utc_end 2010-03-14 10:00:00 (Sun)
63392720400, #  local_start 2009-11-01 01:00:00 (Sun)
63404215200, #    local_end 2010-03-14 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63404244000, #    utc_start 2010-03-14 10:00:00 (Sun)
63424803600, #      utc_end 2010-11-07 09:00:00 (Sun)
63404218800, #  local_start 2010-03-14 03:00:00 (Sun)
63424778400, #    local_end 2010-11-07 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63424803600, #    utc_start 2010-11-07 09:00:00 (Sun)
63435693600, #      utc_end 2011-03-13 10:00:00 (Sun)
63424774800, #  local_start 2010-11-07 01:00:00 (Sun)
63435664800, #    local_end 2011-03-13 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63435693600, #    utc_start 2011-03-13 10:00:00 (Sun)
63456253200, #      utc_end 2011-11-06 09:00:00 (Sun)
63435668400, #  local_start 2011-03-13 03:00:00 (Sun)
63456228000, #    local_end 2011-11-06 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63456253200, #    utc_start 2011-11-06 09:00:00 (Sun)
63467143200, #      utc_end 2012-03-11 10:00:00 (Sun)
63456224400, #  local_start 2011-11-06 01:00:00 (Sun)
63467114400, #    local_end 2012-03-11 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63467143200, #    utc_start 2012-03-11 10:00:00 (Sun)
63487702800, #      utc_end 2012-11-04 09:00:00 (Sun)
63467118000, #  local_start 2012-03-11 03:00:00 (Sun)
63487677600, #    local_end 2012-11-04 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63487702800, #    utc_start 2012-11-04 09:00:00 (Sun)
63498592800, #      utc_end 2013-03-10 10:00:00 (Sun)
63487674000, #  local_start 2012-11-04 01:00:00 (Sun)
63498564000, #    local_end 2013-03-10 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63498592800, #    utc_start 2013-03-10 10:00:00 (Sun)
63519152400, #      utc_end 2013-11-03 09:00:00 (Sun)
63498567600, #  local_start 2013-03-10 03:00:00 (Sun)
63519127200, #    local_end 2013-11-03 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63519152400, #    utc_start 2013-11-03 09:00:00 (Sun)
63530042400, #      utc_end 2014-03-09 10:00:00 (Sun)
63519123600, #  local_start 2013-11-03 01:00:00 (Sun)
63530013600, #    local_end 2014-03-09 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63530042400, #    utc_start 2014-03-09 10:00:00 (Sun)
63550602000, #      utc_end 2014-11-02 09:00:00 (Sun)
63530017200, #  local_start 2014-03-09 03:00:00 (Sun)
63550576800, #    local_end 2014-11-02 02:00:00 (Sun)
-25200,
1,
'PDT',
    ],
    [
63550602000, #    utc_start 2014-11-02 09:00:00 (Sun)
63561492000, #      utc_end 2015-03-08 10:00:00 (Sun)
63550573200, #  local_start 2014-11-02 01:00:00 (Sun)
63561463200, #    local_end 2015-03-08 02:00:00 (Sun)
-28800,
0,
'PST',
    ],
    [
63561492000, #    utc_start 2015-03-08 10:00:00 (Sun)
DateTime::TimeZone::INFINITY, #      utc_end
63561466800, #  local_start 2015-03-08 03:00:00 (Sun)
DateTime::TimeZone::INFINITY, #    local_end
-25200,
0,
'MST',
    ],
];

sub olson_version {'2025b'}

sub has_dst_changes {71}

sub _max_year {2035}

sub _new_instance {
    return shift->_init( @_, spans => $spans );
}



1;

