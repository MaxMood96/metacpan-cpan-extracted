# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.08) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/u7OXIWSGdF/australasia.  Olson data version 2025a
#
# Do not edit this file directly.
#
package DateTime::TimeZone::Australia::Adelaide;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '2.64';

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::Australia::Adelaide::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
59771573140, #      utc_end 1895-01-31 14:45:40 (Thu)
DateTime::TimeZone::NEG_INFINITY, #  local_start
59771606400, #    local_end 1895-02-01 00:00:00 (Fri)
33260,
0,
'LMT',
    ],
    [
59771573140, #    utc_start 1895-01-31 14:45:40 (Thu)
59905494000, #      utc_end 1899-04-30 15:00:00 (Sun)
59771605540, #  local_start 1895-01-31 23:45:40 (Thu)
59905526400, #    local_end 1899-05-01 00:00:00 (Mon)
32400,
0,
'ACST',
    ],
    [
59905494000, #    utc_start 1899-04-30 15:00:00 (Sun)
60463125000, #      utc_end 1916-12-31 16:30:00 (Sun)
59905528200, #  local_start 1899-05-01 00:30:00 (Mon)
60463159200, #    local_end 1917-01-01 02:00:00 (Mon)
34200,
0,
'ACST',
    ],
    [
60463125000, #    utc_start 1916-12-31 16:30:00 (Sun)
60470296200, #      utc_end 1917-03-24 16:30:00 (Sat)
60463162800, #  local_start 1917-01-01 03:00:00 (Mon)
60470334000, #    local_end 1917-03-25 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
60470296200, #    utc_start 1917-03-24 16:30:00 (Sat)
61252043400, #      utc_end 1941-12-31 16:30:00 (Wed)
60470330400, #  local_start 1917-03-25 02:00:00 (Sun)
61252077600, #    local_end 1942-01-01 02:00:00 (Thu)
34200,
0,
'ACST',
    ],
    [
61252043400, #    utc_start 1941-12-31 16:30:00 (Wed)
61259560200, #      utc_end 1942-03-28 16:30:00 (Sat)
61252081200, #  local_start 1942-01-01 03:00:00 (Thu)
61259598000, #    local_end 1942-03-29 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
61259560200, #    utc_start 1942-03-28 16:30:00 (Sat)
61275285000, #      utc_end 1942-09-26 16:30:00 (Sat)
61259594400, #  local_start 1942-03-29 02:00:00 (Sun)
61275319200, #    local_end 1942-09-27 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
61275285000, #    utc_start 1942-09-26 16:30:00 (Sat)
61291009800, #      utc_end 1943-03-27 16:30:00 (Sat)
61275322800, #  local_start 1942-09-27 03:00:00 (Sun)
61291047600, #    local_end 1943-03-28 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
61291009800, #    utc_start 1943-03-27 16:30:00 (Sat)
61307339400, #      utc_end 1943-10-02 16:30:00 (Sat)
61291044000, #  local_start 1943-03-28 02:00:00 (Sun)
61307373600, #    local_end 1943-10-03 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
61307339400, #    utc_start 1943-10-02 16:30:00 (Sat)
61322459400, #      utc_end 1944-03-25 16:30:00 (Sat)
61307377200, #  local_start 1943-10-03 03:00:00 (Sun)
61322497200, #    local_end 1944-03-26 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
61322459400, #    utc_start 1944-03-25 16:30:00 (Sat)
62193371400, #      utc_end 1971-10-30 16:30:00 (Sat)
61322493600, #  local_start 1944-03-26 02:00:00 (Sun)
62193405600, #    local_end 1971-10-31 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62193371400, #    utc_start 1971-10-30 16:30:00 (Sat)
62203653000, #      utc_end 1972-02-26 16:30:00 (Sat)
62193409200, #  local_start 1971-10-31 03:00:00 (Sun)
62203690800, #    local_end 1972-02-27 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62203653000, #    utc_start 1972-02-26 16:30:00 (Sat)
62224821000, #      utc_end 1972-10-28 16:30:00 (Sat)
62203687200, #  local_start 1972-02-27 02:00:00 (Sun)
62224855200, #    local_end 1972-10-29 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62224821000, #    utc_start 1972-10-28 16:30:00 (Sat)
62235707400, #      utc_end 1973-03-03 16:30:00 (Sat)
62224858800, #  local_start 1972-10-29 03:00:00 (Sun)
62235745200, #    local_end 1973-03-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62235707400, #    utc_start 1973-03-03 16:30:00 (Sat)
62256270600, #      utc_end 1973-10-27 16:30:00 (Sat)
62235741600, #  local_start 1973-03-04 02:00:00 (Sun)
62256304800, #    local_end 1973-10-28 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62256270600, #    utc_start 1973-10-27 16:30:00 (Sat)
62267157000, #      utc_end 1974-03-02 16:30:00 (Sat)
62256308400, #  local_start 1973-10-28 03:00:00 (Sun)
62267194800, #    local_end 1974-03-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62267157000, #    utc_start 1974-03-02 16:30:00 (Sat)
62287720200, #      utc_end 1974-10-26 16:30:00 (Sat)
62267191200, #  local_start 1974-03-03 02:00:00 (Sun)
62287754400, #    local_end 1974-10-27 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62287720200, #    utc_start 1974-10-26 16:30:00 (Sat)
62298606600, #      utc_end 1975-03-01 16:30:00 (Sat)
62287758000, #  local_start 1974-10-27 03:00:00 (Sun)
62298644400, #    local_end 1975-03-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62298606600, #    utc_start 1975-03-01 16:30:00 (Sat)
62319169800, #      utc_end 1975-10-25 16:30:00 (Sat)
62298640800, #  local_start 1975-03-02 02:00:00 (Sun)
62319204000, #    local_end 1975-10-26 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62319169800, #    utc_start 1975-10-25 16:30:00 (Sat)
62330661000, #      utc_end 1976-03-06 16:30:00 (Sat)
62319207600, #  local_start 1975-10-26 03:00:00 (Sun)
62330698800, #    local_end 1976-03-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62330661000, #    utc_start 1976-03-06 16:30:00 (Sat)
62351224200, #      utc_end 1976-10-30 16:30:00 (Sat)
62330695200, #  local_start 1976-03-07 02:00:00 (Sun)
62351258400, #    local_end 1976-10-31 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62351224200, #    utc_start 1976-10-30 16:30:00 (Sat)
62362110600, #      utc_end 1977-03-05 16:30:00 (Sat)
62351262000, #  local_start 1976-10-31 03:00:00 (Sun)
62362148400, #    local_end 1977-03-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62362110600, #    utc_start 1977-03-05 16:30:00 (Sat)
62382673800, #      utc_end 1977-10-29 16:30:00 (Sat)
62362144800, #  local_start 1977-03-06 02:00:00 (Sun)
62382708000, #    local_end 1977-10-30 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62382673800, #    utc_start 1977-10-29 16:30:00 (Sat)
62393560200, #      utc_end 1978-03-04 16:30:00 (Sat)
62382711600, #  local_start 1977-10-30 03:00:00 (Sun)
62393598000, #    local_end 1978-03-05 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62393560200, #    utc_start 1978-03-04 16:30:00 (Sat)
62414123400, #      utc_end 1978-10-28 16:30:00 (Sat)
62393594400, #  local_start 1978-03-05 02:00:00 (Sun)
62414157600, #    local_end 1978-10-29 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62414123400, #    utc_start 1978-10-28 16:30:00 (Sat)
62425009800, #      utc_end 1979-03-03 16:30:00 (Sat)
62414161200, #  local_start 1978-10-29 03:00:00 (Sun)
62425047600, #    local_end 1979-03-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62425009800, #    utc_start 1979-03-03 16:30:00 (Sat)
62445573000, #      utc_end 1979-10-27 16:30:00 (Sat)
62425044000, #  local_start 1979-03-04 02:00:00 (Sun)
62445607200, #    local_end 1979-10-28 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62445573000, #    utc_start 1979-10-27 16:30:00 (Sat)
62456459400, #      utc_end 1980-03-01 16:30:00 (Sat)
62445610800, #  local_start 1979-10-28 03:00:00 (Sun)
62456497200, #    local_end 1980-03-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62456459400, #    utc_start 1980-03-01 16:30:00 (Sat)
62477022600, #      utc_end 1980-10-25 16:30:00 (Sat)
62456493600, #  local_start 1980-03-02 02:00:00 (Sun)
62477056800, #    local_end 1980-10-26 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62477022600, #    utc_start 1980-10-25 16:30:00 (Sat)
62487909000, #      utc_end 1981-02-28 16:30:00 (Sat)
62477060400, #  local_start 1980-10-26 03:00:00 (Sun)
62487946800, #    local_end 1981-03-01 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62487909000, #    utc_start 1981-02-28 16:30:00 (Sat)
62508472200, #      utc_end 1981-10-24 16:30:00 (Sat)
62487943200, #  local_start 1981-03-01 02:00:00 (Sun)
62508506400, #    local_end 1981-10-25 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62508472200, #    utc_start 1981-10-24 16:30:00 (Sat)
62519963400, #      utc_end 1982-03-06 16:30:00 (Sat)
62508510000, #  local_start 1981-10-25 03:00:00 (Sun)
62520001200, #    local_end 1982-03-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62519963400, #    utc_start 1982-03-06 16:30:00 (Sat)
62540526600, #      utc_end 1982-10-30 16:30:00 (Sat)
62519997600, #  local_start 1982-03-07 02:00:00 (Sun)
62540560800, #    local_end 1982-10-31 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62540526600, #    utc_start 1982-10-30 16:30:00 (Sat)
62551413000, #      utc_end 1983-03-05 16:30:00 (Sat)
62540564400, #  local_start 1982-10-31 03:00:00 (Sun)
62551450800, #    local_end 1983-03-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62551413000, #    utc_start 1983-03-05 16:30:00 (Sat)
62571976200, #      utc_end 1983-10-29 16:30:00 (Sat)
62551447200, #  local_start 1983-03-06 02:00:00 (Sun)
62572010400, #    local_end 1983-10-30 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62571976200, #    utc_start 1983-10-29 16:30:00 (Sat)
62582862600, #      utc_end 1984-03-03 16:30:00 (Sat)
62572014000, #  local_start 1983-10-30 03:00:00 (Sun)
62582900400, #    local_end 1984-03-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62582862600, #    utc_start 1984-03-03 16:30:00 (Sat)
62603425800, #      utc_end 1984-10-27 16:30:00 (Sat)
62582896800, #  local_start 1984-03-04 02:00:00 (Sun)
62603460000, #    local_end 1984-10-28 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62603425800, #    utc_start 1984-10-27 16:30:00 (Sat)
62614312200, #      utc_end 1985-03-02 16:30:00 (Sat)
62603463600, #  local_start 1984-10-28 03:00:00 (Sun)
62614350000, #    local_end 1985-03-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62614312200, #    utc_start 1985-03-02 16:30:00 (Sat)
62634875400, #      utc_end 1985-10-26 16:30:00 (Sat)
62614346400, #  local_start 1985-03-03 02:00:00 (Sun)
62634909600, #    local_end 1985-10-27 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62634875400, #    utc_start 1985-10-26 16:30:00 (Sat)
62646971400, #      utc_end 1986-03-15 16:30:00 (Sat)
62634913200, #  local_start 1985-10-27 03:00:00 (Sun)
62647009200, #    local_end 1986-03-16 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62646971400, #    utc_start 1986-03-15 16:30:00 (Sat)
62665720200, #      utc_end 1986-10-18 16:30:00 (Sat)
62647005600, #  local_start 1986-03-16 02:00:00 (Sun)
62665754400, #    local_end 1986-10-19 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62665720200, #    utc_start 1986-10-18 16:30:00 (Sat)
62678421000, #      utc_end 1987-03-14 16:30:00 (Sat)
62665758000, #  local_start 1986-10-19 03:00:00 (Sun)
62678458800, #    local_end 1987-03-15 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62678421000, #    utc_start 1987-03-14 16:30:00 (Sat)
62697774600, #      utc_end 1987-10-24 16:30:00 (Sat)
62678455200, #  local_start 1987-03-15 02:00:00 (Sun)
62697808800, #    local_end 1987-10-25 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62697774600, #    utc_start 1987-10-24 16:30:00 (Sat)
62710475400, #      utc_end 1988-03-19 16:30:00 (Sat)
62697812400, #  local_start 1987-10-25 03:00:00 (Sun)
62710513200, #    local_end 1988-03-20 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62710475400, #    utc_start 1988-03-19 16:30:00 (Sat)
62729829000, #      utc_end 1988-10-29 16:30:00 (Sat)
62710509600, #  local_start 1988-03-20 02:00:00 (Sun)
62729863200, #    local_end 1988-10-30 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62729829000, #    utc_start 1988-10-29 16:30:00 (Sat)
62741925000, #      utc_end 1989-03-18 16:30:00 (Sat)
62729866800, #  local_start 1988-10-30 03:00:00 (Sun)
62741962800, #    local_end 1989-03-19 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62741925000, #    utc_start 1989-03-18 16:30:00 (Sat)
62761278600, #      utc_end 1989-10-28 16:30:00 (Sat)
62741959200, #  local_start 1989-03-19 02:00:00 (Sun)
62761312800, #    local_end 1989-10-29 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62761278600, #    utc_start 1989-10-28 16:30:00 (Sat)
62773374600, #      utc_end 1990-03-17 16:30:00 (Sat)
62761316400, #  local_start 1989-10-29 03:00:00 (Sun)
62773412400, #    local_end 1990-03-18 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62773374600, #    utc_start 1990-03-17 16:30:00 (Sat)
62792728200, #      utc_end 1990-10-27 16:30:00 (Sat)
62773408800, #  local_start 1990-03-18 02:00:00 (Sun)
62792762400, #    local_end 1990-10-28 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62792728200, #    utc_start 1990-10-27 16:30:00 (Sat)
62803614600, #      utc_end 1991-03-02 16:30:00 (Sat)
62792766000, #  local_start 1990-10-28 03:00:00 (Sun)
62803652400, #    local_end 1991-03-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62803614600, #    utc_start 1991-03-02 16:30:00 (Sat)
62824177800, #      utc_end 1991-10-26 16:30:00 (Sat)
62803648800, #  local_start 1991-03-03 02:00:00 (Sun)
62824212000, #    local_end 1991-10-27 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62824177800, #    utc_start 1991-10-26 16:30:00 (Sat)
62836878600, #      utc_end 1992-03-21 16:30:00 (Sat)
62824215600, #  local_start 1991-10-27 03:00:00 (Sun)
62836916400, #    local_end 1992-03-22 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62836878600, #    utc_start 1992-03-21 16:30:00 (Sat)
62855627400, #      utc_end 1992-10-24 16:30:00 (Sat)
62836912800, #  local_start 1992-03-22 02:00:00 (Sun)
62855661600, #    local_end 1992-10-25 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62855627400, #    utc_start 1992-10-24 16:30:00 (Sat)
62867118600, #      utc_end 1993-03-06 16:30:00 (Sat)
62855665200, #  local_start 1992-10-25 03:00:00 (Sun)
62867156400, #    local_end 1993-03-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62867118600, #    utc_start 1993-03-06 16:30:00 (Sat)
62887681800, #      utc_end 1993-10-30 16:30:00 (Sat)
62867152800, #  local_start 1993-03-07 02:00:00 (Sun)
62887716000, #    local_end 1993-10-31 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62887681800, #    utc_start 1993-10-30 16:30:00 (Sat)
62899777800, #      utc_end 1994-03-19 16:30:00 (Sat)
62887719600, #  local_start 1993-10-31 03:00:00 (Sun)
62899815600, #    local_end 1994-03-20 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62899777800, #    utc_start 1994-03-19 16:30:00 (Sat)
62919131400, #      utc_end 1994-10-29 16:30:00 (Sat)
62899812000, #  local_start 1994-03-20 02:00:00 (Sun)
62919165600, #    local_end 1994-10-30 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62919131400, #    utc_start 1994-10-29 16:30:00 (Sat)
62931832200, #      utc_end 1995-03-25 16:30:00 (Sat)
62919169200, #  local_start 1994-10-30 03:00:00 (Sun)
62931870000, #    local_end 1995-03-26 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62931832200, #    utc_start 1995-03-25 16:30:00 (Sat)
62950581000, #      utc_end 1995-10-28 16:30:00 (Sat)
62931866400, #  local_start 1995-03-26 02:00:00 (Sun)
62950615200, #    local_end 1995-10-29 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62950581000, #    utc_start 1995-10-28 16:30:00 (Sat)
62963886600, #      utc_end 1996-03-30 16:30:00 (Sat)
62950618800, #  local_start 1995-10-29 03:00:00 (Sun)
62963924400, #    local_end 1996-03-31 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62963886600, #    utc_start 1996-03-30 16:30:00 (Sat)
62982030600, #      utc_end 1996-10-26 16:30:00 (Sat)
62963920800, #  local_start 1996-03-31 02:00:00 (Sun)
62982064800, #    local_end 1996-10-27 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
62982030600, #    utc_start 1996-10-26 16:30:00 (Sat)
62995336200, #      utc_end 1997-03-29 16:30:00 (Sat)
62982068400, #  local_start 1996-10-27 03:00:00 (Sun)
62995374000, #    local_end 1997-03-30 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
62995336200, #    utc_start 1997-03-29 16:30:00 (Sat)
63013480200, #      utc_end 1997-10-25 16:30:00 (Sat)
62995370400, #  local_start 1997-03-30 02:00:00 (Sun)
63013514400, #    local_end 1997-10-26 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63013480200, #    utc_start 1997-10-25 16:30:00 (Sat)
63026785800, #      utc_end 1998-03-28 16:30:00 (Sat)
63013518000, #  local_start 1997-10-26 03:00:00 (Sun)
63026823600, #    local_end 1998-03-29 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63026785800, #    utc_start 1998-03-28 16:30:00 (Sat)
63044929800, #      utc_end 1998-10-24 16:30:00 (Sat)
63026820000, #  local_start 1998-03-29 02:00:00 (Sun)
63044964000, #    local_end 1998-10-25 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63044929800, #    utc_start 1998-10-24 16:30:00 (Sat)
63058235400, #      utc_end 1999-03-27 16:30:00 (Sat)
63044967600, #  local_start 1998-10-25 03:00:00 (Sun)
63058273200, #    local_end 1999-03-28 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63058235400, #    utc_start 1999-03-27 16:30:00 (Sat)
63076984200, #      utc_end 1999-10-30 16:30:00 (Sat)
63058269600, #  local_start 1999-03-28 02:00:00 (Sun)
63077018400, #    local_end 1999-10-31 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63076984200, #    utc_start 1999-10-30 16:30:00 (Sat)
63089685000, #      utc_end 2000-03-25 16:30:00 (Sat)
63077022000, #  local_start 1999-10-31 03:00:00 (Sun)
63089722800, #    local_end 2000-03-26 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63089685000, #    utc_start 2000-03-25 16:30:00 (Sat)
63108433800, #      utc_end 2000-10-28 16:30:00 (Sat)
63089719200, #  local_start 2000-03-26 02:00:00 (Sun)
63108468000, #    local_end 2000-10-29 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63108433800, #    utc_start 2000-10-28 16:30:00 (Sat)
63121134600, #      utc_end 2001-03-24 16:30:00 (Sat)
63108471600, #  local_start 2000-10-29 03:00:00 (Sun)
63121172400, #    local_end 2001-03-25 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63121134600, #    utc_start 2001-03-24 16:30:00 (Sat)
63139883400, #      utc_end 2001-10-27 16:30:00 (Sat)
63121168800, #  local_start 2001-03-25 02:00:00 (Sun)
63139917600, #    local_end 2001-10-28 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63139883400, #    utc_start 2001-10-27 16:30:00 (Sat)
63153189000, #      utc_end 2002-03-30 16:30:00 (Sat)
63139921200, #  local_start 2001-10-28 03:00:00 (Sun)
63153226800, #    local_end 2002-03-31 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63153189000, #    utc_start 2002-03-30 16:30:00 (Sat)
63171333000, #      utc_end 2002-10-26 16:30:00 (Sat)
63153223200, #  local_start 2002-03-31 02:00:00 (Sun)
63171367200, #    local_end 2002-10-27 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63171333000, #    utc_start 2002-10-26 16:30:00 (Sat)
63184638600, #      utc_end 2003-03-29 16:30:00 (Sat)
63171370800, #  local_start 2002-10-27 03:00:00 (Sun)
63184676400, #    local_end 2003-03-30 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63184638600, #    utc_start 2003-03-29 16:30:00 (Sat)
63202782600, #      utc_end 2003-10-25 16:30:00 (Sat)
63184672800, #  local_start 2003-03-30 02:00:00 (Sun)
63202816800, #    local_end 2003-10-26 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63202782600, #    utc_start 2003-10-25 16:30:00 (Sat)
63216088200, #      utc_end 2004-03-27 16:30:00 (Sat)
63202820400, #  local_start 2003-10-26 03:00:00 (Sun)
63216126000, #    local_end 2004-03-28 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63216088200, #    utc_start 2004-03-27 16:30:00 (Sat)
63234837000, #      utc_end 2004-10-30 16:30:00 (Sat)
63216122400, #  local_start 2004-03-28 02:00:00 (Sun)
63234871200, #    local_end 2004-10-31 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63234837000, #    utc_start 2004-10-30 16:30:00 (Sat)
63247537800, #      utc_end 2005-03-26 16:30:00 (Sat)
63234874800, #  local_start 2004-10-31 03:00:00 (Sun)
63247575600, #    local_end 2005-03-27 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63247537800, #    utc_start 2005-03-26 16:30:00 (Sat)
63266286600, #      utc_end 2005-10-29 16:30:00 (Sat)
63247572000, #  local_start 2005-03-27 02:00:00 (Sun)
63266320800, #    local_end 2005-10-30 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63266286600, #    utc_start 2005-10-29 16:30:00 (Sat)
63279592200, #      utc_end 2006-04-01 16:30:00 (Sat)
63266324400, #  local_start 2005-10-30 03:00:00 (Sun)
63279630000, #    local_end 2006-04-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63279592200, #    utc_start 2006-04-01 16:30:00 (Sat)
63297736200, #      utc_end 2006-10-28 16:30:00 (Sat)
63279626400, #  local_start 2006-04-02 02:00:00 (Sun)
63297770400, #    local_end 2006-10-29 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63297736200, #    utc_start 2006-10-28 16:30:00 (Sat)
63310437000, #      utc_end 2007-03-24 16:30:00 (Sat)
63297774000, #  local_start 2006-10-29 03:00:00 (Sun)
63310474800, #    local_end 2007-03-25 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63310437000, #    utc_start 2007-03-24 16:30:00 (Sat)
63329185800, #      utc_end 2007-10-27 16:30:00 (Sat)
63310471200, #  local_start 2007-03-25 02:00:00 (Sun)
63329220000, #    local_end 2007-10-28 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63329185800, #    utc_start 2007-10-27 16:30:00 (Sat)
63343096200, #      utc_end 2008-04-05 16:30:00 (Sat)
63329223600, #  local_start 2007-10-28 03:00:00 (Sun)
63343134000, #    local_end 2008-04-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63343096200, #    utc_start 2008-04-05 16:30:00 (Sat)
63358821000, #      utc_end 2008-10-04 16:30:00 (Sat)
63343130400, #  local_start 2008-04-06 02:00:00 (Sun)
63358855200, #    local_end 2008-10-05 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63358821000, #    utc_start 2008-10-04 16:30:00 (Sat)
63374545800, #      utc_end 2009-04-04 16:30:00 (Sat)
63358858800, #  local_start 2008-10-05 03:00:00 (Sun)
63374583600, #    local_end 2009-04-05 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63374545800, #    utc_start 2009-04-04 16:30:00 (Sat)
63390270600, #      utc_end 2009-10-03 16:30:00 (Sat)
63374580000, #  local_start 2009-04-05 02:00:00 (Sun)
63390304800, #    local_end 2009-10-04 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63390270600, #    utc_start 2009-10-03 16:30:00 (Sat)
63405995400, #      utc_end 2010-04-03 16:30:00 (Sat)
63390308400, #  local_start 2009-10-04 03:00:00 (Sun)
63406033200, #    local_end 2010-04-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63405995400, #    utc_start 2010-04-03 16:30:00 (Sat)
63421720200, #      utc_end 2010-10-02 16:30:00 (Sat)
63406029600, #  local_start 2010-04-04 02:00:00 (Sun)
63421754400, #    local_end 2010-10-03 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63421720200, #    utc_start 2010-10-02 16:30:00 (Sat)
63437445000, #      utc_end 2011-04-02 16:30:00 (Sat)
63421758000, #  local_start 2010-10-03 03:00:00 (Sun)
63437482800, #    local_end 2011-04-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63437445000, #    utc_start 2011-04-02 16:30:00 (Sat)
63453169800, #      utc_end 2011-10-01 16:30:00 (Sat)
63437479200, #  local_start 2011-04-03 02:00:00 (Sun)
63453204000, #    local_end 2011-10-02 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63453169800, #    utc_start 2011-10-01 16:30:00 (Sat)
63468894600, #      utc_end 2012-03-31 16:30:00 (Sat)
63453207600, #  local_start 2011-10-02 03:00:00 (Sun)
63468932400, #    local_end 2012-04-01 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63468894600, #    utc_start 2012-03-31 16:30:00 (Sat)
63485224200, #      utc_end 2012-10-06 16:30:00 (Sat)
63468928800, #  local_start 2012-04-01 02:00:00 (Sun)
63485258400, #    local_end 2012-10-07 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63485224200, #    utc_start 2012-10-06 16:30:00 (Sat)
63500949000, #      utc_end 2013-04-06 16:30:00 (Sat)
63485262000, #  local_start 2012-10-07 03:00:00 (Sun)
63500986800, #    local_end 2013-04-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63500949000, #    utc_start 2013-04-06 16:30:00 (Sat)
63516673800, #      utc_end 2013-10-05 16:30:00 (Sat)
63500983200, #  local_start 2013-04-07 02:00:00 (Sun)
63516708000, #    local_end 2013-10-06 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63516673800, #    utc_start 2013-10-05 16:30:00 (Sat)
63532398600, #      utc_end 2014-04-05 16:30:00 (Sat)
63516711600, #  local_start 2013-10-06 03:00:00 (Sun)
63532436400, #    local_end 2014-04-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63532398600, #    utc_start 2014-04-05 16:30:00 (Sat)
63548123400, #      utc_end 2014-10-04 16:30:00 (Sat)
63532432800, #  local_start 2014-04-06 02:00:00 (Sun)
63548157600, #    local_end 2014-10-05 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63548123400, #    utc_start 2014-10-04 16:30:00 (Sat)
63563848200, #      utc_end 2015-04-04 16:30:00 (Sat)
63548161200, #  local_start 2014-10-05 03:00:00 (Sun)
63563886000, #    local_end 2015-04-05 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63563848200, #    utc_start 2015-04-04 16:30:00 (Sat)
63579573000, #      utc_end 2015-10-03 16:30:00 (Sat)
63563882400, #  local_start 2015-04-05 02:00:00 (Sun)
63579607200, #    local_end 2015-10-04 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63579573000, #    utc_start 2015-10-03 16:30:00 (Sat)
63595297800, #      utc_end 2016-04-02 16:30:00 (Sat)
63579610800, #  local_start 2015-10-04 03:00:00 (Sun)
63595335600, #    local_end 2016-04-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63595297800, #    utc_start 2016-04-02 16:30:00 (Sat)
63611022600, #      utc_end 2016-10-01 16:30:00 (Sat)
63595332000, #  local_start 2016-04-03 02:00:00 (Sun)
63611056800, #    local_end 2016-10-02 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63611022600, #    utc_start 2016-10-01 16:30:00 (Sat)
63626747400, #      utc_end 2017-04-01 16:30:00 (Sat)
63611060400, #  local_start 2016-10-02 03:00:00 (Sun)
63626785200, #    local_end 2017-04-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63626747400, #    utc_start 2017-04-01 16:30:00 (Sat)
63642472200, #      utc_end 2017-09-30 16:30:00 (Sat)
63626781600, #  local_start 2017-04-02 02:00:00 (Sun)
63642506400, #    local_end 2017-10-01 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63642472200, #    utc_start 2017-09-30 16:30:00 (Sat)
63658197000, #      utc_end 2018-03-31 16:30:00 (Sat)
63642510000, #  local_start 2017-10-01 03:00:00 (Sun)
63658234800, #    local_end 2018-04-01 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63658197000, #    utc_start 2018-03-31 16:30:00 (Sat)
63674526600, #      utc_end 2018-10-06 16:30:00 (Sat)
63658231200, #  local_start 2018-04-01 02:00:00 (Sun)
63674560800, #    local_end 2018-10-07 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63674526600, #    utc_start 2018-10-06 16:30:00 (Sat)
63690251400, #      utc_end 2019-04-06 16:30:00 (Sat)
63674564400, #  local_start 2018-10-07 03:00:00 (Sun)
63690289200, #    local_end 2019-04-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63690251400, #    utc_start 2019-04-06 16:30:00 (Sat)
63705976200, #      utc_end 2019-10-05 16:30:00 (Sat)
63690285600, #  local_start 2019-04-07 02:00:00 (Sun)
63706010400, #    local_end 2019-10-06 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63705976200, #    utc_start 2019-10-05 16:30:00 (Sat)
63721701000, #      utc_end 2020-04-04 16:30:00 (Sat)
63706014000, #  local_start 2019-10-06 03:00:00 (Sun)
63721738800, #    local_end 2020-04-05 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63721701000, #    utc_start 2020-04-04 16:30:00 (Sat)
63737425800, #      utc_end 2020-10-03 16:30:00 (Sat)
63721735200, #  local_start 2020-04-05 02:00:00 (Sun)
63737460000, #    local_end 2020-10-04 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63737425800, #    utc_start 2020-10-03 16:30:00 (Sat)
63753150600, #      utc_end 2021-04-03 16:30:00 (Sat)
63737463600, #  local_start 2020-10-04 03:00:00 (Sun)
63753188400, #    local_end 2021-04-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63753150600, #    utc_start 2021-04-03 16:30:00 (Sat)
63768875400, #      utc_end 2021-10-02 16:30:00 (Sat)
63753184800, #  local_start 2021-04-04 02:00:00 (Sun)
63768909600, #    local_end 2021-10-03 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63768875400, #    utc_start 2021-10-02 16:30:00 (Sat)
63784600200, #      utc_end 2022-04-02 16:30:00 (Sat)
63768913200, #  local_start 2021-10-03 03:00:00 (Sun)
63784638000, #    local_end 2022-04-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63784600200, #    utc_start 2022-04-02 16:30:00 (Sat)
63800325000, #      utc_end 2022-10-01 16:30:00 (Sat)
63784634400, #  local_start 2022-04-03 02:00:00 (Sun)
63800359200, #    local_end 2022-10-02 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63800325000, #    utc_start 2022-10-01 16:30:00 (Sat)
63816049800, #      utc_end 2023-04-01 16:30:00 (Sat)
63800362800, #  local_start 2022-10-02 03:00:00 (Sun)
63816087600, #    local_end 2023-04-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63816049800, #    utc_start 2023-04-01 16:30:00 (Sat)
63831774600, #      utc_end 2023-09-30 16:30:00 (Sat)
63816084000, #  local_start 2023-04-02 02:00:00 (Sun)
63831808800, #    local_end 2023-10-01 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63831774600, #    utc_start 2023-09-30 16:30:00 (Sat)
63848104200, #      utc_end 2024-04-06 16:30:00 (Sat)
63831812400, #  local_start 2023-10-01 03:00:00 (Sun)
63848142000, #    local_end 2024-04-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63848104200, #    utc_start 2024-04-06 16:30:00 (Sat)
63863829000, #      utc_end 2024-10-05 16:30:00 (Sat)
63848138400, #  local_start 2024-04-07 02:00:00 (Sun)
63863863200, #    local_end 2024-10-06 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63863829000, #    utc_start 2024-10-05 16:30:00 (Sat)
63879553800, #      utc_end 2025-04-05 16:30:00 (Sat)
63863866800, #  local_start 2024-10-06 03:00:00 (Sun)
63879591600, #    local_end 2025-04-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63879553800, #    utc_start 2025-04-05 16:30:00 (Sat)
63895278600, #      utc_end 2025-10-04 16:30:00 (Sat)
63879588000, #  local_start 2025-04-06 02:00:00 (Sun)
63895312800, #    local_end 2025-10-05 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63895278600, #    utc_start 2025-10-04 16:30:00 (Sat)
63911003400, #      utc_end 2026-04-04 16:30:00 (Sat)
63895316400, #  local_start 2025-10-05 03:00:00 (Sun)
63911041200, #    local_end 2026-04-05 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63911003400, #    utc_start 2026-04-04 16:30:00 (Sat)
63926728200, #      utc_end 2026-10-03 16:30:00 (Sat)
63911037600, #  local_start 2026-04-05 02:00:00 (Sun)
63926762400, #    local_end 2026-10-04 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63926728200, #    utc_start 2026-10-03 16:30:00 (Sat)
63942453000, #      utc_end 2027-04-03 16:30:00 (Sat)
63926766000, #  local_start 2026-10-04 03:00:00 (Sun)
63942490800, #    local_end 2027-04-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63942453000, #    utc_start 2027-04-03 16:30:00 (Sat)
63958177800, #      utc_end 2027-10-02 16:30:00 (Sat)
63942487200, #  local_start 2027-04-04 02:00:00 (Sun)
63958212000, #    local_end 2027-10-03 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63958177800, #    utc_start 2027-10-02 16:30:00 (Sat)
63973902600, #      utc_end 2028-04-01 16:30:00 (Sat)
63958215600, #  local_start 2027-10-03 03:00:00 (Sun)
63973940400, #    local_end 2028-04-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
63973902600, #    utc_start 2028-04-01 16:30:00 (Sat)
63989627400, #      utc_end 2028-09-30 16:30:00 (Sat)
63973936800, #  local_start 2028-04-02 02:00:00 (Sun)
63989661600, #    local_end 2028-10-01 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
63989627400, #    utc_start 2028-09-30 16:30:00 (Sat)
64005352200, #      utc_end 2029-03-31 16:30:00 (Sat)
63989665200, #  local_start 2028-10-01 03:00:00 (Sun)
64005390000, #    local_end 2029-04-01 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64005352200, #    utc_start 2029-03-31 16:30:00 (Sat)
64021681800, #      utc_end 2029-10-06 16:30:00 (Sat)
64005386400, #  local_start 2029-04-01 02:00:00 (Sun)
64021716000, #    local_end 2029-10-07 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64021681800, #    utc_start 2029-10-06 16:30:00 (Sat)
64037406600, #      utc_end 2030-04-06 16:30:00 (Sat)
64021719600, #  local_start 2029-10-07 03:00:00 (Sun)
64037444400, #    local_end 2030-04-07 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64037406600, #    utc_start 2030-04-06 16:30:00 (Sat)
64053131400, #      utc_end 2030-10-05 16:30:00 (Sat)
64037440800, #  local_start 2030-04-07 02:00:00 (Sun)
64053165600, #    local_end 2030-10-06 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64053131400, #    utc_start 2030-10-05 16:30:00 (Sat)
64068856200, #      utc_end 2031-04-05 16:30:00 (Sat)
64053169200, #  local_start 2030-10-06 03:00:00 (Sun)
64068894000, #    local_end 2031-04-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64068856200, #    utc_start 2031-04-05 16:30:00 (Sat)
64084581000, #      utc_end 2031-10-04 16:30:00 (Sat)
64068890400, #  local_start 2031-04-06 02:00:00 (Sun)
64084615200, #    local_end 2031-10-05 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64084581000, #    utc_start 2031-10-04 16:30:00 (Sat)
64100305800, #      utc_end 2032-04-03 16:30:00 (Sat)
64084618800, #  local_start 2031-10-05 03:00:00 (Sun)
64100343600, #    local_end 2032-04-04 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64100305800, #    utc_start 2032-04-03 16:30:00 (Sat)
64116030600, #      utc_end 2032-10-02 16:30:00 (Sat)
64100340000, #  local_start 2032-04-04 02:00:00 (Sun)
64116064800, #    local_end 2032-10-03 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64116030600, #    utc_start 2032-10-02 16:30:00 (Sat)
64131755400, #      utc_end 2033-04-02 16:30:00 (Sat)
64116068400, #  local_start 2032-10-03 03:00:00 (Sun)
64131793200, #    local_end 2033-04-03 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64131755400, #    utc_start 2033-04-02 16:30:00 (Sat)
64147480200, #      utc_end 2033-10-01 16:30:00 (Sat)
64131789600, #  local_start 2033-04-03 02:00:00 (Sun)
64147514400, #    local_end 2033-10-02 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64147480200, #    utc_start 2033-10-01 16:30:00 (Sat)
64163205000, #      utc_end 2034-04-01 16:30:00 (Sat)
64147518000, #  local_start 2033-10-02 03:00:00 (Sun)
64163242800, #    local_end 2034-04-02 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64163205000, #    utc_start 2034-04-01 16:30:00 (Sat)
64178929800, #      utc_end 2034-09-30 16:30:00 (Sat)
64163239200, #  local_start 2034-04-02 02:00:00 (Sun)
64178964000, #    local_end 2034-10-01 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64178929800, #    utc_start 2034-09-30 16:30:00 (Sat)
64194654600, #      utc_end 2035-03-31 16:30:00 (Sat)
64178967600, #  local_start 2034-10-01 03:00:00 (Sun)
64194692400, #    local_end 2035-04-01 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64194654600, #    utc_start 2035-03-31 16:30:00 (Sat)
64210984200, #      utc_end 2035-10-06 16:30:00 (Sat)
64194688800, #  local_start 2035-04-01 02:00:00 (Sun)
64211018400, #    local_end 2035-10-07 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
    [
64210984200, #    utc_start 2035-10-06 16:30:00 (Sat)
64226709000, #      utc_end 2036-04-05 16:30:00 (Sat)
64211022000, #  local_start 2035-10-07 03:00:00 (Sun)
64226746800, #    local_end 2036-04-06 03:00:00 (Sun)
37800,
1,
'ACDT',
    ],
    [
64226709000, #    utc_start 2036-04-05 16:30:00 (Sat)
64242433800, #      utc_end 2036-10-04 16:30:00 (Sat)
64226743200, #  local_start 2036-04-06 02:00:00 (Sun)
64242468000, #    local_end 2036-10-05 02:00:00 (Sun)
34200,
0,
'ACST',
    ],
];

