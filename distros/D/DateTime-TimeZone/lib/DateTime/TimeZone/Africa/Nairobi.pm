# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.08) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/nUm_LjpJ6O/africa.  Olson data version 2025b
#
# Do not edit this file directly.
#
package DateTime::TimeZone::Africa::Nairobi;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '2.65';

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::Africa::Nairobi::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
60189514364, #      utc_end 1908-04-30 21:32:44 (Thu)
DateTime::TimeZone::NEG_INFINITY, #  local_start
60189523200, #    local_end 1908-05-01 00:00:00 (Fri)
8836,
0,
'LMT',
    ],
    [
60189514364, #    utc_start 1908-04-30 21:32:44 (Thu)
60825936600, #      utc_end 1928-06-30 21:30:00 (Sat)
60189523364, #  local_start 1908-05-01 00:02:44 (Fri)
60825945600, #    local_end 1928-07-01 00:00:00 (Sun)
9000,
0,
'+0230',
    ],
    [
60825936600, #    utc_start 1928-06-30 21:30:00 (Sat)
60873714000, #      utc_end 1930-01-04 21:00:00 (Sat)
60825947400, #  local_start 1928-07-01 00:30:00 (Sun)
60873724800, #    local_end 1930-01-05 00:00:00 (Sun)
10800,
0,
'EAT',
    ],
    [
60873714000, #    utc_start 1930-01-04 21:00:00 (Sat)
61094295000, #      utc_end 1936-12-31 21:30:00 (Thu)
60873723000, #  local_start 1930-01-04 23:30:00 (Sat)
61094304000, #    local_end 1937-01-01 00:00:00 (Fri)
9000,
0,
'+0230',
    ],
    [
61094295000, #    utc_start 1936-12-31 21:30:00 (Thu)
61270377300, #      utc_end 1942-07-31 21:15:00 (Fri)
61094304900, #  local_start 1937-01-01 00:15:00 (Fri)
61270387200, #    local_end 1942-08-01 00:00:00 (Sat)
9900,
0,
'+0245',
    ],
    [
61270377300, #    utc_start 1942-07-31 21:15:00 (Fri)
DateTime::TimeZone::INFINITY, #      utc_end
61270388100, #  local_start 1942-08-01 00:15:00 (Sat)
DateTime::TimeZone::INFINITY, #    local_end
10800,
0,
'EAT',
    ],
];

sub olson_version {'2025b'}

sub has_dst_changes {0}

sub _max_year {2035}

sub _new_instance {
    return shift->_init( @_, spans => $spans );
}



1;

