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
package Number::Phone::StubCountry::JE;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101550;

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
                'fixed_line' => '1534[0-24-8]\\d{5}',
                'geographic' => '1534[0-24-8]\\d{5}',
                'mobile' => '
          7(?:
            (?:
              (?:
                50|
                82
              )9|
              937
            )\\d|
            7(?:
              00[378]|
              97\\d
            )
          )\\d{5}
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
                'personal_number' => '701511\\d{4}',
                'specialrate' => '(
          (?:
            8(?:
              4(?:
                4(?:
                  4(?:
                    05|
                    42|
                    69
                  )|
                  703
                )|
                5(?:
                  041|
                  800
                )
              )|
              7(?:
                0002|
                1206
              )
            )|
            90(?:
              066[59]|
              1810|
              71(?:
                07|
                55
              )
            )
          )\\d{4}
        )|(
          (?:
            3(?:
              0(?:
                07(?:
                  35|
                  81
                )|
                8901
              )|
              3\\d{4}|
              4(?:
                4(?:
                  4(?:
                    05|
                    42|
                    69
                  )|
                  703
                )|
                5(?:
                  041|
                  800
                )
              )|
              7(?:
                0002|
                1206
              )
            )|
            55\\d{4}
          )\\d{4}
        )',
                'toll_free' => '
          80(?:
            07(?:
              35|
              81
            )|
            8901
          )\\d{4}
        ',
                'voip' => '56\\d{8}'
              };
