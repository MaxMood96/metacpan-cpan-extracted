#!/usr/bin/perl
# Do not normalise this test file. It has deliberately unnormalised characters in it.
use v5.10;
use strict;
use warnings;
use utf8;
use if $^V ge v5.12.0, feature => 'unicode_strings';

use Test::More tests => 24;
use Test::Exception;

use ok 'Locale::CLDR';

my $locale = Locale::CLDR->new('de_DE');
my $other_locale = Locale::CLDR->new('de_BE');

is($locale->locale_name(), 'Deutsch (Deutschland)', 'Locale name from current locale');
is($locale->locale_name('fr_CA'), 'Französisch (Kanada)', 'Locale name from string');
is($locale->locale_name($other_locale), 'Deutsch (Belgien)', 'Locale name from other locale object');

is($locale->language_name(), 'Deutsch', 'Language name from current locale');
is($locale->language_name('fr'), 'Französisch', 'Language name from string');
is($locale->language_name($other_locale), 'Deutsch', 'Language name from other locale object');

my $all_languages = {
    'aa' => 'Afar',
    'ab' => 'Abchasisch',
    'ace' => 'Aceh',
    'ach' => 'Acholi',
    'ada' => 'Adangme',
    'ady' => 'Adygeisch',
    'ae' => 'Avestisch',
    'aeb' => 'Tunesisches Arabisch',
    'af' => 'Afrikaans',
    'afh' => 'Afrihili',
    'agq' => 'Aghem',
    'ain' => 'Ainu',
    'ak' => 'Akan',
    'akk' => 'Akkadisch',
    'akz' => 'Alabama',
    'ale' => 'Aleutisch',
    'aln' => 'Gegisch',
    'alt' => 'Süd-Altaisch',
    'am' => 'Amharisch',
    'an' => 'Aragonesisch',
    'ang' => 'Altenglisch',
    'ann' => 'Obolo',
    'anp' => 'Angika',
    'ar' => 'Arabisch',
    'ar_001' => 'Modernes Hocharabisch',
    'arc' => 'Aramäisch',
    'arn' => 'Mapudungun',
    'aro' => 'Araona',
    'arp' => 'Arapaho',
    'arq' => 'Algerisches Arabisch',
    'ars' => 'Arabisch (Nadschd)',
    'arw' => 'Arawak',
    'ary' => 'Marokkanisches Arabisch',
    'arz' => 'Ägyptisches Arabisch',
    'as' => 'Assamesisch',
    'asa' => 'Asu',
    'ase' => 'Amerikanische Gebärdensprache',
    'ast' => 'Asturisch',
    'atj' => 'Atikamekw',
    'av' => 'Awarisch',
    'avk' => 'Kotava',
    'awa' => 'Awadhi',
    'ay' => 'Aymara',
    'az' => 'Aserbaidschanisch',
    'ba' => 'Baschkirisch',
    'bal' => 'Belutschisch',
    'ban' => 'Balinesisch',
    'bar' => 'Bairisch',
    'bas' => 'Bassa',
    'bax' => 'Bamun',
    'bbc' => 'Batak Toba',
    'bbj' => 'Ghomala',
    'be' => 'Belarussisch',
    'bej' => 'Bedauye',
    'bem' => 'Bemba',
    'bew' => 'Betawi',
    'bez' => 'Bena',
    'bfd' => 'Bafut',
    'bfq' => 'Badaga',
    'bg' => 'Bulgarisch',
    'bgc' => 'Haryanvi',
    'bgn' => 'Westliches Belutschi',
    'bho' => 'Bhodschpuri',
    'bi' => 'Bislama',
    'bik' => 'Bikol',
    'bin' => 'Bini',
    'bjn' => 'Banjaresisch',
    'bkm' => 'Kom',
    'bla' => 'Blackfoot',
    'blo' => 'Anii',
    'bm' => 'Bambara',
    'bn' => 'Bengalisch',
    'bo' => 'Tibetisch',
    'bpy' => 'Bishnupriya',
    'bqi' => 'Bachtiarisch',
    'br' => 'Bretonisch',
    'bra' => 'Braj-Bhakha',
    'brh' => 'Brahui',
    'brx' => 'Bodo',
    'bs' => 'Bosnisch',
    'bss' => 'Akoose',
    'bua' => 'Burjatisch',
    'bug' => 'Buginesisch',
    'bum' => 'Bulu',
    'byn' => 'Blin',
    'byv' => 'Medumba',
    'ca' => 'Katalanisch',
    'cad' => 'Caddo',
    'car' => 'Karibisch',
    'cay' => 'Cayuga',
    'cch' => 'Atsam',
    'ccp' => 'Chakma',
    'ce' => 'Tschetschenisch',
    'ceb' => 'Cebuano',
    'cgg' => 'Rukiga',
    'ch' => 'Chamorro',
    'chb' => 'Chibcha',
    'chg' => 'Tschagataisch',
    'chk' => 'Chuukesisch',
    'chm' => 'Mari',
    'chn' => 'Chinook',
    'cho' => 'Choctaw',
    'chp' => 'Chipewyan',
    'chr' => 'Cherokee',
    'chy' => 'Cheyenne',
    'ckb' => 'Zentralkurdisch',
    'ckb@alt=menu' => 'Kurdisch (Sorani)',
    'clc' => 'Chilcotin',
    'co' => 'Korsisch',
    'cop' => 'Koptisch',
    'cps' => 'Capiznon',
    'cr' => 'Cree',
    'crg' => 'Michif',
    'crh' => 'Krimtatarisch',
    'crj' => 'Südost-Cree',
    'crk' => 'Plains-Cree',
    'crl' => 'Northern East Cree',
    'crm' => 'Moose Cree',
    'crr' => 'Carolina-Algonkin',
    'crs' => 'Seychellenkreol',
    'cs' => 'Tschechisch',
    'csb' => 'Kaschubisch',
    'csw' => 'Swampy Cree',
    'cu' => 'Kirchenslawisch',
    'cv' => 'Tschuwaschisch',
    'cy' => 'Walisisch',
    'da' => 'Dänisch',
    'dak' => 'Dakota',
    'dar' => 'Darginisch',
    'dav' => 'Taita',
    'de' => 'Deutsch',
    'de_AT' => 'Österreichisches Deutsch',
    'de_CH' => 'Schweizer Hochdeutsch',
    'del' => 'Delaware',
    'den' => 'Slave',
    'dgr' => 'Dogrib',
    'din' => 'Dinka',
    'dje' => 'Zarma',
    'doi' => 'Dogri',
    'dsb' => 'Niedersorbisch',
    'dtp' => 'Zentral-Dusun',
    'dua' => 'Duala',
    'dum' => 'Mittelniederländisch',
    'dv' => 'Dhivehi',
    'dyo' => 'Diola',
    'dyu' => 'Dyula',
    'dz' => 'Dzongkha',
    'dzg' => 'Dazaga',
    'ebu' => 'Embu',
    'ee' => 'Ewe',
    'efi' => 'Efik',
    'egl' => 'Emilianisch',
    'egy' => 'Ägyptisch',
    'eka' => 'Ekajuk',
    'el' => 'Griechisch',
    'elx' => 'Elamisch',
    'en' => 'Englisch',
    'en_GB@alt=short' => 'Englisch (GB)',
    'enm' => 'Mittelenglisch',
    'eo' => 'Esperanto',
    'es' => 'Spanisch',
    'esu' => 'Zentral-Alaska-Yupik',
    'et' => 'Estnisch',
    'eu' => 'Baskisch',
    'ewo' => 'Ewondo',
    'ext' => 'Extremadurisch',
    'fa' => 'Persisch',
    'fa_AF' => 'Dari',
    'fan' => 'Pangwe',
    'fat' => 'Fanti',
    'ff' => 'Ful',
    'fi' => 'Finnisch',
    'fil' => 'Filipino',
    'fit' => 'Meänkieli',
    'fj' => 'Fidschi',
    'fo' => 'Färöisch',
    'fon' => 'Fon',
    'fr' => 'Französisch',
    'frc' => 'Cajun',
    'frm' => 'Mittelfranzösisch',
    'fro' => 'Altfranzösisch',
    'frp' => 'Frankoprovenzalisch',
    'frr' => 'Nordfriesisch',
    'frs' => 'Ostfriesisch',
    'fur' => 'Friaulisch',
    'fy' => 'Westfriesisch',
    'ga' => 'Irisch',
    'gaa' => 'Ga',
    'gag' => 'Gagausisch',
    'gan' => 'Gan',
    'gay' => 'Gayo',
    'gba' => 'Gbaya',
    'gbz' => 'Gabri',
    'gd' => 'Gälisch (Schottland)',
    'gez' => 'Geez',
    'gil' => 'Kiribatisch',
    'gl' => 'Galicisch',
    'glk' => 'Gilaki',
    'gmh' => 'Mittelhochdeutsch',
    'gn' => 'Guaraní',
    'goh' => 'Althochdeutsch',
    'gon' => 'Gondi',
    'gor' => 'Mongondou',
    'got' => 'Gotisch',
    'grb' => 'Grebo',
    'grc' => 'Altgriechisch',
    'gsw' => 'Schweizerdeutsch',
    'gu' => 'Gujarati',
    'guc' => 'Wayúu',
    'gur' => 'Farefare',
    'guz' => 'Gusii',
    'gv' => 'Manx',
    'gwi' => 'Kutchin',
    'ha' => 'Haussa',
    'hai' => 'Haida',
    'hak' => 'Hakka',
    'haw' => 'Hawaiisch',
    'hax' => 'Süd-Haida',
    'he' => 'Hebräisch',
    'hi' => 'Hindi',
    'hi_Latn' => 'Hindi (lateinisch)',
    'hi_Latn@alt=variant' => 'Hinglish',
    'hif' => 'Fidschi-Hindi',
    'hil' => 'Hiligaynon',
    'hit' => 'Hethitisch',
    'hmn' => 'Miao',
    'ho' => 'Hiri-Motu',
    'hr' => 'Kroatisch',
    'hsb' => 'Obersorbisch',
    'hsn' => 'Xiang',
    'ht' => 'Haiti-Kreolisch',
    'hu' => 'Ungarisch',
    'hup' => 'Hupa',
    'hur' => 'Halkomelem',
    'hy' => 'Armenisch',
    'hz' => 'Herero',
    'ia' => 'Interlingua',
    'iba' => 'Iban',
    'ibb' => 'Ibibio',
    'id' => 'Indonesisch',
    'ie' => 'Interlingue',
    'ig' => 'Igbo',
    'ii' => 'Yi',
    'ik' => 'Inupiak',
    'ikt' => 'Westkanadisches Inuktitut',
    'ilo' => 'Ilokano',
    'inh' => 'Inguschisch',
    'io' => 'Ido',
    'is' => 'Isländisch',
    'it' => 'Italienisch',
    'iu' => 'Inuktitut',
    'izh' => 'Ischorisch',
    'ja' => 'Japanisch',
    'jam' => 'Jamaikanisch-Kreolisch',
    'jbo' => 'Lojban',
    'jgo' => 'Ngomba',
    'jmc' => 'Machame',
    'jpr' => 'Jüdisch-Persisch',
    'jrb' => 'Jüdisch-Arabisch',
    'jut' => 'Jütisch',
    'jv' => 'Javanisch',
    'ka' => 'Georgisch',
    'kaa' => 'Karakalpakisch',
    'kab' => 'Kabylisch',
    'kac' => 'Kachin',
    'kaj' => 'Jju',
    'kam' => 'Kamba',
    'kaw' => 'Kawi',
    'kbd' => 'Kabardinisch',
    'kbl' => 'Kanembu',
    'kcg' => 'Tyap',
    'kde' => 'Makonde',
    'kea' => 'Kabuverdianu',
    'ken' => 'Kenyang',
    'kfo' => 'Koro',
    'kg' => 'Kongolesisch',
    'kgp' => 'Kaingang',
    'kha' => 'Khasi',
    'kho' => 'Sakisch',
    'khq' => 'Koyra Chiini',
    'khw' => 'Khowar',
    'ki' => 'Kikuyu',
    'kiu' => 'Kirmanjki',
    'kj' => 'Kwanyama',
    'kk' => 'Kasachisch',
    'kkj' => 'Kako',
    'kl' => 'Grönländisch',
    'kln' => 'Kalenjin',
    'km' => 'Khmer',
    'kmb' => 'Kimbundu',
    'kn' => 'Kannada',
    'ko' => 'Koreanisch',
    'koi' => 'Komi-Permjakisch',
    'kok' => 'Konkani',
    'kos' => 'Kosraeanisch',
    'kpe' => 'Kpelle',
    'kr' => 'Kanuri',
    'krc' => 'Karatschaiisch-Balkarisch',
    'kri' => 'Krio',
    'krj' => 'Kinaray-a',
    'krl' => 'Karelisch',
    'kru' => 'Oraon',
    'ks' => 'Kaschmiri',
    'ksb' => 'Shambala',
    'ksf' => 'Bafia',
    'ksh' => 'Kölsch',
    'ku' => 'Kurdisch',
    'kum' => 'Kumükisch',
    'kut' => 'Kutenai',
    'kv' => 'Komi',
    'kw' => 'Kornisch',
    'kwk' => 'Kwakʼwala',
    'kxv' => 'Kuvi',
    'ky' => 'Kirgisisch',
    'la' => 'Latein',
    'lad' => 'Ladino',
    'lag' => 'Langi',
    'lah' => 'Lahnda',
    'lam' => 'Lamba',
    'lb' => 'Luxemburgisch',
    'lez' => 'Lesgisch',
    'lfn' => 'Lingua Franca Nova',
    'lg' => 'Ganda',
    'li' => 'Limburgisch',
    'lij' => 'Ligurisch',
    'lil' => 'Lillooet',
    'liv' => 'Livisch',
    'lkt' => 'Lakota',
    'lmo' => 'Lombardisch',
    'ln' => 'Lingala',
    'lo' => 'Laotisch',
    'lol' => 'Mongo',
    'lou' => 'Kreol (Louisiana)',
    'loz' => 'Lozi',
    'lrc' => 'Nördliches Luri',
    'lsm' => 'Saamia',
    'lt' => 'Litauisch',
    'ltg' => 'Lettgallisch',
    'lu' => 'Luba-Katanga',
    'lua' => 'Luba-Lulua',
    'lui' => 'Luiseno',
    'lun' => 'Lunda',
    'luo' => 'Luo',
    'lus' => 'Lushai',
    'luy' => 'Luhya',
    'lv' => 'Lettisch',
    'lzh' => 'Klassisches Chinesisch',
    'lzz' => 'Lasisch',
    'mad' => 'Maduresisch',
    'maf' => 'Mafa',
    'mag' => 'Khotta',
    'mai' => 'Maithili',
    'mak' => 'Makassarisch',
    'man' => 'Malinke',
    'mas' => 'Massai',
    'mde' => 'Maba',
    'mdf' => 'Mokschanisch',
    'mdr' => 'Mandaresisch',
    'men' => 'Mende',
    'mer' => 'Meru',
    'mfe' => 'Morisyen',
    'mg' => 'Malagasy',
    'mga' => 'Mittelirisch',
    'mgh' => 'Makhuwa-Meetto',
    'mgo' => 'Meta’',
    'mh' => 'Marschallesisch',
    'mi' => 'Māori',
    'mic' => 'Micmac',
    'min' => 'Minangkabau',
    'mk' => 'Mazedonisch',
    'ml' => 'Malayalam',
    'mn' => 'Mongolisch',
    'mnc' => 'Mandschurisch',
    'mni' => 'Meithei',
    'moe' => 'Innu-Aimun',
    'moh' => 'Mohawk',
    'mos' => 'Mossi',
    'mr' => 'Marathi',
    'mrj' => 'Bergmari',
    'ms' => 'Malaiisch',
    'mt' => 'Maltesisch',
    'mua' => 'Mundang',
    'mul' => 'Mehrsprachig',
    'mus' => 'Muskogee',
    'mwl' => 'Mirandesisch',
    'mwr' => 'Marwari',
    'mwv' => 'Mentawai',
    'my' => 'Birmanisch',
    'mye' => 'Myene',
    'myv' => 'Ersja-Mordwinisch',
    'mzn' => 'Masanderanisch',
    'na' => 'Nauruisch',
    'nan' => 'Min Nan',
    'nap' => 'Neapolitanisch',
    'naq' => 'Nama',
    'nb' => 'Norwegisch (Bokmål)',
    'nd' => 'Nord-Ndebele',
    'nds' => 'Niederdeutsch',
    'nds_NL' => 'Niedersächsisch',
    'ne' => 'Nepalesisch',
    'new' => 'Newari',
    'ng' => 'Ndonga',
    'nia' => 'Nias',
    'niu' => 'Niue',
    'njo' => 'Ao-Naga',
    'nl' => 'Niederländisch',
    'nl_BE' => 'Flämisch',
    'nmg' => 'Kwasio',
    'nn' => 'Norwegisch (Nynorsk)',
    'nnh' => 'Ngiemboon',
    'no' => 'Norwegisch',
    'nog' => 'Nogai',
    'non' => 'Altnordisch',
    'nov' => 'Novial',
    'nqo' => 'N’Ko',
    'nr' => 'Süd-Ndebele',
    'nso' => 'Nord-Sotho',
    'nus' => 'Nuer',
    'nv' => 'Navajo',
    'nwc' => 'Alt-Newari',
    'ny' => 'Nyanja',
    'nym' => 'Nyamwezi',
    'nyn' => 'Nyankole',
    'nyo' => 'Nyoro',
    'nzi' => 'Nzima',
    'oc' => 'Okzitanisch',
    'oj' => 'Ojibwa',
    'ojb' => 'Nordwest-Ojibwe',
    'ojc' => 'Zentral-Ojibwe',
    'ojs' => 'Oji-Cree',
    'ojw' => 'West-Ojibwe',
    'oka' => 'Okanagan',
    'om' => 'Oromo',
    'or' => 'Oriya',
    'os' => 'Ossetisch',
    'osa' => 'Osage',
    'ota' => 'Osmanisch',
    'pa' => 'Punjabi',
    'pag' => 'Pangasinan',
    'pal' => 'Mittelpersisch',
    'pam' => 'Pampanggan',
    'pap' => 'Papiamento',
    'pau' => 'Palau',
    'pcd' => 'Picardisch',
    'pcm' => 'Nigerianisches Pidgin',
    'pdc' => 'Pennsylvaniadeutsch',
    'pdt' => 'Plautdietsch',
    'peo' => 'Altpersisch',
    'pfl' => 'Pfälzisch',
    'phn' => 'Phönizisch',
    'pi' => 'Pali',
    'pis' => 'Pijin',
    'pl' => 'Polnisch',
    'pms' => 'Piemontesisch',
    'pnt' => 'Pontisch',
    'pon' => 'Ponapeanisch',
    'pqm' => 'Maliseet-Passamaquoddy',
    'prg' => 'Altpreußisch',
    'pro' => 'Altprovenzalisch',
    'ps' => 'Paschtu',
    'pt' => 'Portugiesisch',
    'qu' => 'Quechua',
    'quc' => 'K’iche’',
    'qug' => 'Chimborazo Hochland-Quechua',
    'raj' => 'Rajasthani',
    'rap' => 'Rapanui',
    'rar' => 'Rarotonganisch',
    'rgn' => 'Romagnol',
    'rhg' => 'Rohingyalisch',
    'rif' => 'Tarifit',
    'rm' => 'Rätoromanisch',
    'rn' => 'Rundi',
    'ro' => 'Rumänisch',
    'ro_MD' => 'Moldauisch',
    'rof' => 'Rombo',
    'rom' => 'Romani',
    'rtm' => 'Rotumanisch',
    'ru' => 'Russisch',
    'rue' => 'Russinisch',
    'rug' => 'Roviana',
    'rup' => 'Aromunisch',
    'rw' => 'Kinyarwanda',
    'rwk' => 'Rwa',
    'sa' => 'Sanskrit',
    'sad' => 'Sandawe',
    'sah' => 'Jakutisch',
    'sam' => 'Samaritanisch',
    'saq' => 'Samburu',
    'sas' => 'Sasak',
    'sat' => 'Santali',
    'saz' => 'Saurashtra',
    'sba' => 'Ngambay',
    'sbp' => 'Sangu',
    'sc' => 'Sardisch',
    'scn' => 'Sizilianisch',
    'sco' => 'Schottisch',
    'sd' => 'Sindhi',
    'sdc' => 'Sassarisch',
    'sdh' => 'Südkurdisch',
    'se' => 'Nordsamisch',
    'see' => 'Seneca',
    'seh' => 'Sena',
    'sei' => 'Seri',
    'sel' => 'Selkupisch',
    'ses' => 'Koyra Senni',
    'sg' => 'Sango',
    'sga' => 'Altirisch',
    'sgs' => 'Samogitisch',
    'sh' => 'Serbo-Kroatisch',
    'shi' => 'Taschelhit',
    'shn' => 'Schan',
    'shu' => 'Tschadisch-Arabisch',
    'si' => 'Singhalesisch',
    'sid' => 'Sidamo',
    'sk' => 'Slowakisch',
    'sl' => 'Slowenisch',
    'slh' => 'Süd-Lushootseed',
    'sli' => 'Schlesisch (Niederschlesisch)',
    'sly' => 'Selayar',
    'sm' => 'Samoanisch',
    'sma' => 'Südsamisch',
    'smj' => 'Lule-Samisch',
    'smn' => 'Inari-Samisch',
    'sms' => 'Skolt-Samisch',
    'sn' => 'Shona',
    'snk' => 'Soninke',
    'so' => 'Somali',
    'sog' => 'Sogdisch',
    'sq' => 'Albanisch',
    'sr' => 'Serbisch',
    'srn' => 'Srananisch',
    'srr' => 'Serer',
    'ss' => 'Swazi',
    'ssy' => 'Saho',
    'st' => 'Süd-Sotho',
    'stq' => 'Saterfriesisch',
    'str' => 'Straits Salish',
    'su' => 'Sundanesisch',
    'suk' => 'Sukuma',
    'sus' => 'Susu',
    'sux' => 'Sumerisch',
    'sv' => 'Schwedisch',
    'sw' => 'Suaheli',
    'sw_CD' => 'Kongo-Swahili',
    'swb' => 'Komorisch',
    'syc' => 'Altsyrisch',
    'syr' => 'Syrisch',
    'szl' => 'Schlesisch (Wasserpolnisch)',
    'ta' => 'Tamil',
    'tce' => 'Südliches Tutchone',
    'tcy' => 'Tulu',
    'te' => 'Telugu',
    'tem' => 'Temne',
    'teo' => 'Teso',
    'ter' => 'Tereno',
    'tet' => 'Tetum',
    'tg' => 'Tadschikisch',
    'tgx' => 'Tagish',
    'th' => 'Thailändisch',
    'tht' => 'Tahltan',
    'ti' => 'Tigrinya',
    'tig' => 'Tigre',
    'tiv' => 'Tiv',
    'tk' => 'Turkmenisch',
    'tkl' => 'Tokelauanisch',
    'tkr' => 'Tsachurisch',
    'tl' => 'Tagalog',
    'tlh' => 'Klingonisch',
    'tli' => 'Tlingit',
    'tly' => 'Talisch',
    'tmh' => 'Tamaseq',
    'tn' => 'Tswana',
    'to' => 'Tongaisch',
    'tog' => 'Nyasa Tonga',
    'tok' => 'Toki Pona',
    'tpi' => 'Neumelanesisch',
    'tr' => 'Türkisch',
    'tru' => 'Turoyo',
    'trv' => 'Taroko',
    'ts' => 'Tsonga',
    'tsd' => 'Tsakonisch',
    'tsi' => 'Tsimshian',
    'tt' => 'Tatarisch',
    'ttm' => 'Nördliches Tutchone',
    'ttt' => 'Tatisch',
    'tum' => 'Tumbuka',
    'tvl' => 'Tuvaluisch',
    'tw' => 'Twi',
    'twq' => 'Tasawaq',
    'ty' => 'Tahitisch',
    'tyv' => 'Tuwinisch',
    'tzm' => 'Zentralatlas-Tamazight',
    'udm' => 'Udmurtisch',
    'ug' => 'Uigurisch',
    'uga' => 'Ugaritisch',
    'uk' => 'Ukrainisch',
    'umb' => 'Umbundu',
    'und' => 'Unbekannte Sprache',
    'ur' => 'Urdu',
    'uz' => 'Usbekisch',
    'vai' => 'Vai',
    've' => 'Venda',
    'vec' => 'Venetisch',
    'vep' => 'Wepsisch',
    'vi' => 'Vietnamesisch',
    'vls' => 'Westflämisch',
    'vmf' => 'Mainfränkisch',
    'vmw' => 'Makua',
    'vo' => 'Volapük',
    'vot' => 'Wotisch',
    'vro' => 'Võro',
    'vun' => 'Vunjo',
    'wa' => 'Wallonisch',
    'wae' => 'Walliserdeutsch',
    'wal' => 'Walamo',
    'war' => 'Waray',
    'was' => 'Washo',
    'wbp' => 'Warlpiri',
    'wo' => 'Wolof',
    'wuu' => 'Wu',
    'xal' => 'Kalmückisch',
    'xh' => 'Xhosa',
    'xmf' => 'Mingrelisch',
    'xnr' => 'Kangri',
    'xog' => 'Soga',
    'yao' => 'Yao',
    'yap' => 'Yapesisch',
    'yav' => 'Yangben',
    'ybb' => 'Yemba',
    'yi' => 'Jiddisch',
    'yo' => 'Yoruba',
    'yrl' => 'Nheengatu',
    'yue' => 'Kantonesisch',
    'yue@alt=menu' => 'Chinesisch (Kantonesisch)',
    'za' => 'Zhuang',
    'zap' => 'Zapotekisch',
    'zbl' => 'Bliss-Symbole',
    'zea' => 'Seeländisch',
    'zen' => 'Zenaga',
    'zgh' => 'Tamazight',
    'zh' => 'Chinesisch',
    'zh@alt=menu' => 'Chinesisch (Mandarin)',
    'zh_Hans' => 'Chinesisch (vereinfacht)',
    'zh_Hans@alt=long' => 'Mandarin (Vereinfacht)',
    'zh_Hant' => 'Chinesisch (traditionell)',
    'zh_Hant@alt=long' => 'Mandarin (traditionell)',
    'zu' => 'Zulu',
    'zun' => 'Zuni',
    'zxx' => 'Keine Sprachinhalte',
    'zza' => 'Zaza',
};

