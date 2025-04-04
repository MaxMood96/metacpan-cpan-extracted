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
package Number::Phone::StubCountry::GR;
use base qw(Number::Phone::StubCountry);

use strict;
use warnings;
use utf8;
our $VERSION = 1.20250323211828;

my $formatters = [
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '
            21|
            7
          ',
                  'pattern' => '(\\d{2})(\\d{4})(\\d{4})'
                },
                {
                  'format' => '$1 $2',
                  'leading_digits' => '
            2(?:
              2|
              3[2-57-9]|
              4[2-469]|
              5[2-59]|
              6[2-9]|
              7[2-69]|
              8[2-49]
            )|
            5
          ',
                  'pattern' => '(\\d{4})(\\d{6})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '[2689]',
                  'pattern' => '(\\d{3})(\\d{3})(\\d{4})'
                },
                {
                  'format' => '$1 $2 $3',
                  'leading_digits' => '8',
                  'pattern' => '(\\d{3})(\\d{3,4})(\\d{5})'
                }
              ];

my $validators = {
                'fixed_line' => '
          2(?:
            1\\d\\d|
            2(?:
              2[1-46-9]|
              [36][1-8]|
              4[1-7]|
              5[1-4]|
              7[1-5]|
              [89][1-9]
            )|
            3(?:
              1\\d|
              2[1-57]|
              [35][1-3]|
              4[13]|
              7[1-7]|
              8[124-6]|
              9[1-79]
            )|
            4(?:
              1\\d|
              2[1-8]|
              3[1-4]|
              4[13-5]|
              6[1-578]|
              9[1-5]
            )|
            5(?:
              1\\d|
              [29][1-4]|
              3[1-5]|
              4[124]|
              5[1-6]
            )|
            6(?:
              1\\d|
              [269][1-6]|
              3[1245]|
              4[1-7]|
              5[13-9]|
              7[14]|
              8[1-5]
            )|
            7(?:
              1\\d|
              2[1-5]|
              3[1-6]|
              4[1-7]|
              5[1-57]|
              6[135]|
              9[125-7]
            )|
            8(?:
              1\\d|
              2[1-5]|
              [34][1-4]|
              9[1-57]
            )
          )\\d{6}
        ',
                'geographic' => '
          2(?:
            1\\d\\d|
            2(?:
              2[1-46-9]|
              [36][1-8]|
              4[1-7]|
              5[1-4]|
              7[1-5]|
              [89][1-9]
            )|
            3(?:
              1\\d|
              2[1-57]|
              [35][1-3]|
              4[13]|
              7[1-7]|
              8[124-6]|
              9[1-79]
            )|
            4(?:
              1\\d|
              2[1-8]|
              3[1-4]|
              4[13-5]|
              6[1-578]|
              9[1-5]
            )|
            5(?:
              1\\d|
              [29][1-4]|
              3[1-5]|
              4[124]|
              5[1-6]
            )|
            6(?:
              1\\d|
              [269][1-6]|
              3[1245]|
              4[1-7]|
              5[13-9]|
              7[14]|
              8[1-5]
            )|
            7(?:
              1\\d|
              2[1-5]|
              3[1-6]|
              4[1-7]|
              5[1-57]|
              6[135]|
              9[125-7]
            )|
            8(?:
              1\\d|
              2[1-5]|
              [34][1-4]|
              9[1-57]
            )
          )\\d{6}
        ',
                'mobile' => '
          68[57-9]\\d{7}|
          (?:
            69|
            94
          )\\d{8}
        ',
                'pager' => '',
                'personal_number' => '70\\d{8}',
                'specialrate' => '(
          8(?:
            0[16]|
            12|
            [27]5|
            50
          )\\d{7}
        )|(90[19]\\d{7})|(5005000\\d{3})',
                'toll_free' => '800\\d{7,9}',
                'voip' => ''
              };
