#!/usr/bin/perl
# Do not normalise this test file. It has deliberately unnormalised characters in it.
use v5.10;
use strict;
use warnings;
use utf8;
use if $^V ge v5.12.0, feature => 'unicode_strings';

use Test::More tests => 25;
use Test::Exception;

use ok 'Locale::CLDR';

my $locale = Locale::CLDR->new('br_FR');
my $other_locale = Locale::CLDR->new('en_US');

is($locale->locale_name(), 'brezhoneg (Frañs)', 'Locale name from current locale');
is($locale->locale_name('fr_CA'), 'galleg Kanada', 'Locale name from string');
is($locale->locale_name($other_locale), 'saozneg Amerika', 'Locale name from other locale object');

is($locale->language_name(), 'brezhoneg', 'Language name from current locale');
is($locale->language_name('fr'), 'galleg', 'Language name from string');
is($locale->language_name($other_locale), 'saozneg', 'Language name from other locale object');

my $all_languages = {
    'aa' => 'afar',
    'ab' => 'abkhazeg',
    'ace' => 'achineg',
    'ach' => 'acoli',
    'ada' => 'adangme',
    'ady' => 'adygeieg',
    'ae' => 'avesteg',
    'aeb' => 'arabeg Tunizia',
    'af' => 'afrikaans',
    'afh' => 'afrihili',
    'agq' => 'aghem',
    'ain' => 'ainoueg',
    'ak' => 'akan',
    'akk' => 'akadeg',
    'akz' => 'alabamaeg',
    'ale' => 'aleouteg',
    'aln' => 'gegeg',
    'alt' => 'altaieg ar Su',
    'am' => 'amhareg',
    'an' => 'aragoneg',
    'ang' => 'hensaozneg',
    'ann' => 'obolo',
    'anp' => 'angika',
    'ar' => 'arabeg',
    'ar_001' => 'arabeg modern',
    'arc' => 'arameeg',
    'arn' => 'araoukaneg',
    'aro' => 'araona',
    'arp' => 'arapaho',
    'arq' => 'arabeg Aljeria',
    'ars' => 'arabeg nadjiek',
    'arw' => 'arawakeg',
    'ary' => 'arabeg Maroko',
    'arz' => 'arabeg Egipt',
    'as' => 'asameg',
    'asa' => 'asu',
    'ase' => 'yezh sinoù Amerika',
    'ast' => 'asturianeg',
    'atj' => 'atikamekweg',
    'av' => 'avar',
    'awa' => 'awadhi',
    'ay' => 'aymara',
    'az' => 'azerbaidjaneg',
    'az@alt=short' => 'azeri',
    'ba' => 'bachkir',
    'bal' => 'baloutchi',
    'ban' => 'balineg',
    'bar' => 'bavarieg',
    'bas' => 'basaa',
    'be' => 'belaruseg',
    'bej' => 'bedawieg',
    'bem' => 'bemba',
    'bez' => 'bena',
    'bg' => 'bulgareg',
    'bgn' => 'baloutchi ar Cʼhornôg',
    'bho' => 'bhojpuri',
    'bi' => 'bislama',
    'bik' => 'bikol',
    'bin' => 'bini',
    'bla' => 'siksika',
    'bm' => 'bambara',
    'bn' => 'bengali',
    'bo' => 'tibetaneg',
    'br' => 'brezhoneg',
    'bra' => 'braj',
    'brh' => 'brahweg',
    'brx' => 'bodo',
    'bs' => 'bosneg',
    'bss' => 'akoose',
    'bua' => 'bouriat',
    'bug' => 'bugi',
    'byn' => 'blin',
    'ca' => 'katalaneg',
    'cad' => 'caddo',
    'car' => 'karibeg',
    'cay' => 'kayougeg',
    'cch' => 'atsam',
    'ccp' => 'chakmaeg',
    'ce' => 'tchetcheneg',
    'ceb' => 'cebuano',
    'cgg' => 'chigaeg',
    'ch' => 'chamorru',
    'chb' => 'chibcha',
    'chk' => 'chuuk',
    'chm' => 'marieg',
    'cho' => 'choktaw',
    'chp' => 'chipewyan',
    'chr' => 'cherokee',
    'chy' => 'cheyenne',
    'ckb' => 'kurdeg sorani',
    'ckb@alt=menu' => 'kurdeg kreiz',
    'clc' => 'chilkotineg',
    'co' => 'korseg',
    'cop' => 'kopteg',
    'cr' => 'kri',
    'crg' => 'michifeg',
    'crh' => 'turkeg Krimea',
    'crj' => 'krieg ar Gevred',
    'crk' => 'krieg ar cʼhompezennoù',
    'crl' => 'krieg ar Biz',
    'crm' => 'krieg ar cʼhornôg',
    'crr' => 'algonkeg Carolina',
    'crs' => 'kreoleg Sechelez',
    'cs' => 'tchekeg',
    'csb' => 'kachoubeg',
    'csw' => 'krieg ar gwernioù',
    'cu' => 'slavoneg iliz',
    'cv' => 'tchouvatch',
    'cy' => 'kembraeg',
    'da' => 'daneg',
    'dak' => 'dakota',
    'dar' => 'dargwa',
    'dav' => 'taita',
    'de' => 'alamaneg',
    'de_AT' => 'alamaneg Aostria',
    'de_CH' => 'alamaneg uhel Suis',
    'del' => 'delaware',
    'dgr' => 'dogrib',
    'din' => 'dinka',
    'dje' => 'zarma',
    'doi' => 'dogri',
    'dsb' => 'izelsorabeg',
    'dua' => 'douala',
    'dum' => 'nederlandeg krenn',
    'dv' => 'divehi',
    'dyo' => 'diola',
    'dyu' => 'dyula',
    'dz' => 'dzongkha',
    'dzg' => 'dazagaeg',
    'ebu' => 'embu',
    'ee' => 'ewe',
    'efi' => 'efik',
    'egy' => 'henegipteg',
    'eka' => 'ekajuk',
    'el' => 'gresianeg',
    'elx' => 'elameg',
    'en' => 'saozneg',
    'en_AU' => 'saozneg Aostralia',
    'en_CA' => 'saozneg Kanada',
    'en_GB' => 'saozneg Breizh-Veur',
    'en_GB@alt=short' => 'saozneg RU',
    'en_US' => 'saozneg Amerika',
    'en_US@alt=short' => 'saozneg SU',
    'enm' => 'krennsaozneg',
    'eo' => 'esperanteg',
    'es' => 'spagnoleg',
    'es_419' => 'spagnoleg Amerika latin',
    'es_ES' => 'spagnoleg Europa',
    'es_MX' => 'spagnoleg Mecʼhiko',
    'et' => 'estoneg',
    'eu' => 'euskareg',
    'ewo' => 'ewondo',
    'fa' => 'perseg',
    'fa_AF' => 'dareg',
    'fan' => 'fang',
    'fat' => 'fanti',
    'ff' => 'fula',
    'fi' => 'finneg',
    'fil' => 'filipineg',
    'fit' => 'finneg traoñienn an Torne',
    'fj' => 'fidjieg',
    'fo' => 'faeroeg',
    'fon' => 'fon',
    'fr' => 'galleg',
    'fr_CA' => 'galleg Kanada',
    'fr_CH' => 'galleg Suis',
    'frc' => 'galleg cajun',
    'frm' => 'krenncʼhalleg',
    'fro' => 'hencʼhalleg',
    'frp' => 'arpitaneg',
    'frr' => 'frizeg an Norzh',
    'frs' => 'frizeg ar Reter',
    'fur' => 'frioulaneg',
    'fy' => 'frizeg ar Cʼhornôg',
    'ga' => 'iwerzhoneg',
    'gaa' => 'ga',
    'gag' => 'gagaouzeg',
    'gan' => 'sinaeg Gan',
    'gay' => 'gayo',
    'gba' => 'gbaya',
    'gd' => 'skoseg',
    'gez' => 'gezeg',
    'gil' => 'gilberteg',
    'gl' => 'galizeg',
    'gmh' => 'krennalamaneg uhel',
    'gn' => 'guarani',
    'goh' => 'henalamaneg uhel',
    'gor' => 'gorontalo',
    'got' => 'goteg',
    'grb' => 'grebo',
    'grc' => 'hencʼhresianeg',
    'gsw' => 'alamaneg Suis',
    'gu' => 'gujarati',
    'guz' => 'gusiieg',
    'gv' => 'manaveg',
    'gwi' => 'gwich’in',
    'ha' => 'haousa',
    'hai' => 'haideg',
    'hak' => 'sinaeg Hakka',
    'haw' => 'hawaieg',
    'hax' => 'haideg ar Su',
    'he' => 'hebraeg',
    'hi' => 'hindi',
    'hil' => 'hiligaynon',
    'hmn' => 'hmong',
    'ho' => 'hiri motu',
    'hr' => 'kroateg',
    'hsb' => 'uhelsorabeg',
    'hsn' => 'sinaeg Xian',
    'ht' => 'haitieg',
    'hu' => 'hungareg',
    'hup' => 'hupa',
    'hur' => 'halkomelemeg',
    'hy' => 'armenianeg',
    'hz' => 'herero',
    'ia' => 'interlingua',
    'iba' => 'iban',
    'ibb' => 'ibibio',
    'id' => 'indonezeg',
    'ie' => 'interlingue',
    'ig' => 'igbo',
    'ii' => 'yieg Sichuan',
    'ik' => 'inupiaq',
    'ikt' => 'inuktitut Kanada ar Cʼhornôg',
    'ilo' => 'ilokanoeg',
    'inh' => 'ingoucheg',
    'io' => 'ido',
    'is' => 'islandeg',
    'it' => 'italianeg',
    'iu' => 'inuktitut',
    'ja' => 'japaneg',
    'jam' => 'kreoleg Jamaika',
    'jbo' => 'lojban',
    'jgo' => 'ngomba',
    'jmc' => 'machame',
    'jpr' => 'yuzev-perseg',
    'jrb' => 'yuzev-arabeg',
    'jv' => 'javaneg',
    'ka' => 'jorjianeg',
    'kaa' => 'karakalpak',
    'kab' => 'kabileg',
    'kac' => 'kachin',
    'kaj' => 'jju',
    'kam' => 'kamba',
    'kbd' => 'kabardeg',
    'kcg' => 'tyap',
    'kde' => 'makonde',
    'kea' => 'kabuverdianu',
    'kfo' => 'koroeg',
    'kg' => 'kongo',
    'kgp' => 'kaingangeg',
    'kha' => 'khasi',
    'kho' => 'khotaneg',
    'khq' => 'koyra chiini',
    'ki' => 'kikuyu',
    'kj' => 'kwanyama',
    'kk' => 'kazak',
    'kkj' => 'kakoeg',
    'kl' => 'greunlandeg',
    'kln' => 'kalendjineg',
    'km' => 'khmer',
    'kmb' => 'kimbundu',
    'kn' => 'kanareg',
    'ko' => 'koreaneg',
    'kok' => 'konkani',
    'kos' => 'kosrae',
    'kpe' => 'kpelle',
    'kr' => 'kanouri',
    'krc' => 'karatchay-balkar',
    'kri' => 'krio',
    'krl' => 'karelieg',
    'kru' => 'kurukh',
    'ks' => 'kashmiri',
    'ksb' => 'shambala',
    'ksf' => 'bafiaeg',
    'ksh' => 'koluneg',
    'ku' => 'kurdeg',
    'kum' => 'koumikeg',
    'kut' => 'kutenai',
    'kv' => 'komieg',
    'kw' => 'kerneveureg',
    'kwk' => 'kwakwaleg',
    'ky' => 'kirgiz',
    'la' => 'latin',
    'lad' => 'ladino',
    'lag' => 'langi',
    'lah' => 'lahnda',
    'lam' => 'lamba',
    'lb' => 'luksembourgeg',
    'lez' => 'lezgi',
    'lfn' => 'lingua franca nova',
    'lg' => 'ganda',
    'li' => 'limbourgeg',
    'lij' => 'ligurieg',
    'lil' => 'lillooet',
    'lkt' => 'lakota',
    'ln' => 'lingala',
    'lo' => 'laoseg',
    'lol' => 'mongo',
    'lou' => 'kreoleg Louiziana',
    'loz' => 'lozi',
    'lrc' => 'loureg an Norzh',
    'lt' => 'lituaneg',
    'lu' => 'luba-katanga',
    'lua' => 'luba-lulua',
    'lui' => 'luiseno',
    'lun' => 'lunda',
    'luo' => 'luo',
    'lus' => 'lushai',
    'luy' => 'luyia',
    'lv' => 'latvieg',
    'lzh' => 'sinaeg lennegel',
    'mad' => 'madoureg',
    'mag' => 'magahi',
    'mai' => 'maithili',
    'mak' => 'makasar',
    'mas' => 'masai',
    'mdf' => 'moksha',
    'mdr' => 'mandar',
    'men' => 'mende',
    'mer' => 'meru',
    'mfe' => 'moriseg',
    'mg' => 'malgacheg',
    'mga' => 'krenniwerzhoneg',
    'mgh' => 'makhuwa-meetto',
    'mgo' => 'metaʼ',
    'mh' => 'marshall',
    'mi' => 'maori',
    'mic' => 'mikmakeg',
    'min' => 'minangkabau',
    'mk' => 'makedoneg',
    'ml' => 'malayalam',
    'mn' => 'mongoleg',
    'mnc' => 'manchou',
    'mni' => 'manipuri',
    'moe' => 'montagneg',
    'moh' => 'mohawk',
    'mos' => 'more',
    'mr' => 'marathi',
    'mrj' => 'marieg ar Cʼhornôg',
    'ms' => 'malayseg',
    'mt' => 'malteg',
    'mua' => 'moundangeg',
    'mul' => 'yezhoù lies',
    'mus' => 'muskogi',
    'mwl' => 'mirandeg',
    'my' => 'birmaneg',
    'myv' => 'erza',
    'mzn' => 'mazanderaneg',
    'na' => 'naurueg',
    'nan' => 'sinaeg Min Nan',
    'nap' => 'napolitaneg',
    'naq' => 'nama',
    'nb' => 'norvegeg bokmål',
    'nd' => 'ndebele an Norzh',
    'nds' => 'alamaneg izel',
    'nds_NL' => 'saksoneg izel',
    'ne' => 'nepaleg',
    'new' => 'newari',
    'ng' => 'ndonga',
    'nia' => 'nias',
    'niu' => 'niue',
    'njo' => 'aoeg',
    'nl' => 'nederlandeg',
    'nl_BE' => 'flandrezeg',
    'nmg' => 'ngoumbeg',
    'nn' => 'norvegeg nynorsk',
    'nnh' => 'ngiemboon',
    'no' => 'norvegeg',
    'nog' => 'nogay',
    'non' => 'hennorseg',
    'nov' => 'novial',
    'nqo' => 'nkoeg',
    'nr' => 'ndebele ar Su',
    'nso' => 'sotho an Norzh',
    'nus' => 'nouereg',
    'nv' => 'navacʼho',
    'nwc' => 'newari klasel',
    'ny' => 'nyanja',
    'nym' => 'nyamwezi',
    'nyn' => 'nyankole',
    'nyo' => 'nyoro',
    'oc' => 'okitaneg',
    'oj' => 'ojibweg',
    'ojb' => 'ojibweg ar Gwalarn',
    'ojc' => 'ojibweg ar cʼhreiz',
    'ojs' => 'ojibweg Severn',
    'ojw' => 'ojibweg ar Cʼhornôg',
    'oka' => 'okanaganeg',
    'om' => 'oromoeg',
    'or' => 'oriya',
    'os' => 'oseteg',
    'osa' => 'osage',
    'ota' => 'turkeg otoman',
    'pa' => 'punjabi',
    'pag' => 'pangasinan',
    'pal' => 'pahlavi',
    'pam' => 'pampanga',
    'pap' => 'papiamento',
    'pau' => 'palau',
    'pcd' => 'pikardeg',
    'pcm' => 'pidjin Nigeria',
    'pdc' => 'alamaneg Pennsylvania',
    'peo' => 'henberseg',
    'phn' => 'fenikianeg',
    'pi' => 'pali',
    'pis' => 'pidjin',
    'pl' => 'poloneg',
    'pms' => 'piemonteg',
    'pnt' => 'ponteg',
    'pon' => 'pohnpei',
    'pqm' => 'malisiteg-pasamawkodieg',
    'prg' => 'henbruseg',
    'pro' => 'henbrovañseg',
    'ps' => 'pachto',
    'pt' => 'portugaleg',
    'pt_BR' => 'portugaleg Brazil',
    'pt_PT' => 'portugaleg Europa',
    'qu' => 'kechuaeg',
    'quc' => 'kʼicheʼ',
    'qug' => 'kichuaeg Chimborazo',
    'raj' => 'rajasthani',
    'rap' => 'rapanui',
    'rar' => 'rarotonga',
    'rgn' => 'romagnoleg',
    'rhg' => 'rohingya',
    'rm' => 'romañcheg',
    'rn' => 'rundi',
    'ro' => 'roumaneg',
    'ro_MD' => 'moldoveg',
    'rof' => 'rombo',
    'rom' => 'romanieg',
    'ru' => 'rusianeg',
    'rup' => 'aroumaneg',
    'rw' => 'kinyarwanda',
    'rwk' => 'rwa',
    'sa' => 'sanskriteg',
    'sad' => 'sandawe',
    'sah' => 'yakouteg',
    'sam' => 'arameeg ar Samaritaned',
    'saq' => 'samburu',
    'sas' => 'sasak',
    'sat' => 'santali',
    'sba' => 'ngambayeg',
    'sbp' => 'sangu',
    'sc' => 'sardeg',
    'scn' => 'sikilieg',
    'sco' => 'skoteg',
    'sd' => 'sindhi',
    'sdc' => 'sasareseg',
    'se' => 'sámi an Norzh',
    'seh' => 'sena',
    'ses' => 'koyraboro senni',
    'sg' => 'sango',
    'sga' => 'heniwerzhoneg',
    'sh' => 'serb-kroateg',
    'shi' => 'tacheliteg',
    'shn' => 'shan',
    'shu' => 'arabeg Tchad',
    'si' => 'singhaleg',
    'sid' => 'sidamo',
    'sk' => 'slovakeg',
    'sl' => 'sloveneg',
    'slh' => 'luchoutsideg ar Su',
    'sm' => 'samoan',
    'sma' => 'sámi ar Su',
    'smj' => 'sámi Luleå',
    'smn' => 'sámi Inari',
    'sms' => 'sámi Skolt',
    'sn' => 'shona',
    'snk' => 'soninke',
    'so' => 'somali',
    'sog' => 'sogdieg',
    'sq' => 'albaneg',
    'sr' => 'serbeg',
    'srn' => 'sranan tongo',
    'srr' => 'serer',
    'ss' => 'swati',
    'ssy' => 'sahoeg',
    'st' => 'sotho ar Su',
    'su' => 'sundaneg',
    'suk' => 'sukuma',
    'sux' => 'sumereg',
    'sv' => 'svedeg',
    'sw' => 'swahili',
    'sw_CD' => 'swahili Kongo',
    'swb' => 'komoreg',
    'syc' => 'sirieg klasel',
    'syr' => 'sirieg',
    'szl' => 'silezieg',
    'ta' => 'tamileg',
    'tce' => 'tutchoneg ar Su',
    'tcy' => 'touloueg',
    'te' => 'telougou',
    'tem' => 'temne',
    'teo' => 'tesoeg',
    'ter' => 'tereno',
    'tet' => 'tetum',
    'tg' => 'tadjik',
    'th' => 'thai',
    'ti' => 'tigrigna',
    'tig' => 'tigreaneg',
    'tiv' => 'tiv',
    'tk' => 'turkmeneg',
    'tkl' => 'tokelau',
    'tl' => 'tagalog',
    'tlh' => 'klingon',
    'tli' => 'tinglit',
    'tmh' => 'tamacheg',
    'tn' => 'tswana',
    'to' => 'tonga',
    'tog' => 'nyasa tonga',
    'tok' => 'toki pona',
    'tpi' => 'tok pisin',
    'tr' => 'turkeg',
    'tru' => 'turoyoeg',
    'trv' => 'taroko',
    'ts' => 'tsonga',
    'tsi' => 'tsimshian',
    'tt' => 'tatar',
    'ttm' => 'tutchoneg an Norzh',
    'tum' => 'tumbuka',
    'tvl' => 'tuvalu',
    'tw' => 'twi',
    'twq' => 'tasawakeg',
    'ty' => 'tahitianeg',
    'tyv' => 'touva',
    'tzm' => 'tamazigteg Kreizatlas',
    'udm' => 'oudmourteg',
    'ug' => 'ouigoureg',
    'uga' => 'ougariteg',
    'uk' => 'ukraineg',
    'umb' => 'umbundu',
    'und' => 'yezh dianav',
    'ur' => 'ourdou',
    'uz' => 'ouzbekeg',
    'vai' => 'vai',
    've' => 'venda',
    'vec' => 'venezieg',
    'vep' => 'vepseg',
    'vi' => 'vietnameg',
    'vls' => 'flandrezeg ar c’hornôg',
    'vo' => 'volapük',
    'vot' => 'votyakeg',
    'vro' => 'voroeg',
    'vun' => 'vunjo',
    'wa' => 'walloneg',
    'wae' => 'walser',
    'wal' => 'walamo',
    'war' => 'waray',
    'was' => 'washo',
    'wo' => 'wolof',
    'wuu' => 'sinaeg Wu',
    'xal' => 'kalmouk',
    'xh' => 'xhosa',
    'xmf' => 'megreleg',
    'xog' => 'sogaeg',
    'yao' => 'yao',
    'yap' => 'yapeg',
    'yav' => 'yangben',
    'ybb' => 'yemba',
    'yi' => 'yiddish',
    'yo' => 'yorouba',
    'yrl' => 'nengatoueg',
    'yue' => 'kantoneg',
    'yue@alt=menu' => 'sinaeg, kantoneg',
    'za' => 'zhuang',
    'zap' => 'zapoteg',
    'zbl' => 'arouezioù Bliss',
    'zea' => 'zelandeg',
    'zen' => 'zenaga',
    'zgh' => 'tamacheg Maroko standart',
    'zh' => 'sinaeg',
    'zh@alt=menu' => 'sinaeg, mandarineg',
    'zh_Hans' => 'sinaeg eeunaet',
    'zh_Hans@alt=long' => 'sinaeg mandarinek eeunaet',
    'zh_Hant' => 'sinaeg hengounel',
    'zh_Hant@alt=long' => 'sinaeg mandarinek hengounel',
    'zu' => 'zouloueg',
    'zun' => 'zuni',
    'zxx' => 'diyezh',
    'zza' => 'zazakeg',
};

