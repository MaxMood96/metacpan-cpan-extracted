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
package Number::Phone::StubCountry::FO;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1',
                  'leading_digits' => '[2-9]',
                  'pattern' => '(\\d{6})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            20|
            [34]\\d|
            8[19]
          )\\d{4}
        ',
                'geographic' => '
          (?:
            20|
            [34]\\d|
            8[19]
          )\\d{4}
        ',
                'mobile' => '
          (?:
            [27][1-9]|
            5\\d|
            9[16]
          )\\d{4}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(
          90(?:
            [13-5][15-7]|
            2[125-7]|
            9\\d
          )\\d\\d
        )',
                'toll_free' => '80[257-9]\\d{3}',
                'voip' => '
          (?:
            6[0-36]|
            88
          )\\d{4}
        '
              };
my $timezones = {
               '' => [
                       'Atlantic/Faeroe'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+298|\D)//g;
      my $self = bless({ country_code => '298', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:(10(?:01|[12]0|88)))//;
      $self = bless({ country_code => '298', number => $number, formatters => $formatters, validators => $validators, }, $class);
      return $self->is_valid() ? $self : undef;
    }
1;