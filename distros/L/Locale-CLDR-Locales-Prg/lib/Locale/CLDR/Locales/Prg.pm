=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Prg - Package for language Prussian

=cut

package Locale::CLDR::Locales::Prg;
# This file auto generated from Data\common\main\prg.xml
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
				'ar' => 'arābiskan',
 				'da' => 'dāniskan',
 				'de' => 'miksiskan',
 				'de_AT' => 'Āustrarīkis miksiskan',
 				'de_CH' => 'Šwēicis aūktamiksiskan',
 				'el' => 'grēkiskan',
 				'en' => 'ēngliskan',
 				'en_AU' => 'Austrālijas ēngliskan',
 				'en_CA' => 'Kanādas ēngliskan',
 				'en_GB' => 'brītiskan ēngliskan',
 				'en_US' => 'amērikaniskan ēngliskan',
 				'en_US@alt=short' => 'APW ēngliskan',
 				'es' => 'špāniskan',
 				'es_419' => 'Lātiniskas Amērikas špāniskan',
 				'es_ES' => 'eurōpiskan špāniskan',
 				'es_MX' => 'Meksikus špāniskan',
 				'et' => 'èstiskan',
 				'fi' => 'sōmiskan',
 				'fr' => 'prancōziskan',
 				'fr_CA' => 'Kanādas prancōziskan',
 				'fr_CH' => 'Šwēicis prancōziskan',
 				'it' => 'wālkiskan',
 				'ja' => 'japāniskan',
 				'lt' => 'laītawiskan',
 				'lv' => 'lattawiskan',
 				'nl' => 'ullandiskan',
 				'pl' => 'pōliskan',
 				'prg' => 'prūsiskan',
 				'pt' => 'pōrtugaliskan',
 				'pt_BR' => 'Brazīlijas pōrtugaliskan',
 				'pt_PT' => 'eurōpiskan pōrtugaliskan',
 				'ru' => 'maskōwitiskan',
 				'sv' => 'šwēdiskan',
 				'tr' => 'turkiskan',
 				'und' => 'niwaistā bilā',
 				'zh' => 'kīniskan',
 				'zh_Hans' => 'prastintan kīniskan',
 				'zh_Hant' => 'tradiciōnalin kīniskan',

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
			'Arab' => 'arābiskan',
 			'Cyrl' => 'cīriliskan',
 			'Hans' => 'prastintan',
 			'Hans@alt=stand-alone' => 'prastintan han',
 			'Hant' => 'tradiciōnalin',
 			'Hant@alt=stand-alone' => 'tradiciōnalin han',
 			'Jpan' => 'japāniskas',
 			'Latn' => 'lātiniskan',
 			'Zxxx' => 'nienpeisātan',
 			'Zzzz' => 'niwaīstan skriptan',

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
			'001' => 'swītai',
 			'002' => 'Afrika',
 			'003' => 'Zēimanamērika',
 			'005' => 'Pussideinanamērika',
 			'019' => 'Amērika',
 			'142' => 'Āzija',
 			'150' => 'Eurōpa',
 			'AD' => 'Andōra',
 			'AG' => 'Antīgwa be Barbūda',
 			'AL' => 'Albānija',
 			'AR' => 'Argentīnija',
 			'AT' => 'Āustrarīki',
 			'AU' => 'Austrālija',
 			'BA' => 'Bōsnija be Ercegōwina',
 			'BB' => 'Barbādas',
 			'BE' => 'Belgija',
 			'BG' => 'Bulgārija',
 			'BO' => 'Bōliwija',
 			'BR' => 'Brazīlija',
 			'BS' => 'Bahāmai',
 			'BY' => 'Krēiwa',
 			'BZ' => 'Belīzi',
 			'CA' => 'Kānada',
 			'CH' => 'Šwēici',
 			'CL' => 'Čīli',
 			'CN' => 'Kīna',
 			'CO' => 'Kōlumbija',
 			'CR' => 'Costa Rica',
 			'CU' => 'Kūba',
 			'CZ' => 'Čekkija',
 			'DE' => 'Mikskātauta',
 			'DK' => 'Dānanmarki',
 			'DM' => 'Dōminika',
 			'DO' => 'Dōminikas Republīki',
 			'EC' => 'Ekwadōrs',
 			'EE' => 'Estantauta',
 			'ES' => 'Špānija',
 			'FI' => 'Sōmija',
 			'FO' => 'Farēirai',
 			'FR' => 'Prankrīki',
 			'GB' => 'Debabritānija',
 			'GB@alt=short' => 'DB',
 			'GD' => 'Grenāda',
 			'GF' => 'Prancōziska Gujāna',
 			'GI' => 'Gibrāltars',
 			'GL' => 'Grēnlandan',
 			'GR' => 'Grēkantauta',
 			'GT' => 'Gwatemāla',
 			'GY' => 'Gujāna',
 			'HN' => 'Hōnduras',
 			'HR' => 'Kruātija',
 			'HT' => 'Haīti',
 			'HU' => 'Ungrai',
 			'ID' => 'Indōnezija',
 			'IN' => 'Īndija',
 			'IS' => 'Īslandan',
 			'IT' => 'Wālkija',
 			'JM' => 'Jamāika',
 			'JP' => 'Japānija',
 			'KR' => 'Pussideinankōreja',
 			'LI' => 'Līchtenšteinan',
 			'LT' => 'Laītawa',
 			'LU' => 'Luksemburgan',
 			'LV' => 'Lattawa',
 			'MC' => 'Mōnakō',
 			'MD' => 'Mōldawija',
 			'ME' => 'Mōntenegran',
 			'MT' => 'Mālta',
 			'MX' => 'Meksiku',
 			'NI' => 'Nikarāgwa',
 			'NO' => 'Nōrwigai',
 			'NZ' => 'Nawazēlandan',
 			'PA' => 'Panāma',
 			'PE' => 'Perū',
 			'PL' => 'Pōli',
 			'PT' => 'Pōrtugalin',
 			'PW' => 'Palau',
 			'PY' => 'Paragwājs',
 			'RO' => 'Rumānija',
 			'RS' => 'Serbija',
 			'RU' => 'Russi',
 			'SA' => 'Saūdi Arābija',
 			'SE' => 'Šwēdija',
 			'SI' => 'Slōwenija',
 			'SK' => 'Slōwakei',
 			'SM' => 'San Marinō',
 			'SR' => 'Surināms',
 			'SV' => 'El Salvadōrs',
 			'TH' => 'Tāilandan',
 			'TR' => 'Turkāja',
 			'TT' => 'Trinidāds be Tobagō',
 			'TW' => 'Taiwāns',
 			'UA' => 'Ukrāini',
 			'US' => 'Peraīnintas Wālstis',
 			'US@alt=short' => 'PW',
 			'UY' => 'Urugwājs',
 			'VE' => 'Venezuēla',
 			'XK' => 'Kōsawa',
 			'ZA' => 'Pussideinanafrika',
 			'ZZ' => 'niwaistā regiōni',

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
 				'gregorian' => q{Gregōriskas kalāndars},
 			},
 			'collation' => {
 				'standard' => q{sēisnas rikā},
 			},
 			'numbers' => {
 				'latn' => q{lātiniskas cipperis},
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
			'metric' => q{mētriskan},
 			'UK' => q{brītiskan},
 			'US' => q{amērikaniskan},

		}
	},
);

