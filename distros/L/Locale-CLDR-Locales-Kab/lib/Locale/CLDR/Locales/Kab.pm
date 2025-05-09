=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Kab - Package for language Kabyle

=cut

package Locale::CLDR::Locales::Kab;
# This file auto generated from Data\common\main\kab.xml
#	on Fri 17 Jan 12:03:31 pm GMT

use strict;
use warnings;
use version;

our $VERSION = version->declare('v0.46.0');

use v5.12.0;
use mro 'c3';
use utf8;
use feature 'unicode_strings';
use Types::Standard qw( Str Int HashRef ArrayRef CodeRef RegexpRef );
use Moo;

extends('Locale::CLDR::Locales::Root');
has 'display_name_language' => (
	is			=> 'ro',
	isa			=> CodeRef,
	init_arg	=> undef,
	default		=> sub {
		 sub {
			 my %languages = (
				'aa' => 'Tafarit',
 				'ab' => 'Tabxazit',
 				'ace' => 'Tačinist',
 				'ada' => 'Tadanegmit',
 				'ady' => 'Tadiganit',
 				'af' => 'Tafrikant',
 				'agq' => 'Taghemit',
 				'ain' => 'Taynut',
 				'ak' => 'Takanit',
 				'ale' => 'Taliyut',
 				'alt' => 'Talṭayt n unẓul',
 				'am' => 'Tamahrict',
 				'an' => 'Taṛagunit',
 				'anp' => 'Tangikat',
 				'ar' => 'Taɛrabt',
 				'ar_001' => 'Taɛrabt tamezdayt tatrart',
 				'arn' => 'Tamapuct',
 				'arp' => 'Taṛapahut',
 				'as' => 'Tasamizt',
 				'asa' => 'Tasut',
 				'ast' => 'Tasturit',
 				'atj' => 'Tatikamkawt',
 				'av' => 'Tavarikt',
 				'awa' => 'Tawadhit',
 				'ay' => 'Taymarit',
 				'az' => 'Tazerbayǧant',
 				'az@alt=short' => 'Tazrit',
 				'ba' => 'Tabackirt',
 				'ban' => 'Tabalinit',
 				'bas' => 'Tabasat',
 				'be' => 'Tabilarusit',
 				'bem' => 'Tabimbat',
 				'bez' => 'Tabinat',
 				'bg' => 'Tabulgarit',
 				'bho' => 'Tabujpurit',
 				'bi' => 'Tabislamat',
 				'bin' => 'Tabinit',
 				'bla' => 'Tasiksikat',
 				'bm' => 'Tabambarat',
 				'bn' => 'Tabengalit',
 				'bo' => 'Tatibitant',
 				'br' => 'Tabrutunt',
 				'brx' => 'Tabudut',
 				'bs' => 'Tabusnit',
 				'bug' => 'Tabujinit',
 				'byn' => 'Tablint',
 				'ca' => 'Takaṭalant',
 				'cay' => 'Takayugat',
 				'ccp' => 'Tacakmat',
 				'ce' => 'Tačičinit',
 				'ceb' => 'Tacibwanit',
 				'cgg' => 'Tacigat',
 				'ch' => 'Tacamuṛut',
 				'chk' => 'Tačukizt',
 				'chm' => 'Tamarit',
 				'cho' => 'Tacuktawt',
 				'chr' => 'Tacirukit',
 				'chy' => 'Taciyant',
 				'ckb' => 'Takurdit Talemmast',
 				'clc' => 'Tacilkuṭint',
 				'co' => 'Takuṛsit',
 				'crs' => 'Takriyult n Saycal',
 				'cs' => 'Tačikit',
 				'cu' => 'Taslavt n tmezgida',
 				'cv' => 'Tačubact',
 				'cy' => 'Takusit',
 				'da' => 'Tadanit',
 				'dak' => 'Tadakutat',
 				'dar' => 'Tadargwat',
 				'dav' => 'Tataytat',
 				'de' => 'Talmant',
 				'de_AT' => 'Talmanit n Ustriya',
 				'de_CH' => 'Talmanit n Swis',
 				'dgr' => 'Tadugribt',
 				'dje' => 'Tazarmat',
 				'doi' => 'Tadugrit',
 				'dsb' => 'Taṣurbyant n wadda',
 				'dua' => 'Tadwalat',
 				'dv' => 'Tamaldivit',
 				'dyo' => 'Jula-Funyi',
 				'dz' => 'Tadzungat',
 				'dzg' => 'Tadazagat',
 				'ebu' => 'Tumbut',
 				'ee' => 'Tiwit',
 				'efi' => 'Tafikt',
 				'eka' => 'Takajukt',
 				'el' => 'Tagrikit',
 				'en' => 'Taglizit',
 				'en_AU' => 'Taglizit n Ustralya',
 				'en_CA' => 'Taglizit n Kanada',
 				'en_GB' => 'Taglizit n Briṭanya',
 				'en_GB@alt=short' => 'Taglizit n Tgelda Yedduklen',
 				'en_US' => 'Taglizit n Marikan',
 				'en_US@alt=short' => 'Taglizit n US',
 				'eo' => 'Taspirantit',
 				'es' => 'Taspenyulit',
 				'es_419' => 'Taspenyulit n Temrikt Talaṭinit',
 				'es_ES' => 'Taspenyulit n Turuft',
 				'es_MX' => 'Taspenyulit n Miksik',
 				'et' => 'Tasṭunit',
 				'eu' => 'Tabaskit',
 				'ewo' => 'Tawundut',
 				'fa' => 'Tafarisit',
 				'ff' => 'Tafulaht',
 				'fi' => 'Tafinit',
 				'fil' => 'Tafilipant',
 				'fj' => 'Tafiǧit',
 				'fo' => 'Tafirwanit',
 				'fon' => 'Tafunit',
 				'fr' => 'Tafransist',
 				'fr_CA' => 'Tafransist n Kanada',
 				'fr_CH' => 'Tafransist n Swis',
 				'frc' => 'Tafransist takadit',
 				'fur' => 'Tafriyulant',
 				'fy' => 'Tafrizunt n umalu',
 				'ga' => 'Tirlandit',
 				'gaa' => 'Tagat',
 				'gd' => 'Tagaylikt n Skuṭland',
 				'gez' => 'Tagizit',
 				'gil' => 'Tajibṛaltart',
 				'gl' => 'Tagalisit',
 				'gn' => 'Tagaranit',
 				'gor' => 'Taguruntalut',
 				'gsw' => 'Talmanit n Swiss',
 				'gu' => 'Taguǧaṛatit',
 				'guz' => 'Tagusit',
 				'gv' => 'Tamanksit',
 				'gwi' => 'Tagwičint',
 				'ha' => 'Tahwasit',
 				'hai' => 'Hayda',
 				'haw' => 'Tahawayt',
 				'he' => 'Taɛebrit',
 				'hi' => 'Tahendit',
 				'hil' => 'Tahiligaynunt',
 				'hmn' => 'Tahmungt',
 				'hr' => 'Takeṛwasit',
 				'hsb' => 'Tasirbit n ufella',
 				'ht' => 'Takriyult n Hayti',
 				'hu' => 'Tahungarit',
 				'hup' => 'Tahupat',
 				'hy' => 'Taṛminit',
 				'hz' => 'Tahiriṛut',
 				'ia' => 'Tutlayt tagraɣlant',
 				'iba' => 'Tibant',
 				'ibb' => 'Tabibyut',
 				'id' => 'Tandunisit',
 				'ig' => 'Tigbut',
 				'ii' => 'Yi-n-Sicwan',
 				'ilo' => 'Tilukanut',
 				'inh' => 'Tinguct',
 				'io' => 'Tidut',
 				'is' => 'Taṣlandit',
 				'it' => 'Taṭalyanit',
 				'iu' => 'Tinuktitut',
 				'ja' => 'Tajapunit',
 				'jbo' => 'Talujbant',
 				'jgo' => 'Tangumbat',
 				'jmc' => 'Tamačamit',
 				'jv' => 'Tajavanit',
 				'ka' => 'Tajyurjit',
 				'kab' => 'Taqbaylit',
 				'kac' => 'Takacint',
 				'kaj' => 'Tajjut',
 				'kam' => 'Takambat',
 				'kbd' => 'Takabardint',
 				'kcg' => 'Tatyapt',
 				'kde' => 'Tamakundit',
 				'kea' => 'Takapverdit',
 				'kfo' => 'Takurut',
 				'kha' => 'Taxasit',
 				'khq' => 'koyra chiini',
 				'ki' => 'Takikuyut',
 				'kj' => 'Takwanyamat',
 				'kk' => 'Takazaxt',
 				'kkj' => 'Takakut',
 				'kl' => 'Tagrinlandit',
 				'kln' => 'Takalinjint',
 				'km' => 'Takemrit',
 				'kmb' => 'Takimbundut',
 				'kn' => 'Takannadat',
 				'ko' => 'Takurit',
 				'kok' => 'Takunkanit',
 				'kpe' => 'Takpilit',
 				'kr' => 'Takanurit',
 				'krc' => 'Takaračayt Tabalkart',
 				'krl' => 'Takarilyant',
 				'kru' => 'Takuruxt',
 				'ks' => 'Takacmirit',
 				'ksb' => 'Tacambalat',
 				'ksf' => 'Tabafyat',
 				'ksh' => 'Takulunyant',
 				'ku' => 'Takurdit',
 				'kum' => 'Takumyakt',
 				'kv' => 'Taklingunit',
 				'kw' => 'Takurnikt',
 				'ky' => 'Takirgizt',
 				'la' => 'Talaṭinit',
 				'lad' => 'Taladinut',
 				'lag' => 'Talangit',
 				'lb' => 'Taluksumburgit',
 				'lez' => 'Talezɣant',
 				'lg' => 'Tagandat',
 				'li' => 'Talimburjwat',
 				'lkt' => 'Talakutat',
 				'ln' => 'Talingalat',
 				'lo' => 'Talawsit',
 				'loz' => 'Taluzit',
 				'lrc' => 'Talurit n ugafa',
 				'lt' => 'Talitwanit',
 				'lu' => 'Talubit-Takatangit',
 				'lua' => 'Talubat n Lulua',
 				'lun' => 'Talundat',
 				'luo' => 'Taluwut',
 				'lus' => 'Talucayt',
 				'luy' => 'Taluhyat',
 				'lv' => 'Talitunit',
 				'mad' => 'Tamadurizt',
 				'mag' => 'Tamagahit',
 				'mai' => 'Tamaytilit',
 				'mak' => 'Tamakassart',
 				'mas' => 'Tamassayt',
 				'mdf' => 'Tamuksat',
 				'men' => 'Tamandit',
 				'mer' => 'Tamirut',
 				'mfe' => 'Takriyult n Muris',
 				'mg' => 'Tamalgact',
 				'mgh' => 'Makhuwa-meetto',
 				'mgo' => 'Tamitat',
 				'mh' => 'Tamaṛcalit',
 				'mi' => 'Tamawrit',
 				'mic' => 'Tamikmakt',
 				'min' => 'Taminangkabut',
 				'mk' => 'Tamasidunit',
 				'ml' => 'Tamalayalamit',
 				'mn' => 'Tamungulit',
 				'mni' => 'Tamanipurit',
 				'moh' => 'Tamuhawkt',
 				'mos' => 'Tamurit',
 				'mr' => 'Tamaṛatit',
 				'ms' => 'Tamalawit',
 				'mt' => 'Tamalṭit',
 				'mua' => 'Tamundangt',
 				'mul' => 'Tugett n tutlayin',
 				'mus' => 'Takrikt',
 				'mwl' => 'Tamirandit',
 				'my' => 'Taburmisit',
 				'myv' => 'Tirzyat',
 				'mzn' => 'Tamazandiranit',
 				'na' => 'Tanurwant',
 				'nap' => 'Tanapolitant',
 				'naq' => 'Tanamat',
 				'nb' => 'Tanurvijit Bukmal',
 				'nd' => 'Tandibilit n Ugafa',
 				'ne' => 'Tanipalit',
 				'new' => 'Taniwarit',
 				'ng' => 'Tandungat',
 				'nia' => 'Tanizt',
 				'niu' => 'Tanyunit',
 				'nl' => 'Tadučit',
 				'nl_BE' => 'Taflamant',
 				'nmg' => 'Takwazyut',
 				'nn' => 'Tanuṛvijt ninuṛsk',
 				'nnh' => 'Tangimbunt',
 				'no' => 'Tanuṛvijit',
 				'nog' => 'Tanugayt',
 				'nqo' => 'Tankut',
 				'nr' => 'Tandibilit n unzul',
 				'nso' => 'Talizutut n ugafa',
 				'nus' => 'Tanyurt',
 				'nv' => 'Tanavahut',
 				'ny' => 'Tanyanjat',
 				'nyn' => 'Tanyankulit',
 				'oc' => 'Tuksitant',
 				'ojc' => 'Tujibwat talemmast',
 				'om' => 'Turumut',
 				'or' => 'Turyat',
 				'os' => 'Tusitit',
 				'pa' => 'Tapunjabit',
 				'pag' => 'Tapangazinant',
 				'pam' => 'Tapampangant',
 				'pap' => 'Tapapyamintut',
 				'pau' => 'Tapalut',
 				'pcm' => 'Tapidgint n Nijirya',
 				'pl' => 'Tapulunit',
 				'prg' => 'Taprusit',
 				'ps' => 'Tapactut',
 				'pt' => 'Tapurtugalit',
 				'pt_BR' => 'Tapurtugalit n Brizil',
 				'pt_PT' => 'Tapurtugalit n Purtugal',
 				'qu' => 'Takicwit',
 				'quc' => 'Takict',
 				'rap' => 'Tarapanwit',
 				'rar' => 'Tararutungant',
 				'rm' => 'Tarumancit',
 				'rn' => 'Tarundit',
 				'ro' => 'Tarumanit',
 				'ro_MD' => 'Tamuldavt',
 				'rof' => 'Tarumbut',
 				'ru' => 'Tarusit',
 				'rup' => 'Tavalakt',
 				'rw' => 'Taruwandit',
 				'rwk' => 'Tarwat',
 				'sa' => 'Tasanskrit',
 				'sad' => 'Tasandawit',
 				'sah' => 'Tayakut',
 				'saq' => 'Tasamburut',
 				'sat' => 'Tasantalt',
 				'sba' => 'Tangambayt',
 				'sbp' => 'Tasangut',
 				'sc' => 'Tasardinit',
 				'scn' => 'Tasisilit',
 				'sco' => 'Taskutlandit',
 				'sd' => 'Tasinḍit',
 				'se' => 'Tasamt n ugafa',
 				'seh' => 'Tasisinat',
 				'ses' => 'Takuyraburut n Senni',
 				'sg' => 'Tasangit',
 				'shi' => 'Tacelḥit',
 				'shn' => 'Tacant',
 				'si' => 'Tasinhalit',
 				'sk' => 'Tasluvakt',
 				'sl' => 'Tasluvinit',
 				'sm' => 'Taṣamwant',
 				'sma' => 'Tasamit n unzul',
 				'smj' => 'Tasamit n Lule',
 				'smn' => 'Tasami n Inari',
 				'sms' => 'Tasamit n Skolt',
 				'sn' => 'Tacunit',
 				'snk' => 'Tasunikit',
 				'so' => 'Taṣumalit',
 				'sq' => 'Talbanit',
 				'sr' => 'Taṣirbit',
 				'srn' => 'Tasranant n Tongo',
 				'ss' => 'Taswatit',
 				'ssy' => 'Tasahut',
 				'st' => 'Talizutut n Unzul',
 				'su' => 'Tasudanit',
 				'suk' => 'Tasukumat',
 				'sv' => 'Taswidit',
 				'sw' => 'Taswayilit',
 				'sw_CD' => 'Taswayilit n Kungu',
 				'swb' => 'Takumurit',
 				'syr' => 'Tasiryakt',
 				'ta' => 'Taṭamulit',
 				'te' => 'Taluggut',
 				'tem' => 'Tatimnit',
 				'teo' => 'Tatizut',
 				'tet' => 'Tatitumt',
 				'tg' => 'Tatajikt',
 				'th' => 'Taṭaylundit',
 				'ti' => 'Tigrinit',
 				'tig' => 'Tatigrit',
 				'tk' => 'Taturkmant',
 				'tlh' => 'Taklingunt',
 				'tn' => 'Tattwanit',
 				'to' => 'Tatungant',
 				'tpi' => 'Tatukt n Pisin',
 				'tr' => 'Taṭurkit',
 				'trv' => 'Tatarukut',
 				'ts' => 'Ttunga',
 				'tt' => 'Taṭaṭarit',
 				'tum' => 'Tatumbukat',
 				'tvl' => 'Tatuvalut',
 				'twq' => 'Tatasawaqt',
 				'ty' => 'Tahesiant',
 				'tyv' => 'Tatuvat',
 				'tzm' => 'Tamaziɣt n Waṭlas alemmas',
 				'udm' => 'Tudmurt',
 				'ug' => 'Tawigurt',
 				'uk' => 'Tukranit',
 				'umb' => 'Tumbundut',
 				'und' => 'Tutlayt tarussint',
 				'ur' => 'Turdut',
 				'uz' => 'Tuzbikt',
 				'vai' => 'Tavayt',
 				've' => 'Tavendat',
 				'vi' => 'Tabyiṭnamit',
 				'vo' => 'Tavulapukt',
 				'vun' => 'Tavunjut',
 				'wa' => 'Tawalunit',
 				'wae' => 'Tawalsirt',
 				'wal' => 'Tawalamut',
 				'war' => 'Tawarayt',
 				'wo' => 'Tawuluft',
 				'xal' => 'Takalmukt',
 				'xh' => 'Taksuzit',
 				'xog' => 'Tasugat',
 				'yav' => 'Tayangbent',
 				'ybb' => 'Yemba',
 				'yi' => 'Tayiddict',
 				'yo' => 'Tayurubit',
 				'yue' => 'Takantunit',
 				'yue@alt=menu' => 'Tacinwat, Takantunit',
 				'zgh' => 'Tamaziɣt Tizeɣt Tamerrukit',
 				'zh' => 'Tacinwat, Tamundarint',
 				'zh_Hans' => 'Tacinwat taḥerfit',
 				'zh_Hans@alt=long' => 'Tacinwat tamundarint taḥerfit',
 				'zh_Hant' => 'Tacinwat tamensayt',
 				'zh_Hant@alt=long' => 'Tacinwat tamundarint tamensayt',
 				'zu' => 'Tazulut',
 				'zun' => 'Tazunit',
 				'zxx' => 'Ulac agbur utlayan',
 				'zza' => 'Tazazakit',

			);
			if (@_) {
				return $languages{$_[0]};
			}
			return \%languages;
		}
	},
);

has 'display_name_script' => (
	is			=> 'ro',
	isa			=> CodeRef,
	init_arg	=> undef,
	default		=> sub {
		sub {
			my %scripts = (
			'Arab' => 'Aɛrab',
 			'Armn' => 'Armini',
 			'Beng' => 'Abengali',
 			'Bopo' => 'Abupumufu',
 			'Brai' => 'Bray',
 			'Cyrl' => 'Tasirilikit',
 			'Deva' => 'Adivangari',
 			'Ethi' => 'Atyupan',
 			'Geor' => 'Agriguri',
 			'Grek' => 'Agrigi',
 			'Gujr' => 'Agujarati',
 			'Guru' => 'Agurmuxi',
 			'Hanb' => 'Ahanbt',
 			'Hang' => 'Ahangul',
 			'Hani' => 'Ahan',
 			'Hans' => 'Aḥerfi',
 			'Hans@alt=stand-alone' => 'Isinugramen iḥerfiyen',
 			'Hant' => 'Amensay',
 			'Hant@alt=stand-alone' => 'Isinugramen imensayen',
 			'Hebr' => 'Aɛebri',
 			'Hira' => 'Ahiragana',
 			'Hrkt' => 'Akatakana n hiragana',
 			'Jamo' => 'Ajamu',
 			'Jpan' => 'Ajapuni',
 			'Kana' => 'Akatakana',
 			'Khmr' => 'Axemri',
 			'Knda' => 'Akannada',
 			'Kore' => 'Akuri',
 			'Laoo' => 'Alawsi',
 			'Latn' => 'Alaṭini',
 			'Mlym' => 'Amalayalam',
 			'Mong' => 'Amungul',
 			'Mymr' => 'Abiṛman',
 			'Orya' => 'Urya',
 			'Sinh' => 'Asingali',
 			'Taml' => 'Aṭamil',
 			'Telu' => 'Tilugut',
 			'Thaa' => 'Athana',
 			'Thai' => 'Ataylan',
 			'Tibt' => 'Atibitan',
 			'Zmth' => 'Tira tusnakt',
 			'Zsye' => 'Imujit',
 			'Zsym' => 'Izamulen',
 			'Zxxx' => 'War tira',
 			'Zyyy' => 'Ucrik',
 			'Zzzz' => 'Tira tarussint',

			);
			if ( @_ ) {
				return $scripts{$_[0]};
			}
			return \%scripts;
		}
	}
);

has 'display_name_region' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'001' => 'Amaḍal',
 			'002' => 'Taferka',
 			'003' => 'Tamrikt n ugafa',
 			'005' => 'Tamrikt n unẓul',
 			'009' => 'Usyanya',
 			'011' => 'Tafriqt n umalu',
 			'013' => 'Tamrikt Talemmast',
 			'014' => 'Tafriqt n usammar',
 			'015' => 'Tafriqt n ugafa',
 			'017' => 'Tafriqt talemmast',
 			'018' => 'Tafriqt n unẓul',
 			'019' => 'Timrikin',
 			'021' => 'Tamrikt tagafant',
 			'029' => 'Kaṛayib',
 			'030' => 'Asya n usammar',
 			'034' => 'Asya n unẓul',
 			'035' => 'Asya n unẓul asammar',
 			'039' => 'Turuft n unẓul',
 			'053' => 'Ustṛalazya',
 			'054' => 'Milanizya',
 			'057' => 'Tamnaḍt n Mikṛunizya',
 			'061' => 'Pulinizya',
 			'142' => 'Asya',
 			'143' => 'Asya talemmast',
 			'145' => 'Asya n umalu',
 			'150' => 'Turuft',
 			'151' => 'Turuft n usammar',
 			'154' => 'Turuft n ugafa',
 			'155' => 'Turuft n umalu',
 			'202' => 'Tafriqt n wadda n Seḥra',
 			'419' => 'Tamrikt talaṭinit',
 			'AC' => 'Tigzirt n Aṣunsyun',
 			'AD' => 'Undura',
 			'AE' => 'Tigeldunin Yedduklen Taɛrabin',
 			'AF' => 'Afɣanistan',
 			'AG' => 'Untiga d Barbuda',
 			'AI' => 'Ungiya',
 			'AL' => 'Lalbani',
 			'AM' => 'Arminya',
 			'AO' => 'Ungula',
 			'AQ' => 'Anṭarktik',
 			'AR' => 'Arjuntin',
 			'AS' => 'Samwa Tamarikanit',
 			'AT' => 'Ustriya',
 			'AU' => 'Ustrali',
 			'AW' => 'Aruba',
 			'AX' => 'Tigzirin n Aland',
 			'AZ' => 'Azrabijan',
 			'BA' => 'Busna d Hersek',
 			'BB' => 'Barbadus',
 			'BD' => 'Bangladac',
 			'BE' => 'Belǧik',
 			'BF' => 'Burkina Fasu',
 			'BG' => 'Bulgari',
 			'BH' => 'Baḥrin',
 			'BI' => 'Burandi',
 			'BJ' => 'Binin',
 			'BL' => 'Sant Baṛtilimi',
 			'BM' => 'Bermuda',
 			'BN' => 'Bruney',
 			'BO' => 'Bulivi',
 			'BQ' => 'Huland n Kaṛayib',
 			'BR' => 'Brizil',
 			'BS' => 'Bahamas',
 			'BT' => 'Bhutan',
 			'BV' => 'Tigzirin n Buvet',
 			'BW' => 'Bustwana',
 			'BY' => 'Bilarus',
 			'BZ' => 'Biliz',
 			'CA' => 'Kanada',
 			'CC' => 'Tigzirin n Kukus',
 			'CD' => 'Tigduda Tagdudant n Kungu',
 			'CD@alt=variant' => 'Tagduda Tamegdayt n Kungu',
 			'CF' => 'Tigduda n Tefriqt Talemmast',
 			'CG' => 'Kungu',
 			'CG@alt=variant' => 'Kungu (Tagduda)',
 			'CH' => 'Swis',
 			'CI' => 'Kuṭ Divwar',
 			'CK' => 'Tigzirin n Kuk',
 			'CL' => 'Cili',
 			'CM' => 'Kamirun',
 			'CN' => 'Lacin',
 			'CO' => 'Kulumbi',
 			'CP' => 'Tigzirt n Klipirṭun',
 			'CR' => 'Kusta Rika',
 			'CU' => 'Kuba',
 			'CV' => 'Tigzirin n yixef azegzaw',
 			'CW' => 'Kurasaw',
 			'CX' => 'Tigzrin n Kristmaṣ',
 			'CY' => 'Cipr',
 			'CZ' => 'Čček',
 			'CZ@alt=variant' => 'Tagduda n Čcik',
 			'DE' => 'Lalman',
 			'DG' => 'Dyigu Garsiya',
 			'DJ' => 'Ǧibuti',
 			'DK' => 'Denmark',
 			'DM' => 'Duminik',
 			'DO' => 'Tigduda Taduminikit',
 			'DZ' => 'Lezzayer',
 			'EA' => 'Sebta d Melilla',
 			'EC' => 'Ikwaṭur',
 			'EE' => 'Istunya',
 			'EG' => 'Maṣr',
 			'EH' => 'Seḥra n umalu',
 			'ER' => 'Iritiria',
 			'ES' => 'Spanya',
 			'ET' => 'Utyupi',
 			'EU' => 'Tiddukkla n Turuft',
 			'EZ' => 'Tamnaḍt n Turuft',
 			'FI' => 'Finlund',
 			'FJ' => 'Fiji',
 			'FK' => 'Tigzirin n Falkland',
 			'FM' => 'Mikrunizya',
 			'FO' => 'Tigzirin n Faṛwi',
 			'FR' => 'Fransa',
 			'GA' => 'Gabun',
 			'GB' => 'Tagelda Yedduklen',
 			'GB@alt=short' => 'TY',
 			'GD' => 'Grunad',
 			'GE' => 'Jiyurji',
 			'GF' => 'Ɣana tafransist',
 			'GG' => 'Girnizi',
 			'GH' => 'Ɣana',
 			'GI' => 'Jibraltar',
 			'GL' => 'Grunland',
 			'GM' => 'Gambya',
 			'GN' => 'Ɣinya',
 			'GP' => 'Gwadalupi',
 			'GQ' => 'Ɣinya Tasebgast',
 			'GR' => 'Lagris',
 			'GS' => 'Tigzirin n Jyuṛjya n Unẓul akked Sandwič n Unẓul',
 			'GT' => 'Gwatimala',
 			'GU' => 'Gwam',
 			'GW' => 'Ɣinya-Bisaw',
 			'GY' => 'Guwana',
 			'HK' => 'Tamnaṭ Taqbuṛt Tacinwat n Hung Kung',
 			'HK@alt=short' => 'Hung Kung',
 			'HM' => 'Tigzirin n Hird d Makdunalt',
 			'HN' => 'Hunduras',
 			'HR' => 'Kerwasya',
 			'HT' => 'Hayti',
 			'HU' => 'Hungri',
 			'IC' => 'Tigzirin Tikanaṛiyin',
 			'ID' => 'Indunizi',
 			'IE' => 'Lirlund',
 			'IL' => 'Izrayil',
 			'IM' => 'Tigzirt n Man',
 			'IN' => 'Lhend',
 			'IO' => 'Akal Aglizi deg Ugaraw Ahendi',
 			'IQ' => 'Lɛiraq',
 			'IR' => 'Iran',
 			'IS' => 'Island',
 			'IT' => 'Ṭelyan',
 			'JE' => 'Jirzi',
 			'JM' => 'Jamyika',
 			'JO' => 'Lajurdani',
 			'JP' => 'Jappu',
 			'KE' => 'Kinya',
 			'KG' => 'Kirigistan',
 			'KH' => 'Cambudya',
 			'KI' => 'Kiribati',
 			'KM' => 'Kumur',
 			'KN' => 'San Kits d Nivis',
 			'KP' => 'Kurya, Ufella',
 			'KR' => 'Kurya, Wadda',
 			'KW' => 'Kuwayt',
 			'KY' => 'Tigzirin n Kamyan',
 			'KZ' => 'Kazaxistan',
 			'LA' => 'Laws',
 			'LB' => 'Lubnan',
 			'LC' => 'San Lučya',
 			'LI' => 'Layctenstan',
 			'LK' => 'Sri Lanka',
 			'LR' => 'Libirya',
 			'LS' => 'Lizuṭu',
 			'LT' => 'Liṭwanya',
 			'LU' => 'Luksamburg',
 			'LV' => 'Latvia',
 			'LY' => 'Libya',
 			'MA' => 'Lmerruk',
 			'MC' => 'Munaku',
 			'MD' => 'Muldabi',
 			'ME' => 'Muntinigru',
 			'MF' => 'San Maṛtan',
 			'MG' => 'Madaɣecqer',
 			'MH' => 'Tigzirin n Marcal',
 			'MK' => 'Masidunya n ugafa',
 			'ML' => 'Mali',
 			'MM' => 'Myanmar',
 			'MN' => 'Mungulya',
 			'MO' => 'Tamnaḍt tudbilt tuzzigt tacinwat n Makaw',
 			'MO@alt=short' => 'Makaw',
 			'MP' => 'Tigzirin n Maryan Ufella',
 			'MQ' => 'Martinik',
 			'MR' => 'Muriṭanya',
 			'MS' => 'Munsirat',
 			'MT' => 'Malṭ',
 			'MU' => 'Muris',
 			'MV' => 'Maldib',
 			'MW' => 'Malawi',
 			'MX' => 'Meksik',
 			'MY' => 'Malizya',
 			'MZ' => 'Muzembiq',
 			'NA' => 'Namibya',
 			'NC' => 'Kalidunya Tamaynut',
 			'NE' => 'Nijer',
 			'NF' => 'Tigzirin Tinawfukin',
 			'NG' => 'Nijirya',
 			'NI' => 'Nikaragwa',
 			'NL' => 'Timura-Yessakesren',
 			'NO' => 'Nurvij',
 			'NP' => 'Nipal',
 			'NR' => 'Nuru',
 			'NU' => 'Niwi',
 			'NZ' => 'Ziland Tamaynut',
 			'OM' => 'Ɛuman',
 			'PA' => 'Panam',
 			'PE' => 'Piru',
 			'PF' => 'Pulunizi tafransist',
 			'PG' => 'Ɣinya Tamaynut Tapaput',
 			'PH' => 'Filipin',
 			'PK' => 'Pakistan',
 			'PL' => 'Pulund',
 			'PM' => 'San Pyar d Miklun',
 			'PN' => 'Pitkarin',
 			'PR' => 'Purtu Riku',
 			'PS' => 'Falisṭin d Ɣezza',
 			'PS@alt=short' => 'Palistin',
 			'PT' => 'Purtugal',
 			'PW' => 'Palu',
 			'PY' => 'Paragway',
 			'QA' => 'Qaṭar',
 			'QO' => 'Timnaḍin ibeɛden n Usyanya',
 			'RE' => 'Timlilit',
 			'RO' => 'Rumani',
 			'RS' => 'Ṣirbya',
 			'RU' => 'Rrus',
 			'RW' => 'Ruwanda',
 			'SA' => 'Suɛudiya Taɛrabt',
 			'SB' => 'Tigzirin n Sulumun',
 			'SC' => 'Seycel',
 			'SD' => 'Sudan',
 			'SE' => 'Swid',
 			'SG' => 'Singafur',
 			'SH' => 'Sant Ilina',
 			'SI' => 'Sluvinya',
 			'SJ' => 'Svalvard d Jan Mayen',
 			'SK' => 'Sluvakya',
 			'SL' => 'Sira Lyun',
 			'SM' => 'San Marinu',
 			'SN' => 'Sinigal',
 			'SO' => 'Ṣumal',
 			'SR' => 'Surinam',
 			'SS' => 'Sudan n unẓul',
 			'ST' => 'Saw Tumi d Pransip',
 			'SV' => 'Salvadur',
 			'SX' => 'Sint Maarten',
 			'SY' => 'Surya',
 			'SZ' => 'Swazilund',
 			'SZ@alt=variant' => 'Swaziland',
 			'TA' => 'Tristan da Kunha',
 			'TC' => 'Ṭurk d Tegzirin n Kaykus',
 			'TD' => 'Čad',
 			'TF' => 'Timura tifransisin n unẓul',
 			'TG' => 'Ṭugu',
 			'TH' => 'Ṭayland',
 			'TJ' => 'Tajikistan',
 			'TK' => 'Ṭuklu',
 			'TL' => 'Tumur Asamar',
 			'TL@alt=variant' => 'Timur n Usammar',
 			'TM' => 'Ṭurkmanistan',
 			'TN' => 'Tunes',
 			'TO' => 'Ṭunga',
 			'TR' => 'Ṭurk',
 			'TT' => 'Ṭrindad d Ṭubagu',
 			'TV' => 'Ṭuvalu',
 			'TW' => 'Ṭaywan',
 			'TZ' => 'Ṭanzanya',
 			'UA' => 'Ukran',
 			'UG' => 'Uɣanda',
 			'UM' => 'Tigzirin ibeɛden n Marikan',
 			'UN' => 'Timura Iddukklen',
 			'US' => 'WDM',
 			'US@alt=short' => 'Marikan',
 			'UY' => 'Urugway',
 			'UZ' => 'Uzbaxistan',
 			'VA' => 'Awanek n Vatikan',
 			'VC' => 'San Vansu d Grunadin',
 			'VE' => 'Venzwila',
 			'VG' => 'Tigzirin Tiverjiniyin Tigliziyin',
 			'VI' => 'W.D. Tigzirin n Virginya',
 			'VN' => 'Vyeṭnam',
 			'VU' => 'Vanwatu',
 			'WF' => 'Wallis d Futuna',
 			'WS' => 'Samwa',
 			'XA' => 'Azun iɣdebba',
 			'XB' => 'Azun Bidi',
 			'XK' => 'Kuṣuvu',
 			'YE' => 'Lyamen',
 			'YT' => 'Mayuṭ',
 			'ZA' => 'Tafriqt Wadda',
 			'ZM' => 'Zambya',
 			'ZW' => 'Zimbabwi',
 			'ZZ' => 'Timnaḍin Tirussinin',

		}
	},
);

