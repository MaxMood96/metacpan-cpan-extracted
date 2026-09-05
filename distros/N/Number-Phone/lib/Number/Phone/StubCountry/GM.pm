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
package Number::Phone::StubCountry::GM;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101550;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            [235-9]|
            4(?:
              [0-35]|
              4[16-9]
            )
          ',
                  'pattern' => '(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[48]',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            4(?:
              [23]\\d\\d|
              4(?:
                1[024679]|
                (?:
                  4(?:
                    [237-9]\\d|
                    4[14-9]
                  )|
                  8[0-389]\\d
                )\\d|
                5(?:
                  5(?:
                    3\\d|
                    4[0-7]
                  )|
                  [67]\\d\\d
                )
              )
            )|
            5(?:
              5(?:
                3\\d|
                4[0-7]
              )|
              6[67]\\d|
              7(?:
                1[04]|
                2[035]|
                3[58]|
                48
              )
            )|
            8[0-389]\\d\\d
          )\\d{3}|
          44[6-9]\\d{4}
        ',
                'geographic' => '
          (?:
            4(?:
              [23]\\d\\d|
              4(?:
                1[024679]|
                (?:
                  4(?:
                    [237-9]\\d|
                    4[14-9]
                  )|
                  8[0-389]\\d
                )\\d|
                5(?:
                  5(?:
                    3\\d|
                    4[0-7]
                  )|
                  [67]\\d\\d
                )
              )
            )|
            5(?:
              5(?:
                3\\d|
                4[0-7]
              )|
              6[67]\\d|
              7(?:
                1[04]|
                2[035]|
                3[58]|
                48
              )
            )|
            8[0-389]\\d\\d
          )\\d{3}|
          44[6-9]\\d{4}
        ',
                'mobile' => '
          (?:
            (?:
              [23679]\\d|
              4[015]|
              8(?:
                (?:
                  3[35]|
                  6[68]|
                  99
                )\\d|
                7(?:
                  [27]\\d|
                  4[015]
                )
              )
            )\\d|
            5(?:
              [0-489]\\d|
              56
            )
          )\\d{4}|
          8[4-7]\\d{5}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"2204442", "Banjul",
"220445546", "Kudang",
"2204414", "Sanyang",
"220444481", "Brikama\/Kanilia",
"2205714", "Ndugukebbe",
"2205545", "Pakaliba",
"220445542", "Nyorojattaba",
"220444489", "Bwiam",
"22044441", "Brufut\/Kartong\/Sanyang\/Tanji\/Berending",
"2204443", "Serekunda",
"2205678", "Brikama\-Ba",
"2205674", "Bansang",
"2205544", "Bureng",
"22043", "Bundung\/Serekunda",
"22042", "Banjul",
"2204419", "Kartong",
"22044445", "Soma",
"220444488", "Sibanor",
"220445547", "Jareng",
"2204485", "Kafuta",
"220445543", "Japeneh\/Soma",
"2205725", "Iliasa",
"2204447", "Yundum",
"2205665", "Kuntaur",
"2204489", "Bwiam",
"220445545", "Pakaliba",
"220445544", "Bureng",
"220444480", "Bondali",
"220574", "Kaur",
"2204484", "Brikama\/Kanilia",
"2204488", "Sibanor",
"22044447", "Yundum",
"2204416", "Tujereng",
"2205541", "Kwenella",
"220444482", "Brikama\/Kanilia",
"2204457", "Kerewan\/Farafenni\/Barra\/Kaur",
"22044449", "Bakau",
"220445541", "Kwenella",
"2205547", "Jareng",
"2204482", "Brikama\/Kanilia",
"220449", "Bakau",
"220444486", "Gunjur",
"2204480", "Bondali",
"2205738", "Ngensanjal",
"2205720", "Kerewan",
"2204456", "Basse\/Bansang\/Gambisara\/Janjanbury\/Kuntaur",
"220446", "Kotu\/Senegambia",
"22044444", "Pakaliba\/Kaiaf\/Jeren\/Kudang\/Bureng\/Japineh\/Kwenela\/Nyorojataba",
"2204417", "Sanyang",
"220567", "Sotuma",
"2205723", "Njabakunda",
"2204483", "Brikama\/Kanilia",
"2205546", "Kudang",
"22044553", "Soma",
"2205676", "Georgetown",
"2205735", "Farafenni",
"2204449", "Bakau",
"2205542", "Nyorojattaba",
"2205540", "Kaiaf",
"220444485", "Kafuta",
"220553", "Soma",
"2204487", "Faraba",
"2204481", "Brikama\/Kanilia",
"220444487", "Faraba",
"220444483", "Brikama\/Kanilia",
"2204486", "Gunjur",
"2205710", "Barra",
"22044446", "Kotu\/Kololi",
"220447", "Yundum",
"2205543", "Japeneh\/Soma",
"2204448", "Brikama\/Gunjur\/Sanyang\/Bwiam\/Kanilai",
"2205666", "Numeyel",
"22044195", "Berending",
"220566", "Baja\ Kunda\/Basse\/Fatoto\/Gambisara\/Garawol\/Misera\/Sambakunda\/Sudowol",
"220445540", "Kaiaf",
"2204410", "Brufut",
"220444484", "Brikama\/Kanilia",
"2204412", "Tanji",};
my $timezones = {
               '' => [
                       'Africa/Banjul'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+220|\D)//g;
      my $self = bless({ country_code => '220', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;