has 'display_name_code_patterns' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'language' => 'Bilā: {0}',
 			'script' => 'Skriptan: {0}',
 			'region' => 'Regiōni: {0}',

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
			index => ['AĀ', 'B', 'C', 'DḐ', 'EĒ', 'F', 'GĢ', 'H', 'IĪ', 'J', 'KĶ', 'L', 'M', 'NŅ', 'OŌ', 'P', 'Q', 'RŖ', 'SŠ', 'TȚ', 'UŪ', 'V', 'W', 'X', 'Y', 'ZŽ'],
			main => qr{[aā b c dḑ eē f gģ h iī j kķ l m nņ oō p q rŗ sš tț uū v w x y zž]},
			numbers => qr{[  \- ‑ , % ‰ + 0 1 2 3 4 5 6 7 8 9]},
			punctuation => qr{[\- ‐‑ – — , ; \: ! ? . … “„ ( ) \[ \] \{ \}]},
		};
	},
EOT
: sub {
		return { index => ['AĀ', 'B', 'C', 'DḐ', 'EĒ', 'F', 'GĢ', 'H', 'IĪ', 'J', 'KĶ', 'L', 'M', 'NŅ', 'OŌ', 'P', 'Q', 'RŖ', 'SŠ', 'TȚ', 'UŪ', 'V', 'W', 'X', 'Y', 'ZŽ'], };
},
);


