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
package Number::Phone::StubCountry::VA;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20260904101551;

my $formatters = [];

my $validators = {
                'fixed_line' => '06698\\d{1,6}',
                'geographic' => '06698\\d{1,6}',
                'mobile' => '
          3[1-9]\\d{8}|
          3[2-9]\\d{7}
        ',
                'pager' => '',
                'personal_number' => '
          1(?:
            78\\d|
            99
          )\\d{6}
        ',
                'specialrate' => '(
          84(?:
            [08]\\d{3}|
            [17]
          )\\d{3}
        )|(
          (?:
            0878\\d{3}|
            89(?:
              2\\d|
              3[04]|
              4(?:
                [0-4]|
                [5-9]\\d\\d
              )|
              5[0-4]
            )
          )\\d\\d|
          (?:
            1(?:
              44|
              6[346]
            )|
            89(?:
              38|
              5[5-9]|
              9
            )
          )\\d{6}
        )',
                'toll_free' => '
          80(?:
            0\\d{3}|
            3
          )\\d{3}
        ',
                'voip' => '55\\d{8}'
              };
my %areanames = ();
$areanames{en} = {"390421", "Venice",
"390141", "Asti",
"39041", "Venice",
"390737", "Macerata",
"390732", "Ancona",
"39011", "Turin",
"390425", "Rovigo",
"390884", "Foggia",
"390363", "Bergamo",
"390774", "Rome",
"390426", "Rovigo",
"390322", "Novara",
"39049", "Padova",
"390125", "Turin",
"390342", "Sondrio",
"390445", "Vicenza",
"39099", "Taranto",
"39070", "Cagliari",
"390865", "Isernia",
"390925", "Agrigento",
"390565", "Livorno",
"390382", "Pavia",
"3902", "Milan",
"390577", "Siena",
"390824", "Benevento",
"39030", "Brescia",
"390921", "Palermo",
"39091", "Palermo",
"390185", "Genoa",
"390934", "Caltanissetta\ and\ Enna",
"390545", "Ravenna",
"390961", "Catanzaro",
"3906698", "Vatican\ City",
"390924", "Trapani",
"39059", "Modena",
"39081", "Naples",
"390831", "Brindisi",
"39035", "Bergamo",
"39089", "Salerno",
"390783", "Oristano",
"390541", "Rimini",
"390965", "Reggio\ Calabria",
"39075", "Perugia",
"390825", "Avellino",
"390549", "San\ Marino",
"39051", "Bologna",
"390521", "Parma",
"390376", "Mantua",
"390343", "Sondrio",
"390166", "Aosta\ Valley",
"390165", "Aosta\ Valley",
"390362", "Cremona\/Monza",
"390585", "Massa\-Carrara",
"390881", "Foggia",
"390586", "Livorno",
"390444", "Vicenza",
"390733", "Macerata",
"390161", "Vercelli",
"390371", "Lodi",
"390776", "Frosinone",
"39033", "Varese",
"390461", "Trento",
"390424", "Vicenza",
"390963", "Vibo\ Valentia",
"390922", "Agrigento",
"390862", "L\'Aquila",
"390942", "Catania",
"390823", "Caserta",
"39040", "Trieste",
"390575", "Arezzo",
"390543", "Forlì\-Cesena",
"390523", "Piacenza",
"390974", "Salerno",
"39010", "Genoa",
"390789", "Sassari",
"390187", "La\ Spezia",
"390341", "Lecco",
"390735", "Ascoli\ Piceno",
"390883", "Andria\ Barletta\ Trani",
"39079", "Sassari",
"390364", "Brescia",
"390321", "Novara",
"39090", "Messina",
"39031", "Como",
"39085", "Pescara",
"39039", "Monza",
"390346", "Bergamo",
"390373", "Cremona",
"39071", "Ancona",
"390731", "Ancona",
"390122", "Turin",
"390432", "Udine",
"39055", "Florence",
"390422", "Treviso",
"390583", "Lucca",
"390423", "Treviso",
"390365", "Brescia",
"390734", "Fermo",
"390372", "Cremona",
"39050", "Pisa",
"390882", "Foggia",
"390171", "Cuneo",
"390324", "Verbano\-Cusio\-Ossola",
"390344", "Como",
"39013", "Alessandria",
"39080", "Bari",
"390471", "Bolzano\/Bozen",
"39095", "Catania",
"390522", "Reggio\ Emilia",
"390532", "Ferrara",
"39045", "Verona",
"390183", "Imperia",
"390874", "Campobasso",
"39015", "Biella",
"390832", "Lecce",
"39048", "Gorizia",
"390975", "Potenza",
"390962", "Crotone",
"390933", "Caltanissetta",
"3906", "Rome",
"390574", "Prato",};
$areanames{it} = {"390732", "Fabriano",
"390374", "Soresina",
"390439", "Feltre",
"39011", "Torino",
"390985", "Scalea",
"390742", "Foligno",
"390431", "Cervignano\ del\ Friuli",
"39041", "Venezia",
"390584", "Viareggio",
"390473", "Merano",
"390981", "Castrovillari",
"390445", "Schio",
"390884", "Manfredonia",
"390332", "Varese",
"390774", "Tivoli",
"390173", "Alba",
"390426", "Adria",
"390435", "Pieve\ di\ Cadore",
"390782", "Lanusei",
"390872", "Lanciano",
"390935", "Enna",
"390544", "Ravenna",
"390973", "Lagonegro",
"390534", "Porretta\ Terme",
"390572", "Montecatini\ Terme",
"390931", "Siracusa",
"390185", "Rapallo",
"3902", "Milano",
"390941", "Patti",
"390566", "Follonica",
"390864", "Sulmona",
"390536", "Sassuolo",
"390525", "Fornovo\ di\ Taro",
"390546", "Faenza",
"390924", "Alcamo",
"390836", "Maglie",
"390564", "Grosseto",
"390965", "Reggio\ di\ Calabria",
"390362", "Seregno",
"390465", "Tione\ di\ Trento",
"390323", "Baveno",
"390376", "Mantova",
"390165", "Aosta",
"390776", "Cassino",
"390424", "Bassano\ del\ Grappa",
"390124", "Rivarolo\ Canavese",
"390833", "Gallipoli",
"390942", "Taormina",
"390381", "Vigevano",
"390571", "Empoli",
"390932", "Ragusa",
"390875", "Termoli",
"390785", "Macomer",
"390974", "Vallo\ della\ Lucania",
"39010", "Genova",
"390789", "Olbia",
"390533", "Comacchio",
"390385", "Stradella",
"390182", "Albenga",
"390781", "Iglesias",
"390543", "Forlì",
"390871", "Chieti",
"390883", "Andria",
"390174", "Mondovì",
"390773", "Latina",
"390331", "Busto\ Arsizio",
"390982", "Paola",
"390474", "Brunico",
"390735", "San\ Benedetto\ del\ Tronto",
"390142", "Casale\ Monferrato",
"390428", "Tarvisio",
"390427", "Spilimbergo",
"390442", "Legnago",
"390373", "Crema",
"390731", "Jesi",
"390345", "San\ Pellegrino\ Terme",
"390587", "Pontedera",
"390588", "Volterra",
"390761", "Viterbo",
"390123", "Lanzo\ Torinese",
"390462", "Cavalese",
"390377", "Codogno",
"390365", "Salò",
"390423", "Montebelluna",
"390765", "Poggio\ Mirteto",
"390324", "Domodossola",
"390547", "Cesena",
"390522", "Reggio\ nell\'Emilia",
"3906", "Roma",
"390923", "Trapani",
"390863", "Avezzano",
"390976", "Muro\ Lucano",
"390763", "Orvieto",
"390429", "Este",
"390121", "Pinerolo",
"390722", "Urbino",
"390464", "Rovereto",
"390421", "San\ Donà\ di\ Piave",
"390737", "Camerino",
"390125", "Ivrea",
"390363", "Treviglio",
"39019", "Savona",
"390436", "Cortina\ d\'Ampezzo",
"390322", "Arona",
"390925", "Sciacca",
"390524", "Fidenza",
"390964", "Locri",
"390921", "Cefalù",
"390565", "Piombino",
"390578", "Chianciano\ Terme",
"390861", "Teramo",
"390535", "Mirandola",
"390383", "Voghera",
"39081", "Napoli",
"390545", "Lugo",
"390934", "Caltanissetta",
"390573", "Pistoia",
"3906698", "Città\ del\ Vaticano",
"390972", "Melfi",
"390549", "Repubblica\ di\ San\ Marino",
"390835", "Matera",
"390184", "Sanremo",
"390873", "Vasto",
"390966", "Palmi",
"390585", "Massa",
"390172", "Savigliano",
"390771", "Formia",
"390343", "Chiavenna",
"390984", "Cosenza",
"390166", "Saint\-Vincent",
"390472", "Bressanone",
"390375", "Casalmaggiore",
"390144", "Acqui\ Terme",
"390743", "Spoleto",
"390434", "Pordenone",
"390775", "Frosinone",
"390885", "Cerignola",
"390386", "Ostiglia",
"390364", "Breno",
"390746", "Rieti",
"390736", "Ascoli\ Piceno",
"39055", "Firenze",
"390463", "Cles",
"390163", "Borgosesia",
"390721", "Pesaro",
"390346", "Clusone",
"390437", "Belluno",
"390122", "Susa",
"390438", "Conegliano",
"390433", "Tolmezzo",
"390744", "Terni",
"390143", "Novi\ Ligure",
"390175", "Saluzzo",
"390983", "Rossano",
"390344", "Menaggio",
"390766", "Civitavecchia",
"390471", "Bolzano",
"390882", "San\ Severo",
"390784", "Nuoro",
"390542", "Imola",
"390971", "Potenza",
"390828", "Battipaglia",
"390827", "Sant\'Angelo\ dei\ Lombardi",
"390933", "Caltagirone",
"390384", "Mortara",
"390975", "Sala\ Consilina",
"390968", "Lamezia\ Terme",
"390967", "Soverato",};
my $timezones = {
               '' => [
                       'Europe/Rome',
                       'Europe/Vatican'
                     ],
               '0' => [
                        'Europe/Rome'
                      ],
               '06698' => [
                            'Europe/Vatican'
                          ],
               '0878' => [
                           'Europe/Rome',
                           'Europe/Vatican'
                         ],
               '1' => [
                        'Europe/Rome',
                        'Europe/Vatican'
                      ],
               '3' => [
                        'Europe/Rome',
                        'Europe/Vatican'
                      ],
               '4' => [
                        'Europe/Rome'
                      ],
               '5' => [
                        'Europe/Rome',
                        'Europe/Vatican'
                      ],
               '7' => [
                        'Europe/Rome'
                      ],
               '8' => [
                        'Europe/Rome',
                        'Europe/Vatican'
                      ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+39|\D)//g;
      my $self = bless({ country_code => '39', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;