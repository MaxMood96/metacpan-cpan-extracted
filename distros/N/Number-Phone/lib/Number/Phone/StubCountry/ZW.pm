# automatically generated file, don't edit



# Copyright 2024 David Cantrell, derived from data from libphonenumber
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
our $VERSION = 1.20241212130807;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            2(?:
              0[45]|
              2[278]|
              [49]8
            )|
            3(?:
              [09]8|
              17
            )|
            6(?:
              [29]8|
              37|
              75
            )|
            [23][78]|
            (?:
              33|
              5[15]|
              6[68]
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
                  'leading_digits' => '
            2(?:
              02[014]|
              4|
              [56]20|
              [79]2
            )|
            392|
            5(?:
              42|
              525
            )|
            6(?:
              [16-8]21|
              52[013]
            )|
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
                  'leading_digits' => '
            2(?:
              1[39]|
              2[0157]|
              [378]|
              [56][14]
            )|
            3(?:
              123|
              29
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '8',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{6})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            1|
            2(?:
              0[0-36-9]|
              12|
              29|
              [56]
            )|
            3(?:
              1[0-689]|
              [24-6]
            )|
            5(?:
              [0236-9]|
              1[2-4]
            )|
            6(?:
              [013-59]|
              7[0-46-9]
            )|
            (?:
              33|
              55|
              6[68]
            )[0-69]|
            (?:
              29|
              3[09]|
              62
            )[0-79]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3,5})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            29[013-9]|
            39|
            54
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            258|
            5483
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{3,5})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1(?:
              (?:
                3\\d|
                9
              )\\d|
              [4-8]
            )|
            2(?:
              (?:
                (?:
                  0(?:
                    2[014]|
                    5
                  )|
                  (?:
                    2[0157]|
                    31|
                    84|
                    9
                  )\\d\\d|
                  [56](?:
                    [14]\\d\\d|
                    20
                  )|
                  7(?:
                    [089]|
                    2[03]|
                    [35]\\d\\d
                  )
                )\\d|
                4(?:
                  2\\d\\d|
                  8
                )
              )\\d|
              1(?:
                2|
                [39]\\d{4}
              )
            )|
            3(?:
              (?:
                123|
                (?:
                  29\\d|
                  92
                )\\d
              )\\d\\d|
              7(?:
                [19]|
                [56]\\d
              )
            )|
            5(?:
              0|
              1[2-478]|
              26|
              [37]2|
              4(?:
                2\\d{3}|
                83
              )|
              5(?:
                25\\d\\d|
                [78]
              )|
              [689]\\d
            )|
            6(?:
              (?:
                [16-8]21|
                28|
                52[013]
              )\\d\\d|
              [39]
            )|
            8(?:
              [1349]28|
              523
            )\\d\\d
          )\\d{3}|
          (?:
            4\\d\\d|
            9[2-9]
          )\\d{4,5}|
          (?:
            (?:
              2(?:
                (?:
                  (?:
                    0|
                    8[146]
                  )\\d|
                  7[1-7]
                )\\d|
                2(?:
                  [278]\\d|
                  92
                )|
                58(?:
                  2\\d|
                  3
                )
              )|
              3(?:
                [26]|
                9\\d{3}
              )|
              5(?:
                4\\d|
                5
              )\\d\\d
            )\\d|
            6(?:
              (?:
                (?:
                  [0-246]|
                  [78]\\d
                )\\d|
                37
              )\\d|
              5[2-8]
            )
          )\\d\\d|
          (?:
            2(?:
              [569]\\d|
              8[2-57-9]
            )|
            3(?:
              [013-59]\\d|
              8[37]
            )|
            6[89]8
          )\\d{3}
        ',
                'geographic' => '
          (?:
            1(?:
              (?:
                3\\d|
                9
              )\\d|
              [4-8]
            )|
            2(?:
              (?:
                (?:
                  0(?:
                    2[014]|
                    5
                  )|
                  (?:
                    2[0157]|
                    31|
                    84|
                    9
                  )\\d\\d|
                  [56](?:
                    [14]\\d\\d|
                    20
                  )|
                  7(?:
                    [089]|
                    2[03]|
                    [35]\\d\\d
                  )
                )\\d|
                4(?:
                  2\\d\\d|
                  8
                )
              )\\d|
              1(?:
                2|
                [39]\\d{4}
              )
            )|
            3(?:
              (?:
                123|
                (?:
                  29\\d|
                  92
                )\\d
              )\\d\\d|
              7(?:
                [19]|
                [56]\\d
              )
            )|
            5(?:
              0|
              1[2-478]|
              26|
              [37]2|
              4(?:
                2\\d{3}|
                83
              )|
              5(?:
                25\\d\\d|
                [78]
              )|
              [689]\\d
            )|
            6(?:
              (?:
                [16-8]21|
                28|
                52[013]
              )\\d\\d|
              [39]
            )|
            8(?:
              [1349]28|
              523
            )\\d\\d
          )\\d{3}|
          (?:
            4\\d\\d|
            9[2-9]
          )\\d{4,5}|
          (?:
            (?:
              2(?:
                (?:
                  (?:
                    0|
                    8[146]
                  )\\d|
                  7[1-7]
                )\\d|
                2(?:
                  [278]\\d|
                  92
                )|
                58(?:
                  2\\d|
                  3
                )
              )|
              3(?:
                [26]|
                9\\d{3}
              )|
              5(?:
                4\\d|
                5
              )\\d\\d
            )\\d|
            6(?:
              (?:
                (?:
                  [0-246]|
                  [78]\\d
                )\\d|
                37
              )\\d|
              5[2-8]
            )
          )\\d\\d|
          (?:
            2(?:
              [569]\\d|
              8[2-57-9]
            )|
            3(?:
              [013-59]\\d|
              8[37]
            )|
            6[89]8
          )\\d{3}
        ',
                'mobile' => '
          7(?:
            [1278]\\d|
            3[1-9]
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
$areanames{en} = {"263812856", "Lupane",
"26316", "West\ Nicholson",
"26367215", "Murombedzi",
"263275219", "Mazowe",
"263612140", "Chirundu",
"263392380", "Nyaningwe",
"26327205", "Chimanimani",
"263947", "Bellevue",
"263672196", "Mutorashanga",
"263262098", "Nyanga",
"263292809", "Matopos",
"263929", "Killarney",
"263212", "Murambinda",
"26342723", "Chitungwiza",
"263672192", "Darwendale",
"263219", "Plumtree",
"263675", "Murombedzi",
"263272046", "Chipangayi",
"26336", "Ngundu",
"2634", "Harare",
"26342722", "Chitungwiza",
"26330", "Gutu",
"263542548", "Lalapanzi",
"263308", "Chatsworth",
"263392308", "Chatsworth",
"26342728", "Marondera",
"26331", "Chiredzi",
"26327204", "Chipinge",
"263292807", "Kezi",
"263949", "Nkulumane",
"26327526", "Mt\.\ Darwin",
"26357", "Centenary",
"263942", "Mabutewni",
"26353", "Chegutu",
"26327541", "Mt\.\ Darwin",
"263687", "Sanyati",
"26367214", "Banket\/Mhangura",
"2636821", "Kadoma\/Selous",
"26363", "Makuti",
"263513", "Zvishavane",
"26367", "Chinhoyi",
"263420086", "Selous",
"263812875", "Jotsholo",
"26365", "Beatrice",
"263292800", "Esigodini",
"263283", "Figtree",
"263242150", "Beatrice",
"26365208", "Wedza",
"26389280", "Plumtree",
"263558", "Nkayi",
"26366216", "Mvurwi",
"263682189", "Chakari",
"263842801", "Filabusi",
"2632021", "Dangamvura",
"26355", "Kwekwe",
"263662137", "Shamva",
"26327540", "Mt\.\ Darwin",
"263251", "Zvishavane",
"26318", "Dete",
"26314", "Rutenga",
"263512", "Zvishavane",
"26342010", "Selous",
"263227", "Chipinge",
"263943", "Mabutewni",
"263940", "Mabutewni",
"263672136", "Trelawney",
"263956", "Luveve",
"263392366", "Mataga",
"26334", "Jerera",
"2632582", "Headlands",
"26342729", "Marondera",
"26342009", "Selous",
"263289", "Jotsholo",
"263282", "Kezi",
"2635483", "Lalapanzi",
"263337", "Nyaningwe",
"263242", "Harare",
"263271", "Bindura",
"263272317", "Checheche",
"26327527", "Mt\.\ Darwin",
"2632020", "Mutare",
"263517", "Mataga",
"263274", "Arcturus",
"263292861", "Tsholotsho",
"263398", "Lupane",
"263312337", "Rutenga",
"26332", "Mvuma",
"263667", "Raffingora",
"26365213", "Mutoko",
"2636523", "Marondera",
"26339", "Masvingo",
"263292804", "Figtree",
"26325", "Rusape",
"263222", "Wedza",
"26355259", "Gokwe",
"263229", "Juliasdale",
"26319", "Plumtree",
"263278", "Murewa",
"2632421", "Chitungwiza",
"263420106", "Norton",
"26323", "Chiredzi",
"263213", "Victoria\ Falls",
"26368216", "Sanyati",
"263379", "Macheke",
"2639228", "Queensdale",
"26366217", "Guruve",
"263920", "Northend",
"26327203", "Birchenough\ Bridge",
"263254", "Gweru",
"263287", "Tsholotsho",
"26339230", "Gutu",
"263375", "Concession",
"26329246", "Bellevue",
"263668", "Mutorashanga",
"263292821", "Nyamandlovu",
"263420088", "Selous",
"263221", "Murambinda",
"26350", "Shanagani",
"26366", "Banket",
"263812847", "Binga",
"263518", "Mberengwa",
"263812835", "Dete",
"26356", "Chivhu",
"26325206", "Murambinda",
"26360", "Mhangura",
"263284", "Gwanda",
"26361", "Kariba",
"263420087", "Selous",
"26327529", "Mt\.\ Darwin",
"263206", "Mutare",
"26326209", "Hauna",
"2635525", "Battle\ Fields\/Kwekwe\/Redcliff",
"263842808", "West\ Nicholson",
"26324214", "Arcturus",
"26354212", "Chivhu",
"26327524", "Mt\.\ Darwin",
"263514", "Zvishavane",
"26366219", "Christon\ Bank\/Concession\/Mazowe",
"263225", "Rusape",
"263277", "Mvurwi",
"263371", "Shamva",
"263288", "Esigodini",
"263248", "Birchenough\ Bridge",
"263292803", "Turkmine",
"263292802", "Shangani",
"263220203", "Dangamvura",
"263220202", "Mutare",
"26361215", "Karoi",
"26335", "Mashava",
"263285", "Turkmine",
"263672198", "Raffingora",
"263420110", "Norton",
"263329", "Nyanga",
"26313", "Victoria\ Falls",
"26317", "Filabusi",
"263392323", "Nyika",
"2632024", "Penhalonga",
"263228", "Hauna",
"26329", "Bulawayo",
"263272", "Mutoko",
"26327525", "Mt\.\ Darwin",
"26329252", "Luveve",
"2639226", "Queensdale",
"263279", "Marondera",
"263612141", "Makuti",
"26324215", "Norton",
"263652080", "Macheke",
"26315", "Binga",
"263281", "Hwange",
"263387", "Nyamandhlovu",
"263338", "Nyika",
"263946", "Bellevue",
"2638428", "Gwanda",
"26333", "Triangle",
"2639", "Bulawayo",
"263420089", "Selous",
"263220201", "Chikanga\/Mutare",
"263552557", "Munyati",
"26364", "Karoi",
"26327522", "Mt\.\ Darwin",
"263688", "Chakari",
"263924", "Hillside",
"263286", "Beitbridge",
"26327528", "Mt\.\ Darwin",
"26368", "Kadoma",
"263204", "Odzi",
"26358", "Guruve",
"26325207", "Headlands",
"26327523", "Mt\.\ Darwin",
"263264", "Karoi",
"263842835", "Collen\ Bawn",
"263941", "Mabutewni",
"263552558", "Nkayi",
"263637", "Chirundu",
"26324213", "Ruwa",
"26354", "Gweru",
"26320200", "Odzi",
"263952", "Luveve",
"263420085", "Selous",
"26354252", "Shurugwi",
"263420107", "Norton",
"26339234", "Jerera",
"263252055", "Nyazura",
"26326208", "Juliasdale",
"263273", "Ruwa",
"2632753", "Mt\.\ Darwin",
"263270", "Chitungwiza",
"26366210", "Bindura\/Centenary",
"263420108", "Norton",
"26366212", "Mount\ Darwin",
"263312370", "Ngundu",
"26339245", "Mashava",
"263557", "Munyati",
"26366218", "Glendale",
"26326", "Chimanimani",
"2636521", "Murewa",
"263376", "Glendale",
"263948", "Nkulumane",
"26385", "BeitBridge",
"263392360", "Mberengwa",
"263420109", "Norton",
"26368215", "Chegutu",
"263205", "Pengalonga",
"26362", "Norton",
"26339235", "Zvishavane",
"263698", "Trelawney",
"2638128", "Baobab\/Hwange",
"26331233", "Triangle",
"26369", "Darwendale",
"263628", "Selous",
"263542532", "Mvuma",
"263261", "Kariba",
"26359", "Gokwe",
"263383", "Matopose",
"263921", "Northend",
"263317", "Checheche",
"26383", "Victoria\ Falls",
"26352", "Shurugwi",
"2632583", "Nyazura",};
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