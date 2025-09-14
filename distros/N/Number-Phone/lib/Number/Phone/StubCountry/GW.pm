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
package Number::Phone::StubCountry::GW;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '40',
                  'pattern' => '(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[49]',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                }
              ];

my $validators = {
                'fixed_line' => '443\\d{6}',
                'geographic' => '443\\d{6}',
                'mobile' => '
          9(?:
            5\\d|
            6[569]|
            77
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '',
                'voip' => '40\\d{5}'
              };
my %areanames = ();
$areanames{en} = {"24544334", "Mansaba",
"24544325", "Brá",
"24544394", "Bula",
"24544353", "Pirada",
"24544335", "Farim",
"24544332", "Bissora",
"24544320", "Bissau",
"24544341", "Bafatá",
"24544322", "St\.\ Luzia",
"24544391", "Canchungo",
"24544331", "Mansôa",
"24544342", "Bambadinca",
"24544321", "Bissau",
"24544392", "Cacheu",
"24544393", "S\.\ Domingos",
"24544370", "Buba",
"24544354", "Pitche",
"24544397", "Bigene",
"24544396", "Ingoré",
"24544352", "Sonaco",
"24544351", "Gabu",};
$areanames{pt} = {"245393", "S\.\ Domingos",
"245342", "Bambadinca",
"245331", "Mansôa",
"245335", "Farim",
"245392", "Cacheu",
"245394", "Bula",
"245321", "Bissau",
"245325", "Brá",
"245351", "Gabú",
"245396", "Ingoré",
"245332", "Bigene\/Bissorã",
"245353", "Pirada",
"245341", "Bafatá",
"245320", "Bissau",
"245334", "Mansaba",
"245370", "Buba",
"245391", "Canchungo",
"245354", "Pitche",
"245322", "Sta\.\ Luzia",
"245352", "Sonaco",};
my $timezones = {
               '' => [
                       'Atlantic/Reykjavik'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+245|\D)//g;
      my $self = bless({ country_code => '245', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;