has 'display_name_key' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'calendar' => 'Awitay',
 			'cf' => 'Amasal n tedrimt',
 			'collation' => 'Amizwer deg ufr',
 			'currency' => 'Tadrimt',
 			'hc' => 'Anagraw usrig (12 mgal 24)',
 			'lb' => 'Aɣanib n tuɣalin ar udur',
 			'ms' => 'Anagraw n uktal',
 			'numbers' => 'Imḍanen',

		}
	},
);

has 'display_name_type' => (
	is			=> 'ro',
	isa			=> HashRef[HashRef[Str]],
	init_arg	=> undef,
	default		=> sub {
		{
			'calendar' => {
 				'buddhist' => q{Awitay abudi},
 				'chinese' => q{Awitay acinwa},
 				'dangi' => q{Awitay n Dangi},
 				'ethiopic' => q{Awitay n Ityupya},
 				'gregorian' => q{Awitay agriguryan},
 				'hebrew' => q{Awitay aɛebri},
 				'islamic' => q{Awitay ineslem},
 				'iso8601' => q{Awitay ISO-8601},
 				'japanese' => q{Awitay ajapuni},
 				'persian' => q{Awitay afarsi},
 				'roc' => q{Awitay agdudan acinwa},
 			},
 			'cf' => {
 				'account' => q{Amasal n tedrimt n tsiḍent},
 				'standard' => q{Amasal n tedrimt izeɣ},
 			},
 			'collation' => {
 				'ducet' => q{Tanila n usemyizwer Unicod amezwaru},
 				'search' => q{Anadi amatu},
 				'standard' => q{Amizwer s ufran izeɣ},
 			},
 			'hc' => {
 				'h11' => q{Anagraw usrig 12 (0–11)},
 				'h12' => q{Anagraw usrig 12 (1–12)},
 				'h23' => q{Anagraw usrig 24 (0–23)},
 				'h24' => q{Anagraw usrig 24 (1–24)},
 			},
 			'lb' => {
 				'loose' => q{Aɣanib n tuɣalin ar udur ilelli},
 				'normal' => q{Aɣanib n tuɣalin ar udur amagnu},
 				'strict' => q{Aɣanib n tuɣalin ar udur uḥriṣ.},
 			},
 			'ms' => {
 				'metric' => q{Anagraw amitran},
 				'uksystem' => q{Anagraw n uktal Impiryal},
 				'ussystem' => q{Anagraw n uktal n Marikan},
 			},
 			'numbers' => {
 				'arab' => q{Izwilen aɛraben},
 				'arabext' => q{Izwilen aɛraben yettwasɣezfen},
 				'armn' => q{Izwilen iṛminiyen},
 				'armnlow' => q{Izwilen iṛminiyen meẓẓiyen},
 				'beng' => q{Izwilen ibingaliyen},
 				'deva' => q{Izwilen idivangariyen},
 				'ethi' => q{Izwilen ityupanen},
 				'fullwide' => q{Izwilen ihrawanen},
 				'geor' => q{Izwilen ijyuṛjiyen},
 				'grek' => q{Izwilen igrikiyen},
 				'greklow' => q{Izwilen igrikiyen imeẓyanen},
 				'gujr' => q{Izwilen iguǧaratiyen},
 				'guru' => q{Izwilen igurmuxiyen},
 				'hanidec' => q{Izwilen imrawen icinwaten},
 				'hans' => q{Izwilen iḥerfiyen icinwaten},
 				'hansfin' => q{Izwilen udrimen iḥerfiyen icinwaten},
 				'hant' => q{Izwilen imensayen icinwaten},
 				'hantfin' => q{Izwilen udrimen iḥerfiyen nicinwaten},
 				'hebr' => q{Izwilen iɛebriyen},
 				'jpan' => q{Izwilen ijapuniyen},
 				'jpanfin' => q{Izwilen udrimen ijjapuniyen},
 				'khmr' => q{Izwilen ixmariyen},
 				'knda' => q{Izwilen n Kannada},
 				'laoo' => q{Izwilen ilawsiyen},
 				'latn' => q{Izwilen n umalu},
 				'mlym' => q{Izwilen n Malayalam},
 				'mymr' => q{Izwilen n Myanmar},
 				'orya' => q{Izwilen uryanen},
 				'roman' => q{Izwilen iṛumanen},
 				'romanlow' => q{Izwilen iṛumanen imeẓyanen},
 				'taml' => q{Izwilen imensayen n ṭamil},
 				'tamldec' => q{Izwilen n Ṭamil},
 				'telu' => q{Izwilen n Tilugu},
 				'thai' => q{Izwilen n Ṭayland},
 				'tibt' => q{Izwilen Itibitanen},
 			},

		}
	},
);

has 'display_name_measurement_system' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'metric' => q{Amitran},
 			'UK' => q{Anglizi},
 			'US' => q{Amarikan},

		}
	},
);

has 'display_name_code_patterns' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'language' => 'Tutlayt: {0}',
 			'script' => 'Tira: {0}',
 			'region' => 'Tamnaḍt: {0}',

		}
	},
);

has 'characters' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> $^V ge v5.18.0
	? eval <<'EOT'
	sub {
		no warnings 'experimental::regex_sets';
		return {
			auxiliary => qr{[o v]},
			index => ['A', 'B', 'CČ', 'DḌ', 'E', 'Ɛ', 'F', 'GǦ', 'Ɣ', 'HḤ', 'I', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'RṚ', 'SṢ', 'TṬ', 'U', 'W', 'X', 'Y', 'ZẒ'],
			main => qr{[a b cč dḍ e ɛ f gǧ ɣ hḥ i j k l m n p q rṛ sṣ tṭ u w x y zẓ]},
			numbers => qr{[  \- ‑ , % ‰ + 0 1 2 3 4 5 6 7 8 9]},
			punctuation => qr{[\- ‐‑ – — , ; \: ! ? . … '‘’ "“” ( ) \[ \] § @ * / \& # † ‡ ′ ″]},
		};
	},
EOT
: sub {
		return { index => ['A', 'B', 'CČ', 'DḌ', 'E', 'Ɛ', 'F', 'GǦ', 'Ɣ', 'HḤ', 'I', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'RṚ', 'SṢ', 'TṬ', 'U', 'W', 'X', 'Y', 'ZẒ'], };
},
);


has 'quote_start' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{«},
);

has 'quote_end' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{»},
);

has 'alternate_quote_start' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{“},
);

has 'alternate_quote_end' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{”},
);

