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
package Number::Phone::StubCountry::MD;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[89]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{5})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            22|
            3
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[25-7]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{3})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            (?:
              2[1-9]|
              3[1-79]
            )\\d|
            5(?:
              33|
              5[257]
            )
          )\\d{5}
        ',
                'geographic' => '
          (?:
            (?:
              2[1-9]|
              3[1-79]
            )\\d|
            5(?:
              33|
              5[257]
            )
          )\\d{5}
        ',
                'mobile' => '
          562\\d{5}|
          (?:
            6\\d|
            7[16-9]
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(808\\d{5})|(90[056]\\d{5})|(803\\d{5})',
                'toll_free' => '800\\d{5}',
                'voip' => '3[08]\\d{6}'
              };
my %areanames = ();
$areanames{ru} = {"373297", "Басарабяска",
"373244", "Кэлэрашь",
"37353", "Тираспол",
"373264", "Ниспорень",
"373258", "Теленешть",
"373236", "Унгень",
"373215", "Дубэсарь",
"373231", "Бэлць",
"373298", "Комрат",
"373269", "Хынчешть",
"373293", "Вулкэнешть",
"373271", "Окница",
"373252", "Дрокия",
"373230", "Сорока",
"373246", "Единец",
"373241", "Чимишлия",
"373249", "Глодень",
"373248", "Криулень",
"373243", "Кэушень",
"37322", "Кишинэу",
"373299", "Кагул",
"373263", "Леова",
"373268", "Яловень",
"373254", "Резина",
"373273", "Кантемир",
"373291", "Чадыр\-Лунга",
"373552", "Бендер",
"373251", "Дондушень",
"373294", "Тараклия",
"373259", "Фэлешть",
"373247", "Бричень",
"373219", "Днестровск",
"373235", "Орхей",
"373242", "Штефан\ Водэ",
"373265", "Анений\ Ной",
"373256", "Рышкань",
"373216", "Каменка",
"373557", "Слобозия",
"373555", "Рыбница",
"373237", "Стрэшень",
"373250", "Флорешть",
"373262", "Сынжерей",
"373210", "Григориополь",
"373272", "Шолдэнешть",};
$areanames{ro} = {"373241", "Cimişlia",
"373293", "Vulcăneşti",
"373269", "Hînceşti",
"373231", "Bălţi",
"373215", "Dubăsari",
"373258", "Teleneşti",
"373244", "Călăraşi",
"373272", "Şoldăneşti",
"373262", "Sîngerei",
"373250", "Floreşti",
"373237", "Străşeni",
"373555", "Rîbniţa",
"373256", "Rîşcani",
"373242", "Ştefan\ Vodă",
"373259", "Făleşti",
"373251", "Donduşeni",
"373291", "Ceadîr\ Lunga",
"37322", "Chişinău",
"373243", "Căuşeni",};
$areanames{en} = {"37353", "Tiraspol",
"373264", "Nisporeni",
"373258", "Telenesti",
"373297", "Basarabeasca",
"373244", "Calarasi",
"373252", "Drochia",
"373230", "Soroca",
"373246", "Edineţ",
"373249", "Glodeni",
"373241", "Cimislia",
"373236", "Ungheni",
"373215", "Dubasari",
"373298", "Comrat",
"373271", "Ocniţa",
"373293", "Vulcanesti",
"373269", "Hincesti",
"373231", "Balţi",
"373291", "Ceadir\ Lunga",
"373273", "Cantemir",
"373299", "Cahul",
"373263", "Leova",
"373268", "Ialoveni",
"373254", "Rezina",
"373248", "Criuleni",
"373243", "Causeni",
"37322", "Chisinau",
"373237", "Straseni",
"373555", "Ribnita",
"373272", "Soldanesti",
"373262", "Singerei",
"373250", "Floresti",
"373210", "Grigoriopol",
"373294", "Taraclia",
"373259", "Falesti",
"373247", "Briceni",
"373219", "Dnestrovsk",
"373552", "Bender",
"373251", "Donduseni",
"373557", "Slobozia",
"373235", "Orhei",
"373242", "Stefan\ Voda",
"373265", "Anenii\ Noi",
"373256", "Riscani",
"373216", "Camenca",};
my $timezones = {
               '' => [
                       'Europe/Chisinau'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+373|\D)//g;
      my $self = bless({ country_code => '373', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '373', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;