my %areanames = ();
$areanames{en} = {"302524", "Paranesti",
"302397", "Asprovalta",
"302695", "Zakynthos",
"302491", "Farsala",
"302381", "Edessa",
"302897", "Limenas\ Chersonisou",
"302263", "Vilia",
"302655", "Konitsa",
"302273", "Samos",
"302521", "Drama",
"30281", "Heraklion",
"302227", "Kireas",
"302384", "Aridaia",
"302494", "Agia",
"302683", "Filippiada",
"302692", "Kalavryta",
"30231", "Thessaloniki",
"302296", "Megara",
"302644", "Thermo",
"302299", "Markopoulo\ Mesogaias",
"302634", "Nafpaktos",
"302833", "Amari\,\ Rethymno",
"302843", "Sitia",
"302432", "Kalabaka",
"302343", "Polykastro",
"302333", "Alexandria",
"302746", "Nemea",
"302736", "Kythera",
"302228", "Messapia",
"302723", "Pylos",
"302631", "Messolonghi",
"302445", "Mouzaki",
"302641", "Agrinio",
"302271", "Chios",
"302892", "Moires\,\ Heraklion",
"302352", "Litochoro",
"302684", "Kanalaki",
"302261", "Livadeia",
"302392", "Peraia\,\ Thessaloniki",
"302493", "Elassona",
"30261", "Patras",
"3021", "Athens\/Piraeus\/Salamina",
"302274", "Psara\,\ Chios",
"302681", "Arta",
"302395", "Sochos",
"302264", "Thisvi",
"302895", "Ano\ Viannos",
"302657", "Delvinaki",
"302523", "Kato\ Nevrokopi",
"302222", "Kymi",
"302341", "Kilkis",
"302626", "Andritsaina",
"302658", "Zitsa",
"302331", "Veria",
"302831", "Rethymno",
"302841", "Agios\ Nikolaos",
"302724", "Meligalas",
"302643", "Vonitsa",
"302844", "Tzermadio",
"302765", "Kopanaki",
"302834", "Perama\ Mylopotamou",
"302721", "Kalamata",
"302533", "Xylagani",
"302752", "Nafplio",
"302242", "Kos",
"302232", "Domokos",
"302792", "Kastri\ Kynourias",
"302386", "Amyntaio",
"302795", "Vytina",
"302288", "Kea",
"302755", "Astros",
"302235", "Kamena\ Vourla",
"302245", "Karpathos",
"302623", "Lechaina",
"302372", "Arnaia",
"302824", "Kolymvari",
"302463", "Ptolemaida",
"302251", "Mytilene",
"302741", "Corinth",
"302731", "Sparti",
"302291", "Lagonisi",
"302287", "Milos",
"302324", "Nea\ Zichni",
"302821", "Chania",
"30251", "Kavala",
"302254", "Agios\ Efstratios",
"302734", "Neapoli\,\ Voies",
"302744", "Loutraki",
"302294", "Rafina",
"302427", "Skiathos",
"302375", "Nikiti",
"302321", "Serres",
"302797", "Tropaia",
"302757", "Leonidio",
"302531", "Komotini",
"302541", "Xanthi",
"302237", "Karpenisi",
"302247", "Leros",
"302266", "Lidoriki",
"302544", "Echinos",
"302534", "Iasmos",
"30271", "Tripoli",
"302293", "Agia\ Sotira",
"302592", "Eleftheroupoli",
"302282", "Andros",
"302461", "Kozani",
"302665", "Igoumenitsa",
"302253", "Kalloni\,\ Lesbos",
"302743", "Xylokastro",
"302552", "Orestiada",
"302733", "Gytheio",
"302425", "Feres\,\ Magnesia",
"302621", "Burgas",
"302377", "Ierissos\/Mount\ Athos",
"302422", "Almyros",
"302323", "Sidirokastro",
"302662", "Lefkimmi",
"302238", "Stylida",
"302555", "Feres\,\ Evros",
"302464", "Servia",
"302285", "Naxos",
"302624", "Olympia",
"302823", "Kandanos",
"302332", "Naousa\,\ Imathia",
"302761", "Kyparissia",
"302433", "Farkadona",
"302443", "Sofades",
"302725", "Koroni",
"302556", "Kyprinos",
"302286", "Santorini",
"302842", "Ierapetra",
"302289", "Mykonos",
"302832", "Spyli",
"302722", "Messene",
"302666", "Paramythia",
"302426", "Zagora",
"302647", "Fyteies",
"302262", "Thebes",
"302891", "Arkalochori",
"302351", "Korinos",
"302272", "Kardamyla",
"302224", "Karystos",
"302685", "Athamania",
"302391", "Chalkidona",
"302693", "Kato\ Achaia",
"302682", "Preveza",
"302894", "Agia\ Varvara",
"30241", "Larissa",
"302221", "Chalcis",
"302275", "Agios\ Kirykos",
"302265", "Amfissa",
"302653", "Asprangeli",
"302394", "Lagkadas",
"302763", "Gargalianoi",
"302635", "Mataranga",
"302431", "Trikala",
"302376", "Stratoni",
"302645", "Lefkada",
"302441", "Karditsa",
"302268", "Aliartos",
"302642", "Amfilochia",
"302632", "Aitoliko",
"302444", "Palamas",
"302434", "Pyli",
"302382", "Giannitsa",
"302492", "Tyrnavos",
"302393", "Lagkadikia",
"302796", "Levidi",
"302236", "Makrakomi",
"302246", "Salakos\,\ Rhodes",
"302267", "Distomo",
"302694", "Chalandritsa",
"302353", "Aiginio",
"302893", "Pyrgos\,\ Crete",
"302651", "Ioannina",
"302223", "Aliveri",
"302522", "Prosotsani",
"302691", "Aigio",
"302495", "Gonnoi\/Makrychori",
"302385", "Florina",
"302591", "Chrysoupoli",
"302281", "Ano\ Syros",
"302297", "Aegina",
"302664", "Filiates",
"302674", "Sami\,\ Cephalonia",
"302424", "Skopelos",
"302373", "Nea\ Moudania",
"302622", "Amaliada",
"302747", "Stymfalia",
"302551", "Alexandroupoli",
"302462", "Grevena",
"302284", "Paros",
"302594", "Nea\ Peramos\,\ Kavala",
"302465", "Siatista",
"302661", "Corfu",
"302327", "Rodopoli",
"302671", "Argostoli",
"302625", "Krestena",
"302421", "Volos",
"302554", "Soufli",
"302399", "Kallikrateia",
"302396", "Vasilika",
"302233", "Atalanta",
"302243", "Kalymnos",
"302542", "Stavroupoli",
"302753", "Lygourio",
"302532", "Sapes",
"302226", "Aidipsos",
"302535", "Nea\ Kallisti",
"302229", "Eretria",
"302298", "Troezen\/Poros\/Hydra\/Spetses",
"302732", "Molaoi",
"302553", "Didymoteicho",
"302742", "Kiato",
"302252", "Agiasos\/Plomari",
"302467", "Kastoria",
"302325", "Irakleia\,\ Serres",
"302371", "Polygyros",
"302825", "Vamos",
"302593", "Thasos",
"302283", "Tinos",
"302292", "Lavrio",
"302295", "Afidnes",
"302374", "Kassandreia",
"302822", "Kissamos",
"302322", "Nigrita",
"302423", "Kala\ Nera",
"302735", "Molaoi",
"302663", "Corfu\ Island",
"302231", "Lamia",
"302241", "Rhodes",
"302751", "Argos",
"302791", "Megalopolis",
"302244", "Archangelos\,\ Rhodes",
"302234", "Amfikleia",
"302754", "Kranidi",
"302696", "Akrata",
"302656", "Metsovo",
"302659", "Kalentzi",
"302468", "Neapoli",};
$areanames{el} = {"302229", "Ερέτρια",
"302535", "Νέα\ Καλλίστη",
"302226", "Αιδηψός",
"302298", "Μέθανα\/Πόρος\/Σπέτσες",
"302396", "Βασιλικά",
"302399", "Καλλικράτεια",
"302233", "Αταλάντη",
"302243", "Κάλυμνος",
"302542", "Σταυρούπολη",
"302753", "Λυγουριό",
"302532", "Σάπες",
"302327", "Ροδόπολη\,\ Σερρών",
"302671", "Αργοστόλι",
"302625", "Κρέστενα",
"302421", "Βόλος",
"302284", "Πάρος",
"302594", "Νέα\ Πέραμος\ Καβάλας",
"302661", "Κέρκυρα",
"302465", "Σιάτιστα",
"302554", "Σουφλί",
"302674", "Σάμη",
"302424", "Σκόπελος",
"302281", "Σύρος",
"302591", "Χρυσούπολη",
"302297", "Αίγινα",
"302664", "Φιλιάτες",
"302747", "Καλιανοί",
"302551", "Αλεξανδρούπολη",
"302462", "Γρεβενά",
"302373", "Νέα\ Μουδανιά",
"302622", "Αμαλιάδα",
"302696", "Ακράτα",
"302244", "Αρχάγγελος",
"302234", "Αμφίκλεια",
"302754", "Κρανίδι",
"302659", "Καλέντζι\ Δωδώνης",
"302468", "Νεάπολη",
"302656", "Μέτσοβο",
"302231", "Λαμία",
"302241", "Ρόδος",
"302751", "Άργος",
"302791", "Μεγαλόπολη",
"302374", "Κασσάνδρεια",
"302822", "Κίσσαμος",
"302295", "Αφίδναι",
"302735", "Σκάλα",
"302663", "Σκριπερό",
"302322", "Νιγρίτα",
"302423", "Καλά\ Νερά",
"302371", "Πολύγυρος",
"302325", "Ηράκλεια\,\ Σερρών",
"302732", "Μολάοι",
"302742", "Κιάτο",
"302553", "Διδυμότειχο",
"302252", "Αγιάσος\/Πλωμάρι",
"302467", "Καστοριά",
"302593", "Θάσος",
"302283", "Τήνος",
"302292", "Λαύριο",
"302825", "Βάμος",
"30241", "Λάρισα",
"302693", "Κάτω\ Αχαΐα",
"302894", "Αγία\ Βαρβάρα\,\ Ηράκλειο\ Κρήτης",
"302682", "Πρέβεζα",
"302265", "Άμφισσα",
"302653", "Καρυές\ Ασπραγγέλων",
"302394", "Λαγκαδάς",
"302221", "Χαλκίδα",
"302275", "Άγιος\ Κήρυκος",
"302272", "Καρδάμυλα",
"302262", "Θήβα",
"302891", "Αρκαλοχώρι",
"302351", "Κατερίνη",
"302685", "Βουργαρέλι",
"302391", "Χαλκηδόνα",
"302224", "Κάρυστος",
"302426", "Ζαγορά",
"302647", "Νέο\ Χαλκιόπουλο\/Φυτείες",
"302722", "Μεσσήνη",
"302666", "Παραμυθιά",
"302725", "Κορώνη\ Πυλίας",
"302556", "Κυπρίνος",
"302332", "Νάουσα",
"302761", "Κυπαρισσία",
"302433", "Φαρκαδόνα",
"302443", "Σοφάδες",
"302842", "Ιεράπετρα",
"302289", "Μύκονος",
"302832", "Σπήλι",
"302286", "Θήρα",
"302223", "Αλιβέρι",
"302522", "Προσοτσάνη",
"302651", "Ιωάννινα",
"302691", "Αίγιο",
"302495", "Γόννοι\/Μακρυχώρι",
"302385", "Φλώρινα",
"302796", "Λεβίδι",
"302382", "Γιαννιτσά",
"302492", "Τύρναβος",
"302393", "Λαγκαδίκια",
"302267", "Δίστομο",
"302694", "Χαλανδρίτσα",
"302893", "Πύργος\,\ Κρήτη",
"302353", "Αιγίνιο",
"302236", "Μακρακώμη",
"302246", "Τήλος\/Σύμη\/Χάλκη\/Μεγίστη",
"302268", "Αλίαρτος",
"302642", "Αμφιλοχία",
"302632", "Αιτωλικό",
"302444", "Παλαμάς",
"302434", "Πύλη",
"302763", "Γαργαλιάνοι",
"302431", "Τρίκαλα",
"302635", "Ματαράγκα",
"302441", "Καρδίτσα",
"302645", "Λευκάδα",
"302376", "Στρατώνι",
"302254", "Άγιος\ Ευστράτιος\/Μούδρος\/Μύρινα",
"302734", "Νεάπολη",
"302744", "Λουτράκι",
"302821", "Χανιά",
"30251", "Καβάλα",
"302427", "Σκιάθος",
"302375", "Νικήτη",
"302321", "Σέρρες",
"302294", "Ραφήνα",
"302463", "Πτολεμαΐδα",
"302251", "Μυτιλήνη",
"302741", "Κόρινθος",
"302731", "Σπάρτη",
"302623", "Λεχαινά",
"302372", "Αρναία",
"302824", "Κολυμβάρι",
"302324", "Νέα\ Ζίχνη",
"302291", "Λαγονήσι",
"302287", "Μήλος",
"302795", "Βυτίνα",
"302288", "Κέα",
"302755", "Άστρος",
"302235", "Καμμένα\ Βούρλα",
"302245", "Κάρπαθος",
"302533", "Ξυλαγανή",
"302752", "Ναύπλιο",
"302242", "Κως",
"302232", "Δομοκός",
"302386", "Αμύνταιο",
"302792", "Καστρί\ Κυνουρίας",
"302662", "Λευκίμμη",
"302238", "Στυλίδα",
"302555", "Φέρες",
"302422", "Αλμυρός",
"302323", "Σιδηρόκαστρο",
"302624", "Αρχαία\ Ολυμπία",
"302823", "Κάντανος",
"302464", "Σέρβια",
"302285", "Νάξος",
"302293", "Άγιος\ Σωτήρας",
"302592", "Ελευθερούπολη",
"302282", "Άνδρος",
"302621", "Πύργος",
"302425", "Βελεστίνο",
"302377", "Άγιον\ Όρος\/Ιερισσός",
"302665", "Ηγουμενίτσα",
"302461", "Κοζάνη",
"302253", "Καλλονή\/Μήθυμνα",
"302552", "Ορεστιάδα",
"302743", "Ξυλόκαστρο",
"302733", "Γύθειο",
"30271", "Τρίπολη",
"302544", "Εχίνος",
"302534", "Ίασμος",
"302797", "Τροπαία",
"302266", "Λιδορίκι",
"302757", "Λεωνίδιο",
"302531", "Κομοτηνή",
"302541", "Ξάνθη",
"302237", "Καρπενήσι",
"302247", "Λέρος",
"302631", "Μεσολόγγι",
"302445", "Μουζάκι",
"302641", "Αγρίνιο",
"302723", "Πύλος",
"302644", "Θερμό",
"302299", "Μαρκόπουλο",
"302634", "Ναύπακτος",
"302833", "Αμάρι",
"302843", "Σητεία",
"302296", "Μέγαρα\/Νέα\ Πέραμος",
"302746", "Νεμέα",
"302736", "Κύθηρα",
"302228", "Ψαχνά",
"302432", "Καλαμπάκα",
"302343", "Πολύκαστρο",
"302333", "Αλεξάνδρεια",
"302384", "Αριδαία",
"302494", "Αγιά",
"302521", "Δράμα",
"30281", "Ηράκλειο",
"302227", "Μαντούδι",
"30231", "Θεσσαλονίκη",
"302683", "Φιλιππιάδα",
"302692", "Καλάβρυτα",
"302397", "Ασπροβάλτα",
"302491", "Φάρσαλα",
"302695", "Ζάκυνθος",
"302381", "Έδεσσα",
"302524", "Παρανέστι",
"302273", "Σάμος",
"302897", "Λιμένας\ Χερσονήσου",
"302263", "Βίλια",
"302655", "Κόνιτσα\/Πέρδικα\ Δωδώνης",
"302721", "Καλαμάτα",
"302643", "Βόνιτσα",
"302844", "Τζερμιάδο",
"302765", "Κοπανάκι",
"302834", "Πέραμα\ Μυλοποτάμου",
"302341", "Κιλκίς",
"302626", "Ανδρίτσαινα",
"302331", "Βέροια",
"302658", "Ζίτσα",
"302724", "Μελιγαλάς",
"302831", "Ρέθυμνο",
"302841", "Άγιος\ Νικόλαος",
"302681", "Άρτα",
"302395", "Σοχός",
"302264", "Δόμβραινα",
"3021", "Αθήνα\/Πειραιάς\/Σαλαμίνα",
"302274", "Βολισσός",
"302523", "Κάτω\ Νευροκόπι",
"302222", "Κύμη",
"302895", "Άνω\ Βιάννος",
"302657", "Δελβινάκι",
"302892", "Μοίρες\,\ Ηράκλειο",
"302352", "Λιτόχωρο",
"302684", "Καναλλάκι",
"302261", "Λειβαδιά",
"302271", "Χίος",
"30261", "Πάτρα",
"302392", "Περαία",
"302493", "Ελασσόνα",};
my $timezones = {
               '' => [
                       'Europe/Athens'
                     ]
             };

    sub new {
      my $class = shift;
      my $number = shift;
      $number =~ s/(^\+30|\D)//g;
      my $self = bless({ country_code => '30', number => $number, formatters => $formatters, validators => $validators, timezones => $timezones, areanames => \%areanames}, $class);
        return $self->is_valid() ? $self : undef;
    }
1;