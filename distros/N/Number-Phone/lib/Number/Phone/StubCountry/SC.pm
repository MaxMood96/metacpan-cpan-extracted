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
package Number::Phone::StubCountry::SC;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135859;

my $formatters = [
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            [246]|
            9[57]
          ',
                  'pattern' => '(\\d)(\\d{3})(\\d{3})'
                }
              ];

my $validators = {
                'fixed_line' => '4[2-46]\\d{5}',
                'geographic' => '4[2-46]\\d{5}',
                'mobile' => '2[125-8]\\d{5}',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(85\\d{5})',
                'toll_free' => '800[08]\\d{3}',
                'voip' => '
          971\\d{4}|
          (?:
            64|
            95
          )\\d{5}
        '
              };
my $timezones = {
               '' => [
                       'Indian/Mahe'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+248|\D)//g;
      my $self = bless({ country_code => '248', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, }, $class);
        return $self->is_valid() ? $self : undef;
    }
1;