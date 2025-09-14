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
package Number::Phone::StubCountry::BF;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135855;

my $formatters = [
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '[024-7]',
                  'pattern' => '(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          2(?:
            0(?:
              49|
              5[23]|
              6[5-7]|
              9[016-9]
            )|
            4(?:
              4[569]|
              5[4-6]|
              6[5-7]|
              7[0179]
            )|
            5(?:
              [34]\\d|
              50|
              6[5-7]
            )
          )\\d{4}
        ',
                'geographic' => '
          2(?:
            0(?:
              49|
              5[23]|
              6[5-7]|
              9[016-9]
            )|
            4(?:
              4[569]|
              5[4-6]|
              6[5-7]|
              7[0179]
            )|
            5(?:
              [34]\\d|
              50|
              6[5-7]
            )
          )\\d{4}
        ',
                'mobile' => '
          (?:
            0[1-7]|
            44|
            5[0-8]|
            [67]\\d
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"2262456", "Djibo",
"2262098", "Bobo\-Dioulasso",
"2262544", "Koudougou",
"2262099", "Béréba\/Fo\/Houndé",
"2262097", "Bobo\-Dioulasso",
"2262449", "Falagountou\/Dori",
"2262090", "Gaoua",
"2262455", "Ouahigouya",
"226254", "Ouagadougou",
"2262540", "Pô\/Kombissiri\/Koubri",
"2262091", "Banfora",
"226253", "Ouagadougou",
"2262541", "Léo\/Sapouy",
"2262477", "Fada\/Diabo",
"2262454", "Yako",
"2262470", "Pouytenga\/Koupéla",
"2262445", "Kaya",
"226204", "Kaya",
"2262096", "Orodara",
"2262471", "Tenkodogo",
"2262053", "Boromo\/Djibasso\/Nouna",
"2262052", "Dédougou",
"2262446", "Falagountou\/Dori",
"2262479", "Kantchari",};
my $timezones = {
               '' => [
                       'Africa/Ouagadougou'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+226|\D)//g;
      my $self = bless({ country_code => '226', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;