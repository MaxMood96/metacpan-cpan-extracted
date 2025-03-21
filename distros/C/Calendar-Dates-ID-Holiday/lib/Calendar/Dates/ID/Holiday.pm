package Calendar::Dates::ID::Holiday;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2021-03-09'; # DATE
our $DIST = 'Calendar-Dates-ID-Holiday'; # DIST
our $VERSION = '0.008'; # VERSION

use 5.010001;
use strict;
use warnings;

use Calendar::Indonesia::Holiday;
use Role::Tiny::With;

with 'Calendar::DatesRoles::DataUser::CalendarVar';

our $CALENDAR;

sub prepare_data {
    $CALENDAR = {
        entries => [],
    };

    my $res = Calendar::Indonesia::Holiday::list_idn_holidays(detail=>1);
    die "Cannot get list of holidays from Calendar::Indonesia::Holiday: $res->[0] - $res->[1]"
        unless $res->[0] == 200;
    for my $e (@{ $res->[2] }) {
        $e->{summary} = delete $e->{eng_name};
        $e->{"summary.alt.lang.id"} = delete $e->{ind_name};
        if ($e->{eng_aliases} && @{ $e->{eng_aliases} }) {
            $e->{description} = "Also known as ".
                join(", ", @{ delete $e->{eng_aliases} });
        }
        if ($e->{ind_aliases} && @{ $e->{ind_aliases} }) {
            $e->{"description.alt.lang.id"} = "Juga dikenal dengan ".
                join(", ", @{ delete $e->{ind_aliases} });
        }
        push @{ $CALENDAR->{entries} }, $e;
    }
}

1;
# ABSTRACT: Indonesian holiday calendar

__END__

=pod

=encoding UTF-8

=head1 NAME

Calendar::Dates::ID::Holiday - Indonesian holiday calendar

=head1 VERSION

This document describes version 0.008 of Calendar::Dates::ID::Holiday (from Perl distribution Calendar-Dates-ID-Holiday), released on 2021-03-09.

=head1 SYNOPSIS

=head2 Using from Perl

 use Calendar::Dates::ID::Holiday;
 my $min_year = Calendar::Dates::ID::Holiday->get_min_year; # => 1990
 my $max_year = Calendar::Dates::ID::Holiday->get_max_year; # => 2021
 my $entries  = Calendar::Dates::ID::Holiday->get_entries(2021);

