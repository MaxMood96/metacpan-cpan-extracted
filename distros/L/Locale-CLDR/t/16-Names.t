#!/usr/bin/perl
# Do not normalise this test file. It has deliberately unnormalised characters in it.
use v5.10;
use strict;
use warnings;
use utf8;
use if $^V ge v5.12.0, feature => 'unicode_strings';

use Test::More tests => 20;
use Test::Exception;

use ok 'Locale::CLDR';

my $locale = Locale::CLDR->new('en_US');

is($locale->locale_name(), 'American English', 'Locale name from current locale');
is($locale->locale_name('fr_CA'), 'Canadian French', 'Locale name from string');
is($locale->language_name(), 'English', 'Language name from current locale');
is($locale->language_name('fr'), 'French', 'Language name from string');

my $all_languages = {
	'aa' => 'Afar',
	'ab' => 'Abkhazian',
	'ace' => 'Acehnese',
	'ach' => 'Acoli',
	'ada' => 'Adangme',
	'ady' => 'Adyghe',
	'ae' => 'Avestan',
	'aeb' => 'Tunisian Arabic',
	'af' => 'Afrikaans',
	'afh' => 'Afrihili',
	'agq' => 'Aghem',
	'ain' => 'Ainu',
	'ak' => 'Akan',
	'akk' => 'Akkadian',
	'akz' => 'Alabama',
	'ale' => 'Aleut',
	'aln' => 'Gheg Albanian',
	'alt' => 'Southern Altai',
	'am' => 'Amharic',
	'an' => 'Aragonese',
	'ang' => 'Old English',
    'ann' => 'Obolo',
	'anp' => 'Angika',
	'ar' => 'Arabic',
	'ar_001' => 'Modern Standard Arabic',
	'ars' => 'Najdi Arabic',
	'ars@alt=menu' => 'Arabic, Najdi',
	'arc' => 'Aramaic',
	'arn' => 'Mapuche',
	'aro' => 'Araona',
	'arp' => 'Arapaho',
	'arq' => 'Algerian Arabic',
	'arw' => 'Arawak',
	'ary' => 'Moroccan Arabic',
	'arz' => 'Egyptian Arabic',
	'as' => 'Assamese',
	'asa' => 'Asu',
	'ase' => 'American Sign Language',
	'ast' => 'Asturian',
    'atj' => 'Atikamekw',
	'av' => 'Avaric',
	'avk' => 'Kotava',
	'awa' => 'Awadhi',
	'ay' => 'Aymara',
	'az' => 'Azerbaijani',
	'az@alt=short' => 'Azeri',
	'ba' => 'Bashkir',
	'bal' => 'Baluchi',
	'ban' => 'Balinese',
	'bar' => 'Bavarian',
	'bas' => 'Basaa',
	'bax' => 'Bamun',
	'bbc' => 'Batak Toba',
	'bbj' => 'Ghomala',
	'be' => 'Belarusian',
	'bej' => 'Beja',
	'bem' => 'Bemba',
	'bew' => 'Betawi',
	'bez' => 'Bena',
	'bfd' => 'Bafut',
	'bfq' => 'Badaga',
	'bg' => 'Bulgarian',
    'bgc' => 'Haryanvi',
	'bgn' => 'Western Balochi',
	'bho' => 'Bhojpuri',
	'bi' => 'Bislama',
	'bik' => 'Bikol',
	'bin' => 'Bini',
	'bjn' => 'Banjar',
	'bkm' => 'Kom',
	'bla' => 'Siksiká',
    'blo' => 'Anii',
    'blt' => 'Tai Dam',
	'bm' => 'Bambara',
	'bn' => 'Bangla',
	'bo' => 'Tibetan',
	'bpy' => 'Bishnupriya',
	'bqi' => 'Bakhtiari',
	'br' => 'Breton',
	'bra' => 'Braj',
	'brh' => 'Brahui',
	'brx' => 'Bodo',
	'bs' => 'Bosnian',
	'bss' => 'Akoose',
	'bua' => 'Buriat',
	'bug' => 'Buginese',
	'bum' => 'Bulu',
	'byn' => 'Blin',
	'byv' => 'Medumba',
	'ca' => 'Catalan',
	'cad' => 'Caddo',
	'car' => 'Carib',
	'cay' => 'Cayuga',
	'cch' => 'Atsam',
	'ccp' => 'Chakma',
	'ce' => 'Chechen',
	'ceb' => 'Cebuano',
	'cgg' => 'Chiga',
	'ch' => 'Chamorro',
	'chb' => 'Chibcha',
	'chg' => 'Chagatai',
	'chk' => 'Chuukese',
	'chm' => 'Mari',
	'chn' => 'Chinook Jargon',
	'cho' => 'Choctaw',
	'chp' => 'Chipewyan',
	'chr' => 'Cherokee',
	'chy' => 'Cheyenne',
	'cic' => 'Chickasaw',
	'ckb' => 'Central Kurdish',
	'ckb@alt=menu' => 'Kurdish, Central',
	'ckb@alt=variant' => 'Kurdish, Sorani',
    'clc' => 'Chilcotin',
	'co' => 'Corsican',
	'cop' => 'Coptic',
	'cps' => 'Capiznon',
	'cr' => 'Cree',
    'crg' => 'Michif',
	'crh' => 'Crimean Tatar',
    'crj' => 'Southern East Cree',
    'crk' => 'Plains Cree',
    'crl' => 'Northern East Cree',
    'crm' => 'Moose Cree',
    'crr' => 'Carolina Algonquian',
	'crs' => 'Seselwa Creole French',
	'cs' => 'Czech',
	'csb' => 'Kashubian',
    'csw' => 'Swampy Cree',
	'cu' => 'Church Slavic',
	'cv' => 'Chuvash',
    'cwd' => 'Woods Cree',
	'cy' => 'Welsh',
	'da' => 'Danish',
	'dak' => 'Dakota',
	'dar' => 'Dargwa',
	'dav' => 'Taita',
	'de' => 'German',
	'de_AT' => 'Austrian German',
	'de_CH' => 'Swiss High German',
	'del' => 'Delaware',
	'den' => 'Slave',
	'dgr' => 'Dogrib',
	'din' => 'Dinka',
	'dje' => 'Zarma',
	'doi' => 'Dogri',
	'dsb' => 'Lower Sorbian',
	'dtp' => 'Central Dusun',
	'dua' => 'Duala',
	'dum' => 'Middle Dutch',
	'dv' => 'Divehi',
	'dyo' => 'Jola-Fonyi',
	'dyu' => 'Dyula',
	'dz' => 'Dzongkha',
	'dzg' => 'Dazaga',
	'ebu' => 'Embu',
	'ee' => 'Ewe',
	'efi' => 'Efik',
	'egl' => 'Emilian',
	'egy' => 'Ancient Egyptian',
	'eka' => 'Ekajuk',
	'el' => 'Greek',
	'elx' => 'Elamite',
	'en' => 'English',
	'en_AU' => 'Australian English',
	'en_CA' => 'Canadian English',
	'en_GB' => 'British English',
	'en_GB@alt=short' => 'UK English',
	'en_US' => 'American English',
	'en_US@alt=short' => 'US English',
	'enm' => 'Middle English',
	'eo' => 'Esperanto',
	'es' => 'Spanish',
	'es_419' => 'Latin American Spanish',
	'es_ES' => 'European Spanish',
	'es_MX' => 'Mexican Spanish',
	'esu' => 'Central Yupik',
	'et' => 'Estonian',
	'eu' => 'Basque',
	'ewo' => 'Ewondo',
	'ext' => 'Extremaduran',
	'fa' => 'Persian',
	'fa_AF' => 'Dari',
	'fan' => 'Fang',
	'fat' => 'Fanti',
	'ff' => 'Fula',
	'fi' => 'Finnish',
	'fil' => 'Filipino',
	'fit' => 'Tornedalen Finnish',
	'fj' => 'Fijian',
	'fo' => 'Faroese',
	'fon' => 'Fon',
	'fr' => 'French',
	'fr_CA' => 'Canadian French',
	'fr_CH' => 'Swiss French',
	'frc' => 'Cajun French',
	'frm' => 'Middle French',
	'fro' => 'Old French',
	'frp' => 'Arpitan',
	'frr' => 'Northern Frisian',
	'frs' => 'Eastern Frisian',
	'fur' => 'Friulian',
	'fy' => 'Western Frisian',
	'ga' => 'Irish',
	'gaa' => 'Ga',
	'gag' => 'Gagauz',
	'gan' => 'Gan Chinese',
	'gay' => 'Gayo',
	'gba' => 'Gbaya',
	'gbz' => 'Zoroastrian Dari',
	'gd' => 'Scottish Gaelic',
	'gez' => 'Geez',
	'gil' => 'Gilbertese',
	'gl' => 'Galician',
	'glk' => 'Gilaki',
	'gmh' => 'Middle High German',
	'gn' => 'Guarani',
	'goh' => 'Old High German',
	'gon' => 'Gondi',
	'gor' => 'Gorontalo',
	'got' => 'Gothic',
	'grb' => 'Grebo',
	'grc' => 'Ancient Greek',
	'gsw' => 'Swiss German',
	'gu' => 'Gujarati',
	'guc' => 'Wayuu',
	'gur' => 'Frafra',
	'guz' => 'Gusii',
	'gv' => 'Manx',
	'gwi' => 'Gwichʼin',
	'ha' => 'Hausa',
	'hai' => 'Haida',
	'hak' => 'Hakka Chinese',
	'haw' => 'Hawaiian',
    'hax' => 'Southern Haida',
    'hdn' => 'Northern Haida',
	'he' => 'Hebrew',
	'hi' => 'Hindi',
    'hi_Latn' => 'Hindi (Latin)',
    'hi_Latn@alt=variant' => 'Hinglish',
	'hif' => 'Fiji Hindi',
	'hil' => 'Hiligaynon',
	'hit' => 'Hittite',
	'hmn' => 'Hmong',
    'hnj' => 'Hmong Njua',
	'ho' => 'Hiri Motu',
	'hr' => 'Croatian',
	'hsb' => 'Upper Sorbian',
	'hsn' => 'Xiang Chinese',
	'ht' => 'Haitian Creole',
	'hu' => 'Hungarian',
	'hup' => 'Hupa',
    'hur' => 'Halkomelem',
	'hy' => 'Armenian',
	'hz' => 'Herero',
	'ia' => 'Interlingua',
	'iba' => 'Iban',
	'ibb' => 'Ibibio',
	'id' => 'Indonesian',
	'ie' => 'Interlingue',
	'ig' => 'Igbo',
	'ii' => 'Sichuan Yi',
	'ik' => 'Inupiaq',
    'ike' => 'Eastern Canadian Inuktitut',
    'ikt' => 'Western Canadian Inuktitut',
	'ilo' => 'Iloko',
	'inh' => 'Ingush',
	'io' => 'Ido',
	'is' => 'Icelandic',
	'it' => 'Italian',
	'iu' => 'Inuktitut',
	'izh' => 'Ingrian',
	'ja' => 'Japanese',
	'jam' => 'Jamaican Creole English',
	'jbo' => 'Lojban',
	'jgo' => 'Ngomba',
	'jmc' => 'Machame',
	'jpr' => 'Judeo-Persian',
	'jrb' => 'Judeo-Arabic',
	'jut' => 'Jutish',
	'jv' => 'Javanese',
	'ka' => 'Georgian',
	'kaa' => 'Kara-Kalpak',
	'kab' => 'Kabyle',
	'kac' => 'Kachin',
	'kaj' => 'Jju',
	'kam' => 'Kamba',
	'kaw' => 'Kawi',
	'kbd' => 'Kabardian',
	'kbl' => 'Kanembu',
	'kcg' => 'Tyap',
	'kde' => 'Makonde',
	'kea' => 'Kabuverdianu',
	'ken' => 'Kenyang',
	'kfo' => 'Koro',
	'kg' => 'Kongo',
	'kgp' => 'Kaingang',
	'kha' => 'Khasi',
	'kho' => 'Khotanese',
	'khq' => 'Koyra Chiini',
	'khw' => 'Khowar',
	'ki' => 'Kikuyu',
	'kiu' => 'Kirmanjki',
	'kj' => 'Kuanyama',
	'kk' => 'Kazakh',
	'kkj' => 'Kako',
	'kl' => 'Kalaallisut',
	'kln' => 'Kalenjin',
	'km' => 'Khmer',
	'kmb' => 'Kimbundu',
	'kn' => 'Kannada',
	'ko' => 'Korean',
	'koi' => 'Komi-Permyak',
	'kok' => 'Konkani',
	'kos' => 'Kosraean',
	'kpe' => 'Kpelle',
	'kr' => 'Kanuri',
	'krc' => 'Karachay-Balkar',
	'kri' => 'Krio',
	'krj' => 'Kinaray-a',
	'krl' => 'Karelian',
	'kru' => 'Kurukh',
	'ks' => 'Kashmiri',
	'ksb' => 'Shambala',
	'ksf' => 'Bafia',
	'ksh' => 'Colognian',
	'ku' => 'Kurdish',
	'kum' => 'Kumyk',
	'kut' => 'Kutenai',
	'kv' => 'Komi',
	'kw' => 'Cornish',
    'kwk' => 'Kwakʼwala',
    'kxv' => 'Kuvi',
	'ky' => 'Kyrgyz',
	'ky@alt=variant' => 'Kirghiz',
	'la' => 'Latin',
	'lad' => 'Ladino',
	'lag' => 'Langi',
	'lah' => 'Western Panjabi',
	'lam' => 'Lamba',
	'lb' => 'Luxembourgish',
	'lez' => 'Lezghian',
	'lfn' => 'Lingua Franca Nova',
	'lg' => 'Ganda',
	'li' => 'Limburgish',
	'lij' => 'Ligurian',
    'lil' => 'Lillooet',
	'liv' => 'Livonian',
	'lkt' => 'Lakota',
	'lmo' => 'Lombard',
	'ln' => 'Lingala',
	'lo' => 'Lao',
	'lol' => 'Mongo',
	'lou' => 'Louisiana Creole',
	'loz' => 'Lozi',
	'lrc' => 'Northern Luri',
    'lsm' => 'Saamia',
	'lt' => 'Lithuanian',
	'ltg' => 'Latgalian',
	'lu' => 'Luba-Katanga',
	'lua' => 'Luba-Lulua',
	'lui' => 'Luiseno',
	'lun' => 'Lunda',
	'luo' => 'Luo',
	'lus' => 'Mizo',
	'luy' => 'Luyia',
	'lv' => 'Latvian',
	'lzh' => 'Literary Chinese',
	'lzz' => 'Laz',
	'mad' => 'Madurese',
	'maf' => 'Mafa',
	'mag' => 'Magahi',
	'mai' => 'Maithili',
	'mak' => 'Makasar',
	'man' => 'Mandingo',
	'mas' => 'Masai',
	'mde' => 'Maba',
	'mdf' => 'Moksha',
	'mdr' => 'Mandar',
	'men' => 'Mende',
	'mer' => 'Meru',
	'mfe' => 'Morisyen',
	'mg' => 'Malagasy',
	'mga' => 'Middle Irish',
	'mgh' => 'Makhuwa-Meetto',
	'mgo' => 'Metaʼ',
	'mh' => 'Marshallese',
	'mi' => 'Māori',
	'mic' => 'Mi\'kmaw',
	'min' => 'Minangkabau',
	'mk' => 'Macedonian',
	'ml' => 'Malayalam',
	'mn' => 'Mongolian',
	'mnc' => 'Manchu',
	'mni' => 'Manipuri',
    'moe' => 'Innu-aimun',
	'moh' => 'Mohawk',
	'mos' => 'Mossi',
	'mr' => 'Marathi',
	'mrj' => 'Western Mari',
	'ms' => 'Malay',
	'mt' => 'Maltese',
	'mua' => 'Mundang',
	'mul' => 'Multiple languages',
	'mus' => 'Muscogee',
    'mus@alt=official' => 'Mvskoke',
	'mwl' => 'Mirandese',
	'mwr' => 'Marwari',
	'mwv' => 'Mentawai',
	'my' => 'Burmese',
	'my@alt=variant' => 'Myanmar Language',
	'mye' => 'Myene',
	'myv' => 'Erzya',
	'mzn' => 'Mazanderani',
	'na' => 'Nauru',
	'nan' => 'Min Nan Chinese',
	'nap' => 'Neapolitan',
	'naq' => 'Nama',
	'nb' => 'Norwegian Bokmål',
	'nd' => 'North Ndebele',
	'nds' => 'Low German',
	'nds_NL' => 'Low Saxon',
	'ne' => 'Nepali',
	'new' => 'Newari',
	'ng' => 'Ndonga',
	'nia' => 'Nias',
	'niu' => 'Niuean',
	'njo' => 'Ao Naga',
	'nl' => 'Dutch',
	'nl_BE' => 'Flemish',
	'nmg' => 'Kwasio',
	'nn' => 'Norwegian Nynorsk',
	'nnh' => 'Ngiemboon',
	'no' => 'Norwegian',
	'nog' => 'Nogai',
	'non' => 'Old Norse',
	'nov' => 'Novial',
	'nqo' => 'N’Ko',
	'nr' => 'South Ndebele',
	'nso' => 'Northern Sotho',
	'nus' => 'Nuer',
	'nv' => 'Navajo',
	'nwc' => 'Classical Newari',
	'ny' => 'Nyanja',
	'nym' => 'Nyamwezi',
	'nyn' => 'Nyankole',
	'nyo' => 'Nyoro',
	'nzi' => 'Nzima',
    'ojb' => 'Northwestern Ojibwa',
	'oc' => 'Occitan',
	'oj' => 'Ojibwa',
    'ojc' => 'Central Ojibwa',
    'ojg' => 'Eastern Ojibwa',
    'ojs' => 'Oji-Cree',
    'ojw' => 'Western Ojibwa',
    'oka' => 'Okanagan',
	'om' => 'Oromo',
	'or' => 'Odia',
	'os' => 'Ossetic',
	'osa' => 'Osage',
	'ota' => 'Ottoman Turkish',
	'pa' => 'Punjabi',
	'pag' => 'Pangasinan',
	'pal' => 'Pahlavi',
	'pam' => 'Pampanga',
	'pap' => 'Papiamento',
	'pau' => 'Palauan',
	'pcd' => 'Picard',
	'pcm' => 'Nigerian Pidgin',
	'pdc' => 'Pennsylvania German',
	'pdt' => 'Plautdietsch',
	'peo' => 'Old Persian',
	'pfl' => 'Palatine German',
	'phn' => 'Phoenician',
	'pi' => 'Pali',
    'pis' => 'Pijin',
	'pl' => 'Polish',
	'pms' => 'Piedmontese',
	'pnt' => 'Pontic',
	'pon' => 'Pohnpeian',
    'pqm' => 'Maliseet-Passamaquoddy',
	'prg' => 'Prussian',
	'pro' => 'Old Provençal',
	'ps' => 'Pashto',
	'ps@alt=variant' => 'Pushto',
	'pt' => 'Portuguese',
	'pt_BR' => 'Brazilian Portuguese',
	'pt_PT' => 'European Portuguese',
	'qu' => 'Quechua',
	'quc' => 'Kʼicheʼ',
	'qug' => 'Chimborazo Highland Quichua',
	'raj' => 'Rajasthani',
	'rap' => 'Rapanui',
	'rar' => 'Rarotongan',
	'rgn' => 'Romagnol',
	'rhg' => 'Rohingya',
	'rif' => 'Riffian',
	'rm' => 'Romansh',
	'rn' => 'Rundi',
	'ro' => 'Romanian',
	'ro_MD' => 'Moldavian',
	'rof' => 'Rombo',
	'rom' => 'Romany',
	'rtm' => 'Rotuman',
	'ru' => 'Russian',
	'rue' => 'Rusyn',
	'rug' => 'Roviana',
	'rup' => 'Aromanian',
	'rw' => 'Kinyarwanda',
	'rwk' => 'Rwa',
	'sa' => 'Sanskrit',
	'sad' => 'Sandawe',
	'sah' => 'Yakut',
	'sam' => 'Samaritan Aramaic',
	'saq' => 'Samburu',
	'sas' => 'Sasak',
	'sat' => 'Santali',
	'saz' => 'Saurashtra',
	'sba' => 'Ngambay',
	'sbp' => 'Sangu',
	'sc' => 'Sardinian',
	'scn' => 'Sicilian',
	'sco' => 'Scots',
	'sd' => 'Sindhi',
	'sdc' => 'Sassarese Sardinian',
	'sdh' => 'Southern Kurdish',
	'se' => 'Northern Sami',
	'se@alt=menu' => 'Sami, Northern',
	'see' => 'Seneca',
	'seh' => 'Sena',
	'sei' => 'Seri',
	'sel' => 'Selkup',
	'ses' => 'Koyraboro Senni',
	'sg' => 'Sango',
	'sga' => 'Old Irish',
	'sgs' => 'Samogitian',
	'sh' => 'Serbo-Croatian',
	'shi' => 'Tachelhit',
	'shn' => 'Shan',
	'shu' => 'Chadian Arabic',
	'si' => 'Sinhala',
	'sid' => 'Sidamo',
	'sk' => 'Slovak',
	'sl' => 'Slovenian',
    'slh' => 'Southern Lushootseed',
	'sli' => 'Lower Silesian',
	'sly' => 'Selayar',
	'sm' => 'Samoan',
	'sma' => 'Southern Sami',
	'sma@alt=menu' => 'Sami, Southern',
	'smj' => 'Lule Sami',
	'smj@alt=menu' => 'Sami, Lule',
	'smn' => 'Inari Sami',
	'smn@alt=menu' => 'Sami, Inari',
	'sms' => 'Skolt Sami',
	'sms@alt=menu' => 'Sami, Skolt',
	'sn' => 'Shona',
	'snk' => 'Soninke',
	'so' => 'Somali',
	'sog' => 'Sogdien',
	'sq' => 'Albanian',
	'sr' => 'Serbian',
	'sr_ME' => 'Montenegrin',
	'srn' => 'Sranan Tongo',
	'srr' => 'Serer',
	'ss' => 'Swati',
	'ssy' => 'Saho',
	'st' => 'Southern Sotho',
	'stq' => 'Saterland Frisian',
    'str' => 'Straits Salish',
	'su' => 'Sundanese',
	'suk' => 'Sukuma',
	'sus' => 'Susu',
	'sux' => 'Sumerian',
	'sv' => 'Swedish',
	'sw' => 'Swahili',
	'sw_CD' => 'Congo Swahili',
	'swb' => 'Comorian',
	'syc' => 'Classical Syriac',
	'syr' => 'Syriac',
	'szl' => 'Silesian',
	'ta' => 'Tamil',
    'tce' => 'Southern Tutchone',
	'tcy' => 'Tulu',
	'te' => 'Telugu',
	'tem' => 'Timne',
	'teo' => 'Teso',
	'ter' => 'Tereno',
	'tet' => 'Tetum',
	'tg' => 'Tajik',
    'tgx' => 'Tagish',
	'th' => 'Thai',
    'tht' => 'Tahltan',
	'ti' => 'Tigrinya',
	'tig' => 'Tigre',
	'tiv' => 'Tiv',
	'tk' => 'Turkmen',
	'tkl' => 'Tokelau',
	'tkr' => 'Tsakhur',
	'tl' => 'Tagalog',
	'tlh' => 'Klingon',
	'tli' => 'Tlingit',
	'tly' => 'Talysh',
	'tmh' => 'Tamashek',
	'tn' => 'Tswana',
	'to' => 'Tongan',
	'tog' => 'Nyasa Tonga',
	'tpi' => 'Tok Pisin',
    'tok' => 'Toki Pona',
	'tr' => 'Turkish',
	'tru' => 'Turoyo',
	'trv' => 'Taroko',
    'trw' => 'Torwali',
	'ts' => 'Tsonga',
	'tsd' => 'Tsakonian',
	'tsi' => 'Tsimshian',
	'tt' => 'Tatar',
    'ttm' => 'Northern Tutchone',
	'ttt' => 'Muslim Tat',
	'tum' => 'Tumbuka',
	'tvl' => 'Tuvalu',
	'tw' => 'Twi',
	'twq' => 'Tasawaq',
	'ty' => 'Tahitian',
	'tyv' => 'Tuvinian',
	'tzm' => 'Central Atlas Tamazight',
	'udm' => 'Udmurt',
	'ug' => 'Uyghur',
	'ug@alt=variant' => 'Uighur',
	'uga' => 'Ugaritic',
	'uk' => 'Ukrainian',
	'umb' => 'Umbundu',
	'und' => 'Unknown language',
	'ur' => 'Urdu',
	'uz' => 'Uzbek',
	'vai' => 'Vai',
	've' => 'Venda',
	'vec' => 'Venetian',
	'vep' => 'Veps',
	'vi' => 'Vietnamese',
	'vls' => 'West Flemish',
	'vmf' => 'Main-Franconian',
    'vmw' => 'Makhuwa',
	'vo' => 'Volapük',
	'vot' => 'Votic',
	'vro' => 'Võro',
	'vun' => 'Vunjo',
	'wa' => 'Walloon',
	'wae' => 'Walser',
	'wal' => 'Wolaytta',
	'war' => 'Waray',
	'was' => 'Washo',
	'wbp' => 'Warlpiri',
	'wo' => 'Wolof',
	'wuu' => 'Wu Chinese',
	'xal' => 'Kalmyk',
	'xh' => 'Xhosa',
	'xmf' => 'Mingrelian',
    'xnr' => 'Kangri',
	'xog' => 'Soga',
	'yao' => 'Yao',
	'yap' => 'Yapese',
	'yav' => 'Yangben',
	'ybb' => 'Yemba',
	'yi' => 'Yiddish',
	'yo' => 'Yoruba',
	'yrl' => 'Nheengatu',
	'yue' => 'Cantonese',
	'yue@alt=menu' => 'Chinese, Cantonese',
	'za' => 'Zhuang',
	'zap' => 'Zapotec',
	'zbl' => 'Blissymbols',
	'zea' => 'Zeelandic',
	'zen' => 'Zenaga',
	'zgh' => 'Standard Moroccan Tamazight',
	'zh' => 'Chinese',
	'zh@alt=long' => 'Mandarin Chinese',
	'zh@alt=menu' => 'Chinese, Mandarin',
	'zh_Hans' => 'Simplified Chinese',
	'zh_Hans@alt=long' => 'Simplified Mandarin Chinese',
	'zh_Hant' => 'Traditional Chinese',
	'zh_Hant@alt=long' => 'Traditional Mandarin Chinese',
	'zu' => 'Zulu',
	'zun' => 'Zuni',
	'zxx' => 'No linguistic content',
	'zza' => 'Zaza',
};

