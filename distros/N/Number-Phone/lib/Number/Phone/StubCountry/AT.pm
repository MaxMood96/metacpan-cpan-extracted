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
package Number::Phone::StubCountry::AT;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250323211814;

my $formatters = [
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '14',
                  'pattern' => '(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            1(?:
              11|
              [2-9]
            )
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d)(\\d{3,12})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '517',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{2})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '5[079]',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3,5})'
                },
                {
                  'format' => '$1',
                  'intl_format' => 'NA',
                  'leading_digits' => '[18]',
                  'pattern' => '(\\d{6})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            (?:
              31|
              4
            )6|
            51|
            6(?:
              5[0-3579]|
              [6-9]
            )|
            7(?:
              20|
              32|
              8
            )|
            [89]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{3})(\\d{3,10})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            [2-467]|
            5[2-6]
          ',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{4})(\\d{3,9})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '5',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{3})(\\d{3,4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '5',
                  'national_rule' => '0$1',
                  'pattern' => '(\\d{2})(\\d{4})(\\d{4,7})'
                }
              ];

my $validators = {
                'fixed_line' => '
          1(?:
            11\\d|
            [2-9]\\d{3,11}
          )|
          (?:
            316|
            463|
            (?:
              51|
              66|
              73
            )2
          )\\d{3,10}|
          (?:
            2(?:
              1[467]|
              2[13-8]|
              5[2357]|
              6[1-46-8]|
              7[1-8]|
              8[124-7]|
              9[1458]
            )|
            3(?:
              1[1-578]|
              3[23568]|
              4[5-7]|
              5[1378]|
              6[1-38]|
              8[3-68]
            )|
            4(?:
              2[1-8]|
              35|
              7[1368]|
              8[2457]
            )|
            5(?:
              2[1-8]|
              3[357]|
              4[147]|
              5[12578]|
              6[37]
            )|
            6(?:
              13|
              2[1-47]|
              4[135-8]|
              5[468]
            )|
            7(?:
              2[1-8]|
              35|
              4[13478]|
              5[68]|
              6[16-8]|
              7[1-6]|
              9[45]
            )
          )\\d{4,10}
        ',
                'geographic' => '
          1(?:
            11\\d|
            [2-9]\\d{3,11}
          )|
          (?:
            316|
            463|
            (?:
              51|
              66|
              73
            )2
          )\\d{3,10}|
          (?:
            2(?:
              1[467]|
              2[13-8]|
              5[2357]|
              6[1-46-8]|
              7[1-8]|
              8[124-7]|
              9[1458]
            )|
            3(?:
              1[1-578]|
              3[23568]|
              4[5-7]|
              5[1378]|
              6[1-38]|
              8[3-68]
            )|
            4(?:
              2[1-8]|
              35|
              7[1368]|
              8[2457]
            )|
            5(?:
              2[1-8]|
              3[357]|
              4[147]|
              5[12578]|
              6[37]
            )|
            6(?:
              13|
              2[1-47]|
              4[135-8]|
              5[468]
            )|
            7(?:
              2[1-8]|
              35|
              4[13478]|
              5[68]|
              6[16-8]|
              7[1-6]|
              9[45]
            )
          )\\d{4,10}
        ',
                'mobile' => '
          6(?:
            5[0-3579]|
            6[013-9]|
            [7-9]\\d
          )\\d{4,10}
        ',
                'pager' => '',
                'personal_number' => '',
                'specialrate' => '(
          8(?:
            10|
            2[018]
          )\\d{6,10}|
          828\\d{5}
        )|(
          (?:
            8[69][2-68]|
            9(?:
              0[01]|
              3[019]
            )
          )\\d{6,10}
        )',
                'toll_free' => '800\\d{6,10}',
                'voip' => '
          5(?:
            0[1-9]|
            17|
            [79]\\d
          )\\d{2,10}|
          7[28]0\\d{6,10}
        '
              };
