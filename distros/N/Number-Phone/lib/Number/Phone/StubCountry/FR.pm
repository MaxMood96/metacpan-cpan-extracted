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
package Number::Phone::StubCountry::FR;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '10',
                  'pattern' => '(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'intl_format' => 'NA',
                  'leading_digits' => '1',
                  'pattern' => '(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '8',
                  'national_rule' => '0 $1',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2 $3 $4 $5',
                  'leading_digits' => '[1-79]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            26[013-9]|
            59[1-35-9]
          )\\d{6}|
          (?:
            [13]\\d|
            2[0-57-9]|
            4[1-9]|
            5[0-8]
          )\\d{7}
        ',
                'geographic' => '
          (?:
            26[013-9]|
            59[1-35-9]
          )\\d{6}|
          (?:
            [13]\\d|
            2[0-57-9]|
            4[1-9]|
            5[0-8]
          )\\d{7}
        ',
                'mobile' => '
          (?:
            6(?:
              [0-24-8]\\d|
              3[0-8]|
              9[589]
            )|
            7[3-9]\\d
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(
          8(?:
            1[01]|
            2[0156]|
            4[024]|
            84
          )\\d{6}
        )|(
          836(?:
            0[0-36-9]|
            [1-9]\\d
          )\\d{4}|
          8(?:
            1[2-9]|
            2[2-47-9]|
            3[0-57-9]|
            [569]\\d|
            8[0-35-9]
          )\\d{6}
        )|(80[6-9]\\d{6})',
                'toll_free' => '80[0-5]\\d{6}',
                'voip' => '9\\d{8}'
              };
my $timezones = {
               '' => [
                       'Europe/Paris'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+33|\D)//g;
      my $self = bless({ country_code => '33', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '33', number => $number, formatters => $formatters, validators => $validators, }, $class);
      return $self->is_valid() ? $self : undef;
    }
1;