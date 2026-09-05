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
package Number::Phone::StubCountry::IE;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101550;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            2[24-9]|
            47|
            58|
            6[237-9]|
            9[35-9]
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{5})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '[45]0',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{3})(\\d{5})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '1',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d)(\\d{3,4})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            [2569]|
            4[1-69]|
            7[14]
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '70',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '81',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[78]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '1',
                  'pattern' => '(\\d{4})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '4',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{4})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '8',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d)(\\d{3})(\\d{4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1\\d|
            21
          )\\d{6,7}|
          (?:
            2[24-9]|
            4(?:
              0[24]|
              5\\d|
              7
            )|
            5(?:
              0[45]|
              1\\d|
              8
            )|
            6(?:
              1\\d|
              [237-9]
            )|
            9(?:
              1\\d|
              [35-9]
            )
          )\\d{5}|
          (?:
            23|
            4(?:
              [1-469]|
              8\\d
            )|
            5[23679]|
            6[4-6]|
            7[14]|
            9[04]
          )\\d{7}
        ',
                'geographic' => '
          (?:
            1\\d|
            21
          )\\d{6,7}|
          (?:
            2[24-9]|
            4(?:
              0[24]|
              5\\d|
              7
            )|
            5(?:
              0[45]|
              1\\d|
              8
            )|
            6(?:
              1\\d|
              [237-9]
            )|
            9(?:
              1\\d|
              [35-9]
            )
          )\\d{5}|
          (?:
            23|
            4(?:
              [1-469]|
              8\\d
            )|
            5[23679]|
            6[4-6]|
            7[14]|
            9[04]
          )\\d{7}
        ',
                'mobile' => '
          8(?:
            22|
            [35-9]\\d
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '700\\d{6}',
                'specialrate' => '(18[59]0\\d{6})|(
          15(?:
            1[2-8]|
            [2-8]0|
            9[089]
          )\\d{6}
        )|(818\\d{6})',
                'toll_free' => '1800\\d{6}',
                'voip' => '76\\d{7}'
              };
