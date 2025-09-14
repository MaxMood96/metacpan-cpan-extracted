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
package Number::Phone::StubCountry::NP;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1-$2',
                  'leading_digits' => '1[2-6]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{7})'
                },
                {
                  'format' => '$1-$2',
                  'leading_digits' => '
            1[01]|
            [2-8]|
            9(?:
              [1-59]|
              [67][2-6]
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{6})'
                },
                {
                  'format' => '$1-$2',
                  'leading_digits' => '9',
                  'pattern' => '(\\d{3})(\\d{7})'
                },
                {
                  'format' => '$1-$2-$3',
                  'intl_format' => 'NA',
                  'leading_digits' => '1',
                  'pattern' => '(\\d{4})(\\d{2})(\\d{5})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1[0-6]\\d|
            99[02-6]
          )\\d{5}|
          (?:
            2[13-79]|
            3[135-8]|
            4[146-9]|
            5[135-7]|
            6[13-9]|
            7[15-9]|
            8[1-46-9]|
            9[1-7]
          )[2-6]\\d{5}
        ',
                'geographic' => '
          (?:
            1[0-6]\\d|
            99[02-6]
          )\\d{5}|
          (?:
            2[13-79]|
            3[135-8]|
            4[146-9]|
            5[135-7]|
            6[13-9]|
            7[15-9]|
            8[1-46-9]|
            9[1-7]
          )[2-6]\\d{5}
        ',
                'mobile' => '
          9(?:
            00|
            6[0-3]|
            7[0-24-6]|
            8[0-24-68]
          )\\d{7}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '
          1(?:
            66001|
            800\\d\\d
          )\\d{5}
        ',
                'voip' => ''
              };
my $timezones = {
               '' => [
                       'Asia/Katmandu'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+977|\D)//g;
      my $self = bless({ country_code => '977', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '977', number => $number, formatters => $formatters, validators => $validators, }, $class);
      return $self->is_valid() ? $self : undef;
    }
1;