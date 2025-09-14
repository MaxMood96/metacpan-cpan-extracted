# automatically generated file, don't edit



# Copyright 2025 David Cantrell, derived from data from libphonenumber
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
package Number::Phone::StubCountry::EE;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            [369]|
            4[3-8]|
            5(?:
              [02]|
              1(?:
                [0-8]|
                95
              )|
              5[0-478]|
              6(?:
                4[0-4]|
                5[1-589]
              )
            )|
            7[1-9]|
            88
          ',
                  'pattern' => '(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            [45]|
            8(?:
              00[1-9]|
              [1-49]
            )
          ',
                  'pattern' => '(\\d{4})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '7',
                  'pattern' => '(\\d{2})(\\d{2})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '8',
                  'pattern' => '(\\d{4})(\\d{3})(\\d{3})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            3[23589]|
            4[3-8]|
            6\\d|
            7[1-9]|
            88
          )\\d{5}
        ',
                'geographic' => '
          (?:
            3[23589]|
            4[3-8]|
            6\\d|
            7[1-9]|
            88
          )\\d{5}
        ',
                'mobile' => '
          (?:
            5\\d{5}|
            8(?:
              1(?:
                0(?:
                  0(?:
                    00|
                    [178]\\d
                  )|
                  [3-9]\\d\\d
                )|
                (?:
                  1(?:
                    0[2-6]|
                    1\\d
                  )|
                  (?:
                    2[0-59]|
                    [3-79]\\d
                  )\\d
                )\\d
              )|
              2(?:
                0(?:
                  0(?:
                    00|
                    4\\d
                  )|
                  (?:
                    19|
                    [2-7]\\d
                  )\\d
                )|
                (?:
                  (?:
                    [124-69]\\d|
                    3[5-9]
                  )\\d|
                  7(?:
                    [0-79]\\d|
                    8[13-9]
                  )|
                  8(?:
                    [2-6]\\d|
                    7[01]
                  )
                )\\d
              )|
              [349]\\d{4}
            )
          )\\d\\d|
          5(?:
            (?:
              [02]\\d|
              5[0-478]
            )\\d|
            1(?:
              [0-8]\\d|
              95
            )|
            6(?:
              4[0-4]|
              5[1-589]
            )
          )\\d{3}
        ',
                'pager' => '',
                'personal_number' => '70[0-2]\\d{5}',
                'specialrate' => '(
          (?:
            40\\d\\d|
            900
          )\\d{4}
        )',
                'toll_free' => '
          800(?:
            (?:
              0\\d\\d|
              1
            )\\d|
            [2-9]
          )\\d{3}
        ',
                'voip' => ''
              };
my $timezones = {
               '' => [
                       'Europe/Bucharest'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+372|\D)//g;
      my $self = bless({ country_code => '372', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
        return $self->is_valid() ? $self : undef;
    }
1;