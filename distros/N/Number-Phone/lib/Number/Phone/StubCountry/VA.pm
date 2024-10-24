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
package Number::Phone::StubCountry::VA;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20240910191017;

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
$areanames{it} = {"390884", "Manfredonia",
"390736", "Ascoli\ Piceno",
"390864", "Sulmona",
"390431", "Cervignano\ del\ Friuli",
"390924", "Alcamo",
"390384", "Mortara",
"390345", "San\ Pellegrino\ Terme",
"390472", "Bressanone",
"390974", "Vallo\ della\ Lucania",
"390941", "Patti",
"390773", "Latina",
"390143", "Novi\ Ligure",
"390364", "Breno",
"390524", "Fidenza",
"390735", "San\ Benedetto\ del\ Tronto",
"3906698", "Città\ del\ Vaticano",
"390463", "Cles",
"390346", "Clusone",
"390782", "Lanusei",
"390931", "Siracusa",
"390882", "San\ Severo",
"390474", "Brunico",
"390972", "Melfi",
"390362", "Seregno",
"390522", "Reggio\ nell\'Emilia",
"390424", "Bassano\ del\ Grappa",
"390835", "Matera",
"390746", "Rieti",
"390429", "Este",
"390572", "Montecatini\ Terme",
"390873", "Vasto",
"390737", "Camerino",
"390323", "Baveno",
"390789", "Olbia",
"390836", "Maglie",
"390983", "Rossano",
"390175", "Saluzzo",
"390784", "Nuoro",
"390373", "Crema",
"390438", "Conegliano",
"390125", "Ivrea",
"390933", "Caltagirone",
"39019", "Savona",
"390533", "Comacchio",
"390386", "Ostiglia",
"390742", "Foligno",
"390172", "Savigliano",
"390122", "Susa",
"390976", "Muro\ Lucano",
"390885", "Cerignola",
"390871", "Chieti",
"390332", "Varese",
"390427", "Spilimbergo",
"390975", "Sala\ Consilina",
"390981", "Castrovillari",
"390365", "Salò",
"390525", "Fornovo\ di\ Taro",
"390925", "Sciacca",
"390163", "Borgosesia",
"390385", "Stradella",
"390344", "Menaggio",
"390968", "Lamezia\ Terme",
"390433", "Tolmezzo",
"390588", "Volterra",
"390732", "Fabriano",
"39055", "Firenze",
"390828", "Battipaglia",
"390543", "Forlì",
"390124", "Rivarolo\ Canavese",
"390721", "Pesaro",
"390765", "Poggio\ Mirteto",
"390174", "Mondovì",
"390744", "Terni",
"390771", "Formia",
"390426", "Adria",
"390785", "Macomer",
"39081", "Napoli",
"390766", "Civitavecchia",
"39010", "Genova",
"390578", "Chianciano\ Terme",
"390343", "Chiavenna",
"390761", "Viterbo",
"390184", "Sanremo",
"390781", "Iglesias",
"390775", "Frosinone",
"390587", "Pontedera",
"390377", "Codogno",
"390534", "Porretta\ Terme",
"390967", "Soverato",
"390934", "Caltanissetta",
"390465", "Tione\ di\ Trento",
"390776", "Cassino",
"390421", "San\ Donà\ di\ Piave",
"390542", "Imola",
"390942", "Taormina",
"390471", "Bolzano",
"3906", "Roma",
"390827", "Sant\'Angelo\ dei\ Lombardi",
"390428", "Tarvisio",
"3902", "Milano",
"390376", "Mantova",
"390182", "Albenga",
"390966", "Palmi",
"390566", "Follonica",
"390833", "Gallipoli",
"390932", "Ragusa",
"390434", "Pordenone",
"390861", "Teramo",
"390439", "Feltre",
"390875", "Termoli",
"390743", "Spoleto",
"390985", "Scalea",
"390173", "Alba",
"390442", "Legnago",
"390971", "Potenza",
"39041", "Venezia",
"390565", "Piombino",
"390965", "Reggio\ di\ Calabria",
"390123", "Lanzo\ Torinese",
"390549", "Repubblica\ di\ San\ Marino",
"390921", "Cefalù",
"390375", "Casalmaggiore",
"390544", "Ravenna",
"390571", "Empoli",
"390381", "Vigevano",
"390585", "Massa",
"390935", "Enna",
"390872", "Lanciano",
"390547", "Cesena",
"390535", "Mirandola",
"390331", "Busto\ Arsizio",
"390982", "Paola",
"390166", "Saint\-Vincent",
"390445", "Schio",
"390322", "Arona",
"390437", "Belluno",
"390464", "Rovereto",
"390831", "Brindisi",
"390536", "Sassuolo",
"390863", "Avezzano",
"390883", "Andria",
"390363", "Treviglio",
"390973", "Lagonegro",
"390185", "Rapallo",
"390144", "Acqui\ Terme",
"390774", "Tivoli",
"390383", "Voghera",
"390573", "Pistoia",
"390165", "Aosta",
"390923", "Trapani",
"390121", "Pinerolo",
"390435", "Pieve\ di\ Cadore",
"390964", "Locri",
"390462", "Cavalese",
"390763", "Orvieto",
"390374", "Soresina",
"390545", "Lugo",
"390584", "Viareggio",
"390984", "Cosenza",
"390324", "Domodossola",
"390564", "Grosseto",
"390436", "Cortina\ d\'Ampezzo",
"390731", "Jesi",
"390423", "Montebelluna",
"390722", "Urbino",
"390546", "Faenza",
"390473", "Merano",
"390142", "Casale\ Monferrato",
"39011", "Torino",};
$areanames{en} = {"39059", "Modena",
"390862", "L\'Aquila",
"3902", "Milan",
"39048", "Gorizia",
"390882", "Foggia",
"39099", "Taranto",
"390586", "Livorno",
"390376", "Mantua",
"390522", "Reggio\ Emilia",
"390362", "Cremona\/Monza",
"390424", "Vicenza",
"390922", "Agrigento",
"390382", "Pavia",
"390825", "Avellino",
"390823", "Caserta",
"390881", "Foggia",
"390532", "Ferrara",
"39075", "Perugia",
"39070", "Cagliari",
"390789", "Sassari",
"39041", "Venice",
"390737", "Macerata",
"390565", "Livorno",
"390521", "Parma",
"390583", "Lucca",
"390921", "Palermo",
"390965", "Reggio\ Calabria",
"390549", "San\ Marino",
"390373", "Cremona",
"390585", "Massa\-Carrara",
"390161", "Vercelli",
"390125", "Turin",
"390963", "Vibo\ Valentia",
"390884", "Foggia",
"39010", "Genoa",
"39015", "Biella",
"39049", "Padova",
"39030", "Brescia",
"39035", "Bergamo",
"390343", "Sondrio",
"390924", "Trapani",
"390422", "Treviso",
"390541", "Rimini",
"390574", "Prato",
"39080", "Bari",
"39085", "Pescara",
"390974", "Salerno",
"390364", "Brescia",
"390733", "Macerata",
"390934", "Caltanissetta\ and\ Enna",
"390432", "Udine",
"390735", "Ascoli\ Piceno",
"390776", "Frosinone",
"390421", "Venice",
"3906698", "Vatican\ City",
"39051", "Bologna",
"39013", "Alessandria",
"39091", "Palermo",
"390471", "Bolzano\/Bozen",
"390444", "Vicenza",
"390942", "Catania",
"390346", "Bergamo",
"3906", "Rome",
"39033", "Varese",
"39090", "Messina",
"39095", "Catania",
"390874", "Campobasso",
"390824", "Benevento",
"39055", "Florence",
"390732", "Ancona",
"39050", "Pisa",
"390543", "Forlì\-Cesena",
"390545", "Ravenna",
"390341", "Lecco",
"390783", "Oristano",
"390324", "Verbano\-Cusio\-Ossola",
"390426", "Rovigo",
"390141", "Asti",
"39081", "Naples",
"39079", "Sassari",
"390577", "Siena",
"390187", "La\ Spezia",
"390731", "Ancona",
"390461", "Trento",
"390425", "Rovigo",
"390342", "Sondrio",
"39031", "Como",
"390423", "Treviso",
"39011", "Turin",
"39039", "Monza",
"390734", "Fermo",
"390933", "Caltanissetta",
"39040", "Trieste",
"39045", "Verona",
"390445", "Vicenza",
"390166", "Aosta\ Valley",
"39071", "Ancona",
"390322", "Novara",
"39089", "Salerno",
"390962", "Crotone",
"390372", "Cremona",
"390122", "Turin",
"390865", "Isernia",
"390883", "Andria\ Barletta\ Trani",
"390523", "Piacenza",
"390975", "Potenza",
"390183", "Imperia",
"390363", "Bergamo",
"390171", "Cuneo",
"390321", "Novara",
"390774", "Rome",
"390185", "Genoa",
"390365", "Brescia",
"390961", "Catanzaro",
"390925", "Agrigento",
"390832", "Lecce",
"390344", "Como",
"390575", "Arezzo",
"390371", "Lodi",
"390165", "Aosta\ Valley",};
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