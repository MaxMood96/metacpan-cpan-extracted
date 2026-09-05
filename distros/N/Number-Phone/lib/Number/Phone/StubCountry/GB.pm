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
package Number::Phone::StubCountry::GB;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101549;

my $formatters = [
                {
                  'format' => '$1 $2',
                  'leading_digits' => '8001111',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '845464',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{2})(\\d{2})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '800',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{6})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            1(?:
              3873|
              5(?:
                242|
                39[4-6]
              )|
              (?:
                697|
                768
              )[347]|
              9467
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{5})(\\d{4,5})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            1(?:
              [2-69][02-9]|
              [78]
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{5,6})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            [25]|
            7(?:
              0|
              6(?:
                [03-9]|
                2[356]
              )
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{4})(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '7',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{6})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[1389]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{4})'
                }
              ];

my $validators = {
                'fixed_line' => '
          (?:
            1(?:
              1(?:
                3(?:
                  [0-58]\\d\\d|
                  73[0-5]
                )|
                4(?:
                  (?:
                    [0-5]\\d|
                    70
                  )\\d|
                  69[7-9]
                )|
                (?:
                  (?:
                    5[0-26-9]|
                    [78][0-49]
                  )\\d|
                  6(?:
                    [0-4]\\d|
                    5[01]
                  )
                )\\d
              )|
              (?:
                2(?:
                  (?:
                    0[024-9]|
                    2[3-9]|
                    3[3-79]|
                    4[1-689]|
                    [58][02-9]|
                    6[0-47-9]|
                    7[013-9]|
                    9\\d
                  )\\d|
                  1(?:
                    [0-7]\\d|
                    8[0-3]
                  )
                )|
                (?:
                  3(?:
                    0\\d|
                    1[0-8]|
                    [25][02-9]|
                    3[02-579]|
                    [468][0-46-9]|
                    7[1-35-79]|
                    9[2-578]
                  )|
                  4(?:
                    0[03-9]|
                    [137]\\d|
                    [28][02-57-9]|
                    4[02-69]|
                    5[0-8]|
                    [69][0-79]
                  )|
                  5(?:
                    0[1-35-9]|
                    [16]\\d|
                    2[024-9]|
                    3[015689]|
                    4[02-9]|
                    5[03-9]|
                    7[0-35-9]|
                    8[0-468]|
                    9[0-57-9]
                  )|
                  6(?:
                    0[034689]|
                    1\\d|
                    2[0-35689]|
                    [38][013-9]|
                    4[1-467]|
                    5[0-69]|
                    6[13-9]|
                    7[0-8]|
                    9[0-24578]
                  )|
                  7(?:
                    0[0246-9]|
                    2\\d|
                    3[0236-8]|
                    4[03-9]|
                    5[0-46-9]|
                    6[013-9]|
                    7[0-35-9]|
                    8[024-9]|
                    9[02-9]
                  )|
                  8(?:
                    0[35-9]|
                    2[1-57-9]|
                    3[02-578]|
                    4[0-578]|
                    5[124-9]|
                    6[2-69]|
                    7\\d|
                    8[02-9]|
                    9[02569]
                  )|
                  9(?:
                    0[02-589]|
                    [18]\\d|
                    2[02-689]|
                    3[1-57-9]|
                    4[2-9]|
                    5[0-579]|
                    6[2-47-9]|
                    7[0-24578]|
                    9[2-57]
                  )
                )\\d
              )\\d
            )|
            2(?:
              0[013478]|
              3[0189]|
              4[017]|
              8[0-46-9]|
              9[0-2]
            )\\d{3}
          )\\d{4}|
          1(?:
            2(?:
              0(?:
                46[1-4]|
                87[2-9]
              )|
              545[1-79]|
              76(?:
                2\\d|
                3[1-8]|
                6[1-6]
              )|
              9(?:
                7(?:
                  2[0-4]|
                  3[2-5]
                )|
                8(?:
                  2[2-8]|
                  7[0-47-9]|
                  8[3-5]
                )
              )
            )|
            3(?:
              6(?:
                38[2-5]|
                47[23]
              )|
              8(?:
                47[04-9]|
                64[0157-9]
              )
            )|
            4(?:
              044[1-7]|
              20(?:
                2[23]|
                8\\d
              )|
              6(?:
                0(?:
                  30|
                  5[2-57]|
                  6[1-8]|
                  7[2-8]
                )|
                140
              )|
              8(?:
                052|
                87[1-3]
              )
            )|
            5(?:
              2(?:
                4(?:
                  3[2-79]|
                  6\\d
                )|
                76\\d
              )|
              6(?:
                26[06-9]|
                686
              )
            )|
            6(?:
              06(?:
                4\\d|
                7[4-79]
              )|
              295[5-7]|
              35[34]\\d|
              47(?:
                24|
                61
              )|
              59(?:
                5[08]|
                6[67]|
                74
              )|
              9(?:
                55[0-4]|
                77[23]
              )
            )|
            7(?:
              26(?:
                6[13-9]|
                7[0-7]
              )|
              (?:
                442|
                688
              )\\d|
              50(?:
                2[0-3]|
                [3-68]2|
                76
              )
            )|
            8(?:
              27[56]\\d|
              37(?:
                5[2-5]|
                8[239]
              )|
              843[2-58]
            )|
            9(?:
              0(?:
                0(?:
                  6[1-8]|
                  85
                )|
                52\\d
              )|
              3583|
              4(?:
                66[1-8]|
                9(?:
                  2[01]|
                  81
                )
              )|
              63(?:
                23|
                3[1-4]
              )|
              9561
            )
          )\\d{3}
        ',
                'geographic' => '
          (?:
            1(?:
              1(?:
                3(?:
                  [0-58]\\d\\d|
                  73[0-5]
                )|
                4(?:
                  (?:
                    [0-5]\\d|
                    70
                  )\\d|
                  69[7-9]
                )|
                (?:
                  (?:
                    5[0-26-9]|
                    [78][0-49]
                  )\\d|
                  6(?:
                    [0-4]\\d|
                    5[01]
                  )
                )\\d
              )|
              (?:
                2(?:
                  (?:
                    0[024-9]|
                    2[3-9]|
                    3[3-79]|
                    4[1-689]|
                    [58][02-9]|
                    6[0-47-9]|
                    7[013-9]|
                    9\\d
                  )\\d|
                  1(?:
                    [0-7]\\d|
                    8[0-3]
                  )
                )|
                (?:
                  3(?:
                    0\\d|
                    1[0-8]|
                    [25][02-9]|
                    3[02-579]|
                    [468][0-46-9]|
                    7[1-35-79]|
                    9[2-578]
                  )|
                  4(?:
                    0[03-9]|
                    [137]\\d|
                    [28][02-57-9]|
                    4[02-69]|
                    5[0-8]|
                    [69][0-79]
                  )|
                  5(?:
                    0[1-35-9]|
                    [16]\\d|
                    2[024-9]|
                    3[015689]|
                    4[02-9]|
                    5[03-9]|
                    7[0-35-9]|
                    8[0-468]|
                    9[0-57-9]
                  )|
                  6(?:
                    0[034689]|
                    1\\d|
                    2[0-35689]|
                    [38][013-9]|
                    4[1-467]|
                    5[0-69]|
                    6[13-9]|
                    7[0-8]|
                    9[0-24578]
                  )|
                  7(?:
                    0[0246-9]|
                    2\\d|
                    3[0236-8]|
                    4[03-9]|
                    5[0-46-9]|
                    6[013-9]|
                    7[0-35-9]|
                    8[024-9]|
                    9[02-9]
                  )|
                  8(?:
                    0[35-9]|
                    2[1-57-9]|
                    3[02-578]|
                    4[0-578]|
                    5[124-9]|
                    6[2-69]|
                    7\\d|
                    8[02-9]|
                    9[02569]
                  )|
                  9(?:
                    0[02-589]|
                    [18]\\d|
                    2[02-689]|
                    3[1-57-9]|
                    4[2-9]|
                    5[0-579]|
                    6[2-47-9]|
                    7[0-24578]|
                    9[2-57]
                  )
                )\\d
              )\\d
            )|
            2(?:
              0[013478]|
              3[0189]|
              4[017]|
              8[0-46-9]|
              9[0-2]
            )\\d{3}
          )\\d{4}|
          1(?:
            2(?:
              0(?:
                46[1-4]|
                87[2-9]
              )|
              545[1-79]|
              76(?:
                2\\d|
                3[1-8]|
                6[1-6]
              )|
              9(?:
                7(?:
                  2[0-4]|
                  3[2-5]
                )|
                8(?:
                  2[2-8]|
                  7[0-47-9]|
                  8[3-5]
                )
              )
            )|
            3(?:
              6(?:
                38[2-5]|
                47[23]
              )|
              8(?:
                47[04-9]|
                64[0157-9]
              )
            )|
            4(?:
              044[1-7]|
              20(?:
                2[23]|
                8\\d
              )|
              6(?:
                0(?:
                  30|
                  5[2-57]|
                  6[1-8]|
                  7[2-8]
                )|
                140
              )|
              8(?:
                052|
                87[1-3]
              )
            )|
            5(?:
              2(?:
                4(?:
                  3[2-79]|
                  6\\d
                )|
                76\\d
              )|
              6(?:
                26[06-9]|
                686
              )
            )|
            6(?:
              06(?:
                4\\d|
                7[4-79]
              )|
              295[5-7]|
              35[34]\\d|
              47(?:
                24|
                61
              )|
              59(?:
                5[08]|
                6[67]|
                74
              )|
              9(?:
                55[0-4]|
                77[23]
              )
            )|
            7(?:
              26(?:
                6[13-9]|
                7[0-7]
              )|
              (?:
                442|
                688
              )\\d|
              50(?:
                2[0-3]|
                [3-68]2|
                76
              )
            )|
            8(?:
              27[56]\\d|
              37(?:
                5[2-5]|
                8[239]
              )|
              843[2-58]
            )|
            9(?:
              0(?:
                0(?:
                  6[1-8]|
                  85
                )|
                52\\d
              )|
              3583|
              4(?:
                66[1-8]|
                9(?:
                  2[01]|
                  81
                )
              )|
              63(?:
                23|
                3[1-4]
              )|
              9561
            )
          )\\d{3}
        ',
                'mobile' => '
          7(?:
            457[0-57-9]|
            700[01]|
            911[028]
          )\\d{5}|
          7(?:
            [1-3]\\d\\d|
            4(?:
              [0-46-9]\\d|
              5[0-689]
            )|
            5(?:
              0[0-8]|
              [13-9]\\d|
              2[0-35-9]
            )|
            7(?:
              0[1-9]|
              [1-7]\\d|
              8[02-9]|
              9[0-689]
            )|
            8(?:
              [014-9]\\d|
              [23][0-8]
            )|
            9(?:
              [024-9]\\d|
              1[02-9]|
              3[0-689]
            )
          )\\d{6}
        ',
                'pager' => '
          76(?:
            464|
            652
          )\\d{5}|
          76(?:
            0[0-28]|
            2[356]|
            34|
            4[01347]|
            5[49]|
            6[0-369]|
            77|
            8[14]|
            9[139]
          )\\d{6}
        ',
                'personal_number' => '70\\d{8}',
                'specialrate' => '(
          (?:
            8(?:
              4[2-5]|
              7[0-3]
            )|
            9(?:
              [01]\\d|
              8[2-49]
            )
          )\\d{7}|
          845464\\d
        )|(
          (?:
            3[0347]|
            55
          )\\d{8}
        )',
                'toll_free' => '
          80[08]\\d{7}|
          800\\d{6}|
          8001111
        ',
                'voip' => '56\\d{8}'
              };