C<$entries> result:

 [
   {
     "date"                => "2021-01-01",
     "day"                 => 1,
     "dow"                 => 5,
     "fixed_date"          => 1,
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 1,
     "summary"             => "New Year",
     "summary.alt.lang.id" => "Tahun Baru",
     "tags"                => ["international", "fixed-date"],
     "year"                => 2021,
   },
   {
     "date"                => "2021-02-12",
     "day"                 => 12,
     "dow"                 => 5,
     "eng_aliases"         => [],
     "ind_aliases"         => [],
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 2,
     "summary"             => "Chinese New Year 2572",
     "summary.alt.lang.id" => "Tahun Baru Imlek 2572",
     "tags"                => ["international", "calendar=lunar"],
     "year"                => 2021,
     "year_start"          => 2003,
   },
   {
     "date"                => "2021-03-11",
     "day"                 => 11,
     "dow"                 => 4,
     "eng_aliases"         => [],
     "ind_aliases"         => [],
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 3,
     "summary"             => "Isra And Miraj",
     "summary.alt.lang.id" => "Isra Miraj",
     "tags"                => ["religious", "religion=islam", "calendar=lunar"],
     "year"                => 2021,
   },
   {
     "date" => "2021-03-14",
     "day" => 14,
     "description" => "Also known as Bali New Year, Bali Day Of Silence",
     "description.alt.lang.id" => "Juga dikenal dengan Tahun Baru Saka",
     "dow" => 7,
     "is_holiday" => 1,
     "is_joint_leave" => 0,
     "month" => 3,
     "summary" => "Nyepi 1943",
     "summary.alt.lang.id" => "Nyepi 1943",
     "tags" => ["religious", "religion=hinduism", "calendar=saka"],
     "year" => 2021,
   },
   {
     "date" => "2021-04-02",
     "day" => 2,
     "description.alt.lang.id" => "Juga dikenal dengan Wafat Isa Al-Masih",
     "dow" => 5,
     "eng_aliases" => [],
     "is_holiday" => 1,
     "is_joint_leave" => 0,
     "month" => 4,
     "summary" => "Good Friday",
     "summary.alt.lang.id" => "Jum'at Agung",
     "tags" => ["religious", "religion=christianity"],
     "year" => 2021,
   },
   {
     "date"                => "2021-05-01",
     "day"                 => 1,
     "decree_date"         => "2013-04-29",
     "decree_note"         => "Labor day becomes national holiday since 2014, decreed by president",
     "dow"                 => 6,
     "fixed_date"          => 1,
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 5,
     "summary"             => "Labor Day",
     "summary.alt.lang.id" => "Hari Buruh",
     "tags"                => ["international", "fixed-date"],
     "year"                => 2021,
     "year_start"          => 2014,
   },
   {
     "date"                => "2021-05-12",
     "day"                 => 12,
     "dow"                 => 3,
     "eng_aliases"         => [],
     "ind_aliases"         => [],
     "is_holiday"          => 0,
     "is_joint_leave"      => 1,
     "month"               => 5,
     "summary"             => "Joint Leave (Eid Ul-Fitr 1442H (Day 1))",
     "summary.alt.lang.id" => "Cuti Bersama (Idul Fitri 1442H (Hari 1))",
     "tags"                => [],
     "year"                => 2021,
   },
   {
     "date"                => "2021-05-13",
     "day"                 => 13,
     "dow"                 => 4,
     "holidays"            => [
                                {
                                  date => "2021-05-13",
                                  day => 13,
                                  dow => 4,
                                  eng_aliases => [],
                                  eng_name => "Ascension Day",
                                  ind_aliases => [],
                                  ind_name => "Kenaikan Isa Al-Masih",
                                  is_holiday => 1,
                                  is_joint_leave => 0,
                                  month => 5,
                                  tags => ["religious", "religion=christianity"],
                                  year => 2021,
                                },
                                {
                                  date => "2021-05-13",
                                  day => 13,
                                  dow => 4,
                                  eng_aliases => [],
                                  eng_name => "Eid Ul-Fitr 1442H (Day 1)",
                                  ind_aliases => ["Lebaran"],
                                  ind_name => "Idul Fitri 1442H (Hari 1)",
                                  is_holiday => 1,
                                  is_joint_leave => 0,
                                  month => 5,
                                  tags => ["religious", "religion=islam", "calendar=lunar"],
                                  year => 2021,
                                },
                              ],
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 5,
     "multiple"            => 1,
     "summary"             => "Ascension Day, Eid Ul-Fitr 1442H (Day 1)",
     "summary.alt.lang.id" => "Kenaikan Isa Al-Masih, Idul Fitri 1442H (Hari 1)",
     "tags"                => [
                                "religious",
                                "religion=christianity",
                                "religion=islam",
                                "calendar=lunar",
                              ],
     "year"                => 2021,
   },
   {
     "date" => "2021-05-14",
     "day" => 14,
     "description.alt.lang.id" => "Juga dikenal dengan Lebaran",
     "dow" => 5,
     "eng_aliases" => [],
     "is_holiday" => 1,
     "is_joint_leave" => 0,
     "month" => 5,
     "summary" => "Eid Ul-Fitr 1442H (Day 1)",
     "summary.alt.lang.id" => "Idul Fitri 1442H (Hari 1)",
     "tags" => ["religious", "religion=islam", "calendar=lunar"],
     "year" => 2021,
   },
   {
     "date"                => "2021-05-26",
     "day"                 => 26,
     "description"         => "Also known as Vesak",
     "dow"                 => 3,
     "ind_aliases"         => [],
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 5,
     "summary"             => "Vesakha 2565",
     "summary.alt.lang.id" => "Waisyak 2565",
     "tags"                => ["religious", "religion=buddhism"],
     "year"                => 2021,
   },
   {
     "date"                => "2021-06-01",
     "day"                 => 1,
     "decree_date"         => "2016-06-01",
     "decree_note"         => "Pancasila day becomes national holiday since 2017, decreed by president (Keppres 24/2016)",
     "dow"                 => 2,
     "fixed_date"          => 1,
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 6,
     "summary"             => "Pancasila Day",
     "summary.alt.lang.id" => "Hari Lahir Pancasila",
     "tags"                => ["national", "fixed-date"],
     "year"                => 2021,
     "year_start"          => 2017,
   },
   {
     "date" => "2021-07-20",
     "day" => 20,
     "description.alt.lang.id" => "Juga dikenal dengan Idul Kurban",
     "dow" => 2,
     "eng_aliases" => [],
     "is_holiday" => 1,
     "is_joint_leave" => 0,
     "month" => 7,
     "summary" => "Eid Al-Adha",
     "summary.alt.lang.id" => "Idul Adha",
     "tags" => ["religious", "religion=islam", "calendar=lunar"],
     "year" => 2021,
   },
   {
     "date" => "2021-08-10",
     "day" => 10,
     "description.alt.lang.id" => "Juga dikenal dengan 1 Muharam",
     "dow" => 2,
     "eng_aliases" => [],
     "is_holiday" => 1,
     "is_joint_leave" => 0,
     "month" => 8,
     "summary" => "Hijra 1443H",
     "summary.alt.lang.id" => "Tahun Baru Hijriyah 1443H",
     "tags" => ["calendar=lunar"],
     "year" => 2021,
   },
   {
     "date"                => "2021-08-17",
     "day"                 => 17,
     "dow"                 => 2,
     "fixed_date"          => 1,
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 8,
     "summary"             => "Declaration Of Independence",
     "summary.alt.lang.id" => "Proklamasi",
     "tags"                => ["national", "fixed-date"],
     "year"                => 2021,
   },
   {
     "date" => "2021-10-19",
     "day" => 19,
     "description" => "Also known as Mawlid An-Nabi",
     "description.alt.lang.id" => "Juga dikenal dengan Maulud",
     "dow" => 2,
     "is_holiday" => 1,
     "is_joint_leave" => 0,
     "month" => 10,
     "summary" => "Mawlid",
     "summary.alt.lang.id" => "Maulid Nabi Muhammad",
     "tags" => ["religious", "religion=islam", "calendar=lunar"],
     "year" => 2021,
   },
   {
     "date"                => "2021-12-24",
     "day"                 => 24,
     "dow"                 => 5,
     "eng_aliases"         => [],
     "ind_aliases"         => [],
     "is_holiday"          => 0,
     "is_joint_leave"      => 1,
     "month"               => 12,
     "summary"             => "Joint Leave (Christmas)",
     "summary.alt.lang.id" => "Cuti Bersama (Natal)",
     "tags"                => [],
     "year"                => 2021,
   },
   {
     "date"                => "2021-12-25",
     "day"                 => 25,
     "dow"                 => 6,
     "fixed_date"          => 1,
     "is_holiday"          => 1,
     "is_joint_leave"      => 0,
     "month"               => 12,
     "summary"             => "Christmas",
     "summary.alt.lang.id" => "Natal",
     "tags"                => [
                                "international",
                                "religious",
                                "religion=christianity",
                                "fixed-date",
                              ],
     "year"                => 2021,
   },
 ]