has 'units' => (
	is			=> 'ro',
	isa			=> HashRef[HashRef[HashRef[Str]]],
	init_arg	=> undef,
	default		=> sub { {
				'long' => {
					# Long Unit Identifier
					'' => {
						'name' => q(tanila tagejdant),
					},
					# Core Unit Identifier
					'' => {
						'name' => q(tanila tagejdant),
					},
					# Long Unit Identifier
					'acceleration-meter-per-square-second' => {
						'name' => q(mitrat deg tasint tuzmirt-sin),
						'one' => q({0} n mitra deg tasint tuzmirt-sin),
						'other' => q({0} n mitrat deg tasint tuzmirt-sin),
					},
					# Core Unit Identifier
					'meter-per-square-second' => {
						'name' => q(mitrat deg tasint tuzmirt-sin),
						'one' => q({0} n mitra deg tasint tuzmirt-sin),
						'other' => q({0} n mitrat deg tasint tuzmirt-sin),
					},
					# Long Unit Identifier
					'angle-degree' => {
						'name' => q(tafesna),
						'one' => q({0} n tfesna),
						'other' => q({0} n tfesniwin),
					},
					# Core Unit Identifier
					'degree' => {
						'name' => q(tafesna),
						'one' => q({0} n tfesna),
						'other' => q({0} n tfesniwin),
					},
					# Long Unit Identifier
					'angle-radian' => {
						'one' => q({0} n uradyan),
						'other' => q({0} n yiradyanen),
					},
					# Core Unit Identifier
					'radian' => {
						'one' => q({0} n uradyan),
						'other' => q({0} n yiradyanen),
					},
					# Long Unit Identifier
					'area-acre' => {
						'one' => q({0} n ukeṛ),
						'other' => q({0} n yikṛen),
					},
					# Core Unit Identifier
					'acre' => {
						'one' => q({0} n ukeṛ),
						'other' => q({0} n yikṛen),
					},
					# Long Unit Identifier
					'area-dunam' => {
						'one' => q({0} n udunam),
						'other' => q({0} n yidunamen),
					},
					# Core Unit Identifier
					'dunam' => {
						'one' => q({0} n udunam),
						'other' => q({0} n yidunamen),
					},
					# Long Unit Identifier
					'area-hectare' => {
						'one' => q({0} n uktar),
						'other' => q({0} n yiktaren),
					},
					# Core Unit Identifier
					'hectare' => {
						'one' => q({0} n uktar),
						'other' => q({0} n yiktaren),
					},
					# Long Unit Identifier
					'area-square-centimeter' => {
						'name' => q(isantimitren uzmir-sin),
						'one' => q({0} n usantimiter uzmir-sin),
						'other' => q({0} n yisantimitren uzmir-sin),
						'per' => q({0} deg usantimiter uzmir-sin),
					},
					# Core Unit Identifier
					'square-centimeter' => {
						'name' => q(isantimitren uzmir-sin),
						'one' => q({0} n usantimiter uzmir-sin),
						'other' => q({0} n yisantimitren uzmir-sin),
						'per' => q({0} deg usantimiter uzmir-sin),
					},
					# Long Unit Identifier
					'area-square-foot' => {
						'name' => q(iḍarren uzmir-sin),
						'one' => q({0} n uḍar uzmir-sin),
						'other' => q({0} n yiḍarren uzmir-sin),
					},
					# Core Unit Identifier
					'square-foot' => {
						'name' => q(iḍarren uzmir-sin),
						'one' => q({0} n uḍar uzmir-sin),
						'other' => q({0} n yiḍarren uzmir-sin),
					},
					# Long Unit Identifier
					'area-square-inch' => {
						'name' => q(idebbuzen uzmir-sin),
						'one' => q({0} n udebbuz uzmir-sin),
						'other' => q({0} n yidebbuzen uzmir-sin),
						'per' => q({0} deg udebbuz uzmir-sin),
					},
					# Core Unit Identifier
					'square-inch' => {
						'name' => q(idebbuzen uzmir-sin),
						'one' => q({0} n udebbuz uzmir-sin),
						'other' => q({0} n yidebbuzen uzmir-sin),
						'per' => q({0} deg udebbuz uzmir-sin),
					},
					# Long Unit Identifier
					'area-square-kilometer' => {
						'name' => q(ikilumitren uzmir-sin),
						'one' => q({0} n ukilumiter uzmir-sin),
						'other' => q({0} n yikilumitren uzmir-sin),
						'per' => q({0} deg ukilumiter uzmir-sin),
					},
					# Core Unit Identifier
					'square-kilometer' => {
						'name' => q(ikilumitren uzmir-sin),
						'one' => q({0} n ukilumiter uzmir-sin),
						'other' => q({0} n yikilumitren uzmir-sin),
						'per' => q({0} deg ukilumiter uzmir-sin),
					},
					# Long Unit Identifier
					'area-square-meter' => {
						'name' => q(mitrat uzmir-sin),
						'one' => q({0} n mitra uzmir-sin),
						'other' => q({0} n mitrat uzmir-sin),
						'per' => q({0} deg mitra uzmir-sin),
					},
					# Core Unit Identifier
					'square-meter' => {
						'name' => q(mitrat uzmir-sin),
						'one' => q({0} n mitra uzmir-sin),
						'other' => q({0} n mitrat uzmir-sin),
						'per' => q({0} deg mitra uzmir-sin),
					},
					# Long Unit Identifier
					'area-square-mile' => {
						'name' => q(imilen uzmir-sin),
						'one' => q({0} n umil uzmir-sin),
						'other' => q({0} n yimilen uzmir-sin),
						'per' => q({0} deg umil uzmir-sin),
					},
					# Core Unit Identifier
					'square-mile' => {
						'name' => q(imilen uzmir-sin),
						'one' => q({0} n umil uzmir-sin),
						'other' => q({0} n yimilen uzmir-sin),
						'per' => q({0} deg umil uzmir-sin),
					},
					# Long Unit Identifier
					'area-square-yard' => {
						'name' => q(iyarden uzmir-sin),
						'one' => q({0} n uyard uzmir-sin),
						'other' => q({0} n yiyarden uzmir-sin),
					},
					# Core Unit Identifier
					'square-yard' => {
						'name' => q(iyarden uzmir-sin),
						'one' => q({0} n uyard uzmir-sin),
						'other' => q({0} n yiyarden uzmir-sin),
					},
					# Long Unit Identifier
					'concentr-millimole-per-liter' => {
						'name' => q(imilimulen deg ulitr),
						'one' => q({0} n umilimul deg ulitr),
						'other' => q({0} n imilimulen deg ulitr),
					},
					# Core Unit Identifier
					'millimole-per-liter' => {
						'name' => q(imilimulen deg ulitr),
						'one' => q({0} n umilimul deg ulitr),
						'other' => q({0} n imilimulen deg ulitr),
					},
					# Long Unit Identifier
					'concentr-permille' => {
						'name' => q(ɣef wagim),
						'one' => q({0} ɣef wagim),
						'other' => q({0} ɣef wagim),
					},
					# Core Unit Identifier
					'permille' => {
						'name' => q(ɣef wagim),
						'one' => q({0} ɣef wagim),
						'other' => q({0} ɣef wagim),
					},
					# Long Unit Identifier
					'coordinate' => {
						'east' => q({0} asammar),
						'north' => q({0} agafa),
						'south' => q({0} anẓul),
						'west' => q({0} amalu),
					},
					# Core Unit Identifier
					'coordinate' => {
						'east' => q({0} asammar),
						'north' => q({0} agafa),
						'south' => q({0} anẓul),
						'west' => q({0} amalu),
					},
					# Long Unit Identifier
					'digital-byte' => {
						'one' => q({0} aṭamdan),
						'other' => q({0} iṭamḍanen),
					},
					# Core Unit Identifier
					'byte' => {
						'one' => q({0} aṭamdan),
						'other' => q({0} iṭamḍanen),
					},
					# Long Unit Identifier
					'digital-gigabit' => {
						'name' => q(igigabiten),
						'one' => q({0} agigabit),
						'other' => q({0} igigabiten),
					},
					# Core Unit Identifier
					'gigabit' => {
						'name' => q(igigabiten),
						'one' => q({0} agigabit),
						'other' => q({0} igigabiten),
					},
					# Long Unit Identifier
					'digital-gigabyte' => {
						'name' => q(igigaṭamḍanen),
						'one' => q({0} n ugigaṭamḍan),
						'other' => q({0} n igigaṭamḍanen),
					},
					# Core Unit Identifier
					'gigabyte' => {
						'name' => q(igigaṭamḍanen),
						'one' => q({0} n ugigaṭamḍan),
						'other' => q({0} n igigaṭamḍanen),
					},
					# Long Unit Identifier
					'digital-kilobit' => {
						'name' => q(ikilubiten),
						'one' => q({0} akilubit),
						'other' => q({0} ikilubiten),
					},
					# Core Unit Identifier
					'kilobit' => {
						'name' => q(ikilubiten),
						'one' => q({0} akilubit),
						'other' => q({0} ikilubiten),
					},
					# Long Unit Identifier
					'digital-kilobyte' => {
						'name' => q(akiluṭamḍan),
						'one' => q({0} akiluṭamḍan),
						'other' => q({0} ikiluṭamḍanen),
					},
					# Core Unit Identifier
					'kilobyte' => {
						'name' => q(akiluṭamḍan),
						'one' => q({0} akiluṭamḍan),
						'other' => q({0} ikiluṭamḍanen),
					},
					# Long Unit Identifier
					'digital-megabit' => {
						'name' => q(imigabiten),
						'one' => q({0} amigabit),
						'other' => q({0} imigabiten),
					},
					# Core Unit Identifier
					'megabit' => {
						'name' => q(imigabiten),
						'one' => q({0} amigabit),
						'other' => q({0} imigabiten),
					},
					# Long Unit Identifier
					'digital-megabyte' => {
						'name' => q(imigaṭamḍanen),
						'one' => q({0} amigaṭamdan),
						'other' => q({0} imigaṭamḍanen),
					},
					# Core Unit Identifier
					'megabyte' => {
						'name' => q(imigaṭamḍanen),
						'one' => q({0} amigaṭamdan),
						'other' => q({0} imigaṭamḍanen),
					},
					# Long Unit Identifier
					'digital-terabit' => {
						'name' => q(itirabiten),
						'one' => q({0} atirabit),
						'other' => q({0} itirabiten),
					},
					# Core Unit Identifier
					'terabit' => {
						'name' => q(itirabiten),
						'one' => q({0} atirabit),
						'other' => q({0} itirabiten),
					},
					# Long Unit Identifier
					'digital-terabyte' => {
						'name' => q(itiraṭamḍanen),
						'one' => q({0} atiramḍan),
						'other' => q({0} itiramḍanen),
					},
					# Core Unit Identifier
					'terabyte' => {
						'name' => q(itiraṭamḍanen),
						'one' => q({0} atiramḍan),
						'other' => q({0} itiramḍanen),
					},
					# Long Unit Identifier
					'duration-century' => {
						'name' => q(tasutin),
						'one' => q({0} n tasut),
						'other' => q({0} n tasutin),
					},
					# Core Unit Identifier
					'century' => {
						'name' => q(tasutin),
						'one' => q({0} n tasut),
						'other' => q({0} n tasutin),
					},
					# Long Unit Identifier
					'duration-day' => {
						'per' => q({0} i wass),
					},
					# Core Unit Identifier
					'day' => {
						'per' => q({0} i wass),
					},
					# Long Unit Identifier
					'duration-decade' => {
						'name' => q(timerwatin),
						'one' => q({0} n tmerwa),
						'other' => q({0} n tmerwatin),
					},
					# Core Unit Identifier
					'decade' => {
						'name' => q(timerwatin),
						'one' => q({0} n tmerwa),
						'other' => q({0} n tmerwatin),
					},
					# Long Unit Identifier
					'duration-hour' => {
						'one' => q({0} n usrag),
						'other' => q({0} n yisragen),
						'per' => q({0} i usrag),
					},
					# Core Unit Identifier
					'hour' => {
						'one' => q({0} n usrag),
						'other' => q({0} n yisragen),
						'per' => q({0} i usrag),
					},
					# Long Unit Identifier
					'duration-microsecond' => {
						'name' => q(timikrusinin),
						'one' => q({0} n tmikrusint),
						'other' => q({0} n tmikrusinin),
					},
					# Core Unit Identifier
					'microsecond' => {
						'name' => q(timikrusinin),
						'one' => q({0} n tmikrusint),
						'other' => q({0} n tmikrusinin),
					},
					# Long Unit Identifier
					'duration-millisecond' => {
						'name' => q(timilisinin),
						'one' => q({0} n tmilisint),
						'other' => q({0} n tmilisinin),
					},
					# Core Unit Identifier
					'millisecond' => {
						'name' => q(timilisinin),
						'one' => q({0} n tmilisint),
						'other' => q({0} n tmilisinin),
					},
					# Long Unit Identifier
					'duration-minute' => {
						'name' => q(tisdatin),
						'one' => q({0} n tesdat),
						'other' => q({0} n tesdatin),
						'per' => q({0} i tesdat),
					},
					# Core Unit Identifier
					'minute' => {
						'name' => q(tisdatin),
						'one' => q({0} n tesdat),
						'other' => q({0} n tesdatin),
						'per' => q({0} i tesdat),
					},
					# Long Unit Identifier
					'duration-month' => {
						'one' => q({0} n wayyur),
						'other' => q({0} n wayyuren),
						'per' => q({0} i wayyur),
					},
					# Core Unit Identifier
					'month' => {
						'one' => q({0} n wayyur),
						'other' => q({0} n wayyuren),
						'per' => q({0} i wayyur),
					},
					# Long Unit Identifier
					'duration-nanosecond' => {
						'name' => q(tinanusinin),
						'one' => q({0} n tnanusint),
						'other' => q({0} n tnanusinin),
					},
					# Core Unit Identifier
					'nanosecond' => {
						'name' => q(tinanusinin),
						'one' => q({0} n tnanusint),
						'other' => q({0} n tnanusinin),
					},
					# Long Unit Identifier
					'duration-second' => {
						'name' => q(tisinin),
						'one' => q({0} n tsint),
						'other' => q({0} n tsinin),
						'per' => q({0} i tsint),
					},
					# Core Unit Identifier
					'second' => {
						'name' => q(tisinin),
						'one' => q({0} n tsint),
						'other' => q({0} n tsinin),
						'per' => q({0} i tsint),
					},
					# Long Unit Identifier
					'duration-week' => {
						'one' => q({0} n yimalas),
						'other' => q({0} n yimalasen),
						'per' => q({0} i yimalas),
					},
					# Core Unit Identifier
					'week' => {
						'one' => q({0} n yimalas),
						'other' => q({0} n yimalasen),
						'per' => q({0} i yimalas),
					},
					# Long Unit Identifier
					'duration-year' => {
						'one' => q({0} n useggas),
						'other' => q({0} n yiseggasen),
						'per' => q({0} i useggas),
					},
					# Core Unit Identifier
					'year' => {
						'one' => q({0} n useggas),
						'other' => q({0} n yiseggasen),
						'per' => q({0} i useggas),
					},
					# Long Unit Identifier
					'energy-calorie' => {
						'name' => q(ikaluriyen),
						'one' => q({0} n ukaluri),
						'other' => q({0} n yikaluriyen),
					},
					# Core Unit Identifier
					'calorie' => {
						'name' => q(ikaluriyen),
						'one' => q({0} n ukaluri),
						'other' => q({0} n yikaluriyen),
					},
					# Long Unit Identifier
					'energy-foodcalorie' => {
						'name' => q(Ikaluriyen),
						'one' => q({0} n ukaluri),
						'other' => q({0} n yikaluriyen),
					},
					# Core Unit Identifier
					'foodcalorie' => {
						'name' => q(Ikaluriyen),
						'one' => q({0} n ukaluri),
						'other' => q({0} n yikaluriyen),
					},
					# Long Unit Identifier
					'energy-joule' => {
						'one' => q({0} n ujul),
						'other' => q({0} n yijulen),
					},
					# Core Unit Identifier
					'joule' => {
						'one' => q({0} n ujul),
						'other' => q({0} n yijulen),
					},
					# Long Unit Identifier
					'energy-kilocalorie' => {
						'name' => q(Ikilukaluriyen),
						'one' => q({0} n ukilukaluri),
						'other' => q({0} n yikilukaluriyen),
					},
					# Core Unit Identifier
					'kilocalorie' => {
						'name' => q(Ikilukaluriyen),
						'one' => q({0} n ukilukaluri),
						'other' => q({0} n yikilukaluriyen),
					},
					# Long Unit Identifier
					'energy-kilojoule' => {
						'name' => q(ikilujulen),
						'one' => q({0} n ukilujul),
						'other' => q({0} n yikilujulen),
					},
					# Core Unit Identifier
					'kilojoule' => {
						'name' => q(ikilujulen),
						'one' => q({0} n ukilujul),
						'other' => q({0} n yikilujulen),
					},
					# Long Unit Identifier
					'graphics-dot' => {
						'name' => q(taneqqiḍt),
						'one' => q({0} n tneqqiṭ),
						'other' => q({0} n tneqqiṭ),
					},
					# Core Unit Identifier
					'dot' => {
						'name' => q(taneqqiḍt),
						'one' => q({0} n tneqqiṭ),
						'other' => q({0} n tneqqiṭ),
					},
					# Long Unit Identifier
					'graphics-dot-per-centimeter' => {
						'name' => q(tineqqiḍin deg usantimitr),
						'one' => q({0} n tneqqiḍt deg usantimitr),
						'other' => q({0} n tneqqiḍin deg usantimitr),
					},
					# Core Unit Identifier
					'dot-per-centimeter' => {
						'name' => q(tineqqiḍin deg usantimitr),
						'one' => q({0} n tneqqiḍt deg usantimitr),
						'other' => q({0} n tneqqiḍin deg usantimitr),
					},
					# Long Unit Identifier
					'graphics-dot-per-inch' => {
						'name' => q(Tineqqiḍin deg udebbuz),
						'one' => q({0} n tneqqiḍt deg udebbuz),
						'other' => q({0} n tneqqiḍin deg udebbuz),
					},
					# Core Unit Identifier
					'dot-per-inch' => {
						'name' => q(Tineqqiḍin deg udebbuz),
						'one' => q({0} n tneqqiḍt deg udebbuz),
						'other' => q({0} n tneqqiḍin deg udebbuz),
					},
					# Long Unit Identifier
					'graphics-em' => {
						'name' => q(azamul ntira em),
						'one' => q({0} em),
						'other' => q({0} ems),
					},
					# Core Unit Identifier
					'em' => {
						'name' => q(azamul ntira em),
						'one' => q({0} em),
						'other' => q({0} ems),
					},
					# Long Unit Identifier
					'graphics-megapixel' => {
						'one' => q({0} n umigapiksil),
						'other' => q({0} n yimigapiksilen),
					},
					# Core Unit Identifier
					'megapixel' => {
						'one' => q({0} n umigapiksil),
						'other' => q({0} n yimigapiksilen),
					},
					# Long Unit Identifier
					'graphics-pixel' => {
						'one' => q({0} n upiksil),
						'other' => q({0} n yipiksilen),
					},
					# Core Unit Identifier
					'pixel' => {
						'one' => q({0} n upiksil),
						'other' => q({0} n yipiksilen),
					},
					# Long Unit Identifier
					'graphics-pixel-per-centimeter' => {
						'name' => q(ipiksilen deg usantimitr),
						'one' => q({0} n upiksil deg usantimitr),
						'other' => q({0} n yipiksilen deg usantimitr),
					},
					# Core Unit Identifier
					'pixel-per-centimeter' => {
						'name' => q(ipiksilen deg usantimitr),
						'one' => q({0} n upiksil deg usantimitr),
						'other' => q({0} n yipiksilen deg usantimitr),
					},
					# Long Unit Identifier
					'graphics-pixel-per-inch' => {
						'name' => q(ipiksilen deg udebbuz),
						'one' => q({0} n upiksil deg udebbuz),
						'other' => q({0} n yipiksilen deg udebbuz),
					},
					# Core Unit Identifier
					'pixel-per-inch' => {
						'name' => q(ipiksilen deg udebbuz),
						'one' => q({0} n upiksil deg udebbuz),
						'other' => q({0} n yipiksilen deg udebbuz),
					},
					# Long Unit Identifier
					'length-astronomical-unit' => {
						'name' => q(iferdisen isnallunen),
						'one' => q({0} aferdis asnallun),
						'other' => q({0} iferdisen isnallunen),
					},
					# Core Unit Identifier
					'astronomical-unit' => {
						'name' => q(iferdisen isnallunen),
						'one' => q({0} aferdis asnallun),
						'other' => q({0} iferdisen isnallunen),
					},
					# Long Unit Identifier
					'length-centimeter' => {
						'name' => q(isantimitren),
						'one' => q({0} n usantimiter),
						'other' => q({0} n yisantimitren),
						'per' => q({0} i usantimiter),
					},
					# Core Unit Identifier
					'centimeter' => {
						'name' => q(isantimitren),
						'one' => q({0} n usantimiter),
						'other' => q({0} n yisantimitren),
						'per' => q({0} i usantimiter),
					},
					# Long Unit Identifier
					'length-decimeter' => {
						'name' => q(idisimitren),
						'one' => q({0} n udisimiter),
						'other' => q({0} n yidisimitren),
					},
					# Core Unit Identifier
					'decimeter' => {
						'name' => q(idisimitren),
						'one' => q({0} n udisimiter),
						'other' => q({0} n yidisimitren),
					},
					# Long Unit Identifier
					'length-foot' => {
						'one' => q({0} n uḍaṛ),
						'other' => q({0} n iḍarren),
						'per' => q({0} deg uḍar),
					},
					# Core Unit Identifier
					'foot' => {
						'one' => q({0} n uḍaṛ),
						'other' => q({0} n iḍarren),
						'per' => q({0} deg uḍar),
					},
					# Long Unit Identifier
					'length-inch' => {
						'one' => q({0} n udebbuz),
						'other' => q({0} n yidebbuzen),
						'per' => q({0} i udebbuz),
					},
					# Core Unit Identifier
					'inch' => {
						'one' => q({0} n udebbuz),
						'other' => q({0} n yidebbuzen),
						'per' => q({0} i udebbuz),
					},
					# Long Unit Identifier
					'length-kilometer' => {
						'name' => q(ikilumitren),
						'one' => q({0} n ukilumiter),
						'other' => q({0} n yikilumitren),
						'per' => q({0} i ukilumiter),
					},
					# Core Unit Identifier
					'kilometer' => {
						'name' => q(ikilumitren),
						'one' => q({0} n ukilumiter),
						'other' => q({0} n yikilumitren),
						'per' => q({0} i ukilumiter),
					},
					# Long Unit Identifier
					'length-light-year' => {
						'name' => q(iseggasen n tafat),
						'one' => q({0} n useggas n tfat),
						'other' => q({0} n yiseggasen n tafat),
					},
					# Core Unit Identifier
					'light-year' => {
						'name' => q(iseggasen n tafat),
						'one' => q({0} n useggas n tfat),
						'other' => q({0} n yiseggasen n tafat),
					},
					# Long Unit Identifier
					'length-meter' => {
						'name' => q(lmitrat),
						'one' => q({0} n lmitra),
						'other' => q({0} n lmitrat),
						'per' => q({0} i lmitra),
					},
					# Core Unit Identifier
					'meter' => {
						'name' => q(lmitrat),
						'one' => q({0} n lmitra),
						'other' => q({0} n lmitrat),
						'per' => q({0} i lmitra),
					},
					# Long Unit Identifier
					'length-micrometer' => {
						'name' => q(imikrumitren),
						'one' => q({0} n umikrumiter),
						'other' => q({0} n yimikrumitren),
					},
					# Core Unit Identifier
					'micrometer' => {
						'name' => q(imikrumitren),
						'one' => q({0} n umikrumiter),
						'other' => q({0} n yimikrumitren),
					},
					# Long Unit Identifier
					'length-mile' => {
						'one' => q({0} n umil),
						'other' => q({0} n yimilen),
					},
					# Core Unit Identifier
					'mile' => {
						'one' => q({0} n umil),
						'other' => q({0} n yimilen),
					},
					# Long Unit Identifier
					'length-mile-scandinavian' => {
						'name' => q(amil askandinavi),
						'one' => q({0} n umil askandinavi),
						'other' => q({0} n yimilen iskandanaviyen),
					},
					# Core Unit Identifier
					'mile-scandinavian' => {
						'name' => q(amil askandinavi),
						'one' => q({0} n umil askandinavi),
						'other' => q({0} n yimilen iskandanaviyen),
					},
					# Long Unit Identifier
					'length-millimeter' => {
						'name' => q(imilimitren),
						'one' => q({0} n umilimiter),
						'other' => q({0} n yimilimitren),
					},
					# Core Unit Identifier
					'millimeter' => {
						'name' => q(imilimitren),
						'one' => q({0} n umilimiter),
						'other' => q({0} n yimilimitren),
					},
					# Long Unit Identifier
					'length-nanometer' => {
						'name' => q(inanumitren),
						'one' => q({0} n unanumiter),
						'other' => q({0} n yinanumitren),
					},
					# Core Unit Identifier
					'nanometer' => {
						'name' => q(inanumitren),
						'one' => q({0} n unanumiter),
						'other' => q({0} n yinanumitren),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'name' => q(imilen iwlalen),
						'one' => q({0} n umil awlal),
						'other' => q({0} n yimilen iwlalen),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'name' => q(imilen iwlalen),
						'one' => q({0} n umil awlal),
						'other' => q({0} n yimilen iwlalen),
					},
					# Long Unit Identifier
					'length-parsec' => {
						'one' => q({0} n uparsik),
						'other' => q({0} n yiparsiken),
					},
					# Core Unit Identifier
					'parsec' => {
						'one' => q({0} n uparsik),
						'other' => q({0} n yiparsiken),
					},
					# Long Unit Identifier
					'length-picometer' => {
						'name' => q(ipikumitren),
						'one' => q({0} n upikumiter),
						'other' => q({0} n yipikumitren),
					},
					# Core Unit Identifier
					'picometer' => {
						'name' => q(ipikumitren),
						'one' => q({0} n upikumiter),
						'other' => q({0} n yipikumitren),
					},
					# Long Unit Identifier
					'length-point' => {
						'one' => q({0} n tneqqiḍt),
						'other' => q({0} n tneqqiḍin),
					},
					# Core Unit Identifier
					'point' => {
						'one' => q({0} n tneqqiḍt),
						'other' => q({0} n tneqqiḍin),
					},
					# Long Unit Identifier
					'length-solar-radius' => {
						'name' => q(Aqqar n yiṭij),
					},
					# Core Unit Identifier
					'solar-radius' => {
						'name' => q(Aqqar n yiṭij),
					},
					# Long Unit Identifier
					'length-yard' => {
						'one' => q({0} n uyard),
						'other' => q({0} n yiyarden),
					},
					# Core Unit Identifier
					'yard' => {
						'one' => q({0} n uyard),
						'other' => q({0} n yiyarden),
					},
					# Long Unit Identifier
					'light-lux' => {
						'name' => q(Aluks),
						'one' => q({0} lks),
						'other' => q({0} lks),
					},
					# Core Unit Identifier
					'lux' => {
						'name' => q(Aluks),
						'one' => q({0} lks),
						'other' => q({0} lks),
					},
					# Long Unit Identifier
					'mass-gram' => {
						'name' => q(igramen),
						'one' => q({0} n ugram),
						'other' => q({0} n igramen),
						'per' => q({0} deg ugram),
					},
					# Core Unit Identifier
					'gram' => {
						'name' => q(igramen),
						'one' => q({0} n ugram),
						'other' => q({0} n igramen),
						'per' => q({0} deg ugram),
					},
					# Long Unit Identifier
					'mass-kilogram' => {
						'name' => q(ikilugramen),
						'one' => q({0} ukilugram),
						'other' => q({0} n ikilugramen),
						'per' => q({0} deg ukilugram),
					},
					# Core Unit Identifier
					'kilogram' => {
						'name' => q(ikilugramen),
						'one' => q({0} ukilugram),
						'other' => q({0} n ikilugramen),
						'per' => q({0} deg ukilugram),
					},
					# Long Unit Identifier
					'mass-microgram' => {
						'name' => q(imikrugramen),
						'one' => q({0} n umikrugram),
						'other' => q({0} n imikrugramen),
					},
					# Core Unit Identifier
					'microgram' => {
						'name' => q(imikrugramen),
						'one' => q({0} n umikrugram),
						'other' => q({0} n imikrugramen),
					},
					# Long Unit Identifier
					'mass-milligram' => {
						'name' => q(imiligramen),
						'one' => q({0} n umiligram),
						'other' => q({0} n imiligramen),
					},
					# Core Unit Identifier
					'milligram' => {
						'name' => q(imiligramen),
						'one' => q({0} n umiligram),
						'other' => q({0} n imiligramen),
					},
					# Long Unit Identifier
					'mass-pound' => {
						'one' => q({0} n upund),
						'other' => q({0} n yipunden),
						'per' => q({0} deg upund),
					},
					# Core Unit Identifier
					'pound' => {
						'one' => q({0} n upund),
						'other' => q({0} n yipunden),
						'per' => q({0} deg upund),
					},
					# Long Unit Identifier
					'mass-ton' => {
						'one' => q({0} n uṭun),
						'other' => q({0} n iṭenen),
					},
					# Core Unit Identifier
					'ton' => {
						'one' => q({0} n uṭun),
						'other' => q({0} n iṭenen),
					},
					# Long Unit Identifier
					'mass-tonne' => {
						'name' => q(Iṭunen imitranen),
						'one' => q({0} n uṭun amitran),
						'other' => q({0} n iṭunen imitranen),
					},
					# Core Unit Identifier
					'tonne' => {
						'name' => q(Iṭunen imitranen),
						'one' => q({0} n uṭun amitran),
						'other' => q({0} n iṭunen imitranen),
					},
					# Long Unit Identifier
					'per' => {
						'1' => q({0} deg {1}),
					},
					# Core Unit Identifier
					'per' => {
						'1' => q({0} deg {1}),
					},
					# Long Unit Identifier
					'power-watt' => {
						'one' => q({0} waṭ),
						'other' => q({0} waṭ),
					},
					# Core Unit Identifier
					'watt' => {
						'one' => q({0} waṭ),
						'other' => q({0} waṭ),
					},
					# Long Unit Identifier
					'pressure-hectopascal' => {
						'name' => q(ihiktupaskalen),
						'one' => q({0} n uhiktupaskal),
						'other' => q({0} n ihiktupaskalen),
					},
					# Core Unit Identifier
					'hectopascal' => {
						'name' => q(ihiktupaskalen),
						'one' => q({0} n uhiktupaskal),
						'other' => q({0} n ihiktupaskalen),
					},
					# Long Unit Identifier
					'speed-kilometer-per-hour' => {
						'name' => q(ikilumitren deg usrag),
						'one' => q({0} n ukilumiter deg usrag),
						'other' => q({0} n yikilumitren deg usrag),
					},
					# Core Unit Identifier
					'kilometer-per-hour' => {
						'name' => q(ikilumitren deg usrag),
						'one' => q({0} n ukilumiter deg usrag),
						'other' => q({0} n yikilumitren deg usrag),
					},
					# Long Unit Identifier
					'speed-knot' => {
						'name' => q(timukrisin),
						'one' => q({0} n tmukrist),
						'other' => q({0} n tmukrisin),
					},
					# Core Unit Identifier
					'knot' => {
						'name' => q(timukrisin),
						'one' => q({0} n tmukrist),
						'other' => q({0} n tmukrisin),
					},
					# Long Unit Identifier
					'speed-meter-per-second' => {
						'name' => q(mitrat deg tasint),
						'one' => q({0} n mitra deg tasint),
						'other' => q({0} n mitrat deg tasint),
					},
					# Core Unit Identifier
					'meter-per-second' => {
						'name' => q(mitrat deg tasint),
						'one' => q({0} n mitra deg tasint),
						'other' => q({0} n mitrat deg tasint),
					},
					# Long Unit Identifier
					'speed-mile-per-hour' => {
						'name' => q(imilen deg usrag),
						'one' => q({0} n umil deg usrag),
						'other' => q({0} n yimilen deg usrag),
					},
					# Core Unit Identifier
					'mile-per-hour' => {
						'name' => q(imilen deg usrag),
						'one' => q({0} n umil deg usrag),
						'other' => q({0} n yimilen deg usrag),
					},
					# Long Unit Identifier
					'times' => {
						'1' => q({0}-{1}),
					},
					# Core Unit Identifier
					'times' => {
						'1' => q({0}-{1}),
					},
					# Long Unit Identifier
					'volume-acre-foot' => {
						'name' => q(akeṛ-iḍarren),
						'one' => q({0} n ukeṛ-aḍar),
						'other' => q({0} n ukeṛ-iḍarreb),
					},
					# Core Unit Identifier
					'acre-foot' => {
						'name' => q(akeṛ-iḍarren),
						'one' => q({0} n ukeṛ-aḍar),
						'other' => q({0} n ukeṛ-iḍarreb),
					},
					# Long Unit Identifier
					'volume-barrel' => {
						'name' => q(tibettiyin),
						'one' => q({0} n tbettit),
						'other' => q({0} n tbettiyin),
					},
					# Core Unit Identifier
					'barrel' => {
						'name' => q(tibettiyin),
						'one' => q({0} n tbettit),
						'other' => q({0} n tbettiyin),
					},
					# Long Unit Identifier
					'volume-centiliter' => {
						'name' => q(isantilitren),
						'one' => q({0} n usantiliter),
						'other' => q({0} n yisantilitren),
					},
					# Core Unit Identifier
					'centiliter' => {
						'name' => q(isantilitren),
						'one' => q({0} n usantiliter),
						'other' => q({0} n yisantilitren),
					},
					# Long Unit Identifier
					'volume-cubic-centimeter' => {
						'name' => q(isantimitren uzmir-kraḍ),
						'one' => q({0} usantimitr uzmir-kraḍ),
						'other' => q({0} yisantimitren uzmir-kraḍ),
						'per' => q({0} i usantimitr uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-centimeter' => {
						'name' => q(isantimitren uzmir-kraḍ),
						'one' => q({0} usantimitr uzmir-kraḍ),
						'other' => q({0} yisantimitren uzmir-kraḍ),
						'per' => q({0} i usantimitr uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cubic-foot' => {
						'name' => q(iḍarren uzmir-kraḍ),
						'one' => q({0} uḍar uzmir-kraḍ),
						'other' => q({0} yiḍarren uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-foot' => {
						'name' => q(iḍarren uzmir-kraḍ),
						'one' => q({0} uḍar uzmir-kraḍ),
						'other' => q({0} yiḍarren uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cubic-inch' => {
						'name' => q(idebbuzen uzmir-kraḍ),
						'one' => q({0} udebbuz uzmir-kraḍ),
						'other' => q({0} yidebbuzen uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-inch' => {
						'name' => q(idebbuzen uzmir-kraḍ),
						'one' => q({0} udebbuz uzmir-kraḍ),
						'other' => q({0} yidebbuzen uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cubic-kilometer' => {
						'name' => q(ikilumitren uzmir-kraḍ),
						'one' => q({0} n ukilumitr uzmir-kraḍ),
						'other' => q({0} n yikilumitren uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-kilometer' => {
						'name' => q(ikilumitren uzmir-kraḍ),
						'one' => q({0} n ukilumitr uzmir-kraḍ),
						'other' => q({0} n yikilumitren uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cubic-meter' => {
						'name' => q(imitren uzmir-kraḍ),
						'one' => q({0} umitr uzmir-kraḍ),
						'other' => q({0} yimitren uzmir-kraḍ),
						'per' => q({0} i umitr uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-meter' => {
						'name' => q(imitren uzmir-kraḍ),
						'one' => q({0} umitr uzmir-kraḍ),
						'other' => q({0} yimitren uzmir-kraḍ),
						'per' => q({0} i umitr uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cubic-mile' => {
						'name' => q(imilen uzmir-kraḍ),
						'one' => q({0} umil uzmir-kraḍ),
						'other' => q({0} yimilen uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-mile' => {
						'name' => q(imilen uzmir-kraḍ),
						'one' => q({0} umil uzmir-kraḍ),
						'other' => q({0} yimilen uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cubic-yard' => {
						'name' => q(iyaṛden uzmir-kraḍ),
						'one' => q({0} uyaṛd uzmir-kraḍ),
						'other' => q({0} yiyaṛden uzmir-kraḍ),
					},
					# Core Unit Identifier
					'cubic-yard' => {
						'name' => q(iyaṛden uzmir-kraḍ),
						'one' => q({0} uyaṛd uzmir-kraḍ),
						'other' => q({0} yiyaṛden uzmir-kraḍ),
					},
					# Long Unit Identifier
					'volume-cup' => {
						'one' => q({0} n ufenjal),
						'other' => q({0} n yifenjalen),
					},
					# Core Unit Identifier
					'cup' => {
						'one' => q({0} n ufenjal),
						'other' => q({0} n yifenjalen),
					},
					# Long Unit Identifier
					'volume-cup-metric' => {
						'name' => q(ifenjalen imitranen),
						'one' => q({0} n ufenjal amitran),
						'other' => q({0} n yifenjalen imitranen),
					},
					# Core Unit Identifier
					'cup-metric' => {
						'name' => q(ifenjalen imitranen),
						'one' => q({0} n ufenjal amitran),
						'other' => q({0} n yifenjalen imitranen),
					},
					# Long Unit Identifier
					'volume-deciliter' => {
						'name' => q(idisilitren),
						'one' => q({0} n udisiliter),
						'other' => q({0} n yidisiltren),
					},
					# Core Unit Identifier
					'deciliter' => {
						'name' => q(idisilitren),
						'one' => q({0} n udisiliter),
						'other' => q({0} n yidisiltren),
					},
					# Long Unit Identifier
					'volume-dram' => {
						'name' => q(adram),
					},
					# Core Unit Identifier
					'dram' => {
						'name' => q(adram),
					},
					# Long Unit Identifier
					'volume-drop' => {
						'one' => q({0} n tiqqit),
						'other' => q({0} n tmiqqwa),
					},
					# Core Unit Identifier
					'drop' => {
						'one' => q({0} n tiqqit),
						'other' => q({0} n tmiqqwa),
					},
					# Long Unit Identifier
					'volume-gallon' => {
						'name' => q(Igalunen),
						'one' => q({0} n ugalun),
						'other' => q({0} n yigalunen),
						'per' => q({0} deg ugalun),
					},
					# Core Unit Identifier
					'gallon' => {
						'name' => q(Igalunen),
						'one' => q({0} n ugalun),
						'other' => q({0} n yigalunen),
						'per' => q({0} deg ugalun),
					},
					# Long Unit Identifier
					'volume-gallon-imperial' => {
						'name' => q(Igalunen Imp.),
						'one' => q({0} n ugalun Imp.),
						'other' => q({0} n yigalunen Imp.),
						'per' => q({0} deg ugalun Imp.),
					},
					# Core Unit Identifier
					'gallon-imperial' => {
						'name' => q(Igalunen Imp.),
						'one' => q({0} n ugalun Imp.),
						'other' => q({0} n yigalunen Imp.),
						'per' => q({0} deg ugalun Imp.),
					},
					# Long Unit Identifier
					'volume-hectoliter' => {
						'name' => q(ihiktulitren),
						'one' => q({0} n uhiktuliter),
						'other' => q({0} n yihiktulitren),
					},
					# Core Unit Identifier
					'hectoliter' => {
						'name' => q(ihiktulitren),
						'one' => q({0} n uhiktuliter),
						'other' => q({0} n yihiktulitren),
					},
					# Long Unit Identifier
					'volume-liter' => {
						'one' => q({0} n litra),
						'other' => q({0} n litrat),
						'per' => q({0} deg litra),
					},
					# Core Unit Identifier
					'liter' => {
						'one' => q({0} n litra),
						'other' => q({0} n litrat),
						'per' => q({0} deg litra),
					},
					# Long Unit Identifier
					'volume-megaliter' => {
						'name' => q(imigalitren),
						'one' => q({0} umigaliter),
						'other' => q({0} yimigalitren),
					},
					# Core Unit Identifier
					'megaliter' => {
						'name' => q(imigalitren),
						'one' => q({0} umigaliter),
						'other' => q({0} yimigalitren),
					},
					# Long Unit Identifier
					'volume-milliliter' => {
						'name' => q(imililitren),
						'one' => q({0} n umililiter),
						'other' => q({0} n yimililitren),
					},
					# Core Unit Identifier
					'milliliter' => {
						'name' => q(imililitren),
						'one' => q({0} n umililiter),
						'other' => q({0} n yimililitren),
					},
					# Long Unit Identifier
					'volume-pint' => {
						'one' => q({0} n upint),
						'other' => q({0} n yipinten),
					},
					# Core Unit Identifier
					'pint' => {
						'one' => q({0} n upint),
						'other' => q({0} n yipinten),
					},
					# Long Unit Identifier
					'volume-pint-metric' => {
						'name' => q(ipinten imitranen),
						'one' => q({0} n upint amitran),
						'other' => q({0} n yipinten imitranen),
					},
					# Core Unit Identifier
					'pint-metric' => {
						'name' => q(ipinten imitranen),
						'one' => q({0} n upint amitran),
						'other' => q({0} n yipinten imitranen),
					},
					# Long Unit Identifier
					'volume-quart' => {
						'name' => q(ifkuẓen),
						'one' => q({0} n ufkuẓ),
						'other' => q({0} n yifkuẓen),
					},
					# Core Unit Identifier
					'quart' => {
						'name' => q(ifkuẓen),
						'one' => q({0} n ufkuẓ),
						'other' => q({0} n yifkuẓen),
					},
					# Long Unit Identifier
					'volume-quart-imperial' => {
						'name' => q(afkuẓ Imp.),
						'one' => q({0} n ufkuẓ Imp.),
						'other' => q({0} n ufkuẓ Imp.),
					},
					# Core Unit Identifier
					'quart-imperial' => {
						'name' => q(afkuẓ Imp.),
						'one' => q({0} n ufkuẓ Imp.),
						'other' => q({0} n ufkuẓ Imp.),
					},
					# Long Unit Identifier
					'volume-tablespoon' => {
						'name' => q(tiɣenjawin n wučči),
						'one' => q({0} n tɣenjawt n wučči),
						'other' => q({0} n tɣenjawin n wučči),
					},
					# Core Unit Identifier
					'tablespoon' => {
						'name' => q(tiɣenjawin n wučči),
						'one' => q({0} n tɣenjawt n wučči),
						'other' => q({0} n tɣenjawin n wučči),
					},
					# Long Unit Identifier
					'volume-teaspoon' => {
						'name' => q(tiɣenjawin n lqahwa),
						'one' => q({0} n tɣenjawt n lqahwa),
						'other' => q({0} n tɣenjawin n lqahwa),
					},
					# Core Unit Identifier
					'teaspoon' => {
						'name' => q(tiɣenjawin n lqahwa),
						'one' => q({0} n tɣenjawt n lqahwa),
						'other' => q({0} n tɣenjawin n lqahwa),
					},
				},
				'narrow' => {
					# Long Unit Identifier
					'area-dunam' => {
						'one' => q({0}udunam),
						'other' => q({0}udunam),
					},
					# Core Unit Identifier
					'dunam' => {
						'one' => q({0}udunam),
						'other' => q({0}udunam),
					},
					# Long Unit Identifier
					'consumption-mile-per-gallon-imperial' => {
						'one' => q({0}m/gUK),
						'other' => q({0}m/gUK),
					},
					# Core Unit Identifier
					'mile-per-gallon-imperial' => {
						'one' => q({0}m/gUK),
						'other' => q({0}m/gUK),
					},
					# Long Unit Identifier
					'coordinate' => {
						'east' => q({0}SM),
						'north' => q({0}GF),
						'south' => q({0}NZ),
						'west' => q({0}ML),
					},
					# Core Unit Identifier
					'coordinate' => {
						'east' => q({0}SM),
						'north' => q({0}GF),
						'south' => q({0}NZ),
						'west' => q({0}ML),
					},
					# Long Unit Identifier
					'digital-byte' => {
						'one' => q({0}aṭ),
						'other' => q({0}Aṭ),
					},
					# Core Unit Identifier
					'byte' => {
						'one' => q({0}aṭ),
						'other' => q({0}Aṭ),
					},
					# Long Unit Identifier
					'duration-day' => {
						'name' => q(ass),
						'one' => q({0}s),
						'other' => q({0}s),
					},
					# Core Unit Identifier
					'day' => {
						'name' => q(ass),
						'one' => q({0}s),
						'other' => q({0}s),
					},
					# Long Unit Identifier
					'duration-hour' => {
						'name' => q(asrag),
						'one' => q({0}r),
						'other' => q({0}r),
					},
					# Core Unit Identifier
					'hour' => {
						'name' => q(asrag),
						'one' => q({0}r),
						'other' => q({0}r),
					},
					# Long Unit Identifier
					'duration-millisecond' => {
						'name' => q(mtsn),
					},
					# Core Unit Identifier
					'millisecond' => {
						'name' => q(mtsn),
					},
					# Long Unit Identifier
					'duration-minute' => {
						'name' => q(tsd),
						'one' => q({0}d),
						'other' => q({0}d),
					},
					# Core Unit Identifier
					'minute' => {
						'name' => q(tsd),
						'one' => q({0}d),
						'other' => q({0}d),
					},
					# Long Unit Identifier
					'duration-month' => {
						'name' => q(ayyur),
						'one' => q({0}y),
						'other' => q({0}y),
					},
					# Core Unit Identifier
					'month' => {
						'name' => q(ayyur),
						'one' => q({0}y),
						'other' => q({0}y),
					},
					# Long Unit Identifier
					'duration-second' => {
						'name' => q(tsn),
						'one' => q({0}n),
						'other' => q({0}n),
					},
					# Core Unit Identifier
					'second' => {
						'name' => q(tsn),
						'one' => q({0}n),
						'other' => q({0}n),
					},
					# Long Unit Identifier
					'duration-week' => {
						'name' => q(ml),
						'one' => q({0}m),
						'other' => q({0}m),
					},
					# Core Unit Identifier
					'week' => {
						'name' => q(ml),
						'one' => q({0}m),
						'other' => q({0}m),
					},
					# Long Unit Identifier
					'duration-year' => {
						'name' => q(sg),
						'one' => q({0}g),
						'other' => q({0}g),
					},
					# Core Unit Identifier
					'year' => {
						'name' => q(sg),
						'one' => q({0}g),
						'other' => q({0}g),
					},
					# Long Unit Identifier
					'force-kilowatt-hour-per-100-kilometer' => {
						'one' => q({0}kWh/100km),
						'other' => q({0}kWh/100km),
					},
					# Core Unit Identifier
					'kilowatt-hour-per-100-kilometer' => {
						'one' => q({0}kWh/100km),
						'other' => q({0}kWh/100km),
					},
					# Long Unit Identifier
					'graphics-dot' => {
						'name' => q(taneqqiḍt),
						'one' => q({0}tneqqiḍt),
						'other' => q({0}tneqqiḍt),
					},
					# Core Unit Identifier
					'dot' => {
						'name' => q(taneqqiḍt),
						'one' => q({0}tneqqiḍt),
						'other' => q({0}tneqqiḍt),
					},
					# Long Unit Identifier
					'graphics-megapixel' => {
						'name' => q(MP),
					},
					# Core Unit Identifier
					'megapixel' => {
						'name' => q(MP),
					},
					# Long Unit Identifier
					'graphics-pixel' => {
						'name' => q(pks),
					},
					# Core Unit Identifier
					'pixel' => {
						'name' => q(pks),
					},
					# Long Unit Identifier
					'length-centimeter' => {
						'one' => q({0}sm),
						'other' => q({0}sm),
					},
					# Core Unit Identifier
					'centimeter' => {
						'one' => q({0}sm),
						'other' => q({0}sm),
					},
					# Long Unit Identifier
					'length-kilometer' => {
						'one' => q({0}km),
						'other' => q({0}km),
					},
					# Core Unit Identifier
					'kilometer' => {
						'one' => q({0}km),
						'other' => q({0}km),
					},
					# Long Unit Identifier
					'length-light-year' => {
						'name' => q(gf),
					},
					# Core Unit Identifier
					'light-year' => {
						'name' => q(gf),
					},
					# Long Unit Identifier
					'length-mile' => {
						'one' => q({0}mi),
						'other' => q({0}mi),
					},
					# Core Unit Identifier
					'mile' => {
						'one' => q({0}mi),
						'other' => q({0}mi),
					},
					# Long Unit Identifier
					'length-millimeter' => {
						'one' => q({0}mm),
						'other' => q({0}mm),
					},
					# Core Unit Identifier
					'millimeter' => {
						'one' => q({0}mm),
						'other' => q({0}mm),
					},
					# Long Unit Identifier
					'length-parsec' => {
						'name' => q(aparsik),
						'one' => q({0}ps),
						'other' => q({0}ps),
					},
					# Core Unit Identifier
					'parsec' => {
						'name' => q(aparsik),
						'one' => q({0}ps),
						'other' => q({0}ps),
					},
					# Long Unit Identifier
					'length-picometer' => {
						'one' => q({0}pm),
						'other' => q({0}pm),
					},
					# Core Unit Identifier
					'picometer' => {
						'one' => q({0}pm),
						'other' => q({0}pm),
					},
					# Long Unit Identifier
					'mass-gram' => {
						'name' => q(grm),
					},
					# Core Unit Identifier
					'gram' => {
						'name' => q(grm),
					},
					# Long Unit Identifier
					'speed-kilometer-per-hour' => {
						'name' => q(km/sr),
						'one' => q({0}km/sr),
						'other' => q({0}km/sr),
					},
					# Core Unit Identifier
					'kilometer-per-hour' => {
						'name' => q(km/sr),
						'one' => q({0}km/sr),
						'other' => q({0}km/sr),
					},
					# Long Unit Identifier
					'temperature-celsius' => {
						'name' => q(℃),
						'one' => q({0}℃),
						'other' => q({0}℃),
					},
					# Core Unit Identifier
					'celsius' => {
						'name' => q(℃),
						'one' => q({0}℃),
						'other' => q({0}℃),
					},
					# Long Unit Identifier
					'volume-cubic-foot' => {
						'name' => q(ḍr³),
						'one' => q({0}ḍr³),
						'other' => q({0}ḍr³),
					},
					# Core Unit Identifier
					'cubic-foot' => {
						'name' => q(ḍr³),
						'one' => q({0}ḍr³),
						'other' => q({0}ḍr³),
					},
					# Long Unit Identifier
					'volume-cubic-inch' => {
						'name' => q(db³),
						'one' => q({0}db³),
						'other' => q({0}db³),
					},
					# Core Unit Identifier
					'cubic-inch' => {
						'name' => q(db³),
						'one' => q({0}db³),
						'other' => q({0}db³),
					},
					# Long Unit Identifier
					'volume-cubic-kilometer' => {
						'one' => q({0}km³),
						'other' => q({0}km³),
					},
					# Core Unit Identifier
					'cubic-kilometer' => {
						'one' => q({0}km³),
						'other' => q({0}km³),
					},
					# Long Unit Identifier
					'volume-cubic-mile' => {
						'one' => q({0}mi³),
						'other' => q({0}mi³),
					},
					# Core Unit Identifier
					'cubic-mile' => {
						'one' => q({0}mi³),
						'other' => q({0}mi³),
					},
					# Long Unit Identifier
					'volume-cubic-yard' => {
						'name' => q(yd³),
						'one' => q({0}yd³),
						'other' => q({0}yd³),
					},
					# Core Unit Identifier
					'cubic-yard' => {
						'name' => q(yd³),
						'one' => q({0}yd³),
						'other' => q({0}yd³),
					},
					# Long Unit Identifier
					'volume-dessert-spoon-imperial' => {
						'one' => q({0}dsp-Imp),
						'other' => q({0}dsp-Imp),
					},
					# Core Unit Identifier
					'dessert-spoon-imperial' => {
						'one' => q({0}dsp-Imp),
						'other' => q({0}dsp-Imp),
					},
					# Long Unit Identifier
					'volume-fluid-ounce-imperial' => {
						'one' => q({0}fl oz Im),
						'other' => q({0}fl oz Im),
					},
					# Core Unit Identifier
					'fluid-ounce-imperial' => {
						'one' => q({0}fl oz Im),
						'other' => q({0}fl oz Im),
					},
					# Long Unit Identifier
					'volume-gallon-imperial' => {
						'one' => q({0}galIm),
						'other' => q({0}galIm),
					},
					# Core Unit Identifier
					'gallon-imperial' => {
						'one' => q({0}galIm),
						'other' => q({0}galIm),
					},
					# Long Unit Identifier
					'volume-liter' => {
						'name' => q(litra),
						'one' => q({0} L),
						'other' => q({0}L),
					},
					# Core Unit Identifier
					'liter' => {
						'name' => q(litra),
						'one' => q({0} L),
						'other' => q({0}L),
					},
					# Long Unit Identifier
					'volume-megaliter' => {
						'one' => q({0}ML),
						'other' => q({0}ML),
					},
					# Core Unit Identifier
					'megaliter' => {
						'one' => q({0}ML),
						'other' => q({0}ML),
					},
					# Long Unit Identifier
					'volume-pinch' => {
						'name' => q(pn),
					},
					# Core Unit Identifier
					'pinch' => {
						'name' => q(pn),
					},
				},
				'short' => {
					# Long Unit Identifier
					'' => {
						'name' => q(tanila),
					},
					# Core Unit Identifier
					'' => {
						'name' => q(tanila),
					},
					# Long Unit Identifier
					'acceleration-meter-per-square-second' => {
						'name' => q(mitrat/sec²),
					},
					# Core Unit Identifier
					'meter-per-square-second' => {
						'name' => q(mitrat/sec²),
					},
					# Long Unit Identifier
					'angle-degree' => {
						'name' => q(tifesniwin),
						'one' => q({0} fsn),
						'other' => q({0} fsn),
					},
					# Core Unit Identifier
					'degree' => {
						'name' => q(tifesniwin),
						'one' => q({0} fsn),
						'other' => q({0} fsn),
					},
					# Long Unit Identifier
					'angle-radian' => {
						'name' => q(iradyanen),
					},
					# Core Unit Identifier
					'radian' => {
						'name' => q(iradyanen),
					},
					# Long Unit Identifier
					'area-acre' => {
						'name' => q(ikṛen),
						'one' => q({0} kṛ),
						'other' => q({0} kṛ),
					},
					# Core Unit Identifier
					'acre' => {
						'name' => q(ikṛen),
						'one' => q({0} kṛ),
						'other' => q({0} kṛ),
					},
					# Long Unit Identifier
					'area-dunam' => {
						'name' => q(idunamen),
						'one' => q({0} n udunam),
						'other' => q({0} n udunam),
					},
					# Core Unit Identifier
					'dunam' => {
						'name' => q(idunamen),
						'one' => q({0} n udunam),
						'other' => q({0} n udunam),
					},
					# Long Unit Identifier
					'area-hectare' => {
						'name' => q(iktaren),
					},
					# Core Unit Identifier
					'hectare' => {
						'name' => q(iktaren),
					},
					# Long Unit Identifier
					'area-square-centimeter' => {
						'name' => q(sm²),
						'one' => q({0} sm²),
						'other' => q({0} sm²),
						'per' => q({0}/sm²),
					},
					# Core Unit Identifier
					'square-centimeter' => {
						'name' => q(sm²),
						'one' => q({0} sm²),
						'other' => q({0} sm²),
						'per' => q({0}/sm²),
					},
					# Long Unit Identifier
					'area-square-foot' => {
						'name' => q(aḍar uz.sin.),
						'one' => q({0} ḍr zm.sn.),
						'other' => q({0} ḍr zm.sn.),
					},
					# Core Unit Identifier
					'square-foot' => {
						'name' => q(aḍar uz.sin.),
						'one' => q({0} ḍr zm.sn.),
						'other' => q({0} ḍr zm.sn.),
					},
					# Long Unit Identifier
					'area-square-inch' => {
						'name' => q(idebbuzen²),
						'one' => q({0} db²),
						'other' => q({0} db²),
						'per' => q({0}/db²),
					},
					# Core Unit Identifier
					'square-inch' => {
						'name' => q(idebbuzen²),
						'one' => q({0} db²),
						'other' => q({0} db²),
						'per' => q({0}/db²),
					},
					# Long Unit Identifier
					'area-square-mile' => {
						'name' => q(imlen uz.sin.),
						'one' => q({0} mi uz.sin.),
						'other' => q({0} mi uz.sin.),
					},
					# Core Unit Identifier
					'square-mile' => {
						'name' => q(imlen uz.sin.),
						'one' => q({0} mi uz.sin.),
						'other' => q({0} mi uz.sin.),
					},
					# Long Unit Identifier
					'area-square-yard' => {
						'name' => q(iyarden²),
					},
					# Core Unit Identifier
					'square-yard' => {
						'name' => q(iyarden²),
					},
					# Long Unit Identifier
					'concentr-percent' => {
						'one' => q({0} %),
						'other' => q({0} %),
					},
					# Core Unit Identifier
					'percent' => {
						'one' => q({0} %),
						'other' => q({0} %),
					},
					# Long Unit Identifier
					'concentr-permyriad' => {
						'one' => q({0} ‱),
						'other' => q({0} ‱),
					},
					# Core Unit Identifier
					'permyriad' => {
						'one' => q({0} ‱),
						'other' => q({0} ‱),
					},
					# Long Unit Identifier
					'coordinate' => {
						'east' => q({0} SM),
						'north' => q({0} GF),
						'south' => q({0} NZ),
						'west' => q({0} ML),
					},
					# Core Unit Identifier
					'coordinate' => {
						'east' => q({0} SM),
						'north' => q({0} GF),
						'south' => q({0} NZ),
						'west' => q({0} ML),
					},
					# Long Unit Identifier
					'digital-bit' => {
						'name' => q(abit),
						'one' => q({0} abit),
						'other' => q({0} ibiten),
					},
					# Core Unit Identifier
					'bit' => {
						'name' => q(abit),
						'one' => q({0} abit),
						'other' => q({0} ibiten),
					},
					# Long Unit Identifier
					'digital-byte' => {
						'name' => q(aṭamḍan),
						'one' => q({0} aṭ),
						'other' => q({0} Aṭ),
					},
					# Core Unit Identifier
					'byte' => {
						'name' => q(aṭamḍan),
						'one' => q({0} aṭ),
						'other' => q({0} Aṭ),
					},
					# Long Unit Identifier
					'digital-gigabit' => {
						'name' => q(Gbit),
					},
					# Core Unit Identifier
					'gigabit' => {
						'name' => q(Gbit),
					},
					# Long Unit Identifier
					'digital-gigabyte' => {
						'name' => q(GAṬM),
						'one' => q({0} GAṬ),
						'other' => q({0} GAṬ),
					},
					# Core Unit Identifier
					'gigabyte' => {
						'name' => q(GAṬM),
						'one' => q({0} GAṬ),
						'other' => q({0} GAṬ),
					},
					# Long Unit Identifier
					'digital-kilobit' => {
						'name' => q(kbit),
					},
					# Core Unit Identifier
					'kilobit' => {
						'name' => q(kbit),
					},
					# Long Unit Identifier
					'digital-kilobyte' => {
						'name' => q(kAṬ),
						'one' => q({0} kAṬ),
						'other' => q({0} kAṬ),
					},
					# Core Unit Identifier
					'kilobyte' => {
						'name' => q(kAṬ),
						'one' => q({0} kAṬ),
						'other' => q({0} kAṬ),
					},
					# Long Unit Identifier
					'digital-megabit' => {
						'name' => q(Mbit),
					},
					# Core Unit Identifier
					'megabit' => {
						'name' => q(Mbit),
					},
					# Long Unit Identifier
					'digital-megabyte' => {
						'name' => q(MAṬ),
						'one' => q({0} MAṬ),
						'other' => q({0} MAṬ),
					},
					# Core Unit Identifier
					'megabyte' => {
						'name' => q(MAṬ),
						'one' => q({0} MAṬ),
						'other' => q({0} MAṬ),
					},
					# Long Unit Identifier
					'digital-terabit' => {
						'name' => q(Tbit),
					},
					# Core Unit Identifier
					'terabit' => {
						'name' => q(Tbit),
					},
					# Long Unit Identifier
					'digital-terabyte' => {
						'one' => q({0} TAṬ),
						'other' => q({0} TAṬ),
					},
					# Core Unit Identifier
					'terabyte' => {
						'one' => q({0} TAṬ),
						'other' => q({0} TAṬ),
					},
					# Long Unit Identifier
					'duration-century' => {
						'name' => q(st),
						'one' => q({0} st),
						'other' => q({0} st),
					},
					# Core Unit Identifier
					'century' => {
						'name' => q(st),
						'one' => q({0} st),
						'other' => q({0} st),
					},
					# Long Unit Identifier
					'duration-day' => {
						'name' => q(ussan),
						'one' => q({0} n wass),
						'other' => q({0} n wussan),
						'per' => q({0}/s),
					},
					# Core Unit Identifier
					'day' => {
						'name' => q(ussan),
						'one' => q({0} n wass),
						'other' => q({0} n wussan),
						'per' => q({0}/s),
					},
					# Long Unit Identifier
					'duration-decade' => {
						'name' => q(mrw),
						'one' => q({0} mrw),
						'other' => q({0} mrw),
					},
					# Core Unit Identifier
					'decade' => {
						'name' => q(mrw),
						'one' => q({0} mrw),
						'other' => q({0} mrw),
					},
					# Long Unit Identifier
					'duration-hour' => {
						'name' => q(isragen),
						'one' => q({0} sr),
						'other' => q({0} sr),
						'per' => q({0}/r),
					},
					# Core Unit Identifier
					'hour' => {
						'name' => q(isragen),
						'one' => q({0} sr),
						'other' => q({0} sr),
						'per' => q({0}/r),
					},
					# Long Unit Identifier
					'duration-microsecond' => {
						'name' => q(μtsn),
						'one' => q({0} μn),
						'other' => q({0} μn),
					},
					# Core Unit Identifier
					'microsecond' => {
						'name' => q(μtsn),
						'one' => q({0} μn),
						'other' => q({0} μn),
					},
					# Long Unit Identifier
					'duration-millisecond' => {
						'name' => q(timilisn),
						'one' => q({0} mn),
						'other' => q({0} mn),
					},
					# Core Unit Identifier
					'millisecond' => {
						'name' => q(timilisn),
						'one' => q({0} mn),
						'other' => q({0} mn),
					},
					# Long Unit Identifier
					'duration-minute' => {
						'name' => q(tsdn),
						'one' => q({0} tsd),
						'other' => q({0} tsd),
						'per' => q({0}/tsd),
					},
					# Core Unit Identifier
					'minute' => {
						'name' => q(tsdn),
						'one' => q({0} tsd),
						'other' => q({0} tsd),
						'per' => q({0}/tsd),
					},
					# Long Unit Identifier
					'duration-month' => {
						'name' => q(ayyuren),
						'one' => q({0} yyr),
						'other' => q({0} yyrn),
						'per' => q({0}/y),
					},
					# Core Unit Identifier
					'month' => {
						'name' => q(ayyuren),
						'one' => q({0} yyr),
						'other' => q({0} yyrn),
						'per' => q({0}/y),
					},
					# Long Unit Identifier
					'duration-nanosecond' => {
						'name' => q(nanutsn),
						'one' => q({0} nn),
						'other' => q({0} nn),
					},
					# Core Unit Identifier
					'nanosecond' => {
						'name' => q(nanutsn),
						'one' => q({0} nn),
						'other' => q({0} nn),
					},
					# Long Unit Identifier
					'duration-second' => {
						'name' => q(tisn),
						'one' => q({0} tsn),
						'other' => q({0} tsn),
						'per' => q({0}/n),
					},
					# Core Unit Identifier
					'second' => {
						'name' => q(tisn),
						'one' => q({0} tsn),
						'other' => q({0} tsn),
						'per' => q({0}/n),
					},
					# Long Unit Identifier
					'duration-week' => {
						'name' => q(imalasen),
						'one' => q({0} ml),
						'other' => q({0} mln),
						'per' => q({0}/m),
					},
					# Core Unit Identifier
					'week' => {
						'name' => q(imalasen),
						'one' => q({0} ml),
						'other' => q({0} mln),
						'per' => q({0}/m),
					},
					# Long Unit Identifier
					'duration-year' => {
						'name' => q(iseggasen),
						'one' => q({0} sg),
						'other' => q({0} sgn),
						'per' => q({0}/g),
					},
					# Core Unit Identifier
					'year' => {
						'name' => q(iseggasen),
						'one' => q({0} sg),
						'other' => q({0} sgn),
						'per' => q({0}/g),
					},
					# Long Unit Identifier
					'energy-calorie' => {
						'name' => q(kal),
						'one' => q({0} kal),
						'other' => q({0} kal),
					},
					# Core Unit Identifier
					'calorie' => {
						'name' => q(kal),
						'one' => q({0} kal),
						'other' => q({0} kal),
					},
					# Long Unit Identifier
					'energy-foodcalorie' => {
						'name' => q(kal),
						'one' => q({0} kal),
						'other' => q({0} kal),
					},
					# Core Unit Identifier
					'foodcalorie' => {
						'name' => q(kal),
						'one' => q({0} kal),
						'other' => q({0} kal),
					},
					# Long Unit Identifier
					'energy-joule' => {
						'name' => q(ijulen),
					},
					# Core Unit Identifier
					'joule' => {
						'name' => q(ijulen),
					},
					# Long Unit Identifier
					'energy-kilocalorie' => {
						'name' => q(kkal),
						'one' => q({0} kkal),
						'other' => q({0} kkal),
					},
					# Core Unit Identifier
					'kilocalorie' => {
						'name' => q(kkal),
						'one' => q({0} kkal),
						'other' => q({0} kkal),
					},
					# Long Unit Identifier
					'energy-kilojoule' => {
						'name' => q(akilujul),
					},
					# Core Unit Identifier
					'kilojoule' => {
						'name' => q(akilujul),
					},
					# Long Unit Identifier
					'graphics-dot-per-centimeter' => {
						'name' => q(nqsm),
						'one' => q({0} nqsm),
						'other' => q({0} nqsm),
					},
					# Core Unit Identifier
					'dot-per-centimeter' => {
						'name' => q(nqsm),
						'one' => q({0} nqsm),
						'other' => q({0} nqsm),
					},
					# Long Unit Identifier
					'graphics-dot-per-inch' => {
						'name' => q(nqd),
						'one' => q({0} nqd),
						'other' => q({0} nqd),
					},
					# Core Unit Identifier
					'dot-per-inch' => {
						'name' => q(nqd),
						'one' => q({0} nqd),
						'other' => q({0} nqd),
					},
					# Long Unit Identifier
					'graphics-megapixel' => {
						'name' => q(imigapiksilen),
					},
					# Core Unit Identifier
					'megapixel' => {
						'name' => q(imigapiksilen),
					},
					# Long Unit Identifier
					'graphics-pixel' => {
						'name' => q(ipiksilen),
						'one' => q({0} pks),
						'other' => q({0} pks),
					},
					# Core Unit Identifier
					'pixel' => {
						'name' => q(ipiksilen),
						'one' => q({0} pks),
						'other' => q({0} pks),
					},
					# Long Unit Identifier
					'graphics-pixel-per-centimeter' => {
						'name' => q(ppsm),
						'one' => q({0} ppsm),
						'other' => q({0} ppsm),
					},
					# Core Unit Identifier
					'pixel-per-centimeter' => {
						'name' => q(ppsm),
						'one' => q({0} ppsm),
						'other' => q({0} ppsm),
					},
					# Long Unit Identifier
					'length-astronomical-unit' => {
						'name' => q(fl),
						'one' => q({0} fl),
						'other' => q({0} fl),
					},
					# Core Unit Identifier
					'astronomical-unit' => {
						'name' => q(fl),
						'one' => q({0} fl),
						'other' => q({0} fl),
					},
					# Long Unit Identifier
					'length-centimeter' => {
						'name' => q(sm),
						'one' => q({0} sm),
						'other' => q({0} sm),
						'per' => q({0}/sm),
					},
					# Core Unit Identifier
					'centimeter' => {
						'name' => q(sm),
						'one' => q({0} sm),
						'other' => q({0} sm),
						'per' => q({0}/sm),
					},
					# Long Unit Identifier
					'length-foot' => {
						'name' => q(iḍarren),
						'one' => q({0} ḍr),
						'other' => q({0} ḍr),
						'per' => q({0}/ḍr),
					},
					# Core Unit Identifier
					'foot' => {
						'name' => q(iḍarren),
						'one' => q({0} ḍr),
						'other' => q({0} ḍr),
						'per' => q({0}/ḍr),
					},
					# Long Unit Identifier
					'length-inch' => {
						'name' => q(idebbuzen),
						'one' => q({0} db),
						'other' => q({0} db),
						'per' => q({0}/db),
					},
					# Core Unit Identifier
					'inch' => {
						'name' => q(idebbuzen),
						'one' => q({0} db),
						'other' => q({0} db),
						'per' => q({0}/db),
					},
					# Long Unit Identifier
					'length-light-year' => {
						'name' => q(sgs n tafat),
						'one' => q({0} gf),
						'other' => q({0} gf),
					},
					# Core Unit Identifier
					'light-year' => {
						'name' => q(sgs n tafat),
						'one' => q({0} gf),
						'other' => q({0} gf),
					},
					# Long Unit Identifier
					'length-meter' => {
						'name' => q(m),
					},
					# Core Unit Identifier
					'meter' => {
						'name' => q(m),
					},
					# Long Unit Identifier
					'length-micrometer' => {
						'name' => q(μmitr),
					},
					# Core Unit Identifier
					'micrometer' => {
						'name' => q(μmitr),
					},
					# Long Unit Identifier
					'length-mile' => {
						'name' => q(imilen),
					},
					# Core Unit Identifier
					'mile' => {
						'name' => q(imilen),
					},
					# Long Unit Identifier
					'length-mile-scandinavian' => {
						'name' => q(mis),
						'one' => q({0} mis),
						'other' => q({0} mis),
					},
					# Core Unit Identifier
					'mile-scandinavian' => {
						'name' => q(mis),
						'one' => q({0} mis),
						'other' => q({0} mis),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'name' => q(miw),
						'one' => q({0} miw),
						'other' => q({0} miw),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'name' => q(miw),
						'one' => q({0} miw),
						'other' => q({0} miw),
					},
					# Long Unit Identifier
					'length-parsec' => {
						'name' => q(iparsiken),
						'one' => q({0} ps),
						'other' => q({0} ps),
					},
					# Core Unit Identifier
					'parsec' => {
						'name' => q(iparsiken),
						'one' => q({0} ps),
						'other' => q({0} ps),
					},
					# Long Unit Identifier
					'length-point' => {
						'name' => q(tineqqiḍin),
						'one' => q({0} nq),
						'other' => q({0} nq),
					},
					# Core Unit Identifier
					'point' => {
						'name' => q(tineqqiḍin),
						'one' => q({0} nq),
						'other' => q({0} nq),
					},
					# Long Unit Identifier
					'length-yard' => {
						'name' => q(iyarden),
					},
					# Core Unit Identifier
					'yard' => {
						'name' => q(iyarden),
					},
					# Long Unit Identifier
					'light-lux' => {
						'name' => q(lks),
						'one' => q({0} ks),
						'other' => q({0} ks),
					},
					# Core Unit Identifier
					'lux' => {
						'name' => q(lks),
						'one' => q({0} ks),
						'other' => q({0} ks),
					},
					# Long Unit Identifier
					'mass-gram' => {
						'name' => q(grmn),
					},
					# Core Unit Identifier
					'gram' => {
						'name' => q(grmn),
					},
					# Long Unit Identifier
					'mass-pound' => {
						'name' => q(ipunden),
					},
					# Core Unit Identifier
					'pound' => {
						'name' => q(ipunden),
					},
					# Long Unit Identifier
					'mass-ton' => {
						'name' => q(iṭunen),
					},
					# Core Unit Identifier
					'ton' => {
						'name' => q(iṭunen),
					},
					# Long Unit Identifier
					'power-watt' => {
						'name' => q(waṭ),
					},
					# Core Unit Identifier
					'watt' => {
						'name' => q(waṭ),
					},
					# Long Unit Identifier
					'speed-kilometer-per-hour' => {
						'name' => q(km/asrag),
						'one' => q({0} km/sr),
						'other' => q({0} km/sr),
					},
					# Core Unit Identifier
					'kilometer-per-hour' => {
						'name' => q(km/asrag),
						'one' => q({0} km/sr),
						'other' => q({0} km/sr),
					},
					# Long Unit Identifier
					'speed-knot' => {
						'name' => q(krs),
						'one' => q({0} krs),
						'other' => q({0} krs),
					},
					# Core Unit Identifier
					'knot' => {
						'name' => q(krs),
						'one' => q({0} krs),
						'other' => q({0} krs),
					},
					# Long Unit Identifier
					'speed-meter-per-second' => {
						'name' => q(mitrat/tsn),
					},
					# Core Unit Identifier
					'meter-per-second' => {
						'name' => q(mitrat/tsn),
					},
					# Long Unit Identifier
					'speed-mile-per-hour' => {
						'name' => q(imilen/asrag),
						'one' => q({0} mi/sr),
						'other' => q({0} mi/sr),
					},
					# Core Unit Identifier
					'mile-per-hour' => {
						'name' => q(imilen/asrag),
						'one' => q({0} mi/sr),
						'other' => q({0} mi/sr),
					},
					# Long Unit Identifier
					'temperature-celsius' => {
						'one' => q({0} ℃),
						'other' => q({0} ℃),
					},
					# Core Unit Identifier
					'celsius' => {
						'one' => q({0} ℃),
						'other' => q({0} ℃),
					},
					# Long Unit Identifier
					'temperature-fahrenheit' => {
						'name' => q(℉),
						'one' => q({0} ℉),
						'other' => q({0} ℉),
					},
					# Core Unit Identifier
					'fahrenheit' => {
						'name' => q(℉),
						'one' => q({0} ℉),
						'other' => q({0} ℉),
					},
					# Long Unit Identifier
					'volume-acre-foot' => {
						'name' => q(akeṛ ḍr),
						'one' => q({0} kṛ ḍr),
						'other' => q({0} kṛ ḍr),
					},
					# Core Unit Identifier
					'acre-foot' => {
						'name' => q(akeṛ ḍr),
						'one' => q({0} kṛ ḍr),
						'other' => q({0} kṛ ḍr),
					},
					# Long Unit Identifier
					'volume-barrel' => {
						'name' => q(tabettit),
						'one' => q({0} btt),
						'other' => q({0} btt),
					},
					# Core Unit Identifier
					'barrel' => {
						'name' => q(tabettit),
						'one' => q({0} btt),
						'other' => q({0} btt),
					},
					# Long Unit Identifier
					'volume-centiliter' => {
						'name' => q(sL),
						'one' => q({0} sL),
						'other' => q({0} sL),
					},
					# Core Unit Identifier
					'centiliter' => {
						'name' => q(sL),
						'one' => q({0} sL),
						'other' => q({0} sL),
					},
					# Long Unit Identifier
					'volume-cubic-centimeter' => {
						'name' => q(sm³),
						'one' => q({0} sm³),
						'other' => q({0} sm³),
						'per' => q({0}/sm³),
					},
					# Core Unit Identifier
					'cubic-centimeter' => {
						'name' => q(sm³),
						'one' => q({0} sm³),
						'other' => q({0} sm³),
						'per' => q({0}/sm³),
					},
					# Long Unit Identifier
					'volume-cubic-foot' => {
						'name' => q(iḍarren³),
						'one' => q({0} ḍr³),
						'other' => q({0} ḍr³),
					},
					# Core Unit Identifier
					'cubic-foot' => {
						'name' => q(iḍarren³),
						'one' => q({0} ḍr³),
						'other' => q({0} ḍr³),
					},
					# Long Unit Identifier
					'volume-cubic-inch' => {
						'name' => q(idebbuzen³),
						'one' => q({0} db³),
						'other' => q({0} db³),
					},
					# Core Unit Identifier
					'cubic-inch' => {
						'name' => q(idebbuzen³),
						'one' => q({0} db³),
						'other' => q({0} db³),
					},
					# Long Unit Identifier
					'volume-cubic-yard' => {
						'name' => q(iyaṛden³),
					},
					# Core Unit Identifier
					'cubic-yard' => {
						'name' => q(iyaṛden³),
					},
					# Long Unit Identifier
					'volume-cup' => {
						'name' => q(ifenjalen),
						'one' => q({0} f),
						'other' => q({0} f),
					},
					# Core Unit Identifier
					'cup' => {
						'name' => q(ifenjalen),
						'one' => q({0} f),
						'other' => q({0} f),
					},
					# Long Unit Identifier
					'volume-cup-metric' => {
						'name' => q(fnjl),
						'one' => q({0} fnjl),
						'other' => q({0} fnjl),
					},
					# Core Unit Identifier
					'cup-metric' => {
						'name' => q(fnjl),
						'one' => q({0} fnjl),
						'other' => q({0} fnjl),
					},
					# Long Unit Identifier
					'volume-drop' => {
						'name' => q(tiqqit),
						'one' => q({0} n tiqqit),
						'other' => q({0} n tiqqit),
					},
					# Core Unit Identifier
					'drop' => {
						'name' => q(tiqqit),
						'one' => q({0} n tiqqit),
						'other' => q({0} n tiqqit),
					},
					# Long Unit Identifier
					'volume-gallon' => {
						'name' => q(gal),
						'one' => q({0} gal),
						'other' => q({0} gal),
						'per' => q({0}/gal MAR),
					},
					# Core Unit Identifier
					'gallon' => {
						'name' => q(gal),
						'one' => q({0} gal),
						'other' => q({0} gal),
						'per' => q({0}/gal MAR),
					},
					# Long Unit Identifier
					'volume-gallon-imperial' => {
						'name' => q(gal Imp.),
						'one' => q({0} gal imp.),
						'other' => q({0} gal imp.),
						'per' => q({0} gal imp.),
					},
					# Core Unit Identifier
					'gallon-imperial' => {
						'name' => q(gal Imp.),
						'one' => q({0} gal imp.),
						'other' => q({0} gal imp.),
						'per' => q({0} gal imp.),
					},
					# Long Unit Identifier
					'volume-jigger' => {
						'name' => q(ajiger),
						'one' => q({0} ujiger),
						'other' => q({0} ujiger),
					},
					# Core Unit Identifier
					'jigger' => {
						'name' => q(ajiger),
						'one' => q({0} ujiger),
						'other' => q({0} ujiger),
					},
					# Long Unit Identifier
					'volume-liter' => {
						'name' => q(litrat),
						'one' => q({0} L),
						'other' => q({0} L),
						'per' => q({0}/L),
					},
					# Core Unit Identifier
					'liter' => {
						'name' => q(litrat),
						'one' => q({0} L),
						'other' => q({0} L),
						'per' => q({0}/L),
					},
					# Long Unit Identifier
					'volume-pinch' => {
						'name' => q(apinč),
						'one' => q({0} upinč),
						'other' => q({0} upinč),
					},
					# Core Unit Identifier
					'pinch' => {
						'name' => q(apinč),
						'one' => q({0} upinč),
						'other' => q({0} upinč),
					},
					# Long Unit Identifier
					'volume-pint' => {
						'name' => q(ipinten),
					},
					# Core Unit Identifier
					'pint' => {
						'name' => q(ipinten),
					},
					# Long Unit Identifier
					'volume-quart' => {
						'name' => q(fkẓ),
						'one' => q({0} kẓ),
						'other' => q({0} kẓ),
					},
					# Core Unit Identifier
					'quart' => {
						'name' => q(fkẓ),
						'one' => q({0} kẓ),
						'other' => q({0} kẓ),
					},
					# Long Unit Identifier
					'volume-quart-imperial' => {
						'name' => q(kẓ Imp),
						'one' => q({0} kẓ Imp.),
						'other' => q({0} kẓ Imp.),
					},
					# Core Unit Identifier
					'quart-imperial' => {
						'name' => q(kẓ Imp),
						'one' => q({0} kẓ Imp.),
						'other' => q({0} kẓ Imp.),
					},
					# Long Unit Identifier
					'volume-tablespoon' => {
						'name' => q(ɣnjč),
						'one' => q({0} ɣnjč),
						'other' => q({0} ɣnjč),
					},
					# Core Unit Identifier
					'tablespoon' => {
						'name' => q(ɣnjč),
						'one' => q({0} ɣnjč),
						'other' => q({0} ɣnjč),
					},
					# Long Unit Identifier
					'volume-teaspoon' => {
						'name' => q(ɣnjq),
						'one' => q({0} ɣnjq),
						'other' => q({0} ɣnjq),
					},
					# Core Unit Identifier
					'teaspoon' => {
						'name' => q(ɣnjq),
						'one' => q({0} ɣnjq),
						'other' => q({0} ɣnjq),
					},
				},
			} }
);

has 'yesstr' => (
	is			=> 'ro',
	isa			=> RegexpRef,
	init_arg	=> undef,
	default		=> sub { qr'^(?i:Ih|I|yes|y)$' }
);

has 'nostr' => (
	is			=> 'ro',
	isa			=> RegexpRef,
	init_arg	=> undef,
	default		=> sub { qr'^(?i:Uhu|U|no|n)$' }
);

has 'listPatterns' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
				end => q({0}, d {1}),
				2 => q({0} d {1}),
		} }
);

has 'number_symbols' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'latn' => {
			'decimal' => q(,),
			'group' => q( ),
			'nan' => q(MdM),
		},
	} }
);

has 'number_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		decimalFormat => {
			'long' => {
				'1000' => {
					'one' => '0 n wagim',
					'other' => '0 n wagimen',
				},
				'10000' => {
					'one' => '00 n wagimen',
					'other' => '00 n wagimen',
				},
				'100000' => {
					'one' => '000 n wagimen',
					'other' => '000 n wagimen',
				},
				'1000000' => {
					'one' => '0 n umilyun',
					'other' => '0 n imelyunen',
				},
				'10000000' => {
					'one' => '00 n imelyunen',
					'other' => '00 n imelyunen',
				},
				'100000000' => {
					'one' => '000 n imelyunen',
					'other' => '000 n imelyunen',
				},
				'1000000000' => {
					'one' => '0 n umelyaṛ',
					'other' => '0 n imelyaṛen',
				},
				'10000000000' => {
					'one' => '00 n imelyaṛen',
					'other' => '00 n imelyaṛen',
				},
				'100000000000' => {
					'one' => '000 n imelyaṛen',
					'other' => '000 n imelyaṛen',
				},
				'1000000000000' => {
					'one' => '0 n utrilyun',
					'other' => '0 n itrilyunen',
				},
				'10000000000000' => {
					'one' => '00 n itrilyunen',
					'other' => '00 n itrilyunen',
				},
				'100000000000000' => {
					'one' => '000 n itrilyunen',
					'other' => '000 n itrilyunen',
				},
			},
			'short' => {
				'1000' => {
					'one' => '0G',
					'other' => '0G',
				},
				'10000' => {
					'one' => '00G',
					'other' => '00G',
				},
				'100000' => {
					'one' => '000G',
					'other' => '000G',
				},
				'1000000000' => {
					'one' => '0L',
					'other' => '0L',
				},
				'10000000000' => {
					'one' => '00L',
					'other' => '00L',
				},
				'100000000000' => {
					'one' => '000L',
					'other' => '000L',
				},
			},
		},
} },
);

has 'number_currency_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'latn' => {
			'pattern' => {
				'default' => {
					'standard' => {
						'positive' => '#,##0.00¤',
					},
				},
			},
		},
} },
);