is_deeply($locale->all_languages, $all_languages, 'All languages');

is($locale->script_name(), '', 'Script name from current locale');
is($locale->script_name('latn'), 'latin', 'Script name from string');
is($locale->script_name($other_locale), '', 'Script name from other locale object');

my $all_scripts = {
	'Adlm' => 'adlam',
    'Arab' => 'arabek',
    'Armi' => 'arameek impalaerel',
    'Armn' => 'armenianek',
    'Avst' => 'avestek',
    'Bali' => 'balinek',
	'Batk' => 'batak',
	'Bamu' => 'bamounek',
    'Beng' => 'bengali',
    'Bopo' => 'bopomofo',
    'Brai' => 'Braille',
    'Bugi' => 'bougiek',
	'Cakm' => 'chakmaek',
	'Cans' => 'silabennaoueg engenidik unvan Kanada',
	'Cham' => 'cham',
	'Cher' => 'cherokee',
    'Copt' => 'koptek',
	'Cprt' => 'silabennaoueg kipriek',
    'Cyrl' => 'kirillek',
    'Cyrs' => 'kirillek henslavonek',
    'Deva' => 'devanagari',
	'Dupl' => 'berrskriverezh Duployé',
    'Egyp' => 'hieroglifoù egiptek',
    'Ethi' => 'etiopek',
    'Geor' => 'jorjianek',
    'Glag' => 'glagolitek',
    'Goth' => 'gotek',
    'Grek' => 'gresianek',
    'Gujr' => 'gujarati',
    'Guru' => 'gurmukhi',
	'Hanb' => 'han gant bopomofo',
    'Hang' => 'hangeul',
    'Hani' => 'sinalunioù (han)',
    'Hans' => 'eeunaet',
    'Hans@alt=stand-alone' => 'sinalunioù (han) eeunaet',
    'Hant' => 'hengounel',
    'Hant@alt=stand-alone' => 'sinalunioù (han) hengounel',
    'Hebr' => 'hebraek',
    'Hira' => 'hiragana',
    'Hluw' => 'hieroglifoù Anatolia',
	'Hrkt' => 'silabennaouegoù japanek',
	'Hung' => 'henhungarek',
    'Ital' => 'henitalek',
	'Jamo' => 'jamo',
    'Java' => 'javanek',
    'Jpan' => 'japanek',
    'Kana' => 'katakana',
    'Khmr' => 'khmer',
    'Knda' => 'kannada',
    'Kore' => 'koreanek',
    'Laoo' => 'laosek',
    'Latg' => 'latin gouezelek',
    'Latn' => 'latin',
	'Lyci' => 'likiek',
	'Lydi' => 'lidiek',
	'Mani' => 'manikeek',
    'Maya' => 'hieroglifoù mayaek',
    'Mlym' => 'malayalam',
    'Mong' => 'mongolek',
    'Mymr' => 'myanmar',
	'Narb' => 'henarabek an Norzh',
    'Ogam' => 'ogam',
    'Orya' => 'oriya',
	'Phnx' => 'fenikianek',
    'Runr' => 'runek',
	'Samr' => 'samaritek',
	'Sarb' => 'henarabek ar Su',
    'Sinh' => 'singhalek',
    'Sund' => 'sundanek',
    'Syrc' => 'siriek',
    'Syre' => 'siriek Estrangelā',
    'Syrj' => 'siriek ar C’hornôg',
    'Syrn' => 'siriek ar Reter',
    'Taml' => 'tamilek',
    'Telu' => 'telougou',
    'Tglg' => 'tagalog',
    'Thaa' => 'thaana',
    'Thai' => 'thai',
    'Tibt' => 'tibetanek',
    'Ugar' => 'ougaritek',
    'Vaii' => 'vai',
    'Xpeo' => 'persek kozh',
	'Xsux' => 'gennheñvel',
	'Zinh' => 'hêrezh',
    'Zmth' => 'notadur jedoniel',
	'Zsye' => 'fromlunioù',
    'Zsym' => 'arouezioù',
    'Zxxx' => 'anskrivet',
    'Zyyy' => 'boutin',
    'Zzzz' => 'skritur dianav',
};

