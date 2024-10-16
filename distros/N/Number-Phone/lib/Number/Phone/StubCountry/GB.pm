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
package Number::Phone::StubCountry::GB;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20240910191015;

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
                  73[0-35]
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
                    50
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
                  73[0-35]
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
                    50
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
$areanames{en} = {"441144", "Sheffield",
"4413882", "Stanhope\ \(Eastgate\)",
"4414340", "Bellingham\/Haltwhistle\/Hexham",
"441724", "Scunthorpe",
"441555", "Lanark",
"441503", "Looe",
"441685", "Merthyr\ Tydfil",
"4414301", "North\ Cave\/Market\ Weighton",
"441228", "Carlisle",
"441440", "Haverhill",
"441671", "Newton\ Stewart",
"441573", "Kelso",
"441644", "New\ Galloway",
"4414377", "Haverfordwest",
"441758", "Pwllheli",
"441254", "Blackburn",
"441994", "St\ Clears",
"441489", "Bishops\ Waltham",
"441267", "Carmarthen",
"4414346", "Hexham",
"441666", "Malmesbury",
"441582", "Luton",
"4419758", "Strathdon",
"441738", "Perth",
"441234", "Bedford",
"441652", "Brigg",
"441535", "Keighley",
"44121", "Birmingham",
"4412298", "Barrow\-in\-Furness",
"441242", "Cheltenham",
"441695", "Skelmersdale",
"442825", "Ballymena",
"441436", "Helensburgh",
"441260", "Congleton",
"441838", "Dalmally",
"441456", "Glenurquhart",
"4414307", "Market\ Weighton",
"441462", "Hitchin",
"441592", "Kirkcaldy",
"441324", "Falkirk",
"441984", "Watchet\ \(Williton\)",
"441858", "Market\ Harborough",
"441499", "Inveraray",
"441569", "Stonehaven",
"441945", "Wisbech",
"441358", "Ellon",
"4414371", "Haverfordwest\/Clynderwen\ \(Clunderwen\)",
"4413398", "Aboyne",
"441824", "Ruthin",
"441807", "Ballindalloch",
"441770", "Isle\ of\ Arran",
"441700", "Rothesay",
"441877", "Callander",
"4419649", "Hornsea",
"441465", "Girvan",
"441595", "Lerwick\,\ Foula\ \&\ Fair\ Isle",
"441942", "Wigan",
"441294", "Ardrossan",
"442848", "Northern\ Ireland",
"441967", "Strontian",
"441307", "Forfar",
"441798", "Pulborough",
"441377", "Driffield",
"441934", "Weston\-super\-Mare",
"441692", "North\ Walsham",
"442822", "Northern\ Ireland",
"441669", "Rothbury",
"441888", "Turriff",
"441954", "Madingley",
"441388", "Bishop\ Auckland",
"441928", "Runcorn",
"4416869", "Newtown",
"4418510", "Great\ Bernera\/Stornoway",
"4418478", "Thurso",
"441544", "Kington",
"441673", "Market\ Rasen",
"441571", "Lochinver",
"441501", "Harthill",
"441603", "Norwich",
"4415075", "Spilsby\ \(Horncastle\)",
"441655", "Maybole",
"441439", "Helmsley",
"4414234", "Boroughbridge",
"441788", "Rugby",
"441284", "Bury\ St\ Edmunds",
"441245", "Chelmsford",
"441300", "Cerne\ Abbas",
"442879", "Magherafelt",
"4418516", "Great\ Bernera",
"441496", "Port\ Ellen",
"441566", "Launceston",
"4414232", "Harrogate",
"441777", "Retford",
"441398", "Dulverton",
"441707", "Welwyn\ Garden\ City",
"441870", "Isle\ of\ Benbecula",
"441635", "Newbury",
"4414303", "North\ Cave",
"4418479", "Tongue",
"441301", "Arrochar",
"441371", "Great\ Dunmow",
"441344", "Bracknell",
"441832", "Clopton",
"441925", "Warrington",
"4416868", "Newtown",
"441279", "Bishops\ Stortford",
"441332", "Derby",
"4415242", "Hornby",
"441427", "Gainsborough",
"441209", "Redruth",
"441885", "Pencombe",
"441844", "Thame",
"441871", "Castlebay",
"442845", "Northern\ Ireland",
"441570", "Lampeter",
"442884", "Northern\ Ireland",
"441443", "Pontypridd",
"4413885", "Stanhope\ \(Eastgate\)",
"441795", "Sittingbourne",
"441352", "Mold",
"441366", "Downham\ Market",
"441598", "Lynton",
"44280", "Northern\ Ireland",
"441866", "Kilchrenan",
"44287", "Northern\ Ireland",
"441852", "Kilmelford",
"441395", "Budleigh\ Salterton",
"4419648", "Hornsea",
"441752", "Plymouth",
"441638", "Newmarket",
"441766", "Porthmadog",
"441895", "Uxbridge",
"441919", "Durham",
"441577", "Kinross",
"441744", "St\ Helens",
"441771", "Maud",
"441785", "Stafford",
"441624", "Isle\ of\ Man",
"441248", "Bangor\ \(Gwynedd\)",
"442894", "Antrim",
"441420", "Alton",
"4414373", "Clynderwen\ \(Clunderwen\)",
"441263", "Cromer",
"44116", "Leicester",
"441588", "Bishops\ Castle",
"441732", "Sevenoaks",
"441782", "Stoke\-on\-Trent",
"441538", "Ipstones",
"4418906", "Ayton",
"441677", "Bedale",
"441276", "Camberley",
"441206", "Colchester",
"441392", "Exeter",
"4418900", "Coldstream\/Ayton",
"441524", "Lancaster",
"441909", "Worksop",
"441369", "Dunoon",
"441773", "Ripley",
"441892", "Tunbridge\ Wells",
"4413399", "Ballater",
"441869", "Bicester",
"441558", "Llandeilo",
"441225", "Bath",
"441688", "Isle\ of\ Mull\ \-\ Tobermory",
"441261", "Banff",
"44281", "Northern\ Ireland",
"442842", "Kircubbin",
"4415074", "Alford\ \(Lincs\)",
"441792", "Swansea",
"441355", "East\ Kilbride",
"441963", "Wincanton",
"441373", "Frome",
"441769", "South\ Molton",
"441303", "Folkestone",
"441916", "Tyneside",
"441873", "Abergavenny",
"441803", "Torquay",
"442867", "Lisnaskea",
"441855", "Ballachulish",
"4414235", "Harrogate",
"441948", "Whitchurch",
"441474", "Gravesend",
"4419759", "Alford\ \(Aberdeen\)",
"441600", "Monmouth",
"441670", "Morpeth",
"4415072", "Spilsby\ \(Horncastle\)",
"441404", "Honiton",
"441382", "Dundee",
"441922", "Walsall",
"441835", "St\ Boswells",
"4412299", "Millom",
"441698", "Motherwell",
"442828", "Larne",
"441335", "Ashbourne",
"441882", "Kinloch\ Rannoch",
"441704", "Southport",
"442891", "Bangor\ \(Co\.\ Down\)",
"4413873", "Langholm",
"4415394", "Hawkshead",
"441665", "Alnwick",
"441278", "Bridgwater",
"441621", "Maldon",
"441208", "Bodmin",
"441290", "Cumnock",
"441536", "Kettering",
"441492", "Colwyn\ Bay",
"441562", "Kidderminster",
"441556", "Castle\ Douglas",
"441469", "Killingholme",
"4418903", "Coldstream",
"441287", "Guisborough",
"4418517", "Stornoway",
"441599", "Kyle",
"441950", "Sandwick",
"441547", "Knighton",
"4417684", "Pooley\ Bridge",
"441946", "Whitehaven",
"4418511", "Great\ Bernera\/Stornoway",
"442881", "Newtownstewart",
"441473", "Ipswich",
"441403", "Horsham",
"441540", "Kingussie",
"441455", "Hinckley",
"441918", "Tyneside",
"44241", "Coventry",
"441639", "Neath",
"44114705", "Sheffield",
"441957", "Mid\ Yell",
"441280", "Buckingham",
"441341", "Barmouth",
"441659", "Sanquhar",
"441304", "Dover",
"441297", "Axminster",
"441937", "Wetherby",
"441482", "Kingston\-upon\-Hull",
"442826", "Northern\ Ireland",
"441249", "Chippenham",
"4418475", "Thurso",
"441874", "Brecon",
"441841", "Newquay\ \(Padstow\)",
"4415078", "Alford\ \(Lincs\)",
"441435", "Heathfield",
"441140", "Sheffield",
"441720", "Isles\ of\ Scilly",
"4414300", "North\ Cave\/Market\ Weighton",
"441827", "Tamworth",
"441485", "Hunstanton",
"4412295", "Barrow\-in\-Furness",
"442883", "Northern\ Ireland",
"441444", "Haywards\ Heath",
"441471", "Isle\ of\ Skye\ \-\ Broadford",
"4414341", "Bellingham\/Haltwhistle\/Hexham",
"4416862", "Llanidloes",
"441539", "Kendal",
"4419755", "Alford\ \(Aberdeen\)",
"441987", "Ebbsfleet",
"441432", "Hereford",
"441327", "Daventry",
"441250", "Blairgowrie",
"441689", "Orpington",
"4414306", "Market\ Weighton",
"4414239", "Boroughbridge",
"441343", "Elgin",
"441559", "Llandysul",
"441466", "Huntly",
"44247", "Coventry",
"441452", "Gloucester",
"441368", "Dunbar",
"4416864", "Llanidloes",
"441843", "Thanet",
"441978", "Wrexham",
"441908", "Milton\ Keynes",
"441623", "Mansfield",
"441495", "Pontypool",
"442893", "Ballyclare",
"441565", "Knutsford",
"441949", "Whatton",
"441743", "Shrewsbury",
"4413395", "Aboyne",
"441636", "Newark\-on\-Trent",
"441768", "Penrith",
"4414376", "Haverfordwest",
"4419642", "Hornsea",
"441264", "Andover",
"441997", "Strathpeffer",
"441237", "Bideford",
"4414347", "Hexham",
"441656", "Bridgend",
"441586", "Campbeltown",
"441320", "Fort\ Augustus",
"441257", "Coppull",
"442829", "Kilrea",
"441980", "Amesbury",
"441246", "Chesterfield",
"4419644", "Patrington",
"441647", "Moretonhampstead",
"441727", "St\ Albans",
"4414370", "Haverfordwest\/Clynderwen\ \(Clunderwen\)",
"441953", "Wymondham",
"441905", "Worcester",
"441759", "Pocklington",
"441981", "Wormbridge",
"441796", "Pitlochry",
"4415395", "Grange\-over\-Sands",
"442846", "Northern\ Ireland",
"441407", "Holyhead",
"441477", "Holmes\ Chapel",
"441865", "Oxford",
"441821", "Kinrossie",
"44114702", "Sheffield",
"441912", "Tyneside",
"4418901", "Coldstream\/Ayton",
"441926", "Warwick",
"441386", "Evesham",
"442837", "Armagh",
"441520", "Lochcarron",
"441933", "Wellingborough",
"441886", "Bromyard\ \(Knightwick\/Leigh\ Sinton\)",
"441293", "Crawley",
"441488", "Hungerford",
"441786", "Stirling",
"4416973", "Wigton",
"4418513", "Stornoway",
"4418907", "Ayton",
"442830", "Newry",
"441202", "Bournemouth",
"4418472", "Thurso",
"441527", "Redditch",
"441721", "Peebles",
"44114704", "Sheffield",
"441765", "Ripon",
"441641", "Strathy",
"441400", "Honington",
"441359", "Pakenham",
"441543", "Cannock",
"441674", "Montrose",
"441604", "Northampton",
"441470", "Isle\ of\ Skye\ \-\ Edinbane",
"441141", "Sheffield",
"4414238", "Harrogate",
"44118", "Reading",
"441859", "Harris",
"441283", "Burton\-on\-Trent",
"441568", "Leominster",
"4418474", "Thurso",
"441896", "Galashiels",
"441233", "Ashford\ \(Kent\)",
"44113", "Leeds",
"4412294", "Barrow\-in\-Furness",
"441756", "Skipton",
"4414343", "Haltwhistle",
"441340", "Craigellachie\ \(Aberlour\)",
"441799", "Saffron\ Walden",
"442849", "Northern\ Ireland",
"441993", "Witney",
"441226", "Barnsley",
"4419754", "Alford\ \(Aberdeen\)",
"442897", "Saintfield",
"441840", "Camelford",
"441747", "Shaftesbury",
"442880", "Carrickmore",
"4412292", "Barrow\-in\-Furness",
"441929", "Wareham",
"441643", "Minehead",
"441389", "Dumbarton",
"441723", "Scarborough",
"44114708", "Sheffield",
"441143", "Sheffield",
"44115", "Nottingham",
"441253", "Blackpool",
"441889", "Rugeley",
"441275", "Clevedon",
"4419752", "Alford\ \(Aberdeen\)",
"441668", "Bamburgh",
"4415079", "Alford\ \(Lincs\)",
"441736", "Penzance",
"441205", "Boston",
"4416865", "Newtown",
"441983", "Isle\ of\ Wight",
"441323", "Eastbourne",
"441951", "Colonsay",
"4413394", "Ballater",
"441789", "Stratford\-upon\-Avon",
"441438", "Stevenage",
"441823", "Taunton",
"442887", "Dungannon",
"441362", "Dereham",
"441972", "Glenborrodale",
"4413392", "Aboyne",
"441356", "Brechin",
"441902", "Wolverhampton",
"441740", "Sedgefield",
"441424", "Hastings",
"442890", "Belfast",
"441620", "North\ Berwick",
"441856", "Orkney",
"441862", "Tain",
"441931", "Shap",
"4419645", "Hornsea",
"441291", "Chepstow",
"441347", "Easingwold",
"441458", "Glastonbury",
"441899", "Biggar",
"441915", "Sunderland",
"441903", "Worthing",
"441955", "Wick",
"441363", "Crediton",
"441709", "Rotherham",
"4415073", "Louth",
"441848", "Thornhill",
"441779", "Peterhead",
"441446", "Barry",
"441863", "Ardgay",
"441457", "Glossop",
"441348", "Fishguard",
"442877", "Limavady",
"44291", "Cardiff",
"4414231", "Harrogate\/Boroughbridge",
"441322", "Dartford",
"441982", "Builth\ Wells",
"441464", "Insch",
"441594", "Lydney",
"441935", "Yeovil",
"441822", "Tavistock",
"4414349", "Bellingham",
"441295", "Banbury",
"442888", "Northern\ Ireland",
"441911", "Tyneside\/Durham\/Sunderland",
"441722", "Salisbury",
"44161", "Manchester",
"441642", "Middlesbrough",
"441142", "Sheffield",
"441634", "Medway",
"441252", "Aldershot",
"4418908", "Coldstream",
"441667", "Nairn",
"442870", "Coleraine",
"4415396", "Sedbergh",
"441969", "Leyburn",
"441545", "Llanarth",
"441584", "Ludlow",
"441379", "Diss",
"441654", "Machynlleth",
"441450", "Hawick",
"441309", "Forres",
"441763", "Royston",
"441992", "Lea\ Valley",
"441748", "Richmond",
"441879", "Scarinish",
"441809", "Tomdoun",
"441285", "Cirencester",
"4414237", "Harrogate",
"441628", "Maidenhead",
"441271", "Barnstaple",
"442898", "Belfast",
"441244", "Chester",
"441542", "Keith",
"44151", "Liverpool",
"441706", "Rochdale",
"441235", "Abingdon",
"441776", "Stranraer",
"441995", "Garstang",
"441449", "Stowmarket",
"442310", "Portsmouth",
"4419646", "Patrington",
"4414372", "Clynderwen\ \(Clunderwen\)",
"441534", "Jersey",
"441282", "Burnley",
"441567", "Killin",
"441497", "Hay\-on\-Wye",
"441761", "Temple\ Cloud",
"441725", "Rockbourne",
"441554", "Llanelli",
"441684", "Malvern",
"441480", "Huntingdon",
"441145", "Sheffield",
"441273", "Brighton",
"44117", "Bristol",
"4414374", "Clynderwen\ \(Clunderwen\)",
"441528", "Laggan",
"441255", "Clacton\-on\-Sea",
"4419640", "Hornsea\/Patrington",
"441325", "Darlington",
"441361", "Duns",
"4414304", "North\ Cave",
"441985", "Warminster",
"441944", "West\ Heslerton",
"441971", "Scourie",
"442838", "Portadown",
"441269", "Ammanford",
"441487", "Warboys",
"441825", "Uckfield",
"441932", "Weybridge",
"4416866", "Newtown",
"441292", "Ayr",
"4413881", "Bishop\ Auckland\/Stanhope\ \(Eastgate\)",
"441376", "Braintree",
"441952", "Telford",
"4414302", "North\ Cave",
"441306", "Dorking",
"441560", "Moscow",
"441694", "Church\ Stretton",
"44114709", "Sheffield",
"44114703", "Sheffield",
"442824", "Northern\ Ireland",
"441490", "Corwen",
"4420", "London",
"441876", "Lochmaddy",
"441806", "Shetland",
"44286", "Northern\ Ireland",
"441913", "Durham",
"441478", "Isle\ of\ Skye\ \-\ Portree",
"4416860", "Newtown\/Llanidloes",
"4418519", "Great\ Bernera",
"441408", "Golspie",
"441663", "New\ Mills",
"441561", "Laurencekirk",
"441491", "Henley\-on\-Thames",
"441754", "Skegness",
"441525", "Leighton\ Buzzard",
"441258", "Blandford",
"4415071", "Louth\/Alford\ \(Lincs\)\/Spilsby\ \(Horncastle\)",
"441728", "Saxmundham",
"4414233", "Boroughbridge",
"441224", "Aberdeen",
"4418476", "Tongue",
"441506", "Bathgate",
"441622", "Maidstone",
"441576", "Lockerbie",
"442892", "Lisburn",
"441360", "Killearn",
"441900", "Workington",
"441970", "Aberystwyth",
"4418518", "Stornoway",
"4418470", "Thurso\/Tongue",
"441767", "Sandy",
"44131", "Edinburgh",
"441342", "East\ Grinstead",
"441834", "Narberth",
"441453", "Dursley",
"441760", "Swaffham",
"441475", "Greenock",
"441405", "Goole",
"441481", "Guernsey",
"441334", "St\ Andrews",
"441842", "Thetford",
"441977", "Pontefract",
"441367", "Faringdon",
"441354", "Chatteris",
"4415077", "Louth",
"441609", "Northallerton",
"441828", "Coupar\ Angus",
"442311", "Southampton",
"442882", "Omagh",
"441328", "Fakenham",
"441988", "Wigtown",
"441854", "Ullapool",
"441433", "Hathersage",
"441938", "Welshpool",
"442871", "Londonderry",
"442844", "Downpatrick",
"4413390", "Aboyne\/Ballater",
"441298", "Buxton",
"441483", "Guildford",
"442885", "Ballygawley",
"441451", "Stow\-on\-the\-Wold",
"441794", "Romsey",
"4418909", "Ayton",
"44114701", "Sheffield",
"441200", "Clitheroe",
"441270", "Crewe",
"441917", "Sunderland",
"441384", "Dudley",
"4413396", "Ballater",
"441509", "Loughborough",
"441924", "Wakefield",
"441579", "Liskeard",
"441472", "Grimsby",
"442866", "Enniskillen",
"441884", "Tiverton",
"441845", "Thirsk",
"441431", "Helmsdale",
"4414375", "Clynderwen\ \(Clunderwen\)",
"441745", "Rhyl",
"441784", "Staines",
"441625", "Macclesfield",
"441493", "Great\ Yarmouth",
"441288", "Bude",
"442895", "Belfast",
"441661", "Prudhoe",
"441563", "Kilmarnock",
"4414305", "North\ Cave",
"4412290", "Barrow\-in\-Furness\/Millom",
"441548", "Kingsbridge",
"441910", "Tyneside\/Durham\/Sunderland",
"4419750", "Alford\ \(Aberdeen\)\/Strathdon",
"441676", "Meriden",
"441522", "Lincoln",
"441606", "Northwich",
"4412296", "Barrow\-in\-Furness",
"441429", "Hartlepool",
"441207", "Consett",
"441277", "Brentwood",
"441394", "Felixstowe",
"4419756", "Strathdon",
"4414348", "Hexham",
"4413393", "Aboyne",
"441923", "Watford",
"44283", "Northern\ Ireland",
"441383", "Dunfermline",
"441729", "Settle",
"441530", "Coalville",
"441296", "Aylesbury",
"4416867", "Llanidloes",
"441259", "Alloa",
"441883", "Caterham",
"442827", "Ballymoney",
"441697", "Brampton",
"441550", "Llandovery",
"441793", "Swindon",
"442843", "Newcastle\ \(Co\.\ Down\)",
"441484", "Huddersfield",
"441680", "Isle\ of\ Mull\ \-\ Craignure",
"441445", "Gairloch",
"441372", "Esher",
"441239", "Cardigan",
"441302", "Doncaster",
"441962", "Winchester",
"441947", "Whitby",
"442868", "Kesh",
"441872", "Truro",
"4419641", "Hornsea\/Patrington",
"4412293", "Millom",
"4414344", "Bellingham",
"441702", "Southend\-on\-Sea",
"441772", "Preston",
"441546", "Lochgilphead",
"4419647", "Patrington",
"441687", "Mallaig",
"441557", "Kirkcudbright",
"4419753", "Strathdon",
"441286", "Caernarfon",
"4414342", "Bellingham",
"4413880", "Bishop\ Auckland\/Stanhope\ \(Eastgate\)",
"442820", "Ballycastle",
"441751", "Pickering",
"441494", "High\ Wycombe",
"441989", "Ross\-on\-Wye",
"441690", "Betws\-y\-Coed",
"441564", "Lapworth",
"441329", "Fareham",
"4419467", "Gosforth",
"441829", "Tarporley",
"4416861", "Newtown\/Llanidloes",
"441678", "Bala",
"441608", "Chipping\ Norton",
"441146", "Sheffield",
"441646", "Milford\ Haven",
"4418514", "Great\ Bernera",
"4416974", "Raughton\ Head",
"441726", "St\ Austell",
"441299", "Bewdley",
"441939", "Wem",
"441256", "Basingstoke",
"4414230", "Harrogate\/Boroughbridge",
"441262", "Bridlington",
"441733", "Peterborough",
"44239", "Portsmouth",
"441637", "Newquay",
"441959", "Westerham",
"441236", "Coatbridge",
"441775", "Spalding",
"441664", "Melton\ Mowbray",
"441590", "Lymington",
"4418512", "Stornoway",
"441753", "Slough",
"441460", "Chard",
"4414309", "Market\ Weighton",
"4414236", "Harrogate",
"441223", "Cambridge",
"441508", "Brooke",
"441578", "Lauder",
"4418473", "Thurso",
"4414379", "Haverfordwest",
"441442", "Hemel\ Hempstead",
"44141", "Glasgow",
"441375", "Grays\ Thurrock",
"441381", "Fortrose",
"441305", "Dorchester",
"441549", "Lairg",
"441353", "Ely",
"441630", "Market\ Drayton",
"441289", "Berwick\-upon\-Tweed",
"441597", "Llandrindod\ Wells",
"441467", "Inverurie",
"441875", "Tranent",
"441805", "Torrington",
"441580", "Cranbrook",
"442841", "Rostrevor",
"441454", "Chipping\ Sodbury",
"4418905", "Ayton",
"4417687", "Keswick",
"441650", "Cemmaes\ Road",
"441833", "Barnard\ Castle",
"441986", "Bungay",
"44292", "Cardiff",
"441326", "Falmouth",
"44238", "Southampton",
"441428", "Haslemere",
"441333", "Peat\ Inn\ \(Leven\ \(Fife\)\)",
"441505", "Johnstone",
"441683", "Moffat",
"441581", "New\ Luce",
"442840", "Banbridge",
"441575", "Kirriemuir",
"4414378", "Haverfordwest",
"441790", "Spilsby",
"441553", "Kings\ Lynn",
"441349", "Dingwall",
"4413391", "Aboyne\/Ballater",
"441651", "Oldmeldrum",
"441708", "Romford",
"441397", "Fort\ William",
"441778", "Bourne",
"441241", "Arbroath",
"441274", "Bradford",
"441204", "Bolton",
"441380", "Devizes",
"4412297", "Millom",
"442889", "Fivemiletown",
"441920", "Ware",
"441672", "Marlborough",
"441526", "Martin",
"4419757", "Strathdon",
"441787", "Sudbury",
"4419643", "Patrington",
"441880", "Tarbert",
"441631", "Oban",
"441780", "Stamford",
"441887", "Aberfeldy",
"441591", "Llanwrtyd\ Wells",
"441425", "Ringwood",
"442823", "Northern\ Ireland",
"441461", "Gretna",
"4414345", "Haltwhistle",
"4412291", "Barrow\-in\-Furness\/Millom",
"44114700", "Sheffield",
"441387", "Dumfries",
"441914", "Tyneside",
"4419751", "Alford\ \(Aberdeen\)\/Strathdon",
"4413397", "Ballater",
"441476", "Grantham",
"441406", "Holbeach",
"441629", "Matlock",
"442899", "Northern\ Ireland",
"441943", "Guiseley",
"441878", "Lochboisdale",
"441749", "Shepton\ Mallet",
"441808", "Tomatin",
"4416863", "Llanidloes",
"4414308", "Market\ Weighton",
"441797", "Rye",
"441308", "Bridport",
"441968", "Penicuik",
"442847", "Northern\ Ireland",
"441750", "Selkirk",
"442821", "Martinstown",
"4417683", "Appleby",
"441463", "Inverness",
"441691", "Oswestry",
"441857", "Sanday",
"441593", "Lybster",
"4418515", "Stornoway",
"4415070", "Louth\/Alford\ \(Lincs\)\/Spilsby\ \(Horncastle\)",
"441346", "Fraserburgh",
"441357", "Strathaven",
"4415076", "Louth",
"441422", "Halifax",
"442886", "Cookstown",
"441337", "Ladybank",
"441364", "Ashburton",
"44114707", "Sheffield",
"441974", "Llanon",
"441529", "Sleaford",
"441904", "York",
"441730", "Petersfield",
"441837", "Okehampton",
"4418471", "Thurso\/Tongue",
"441864", "Abington\ \(Crawford\)",
"441737", "Redhill",
"441830", "Kirkwhelpington",
"441653", "Malton",
"441764", "Crieff",
"4418902", "Coldstream",
"441675", "Coleshill",
"441268", "Basildon",
"441681", "Isle\ of\ Mull\ \-\ Fionnphort",
"441583", "Carradale",
"441330", "Banchory",
"441243", "Chichester",
"4418477", "Tongue",
"441479", "Grantown\-on\-Spey",
"441227", "Canterbury",
"441409", "Holsworthy",
"441350", "Dunkeld",
"441626", "Newton\ Abbot",
"441502", "Lowestoft",
"4418904", "Coldstream",
"441572", "Oakham",
"442896", "Belfast",
"441746", "Bridgnorth",
"441757", "Selby",
"441531", "Ledbury",
"441633", "Newport",};
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
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '44', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;