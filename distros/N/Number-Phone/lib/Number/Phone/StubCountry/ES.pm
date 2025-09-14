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
package Number::Phone::StubCountry::ES;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135857;

my $formatters = [
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '905',
                  'pattern' => '(\\d{4})'
                },
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '[79]9',
                  'pattern' => '(\\d{6})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[89]00',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '[5-9]',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          96906(?:
            0[0-8]|
            1[1-9]|
            [2-9]\\d
          )\\d\\d|
          9(?:
            69(?:
              0[0-57-9]|
              [1-9]\\d
            )|
            73(?:
              [0-8]\\d|
              9[1-9]
            )
          )\\d{4}|
          (?:
            8(?:
              [1356]\\d|
              [28][0-8]|
              [47][1-9]
            )|
            9(?:
              [135]\\d|
              [268][0-8]|
              4[1-9]|
              7[124-9]
            )
          )\\d{6}
        ',
                'geographic' => '
          96906(?:
            0[0-8]|
            1[1-9]|
            [2-9]\\d
          )\\d\\d|
          9(?:
            69(?:
              0[0-57-9]|
              [1-9]\\d
            )|
            73(?:
              [0-8]\\d|
              9[1-9]
            )
          )\\d{4}|
          (?:
            8(?:
              [1356]\\d|
              [28][0-8]|
              [47][1-9]
            )|
            9(?:
              [135]\\d|
              [268][0-8]|
              4[1-9]|
              7[124-9]
            )
          )\\d{6}
        ',
                'mobile' => '
          (?:
            590[16]00\\d|
            9(?:
              6906(?:
                09|
                10
              )|
              7390\\d\\d
            )
          )\\d\\d|
          (?:
            6\\d|
            7[1-48]
          )\\d{7}
        ',
                'pager' => '',
                'personal_number' => '70\\d{7}',
                'specialrate' => '(90[12]\\d{6})|(80[367]\\d{6})|(51\\d{7})',
                'toll_free' => '[89]00\\d{6}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"34863", "Valencia",