is_deeply($locale->all_languages, $all_languages, 'All languages');

is($locale->script_name(), '', 'Script name from current locale');
is($locale->script_name('latn'), 'Lateinisch', 'Script name from string');
is($locale->script_name($other_locale), '', 'Script name from other locale object');

my $all_scripts = {
	'Adlm' => 'Adlam',
	'Afak' => 'Afaka',
	'Aghb' => 'Kaukasisch-Albanisch',
	'Arab' => 'Arabisch',
	'Arab@alt=variant' => 'Persisch',
	'Aran' => 'Nastaliq',
    'Armi' => 'Aramäisch',
	'Armn' => 'Armenisch',
	'Avst' => 'Avestisch',
	'Bali' => 'Balinesisch',
	'Bamu' => 'Bamun',
	'Bass' => 'Bassa',
	'Batk' => 'Battakisch',
	'Beng' => 'Bengalisch',
	'Bhks' => 'Bhaiksuki',
	'Blis' => 'Bliss-Symbole',
	'Bopo' => 'Bopomofo',
	'Brah' => 'Brahmi',
	'Brai' => 'Braille',
	'Bugi' => 'Buginesisch',
	'Buhd' => 'Buhid',
	'Cakm' => 'Chakma',
	'Cans' => 'Kanadische Aborigine-Silbenschrift',
	'Cari' => 'Karisch',
	'Cher' => 'Cherokee',
    'Chrs' => 'Choresmisch',
	'Cirt' => 'Cirth',
	'Copt' => 'Koptisch',
    'Cpmn' => 'Minoisch',
	'Cprt' => 'Zypriotisch',
	'Cyrl' => 'Kyrillisch',
	'Cyrs' => 'Altkirchenslawisch',
	'Deva' => 'Devanagari',
	'Dogr' => 'Dogra',
	'Dsrt' => 'Deseret',
	'Dupl' => 'Duployanisch',
	'Egyd' => 'Ägyptisch - Demotisch',
	'Egyh' => 'Ägyptisch - Hieratisch',
	'Egyp' => 'Ägyptische Hieroglyphen',
	'Elba' => 'Elbasanisch',
	'Elym' => 'Elymäisch',
	'Ethi' => 'Äthiopisch',
	'Geok' => 'Khutsuri',
	'Geor' => 'Georgisch',
	'Glag' => 'Glagolitisch',
	'Gong' => 'Gunjala Gondi',
	'Gonm' => 'Masaram-Gondi',
	'Goth' => 'Gotisch',
	'Gran' => 'Grantha',
	'Grek' => 'Griechisch',
	'Gujr' => 'Gujarati',
	'Guru' => 'Gurmukhi',
	'Hanb' => 'Han mit Bopomofo',
	'Hang' => 'Hangul',
	'Hani' => 'Chinesisch',
	'Hano' => 'Hanunoo',
	'Hans' => 'Vereinfacht',
	'Hans@alt=stand-alone' => 'Vereinfachtes Chinesisch',
	'Hant' => 'Traditionell',
	'Hant@alt=stand-alone' => 'Traditionelles Chinesisch',
	'Hatr' => 'Hatranisch',
	'Hebr' => 'Hebräisch',
	'Hira' => 'Hiragana',
	'Hluw' => 'Hieroglyphen-Luwisch',
	'Hmng' => 'Pahawh Hmong',
	'Hmnp' => 'Nyiakeng Puachue Hmong',
	'Hrkt' => 'Japanische Silbenschrift',
	'Hung' => 'Altungarisch',
	'Inds' => 'Indus-Schrift',
	'Ital' => 'Altitalisch',
	'Java' => 'Javanesisch',
	'Jpan' => 'Japanisch',
	'Jurc' => 'Jurchen',
	'Kali' => 'Kayah Li',
	'Kana' => 'Katakana',
	'Khar' => 'Kharoshthi',
	'Khmr' => 'Khmer',
	'Khoj' => 'Khojki',
    'Kits' => 'Chitan',
	'Knda' => 'Kannada',
	'Kore' => 'Koreanisch',
	'Kpel' => 'Kpelle',
	'Kthi' => 'Kaithi',
	'Lana' => 'Lanna',
	'Laoo' => 'Laotisch',
	'Latf' => 'Lateinisch - Fraktur-Variante',
	'Latg' => 'Lateinisch - Gälische Variante',
	'Latn' => 'Lateinisch',
	'Lepc' => 'Lepcha',
	'Limb' => 'Limbu',
	'Lina' => 'Linear A',
	'Linb' => 'Linear B',
	'Lisu' => 'Fraser',
	'Loma' => 'Loma',
	'Lyci' => 'Lykisch',
	'Lydi' => 'Lydisch',
	'Mahj' => 'Mahajani',
	'Maka' => 'Makasar',
	'Mand' => 'Mandäisch',
	'Mani' => 'Manichäisch',
	'Marc' => 'Marchen',
	'Maya' => 'Maya-Hieroglyphen',
	'Medf' => 'Medefaidrin',
	'Mend' => 'Mende',
	'Merc' => 'Meroitisch kursiv',
	'Mero' => 'Meroitisch',
	'Mlym' => 'Malayalam',
	'Mong' => 'Mongolisch',
	'Moon' => 'Moon',
	'Mroo' => 'Mro',
	'Mtei' => 'Meitei-Mayek',
	'Mult' => 'Multani',
	'Mymr' => 'Birmanisch',
	'Nand' => 'Nandinagari',
	'Narb' => 'Altnordarabisch',
	'Nbat' => 'Nabatäisch',
	'Nkgb' => 'Geba',
	'Nkoo' => 'N’Ko',
	'Nshu' => 'Frauenschrift',
	'Ogam' => 'Ogham',
	'Olck' => 'Ol Chiki',
	'Orkh' => 'Orchon-Runen',
	'Orya' => 'Oriya',
	'Osge' => 'Osage',
	'Osma' => 'Osmanisch',
    'Ougr' => 'Altuigurisch',
	'Palm' => 'Palmyrenisch',
	'Pauc' => 'Pau Cin Hau',
	'Perm' => 'Altpermisch',
	'Phag' => 'Phags-pa',
	'Phli' => 'Buch-Pahlavi',
	'Phlp' => 'Psalter-Pahlavi',
	'Phlv' => 'Pahlavi',
	'Phnx' => 'Phönizisch',
	'Plrd' => 'Pollard Phonetisch',
	'Prti' => 'Parthisch',
	'Qaag' => 'Zawgyi',
	'Rjng' => 'Rejang',
	'Rohg' => 'Hanifi Rohingya',
	'Roro' => 'Rongorongo',
	'Runr' => 'Runenschrift',
	'Samr' => 'Samaritanisch',
	'Sara' => 'Sarati',
	'Sarb' => 'Altsüdarabisch',
	'Saur' => 'Saurashtra',
	'Sgnw' => 'Gebärdensprache',
	'Shaw' => 'Shaw-Alphabet',
	'Shrd' => 'Sharada',
	'Sidd' => 'Siddham',
	'Sind' => 'Khudawadi',
	'Sinh' => 'Singhalesisch',
	'Sogd' => 'Sogdisch',
 	'Sogo' => 'Alt-Sogdisch',
	'Sora' => 'Sora Sompeng',
	'Soyo' => 'Sojombo',
	'Sund' => 'Sundanesisch',
	'Sylo' => 'Syloti Nagri',
	'Syrc' => 'Syrisch',
	'Syre' => 'Syrisch - Estrangelo-Variante',
	'Syrj' => 'Westsyrisch',
	'Syrn' => 'Ostsyrisch',
	'Tagb' => 'Tagbanwa',
	'Takr' => 'Takri',
	'Tale' => 'Tai Le',
	'Talu' => 'Tai Lue',
	'Taml' => 'Tamilisch',
	'Tang' => 'Xixia',
	'Tavt' => 'Tai-Viet',
	'Telu' => 'Telugu',
	'Teng' => 'Tengwar',
	'Tfng' => 'Tifinagh',
	'Tglg' => 'Tagalog',
	'Thaa' => 'Thaana',
	'Tibt' => 'Tibetisch',
	'Tirh' => 'Tirhuta',
	'Ugar' => 'Ugaritisch',
	'Vaii' => 'Vai',
	'Visp' => 'Sichtbare Sprache',
	'Wara' => 'Varang Kshiti',
	'Wcho' => 'Wancho',
	'Wole' => 'Woleaianisch',
	'Xpeo' => 'Altpersisch',
	'Xsux' => 'Sumerisch-akkadische Keilschrift',
    'Yezi' => 'Jesidisch',
	'Yiii' => 'Yi',
	'Zanb' => 'Dsanabadsar-Quadratschrift',
	'Zinh' => 'Geerbter Schriftwert',
	'Zmth' => 'Mathematische Notation',
	'Zsye' => 'Emoji',
	'Zsym' => 'Symbole',
	'Zxxx' => 'Schriftlos',
	'Zyyy' => 'Unbestimmt',
	'Zzzz' => 'Unbekannte Schrift',

};