my %areanames = ();
$areanames{en} = {"432986", "Irnfritz",
"435447", "Flirsch",
"433862", "Bruck\ an\ der\ Mur",
"433127", "Peggau",
"436216", "Neumarkt\ am\ Wallersee",
"437732", "Haag\ am\ Hausruck",
"432286", "Obersiebenbrunn",
"437477", "St\.\ Peter\ in\ der\ Au",
"432845", "Weikertschlag\ an\ der\ Thaya",
"433365", "Deutsch\ Schützen\-Eisenberg",
"435334", "Westendorf",
"436228", "Faistenau",
"432774", "Innermanzing",
"437255", "Losenstein",
"437212", "Zwettl\ an\ der\ Rodl",
"434242", "Villach",
"437955", "Königswiesen",
"435633", "Hägerau",
"432637", "Grünbach\ am\ Schneeberg",
"436454", "Mandling",
"437941", "Neumarkt\ im\ Mühlkreis",
"432648", "Hochneukirchen",
"435577", "Lustenau",
"432272", "Tulln\ an\ der\ Donau",
"435225", "Fulpmes",
"432573", "Wilfersdorf",
"437241", "Steinerkirchen\ an\ der\ Traun",
"433456", "Fresing",
"437714", "Esternberg",
"437566", "Rosenau\ am\ Hengstpass",
"433533", "Turrach",
"432685", "Rust",
"434875", "Matrei\ in\ Osttirol",
"433119", "St\.\ Marein\ bei\ Graz",
"435413", "St\.\ Leonhard\ im\ Pitztal",
"436562", "Mittersill",
"437234", "Ottensheim",
"435355", "Jochberg",
"437472", "Amstetten",
"433846", "Kalwang",
"435442", "Landeck",
"437674", "Attnang\-Puchheim",
"433867", "Pernegg\ an\ der\ Mur",
"434266", "Strassburg",
"432632", "Pernitz",
"433474", "Deutsch\ Goritz",
"437217", "St\.\ Veit\ im\ Mühlkreis",
"434247", "Afritz",
"436476", "St\.\ Margarethen\ im\ Lungau",
"432853", "Schrems",
"434823", "Tresdorf\,\ Rangersdorf",
"437243", "Marchtrenk",
"437240", "Sipbachzell",
"434213", "Launsdorf",
"432277", "Zwentendorf",
"435572", "Dornbirn",
"432756", "St\.\ Leonhard\ am\ Forst",
"435273", "Matrei\ am\ Brenner",
"432525", "Gnadendorf",
"434238", "Eisenkappel\-Vellach",
"437486", "Lunz\ am\ See",
"437943", "Windhaag\ bei\ Freistadt",
"436138", "St\.\ Wolfgang\ im\ Salzkammergut",
"432614", "Kleinwarasdorf",
"434733", "Malta",
"433686", "Haus",
"436546", "Fusch\ an\ der\ Grossglocknerstrasse",
"437748", "Eggelsberg",
"434718", "Dellach",
"437229", "Traun",
"433333", "Sebersdorf",
"432674", "Weissenbach\ an\ der\ Triesting",
"433634", "Hieflau",
"432769", "Türnitz",
"433145", "Edelschrott",
"433858", "Mitterdorf\ im\ Mürztal",
"435238", "Zirl",
"434273", "Reifnitz",
"437434", "Haag",
"432827", "Schönbach",
"433326", "Stegersbach",
"432162", "Bruck\ an\ der\ Leitha",
"435512", "Egg",
"435213", "Scharnitz",
"436463", "Annaberg\-Lungötz",
"437277", "Waizenkirchen",
"436235", "Thalgau",
"432943", "Obritz",
"435266", "Ötztal\-Bahnhof",
"436416", "Lend",
"433612", "Liezen",
"432243", "Klosterneuburg",
"432748", "Kilb",
"433151", "Gnas",
"437412", "Ybbs\ an\ der\ Donau",
"437614", "Vorchdorf",
"432732", "Krems\ an\ der\ Donau",
"437286", "Lembach\ im\ Mühlkreis",
"435473", "Nauders",
"434355", "Gemmersdorf",
"435372", "Kufstein",
"437443", "Ybbsitz",
"433469", "St\.\ Oswald\ im\ Freiland",
"433331", "St\.\ Lorenzen\ am\ Wechsel",
"435517", "Riezlern",
"432167", "Neusiedl\ am\ See",
"432212", "Orth\ an\ der\ Donau",
"436461", "Dienten\ am\ Hochkönig",
"432955", "Grossweikersdorf",
"432822", "Zwettl\,\ Lower\ Austria",
"433578", "Obdach",
"434852", "Lienz",
"432146", "Nickelsdorf",
"432912", "Geras",
"433179", "Passail",
"432864", "Kautzen",
"432255", "Deutsch\ Brodersdorf",
"434225", "Grafenstein",
"436583", "Leogang",
"434271", "Steuerberg",
"432538", "Velm\-Götzendorf",
"433617", "Gaishorn\ am\ See",
"432714", "Rossatz",
"435242", "Schwaz",
"435678", "Weissenbach\ am\ Lech",
"4318", "Vienna",
"437272", "Eferding",
"433883", "Terz",
"432234", "Gramatneusiedl",
"436276", "Nussdorf\ am\ Haunsberg",
"433153", "Riegersburg",
"433150", "Paldau",
"437269", "Baumgartenberg",
"437237", "St\.\ Georgen\ an\ der\ Gusen",
"436221", "Koppl",
"436484", "Lessach",
"432612", "Oberpullendorf",
"433359", "Loipersdorf\-Kitzladen",
"437717", "St\.\ Aegidi",
"434766", "Millstatt",
"436457", "Flachau",
"435574", "Bregenz",
"434713", "Techendorf",
"434710", "Oberdrauburg",
"433472", "Mureck",
"437743", "Maria\ Schmolln",
"432956", "Ziersdorf",
"432634", "Gutenstein",
"432145", "Prellenkirchen",
"435337", "Brixlegg",
"436133", "Ebensee",
"432256", "Leobersdorf",
"434226", "St\.\ Margareten\ im\ Rosental",
"435278", "Navis",
"434233", "Griffen",
"434230", "Globasnitz",
"437285", "Hofkirchen\ im\ Mühlkreis",
"437948", "Hirschbach\ im\ Mühlkreis",
"432641", "Kirchberg\ am\ Wechsel",
"437474", "Euratsfeld",
"434356", "Lavamünd",
"437672", "Vöcklabruck",
"432858", "Moorbad\ Harbach",
"435444", "Ischgl",
"437729", "Neukirchen\ an\ der\ Enknach",
"433124", "Gratkorn",
"437248", "Grieskirchen",
"436564", "Krimml",
"432617", "Drassmarkt",
"432786", "Oberwölbling",
"437232", "St\.\ Martin\ im\ Mühlkreis",
"436223", "Anthering",
"437755", "Mettmach",
"432274", "Sieghartskirchen",
"436452", "Radstadt",
"435265", "Nassereith",
"436415", "Schwarzach\ im\ Pongau",
"437712", "Schärding",
"432629", "Warth\,\ Lower\ Austria",
"432772", "Neulengbach",
"435556", "Schruns",
"435332", "Wörgl",
"436131", "Obertraun",
"435289", "Häusling",
"435418", "Schönwies",
"433325", "Heiligenkreuz\ im\ Lafnitztal",
"434244", "Bad\ Bleiberg",
"437214", "Reichenthal",
"433477", "St\.\ Peter\ am\ Ottersbach",
"433864", "St\.\ Marein\ im\ Mürztal",
"432643", "Lichtenegg",
"433513", "Bischoffeld",
"434231", "Mittertrixen",
"437734", "Hofkirchen\ an\ der\ Trattnach",
"433146", "Modriach",
"437617", "Traunkirchen",
"432533", "Neusiedl\ an\ der\ Zaya",
"436588", "Lofer",
"432232", "Fischamend",
"433685", "Gröbming",
"436545", "Bruck\ an\ der\ Grossglocknerstrasse",
"433573", "Fohnsdorf",
"437448", "Kematen\ an\ der\ Ybbs",
"435244", "Jenbach",
"432712", "Aggsbach",
"432755", "Mank",
"437274", "Alkoven",
"432526", "Stronsdorf",
"437485", "Gaming",
"434265", "Weitensfeld\ im\ Gurktal",
"432824", "Allentsteig",
"432214", "Kopfstetten",
"433158", "St\.\ Anna\ am\ Aigen",
"432741", "Flinsbach",
"432862", "Heidenreichstein",
"432914", "Japons",
"436475", "Ramingstein",
"435374", "Walchsee",
"435585", "Dalaas",
"433637", "Gams\ bei\ Hieflau",
"432734", "Langenlois",
"433845", "Mautern\ in\ Steiermark",
"435673", "Ehrwald",
"437414", "Weins\-Isperdorf",
"433571", "Möderbrugg",
"436468", "Werfen",
"434278", "Gnesau",
"435230", "Sellrain",
"432269", "Niederfellabrunn",
"433853", "Spital\ am\ Semmering",
"432237", "Gaaden",
"437612", "Gmunden",
"435356", "Kitzbühel",
"435226", "Neustift\ im\ Stubaital",
"433338", "Lafnitz",
"433455", "Arnfels",
"433183", "St\.\ Georgen\ an\ der\ Stiefing",
"433614", "Rottenmann",
"432717", "Unter\-Meisling",
"437565", "St\.\ Pankraz",
"434876", "Kals\ am\ Grossglockner",
"432686", "Drassburg",
"437432", "Strengberg",
"432846", "Raabs\ an\ der\ Thaya",
"433366", "Kohfidisch",
"437256", "Ternberg",
"435514", "Bezau",
"432164", "Rohrau",
"432743", "Böheimkirchen",
"437956", "Unterweissenbach",
"432672", "Berndorf",
"432985", "Gars\ am\ Kamp",
"432248", "Markgrafneusiedl",
"436215", "Strasswalchen",
"433632", "St\.\ Gallen",
"432285", "Marchegg",
"432948", "Weitersfeld",
"435476", "Serfaus",
"437283", "Sarleinsbach",
"437582", "Kirchdorf\ an\ der\ Krems",
"434235", "Bleiburg",
"437280", "Schwarzenberg\ am\ Böhmerwald",
"433584", "Neumarkt\ in\ Steiermark",
"432764", "Hainfeld",
"432143", "Kittsee",
"437745", "Lochen",
"434715", "Kötschach\-Mauthen",
"432722", "Kirchberg\ an\ der\ Pielach",
"436135", "Bad\ Goisern",
"432262", "Korneuburg",
"4317", "Vienna",
"437619", "Kirchham",
"434254", "Faak\ am\ See",
"433886", "Weichselboden",
"437751", "St\.\ Martin\ im\ Innkreis",
"432814", "Langschlag",
"432688", "Steinbrunn",
"433336", "Waldbach",
"433174", "Birkfeld",
"437281", "Aigen\ im\ Mühlkreis",
"437664", "Weyregg\ am\ Attersee",
"434784", "Mallnitz",
"437587", "Wartberg\ an\ der\ Krems",
"433515", "St\.\ Lorenzen\ bei\ Knittelfeld",
"432645", "Wiesmath",
"435358", "Ellmau",
"433464", "Gross\ St\.\ Florian",
"433624", "Pichl\-Kainisch",
"434276", "Feldkirchen\ in\ Kärnten",
"436466", "Werfenweng",
"433323", "Eberau",
"432946", "Pulkau",
"437750", "Andrichsfurt",
"435524", "Satteins",
"437753", "Eberschwang",
"432246", "Gerasdorf\ bei\ Wien",
"432239", "Breitenfurt\ bei\ Wien",
"432267", "Sierndorf",
"435263", "Silz",
"436413", "Wagrain",
"436225", "Eugendorf",
"434282", "Hermagor",
"437258", "Bad\ Hall",
"432848", "Pfaffenschlag\ bei\ Waidhofen",
"432719", "Dross",
"435583", "Lech",
"432664", "Semmering",
"435282", "Zell\ am\ Ziller",
"435675", "Tannheim",
"432622", "Wiener\ Neustadt",
"434768", "Kleblach\-Lind",
"435339", "Wildschönau",
"433843", "St\.\ Michael\ in\ Obersteiermark",
"433132", "Kumberg",
"434263", "Hüttenberg",
"432172", "Frauenkirchen",
"436470", "Atzmannsdorf",
"436473", "Mariapfarr",
"437727", "Ach",
"432554", "Stützenhofen",
"433357", "Pinkafeld",
"437246", "Gunskirchen",
"437239", "Lichtenberg",
"432856", "Weitra",
"434826", "Mörtschach",
"437267", "Mönchdorf",
"437946", "Gutau",
"434358", "St\.\ Andrä",
"437480", "Langau\,\ Gaming",
"437483", "Oberndorf\ an\ der\ Melk",
"435276", "Gschnitz",
"432753", "Gansbach",
"434736", "Innerkrems",
"433683", "Donnersbach",
"432258", "Alland",
"433680", "Donnersbachwald",
"434228", "Feistritz\ im\ Rosental",
"432535", "Hohenau\ an\ der\ March",
"433114", "Markt\ Hartmannsdorf",
"437719", "Taufkirchen\ an\ der\ Pram",
"4316", "Vienna",
"432958", "Maissau",
"433575", "St\.\ Johann\ am\ Tauern",
"436242", "Russbach\ am\ Pass\ Gschütt",
"436543", "Taxenbach",
"436213", "Oberhofen\ am\ Irrsee",
"432983", "Sigmundsherberg",
"432627", "Pitten",
"432283", "Angern\ an\ der\ March",
"435287", "Tux",
"435254", "Sölden",
"437722", "Braunau\ am\ Inn",
"433834", "Wald\ am\ Schoberpass",
"432177", "Podersdorf\ am\ See",
"436471", "Tweng",
"432874", "Martinsberg",
"437764", "Riedau",
"432745", "Pyhra",
"433137", "Söding",
"437224", "St\.\ Florian",
"432576", "Ernstbrunn",
"433148", "Kainach\ bei\ Voitsberg",
"437262", "Perg",
"433536", "St\.\ Peter\ am\ Kammersberg",
"437563", "Spital\ am\ Pyhrn",
"433352", "Oberwart",
"432619", "Lackendorf",
"433453", "Ehrenhausen",
"433185", "Preding",
"436247", "Grossgmain",
"436541", "Saalbach",
"433855", "Krieglach",
"435558", "Gaschurn",
"433328", "Kukmirn",
"437279", "Haibach\ ob\ der\ Donau",
"435353", "Waidring",
"434284", "Kirchbach",
"433856", "Veitsch",
"435236", "Gries\ im\ Sellrain",
"435223", "Hall\ in\ Tirol",
"432575", "Ladendorf",
"434257", "Fürnitz",
"435522", "Feldkirch",
"434873", "St\.\ Jakob\ in\ Defereggen",
"432683", "Purbach\ am\ Neusiedler\ See",
"432680", "St\.\ Margarethen\ im\ Burgenland",
"433535", "Krakaudorf",
"437253", "Wolfern",
"433622", "Bad\ Aussee",
"437250", "Maria\ Neustift",
"433363", "Rechnitz",
"433462", "Deutschlandsberg",
"432843", "Dobersberg",
"432767", "Hohenberg",
"437953", "Liebenau",
"435635", "Elmen",
"433587", "Schönberg\-Lachtal",
"432739", "Tiefenfucha",
"432746", "Wilhelmsburg",
"433172", "Weiz",
"436418", "Kleinarl",
"436433", "Dorfgastein",
"437662", "Seewalchen\ am\ Attersee",
"434782", "Obervellach",
"437758", "Obernberg\ am\ Inn",
"432829", "Schweiggers",
"434735", "Kremsbrücke",
"432536", "Drösing",
"433619", "Oppenberg",
"433576", "Bretstein",
"434215", "Liebenfels",
"437245", "Lambach",
"432855", "Waldenstein",
"434825", "Grosskirchheim",
"432264", "Rückersdorf\,\ Harmannsdorf",
"437945", "St\.\ Oswald\ bei\ Freistadt",
"432812", "Gross\ Gerungs",
"435275", "Trins",
"432523", "Kirchstetten\,\ Neudorf\ bei\ Staatz",
"437288", "Ulrichsberg",
"434252", "Wernberg",
"4312", "Vienna",
"433582", "Scheifling",
"432762", "Lilienfeld",
"4319", "Vienna",
"432841", "Vitis",
"433467", "Schwanberg",
"437251", "Schiedlberg",
"436278", "Ostermiething",
"432724", "Schwarzenbach\ an\ der\ Pielach",
"437584", "Molln",
"437667", "St\.\ Georgen\ im\ Attergau",
"432169", "Trautmannsdorf\ an\ der\ Leitha",
"435519", "Schröcken",
"435676", "Jungholz",
"433177", "Puch\ bei\ Weiz",
"43316", "Graz",
"435579", "Alberschwende",
"433387", "Söchau",
"433117", "Eggersdorf\ bei\ Graz",
"436226", "Fuschl\ am\ See",
"432783", "Traismauer",
"432945", "Zellerndorf",
"434842", "Sillian",
"436233", "Oberwang",
"432288", "Auersthal",
"433354", "Bernstein",
"432245", "Wolkersdorf\ im\ Weinviertel",
"434761", "Stockenboi",
"432988", "Neupölla",
"437264", "Windhaag\ bei\ Perg",
"433832", "Kraubath\ an\ der\ Mur",
"435553", "Raggal",
"434221", "Gallizien",
"434275", "Ebene\ Reichenau",
"435252", "Oetz",
"435449", "Fliess",
"432557", "Bernhardsthal",
"435550", "Thüringen",
"437724", "Mauerkirchen",
"437479", "Ardagger",
"432951", "Guntersdorf",
"432872", "Ottenschlag",
"437762", "Raab",
"433335", "Pöllau",
"432639", "Bad\ Fischau",
"433143", "Krottendorf",
"432667", "Schwarzau\ im\ Gebirge",
"433140", "St\.\ Martin\ am\ Wöllmissberg",
"433516", "Kleinlobming",
"432646", "Kirchschlag\ in\ der\ Buckligen\ Welt",
"437357", "Kleinreifling",
"436478", "Zederhaus",
"433112", "Gleisdorf",
"433382", "Fürstenfeld",
"436244", "Golling\ an\ der\ Salzach",
"433155", "Fehring",
"434268", "Friesach",
"4314", "Vienna",
"432279", "Kirchberg\ am\ Wagram",
"437683", "Frankenburg\ am\ Hausruck",
"433848", "Eisenerz",
"433885", "Greith",
"437227", "Neuhofen\ an\ der\ Krems",
"434847", "Obertilliach",
"432953", "Nappersdorf",
"437767", "Eggerding",
"432877", "Grainbrunn",
"436548", "Niedernsill",
"437746", "Friedburg",
"433134", "Heiligenkreuz\ am\ Waasen",
"434716", "Lesachtal",
"433869", "St\.\ Katharein\ an\ der\ Laming",
"432253", "Oberwaltersdorf",
"434223", "Maria\ Saal",
"433688", "Tauplitz",
"434220", "Köttmannsdorf",
"432552", "Poysdorf",
"436136", "Gosau",
"432174", "Wallern\ im\ Burgenland",
"434350", "Bad\ St\.\ Leonhard\ im\ Lavanttal",
"437488", "Steinakirchen\ am\ Forst",
"435475", "Feichten",
"437219", "Vorderweissenbach",
"434353", "Prebl",
"432662", "Gloggnitz",
"435284", "Gerlos",
"433141", "Hirschegg",
"432758", "Pöggstall",
"434236", "Eberndorf",
"437445", "Hollenstein\ an\ der\ Ybbs",
"432624", "Ebenfurth",
"436219", "Obertrum\ am\ See",
"436132", "Bad\ Ischl",
"435331", "Brandenberg",
"432725", "Frankenfels",
"432556", "Grosskrut",
"432989", "Brunn\ an\ der\ Wild",
"437742", "Mattighofen",
"433473", "Straden",
"434712", "Greifenburg",
"432289", "Matzen",
"437673", "Schwanenstadt",
"435578", "Höchst",
"432666", "Reichenau",
"434232", "Völkermarkt",
"437585", "Klaus\ an\ der\ Pyhrnbahn",
"432647", "Krumbach\,\ Lower\ Austria",
"432638", "Winzendorf\-Muthmannsdorf",
"433386", "Grosssteinbach",
"433116", "Kirchbach\ in\ Steiermark",
"436227", "St\.\ Gilgen",
"437231", "Herzogsdorf",
"434734", "Rennweg",
"432610", "Horitschon",
"432613", "Deutschkreutz",
"437944", "Sandl",
"437478", "Oed\-Oehling",
"435274", "Gries\ am\ Brenner",
"437711", "Suben",
"437244", "Sattledt",
"434214", "Brückl",
"432265", "Hausleiten",
"435448", "Pettneu\ am\ Arlberg",
"434824", "Heiligenblut",
"432854", "Kirchberg\ am\ Walde",
"435634", "Elbigenalp",
"437766", "Andorf",
"432876", "Els",
"437747", "Kirchberg\ bei\ Mattighofen",
"434717", "Steinfeld",
"432773", "Eichgraben",
"435256", "Untergurgl",
"436137", "Strobl",
"435333", "Söll",
"433849", "Vordernberg",
"433512", "Knittelfeld",
"432642", "Aspangberg\-St\.\ Peter",
"432278", "Absdorf",
"434269", "Flattnitz",
"434237", "Miklauzhof",
"436479", "Muhr",
"43732", "Linz",
"432611", "Mannersdorf\ an\ der\ Rabnitz",
"437233", "Feldkirchen\ an\ der\ Donau",
"437230", "Altenberg\ bei\ Linz",
"434285", "Tröpolach",
"437218", "Grosstraberg",
"437489", "Purgstall\ an\ der\ Erlauf",
"434248", "Treffen",
"435414", "Wenns",
"433689", "St\.\ Nikolai\ im\ Sölktal",
"433534", "Stadl\ an\ der\ Mur",
"433868", "Tragöss",
"437713", "Schardenberg",
"432574", "Gaweinstal",
"437226", "Wilhering",
"436453", "Filzmoos",
"434846", "Abfaltersbach",
"436549", "Piesendorf",
"432863", "Eggern",
"436584", "Maria\ Alm\ am\ Steinernen\ Meer",
"432175", "Apetlon",
"432766", "Kleinzell",
"433586", "Mühlen",
"432747", "Ober\-Grafendorf",
"433135", "Kalsdorf\ bei\ Graz",
"435248", "Steinberg\ am\ Rofan",
"435672", "Reutte",
"432625", "Bad\ Sauerbrunn",
"437444", "Opponitz",
"435474", "Pfunds",
"433329", "Jennersdorf",
"437278", "Neukirchen\ am\ Walde",
"433631", "Unterlaussa",
"435285", "Mayrhofen",
"436245", "Hallein",
"433572", "Judenburg",
"434858", "Nikolsdorf",
"432828", "Rappottenstein",
"437759", "Antiesenhofen",
"433857", "Neuberg\ an\ der\ Mürz",
"432233", "Pressbaum",
"432532", "Zistersdorf",
"432230", "Schwadorf",
"432738", "Fels\ am\ Wagram",
"434256", "Nötsch\ im\ Gailtal",
"433884", "Wegscheid",
"432816", "Karlstift",
"432713", "Spitz",
"432742", "St\.\ Pölten",
"435214", "Leutasch",
"437289", "Rohrbach\ in\ Oberösterreich",
"433466", "Eibiswald",
"437433", "Wallsee",
"434274", "Velden\ am\ Wörther\ See",
"437666", "Attersee",
"433633", "Landl",
"435677", "Vils",
"432673", "Altenmarkt\ an\ der\ Triesting",
"433176", "Stubenberg",
"433618", "Hohentauern",
"433334", "Kaindorf",
"433852", "Mürzzuschlag",
"432231", "Purkersdorf",
"435232", "Kematen\ in\ Tirol",
"437613", "Laakirchen",
"433577", "Zeltweg",
"432168", "Mannersdorf\ am\ Leithagebirge",
"435518", "Mellau",
"432711", "Dürnstein",
"433355", "Stadtschlaining",
"432244", "Langenzersdorf",
"433182", "Wildon",
"437265", "Pabneukirchen",
"432944", "Haugsdorf",
"435526", "Laterns",
"433356", "Markt\ Allhau",
"437247", "Kematen\ am\ Innbach",
"432857", "Bad\ Grosspertholz",
"437266", "Bad\ Kreuzen",
"433532", "Murau",
"437947", "Kefermarkt",
"432572", "Mistelbach",
"435525", "Nenzing",
"432273", "Tulbing",
"434769", "Möllbrücke",
"436224", "Hintersee",
"435338", "Kundl",
"436563", "Uttendorf",
"435412", "Imst",
"434785", "Ausserfragant",
"437665", "Unterach\ am\ Attersee",
"437733", "Neumarkt\ im\ Hausruckkreis",
"432959", "Sitzendorf\ an\ der\ Schmida",
"437471", "Neustadtl\ an\ der\ Donau",
"432644", "Grimmenstein",
"436458", "Hüttau",
"433514", "Seckau",
"434229", "Krumpendorf\ am\ Wörther\ See",
"432259", "Münchendorf",
"433863", "Turnau",
"435441", "See",
"433175", "Anger",
"437718", "Waldkirchen\ am\ Wesen",
"434243", "Bodensdorf",
"434359", "Reichenfels",
"434240", "Bad\ Kleinkirchheim",
"437213", "Bad\ Leonfelden",
"432631", "Pöttsching",
"435632", "Stanzach",
"433465", "Pölfing\-Brunn",
"437238", "Mauthausen",
"435272", "Steinach\ am\ Brenner",
"432577", "Asparn\ an\ der\ Zaya",
"435573", "Hörbranz",
"434255", "Arnoldstein",
"432271", "Ried\ am\ Riederberg",
"437942", "Freistadt",
"432815", "Grossschönau",
"434822", "Winklern",
"432852", "Gmünd",
"433537", "St\.\ Georgen\ ob\ Murau",
"434212", "St\.\ Veit\ an\ der\ Glan",
"437242", "Wels",
"436246", "Grödig",
"435417", "Roppen",
"436483", "Göriach",
"434732", "Gmünd\ in\ Kärnten",
"433123", "St\.\ Oswald\ bei\ Plankenwarth",
"435559", "Brand",
"433861", "Aflenz",
"432626", "Mattersburg",
"435443", "Galtür",
"437473", "Blindenmarkt",
"434234", "Ruden",
"435286", "Ginzling",
"432176", "Tadten",
"432618", "Markt\ St\.\ Martin",
"436134", "Hallstatt",
"433149", "Geistthal",
"432633", "Markt\ Piesting",
"432765", "Kaumberg",
"432630", "Ternitz",
"433585", "St\.\ Lambrecht",
"434714", "Dellach\ im\ Drautal",
"433136", "Dobl",
"437744", "Munderfing",
"437211", "Reichenau\ im\ Mühlkreis",
"433184", "Wolfsberg\ im\ Schwarzautal",
"433613", "Admont",
"432242", "St\.\ Andrä\-Wördern",
"437225", "Hargelsberg",
"433638", "Palfau",
"432942", "Retz",
"437355", "Weyer",
"435234", "Axams",
"434286", "Weissbriach",
"433854", "Langenwang",
"433157", "Kapfenstein",
"437413", "Marbach\ an\ der\ Donau",
"435477", "Tösens",
"4346", "Klagenfurt",
"432731", "Idolsberg",
"433332", "Hartberg",
"437765", "Lambrechten",
"432875", "Grafenschlag",
"435510", "Damüls",
"436462", "Bischofshofen",
"432160", "Jois",
"435212", "Seefeld\ in\ Tirol",
"432163", "Petronell\-Carnuntum",
"435513", "Hittisau",
"432744", "Kasten\ bei\ Böheimkirchen",
"434272", "Pörtschach\ am\ Wörther\ See",
"435255", "Umhausen",
"437618", "Neukirchen\,\ Altmünster",
"432947", "Theras",
"433882", "Mariazell",
"437273", "Aschach\ an\ der\ Donau",
"435243", "Maurach",
"432247", "Deutsch\-Wagram",
"435359", "Hochfilzen",
"433611", "Johnsbach",
"432266", "Stockerau",
"433574", "Pusterwald",
"433385", "Ilz",
"433152", "Feldbach",
"433115", "Studenzen",
"432534", "Niedersulz",
"434879", "St\.\ Veit\ in\ Defereggen",
"432689", "Hornstein",
"437442", "Waidhofen\ an\ der\ Ybbs",
"437259", "Sierning",
"435674", "Bichlbach",
"433337", "Vorau",
"432718", "Lichtenau\ im\ Waldviertel",
"432849", "Schwarzenau",
"432665", "Prein\ an\ der\ Rax",
"432733", "Schönberg\ am\ Kamp",
"437586", "Pettenbach",
"435373", "Ebbs",
"435472", "Prutz",
"432913", "Hötzelsdorf",
"432726", "Puchenstuben",
"436582", "Saalfelden\ am\ Steinernen\ Meer",
"434277", "Glanegg",
"432555", "Herrnbaumgarten",
"432238", "Kaltenleutgeben",
"436467", "Mühlbach\ am\ Hochkönig",
"432213", "Lassee",
"434853", "Ainet",
"432823", "Grossglobnitz",
"437952", "Weitersfelden",
"433581", "Oberwölz",
"437215", "Hellmonsödt",
"434245", "Feistritz\ an\ der\ Drau",
"433324", "Strem",
"433623", "Bad\ Mitterndorf",
"437252", "Steyr",
"432842", "Waidhofen\ an\ der\ Thaya",
"433463", "Stainz",
"433362", "Grosspetersdorf",
"433460", "Soboth",
"436432", "Bad\ Hofgastein",
"437735", "Gaspoltshofen",
"434783", "Reisseck",
"437663", "Steinbach\ am\ Attersee",
"433636", "Wildalpen",
"433170", "Fischbach",
"433173", "Ratten",
"436589", "Unken",
"433865", "Kindberg",
"437616", "Grünau\ im\ Almtal",
"435352", "St\.\ Johann\ in\ Tirol",
"436565", "Neukirchen\ am\ Grossvenediger",
"436414", "Grossarl",
"434872", "Huben",
"432682", "Eisenstadt",
"435264", "Mieming",
"435523", "Götzis",
"432275", "Atzenbrugg",
"437754", "Waldzell",
"432527", "Wulzeshofen",
"433159", "Bad\ Gleichenberg",
"432847", "Gross\-Siegharts",
"433461", "Trahütten",
"433339", "Friedberg",
"437257", "Grünburg",
"4315", "Vienna",
"432763", "St\.\ Veit\ an\ der\ Gölsen",
"432144", "Deutsch\ Jahrndorf",
"433583", "Unzmarkt",
"432635", "Neunkirchen",
"432268", "Grossmugl",
"435445", "Kappl",
"434279", "Sirnitz",
"433125", "Übelbach",
"433171", "Gasen",
"437284", "Oberkappel",
"437475", "Hausmening\,\ Neuhofen\ an\ der\ Ybbs",
"432949", "Niederfladnitz",
"436274", "Lamprechtshausen",
"432728", "Wienerbruck",
"432236", "Mödling",
"435357", "Kirchberg\ in\ Tirol",
"432249", "Gross\-Enzersdorf",
"432813", "Arbesbach",
"434253", "St\.\ Jakob\ im\ Rosental",
"435575", "Langen\ bei\ Bregenz",
"432522", "Laa\ an\ der\ Thaya",
"437588", "Ried\ im\ Traunkreis",
"432716", "Gföhl",
"434877", "Prägraten\ am\ Grossvenediger",
"432687", "Siegendorf",
"432165", "Hainburg\ a\.d\.\ Donau",
"435515", "Au",
"437763", "Kopfing\ im\ Innkreis",
"432957", "Hohenwarth",
"432873", "Kottes",
"435336", "Alpbach",
"435253", "Längenfeld",
"435552", "Bludenz",
"432257", "Klausen\-Leopoldsdorf",
"433833", "Traboch",
"434227", "Ferlach",
"432284", "Oberweiden",
"433142", "Voitsberg",
"434357", "St\.\ Paul\ im\ Lavanttal",
"437268", "Grein",
"432984", "Eggenburg",
"436214", "Henndorf\ am\ Wallersee",
"433358", "Litzelsdorf",
"437728", "Schwand\ im\ Innkreis",
"432782", "Herzogenburg",
"437236", "Pregarten",
"432859", "Brand\-Nagelberg",
"437249", "Bad\ Schallerbach",
"437353", "Gaflenz",
"437415", "Altenmarkt\,\ Yspertal",
"435279", "St\.\ Jodok\ am\ Brenner",
"437949", "Rainbach\ im\ Mühlkreis",
"433615", "Trieben",
"437716", "Münzkirchen",
"433454", "Leutschach",
"434767", "Rothenthurn",
"437564", "Hinterstoder",
"434843", "Ausservillgraten",
"436456", "Obertauern",
"436232", "Mondsee",
"437223", "Enns",
"435557", "St\.\ Gallenkirch",
"432252", "Baden",
"436474", "Tamsweg",
"432915", "Drosendorf\-Zissersdorf",
"434855", "Assling",
"432825", "Göpfritz\ an\ der\ Wild",
"432952", "Hollabrunn",
"434264", "Klein\ St\.\ Paul",
"43512", "Innsbruck",
"432215", "Probstdorf",
"433476", "Bad\ Radkersburg",
"433844", "Kammern\ im\ Liesingtal",
"437676", "Ottnang\ am\ Hausruck",
"434352", "Wolfsberg",
"435375", "Kössen",
"432735", "Hadersdorf\ am\ Kamp",
"432663", "Schottwien",
"433147", "Salla",
"433383", "Burgau",
"436544", "Rauris",
"4313", "Vienna",
"432616", "Lockenhaus",
"433684", "St\.\ Martin\ am\ Grimming",
"433113", "Pischelsdorf\ in\ der\ Steiermark",
"437221", "Hörsching",
"432754", "Loosdorf",
"435288", "Fügen",
"437484", "Göstling\ an\ der\ Ybbs",
"437682", "Vöcklamarkt",
"432628", "Felixdorf",
"434762", "Spittal\ an\ der\ Drau",
"435245", "Hinterriss",
"432524", "Kautendorf",
"437757", "Gurten",
"437276", "Peuerbach",
"435239", "Kühtai",
"436417", "Hüttschlag",
"433859", "Mürzsteg",
"432263", "Grossrussbach",
"435246", "Achenkirch",
"432768", "St\.\ Aegyd\ am\ Neuwalde",
"433588", "Katsch\ an\ der\ Mur",
"432615", "Lutzmannsburg",
"436272", "Oberndorf\ bei\ Salzburg",
"437675", "Ampflwang\ im\ Hausruckwald",
"432749", "Prinzersdorf",
"435376", "Thiersee",
"432736", "Paudorf",
"437583", "Kremsmünster",
"437282", "Neufelden",
"434258", "Gummern",
"432723", "Rabenstein\ an\ der\ Pielach",
"432916", "Riegersburg\,\ Hardegg",
"432826", "Rastenfeld",
"432142", "Gattendorf",
"433327", "St\.\ Michael\ im\ Burgenland",
"432216", "Leopoldsdorf\ im\ Marchfelde",
"433475", "Hürth",
"433178", "St\.\ Ruprecht\ an\ der\ Raab",
"433616", "Selzthal",
"434874", "Virgen",
"436412", "St\.\ Johann\ im\ Pongau",
"432684", "Schützen\ am\ Gebirge",
"435262", "Telfs",
"436455", "Untertauern",
"437752", "Ried\ im\ Innkreis",
"435224", "Wattens",
"433579", "Pöls",
"434283", "St\.\ Stefan\ im\ Gailtal",
"436277", "St\.\ Pantaleon",
"437235", "Gallneukirchen",
"433468", "St\.\ Oswald\ ob\ Eibiswald",
"435354", "Fieberbrunn",
"437416", "Wieselburg",
"437287", "Peilstein\ im\ Mühlviertel",
"436434", "Bad\ Gastein",
"432166", "Parndorf",
"435516", "Doren",
"433322", "Güssing",
"432147", "Zurndorf",
"437954", "St\.\ Georgen\ am\ Walde",
"435335", "Hopfgarten\ im\ Brixental",
"433364", "Hannersdorf",
"432844", "Karlstein\ an\ der\ Thaya",
"437254", "Grossraming",
"437482", "Scheibbs",
"432752", "Melk",
"435576", "Hohenems",
"433457", "Gleinstätten",
"432715", "Weissenkirchen\ in\ der\ Wachau",
"437684", "Frankenmarkt",
"436229", "Hof\ bei\ Salzburg",
"437261", "Schönau\ im\ Mühlkreis",
"436240", "Krispl",
"436542", "Zell\ am\ See",
"436243", "Abtenau",
"433682", "Stainach",
"432235", "Maria\-Lanzendorf",
"432623", "Pottendorf",
"435446", "St\.\ Anton\ am\ Arlberg",
"432987", "St\.\ Leonhard\ am\ Hornerwald",
"432620", "Willendorf",
"433842", "Leoben",
"433126", "Frohnleiten",
"436217", "Mattsee",
"435283", "Kaltenbach",
"435280", "Hochfügen",
"432287", "Strasshof\ an\ der\ Nordbahn",
"435582", "Klösterle",
"434354", "Preitenegg",
"437476", "Aschbach\-Markt",
"436472", "Mauterndorf",
"432173", "Gols",
"434224", "Pischeldorf",
"433118", "Sinabelkirchen",
"432254", "Ebreichsdorf",
"432865", "Litschau",
"433133", "Nestelbach",
"432649", "Mönichkirchen",
"434262", "Treibach",
"432954", "Göllersdorf",
"432636", "Puchberg\ am\ Schneeberg",
"437562", "Windischgarsten",
"437260", "Waldhausen",
"437263", "Bad\ Zell",
"433452", "Leibnitz",
"433353", "Oberschützen",
"432276", "Reidling",
"432757", "Pöchlarn",
"436234", "Zell\ am\ Moos",
"437487", "Gresten",
"437615", "Scharnstein",
"433687", "Schladming",
"432784", "Perschling",
"436547", "Kaprun",
"436241", "St\.\ Koloman",
"432878", "Traunstein",
"436566", "Bramberg\ am\ Wildkogel",
"434848", "Kartitsch",
"433144", "Köflach",
"437736", "Pram",
"432282", "Gänserndorf",
"437228", "Kematen\ an\ der\ Krems",
"433635", "Radmer",
"433847", "Trofaiach",
"436212", "Seekirchen\ am\ Wallersee",
"432982", "Horn",
"432621", "Sieggraben",
"433866", "Breitenau\ am\ Hochlantsch",
"434239", "St\.\ Kanzian\ am\ Klopeiner\ See",
"434267", "Metnitz",
"437216", "Helfenberg",
"434246", "Radenthein",
"435554", "Sonntag",
"43662", "Salzburg",
"437723", "Altheim",
"436477", "St\.\ Michael\ im\ Lungau",
"437435", "St\.\ Valentin",};
$areanames{de} = {"432233", "Preßbaum",
"432742", "Sankt\ Pölten",
"432647", "Krumbach\,\ Niederösterreich",
"432556", "Großkrut",
"436227", "Sankt\ Gilgen",
"433386", "Großsteinbach",
"432642", "Aspangberg\-Sankt\ Peter",
"433689", "Sankt\ Nikolai\ im\ Sölktal",
"433868", "Tragöß",
"437218", "Großtraberg",
"434286", "Weißbriach",
"432242", "Sankt\ Andrä\-Wördern",
"434879", "Sankt\ Veit\ in\ Defereggen",
"432823", "Großglobnitz",
"432857", "Bad\ Großpertholz",
"434785", "Außerfragant",
"433537", "Sankt\ Georgen\ ob\ Murau",
"434212", "Sankt\ Veit\ an\ der\ Glan",
"432815", "Großschönau",
"433585", "Sankt\ Lambrecht",
"432618", "Markt\ Sankt\ Martin",
"433123", "Sankt\ Oswald\ bei\ Plankenwarth",
"434357", "Sankt\ Paul\ im\ Lavanttal",
"434843", "Außervillgraten",
"435279", "Sankt\ Jodok\ am\ Brenner",
"434264", "Klein\ Sankt\ Paul",
"435557", "Sankt\ Gallenkirch",
"435245", "Hinterriß",
"433684", "Sankt\ Martin\ am\ Grimming",
"4313", "Wien",
"434783", "Reißeck",
"433362", "Großpetersdorf",
"436414", "Großarl",
"436565", "Neukirchen\ am\ Großvenediger",
"435352", "Sankt\ Johann\ in\ Tirol",
"432268", "Großmugl",
"4315", "Wien",
"432763", "Sankt\ Veit\ an\ der\ Gölsen",
"432847", "Groß\-Siegharts",
"434877", "Prägraten\ am\ Großvenediger",
"434253", "Sankt\ Jakob\ im\ Rosental",
"432249", "Groß\-Enzersdorf",
"432715", "Weißenkirchen\ in\ der\ Wachau",
"432987", "Sankt\ Leonhard\ am\ Hornerwald",
"435446", "Sankt\ Anton\ am\ Arlberg",
"436241", "Sankt\ Koloman",
"436477", "Sankt\ Michael\ im\ Lungau",
"437435", "Sankt\ Valentin",
"434239", "Sankt\ Kanzian\ am\ Klopeiner\ See",
"432768", "Sankt\ Aegyd\ am\ Neuwalde",
"432263", "Großrußbach",
"433327", "Sankt\ Michael\ im\ Burgenland",
"434283", "Sankt\ Stefan\ im\ Gailtal",
"436277", "Sankt\ Pantaleon",
"433468", "Sankt\ Oswald\ ob\ Eibiswald",
"433178", "Sankt\ Ruprecht\ an\ der\ Raab",
"436412", "Sankt\ Johann\ im\ Pongau",
"437254", "Großraming",
"437954", "Sankt\ Georgen\ am\ Walde",
"432674", "Weißenbach\ an\ der\ Triesting",
"432955", "Großweikersdorf",
"432822", "Zwettl\-Niederösterreich",
"433469", "Sankt\ Oswald\ im\ Freiland",
"433331", "Sankt\ Lorenzen\ am\ Wechsel",
"436276", "Nußdorf\ am\ Haunsberg",
"4318", "Wien",
"435678", "Weißenbach\ am\ Lech",
"437477", "Sankt\ Peter\ in\ der\ Au",
"435413", "Sankt\ Leonhard\ im\ Pitztal",
"437566", "Rosenau\ am\ Hengstpaß",
"433119", "Sankt\ Marein\ bei\ Graz",
"436476", "Sankt\ Margarethen\ im\ Lungau",
"434266", "Straßburg",
"437217", "Sankt\ Veit\ im\ Mühlkreis",
"436546", "Fusch\ an\ der\ Großglocknerstraße",
"436138", "Sankt\ Wolfgang\ im\ Salzkammergut",
"432756", "Sankt\ Leonhard\ am\ Forst",
"436545", "Bruck\ an\ der\ Großglocknerstraße",
"433158", "Sankt\ Anna\ am\ Aigen",
"433183", "Sankt\ Georgen\ an\ der\ Stiefing",
"437565", "Sankt\ Pankraz",
"432686", "Draßburg",
"434876", "Kals\ am\ Großglockner",
"433632", "Sankt\ Gallen",
"436215", "Straßwalchen",
"437956", "Unterweißenbach",
"437717", "Sankt\ Aegidi",
"437237", "Sankt\ Georgen\ an\ der\ Gusen",
"434226", "Sankt\ Margareten\ im\ Rosental",
"432617", "Draßmarkt",
"437232", "Sankt\ Martin\ im\ Mühlkreis",
"433864", "Sankt\ Marein\ im\ Mürztal",
"433477", "Sankt\ Peter\ am\ Ottersbach",
"432629", "Warth\,\ Niederösterreich",
"433843", "Sankt\ Michael\ in\ Obersteiermark",
"433575", "Sankt\ Johann\ am\ Tauern",
"436242", "Rußbach\ am\ Paß\ Gschütt",
"4316", "Wien",
"434358", "Sankt\ Andrä",
"433834", "Wald\ am\ Schoberpaß",
"436247", "Großgmain",
"433536", "Sankt\ Peter\ am\ Kammersberg",
"437224", "Sankt\ Florian",
"437751", "Sankt\ Martin\ im\ Innkreis",
"4317", "Wien",
"433464", "Groß\ Sankt\ Florian",
"433515", "Sankt\ Lorenzen\ bei\ Knittelfeld",
"432719", "Droß",
"433140", "Sankt\ Martin\ am\ Wöllmißberg",
"435449", "Fließ",
"4314", "Wien",
"434350", "Bad\ Sankt\ Leonhard\ im\ Lavanttal",
"437219", "Vorderweißenbach",
"433869", "Sankt\ Katharein\ an\ der\ Laming",
"434873", "Sankt\ Jakob\ in\ Defereggen",
"432680", "Sankt\ Margarethen\ im\ Burgenland",
"437945", "Sankt\ Oswald\ bei\ Freistadt",
"432812", "Groß\ Gerungs",
"434825", "Großkirchheim",
"437667", "Sankt\ Georgen\ im\ Attergau",
"4319", "Wien",
"4312", "Wien",};
my $timezones = {
               '' => [
                       'Europe/Vienna'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+43|\D)//g;
      my $self = bless({ country_code => '43', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
      return $self if ($self->is_valid());
      $number =~ s/^(?:0)//;
      $self = bless({ country_code => '43', number => $number, formatters => $formatters, validators => $validators, areanames => \%areanames}, $class);
      return $self->is_valid() ? $self : undef;
    }
1;