is_deeply($locale->all_languages, $all_languages, 'All languages');

is($locale->script_name(), '', 'Script name from current locale');
is($locale->script_name('latn'), 'Latin', 'Script name from string');


my $all_scripts = {
	'Adlm' => 'Adlam',
	'Afak' => 'Afaka',
	'Aghb' => 'Caucasian Albanian',
	'Ahom' => 'Ahom',
	'Arab' => 'Arabic',
	'Arab@alt=variant' => 'Perso-Arabic',
	'Aran' => 'Nastaliq',
	'Armi' => 'Imperial Aramaic',
	'Armn' => 'Armenian',
	'Avst' => 'Avestan',
	'Bali' => 'Balinese',
	'Bamu' => 'Bamum',
	'Bass' => 'Bassa Vah',
	'Batk' => 'Batak',
	'Beng' => 'Bangla',
	'Bhks' => 'Bhaiksuki',
	'Blis' => 'Blissymbols',
	'Bopo' => 'Bopomofo',
	'Brah' => 'Brahmi',
	'Brai' => 'Braille',
	'Bugi' => 'Buginese',
	'Buhd' => 'Buhid',
	'Cakm' => 'Chakma',
	'Cans' => 'Unified Canadian Aboriginal Syllabics',
	'Cans@alt=short' => 'UCAS',
	'Cari' => 'Carian',
	'Cham' => 'Cham',
	'Cher' => 'Cherokee',
	'Chrs' => 'Chorasmian',
	'Cirt' => 'Cirth',
	'Copt' => 'Coptic',
	'Cpmn' => 'Cypro-Minoan',
	'Cprt' => 'Cypriot',
	'Cyrl' => 'Cyrillic',
	'Cyrs' => 'Old Church Slavonic Cyrillic',
	'Deva' => 'Devanagari',
	'Diak' => 'Dives Akuru',
	'Dogr' => 'Dogra',
	'Dsrt' => 'Deseret',
	'Dupl' => 'Duployan shorthand',
	'Egyd' => 'Egyptian demotic',
	'Egyh' => 'Egyptian hieratic',
	'Egyp' => 'Egyptian hieroglyphs',
	'Elba' => 'Elbasan',
	'Elym' => 'Elymaic',
	'Ethi' => 'Ethiopic',
    'Gara' => 'Garay',
	'Geok' => 'Georgian Khutsuri',
	'Geor' => 'Georgian',
	'Glag' => 'Glagolitic',
	'Gong' => 'Gunjala Gondi',
	'Gonm' => 'Masaram Gondi',
	'Goth' => 'Gothic',
	'Gran' => 'Grantha',
	'Grek' => 'Greek',
	'Gujr' => 'Gujarati',
    'Gukh' => 'Gurung Khema',
	'Guru' => 'Gurmukhi',
	'Hanb' => 'Han with Bopomofo',
	'Hang' => 'Hangul',
	'Hani' => 'Han',
	'Hano' => 'Hanunoo',
	'Hans' => 'Simplified',
	'Hans@alt=stand-alone' => 'Simplified Han',
	'Hant' => 'Traditional',
	'Hant@alt=stand-alone' => 'Traditional Han',
	'Hatr' => 'Hatran',
	'Hebr' => 'Hebrew',
	'Hira' => 'Hiragana',
	'Hluw' => 'Anatolian Hieroglyphs',
	'Hmng' => 'Pahawh Hmong',
	'Hmnp' => 'Nyiakeng Puachue Hmong',
	'Hrkt' => 'Japanese syllabaries',
	'Hung' => 'Old Hungarian',
	'Inds' => 'Indus',
	'Ital' => 'Old Italic',
	'Java' => 'Javanese',
	'Jamo' => 'Jamo',
	'Jpan' => 'Japanese',
	'Jurc' => 'Jurchen',
	'Kali' => 'Kayah Li',
	'Kana' => 'Katakana',
    'Kawi' => 'Kawi',
	'Khar' => 'Kharoshthi',
	'Khmr' => 'Khmer',
	'Khoj' => 'Khojki',
    'Kits' => 'Khitan small script',
	'Knda' => 'Kannada',
	'Kore' => 'Korean',
	'Kpel' => 'Kpelle',
    'Krai' => 'Kirat Rai',
	'Kthi' => 'Kaithi',
	'Lana' => 'Lanna',
	'Laoo' => 'Lao',
	'Latf' => 'Fraktur Latin',
	'Latg' => 'Gaelic Latin',
	'Latn' => 'Latin',
	'Lepc' => 'Lepcha',
	'Limb' => 'Limbu',
	'Lina' => 'Linear A',
	'Linb' => 'Linear B',
	'Lisu' => 'Fraser',
	'Loma' => 'Loma',
	'Lyci' => 'Lycian',
	'Lydi' => 'Lydian',
	'Mahj' => 'Mahajani',
	'Maka' => 'Makasar',
	'Mand' => 'Mandaean',
	'Mani' => 'Manichaean',
	'Marc' => 'Marchen',
	'Maya' => 'Mayan hieroglyphs',
	'Medf' => 'Medefaidrin',
	'Mend' => 'Mende',
	'Merc' => 'Meroitic Cursive',
	'Mero' => 'Meroitic',
	'Mlym' => 'Malayalam',
	'Modi' => 'Modi',
	'Mong' => 'Mongolian',
	'Moon' => 'Moon',
	'Mroo' => 'Mro',
	'Mtei' => 'Meitei Mayek',
	'Mult' => 'Multani',
	'Mymr' => 'Myanmar',
    'Nagm' => 'Nag Mundari',
	'Nand' => 'Nandinagari',
	'Narb' => 'Old North Arabian',
	'Nbat' => 'Nabataean',
	'Newa' => 'Newa',
	'Nkgb' => 'Naxi Geba',
	'Nkoo' => 'N’Ko',
	'Nshu' => 'Nüshu',
	'Ogam' => 'Ogham',
	'Olck' => 'Ol Chiki',
    'Onao' => 'Ol Onal',
	'Orkh' => 'Orkhon',
	'Orya' => 'Odia',
	'Osge' => 'Osage',
	'Osma' => 'Osmanya',
	'Ougr' => 'Old Uyghur',
	'Palm' => 'Palmyrene',
	'Pauc' => 'Pau Cin Hau',
	'Perm' => 'Old Permic',
	'Phag' => 'Phags-pa',
	'Phli' => 'Inscriptional Pahlavi',
	'Phlp' => 'Psalter Pahlavi',
	'Phlv' => 'Book Pahlavi',
	'Phnx' => 'Phoenician',
	'Plrd' => 'Pollard Phonetic',
	'Prti' => 'Inscriptional Parthian',
	'Qaag' => 'Zawgyi',
	'Rjng' => 'Rejang',
	'Rohg' => 'Hanifi',
	'Rohg@alt=stand-alone' => 'Hanifi Rohingya',
	'Roro' => 'Rongorongo',
	'Runr' => 'Runic',
	'Samr' => 'Samaritan',
	'Sara' => 'Sarati',
	'Sarb' => 'Old South Arabian',
	'Saur' => 'Saurashtra',
	'Sgnw' => 'SignWriting',
	'Shaw' => 'Shavian',
	'Shrd' => 'Sharada',
	'Sidd' => 'Siddham',
	'Sind' => 'Khudawadi',
	'Sinh' => 'Sinhala',
	'Sogd' => 'Sogdian',
	'Sogo' => 'Old Sogdian',
	'Sora' => 'Sora Sompeng',
	'Soyo' => 'Soyombo',
	'Sund' => 'Sundanese',
    'Sunu' => 'Sunuwar',
	'Sylo' => 'Syloti Nagri',
	'Syrc' => 'Syriac',
	'Syre' => 'Estrangelo Syriac',
	'Syrj' => 'Western Syriac',
	'Syrn' => 'Eastern Syriac',
	'Tagb' => 'Tagbanwa',
	'Takr' => 'Takri',
	'Tale' => 'Tai Le',
	'Talu' => 'New Tai Lue',
	'Taml' => 'Tamil',
	'Tang' => 'Tangut',
	'Tavt' => 'Tai Viet',
	'Telu' => 'Telugu',
	'Teng' => 'Tengwar',
	'Tfng' => 'Tifinagh',
	'Tglg' => 'Tagalog',
	'Thaa' => 'Thaana',
	'Thai' => 'Thai',
	'Tibt' => 'Tibetan',
	'Tirh' => 'Tirhuta',
	'Tnsa' => 'Tangsa',
	'Toto' => 'Toto',
    'Tutg' => 'Tulu-Tigalari',
    'Todr' => 'Todhri',
	'Ugar' => 'Ugaritic',
	'Vaii' => 'Vai',
	'Visp' => 'Visible Speech',
	'Vith' => 'Vithkuqi',
	'Wara' => 'Varang Kshiti',
	'Wcho' => 'Wancho',
	'Wole' => 'Woleai',
	'Xpeo' => 'Old Persian',
	'Xsux' => 'Sumero-Akkadian Cuneiform',
	'Xsux@alt=short' => 'S-A Cuneiform',
	'Yezi' => 'Yezidi',
	'Yiii' => 'Yi',
	'Zanb' => 'Zanabazar Square',
	'Zinh' => 'Inherited',
	'Zmth' => 'Mathematical Notation',
	'Zsye' => 'Emoji',
	'Zsym' => 'Symbols',
	'Zxxx' => 'Unwritten',
	'Zyyy' => 'Common',
	'Zzzz' => 'Unknown Script',
};