is_deeply($locale->all_scripts, $all_scripts, 'All scripts');

is($locale->region_name(), 'Deutschland', 'Region name from current locale');
is($locale->region_name('fr'), 'Frankreich', 'Region name from string');
is($locale->region_name($other_locale), 'Belgien', 'Region name from other locale object');

my $all_regions = {
	'001' => 'Welt',
	'002' => 'Afrika',
	'003' => 'Nordamerika',
	'005' => 'Südamerika',
	'009' => 'Ozeanien',
	'011' => 'Westafrika',
	'013' => 'Mittelamerika',
	'014' => 'Ostafrika',
	'015' => 'Nordafrika',
	'017' => 'Zentralafrika',
	'018' => 'Südliches Afrika',
	'019' => 'Amerika',
	'021' => 'Nördliches Amerika',
	'029' => 'Karibik',
	'030' => 'Ostasien',
	'034' => 'Südasien',
	'035' => 'Südostasien',
	'039' => 'Südeuropa',
	'053' => 'Australasien',
	'054' => 'Melanesien',
	'057' => 'Mikronesisches Inselgebiet',
	'061' => 'Polynesien',
	'142' => 'Asien',
	'143' => 'Zentralasien',
	'145' => 'Westasien',
	'150' => 'Europa',
	'151' => 'Osteuropa',
	'154' => 'Nordeuropa',
	'155' => 'Westeuropa',
	'202' => 'Subsahara-Afrika',
	'419' => 'Lateinamerika',
	'AC' => 'Ascension',
	'AD' => 'Andorra',
	'AE' => 'Vereinigte Arabische Emirate',
	'AF' => 'Afghanistan',
	'AG' => 'Antigua und Barbuda',
	'AI' => 'Anguilla',
	'AL' => 'Albanien',
	'AM' => 'Armenien',
	'AO' => 'Angola',
	'AQ' => 'Antarktis',
	'AR' => 'Argentinien',
	'AS' => 'Amerikanisch-Samoa',
	'AT' => 'Österreich',
	'AU' => 'Australien',
	'AW' => 'Aruba',
	'AX' => 'Ålandinseln',
	'AZ' => 'Aserbaidschan',
	'BA' => 'Bosnien und Herzegowina',
	'BB' => 'Barbados',
	'BD' => 'Bangladesch',
	'BE' => 'Belgien',
	'BF' => 'Burkina Faso',
	'BG' => 'Bulgarien',
	'BH' => 'Bahrain',
	'BI' => 'Burundi',
	'BJ' => 'Benin',
	'BL' => 'St. Barthélemy',
	'BM' => 'Bermuda',
	'BN' => 'Brunei Darussalam',
	'BO' => 'Bolivien',
	'BQ' => 'Karibische Niederlande',
	'BR' => 'Brasilien',
	'BS' => 'Bahamas',
	'BT' => 'Bhutan',
	'BV' => 'Bouvetinsel',
	'BW' => 'Botsuana',
	'BY' => 'Belarus',
	'BZ' => 'Belize',
	'CA' => 'Kanada',
	'CC' => 'Kokosinseln',
	'CD' => 'Kongo-Kinshasa',
	'CD@alt=variant' => 'Kongo (Demokratische Republik)',
	'CF' => 'Zentralafrikanische Republik',
	'CG' => 'Kongo-Brazzaville',
	'CG@alt=variant' => 'Kongo (Republik)',
	'CH' => 'Schweiz',
	'CI' => 'Côte d’Ivoire',
	'CI@alt=variant' => 'Elfenbeinküste',
	'CK' => 'Cookinseln',
	'CL' => 'Chile',
	'CM' => 'Kamerun',
	'CN' => 'China',
	'CO' => 'Kolumbien',
	'CP' => 'Clipperton-Insel',
	'CR' => 'Costa Rica',
	'CU' => 'Kuba',
	'CV' => 'Cabo Verde',
	'CW' => 'Curaçao',
	'CX' => 'Weihnachtsinsel',
	'CY' => 'Zypern',
	'CZ' => 'Tschechien',
	'CZ@alt=variant' => 'Tschechische Republik',
	'DE' => 'Deutschland',
	'DG' => 'Diego Garcia',
	'DJ' => 'Dschibuti',
	'DK' => 'Dänemark',
	'DM' => 'Dominica',
	'DO' => 'Dominikanische Republik',
	'DZ' => 'Algerien',
	'EA' => 'Ceuta und Melilla',
	'EC' => 'Ecuador',
	'EE' => 'Estland',
	'EG' => 'Ägypten',
	'EH' => 'Westsahara',
	'ER' => 'Eritrea',
	'ES' => 'Spanien',
	'ET' => 'Äthiopien',
	'EU' => 'Europäische Union',
	'EZ' => 'Eurozone',
	'FI' => 'Finnland',
	'FJ' => 'Fidschi',
	'FK' => 'Falklandinseln',
	'FK@alt=variant' => 'Falklandinseln (Malwinen)',
	'FM' => 'Mikronesien',
	'FO' => 'Färöer',
	'FR' => 'Frankreich',
	'GA' => 'Gabun',
	'GB' => 'Vereinigtes Königreich',
	'GB@alt=short' => 'UK',
	'GD' => 'Grenada',
	'GE' => 'Georgien',
	'GF' => 'Französisch-Guayana',
	'GG' => 'Guernsey',
	'GH' => 'Ghana',
	'GI' => 'Gibraltar',
	'GL' => 'Grönland',
	'GM' => 'Gambia',
	'GN' => 'Guinea',
	'GP' => 'Guadeloupe',
	'GQ' => 'Äquatorialguinea',
	'GR' => 'Griechenland',
	'GS' => 'Südgeorgien und die Südlichen Sandwichinseln',
	'GT' => 'Guatemala',
	'GU' => 'Guam',
	'GW' => 'Guinea-Bissau',
	'GY' => 'Guyana',
	'HK' => 'Sonderverwaltungsregion Hongkong',
	'HK@alt=short' => 'Hongkong',
	'HM' => 'Heard und McDonaldinseln',
	'HN' => 'Honduras',
	'HR' => 'Kroatien',
	'HT' => 'Haiti',
	'HU' => 'Ungarn',
	'IC' => 'Kanarische Inseln',
	'ID' => 'Indonesien',
	'IE' => 'Irland',
	'IL' => 'Israel',
	'IM' => 'Isle of Man',
	'IN' => 'Indien',
	'IO' => 'Britisches Territorium im Indischen Ozean',
    'IO@alt=chagos' => 'Chagos-Archipel',
	'IQ' => 'Irak',
	'IR' => 'Iran',
	'IS' => 'Island',
	'IT' => 'Italien',
	'JE' => 'Jersey',
	'JM' => 'Jamaika',
	'JO' => 'Jordanien',
	'JP' => 'Japan',
	'KE' => 'Kenia',
	'KG' => 'Kirgisistan',
	'KH' => 'Kambodscha',
	'KI' => 'Kiribati',
	'KM' => 'Komoren',
	'KN' => 'St. Kitts und Nevis',
	'KP' => 'Nordkorea',
	'KR' => 'Südkorea',
	'KW' => 'Kuwait',
	'KY' => 'Kaimaninseln',
	'KZ' => 'Kasachstan',
	'LA' => 'Laos',
	'LB' => 'Libanon',
	'LC' => 'St. Lucia',
	'LI' => 'Liechtenstein',
	'LK' => 'Sri Lanka',
	'LR' => 'Liberia',
	'LS' => 'Lesotho',
	'LT' => 'Litauen',
	'LU' => 'Luxemburg',
	'LV' => 'Lettland',
	'LY' => 'Libyen',
	'MA' => 'Marokko',
	'MC' => 'Monaco',
	'MD' => 'Republik Moldau',
	'ME' => 'Montenegro',
	'MF' => 'St. Martin',
	'MG' => 'Madagaskar',
	'MH' => 'Marshallinseln',
	'MK' => 'Nordmazedonien',
	'ML' => 'Mali',
	'MM' => 'Myanmar',
	'MN' => 'Mongolei',
	'MO' => 'Sonderverwaltungsregion Macau',
	'MO@alt=short' => 'Macau',
	'MP' => 'Nördliche Marianen',
	'MQ' => 'Martinique',
	'MR' => 'Mauretanien',
	'MS' => 'Montserrat',
	'MT' => 'Malta',
	'MU' => 'Mauritius',
	'MV' => 'Malediven',
	'MW' => 'Malawi',
	'MX' => 'Mexiko',
	'MY' => 'Malaysia',
	'MZ' => 'Mosambik',
	'NA' => 'Namibia',
	'NC' => 'Neukaledonien',
	'NE' => 'Niger',
	'NF' => 'Norfolkinsel',
	'NG' => 'Nigeria',
	'NI' => 'Nicaragua',
	'NL' => 'Niederlande',
	'NO' => 'Norwegen',
	'NP' => 'Nepal',
	'NR' => 'Nauru',
	'NU' => 'Niue',
	'NZ' => 'Neuseeland',
    'NZ@alt=variant' => 'Aotearoa (Neuseeland)',
	'OM' => 'Oman',
	'PA' => 'Panama',
	'PE' => 'Peru',
	'PF' => 'Französisch-Polynesien',
	'PG' => 'Papua-Neuguinea',
	'PH' => 'Philippinen',
	'PK' => 'Pakistan',
	'PL' => 'Polen',
	'PM' => 'St. Pierre und Miquelon',
	'PN' => 'Pitcairninseln',
	'PR' => 'Puerto Rico',
	'PS' => 'Palästinensische Autonomiegebiete',
	'PS@alt=short' => 'Palästina',
	'PT' => 'Portugal',
	'PW' => 'Palau',
	'PY' => 'Paraguay',
	'QA' => 'Katar',
	'QO' => 'Äußeres Ozeanien',
	'RE' => 'Réunion',
	'RO' => 'Rumänien',
	'RS' => 'Serbien',
	'RU' => 'Russland',
	'RW' => 'Ruanda',
	'SA' => 'Saudi-Arabien',
	'SB' => 'Salomonen',
	'SC' => 'Seychellen',
	'SD' => 'Sudan',
	'SE' => 'Schweden',
	'SG' => 'Singapur',
	'SH' => 'St. Helena',
	'SI' => 'Slowenien',
	'SJ' => 'Spitzbergen und Jan Mayen',
	'SK' => 'Slowakei',
	'SL' => 'Sierra Leone',
	'SM' => 'San Marino',
	'SN' => 'Senegal',
	'SO' => 'Somalia',
	'SR' => 'Suriname',
	'SS' => 'Südsudan',
	'ST' => 'São Tomé und Príncipe',
	'SV' => 'El Salvador',
	'SX' => 'Sint Maarten',
	'SY' => 'Syrien',
	'SZ' => 'Eswatini',
	'SZ@alt=variant' => 'Swasiland',
	'TA' => 'Tristan da Cunha',
	'TC' => 'Turks- und Caicosinseln',
	'TD' => 'Tschad',
	'TF' => 'Französische Süd- und Antarktisgebiete',
	'TG' => 'Togo',
	'TH' => 'Thailand',
	'TJ' => 'Tadschikistan',
	'TK' => 'Tokelau',
	'TL' => 'Timor-Leste',
	'TL@alt=variant' => 'Osttimor',
	'TM' => 'Turkmenistan',
	'TN' => 'Tunesien',
	'TO' => 'Tonga',
	'TR' => 'Türkei',
	'TT' => 'Trinidad und Tobago',
	'TV' => 'Tuvalu',
	'TW' => 'Taiwan',
	'TZ' => 'Tansania',
	'UA' => 'Ukraine',
	'UG' => 'Uganda',
	'UM' => 'Amerikanische Überseeinseln',
	'UN' => 'Vereinte Nationen',
	'UN@alt=short' => 'UN',
	'US' => 'Vereinigte Staaten',
	'US@alt=short' => 'USA',
	'UY' => 'Uruguay',
	'UZ' => 'Usbekistan',
	'VA' => 'Vatikanstadt',
	'VC' => 'St. Vincent und die Grenadinen',
	'VE' => 'Venezuela',
	'VG' => 'Britische Jungferninseln',
	'VI' => 'Amerikanische Jungferninseln',
	'VN' => 'Vietnam',
	'VU' => 'Vanuatu',
	'WF' => 'Wallis und Futuna',
	'WS' => 'Samoa',
	'XA' => 'Pseudo-Akzente',
	'XB' => 'Pseudo-Bidi',
	'XK' => 'Kosovo',
	'YE' => 'Jemen',
	'YT' => 'Mayotte',
	'ZA' => 'Südafrika',
	'ZM' => 'Sambia',
	'ZW' => 'Simbabwe',
	'ZZ' => 'Unbekannte Region',
};

is_deeply($locale->all_regions(), $all_regions, 'All Regions');

is($locale->variant_name(), '', 'Variant name from current locale');
is($locale->variant_name('AREVMDA'), 'Westarmenisch', 'Variant name from string');
is($locale->variant_name($other_locale), '', 'Variant name from other locale object');

is($locale->key_name('colCaseLevel'), 'Sortierung nach Groß- oder Kleinschreibung', 'Key name from string');

is($locale->type_name(colCaseFirst => 'lower'), 'Kleinbuchstaben zuerst aufführen', 'Type name from string');

is($locale->measurement_system_name('metric'), 'Internationales (SI)', 'Measurement system name German Metric');
is($locale->measurement_system_name('us'), 'US', 'Measurement system name German US');
is($locale->measurement_system_name('uk'), 'UK', 'Measurement system name German UK');