my %areanames = ();
$areanames{en} = {"35321", "Cork",
"3536690", "Killorglin",
"353459", "Naas",
"353623", "Tipperary",
"353616", "Scariff",
"353579901", "Portlaoise",
"3535987", "Athy",
"35327", "Bantry",
"353451", "Naas\/Kildare\/Curragh",
"3532140", "Kinsale",
"35371931", "Sligo",
"353569900", "Kilkenny",
"3535274", "Cahir",
"353570", "Portlaoise",
"3536693", "Dingle",
"3537491", "Letterkenny",
"3536299", "Tipperary",
"35399", "Kilronan",
"353561", "Kilkenny",
"353455", "Kildare",
"3534999", "Cavan\/Cootehill\/Oldcastle\/Belturbet",
"353740", "Letterkenny",
"3535791", "Birr",
"3534497", "Castlepollard",
"353425", "Castleblaney",
"3536599", "Ennis\/Ennistymon\/Kilrush",
"353749211", "Letterkenny",
"353493", "Belturbet",
"35371959", "Carrick\-on\-Shannon",
"353653", "Ennis",
"353464", "Trim",
"3536696", "Cahirciveen",
"3531", "Dublin",
"353421", "Dundalk\/Carrickmacross\/Castleblaney",
"353901", "Athlone",
"353498", "Oldcastle",
"353497", "Cavan",
"3534330", "Longford",
"353719331", "Sligo",
"353657", "Ennistymon",
"353658", "Kilrush",
"353909900", "Athlone",
"3534333", "Longford",
"353719900", "Sligo",
"35374", "Letterkenny\/Donegal\/Dungloe\/Buncrana",
"353650", "Ennis\/Ennistymon\/Kilrush",
"353466", "Edenderry",
"353490", "Cavan\/Cootehill\/Oldcastle\/Belturbet",
"353504", "Thurles",
"3534697", "Edenderry",
"35351999", "Waterford\/Carrick\-on\-Suir\/New\ Ross\/Kilmacthomas",
"353472", "Clones",
"353711", "Sligo",
"35357859", "Portlaoise",
"3536477", "Rathmore",
"353620", "Tipperary\/Cashel",
"353218", "Cork\/Kinsale\/Coachford",
"3534295", "Carrickmacross",
"353217", "Coachford",
"353531", "Wexford",
"35351", "Waterford",
"353912", "Gort",
"35357", "Portlaoise\/Abbeyleix\/Tullamore\/Birr",
"353539900", "Wexford",
"353949291", "Castlebar",
"35371930", "Sligo",
"3536698", "Killorglin",
"3536694", "Cahirciveen",
"353628", "Tipperary",
"353627", "Cashel",
"353422", "Dundalk",
"353447", "Castlepollard",
"353654", "Ennis",
"353448", "Tyrellspass",
"3534492", "Tyrellspass",
"353463", "Navan\/Kells\/Trim\/Edenderry\/Enfield",
"353719332", "Sligo",
"3535786", "Portlaoise",
"353438", "Granard",
"353437", "Granard",
"3534290", "Dundalk",
"353494", "Cavan",
"3534699", "Navan\/Kells\/Trim\/Edenderry\/Enfield",
"35343669", "Granard",
"3537198", "Manorhamilton",
"3534293", "Dundalk",
"3537497", "Donegal",
"353646701", "Killarney",
"353719335", "Sligo",
"353949285", "Castlebar",
"353516", "Carrick\-on\-Suir",
"3534491", "Tyrellspass",
"3535394", "Gorey",
"35396", "Ballina",
"353624", "Tipperary",
"3534296", "Carrickmacross",
"353452", "Kildare",
"35343668", "Granard",
"35352", "Clonmel\/Cahir\/Killenaule",
"3534510", "Kildare",
"35374920", "Letterkenny",
"3535677", "Kilkenny",
"3535393", "Ferns",
"353402", "Arklow",
"35367", "Nenagh",
"3535989", "Athy",
"35361", "Limerick",
"353514", "New\ Ross",
"353719344", "Sligo",
"3539096", "Ballinasloe",
"353949289", "Castlebar",
"35322", "Mallow",
"3537196", "Carrick\-on\-Shannon",
"35357850", "Portlaoise",
"3535390", "Wexford",
"3534691", "Navan",
"35393", "Tuam",
"353626", "Cashel",
"353949288", "Castlebar",
"35394", "Castlebar\/Claremorris\/Castlerea\/Ballinrobe",
"3534499", "Mullingar\/Castlepollard\/Tyrrellspass",
"353471", "Monaghan\/Clones",
"35325", "Fermoy",
"353496", "Cavan",
"35344", "Mullingar",
"3536695", "Cahirciveen",
"353656", "Ennis",
"353460", "Navan",
"3534120", "Drogheda\/Ardee",
"353479", "Monaghan",
"3534368", "Granard",
"35343", "Longford\/Granard",
"35361999", "Limerick\/Scariff",
"353475", "Clones",
"353719401", "Sligo",
"353468", "Navan",
"3534692", "Kells",
"353467", "Navan",
"353443", "Mullingar\/Castlepollard\/Tyrrellspass",
"3534298", "Castleblaney",
"35398", "Westport",
"3535291", "Killenaule",
"3534294", "Dundalk",
"353469901", "Navan",
"353669100", "Killorglin",
"353749212", "Letterkenny",
"35391", "Galway",
"353668", "Tralee\/Dingle\/Killorglin\/Cahersiveen",
"3536692", "Dingle",
"353404", "Wicklow",
"353512", "Kilmacthomas",
"35397", "Belmullet",
"35364", "Killarney\/Rathmore",
"353619", "Scariff",
"353909903", "Ballinasloe",
"3535793", "Tullamore",
"353646700", "Killarney",
"3534695", "Enfield",
"353456", "Naas",
"353539902", "Enniscorthy",
"35329", "Kanturk",
"3535787", "Abbeyleix",
"35363", "Rathluirc",
"35371932", "Sligo",
"353749889", "Letterkenny",
"3537493", "Buncrana",
"3534297", "Castleblaney",
"3536691", "Dingle",
"353473", "Monaghan",
"353949287", "Castlebar",
"353426", "Dundalk",
"353749888", "Letterkenny",
"3534799", "Monaghan\/Clones",
"353539903", "Gorey",
"3532141", "Kinsale",
"353505", "Roscrea",
"35341", "Drogheda",
"353909902", "Ballinasloe",
"3535991", "Carlow",
"353719334", "Sligo",
"35368", "Listowel",
"3534367", "Granard",
"3534199", "Drogheda\/Ardee",
"353909897", "Athlone",
"353461", "Navan",
"353652", "Ennis",
"353424", "Carrickmacross",
"353749214", "Letterkenny",
"3534332", "Longford",
"353470", "Monaghan\/Clones",
"353469900", "Navan",
"353492", "Cootehill",
"353477", "Monaghan",
"353478", "Monaghan",
"3536466", "Killarney",
"3539495", "Ballinrobe",
"353465", "Enfield",
"353719010", "Sligo",
"353531203", "Gorey",
"3539097", "Portumna",
"35394925", "Castlebar",
"3534331", "Longford",
"3536699", "Tralee\/Dingle\/Killorglin\/Cahersiveen",
"35366", "Tralee",
"353918", "Loughrea",
"35343667", "Granard",
"3534495", "Castlepollard",
"3535688", "Freshford",
"3535678", "Kilkenny",
"353454", "The\ Curragh",
"353622", "Cashel",
"35374989", "Letterkenny",
"3534791", "Monaghan\/Clones",
"353531202", "Enniscorthy",
"3535964", "Baltinglass",
"35359", "Carlow\/Muine\ Bheag\/Athy\/Baltinglass",
"35374960", "Letterkenny",
"353741", "Letterkenny",
"3534490", "Tyrellspass",
"353432", "Longford",
"3539496", "Castlerea",
"3534694", "Trim",
"35371", "Sligo\/Manorhamilton\/Carrick\-on\-Shannon",
"3534698", "Edenderry",
"353749210", "Letterkenny",
"35390650", "Athlone",
"353427", "Dundalk",
"353428", "Dundalk",
"353749900", "Letterkenny",
"3534292", "Dundalk",
"353949286", "Castlebar",
"35358", "Dungarvan",
"353469907", "Edenderry",
"3539064", "Athlone",
"35390", "Athlone\/Ballinasloe\/Portumna\/Roscommon",
"353420", "Dundalk\/Carrickmacross\/Castleblaney",
"3535986", "Athy",
"353474", "Clones",
"3535644", "Castlecomer",
"353450", "Naas\/Kildare\/Curragh",
"35343666", "Granard",
"3536697", "Killorglin",
"353569901", "Kilkenny",
"3534291", "Dundalk",
"3539493", "Claremorris",
"35326", "Macroom",
"353579900", "Portlaoise",
"35353", "Wexford\/Enniscorthy\/Ferns\/Gorey",
"3535997", "Muine\ Bheag",
"353560", "Kilkenny",
"3532147", "Kinsale",
"3536670", "Tralee\/Dingle\/Killorglin\/Cahersiveen",
"3539490", "Castlebar",
"353571", "Portlaoise",
"353458", "Naas",
"3534496", "Castlepollard",
"353457", "Naas",
"353916", "Gort",
"3539498", "Castlerea",
"353629", "Cashel",
"3537191", "Sligo",
"35356", "Kilkenny\/Castlecomer\/Freshford",
"353453", "The\ Curragh",
"353621", "Tipperary\/Cashel",
"3534696", "Enfield",
"353530", "Wexford",
"353539901", "Wexford",
"3539066", "Roscommon",
"3535392", "Enniscorthy",
"353949290", "Castlebar",
"35323", "Bandon",
"35369", "Newcastle\ West",
"3537495", "Dungloe",
"3535988", "Athy",
"35324", "Youghal",
"353625", "Tipperary",
"353495", "Cootehill",
"35395", "Clifden",
"353578510", "Portlaoise",
"3534693", "Kells",
"353900", "Athlone",
"3535261", "Clonmel",
"353655", "Ennis",
"3534299", "Dundalk\/Carrickmacross\/Castleblaney",
"353719330", "Sligo",
"3535391", "Wexford",
"3534690", "Navan",
"353491", "Cavan\/Cootehill\/Oldcastle\/Belturbet",
"353476", "Monaghan",
"353710", "Sligo",
"353909901", "Athlone",
"3534369", "Granard",
"353659", "Kilrush",
"35328", "Skibbereen",
"3534498", "Castlepollard",
"353416", "Ardee",
"353499", "Belturbet",
"353423", "Dundalk\/Carrickmacross\/Castleblaney",
"353462", "Kells",
"353651", "Ennis\/Ennistymon\/Kilrush",};
my $timezones = {
               '' => [
                       'Europe/Guernsey',
                       'Europe/Isle_of_Man',
                       'Europe/London'
                     ],
               '539253' => [
                             'Europe/Guernsey',
                             'Europe/Isle_of_Man',
                             'Europe/London'
                           ]
             };
sub _may_be_noncanonical_number { 1 }

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+353|\D)//g;
      my $self = bless({ country_code => '353', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '353', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;