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
package Number::Phone::StubCountry::XK;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135859;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[89]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{5})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[2-4]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            2|
            39
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '3',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{7,10})'
                }
              ];

my $validators = {
                'fixed_line' => '
          38\\d{6,10}|
          (?:
            2[89]|
            39
          )(?:
            0\\d{5,6}|
            [1-9]\\d{5}
          )
        ',
                'geographic' => '
          38\\d{6,10}|
          (?:
            2[89]|
            39
          )(?:
            0\\d{5,6}|
            [1-9]\\d{5}
          )
        ',
                'mobile' => '4[3-9]\\d{6}',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(900\\d{5})',
                'toll_free' => '800\\d{5}',
                'voip' => ''
              };
my %areanames = ();
$areanames{sr} = {"383290", "Урошевац",
"38338", "Приштина",
"38329", "Призрен",
"38328", "Косовска\ Митровица",
"38339", "Пећ",
"383390", "Ђаковица",
"383280", "Гњилане",};
$areanames{en} = {"383390", "Gjakova",
"383280", "Gjilan",
"38339", "Peja",
"38328", "Mitrovica",
"38329", "Prizren",
"38338", "Prishtina",
"383290", "Ferizaj",};
$areanames{sq} = {"38328", "Mitrovicë",
"38339", "Pejë",
"383390", "Gjakovë",
"38338", "Prishtinë",};
my $timezones = {
               '' => [
                       'Europe/Belgrade'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+383|\D)//g;
      my $self = bless({ country_code => '383', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '383', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;