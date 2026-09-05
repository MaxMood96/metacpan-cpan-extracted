# automatically generated file, don't edit



# Copyright 2026 David Cantrell, derived from data from libphonenumber
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
package Number::Phone::StubCountry::ZW;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101552;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            1|
            2(?:
              0[0-36-9]|
              29|
              58
            )|
            67[0-46-9]|
            (?:
              55|
              68
            )[0-69]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3,5})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            2(?:
              0[45]|
              [27]|
              48
            )|
            37|
            675|
            (?:
              55|
              68
            )[78]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3,5})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[49]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{3})(\\d{2,4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '80',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '548',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{3,5})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '29[013-9]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            [256]|
            39|
            8[13-59]
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{7})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '7',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '3',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '8',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{6})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            2(?:
              (?:
                (?:
                  02[014]|
                  72[03]
                )\\d|
                48
              )\\d|
              2(?:
                [278]\\d|
                92
              )|
              583
            )|
            (?:
              37[56]|
              6[78]21\\d
            )\\d|
            5(?:
              483|
              525\\d\\d
            )
          )\\d{3}|
          (?:
            2(?:
              0\\d|
              7[1-7]
            )|
            (?:
              55|
              6[78]
            )\\d
          )\\d{4}|
          (?:
            13|
            2(?:
              (?:
                42|
                9\\d
              )\\d|
              [56]20
            )|
            3(?:
              123|
              92\\d
            )|
            (?:
              4|
              542
            )\\d|
            6(?:
              [16]21|
              52[013]
            )|
            8(?:
              [1349]28|
              523
            )|
            9[2-9]
          )\\d{5}
        ',
                'geographic' => '
          (?:
            2(?:
              (?:
                (?:
                  02[014]|
                  72[03]
                )\\d|
                48
              )\\d|
              2(?:
                [278]\\d|
                92
              )|
              583
            )|
            (?:
              37[56]|
              6[78]21\\d
            )\\d|
            5(?:
              483|
              525\\d\\d
            )
          )\\d{3}|
          (?:
            2(?:
              0\\d|
              7[1-7]
            )|
            (?:
              55|
              6[78]
            )\\d
          )\\d{4}|
          (?:
            13|
            2(?:
              (?:
                42|
                9\\d
              )\\d|
              [56]20
            )|
            3(?:
              123|
              92\\d
            )|
            (?:
              4|
              542
            )\\d|
            6(?:
              [16]21|
              52[013]
            )|
            8(?:
              [1349]28|
              523
            )|
            9[2-9]
          )\\d{5}
        ',
                'mobile' => '
          7(?:
            [1278]\\d|
            3[1-9]|
            9[01]
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '
          80(?:
            [01]\\d|
            20|
            8[0-8]
          )\\d{3}
        ',
                'voip' => '
          86(?:
            1[12]|
            22|
            30|
            44|
            55|
            77|
            8[368]
          )\\d{6}
        '
              };