=head2 Using from CLI (requires L<list-calendar-dates> and L<calx>)

 % list-calendar-dates -l -m ID::Holiday
 % calx -c ID::Holiday

=head1 DESCRIPTION

This module provides Indonesian holiday calendar using the L<Calendar::Dates>
interface.

=head1 DATES STATISTICS

 +---------------+-------+
 | key           | value |
 +---------------+-------+
 | Earliest year | 1990  |
 | Latest year   | 2021  |
 +---------------+-------+

=head1 DATES SAMPLES

Entries for year 2020:

 [
    200,
    "OK",
    [
       {
          "date" : "2020-01-01",
          "day" : 1,
          "dow" : 3,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 1,
          "summary" : "New Year",
          "summary.alt.lang.id" : "Tahun Baru",
          "tags" : "international, fixed-date",
          "year" : 2020
       },
       {
          "date" : "2020-01-25",
          "day" : 25,
          "dow" : 6,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 1,
          "summary" : "Chinese New Year 2571",
          "summary.alt.lang.id" : "Tahun Baru Imlek 2571",
          "tags" : "international, calendar=lunar",
          "year" : 2020,
          "year_start" : 2003
       },
       {
          "date" : "2020-03-22",
          "day" : 22,
          "dow" : 7,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 3,
          "summary" : "Isra And Miraj",
          "summary.alt.lang.id" : "Isra Miraj",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2020
       },
       {
          "date" : "2020-03-25",
          "day" : 25,
          "description" : "Also known as Bali New Year, Bali Day Of Silence",
          "description.alt.lang.id" : "Juga dikenal dengan Tahun Baru Saka",
          "dow" : 3,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 3,
          "summary" : "Nyepi 1942",
          "summary.alt.lang.id" : "Nyepi 1942",
          "tags" : "religious, religion=hinduism, calendar=saka",
          "year" : 2020
       },
       {
          "date" : "2020-04-10",
          "day" : 10,
          "description.alt.lang.id" : "Juga dikenal dengan Wafat Isa Al-Masih",
          "dow" : 5,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 4,
          "summary" : "Good Friday",
          "summary.alt.lang.id" : "Jum'at Agung",
          "tags" : "religious, religion=christianity",
          "year" : 2020
       },
       {
          "date" : "2020-05-01",
          "day" : 1,
          "decree_date" : "2013-04-29",
          "decree_note" : "Labor day becomes national holiday since 2014, decreed by president",
          "dow" : 5,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Labor Day",
          "summary.alt.lang.id" : "Hari Buruh",
          "tags" : "international, fixed-date",
          "year" : 2020,
          "year_start" : 2014
       },
       {
          "date" : "2020-05-07",
          "day" : 7,
          "description" : "Also known as Vesak",
          "dow" : 4,
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Vesakha 2564",
          "summary.alt.lang.id" : "Waisyak 2564",
          "tags" : "religious, religion=buddhism",
          "year" : 2020
       },
       {
          "date" : "2020-05-21",
          "day" : 21,
          "dow" : 4,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Ascension Day",
          "summary.alt.lang.id" : "Kenaikan Isa Al-Masih",
          "tags" : "religious, religion=christianity",
          "year" : 2020
       },
       {
          "date" : "2020-05-24",
          "day" : 24,
          "description.alt.lang.id" : "Juga dikenal dengan Lebaran",
          "dow" : 7,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Eid Ul-Fitr 1441H (Day 1)",
          "summary.alt.lang.id" : "Idul Fitri 1441H (Hari 1)",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2020
       },
       {
          "date" : "2020-05-25",
          "day" : 25,
          "description.alt.lang.id" : "Juga dikenal dengan Lebaran",
          "dow" : 1,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Eid Ul-Fitr 1441H (Day 2)",
          "summary.alt.lang.id" : "Idul Fitri 1441H (Hari 2)",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2020
       },
       {
          "date" : "2020-06-01",
          "day" : 1,
          "decree_date" : "2016-06-01",
          "decree_note" : "Pancasila day becomes national holiday since 2017, decreed by president (Keppres 24/2016)",
          "dow" : 1,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 6,
          "summary" : "Pancasila Day",
          "summary.alt.lang.id" : "Hari Lahir Pancasila",
          "tags" : "national, fixed-date",
          "year" : 2020,
          "year_start" : 2017
       },
       {
          "date" : "2020-07-31",
          "day" : 31,
          "description.alt.lang.id" : "Juga dikenal dengan Idul Kurban",
          "dow" : 5,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 7,
          "summary" : "Eid Al-Adha",
          "summary.alt.lang.id" : "Idul Adha",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2020
       },
       {
          "date" : "2020-08-17",
          "day" : 17,
          "dow" : 1,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 8,
          "summary" : "Declaration Of Independence",
          "summary.alt.lang.id" : "Proklamasi",
          "tags" : "national, fixed-date",
          "year" : 2020
       },
       {
          "date" : "2020-08-20",
          "day" : 20,
          "description.alt.lang.id" : "Juga dikenal dengan 1 Muharam",
          "dow" : 4,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 8,
          "summary" : "Hijra 1442H",
          "summary.alt.lang.id" : "Tahun Baru Hijriyah 1442H",
          "tags" : "calendar=lunar",
          "year" : 2020
       },
       {
          "date" : "2020-08-21",
          "day" : 21,
          "dow" : 5,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 8,
          "summary" : "Joint Leave (Hijra 1442H)",
          "summary.alt.lang.id" : "Cuti Bersama (Tahun Baru Hijriyah 1442H)",
          "tags" : "",
          "year" : 2020
       },
       {
          "date" : "2020-10-28",
          "day" : 28,
          "dow" : 3,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 10,
          "summary" : "Joint Leave (Mawlid)",
          "summary.alt.lang.id" : "Cuti Bersama (Maulid Nabi Muhammad)",
          "tags" : "",
          "year" : 2020
       },
       {
          "date" : "2020-10-29",
          "day" : 29,
          "description" : "Also known as Mawlid An-Nabi",
          "description.alt.lang.id" : "Juga dikenal dengan Maulud",
          "dow" : 4,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 10,
          "summary" : "Mawlid",
          "summary.alt.lang.id" : "Maulid Nabi Muhammad",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2020
       },
       {
          "date" : "2020-10-30",
          "day" : 30,
          "dow" : 5,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 10,
          "summary" : "Joint Leave (Mawlid)",
          "summary.alt.lang.id" : "Cuti Bersama (Maulid Nabi Muhammad)",
          "tags" : "",
          "year" : 2020
       },
       {
          "date" : "2020-12-09",
          "day" : 9,
          "decree_date" : "2015-11-27",
          "dow" : 3,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 12,
          "summary" : "Joint Regional Election",
          "summary.alt.lang.id" : "Pilkada Serentak",
          "tags" : "political",
          "year" : 2020
       },
       {
          "date" : "2020-12-24",
          "day" : 24,
          "dow" : 4,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 12,
          "summary" : "Joint Leave (Christmas)",
          "summary.alt.lang.id" : "Cuti Bersama (Natal)",
          "tags" : "",
          "year" : 2020
       },
       {
          "date" : "2020-12-25",
          "day" : 25,
          "dow" : 5,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 12,
          "summary" : "Christmas",
          "summary.alt.lang.id" : "Natal",
          "tags" : "international, religious, religion=christianity, fixed-date",
          "year" : 2020
       },
       {
          "date" : "2020-12-31",
          "day" : 31,
          "dow" : 4,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 12,
          "summary" : "Joint Leave (Eid Ul-Fitr 1441H (Day 2))",
          "summary.alt.lang.id" : "Cuti Bersama (Idul Fitri 1441H (Hari 2))",
          "tags" : "",
          "year" : 2020
       }
    ],
    {}
 ]