has 'currencies' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'ADP' => {
			display_name => {
				'currency' => q(Apisetas Anduran),
				'one' => q(Apisetas Anduran),
				'other' => q(Ipisetasen Induranen),
			},
		},
		'AED' => {
			display_name => {
				'currency' => q(Adirham n Tgeldunin Taɛrabin Yedduklen),
				'one' => q(Adirham n Imarat Taɛrabin Yedduklen),
				'other' => q(Idirhamen n Imarat Taɛrabin Yedduklen),
			},
		},
		'AFA' => {
			display_name => {
				'currency' => q(Afɣani \(1927–2002\)),
				'one' => q(Afɣani \(1927–2002\)),
				'other' => q(Ifɣaniyen \(1927–2002\)),
			},
		},
		'AFN' => {
			display_name => {
				'currency' => q(Afɣani Afɣan),
				'one' => q(Afɣani Afɣan),
				'other' => q(Ifɣaniyen ifɣanen),
			},
		},
		'ALK' => {
			display_name => {
				'currency' => q(Alek Albani \(1947–1961\)),
				'one' => q(Alek Albani \(1947–1961\)),
				'other' => q(Ilekan Ilbaniyen \(1947–1961\)),
			},
		},
		'ALL' => {
			display_name => {
				'currency' => q(Alek Albani),
				'one' => q(Alek n Albanya),
				'other' => q(Ilkan n Albanya),
			},
		},
		'AMD' => {
			display_name => {
				'currency' => q(Adram Armini),
				'one' => q(Idramen Irminiyen),
				'other' => q(Adram Armini),
			},
		},
		'ANG' => {
			display_name => {
				'currency' => q(Afluran n Antilles),
				'one' => q(Afluran n Antilles),
				'other' => q(Ifluranen n Antilles),
			},
		},
		'AOA' => {
			display_name => {
				'currency' => q(Akwanza n Ungula),
				'one' => q(Akwanza n Ungula),
				'other' => q(Ikwanzayen n Ungula),
			},
		},
		'AOK' => {
			display_name => {
				'currency' => q(Akwanza n Angula \(1977–1990\)),
				'one' => q(Akwanza n Angula \(1977–1990\)),
				'other' => q(Ikwanzayen n Angula \(1977–1990\)),
			},
		},
		'AON' => {
			display_name => {
				'currency' => q(Akwanza amaynut n Angula \(1990–2000\)),
				'one' => q(Akwanza amaynut n Angula \(1990–2000\)),
				'other' => q(Ikwanzayen imaynuten n Angula \(1990–2000\)),
			},
		},
		'AOR' => {
			display_name => {
				'currency' => q(Akwanza n Angula yettwaseggmen \(1995–1999\)),
				'one' => q(Akwanza n Angula yettwaseggmen \(1995–1999\)),
				'other' => q(Ikwanzayen n Angula yettwaseggmen \(1995–1999\)),
			},
		},
		'ARA' => {
			display_name => {
				'currency' => q(Ustral n Arjuntin),
				'one' => q(Ustral n Arjuntin),
				'other' => q(Ustralen n Arjuntin),
			},
		},
		'ARL' => {
			display_name => {
				'currency' => q(Apisu aẓayan n Arjuntin \(1970–1983\)),
				'one' => q(Apisu aẓayan n Arjuntin \(1970–1983\)),
				'other' => q(Ipisuten iẓayanen n Arjuntin \(1970–1983\)),
			},
		},
		'ARM' => {
			display_name => {
				'currency' => q(Apisu n Arjuntin \(1881–1970\)),
				'one' => q(Apisu n Arjuntin \(1881–1970\)),
				'other' => q(Ipisuten n Arjuntin \(1881–1970\)),
			},
		},
		'ARP' => {
			display_name => {
				'currency' => q(Apisu n Arjuntin \(1983–1985\)),
				'one' => q(Apisu n Arjuntin \(1983–1985\)),
				'other' => q(Ipisuten n Arjuntin \(1983–1985\)),
			},
		},
		'ARS' => {
			symbol => '$AR',
			display_name => {
				'currency' => q(Apisu n Arjuntin),
				'one' => q(Apisu n Arjuntin),
				'other' => q(Ipisuten n Arjuntin),
			},
		},
		'ATS' => {
			display_name => {
				'currency' => q(Aciling n Ustriya),
				'one' => q(Aciling n Ustriya),
				'other' => q(Icilingen n Ustriya),
			},
		},
		'AUD' => {
			symbol => '$AU',
			display_name => {
				'currency' => q(Adular n Lusṭrali),
				'one' => q(Adular n Ustralya),
				'other' => q(Idularen n Ustralya),
			},
		},
		'AWG' => {
			display_name => {
				'currency' => q(Afluran n Aruba),
				'one' => q(Afluran n Aruba),
				'other' => q(Ifluranen n Aruba),
			},
		},
		'AZM' => {
			display_name => {
				'currency' => q(Amanat Aziri \(1993–2006\)),
				'one' => q(Amanat Aziri \(1993–2006\)),
				'other' => q(Imanaten Aziri \(1993–2006\)),
			},
		},
		'AZN' => {
			display_name => {
				'currency' => q(Amanat Aziri),
				'one' => q(Amanat Aziri),
				'other' => q(Imanaten Iziriyen),
			},
		},
		'BAD' => {
			display_name => {
				'currency' => q(Adinar Abusni),
				'one' => q(Adinar Abusni),
				'other' => q(Idinaren Ibusniyen),
			},
		},
		'BAM' => {
			display_name => {
				'currency' => q(Amark yettwaseklaten n Busni),
				'one' => q(Amark yettwaseklaten n Busni),
				'other' => q(Imarken yettwaseklaten n Busni),
			},
		},
		'BBD' => {
			display_name => {
				'currency' => q(Adular n Barbuda),
				'one' => q(Adular n Barbuda),
				'other' => q(Idularen n Barbuda),
			},
		},
		'BDT' => {
			display_name => {
				'currency' => q(Ataka n Bangladec),
				'one' => q(Ataka n Bangladec),
				'other' => q(Itakaten n Bangladec),
			},
		},
		'BEC' => {
			display_name => {
				'currency' => q(Afrank n Biljik \(yettwaselkaten\)),
				'one' => q(Afrank n Biljik \(yettwaselkaten\)),
				'other' => q(Ifranken n Biljik \(yettwaselkaten\)),
			},
		},
		'BEF' => {
			symbol => 'FB',
			display_name => {
				'currency' => q(Afrank n Biljik),
				'one' => q(Afrank n Biljik),
				'other' => q(Ifranken n Biljik),
			},
		},
		'BEL' => {
			display_name => {
				'currency' => q(Afrank n Biljik \(adriman\)),
				'one' => q(Afrank n Biljik \(adriman\)),
				'other' => q(Ifranken n Biljik \(idrimanen\)),
			},
		},
		'BGL' => {
			display_name => {
				'currency' => q(Alev n Bulgar \(1962–1999\)),
				'one' => q(Alev n Bulgar \(1962–1999\)),
				'other' => q(Ilevan n Bulgar \(1962–1999\)),
			},
		},
		'BGN' => {
			display_name => {
				'currency' => q(Alev n Bulgari),
				'one' => q(Alev n Bulgari),
				'other' => q(Ilvan n Bulgari),
			},
		},
		'BHD' => {
			display_name => {
				'currency' => q(Adinar Abaḥrini),
				'one' => q(Adinar n Baḥrin),
				'other' => q(Idinaren n Baḥrin),
			},
		},
		'BIF' => {
			display_name => {
				'currency' => q(Afrank Aburandi),
				'one' => q(Afrank n Burundi),
				'other' => q(Ifranken n Burundi),
			},
		},
		'BMD' => {
			symbol => '$BM',
			display_name => {
				'currency' => q(Adular n Birmud),
				'one' => q(Adular n Birmud),
				'other' => q(Idularen n Birmud),
			},
		},
		'BND' => {
			symbol => '$BN',
			display_name => {
				'currency' => q(Adular n Brunay),
				'one' => q(Adular n Brunay),
				'other' => q(Idularen n Brunay),
			},
		},
		'BOB' => {
			display_name => {
				'currency' => q(Abulivyanu n Bulivi),
				'one' => q(Abulivyanu n Bulivi),
				'other' => q(Ibulivyanen n Bulivi),
			},
		},
		'BOL' => {
			display_name => {
				'currency' => q(Abulivyanu n Bulivi \(1863–1963\)),
				'one' => q(Abulivyanu n Bulivi \(1863–1963\)),
				'other' => q(Ibulivyanen n Bulivi \(1863–1963\)),
			},
		},
		'BOP' => {
			display_name => {
				'currency' => q(Apisu n Bulivi),
				'one' => q(Apisu n Bulivi),
				'other' => q(Ipisuten n Bulivi),
			},
		},
		'BOV' => {
			display_name => {
				'currency' => q(Amevdul n Bulivi),
				'one' => q(Amevdul n Bulivi),
				'other' => q(Imevdulen n Bulivi),
			},
		},
		'BRB' => {
			display_name => {
				'currency' => q(Akruziru amaynut n Brizil \(1967–1986\)),
				'one' => q(Akruziru amaynut n Brizil \(1967–1986\)),
				'other' => q(Ikruziruyen imaynuten n Brizil \(1967–1986\)),
			},
		},
		'BRC' => {
			display_name => {
				'currency' => q(Akruzadu n Brizil \(1986–1989\)),
				'one' => q(Akruzadu n Brizil \(1986–1989\)),
				'other' => q(Ikruzaduyen n Brizil \(1986–1989\)),
			},
		},
		'BRE' => {
			display_name => {
				'currency' => q(Akruziru n Brizil \(1990–1993\)),
				'one' => q(Akruziru n Brizil \(1990–1993\)),
				'other' => q(Ikruziruyen n Brizil \(1990–1993\)),
			},
		},
		'BRL' => {
			display_name => {
				'currency' => q(Ariyal n Brizil),
				'one' => q(Ariyal n Brizil),
				'other' => q(Iriyalen n Brizil),
			},
		},
		'BRN' => {
			display_name => {
				'currency' => q(Akruzadu amaynut n Brizil),
				'one' => q(Akruzadu amaynut n Brizil \(1989–1990\)),
				'other' => q(Ikruzaduyen imaynuten n Brizil \(1989–1990\)),
			},
		},
		'BRR' => {
			display_name => {
				'currency' => q(Akruziru),
				'one' => q(Akruziru Ariyal n Brizil\(1993–1994\)),
				'other' => q(Ikruziruyen Iriyalen n Brizil \(1993–1994\)),
			},
		},
		'BRZ' => {
			display_name => {
				'currency' => q(Akruziru n Brizil \(1942–1967\)),
				'one' => q(Akruziru n Brizil \(1942–1967\)),
				'other' => q(Ikruziruyen n Brizil \(1942–1967\)),
			},
		},
		'BSD' => {
			symbol => '$BS',
			display_name => {
				'currency' => q(Adular n Bahamas),
				'one' => q(Adular n Bahamas),
				'other' => q(Idularen n Bahamas),
			},
		},
		'BTN' => {
			display_name => {
				'currency' => q(Angultrum n Butan),
				'one' => q(Angultrum n Butan),
				'other' => q(Ingultrumen n Butan),
			},
		},
		'BUK' => {
			display_name => {
				'currency' => q(Akyat n Burma),
				'one' => q(Akyat n Burma),
				'other' => q(Ikyaten n Burma),
			},
		},
		'BWP' => {
			display_name => {
				'currency' => q(Apula Abusṭwanan),
				'one' => q(Apula n Butswana),
				'other' => q(Ipula n Butswana),
			},
		},
		'BYB' => {
			display_name => {
				'currency' => q(Arubl amaynut n Bilarus \(1994–1999\)),
				'one' => q(Arubl amaynut n Bilarus \(1994–1999\)),
				'other' => q(Irublen amaynut n Bilarus \(1994–1999\)),
			},
		},
		'BYN' => {
			symbol => 'р.',
			display_name => {
				'currency' => q(Arubl n Bilarus),
				'one' => q(Arubl n Bilarus),
				'other' => q(Irublen n Bilarus),
			},
		},
		'BYR' => {
			display_name => {
				'currency' => q(Arubl n Bilarus \(2000–2016\)),
				'one' => q(Arubl n Bilarus \(2000–2016\)),
				'other' => q(Irublen n Bilarus \(2000–2016\)),
			},
		},
		'BZD' => {
			symbol => '$BZ',
			display_name => {
				'currency' => q(Adular n Biliz),
				'one' => q(Adular n Biliz),
				'other' => q(Idularen n Biliz),
			},
		},
		'CAD' => {
			symbol => '$CA',
			display_name => {
				'currency' => q(Adular Akanadi),
				'one' => q(Adular n Kanada),
				'other' => q(Idularen n Kanada),
			},
		},
		'CDF' => {
			display_name => {
				'currency' => q(Afrank Akunguli),
				'one' => q(Afrank n Kungu),
				'other' => q(Ifranken n Kungu),
			},
		},
		'CHE' => {
			display_name => {
				'currency' => q(Uru WIR),
				'one' => q(Uru WIR),
				'other' => q(Uruten WIR),
			},
		},
		'CHF' => {
			display_name => {
				'currency' => q(Afrank Aswis),
				'one' => q(Afrank n Swis),
				'other' => q(Ifranken n Swis),
			},
		},
		'CHW' => {
			display_name => {
				'currency' => q(Afrank WIR),
				'one' => q(Afrank WIR),
				'other' => q(Ifranken WIR),
			},
		},
		'CLE' => {
			display_name => {
				'currency' => q(Askudu n Cili),
				'one' => q(Askudu n Cili),
				'other' => q(Iskuduyen n Cili),
			},
		},
		'CLF' => {
			display_name => {
				'currency' => q(Aferdis n Usefti n Cili),
				'one' => q(Aferdis n Usefti n Cili),
				'other' => q(Iferdisen n Usefti n Cili),
			},
		},
		'CLP' => {
			symbol => '$CL',
			display_name => {
				'currency' => q(Apisu n Cili),
				'one' => q(Apisu n Cili),
				'other' => q(Ipisuten n Cili),
			},
		},
		'CNX' => {
			display_name => {
				'currency' => q(Adular n Lbanka Taɣerfant n Tacinwit),
				'one' => q(Adular n Lbanka Taɣerfant n Tacinwit),
				'other' => q(Idularen n Lbanka Taɣerfant n Tacinwit),
			},
		},
		'CNY' => {
			symbol => 'CNY',
			display_name => {
				'currency' => q(Ayuwan Renminbi Acinwa),
				'one' => q(Ayuwan Acinwa),
				'other' => q(Iyuwanen Icinwaten),
			},
		},
		'COP' => {
			symbol => '$CO',
			display_name => {
				'currency' => q(Apisu n Kulumbi),
				'one' => q(Apisu n Kulumbi),
				'other' => q(Ipisuten n Kulumbi),
			},
		},
		'COU' => {
			display_name => {
				'currency' => q(Aferdis n wazal ilaw n Kulumbi),
				'one' => q(Aferdis n wazal ilaw n Kulumbi),
				'other' => q(Iferdisen n wazal ilaw n Kulumbi),
			},
		},
		'CRC' => {
			display_name => {
				'currency' => q(Akulun n Kusta Rika),
				'one' => q(Akulun n Kusta Rika),
				'other' => q(Ikulunen n Kusta Rika),
			},
		},
		'CSD' => {
			display_name => {
				'currency' => q(Adinar n Ṣirbya-Muntinigru),
				'one' => q(Adinar n Ṣirbya-Muntinigru),
				'other' => q(Idinaren n Ṣirbya-Muntinigru),
			},
		},
		'CSK' => {
			display_name => {
				'currency' => q(Akurun iǧehden Ačikusluvak),
				'one' => q(Akurun iǧehden Ačikusluvak),
				'other' => q(Ikurunen iǧehden Ičikusluvaken),
			},
		},
		'CUC' => {
			display_name => {
				'currency' => q(Apisu n Kuba yettwaselkaten),
				'one' => q(Apisu n Kuba yettwaselkaten),
				'other' => q(Ipisuten n Kuba yettwaselkaten),
			},
		},
		'CUP' => {
			display_name => {
				'currency' => q(Apisu n Kuba),
				'one' => q(Apisu n Kuba),
				'other' => q(Ipisuten n Kuba),
			},
		},
		'CVE' => {
			display_name => {
				'currency' => q(Akabuviradinu Askudi),
				'one' => q(Askudu n Kapvir),
				'other' => q(Iskuduyen n Kapvir),
			},
		},
		'CYP' => {
			symbol => '£CY',
			display_name => {
				'currency' => q(Apawnd n Cipr),
				'one' => q(Apawnd n Cipr),
				'other' => q(Ipawnden n Cipr),
			},
		},
		'CZK' => {
			display_name => {
				'currency' => q(Akurun n Čček),
				'one' => q(Akurun n Čček),
				'other' => q(Ikurunen n Čček),
			},
		},
		'DDM' => {
			display_name => {
				'currency' => q(Amark n Walman n usammar),
				'one' => q(Amark n Walman n usammar),
				'other' => q(Imarken n Walman n usammar),
			},
		},
		'DEM' => {
			display_name => {
				'currency' => q(Amark n Walman),
				'one' => q(Amark n Walman),
				'other' => q(Imarken n Walman),
			},
		},
		'DJF' => {
			display_name => {
				'currency' => q(Afrank Ajibuti),
				'one' => q(Afrank n Jibuti),
				'other' => q(Ifranken n Jibuti),
			},
		},
		'DKK' => {
			display_name => {
				'currency' => q(Akurun n Danmark),
				'one' => q(Akurun n Danmark),
				'other' => q(Ikurunen n Danmark),
			},
		},
		'DOP' => {
			display_name => {
				'currency' => q(Apisu n Duminik),
				'one' => q(Apisu n Duminik),
				'other' => q(Ipisuten n Duminik),
			},
		},
		'DZD' => {
			symbol => 'DA',
			display_name => {
				'currency' => q(Adinar Azzayri),
				'one' => q(Adinar n Lezzayer),
				'other' => q(Idinaren n Lezzayer),
			},
		},
		'ECS' => {
			display_name => {
				'currency' => q(Asukr n Ikwaṭur),
				'one' => q(Asukr n Ikwaṭur),
				'other' => q(Isukren n Ikwaṭur),
			},
		},
		'ECV' => {
			display_name => {
				'currency' => q(Aferdis n wazal ameɣlal n Ikwaṭur \(UVC\)),
				'one' => q(Aferdis n wazal ameɣlal n Ikwaṭur \(UVC\)),
				'other' => q(Iferdisen n wazal ameɣlal n Ikwaṭur \(UVC\)),
			},
		},
		'EEK' => {
			display_name => {
				'currency' => q(Akurun n Isṭunya),
				'one' => q(Akurun n Isṭunya),
				'other' => q(Ikurunen n Isṭunya),
			},
		},
		'EGP' => {
			symbol => '£E',
			display_name => {
				'currency' => q(Apund Amaṣri),
				'one' => q(Apund n Maser),
				'other' => q(Ipunden n Maser),
			},
		},
		'ERN' => {
			display_name => {
				'currency' => q(Anakfa Iritiri),
				'one' => q(Anafka n Iritirya),
				'other' => q(Inafkayen n Iritirya),
			},
		},
		'ESA' => {
			display_name => {
				'currency' => q(Apisetas n Spanya \(amiḍan A\)),
				'one' => q(Apisetas n Spanya \(amiḍan A\)),
				'other' => q(Ipisetasen n Spanya \(amiḍan A\)),
			},
		},
		'ESB' => {
			display_name => {
				'currency' => q(Apisetas n Spanya \(amiḍan yettwaselkaten\)),
				'one' => q(Apisetas n Spanya \(amiḍan yettwaselkaten\)),
				'other' => q(Ipisetasen n Spanya \(amiḍan yettwaselkaten\)),
			},
		},
		'ESP' => {
			display_name => {
				'currency' => q(Apisetas n Spanya),
				'one' => q(Apisetas n Spanya),
				'other' => q(Ipisetasen n Spanya),
			},
		},
		'ETB' => {
			display_name => {
				'currency' => q(Abir Utyupi),
				'one' => q(Abirr n Ityupya),
				'other' => q(Ibirren n Ityupya),
			},
		},
		'EUR' => {
			display_name => {
				'currency' => q(Uru),
				'one' => q(URU),
				'other' => q(URUTEN),
			},
		},
		'FIM' => {
			display_name => {
				'currency' => q(Amark n Finland),
				'one' => q(Amark n Finland),
				'other' => q(Imarken n Finland),
			},
		},
		'FJD' => {
			symbol => '$FJ',
			display_name => {
				'currency' => q(Adular n Fiǧi),
				'one' => q(Adular n Fiǧi),
				'other' => q(Idularen n Fiǧi),
			},
		},
		'FKP' => {
			symbol => '£FK',
			display_name => {
				'currency' => q(Apawnd n tegzrin n Malwin),
				'one' => q(Apawnd n tegzrin n Malwin),
				'other' => q(Ipawnden n tegzrin n Malwin),
			},
		},
		'FRF' => {
			symbol => 'F',
			display_name => {
				'currency' => q(Afrank n Fṛansa),
				'one' => q(Afrank n Fṛansa),
				'other' => q(Ifranken n Fṛansa),
			},
		},
		'GBP' => {
			display_name => {
				'currency' => q(Apund Aglizi),
				'one' => q(Apund aglizi),
				'other' => q(Apund Aglizi),
			},
		},
		'GEK' => {
			display_name => {
				'currency' => q(Akupun n Larin Jyujya),
				'one' => q(Akupun n Larin Jyujya),
				'other' => q(Ikupunen n Larin Jyujya),
			},
		},
		'GEL' => {
			display_name => {
				'currency' => q(Alari n Jyurjya),
				'one' => q(Alari n Jyurjya),
				'other' => q(Ilariyen n Jyurjya),
			},
		},
		'GHC' => {
			display_name => {
				'currency' => q(Asidi Aɣani),
				'one' => q(Asidi n Ɣana \(1967–2007\)),
				'other' => q(Isidiyen n Ɣana \(1967–2007\)),
			},
		},
		'GHS' => {
			display_name => {
				'currency' => q(Asidi n Ɣana),
				'one' => q(Asidi n Ɣana),
				'other' => q(Isidiyen n Ɣana),
			},
		},
		'GIP' => {
			symbol => '£GI',
			display_name => {
				'currency' => q(Apund n Jibraltar),
				'one' => q(Apund n Jibraltar),
				'other' => q(ipunden n Jibraltar),
			},
		},
		'GMD' => {
			display_name => {
				'currency' => q(Adalasi Agambi),
				'one' => q(Adalasi n Gambya),
				'other' => q(Idalasiyen n Gambya),
			},
		},
		'GNF' => {
			display_name => {
				'currency' => q(Afrank n Ɣinya),
				'one' => q(Afrank n Ɣinya),
				'other' => q(Ifranken n Ɣinya),
			},
		},
		'GNS' => {
			display_name => {
				'currency' => q(Afrank Aɣini),
				'one' => q(Azili n Ɣinya),
				'other' => q(Iziliyen n Ɣinya),
			},
		},
		'GQE' => {
			display_name => {
				'currency' => q(Akwili n Ɣinya Tasebgast),
			},
		},
		'GRD' => {
			display_name => {
				'currency' => q(Adrakmi n Grik),
				'one' => q(Adrakmi n Grik),
				'other' => q(Idrakmiyen n Grik),
			},
		},
		'GTQ' => {
			display_name => {
				'currency' => q(Aketzal n Gwatimala),
				'one' => q(Aketzal n Gwatimala),
				'other' => q(Iketzalen n Gwatimala),
			},
		},
		'GWE' => {
			display_name => {
				'currency' => q(Askudu n Ɣinya tapurtugit),
				'one' => q(Askudu n Ɣinya tapurtugit),
				'other' => q(Iskuduyen n Ɣinya tapurtugit),
			},
		},
		'GWP' => {
			display_name => {
				'currency' => q(Apisu n Ɣinya-Bisaw),
				'one' => q(Apisu n Ɣinya-Bisaw),
				'other' => q(Ipisuten n Ɣinya-Bisaw),
			},
		},
		'GYD' => {
			display_name => {
				'currency' => q(Adular n Guyana),
				'one' => q(Adular n Guyana),
				'other' => q(Idularen n Guyana),
			},
		},
		'HKD' => {
			symbol => 'HKD',
			display_name => {
				'currency' => q(Adular n Hung Kung),
				'one' => q(Adular n Hung Kung),
				'other' => q(Idularen n Hung Kung),
			},
		},
		'HNL' => {
			display_name => {
				'currency' => q(Alampir n Hunduras),
				'one' => q(Alampir n Hunduras),
				'other' => q(Ilampiren n Hunduras),
			},
		},
		'HRD' => {
			display_name => {
				'currency' => q(Adinar n Kaṛwasya),
				'one' => q(Adinar n Kaṛwasya),
				'other' => q(Idinaren n Kaṛwasya),
			},
		},
		'HRK' => {
			display_name => {
				'currency' => q(Akuna n Kerwasya),
				'one' => q(Akuna n Kerwasya),
				'other' => q(Ikunayen n Kerwasya),
			},
		},
		'HTG' => {
			display_name => {
				'currency' => q(Agurd n Hayti),
				'one' => q(Agurd n Hayti),
				'other' => q(Igurden n Hayti),
			},
		},
		'HUF' => {
			display_name => {
				'currency' => q(Afurint Ahungri),
				'one' => q(Afurint n Hungri),
				'other' => q(Ifurinten n Hungri),
			},
		},
		'IDR' => {
			display_name => {
				'currency' => q(Arupi n Indunisya),
				'one' => q(Arupi n Indunisya),
				'other' => q(Irupiyen n Indunisya),
			},
		},
		'IEP' => {
			symbol => '£IE',
			display_name => {
				'currency' => q(Apawnd n Irland),
				'one' => q(Apawnd n Irland),
				'other' => q(Ipawnden n Irland),
			},
		},
		'ILP' => {
			symbol => '£IL',
			display_name => {
				'currency' => q(Apawnd n Izrayil),
				'one' => q(Apawnd n Izrayil),
				'other' => q(Ipawnden n Izrayil),
			},
		},
		'ILR' => {
			display_name => {
				'currency' => q(Acikil n Izrayil\(1980–1985\)),
				'one' => q(Acikil n Izrayil\(1980–1985\)),
				'other' => q(Icikilen n Izrayil \(1980–1985\)),
			},
		},
		'ILS' => {
			display_name => {
				'currency' => q(Acikil amaynut n Izrayil),
				'one' => q(Acikil amaynut n Izrayil),
				'other' => q(Acikilen amaynut n Izrayil),
			},
		},
		'INR' => {
			display_name => {
				'currency' => q(Arupi Ahendi),
				'one' => q(Arupi n Lhend),
				'other' => q(Irupiyen n Lhend),
			},
		},
		'IQD' => {
			display_name => {
				'currency' => q(Adinar Aɛiraqi),
				'one' => q(Adinar n Ɛiraq),
				'other' => q(Idinaren n Ɛiraq),
			},
		},
		'IRR' => {
			display_name => {
				'currency' => q(Ariyal n Iran),
				'one' => q(Ariyal n Iran),
				'other' => q(Iriyalen n Iran),
			},
		},
		'ISK' => {
			display_name => {
				'currency' => q(Akurun n Island),
				'one' => q(Akurun n Island),
				'other' => q(Ikurunen n Island),
			},
		},
		'ITL' => {
			symbol => '₤IT',
			display_name => {
				'currency' => q(Alir n Ṭelyan),
				'one' => q(Alir n Ṭelyan),
				'other' => q(Iliren n Ṭelyan),
			},
		},
		'JMD' => {
			display_name => {
				'currency' => q(Adular n Jamayik),
				'one' => q(Adular n Jamayik),
				'other' => q(Idularen n Jamayik),
			},
		},
		'JOD' => {
			display_name => {
				'currency' => q(Adinar Urdun),
				'one' => q(Adinar n Urdun),
				'other' => q(Idinaren n Urdun),
			},
		},
		'JPY' => {
			symbol => 'JPY',
			display_name => {
				'currency' => q(Ayen Ajappuni),
				'one' => q(Iyen n Japun),
				'other' => q(Iynen n Japun),
			},
		},
		'KES' => {
			display_name => {
				'currency' => q(Aciling Akini),
				'one' => q(Aciling n Kinya),
				'other' => q(Icilingen n Kinya),
			},
		},
		'KGS' => {
			display_name => {
				'currency' => q(Asum n Kirigistan),
				'one' => q(Asum n Kirigistan),
				'other' => q(Isumen n Kirigistan),
			},
		},
		'KHR' => {
			display_name => {
				'currency' => q(Ariyil n Kambuj),
				'one' => q(Ariyil n Kambuj),
				'other' => q(Iriyilen n Kambuj),
			},
		},
		'KMF' => {
			display_name => {
				'currency' => q(Afrank Akamiruni),
				'one' => q(Afrank n Kumur),
				'other' => q(Ifranken n Kumur),
			},
		},
		'KPW' => {
			display_name => {
				'currency' => q(Awun n Kurya n Ugafa),
				'one' => q(Awun n Kurya n Ugafa),
				'other' => q(Iwunen n Kurya n Ugafa),
			},
		},
		'KRH' => {
			display_name => {
				'currency' => q(Ahwan n Tkirit n unẓul \(1953–1962\)),
				'one' => q(Ahwan n Tkirit n unẓul \(1953–1962\)),
				'other' => q(Ihwanen n Tkirit n unẓul \(1953–1962\)),
			},
		},
		'KRO' => {
			display_name => {
				'currency' => q(Ahwan n Tkirit n unẓul \(1945–1953\)),
				'one' => q(Ahwan n Tkirit n unẓul \(1945–1953\)),
				'other' => q(Ihwanen n Tkirit n unẓul \(1945–1953\)),
			},
		},
		'KRW' => {
			display_name => {
				'currency' => q(Awun n Kurya n Unẓul),
				'one' => q(Awun n Kurya n Unẓul),
				'other' => q(Iwunen n Kurya n Unẓul),
			},
		},
		'KWD' => {
			display_name => {
				'currency' => q(Adinarn Kuwayt),
				'one' => q(Adinarn Kuwayt),
				'other' => q(Idinaren n Kuwayt),
			},
		},
		'KYD' => {
			display_name => {
				'currency' => q(Adular n tegzirin Kayman),
				'one' => q(Adular n tegzirin Kayman),
				'other' => q(Idularen n tegzirin Kayman),
			},
		},
		'KZT' => {
			display_name => {
				'currency' => q(Atunj n Kazaxistan),
				'one' => q(Atunj n Kazaxistan),
				'other' => q(Itunjen n Kazaxistan),
			},
		},
		'LAK' => {
			display_name => {
				'currency' => q(Akip n Laws),
				'one' => q(Akip n Laws),
				'other' => q(Ikipen n Laws),
			},
		},
		'LBP' => {
			symbol => '£LB',
			display_name => {
				'currency' => q(Apund n Lubnan),
				'one' => q(Apund n Lubnan),
				'other' => q(Ipunden n Lubnan),
			},
		},
		'LKR' => {
			display_name => {
				'currency' => q(Arupi n Srilanka),
				'one' => q(Arupi n Srilanka),
				'other' => q(Irupiyen n Srilanka),
			},
		},
		'LRD' => {
			display_name => {
				'currency' => q(Adular Alibiri),
				'one' => q(Adular n Libirya),
				'other' => q(Idularen n Libirya),
			},
		},
		'LSL' => {
			symbol => 'lLS',
			display_name => {
				'currency' => q(Aluṭi Alizuṭi),
				'one' => q(Aluti n Lizuṭu),
				'other' => q(Ilutiyen n Lizuṭu),
			},
		},
		'LTL' => {
			display_name => {
				'currency' => q(Alitas n Litwanya),
				'one' => q(Alitas n Litwanya),
				'other' => q(Ilitasen n Litwanya),
			},
		},
		'LTT' => {
			display_name => {
				'currency' => q(Atalonas n Litwanya),
				'one' => q(Atalonas n Litwanya),
				'other' => q(Italonasen n Litwanya),
			},
		},
		'LUC' => {
			display_name => {
				'currency' => q(Afrank yettwaseklaten n Luksumburg),
				'one' => q(Afrank yettwaseklaten n Luksumburg),
				'other' => q(Ifranken yettwaseklaten n Luksumburg),
			},
		},
		'LUF' => {
			display_name => {
				'currency' => q(Afrank n Luksumburg),
				'one' => q(Afrank n Luksumburg),
				'other' => q(Ifranken n Luksumburg),
			},
		},
		'LUL' => {
			display_name => {
				'currency' => q(Afrank adriman n Luksumburg),
				'one' => q(Afrank adriman n Luksumburg),
				'other' => q(Ifranken idrimanen n Luksumburg),
			},
		},
		'LVL' => {
			display_name => {
				'currency' => q(Alats n Letunya),
				'one' => q(Alats n Letunya),
				'other' => q(Ilatsen n Letunya),
			},
		},
		'LVR' => {
			display_name => {
				'currency' => q(Arubl n Litunya),
				'one' => q(Arubl n Litunya),
				'other' => q(Irublen n Litunya),
			},
		},
		'LYD' => {
			display_name => {
				'currency' => q(Adinar Alibi),
				'one' => q(Adinar n Libya),
				'other' => q(Idinaren n Libya),
			},
		},
		'MAD' => {
			display_name => {
				'currency' => q(Adirham Amerruki),
				'one' => q(Adirham n Merruk),
				'other' => q(Idirhamen n Merruk),
			},
		},
		'MAF' => {
			symbol => 'fMA',
			display_name => {
				'currency' => q(Afrank n Meṛṛuk),
				'one' => q(Afrank n Meṛṛuk),
				'other' => q(Ifranken n Meṛṛuk),
			},
		},
		'MDL' => {
			display_name => {
				'currency' => q(Alu n Mulduvi),
				'one' => q(Alu n Mulduvi),
				'other' => q(Iluten n Mulduvi),
			},
		},
		'MGA' => {
			display_name => {
				'currency' => q(Aryari Amalgac),
				'one' => q(Aryari n Madagaskar),
				'other' => q(Iryariyen n Madagaskar),
			},
		},
		'MGF' => {
			symbol => 'Fmg',
			display_name => {
				'currency' => q(Afrank n Madakaskaṛ),
				'one' => q(Afrank n Madakaskaṛ),
				'other' => q(Ifranken n Madakaskaṛ),
			},
		},
		'MKD' => {
			display_name => {
				'currency' => q(Adnar n Masidunya),
				'one' => q(Adnar n Masidunya),
				'other' => q(I dnaren n Masidunya),
			},
		},
		'MLF' => {
			display_name => {
				'currency' => q(Afrank n Mali),
				'one' => q(Afrank n Mali),
				'other' => q(Ifranken n Mali),
			},
		},
		'MMK' => {
			display_name => {
				'currency' => q(Akyat n Myanmar),
				'one' => q(Akyat n Myanmar),
				'other' => q(Ikyaten n Myanmar),
			},
		},
		'MNT' => {
			display_name => {
				'currency' => q(Atugrik n Mungulya),
				'one' => q(Atugrik n Mungulya),
				'other' => q(Itugriken n Mungulya),
			},
		},
		'MOP' => {
			display_name => {
				'currency' => q(Apataka n Makaw),
				'one' => q(Apataka n Makaw),
				'other' => q(Ipatakayen n Makaw),
			},
		},
		'MRO' => {
			display_name => {
				'currency' => q(Agiya Amuriṭani \(1973–2017\)),
				'one' => q(Ugiya n Muritaniya \(1973–2017\)),
				'other' => q(Ugiyaten n Muritaniya \(1973–2017\)),
			},
		},
		'MRU' => {
			display_name => {
				'currency' => q(Agiya Amuriṭani),
				'one' => q(Ugiya n Muritaniya),
				'other' => q(Ugiyaten n Muritaniya),
			},
		},
		'MTL' => {
			display_name => {
				'currency' => q(Alir n Malt),
				'one' => q(Alir n Malt),
				'other' => q(Iliren n Malt),
			},
		},
		'MTP' => {
			symbol => '£MT',
			display_name => {
				'currency' => q(Apawnd n Malt),
				'one' => q(Apawnd n Malt),
				'other' => q(Ipawnden n Malt),
			},
		},
		'MUR' => {
			display_name => {
				'currency' => q(Arupi Amurisi),
				'one' => q(Arupi n Muris),
				'other' => q(Irupiyen n Muris),
			},
		},
		'MVP' => {
			display_name => {
				'currency' => q(Arupi n Maldiv),
				'one' => q(Arupi n Maldiv),
				'other' => q(Trupiyen n Maldiv),
			},
		},
		'MVR' => {
			display_name => {
				'currency' => q(Arufiya n Maldiv),
				'one' => q(Arufiya n Maldiv),
				'other' => q(Irufiyaten n Maldiv),
			},
		},
		'MWK' => {
			display_name => {
				'currency' => q(Akwaca Amalawi),
				'one' => q(Akwaca n Malawi),
				'other' => q(Ikwacayen n Malawi),
			},
		},
		'MXN' => {
			symbol => '$MX',
			display_name => {
				'currency' => q(Apisu Miksik),
				'one' => q(Apisu Miksik),
				'other' => q(Ipisuten Miksik),
			},
		},
		'MXP' => {
			display_name => {
				'currency' => q(Apisu n lfeṭṭa n Miksik \(1861–1992\)),
				'one' => q(Apisu n lfeṭṭa n Miksik \(1861–1992\)),
				'other' => q(Ipisuten n lfeṭṭa n Miksik \(1861–1992\)),
			},
		},
		'MXV' => {
			display_name => {
				'currency' => q(Aferdis n uselket n Miksi \(UDI\)),
				'one' => q(Aferdis n uselket n Miksi \(UDI\)),
				'other' => q(Iferdisen n uselket n Miksi \(UDI\)),
			},
		},
		'MYR' => {
			display_name => {
				'currency' => q(Aringgit n Malizya),
				'one' => q(Aringgit n Malizya),
				'other' => q(Iringgiten n Malizya),
			},
		},
		'MZE' => {
			display_name => {
				'currency' => q(Askudu n Muzumbik),
				'one' => q(Askudu n Muzumbik),
				'other' => q(Iskuduyen n Muzumbik),
			},
		},
		'MZM' => {
			display_name => {
				'currency' => q(Amitikal Amuzembiqi),
				'one' => q(Amitikal n Muzumbik \(1980–2006\)),
				'other' => q(Imitikalen n Muzumbik \(1980–2006\)),
			},
		},
		'MZN' => {
			display_name => {
				'currency' => q(Amitikal amuzembiq),
				'one' => q(Amitikal n Muzembiq),
				'other' => q(Imitikalen n Muzembiq),
			},
		},
		'NAD' => {
			symbol => '$NA',
			display_name => {
				'currency' => q(Adular Anamibi),
				'one' => q(Adular n Namibya),
				'other' => q(Idularen n Namibya),
			},
		},
		'NGN' => {
			display_name => {
				'currency' => q(Anayra Anijiri),
				'one' => q(Anayra n Nijirya),
				'other' => q(Inayrayen n Nijirya),
			},
		},
		'NIC' => {
			display_name => {
				'currency' => q(Akurduba n Nikaragwa \(1912–1988\)),
				'one' => q(Akurduba n Nikaragwa \(1912–1988\)),
				'other' => q(Ikurdubayen n Nikaragwa \(1912–1988\)),
			},
		},
		'NIO' => {
			symbol => '$C',
			display_name => {
				'currency' => q(Akurduba n Nikaragwa),
				'one' => q(Akurduba n Nikaragwa),
				'other' => q(Ikurdubayen n Nikaragwa),
			},
		},
		'NLG' => {
			display_name => {
				'currency' => q(Aflurin n Huland),
				'one' => q(Aflurin n Huland),
				'other' => q(Iflurinen n Huland),
			},
		},
		'NOK' => {
			display_name => {
				'currency' => q(Akurun n Nurvij),
				'one' => q(Akurun n Nurvij),
				'other' => q(Ikurunen n Nurvij),
			},
		},
		'NPR' => {
			display_name => {
				'currency' => q(Arupi n Nipal),
				'one' => q(Arupi n Nipal),
				'other' => q(Irupiyen n Nipal),
			},
		},
		'NZD' => {
			symbol => '$NZ',
			display_name => {
				'currency' => q(Adular n Ziland Tamaynut),
				'one' => q(Adular n Ziland Tamaynut),
				'other' => q(Idularen n Ziland Tamaynut),
			},
		},
		'OMR' => {
			display_name => {
				'currency' => q(Ariyal n Ɛuman),
				'one' => q(Ariyal n Ɛuman),
				'other' => q(Iriyalen n Ɛuman),
			},
		},
		'PAB' => {
			display_name => {
				'currency' => q(Abalbwa n Panama),
				'one' => q(Abalbwa n Panama),
				'other' => q(Ibalbwayen n Panama),
			},
		},
		'PEI' => {
			display_name => {
				'currency' => q(Inti n Piru),
				'one' => q(Inti n Piru),
				'other' => q(Intiyen n Piru),
			},
		},
		'PEN' => {
			display_name => {
				'currency' => q(Asul amaynut n Piru),
				'one' => q(Asul amaynut n Piru),
				'other' => q(Isulen amaynut n Piru),
			},
		},
		'PES' => {
			display_name => {
				'currency' => q(Asul n Piru \(1863–1985\)),
				'one' => q(Asul n Piru \(1863–1985\)),
				'other' => q(Isulen n Piru \(1863–1985\)),
			},
		},
		'PGK' => {
			display_name => {
				'currency' => q(Akina n Papwazi n Ɣinya Tamaynut),
				'one' => q(Akina n Papwazi n Ɣinya Tamaynut),
				'other' => q(Ikinayen n Papwazi n Ɣinya Tamaynut),
			},
		},
		'PHP' => {
			symbol => 'PHP',
			display_name => {
				'currency' => q(Apisu n Filipin),
				'one' => q(Apisu n Filipin),
				'other' => q(Ipisuten n Filipin),
			},
		},
		'PKR' => {
			display_name => {
				'currency' => q(Arupi n Pakistan),
				'one' => q(Arupi n Pakistan),
				'other' => q(Irupiyen n Pakistan),
			},
		},
		'PLN' => {
			display_name => {
				'currency' => q(Azluti n Puland),
				'one' => q(Azluti n Puland),
				'other' => q(Izlutiyen n Puland),
			},
		},
		'PLZ' => {
			display_name => {
				'currency' => q(Azluti n Pulund \(1950–1995\)),
				'one' => q(Azluti n Pulund \(1950–1995\)),
				'other' => q(Izlutiyen n Pulund \(1950–1995\)),
			},
		},
		'PTE' => {
			display_name => {
				'currency' => q(Askudu n Purtugal),
				'one' => q(Askudu n Purtugal),
				'other' => q(Iskuduten n Purtugal),
			},
		},
		'PYG' => {
			display_name => {
				'currency' => q(Agarani n Paragway),
				'one' => q(Agarani n Paragway),
				'other' => q(Igaraniyen n Paragway),
			},
		},
		'QAR' => {
			display_name => {
				'currency' => q(Ariyal n Qatar),
				'one' => q(Ariyal n Qatar),
				'other' => q(Iriyalen n Qatar),
			},
		},
		'RHD' => {
			symbol => '$RH',
			display_name => {
				'currency' => q(Adular Arudizyan),
				'one' => q(Adular Arudizyan),
				'other' => q(Idularen Irudizyanen),
			},
		},
		'ROL' => {
			display_name => {
				'currency' => q(Alu aqbuṛ n Rumanya \(1952–2005\)),
				'one' => q(Alu aqbuṛ n Rumanya \(1952–2005\)),
				'other' => q(Iluten iqbuṛen n Rumanya \(1952–2005\)),
			},
		},
		'RON' => {
			symbol => 'L',
			display_name => {
				'currency' => q(Alu n Rumanya),
				'one' => q(Alu n Rumanya),
				'other' => q(Aluten n Rumanya),
			},
		},
		'RSD' => {
			display_name => {
				'currency' => q(Adinar n Ṣirbya),
				'one' => q(Adinar n Ṣirbya),
				'other' => q(Idinaren n Ṣirbya),
			},
		},
		'RUB' => {
			display_name => {
				'currency' => q(Arubl n Rrus),
				'one' => q(Arubl n Rrus),
				'other' => q(Irublen n Rrus),
			},
		},
		'RUR' => {
			display_name => {
				'currency' => q(Arubl n Rrus \(1991–1998\)),
				'one' => q(Arubl n Rrus \(1991–1998\)),
				'other' => q(Irublen n Rrus \(1991–1998\)),
			},
		},
		'RWF' => {
			display_name => {
				'currency' => q(Afrank Aruwandi),
				'one' => q(Afrank n Rwanda),
				'other' => q(Ifranken n Rwanda),
			},
		},
		'SAR' => {
			display_name => {
				'currency' => q(Aryal Asuɛudi),
				'one' => q(Ariyal n Saɛudya),
				'other' => q(Iriyalen n Saɛudya),
			},
		},
		'SBD' => {
			symbol => '$SB',
			display_name => {
				'currency' => q(Adular n Tegzirin n Salumun),
				'one' => q(Adular n Tegzirin n Salumun),
				'other' => q(Idularen n Tegzirin n Salumun),
			},
		},
		'SCR' => {
			display_name => {
				'currency' => q(Arupi Aseycili),
				'one' => q(Arupi n Saycal),
				'other' => q(Irupiyen n Saycal),
			},
		},
		'SDD' => {
			display_name => {
				'currency' => q(Adinar n Sudan \(1992–2007\)),
				'one' => q(Adinar n Sudan \(1992–2007\)),
				'other' => q(Idinaren n Sudan \(1992–2007\)),
			},
		},
		'SDG' => {
			display_name => {
				'currency' => q(Apund Asudani),
				'one' => q(Apund n Sudan),
				'other' => q(Ipunden n Sudan),
			},
		},
		'SDP' => {
			display_name => {
				'currency' => q(Apawnd n Sudan \(1956–2007\)),
				'one' => q(Apawnd n Sudan \(1956–2007\)),
				'other' => q(Ipawnden n Sudan \(1956–2007\)),
			},
		},
		'SEK' => {
			display_name => {
				'currency' => q(Akurun n Swid),
			},
		},
		'SGD' => {
			symbol => '$SG',
			display_name => {
				'currency' => q(Adular n Sangapur),
				'one' => q(Adular n Sangapur),
				'other' => q(Idularen n Sangapur),
			},
		},
		'SHP' => {
			display_name => {
				'currency' => q(Apund Asant Ilini),
				'one' => q(Apund n Sant Ilina),
				'other' => q(Ipunden n Sant Ilina),
			},
		},
		'SIT' => {
			display_name => {
				'currency' => q(Atular n Sluvinya),
				'one' => q(Atular n Sluvinya),
				'other' => q(Itularen n Sluvinya),
			},
		},
		'SKK' => {
			display_name => {
				'currency' => q(Akurun n Sluvakya),
				'one' => q(Akurun n Sluvakya),
				'other' => q(Ikurunen n Sluvakya),
			},
		},
		'SLE' => {
			display_name => {
				'currency' => q(Alyun),
				'one' => q(Aliyun n Sira Lyun),
				'other' => q(Iliyunen n Sira Lyun),
			},
		},
		'SLL' => {
			display_name => {
				'currency' => q(Alyun \(1964—2022\)),
				'one' => q(Aliyun n Sira Lyun \(1964—2022\)),
				'other' => q(Iliyunen n Sira Lyun \(1964—2022\)),
			},
		},
		'SOS' => {
			display_name => {
				'currency' => q(Aciling Aṣumali),
				'one' => q(Aciling n Ṣumal),
				'other' => q(Icilingen n Ṣumal),
			},
		},
		'SRD' => {
			symbol => '$SR',
			display_name => {
				'currency' => q(Adular n Surinam),
				'one' => q(Adular n Surinam),
				'other' => q(Idularen n Surinam),
			},
		},
		'SRG' => {
			display_name => {
				'currency' => q(Aflurin n Surinam),
				'one' => q(Aflurin n Surinam),
				'other' => q(Iflurinen n Surinam),
			},
		},
		'SSP' => {
			display_name => {
				'currency' => q(Apund n Sudan n Unẓul),
				'one' => q(Apund n Sudan n Unẓul),
				'other' => q(Ipunden n Sudan n Unẓul),
			},
		},
		'STD' => {
			display_name => {
				'currency' => q(Asw Ṭum d Udubra Amenzay \(1977–2017\)),
				'one' => q(Adubra n Sint-Toma \(1977–2017\)),
				'other' => q(Idubrayen n Sint-Toma \(1977–2017\)),
			},
		},
		'STN' => {
			display_name => {
				'currency' => q(Asw Ṭum d Udubra Amenzay),
				'one' => q(Adubra n Saw Tumi d Prinsip),
				'other' => q(Idubrayen n Saw Tumi d Prinsip),
			},
		},
		'SUR' => {
			display_name => {
				'currency' => q(Arubl n Suvyat),
				'one' => q(Arubl n Suvyat),
				'other' => q(Irublen n Suvyat),
			},
		},
		'SVC' => {
			display_name => {
				'currency' => q(Akulun n Salvadur),
				'one' => q(Akulun n Salvadur),
				'other' => q(Ikulunen n Salvadur),
			},
		},
		'SYP' => {
			display_name => {
				'currency' => q(Apund n Surya),
				'one' => q(Apund n Surya),
				'other' => q(Ipunden n Surya),
			},
		},
		'SZL' => {
			display_name => {
				'currency' => q(Alilangini),
				'one' => q(Alilangini n Swazilan),
				'other' => q(Ililanginiyen n Swazilan),
			},
		},
		'THB' => {
			display_name => {
				'currency' => q(Abaht n Tayland),
				'one' => q(Abaht n Tayland),
				'other' => q(Ibahten n Tayland),
			},
		},
		'TJR' => {
			display_name => {
				'currency' => q(Arubl n Ṭajikistan),
				'one' => q(Arubl n Ṭajikistan),
				'other' => q(Irublen n Ṭajikistan),
			},
		},
		'TJS' => {
			display_name => {
				'currency' => q(Asumuni n Ṭajikistan),
				'one' => q(Asumuni n Ṭajikistan),
				'other' => q(Isumuniyen n Ṭajikistan),
			},
		},
		'TMM' => {
			display_name => {
				'currency' => q(Amanat n Ṭurkmanistan),
				'one' => q(Amanat n Ṭurkmanistan),
				'other' => q(Imanaten n Ṭurkmanistan),
			},
		},
		'TMT' => {
			display_name => {
				'currency' => q(Amanat amaynut n Ṭurkmanistan),
				'one' => q(Amanat amaynut n Ṭurkmanistan),
				'other' => q(Imanaten imaynuten n Ṭurkmanistan),
			},
		},
		'TND' => {
			display_name => {
				'currency' => q(Adinar Atunsi),
				'one' => q(Adinar n Tunes),
				'other' => q(Idinaren n Tunes),
			},
		},
		'TOP' => {
			display_name => {
				'currency' => q(Apanga n Tunga),
				'one' => q(Apanga n Tunga),
				'other' => q(Ipangayen n Tunga),
			},
		},
		'TPE' => {
			display_name => {
				'currency' => q(Askudu n Timur),
				'one' => q(Askudu n Timur),
				'other' => q(Iskuduyen n Timur),
			},
		},
		'TRL' => {
			display_name => {
				'currency' => q(Apawnd n Ṭurk \(1844–2005\)),
				'one' => q(Apawnd n Ṭurk \(1844–2005\)),
				'other' => q(Ipawnden n Ṭurk \(1844–2005\)),
			},
		},
		'TRY' => {
			symbol => 'LT',
			display_name => {
				'currency' => q(Apund n Ṭurk),
				'one' => q(Apund n Ṭurk),
				'other' => q(Ipunden n Ṭurk),
			},
		},
		'TTD' => {
			symbol => '$TT',
			display_name => {
				'currency' => q(Adular n Trinidad d Tubagu),
				'one' => q(Adular n Trinidad d Tubagu),
				'other' => q(Idularen n Trinidad d Tubagu),
			},
		},
		'TWD' => {
			symbol => 'TWD',
			display_name => {
				'currency' => q(Adular amaynut n Taywan),
				'one' => q(Adular amaynut n Taywan),
				'other' => q(Idularen imaynuten n Taywan),
			},
		},
		'TZS' => {
			display_name => {
				'currency' => q(Aciling Aṭanẓani),
				'one' => q(Aciling n Ṭanzanya),
				'other' => q(Icilingen n Ṭanzanya),
			},
		},
		'UAH' => {
			display_name => {
				'currency' => q(Ahrivnya n Ukran),
				'one' => q(Ahrivnya n Ukran),
				'other' => q(Ihrivnyaen n Ukran),
			},
		},
		'UAK' => {
			display_name => {
				'currency' => q(Akarbuvanit n Ukrin \(1992–1996\)),
				'one' => q(Akarbuvanit n Ukrin \(1992–1996\)),
				'other' => q(Ikarbuvaniten n Ukrin \(1992–1996\)),
			},
		},
		'UGS' => {
			display_name => {
				'currency' => q(Aciling n Uganda \(1966–1987\)),
				'one' => q(Aciling n Uganda \(1966–1987\)),
				'other' => q(Icilingen n Uganda \(1966–1987\)),
			},
		},
		'UGX' => {
			display_name => {
				'currency' => q(Aciling Awgandi),
				'one' => q(Aciling n Uganda),
				'other' => q(Icilingen n Uganda),
			},
		},
		'USD' => {
			symbol => '$',
			display_name => {
				'currency' => q(Adular WD),
				'one' => q(Adular n Marikan),
				'other' => q(Idularen n Marikan),
			},
		},
		'USN' => {
			display_name => {
				'currency' => q(Adular n Marikan \(azekka–yen\)),
				'one' => q(Adular n Marikan \(azekka–yen\)),
				'other' => q(Idularen n Marikan \(azekka–yen\)),
			},
		},
		'USS' => {
			display_name => {
				'currency' => q(Adular n Marikan \(ass–en\)),
				'one' => q(Adular n Marikan \(ass–en\)),
				'other' => q(Idularen n Marikan \(ass–en\)),
			},
		},
		'UYI' => {
			display_name => {
				'currency' => q(Apisu n Urugway \(iferdisen s umatar\)),
				'one' => q(Apisu n Urugway \(iferdisen s umatar\)),
				'other' => q(Ipisuten n Urugway \(iferdisen s umatar\)),
			},
		},
		'UYP' => {
			display_name => {
				'currency' => q(Apisu n Urugway \(1975–1993\)),
				'one' => q(Apisu n Urugway \(1975–1993\)),
				'other' => q(Ipisuten n Urugway \(1975–1993\)),
			},
		},
		'UYU' => {
			symbol => '$UY',
			display_name => {
				'currency' => q(Apisu n Urugway),
				'one' => q(Apisu n Urugway),
				'other' => q(Ipisuten n Urugway),
			},
		},
		'UZS' => {
			display_name => {
				'currency' => q(Asum n Uzbikistan),
				'one' => q(Asum n Uzbikistan),
				'other' => q(Isumen n Uzbikistan),
			},
		},
		'VEB' => {
			display_name => {
				'currency' => q(Abulivaṛ n Vinizwila \(1871–2008\)),
				'one' => q(Abulivaṛ n Vinizwila \(1871–2008\)),
				'other' => q(Ibulivaṛen n Vinizwila \(1871–2008\)),
			},
		},
		'VEF' => {
			display_name => {
				'currency' => q(Abulivaṛ n Vinizwila \(2008–2018\)),
				'one' => q(Abulivaṛ n Vinizwila \(2008–2018\)),
				'other' => q(Ibulivaṛen n Vinizwila \(2008–2018\)),
			},
		},
		'VES' => {
			display_name => {
				'currency' => q(Abulivar n Vinizwila),
				'one' => q(Abulivar n Vinizwila),
				'other' => q(Ibulivaren n Vinizwila),
			},
		},
		'VND' => {
			display_name => {
				'currency' => q(Adung n Vyitnam),
				'one' => q(Adung n Vyitnam),
				'other' => q(Idungen n Vyitnam),
			},
		},
		'VNN' => {
			display_name => {
				'currency' => q(Adung n Vyitnam \(1978–1985\)),
				'one' => q(Adung n Vyitnam \(1978–1985\)),
				'other' => q(Idungen n Vyitnam \(1978–1985\)),
			},
		},
		'VUV' => {
			display_name => {
				'currency' => q(Avatu n Vanuyatu),
				'one' => q(Avatu n Vanuyatu),
				'other' => q(Ivatuyen n Vanuyatu),
			},
		},
		'WST' => {
			symbol => 'WS$',
			display_name => {
				'currency' => q(Atala n Samwa),
				'one' => q(Atala n Samwa),
				'other' => q(Italayen n Samwa),
			},
		},
		'XAF' => {
			display_name => {
				'currency' => q(Afrank BCEA CFA),
				'one' => q(Afrank n CFA \(BEAC\)),
				'other' => q(Ifranken n CFA \(BEAC\)),
			},
		},
		'XAG' => {
			display_name => {
				'currency' => q(lfeṭṭa),
				'one' => q(Uns Ṭruy n lfe),
				'other' => q(Unsen Ṭruy n lfe),
			},
		},
		'XAU' => {
			display_name => {
				'currency' => q(Awraɣ),
				'one' => q(Uns Ṭruy n n uwraɣ),
				'other' => q(Unsen Ṭruy n n uwraɣ),
			},
		},
		'XBA' => {
			display_name => {
				'currency' => q(Aferdis n tufut uddis \(URKU\)),
				'one' => q(Aferdis n tufut uddis \(URKU\)),
				'other' => q(Iferdisen n tufut uddisen \(URKU\)),
			},
		},
		'XBB' => {
			display_name => {
				'currency' => q(Aferdis n tedrimt n tufurt \(UME–6\)),
			},
		},
		'XBC' => {
			display_name => {
				'currency' => q(Aferdis n umiḍan n turfut \(UEC–9\)),
				'one' => q(Aferdis n umiḍan n turfut \(UEC–9\)),
				'other' => q(Iferdisen n umiḍan n turfut \(UEC–9\)),
			},
		},
		'XBD' => {
			display_name => {
				'currency' => q(Aferdis n umiḍan 17 n turfut \(UEC–17\)),
				'one' => q(Aferdis n umiḍan 17 n turfut \(UEC–17\)),
				'other' => q(Iferdisen n umiḍan 17 n turfut \(UEC–17\)),
			},
		},
		'XCD' => {
			symbol => 'XCD',
			display_name => {
				'currency' => q(Adular n Karayib n usammar),
				'one' => q(Adular n Karayib n usammar),
				'other' => q(Idularen n Karayib n usammar),
			},
		},
		'XDR' => {
			symbol => 'DTS',
			display_name => {
				'currency' => q(droit de tirage spécial),
				'one' => q(droit de tirage spécial),
				'other' => q(droits de tirage spéciaux),
			},
		},
		'XEU' => {
			display_name => {
				'currency' => q(Aferdis n umiḍan n turfut \(ACU\)),
				'one' => q(Aferdis n umiḍan n turfut \(ACU\)),
				'other' => q(Iferdisen n umiḍan n turfut \(ACU\)),
			},
		},
		'XFO' => {
			display_name => {
				'currency' => q(Afrank awraɣ),
				'one' => q(Afrank n awraɣ),
				'other' => q(Ifranken n uwraɣ),
			},
		},
		'XFU' => {
			display_name => {
				'currency' => q(Afrank UIC),
				'one' => q(Afrank UIC),
				'other' => q(Ifranken UIC),
			},
		},
		'XOF' => {
			display_name => {
				'currency' => q(Afrank BCEAO CFA),
				'one' => q(Afrank CFA \(BCEAO\)),
				'other' => q(Ifranken CFA \(BCEAO\)),
			},
		},
		'XPD' => {
			display_name => {
				'currency' => q(Palladium),
				'one' => q(Uns n Ṭrwa n palladium),
				'other' => q(Unsen n Ṭrwa n palladium),
			},
		},
		'XPF' => {
			symbol => 'FCFP',
			display_name => {
				'currency' => q(Afrank CFP),
				'one' => q(Afrank CFP),
				'other' => q(Ifranken CFP),
			},
		},
		'XPT' => {
			display_name => {
				'currency' => q(Platin),
				'one' => q(Uns n Ṭrwa n Platin),
				'other' => q(Unsen n Ṭrwa n Platin),
			},
		},
		'XRE' => {
			display_name => {
				'currency' => q(Anaw n idran RINET),
				'one' => q(Aferdis n idran RINET),
				'other' => q(Aferdis n idran RINET),
			},
		},
		'XSU' => {
			display_name => {
				'currency' => q(Asukr),
				'one' => q(Asukr),
				'other' => q(Isukren),
			},
		},
		'XTS' => {
			display_name => {
				'currency' => q(\(tadrimt n usefkyed\)),
			},
		},
		'XUA' => {
			display_name => {
				'currency' => q(Aferdis n umiḍan ADB),
				'one' => q(Aferdis n umiḍan ADB),
				'other' => q(Iferdisen n umiḍan ADB),
			},
		},
		'XXX' => {
			symbol => 'XXX',
			display_name => {
				'currency' => q(Tadrimt tarussint neɣ tarameɣtut),
				'one' => q(Tadrimt tarussint),
				'other' => q(Tadrimt tirussinin),
			},
		},
		'YDD' => {
			display_name => {
				'currency' => q(Adinar n Yaman),
				'one' => q(Adinar n Yaman),
				'other' => q(Idinaren n Yaman),
			},
		},
		'YER' => {
			display_name => {
				'currency' => q(Ariyal n Yaman),
				'one' => q(Ariyal n Yaman),
				'other' => q(Iriyalen n Yaman),
			},
		},
		'YUD' => {
			display_name => {
				'currency' => q(Adinar n Yuguslavya amaynut \(1966–1989\)),
			},
		},
		'YUM' => {
			display_name => {
				'currency' => q(Adinar n Yuguslavya amaynut \(1994–2003\)),
				'one' => q(Adinar n Yuguslavya amaynut \(1994–2003\)),
				'other' => q(Idinaren n Yuguslavya amaynut \(1994–2003\)),
			},
		},
		'YUN' => {
			display_name => {
				'currency' => q(Adinar n Yuguslavya yettwaselkaten \(1990–1992\)),
				'one' => q(Adinar n Yuguslavya yettwaselkaten \(1990–1992\)),
				'other' => q(Idinaren n Yuguslavya yettwaselkaten \(1990–1992\)),
			},
		},
		'ZAL' => {
			display_name => {
				'currency' => q(Arand n Tefriqt n unzul \(adriman\)),
				'one' => q(Arand n Tefriqt n unzul \(adriman\)),
				'other' => q(Iranden n Tefriqt n unzul \(idrimanen\)),
			},
		},
		'ZAR' => {
			display_name => {
				'currency' => q(Arand Afriqi n Wadda),
				'one' => q(Arand n Tefriqt n Unẓul),
				'other' => q(Iranden n Tefriqt n Unẓul),
			},
		},
		'ZMK' => {
			display_name => {
				'currency' => q(Akwaca Azambi \(1968–2012\)),
				'one' => q(Akwaca n Ẓambya \(1968–2012\)),
				'other' => q(Ikwacayen n Ẓambya \(1968–2012\)),
			},
		},
		'ZMW' => {
			symbol => 'Kw',
			display_name => {
				'currency' => q(Akwaca Azambi),
				'one' => q(Akwaca n Zambya),
				'other' => q(Ikwacayen n Zambya),
			},
		},
		'ZRN' => {
			display_name => {
				'currency' => q(Azayir amaynut n Zayir),
				'one' => q(Azayir amaynut n Zayir),
				'other' => q(Izayiren imaynuten n Zayir),
			},
		},
		'ZRZ' => {
			display_name => {
				'currency' => q(Azayir n Zayir),
				'one' => q(Azayir n Zayir),
				'other' => q(Izayiren n Zayir),
			},
		},
		'ZWD' => {
			display_name => {
				'currency' => q(Adular Azimbabwi),
				'one' => q(Adular n zimbabwi),
				'other' => q(Idularen n zimbabwi),
			},
		},
		'ZWL' => {
			display_name => {
				'currency' => q(Adular n zimbabwi \(2009\)),
				'one' => q(Adular n zimbabwi \(2009\)),
				'other' => q(Idularen n zimbabwi \(2009\)),
			},
		},
		'ZWR' => {
			display_name => {
				'currency' => q(Adular n zimbabwi \(2008\)),
				'one' => q(Adular n zimbabwi \(2008\)),
				'other' => q(Idularen n zimbabwi \(2008\)),
			},
		},
	} },
);