my %areanames = ();
$areanames{en} = {"263812847", "Binga",
"2636520", "Beatrice",
"263420108", "Norton",
"26329252", "Luveve",
"26325207", "Headlands",
"263542532", "Mvuma",
"263842808", "West\ Nicholson",
"263420109", "Norton",
"263275219", "Mazowe",
"2636523", "Marondera",
"26342722", "Chitungwiza",
"26327541", "Mt\.\ Darwin",
"263558", "Nkayi",
"26365208", "Wedza",
"26339234", "Jerera",
"263557", "Munyati",
"263392", "Masvingo",
"2638128", "Baobab\/Hwange",
"263271", "Bindura",
"26327524", "Mt\.\ Darwin",
"26361215", "Karoi",
"263548", "Lalapanzi",
"2636521", "Murewa",
"263542", "Gweru",
"263552557", "Munyati",
"26367215", "Murombedzi",
"263252055", "Nyazura",
"263312370", "Ngundu",
"2636821", "Kadoma\/Selous",
"26320200", "Odzi",
"26366213", "Banket",
"263943", "Mabutewni",
"26324215", "Norton",
"26339245", "Mashava",
"263612140", "Chirundu",
"26368216", "Sanyati",
"26367", "Chinhoyi",
"26339230", "Gutu",
"263947", "Bellevue",
"263392308", "Chatsworth",
"263248", "Birchenough\ Bridge",
"263948", "Nkulumane",
"263222", "Wedza",
"26329246", "Bellevue",
"263420087", "Selous",
"26327527", "Mt\.\ Darwin",
"2635525", "Battle\ Fields\/Kwekwe\/Redcliff",
"263292807", "Kezi",
"263652080", "Macheke",
"263420110", "Norton",
"263942", "Mabutewni",
"263228", "Hauna",
"263242", "Harare",
"263227", "Chipinge",
"263272317", "Checheche",
"263420106", "Norton",
"26327522", "Mt\.\ Darwin",
"263920", "Northend",
"26366219", "Christon\ Bank\/Concession\/Mazowe",
"26339235", "Zvishavane",
"263682189", "Chakari",
"263940", "Mabutewni",
"263274", "Arcturus",
"26383", "Victoria\ Falls",
"263292804", "Figtree",
"263392323", "Nyika",
"26367214", "Banket\/Mhangura",
"26366216", "Mvurwi",
"263242150", "Beatrice",
"26385", "BeitBridge",
"26354212", "Chivhu",
"26327525", "Mt\.\ Darwin",
"26366218", "Glendale",
"263952", "Luveve",
"263812835", "Dete",
"26324214", "Arcturus",
"26355259", "Gokwe",
"26342010", "Selous",
"263258", "Nyazura",
"26327540", "Mt\.\ Darwin",
"26365213", "Mutoko",
"26355", "Kwekwe",
"26327203", "Birchenough\ Bridge",
"263312337", "Rutenga",
"263292821", "Nyamandlovu",
"26366211", "Banket",
"263924", "Hillside",
"2639228", "Queensdale",
"2632620", "Chimanimani",
"263612141", "Makuti",
"26327526", "Mt\.\ Darwin",
"26324213", "Ruwa",
"263672198", "Raffingora",
"26327204", "Chipinge",
"26366215", "Banket",
"26327528", "Mt\.\ Darwin",
"263292800", "Esigodini",
"263392366", "Mataga",
"263277", "Mvurwi",
"26342723", "Chitungwiza",
"2632021", "Dangamvura",
"263842801", "Filabusi",
"263272", "Mutoko",
"26326208", "Juliasdale",
"2632753", "Mt\.\ Darwin",
"26354252", "Shurugwi",
"263272046", "Chipangayi",
"263687", "Sanyati",
"263688", "Chakari",
"263375", "Concession",
"26366217", "Guruve",
"263376", "Glendale",
"263842835", "Collen\ Bawn",
"263205", "Pengalonga",
"263292861", "Tsholotsho",
"263206", "Mutare",
"2633123", "Chiredzi",
"263542548", "Lalapanzi",
"26366212", "Mount\ Darwin",
"263292809", "Matopos",
"263420088", "Selous",
"26389280", "Plumtree",
"26327529", "Mt\.\ Darwin",
"26326209", "Hauna",
"263662137", "Shamva",
"263420089", "Selous",
"263672136", "Trelawney",
"2632020", "Mutare",
"26366214", "Banket",
"26327205", "Chimanimani",
"2636121", "Kariba",
"263262098", "Nyanga",
"26325206", "Murambinda",
"2631", "Victoria\ Falls",
"2632024", "Penhalonga",
"2639226", "Queensdale",
"263204", "Odzi",
"26368", "Kadoma",
"2632520", "Rusape",
"263292803", "Turkmine",
"2634", "Harare",
"263420085", "Selous",
"263672192", "Darwendale",
"26327523", "Mt\.\ Darwin",
"2632421", "Chitungwiza",
"26368215", "Chegutu",
"26342728", "Marondera",
"263672196", "Mutorashanga",
"263956", "Luveve",
"263552558", "Nkayi",
"263420086", "Selous",
"263946", "Bellevue",
"26366210", "Bindura\/Centenary",
"263273", "Ruwa",
"263292802", "Shangani",
"26329", "Bulawayo",
"263812856", "Lupane",
"26342009", "Selous",
"263392360", "Mberengwa",
"263812875", "Jotsholo",
"26342729", "Marondera",
"263941", "Mabutewni",
"263229", "Juliasdale",
"26331233", "Triangle",
"263929", "Killarney",
"2639", "Bulawayo",
"263420107", "Norton",
"263675", "Murombedzi",
"263392380", "Nyaningwe",
"263949", "Nkulumane",
"263921", "Northend",
"2638428", "Gwanda",};
my $timezones = {
               '' => [
                       'Africa/Harare'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+263|\D)//g;
      my $self = bless({ country_code => '263', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '263', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;