Entries for year 2021:

 [
    200,
    "OK",
    [
       {
          "date" : "2021-01-01",
          "day" : 1,
          "dow" : 5,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 1,
          "summary" : "New Year",
          "summary.alt.lang.id" : "Tahun Baru",
          "tags" : "international, fixed-date",
          "year" : 2021
       },
       {
          "date" : "2021-02-12",
          "day" : 12,
          "dow" : 5,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 2,
          "summary" : "Chinese New Year 2572",
          "summary.alt.lang.id" : "Tahun Baru Imlek 2572",
          "tags" : "international, calendar=lunar",
          "year" : 2021,
          "year_start" : 2003
       },
       {
          "date" : "2021-03-11",
          "day" : 11,
          "dow" : 4,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 3,
          "summary" : "Isra And Miraj",
          "summary.alt.lang.id" : "Isra Miraj",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2021
       },
       {
          "date" : "2021-03-14",
          "day" : 14,
          "description" : "Also known as Bali New Year, Bali Day Of Silence",
          "description.alt.lang.id" : "Juga dikenal dengan Tahun Baru Saka",
          "dow" : 7,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 3,
          "summary" : "Nyepi 1943",
          "summary.alt.lang.id" : "Nyepi 1943",
          "tags" : "religious, religion=hinduism, calendar=saka",
          "year" : 2021
       },
       {
          "date" : "2021-04-02",
          "day" : 2,
          "description.alt.lang.id" : "Juga dikenal dengan Wafat Isa Al-Masih",
          "dow" : 5,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 4,
          "summary" : "Good Friday",
          "summary.alt.lang.id" : "Jum'at Agung",
          "tags" : "religious, religion=christianity",
          "year" : 2021
       },
       {
          "date" : "2021-05-01",
          "day" : 1,
          "decree_date" : "2013-04-29",
          "decree_note" : "Labor day becomes national holiday since 2014, decreed by president",
          "dow" : 6,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Labor Day",
          "summary.alt.lang.id" : "Hari Buruh",
          "tags" : "international, fixed-date",
          "year" : 2021,
          "year_start" : 2014
       },
       {
          "date" : "2021-05-12",
          "day" : 12,
          "dow" : 3,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 5,
          "summary" : "Joint Leave (Eid Ul-Fitr 1442H (Day 1))",
          "summary.alt.lang.id" : "Cuti Bersama (Idul Fitri 1442H (Hari 1))",
          "tags" : "",
          "year" : 2021
       },
       {
          "date" : "2021-05-13",
          "day" : 13,
          "dow" : 4,
          "holidays" : [
             {
                "date" : "2021-05-13",
                "day" : 13,
                "dow" : 4,
                "eng_aliases" : [],
                "eng_name" : "Ascension Day",
                "ind_aliases" : [],
                "ind_name" : "Kenaikan Isa Al-Masih",
                "is_holiday" : 1,
                "is_joint_leave" : 0,
                "month" : 5,
                "tags" : [
                   "religious",
                   "religion=christianity"
                ],
                "year" : 2021
             },
             {
                "date" : "2021-05-13",
                "day" : 13,
                "dow" : 4,
                "eng_aliases" : [],
                "eng_name" : "Eid Ul-Fitr 1442H (Day 1)",
                "ind_aliases" : [
                   "Lebaran"
                ],
                "ind_name" : "Idul Fitri 1442H (Hari 1)",
                "is_holiday" : 1,
                "is_joint_leave" : 0,
                "month" : 5,
                "tags" : [
                   "religious",
                   "religion=islam",
                   "calendar=lunar"
                ],
                "year" : 2021
             }
          ],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "multiple" : 1,
          "summary" : "Ascension Day, Eid Ul-Fitr 1442H (Day 1)",
          "summary.alt.lang.id" : "Kenaikan Isa Al-Masih, Idul Fitri 1442H (Hari 1)",
          "tags" : "religious, religion=christianity, religion=islam, calendar=lunar",
          "year" : 2021
       },
       {
          "date" : "2021-05-14",
          "day" : 14,
          "description.alt.lang.id" : "Juga dikenal dengan Lebaran",
          "dow" : 5,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Eid Ul-Fitr 1442H (Day 1)",
          "summary.alt.lang.id" : "Idul Fitri 1442H (Hari 1)",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2021
       },
       {
          "date" : "2021-05-26",
          "day" : 26,
          "description" : "Also known as Vesak",
          "dow" : 3,
          "ind_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 5,
          "summary" : "Vesakha 2565",
          "summary.alt.lang.id" : "Waisyak 2565",
          "tags" : "religious, religion=buddhism",
          "year" : 2021
       },
       {
          "date" : "2021-06-01",
          "day" : 1,
          "decree_date" : "2016-06-01",
          "decree_note" : "Pancasila day becomes national holiday since 2017, decreed by president (Keppres 24/2016)",
          "dow" : 2,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 6,
          "summary" : "Pancasila Day",
          "summary.alt.lang.id" : "Hari Lahir Pancasila",
          "tags" : "national, fixed-date",
          "year" : 2021,
          "year_start" : 2017
       },
       {
          "date" : "2021-07-20",
          "day" : 20,
          "description.alt.lang.id" : "Juga dikenal dengan Idul Kurban",
          "dow" : 2,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 7,
          "summary" : "Eid Al-Adha",
          "summary.alt.lang.id" : "Idul Adha",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2021
       },
       {
          "date" : "2021-08-10",
          "day" : 10,
          "description.alt.lang.id" : "Juga dikenal dengan 1 Muharam",
          "dow" : 2,
          "eng_aliases" : [],
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 8,
          "summary" : "Hijra 1443H",
          "summary.alt.lang.id" : "Tahun Baru Hijriyah 1443H",
          "tags" : "calendar=lunar",
          "year" : 2021
       },
       {
          "date" : "2021-08-17",
          "day" : 17,
          "dow" : 2,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 8,
          "summary" : "Declaration Of Independence",
          "summary.alt.lang.id" : "Proklamasi",
          "tags" : "national, fixed-date",
          "year" : 2021
       },
       {
          "date" : "2021-10-19",
          "day" : 19,
          "description" : "Also known as Mawlid An-Nabi",
          "description.alt.lang.id" : "Juga dikenal dengan Maulud",
          "dow" : 2,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 10,
          "summary" : "Mawlid",
          "summary.alt.lang.id" : "Maulid Nabi Muhammad",
          "tags" : "religious, religion=islam, calendar=lunar",
          "year" : 2021
       },
       {
          "date" : "2021-12-24",
          "day" : 24,
          "dow" : 5,
          "eng_aliases" : [],
          "ind_aliases" : [],
          "is_holiday" : 0,
          "is_joint_leave" : 1,
          "month" : 12,
          "summary" : "Joint Leave (Christmas)",
          "summary.alt.lang.id" : "Cuti Bersama (Natal)",
          "tags" : "",
          "year" : 2021
       },
       {
          "date" : "2021-12-25",
          "day" : 25,
          "dow" : 6,
          "fixed_date" : 1,
          "is_holiday" : 1,
          "is_joint_leave" : 0,
          "month" : 12,
          "summary" : "Christmas",
          "summary.alt.lang.id" : "Natal",
          "tags" : "international, religious, religion=christianity, fixed-date",
          "year" : 2021
       }
    ],
    {}
 ]

=for Pod::Coverage ^(prepare_data)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Calendar-Dates-ID-Holiday>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Calendar-Dates-ID-Holiday>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://github.com/perlancar/perl-Calendar-Dates-ID-Holiday/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<Calendar::Dates>

L<App::CalendarDatesUtils> contains CLIs to list dates from this module, etc.

L<calx> from L<App::calx> can display calendar and highlight dates from Calendar::Dates::* modules

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021, 2019 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
