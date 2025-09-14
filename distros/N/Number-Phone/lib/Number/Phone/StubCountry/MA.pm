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
package Number::Phone::StubCountry::MA;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '5[45]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1-$2',
                  'leading_digits' => '
            5(?:
              2[2-46-9]|
              3[3-9]|
              9
            )|
            8(?:
              0[89]|
              92
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{5})'
                },
                {
                  'format' => '$1-$2',
                  'leading_digits' => '8',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{7})'
                },
                {
                  'format' => '$1-$2',
                  'leading_digits' => '[5-7]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{6})'
                }
              ];

my $validators = {
                'fixed_line' => '
          5(?:
            2(?:
              [0-25-79]\\d|
              3[1-578]|
              4[02-46-8]|
              8[0235-7]
            )|
            3(?:
              [0-47]\\d|
              5[02-9]|
              6[02-8]|
              8[014-9]|
              9[3-9]
            )|
            (?:
              4[067]|
              5[03]
            )\\d
          )\\d{5}
        ',
                'geographic' => '
          5(?:
            2(?:
              [0-25-79]\\d|
              3[1-578]|
              4[02-46-8]|
              8[0235-7]
            )|
            3(?:
              [0-47]\\d|
              5[02-9]|
              6[02-8]|
              8[014-9]|
              9[3-9]
            )|
            (?:
              4[067]|
              5[03]
            )\\d
          )\\d{5}
        ',
                'mobile' => '
          (?:
            6(?:
              [0-79]\\d|
              8[0-247-9]
            )|
            7(?:
              [0167]\\d|
              2[0-8]|
              5[0-5]|
              8[0-7]
            )
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(89\\d{7})',
                'toll_free' => '80[0-7]\\d{6}',
                'voip' => '
          (?:
            592(?:
              4[0-2]|
              93
            )|
            80[89]\\d\\d
          )\\d{4}
        '
              };
my %areanames = ();
$areanames{en} = {"2125223", "Casablanca",
"2125389", "Fez\/Meknes",
"2125384", "Tangier",
"2125373", "Kénitra",
"2125355", "Meknès",
"2125234", "Settai",
"2125248", "Ouarzazate",
"2125289", "Dakhla\/Laayoune",
"2125362", "Berkane",
"2125381", "Rabat",
"2125237", "Settat",
"2125287", "Guelmim\/Tan\ Tan",
"2125225", "Casablanca",
"2125366", "Figuig\/Oujda",
"2125296", "Marrakech",
"2125375", "Khémisset",
"2125380", "Rabat",
"2125387", "Fez\/Meknes",
"2125353", "Midelt",
"2125396", "Fnideq\/Martil\/Mdiq",
"2125374", "Ouazzane",
"2125379", "Souk\ Larbaa",
"2125246", "El\ Youssoufia\/Safi",
"2125357", "Goulmima",
"2125242", "El\ Kelaa\ des\ Sraghna",
"2125229", "Casablanca",
"2125224", "Casablanca",
"2125283", "Inezgane\/Taroudant",
"2125233", "El\ Jedida\/Mohammedia",
"212525", "Southern\ Morocco",
"2125398", "Al\ Hoceima\/Chefchaouen",
"212532", "Fès\/Errachidia\/Meknès\/Nador\/Oujda\/Taza",
"2125385", "Tangier",
"2125285", "Oulad\ Teima\/Taroudant",
"2125235", "Oued\ Zem",
"2125220", "Casablanca",
"2125227", "Casablanca",
"2125298", "Marrakech",
"2125359", "Fès",
"2125368", "Figuig",
"2125354", "Meknès",
"2125377", "Rabat",
"2125222", "Casablanca",
"2125365", "Oujda",
"2125226", "Casablanca",
"2125372", "Rabat",
"2125244", "Marrakech",
"2125288", "Agadir\/Es\-Semara\/Tarfaya",
"2125376", "Rabat\/Témara",
"2125388", "Tangier",
"2125395", "Larache",
"2125363", "Nador",
"2125352", "Taza",
"2125247", "Essaouira",
"2125356", "Fès",
"2125393", "Tangier",
"2125243", "Marrakech",
"2125386", "Fez\/Meknes",
"212531", "Tangier\/Al\ Hoceima\/Larache\/Tètouan\/Chefchaouen",
"2125397", "Tétouan",
"212521", "Casablanca\/Central\ Morocco",
"2125378", "Salé",
"2125286", "Tiznit",
"2125367", "Bouarfa\/Oujda",
"2125232", "Mohammedia",
"2125282", "Agadir\/Ait\ Meloul\/Inezgane",
"2125297", "Agadir",
"212529", "Casablanca",
"2125228", "Casablanca",
"212520", "Casablanca",
"2125299", "Agadir",
"2125358", "Ifrane",
"2125394", "Asilah",
"2125399", "Al\ Hoceima\/Larache\/Tangier",
"212530", "Rabat\/Kènitra",};
$areanames{fr} = {"2125399", "Tanger\/Larache\/Al\ Hoceima",
"212530", "Rabat\/Kénitra",
"212521", "Casablanca\/Maroc\ Central",
"2125367", "Oujda\/Bouarfa",
"2125282", "Agadir\/Inezgane\/Ait\ Melou",
"2125386", "Fès\/Maknès",
"212531", "Tanger\/Tétouan\/Larache\/Al\ Hoceima\/Cherfchaouen",
"2125393", "Tanger",
"2125388", "Tanger",
"2125288", "Es\-Semara\/Agadir\/Tarfaya",
"2125285", "Taroudannt\/Oulad\ Teima",
"212532", "Fès\/Oujda\/Meknès\/Taza\/Nador\/Errachidia",
"2125385", "Tanger",
"2125283", "Inezgane\/Taroudannt",
"2125233", "Mohammedia\/El\ Jadida",
"212525", "Maroc\ Sud",
"2125246", "Safi\/El\ Youssoufia",
"2125387", "Fès\/Maknès",
"2125366", "Oujda\/Figuig",
"2125234", "Settat",
"2125289", "Laayoune\/Dakhla",
"2125389", "Fès\/Maknès",
"2125384", "Tanger",};
my $timezones = {
               '' => [
                       'Atlantic/Canary'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+212|\D)//g;
      my $self = bless({ country_code => '212', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '212', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;