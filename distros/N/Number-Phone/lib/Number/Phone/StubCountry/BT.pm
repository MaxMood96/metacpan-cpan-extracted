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
package Number::Phone::StubCountry::BT;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135855;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'intl_format' => 'NA',
                  'leading_digits' => '[2-7]',
                  'pattern' => '(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            [2-6]|
            7[246]|
            8[2-4]
          ',
                  'pattern' => '(\\d)(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '
            1[67]|
            [78]
          ',
                  'pattern' => '(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            2[3-6]|
            [34][5-7]|
            5[236]|
            6[2-46]|
            7[246]|
            8[2-4]
          )\\d{5}
        ',
                'geographic' => '
          (?:
            2[3-6]|
            [34][5-7]|
            5[236]|
            6[2-46]|
            7[246]|
            8[2-4]
          )\\d{5}
        ',
                'mobile' => '
          (?:
            1[67]|
            [78]7
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"9753", "Trongsa",
"97582", "Paro",
"97574", "Samdrup\ Jongkhar",
"9756", "Gelephu",
"97576", "Samdrup\ Jongkhar",
"9754", "Trashigang",
"97584", "Paro",
"97583", "Paro",
"97572", "Samdrup\ Jongkhar",
"9752", "Thimphu",
"9755", "Phuentsholing",};
my $timezones = {
               '' => [
                       'Asia/Thimphu'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+975|\D)//g;
      my $self = bless({ country_code => '975', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;