has 'calendar_months' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
			'gregorian' => {
				'format' => {
					abbreviated => {
						nonleap => [
							'Yen',
							'Fur',
							'Meɣ',
							'Yeb',
							'May',
							'Yun',
							'Yul',
							'Ɣuc',
							'Cte',
							'Tub',
							'Nun',
							'Duǧ'
						],
						leap => [
							
						],
					},
					narrow => {
						nonleap => [
							'Y',
							'F',
							'M',
							'Y',
							'M',
							'Y',
							'Y',
							'Ɣ',
							'C',
							'T',
							'W',
							'D'
						],
						leap => [
							
						],
					},
					wide => {
						nonleap => [
							'Yennayer',
							'Fuṛar',
							'Meɣres',
							'Yebrir',
							'Mayyu',
							'Yunyu',
							'Yulyu',
							'Ɣuct',
							'Ctembeṛ',
							'Tubeṛ',
							'Nunembeṛ',
							'Duǧembeṛ'
						],
						leap => [
							
						],
					},
				},
				'stand-alone' => {
					abbreviated => {
						nonleap => [
							'Yen',
							'Fur',
							'Meɣ',
							'Yeb',
							'May',
							'Yun',
							'Yul',
							'Ɣuc',
							'Cte',
							'Tub',
							'Wam',
							'Duǧ'
						],
						leap => [
							
						],
					},
					narrow => {
						nonleap => [
							'Y',
							'F',
							'M',
							'Y',
							'M',
							'Y',
							'Y',
							'Ɣ',
							'C',
							'T',
							'N',
							'D'
						],
						leap => [
							
						],
					},
				},
			},
	} },
);

