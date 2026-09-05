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
package Number::Phone::StubCountry::PK;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101551;

my $formatters = [
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[89]0',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{2,7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '1',
                  'pattern' => '(\\d{4})(\\d{5})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            9(?:
              2[3-8]|
              98
            )|
            (?:
              2(?:
                3[2358]|
                4[2-4]|
                9[2-8]
              )|
              45[3479]|
              54[2-467]|
              60[468]|
              72[236]|
              8(?:
                2[2-689]|
                3[23578]|
                4[3478]|
                5[2356]
              )|
              9(?:
                22|
                3[27-9]|
                4[2-6]|
                6[3569]|
                9[25-7]
              )
            )[2-9]
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{3})(\\d{6,7})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            (?:
              2[125]|
              4[0-246-9]|
              5[1-35-7]|
              6[1-8]|
              7[14]|
              8[16]|
              91
            )[2-9]
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{7,8})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '58',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{5})(\\d{5})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '3',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{7})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '
            2[125]|
            4[0-246-9]|
            5[1-35-7]|
            6[1-8]|
            7[14]|
            8[16]|
            91
          ',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3})(\\d{3})'
                },
                {
                  'format' => '$1 $2 $3 $4',
                  'leading_digits' => '[24-9]',
                  'national_rule' => '(0$1)',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{3})(\\d{3})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            (?:
              21|
              42
            )[2-9]|
            58[126]
          )\\d{7}|
          (?:
            2[25]|
            4[0146-9]|
            5[1-35-7]|
            6[1-8]|
            7[14]|
            8[16]|
            91
          )[2-9]\\d{6,7}|
          (?:
            2(?:
              3[2358]|
              4[2-4]|
              9[2-8]
            )|
            45[3479]|
            54[2-467]|
            60[468]|
            72[236]|
            8(?:
              2[2-689]|
              3[23578]|
              4[3478]|
              5[2356]
            )|
            9(?:
              2[2-8]|
              3[27-9]|
              4[2-6]|
              6[3569]|
              9[25-8]
            )
          )[2-9]\\d{5,6}
        ',
                'geographic' => '
          (?:
            (?:
              21|
              42
            )[2-9]|
            58[126]
          )\\d{7}|
          (?:
            2[25]|
            4[0146-9]|
            5[1-35-7]|
            6[1-8]|
            7[14]|
            8[16]|
            91
          )[2-9]\\d{6,7}|
          (?:
            2(?:
              3[2358]|
              4[2-4]|
              9[2-8]
            )|
            45[3479]|
            54[2-467]|
            60[468]|
            72[236]|
            8(?:
              2[2-689]|
              3[23578]|
              4[3478]|
              5[2356]
            )|
            9(?:
              2[2-8]|
              3[27-9]|
              4[2-6]|
              6[3569]|
              9[25-8]
            )
          )[2-9]\\d{5,6}
        ',
                'mobile' => '
          3(?:
            [0-247]\\d|
            3[0-79]|
            55|
            64
          )\\d{7}
        ',
                'pager' => '',
                'personal_number' => '122\\d{6}',
                'specialrate' => '(900\\d{5})|(
          (?:
            2(?:
              [125]|
              3[2358]|
              4[2-4]|
              9[2-8]
            )|
            4(?:
              [0-246-9]|
              5[3479]
            )|
            5(?:
              [1-35-7]|
              4[2-467]
            )|
            6(?:
              0[468]|
              [1-8]
            )|
            7(?:
              [14]|
              2[236]
            )|
            8(?:
              [16]|
              2[2-689]|
              3[23578]|
              4[3478]|
              5[2356]
            )|
            9(?:
              1|
              22|
              3[27-9]|
              4[2-6]|
              6[3569]|
              9[2-7]
            )
          )111\\d{6}
        )',
                'toll_free' => '
          800\\d{5}(?:
            \\d{3}
          )?
        ',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"92539", "Gujrat",