my %areanames = ();
$areanames{en} = {"4419641", "Hornsea\/Patrington",
"4418906", "Ayton",
"441583", "Carradale",
"441957", "Mid\ Yell",
"4418514", "Great\ Bernera",
"4418518", "Stornoway",
"441903", "Worthing",
"441458", "Glastonbury",
"44291", "Cardiff",
"441697", "Brampton",
"441560", "Moscow",
"441914", "Tyneside",
"441543", "Cannock",
"441871", "Castlebay",
"4414235", "Harrogate",
"4418900", "Coldstream\/Ayton",
"441672", "Marlborough",
"441896", "Galashiels",
"441568", "Leominster",
"4415242", "Hornby",
"441666", "Malmesbury",
"441450", "Hawick",
"4414341", "Bellingham\/Haltwhistle\/Hexham",
"4419757", "Strathdon",
"441830", "Kirkwhelpington",
"441547", "Knighton",
"441279", "Bishops\ Stortford",
"441840", "Camelford",
"441400", "Honington",
"441848", "Thornhill",
"441822", "Tavistock",
"441408", "Golspie",
"441275", "Clevedon",
"441664", "Melton\ Mowbray",
"441621", "Maldon",
"441863", "Ardgay",
"441838", "Dalmally",
"441916", "Tyneside",
"441770", "Isle\ of\ Arran",
"441499", "Inveraray",
"441880", "Tarbert",
"441953", "Wymondham",
"44114702", "Sheffield",
"4418513", "Stornoway",
"441888", "Turriff",
"441778", "Bourne",
"441495", "Pontypool",
"441369", "Dunoon",
"4419647", "Patrington",
"4418478", "Thurso",
"4418474", "Thurso",
"442868", "Kesh",
"442843", "Newcastle\ \(Co\.\ Down\)",
"441293", "Crawley",
"441757", "Selby",
"441675", "Coleshill",
"441931", "Shap",
"441264", "Andover",
"44141", "Glasgow",
"4416864", "Llanidloes",
"4416868", "Newtown",
"4414372", "Clynderwen\ \(Clunderwen\)",
"4413393", "Aboyne",
"441981", "Wormbridge",
"442883", "Northern\ Ireland",
"441473", "Ipswich",
"441501", "Harthill",
"441327", "Daventry",
"4413398", "Aboyne",
"4413394", "Ballater",
"4412295", "Barrow\-in\-Furness",
"441376", "Braintree",
"4414379", "Haverfordwest",
"441323", "Eastbourne",
"442887", "Dungannon",
"441477", "Holmes\ Chapel",
"4416863", "Llanidloes",
"4419751", "Alford\ \(Aberdeen\)\/Strathdon",
"4414347", "Hexham",
"441362", "Dereham",
"441492", "Colwyn\ Bay",
"441424", "Hastings",
"441461", "Gretna",
"441707", "Welwyn\ Garden\ City",
"441753", "Slough",
"442847", "Northern\ Ireland",
"441297", "Axminster",
"441829", "Tarporley",
"441970", "Aberystwyth",
"442837", "Armagh",
"441978", "Wrexham",
"4418473", "Thurso",
"441825", "Uckfield",
"4419755", "Alford\ \(Aberdeen\)",
"441606", "Northwich",
"441725", "Rockbourne",
"441282", "Burnley",
"441988", "Wigtown",
"4412291", "Barrow\-in\-Furness\/Millom",
"441508", "Brooke",
"441980", "Amesbury",
"441346", "Fraserburgh",
"441807", "Ballindalloch",
"441654", "Machynlleth",
"4417684", "Pooley\ Bridge",
"441729", "Settle",
"441922", "Walsall",
"441948", "Whitchurch",
"4413880", "Bishop\ Auckland\/Stanhope\ \(Eastgate\)",
"442824", "Northern\ Ireland",
"441595", "Lerwick\,\ Foula\ \&\ Fair\ Isle",
"441963", "Wincanton",
"441938", "Welshpool",
"441994", "St\ Clears",
"441355", "East\ Kilbride",
"441228", "Carlisle",
"442892", "Lisburn",
"441242", "Cheltenham",
"442877", "Limavady",
"441487", "Warboys",
"441359", "Pakenham",
"441386", "Evesham",
"441599", "Kyle",
"441971", "Scourie",
"441309", "Forres",
"441635", "Newbury",
"441483", "Guildford",
"442826", "Northern\ Ireland",
"44238", "Southampton",
"441967", "Strontian",
"441384", "Dudley",
"441305", "Dorchester",
"44281", "Northern\ Ireland",
"441639", "Neath",
"441550", "Llandovery",
"441685", "Merthyr\ Tydfil",
"441433", "Hathersage",
"441143", "Sheffield",
"441604", "Northampton",
"441857", "Sanday",
"441803", "Torquay",
"441443", "Pontypridd",
"4414237", "Harrogate",
"441460", "Chard",
"441656", "Bridgend",
"4415396", "Sedbergh",
"441398", "Dulverton",
"4417683", "Appleby",
"441334", "St\ Andrews",
"441689", "Orpington",
"441558", "Llandeilo",
"441344", "Bracknell",
"441788", "Rugby",
"441245", "Chelmsford",
"442895", "Belfast",
"441878", "Lochboisdale",
"441352", "Mold",
"441561", "Laurencekirk",
"4412297", "Millom",
"441524", "Lancaster",
"441235", "Abingdon",
"441592", "Kirkcaldy",
"4414345", "Haltwhistle",
"441925", "Warrington",
"441239", "Cardigan",
"441577", "Kinross",
"441929", "Wareham",
"441451", "Stow\-on\-the\-Wold",
"441870", "Isle\ of\ Benbecula",
"442899", "Northern\ Ireland",
"441780", "Stamford",
"441249", "Chippenham",
"441738", "Perth",
"4415073", "Louth",
"441794", "Romsey",
"4414303", "North\ Cave",
"441204", "Bolton",
"441748", "Richmond",
"441722", "Salisbury",
"441285", "Cirencester",
"441763", "Royston",
"441740", "Sedgefield",
"441289", "Berwick\-upon\-Tweed",
"441256", "Basingstoke",
"441730", "Petersfield",
"441771", "Maud",
"4414308", "Market\ Weighton",
"4414304", "North\ Cave",
"441206", "Colchester",
"4419645", "Hornsea",
"441796", "Pitlochry",
"4415078", "Alford\ \(Lincs\)",
"4415074", "Alford\ \(Lincs\)",
"441254", "Blackburn",
"441767", "Sandy",
"441573", "Kelso",
"441841", "Newquay\ \(Padstow\)",
"441642", "Middlesbrough",
"441628", "Maidenhead",
"441526", "Martin",
"441302", "Doncaster",
"44151", "Liverpool",
"441620", "North\ Berwick",
"4414231", "Harrogate\/Boroughbridge",
"4418475", "Thurso",
"441341", "Barmouth",
"441287", "Guisborough",
"441420", "Alton",
"441428", "Haslemere",
"441442", "Hemel\ Hempstead",
"4414307", "Market\ Weighton",
"4415077", "Louth",
"441432", "Hereford",
"441142", "Sheffield",
"442897", "Saintfield",
"4413882", "Stanhope\ \(Eastgate\)",
"441237", "Bideford",
"441381", "Fortrose",
"441579", "Liskeard",
"441575", "Kirriemuir",
"4416865", "Newtown",
"442866", "Enniskillen",
"4412293", "Millom",
"441974", "Llanon",
"441482", "Kingston\-upon\-Hull",
"441260", "Congleton",
"44114705", "Sheffield",
"4413395", "Aboyne",
"441268", "Basildon",
"4412294", "Barrow\-in\-Furness",
"4412298", "Barrow\-in\-Furness",
"442893", "Ballyclare",
"441243", "Chichester",
"441923", "Watford",
"442821", "Martinstown",
"441233", "Ashford\ \(Kent\)",
"441962", "Winchester",
"441852", "Kilmelford",
"441769", "South\ Molton",
"44114707", "Sheffield",
"441651", "Oldmeldrum",
"441765", "Ripon",
"441283", "Burton\-on\-Trent",
"441456", "Glenurquhart",
"441597", "Llandrindod\ Wells",
"441489", "Bishops\ Waltham",
"442879", "Magherafelt",
"441357", "Strathaven",
"4418515", "Stornoway",
"44283", "Northern\ Ireland",
"441303", "Folkestone",
"441485", "Hunstanton",
"4415071", "Louth\/Alford\ \(Lincs\)\/Spilsby\ \(Horncastle\)",
"441566", "Launceston",
"441633", "Newport",
"4414301", "North\ Cave\/Market\ Weighton",
"441834", "Narberth",
"441668", "Bamburgh",
"441572", "Oakham",
"441643", "Minehead",
"441844", "Thame",
"441404", "Honiton",
"4414238", "Harrogate",
"4414234", "Boroughbridge",
"441449", "Stowmarket",
"441809", "Tomdoun",
"44117", "Bristol",
"441727", "St\ Albans",
"441439", "Helmsley",
"441435", "Heathfield",
"441145", "Sheffield",
"441683", "Moffat",
"441884", "Tiverton",
"441805", "Torrington",
"441445", "Gairloch",
"441687", "Mallaig",
"4417687", "Keswick",
"4414233", "Boroughbridge",
"441855", "Ballachulish",
"441723", "Scarborough",
"441859", "Harris",
"441886", "Bromyard\ \(Knightwick\/Leigh\ Sinton\)",
"441776", "Stranraer",
"441637", "Newquay",
"441910", "Tyneside\/Durham\/Sunderland",
"441969", "Leyburn",
"441647", "Moretonhampstead",
"441454", "Chipping\ Sodbury",
"441593", "Lybster",
"441406", "Holbeach",
"441564", "Lapworth",
"441307", "Forfar",
"441353", "Ely",
"441918", "Tyneside",
"441329", "Fareham",
"441736", "Penzance",
"441250", "Blairgowrie",
"441746", "Bridgnorth",
"4413397", "Ballater",
"441952", "Telford",
"441258", "Blandford",
"4414348", "Hexham",
"441325", "Darlington",
"4414344", "Bellingham",
"441786", "Stirling",
"441876", "Lochmaddy",
"441692", "North\ Walsham",
"441823", "Taunton",
"441661", "Prudhoe",
"441624", "Isle\ of\ Man",
"441862", "Tain",
"441759", "Pocklington",
"4419643", "Patrington",
"4418902", "Coldstream",
"4413873", "Langholm",
"441677", "Bedale",
"4418511", "Great\ Bernera\/Stornoway",
"441626", "Newton\ Abbot",
"442845", "Northern\ Ireland",
"441295", "Banbury",
"4418477", "Tongue",
"441542", "Keith",
"441528", "Laggan",
"441874", "Brecon",
"441911", "Tyneside\/Durham\/Sunderland",
"441673", "Market\ Rasen",
"441784", "Staines",
"44161", "Manchester",
"4418909", "Ayton",
"441520", "Lochcarron",
"44287", "Northern\ Ireland",
"4414305", "North\ Cave",
"441299", "Bewdley",
"442849", "Northern\ Ireland",
"441709", "Rotherham",
"4415075", "Spilsby\ \(Horncastle\)",
"44118", "Reading",
"4419644", "Patrington",
"4419648", "Hornsea",
"441827", "Tamworth",
"441582", "Luton",
"441744", "St\ Helens",
"441902", "Wolverhampton",
"441208", "Bodmin",
"442885", "Ballygawley",
"441475", "Greenock",
"441798", "Pulborough",
"441479", "Grantown\-on\-Spey",
"441790", "Spilsby",
"442889", "Fivemiletown",
"4414343", "Haltwhistle",
"441200", "Clitheroe",
"4416867", "Llanidloes",
"44113", "Leeds",
"441865", "Oxford",
"441380", "Devizes",
"441946", "Whitehaven",
"441273", "Brighton",
"441695", "Skelmersdale",
"441226", "Barnsley",
"4419754", "Alford\ \(Aberdeen\)",
"4419758", "Strathdon",
"4414376", "Haverfordwest",
"441388", "Bishop\ Auckland",
"441752", "Plymouth",
"44121", "Birmingham",
"441869", "Bicester",
"4413391", "Aboyne\/Ballater",
"441608", "Chipping\ Norton",
"441330", "Banchory",
"44239", "Portsmouth",
"441959", "Westerham",
"441464", "Insch",
"4414370", "Haverfordwest\/Clynderwen\ \(Clunderwen\)",
"441340", "Craigellachie\ \(Aberlour\)",
"441506", "Bathgate",
"441986", "Bungay",
"441493", "Great\ Yarmouth",
"441348", "Fishguard",
"441322", "Dartford",
"441554", "Llanelli",
"441363", "Crediton",
"441600", "Monmouth",
"441394", "Felixstowe",
"441955", "Wick",
"441367", "Faringdon",
"442882", "Omagh",
"441472", "Grimsby",
"441984", "Watchet\ \(Williton\)",
"441905", "Worcester",
"441650", "Cemmaes\ Road",
"441466", "Huntly",
"4418517", "Stornoway",
"4418471", "Thurso\/Tongue",
"441371", "Great\ Dunmow",
"441909", "Worksop",
"441497", "Hay\-on\-Wye",
"441556", "Castle\ Douglas",
"441224", "Aberdeen",
"441261", "Banff",
"441934", "Weston\-super\-Mare",
"441545", "Llanarth",
"442842", "Kircubbin",
"441292", "Ayr",
"442828", "Larne",
"441702", "Southend\-on\-Sea",
"441944", "West\ Heslerton",
"441535", "Keighley",
"44114703", "Sheffield",
"441277", "Brentwood",
"441539", "Kendal",
"442820", "Ballycastle",
"4416861", "Newtown\/Llanidloes",
"441549", "Lairg",
"4419753", "Strathdon",
"44114704", "Sheffield",
"441726", "St\ Austell",
"4413881", "Bishop\ Auckland\/Stanhope\ \(Eastgate\)",
"441950", "Sandwick",
"441349", "Dingwall",
"441773", "Ripley",
"441684", "Malvern",
"441883", "Caterham",
"44241", "Coventry",
"441252", "Aldershot",
"4412296", "Barrow\-in\-Furness",
"441609", "Northallerton",
"441335", "Ashbourne",
"441389", "Dumbarton",
"441457", "Glossop",
"441644", "New\ Galloway",
"441403", "Horsham",
"441571", "Lochinver",
"441843", "Thanet",
"441698", "Motherwell",
"441356", "Brechin",
"441634", "Medway",
"4412290", "Barrow\-in\-Furness\/Millom",
"441833", "Barnard\ Castle",
"441690", "Betws\-y\-Coed",
"441304", "Dover",
"441567", "Killin",
"441563", "Kilmarnock",
"441995", "Garstang",
"441354", "Chatteris",
"441522", "Lincoln",
"441548", "Kingsbridge",
"441636", "Newark\-on\-Trent",
"441594", "Lydney",
"442825", "Ballymena",
"441646", "Milford\ Haven",
"441538", "Ipstones",
"441407", "Holyhead",
"441453", "Dursley",
"441530", "Coalville",
"442829", "Kilrea",
"441837", "Okehampton",
"441306", "Dorking",
"441540", "Kingussie",
"441792", "Swansea",
"441202", "Bournemouth",
"441724", "Scunthorpe",
"441908", "Milton\ Keynes",
"441761", "Temple\ Cloud",
"441659", "Sanquhar",
"441588", "Bishops\ Castle",
"441900", "Workington",
"441580", "Cranbrook",
"441655", "Maybole",
"441887", "Aberfeldy",
"441777", "Retford",
"442871", "Londonderry",
"441481", "Guernsey",
"4416973", "Wigton",
"442896", "Belfast",
"441246", "Chesterfield",
"441926", "Warwick",
"441236", "Coatbridge",
"441750", "Selkirk",
"442867", "Lisnaskea",
"441758", "Pwllheli",
"4419467", "Gosforth",
"441382", "Dundee",
"441431", "Helmsdale",
"441141", "Sheffield",
"441320", "Fort\ Augustus",
"441259", "Alloa",
"441286", "Caernarfon",
"4414302", "North\ Cave",
"4415072", "Spilsby\ \(Horncastle\)",
"441332", "Derby",
"441255", "Clacton\-on\-Sea",
"441328", "Fakenham",
"441342", "East\ Grinstead",
"441284", "Bury\ St\ Edmunds",
"442310", "Portsmouth",
"441205", "Boston",
"441795", "Sittingbourne",
"441478", "Isle\ of\ Skye\ \-\ Portree",
"442888", "Northern\ Ireland",
"441470", "Isle\ of\ Skye\ \-\ Edinbane",
"441799", "Saffron\ Walden",
"442880", "Carrickmore",
"441209", "Redruth",
"4414309", "Market\ Weighton",
"4415079", "Alford\ \(Lincs\)",
"441652", "Brigg",
"4418905", "Ayton",
"4414230", "Harrogate\/Boroughbridge",
"441708", "Romford",
"441924", "Wakefield",
"442822", "Northern\ Ireland",
"441298", "Buxton",
"442848", "Northern\ Ireland",
"4414236", "Harrogate",
"441234", "Bedford",
"441525", "Leighton\ Buzzard",
"4416974", "Raughton\ Head",
"442838", "Portadown",
"441992", "Lea\ Valley",
"441244", "Chester",
"442894", "Antrim",
"442830", "Newry",
"441977", "Pontefract",
"441529", "Sleaford",
"44292", "Cardiff",
"441290", "Cumnock",
"442840", "Banbridge",
"441700", "Rothesay",
"441440", "Haverhill",
"4418519", "Great\ Bernera",
"441987", "Ebbsfleet",
"441140", "Sheffield",
"441553", "Kings\ Lynn",
"441364", "Ashburton",
"441438", "Stevenage",
"441494", "High\ Wycombe",
"4418901", "Coldstream\/Ayton",
"4419646", "Patrington",
"441808", "Tomatin",
"441422", "Halifax",
"441463", "Inverness",
"441669", "Rothbury",
"441947", "Whitby",
"4419640", "Hornsea\/Patrington",
"441751", "Pickering",
"441937", "Wetherby",
"441899", "Biggar",
"441480", "Huntingdon",
"442870", "Coleraine",
"441227", "Canterbury",
"441488", "Hungerford",
"441895", "Uxbridge",
"441665", "Alnwick",
"441274", "Bradford",
"441919", "Durham",
"442841", "Rostrevor",
"441968", "Penicuik",
"441291", "Chepstow",
"4420", "London",
"441943", "Guiseley",
"441276", "Camberley",
"4414346", "Hexham",
"441223", "Cambridge",
"441262", "Bridlington",
"441933", "Wellingborough",
"441915", "Sunderland",
"4418512", "Stornoway",
"441366", "Downham\ Market",
"4414340", "Bellingham\/Haltwhistle\/Hexham",
"441467", "Inverurie",
"441372", "Esher",
"441858", "Market\ Harborough",
"442311", "Southampton",
"441397", "Fort\ William",
"442881", "Newtownstewart",
"441471", "Isle\ of\ Skye\ \-\ Broadford",
"441503", "Looe",
"441557", "Kirkcudbright",
"441496", "Port\ Ellen",
"441983", "Isle\ of\ Wight",
"441787", "Sudbury",
"441877", "Callander",
"4418479", "Tongue",
"441570", "Lampeter",
"441824", "Ruthin",
"441623", "Mansfield",
"441578", "Lauder",
"44114709", "Sheffield",
"4418907", "Ayton",
"441691", "Oswestry",
"441676", "Meriden",
"441892", "Tunbridge\ Wells",
"441737", "Redhill",
"4415395", "Grange\-over\-Sands",
"441747", "Shaftesbury",
"441429", "Hartlepool",
"441951", "Colonsay",
"44114708", "Sheffield",
"441425", "Ringwood",
"4413392", "Aboyne",
"4414373", "Clynderwen\ \(Clunderwen\)",
"4416869", "Newtown",
"441375", "Grays\ Thurrock",
"441760", "Swaffham",
"4413885", "Stanhope\ \(Eastgate\)",
"4414374", "Clynderwen\ \(Clunderwen\)",
"4414378", "Haverfordwest",
"4419756", "Strathdon",
"441733", "Peterborough",
"441379", "Diss",
"441768", "Penrith",
"4413399", "Ballater",
"4416862", "Llanidloes",
"441581", "New\ Luce",
"441743", "Shrewsbury",
"4419750", "Alford\ \(Aberdeen\)\/Strathdon",
"4418472", "Thurso",
"441269", "Ammanford",
"441912", "Tyneside",
"441873", "Abergavenny",
"441674", "Montrose",
"441531", "Ledbury",
"441502", "Lowestoft",
"4414377", "Haverfordwest",
"441474", "Gravesend",
"442884", "Northern\ Ireland",
"441982", "Builth\ Wells",
"4414349", "Bellingham",
"441288", "Bude",
"441745", "Rhyl",
"44131", "Edinburgh",
"441280", "Buckingham",
"441749", "Shepton\ Mallet",
"441373", "Frome",
"441427", "Gainsborough",
"441326", "Falmouth",
"44247", "Coventry",
"442898", "Belfast",
"441248", "Bangor\ \(Gwynedd\)",
"441785", "Stafford",
"441875", "Tranent",
"4418903", "Coldstream",
"4419642", "Hornsea",
"441263", "Cromer",
"441932", "Weybridge",
"441294", "Ardrossan",
"442844", "Downpatrick",
"441942", "Wigan",
"441928", "Runcorn",
"441704", "Southport",
"441756", "Skipton",
"441920", "Ware",
"441879", "Scarinish",
"441789", "Stratford\-upon\-Avon",
"442890", "Belfast",
"441271", "Barnstaple",
"441706", "Rochdale",
"441625", "Macclesfield",
"442846", "Northern\ Ireland",
"441296", "Aylesbury",
"4419649", "Hornsea",
"4418908", "Coldstream",
"4418904", "Coldstream",
"44115", "Nottingham",
"441267", "Carmarthen",
"4418516", "Great\ Bernera",
"441754", "Skegness",
"441629", "Matlock",
"441377", "Driffield",
"4418510", "Great\ Bernera\/Stornoway",
"4414342", "Bellingham",
"441462", "Hitchin",
"441491", "Henley\-on\-Thames",
"442886", "Cookstown",
"441476", "Grantham",
"441324", "Falkirk",
"441361", "Duns",
"441392", "Exeter",
"441534", "Jersey",
"441945", "Wisbech",
"441598", "Lynton",
"441866", "Kilchrenan",
"4413396", "Ballater",
"441935", "Yeovil",
"441544", "Kington",
"441913", "Durham",
"4419759", "Alford\ \(Aberdeen\)",
"441671", "Newton\ Stewart",
"441872", "Truro",
"441358", "Ellon",
"4414371", "Haverfordwest\/Clynderwen\ \(Clunderwen\)",
"441225", "Bath",
"441782", "Stoke\-on\-Trent",
"441939", "Wem",
"441350", "Dunkeld",
"441667", "Nairn",
"441949", "Whatton",
"441590", "Lymington",
"441584", "Ludlow",
"441728", "Saxmundham",
"441904", "York",
"441985", "Warminster",
"441732", "Sevenoaks",
"441505", "Johnstone",
"441989", "Ross\-on\-Wye",
"441509", "Loughborough",
"4413390", "Aboyne\/Ballater",
"441720", "Isles\ of\ Scilly",
"441559", "Llandysul",
"441688", "Isle\ of\ Mull\ \-\ Tobermory",
"441465", "Girvan",
"441586", "Campbeltown",
"441954", "Madingley",
"441395", "Budleigh\ Salterton",
"441469", "Killingholme",
"4418476", "Tongue",
"441680", "Isle\ of\ Mull\ \-\ Craignure",
"441555", "Lanark",
"4416860", "Newtown\/Llanidloes",
"4416866", "Newtown",
"441638", "Newmarket",
"441546", "Lochgilphead",
"441300", "Cerne\ Abbas",
"441694", "Church\ Stretton",
"4419752", "Alford\ \(Aberdeen\)",
"441622", "Maidstone",
"441536", "Kettering",
"4418470", "Thurso\/Tongue",
"441663", "New\ Mills",
"441821", "Kinrossie",
"441864", "Abington\ \(Crawford\)",
"44286", "Northern\ Ireland",
"441630", "Market\ Drayton",
"441308", "Bridport",
"441917", "Sunderland",
"44116", "Leicester",
"441721", "Peebles",
"441764", "Crieff",
"441793", "Swindon",
"441257", "Coppull",
"441670", "Morpeth",
"44114700", "Sheffield",
"441452", "Gloucester",
"4412292", "Barrow\-in\-Furness",
"441576", "Lockerbie",
"4415394", "Hawkshead",
"441591", "Llanwrtyd\ Wells",
"441562", "Kidderminster",
"441678", "Bala",
"44114701", "Sheffield",
"4414375", "Clynderwen\ \(Clunderwen\)",
"441527", "Redditch",
"441301", "Arrochar",
"4412299", "Millom",
"441631", "Oban",
"441832", "Clopton",
"441641", "Strathy",
"441828", "Coupar\ Angus",
"441842", "Thetford",
"441207", "Consett",
"441797", "Rye",
"441253", "Blackpool",
"441681", "Isle\ of\ Mull\ \-\ Fionnphort",
"441772", "Preston",
"441882", "Kinloch\ Rannoch",
"441766", "Porthmadog",
"441455", "Hinckley",
"4415076", "Louth",
"441569", "Stonehaven",
"4414306", "Market\ Weighton",
"441241", "Arbroath",
"442891", "Bangor\ \(Co\.\ Down\)",
"441993", "Witney",
"441565", "Knutsford",
"441387", "Dumfries",
"442823", "Northern\ Ireland",
"441653", "Malton",
"441854", "Ullapool",
"441347", "Easingwold",
"4414300", "North\ Cave\/Market\ Weighton",
"441436", "Helensburgh",
"4415070", "Louth\/Alford\ \(Lincs\)\/Spilsby\ \(Horncastle\)",
"441146", "Sheffield",
"441337", "Ladybank",
"4414239", "Boroughbridge",
"441806", "Shetland",
"441446", "Barry",
"441779", "Peterhead",
"441490", "Corwen",
"441368", "Dunbar",
"441889", "Rugeley",
"441343", "Elgin",
"441856", "Orkney",
"441333", "Peat\ Inn\ \(Leven\ \(Fife\)\)",
"44280", "Northern\ Ireland",
"441603", "Norwich",
"441444", "Haywards\ Heath",
"441885", "Pencombe",
"4414232", "Harrogate",
"441775", "Spalding",
"441360", "Killearn",
"441144", "Sheffield",
"441997", "Strathpeffer",
"441270", "Crewe",
"441409", "Holsworthy",
"442827", "Ballymoney",
"441383", "Dunfermline",
"441405", "Goole",
"441845", "Thirsk",
"441278", "Bridgwater",
"441835", "St\ Boswells",
"441972", "Glenborrodale",
"441484", "Huddersfield",};
my $timezones = {
               '' => [
                       'Europe/Guernsey',
                       'Europe/Isle_of_Man',
                       'Europe/Jersey',
                       'Europe/London'
                     ],
               '1' => [
                        'Europe/London'
                      ],
               '1481' => [
                           'Europe/Guernsey'
                         ],
               '1534' => [
                           'Europe/Jersey'
                         ],
               '1624' => [
                           'Europe/Isle_of_Man'
                         ],
               '2' => [
                        'Europe/London'
                      ],
               '3' => [
                        'Europe/Guernsey',
                        'Europe/Isle_of_Man',
                        'Europe/London'
                      ],
               '5' => [
                        'Europe/Guernsey',
                        'Europe/Isle_of_Man',
                        'Europe/London'
                      ],
               '70' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '71' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '72' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '73' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '74' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '75' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '760' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '762' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '763' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '7640' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '7641' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '7643' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '7644' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '7646' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '765' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '766' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '767' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '768' => [
                          'Europe/Guernsey',
                          'Europe/Isle_of_Man',
                          'Europe/London'
                        ],
               '7693' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '7699' => [
                           'Europe/Guernsey',
                           'Europe/Isle_of_Man',
                           'Europe/London'
                         ],
               '77' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '78' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '79' => [
                         'Europe/Guernsey',
                         'Europe/Isle_of_Man',
                         'Europe/London'
                       ],
               '8' => [
                        'Europe/Guernsey',
                        'Europe/Isle_of_Man',
                        'Europe/London'
                      ],
               '9' => [
                        'Europe/Guernsey',
                        'Europe/Isle_of_Man',
                        'Europe/London'
                      ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+44|\D)//g;
      my $self = bless({ country_code => '44', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0|180020)//;
      $self = bless({ country_code => '44', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;