has 'calendar_days' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
			'gregorian' => {
				'format' => {
					abbreviated => {
						mon => 'San',
						tue => 'Kraḍ',
						wed => 'Kuẓ',
						thu => 'Sam',
						fri => 'Sḍis',
						sat => 'Say',
						sun => 'Yan'
					},
					narrow => {
						mon => 'R',
						tue => 'R',
						wed => 'H',
						thu => 'M',
						fri => 'S',
						sat => 'S',
						sun => 'C'
					},
					short => {
						mon => 'Ri',
						tue => 'Ra',
						wed => 'Hd',
						thu => 'Mh',
						fri => 'Sm',
						sat => 'Sd',
						sun => 'Cr'
					},
					wide => {
						mon => 'Sanass',
						tue => 'Kraḍass',
						wed => 'Kuẓass',
						thu => 'Samass',
						fri => 'Sḍisass',
						sat => 'Sayass',
						sun => 'Yanass'
					},
				},
				'stand-alone' => {
					abbreviated => {
						mon => 'Ari',
						tue => 'Ara',
						wed => 'Aha',
						thu => 'Amh',
						fri => 'Sem',
						sat => 'Sed',
						sun => 'Ace'
					},
					narrow => {
						mon => 'S',
						tue => 'K',
						wed => 'K',
						thu => 'S',
						fri => 'S',
						sat => 'S',
						sun => 'Y'
					},
					short => {
						mon => 'Ri',
						tue => 'Ra',
						wed => 'Hd',
						thu => 'Md',
						fri => 'Sm',
						sat => 'Sd',
						sun => 'Cr'
					},
					wide => {
						mon => 'Arim',
						tue => 'Aram',
						wed => 'Ahad',
						thu => 'Amhad',
						fri => 'Sem',
						sat => 'Sed',
						sun => 'Acer'
					},
				},
			},
	} },
);