"92816", "Quetta",
"929972", "Mansehra\/Batagram",
"92555", "Gujranwala",
"922354", "Sanghar",
"929966", "Shangla",
"927227", "Jacobabad",
"92516", "Islamabad\/Rawalpindi",
"92637", "Bahawalnagar",
"929383", "Swabi",
"928257", "Chagai",
"92626", "Bahawalpur",
"929434", "Chitral",
"929444", "Upper\ Dir",
"929657", "South\ Waziristan",
"92212", "Karachi",
"928523", "Kech",
"928562", "Awaran",
"92499", "Kasur",
"929446", "Upper\ Dir",
"922339", "Mirpur\ Khas",
"926042", "Rajanpur",
"929436", "Chitral",
"928527", "Kech",
"922335", "Mirpur\ Khas",
"924578", "Pakpattan",
"929653", "South\ Waziristan",
"92522", "Sialkot",
"922356", "Sanghar",
"927262", "Shikarpur",
"929387", "Swabi",
"929964", "Shangla",
"926082", "Lodhran",
"929459", "Lower\ Dir",
"927223", "Jacobabad",
"92642", "Dera\ Ghazi\ Khan",
"922389", "Umerkot",
"928253", "Chagai",
"92612", "Multan",
"922385", "Umerkot",
"92465", "Toba\ Tek\ Singh",
"92226", "Hyderabad",
"929455", "Lower\ Dir",
"92862", "Gwadar",
"928569", "Awaran",
"928565", "Awaran",
"928486", "Khuzdar",
"92562", "Sheikhupura",
"92998", "Kohistan",
"928387", "Jaffarabad\/Nasirabad",
"925436", "Chakwal",
"929975", "Mansehra\/Batagram",
"925446", "Jhelum",
"928436", "Mastung",
"929979", "Mansehra\/Batagram",
"922977", "Badin",
"928446", "Kalat",
"92425", "Lahore",
"928337", "Sibi\/Ziarat",
"925444", "Jhelum",
"928333", "Sibi\/Ziarat",
"925434", "Chakwal",
"92479", "Jhang",
"926085", "Lodhran",
"922973", "Badin",
"927265", "Shikarpur",
"928444", "Kalat",
"929452", "Lower\ Dir",
"926089", "Lodhran",
"92573", "Attock",
"927269", "Shikarpur",
"928434", "Mastung",
"92574", "Attock",
"92408", "Sahiwal",
"922382", "Umerkot",
"92689", "Rahim\ Yar\ Khan",
"926045", "Rajanpur",
"928383", "Jaffarabad\/Nasirabad",
"92666", "Muzaffargarh",
"92578", "Attock",
"922328", "Tharparkar",
"92404", "Sahiwal",
"928484", "Khuzdar",
"926049", "Rajanpur",
"922332", "Mirpur\ Khas",
"92916", "Peshawar\/Charsadda",
"92403", "Sahiwal",
"925427", "Narowal",
"928474", "Kharan",
"92577", "Attock",
"928288", "Musakhel",
"928373", "Jhal\ Magsi",
"925474", "Hafizabad",
"929663", "D\.I\.\ Khan",
"929638", "Tank",
"92679", "Vehari",
"929694", "Lakki\ Marwat",
"928326", "Bolan",
"928263", "K\.Abdullah\/Pishin",
"92407", "Sahiwal",
"928248", "Loralai",
"928222", "Zhob",
"929954", "Haripur",
"929395", "Buner",
"929469", "Swat",
"928294", "Barkhan\/Kohlu",
"928238", "Killa\ Saifullah",
"92225", "Hyderabad",
"92489", "Sargodha",
"929465", "Swat",
"929399", "Buner",
"922983", "Thatta",
"92652", "Khanewal",
"92466", "Toba\ Tek\ Singh",
"928296", "Barkhan\/Kohlu",
"922987", "Thatta",
"929956", "Haripur",
"92556", "Gujranwala",
"92712", "Sukkur",
"92742", "Larkana",
"92815", "Quetta",
"922448", "Nawabshah",
"922422", "Naushero\ Feroze",
"928267", "K\.Abdullah\/Pishin",
"922438", "Khairpur",
"92515", "Islamabad\/Rawalpindi",
"929667", "D\.I\.\ Khan",
"92252", "Dadu",
"928377", "Jhal\ Magsi",
"928476", "Kharan",
"92625", "Bahawalpur",
"929229", "Kohat",
"925462", "Mandi\ Bahauddin",
"928552", "Panjgur",
"929225", "Kohat",
"925423", "Narowal",
"928324", "Bolan",
"929696", "Lakki\ Marwat",
"925476", "Hafizabad",
"924548", "Khushab",
"929392", "Buner",
"928534", "Lasbela",
"928225", "Zhob",
"929324", "Malakand",
"928358", "Dera\ Bugti",
"924538", "Bhakkar",
"924594", "Mianwali",
"928229", "Zhob",
"926066", "Layyah",
"929377", "Mardan",
"929423", "Bajaur\ Agency",
"929462", "Swat",
"92665", "Muzaffargarh",
"927236", "Ghotki",
"92915", "Peshawar\/Charsadda",
"92442", "Okara",
"92412", "Faisalabad",
"92634", "Bahawalnagar",
"925469", "Mandi\ Bahauddin",
"928559", "Panjgur",
"92633", "Bahawalnagar",
"929928", "Abottabad",
"927234", "Ghotki",
"929222", "Kohat",
"928555", "Panjgur",
"925465", "Mandi\ Bahauddin",
"929326", "Malakand",
"922429", "Naushero\ Feroze",
"924596", "Mianwali",
"92638", "Bahawalnagar",
"928536", "Lasbela",
"929427", "Bajaur\ Agency",
"929373", "Mardan",
"92426", "Lahore",
"926064", "Layyah",
"922425", "Naushero\ Feroze",
"92473", "Jhang",
"92215", "Karachi",
"925438", "Chakwal",
"92688", "Rahim\ Yar\ Khan",
"925463", "Mandi\ Bahauddin",
"92474", "Jhang",
"928553", "Panjgur",
"92677", "Vehari",
"925422", "Narowal",
"925448", "Jhelum",
"928438", "Mastung",
"92579", "Attock",
"92256", "Dadu",
"928448", "Kalat",
"92684", "Rahim\ Yar\ Khan",
"92478", "Jhang",
"929379", "Mardan",
"92487", "Sargodha",
"92683", "Rahim\ Yar\ Khan",
"922423", "Naushero\ Feroze",
"928227", "Zhob",
"92746", "Larkana",
"92409", "Sahiwal",
"928488", "Khuzdar",
"922324", "Tharparkar",
"929375", "Mardan",
"92552", "Gujranwala",
"92716", "Sukkur",
"92462", "Toba\ Tek\ Singh",
"92656", "Khanewal",
"929425", "Bajaur\ Agency",
"922982", "Thatta",
"922326", "Tharparkar",
"92645", "Dera\ Ghazi\ Khan",
"929429", "Bajaur\ Agency",
"928262", "K\.Abdullah\/Pishin",
"92615", "Multan",
"928223", "Zhob",
"922427", "Naushero\ Feroze",
"928372", "Jhal\ Magsi",
"92525", "Sialkot",
"929662", "D\.I\.\ Khan",
"928557", "Panjgur",
"925467", "Mandi\ Bahauddin",
"92494", "Kasur",
"92925", "Hangu\/Orakzai\ Agy",
"929397", "Buner",
"92493", "Kasur",
"92422", "Lahore",
"929467", "Swat",
"929372", "Mardan",
"924574", "Pakpattan",
"925425", "Narowal",
"929223", "Kohat",
"92565", "Sheikhupura",
"92498", "Kasur",
"929968", "Shangla",
"92865", "Gwadar",
"925429", "Narowal",
"92416", "Faisalabad",
"929665", "D\.I\.\ Khan",
"92534", "Gujrat",
"928375", "Jhal\ Magsi",
"922358", "Sanghar",
"92446", "Okara",
"92533", "Gujrat",
"929227", "Kohat",
"929669", "D\.I\.\ Khan",
"928379", "Jhal\ Magsi",
"922985", "Thatta",
"929448", "Upper\ Dir",
"929422", "Bajaur\ Agency",
"929463", "Swat",
"929438", "Chitral",
"92538", "Gujrat",
"928269", "K\.Abdullah\/Pishin",
"924576", "Pakpattan",
"928265", "K\.Abdullah\/Pishin",
"922989", "Thatta",
"929393", "Buner",
"922979", "Badin",
"92639", "Bahawalnagar",
"92222", "Hyderabad",
"928339", "Sibi\/Ziarat",
"929977", "Mansehra\/Batagram",
"92655", "Khanewal",
"92616", "Multan",
"92537", "Gujrat",
"928252", "Chagai",
"927238", "Ghotki",
"92646", "Dera\ Ghazi\ Khan",
"927263", "Shikarpur",
"922975", "Badin",
"929924", "Abottabad",
"926083", "Lodhran",
"928335", "Sibi\/Ziarat",
"927222", "Jacobabad",
"92526", "Sialkot",
"929652", "South\ Waziristan",
"928389", "Jaffarabad\/Nasirabad",
"924546", "Khushab",
"928356", "Dera\ Bugti",
"924536", "Bhakkar",
"928567", "Awaran",
"926068", "Layyah",
"926043", "Rajanpur",
"928385", "Jaffarabad\/Nasirabad",
"928522", "Kech",
"924598", "Mianwali",
"926047", "Rajanpur",
"929328", "Malakand",
"924534", "Bhakkar",
"928354", "Dera\ Bugti",
"928563", "Awaran",
"928538", "Lasbela",
"924544", "Khushab",
"92216", "Karachi",
"92497", "Kasur",
"92255", "Dadu",
"92622", "Bahawalpur",
"926087", "Lodhran",
"929382", "Swabi",
"92512", "Islamabad\/Rawalpindi",
"927267", "Shikarpur",
"929926", "Abottabad",
"92715", "Sukkur",
"92812", "Quetta",
"929973", "Mansehra\/Batagram",
"92745", "Larkana",
"92912", "Peshawar\/Charsadda",
"928246", "Loralai",
"92445", "Okara",
"922333", "Mirpur\ Khas",
"928236", "Killa\ Saifullah",
"92415", "Faisalabad",
"929655", "South\ Waziristan",
"928382", "Jaffarabad\/Nasirabad",
"92662", "Muzaffargarh",
"929659", "South\ Waziristan",
"922434", "Khairpur",
"922444", "Nawabshah",
"928259", "Chagai",
"922383", "Umerkot",
"929453", "Lower\ Dir",
"927229", "Jacobabad",
"928286", "Musakhel",
"928332", "Sibi\/Ziarat",
"927225", "Jacobabad",
"922972", "Badin",
"928328", "Bolan",
"928255", "Chagai",
"929636", "Tank",
"928284", "Musakhel",
"929385", "Swabi",
"928478", "Kharan",
"92926", "Kurram\ Agency",
"92673", "Vehari",
"922387", "Umerkot",
"929698", "Lakki\ Marwat",
"929634", "Tank",
"929389", "Swabi",
"92488", "Sargodha",
"92674", "Vehari",
"92477", "Jhang",
"925478", "Hafizabad",
"929457", "Lower\ Dir",
"928234", "Killa\ Saifullah",
"928298", "Barkhan\/Kohlu",
"929958", "Haripur",
"928244", "Loralai",
"92566", "Sheikhupura",
"928525", "Kech",
"922337", "Mirpur\ Khas",
"92484", "Sargodha",
"92678", "Vehari",
"92687", "Rahim\ Yar\ Khan",
"928529", "Kech",
"922446", "Nawabshah",
"92483", "Sargodha",
"92866", "Gwadar",
"922436", "Khairpur",
"928329", "Bolan",
"92223", "Hyderabad",
"92224", "Hyderabad",
"927228", "Jacobabad",
"928325", "Bolan",
"927232", "Ghotki",
"929224", "Kohat",
"928258", "Chagai",
"92228", "Hyderabad",
"924573", "Pakpattan",
"929658", "South\ Waziristan",
"929396", "Buner",
"929466", "Swat",
"926062", "Layyah",
"928295", "Barkhan\/Kohlu",
"929955", "Haripur",
"928532", "Lasbela",
"929394", "Buner",
"92518", "Islamabad\/Rawalpindi",
"929322", "Malakand",
"924592", "Mianwali",
"928528", "Kech",
"924577", "Pakpattan",
"92624", "Bahawalpur",
"92427", "Lahore",
"92623", "Bahawalpur",
"92818", "Quetta",
"929959", "Haripur",
"929464", "Swat",
"928299", "Barkhan\/Kohlu",
"929388", "Swabi",
"92514", "Islamabad\/Rawalpindi",
"925479", "Hafizabad",
"929699", "Lakki\ Marwat",
"92513", "Islamabad\/Rawalpindi",
"928475", "Kharan",
"929226", "Kohat",
"92419", "Faisalabad",
"92814", "Quetta",
"929695", "Lakki\ Marwat",
"928479", "Kharan",
"92628", "Bahawalpur",
"92449", "Okara",
"92813", "Quetta",
"925475", "Hafizabad",
"92749", "Larkana",
"922323", "Tharparkar",
"92406", "Sahiwal",
"92913", "Peshawar\/Charsadda",
"92719", "Sukkur",
"926069", "Layyah",
"928226", "Zhob",
"92914", "Peshawar\/Charsadda",
"922424", "Naushero\ Feroze",
"926065", "Layyah",
"92663", "Muzaffargarh",
"92467", "Toba\ Tek\ Singh",
"92664", "Muzaffargarh",
"928388", "Jaffarabad\/Nasirabad",
"92918", "Peshawar\/Charsadda",
"92259", "Dadu",
"92576", "Attock",
"927239", "Ghotki",
"925464", "Mandi\ Bahauddin",
"92668", "Muzaffargarh",
"928554", "Panjgur",
"928322", "Bolan",
"927235", "Ghotki",
"922978", "Badin",
"928338", "Sibi\/Ziarat",
"928472", "Kharan",
"925472", "Hafizabad",
"92672", "Vehari",
"928556", "Panjgur",
"925466", "Mandi\ Bahauddin",
"929692", "Lakki\ Marwat",
"924595", "Mianwali",
"929325", "Malakand",
"92557", "Gujranwala",
"928224", "Zhob",
"929952", "Haripur",
"928535", "Lasbela",
"928292", "Barkhan\/Kohlu",
"928539", "Lasbela",
"92659", "Khanewal",
"922327", "Tharparkar",
"922426", "Naushero\ Feroze",
"924599", "Mianwali",
"92635", "Bahawalnagar",
"929329", "Malakand",
"92482", "Sargodha",
"925442", "Jhelum",
"925428", "Narowal",
"92472", "Jhang",
"925432", "Chakwal",
"929965", "Shangla",
"928287", "Musakhel",
"929969", "Shangla",
"928442", "Kalat",
"929454", "Lower\ Dir",
"928432", "Mastung",
"929637", "Tank",
"92558", "Gujranwala",
"922384", "Umerkot",
"928247", "Loralai",
"922443", "Nawabshah",
"922433", "Khairpur",
"928237", "Killa\ Saifullah",
"92682", "Rahim\ Yar\ Khan",
"92554", "Gujranwala",
"928482", "Khuzdar",
"92553", "Gujranwala",
"922334", "Mirpur\ Khas",
"922988", "Thatta",
"92463", "Toba\ Tek\ Singh",
"929445", "Upper\ Dir",
"92667", "Muzaffargarh",
"92869", "Gwadar",
"92464", "Toba\ Tek\ Singh",
"929435", "Chitral",
"922447", "Nawabshah",
"928243", "Loralai",
"929439", "Chitral",
"922336", "Mirpur\ Khas",
"928268", "K\.Abdullah\/Pishin",
"928233", "Killa\ Saifullah",
"922437", "Khairpur",
"929449", "Upper\ Dir",
"92569", "Sheikhupura",
"92917", "Peshawar\/Charsadda",
"929668", "D\.I\.\ Khan",
"92468", "Toba\ Tek\ Singh",
"928378", "Jhal\ Magsi",
"922355", "Sanghar",
"929633", "Tank",
"922386", "Umerkot",
"928283", "Musakhel",
"929456", "Lower\ Dir",
"922359", "Sanghar",
"92424", "Lahore",
"92627", "Bahawalpur",
"924547", "Khushab",
"92423", "Lahore",
"928357", "Dera\ Bugti",
"924537", "Bhakkar",
"928489", "Khuzdar",
"926044", "Rajanpur",
"92492", "Kasur",
"92529", "Sialkot",
"928566", "Awaran",
"928485", "Khuzdar",
"929378", "Mardan",
"927264", "Shikarpur",
"92817", "Quetta",
"929923", "Abottabad",
"92619", "Multan",
"926084", "Lodhran",
"928449", "Kalat",
"929962", "Shangla",
"925435", "Chakwal",
"92428", "Lahore",
"92649", "Dera\ Ghazi\ Khan",
"929976", "Mansehra\/Batagram",
"928439", "Mastung",
"925445", "Jhelum",
"92636", "Bahawalnagar",
"92517", "Islamabad\/Rawalpindi",
"925449", "Jhelum",
"928435", "Mastung",
"925439", "Chakwal",
"928445", "Kalat",
"929974", "Mansehra\/Batagram",
"922352", "Sanghar",
"92405", "Sahiwal",
"927266", "Shikarpur",
"92532", "Gujrat",
"926086", "Lodhran",
"929927", "Abottabad",
"92227", "Hyderabad",
"929432", "Chitral",
"92575", "Attock",
"926046", "Rajanpur",
"929428", "Bajaur\ Agency",
"929442", "Upper\ Dir",
"9258", "AJK\/FATA",
"924543", "Khushab",
"924533", "Bhakkar",
"928353", "Dera\ Bugti",
"928564", "Awaran",
"92219", "Karachi",
"928282", "Musakhel",
"925437", "Chakwal",
"925447", "Jhelum",
"928437", "Mastung",
"929632", "Tank",
"928336", "Sibi\/Ziarat",
"922976", "Badin",
"92658", "Khanewal",
"928447", "Kalat",
"928232", "Killa\ Saifullah",
"924545", "Khushab",
"928228", "Zhob",
"928242", "Loralai",
"928355", "Dera\ Bugti",
"924535", "Bhakkar",
"928359", "Dera\ Bugti",
"924539", "Bhakkar",
"92654", "Khanewal",
"928487", "Khuzdar",
"924549", "Khushab",
"928386", "Jaffarabad\/Nasirabad",
"92653", "Khanewal",
"928483", "Khuzdar",
"92713", "Sukkur",
"92258", "Dadu",
"92744", "Larkana",
"92743", "Larkana",
"92567", "Sheikhupura",
"92714", "Sukkur",
"92919", "Peshawar\/Charsadda",
"92686", "Rahim\ Yar\ Khan",
"928384", "Jaffarabad\/Nasirabad",
"922432", "Khairpur",
"92669", "Muzaffargarh",
"92867", "Gwadar",
"922428", "Naushero\ Feroze",
"922442", "Nawabshah",
"928433", "Mastung",
"92253", "Dadu",
"92718", "Sukkur",
"928443", "Kalat",
"92254", "Dadu",
"92748", "Larkana",
"92927", "Karak",
"929929", "Abottabad",
"925433", "Chakwal",
"928334", "Sibi\/Ziarat",
"929925", "Abottabad",
"922974", "Badin",
"925443", "Jhelum",
"92476", "Jhang",
"928558", "Panjgur",
"925468", "Mandi\ Bahauddin",
"92527", "Sialkot",
"928524", "Kech",
"928352", "Dera\ Bugti",
"924532", "Bhakkar",
"928245", "Loralai",
"929656", "South\ Waziristan",
"929398", "Buner",
"924542", "Khushab",
"928235", "Killa\ Saifullah",
"92448", "Okara",
"92629", "Bahawalpur",
"929468", "Swat",
"929443", "Upper\ Dir",
"928239", "Killa\ Saifullah",
"92418", "Faisalabad",
"928249", "Loralai",
"929433", "Chitral",
"92519", "Islamabad\/Rawalpindi",
"929639", "Tank",
"929967", "Shangla",
"929384", "Swabi",
"928285", "Musakhel",
"92443", "Okara",
"92819", "Quetta",
"92414", "Faisalabad",
"922353", "Sanghar",
"92536", "Gujrat",
"92617", "Multan",
"928289", "Musakhel",
"927226", "Jacobabad",
"92413", "Faisalabad",
"92444", "Okara",
"929635", "Tank",
"92647", "Dera\ Ghazi\ Khan",
"928256", "Chagai",
"922357", "Sanghar",
"929386", "Swabi",
"92485", "Sargodha",
"92229", "Hyderabad",
"92632", "Bahawalnagar",
"929228", "Kohat",
"928254", "Chagai",
"929922", "Abottabad",
"929963", "Shangla",
"927224", "Jacobabad",
"929654", "South\ Waziristan",
"922439", "Khairpur",
"929447", "Upper\ Dir",
"92675", "Vehari",
"929437", "Chitral",
"922449", "Nawabshah",
"928526", "Kech",
"92217", "Karachi",
"92496", "Kasur",
"922445", "Nawabshah",
"922435", "Khairpur",
"929978", "Mansehra\/Batagram",
"92218", "Karachi",
"927237", "Ghotki",
"92685", "Rahim\ Yar\ Khan",
"929424", "Bajaur\ Agency",
"928568", "Awaran",
"926067", "Layyah",
"929323", "Malakand",
"92475", "Jhang",
"92213", "Karachi",
"924593", "Mianwali",
"92214", "Karachi",
"929376", "Mardan",
"928533", "Lasbela",
"924597", "Mianwali",
"92648", "Dera\ Ghazi\ Khan",
"926048", "Rajanpur",
"92429", "Lahore",
"926063", "Layyah",
"929327", "Malakand",
"929426", "Bajaur\ Agency",
"92618", "Multan",
"928537", "Lasbela",
"922329", "Tharparkar",
"92524", "Sialkot",
"929374", "Mardan",
"922325", "Tharparkar",
"92523", "Sialkot",
"924572", "Pakpattan",
"92643", "Dera\ Ghazi\ Khan",
"927233", "Ghotki",
"92614", "Multan",
"92417", "Faisalabad",
"92613", "Multan",
"92644", "Dera\ Ghazi\ Khan",
"926088", "Lodhran",
"92447", "Okara",
"927268", "Shikarpur",
"92528", "Sialkot",
"92863", "Gwadar",
"92486", "Sargodha",
"92864", "Gwadar",
"92469", "Toba\ Tek\ Singh",
"922984", "Thatta",
"929953", "Haripur",
"92747", "Larkana",
"92563", "Sheikhupura",
"928293", "Barkhan\/Kohlu",
"92928", "Bannu\/N\.\ Waziristan",
"92564", "Sheikhupura",
"928264", "K\.Abdullah\/Pishin",
"92717", "Sukkur",
"92868", "Gwadar",
"925426", "Narowal",
"929693", "Lakki\ Marwat",
"92676", "Vehari",
"925473", "Hafizabad",
"928374", "Jhal\ Magsi",
"929664", "D\.I\.\ Khan",
"92568", "Sheikhupura",
"92923", "Nowshera",
"928327", "Bolan",
"92257", "Dadu",
"928473", "Kharan",
"92495", "Kasur",
"92924", "Khyber\/Mohmand\ Agy",
"928376", "Jhal\ Magsi",
"929666", "D\.I\.\ Khan",
"928477", "Kharan",
"925424", "Narowal",
"928323", "Bolan",
"922388", "Umerkot",
"929697", "Lakki\ Marwat",
"92572", "Attock",
"925477", "Hafizabad",
"929458", "Lower\ Dir",
"922986", "Thatta",
"92657", "Khanewal",
"928297", "Barkhan\/Kohlu",
"929957", "Haripur",
"924579", "Pakpattan",
"922338", "Mirpur\ Khas",
"924575", "Pakpattan",
"928266", "K\.Abdullah\/Pishin",
"92559", "Gujranwala",
"92402", "Sahiwal",
"922322", "Tharparkar",
"92535", "Gujrat",};
my $timezones = {
               '' => [
                       'Asia/Karachi'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+92|\D)//g;
      my $self = bless({ country_code => '92', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '92', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;