has 'quote_start' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{„},
);

has 'quote_end' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{“},
);

has 'alternate_quote_start' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{„},
);

has 'alternate_quote_end' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{“},
);

has 'yesstr' => (
	is			=> 'ro',
	isa			=> RegexpRef,
	init_arg	=> undef,
	default		=> sub { qr'^(?i:jā|j|yes|y)$' }
);

has 'nostr' => (
	is			=> 'ro',
	isa			=> RegexpRef,
	init_arg	=> undef,
	default		=> sub { qr'^(?i:ni|n)$' }
);

has 'listPatterns' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
				end => q({0} be {1}),
				2 => q({0} be {1}),
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
		},
	} }
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
						'positive' => '#,##0.00 ¤',
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
		'BRL' => {
			display_name => {
				'currency' => q(Brazīlijas reals),
				'one' => q(Brazīlijas reals),
				'other' => q(Brazīlijas realai),
				'zero' => q(Brazīlijas realin),
			},
		},
		'CNY' => {
			display_name => {
				'currency' => q(Kīnas juāns),
				'one' => q(Kīnas juāns),
				'other' => q(Kīnas juānai),
				'zero' => q(Kīnas juānan),
			},
		},
		'EUR' => {
			display_name => {
				'currency' => q(eurō),
			},
		},
		'GBP' => {
			display_name => {
				'currency' => q(punds sterlings),
				'one' => q(punds sterlings),
				'other' => q(pundai sterlingai),
				'zero' => q(pundan sterlingan),
			},
		},
		'INR' => {
			display_name => {
				'currency' => q(Īndijas rūpija),
				'one' => q(Īndijas rūpija),
				'other' => q(Īndijas rūpijas),
				'zero' => q(Īndijas rūpijan),
			},
		},
		'JPY' => {
			display_name => {
				'currency' => q(Japānijas jāns),
				'one' => q(Japānijas jāns),
				'other' => q(Japānijas jānai),
				'zero' => q(Japānijas jānan),
			},
		},
		'RUB' => {
			display_name => {
				'currency' => q(Russis rūbels),
				'one' => q(Russis rūbels),
				'other' => q(Russis rūblai),
				'zero' => q(Russis rūblin),
			},
		},
		'USD' => {
			display_name => {
				'currency' => q(APW dālars),
				'one' => q(APW dālars),
				'other' => q(APW dālarai),
				'zero' => q(APW dālaran),
			},
		},
		'XXX' => {
			display_name => {
				'currency' => q(niwaistā walūta),
				'one' => q(\(niwaistā walūtas aīnibi\)),
				'other' => q(\(niwaistā walūta\)),
				'zero' => q(\(niwaistā walūta\)),
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
							'rag',
							'was',
							'pūl',
							'sak',
							'zal',
							'sīm',
							'līp',
							'dag',
							'sil',
							'spa',
							'lap',
							'sal'
						],
						leap => [
							
						],
					},
					wide => {
						nonleap => [
							'rags',
							'wassarins',
							'pūlis',
							'sakkis',
							'zallaws',
							'sīmenis',
							'līpa',
							'daggis',
							'sillins',
							'spallins',
							'lapkrūtis',
							'sallaws'
						],
						leap => [
							
						],
					},
				},
				'stand-alone' => {
					narrow => {
						nonleap => [
							'R',
							'W',
							'P',
							'S',
							'Z',
							'S',
							'L',
							'D',
							'S',
							'S',
							'L',
							'S'
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
						mon => 'pan',
						tue => 'wis',
						wed => 'pus',
						thu => 'ket',
						fri => 'pēn',
						sat => 'sab',
						sun => 'nad'
					},
					wide => {
						mon => 'panadīli',
						tue => 'wisasīdis',
						wed => 'pussisawaiti',
						thu => 'ketwirtiks',
						fri => 'pēntniks',
						sat => 'sabattika',
						sun => 'nadīli'
					},
				},
				'stand-alone' => {
					narrow => {
						mon => 'P',
						tue => 'W',
						wed => 'P',
						thu => 'K',
						fri => 'P',
						sat => 'S',
						sun => 'N'
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
					abbreviated => {0 => '1. k.',
						1 => '2. k.',
						2 => '3. k.',
						3 => '4. k.'
					},
					wide => {0 => '1. ketwirts',
						1 => '2. ketwirts',
						2 => '3. ketwirts',
						3 => '4. ketwirts'
					},
				},
				'stand-alone' => {
					abbreviated => {0 => '1. ketw.',
						1 => '2. ketw.',
						2 => '3. ketw.',
						3 => '4. ketw.'
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
				'wide' => {
					'am' => q{ankstāinan},
					'pm' => q{pa pussideinan},
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
				'0' => 'BC',
				'1' => 'AD'
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
			'full' => q{EEEE, y 'mettas' d. MMMM G},
			'long' => q{y 'mettas' d. MMMM G},
			'medium' => q{dd.MM 'st'. y G},
			'short' => q{dd.MM.y GGGGG},
		},
		'gregorian' => {
			'full' => q{EEEE, y 'mettas' d. MMMM},
			'long' => q{y 'mettas' d. MMMM},
			'medium' => q{dd.MM 'st'. y},
			'short' => q{dd.MM.yy},
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
			'full' => q{HH:mm:ss zzzz},
			'long' => q{HH:mm:ss z},
			'medium' => q{HH:mm:ss},
			'short' => q{HH:mm},
		},
	} },
);

has 'datetime_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
			'full' => q{{1} {0}},
			'long' => q{{1} {0}},
			'medium' => q{{1} {0}},
			'short' => q{{1} {0}},
		},
		'gregorian' => {
			'full' => q{{1} {0}},
			'long' => q{{1} {0}},
			'medium' => q{{1} {0}},
			'short' => q{{1} {0}},
		},
	} },
);