has 'calendar_quarters' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
			'gregorian' => {
				'format' => {
					abbreviated => {0 => 'Kḍg1',
						1 => 'Kḍg2',
						2 => 'Kḍg3',
						3 => 'Kḍg4'
					},
					wide => {0 => 'akraḍaggur amenzu',
						1 => 'akraḍaggur wis-sin',
						2 => 'akraḍaggur wis-kraḍ',
						3 => 'akraḍaggur wis-kuẓ'
					},
				},
				'stand-alone' => {
					abbreviated => {0 => 'Kḍy1',
						1 => 'Kḍy2',
						2 => 'Kḍy3',
						3 => 'Kḍy4'
					},
					wide => {0 => 'akraḍyur 1u',
						1 => 'akraḍyur w2',
						2 => 'akraḍyur w3',
						3 => 'akraḍyur w4'
					},
				},
			},
	} },
);

has 'day_periods' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'gregorian' => {
			'format' => {
				'abbreviated' => {
					'am' => q{n tufat},
					'pm' => q{n tmeddit},
				},
				'narrow' => {
					'am' => q{f},
					'pm' => q{m},
				},
				'wide' => {
					'am' => q{n tufat},
					'pm' => q{n tmeddit},
				},
			},
			'stand-alone' => {
				'abbreviated' => {
					'am' => q{FT},
					'pm' => q{MD},
				},
			},
		},
	} },
);

has 'eras' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
		},
		'gregorian' => {
			abbreviated => {
				'0' => 'snd. T.Ɛ',
				'1' => 'sld. T.Ɛ'
			},
			wide => {
				'0' => 'send talalit n Ɛisa',
				'1' => 'seld talalit n Ɛisa'
			},
		},
	} },
);

has 'date_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
			'full' => q{EEEE d MMMM y G},
			'long' => q{d MMMM y G},
			'medium' => q{d MMM, y G},
			'short' => q{d/M/y GGGGG},
		},
		'gregorian' => {
			'full' => q{EEEE d MMMM y},
			'long' => q{d MMMM y},
			'medium' => q{d MMM, y},
			'short' => q{d/M/y},
		},
	} },
);

has 'time_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
		},
		'gregorian' => {
			'full' => q{h:mm:ss a zzzz},
			'long' => q{h:mm:ss a z},
			'medium' => q{h:mm:ss a},
			'short' => q{h:mm a},
		},
	} },
);

has 'datetime_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
			'full' => q{{1}, {0}},
			'long' => q{{1}, {0}},
			'medium' => q{{1}, {0}},
			'short' => q{{1}, {0}},
		},
		'gregorian' => {
			'full' => q{{1}, {0}},
			'long' => q{{1}, {0}},
			'medium' => q{{1}, {0}},
			'short' => q{{1}, {0}},
		},
	} },
);

has 'datetime_formats_available_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
			Ed => q{E, d},
			Ehm => q{E h:mm a},
			Ehms => q{E h:mm:ss a},
			Gy => q{y G},
			GyMMM => q{MMM y G},
			GyMMMEd => q{E, d MMM, y G},
			GyMMMd => q{d MMM, y G},
			M => q{M},
			MEd => q{E, dd/MM},
			MMM => q{MMM},
			MMMEd => q{E d MMM},
			MMMMEd => q{E d MMMM},
			MMMMd => q{d MMMM},
			MMMd => q{d MMM},
			MMd => q{d/MM},
			MMdd => q{dd/MM},
			Md => q{d/M},
			h => q{h a},
			hm => q{h:mm a},
			hms => q{h:mm:ss a},
			ms => q{m:ss},
			y => q{y},
			yM => q{M/y},
			yMEd => q{E d/M/y},
			yMM => q{MM/y},
			yMMM => q{MMM y},
			yMMMEd => q{E d MMM y},
			yMMMM => q{MMMM y},
			yMMMd => q{d MMM y},
			yQQQ => q{QQQ y},
			yQQQQ => q{QQQQ y},
			yyyy => q{y G},
			yyyyM => q{MM/y GGGGG},
			yyyyMEd => q{E dd/MM/y GGGGG},
			yyyyMMM => q{MMM y G},
			yyyyMMMEd => q{E d MMM y G},
			yyyyMMMM => q{MMMM y G},
			yyyyMMMd => q{d MMM y G},
			yyyyMd => q{dd/MM/y GGGGG},
			yyyyQQQ => q{QQQ y G},
			yyyyQQQQ => q{QQQQ y G},
		},
		'gregorian' => {
			Ed => q{E d},
			Ehm => q{E h:mm a},
			Ehms => q{E h:mm:ss a},
			Gy => q{y G},
			M => q{M},
			MMM => q{MMM},
			MMMEd => q{E d MMM},
			MMMMEd => q{E d MMMM},
			MMMMW => q{'imalas' W 'n' MMMM},
			MMMMd => q{d MMMM},
			MMMd => q{d MMM},
			MMd => q{d/MM},
			MMdd => q{dd/MM},
			Md => q{d/M},
			h => q{h a},
			hm => q{h:mm a},
			hms => q{h:mm:ss a},
			hmsv => q{h:mm:ss a v},
			hmv => q{h:mm a v},
			ms => q{m:ss},
			yM => q{M/y},
			yMEd => q{E d/M/y},
			yMM => q{MM/y},
			yMMM => q{MMM y},
			yMMMEd => q{E d MMM y},
			yMMMM => q{MMMM y},
			yMMMd => q{d MMM y},
			yMd => q{dd/MM/y},
			yQQQ => q{QQQ y},
			yQQQQ => q{QQQQ y},
			yw => q{'imalas' w 'n' Y},
		},
	} },
);

has 'datetime_formats_append_item' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
	} },
);

has 'datetime_formats_interval' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
			Gy => {
				G => q{y G – y G},
				y => q{y – y G},
			},
			GyM => {
				G => q{MM/y GGGGG – MM/y GGGGG},
				M => q{MM/y – MM/y GGGGG},
				y => q{MM/y – MM/y GGGGG},
			},
			GyMEd => {
				G => q{E dd/MM/y GGGGG – E dd/MM/y GGGGG},
				M => q{E dd/MM/y – E dd/MM/y GGGGG},
				d => q{E dd/MM/y – E dd/MM/y GGGGG},
				y => q{E dd/MM/y – E dd/MM/y GGGGG},
			},
			GyMMM => {
				G => q{MMM y G – MMM y G},
				M => q{MMM – MMM y G},
				y => q{MMM y – MMM y G},
			},
			GyMMMEd => {
				G => q{E d MMM y G – E d MMM y G},
				M => q{E d MMM – E d MMM y G},
				d => q{E d MMM – E d MMM y G},
				y => q{E d MMM y – E d MMM y G},
			},
			GyMMMd => {
				G => q{d MMM y G – d MMM y G},
				M => q{d MMM – d MMM y G},
				d => q{d– d MMM y G},
				y => q{d MMM y – d MMM y G},
			},
			GyMd => {
				G => q{dd/MM/y GGGGG – dd/MM/y GGGGG},
				M => q{dd/MM/y – dd/MM/y GGGGG},
				d => q{dd/MM/y – dd/MM/y GGGGG},
				y => q{dd/MM/y – dd/MM/y GGGGG},
			},
			MEd => {
				M => q{E dd/MM – E dd/MM},
				d => q{E dd/MM – E dd/MM},
			},
			MMM => {
				M => q{MMM – MMM},
			},
			MMMEd => {
				M => q{E d MMM – E d MMM},
				d => q{E d MMM – E d MMM},
			},
			MMMd => {
				M => q{d MMM – d MMM},
				d => q{d – d MMM},
			},
			Md => {
				M => q{dd/MM – dd/MM},
				d => q{dd/MM – dd/MM},
			},
			y => {
				y => q{y – y G},
			},
			yM => {
				M => q{MM/y – MM/y GGGGG},
				y => q{MM/y – MM/y GGGGG},
			},
			yMEd => {
				M => q{E dd/MM/y – E dd/MM/y GGGGG},
				d => q{E dd/MM/y – E dd/MM/y GGGGG},
				y => q{E dd/MM/y – E dd/MM/y GGGGG},
			},
			yMMM => {
				M => q{MMM – MMM y G},
				y => q{MMM y – MMM y G},
			},
			yMMMEd => {
				M => q{E d MMM – E d MMM y G},
				d => q{E d MMM – E d MMM y G},
				y => q{E d MMM y – E d MMM y G},
			},
			yMMMM => {
				M => q{MMM – MMM y G},
				y => q{MMM y – MMM y G},
			},
			yMMMd => {
				M => q{d - MMM – d MMM y G},
				d => q{d – d MMM y G},
				y => q{d MMM y – d MMM y G},
			},
			yMd => {
				M => q{dd/MM/y – dd/MM/y GGGGG},
				d => q{dd/MM/y – dd/MM/y GGGGG},
				y => q{dd/MM/y – dd/MM/y GGGGG},
			},
		},
		'gregorian' => {
			Gy => {
				y => q{y – y G},
			},
			GyM => {
				G => q{MM/y GGGGG – MM/y GGGGG},
				M => q{M–M/y G},
				y => q{MM/y – MM/y GGGGG},
			},
			GyMEd => {
				G => q{E d/MM/y GGGGG – E d/MM/y GGGGG},
				M => q{E d/MM/y – E d/MM/y GGGGG},
				d => q{E d/MM/y – E d/MM/y GGGGG},
				y => q{E d/MM/y – E d/MM/y GGGGG},
			},
			GyMMM => {
				G => q{MMM y G – MMM y G},
				M => q{MMM – MMM y G},
				y => q{MMM y – MMM y G},
			},
			GyMMMEd => {
				G => q{E d MMM y G – E d MMM y G},
				M => q{E d MMM – E d MMM y G},
				d => q{E d MMM y – E d MMM y G},
				y => q{E d MMM y – E d MMM y G},
			},
			GyMMMd => {
				G => q{d MMM y G – d MMM y G},
				M => q{d MMM – d MMM y G},
				d => q{d – d MMM y G},
				y => q{d MMM y – d MMM y G},
			},
			GyMd => {
				G => q{dd/MM/y GGGGG – dd/MM/y GGGGG},
				M => q{d/MM/y – d/MM/y GGGGG},
				d => q{dd/MM/y – dd/MM/y G},
				y => q{d/MM/y – d/MM/y GGGGG},
			},
			H => {
				H => q{HH – HH},
			},
			Hm => {
				H => q{HH:mm – HH:mm},
				m => q{HH:mm – HH:mm},
			},
			Hmv => {
				H => q{HH:mm – HH:mm v},
				m => q{HH:mm – HH:mm v},
			},
			Hv => {
				H => q{HH – HH v},
			},
			M => {
				M => q{M – M},
			},
			MEd => {
				M => q{E dd/MM – E dd/MM},
				d => q{E dd/MM – E dd/MM},
			},
			MMM => {
				M => q{MMM – MMM},
			},
			MMMEd => {
				M => q{E d MMM – E d MMM},
				d => q{E d – E d MMM},
			},
			MMMd => {
				M => q{d MMM – d MMM},
				d => q{d–d MMM},
			},
			Md => {
				M => q{dd/MM – dd/MM},
				d => q{dd/MM – dd/MM},
			},
			d => {
				d => q{d – d},
			},
			h => {
				a => q{h a – h a},
				h => q{h – h a},
			},
			hm => {
				a => q{h:mm a – h:mm a},
				h => q{h:mm – h:mm a},
				m => q{h:mm – h:mm a},
			},
			hmv => {
				a => q{h:mm a – h:mm a v},
				h => q{h:mm – h:mm a v},
				m => q{h:mm – h:mm a v},
			},
			hv => {
				a => q{h a – h a v},
				h => q{h – h a v},
			},
			y => {
				y => q{y – y},
			},
			yM => {
				M => q{MM/y – MM/y},
				y => q{MM/y – MM/y},
			},
			yMEd => {
				M => q{E dd/MM/y – E dd/MM/y},
				d => q{E dd/MM/y – E dd/MM/y},
				y => q{E dd/MM/y – E dd/MM/y},
			},
			yMMM => {
				M => q{MMM–MMM y},
				y => q{MMM y – MMM y},
			},
			yMMMEd => {
				M => q{E d MMM – E d MMM y},
				d => q{E d – E d MMM y},
				y => q{E d MMM y – E d MMM y},
			},
			yMMMM => {
				M => q{MMMM – MMMM y},
				y => q{MMMM y – MMMM y},
			},
			yMMMd => {
				M => q{d MMM – d MMM y},
				d => q{d–d MMM y},
				y => q{d MMM y – d MMM y},
			},
			yMd => {
				M => q{dd/MM/y – dd/MM/y},
				d => q{dd/MM/y – dd/MM/y},
				y => q{dd/MM/y – dd/MM/y},
			},
		},
	} },
);

