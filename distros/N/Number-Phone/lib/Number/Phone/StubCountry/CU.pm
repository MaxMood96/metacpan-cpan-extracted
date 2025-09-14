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
package Number::Phone::StubCountry::CU;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            2[1-4]|
            [34]
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{4,6})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '7',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d)(\\d{6,7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[56]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '8',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{7})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            3[23]|
            4[89]
          )\\d{4,6}|
          (?:
            31|
            4[36]|
            8(?:
              0[25]|
              78
            )\\d
          )\\d{6}|
          (?:
            2[1-4]|
            4[1257]|
            7\\d
          )\\d{5,6}
        ',
                'geographic' => '
          (?:
            3[23]|
            4[89]
          )\\d{4,6}|
          (?:
            31|
            4[36]|
            8(?:
              0[25]|
              78
            )\\d
          )\\d{6}|
          (?:
            2[1-4]|
            4[1257]|
            7\\d
          )\\d{5,6}
        ',
                'mobile' => '
          (?:
            5\\d|
            6[2-4]
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(807\\d{7})',
                'toll_free' => '800\\d{7}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"5346", "Isle\ of\ Youth",
"5333", "Ciego\ de\ Ávila\ Province",
"5347", "Mayabeque\ and\ Artemisa",
"5342", "Villa\ Clara\ Province",
"5348", "Pinar\ del\ Río\ Province",
"5322", "Santiago\ de\ Cuba\ Province",
"5331", "Las\ Tunas\ Province",
"5323", "Granma\ Province",
"5343", "Cienfuegos\ Province",
"537", "Havana\ City",
"5324", "Holguín\ Province",
"5345", "Matanzas\ Province",
"5341", "Sancti\ Spíritus\ Province",
"5349", "Artemisa\ Province",
"5321", "Guantánamo\ Province",
"5332", "Camagüey\ Province",};
my $timezones = {
               '' => [
                       'America/Havana'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+53|\D)//g;
      my $self = bless({ country_code => '53', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '53', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;