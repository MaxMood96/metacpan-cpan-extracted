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
package Number::Phone::StubCountry::MO;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'pattern' => '(\\d{4})(\\d{3})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[268]',
                  'pattern' => '(\\d{4})(\\d{4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            28[2-9]|
            8(?:
              11|
              [2-57-9]\\d
            )
          )\\d{5}
        ',
                'geographic' => '
          (?:
            28[2-9]|
            8(?:
              11|
              [2-57-9]\\d
            )
          )\\d{5}
        ',
                'mobile' => '
          6800[0-79]\\d{3}|
          6(?:
            [235]\\d\\d|
            6(?:
              0[0-5]|
              [1-9]\\d
            )|
            8(?:
              0[1-9]|
              [14-8]\\d|
              2[5-9]|
              [39][0-4]
            )
          )\\d{4}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '0800\\d{3}',
                'voip' => ''
              };
my $timezones = {
               '' => [
                       'Asia/Shanghai'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+853|\D)//g;
      my $self = bless({ country_code => '853', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
        return $self->is_valid() ? $self : undef;
    }
1;