"34955", "Seville",
"3497399", "Lleida",
"34969062", "Cuenca",
"34951", "Málaga",
"34948", "Navarre",
"34872", "Girona",
"34864", "Castellón",
"34981", "A\ Coruña",
"34985", "Asturias",
"349736", "Lleida",
"3497393", "Lleida",
"34825", "Toledo",
"34821", "Segovia",
"349734", "Lleida",
"34978", "Teruel",
"34842", "Cantabria",
"34969066", "Cuenca",
"34868", "Murcia",
"349737", "Lleida",
"34859", "Huelva",
"34957", "Cordova",
"34943", "Guipúzcoa",
"34956", "Cádiz",
"34944", "Bizkaia",
"34987", "León",
"34986", "Pontevedra",
"34974", "Huesca",
"349699", "Cuenca",
"3497392", "Lleida",
"3493", "Barcelona",
"34826", "Ciudad\ Real",
"34827", "Cáceres",
"34860", "Valencia",
"34969067", "Cuenca",
"34962", "Valencia",
"34873", "Lleida",
"34862", "Valencia",
"34960", "Valencia",
"3483", "Barcelona",
"3497391", "Lleida",
"34874", "Huesca",
"3497397", "Lleida",
"34927", "Cáceres",
"349731", "Lleida",
"349698", "Cuenca",
"34926", "Ciudad\ Real",
"34886", "Pontevedra",
"34887", "León",
"34844", "Bizkaia",
"3497395", "Lleida",
"34959", "Huelva",
"349690606", "Cuenca",
"349690616", "Cuenca",
"349692", "Cuenca",
"34968", "Murcia",
"34856", "Cádiz",
"34843", "Guipúzcoa",
"34857", "Cordova",
"34942", "Cantabria",
"34878", "Teruel",
"3497398", "Lleida",
"34925", "Toledo",
"34921", "Segovia",
"34969063", "Cuenca",
"349735", "Lleida",
"34881", "A\ Coruña",
"3496904", "Cuenca",
"34885", "Asturias",
"349733", "Lleida",
"34964", "Castellón",
"34855", "Seville",
"34851", "Málaga",
"34969069", "Cuenca",
"34963", "Valencia",
"34972", "Girona",
"34848", "Navarre",
"349690614", "Cuenca",
"34877", "Tarragona",
"34876", "Zaragoza",
"3497394", "Lleida",
"349690604", "Cuenca",
"3491", "Madrid",
"34924", "Badajoz",
"34979", "Palencia",
"349690613", "Cuenca",
"349690603", "Cuenca",
"349690618", "Cuenca",
"349693", "Cuenca",
"349690608", "Cuenca",
"34923", "Salamanca",
"349695", "Cuenca",
"34883", "Valladolid",
"34854", "Seville",
"3496908", "Cuenca",
"34949", "Guadalajara",
"34847", "Burgos",
"34853", "Jaén",
"34884", "Asturias",
"34961", "Valencia",
"34846", "Bizkaia",
"34965", "Alicante",
"34850", "Almería",
"34952", "Málaga",
"34875", "Soria",
"34871", "Balearic\ Islands",
"349732", "Lleida",
"34880", "Zamora",
"3496905", "Cuenca",
"34982", "Lugo",
"34928", "Las\ Palmas",
"34822", "Tenerife",
"349738", "Lleida",
"34920", "Ávila",
"349691", "Cuenca",
"34888", "Ourense",
"34967", "Albacete",
"34841", "La\ Rioja",
"34966", "Alicante",
"34845", "Araba",
"3496901", "Cuenca",
"34858", "Granada",
"34869", "Cuenca",
"3496907", "Cuenca",
"3496900", "Cuenca",
"34941", "La\ Rioja",
"34945", "Araba",
"34866", "Alicante",
"349690600", "Cuenca",
"34867", "Albacete",
"349730", "Lleida",
"3496902", "Cuenca",
"34969065", "Cuenca",
"349690611", "Cuenca",
"34958", "Granada",
"34969064", "Cuenca",
"349690601", "Cuenca",
"34820", "Ávila",
"34922", "Tenerife",
"34988", "Ourense",
"34882", "Lugo",
"34980", "Zamora",
"34828", "Las\ Palmas",
"349690605", "Cuenca",
"34969068", "Cuenca",
"349690615", "Cuenca",
"34852", "Málaga",
"349690612", "Cuenca",
"34950", "Almería",
"349690602", "Cuenca",
"349697", "Cuenca",
"34975", "Soria",
"34971", "Balearic\ Islands",
"349690619", "Cuenca",
"34849", "Guadalajara",
"3496903", "Cuenca",
"34861", "Valencia",
"34865", "Alicante",
"34946", "Bizkaia",
"34984", "Asturias",
"34953", "Jaén",
"34947", "Burgos",
"349694", "Cuenca",
"34983", "Valladolid",
"34954", "Seville",
"3497396", "Lleida",
"3496909", "Cuenca",
"349690607", "Cuenca",
"349690617", "Cuenca",
"34823", "Salamanca",
"349696", "Cuenca",
"34976", "Zaragoza",
"34977", "Tarragona",
"34879", "Palencia",
"34824", "Badajoz",
"3481", "Madrid",};
$areanames{es} = {"34850", "Álmería",
"34871", "Baleares",
"349732", "Lérida",
"349738", "Lérida",
"34888", "Orense",
"34845", "Álava",
"3497394", "Lérida",
"34854", "Sevilla",
"34846", "Vizcaya",
"34946", "Vizcaya",
"34954", "Sevilla",
"3497396", "Lérida",
"34945", "Álava",
"349730", "Lérida",
"34988", "Orense",
"34971", "Baleares",
"349737", "Lérida",
"34957", "Córdoba",
"34944", "Vizcaya",
"3497392", "Lérida",
"3497399", "Lérida",
"34955", "Sevilla",
"34948", "Navarra",
"34872", "Gerona",
"349736", "Lérida",
"3497393", "Lérida",
"349734", "Lérida",
"3497398", "Lérida",
"349735", "Lérida",
"349733", "Lérida",
"34972", "Gerona",
"34848", "Navarra",
"34873", "Lérida",
"3497391", "Lérida",
"3497397", "Lérida",
"349731", "Lérida",
"34844", "Vizcaya",
"3497395", "Lérida",
"34857", "Córdoba",};
my $timezones = {
               '' => [
                       'Atlantic/Canary',
                       'Europe/Madrid'
                     ],
               '5' => [
                        'Europe/Madrid'
                      ],
               '6' => [
                        'Europe/Madrid'
                      ],
               '7' => [
                        'Europe/Madrid'
                      ],
               '8' => [
                        'Europe/Madrid'
                      ],
               '822' => [
                          'Atlantic/Canary'
                        ],
               '827' => [
                          'Atlantic/Canary'
                        ],
               '828' => [
                          'Atlantic/Canary'
                        ],
               '9' => [
                        'Europe/Madrid'
                      ],
               '922' => [
                          'Atlantic/Canary'
                        ],
               '928' => [
                          'Atlantic/Canary'
                        ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+34|\D)//g;
      my $self = bless({ country_code => '34', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;