is_deeply($locale->all_scripts, $all_scripts, 'All scripts');

is($locale->region_name(), 'Frañs', 'Region name from current locale');
is($locale->region_name('en_US'), 'Rannved dianav', 'Region name from string');
is($locale->region_name($other_locale), 'Stadoù-Unanet', 'Region name from other locale object');

my $all_regions = {
	'001' => 'Bed',
	'002' => 'Afrika',
	'003' => 'Norzhamerika',
	'005' => 'Suamerika',
	'009' => 'Oseania',
	'011' => 'Afrika ar Cʼhornôg',
	'013' => 'Kreizamerika',
	'014' => 'Afrika ar Reter',
	'015' => 'Afrika an Norzh',
	'017' => 'Afrika ar Cʼhreiz',
	'018' => 'Afrika ar Su',
	'019' => 'Amerikaoù',
	'021' => 'Amerika an Norzh',
	'029' => 'Karib',
	'030' => 'Azia ar Reter',
	'034' => 'Azia ar Su',
	'035' => 'Azia ar Gevred',
	'039' => 'Europa ar Su',
	'053' => 'Aostralazia',
	'054' => 'Melanezia',
	'057' => 'Rannved Mikronezia',
	'061' => 'Polinezia',
	'142' => 'Azia',
	'143' => 'Azia ar Cʼhreiz',
	'145' => 'Azia ar Cʼhornôg',
	'150' => 'Europa',
	'151' => 'Europa ar Reter',
	'154' => 'Europa an Norzh',
	'155' => 'Europa ar Cʼhornôg',
	'202' => 'Afrika issaharat',
	'419' => 'Amerika Latin',
	'AC' => 'Enez Ascension',
	'AD' => 'Andorra',
	'AE' => 'Emirelezhioù Arab Unanet',
	'AF' => 'Afghanistan',
	'AG' => 'Antigua ha Barbuda',
	'AI' => 'Anguilla',
	'AL' => 'Albania',
	'AM' => 'Armenia',
	'AO' => 'Angola',
	'AQ' => 'Antarktika',
	'AR' => 'Arcʼhantina',
	'AS' => 'Samoa Amerikan',
	'AT' => 'Aostria',
	'AU' => 'Aostralia',
	'AW' => 'Aruba',
	'AX' => 'Inizi Åland',
	'AZ' => 'Azerbaidjan',
	'BA' => 'Bosnia ha Herzegovina',
	'BB' => 'Barbados',
	'BD' => 'Bangladesh',
	'BE' => 'Belgia',
	'BF' => 'Burkina Faso',
	'BG' => 'Bulgaria',
	'BH' => 'Bahrein',
	'BI' => 'Burundi',
	'BJ' => 'Benin',
	'BL' => 'Saint Barthélemy',
	'BM' => 'Bermuda',
	'BN' => 'Brunei',
	'BO' => 'Bolivia',
	'BQ' => 'Karib Nederlandat',
	'BR' => 'Brazil',
	'BS' => 'Bahamas',
	'BT' => 'Bhoutan',
	'BV' => 'Enez Bouvet',
	'BW' => 'Botswana',
	'BY' => 'Belarus',
	'BZ' => 'Belize',
	'CA' => 'Kanada',
	'CC' => 'Inizi Kokoz',
	'CD' => 'Kongo - Kinshasa',
	'CD@alt=variant' => 'Kongo (RDK)',
	'CF' => 'Republik Kreizafrikan',
	'CG' => 'Kongo - Brazzaville',
	'CG@alt=variant' => 'Kongo (Republik)',
	'CH' => 'Suis',
	'CI' => 'Aod an Olifant',
	'CI@alt=variant' => 'Aod Olifant',
	'CK' => 'Inizi Cook',
	'CL' => 'Chile',
	'CM' => 'Kameroun',
	'CN' => 'Sina',
	'CO' => 'Kolombia',
	'CP' => 'Enez Clipperton',
	'CR' => 'Costa Rica',
	'CU' => 'Kuba',
	'CV' => 'Kab-Glas',
	'CW' => 'Curaçao',
	'CX' => 'Enez Christmas',
	'CY' => 'Kiprenez',
	'CZ' => 'Tchekia',
	'CZ@alt=variant' => 'Republik Tchek',
	'DE' => 'Alamagn',
	'DG' => 'Diego Garcia',
	'DJ' => 'Djibouti',
	'DK' => 'Danmark',
	'DM' => 'Dominica',
	'DO' => 'Republik Dominikan',
	'DZ' => 'Aljeria',
	'EA' => 'Ceuta ha Melilla',
	'EC' => 'Ecuador',
	'EE' => 'Estonia',
	'EG' => 'Egipt',
	'EH' => 'Sahara ar Cʼhornôg',
	'ER' => 'Eritrea',
	'ES' => 'Spagn',
	'ET' => 'Etiopia',
	'EU' => 'Unaniezh Europa',
	'EZ' => 'takad an euro',
	'FI' => 'Finland',
	'FJ' => 'Fidji',
	'FK' => 'Inizi Falkland',
	'FK@alt=variant' => 'Inizi Falkland (Inizi Maloù)',
	'FM' => 'Mikronezia',
	'FO' => 'Inizi Faero',
	'FR' => 'Frañs',
	'GA' => 'Gabon',
	'GB' => 'Rouantelezh-Unanet',
	'GB@alt=short' => 'RU',
	'GD' => 'Grenada',
	'GE' => 'Jorjia',
	'GF' => 'Gwiana cʼhall',
	'GG' => 'Gwernenez',
	'GH' => 'Ghana',
	'GI' => 'Jibraltar',
	'GL' => 'Greunland',
	'GM' => 'Gambia',
	'GN' => 'Ginea',
	'GP' => 'Gwadeloup',
	'GQ' => 'Ginea ar Cʼheheder',
	'GR' => 'Gres',
	'GS' => 'Inizi Georgia ar Su hag Inizi Sandwich ar Su',
	'GT' => 'Guatemala',
	'GU' => 'Guam',
	'GW' => 'Ginea-Bissau',
	'GY' => 'Guyana',
	'HK' => 'Hong Kong RMD Sina',
	'HK@alt=short' => 'Hong Kong',
	'HM' => 'Inizi Heard ha McDonald',
	'HN' => 'Honduras',
	'HR' => 'Kroatia',
	'HT' => 'Haiti',
	'HU' => 'Hungaria',
	'IC' => 'Inizi Kanariez',
	'ID' => 'Indonezia',
	'IE' => 'Iwerzhon',
	'IL' => 'Israel',
	'IM' => 'Enez Vanav',
	'IN' => 'India',
	'IO' => 'Tiriad breizhveurat Meurvor Indez',
	'IQ' => 'Iraq',
	'IR' => 'Iran',
	'IS' => 'Island',
	'IT' => 'Italia',
	'JE' => 'Jerzenez',
	'JM' => 'Jamaika',
	'JO' => 'Jordania',
	'JP' => 'Japan',
	'KE' => 'Kenya',
	'KG' => 'Kyrgyzstan',
	'KH' => 'Kambodja',
	'KI' => 'Kiribati',
	'KM' => 'Komorez',
	'KN' => 'Saint Kitts ha Nevis',
	'KP' => 'Korea an Norzh',
	'KR' => 'Korea ar Su',
	'KW' => 'Koweit',
	'KY' => 'Inizi Cayman',
	'KZ' => 'Kazakstan',
	'LA' => 'Laos',
	'LB' => 'Liban',
	'LC' => 'Saint Lucia',
	'LI' => 'Liechtenstein',
	'LK' => 'Sri Lanka',
	'LR' => 'Liberia',
	'LS' => 'Lesotho',
	'LT' => 'Lituania',
	'LU' => 'Luksembourg',
	'LV' => 'Latvia',
	'LY' => 'Libia',
	'MA' => 'Maroko',
	'MC' => 'Monaco',
	'MD' => 'Moldova',
	'ME' => 'Montenegro',
	'MF' => 'Saint Martin',
	'MG' => 'Madagaskar',
	'MH' => 'Inizi Marshall',
	'MK' => 'Makedonia an Norzh',
	'ML' => 'Mali',
	'MM' => 'Myanmar (Birmania)',
	'MN' => 'Mongolia',
	'MO' => 'Macau RMD Sina',
	'MO@alt=short' => 'Macau',
	'MP' => 'Inizi Mariana an Norzh',
	'MQ' => 'Martinik',
	'MR' => 'Maouritania',
	'MS' => 'Montserrat',
	'MT' => 'Malta',
	'MU' => 'Moris',
	'MV' => 'Maldivez',
	'MW' => 'Malawi',
	'MX' => 'Mecʼhiko',
	'MY' => 'Malaysia',
	'MZ' => 'Mozambik',
	'NA' => 'Namibia',
	'NC' => 'Kaledonia Nevez',
	'NE' => 'Niger',
	'NF' => 'Enez Norfolk',
	'NG' => 'Nigeria',
	'NI' => 'Nicaragua',
	'NL' => 'Izelvroioù',
	'NO' => 'Norvegia',
	'NP' => 'Nepal',
	'NR' => 'Nauru',
	'NU' => 'Niue',
	'NZ' => 'Zeland-Nevez',
    'NZ@alt=variant' => 'Aotearoa Zeland-Nevez',
	'OM' => 'Oman',
	'PA' => 'Panamá',
	'PE' => 'Perou',
	'PF' => 'Polinezia Cʼhall',
	'PG' => 'Papoua Ginea-Nevez',
	'PH' => 'Filipinez',
	'PK' => 'Pakistan',
	'PL' => 'Polonia',
	'PM' => 'Sant-Pêr-ha-Mikelon',
	'PN' => 'Enez Pitcairn',
	'PR' => 'Puerto Rico',
	'PS' => 'Tiriadoù Palestina',
	'PS@alt=short' => 'Palestina',
	'PT' => 'Portugal',
	'PW' => 'Palau',
	'PY' => 'Paraguay',
	'QA' => 'Qatar',
	'QO' => 'Oseania diabell',
	'RE' => 'Ar Reünion',
	'RO' => 'Roumania',
	'RS' => 'Serbia',
	'RU' => 'Rusia',
	'RW' => 'Rwanda',
	'SA' => 'Arabia Saoudat',
	'SB' => 'Inizi Salomon',
	'SC' => 'Sechelez',
	'SD' => 'Soudan',
	'SE' => 'Sveden',
	'SG' => 'Singapour',
	'SH' => 'Saint-Helena',
	'SI' => 'Slovenia',
	'SJ' => 'Svalbard',
	'SK' => 'Slovakia',
	'SL' => 'Sierra Leone',
	'SM' => 'San Marino',
	'SN' => 'Senegal',
	'SO' => 'Somalia',
	'SR' => 'Surinam',
	'SS' => 'Susoudan',
	'ST' => 'São Tomé ha Príncipe',
	'SV' => 'Salvador',
	'SX' => 'Sint Maarten',
	'SY' => 'Siria',
	'SZ' => 'Eswatini',
	'SZ@alt=variant' => 'Swaziland',
	'TA' => 'Tristan da Cunha',
	'TC' => 'Inizi Turks ha Caicos',
	'TD' => 'Tchad',
	'TF' => 'Douaroù aostral Frañs',
	'TG' => 'Togo',
	'TH' => 'Thailand',
	'TJ' => 'Tadjikistan',
	'TK' => 'Tokelau',
	'TL' => 'Timor-Leste',
	'TL@alt=variant' => 'Timor ar Reter',
	'TM' => 'Turkmenistan',
	'TN' => 'Tunizia',
	'TO' => 'Tonga',
	'TR' => 'Turkia',
	'TT' => 'Trinidad ha Tobago',
	'TV' => 'Tuvalu',
	'TW' => 'Taiwan',
	'TZ' => 'Tanzania',
	'UA' => 'Ukraina',
	'UG' => 'Ouganda',
	'UM' => 'Inizi diabell ar Stadoù-Unanet',
	'UN' => 'Broadoù unanet',
	'US' => 'Stadoù-Unanet',
	'US@alt=short' => 'SU',
	'UY' => 'Uruguay',
	'UZ' => 'Ouzbekistan',
	'VA' => 'Vatikan',
	'VC' => 'Sant Visant hag ar Grenadinez',
	'VE' => 'Venezuela',
	'VG' => 'Inizi Gwercʼh Breizh-Veur',
	'VI' => 'Inizi Gwercʼh ar Stadoù-Unanet',
	'VN' => 'Viêt Nam',
	'VU' => 'Vanuatu',
	'WF' => 'Wallis ha Futuna',
	'WS' => 'Samoa',
	'XA' => 'pouez-mouezh gaou',
	'XB' => 'BiDi gaou',
	'XK' => 'Kosovo',
	'YE' => 'Yemen',
	'YT' => 'Mayotte',
	'ZA' => 'Suafrika',
	'ZM' => 'Zambia',
	'ZW' => 'Zimbabwe',
	'ZZ' => 'Rannved dianav',
};

is_deeply($locale->all_regions(), $all_regions, 'All regions');

is($locale->variant_name(), '', 'Variant name from current locale');
is($locale->variant_name('JYUTPING'), 'romanekadur kantonek Jyutping', 'Variant name from string');
is($locale->variant_name($other_locale), '', 'Variant name from other locale object');

is($locale->key_name('collation'), 'doare rummañ', 'Key name from string');

is($locale->type_name(collation => 'standard'), 'urzh rummañ standart', 'Type name from string');

is($locale->measurement_system_name('metric'), 'metrek', 'Measurement system name English Metric');
is($locale->measurement_system_name('us'), 'SU', 'Measurement system name English US');
is($locale->measurement_system_name('uk'), 'RU', 'Measurement system name English UK');

is($locale->transform_name('Numeric'), '', 'Transform name from string');