has 'datetime_formats_available_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'gregorian' => {
			EHm => q{E, HH:mm},
			EHms => q{E, HH:mm:ss},
			Ed => q{E, d.},
			Ehm => q{E, h:mm a},
			Ehms => q{E, h:mm:ss a},
			Gy => q{y 'm'. G},
			GyMMM => q{y 'm'. MMM G},
			GyMMMEd => q{E, dd.MM 'st'. y G},
			GyMMMd => q{dd.MM 'st'. y G},
			Hmsv => q{HH:mm:ss; v},
			Hmv => q{HH:mm; v},
			M => q{L.},
			MEd => q{E, d.M},
			MMMEd => q{E, d. MMM},
			MMMd => q{d. MMM},
			Md => q{d.M},
			d => q{d.},
			h => q{h a},
			hm => q{h:mm a},
			hms => q{h:mm:ss a},
			hmsv => q{h:mm:ss a; v},
			hmv => q{h:mm a; v},
			y => q{y 'm'.},
			yM => q{M.y},
			yMEd => q{E, d.M.y},
			yMMM => q{y 'm'. MMM},
			yMMMEd => q{E, dd.MM 'st'. y},
			yMMMd => q{dd.MM 'st'. y},
			yMd => q{d.M.y},
			yQQQ => q{y 'm'. QQQ},
			yQQQQ => q{y 'm'. QQQQ},
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
		'gregorian' => {
			M => {
				M => q{M.–M.},
			},
			MEd => {
				M => q{E, dd.MM – E, dd.MM},
				d => q{E, dd.MM – E, dd.MM},
			},
			MMM => {
				M => q{MMM–MMM},
			},
			MMMEd => {
				M => q{E, d. MMM – E, d. MMM},
				d => q{E, d. – E, d. MMM},
			},
			MMMd => {
				M => q{d. MMM – d. MMM},
				d => q{d.–d. MMM},
			},
			Md => {
				M => q{dd.MM–dd.MM},
				d => q{dd.MM–dd.MM},
			},
			d => {
				d => q{d.–d.},
			},
			h => {
				a => q{h a – h a},
				h => q{h–h a},
			},
			hm => {
				a => q{h:mm a – h:mm a},
				h => q{h:mm–h:mm a},
				m => q{h:mm–h:mm a},
			},
			hmv => {
				a => q{h:mm a – h:mm a v},
				h => q{h:mm–h:mm a v},
				m => q{h:mm–h:mm a v},
			},
			hv => {
				a => q{h a – h a v},
				h => q{h–h a v},
			},
			yM => {
				M => q{MM.y–MM.y},
				y => q{MM.y–MM.y},
			},
			yMEd => {
				M => q{E, dd.MM.y – E, dd.MM.y},
				d => q{E, dd.MM.y – E, dd.MM.y},
				y => q{E, dd.MM.y – E, dd.MM.y},
			},
			yMMM => {
				M => q{y 'm'. MMM–MMM},
				y => q{y 'm'. MMM – y 'm'. MMM},
			},
			yMMMEd => {
				M => q{E, dd.MM – E, dd.MM 'st'. y},
				d => q{E, dd. – E, dd.MM 'st'. y},
				y => q{E, dd.MM 'st'. y – E, dd.MM 'st'. y},
			},
			yMMMM => {
				M => q{y 'mettas' MMMM–MMMM},
				y => q{y 'mettas' MMMM – y 'mettas' MMMM},
			},
			yMMMd => {
				M => q{dd.MM–dd.MM 'st'. y},
				d => q{dd.–dd.MM 'st'. y},
				y => q{dd.MM 'st'. y – dd.MM 'st'. y},
			},
			yMd => {
				M => q{dd.MM.y–dd.MM.y},
				d => q{dd.MM.y–dd.MM.y},
				y => q{dd.MM.y–dd.MM.y},
			},
		},
	} },
);