my %areanames = ();
$areanames{en} = {"4414304", "North\ Cave",
"4414308", "Market\ Weighton",
"441771", "Maud",
"4415074", "Alford\ \(Lincs\)",
"4415078", "Alford\ \(Lincs\)",
"441796", "Pitlochry",
"4419645", "Hornsea",
"441206", "Colchester",
"441254", "Blackburn",
"441767", "Sandy",
"441841", "Newquay\ \(Padstow\)",
"441573", "Kelso",
"441628", "Maidenhead",
"441642", "Middlesbrough",
"441526", "Martin",
"441302", "Doncaster",
"441620", "North\ Berwick",
"4414231", "Harrogate\/Boroughbridge",
"44151", "Liverpool",
"441878", "Lochboisdale",
"441352", "Mold",
"441245", "Chelmsford",
"442895", "Belfast",
"441788", "Rugby",
"4412297", "Millom",
"441524", "Lancaster",
"441561", "Laurencekirk",
"441592", "Kirkcaldy",
"441235", "Abingdon",
"441925", "Warrington",
"4414345", "Haltwhistle",
"441239", "Cardigan",
"441451", "Stow\-on\-the\-Wold",
"441929", "Wareham",
"441577", "Kinross",
"442899", "Northern\ Ireland",
"441780", "Stamford",
"441249", "Chippenham",
"441870", "Isle\ of\ Benbecula",
"4415073", "Louth",
"441738", "Perth",
"441204", "Bolton",
"4414303", "North\ Cave",
"441794", "Romsey",
"441285", "Cirencester",
"441722", "Salisbury",
"441748", "Richmond",
"441763", "Royston",
"441740", "Sedgefield",
"441289", "Berwick\-upon\-Tweed",
"441730", "Petersfield",
"441256", "Basingstoke",
"441635", "Newbury",
"441309", "Forres",
"441971", "Scourie",
"441483", "Guildford",
"442826", "Northern\ Ireland",
"44238", "Southampton",
"441967", "Strontian",
"441384", "Dudley",
"441639", "Neath",
"44281", "Northern\ Ireland",
"441305", "Dorchester",
"441685", "Merthyr\ Tydfil",
"441550", "Llandovery",
"441143", "Sheffield",
"441433", "Hathersage",
"441443", "Pontypridd",
"441803", "Torquay",
"441604", "Northampton",
"441857", "Sanday",
"441656", "Bridgend",
"4415396", "Sedbergh",
"441398", "Dulverton",
"441460", "Chard",
"4414237", "Harrogate",
"441334", "St\ Andrews",
"4417683", "Appleby",
"441558", "Llandeilo",
"441689", "Orpington",
"441344", "Bracknell",
"4419755", "Alford\ \(Aberdeen\)",
"441282", "Burnley",
"441725", "Rockbourne",
"441606", "Northwich",
"4412291", "Barrow\-in\-Furness\/Millom",
"441988", "Wigtown",
"441508", "Brooke",
"441980", "Amesbury",
"441346", "Fraserburgh",
"4417684", "Pooley\ Bridge",
"441654", "Machynlleth",
"441807", "Ballindalloch",
"441729", "Settle",
"442824", "Northern\ Ireland",
"4413880", "Bishop\ Auckland\/Stanhope\ \(Eastgate\)",
"441948", "Whitchurch",
"441922", "Walsall",
"441963", "Wincanton",
"441595", "Lerwick\,\ Foula\ \&\ Fair\ Isle",
"441938", "Welshpool",
"441242", "Cheltenham",
"442892", "Lisburn",
"441228", "Carlisle",
"441994", "St\ Clears",
"441355", "East\ Kilbride",
"441487", "Warboys",
"442877", "Limavady",
"441359", "Pakenham",
"441599", "Kyle",
"441386", "Evesham",
"4413394", "Ballater",
"4413398", "Aboyne",
"4412295", "Barrow\-in\-Furness",
"441376", "Braintree",
"441477", "Holmes\ Chapel",
"4416863", "Llanidloes",
"442887", "Dungannon",
"441323", "Eastbourne",
"4414379", "Haverfordwest",
"441362", "Dereham",
"4414347", "Hexham",
"4419751", "Alford\ \(Aberdeen\)\/Strathdon",
"441492", "Colwyn\ Bay",
"441461", "Gretna",
"441424", "Hastings",
"442847", "Northern\ Ireland",
"441753", "Slough",
"441297", "Axminster",
"441707", "Welwyn\ Garden\ City",
"441829", "Tarporley",
"442837", "Armagh",
"441970", "Aberystwyth",
"441978", "Wrexham",
"441825", "Uckfield",
"4418473", "Thurso",
"4419647", "Patrington",
"442868", "Kesh",
"4418474", "Thurso",
"4418478", "Thurso",
"441757", "Selby",
"442843", "Newcastle\ \(Co\.\ Down\)",
"441293", "Crawley",
"441931", "Shap",
"441675", "Coleshill",
"441264", "Andover",
"44141", "Glasgow",
"4416868", "Newtown",
"4416864", "Llanidloes",
"4414372", "Clynderwen\ \(Clunderwen\)",
"4413393", "Aboyne",
"441981", "Wormbridge",
"441327", "Daventry",
"441501", "Harthill",
"441473", "Ipswich",
"442883", "Northern\ Ireland",
"441830", "Kirkwhelpington",
"4419757", "Strathdon",
"4414341", "Bellingham\/Haltwhistle\/Hexham",
"441547", "Knighton",
"441400", "Honington",
"441840", "Camelford",
"441279", "Bishops\ Stortford",
"441275", "Clevedon",
"441408", "Golspie",
"441822", "Tavistock",
"441848", "Thornhill",
"441863", "Ardgay",
"441621", "Maldon",
"441664", "Melton\ Mowbray",
"441916", "Tyneside",
"441838", "Dalmally",
"441880", "Tarbert",
"441499", "Inveraray",
"441770", "Isle\ of\ Arran",
"441953", "Wymondham",
"4418513", "Stornoway",
"44114702", "Sheffield",
"441369", "Dunoon",
"441495", "Pontypool",
"441778", "Bourne",
"441888", "Turriff",
"4419641", "Hornsea\/Patrington",
"4418906", "Ayton",
"441583", "Carradale",
"4418518", "Stornoway",
"441903", "Worthing",
"4418514", "Great\ Bernera",
"441957", "Mid\ Yell",
"441458", "Glastonbury",
"441697", "Brampton",
"44291", "Cardiff",
"441560", "Moscow",
"4418900", "Coldstream\/Ayton",
"4414235", "Harrogate",
"441871", "Castlebay",
"441543", "Cannock",
"441914", "Tyneside",
"441896", "Galashiels",
"441568", "Leominster",
"441672", "Marlborough",
"441666", "Malmesbury",
"441450", "Hawick",
"4415242", "Hornby",
"441367", "Faringdon",
"441984", "Watchet\ \(Williton\)",
"441472", "Grimsby",
"442882", "Omagh",
"441905", "Worcester",
"4418471", "Thurso\/Tongue",
"4418517", "Stornoway",
"441650", "Cemmaes\ Road",
"441466", "Huntly",
"441909", "Worksop",
"441371", "Great\ Dunmow",
"441497", "Hay\-on\-Wye",
"441556", "Castle\ Douglas",
"441261", "Banff",
"441224", "Aberdeen",
"441934", "Weston\-super\-Mare",
"441545", "Llanarth",
"441535", "Keighley",
"441944", "West\ Heslerton",
"441702", "Southend\-on\-Sea",
"442828", "Larne",
"442842", "Kircubbin",
"441292", "Ayr",
"441277", "Brentwood",
"44114703", "Sheffield",
"442820", "Ballycastle",
"441539", "Kendal",
"4416861", "Newtown\/Llanidloes",
"4419753", "Strathdon",
"441549", "Lairg",
"441380", "Devizes",
"441865", "Oxford",
"441273", "Brighton",
"441946", "Whitehaven",
"441226", "Barnsley",
"441695", "Skelmersdale",
"4419758", "Strathdon",
"4419754", "Alford\ \(Aberdeen\)",
"4414376", "Haverfordwest",
"44121", "Birmingham",
"441869", "Bicester",
"441752", "Plymouth",
"441388", "Bishop\ Auckland",
"4413391", "Aboyne\/Ballater",
"441330", "Banchory",
"441608", "Chipping\ Norton",
"441464", "Insch",
"441959", "Westerham",
"44239", "Portsmouth",
"441506", "Bathgate",
"441340", "Craigellachie\ \(Aberlour\)",
"4414370", "Haverfordwest\/Clynderwen\ \(Clunderwen\)",
"441493", "Great\ Yarmouth",
"441986", "Bungay",
"441322", "Dartford",
"441348", "Fishguard",
"441363", "Crediton",
"441554", "Llanelli",
"441600", "Monmouth",
"441955", "Wick",
"441394", "Felixstowe",
"441295", "Banbury",
"442845", "Northern\ Ireland",
"4418477", "Tongue",
"4418511", "Great\ Bernera\/Stornoway",
"441626", "Newton\ Abbot",
"441528", "Laggan",
"441542", "Keith",
"441784", "Staines",
"441673", "Market\ Rasen",
"441911", "Tyneside\/Durham\/Sunderland",
"441874", "Brecon",
"441520", "Lochcarron",
"4418909", "Ayton",
"44161", "Manchester",
"44287", "Northern\ Ireland",
"441709", "Rotherham",
"441299", "Bewdley",
"442849", "Northern\ Ireland",
"4414305", "North\ Cave",
"4419648", "Hornsea",
"441827", "Tamworth",
"4419644", "Patrington",
"4415075", "Spilsby\ \(Horncastle\)",
"44118", "Reading",
"441582", "Luton",
"441902", "Wolverhampton",
"441744", "St\ Helens",
"441475", "Greenock",
"441798", "Pulborough",
"442885", "Ballygawley",
"441208", "Bodmin",
"441200", "Clitheroe",
"4414343", "Haltwhistle",
"442889", "Fivemiletown",
"441790", "Spilsby",
"441479", "Grantown\-on\-Spey",
"4416867", "Llanidloes",
"44113", "Leeds",
"441250", "Blairgowrie",
"441329", "Fareham",
"441736", "Penzance",
"441746", "Bridgnorth",
"441952", "Telford",
"4413397", "Ballater",
"441325", "Darlington",
"4414344", "Bellingham",
"4414348", "Hexham",
"441258", "Blandford",
"441876", "Lochmaddy",
"441692", "North\ Walsham",
"441786", "Stirling",
"441624", "Isle\ of\ Man",
"441823", "Taunton",
"441661", "Prudhoe",
"441759", "Pocklington",
"441862", "Tain",
"4419643", "Patrington",
"4418902", "Coldstream",
"4413873", "Langholm",
"441677", "Bedale",
"441687", "Mallaig",
"4417687", "Keswick",
"441855", "Ballachulish",
"4414233", "Boroughbridge",
"441723", "Scarborough",
"441859", "Harris",
"441776", "Stranraer",
"441886", "Bromyard\ \(Knightwick\/Leigh\ Sinton\)",
"441637", "Newquay",
"441910", "Tyneside\/Durham\/Sunderland",
"441454", "Chipping\ Sodbury",
"441647", "Moretonhampstead",
"441969", "Leyburn",
"441593", "Lybster",
"441406", "Holbeach",
"441353", "Ely",
"441307", "Forfar",
"441564", "Lapworth",
"441918", "Tyneside",
"441456", "Glenurquhart",
"441597", "Llandrindod\ Wells",
"442879", "Magherafelt",
"441489", "Bishops\ Waltham",
"441303", "Folkestone",
"44283", "Northern\ Ireland",
"4418515", "Stornoway",
"441357", "Strathaven",
"441566", "Launceston",
"4415071", "Louth\/Alford\ \(Lincs\)\/Spilsby\ \(Horncastle\)",
"441485", "Hunstanton",
"441834", "Narberth",
"441633", "Newport",
"4414301", "North\ Cave\/Market\ Weighton",
"441668", "Bamburgh",
"441572", "Oakham",
"441404", "Honiton",
"441844", "Thame",
"441643", "Minehead",
"441809", "Tomdoun",
"441449", "Stowmarket",
"4414234", "Boroughbridge",
"4414238", "Harrogate",
"441727", "St\ Albans",
"44117", "Bristol",
"441439", "Helmsley",
"441145", "Sheffield",
"441435", "Heathfield",
"441884", "Tiverton",
"441683", "Moffat",
"441445", "Gairloch",
"441805", "Torrington",
"441260", "Congleton",
"44114705", "Sheffield",
"441268", "Basildon",
"4413395", "Aboyne",
"442893", "Ballyclare",
"441243", "Chichester",
"4412298", "Barrow\-in\-Furness",
"4412294", "Barrow\-in\-Furness",
"441923", "Watford",
"441962", "Winchester",
"442821", "Martinstown",
"441233", "Ashford\ \(Kent\)",
"441769", "South\ Molton",
"441852", "Kilmelford",
"441651", "Oldmeldrum",
"44114707", "Sheffield",
"441765", "Ripon",
"441283", "Burton\-on\-Trent",
"441341", "Barmouth",
"4418475", "Thurso",
"441287", "Guisborough",
"441420", "Alton",
"441442", "Hemel\ Hempstead",
"441428", "Haslemere",
"4414307", "Market\ Weighton",
"441142", "Sheffield",
"441432", "Hereford",
"4415077", "Louth",
"4413882", "Stanhope\ \(Eastgate\)",
"442897", "Saintfield",
"441381", "Fortrose",
"441237", "Bideford",
"441579", "Liskeard",
"442866", "Enniskillen",
"4416865", "Newtown",
"441575", "Kirriemuir",
"4412293", "Millom",
"441482", "Kingston\-upon\-Hull",
"441974", "Llanon",
"441760", "Swaffham",
"441375", "Grays\ Thurrock",
"4413885", "Stanhope\ \(Eastgate\)",
"4414378", "Haverfordwest",
"4414374", "Clynderwen\ \(Clunderwen\)",
"441733", "Peterborough",
"4419756", "Strathdon",
"4413399", "Ballater",
"441768", "Penrith",
"441379", "Diss",
"441743", "Shrewsbury",
"4416862", "Llanidloes",
"441581", "New\ Luce",
"441269", "Ammanford",
"4418472", "Thurso",
"4419750", "Alford\ \(Aberdeen\)\/Strathdon",
"441912", "Tyneside",
"441674", "Montrose",
"441873", "Abergavenny",
"441531", "Ledbury",
"441877", "Callander",
"441787", "Sudbury",
"4418479", "Tongue",
"441570", "Lampeter",
"441623", "Mansfield",
"441824", "Ruthin",
"44114709", "Sheffield",
"441578", "Lauder",
"441691", "Oswestry",
"4418907", "Ayton",
"441676", "Meriden",
"441892", "Tunbridge\ Wells",
"441737", "Redhill",
"4415395", "Grange\-over\-Sands",
"441747", "Shaftesbury",
"441951", "Colonsay",
"441429", "Hartlepool",
"44114708", "Sheffield",
"441425", "Ringwood",
"4413392", "Aboyne",
"4416869", "Newtown",
"4414373", "Clynderwen\ \(Clunderwen\)",
"441919", "Durham",
"4420", "London",
"442841", "Rostrevor",
"441291", "Chepstow",
"441968", "Penicuik",
"441276", "Camberley",
"441943", "Guiseley",
"441223", "Cambridge",
"4414346", "Hexham",
"441915", "Sunderland",
"441933", "Wellingborough",
"441262", "Bridlington",
"4414340", "Bellingham\/Haltwhistle\/Hexham",
"4418512", "Stornoway",
"441366", "Downham\ Market",
"441467", "Inverurie",
"442311", "Southampton",
"441372", "Esher",
"441858", "Market\ Harborough",
"441397", "Fort\ William",
"441557", "Kirkcudbright",
"441503", "Looe",
"441471", "Isle\ of\ Skye\ \-\ Broadford",
"442881", "Newtownstewart",
"441496", "Port\ Ellen",
"441983", "Isle\ of\ Wight",
"441440", "Haverhill",
"4418519", "Great\ Bernera",
"441140", "Sheffield",
"441987", "Ebbsfleet",
"441364", "Ashburton",
"441553", "Kings\ Lynn",
"441438", "Stevenage",
"4418901", "Coldstream\/Ayton",
"441494", "High\ Wycombe",
"441422", "Halifax",
"4419646", "Patrington",
"441808", "Tomatin",
"441463", "Inverness",
"441669", "Rothbury",
"441947", "Whitby",
"441751", "Pickering",
"4419640", "Hornsea\/Patrington",
"442870", "Coleraine",
"441480", "Huntingdon",
"441937", "Wetherby",
"441899", "Biggar",
"441227", "Canterbury",
"441895", "Uxbridge",
"441488", "Hungerford",
"441665", "Alnwick",
"441274", "Bradford",
"442310", "Portsmouth",
"441284", "Bury\ St\ Edmunds",
"442888", "Northern\ Ireland",
"441795", "Sittingbourne",
"441478", "Isle\ of\ Skye\ \-\ Portree",
"441205", "Boston",
"441209", "Redruth",
"4414309", "Market\ Weighton",
"442880", "Carrickmore",
"441799", "Saffron\ Walden",
"441470", "Isle\ of\ Skye\ \-\ Edinbane",
"4415079", "Alford\ \(Lincs\)",
"4414230", "Harrogate\/Boroughbridge",
"4418905", "Ayton",
"441652", "Brigg",
"441298", "Buxton",
"442848", "Northern\ Ireland",
"442822", "Northern\ Ireland",
"441924", "Wakefield",
"441708", "Romford",
"441234", "Bedford",
"4414236", "Harrogate",
"442838", "Portadown",
"4416974", "Raughton\ Head",
"441525", "Leighton\ Buzzard",
"442894", "Antrim",
"441244", "Chester",
"441992", "Lea\ Valley",
"441529", "Sleaford",
"441977", "Pontefract",
"442830", "Newry",
"441700", "Rothesay",
"442840", "Banbridge",
"441290", "Cumnock",
"44292", "Cardiff",
"441481", "Guernsey",
"442871", "Londonderry",
"442896", "Belfast",
"441246", "Chesterfield",
"4416973", "Wigton",
"441926", "Warwick",
"441750", "Selkirk",
"441236", "Coatbridge",
"442867", "Lisnaskea",
"4419467", "Gosforth",
"441382", "Dundee",
"441758", "Pwllheli",
"441141", "Sheffield",
"441431", "Helmsdale",
"441259", "Alloa",
"441320", "Fort\ Augustus",
"441286", "Caernarfon",
"4414302", "North\ Cave",
"441332", "Derby",
"4415072", "Spilsby\ \(Horncastle\)",
"441342", "East\ Grinstead",
"441328", "Fakenham",
"441255", "Clacton\-on\-Sea",
"441354", "Chatteris",
"441995", "Garstang",
"441563", "Kilmarnock",
"441548", "Kingsbridge",
"441636", "Newark\-on\-Trent",
"441522", "Lincoln",
"441594", "Lydney",
"441646", "Milford\ Haven",
"441538", "Ipstones",
"442825", "Ballymena",
"441453", "Dursley",
"441407", "Holyhead",
"442829", "Kilrea",
"441530", "Coalville",
"441837", "Okehampton",
"441540", "Kingussie",
"441306", "Dorking",
"441202", "Bournemouth",
"441792", "Swansea",
"441761", "Temple\ Cloud",
"441724", "Scunthorpe",
"441908", "Milton\ Keynes",
"441588", "Bishops\ Castle",
"441659", "Sanquhar",
"441900", "Workington",
"441655", "Maybole",
"441580", "Cranbrook",
"441777", "Retford",
"441887", "Aberfeldy",
"441726", "St\ Austell",
"44114704", "Sheffield",
"441950", "Sandwick",
"4413881", "Bishop\ Auckland\/Stanhope\ \(Eastgate\)",
"441349", "Dingwall",
"441883", "Caterham",
"441773", "Ripley",
"441684", "Malvern",
"4412296", "Barrow\-in\-Furness",
"441252", "Aldershot",
"44241", "Coventry",
"441609", "Northallerton",
"441335", "Ashbourne",
"441389", "Dumbarton",
"441843", "Thanet",
"441403", "Horsham",
"441571", "Lochinver",
"441644", "New\ Galloway",
"441457", "Glossop",
"441356", "Brechin",
"441698", "Motherwell",
"4412290", "Barrow\-in\-Furness\/Millom",
"441833", "Barnard\ Castle",
"441634", "Medway",
"441690", "Betws\-y\-Coed",
"441567", "Killin",
"441304", "Dover",
"441889", "Rugeley",
"441368", "Dunbar",
"441490", "Corwen",
"441779", "Peterhead",
"441343", "Elgin",
"441856", "Orkney",
"44280", "Northern\ Ireland",
"441333", "Peat\ Inn\ \(Leven\ \(Fife\)\)",
"441444", "Haywards\ Heath",
"441603", "Norwich",
"4414232", "Harrogate",
"441360", "Killearn",
"441775", "Spalding",
"441885", "Pencombe",
"441144", "Sheffield",
"441997", "Strathpeffer",
"441409", "Holsworthy",
"441270", "Crewe",
"441383", "Dunfermline",
"442827", "Ballymoney",
"441278", "Bridgwater",
"441845", "Thirsk",
"441405", "Goole",
"441835", "St\ Boswells",
"441484", "Huddersfield",
"441972", "Glenborrodale",
"441455", "Hinckley",
"4415076", "Louth",
"441569", "Stonehaven",
"4414306", "Market\ Weighton",
"442891", "Bangor\ \(Co\.\ Down\)",
"441241", "Arbroath",
"441565", "Knutsford",
"441993", "Witney",
"442823", "Northern\ Ireland",
"441387", "Dumfries",
"441854", "Ullapool",
"441653", "Malton",
"441347", "Easingwold",
"4414300", "North\ Cave\/Market\ Weighton",
"4415070", "Louth\/Alford\ \(Lincs\)\/Spilsby\ \(Horncastle\)",
"441146", "Sheffield",
"441436", "Helensburgh",
"4414239", "Boroughbridge",
"441337", "Ladybank",
"441446", "Barry",
"441806", "Shetland",
"4414375", "Clynderwen\ \(Clunderwen\)",
"44114701", "Sheffield",
"441301", "Arrochar",
"441527", "Redditch",
"4412299", "Millom",
"441631", "Oban",
"441832", "Clopton",
"441641", "Strathy",
"441842", "Thetford",
"441828", "Coupar\ Angus",
"441253", "Blackpool",
"441797", "Rye",
"441207", "Consett",
"441681", "Isle\ of\ Mull\ \-\ Fionnphort",
"441882", "Kinloch\ Rannoch",
"441772", "Preston",
"441766", "Porthmadog",
"44116", "Leicester",
"441764", "Crieff",
"441721", "Peebles",
"441793", "Swindon",
"441257", "Coppull",
"441670", "Morpeth",
"44114700", "Sheffield",
"441452", "Gloucester",
"4412292", "Barrow\-in\-Furness",
"441576", "Lockerbie",
"441591", "Llanwrtyd\ Wells",
"4415394", "Hawkshead",
"441678", "Bala",
"441562", "Kidderminster",
"441688", "Isle\ of\ Mull\ \-\ Tobermory",
"441559", "Llandysul",
"441586", "Campbeltown",
"441465", "Girvan",
"441469", "Killingholme",
"441954", "Madingley",
"441395", "Budleigh\ Salterton",
"4418476", "Tongue",
"441555", "Lanark",
"441680", "Isle\ of\ Mull\ \-\ Craignure",
"4416860", "Newtown\/Llanidloes",
"441300", "Cerne\ Abbas",
"441638", "Newmarket",
"441546", "Lochgilphead",
"4416866", "Newtown",
"441694", "Church\ Stretton",
"441536", "Kettering",
"4418470", "Thurso\/Tongue",
"441622", "Maidstone",
"4419752", "Alford\ \(Aberdeen\)",
"441864", "Abington\ \(Crawford\)",
"441821", "Kinrossie",
"441663", "New\ Mills",
"44286", "Northern\ Ireland",
"441308", "Bridport",
"441630", "Market\ Drayton",
"441917", "Sunderland",
"441534", "Jersey",
"441945", "Wisbech",
"4413396", "Ballater",
"441598", "Lynton",
"441866", "Kilchrenan",
"441671", "Newton\ Stewart",
"4419759", "Alford\ \(Aberdeen\)",
"441935", "Yeovil",
"441913", "Durham",
"441544", "Kington",
"441225", "Bath",
"441782", "Stoke\-on\-Trent",
"4414371", "Haverfordwest\/Clynderwen\ \(Clunderwen\)",
"441872", "Truro",
"441358", "Ellon",
"441939", "Wem",
"441350", "Dunkeld",
"441667", "Nairn",
"441949", "Whatton",
"441590", "Lymington",
"441584", "Ludlow",
"441728", "Saxmundham",
"441904", "York",
"441985", "Warminster",
"441505", "Johnstone",
"441732", "Sevenoaks",
"441989", "Ross\-on\-Wye",
"441509", "Loughborough",
"4413390", "Aboyne\/Ballater",
"441720", "Isles\ of\ Scilly",
"441271", "Barnstaple",
"441296", "Aylesbury",
"442846", "Northern\ Ireland",
"4419649", "Hornsea",
"441706", "Rochdale",
"441625", "Macclesfield",
"44115", "Nottingham",
"4418904", "Coldstream",
"4418908", "Coldstream",
"441267", "Carmarthen",
"441754", "Skegness",
"4418516", "Great\ Bernera",
"441629", "Matlock",
"441377", "Driffield",
"441462", "Hitchin",
"4414342", "Bellingham",
"4418510", "Great\ Bernera\/Stornoway",
"441491", "Henley\-on\-Thames",
"441476", "Grantham",
"442886", "Cookstown",
"441361", "Duns",
"441324", "Falkirk",
"441392", "Exeter",
"4414377", "Haverfordwest",
"441502", "Lowestoft",
"4414349", "Bellingham",
"441982", "Builth\ Wells",
"442884", "Northern\ Ireland",
"441474", "Gravesend",
"44131", "Edinburgh",
"441745", "Rhyl",
"441288", "Bude",
"441749", "Shepton\ Mallet",
"441280", "Buckingham",
"441427", "Gainsborough",
"441373", "Frome",
"441326", "Falmouth",
"44247", "Coventry",
"441875", "Tranent",
"441785", "Stafford",
"441248", "Bangor\ \(Gwynedd\)",
"442898", "Belfast",
"441932", "Weybridge",
"441263", "Cromer",
"4418903", "Coldstream",
"4419642", "Hornsea",
"441704", "Southport",
"441928", "Runcorn",
"441942", "Wigan",
"442844", "Downpatrick",
"441294", "Ardrossan",
"441756", "Skipton",
"441920", "Ware",
"442890", "Belfast",
"441789", "Stratford\-upon\-Avon",
"441879", "Scarinish",};
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
      $number =~ s/^(?:([0-24-8]\d{5})$|0|180020)//;
      $self = bless({ country_code => '44', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;