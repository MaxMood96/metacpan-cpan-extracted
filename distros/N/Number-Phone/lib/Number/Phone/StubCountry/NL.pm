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
package Number::Phone::StubCountry::NL;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135858;

my $formatters = [
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '
            1[238]|
            [34]
          ',
                  'pattern' => '(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'intl_format' => 'NA',
                  'leading_digits' => '14',
                  'pattern' => '(\\d{2})(\\d{3,4})'
                },
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '1',
                  'pattern' => '(\\d{6})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[89]0',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{4,7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '66',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '6',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{8})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            1[16-8]|
            2[259]|
            3[124]|
            4[17-9]|
            5[124679]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            [1-578]|
            91
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '9',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{5})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1(?:
              [035]\\d|
              1[13-578]|
              6[124-8]|
              7[24]|
              8[0-467]
            )|
            2(?:
              [0346]\\d|
              2[2-46-9]|
              5[125]|
              9[479]
            )|
            3(?:
              [03568]\\d|
              1[3-8]|
              2[01]|
              4[1-8]
            )|
            4(?:
              [0356]\\d|
              1[1-368]|
              7[58]|
              8[15-8]|
              9[23579]
            )|
            5(?:
              [0358]\\d|
              [19][1-9]|
              2[1-57-9]|
              4[13-8]|
              6[126]|
              7[0-3578]
            )|
            7\\d\\d
          )\\d{6}
        ',
                'geographic' => '
          (?:
            1(?:
              [035]\\d|
              1[13-578]|
              6[124-8]|
              7[24]|
              8[0-467]
            )|
            2(?:
              [0346]\\d|
              2[2-46-9]|
              5[125]|
              9[479]
            )|
            3(?:
              [03568]\\d|
              1[3-8]|
              2[01]|
              4[1-8]
            )|
            4(?:
              [0356]\\d|
              1[1-368]|
              7[58]|
              8[15-8]|
              9[23579]
            )|
            5(?:
              [0358]\\d|
              [19][1-9]|
              2[1-57-9]|
              4[13-8]|
              6[126]|
              7[0-3578]
            )|
            7\\d\\d
          )\\d{6}
        ',
                'mobile' => '
          (?:
            6[1-58]|
            970\\d
          )\\d{7}
        ',
                'pager' => '66\\d{7}',
                'personal_number' => '',
                'specialrate' => '(90[069]\\d{4,7})|(
          140(?:
            1[035]|
            2[0346]|
            3[03568]|
            4[0356]|
            5[0358]|
            8[458]
          )|
          (?:
            140(?:
              1[16-8]|
              2[259]|
              3[124]|
              4[17-9]|
              5[124679]|
              7
            )|
            8[478]\\d{6}
          )\\d
        )',
                'toll_free' => '800\\d{4,7}',
                'voip' => '
          (?:
            85|
            91
          )\\d{7}
        '
              };
my %areanames = ();
$areanames{en} = {"3135", "Hilversum",
"31548", "Rijssen",
"31570", "Deventer",
"31593", "Beilen",
"31294", "Weesp",
"31183", "Gorinchem",
"31524", "Coevorden",
"31518", "St\.\ Annaparochie",
"31223", "Den\ Helder",
"31481", "Bemmel",
"3172", "Alkmaar",
"31485", "Cuyk",
"31345", "Culemborg",
"31341", "Harderwijk",
"31315", "Terborg",
"31117", "Oostburg",
"31418", "Zaltbommel",
"31594", "Zuidhorn",
"3138", "Zwolle",
"31224", "Schagen",
"31493", "Deurne",
"3124", "Nijmegen",
"31523", "Hardenberg",
"31184", "Sliedrecht",
"3179", "Zoetermeer",
"31255", "IJmuiden",
"31251", "Beverwijk",
"31172", "Alphen\ aan\ den\ Rijn",
"31478", "Venray",
"3173", "\'s\-Hertogenbosch",
"31561", "Wolvega",
"31578", "Epe",
"31519", "Dokkum",
"3136", "Almere",
"31164", "Bergen\ op\ Zoom",
"3110", "Rotterdam",
"31346", "Maarssen",
"31543", "Winterswijk",
"31598", "Veendam",
"31486", "Grave",
"31317", "Wageningen",
"31347", "Vianen",
"31487", "Druten",
"31513", "Heerenveen",
"31228", "Enkhuizen",
"31316", "Zevenaar",
"31342", "Barneveld",
"31413", "Uden",
"31544", "Lichtenvoorde",
"3115", "Delft",
"31528", "Hoogeveen",
"31514", "Lemmer",
"3171", "Leiden",
"3174", "Hengelo",
"31111", "Zierikzee",
"31252", "Nieuw\-Vennep",
"31321", "Dronten",
"31115", "Terneuzen",
"3177", "Venlo",
"31499", "Best",
"31529", "Dalfsen",
"31299", "Purmerend",
"3130", "Utrecht",
"3153", "Enschede",
"31168", "Zevenbergen",
"31562", "West\-Terschelling",
"3143", "Maastricht",
"31573", "Lochem",
"31229", "Horn",
"3123", "Haarlem",
"31566", "Grou",
"31180", "Barendrecht",
"31599", "Stadskanaal",
"31348", "Woerden",
"3155", "Apeldoorn",
"31187", "Middelharnis",
"31488", "Zetten",
"31596", "Delfzijl",
"31227", "Medemblik",
"31597", "Winschoten",
"31226", "Noord\ Scharwoude",
"31318", "Veenendaal",
"31186", "Oud\-Beijerland",
"31114", "Hulst",
"31592", "Assen",
"31541", "Oldenzaal",
"31545", "Eibergen",
"31511", "Veenwouden",
"31222", "Den\ Burg",
"31182", "Gouda",
"31515", "Sneek",
"31497", "Eersel",
"31527", "Emmeloord",
"3158", "Leeuwarden",
"31297", "Aalsmeer",
"31113", "Goes",
"3145", "Heerlen",
"31411", "Boxtel",
"31522", "Meppel",
"31492", "Helmond",
"31475", "Roermond",
"31162", "Oosterhout",
"3126", "Arnhem",
"31167", "Steenbergen",
"3146", "Sittard",
"31166", "Tholen",
"31575", "Zutphen",
"31571", "Twello",
"3170", "The\ Hague",
"31174", "Naaldwijk",
"3113", "Tilburg",
"31343", "Driebergen\-Rijsenburg",
"31546", "Almelo",
"31517", "Harlingen",
"31547", "Goor",
"31516", "Oosterwolde",
"31313", "Dieren",
"31591", "Emmen",
"3178", "Dordrecht",
"31595", "Warffum",
"31181", "Spijkenisse",
"31512", "Drachten",
"31416", "Waalwijk",
"31344", "Tiel",
"31314", "Doetinchem",
"31118", "Middelburg",
"31412", "Oss",
"3175", "Zaandam",
"31525", "Elburg",
"31521", "Steenwijk",
"31495", "Weert",
"3176", "Breda",
"31161", "Rijen",
"31165", "Roosendaal",
"3150", "Groningen",
"3133", "Amersfoort",
"31320", "Lelystad",
"31572", "Raalte",
"3140", "Eindhoven",
"31577", "Elspeet",
"3120", "Amsterdam",};
$areanames{nl} = {"3170", "Den\ Haag",
"31481", "Elst",
"31486", "Schaijk",
"31229", "Hoorn",};
my $timezones = {
               '' => [
                       'Europe/Amsterdam'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+31|\D)//g;
      my $self = bless({ country_code => '31', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '31', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;