sub olson_version {'2025a'}

sub has_dst_changes {70}

sub _max_year {2035}

sub _new_instance {
    return shift->_init( @_, spans => $spans );
}

sub _last_offset { 34200 }

my $last_observance = bless( {
  'format' => 'AC%sT',
  'gmtoff' => '9:30',
  'local_start_datetime' => bless( {
    'formatter' => undef,
    'local_rd_days' => 719528,
    'local_rd_secs' => 0,
    'offset_modifier' => 0,
    'rd_nanosecs' => 0,
    'tz' => bless( {
      'name' => 'floating',
      'offset' => 0
    }, 'DateTime::TimeZone::Floating' ),
    'utc_rd_days' => 719528,
    'utc_rd_secs' => 0,
    'utc_year' => 1972
  }, 'DateTime' ),
  'offset_from_std' => 0,
  'offset_from_utc' => 34200,
  'until' => [],
  'utc_start_datetime' => bless( {
    'formatter' => undef,
    'local_rd_days' => 719527,
    'local_rd_secs' => 52200,
    'offset_modifier' => 0,
    'rd_nanosecs' => 0,
    'tz' => bless( {
      'name' => 'floating',
      'offset' => 0
    }, 'DateTime::TimeZone::Floating' ),
    'utc_rd_days' => 719527,
    'utc_rd_secs' => 52200,
    'utc_year' => 1971
  }, 'DateTime' )
}, 'DateTime::TimeZone::OlsonDB::Observance' )
;
sub _last_observance { $last_observance }

my $rules = [
  bless( {
    'at' => '2:00s',
    'from' => '2008',
    'in' => 'Oct',
    'letter' => 'D',
    'name' => 'AS',
    'offset_from_std' => 3600,
    'on' => 'Sun>=1',
    'save' => '1:00',
    'to' => 'max'
  }, 'DateTime::TimeZone::OlsonDB::Rule' ),
  bless( {
    'at' => '2:00s',
    'from' => '2008',
    'in' => 'Apr',
    'letter' => 'S',
    'name' => 'AS',
    'offset_from_std' => 0,
    'on' => 'Sun>=1',
    'save' => '0',
    'to' => 'max'
  }, 'DateTime::TimeZone::OlsonDB::Rule' )
]
;
sub _rules { $rules }


1;

