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
package Number::Phone::StubCountry::CM;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250913135855;

my $formatters = [
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '88',
                  'pattern' => '(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2 $3 $4 $5',
                  'leading_digits' => '
            [26]|
            88
          ',
                  'pattern' => '(\\d)(\\d{2})(\\d{2})(\\d{2})(\\d{2})'
                }
              ];

my $validators = {
                'fixed_line' => '
          2(?:
            22|
            33
          )\\d{6}
        ',
                'geographic' => '
          2(?:
            22|
            33
          )\\d{6}
        ',
                'mobile' => '
          (?:
            24[23]|
            6(?:
              [25-9]\\d|
              40
            )
          )\\d{6}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '',
                'toll_free' => '88\\d{6,7}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"237233323", "Buéa",
"237222120", "Akonolinga",
"237222121", "Ayos",
"237233328", "Buéa",
"237222144", "Ngoumou",
"237233452", "Dschang",
"237233464", "Edéa",
"237222482", "Kye\-Ossie\/Ambam",
"237233341", "Manfé",
"237222355", "Tignère",
"237233296", "Bafang",
"237233324", "Buéa",
"23723342", "Akwa\ Centre",
"237233489", "Bangangté",
"237222397", "Figuil",
"237233497", "Loum\/Mbanga",
"237233313", "Yabassi",
"23722227", "Garoua",
"237233337", "Limbé",
"237233364", "Bamenda",
"237222111", "Mbalmayo",
"237222464", "Lolodorf",
"237222414", "Kousseri",
"23723341", "Bepanda",
"237233355", "Kumba",
"23722230", "Nkomo",
"237233451", "Dschang",
"23722231", "Biyem\ Assi",
"237222455", "Mokolo",
"23723340", "Bepanda",
"237233363", "Bamenda",
"237222463", "Lolodorf",
"237233297", "Bafang",
"237222335", "Abong\-Bang",
"237233490", "Nkongsamba",
"237233331", "Tiko",
"237233491", "Nkongsamba",
"237222264", "Belabo",
"237222256", "Beelel\/Mbé",
"237222242", "Bertoua",
"23723337", "Bassa",
"237222252", "N\'Gaoundéré",
"23722222", "Yaounde",
"237222347", "N\'Gaoundal",
"237233335", "Limbé",
"237222395", "Guider",
"237222282", "Mengong",
"23723347", "Akwa\ North",
"237233495", "Nkongsamba",
"23722220", "Jamot",
"237233492", "Nkongsamba",
"237222241", "Bertoua",
"237233339", "Limbé",
"237222251", "N\'Gaoundéré",
"237233496", "Nkongsamba",
"23722221", "Jamot",
"237222478", "Sangmelima",
"237233263", "Foumban",
"237233336", "Limbé",
"237222447", "Mora",
"237222250", "N\'Gaoundéré",
"237233332", "Limbé",
"237222322", "Soa",
"237222185", "Bafia",
"23722223", "Yaounde",
"237233267", "Foumbot",
"237222182", "Monatélé",
"237233321", "Muyuka",
"237233362", "Bamenda",
"237233354", "Kumba",
"23723344", "Bafoussam",
"237233366", "Mbambili",
"237222462", "Kribi",
"237233305", "Mbouda",
"237233484", "Bangangté",
"237222348", "Tibati",
"237233322", "Buéa",
"237222426", "Yagoua",
"237233361", "Bamenda",
"237233326", "Buéa",
"237222461", "Kribi",
"23722229", "Maroua",
"237233329", "Buéa",
"237233360", "Bamenda",
"237222180", "Obala",
"237222369", "Banyo",
"237222321", "Mfou",
"237222354", "Galim\ Tignère",
"237233325", "Buéa",
"237233494", "Nkongsamba",
"237222371", "Meiganga",
"23723339", "Bonabéri",
"23723343", "Akwa\ Centre",
"237222283", "Ebolowa",
"237233334", "Limbé",
"237233277", "Bandjoun",
"237233493", "Nkongsamba",
"237222479", "Meyomessala\/Efoulan",
"237233338", "Limbé",
"237233262", "Foumban",
"237233221", "Kumbo",
"237233215", "Nkambe",
"237222284", "Ebolowa",
"237222195", "Nanga\ Eboko",
"237233333", "Limbé",
"237233205", "Wum",
"237222136", "Eséka\/Mboumnyebel",
"237222253", "N\'Gaoundéré",
"237233327", "Buéa",
"237222262", "Batouri",
"237222254", "Dang",};
my $timezones = {
               '' => [
                       'Africa/Douala'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+237|\D)//g;
      my $self = bless({ country_code => '237', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;