has 'time_zone_names' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default	=> sub { {
		regionFormat => q(Kerdā: {0}),
		regionFormat => q(Daggas kerdā: {0}),
		regionFormat => q(Zēimas kerdā: {0}),
		'America_Central' => {
			long => {
				'daylight' => q#Centrālas Amērikas daggas kerdā#,
				'generic' => q#Centrālas Amērikas kerdā#,
				'standard' => q#Centrālas Amērikas zēimas kerdā#,
			},
		},
		'America_Eastern' => {
			long => {
				'daylight' => q#Dēiniskas Amērikas daggas kerdā#,
				'generic' => q#Dēiniskas Amērikas kerdā#,
				'standard' => q#Dēiniskas Amērikas zēimas kerdā#,
			},
		},
		'America_Mountain' => {
			long => {
				'daylight' => q#Amērikas gārban daggas kerdā#,
				'generic' => q#Amērikas gārban kerdā#,
				'standard' => q#Amērikas gārban zēimas kerdā#,
			},
		},
		'America_Pacific' => {
			long => {
				'daylight' => q#Pacīfiskas Amērikas daggas kerdā#,
				'generic' => q#Pacīfiskas Amērikas kerdā#,
				'standard' => q#Pacīfiskas Amērikas zēimas kerdā#,
			},
		},
		'Atlantic' => {
			long => {
				'daylight' => q#Atlāntiska daggas kerdā#,
				'generic' => q#Atlāntiska kerdā#,
				'standard' => q#Atlāntiska zēimas kerdā#,
			},
		},
		'Europe_Central' => {
			long => {
				'daylight' => q#Centrālas Eurōpas daggas kerdā#,
				'generic' => q#Centrālas Eurōpas kerdā#,
				'standard' => q#Centrālas Eurōpas zēimas kerdā#,
			},
		},
		'Europe_Eastern' => {
			long => {
				'daylight' => q#Dēiniskas Eurōpas daggas kerdā#,
				'generic' => q#Dēiniskas Eurōpas kerdā#,
				'standard' => q#Dēiniskas Eurōpas zēimas kerdā#,
			},
		},
		'Europe_Western' => {
			long => {
				'daylight' => q#Wakkariskas Eurōpas daggas kerdā#,
				'generic' => q#Wakkariskas Eurōpas kerdā#,
				'standard' => q#Wakkariskas Eurōpas zēimas kerdā#,
			},
		},
		'GMT' => {
			long => {
				'standard' => q#Greenwich kerdā#,
			},
		},
	 } }
);
no Moo;

1;

# vim: tabstop=4
