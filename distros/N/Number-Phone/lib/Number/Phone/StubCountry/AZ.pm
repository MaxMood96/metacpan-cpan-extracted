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
package Number::Phone::StubCountry::AZ;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135855;

my $formatters = [
                {
                  'format' => '$1 $2 $3',
                  'intl_format' => 'NA',
                  'leading_digits' => '[1-9]',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '90',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '
            1[28]|
            2|
            365(?:
              4|
              5[02]
            )|
            46
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '[13-9]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            2[12]428|
            3655[02]
          )\\d{4}|
          (?:
            2(?:
              22[0-79]|
              63[0-28]
            )|
            3654
          )\\d{5}|
          (?:
            (?:
              1[28]|
              46
            )\\d|
            2(?:
              [014-6]2|
              [23]3
            )
          )\\d{6}
        ',
                'geographic' => '
          (?:
            2[12]428|
            3655[02]
          )\\d{4}|
          (?:
            2(?:
              22[0-79]|
              63[0-28]
            )|
            3654
          )\\d{5}|
          (?:
            (?:
              1[28]|
              46
            )\\d|
            2(?:
              [014-6]2|
              [23]3
            )
          )\\d{6}
        ',
                'mobile' => '
          36554\\d{4}|
          (?:
            [16]0|
            4[04]|
            5[015]|
            7[07]|
            99
          )\\d{7}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(900200\\d{3})',
                'toll_free' => '88\\d{7}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"9942122", "Beylagan",
"9942522", "Astara",
"9942223", "Tartar",
"9942126", "Neftchala",
"99436542", "Sharur",
"9942623", "Qubadli",
"99436544", "Nakhchivan\ city",
"9942425", "Gakh",
"99436550", "Nakhchivan\ city",
"9942331", "Khizi",
"9942631", "Fuzuli",
"9942225", "Ganja",
"9942230", "Shamkir",
"9942028", "Ismayilli",
"99418", "Sumgayit",
"9942625", "Zangilan",
"9942330", "Siyazan",
"994214", "Hajigabul",
"9942630", "Hadrut",
"9942231", "Tovuz",
"9942224", "Goranboy",
"9942229", "Gazakh",
"99436541", "Babek",
"9942420", "Gabala",
"9942333", "Guba",
"9942427", "Mingachevir",
"9942128", "Saatli",
"9942624", "Askaran",
"9942629", "Khojavand",
"9942421", "Oguz",
"99436548", "Kangarli",
"9942233", "Yevlakh",
"99436552", "Sharur",
"9942221", "Dashkasan",
"9942022", "Agsu",
"9942627", "Kalbajar",
"9942620", "Khojali",
"9942335", "Shabran",
"9942026", "Shamakhi",
"9942424", "Shaki",
"9942429", "Balakan",
"9942220", "Goygol",
"9942235", "Naftalan",
"99436546", "Julfa",
"9942621", "Lachin",
"9942227", "Samukh",
"9942021", "Ujar",
"9942222", "Agstafa",
"9942123", "Sabirabad",
"9942226", "Ganja",
"9942638", "Jabrayil",
"9942338", "Gusar",
"9942020", "Barda",
"9942626", "Shusha",
"9942027", "Goychay",
"9942622", "Khankandi",
"99412", "Baku",
"9942024", "Gobustan",
"9942029", "Zardab",
"9942525", "Lankaran",
"9942125", "Salyan",
"99436543", "Shahbuz",
"994224", "Agstafa\/Ganja\/Yevlakh",
"9942422", "Zagatala",
"9942524", "Jalilabad",
"9942529", "Bilasuvar",
"9942124", "Imishli",
"9942628", "Agdara",
"9942632", "Agdam",
"9942332", "Khachmaz",
"9942025", "Kurdamir",
"9942232", "Gadabay",
"99436549", "Sadarak",
"9942521", "Masalli",
"9942121", "Shirvan",
"9942023", "Agdash",
"9942520", "Yardimli",
"99436547", "Ordubad",
"9942120", "Hajigabul",
"9942127", "Agjabadi",
"9942527", "Lerik",};
my $timezones = {
               '' => [
                       'Asia/Baku'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+994|\D)//g;
      my $self = bless({ country_code => '994', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '994', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;