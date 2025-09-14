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
package Number::Phone::StubCountry::MR;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '[2-48]',
                  'pattern' => '(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            25[08]|
            35\\d|
            45[1-7]
          )\\d{5}
        ',
                'geographic' => '
          (?:
            25[08]|
            35\\d|
            45[1-7]
          )\\d{5}
        ',
                'mobile' => '[2-4][0-46-9]\\d{6}',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '800\\d{5}',
                'voip' => ''
              };
my %areanames = ();
$areanames{fr} = {"2224515", "Aîoun",};
$areanames{en} = {"2224563", "Kiffa",
"2224569", "Rosso\/Tidjikja",
"2224537", "Aleg",
"2224513", "Néma",
"2224574", "Nouadhibou",
"2224550", "Boghé",
"2224533", "Kaédi",
"2224534", "Sélibaby",
"2224546", "Atar",
"2224515", "Aioun",
"22245", "Nouakchott",
"2224544", "Zouérat",};
my $timezones = {
               '' => [
                       'Africa/Nouakchott'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+222|\D)//g;
      my $self = bless({ country_code => '222', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;