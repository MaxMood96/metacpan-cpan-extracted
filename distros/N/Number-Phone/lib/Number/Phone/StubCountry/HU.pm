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
package Number::Phone::StubCountry::HU;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '1',
                  'national_rule' => '(06 $1)',
                  'pattern' => '(\\d)(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            [27][2-9]|
            3[2-7]|
            4[24-9]|
            5[2-79]|
            6|
            8[2-57-9]|
            9[2-69]
          ',
                  'national_rule' => '(06 $1)',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[2-9]',
                  'national_rule' => '06 $1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3,4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1\\d|
            [27][2-9]|
            3[2-7]|
            4[24-9]|
            5[2-79]|
            6[23689]|
            8[2-57-9]|
            9[2-69]
          )\\d{6}
        ',
                'geographic' => '
          (?:
            1\\d|
            [27][2-9]|
            3[2-7]|
            4[24-9]|
            5[2-79]|
            6[23689]|
            8[2-57-9]|
            9[2-69]
          )\\d{6}
        ',
                'mobile' => '
          (?:
            [257]0|
            3[01]
          )\\d{7}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(9[01]\\d{6})|(38\\d{7})',
                'toll_free' => '
          (?:
            [48]0\\d|
            680[29]
          )\\d{5}
        ',
                'voip' => '21\\d{7}'
              };
my %areanames = ();
$areanames{hu} = {"3674", "Szekszárd",
"3649", "Mezőkövesd",
"3632", "Salgótarján",
"3682", "Kaposvár",
"3669", "Mohács",
"3678", "Kiskőrös",
"3696", "Győr",
"3689", "Pápa",
"3642", "Nyíregyháza",
"3695", "Sárvár",
"3653", "Cegléd",
"3676", "Kecskemét",
"3688", "Veszprém",
"3625", "Dunaújváros",
"3645", "Kisvárda",
"3672", "Pécs",
"3628", "Gödöllő",
"3684", "Siófok",
"3654", "Berettyóújfalu",
"3668", "Orosháza",
"3634", "Tatabánya",
"3648", "Ózd",
"3637", "Gyöngyös",
"3657", "Jászberény",
"3673", "Szigetvár",
"3666", "Békéscsaba",
"3627", "Vác",};
$areanames{en} = {"3666", "Bekescsaba",
"3627", "Vac",
"3646", "Miskolc",
"3647", "Szerencs",
"3626", "Szentendre",
"3692", "Zalaegerszeg",
"3657", "Jaszbereny",
"3687", "Tapolca",
"3637", "Gyongyos",
"3636", "Eger",
"3656", "Szolnok",
"3673", "Szigetvar",
"3699", "Sopron",
"3672", "Pecs",
"3634", "Tatabanya",
"3668", "Oroshaza",
"3654", "Berettyoujfalu",
"3684", "Siofok",
"3648", "Ozd",
"3685", "Marcali",
"3635", "Balassagyarmat",
"3628", "Godollo",
"3679", "Baja",
"3693", "Nagykanizsa",
"3645", "Kisvarda",
"3624", "Szigetszentmiklós",
"3625", "Dunaujvaros",
"3688", "Veszprem",
"3644", "Mátészalka",
"3633", "Esztergom",
"3683", "Keszthely",
"3653", "Cegled",
"3677", "Kiskunhalas",
"3676", "Kecskemet",
"3623", "Biatorbágy",
"3663", "Szentes",
"3695", "Sarvar",
"3694", "Szombathely",
"3696", "Gyor",
"3678", "Kiskoros",
"3662", "Szeged",
"3642", "Nyiregyhaza",
"3659", "Karcag",
"3689", "Papa",
"3622", "Székesfehérvár",
"3674", "Szekszard",
"3675", "Paks",
"3629", "Monor",
"3652", "Debrecen",
"3682", "Kaposvar",
"3632", "Salgotarjan",
"3649", "Mezokovesd",
"361", "Budapest",
"3669", "Mohacs",};
my $timezones = {
               '' => [
                       'Europe/Budapest'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+36|\D)//g;
      my $self = bless({ country_code => '36', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:06)//;
      $self = bless({ country_code => '36', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;