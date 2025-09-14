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
package Number::Phone::StubCountry::MF;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [];

my $validators = {
                'fixed_line' => '
          590(?:
            0[079]|
            [14]3|
            [27][79]|
            3[03-7]|
            5[0-268]|
            87
          )\\d{4}
        ',
                'geographic' => '
          590(?:
            0[079]|
            [14]3|
            [27][79]|
            3[03-7]|
            5[0-268]|
            87
          )\\d{4}
        ',
                'mobile' => '
          (?:
            69(?:
              0\\d\\d|
              1(?:
                2[2-9]|
                3[0-5]
              )|
              4(?:
                0[89]|
                1[2-6]|
                9\\d
              )|
              6(?:
                1[016-9]|
                5[0-4]|
                [67]\\d
              )
            )|
            7090[0-4]
          )\\d{4}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '80[0-5]\\d{6}',
                'voip' => '
          9(?:
            (?:
              39[5-7]|
              76[018]
            )\\d|
            475[0-6]
          )\\d{4}
        '
              };
my $timezones = {
               '' => [
                       'America/Guadeloupe'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+590|\D)//g;
      my $self = bless({ country_code => '590', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '590', number => $number, formatters => $formatters, validators => $validators, }, $class);
      return $self->is_valid() ? $self : undef;
    }
1;