# automatically generated file, don't edit



# Copyright 2024 David Cantrell, derived from data from libphonenumber
# http://code.google.com/p/libphonenumber/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
package Number::Phone::StubCountry::FI;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250323211827;

my $formatters = [
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '75[12]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{5})'
                },
                {
                  'format' => '$1',
                  'leading_digits' => '20[2-59]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{5})'
                },
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '11',
                  'pattern' => '(\\d{6})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            (?:
              [1-3]0|
              [68]
            )0|
            70[07-9]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3,7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            [14]|
            2[09]|
            50|
            7[135]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{4,8})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '7',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{6,10})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            (?:
              19|
              [2568]
            )[1-8]|
            3(?:
              0[1-9]|
              [1-9]
            )|
            9
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{4,9})'
                }
              ];

my $validators = {
                'fixed_line' => '
          1[3-7][1-8]\\d{3,6}|
          (?:
            19[1-8]|
            [23568][1-8]\\d|
            9(?:
              00|
              [1-8]\\d
            )
          )\\d{2,6}
        ',
                'geographic' => '
          1[3-7][1-8]\\d{3,6}|
          (?:
            19[1-8]|
            [23568][1-8]\\d|
            9(?:
              00|
              [1-8]\\d
            )
          )\\d{2,6}
        ',
                'mobile' => '
          4946\\d{2,6}|
          (?:
            4[0-8]|
            50
          )\\d{4,8}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '([67]00\\d{5,6})|(
          20\\d{4,8}|
          60[12]\\d{5,6}|
          7(?:
            099\\d{4,5}|
            5[03-9]\\d{3,7}
          )|
          20[2-59]\\d\\d|
          (?:
            606|
            7(?:
              0[78]|
              1|
              3\\d
            )
          )\\d{7}|
          (?:
            10|
            29|
            3[09]|
            70[1-5]\\d
          )\\d{4,8}
        )',
                'toll_free' => '800\\d{4,6}',
                'voip' => ''
              };
my %areanames = ();
$areanames{sv} = {"35816", "Lappland",
"35865", "Vasa",
"35856", "Kymmene",
"35862", "Vasa",
"35884", "Uleåborg",
"35883", "Uleåborg",
"35857", "Kymmene",
"35833", "Tavastland",
"35834", "Tavastland",
"35861", "Vasa",
"35824", "Åbo\/Björneborg",
"35823", "Åbo\/Björneborg",
"35813", "Norra\ Karelen",
"35814", "Mellersta\ Finland",
"35868", "Vasa",
"35886", "Uleåborg",
"3589", "Helsingfors",
"35854", "Kymmene",
"35853", "Kymmene",
"35887", "Uleåborg",
"35826", "Åbo\/Björneborg",
"35837", "Tavastland",
"35827", "Åbo\/Björneborg",
"35836", "Tavastland",
"35832", "Tavastland",
"35881", "Uleåborg",
"35822", "Åbo\/Björneborg",
"35821", "Åbo\/Björneborg",
"35864", "Vasa",
"35863", "Vasa",
"35882", "Uleåborg",
"35831", "Tavastland",
"35885", "Uleåborg",
"35890", "Nyland",
"35858", "Kymmene",
"35825", "Åbo\/Björneborg",
"35835", "Tavastland",
"35851", "Kymmene",
"35815", "St\ Michel",
"35867", "Vasa",
"35819", "Nyland",
"35866", "Vasa",
"35852", "Kymmene",
"35855", "Kymmene",
"35888", "Uleåborg",
"35838", "Tavastland",
"35828", "Åbo\/Björneborg",};
$areanames{en} = {"35865", "Vaasa",
"35816", "Lapland",
"35817", "Kuopio",
"35824", "Turku\/Pori",
"35823", "Turku\/Pori",
"35861", "Vaasa",
"35833", "Häme",
"35834", "Häme",
"35884", "Oulu",
"35883", "Oulu",
"35857", "Kymi",
"35862", "Vaasa",
"35856", "Kymi",
"35868", "Vaasa",
"35813", "North\ Karelia",
"35814", "Central\ Finland",
"35836", "Häme",
"35827", "Turku\/Pori",
"35837", "Häme",
"35826", "Turku\/Pori",
"35854", "Kymi",
"35887", "Oulu",
"35853", "Kymi",
"3589", "Helsinki",
"35886", "Oulu",
"35831", "Häme",
"35882", "Oulu",
"35864", "Vaasa",
"35863", "Vaasa",
"35821", "Turku\/Pori",
"35822", "Turku\/Pori",
"35881", "Oulu",
"35832", "Häme",
"35835", "Häme",
"35825", "Turku\/Pori",
"35890", "Uusimaa",
"35858", "Kymi",
"35885", "Oulu",
"35852", "Kymi",
"35866", "Vaasa",
"35819", "Uusimaa",
"35867", "Vaasa",
"35815", "Mikkeli",
"35851", "Kymi",
"35828", "Turku\/Pori",
"35838", "Häme",
"35888", "Oulu",
"35855", "Kymi",};
$areanames{fi} = {"35816", "Lappi",
"35814", "Keski\-Suomi",
"35813", "Pohjois\-Karjala",};
my $timezones = {
               '' => [
                       'Europe/Helsinki',
                       'Europe/Mariehamn'
                     ],
               '1' => [
                        'Europe/Helsinki'
                      ],
               '10' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '18' => [
                         'Europe/Mariehamn'
                       ],
               '2' => [
                        'Europe/Helsinki'
                      ],
               '20' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '29' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '3' => [
                        'Europe/Helsinki'
                      ],
               '30' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '39' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '4' => [
                        'Europe/Helsinki',
                        'Europe/Mariehamn'
                      ],
               '5' => [
                        'Europe/Helsinki'
                      ],
               '50' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '6' => [
                        'Europe/Helsinki'
                      ],
               '60' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '7' => [
                        'Europe/Helsinki',
                        'Europe/Mariehamn'
                      ],
               '8' => [
                        'Europe/Helsinki'
                      ],
               '80' => [
                         'Europe/Helsinki',
                         'Europe/Mariehamn'
                       ],
               '9' => [
                        'Europe/Helsinki'
                      ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+358|\D)//g;
      my $self = bless({ country_code => '358', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '358', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;