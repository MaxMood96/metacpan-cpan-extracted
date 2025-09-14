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
package Number::Phone::StubCountry::RS;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135859;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            (?:
              2[389]|
              39
            )0|
            [7-9]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3,9})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[1-36]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{5,10})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            11[1-9]\\d|
            (?:
              2[389]|
              39
            )(?:
              0[2-9]|
              [2-9]\\d
            )
          )\\d{3,8}|
          (?:
            1[02-9]|
            2[0-24-7]|
            3[0-8]
          )[2-9]\\d{4,9}
        ',
                'geographic' => '
          (?:
            11[1-9]\\d|
            (?:
              2[389]|
              39
            )(?:
              0[2-9]|
              [2-9]\\d
            )
          )\\d{3,8}|
          (?:
            1[02-9]|
            2[0-24-7]|
            3[0-8]
          )[2-9]\\d{4,9}
        ',
                'mobile' => '
          6(?:
            [0-689]|
            7\\d
          )\\d{6,7}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(
          (?:
            78\\d|
            90[0169]
          )\\d{3,7}
        )|(7[06]\\d{4,10})',
                'toll_free' => '800\\d{3,9}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"38137", "Krusevac",
"38120", "Novi\ Pazar",
"38133", "Prijepolje",
"38138", "Pristina",
"38129", "Prizren",
"38136", "Kraljevo",
"38131", "Uzice",
"381390", "Dakovica",
"381280", "Gnjilane",
"381230", "Kikinda",
"38135", "Jagodina",
"38132", "Cacak",
"38110", "Pirot",
"38119", "Zajecar",
"38134", "Kragujevac",
"38111", "Belgrade",
"38115", "Sabac",
"38112", "Pozarevac",
"38113", "Pancevo",
"38124", "Subotica",
"38116", "Leskovac",
"38118", "Nis",
"38117", "Vranje",
"38125", "Sombor",
"38122", "Sremska\ Mitrovica",
"38121", "Novi\ Sad",
"381290", "Urosevac",
"38139", "Pec",
"38128", "Kosovska\ Mitrovica",
"38126", "Smederevo",
"38123", "Zrenjanin",
"38114", "Valjevo",
"38127", "Prokuplje",
"38130", "Bor",};
$areanames{sr} = {"381280", "Гњилане",
"381390", "Ђаковица",
"38131", "Ужице",
"38132", "Чачак",
"38135", "Јагодина",
"381230", "Кикинда",
"38133", "Пријепоље",
"38138", "Приштина",
"38129", "Призрен",
"38136", "Краљево",
"38137", "Крушевац",
"38120", "Нови\ Пазар",
"38119", "Зајечар",
"38134", "Крагујевац",
"38110", "Пирот",
"38117", "Врање",
"38124", "Суботица",
"38113", "Панчево",
"38116", "Лесковац",
"38118", "Ниш",
"38111", "Београд",
"38115", "Шабац",
"38112", "Пожаревац",
"38127", "Прокупље",
"38130", "Бор",
"38139", "Пећ",
"38126", "Смедерево",
"38128", "Косовска\ Митровица",
"38123", "Зрењанин",
"38114", "Ваљево",
"38125", "Сомбор",
"38122", "Сремска\ Митровица",
"381290", "Урошевац",
"38121", "Нови\ Сад",};
my $timezones = {
               '' => [
                       'Europe/Belgrade'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+381|\D)//g;
      my $self = bless({ country_code => '381', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '381', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;