is_deeply($locale->all_scripts, $all_scripts, 'All scripts');

is($locale->region_name(), 'United States', 'Region name from current locale');
is($locale->region_name('fr'), 'France', 'Region name from string');

my $all_regions = {
	'001' => 'world',
	'002' => 'Africa',
	'003' => 'North America',
	'005' => 'South America',
	'009' => 'Oceania',
	'011' => 'Western Africa',
	'013' => 'Central America',
	'014' => 'Eastern Africa',
	'015' => 'Northern Africa',
	'017' => 'Middle Africa',
	'018' => 'Southern Africa',
	'019' => 'Americas',
	'021' => 'Northern America',
	'029' => 'Caribbean',
	'030' => 'Eastern Asia',
	'034' => 'Southern Asia',
	'035' => 'Southeast Asia',
	'039' => 'Southern Europe',
	'053' => 'Australasia',
	'054' => 'Melanesia',
	'057' => 'Micronesian Region',
	'061' => 'Polynesia',
	'142' => 'Asia',
	'143' => 'Central Asia',
	'145' => 'Western Asia',
	'150' => 'Europe',
	'151' => 'Eastern Europe',
	'154' => 'Northern Europe',
	'155' => 'Western Europe',
	'202' => 'Sub-Saharan Africa',
	'419' => 'Latin America',
	'AC' => 'Ascension Island',
	'AD' => 'Andorra',
	'AE' => 'United Arab Emirates',
	'AF' => 'Afghanistan',
	'AG' => 'Antigua & Barbuda',
	'AI' => 'Anguilla',
	'AL' => 'Albania',
	'AM' => 'Armenia',
	'AO' => 'Angola',
	'AQ' => 'Antarctica',
	'AR' => 'Argentina',
	'AS' => 'American Samoa',
	'AT' => 'Austria',
	'AU' => 'Australia',
	'AW' => 'Aruba',
	'AX' => 'Åland Islands',
	'AZ' => 'Azerbaijan',
	'BA' => 'Bosnia & Herzegovina',
	'BA@alt=short' => 'Bosnia',
	'BB' => 'Barbados',
	'BD' => 'Bangladesh',
	'BE' => 'Belgium',
	'BF' => 'Burkina Faso',
	'BG' => 'Bulgaria',
	'BH' => 'Bahrain',
	'BI' => 'Burundi',
	'BJ' => 'Benin',
	'BL' => 'St. Barthélemy',
	'BM' => 'Bermuda',
	'BN' => 'Brunei',
	'BO' => 'Bolivia',
	'BQ' => 'Caribbean Netherlands',
	'BR' => 'Brazil',
	'BS' => 'Bahamas',
	'BT' => 'Bhutan',
	'BV' => 'Bouvet Island',
	'BW' => 'Botswana',
	'BY' => 'Belarus',
	'BZ' => 'Belize',
	'CA' => 'Canada',
	'CC' => 'Cocos (Keeling) Islands',
	'CD' => 'Congo - Kinshasa',
	'CD@alt=variant' => 'Congo (DRC)',
	'CF' => 'Central African Republic',
	'CG' => 'Congo - Brazzaville',
	'CG@alt=variant' => 'Congo (Republic)',
	'CH' => 'Switzerland',
	'CI' => 'Côte d’Ivoire',
	'CI@alt=variant' => 'Ivory Coast',
	'CK' => 'Cook Islands',
	'CL' => 'Chile',
	'CM' => 'Cameroon',
	'CN' => 'China',
	'CO' => 'Colombia',
	'CP' => 'Clipperton Island',
    'CQ' => 'Sark',
	'CR' => 'Costa Rica',
	'CU' => 'Cuba',
	'CV' => 'Cape Verde',
	'CV@alt=variant' => 'Cabo Verde',
	'CW' => 'Curaçao',
	'CX' => 'Christmas Island',
	'CY' => 'Cyprus',
	'CZ' => 'Czechia',
	'CZ@alt=variant' => 'Czech Republic',
	'DE' => 'Germany',
	'DG' => 'Diego Garcia',
	'DJ' => 'Djibouti',
	'DK' => 'Denmark',
	'DM' => 'Dominica',
	'DO' => 'Dominican Republic',
	'DZ' => 'Algeria',
	'EA' => 'Ceuta & Melilla',
	'EC' => 'Ecuador',
	'EE' => 'Estonia',
	'EG' => 'Egypt',
	'EH' => 'Western Sahara',
	'ER' => 'Eritrea',
	'ES' => 'Spain',
	'ET' => 'Ethiopia',
	'EU' => 'European Union',
	'EZ' => 'Eurozone',
	'FI' => 'Finland',
	'FJ' => 'Fiji',
	'FK' => 'Falkland Islands',
	'FK@alt=variant' => 'Falkland Islands (Islas Malvinas)',
	'FM' => 'Micronesia',
	'FO' => 'Faroe Islands',
	'FR' => 'France',
	'GA' => 'Gabon',
	'GB' => 'United Kingdom',
	'GB@alt=short' => 'UK',
	'GD' => 'Grenada',
	'GE' => 'Georgia',
	'GF' => 'French Guiana',
	'GG' => 'Guernsey',
	'GH' => 'Ghana',
	'GI' => 'Gibraltar',
	'GL' => 'Greenland',
	'GM' => 'Gambia',
	'GN' => 'Guinea',
	'GP' => 'Guadeloupe',
	'GQ' => 'Equatorial Guinea',
	'GR' => 'Greece',
	'GS' => 'South Georgia & South Sandwich Islands',
	'GT' => 'Guatemala',
	'GU' => 'Guam',
	'GW' => 'Guinea-Bissau',
	'GY' => 'Guyana',
	'HK' => 'Hong Kong SAR China',
	'HK@alt=short' => 'Hong Kong',
	'HM' => 'Heard & McDonald Islands',
	'HN' => 'Honduras',
	'HR' => 'Croatia',
	'HT' => 'Haiti',
	'HU' => 'Hungary',
	'IC' => 'Canary Islands',
	'ID' => 'Indonesia',
	'IE' => 'Ireland',
	'IL' => 'Israel',
	'IM' => 'Isle of Man',
	'IN' => 'India',
	'IO' => 'British Indian Ocean Territory',
    'IO@alt=chagos' => 'Chagos Archipelago',
	'IQ' => 'Iraq',
	'IR' => 'Iran',
	'IS' => 'Iceland',
	'IT' => 'Italy',
	'JE' => 'Jersey',
	'JM' => 'Jamaica',
	'JO' => 'Jordan',
	'JP' => 'Japan',
	'KE' => 'Kenya',
	'KG' => 'Kyrgyzstan',
	'KH' => 'Cambodia',
	'KI' => 'Kiribati',
	'KM' => 'Comoros',
	'KN' => 'St. Kitts & Nevis',
	'KP' => 'North Korea',
	'KR' => 'South Korea',
	'KW' => 'Kuwait',
	'KY' => 'Cayman Islands',
	'KZ' => 'Kazakhstan',
	'LA' => 'Laos',
	'LB' => 'Lebanon',
	'LC' => 'St. Lucia',
	'LI' => 'Liechtenstein',
	'LK' => 'Sri Lanka',
	'LR' => 'Liberia',
	'LS' => 'Lesotho',
	'LT' => 'Lithuania',
	'LU' => 'Luxembourg',
	'LV' => 'Latvia',
	'LY' => 'Libya',
	'MA' => 'Morocco',
	'MC' => 'Monaco',
	'MD' => 'Moldova',
	'ME' => 'Montenegro',
	'MF' => 'St. Martin',
	'MG' => 'Madagascar',
	'MH' => 'Marshall Islands',
	'MK' => 'North Macedonia',
	'ML' => 'Mali',
	'MM' => 'Myanmar (Burma)',
	'MM@alt=short' => 'Myanmar',
	'MN' => 'Mongolia',
	'MO' => 'Macao SAR China',
	'MO@alt=short' => 'Macao',
	'MP' => 'Northern Mariana Islands',
	'MQ' => 'Martinique',
	'MR' => 'Mauritania',
	'MS' => 'Montserrat',
	'MT' => 'Malta',
	'MU' => 'Mauritius',
	'MV' => 'Maldives',
	'MW' => 'Malawi',
	'MX' => 'Mexico',
	'MY' => 'Malaysia',
	'MZ' => 'Mozambique',
	'NA' => 'Namibia',
	'NC' => 'New Caledonia',
	'NE' => 'Niger',
	'NF' => 'Norfolk Island',
	'NG' => 'Nigeria',
	'NI' => 'Nicaragua',
	'NL' => 'Netherlands',
	'NO' => 'Norway',
	'NP' => 'Nepal',
	'NR' => 'Nauru',
	'NU' => 'Niue',
	'NZ' => 'New Zealand',
    'NZ@alt=variant' => 'Aotearoa New Zealand',
	'OM' => 'Oman',
	'PA' => 'Panama',
	'PE' => 'Peru',
	'PF' => 'French Polynesia',
	'PG' => 'Papua New Guinea',
	'PH' => 'Philippines',
	'PK' => 'Pakistan',
	'PL' => 'Poland',
	'PM' => 'St. Pierre & Miquelon',
	'PN' => 'Pitcairn Islands',
	'PR' => 'Puerto Rico',
	'PS' => 'Palestinian Territories',
	'PS@alt=short' => 'Palestine',
	'PT' => 'Portugal',
	'PW' => 'Palau',
	'PY' => 'Paraguay',
	'QA' => 'Qatar',
	'QO' => 'Outlying Oceania',
	'RE' => 'Réunion',
	'RO' => 'Romania',
	'RS' => 'Serbia',
	'RU' => 'Russia',
	'RW' => 'Rwanda',
	'SA' => 'Saudi Arabia',
	'SB' => 'Solomon Islands',
	'SC' => 'Seychelles',
	'SD' => 'Sudan',
	'SE' => 'Sweden',
	'SG' => 'Singapore',
	'SH' => 'St. Helena',
	'SI' => 'Slovenia',
	'SJ' => 'Svalbard & Jan Mayen',
	'SK' => 'Slovakia',
	'SL' => 'Sierra Leone',
	'SM' => 'San Marino',
	'SN' => 'Senegal',
	'SO' => 'Somalia',
	'SR' => 'Suriname',
	'SS' => 'South Sudan',
	'ST' => 'São Tomé & Príncipe',
	'SV' => 'El Salvador',
	'SX' => 'Sint Maarten',
	'SY' => 'Syria',
	'SZ' => 'Eswatini',
	'SZ@alt=variant' => 'Swaziland',
	'TA' => 'Tristan da Cunha',
	'TC' => 'Turks & Caicos Islands',
	'TD' => 'Chad',
	'TF' => 'French Southern Territories',
	'TG' => 'Togo',
	'TH' => 'Thailand',
	'TJ' => 'Tajikistan',
	'TK' => 'Tokelau',
	'TL' => 'Timor-Leste',
	'TL@alt=variant' => 'East Timor',
	'TM' => 'Turkmenistan',
	'TN' => 'Tunisia',
	'TO' => 'Tonga',
    'TR@alt=variant' => 'Turkey',
	'TR' => 'Türkiye',
	'TT' => 'Trinidad & Tobago',
	'TV' => 'Tuvalu',
	'TW' => 'Taiwan',
	'TZ' => 'Tanzania',
	'UA' => 'Ukraine',
	'UG' => 'Uganda',
	'UN' => 'United Nations',
	'UN@alt=short' => 'UN',
	'UM' => 'U.S. Outlying Islands',
	'US' => 'United States',
	'US@alt=short' => 'US',
	'UY' => 'Uruguay',
	'UZ' => 'Uzbekistan',
	'VA' => 'Vatican City',
	'VC' => 'St. Vincent & Grenadines',
	'VE' => 'Venezuela',
	'VG' => 'British Virgin Islands',
	'VI' => 'U.S. Virgin Islands',
	'VN' => 'Vietnam',
	'VU' => 'Vanuatu',
	'WF' => 'Wallis & Futuna',
	'WS' => 'Samoa',
	'XA' => 'Pseudo-Accents',
	'XB' => 'Pseudo-Bidi',
	'XK' => 'Kosovo',
	'YE' => 'Yemen',
	'YT' => 'Mayotte',
	'ZA' => 'South Africa',
	'ZM' => 'Zambia',
	'ZW' => 'Zimbabwe',
	'ZZ' => 'Unknown Region',
};

is_deeply($locale->all_regions(), $all_regions, 'All Regions');

is($locale->variant_name(), '', 'Variant name from current locale');
is($locale->variant_name('BOHORIC'), 'Bohorič alphabet', 'Variant name from string');
is($locale->key_name('colCaseLevel'), 'Case Sensitive Sorting', 'Key name from string');

is($locale->type_name(colCaseFirst => 'lower'), 'Sort Lowercase First', 'Type name from string');

is($locale->measurement_system_name('metric'), 'Metric', 'Measurement system name English Metric');
is($locale->measurement_system_name('us'), 'US', 'Measurement system name English US');
is($locale->measurement_system_name('uk'), 'UK', 'Measurement system name English UK');

TODO: {
	local $TODO = 'Translitteration unimplimented';
	is($locale->transform_name('Numeric'), 'Numeric', 'Transform name from string');
}