has 'time_zone_names' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default	=> sub { {
		gmtFormat => q(KLG {0}),
		gmtZeroFormat => q(KLG),
		regionFormat => q(Akud: {0}),
		regionFormat => q({0} Akud n unebdu),
		regionFormat => q({0} Akud amezday),
		'Afghanistan' => {
			long => {
				'standard' => q#Akud n Afɣanistan#,
			},
		},
		'Africa/Abidjan' => {
			exemplarCity => q#Abiǧan#,
		},
		'Africa/Accra' => {
			exemplarCity => q#Akṛa#,
		},
		'Africa/Addis_Ababa' => {
			exemplarCity => q#Adis Ababa#,
		},
		'Africa/Algiers' => {
			exemplarCity => q#Lezzayer#,
		},
		'Africa/Bamako' => {
			exemplarCity => q#Bamaku#,
		},
		'Africa/Bangui' => {
			exemplarCity => q#Bangi#,
		},
		'Africa/Bissau' => {
			exemplarCity => q#Bisaw#,
		},
		'Africa/Blantyre' => {
			exemplarCity => q#Blantir#,
		},
		'Africa/Brazzaville' => {
			exemplarCity => q#Braẓavil#,
		},
		'Africa/Cairo' => {
			exemplarCity => q#Lqahira#,
		},
		'Africa/Casablanca' => {
			exemplarCity => q#Kaẓablanka#,
		},
		'Africa/Ceuta' => {
			exemplarCity => q#Sebta#,
		},
		'Africa/Conakry' => {
			exemplarCity => q#Kunakri#,
		},
		'Africa/Dar_es_Salaam' => {
			exemplarCity => q#Dar Salam#,
		},
		'Africa/Djibouti' => {
			exemplarCity => q#Ǧibuti#,
		},
		'Africa/Douala' => {
			exemplarCity => q#Dwala#,
		},
		'Africa/El_Aaiun' => {
			exemplarCity => q#Leɛyun#,
		},
		'Africa/Freetown' => {
			exemplarCity => q#Friṭawn#,
		},
		'Africa/Gaborone' => {
			exemplarCity => q#Gaburun#,
		},
		'Africa/Harare' => {
			exemplarCity => q#Harari#,
		},
		'Africa/Johannesburg' => {
			exemplarCity => q#Juhanisburg#,
		},
		'Africa/Khartoum' => {
			exemplarCity => q#Xaṛtum#,
		},
		'Africa/Kinshasa' => {
			exemplarCity => q#Kincaṣa#,
		},
		'Africa/Lagos' => {
			exemplarCity => q#Lagus#,
		},
		'Africa/Libreville' => {
			exemplarCity => q#Libervil#,
		},
		'Africa/Lome' => {
			exemplarCity => q#Lumi#,
		},
		'Africa/Luanda' => {
			exemplarCity => q#Lwanda#,
		},
		'Africa/Lubumbashi' => {
			exemplarCity => q#Lubumbaci#,
		},
		'Africa/Lusaka' => {
			exemplarCity => q#Luzaka#,
		},
		'Africa/Malabo' => {
			exemplarCity => q#Malabu#,
		},
		'Africa/Maputo' => {
			exemplarCity => q#Mapuṭu#,
		},
		'Africa/Maseru' => {
			exemplarCity => q#Masiru#,
		},
		'Africa/Mbabane' => {
			exemplarCity => q#Mbaban#,
		},
		'Africa/Mogadishu' => {
			exemplarCity => q#Muqadicu#,
		},
		'Africa/Monrovia' => {
			exemplarCity => q#Munṛuvya#,
		},
		'Africa/Nairobi' => {
			exemplarCity => q#Nayrubi#,
		},
		'Africa/Ndjamena' => {
			exemplarCity => q#Nǧamina#,
		},
		'Africa/Niamey' => {
			exemplarCity => q#Nyamey#,
		},
		'Africa/Nouakchott' => {
			exemplarCity => q#Nwaqcuṭ#,
		},
		'Africa/Ouagadougou' => {
			exemplarCity => q#Wagadugu#,
		},
		'Africa/Porto-Novo' => {
			exemplarCity => q#Puṛtu Nuvu#,
		},
		'Africa/Sao_Tome' => {
			exemplarCity => q#Saw Ṭumi#,
		},
		'Africa/Tripoli' => {
			exemplarCity => q#Trablus#,
		},
		'Africa/Tunis' => {
			exemplarCity => q#Tunes#,
		},
		'Africa/Windhoek' => {
			exemplarCity => q#Windhek#,
		},
		'Africa_Central' => {
			long => {
				'standard' => q#Akud n Tefriqt talemmast#,
			},
		},
		'Africa_Eastern' => {
			long => {
				'standard' => q#Akud n Tefriqt n usammar#,
			},
		},
		'Africa_Southern' => {
			long => {
				'standard' => q#Akud amezday n Tefriqt n unẓul#,
			},
		},
		'Africa_Western' => {
			long => {
				'daylight' => q#Akud n unebdu n Tefriqt n umalu#,
				'generic' => q#Akud n Tefriqt n umalu#,
				'standard' => q#Akud amezday n Tefriqt n umalu#,
			},
		},
		'Alaska' => {
			long => {
				'daylight' => q#Akud n unebdu n Alaska#,
				'generic' => q#Akud n Alaska#,
				'standard' => q#Akud amezday n Alaska#,
			},
		},
		'Amazon' => {
			long => {
				'daylight' => q#Akud n unebdu n Amaẓun#,
				'generic' => q#Akud n Amaẓun#,
				'standard' => q#Akud amezday n Amaẓun#,
			},
		},
		'America/Anchorage' => {
			exemplarCity => q#Ankuraj#,
		},
		'America/Anguilla' => {
			exemplarCity => q#Angila#,
		},
		'America/Antigua' => {
			exemplarCity => q#Antiga#,
		},
		'America/Argentina/San_Juan' => {
			exemplarCity => q#San Xwan#,
		},
		'America/Argentina/San_Luis' => {
			exemplarCity => q#San Lwis#,
		},
		'America/Argentina/Tucuman' => {
			exemplarCity => q#Tukuman#,
		},
		'America/Argentina/Ushuaia' => {
			exemplarCity => q#Ucwaya#,
		},
		'America/Asuncion' => {
			exemplarCity => q#Asunsyun#,
		},
		'America/Bahia' => {
			exemplarCity => q#Bahya#,
		},
		'America/Bahia_Banderas' => {
			exemplarCity => q#Bahya Bandiras#,
		},
		'America/Barbados' => {
			exemplarCity => q#Barbadus#,
		},
		'America/Belize' => {
			exemplarCity => q#Biliz#,
		},
		'America/Blanc-Sablon' => {
			exemplarCity => q#Blun-Sablun#,
		},
		'America/Bogota' => {
			exemplarCity => q#Buguṭa#,
		},
		'America/Boise' => {
			exemplarCity => q#Bwaẓ#,
		},
		'America/Cambridge_Bay' => {
			exemplarCity => q#Kambriǧ Bay#,
		},
		'America/Campo_Grande' => {
			exemplarCity => q#Kumpu Grandi#,
		},
		'America/Cancun' => {
			exemplarCity => q#Kankun#,
		},
		'America/Caracas' => {
			exemplarCity => q#Karakas#,
		},
		'America/Catamarca' => {
			exemplarCity => q#Katamarka#,
		},
		'America/Cayenne' => {
			exemplarCity => q#Kayan#,
		},
		'America/Cayman' => {
			exemplarCity => q#Kayman#,
		},
		'America/Chicago' => {
			exemplarCity => q#Cikagu#,
		},
		'America/Chihuahua' => {
			exemplarCity => q#Ciwawa#,
		},
		'America/Coral_Harbour' => {
			exemplarCity => q#Atikukan#,
		},
		'America/Cordoba' => {
			exemplarCity => q#Kurduba#,
		},
		'America/Costa_Rica' => {
			exemplarCity => q#Kusta Rika#,
		},
		'America/Creston' => {
			exemplarCity => q#Kristun#,
		},
		'America/Curacao' => {
			exemplarCity => q#Kuračaw#,
		},
		'America/Danmarkshavn' => {
			exemplarCity => q#Danmarkcaven#,
		},
		'America/Dawson' => {
			exemplarCity => q#Dawsun#,
		},
		'America/Dawson_Creek' => {
			exemplarCity => q#Dawsun Krik#,
		},
		'America/Detroit' => {
			exemplarCity => q#Ditrwa#,
		},
		'America/Dominica' => {
			exemplarCity => q#Duminik#,
		},
		'America/Edmonton' => {
			exemplarCity => q#Idmuntun#,
		},
		'America/El_Salvador' => {
			exemplarCity => q#Salvadur#,
		},
		'America/Fort_Nelson' => {
			exemplarCity => q#Fuṛt Nilṣun#,
		},
		'America/Fortaleza' => {
			exemplarCity => q#Furṭaliza#,
		},
		'America/Godthab' => {
			exemplarCity => q#Nuk#,
		},
		'America/Grenada' => {
			exemplarCity => q#Grunada#,
		},
		'America/Guadeloupe' => {
			exemplarCity => q#Gwadalupi#,
		},
		'America/Guatemala' => {
			exemplarCity => q#Gwatimala#,
		},
		'America/Guayaquil' => {
			exemplarCity => q#Gayakil#,
		},
		'America/Guyana' => {
			exemplarCity => q#Guyan#,
		},
		'America/Jamaica' => {
			exemplarCity => q#Jamayka#,
		},
		'America/Managua' => {
			exemplarCity => q#Managa#,
		},
		'America/Marigot' => {
			exemplarCity => q#Mariguṭ#,
		},
		'America/Martinique' => {
			exemplarCity => q#Martinik#,
		},
		'America/Mendoza' => {
			exemplarCity => q#Minduẓa#,
		},
		'America/Merida' => {
			exemplarCity => q#Merida#,
		},
		'America/Noronha' => {
			exemplarCity => q#Nuṛunha#,
		},
		'America/Paramaribo' => {
			exemplarCity => q#Paramaribu#,
		},
		'America/Porto_Velho' => {
			exemplarCity => q#Purtu Vilhu#,
		},
		'America/Recife' => {
			exemplarCity => q#Risif#,
		},
		'America/Rio_Branco' => {
			exemplarCity => q#Ryu Branku#,
		},
		'America/Santiago' => {
			exemplarCity => q#Santyagu#,
		},
		'America/Sao_Paulo' => {
			exemplarCity => q#Saw Pawlu#,
		},
		'America_Central' => {
			long => {
				'daylight' => q#Akud n unebdu n tlemmast n Marikan#,
				'generic' => q#Akud n tlemmast n Marikan#,
				'standard' => q#Akud amezday n tlemmast n Marikan#,
			},
		},
		'America_Eastern' => {
			long => {
				'daylight' => q#Akud n unebdu n usammar n Marikan#,
				'generic' => q#Akud n usammar n Marikan#,
				'standard' => q#Akud amezday n usammar n Marikan#,
			},
		},
		'America_Mountain' => {
			long => {
				'daylight' => q#Akud n unebdu n yidurar n Marikan#,
				'generic' => q#Akud n yidurar n Marikan#,
				'standard' => q#Akud amezday n yidurar n Marikan#,
			},
		},
		'America_Pacific' => {
			long => {
				'daylight' => q#Akud umelwi n unebdu#,
				'generic' => q#Akud amelwi#,
				'standard' => q#Akud amezday amelwi#,
			},
		},
		'Antarctica/Macquarie' => {
			exemplarCity => q#Makari#,
		},
		'Antarctica/Vostok' => {
			exemplarCity => q#Vusṭuk#,
		},
		'Apia' => {
			long => {
				'daylight' => q#Akud n unebdu n Apya#,
				'generic' => q#Akud n Apya#,
				'standard' => q#Akud amezday n Apya#,
			},
		},
		'Arabian' => {
			long => {
				'daylight' => q#Akud aɛrab n unebdu#,
				'generic' => q#Akud aɛrab#,
				'standard' => q#Akud aɛrab amezday#,
			},
		},
		'Arctic/Longyearbyen' => {
			exemplarCity => q#Lungyerbyen#,
		},
		'Argentina' => {
			long => {
				'daylight' => q#Akud n unebdu n Arjuntin#,
				'generic' => q#Akud n Arjuntin#,
				'standard' => q#Akud amezday n Arjuntin#,
			},
		},
		'Argentina_Western' => {
			long => {
				'daylight' => q#Akud n unebdu n Arjuntin n usammar#,
				'generic' => q#Akud n Arjuntin n usammar#,
				'standard' => q#Akud amezday n Arjuntin n usammar#,
			},
		},
		'Armenia' => {
			long => {
				'daylight' => q#Akud n unebdu n Arminya#,
				'generic' => q#Akud n Arminya#,
				'standard' => q#Akud amezday n Arminya#,
			},
		},
		'Asia/Aden' => {
			exemplarCity => q#Ɛaden#,
		},
		'Asia/Almaty' => {
			exemplarCity => q#Almati#,
		},
		'Asia/Amman' => {
			exemplarCity => q#Ɛemman#,
		},
		'Asia/Anadyr' => {
			exemplarCity => q#Anadir#,
		},
		'Asia/Baghdad' => {
			exemplarCity => q#Beɣdad#,
		},
		'Asia/Bahrain' => {
			exemplarCity => q#Baḥrin#,
		},
		'Asia/Bangkok' => {
			exemplarCity => q#Bangkuk#,
		},
		'Asia/Beirut' => {
			exemplarCity => q#Bayrut#,
		},
		'Asia/Brunei' => {
			exemplarCity => q#Brunay#,
		},
		'Asia/Calcutta' => {
			exemplarCity => q#Kulkata#,
		},
		'Asia/Colombo' => {
			exemplarCity => q#Kulumbu#,
		},
		'Asia/Damascus' => {
			exemplarCity => q#Damas#,
		},
		'Asia/Dubai' => {
			exemplarCity => q#Dubay#,
		},
		'Asia/Gaza' => {
			exemplarCity => q#Ɣezza#,
		},
		'Asia/Hebron' => {
			exemplarCity => q#Hebrun#,
		},
		'Asia/Hong_Kong' => {
			exemplarCity => q#Hung Kung#,
		},
		'Asia/Hovd' => {
			exemplarCity => q#Huvd#,
		},
		'Asia/Jerusalem' => {
			exemplarCity => q#Jirusalem#,
		},
		'Asia/Karachi' => {
			exemplarCity => q#Karaci#,
		},
		'Asia/Katmandu' => {
			exemplarCity => q#Katmandu#,
		},
		'Asia/Kuala_Lumpur' => {
			exemplarCity => q#Kwala Lumpur#,
		},
		'Asia/Kuwait' => {
			exemplarCity => q#Kwit#,
		},
		'Asia/Macau' => {
			exemplarCity => q#Makaw#,
		},
		'Asia/Muscat' => {
			exemplarCity => q#Musqaṭ#,
		},
		'Asia/Nicosia' => {
			exemplarCity => q#Nikusya#,
		},
		'Asia/Pyongyang' => {
			exemplarCity => q#Pyungyung#,
		},
		'Asia/Qatar' => {
			exemplarCity => q#Qaṭar#,
		},
		'Asia/Qostanay' => {
			exemplarCity => q#Kustanay#,
		},
		'Asia/Rangoon' => {
			exemplarCity => q#Rangoon#,
		},
		'Asia/Riyadh' => {
			exemplarCity => q#Riyaḍ#,
		},
		'Asia/Seoul' => {
			exemplarCity => q#Siyul#,
		},
		'Asia/Shanghai' => {
			exemplarCity => q#Cangay#,
		},
		'Asia/Singapore' => {
			exemplarCity => q#Sangapur#,
		},
		'Asia/Taipei' => {
			exemplarCity => q#Taypay#,
		},
		'Asia/Tokyo' => {
			exemplarCity => q#Tukyu#,
		},
		'Asia/Ulaanbaatar' => {
			exemplarCity => q#Ulanbatar#,
		},
		'Asia/Yerevan' => {
			exemplarCity => q#Yervan#,
		},
		'Atlantic' => {
			long => {
				'daylight' => q#Akud aṭlasan n unebdu#,
				'generic' => q#Akud aṭlasan#,
				'standard' => q#Akud amezday aṭlasan#,
			},
		},
		'Atlantic/Azores' => {
			exemplarCity => q#Aẓuris#,
		},
		'Atlantic/Bermuda' => {
			exemplarCity => q#Birmud#,
		},
		'Atlantic/Canary' => {
			exemplarCity => q#Tigzirin n Kanari#,
		},
		'Atlantic/Cape_Verde' => {
			exemplarCity => q#Kap Vir#,
		},
		'Atlantic/Faeroe' => {
			exemplarCity => q#Farwi#,
		},
		'Atlantic/Madeira' => {
			exemplarCity => q#Madira#,
		},
		'Atlantic/South_Georgia' => {
			exemplarCity => q#Jyurjya n unẓul#,
		},
		'Atlantic/St_Helena' => {
			exemplarCity => q#Sant Ilina#,
		},
		'Australia/Adelaide' => {
			exemplarCity => q#Adilayid#,
		},
		'Australia/Brisbane' => {
			exemplarCity => q#Brisban#,
		},
		'Australia/Melbourne' => {
			exemplarCity => q#Malburn#,
		},
		'Australia/Sydney' => {
			exemplarCity => q#Sidni#,
		},
		'Australia_Central' => {
			long => {
				'daylight' => q#Akud n unebdu n Ustralya talemmast#,
				'generic' => q#Akud n Ustralya talemmast#,
				'standard' => q#Akud amezday n Ustralya talemmast#,
			},
		},
		'Australia_CentralWestern' => {
			long => {
				'daylight' => q#Akud n unebdu n tlemmast n umalu n Ustralya#,
				'generic' => q#Akud n tlemmast n umalu n Ustralya#,
				'standard' => q#Akud amezday n tlemmast n umalu n Ustralya#,
			},
		},
		'Australia_Eastern' => {
			long => {
				'daylight' => q#Akud n unebdu n Ustralya n usammar#,
				'generic' => q#Akud n Ustralya n usammar#,
				'standard' => q#Akud amezday n Ustralya n usammar#,
			},
		},
		'Australia_Western' => {
			long => {
				'daylight' => q#Akud n unebdu Ustralya n umalu#,
				'generic' => q#Akud n Ustralya n umalu#,
				'standard' => q#Akud amezday n Ustralya n umalu#,
			},
		},
		'Azerbaijan' => {
			long => {
				'daylight' => q#Akud n unebdu n Aẓerbiǧan#,
				'generic' => q#Akud n Aẓerbiǧan#,
				'standard' => q#Akud amezday n Aẓerbiǧan#,
			},
		},
		'Azores' => {
			long => {
				'daylight' => q#Akud n unebdu n Aẓuris#,
				'generic' => q#Akud n Aẓuris#,
				'standard' => q#Akud amezday n Aẓuris#,
			},
		},
		'Bangladesh' => {
			long => {
				'daylight' => q#Akud n unebdu n Bangladac#,
				'generic' => q#Akud n Bangladac#,
				'standard' => q#Akud amezday n Bangladac#,
			},
		},
		'Bhutan' => {
			long => {
				'standard' => q#Akud n Butan#,
			},
		},
		'Bolivia' => {
			long => {
				'standard' => q#Akud n Bulivi#,
			},
		},
		'Brasilia' => {
			long => {
				'daylight' => q#Akud n unebdu n Braẓilya#,
				'generic' => q#Akud n Braẓilya#,
				'standard' => q#Akud amezday n Braẓilya#,
			},
		},
		'Brunei' => {
			long => {
				'standard' => q#Akud n Brunay Dar Salam#,
			},
		},
		'Cape_Verde' => {
			long => {
				'daylight' => q#Akud n unebdu n Kap Vir#,
				'generic' => q#Akud n Kap Vir#,
				'standard' => q#Akud amezday n Kap Vir#,
			},
		},
		'Chamorro' => {
			long => {
				'standard' => q#Akud amezday n Camurru#,
			},
		},
		'Chatham' => {
			long => {
				'daylight' => q#Akud n unebdu Catham#,
				'generic' => q#Akud n Catham#,
				'standard' => q#Akud amezday n Catham#,
			},
		},
		'Chile' => {
			long => {
				'daylight' => q#Akud n unebdu n Cili#,
				'generic' => q#Akud n Cili#,
				'standard' => q#Akud amezday n Cili#,
			},
		},
		'China' => {
			long => {
				'daylight' => q#Akud n unebdu n Cin#,
				'generic' => q#Akud n Cin#,
				'standard' => q#Akud amezday n Cin#,
			},
		},
		'Christmas' => {
			long => {
				'standard' => q#Akud n Tegzirin n Krismas#,
			},
		},
		'Cocos' => {
			long => {
				'standard' => q#Akud n Tegzirin n Kuku#,
			},
		},
		'Colombia' => {
			long => {
				'daylight' => q#Akud n unebdu n Kulumbya#,
				'generic' => q#Akud n Kulumbya#,
				'standard' => q#Akud amezday n Kulumbya#,
			},
		},
		'Cook' => {
			long => {
				'daylight' => q#Akud n unebdu n Tegzirin n Kuk#,
				'generic' => q#Akud n Tegzirin n Kuk#,
				'standard' => q#Akud amezday n Tegzirin n Kuk#,
			},
		},
		'Cuba' => {
			long => {
				'daylight' => q#Akud n unebdu n Kuba#,
				'generic' => q#Akud n Kuba#,
				'standard' => q#Akud amezday n Kuba#,
			},
		},
		'Davis' => {
			long => {
				'standard' => q#Akud n Davis#,
			},
		},
		'DumontDUrville' => {
			long => {
				'standard' => q#Akud n Dumont-d’Urville#,
			},
		},
		'East_Timor' => {
			long => {
				'standard' => q#Akud n Timur n usammar#,
			},
		},
		'Easter' => {
			long => {
				'daylight' => q#Akud n unebdu n Island n usammar#,
				'generic' => q#Akud n Island n usammar#,
				'standard' => q#Akud amezday n Island n usammar#,
			},
		},
		'Ecuador' => {
			long => {
				'standard' => q#Akud n Ikwaṭur#,
			},
		},
		'Etc/UTC' => {
			long => {
				'standard' => q#Akud agraɣlan imyuddsen#,
			},
		},
		'Etc/Unknown' => {
			exemplarCity => q#Aɣrem Arussin#,
		},
		'Europe/Amsterdam' => {
			exemplarCity => q#Amestirdam#,
		},
		'Europe/Andorra' => {
			exemplarCity => q#Andura#,
		},
		'Europe/Athens' => {
			exemplarCity => q#Atina#,
		},
		'Europe/Belgrade' => {
			exemplarCity => q#Bilgrad#,
		},
		'Europe/Brussels' => {
			exemplarCity => q#Bruksel#,
		},
		'Europe/Bucharest' => {
			exemplarCity => q#Buxarest#,
		},
		'Europe/Copenhagen' => {
			exemplarCity => q#Kupenhagen#,
		},
		'Europe/Dublin' => {
			exemplarCity => q#Dublan#,
			long => {
				'daylight' => q#Agud amezday n Irland#,
			},
		},
		'Europe/Gibraltar' => {
			exemplarCity => q#Jibralṭar#,
		},
		'Europe/Guernsey' => {
			exemplarCity => q#Girnizey#,
		},
		'Europe/Helsinki' => {
			exemplarCity => q#Hilsinki#,
		},
		'Europe/Isle_of_Man' => {
			exemplarCity => q#Tigzirt n Man#,
		},
		'Europe/Istanbul' => {
			exemplarCity => q#Isṭanbul#,
		},
		'Europe/Jersey' => {
			exemplarCity => q#Jirzey#,
		},
		'Europe/Kiev' => {
			exemplarCity => q#Kyev#,
		},
		'Europe/Lisbon' => {
			exemplarCity => q#Lizbun#,
		},
		'Europe/London' => {
			exemplarCity => q#Lundun#,
			long => {
				'daylight' => q#Akud n unebdu n Britanya#,
			},
		},
		'Europe/Luxembourg' => {
			exemplarCity => q#Luksemburg#,
		},
		'Europe/Mariehamn' => {
			exemplarCity => q#Marihamn#,
		},
		'Europe/Monaco' => {
			exemplarCity => q#Munaku#,
		},
		'Europe/Moscow' => {
			exemplarCity => q#Musku#,
		},
		'Europe/Oslo' => {
			exemplarCity => q#Uṣlu#,
		},
		'Europe/Prague' => {
			exemplarCity => q#Prag#,
		},
		'Europe/Rome' => {
			exemplarCity => q#Rum#,
		},
		'Europe/San_Marino' => {
			exemplarCity => q#San Marinu#,
		},
		'Europe/Sarajevo' => {
			exemplarCity => q#Sarajivu#,
		},
		'Europe/Sofia' => {
			exemplarCity => q#Sofya#,
		},
		'Europe/Stockholm' => {
			exemplarCity => q#Sṭukhulm#,
		},
		'Europe/Tallinn' => {
			exemplarCity => q#Tallin#,
		},
		'Europe/Tirane' => {
			exemplarCity => q#Tiran#,
		},
		'Europe/Vatican' => {
			exemplarCity => q#Vatikan#,
		},
		'Europe/Vienna' => {
			exemplarCity => q#Vyenna#,
		},
		'Europe/Vilnius' => {
			exemplarCity => q#Vilnyus#,
		},
		'Europe/Zurich' => {
			exemplarCity => q#Zurix#,
		},
		'Europe_Central' => {
			long => {
				'daylight' => q#Akud n unebdu n Turuft talemmast#,
				'generic' => q#Akud n Turuft talemmast#,
				'standard' => q#Akud amezday n Turuft talemmast#,
			},
		},
		'Europe_Eastern' => {
			long => {
				'daylight' => q#Akud n unebdu n Turuft n usammar#,
				'generic' => q#Akud n Turuft n usammar#,
				'standard' => q#Akud amezday n Turuft n usammar#,
			},
		},
		'Europe_Further_Eastern' => {
			long => {
				'standard' => q#Akud nniḍen n Turuft n Usammar#,
			},
		},
		'Europe_Western' => {
			long => {
				'daylight' => q#Akud n unebdu Turuft n umalu#,
				'generic' => q#Akud n Turuft n umalu#,
				'standard' => q#Akud amezday n Turuft n umalu#,
			},
		},
		'Falkland' => {
			long => {
				'daylight' => q#Akud n unebdu Tegzirin n Falkland#,
				'generic' => q#Akud n Tegzirin n Falkland#,
				'standard' => q#Akud amezday n Tegzirin n Falkland#,
			},
		},
		'Fiji' => {
			long => {
				'daylight' => q#Akud n unebdu n Fiji#,
				'generic' => q#Akud n Fiji#,
				'standard' => q#Akud amezday n Fiji#,
			},
		},
		'French_Guiana' => {
			long => {
				'standard' => q#Akud n Gwiyan tafransist#,
			},
		},
		'French_Southern' => {
			long => {
				'standard' => q#Akud n wakal n unẓul d Antarktik n Fransa#,
			},
		},
		'GMT' => {
			long => {
				'standard' => q#Akud alemmas n Greenwich#,
			},
		},
		'Galapagos' => {
			long => {
				'standard' => q#Akud n Galapagus#,
			},
		},
		'Gambier' => {
			long => {
				'standard' => q#Akud n Tegzirin Gambyer#,
			},
		},
		'Georgia' => {
			long => {
				'daylight' => q#Akud n unebdu n Jyurjya#,
				'generic' => q#Akud n Jyurjya#,
				'standard' => q#Akud amezday n Jyurjya#,
			},
		},
		'Gilbert_Islands' => {
			long => {
				'standard' => q#Akud n Tegzirin Jilbar#,
			},
		},
		'Greenland_Eastern' => {
			long => {
				'daylight' => q#Akud n unebdu n Grinland n usammar#,
				'generic' => q#Akud n Grinland n usammar#,
				'standard' => q#Akud amezday n Grinland n usammar#,
			},
		},
		'Greenland_Western' => {
			long => {
				'daylight' => q#Akud n unebdu n Grinland n umalu#,
				'generic' => q#Akud n Grinland n umalu#,
				'standard' => q#Akud amezday n Grinland n umalu#,
			},
		},
		'Gulf' => {
			long => {
				'standard' => q#Akud amezday n Gulf#,
			},
		},
		'Guyana' => {
			long => {
				'standard' => q#Akud n Gwiyan#,
			},
		},
		'Hawaii_Aleutian' => {
			long => {
				'daylight' => q#Akud n unebdu n Haway-Aliwsyan#,
				'generic' => q#Akud n Haway-Aliwsyan#,
				'standard' => q#Akud amezday n Haway-Aliwsyan#,
			},
		},
		'Hong_Kong' => {
			long => {
				'daylight' => q#Akud n unebdu n Hung Kung#,
				'generic' => q#Akud n Hung Kung#,
				'standard' => q#Akud amezday n Hung Kung#,
			},
		},
		'Hovd' => {
			long => {
				'daylight' => q#Akud n unebdu n Huvd#,
				'generic' => q#Akud n Huvd#,
				'standard' => q#Akud amezday n Huvd#,
			},
		},
		'India' => {
			long => {
				'standard' => q#Akud amezday n Lhend#,
			},
		},
		'Indian/Antananarivo' => {
			exemplarCity => q#Antananarivu#,
		},
		'Indian/Chagos' => {
			exemplarCity => q#Cagus#,
		},
		'Indian/Christmas' => {
			exemplarCity => q#Krismas#,
		},
		'Indian/Cocos' => {
			exemplarCity => q#Kuku#,
		},
		'Indian/Comoro' => {
			exemplarCity => q#Kumuṛ#,
		},
		'Indian/Kerguelen' => {
			exemplarCity => q#Kerglen#,
		},
		'Indian/Mahe' => {
			exemplarCity => q#Mahi#,
		},
		'Indian/Maldives' => {
			exemplarCity => q#Maldiv#,
		},
		'Indian/Mauritius' => {
			exemplarCity => q#Muris#,
		},
		'Indian/Mayotte' => {
			exemplarCity => q#Mayuṭ#,
		},
		'Indian/Reunion' => {
			exemplarCity => q#Riyunyun#,
		},
		'Indian_Ocean' => {
			long => {
				'standard' => q#Akud n Ugaraw Ahendi#,
			},
		},
		'Indochina' => {
			long => {
				'standard' => q#Akud n Inducin#,
			},
		},
		'Indonesia_Central' => {
			long => {
				'standard' => q#Akud n tlemmast n Andunisya#,
			},
		},
		'Indonesia_Eastern' => {
			long => {
				'standard' => q#Akud n usammar n Andunisya#,
			},
		},
		'Indonesia_Western' => {
			long => {
				'standard' => q#Akud n umalu n Andunisya#,
			},
		},
		'Iran' => {
			long => {
				'daylight' => q#Akud n unebdu Iran#,
				'generic' => q#Akud n Iran#,
				'standard' => q#Akud amezday n Iran#,
			},
		},
		'Irkutsk' => {
			long => {
				'daylight' => q#Akud n unebdu n Irkutsk#,
				'generic' => q#Akud n Irkutsk#,
				'standard' => q#Akud amezday n Irkutsk#,
			},
		},
		'Israel' => {
			long => {
				'daylight' => q#Akud n unebdu n Izrayil#,
				'generic' => q#Akud n Izrayil#,
				'standard' => q#Akud amezday n Izrayil#,
			},
		},
		'Japan' => {
			long => {
				'daylight' => q#Akud n unebdu n Japun#,
				'generic' => q#Akud n Japun#,
				'standard' => q#Akud amezday n Japun#,
			},
		},
		'Kazakhstan_Eastern' => {
			long => {
				'standard' => q#Akud n usammar n Kazaxistan#,
			},
		},
		'Kazakhstan_Western' => {
			long => {
				'standard' => q#Akud n n umalu n Kazaxistan#,
			},
		},
		'Korea' => {
			long => {
				'daylight' => q#Akud n unebdu n Kurya#,
				'generic' => q#Akud n Kurya#,
				'standard' => q#Akud amezday n Kurya#,
			},
		},
		'Kosrae' => {
			long => {
				'standard' => q#Akud n Kosrae#,
			},
		},
		'Krasnoyarsk' => {
			long => {
				'daylight' => q#Akud n unebdu n Krasnoyarsk#,
				'generic' => q#Akud n Krasnoyarsk#,
				'standard' => q#Akud amagnu n Krasnoyarsk#,
			},
		},
		'Kyrgystan' => {
			long => {
				'standard' => q#Akud n Kirigistan#,
			},
		},
		'Line_Islands' => {
			long => {
				'standard' => q#Akud n Tegzirin Lin#,
			},
		},
		'Lord_Howe' => {
			long => {
				'daylight' => q#Akud n Unebdu n Lord Howe#,
				'generic' => q#Akud n Lord Howe#,
				'standard' => q#Akud Amagnu n Lord Howe#,
			},
		},
		'Magadan' => {
			long => {
				'daylight' => q#Akud n unebdu n Magadan#,
				'generic' => q#Akud n Magadan#,
				'standard' => q#Akud amezday n Magadan#,
			},
		},
		'Malaysia' => {
			long => {
				'standard' => q#Akud n Malizya#,
			},
		},
		'Maldives' => {
			long => {
				'standard' => q#Akud n Maldiv#,
			},
		},
		'Marquesas' => {
			long => {
				'standard' => q#Akud n Tegzirin Markiz#,
			},
		},
		'Marshall_Islands' => {
			long => {
				'standard' => q#Akud n Tegzirin Marcal#,
			},
		},
		'Mauritius' => {
			long => {
				'daylight' => q#Akud n unebdu n Muris#,
				'generic' => q#Akud n Muris#,
				'standard' => q#Akud amezday n Muris#,
			},
		},
		'Mawson' => {
			long => {
				'standard' => q#Akud n Mawsun#,
			},
		},
		'Mexico_Pacific' => {
			long => {
				'daylight' => q#Akud amelwi n unebdu n Miksik#,
				'generic' => q#Akud amelwi n Miksik#,
				'standard' => q#Akud amezday amelwi n Miksik#,
			},
		},
		'Mongolia' => {
			long => {
				'daylight' => q#Akud n unebdu n Ulanbatar#,
				'generic' => q#Akud n Ulanbatar#,
				'standard' => q#Akud amezday n Ulanbatar#,
			},
		},
		'Moscow' => {
			long => {
				'daylight' => q#Akud n unebdu n Muṣku#,
				'generic' => q#Akud n Muṣku#,
				'standard' => q#Akud amezday n Muṣku#,
			},
		},
		'Myanmar' => {
			long => {
				'standard' => q#Akud n Myanmar#,
			},
		},
		'Nauru' => {
			long => {
				'standard' => q#Akud n Nuru#,
			},
		},
		'Nepal' => {
			long => {
				'standard' => q#Akud n Nipal#,
			},
		},
		'New_Caledonia' => {
			long => {
				'daylight' => q#Akud n unebdu n Kalidunya Tamaynut#,
				'generic' => q#Akud n Kalidunya Tamaynut#,
				'standard' => q#Akud amezday n Kalidunya Tamaynut#,
			},
		},
		'New_Zealand' => {
			long => {
				'daylight' => q#Akud n unebdu Ziland Tamaynut#,
				'generic' => q#Akud n Ziland Tamaynut#,
				'standard' => q#Akud amezday n Ziland Tamaynut#,
			},
		},
		'Newfoundland' => {
			long => {
				'daylight' => q#Akud n unebdu n Wakal amaynut#,
				'generic' => q#Akud n Wakal amaynut#,
				'standard' => q#Akud amezday n Wakal amaynut#,
			},
		},
		'Niue' => {
			long => {
				'standard' => q#Akud n Niyu#,
			},
		},
		'Norfolk' => {
			long => {
				'daylight' => q#Akud n unebdu n Tegzirt n Nurfulk#,
				'generic' => q#Akud n Tegzirt n Nurfulk#,
				'standard' => q#Akud amezday n Tegzirt n Nurfulk#,
			},
		},
		'Noronha' => {
			long => {
				'daylight' => q#Akud n unebdu n Firnandu n Nurunha#,
				'generic' => q#Akud n Firnandu n Nurunha#,
				'standard' => q#Akud amezday n Firnandu n Nurunha#,
			},
		},
		'Novosibirsk' => {
			long => {
				'daylight' => q#Akud n Unebdu n Novosibirsk#,
				'generic' => q#Akud n Novosibirsk#,
				'standard' => q#Akud Amagnu n Novosibirsk#,
			},
		},
		'Omsk' => {
			long => {
				'daylight' => q#Akud n Unebdu n Omsk#,
				'generic' => q#Akud n Omsk#,
				'standard' => q#Akud Amagnu n Omsk#,
			},
		},
		'Pacific/Apia' => {
			exemplarCity => q#Apya#,
		},
		'Pacific/Auckland' => {
			exemplarCity => q#Ukland#,
		},
		'Pacific/Chatham' => {
			exemplarCity => q#Catham#,
		},
		'Pacific/Enderbury' => {
			exemplarCity => q#Enderbury#,
		},
		'Pacific/Galapagos' => {
			exemplarCity => q#Galapagus#,
		},
		'Pacific/Gambier' => {
			exemplarCity => q#Gambyer#,
		},
		'Pacific/Honolulu' => {
			exemplarCity => q#Honolulu#,
		},
		'Pacific/Marquesas' => {
			exemplarCity => q#Markiz#,
		},
		'Pacific/Niue' => {
			exemplarCity => q#Niyu#,
		},
		'Pacific/Norfolk' => {
			exemplarCity => q#Nurfulk#,
		},
		'Pakistan' => {
			long => {
				'daylight' => q#Akud n unebdu n Pakistan#,
				'generic' => q#Akud n Pakistan#,
				'standard' => q#Akud amezday n Pakistan#,
			},
		},
		'Palau' => {
			long => {
				'standard' => q#Akud n Palau#,
			},
		},
		'Papua_New_Guinea' => {
			long => {
				'standard' => q#Akud n Papwa n Ɣinya Tamaynut#,
			},
		},
		'Paraguay' => {
			long => {
				'daylight' => q#Akud n unebdu n Paragway#,
				'generic' => q#Akud n Paragway#,
				'standard' => q#Akud amezday n Paragway#,
			},
		},
		'Peru' => {
			long => {
				'daylight' => q#Akud n unebdu n Piru#,
				'generic' => q#Akud n Piru#,
				'standard' => q#Akud amezday n Piru#,
			},
		},
		'Philippines' => {
			long => {
				'daylight' => q#Akud n unebdu n Filipin#,
				'generic' => q#Akud n Filipin#,
				'standard' => q#Akud amezday n Filipin#,
			},
		},
		'Phoenix_Islands' => {
			long => {
				'standard' => q#Akud n Tegzirin n Finiks#,
			},
		},
		'Pierre_Miquelon' => {
			long => {
				'daylight' => q#Akud n unebdu n San Pyir & Miklun#,
				'generic' => q#Akud n San Pyir & Miklun#,
				'standard' => q#Akud amezday n San Pyir & Miklun#,
			},
		},
		'Pitcairn' => {
			long => {
				'standard' => q#Akud n Pitkarn#,
			},
		},
		'Ponape' => {
			long => {
				'standard' => q#Akud n Ponape#,
			},
		},
		'Pyongyang' => {
			long => {
				'standard' => q#Akud n Pyungyung#,
			},
		},
		'Reunion' => {
			long => {
				'standard' => q#Akud n Riyunyun#,
			},
		},
		'Rothera' => {
			long => {
				'standard' => q#Akud n Rothera#,
			},
		},
		'Sakhalin' => {
			long => {
				'daylight' => q#Akud n Unebdu n Sakhalin#,
				'generic' => q#Akud n Sakhalin#,
				'standard' => q#Akud Amagnu n Sakhalin#,
			},
		},
		'Samoa' => {
			long => {
				'daylight' => q#Akud n unebdu n Samwa#,
				'generic' => q#Akud n Samwa#,
				'standard' => q#Akud amezday n Samwa#,
			},
		},
		'Seychelles' => {
			long => {
				'standard' => q#Akud n Saycal#,
			},
		},
		'Singapore' => {
			long => {
				'standard' => q#Akud amezday n Sangapur#,
			},
		},
		'Solomon' => {
			long => {
				'standard' => q#Akud n Tegzirin Salumun#,
			},
		},
		'South_Georgia' => {
			long => {
				'standard' => q#Akud n Jyurjya n unẓul#,
			},
		},
		'Suriname' => {
			long => {
				'standard' => q#Akud n Surinam#,
			},
		},
		'Syowa' => {
			long => {
				'standard' => q#Akud n Syuwa#,
			},
		},
		'Tahiti' => {
			long => {
				'standard' => q#Akud n Tahiti#,
			},
		},
		'Taipei' => {
			long => {
				'daylight' => q#Akud n unebdu n Taypay#,
				'generic' => q#Akud n Taypay#,
				'standard' => q#Akud amezday n Taypay#,
			},
		},
		'Tajikistan' => {
			long => {
				'standard' => q#Akud n Ṭajikistan#,
			},
		},
		'Tokelau' => {
			long => {
				'standard' => q#Akud n Ṭukilaw#,
			},
		},
		'Tonga' => {
			long => {
				'daylight' => q#Akud n unebdu n Ṭunga#,
				'generic' => q#Akud n Ṭunga#,
				'standard' => q#Akud amezday n Ṭunga#,
			},
		},
		'Truk' => {
			long => {
				'standard' => q#Akud n Chuuk#,
			},
		},
		'Turkmenistan' => {
			long => {
				'daylight' => q#Akud n unebdu n Turkmanistan#,
				'generic' => q#Akud n Turkmanistan#,
				'standard' => q#Akud amezday n Turkmanistan#,
			},
		},
		'Tuvalu' => {
			long => {
				'standard' => q#Akud n Tuvalu#,
			},
		},
		'Uruguay' => {
			long => {
				'daylight' => q#Akud n unebdu n Urugway#,
				'generic' => q#Akud n Urugway#,
				'standard' => q#Akud amezday n Urugway#,
			},
		},
		'Uzbekistan' => {
			long => {
				'daylight' => q#Akud n unebdu n Uzbikistan#,
				'generic' => q#Akud n Uzbikistan#,
				'standard' => q#Akud amezday n Uzbikistan#,
			},
		},
		'Vanuatu' => {
			long => {
				'daylight' => q#Akud n Unebdu n Vanuyatu#,
				'generic' => q#Akud n Vanuyatu#,
				'standard' => q#Akud Amagnu n Vanuyatu#,
			},
		},
		'Venezuela' => {
			long => {
				'standard' => q#Akud n Vinizwila#,
			},
		},
		'Vladivostok' => {
			long => {
				'daylight' => q#Akud n Unebdu n Vladivostok#,
				'generic' => q#Akud n Vladivostok#,
				'standard' => q#Akud Amagnu n Vladivostok#,
			},
		},
		'Volgograd' => {
			long => {
				'daylight' => q#Akud n Unebdu n Volgograd#,
				'generic' => q#Akud n Volgograd#,
				'standard' => q#Akud Amagnu n Volgograd#,
			},
		},
		'Vostok' => {
			long => {
				'standard' => q#Akud n Vostok#,
			},
		},
		'Wake' => {
			long => {
				'standard' => q#Akud n Tegzirin n Wake#,
			},
		},
		'Wallis' => {
			long => {
				'standard' => q#Akud n Wallis akked Futuna#,
			},
		},
		'Yakutsk' => {
			long => {
				'daylight' => q#Akud n unebdu n Yakutsk#,
				'generic' => q#Akud n Yakutsk#,
				'standard' => q#Akud amezday n Yakutsk#,
			},
		},
		'Yekaterinburg' => {
			long => {
				'daylight' => q#Akud n Unebdu n Yekaterinburg#,
				'generic' => q#Akud n Yekaterinburg#,
				'standard' => q#Akud Amagnu n Yekaterinburg#,
			},
		},
	 } }
);
no Moo;

1;

# vim: tabstop=4
