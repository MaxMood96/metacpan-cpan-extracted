=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Lt - Package for language Lithuanian

=cut

package Locale::CLDR::Locales::Lt;
# This file auto generated from Data\common\main\lt.xml
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
has 'valid_algorithmic_formats' => (
    is => 'ro',
    isa => ArrayRef,
    init_arg => undef,
    default => sub {[ 'spellout-numbering-year','spellout-numbering','spellout-cardinal-masculine','spellout-cardinal-feminine' ]},
);

has 'algorithmic_number_format_data' => (
    is => 'ro',
    isa => HashRef,
    init_arg => undef,
    default => sub {
        use bigfloat;
        return {
		'spellout-cardinal-feminine' => {
			'public' => {
				'-x' => {
					divisor => q(1),
					rule => q(mīnus →→),
				},
				'0' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(nulis),
				},
				'x.x' => {
					divisor => q(1),
					rule => q(←← kablelis →→),
				},
				'1' => {
					base_value => q(1),
					divisor => q(1),
					rule => q(viena),
				},
				'2' => {
					base_value => q(2),
					divisor => q(1),
					rule => q(dvi),
				},
				'3' => {
					base_value => q(3),
					divisor => q(1),
					rule => q(trys),
				},
				'4' => {
					base_value => q(4),
					divisor => q(1),
					rule => q(=%spellout-cardinal-masculine=os),
				},
				'10' => {
					base_value => q(10),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine=),
				},
				'20' => {
					base_value => q(20),
					divisor => q(10),
					rule => q(←%%spellout-cardinal-feminine-accusative←dešimt[ →→]),
				},
				'100' => {
					base_value => q(100),
					divisor => q(100),
					rule => q(šimtas[ →→]),
				},
				'200' => {
					base_value => q(200),
					divisor => q(100),
					rule => q(←%spellout-cardinal-masculine← šimtai[ →→]),
				},
				'1000' => {
					base_value => q(1000),
					divisor => q(1000),
					rule => q(tūkstantis[ →→]),
				},
				'2000' => {
					base_value => q(2000),
					divisor => q(1000),
					rule => q(←%%spellout-thousands←[ →→]),
				},
				'1000000' => {
					base_value => q(1000000),
					divisor => q(1000000),
					rule => q(vienas milijonas[ →→]),
				},
				'2000000' => {
					base_value => q(2000000),
					divisor => q(1000000),
					rule => q(←%spellout-cardinal-masculine← milijonų[ →→]),
				},
				'1000000000' => {
					base_value => q(1000000000),
					divisor => q(1000000000),
					rule => q(vienas milijardas[ →→]),
				},
				'2000000000' => {
					base_value => q(2000000000),
					divisor => q(1000000000),
					rule => q(←%spellout-cardinal-masculine← milijardų[ →→]),
				},
				'1000000000000' => {
					base_value => q(1000000000000),
					divisor => q(1000000000000),
					rule => q(vienas trilijonas[ →→]),
				},
				'2000000000000' => {
					base_value => q(2000000000000),
					divisor => q(1000000000000),
					rule => q(←%spellout-cardinal-masculine← trilijonų[ →→]),
				},
				'1000000000000000' => {
					base_value => q(1000000000000000),
					divisor => q(1000000000000000),
					rule => q(vienas kvadrilijonas[ →→]),
				},
				'2000000000000000' => {
					base_value => q(2000000000000000),
					divisor => q(1000000000000000),
					rule => q(←%spellout-cardinal-masculine← kvadrilijonų[ →→]),
				},
				'1000000000000000000' => {
					base_value => q(1000000000000000000),
					divisor => q(1000000000000000000),
					rule => q(=#,##0=),
				},
				'max' => {
					base_value => q(1000000000000000000),
					divisor => q(1000000000000000000),
					rule => q(=#,##0=),
				},
			},
		},
		'spellout-cardinal-feminine-accusative' => {
			'private' => {
				'0' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(ERROR),
				},
				'2' => {
					base_value => q(2),
					divisor => q(1),
					rule => q(dvi),
				},
				'3' => {
					base_value => q(3),
					divisor => q(1),
					rule => q(tris),
				},
				'4' => {
					base_value => q(4),
					divisor => q(1),
					rule => q(keturias),
				},
				'5' => {
					base_value => q(5),
					divisor => q(1),
					rule => q(penkias),
				},
				'6' => {
					base_value => q(6),
					divisor => q(1),
					rule => q(šešias),
				},
				'7' => {
					base_value => q(7),
					divisor => q(1),
					rule => q(septynias),
				},
				'8' => {
					base_value => q(8),
					divisor => q(1),
					rule => q(aštuonias),
				},
				'9' => {
					base_value => q(9),
					divisor => q(1),
					rule => q(devynias),
				},
				'10' => {
					base_value => q(10),
					divisor => q(10),
					rule => q(ERROR),
				},
				'max' => {
					base_value => q(10),
					divisor => q(10),
					rule => q(ERROR),
				},
			},
		},
		'spellout-cardinal-masculine' => {
			'public' => {
				'-x' => {
					divisor => q(1),
					rule => q(mīnus →→),
				},
				'0' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(nulis),
				},
				'x.x' => {
					divisor => q(1),
					rule => q(←← kablelis →→),
				},
				'1' => {
					base_value => q(1),
					divisor => q(1),
					rule => q(vienas),
				},
				'2' => {
					base_value => q(2),
					divisor => q(1),
					rule => q(du),
				},
				'3' => {
					base_value => q(3),
					divisor => q(1),
					rule => q(trys),
				},
				'4' => {
					base_value => q(4),
					divisor => q(1),
					rule => q(keturi),
				},
				'5' => {
					base_value => q(5),
					divisor => q(1),
					rule => q(penki),
				},
				'6' => {
					base_value => q(6),
					divisor => q(1),
					rule => q(šeši),
				},
				'7' => {
					base_value => q(7),
					divisor => q(1),
					rule => q(septyni),
				},
				'8' => {
					base_value => q(8),
					divisor => q(1),
					rule => q(aštuoni),
				},
				'9' => {
					base_value => q(9),
					divisor => q(1),
					rule => q(devyni),
				},
				'10' => {
					base_value => q(10),
					divisor => q(10),
					rule => q(dešimt),
				},
				'11' => {
					base_value => q(11),
					divisor => q(10),
					rule => q(vienuolika),
				},
				'12' => {
					base_value => q(12),
					divisor => q(10),
					rule => q(dvylika),
				},
				'13' => {
					base_value => q(13),
					divisor => q(10),
					rule => q(trylika),
				},
				'14' => {
					base_value => q(14),
					divisor => q(10),
					rule => q(→→olika),
				},
				'20' => {
					base_value => q(20),
					divisor => q(10),
					rule => q(←%%spellout-cardinal-feminine-accusative←dešimt[ →→]),
				},
				'100' => {
					base_value => q(100),
					divisor => q(100),
					rule => q(šimtas[ →→]),
				},
				'200' => {
					base_value => q(200),
					divisor => q(100),
					rule => q(←%spellout-cardinal-masculine← šimtai[ →→]),
				},
				'1000' => {
					base_value => q(1000),
					divisor => q(1000),
					rule => q(tūkstantis[ →→]),
				},
				'2000' => {
					base_value => q(2000),
					divisor => q(1000),
					rule => q(←%%spellout-thousands←[ →→]),
				},
				'1000000' => {
					base_value => q(1000000),
					divisor => q(1000000),
					rule => q(vienas milijonas[ →→]),
				},
				'2000000' => {
					base_value => q(2000000),
					divisor => q(1000000),
					rule => q(←%spellout-cardinal-masculine← milijonų[ →→]),
				},
				'1000000000' => {
					base_value => q(1000000000),
					divisor => q(1000000000),
					rule => q(vienas milijardas[ →→]),
				},
				'2000000000' => {
					base_value => q(2000000000),
					divisor => q(1000000000),
					rule => q(←%spellout-cardinal-masculine← milijardų[ →→]),
				},
				'1000000000000' => {
					base_value => q(1000000000000),
					divisor => q(1000000000000),
					rule => q(vienas trilijonas[ →→]),
				},
				'2000000000000' => {
					base_value => q(2000000000000),
					divisor => q(1000000000000),
					rule => q(←%spellout-cardinal-masculine←trilijonų[ →→]),
				},
				'1000000000000000' => {
					base_value => q(1000000000000000),
					divisor => q(1000000000000000),
					rule => q(vienas kvadrilijonas[ →→]),
				},
				'2000000000000000' => {
					base_value => q(2000000000000000),
					divisor => q(1000000000000000),
					rule => q(←%spellout-cardinal-masculine← kvadrilijonų[ →→]),
				},
				'1000000000000000000' => {
					base_value => q(1000000000000000000),
					divisor => q(1000000000000000000),
					rule => q(=#,##0=),
				},
				'max' => {
					base_value => q(1000000000000000000),
					divisor => q(1000000000000000000),
					rule => q(=#,##0=),
				},
			},
		},
		'spellout-numbering' => {
			'public' => {
				'0' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(=%spellout-cardinal-masculine=),
				},
				'max' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(=%spellout-cardinal-masculine=),
				},
			},
		},
		'spellout-numbering-year' => {
			'public' => {
				'0' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(=%spellout-numbering=),
				},
				'x.x' => {
					divisor => q(1),
					rule => q(=0.0=),
				},
				'max' => {
					divisor => q(1),
					rule => q(=0.0=),
				},
			},
		},
		'spellout-thousands' => {
			'private' => {
				'0' => {
					base_value => q(0),
					divisor => q(1),
					rule => q(tūkstančių),
				},
				'1' => {
					base_value => q(1),
					divisor => q(1),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'2' => {
					base_value => q(2),
					divisor => q(1),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'10' => {
					base_value => q(10),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'21' => {
					base_value => q(21),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'22' => {
					base_value => q(22),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'30' => {
					base_value => q(30),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'31' => {
					base_value => q(31),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'32' => {
					base_value => q(32),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'40' => {
					base_value => q(40),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'41' => {
					base_value => q(41),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'42' => {
					base_value => q(42),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'50' => {
					base_value => q(50),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'51' => {
					base_value => q(51),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'52' => {
					base_value => q(52),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'60' => {
					base_value => q(60),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'61' => {
					base_value => q(61),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'62' => {
					base_value => q(62),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'70' => {
					base_value => q(70),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'71' => {
					base_value => q(71),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'72' => {
					base_value => q(72),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'80' => {
					base_value => q(80),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'81' => {
					base_value => q(81),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'82' => {
					base_value => q(82),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'90' => {
					base_value => q(90),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančių),
				},
				'91' => {
					base_value => q(91),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstantis),
				},
				'92' => {
					base_value => q(92),
					divisor => q(10),
					rule => q(=%spellout-cardinal-masculine= tūkstančiai),
				},
				'100' => {
					base_value => q(100),
					divisor => q(100),
					rule => q(šimtas →→),
				},
				'200' => {
					base_value => q(200),
					divisor => q(100),
					rule => q(←%spellout-cardinal-masculine← šimtai →→),
				},
				'max' => {
					base_value => q(200),
					divisor => q(100),
					rule => q(←%spellout-cardinal-masculine← šimtai →→),
				},
			},
		},
    } },
);

has 'display_name_language' => (
	is			=> 'ro',
	isa			=> CodeRef,
	init_arg	=> undef,
	default		=> sub {
		 sub {
			 my %languages = (
				'aa' => 'afarų',
 				'ab' => 'abchazų',
 				'ace' => 'ačinezų',
 				'ach' => 'akolių',
 				'ada' => 'adangmų',
 				'ady' => 'adygėjų',
 				'ae' => 'avestų',
 				'aeb' => 'Tuniso arabų',
 				'af' => 'afrikanų',
 				'afh' => 'afrihili',
 				'agq' => 'aghemų',
 				'ain' => 'ainų',
 				'ak' => 'akanų',
 				'akk' => 'akadianų',
 				'akz' => 'alabamiečių',
 				'ale' => 'aleutų',
 				'aln' => 'albanų kalbos gegų tarmė',
 				'alt' => 'pietų Altajaus',
 				'am' => 'amharų',
 				'an' => 'aragonesų',
 				'ang' => 'senoji anglų',
 				'ann' => 'obolų',
 				'anp' => 'angikų',
 				'ar' => 'arabų',
 				'ar_001' => 'šiuolaikinė standartinė arabų',
 				'arc' => 'aramaikų',
 				'arn' => 'mapudungunų',
 				'aro' => 'araonų',
 				'arp' => 'arapahų',
 				'arq' => 'Alžyro arabų',
 				'ars' => 'arabų najdi',
 				'arw' => 'aravakų',
 				'ary' => 'Maroko arabų',
 				'arz' => 'Egipto arabų',
 				'as' => 'asamų',
 				'asa' => 'asu',
 				'ase' => 'Amerikos ženklų kalba',
 				'ast' => 'asturianų',
 				'atj' => 'atikamekų',
 				'av' => 'avarikų',
 				'avk' => 'kotava',
 				'awa' => 'avadhi',
 				'ay' => 'aimarų',
 				'az' => 'azerbaidžaniečių',
 				'az@alt=short' => 'azeri',
 				'ba' => 'baškirų',
 				'bal' => 'baluči',
 				'ban' => 'baliečių',
 				'bar' => 'bavarų',
 				'bas' => 'basų',
 				'bax' => 'bamunų',
 				'bbc' => 'batak toba',
 				'bbj' => 'ghomalų',
 				'be' => 'baltarusių',
 				'bej' => 'bėjų',
 				'bem' => 'bembų',
 				'bew' => 'betavi',
 				'bez' => 'benų',
 				'bfd' => 'bafutų',
 				'bfq' => 'badaga',
 				'bg' => 'bulgarų',
 				'bgc' => 'harijanvi',
 				'bgn' => 'vakarų beludžių',
 				'bho' => 'baučpuri',
 				'bi' => 'bislama',
 				'bik' => 'bikolų',
 				'bin' => 'bini',
 				'bjn' => 'bandžarų',
 				'bkm' => 'komų',
 				'bla' => 'siksikų',
 				'blo' => 'guanų',
 				'bm' => 'bambarų',
 				'bn' => 'bengalų',
 				'bo' => 'tibetiečių',
 				'bpy' => 'bišnuprijos',
 				'bqi' => 'bakhtiari',
 				'br' => 'bretonų',
 				'bra' => 'brajų',
 				'brh' => 'brahujų',
 				'brx' => 'bodo',
 				'bs' => 'bosnių',
 				'bss' => 'akūsų',
 				'bua' => 'buriatų',
 				'bug' => 'buginezų',
 				'bum' => 'bulu',
 				'byn' => 'blin',
 				'byv' => 'medumbų',
 				'ca' => 'katalonų',
 				'cad' => 'kado',
 				'car' => 'karibų',
 				'cay' => 'kaijūgų',
 				'cch' => 'atsamų',
 				'ccp' => 'Čakma',
 				'ce' => 'čečėnų',
 				'ceb' => 'sebuanų',
 				'cgg' => 'čigų',
 				'ch' => 'čamorų',
 				'chb' => 'čibčų',
 				'chg' => 'čagatų',
 				'chk' => 'čukesų',
 				'chm' => 'marių',
 				'chn' => 'činuk žargonas',
 				'cho' => 'čoktau',
 				'chp' => 'čipvėjų',
 				'chr' => 'čerokių',
 				'chy' => 'čajenų',
 				'ckb' => 'soranių kurdų',
 				'clc' => 'čilkotinų',
 				'co' => 'korsikiečių',
 				'cop' => 'koptų',
 				'cps' => 'capiznon',
 				'cr' => 'kry',
 				'crg' => 'metisų',
 				'crh' => 'Krymo turkų',
 				'crj' => 'pietryčių kri',
 				'crk' => 'supraprastinta kri',
 				'crl' => 'šiaurės rytų kri',
 				'crm' => 'muskri',
 				'crr' => 'pamlikų',
 				'crs' => 'Seišelių kreolų ir prancūzų',
 				'cs' => 'čekų',
 				'csb' => 'kašubų',
 				'csw' => 'pelkynų kri',
 				'cu' => 'bažnytinė slavų',
 				'cv' => 'čiuvašų',
 				'cy' => 'valų',
 				'da' => 'danų',
 				'dak' => 'dakotų',
 				'dar' => 'dargva',
 				'dav' => 'taitų',
 				'de' => 'vokiečių',
 				'de_AT' => 'Austrijos vokiečių',
 				'de_CH' => 'Šveicarijos aukštutinė vokiečių',
 				'del' => 'delavero',
 				'den' => 'slave',
 				'dgr' => 'dogribų',
 				'din' => 'dinkų',
 				'dje' => 'zarmų',
 				'doi' => 'dogri',
 				'dsb' => 'žemutinių sorbų',
 				'dtp' => 'centrinio Dusuno',
 				'dua' => 'dualų',
 				'dum' => 'Vidurio Vokietijos',
 				'dv' => 'divehų',
 				'dyo' => 'džiola-foni',
 				'dyu' => 'dyulų',
 				'dz' => 'botijų',
 				'dzg' => 'dazagų',
 				'ebu' => 'embu',
 				'ee' => 'evių',
 				'efi' => 'efik',
 				'egl' => 'italų kalbos Emilijos tarmė',
 				'egy' => 'senovės egiptiečių',
 				'eka' => 'ekajuk',
 				'el' => 'graikų',
 				'elx' => 'elamitų',
 				'en' => 'anglų',
 				'en_AU' => 'Australijos anglų',
 				'en_CA' => 'Kanados anglų',
 				'en_GB' => 'Didžiosios Britanijos anglų',
 				'en_GB@alt=short' => 'anglų (JK)',
 				'en_US' => 'Jungtinių Valstijų anglų',
 				'en_US@alt=short' => 'anglų (JAV)',
 				'enm' => 'Vidurio Anglijos',
 				'eo' => 'esperanto',
 				'es' => 'ispanų',
 				'esu' => 'centrinės Aliaskos jupikų',
 				'et' => 'estų',
 				'eu' => 'baskų',
 				'ewo' => 'evondo',
 				'ext' => 'ispanų kalbos Ekstremadūros tarmė',
 				'fa' => 'persų',
 				'fan' => 'fangų',
 				'fat' => 'fanti',
 				'ff' => 'fulahų',
 				'fi' => 'suomių',
 				'fil' => 'filipiniečių',
 				'fit' => 'suomių kalbos Tornedalio tarmė',
 				'fj' => 'fidžių',
 				'fo' => 'farerų',
 				'fon' => 'fon',
 				'fr' => 'prancūzų',
 				'fr_CA' => 'Kanados prancūzų',
 				'fr_CH' => 'Šveicarijos prancūzų',
 				'frc' => 'kadžunų prancūzų',
 				'frm' => 'Vidurio Prancūzijos',
 				'fro' => 'senoji prancūzų',
 				'frp' => 'arpitano',
 				'frr' => 'šiaurinių fryzų',
 				'frs' => 'rytų fryzų',
 				'fur' => 'friulių',
 				'fy' => 'vakarų fryzų',
 				'ga' => 'airių',
 				'gaa' => 'ga',
 				'gag' => 'gagaūzų',
 				'gan' => 'kinų kalbos dziangsi tarmė',
 				'gay' => 'gajo',
 				'gba' => 'gbaja',
 				'gbz' => 'zoroastrų dari',
 				'gd' => 'škotų (gėlų)',
 				'gez' => 'gyz',
 				'gil' => 'kiribati',
 				'gl' => 'galisų',
 				'glk' => 'gilaki',
 				'gmh' => 'Vidurio Aukštosios Vokietijos',
 				'gn' => 'gvaranių',
 				'goh' => 'senoji Aukštosios Vokietijos',
 				'gon' => 'gondi',
 				'gor' => 'gorontalo',
 				'got' => 'gotų',
 				'grb' => 'grebo',
 				'grc' => 'senovės graikų',
 				'gsw' => 'Šveicarijos vokiečių',
 				'gu' => 'gudžaratų',
 				'guc' => 'vajų',
 				'gur' => 'frafra',
 				'guz' => 'gusi',
 				'gv' => 'meniečių',
 				'gwi' => 'gvičino',
 				'ha' => 'hausų',
 				'hai' => 'haido',
 				'hak' => 'kinų kalbos hakų tarmė',
 				'haw' => 'havajiečių',
 				'hax' => 'Pietų Haidos',
 				'he' => 'hebrajų',
 				'hi' => 'hindi',
 				'hif' => 'Fidžio hindi',
 				'hil' => 'hiligainonų',
 				'hit' => 'hititų',
 				'hmn' => 'hmong',
 				'ho' => 'hiri motu',
 				'hr' => 'kroatų',
 				'hsb' => 'aukštutinių sorbų',
 				'hsn' => 'kinų kalbos hunano tarmė',
 				'ht' => 'Haičio',
 				'hu' => 'vengrų',
 				'hup' => 'hupa',
 				'hur' => 'halkomelemų',
 				'hy' => 'armėnų',
 				'hz' => 'hererų',
 				'ia' => 'tarpinė',
 				'iba' => 'iban',
 				'ibb' => 'ibibijų',
 				'id' => 'indoneziečių',
 				'ie' => 'interkalba',
 				'ig' => 'igbų',
 				'ii' => 'sičuan ji',
 				'ik' => 'inupiakų',
 				'ikt' => 'vakarų kanadiečių inuktitutas',
 				'ilo' => 'ilokų',
 				'inh' => 'ingušų',
 				'io' => 'ido',
 				'is' => 'islandų',
 				'it' => 'italų',
 				'iu' => 'inukitut',
 				'izh' => 'ingrų',
 				'ja' => 'japonų',
 				'jam' => 'Jamaikos kreolų anglų',
 				'jbo' => 'loiban',
 				'jgo' => 'ngombų',
 				'jmc' => 'mačamų',
 				'jpr' => 'judėjų persų',
 				'jrb' => 'judėjų arabų',
 				'jut' => 'danų kalbos jutų tarmė',
 				'jv' => 'javiečių',
 				'ka' => 'gruzinų',
 				'kaa' => 'karakalpakų',
 				'kab' => 'kebailų',
 				'kac' => 'kačinų',
 				'kaj' => 'ju',
 				'kam' => 'kembų',
 				'kaw' => 'kavių',
 				'kbd' => 'kabardinų',
 				'kbl' => 'kanembų',
 				'kcg' => 'tyap',
 				'kde' => 'makondų',
 				'kea' => 'Žaliojo Kyšulio kreolų',
 				'ken' => 'kenyang',
 				'kfo' => 'koro',
 				'kg' => 'Kongo',
 				'kgp' => 'kaingang',
 				'kha' => 'kasi',
 				'kho' => 'kotanezų',
 				'khq' => 'kojra čini',
 				'khw' => 'khovarų',
 				'ki' => 'kikujų',
 				'kiu' => 'kirmanjki',
 				'kj' => 'kuaniama',
 				'kk' => 'kazachų',
 				'kkj' => 'kako',
 				'kl' => 'kalalisut',
 				'kln' => 'kalenjinų',
 				'km' => 'khmerų',
 				'kmb' => 'kimbundu',
 				'kn' => 'kanadų',
 				'ko' => 'korėjiečių',
 				'koi' => 'komių-permių',
 				'kok' => 'konkanių',
 				'kos' => 'kosreanų',
 				'kpe' => 'kpelių',
 				'kr' => 'kanurių',
 				'krc' => 'karačiajų balkarijos',
 				'kri' => 'krio',
 				'krj' => 'kinaray-a',
 				'krl' => 'karelų',
 				'kru' => 'kuruk',
 				'ks' => 'kašmyrų',
 				'ksb' => 'šambalų',
 				'ksf' => 'bafų',
 				'ksh' => 'kolognų',
 				'ku' => 'kurdų',
 				'kum' => 'kumikų',
 				'kut' => 'kutenai',
 				'kv' => 'komi',
 				'kw' => 'kornų',
 				'kwk' => 'kvakvalų',
 				'kxv' => 'kuvi',
 				'ky' => 'kirgizų',
 				'la' => 'lotynų',
 				'lad' => 'ladino',
 				'lag' => 'langi',
 				'lah' => 'landa',
 				'lam' => 'lamba',
 				'lb' => 'liuksemburgiečių',
 				'lez' => 'lezginų',
 				'lfn' => 'naujoji frankų kalba',
 				'lg' => 'ganda',
 				'li' => 'limburgiečių',
 				'lij' => 'ligūrų',
 				'lil' => 'liluetų',
 				'liv' => 'lyvių',
 				'lkt' => 'lakotų',
 				'lmo' => 'lombardų',
 				'ln' => 'ngalų',
 				'lo' => 'laosiečių',
 				'lol' => 'mongų',
 				'lou' => 'Luizianos kreolų',
 				'loz' => 'lozių',
 				'lrc' => 'šiaurės luri',
 				'lsm' => 'samių',
 				'lt' => 'lietuvių',
 				'ltg' => 'latgalių',
 				'lu' => 'luba katanga',
 				'lua' => 'luba lulua',
 				'lui' => 'luiseno',
 				'lun' => 'Lundos',
 				'lus' => 'mizo',
 				'luy' => 'luja',
 				'lv' => 'latvių',
 				'lzh' => 'klasikinė kinų',
 				'lzz' => 'laz',
 				'mad' => 'madurezų',
 				'maf' => 'mafų',
 				'mag' => 'magahi',
 				'mai' => 'maithili',
 				'mak' => 'Makasaro',
 				'man' => 'mandingų',
 				'mas' => 'masajų',
 				'mde' => 'mabų',
 				'mdf' => 'mokša',
 				'mdr' => 'mandarų',
 				'men' => 'mende',
 				'mer' => 'merų',
 				'mfe' => 'morisijų',
 				'mg' => 'malagasų',
 				'mga' => 'Vidurio Airijos',
 				'mgh' => 'makua-maeto',
 				'mgo' => 'meta',
 				'mh' => 'Maršalo Salų',
 				'mi' => 'maorių',
 				'mic' => 'mikmakų',
 				'min' => 'minangkabau',
 				'mk' => 'makedonų',
 				'ml' => 'malajalių',
 				'mn' => 'mongolų',
 				'mnc' => 'manču',
 				'mni' => 'manipurių',
 				'moe' => 'montanjų',
 				'moh' => 'mohok',
 				'mos' => 'mosi',
 				'mr' => 'maratų',
 				'mrj' => 'vakarų mari',
 				'ms' => 'malajiečių',
 				'mt' => 'maltiečių',
 				'mua' => 'mundangų',
 				'mul' => 'kelios kalbos',
 				'mus' => 'krykų',
 				'mwl' => 'mirandezų',
 				'mwr' => 'marvari',
 				'mwv' => 'mentavai',
 				'my' => 'birmiečių',
 				'mye' => 'mjenų',
 				'myv' => 'erzyjų',
 				'mzn' => 'mazenderanių',
 				'na' => 'naurų',
 				'nan' => 'kinų kalbos pietų minų tarmė',
 				'nap' => 'neapoliečių',
 				'naq' => 'nama',
 				'nb' => 'norvegų bukmolas',
 				'nd' => 'šiaurės ndebelų',
 				'nds' => 'Žemutinės Vokietijos',
 				'nds_NL' => 'Žemutinės Saksonijos (Nyderlandai)',
 				'ne' => 'nepaliečių',
 				'new' => 'nevari',
 				'ng' => 'ndongų',
 				'nia' => 'nias',
 				'niu' => 'niujiečių',
 				'njo' => 'ao naga',
 				'nl' => 'olandų',
 				'nl_BE' => 'flamandų',
 				'nmg' => 'kvasių',
 				'nn' => 'naujoji norvegų',
 				'nnh' => 'ngiembūnų',
 				'no' => 'norvegų',
 				'nog' => 'nogų',
 				'non' => 'senoji norsų',
 				'nov' => 'novial',
 				'nqo' => 'enko',
 				'nr' => 'pietų ndebele',
 				'nso' => 'šiaurės Soto',
 				'nus' => 'nuerų',
 				'nv' => 'navajų',
 				'nwc' => 'klasikinė nevari',
 				'ny' => 'nianjų',
 				'nym' => 'niamvezi',
 				'nyn' => 'niankolų',
 				'nyo' => 'niorų',
 				'nzi' => 'nzima',
 				'oc' => 'očitarų',
 				'oj' => 'ojibva',
 				'ojb' => 'šiaurės vakarų odžibvių',
 				'ojc' => 'ojibvų',
 				'ojs' => 'odži kri',
 				'ojw' => 'vakarų odžibvių',
 				'oka' => 'okanaganų',
 				'om' => 'oromų',
 				'or' => 'odijų',
 				'os' => 'osetinų',
 				'osa' => 'osage',
 				'ota' => 'osmanų turkų',
 				'pa' => 'pendžabų',
 				'pag' => 'pangasinanų',
 				'pal' => 'vidurinė persų kalba',
 				'pam' => 'pampangų',
 				'pap' => 'papiamento',
 				'pau' => 'palauliečių',
 				'pcd' => 'pikardų',
 				'pcm' => 'Nigerijos pidžinų',
 				'pdc' => 'Pensilvanijos vokiečių',
 				'pdt' => 'vokiečių kalbos žemaičių tarmė',
 				'peo' => 'senoji persų',
 				'pfl' => 'vokiečių kalbos Pfalco tarmė',
 				'phn' => 'finikiečių',
 				'pi' => 'pali',
 				'pis' => 'pidžinų',
 				'pl' => 'lenkų',
 				'pms' => 'italų kalbos Pjemonto tarmė',
 				'pnt' => 'Ponto',
 				'pon' => 'Ponapės',
 				'pqm' => 'Maliset-Pasamakvodžio',
 				'prg' => 'prūsų',
 				'pro' => 'senovės provansalų',
 				'ps' => 'puštūnų',
 				'pt' => 'portugalų',
 				'qu' => 'kečujų',
 				'quc' => 'kičių',
 				'qug' => 'Čimboraso aukštumų kečujų',
 				'raj' => 'Radžastano',
 				'rap' => 'rapanui',
 				'rar' => 'rarotonganų',
 				'rgn' => 'italų kalbos Romanijos tarmė',
 				'rhg' => 'rochindža',
 				'rif' => 'rifų',
 				'rm' => 'retoromanų',
 				'rn' => 'rundi',
 				'ro' => 'rumunų',
 				'ro_MD' => 'moldavų',
 				'rof' => 'rombo',
 				'rom' => 'romų',
 				'rtm' => 'rotumanų',
 				'ru' => 'rusų',
 				'rue' => 'rusinų',
 				'rug' => 'Rovianos',
 				'rup' => 'aromanių',
 				'rw' => 'kinjaruandų',
 				'rwk' => 'rua',
 				'sa' => 'sanskritas',
 				'sad' => 'sandavių',
 				'sah' => 'jakutų',
 				'sam' => 'samarėjų aramių',
 				'saq' => 'sambūrų',
 				'sas' => 'sasak',
 				'sat' => 'santalių',
 				'saz' => 'sauraštrų',
 				'sba' => 'ngambajų',
 				'sbp' => 'sangų',
 				'sc' => 'sardiniečių',
 				'scn' => 'siciliečių',
 				'sco' => 'škotų',
 				'sd' => 'sindų',
 				'sdc' => 'sasaresų sardinų',
 				'sdh' => 'pietų kurdų',
 				'se' => 'šiaurės samių',
 				'see' => 'senecų',
 				'seh' => 'senų',
 				'sei' => 'seri',
 				'sel' => 'selkup',
 				'ses' => 'kojraboro seni',
 				'sg' => 'sango',
 				'sga' => 'senoji airių',
 				'sgs' => 'žemaičių',
 				'sh' => 'serbų-kroatų',
 				'shi' => 'tachelhitų',
 				'shn' => 'šan',
 				'shu' => 'chadian arabų',
 				'si' => 'sinhalų',
 				'sid' => 'sidamų',
 				'sk' => 'slovakų',
 				'sl' => 'slovėnų',
 				'slh' => 'pietų lushusidų',
 				'sli' => 'sileziečių žemaičių',
 				'sly' => 'selajarų',
 				'sm' => 'Samoa',
 				'sma' => 'pietų samių',
 				'smj' => 'Liuleo samių',
 				'smn' => 'Inario samių',
 				'sms' => 'Skolto samių',
 				'sn' => 'šonų',
 				'snk' => 'soninke',
 				'so' => 'somaliečių',
 				'sog' => 'sogdien',
 				'sq' => 'albanų',
 				'sr' => 'serbų',
 				'srn' => 'sranan tongo',
 				'srr' => 'sererų',
 				'ss' => 'svatų',
 				'ssy' => 'saho',
 				'st' => 'pietų Soto',
 				'stq' => 'Saterlendo fryzų',
 				'str' => 'Sališo sąsiaurio',
 				'su' => 'sundų',
 				'suk' => 'sukuma',
 				'sus' => 'susu',
 				'sux' => 'šumerų',
 				'sv' => 'švedų',
 				'sw' => 'suahilių',
 				'sw_CD' => 'Kongo suahilių',
 				'swb' => 'komorų',
 				'syc' => 'klasikinė sirų',
 				'syr' => 'sirų',
 				'szl' => 'sileziečių',
 				'ta' => 'tamilų',
 				'tce' => 'pietų tučonų',
 				'tcy' => 'tulų',
 				'te' => 'telugų',
 				'tem' => 'timne',
 				'teo' => 'teso',
 				'ter' => 'Tereno',
 				'tet' => 'tetum',
 				'tg' => 'tadžikų',
 				'tgx' => 'tagišų',
 				'th' => 'tajų',
 				'tht' => 'taltanų',
 				'ti' => 'tigrajų',
 				'tig' => 'tigre',
 				'tiv' => 'tiv',
 				'tk' => 'turkmėnų',
 				'tkl' => 'Tokelau',
 				'tkr' => 'tsakurų',
 				'tl' => 'tagalogų',
 				'tlh' => 'klingonų',
 				'tli' => 'tlingitų',
 				'tly' => 'talyšų',
 				'tmh' => 'tamašek',
 				'tn' => 'tsvanų',
 				'to' => 'tonganų',
 				'tog' => 'niasa tongų',
 				'tok' => 'Toki Pona',
 				'tpi' => 'Papua pidžinų',
 				'tr' => 'turkų',
 				'tru' => 'turoyo',
 				'trv' => 'Taroko',
 				'ts' => 'tsongų',
 				'tsd' => 'tsakonų',
 				'tsi' => 'tsimšian',
 				'tt' => 'totorių',
 				'ttm' => 'šiaurės tutsonų',
 				'ttt' => 'musulmonų tatų',
 				'tum' => 'tumbukų',
 				'tvl' => 'Tuvalu',
 				'tw' => 'tvi',
 				'twq' => 'tasavakų',
 				'ty' => 'taitiečių',
 				'tyv' => 'tuvių',
 				'tzm' => 'Centrinio Maroko tamazitų',
 				'udm' => 'udmurtų',
 				'ug' => 'uigūrų',
 				'uga' => 'ugaritų',
 				'uk' => 'ukrainiečių',
 				'umb' => 'umbundu',
 				'und' => 'nežinoma kalba',
 				'ur' => 'urdų',
 				'uz' => 'uzbekų',
 				've' => 'vendų',
 				'vec' => 'venetų',
 				'vep' => 'vepsų',
 				'vi' => 'vietnamiečių',
 				'vls' => 'vakarų flamandų',
 				'vmf' => 'pagrindinė frankonų',
 				'vmw' => 'makua',
 				'vo' => 'volapiuko',
 				'vot' => 'Votik',
 				'vro' => 'veru',
 				'vun' => 'vunjo',
 				'wa' => 'valonų',
 				'wae' => 'valserų',
 				'wal' => 'valamo',
 				'war' => 'varai',
 				'was' => 'Vašo',
 				'wbp' => 'valrpiri',
 				'wo' => 'volofų',
 				'wuu' => 'kinų kalbos vu tarmė',
 				'xal' => 'kalmukų',
 				'xh' => 'kosų',
 				'xmf' => 'megrelų',
 				'xnr' => 'kangri',
 				'xog' => 'sogų',
 				'yao' => 'jao',
 				'yap' => 'japezų',
 				'yav' => 'jangbenų',
 				'ybb' => 'jembų',
 				'yi' => 'jidiš',
 				'yo' => 'jorubų',
 				'yrl' => 'njengatu',
 				'yue' => 'kinų kalbos Kantono tarmė',
 				'za' => 'chuang',
 				'zap' => 'zapotekų',
 				'zbl' => 'BLISS simbolių',
 				'zea' => 'zelandų',
 				'zen' => 'zenaga',
 				'zgh' => 'standartinė Maroko tamazigtų',
 				'zh' => 'kinų',
 				'zh@alt=menu' => 'kinų, mandarinų',
 				'zh_Hans' => 'supaprastintoji kinų',
 				'zh_Hans@alt=long' => 'supaprastintoji mandarinų kinų',
 				'zh_Hant' => 'tradicinė kinų',
 				'zh_Hant@alt=long' => 'tradicinė mandarinų kinų',
 				'zu' => 'zulų',
 				'zun' => 'Zuni',
 				'zxx' => 'nėra kalbinio turinio',
 				'zza' => 'zaza',

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
			'Adlm' => 'ADLAM',
 			'Afak' => 'Afaka',
 			'Aghb' => 'Kaukazo Albanijos',
 			'Arab' => 'arabų',
 			'Arab@alt=variant' => 'persų-arabų',
 			'Aran' => 'Nastalik',
 			'Armi' => 'imperinė aramaikų',
 			'Armn' => 'armėnų',
 			'Avst' => 'avestano',
 			'Bali' => 'Baliečių',
 			'Bamu' => 'Bamum',
 			'Bass' => 'Bassa Vah',
 			'Batk' => 'batak',
 			'Beng' => 'bengalų',
 			'Blis' => '„Bliss“ simboliai',
 			'Bopo' => 'bopomofo',
 			'Brah' => 'brahmi',
 			'Brai' => 'brailio',
 			'Bugi' => 'buginezų',
 			'Buhd' => 'buhid',
 			'Cakm' => 'čakma',
 			'Cans' => 'suvienodinti Kanados aborigenų silabiniai',
 			'Cari' => 'karių',
 			'Cham' => 'čam',
 			'Cher' => 'čerokių',
 			'Cirt' => 'kirt',
 			'Copt' => 'koptų',
 			'Cprt' => 'kipro',
 			'Cyrl' => 'kirilica',
 			'Cyrs' => 'senoji bažnytinė slavų kirilica',
 			'Deva' => 'devanagari',
 			'Dsrt' => 'deseretas',
 			'Dupl' => 'Duplojė stenografija',
 			'Egyd' => 'Egipto liaudies',
 			'Egyh' => 'Egipto žynių',
 			'Egyp' => 'egipto hieroglifai',
 			'Elba' => 'Elbasano',
 			'Ethi' => 'etiopų',
 			'Geok' => 'gruzinų kutsuri',
 			'Geor' => 'gruzinų',
 			'Glag' => 'glagolitik',
 			'Goth' => 'gotų',
 			'Gran' => 'Granta',
 			'Grek' => 'graikų',
 			'Gujr' => 'gudžaratų',
 			'Guru' => 'gurmuki',
 			'Hanb' => 'hanbų',
 			'Hang' => 'hangul',
 			'Hani' => 'han',
 			'Hano' => 'hanuno',
 			'Hans' => 'supaprastinti',
 			'Hans@alt=stand-alone' => 'supaprastinti han',
 			'Hant' => 'tradiciniai',
 			'Hant@alt=stand-alone' => 'tradiciniai han',
 			'Hebr' => 'hebrajų',
 			'Hira' => 'hiragana',
 			'Hluw' => 'Anatolijaus hieroglifai',
 			'Hmng' => 'pahav hmong',
 			'Hrkt' => 'katakana / hiragana',
 			'Hung' => 'senasis vengrų',
 			'Inds' => 'indus',
 			'Ital' => 'senasis italų',
 			'Jamo' => 'Jamo simboliai',
 			'Java' => 'javiečių',
 			'Jpan' => 'japonų',
 			'Jurc' => 'Jurchen',
 			'Kali' => 'kajah li',
 			'Kana' => 'katakana',
 			'Khar' => 'karošti',
 			'Khmr' => 'khmerų',
 			'Khoj' => 'Khojki',
 			'Knda' => 'kanadų',
 			'Kore' => 'korėjiečių',
 			'Kpel' => 'Kpelų',
 			'Kthi' => 'kaithi',
 			'Lana' => 'lana',
 			'Laoo' => 'laosiečių',
 			'Latf' => 'fraktur lotynų',
 			'Latg' => 'gėlų lotynų',
 			'Latn' => 'lotynų',
 			'Lepc' => 'lepča',
 			'Limb' => 'limbu',
 			'Lina' => 'linijiniai A',
 			'Linb' => 'linijiniai B',
 			'Lisu' => 'Fraser',
 			'Loma' => 'Loma',
 			'Lyci' => 'lician',
 			'Lydi' => 'lidian',
 			'Mahj' => 'Mahadžani',
 			'Mand' => 'mandėjų',
 			'Mani' => 'maničų',
 			'Maya' => 'malų hieroglifai',
 			'Mend' => 'Mende',
 			'Merc' => 'Merojitų rankraštinis',
 			'Mero' => 'meroitik',
 			'Mlym' => 'malajalių',
 			'Mong' => 'mongolų',
 			'Moon' => 'mūn',
 			'Mroo' => 'Mro',
 			'Mtei' => 'meitei majek',
 			'Mymr' => 'birmiečių',
 			'Narb' => 'Senasis šiaurės arabų',
 			'Nbat' => 'Nabatėjų',
 			'Nkgb' => 'Naxi Geba',
 			'Nkoo' => 'enko',
 			'Nshu' => 'Nüshu',
 			'Ogam' => 'ogham',
 			'Olck' => 'ol čiki',
 			'Orkh' => 'orkon',
 			'Orya' => 'orijų',
 			'Osma' => 'osmanų',
 			'Palm' => 'Palmiros',
 			'Pauc' => 'Pau Cin Hau',
 			'Perm' => 'senieji permės',
 			'Phag' => 'pagsa pa',
 			'Phli' => 'rašytiniai pahlavi',
 			'Phlp' => 'pselter pahlavi',
 			'Phlv' => 'buk pahvali',
 			'Phnx' => 'foenikų',
 			'Plrd' => 'polard fonetinė',
 			'Prti' => 'rašytiniai partų',
 			'Rjng' => 'rejang',
 			'Rohg' => 'Hanifi',
 			'Roro' => 'rongorongo',
 			'Runr' => 'runų',
 			'Samr' => 'samariečių',
 			'Sara' => 'sarati',
 			'Sarb' => 'senoji pietų Arabijos',
 			'Saur' => 'sauraštra',
 			'Sgnw' => 'ženklų raštas',
 			'Shaw' => 'šavių',
 			'Shrd' => 'Šarados',
 			'Sidd' => 'Siddham',
 			'Sind' => 'Khudawadi',
 			'Sinh' => 'sinhalų',
 			'Sora' => 'Sora Sompeng',
 			'Sund' => 'sundų',
 			'Sylo' => 'syloti nagri',
 			'Syrc' => 'sirų',
 			'Syre' => 'estrangelo siriečių',
 			'Syrj' => 'vakarų sirų',
 			'Syrn' => 'rytų sirų',
 			'Tagb' => 'tagbanva',
 			'Takr' => 'Takri',
 			'Tale' => 'tai le',
 			'Talu' => 'naujasis Tailando lue',
 			'Taml' => 'tamilų',
 			'Tang' => 'Tangut',
 			'Tavt' => 'tai vet',
 			'Telu' => 'telugų',
 			'Teng' => 'tengvar',
 			'Tfng' => 'tifinag',
 			'Tglg' => 'tagalogų',
 			'Thaa' => 'hana',
 			'Thai' => 'tajų',
 			'Tibt' => 'tibetiečių',
 			'Tirh' => 'Tirhuta',
 			'Ugar' => 'ugaritik',
 			'Vaii' => 'vai',
 			'Visp' => 'matoma kalba',
 			'Wara' => 'Varang Kshiti',
 			'Wole' => 'Woleai',
 			'Xpeo' => 'senieji persų',
 			'Xsux' => 'Šumero Akado dantiraštis',
 			'Yiii' => 'ji',
 			'Zinh' => 'paveldėtas',
 			'Zmth' => 'matematiniai simboliai',
 			'Zsye' => 'jaustukai',
 			'Zsym' => 'simbolių',
 			'Zxxx' => 'neparašyta',
 			'Zyyy' => 'bendri',
 			'Zzzz' => 'nežinomi rašmenys',

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
			'001' => 'pasaulis',
 			'002' => 'Afrika',
 			'003' => 'Šiaurės Amerika',
 			'005' => 'Pietų Amerika',
 			'009' => 'Okeanija',
 			'011' => 'Vakarų Afrika',
 			'013' => 'Centrinė Amerika',
 			'014' => 'Rytų Afrika',
 			'015' => 'Šiaurės Afrika',
 			'017' => 'Vidurio Afrika',
 			'018' => 'Pietinė Afrika',
 			'019' => 'Amerika',
 			'021' => 'Šiaurinė Amerika',
 			'029' => 'Karibai',
 			'030' => 'Rytų Azija',
 			'034' => 'Pietų Azija',
 			'035' => 'Pietryčių Azija',
 			'039' => 'Pietų Europa',
 			'053' => 'Australazija',
 			'054' => 'Melanezija',
 			'057' => 'Mikronezijos regionas',
 			'061' => 'Polinezija',
 			'142' => 'Azija',
 			'143' => 'Centrinė Azija',
 			'145' => 'Vakarų Azija',
 			'150' => 'Europa',
 			'151' => 'Rytų Europa',
 			'154' => 'Šiaurės Europa',
 			'155' => 'Vakarų Europa',
 			'202' => 'Užsachario Afrika',
 			'419' => 'Lotynų Amerika',
 			'AC' => 'Dangun Žengimo sala',
 			'AD' => 'Andora',
 			'AE' => 'Jungtiniai Arabų Emyratai',
 			'AF' => 'Afganistanas',
 			'AG' => 'Antigva ir Barbuda',
 			'AI' => 'Angilija',
 			'AL' => 'Albanija',
 			'AM' => 'Armėnija',
 			'AO' => 'Angola',
 			'AQ' => 'Antarktida',
 			'AR' => 'Argentina',
 			'AS' => 'Amerikos Samoa',
 			'AT' => 'Austrija',
 			'AU' => 'Australija',
 			'AW' => 'Aruba',
 			'AX' => 'Alandų Salos',
 			'AZ' => 'Azerbaidžanas',
 			'BA' => 'Bosnija ir Hercegovina',
 			'BB' => 'Barbadosas',
 			'BD' => 'Bangladešas',
 			'BE' => 'Belgija',
 			'BF' => 'Burkina Fasas',
 			'BG' => 'Bulgarija',
 			'BH' => 'Bahreinas',
 			'BI' => 'Burundis',
 			'BJ' => 'Beninas',
 			'BL' => 'Sen Bartelemi',
 			'BM' => 'Bermuda',
 			'BN' => 'Brunėjus',
 			'BO' => 'Bolivija',
 			'BQ' => 'Karibų Nyderlandai',
 			'BR' => 'Brazilija',
 			'BS' => 'Bahamos',
 			'BT' => 'Butanas',
 			'BV' => 'Buvė Sala',
 			'BW' => 'Botsvana',
 			'BY' => 'Baltarusija',
 			'BZ' => 'Belizas',
 			'CA' => 'Kanada',
 			'CC' => 'Kokosų (Kilingo) Salos',
 			'CD' => 'Kongas-Kinšasa',
 			'CD@alt=variant' => 'Kongo Demokratinė Respublika',
 			'CF' => 'Centrinės Afrikos Respublika',
 			'CG' => 'Kongas-Brazavilis',
 			'CG@alt=variant' => 'Kongo Respublika',
 			'CH' => 'Šveicarija',
 			'CI' => 'Dramblio Kaulo Krantas',
 			'CI@alt=variant' => 'Dramblio Kaulo Kranto Respublika',
 			'CK' => 'Kuko Salos',
 			'CL' => 'Čilė',
 			'CM' => 'Kamerūnas',
 			'CN' => 'Kinija',
 			'CO' => 'Kolumbija',
 			'CP' => 'Klipertono sala',
 			'CR' => 'Kosta Rika',
 			'CU' => 'Kuba',
 			'CV' => 'Žaliasis Kyšulys',
 			'CW' => 'Kiurasao',
 			'CX' => 'Kalėdų Sala',
 			'CY' => 'Kipras',
 			'CZ' => 'Čekija',
 			'CZ@alt=variant' => 'Čekijos Respublika',
 			'DE' => 'Vokietija',
 			'DG' => 'Diego Garsija',
 			'DJ' => 'Džibutis',
 			'DK' => 'Danija',
 			'DM' => 'Dominika',
 			'DO' => 'Dominikos Respublika',
 			'DZ' => 'Alžyras',
 			'EA' => 'Seuta ir Melila',
 			'EC' => 'Ekvadoras',
 			'EE' => 'Estija',
 			'EG' => 'Egiptas',
 			'EH' => 'Vakarų Sachara',
 			'ER' => 'Eritrėja',
 			'ES' => 'Ispanija',
 			'ET' => 'Etiopija',
 			'EU' => 'Europos Sąjunga',
 			'EZ' => 'euro zona',
 			'FI' => 'Suomija',
 			'FJ' => 'Fidžis',
 			'FK' => 'Folklando Salos',
 			'FK@alt=variant' => 'Folklando (Malvinų) Salos',
 			'FM' => 'Mikronezija',
 			'FO' => 'Farerų Salos',
 			'FR' => 'Prancūzija',
 			'GA' => 'Gabonas',
 			'GB' => 'Jungtinė Karalystė',
 			'GB@alt=short' => 'JK',
 			'GD' => 'Grenada',
 			'GE' => 'Gruzija',
 			'GF' => 'Prancūzijos Gviana',
 			'GG' => 'Gernsis',
 			'GH' => 'Gana',
 			'GI' => 'Gibraltaras',
 			'GL' => 'Grenlandija',
 			'GM' => 'Gambija',
 			'GN' => 'Gvinėja',
 			'GP' => 'Gvadelupa',
 			'GQ' => 'Pusiaujo Gvinėja',
 			'GR' => 'Graikija',
 			'GS' => 'Pietų Džordžija ir Pietų Sandvičo salos',
 			'GT' => 'Gvatemala',
 			'GU' => 'Guamas',
 			'GW' => 'Bisau Gvinėja',
 			'GY' => 'Gajana',
 			'HK' => 'Ypatingasis Administracinis Kinijos Regionas Honkongas',
 			'HK@alt=short' => 'Honkongas',
 			'HM' => 'Herdo ir Makdonaldo Salos',
 			'HN' => 'Hondūras',
 			'HR' => 'Kroatija',
 			'HT' => 'Haitis',
 			'HU' => 'Vengrija',
 			'IC' => 'Kanarų salos',
 			'ID' => 'Indonezija',
 			'IE' => 'Airija',
 			'IL' => 'Izraelis',
 			'IM' => 'Meno Sala',
 			'IN' => 'Indija',
 			'IO' => 'Indijos Vandenyno Britų Sritis',
 			'IO@alt=chagos' => 'Čagoso salynas',
 			'IQ' => 'Irakas',
 			'IR' => 'Iranas',
 			'IS' => 'Islandija',
 			'IT' => 'Italija',
 			'JE' => 'Džersis',
 			'JM' => 'Jamaika',
 			'JO' => 'Jordanija',
 			'JP' => 'Japonija',
 			'KE' => 'Kenija',
 			'KG' => 'Kirgizija',
 			'KH' => 'Kambodža',
 			'KI' => 'Kiribatis',
 			'KM' => 'Komorai',
 			'KN' => 'Sent Kitsas ir Nevis',
 			'KP' => 'Šiaurės Korėja',
 			'KR' => 'Pietų Korėja',
 			'KW' => 'Kuveitas',
 			'KY' => 'Kaimanų Salos',
 			'KZ' => 'Kazachstanas',
 			'LA' => 'Laosas',
 			'LB' => 'Libanas',
 			'LC' => 'Sent Lusija',
 			'LI' => 'Lichtenšteinas',
 			'LK' => 'Šri Lanka',
 			'LR' => 'Liberija',
 			'LS' => 'Lesotas',
 			'LT' => 'Lietuva',
 			'LU' => 'Liuksemburgas',
 			'LV' => 'Latvija',
 			'LY' => 'Libija',
 			'MA' => 'Marokas',
 			'MC' => 'Monakas',
 			'MD' => 'Moldova',
 			'ME' => 'Juodkalnija',
 			'MF' => 'Sen Martenas',
 			'MG' => 'Madagaskaras',
 			'MH' => 'Maršalo Salos',
 			'MK' => 'Šiaurės Makedonija',
 			'ML' => 'Malis',
 			'MM' => 'Mianmaras (Birma)',
 			'MN' => 'Mongolija',
 			'MO' => 'Ypatingasis Administracinis Kinijos Regionas Makao',
 			'MO@alt=short' => 'Makao',
 			'MP' => 'Marianos Šiaurinės Salos',
 			'MQ' => 'Martinika',
 			'MR' => 'Mauritanija',
 			'MS' => 'Montseratas',
 			'MT' => 'Malta',
 			'MU' => 'Mauricijus',
 			'MV' => 'Maldyvai',
 			'MW' => 'Malavis',
 			'MX' => 'Meksika',
 			'MY' => 'Malaizija',
 			'MZ' => 'Mozambikas',
 			'NA' => 'Namibija',
 			'NC' => 'Naujoji Kaledonija',
 			'NE' => 'Nigeris',
 			'NF' => 'Norfolko sala',
 			'NG' => 'Nigerija',
 			'NI' => 'Nikaragva',
 			'NL' => 'Nyderlandai',
 			'NO' => 'Norvegija',
 			'NP' => 'Nepalas',
 			'NR' => 'Nauru',
 			'NU' => 'Niujė',
 			'NZ' => 'Naujoji Zelandija',
 			'OM' => 'Omanas',
 			'PA' => 'Panama',
 			'PE' => 'Peru',
 			'PF' => 'Prancūzijos Polinezija',
 			'PG' => 'Papua Naujoji Gvinėja',
 			'PH' => 'Filipinai',
 			'PK' => 'Pakistanas',
 			'PL' => 'Lenkija',
 			'PM' => 'Sen Pjeras ir Mikelonas',
 			'PN' => 'Pitkerno salos',
 			'PR' => 'Puerto Rikas',
 			'PS' => 'Palestinos teritorija',
 			'PS@alt=short' => 'Palestina',
 			'PT' => 'Portugalija',
 			'PW' => 'Palau',
 			'PY' => 'Paragvajus',
 			'QA' => 'Kataras',
 			'QO' => 'Nuošali Okeanija',
 			'RE' => 'Reunjonas',
 			'RO' => 'Rumunija',
 			'RS' => 'Serbija',
 			'RU' => 'Rusija',
 			'RW' => 'Ruanda',
 			'SA' => 'Saudo Arabija',
 			'SB' => 'Saliamono Salos',
 			'SC' => 'Seišeliai',
 			'SD' => 'Sudanas',
 			'SE' => 'Švedija',
 			'SG' => 'Singapūras',
 			'SH' => 'Šv. Elenos Sala',
 			'SI' => 'Slovėnija',
 			'SJ' => 'Svalbardas ir Janas Majenas',
 			'SK' => 'Slovakija',
 			'SL' => 'Siera Leonė',
 			'SM' => 'San Marinas',
 			'SN' => 'Senegalas',
 			'SO' => 'Somalis',
 			'SR' => 'Surinamas',
 			'SS' => 'Pietų Sudanas',
 			'ST' => 'San Tomė ir Prinsipė',
 			'SV' => 'Salvadoras',
 			'SX' => 'Sint Martenas',
 			'SY' => 'Sirija',
 			'SZ' => 'Svazilandas',
 			'TA' => 'Tristano da Kunjos',
 			'TC' => 'Terkso ir Kaikoso Salos',
 			'TD' => 'Čadas',
 			'TF' => 'Prancūzijos Pietų sritys',
 			'TG' => 'Togas',
 			'TH' => 'Tailandas',
 			'TJ' => 'Tadžikija',
 			'TK' => 'Tokelau',
 			'TL' => 'Rytų Timoras',
 			'TM' => 'Turkmėnistanas',
 			'TN' => 'Tunisas',
 			'TO' => 'Tonga',
 			'TR' => 'Turkija',
 			'TT' => 'Trinidadas ir Tobagas',
 			'TV' => 'Tuvalu',
 			'TW' => 'Taivanas',
 			'TZ' => 'Tanzanija',
 			'UA' => 'Ukraina',
 			'UG' => 'Uganda',
 			'UM' => 'Jungtinių Valstijų Mažosios Tolimosios Salos',
 			'UN' => 'Jungtinės Tautos',
 			'UN@alt=short' => 'JT',
 			'US' => 'Jungtinės Valstijos',
 			'US@alt=short' => 'JAV',
 			'UY' => 'Urugvajus',
 			'UZ' => 'Uzbekistanas',
 			'VA' => 'Vatikano Miesto Valstybė',
 			'VC' => 'Šventasis Vincentas ir Grenadinai',
 			'VE' => 'Venesuela',
 			'VG' => 'Didžiosios Britanijos Mergelių Salos',
 			'VI' => 'Jungtinių Valstijų Mergelių Salos',
 			'VN' => 'Vietnamas',
 			'VU' => 'Vanuatu',
 			'WF' => 'Volisas ir Futūna',
 			'WS' => 'Samoa',
 			'XA' => 'pseudo A',
 			'XB' => 'pseudo B',
 			'XK' => 'Kosovas',
 			'YE' => 'Jemenas',
 			'YT' => 'Majotas',
 			'ZA' => 'Pietų Afrika',
 			'ZM' => 'Zambija',
 			'ZW' => 'Zimbabvė',
 			'ZZ' => 'nežinoma sritis',

		}
	},
);

has 'display_name_variant' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'1901' => 'Įprasta vokiečių rašyba',
 			'1994' => 'Sunorminta Resian rašyba',
 			'1996' => '1996 -ųjų metų vokiečių rašyba',
 			'1606NICT' => '1606 -ųjų metų prancūzų kalba',
 			'1694ACAD' => 'Ankstyvasis Prancūzijos modernizmas',
 			'1959ACAD' => 'Akademinis',
 			'AREVELA' => 'Rytų armėnai',
 			'AREVMDA' => 'Vakarų armėnai',
 			'BAKU1926' => 'Suvienodinta turkų kalbos lotyniška abėcėlė',
 			'BISKE' => 'San Giorgio / Bila tarmė',
 			'BOONT' => 'Boontling',
 			'FONIPA' => 'Tarptautinės abėcėlės fonetika',
 			'FONUPA' => 'UPA fonetika',
 			'KKCOR' => 'Įprasta rašyba',
 			'LIPAW' => 'Resian tarmei priklausanti Lipovaz tarmė',
 			'MONOTON' => 'Vienodas',
 			'NEDIS' => 'Natisone tarmė',
 			'NJIVA' => 'Gniva / Njiva tarmė',
 			'OSOJS' => 'Oseacco / Osojane tarmė',
 			'PINYIN' => 'Kinų hieroglifų vertimo sistema Romanization',
 			'POLYTON' => 'Polytonic',
 			'POSIX' => 'Kompiuteris',
 			'REVISED' => 'Ištaisyta rašyba',
 			'ROZAJ' => 'Resian',
 			'SAAHO' => 'Saho',
 			'SCOTLAND' => 'Norminė škotiška anglų kalba',
 			'SCOUSE' => 'Scouse',
 			'SOLBA' => 'Stolvizza / Solbica tarmė',
 			'TARASK' => 'Taraskievica tarmė',
 			'UCCOR' => 'Suvienodinta rašyba',
 			'UCRCOR' => 'Suvienodinta ištaisyta rašyba',
 			'VALENCIA' => 'Valenciečiai',
 			'WADEGILE' => 'Wade-Giles Romanization',

		}
	},
);

has 'display_name_key' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'calendar' => 'kalendorius',
 			'cf' => 'valiutos formatas',
 			'colalternate' => 'Rikiavimas nepaisant simbolių',
 			'colbackwards' => 'Atvirkštinis rikiavimas',
 			'colcasefirst' => 'Didžiųjų / mažųjų raidžių tvarka',
 			'colcaselevel' => 'Rikiavimas skiriant didžiąsias ir mažąsias raides',
 			'collation' => 'rikiavimas',
 			'colnormalization' => 'Normalizuotas rikiavimas',
 			'colnumeric' => 'Skaitinis rikiavimas',
 			'colstrength' => 'Rikiavimo intensyvumas',
 			'currency' => 'valiuta',
 			'hc' => 'valandų ciklas (12 ir 24)',
 			'lb' => 'teksto laužymo stilius',
 			'ms' => 'matų sistema',
 			'numbers' => 'skaičiai',
 			'timezone' => 'Laiko juosta',
 			'va' => 'Lokalės variantas',
 			'x' => 'Naudoti privačiai',

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
 				'buddhist' => q{budistų kalendorius},
 				'chinese' => q{kinų kalendorius},
 				'coptic' => q{koptų kalendorius},
 				'dangi' => q{dangi kalendorius},
 				'ethiopic' => q{Etiopijos kalendorius},
 				'ethiopic-amete-alem' => q{Etiopijos „Amete Alem“ kalendorius},
 				'gregorian' => q{Grigaliaus kalendorius},
 				'hebrew' => q{hebrajų kalendorius},
 				'indian' => q{nacionalinis indų kalendorius},
 				'islamic' => q{islamo kalendorius},
 				'islamic-civil' => q{Islamo kalendorius (lentelinis, pilietinė era)},
 				'islamic-rgsa' => q{Islamo kalendorius (Saudo Arabija)},
 				'islamic-tbla' => q{Islamo kalendorius (lentelinis, astronominė era)},
 				'islamic-umalqura' => q{Islamo kalendorius (Umm al-Qura)},
 				'iso8601' => q{ISO 8601 kalendorius},
 				'japanese' => q{japonų kalendorius},
 				'persian' => q{persų kalendorius},
 				'roc' => q{Kinijos Respublikos kalendorius},
 			},
 			'cf' => {
 				'account' => q{apskaitos valiutos formatas},
 				'standard' => q{standartinis valiutos formatas},
 			},
 			'colalternate' => {
 				'non-ignorable' => q{Rikiuoti simbolius},
 				'shifted' => q{Rikiuoti nepaisant simbolių},
 			},
 			'colbackwards' => {
 				'no' => q{Rikiuoti diakritinius ženklus įprastai},
 				'yes' => q{Rikiuoti diakritinius ženklus atvirkščiai},
 			},
 			'colcasefirst' => {
 				'lower' => q{Rikiuoti suteikiant pirmumą mažosioms raidėms},
 				'no' => q{Rikiuoti įprasta didžiųjų ir mažųjų raidžių tvarka},
 				'upper' => q{Rikiuoti suteikiant pirmumą didžiosioms raidėms},
 			},
 			'colcaselevel' => {
 				'no' => q{Rikiuoti neskiriant didžiųjų ir mažųjų raidžių},
 				'yes' => q{Rikiuoti skiriant didžiąsias ir mažąsias raides},
 			},
 			'collation' => {
 				'big5han' => q{įprasta kiniška rūšiavimo tvarka - Big5},
 				'compat' => q{ankstesnė rūšiavimo tvarka, skirta suderinamumui},
 				'dictionary' => q{žodyno rūšiavimo tvarka},
 				'ducet' => q{numatytasis unikodo rikiavimas},
 				'eor' => q{rūšiavimo tvarka daugiakalbės Europos dokumentų},
 				'gb2312han' => q{supaprastinta kiniška rūšiavimo tvarka - GB2312},
 				'phonebook' => q{telefonų knygos rūšiavimo tvarka},
 				'phonetic' => q{Fonetinė rikiavimo tvarka},
 				'pinyin' => q{supaprastinta kiniškų hieroglifų rūšiavimo tvarka},
 				'search' => q{bendroji paieška},
 				'searchjl' => q{ieškoti pagal hangul pirmines priebalses},
 				'standard' => q{standartinis rikiavimas},
 				'stroke' => q{Įprasta kiniško požymio rūšiavimo tvarka},
 				'traditional' => q{įprasta rūšiavimo tvarka},
 				'unihan' => q{Šaknies ženklų ir brūkšnių rūšiavimo tvarka},
 				'zhuyin' => q{Zhuyin rikiavimo tvarka},
 			},
 			'colnormalization' => {
 				'no' => q{Rikiuoti nenormalizuojant},
 				'yes' => q{Rikiuoti normalizuojant unikodą},
 			},
 			'colnumeric' => {
 				'no' => q{Rikiuoti skaitmenis atskirai},
 				'yes' => q{Rikiuoti skaitmenis pagal skaičius},
 			},
 			'colstrength' => {
 				'identical' => q{Rikiuoti viską},
 				'primary' => q{Rikiuoti tik pagal pamatines raides},
 				'quaternary' => q{Rikiuoti pagal didžiąsias ir mažąsias raides / plotį / diakritinius / kanos ženklus},
 				'secondary' => q{Rikiuoti diakritinius ženklus},
 				'tertiary' => q{Rikiuoti pagal diakritinius ženklus / didžiąsias ir mažąsias raides / plotį},
 			},
 			'd0' => {
 				'fwidth' => q{viso pločio},
 				'hwidth' => q{vidutinio pločio},
 				'npinyin' => q{Skaitinis},
 			},
 			'hc' => {
 				'h11' => q{12 valandų sistema (0–11)},
 				'h12' => q{12 valandų sistema (1–12)},
 				'h23' => q{24 valandų sistema (0–23)},
 				'h24' => q{24 valandų sistema (1–24)},
 			},
 			'lb' => {
 				'loose' => q{laisvas teksto laužymo stilius},
 				'normal' => q{įprastas teksto laužymo stilius},
 				'strict' => q{griežtas teksto laužymo stilius},
 			},
 			'm0' => {
 				'bgn' => q{BGN simboliai},
 				'ungegn' => q{UNGEGN simboliai},
 			},
 			'ms' => {
 				'metric' => q{metrinė sistema},
 				'uksystem' => q{angliška matų sistema},
 				'ussystem' => q{amerikietiška matų sistema},
 			},
 			'numbers' => {
 				'arab' => q{arabų-indų skaitmenys},
 				'arabext' => q{išplėstiniai arabų-indų skaitmenys},
 				'armn' => q{armėnų skaitmenys},
 				'armnlow' => q{armėnų skaitmenys mažosiomis raidėmis},
 				'bali' => q{bali skaitmenys},
 				'beng' => q{bengalų skaitmenys},
 				'brah' => q{Brahmi skaitmenys},
 				'cakm' => q{Čakmų skaitmenys},
 				'cham' => q{cham skaitmenys},
 				'deva' => q{devanagari skaitmenys},
 				'ethi' => q{Etiopijos skaitmenys},
 				'finance' => q{Finansiniai skaičiai},
 				'fullwide' => q{viso pločio skaitmenys},
 				'geor' => q{gruzinų skaitmenys},
 				'grek' => q{graikų skaitmenys},
 				'greklow' => q{graikų skaitmenys mažosiomis raidėmis},
 				'gujr' => q{gudžaratų skaitmenys},
 				'guru' => q{gurmuki skaitmenys},
 				'hanidec' => q{kinų dešimtainiai skaitmenys},
 				'hans' => q{supaprastintos kinų k. skaitmenys},
 				'hansfin' => q{supaprastintos kinų k. finans. skaitmenys},
 				'hant' => q{tradicinės kinų k. skaitmenys},
 				'hantfin' => q{tradicinės kinų k. finans. skaitmenys},
 				'hebr' => q{hebrajų skaitmenys},
 				'java' => q{javiečių skaitmenys},
 				'jpan' => q{japonų skaitmenys},
 				'jpanfin' => q{japonų finans. skaitmenys},
 				'kali' => q{Kayah Li skaitmenys},
 				'khmr' => q{khmerų skaitmenys},
 				'knda' => q{kanadų skaitmenys},
 				'lana' => q{Tai Tham Hora skaitmenys},
 				'lanatham' => q{Tai Tham Tham skaitmenys},
 				'laoo' => q{laosiečių skaitmenys},
 				'latn' => q{lotyniški skaitmenys},
 				'lepc' => q{Lepcha skaitmenys},
 				'limb' => q{Limbu skaitmenys},
 				'mlym' => q{malajalių skaitmenys},
 				'mong' => q{mongolų skaitmenys},
 				'mtei' => q{Meetei Mayek skaitmenys},
 				'mymr' => q{mianmariečių skaitmenys},
 				'mymrshan' => q{Myanmar Shan skaitmenys},
 				'native' => q{Vietiniai skaitmenys},
 				'nkoo' => q{N’Ko skaitmenys},
 				'olck' => q{Ol Chiki skaitmenys},
 				'orya' => q{orijų skaitmenys},
 				'osma' => q{Osmanų skaitmenys},
 				'roman' => q{romėniški skaitmenys},
 				'romanlow' => q{romėniški skaitmenys mažosiomis raidėmis},
 				'saur' => q{Sauraštrų skaitmenys},
 				'shrd' => q{Šaradų skaitmenys},
 				'sora' => q{Sora Sompeng skaitmenys},
 				'sund' => q{Sudaniečių skaitmenys},
 				'takr' => q{Takri skaitmenys},
 				'talu' => q{Naujieji Tai Lue skaitmenys},
 				'taml' => q{tradicinės tamilų skaitmenys},
 				'tamldec' => q{tamilų skaitmenys},
 				'telu' => q{telugų skaitmenys},
 				'thai' => q{tajų skaitmenys},
 				'tibt' => q{tibetiečių skaitmenys},
 				'traditional' => q{Tradiciniai skaičiai},
 				'vaii' => q{vai skaitmenys},
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
			'metric' => q{metrinė},
 			'UK' => q{JK},
 			'US' => q{JAV},

		}
	},
);

has 'display_name_code_patterns' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'language' => 'Kalba: {0}',
 			'script' => 'Rašmenys: {0}',
 			'region' => 'Sritis: {0}',

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
			auxiliary => qr{[áàã{ą́}{ą̃} {ch} {dz} {dž} éèẽ{ę́}{ę̃}{ė́}{ė̃} í{i̇́}ì{i̇̀}ĩ{i̇̃}{į́}{į̇́}{į̃}{į̇̃} {j̃}{j̇̃} {l̃} {m̃} ñ óòõ q {r̃} úùũ{ų́}{ų̃}{ū́}{ū̃} w x]},
			index => ['AĄ', 'B', 'C', 'Č', 'D', 'EĘĖ', 'F', 'G', 'H', 'IĮY', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R', 'S', 'Š', 'T', 'UŲŪ', 'V', 'Z', 'Ž'],
			main => qr{[aą b c č d eęė f g h iįy j k l m n o p r s š t uųū v z ž]},
			numbers => qr{[  , % ‰ + − 0 1 2 3 4 5 6 7 8 9]},
			punctuation => qr{[\- ‐‑ – — , ; \: ! ? . … “„ ( ) \[ \] \{ \}]},
		};
	},
EOT
: sub {
		return { index => ['AĄ', 'B', 'C', 'Č', 'D', 'EĘĖ', 'F', 'G', 'H', 'IĮY', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'R', 'S', 'Š', 'T', 'UŲŪ', 'V', 'Z', 'Ž'], };
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

has 'duration_units' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub { {
				hm => 'hh:mm',
				hms => 'hh:mm:ss',
				ms => 'mm:ss',
			} }
);

has 'units' => (
	is			=> 'ro',
	isa			=> HashRef[HashRef[HashRef[Str]]],
	init_arg	=> undef,
	default		=> sub { {
				'long' => {
					# Long Unit Identifier
					'' => {
						'name' => q(pagrindinė kryptis),
					},
					# Core Unit Identifier
					'' => {
						'name' => q(pagrindinė kryptis),
					},
					# Long Unit Identifier
					'1024p1' => {
						'1' => q(kibi{0}),
					},
					# Core Unit Identifier
					'1024p1' => {
						'1' => q(kibi{0}),
					},
					# Long Unit Identifier
					'1024p2' => {
						'1' => q(mebi{0}),
					},
					# Core Unit Identifier
					'1024p2' => {
						'1' => q(mebi{0}),
					},
					# Long Unit Identifier
					'1024p3' => {
						'1' => q(gibi{0}),
					},
					# Core Unit Identifier
					'1024p3' => {
						'1' => q(gibi{0}),
					},
					# Long Unit Identifier
					'1024p4' => {
						'1' => q(tebi{0}),
					},
					# Core Unit Identifier
					'1024p4' => {
						'1' => q(tebi{0}),
					},
					# Long Unit Identifier
					'1024p5' => {
						'1' => q(pebi{0}),
					},
					# Core Unit Identifier
					'1024p5' => {
						'1' => q(pebi{0}),
					},
					# Long Unit Identifier
					'1024p6' => {
						'1' => q(exbi{0}),
					},
					# Core Unit Identifier
					'1024p6' => {
						'1' => q(exbi{0}),
					},
					# Long Unit Identifier
					'1024p7' => {
						'1' => q(zebi{0}),
					},
					# Core Unit Identifier
					'1024p7' => {
						'1' => q(zebi{0}),
					},
					# Long Unit Identifier
					'1024p8' => {
						'1' => q(yobe{0}),
					},
					# Core Unit Identifier
					'1024p8' => {
						'1' => q(yobe{0}),
					},
					# Long Unit Identifier
					'10p-1' => {
						'1' => q(deci{0}),
					},
					# Core Unit Identifier
					'1' => {
						'1' => q(deci{0}),
					},
					# Long Unit Identifier
					'10p-12' => {
						'1' => q(piko{0}),
					},
					# Core Unit Identifier
					'12' => {
						'1' => q(piko{0}),
					},
					# Long Unit Identifier
					'10p-15' => {
						'1' => q(femto{0}),
					},
					# Core Unit Identifier
					'15' => {
						'1' => q(femto{0}),
					},
					# Long Unit Identifier
					'10p-18' => {
						'1' => q(ato{0}),
					},
					# Core Unit Identifier
					'18' => {
						'1' => q(ato{0}),
					},
					# Long Unit Identifier
					'10p-2' => {
						'1' => q(centi{0}),
					},
					# Core Unit Identifier
					'2' => {
						'1' => q(centi{0}),
					},
					# Long Unit Identifier
					'10p-21' => {
						'1' => q(zepto{0}),
					},
					# Core Unit Identifier
					'21' => {
						'1' => q(zepto{0}),
					},
					# Long Unit Identifier
					'10p-24' => {
						'1' => q(jokto{0}),
					},
					# Core Unit Identifier
					'24' => {
						'1' => q(jokto{0}),
					},
					# Long Unit Identifier
					'10p-27' => {
						'1' => q(ronto{0}),
					},
					# Core Unit Identifier
					'27' => {
						'1' => q(ronto{0}),
					},
					# Long Unit Identifier
					'10p-3' => {
						'1' => q(mili{0}),
					},
					# Core Unit Identifier
					'3' => {
						'1' => q(mili{0}),
					},
					# Long Unit Identifier
					'10p-30' => {
						'1' => q(kvekto{0}),
					},
					# Core Unit Identifier
					'30' => {
						'1' => q(kvekto{0}),
					},
					# Long Unit Identifier
					'10p-6' => {
						'1' => q(mikro{0}),
					},
					# Core Unit Identifier
					'6' => {
						'1' => q(mikro{0}),
					},
					# Long Unit Identifier
					'10p-9' => {
						'1' => q(nano{0}),
					},
					# Core Unit Identifier
					'9' => {
						'1' => q(nano{0}),
					},
					# Long Unit Identifier
					'10p1' => {
						'1' => q(deka{0}),
					},
					# Core Unit Identifier
					'10p1' => {
						'1' => q(deka{0}),
					},
					# Long Unit Identifier
					'10p12' => {
						'1' => q(tera{0}),
					},
					# Core Unit Identifier
					'10p12' => {
						'1' => q(tera{0}),
					},
					# Long Unit Identifier
					'10p15' => {
						'1' => q(peta{0}),
					},
					# Core Unit Identifier
					'10p15' => {
						'1' => q(peta{0}),
					},
					# Long Unit Identifier
					'10p18' => {
						'1' => q(eksa{0}),
					},
					# Core Unit Identifier
					'10p18' => {
						'1' => q(eksa{0}),
					},
					# Long Unit Identifier
					'10p2' => {
						'1' => q(hekto{0}),
					},
					# Core Unit Identifier
					'10p2' => {
						'1' => q(hekto{0}),
					},
					# Long Unit Identifier
					'10p21' => {
						'1' => q(zeta{0}),
					},
					# Core Unit Identifier
					'10p21' => {
						'1' => q(zeta{0}),
					},
					# Long Unit Identifier
					'10p24' => {
						'1' => q(jota{0}),
					},
					# Core Unit Identifier
					'10p24' => {
						'1' => q(jota{0}),
					},
					# Long Unit Identifier
					'10p27' => {
						'1' => q(rona{0}),
					},
					# Core Unit Identifier
					'10p27' => {
						'1' => q(rona{0}),
					},
					# Long Unit Identifier
					'10p3' => {
						'1' => q(kilo{0}),
					},
					# Core Unit Identifier
					'10p3' => {
						'1' => q(kilo{0}),
					},
					# Long Unit Identifier
					'10p30' => {
						'1' => q(geta{0}),
					},
					# Core Unit Identifier
					'10p30' => {
						'1' => q(geta{0}),
					},
					# Long Unit Identifier
					'10p6' => {
						'1' => q(mega{0}),
					},
					# Core Unit Identifier
					'10p6' => {
						'1' => q(mega{0}),
					},
					# Long Unit Identifier
					'10p9' => {
						'1' => q(giga{0}),
					},
					# Core Unit Identifier
					'10p9' => {
						'1' => q(giga{0}),
					},
					# Long Unit Identifier
					'acceleration-g-force' => {
						'1' => q(masculine),
						'few' => q({0} laisvojo kritimo pagreičiai),
						'many' => q({0} laisvojo kritimo pagreičio),
						'name' => q(laisvojo kritimo pagreičiai),
						'one' => q({0} laisvojo kritimo pagreitis),
						'other' => q({0} laisvojo kritimo pagreičių),
					},
					# Core Unit Identifier
					'g-force' => {
						'1' => q(masculine),
						'few' => q({0} laisvojo kritimo pagreičiai),
						'many' => q({0} laisvojo kritimo pagreičio),
						'name' => q(laisvojo kritimo pagreičiai),
						'one' => q({0} laisvojo kritimo pagreitis),
						'other' => q({0} laisvojo kritimo pagreičių),
					},
					# Long Unit Identifier
					'acceleration-meter-per-square-second' => {
						'1' => q(masculine),
						'few' => q({0} m/s²),
						'many' => q({0} m/s²),
						'name' => q(metrai per kvadratinę sekundę),
						'one' => q({0} metras per kvadratinę sekundę),
						'other' => q({0} metrų per kvadratinę sekundę),
					},
					# Core Unit Identifier
					'meter-per-square-second' => {
						'1' => q(masculine),
						'few' => q({0} m/s²),
						'many' => q({0} m/s²),
						'name' => q(metrai per kvadratinę sekundę),
						'one' => q({0} metras per kvadratinę sekundę),
						'other' => q({0} metrų per kvadratinę sekundę),
					},
					# Long Unit Identifier
					'angle-arc-minute' => {
						'1' => q(feminine),
						'few' => q({0} kampo minutės),
						'many' => q({0} kampo minutės),
						'one' => q({0} kampo minutė),
						'other' => q({0} kampo minučių),
					},
					# Core Unit Identifier
					'arc-minute' => {
						'1' => q(feminine),
						'few' => q({0} kampo minutės),
						'many' => q({0} kampo minutės),
						'one' => q({0} kampo minutė),
						'other' => q({0} kampo minučių),
					},
					# Long Unit Identifier
					'angle-arc-second' => {
						'1' => q(feminine),
						'few' => q({0} kampo sekundės),
						'many' => q({0} kampo sekundės),
						'one' => q({0} kampo sekundė),
						'other' => q({0} kampo sekundžių),
					},
					# Core Unit Identifier
					'arc-second' => {
						'1' => q(feminine),
						'few' => q({0} kampo sekundės),
						'many' => q({0} kampo sekundės),
						'one' => q({0} kampo sekundė),
						'other' => q({0} kampo sekundžių),
					},
					# Long Unit Identifier
					'angle-degree' => {
						'1' => q(masculine),
						'few' => q({0} laipsniai),
						'many' => q({0} laipsnio),
						'one' => q({0} laipsnis),
						'other' => q({0} laipsnių),
					},
					# Core Unit Identifier
					'degree' => {
						'1' => q(masculine),
						'few' => q({0} laipsniai),
						'many' => q({0} laipsnio),
						'one' => q({0} laipsnis),
						'other' => q({0} laipsnių),
					},
					# Long Unit Identifier
					'angle-radian' => {
						'1' => q(masculine),
						'few' => q({0} radianai),
						'many' => q({0} radiano),
						'name' => q(radianai),
						'one' => q({0} radianas),
						'other' => q({0} radianų),
					},
					# Core Unit Identifier
					'radian' => {
						'1' => q(masculine),
						'few' => q({0} radianai),
						'many' => q({0} radiano),
						'name' => q(radianai),
						'one' => q({0} radianas),
						'other' => q({0} radianų),
					},
					# Long Unit Identifier
					'angle-revolution' => {
						'1' => q(masculine),
						'few' => q({0} pilni apsisukimai),
						'many' => q({0} pilno apsisukimo),
						'name' => q(pilnas apsisukimas),
						'one' => q({0} pilnas apsisukimas),
						'other' => q({0} pilnų apsisukimų),
					},
					# Core Unit Identifier
					'revolution' => {
						'1' => q(masculine),
						'few' => q({0} pilni apsisukimai),
						'many' => q({0} pilno apsisukimo),
						'name' => q(pilnas apsisukimas),
						'one' => q({0} pilnas apsisukimas),
						'other' => q({0} pilnų apsisukimų),
					},
					# Long Unit Identifier
					'area-acre' => {
						'few' => q({0} akrai),
						'many' => q({0} akro),
						'one' => q({0} akras),
						'other' => q({0} akrų),
					},
					# Core Unit Identifier
					'acre' => {
						'few' => q({0} akrai),
						'many' => q({0} akro),
						'one' => q({0} akras),
						'other' => q({0} akrų),
					},
					# Long Unit Identifier
					'area-hectare' => {
						'1' => q(masculine),
						'few' => q({0} hektarai),
						'many' => q({0} hektaro),
						'one' => q({0} hektaras),
						'other' => q({0} hektarų),
					},
					# Core Unit Identifier
					'hectare' => {
						'1' => q(masculine),
						'few' => q({0} hektarai),
						'many' => q({0} hektaro),
						'one' => q({0} hektaras),
						'other' => q({0} hektarų),
					},
					# Long Unit Identifier
					'area-square-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} kvadratiniai centimetrai),
						'many' => q({0} kvadratinio centimetro),
						'name' => q(kvadratiniai centimetrai),
						'one' => q({0} kvadratinis centimetras),
						'other' => q({0} kvadratinių centimetrų),
					},
					# Core Unit Identifier
					'square-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} kvadratiniai centimetrai),
						'many' => q({0} kvadratinio centimetro),
						'name' => q(kvadratiniai centimetrai),
						'one' => q({0} kvadratinis centimetras),
						'other' => q({0} kvadratinių centimetrų),
					},
					# Long Unit Identifier
					'area-square-foot' => {
						'few' => q({0} kvadratinės pėdos),
						'many' => q({0} kvadratinės pėdos),
						'name' => q(kvadratinės pėdos),
						'one' => q({0} kvadratinė pėda),
						'other' => q({0} kvadratinių pėdų),
					},
					# Core Unit Identifier
					'square-foot' => {
						'few' => q({0} kvadratinės pėdos),
						'many' => q({0} kvadratinės pėdos),
						'name' => q(kvadratinės pėdos),
						'one' => q({0} kvadratinė pėda),
						'other' => q({0} kvadratinių pėdų),
					},
					# Long Unit Identifier
					'area-square-inch' => {
						'few' => q({0} kvadratiniai coliai),
						'many' => q({0} kvadratinio colio),
						'name' => q(kvadratiniai coliai),
						'one' => q({0} kvadratinis colis),
						'other' => q({0} kvadratinių colių),
					},
					# Core Unit Identifier
					'square-inch' => {
						'few' => q({0} kvadratiniai coliai),
						'many' => q({0} kvadratinio colio),
						'name' => q(kvadratiniai coliai),
						'one' => q({0} kvadratinis colis),
						'other' => q({0} kvadratinių colių),
					},
					# Long Unit Identifier
					'area-square-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} kvadratiniai kilometrai),
						'many' => q({0} kvadratinio kilometro),
						'name' => q(kvadratiniai kilometrai),
						'one' => q({0} kvadratinis kilometras),
						'other' => q({0} kvadratinių kilometrų),
						'per' => q({0} kv. km),
					},
					# Core Unit Identifier
					'square-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} kvadratiniai kilometrai),
						'many' => q({0} kvadratinio kilometro),
						'name' => q(kvadratiniai kilometrai),
						'one' => q({0} kvadratinis kilometras),
						'other' => q({0} kvadratinių kilometrų),
						'per' => q({0} kv. km),
					},
					# Long Unit Identifier
					'area-square-meter' => {
						'1' => q(masculine),
						'few' => q({0} kvadratiniai metrai),
						'many' => q({0} kvadratinio metro),
						'name' => q(kvadratiniai metrai),
						'one' => q({0} kvadratinis metras),
						'other' => q({0} kvadratinių metrų),
					},
					# Core Unit Identifier
					'square-meter' => {
						'1' => q(masculine),
						'few' => q({0} kvadratiniai metrai),
						'many' => q({0} kvadratinio metro),
						'name' => q(kvadratiniai metrai),
						'one' => q({0} kvadratinis metras),
						'other' => q({0} kvadratinių metrų),
					},
					# Long Unit Identifier
					'area-square-mile' => {
						'few' => q({0} kvadratinės mylios),
						'many' => q({0} kvadratinės mylios),
						'name' => q(kvadratinės mylios),
						'one' => q({0} kvadratinė mylia),
						'other' => q({0} kvadratinių mylių),
						'per' => q({0} kv. my),
					},
					# Core Unit Identifier
					'square-mile' => {
						'few' => q({0} kvadratinės mylios),
						'many' => q({0} kvadratinės mylios),
						'name' => q(kvadratinės mylios),
						'one' => q({0} kvadratinė mylia),
						'other' => q({0} kvadratinių mylių),
						'per' => q({0} kv. my),
					},
					# Long Unit Identifier
					'area-square-yard' => {
						'few' => q({0} kvadratiniai jardai),
						'many' => q({0} kvadratinio jardo),
						'name' => q(kvadratiniai jardai),
						'one' => q({0} kvadratinis jardas),
						'other' => q({0} yd²),
					},
					# Core Unit Identifier
					'square-yard' => {
						'few' => q({0} kvadratiniai jardai),
						'many' => q({0} kvadratinio jardo),
						'name' => q(kvadratiniai jardai),
						'one' => q({0} kvadratinis jardas),
						'other' => q({0} yd²),
					},
					# Long Unit Identifier
					'concentr-item' => {
						'1' => q(masculine),
						'few' => q({0} elementai),
						'many' => q({0} elemento),
						'one' => q({0} elementas),
						'other' => q({0} elementų),
					},
					# Core Unit Identifier
					'item' => {
						'1' => q(masculine),
						'few' => q({0} elementai),
						'many' => q({0} elemento),
						'one' => q({0} elementas),
						'other' => q({0} elementų),
					},
					# Long Unit Identifier
					'concentr-karat' => {
						'1' => q(masculine),
						'few' => q({0} karatai),
						'many' => q({0} karato),
						'name' => q(karatai),
						'one' => q({0} karatas),
						'other' => q({0} karatų),
					},
					# Core Unit Identifier
					'karat' => {
						'1' => q(masculine),
						'few' => q({0} karatai),
						'many' => q({0} karato),
						'name' => q(karatai),
						'one' => q({0} karatas),
						'other' => q({0} karatų),
					},
					# Long Unit Identifier
					'concentr-milligram-ofglucose-per-deciliter' => {
						'1' => q(masculine),
						'few' => q({0} miligramai decilitre),
						'many' => q({0} miligramo decilitre),
						'name' => q(miligramai decilitre),
						'one' => q({0} miligramas decilitre),
						'other' => q({0} miligramų decilitre),
					},
					# Core Unit Identifier
					'milligram-ofglucose-per-deciliter' => {
						'1' => q(masculine),
						'few' => q({0} miligramai decilitre),
						'many' => q({0} miligramo decilitre),
						'name' => q(miligramai decilitre),
						'one' => q({0} miligramas decilitre),
						'other' => q({0} miligramų decilitre),
					},
					# Long Unit Identifier
					'concentr-millimole-per-liter' => {
						'1' => q(masculine),
						'few' => q({0} milimoliai litre),
						'many' => q({0} milimoliai litre),
						'name' => q(milimoliai litre),
						'one' => q({0} milimolis litre),
						'other' => q({0} milimolių litre),
					},
					# Core Unit Identifier
					'millimole-per-liter' => {
						'1' => q(masculine),
						'few' => q({0} milimoliai litre),
						'many' => q({0} milimoliai litre),
						'name' => q(milimoliai litre),
						'one' => q({0} milimolis litre),
						'other' => q({0} milimolių litre),
					},
					# Long Unit Identifier
					'concentr-mole' => {
						'1' => q(masculine),
						'few' => q({0} moliai),
						'many' => q({0} molio),
						'name' => q(moliai),
						'one' => q({0} molis),
						'other' => q({0} molių),
					},
					# Core Unit Identifier
					'mole' => {
						'1' => q(masculine),
						'few' => q({0} moliai),
						'many' => q({0} molio),
						'name' => q(moliai),
						'one' => q({0} molis),
						'other' => q({0} molių),
					},
					# Long Unit Identifier
					'concentr-percent' => {
						'1' => q(masculine),
						'few' => q({0} procentai),
						'many' => q({0} procento),
						'one' => q({0} procentas),
						'other' => q({0} procentas),
					},
					# Core Unit Identifier
					'percent' => {
						'1' => q(masculine),
						'few' => q({0} procentai),
						'many' => q({0} procento),
						'one' => q({0} procentas),
						'other' => q({0} procentas),
					},
					# Long Unit Identifier
					'concentr-permille' => {
						'1' => q(feminine),
						'few' => q({0} promilės),
						'many' => q({0} promilės),
						'one' => q({0} promilė),
						'other' => q({0} promilių),
					},
					# Core Unit Identifier
					'permille' => {
						'1' => q(feminine),
						'few' => q({0} promilės),
						'many' => q({0} promilės),
						'one' => q({0} promilė),
						'other' => q({0} promilių),
					},
					# Long Unit Identifier
					'concentr-permillion' => {
						'1' => q(feminine),
						'few' => q({0} milijoninės dalys),
						'many' => q({0} milijoninės dalies),
						'name' => q(milijoninės dalys),
						'one' => q({0} milijoninė dalis),
						'other' => q({0} milijoninių dalių),
					},
					# Core Unit Identifier
					'permillion' => {
						'1' => q(feminine),
						'few' => q({0} milijoninės dalys),
						'many' => q({0} milijoninės dalies),
						'name' => q(milijoninės dalys),
						'one' => q({0} milijoninė dalis),
						'other' => q({0} milijoninių dalių),
					},
					# Long Unit Identifier
					'concentr-permyriad' => {
						'1' => q(masculine),
					},
					# Core Unit Identifier
					'permyriad' => {
						'1' => q(masculine),
					},
					# Long Unit Identifier
					'concentr-portion-per-1e9' => {
						'1' => q(feminine),
						'few' => q({0} milijoninės dalelytės),
						'many' => q({0} milijoninės dalelytės),
						'name' => q(milijoninės dalelytės),
						'one' => q({0} milijoninė dalelytė),
						'other' => q({0} milijoninių dalelyčių),
					},
					# Core Unit Identifier
					'portion-per-1e9' => {
						'1' => q(feminine),
						'few' => q({0} milijoninės dalelytės),
						'many' => q({0} milijoninės dalelytės),
						'name' => q(milijoninės dalelytės),
						'one' => q({0} milijoninė dalelytė),
						'other' => q({0} milijoninių dalelyčių),
					},
					# Long Unit Identifier
					'consumption-liter-per-100-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} litrai 100 kilometrų),
						'many' => q({0} litro 100 kilometrų),
						'name' => q(litrai 100 kilometrų),
						'one' => q({0} litras 100 kilometrų),
						'other' => q({0} litrų 100 kilometrų),
					},
					# Core Unit Identifier
					'liter-per-100-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} litrai 100 kilometrų),
						'many' => q({0} litro 100 kilometrų),
						'name' => q(litrai 100 kilometrų),
						'one' => q({0} litras 100 kilometrų),
						'other' => q({0} litrų 100 kilometrų),
					},
					# Long Unit Identifier
					'consumption-liter-per-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} litrai kilometrui),
						'many' => q({0} litro kilometrui),
						'name' => q(litrai kilometrui),
						'one' => q({0} litras kilometrui),
						'other' => q({0} litrų kilometrui),
					},
					# Core Unit Identifier
					'liter-per-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} litrai kilometrui),
						'many' => q({0} litro kilometrui),
						'name' => q(litrai kilometrui),
						'one' => q({0} litras kilometrui),
						'other' => q({0} litrų kilometrui),
					},
					# Long Unit Identifier
					'consumption-mile-per-gallon' => {
						'few' => q({0} mylios už galoną),
						'many' => q({0} mylios už galoną),
						'name' => q(mylios už galoną),
						'one' => q({0} mylia už galoną),
						'other' => q({0} mylių už galoną),
					},
					# Core Unit Identifier
					'mile-per-gallon' => {
						'few' => q({0} mylios už galoną),
						'many' => q({0} mylios už galoną),
						'name' => q(mylios už galoną),
						'one' => q({0} mylia už galoną),
						'other' => q({0} mylių už galoną),
					},
					# Long Unit Identifier
					'consumption-mile-per-gallon-imperial' => {
						'few' => q({0} mylios už imperinį galoną),
						'many' => q({0} mylios už imperinį galoną),
						'name' => q(mylios už imperinį galoną),
						'one' => q({0} mylia už imperinį galoną),
						'other' => q({0} mylių už imperinį galoną),
					},
					# Core Unit Identifier
					'mile-per-gallon-imperial' => {
						'few' => q({0} mylios už imperinį galoną),
						'many' => q({0} mylios už imperinį galoną),
						'name' => q(mylios už imperinį galoną),
						'one' => q({0} mylia už imperinį galoną),
						'other' => q({0} mylių už imperinį galoną),
					},
					# Long Unit Identifier
					'coordinate' => {
						'east' => q({0} rytų),
						'north' => q({0} šiaurės),
						'south' => q({0} pietų),
						'west' => q({0} vakarų),
					},
					# Core Unit Identifier
					'coordinate' => {
						'east' => q({0} rytų),
						'north' => q({0} šiaurės),
						'south' => q({0} pietų),
						'west' => q({0} vakarų),
					},
					# Long Unit Identifier
					'digital-bit' => {
						'1' => q(masculine),
						'few' => q({0} bitai),
						'many' => q({0} bito),
						'one' => q({0} bitas),
						'other' => q({0} bitų),
					},
					# Core Unit Identifier
					'bit' => {
						'1' => q(masculine),
						'few' => q({0} bitai),
						'many' => q({0} bito),
						'one' => q({0} bitas),
						'other' => q({0} bitų),
					},
					# Long Unit Identifier
					'digital-byte' => {
						'1' => q(masculine),
						'few' => q({0} baitai),
						'many' => q({0} baito),
						'name' => q(baitai),
						'one' => q({0} baitas),
						'other' => q({0} baitų),
					},
					# Core Unit Identifier
					'byte' => {
						'1' => q(masculine),
						'few' => q({0} baitai),
						'many' => q({0} baito),
						'name' => q(baitai),
						'one' => q({0} baitas),
						'other' => q({0} baitų),
					},
					# Long Unit Identifier
					'digital-gigabit' => {
						'1' => q(masculine),
						'few' => q({0} gigabitai),
						'many' => q({0} gigabito),
						'name' => q(gigabitai),
						'one' => q({0} gigabitas),
						'other' => q({0} gigabitų),
					},
					# Core Unit Identifier
					'gigabit' => {
						'1' => q(masculine),
						'few' => q({0} gigabitai),
						'many' => q({0} gigabito),
						'name' => q(gigabitai),
						'one' => q({0} gigabitas),
						'other' => q({0} gigabitų),
					},
					# Long Unit Identifier
					'digital-gigabyte' => {
						'1' => q(masculine),
						'few' => q({0} gigabaitai),
						'many' => q({0} gigabaito),
						'name' => q(gigabaitai),
						'one' => q({0} gigabaitas),
						'other' => q({0} gigabaitų),
					},
					# Core Unit Identifier
					'gigabyte' => {
						'1' => q(masculine),
						'few' => q({0} gigabaitai),
						'many' => q({0} gigabaito),
						'name' => q(gigabaitai),
						'one' => q({0} gigabaitas),
						'other' => q({0} gigabaitų),
					},
					# Long Unit Identifier
					'digital-kilobit' => {
						'1' => q(masculine),
						'few' => q({0} kilobitai),
						'many' => q({0} kilobito),
						'name' => q(kilobitai),
						'one' => q({0} kilobitas),
						'other' => q({0} kilobitų),
					},
					# Core Unit Identifier
					'kilobit' => {
						'1' => q(masculine),
						'few' => q({0} kilobitai),
						'many' => q({0} kilobito),
						'name' => q(kilobitai),
						'one' => q({0} kilobitas),
						'other' => q({0} kilobitų),
					},
					# Long Unit Identifier
					'digital-kilobyte' => {
						'1' => q(masculine),
						'few' => q({0} kilobaitai),
						'many' => q({0} kilobaito),
						'name' => q(kilobaitai),
						'one' => q({0} kilobaitas),
						'other' => q({0} kilobaitų),
					},
					# Core Unit Identifier
					'kilobyte' => {
						'1' => q(masculine),
						'few' => q({0} kilobaitai),
						'many' => q({0} kilobaito),
						'name' => q(kilobaitai),
						'one' => q({0} kilobaitas),
						'other' => q({0} kilobaitų),
					},
					# Long Unit Identifier
					'digital-megabit' => {
						'1' => q(masculine),
						'few' => q({0} megabitai),
						'many' => q({0} megabito),
						'name' => q(megabitai),
						'one' => q({0} megabitas),
						'other' => q({0} megabitų),
					},
					# Core Unit Identifier
					'megabit' => {
						'1' => q(masculine),
						'few' => q({0} megabitai),
						'many' => q({0} megabito),
						'name' => q(megabitai),
						'one' => q({0} megabitas),
						'other' => q({0} megabitų),
					},
					# Long Unit Identifier
					'digital-megabyte' => {
						'1' => q(masculine),
						'few' => q({0} megabaitai),
						'many' => q({0} megabaito),
						'name' => q(megabaitai),
						'one' => q({0} megabaitas),
						'other' => q({0} megabaitų),
					},
					# Core Unit Identifier
					'megabyte' => {
						'1' => q(masculine),
						'few' => q({0} megabaitai),
						'many' => q({0} megabaito),
						'name' => q(megabaitai),
						'one' => q({0} megabaitas),
						'other' => q({0} megabaitų),
					},
					# Long Unit Identifier
					'digital-petabyte' => {
						'1' => q(masculine),
						'few' => q({0} PB),
						'many' => q({0} PB),
						'name' => q(pentabaitai),
						'one' => q({0} pentabaitas),
						'other' => q({0} pentabaitų),
					},
					# Core Unit Identifier
					'petabyte' => {
						'1' => q(masculine),
						'few' => q({0} PB),
						'many' => q({0} PB),
						'name' => q(pentabaitai),
						'one' => q({0} pentabaitas),
						'other' => q({0} pentabaitų),
					},
					# Long Unit Identifier
					'digital-terabit' => {
						'1' => q(masculine),
						'few' => q({0} terabitai),
						'many' => q({0} terabito),
						'name' => q(terabitai),
						'one' => q({0} terabitas),
						'other' => q({0} terabitų),
					},
					# Core Unit Identifier
					'terabit' => {
						'1' => q(masculine),
						'few' => q({0} terabitai),
						'many' => q({0} terabito),
						'name' => q(terabitai),
						'one' => q({0} terabitas),
						'other' => q({0} terabitų),
					},
					# Long Unit Identifier
					'digital-terabyte' => {
						'1' => q(masculine),
						'few' => q({0} terabaitai),
						'many' => q({0} terabaito),
						'name' => q(terabaitai),
						'one' => q({0} terabaitas),
						'other' => q({0} terabaitų),
					},
					# Core Unit Identifier
					'terabyte' => {
						'1' => q(masculine),
						'few' => q({0} terabaitai),
						'many' => q({0} terabaito),
						'name' => q(terabaitai),
						'one' => q({0} terabaitas),
						'other' => q({0} terabaitų),
					},
					# Long Unit Identifier
					'duration-century' => {
						'1' => q(masculine),
						'few' => q({0} amžiai),
						'many' => q({0} amžiaus),
						'name' => q(amžiai),
						'one' => q({0} amžius),
						'other' => q({0} amžių),
					},
					# Core Unit Identifier
					'century' => {
						'1' => q(masculine),
						'few' => q({0} amžiai),
						'many' => q({0} amžiaus),
						'name' => q(amžiai),
						'one' => q({0} amžius),
						'other' => q({0} amžių),
					},
					# Long Unit Identifier
					'duration-day' => {
						'1' => q(feminine),
						'few' => q({0} dienos),
						'many' => q({0} dienos),
						'one' => q({0} diena),
						'other' => q({0} dienų),
						'per' => q({0} per dieną),
					},
					# Core Unit Identifier
					'day' => {
						'1' => q(feminine),
						'few' => q({0} dienos),
						'many' => q({0} dienos),
						'one' => q({0} diena),
						'other' => q({0} dienų),
						'per' => q({0} per dieną),
					},
					# Long Unit Identifier
					'duration-decade' => {
						'1' => q(feminine),
						'few' => q({0} dekados),
						'many' => q({0} dekados),
						'one' => q({0} dekada),
						'other' => q({0} dekadų),
					},
					# Core Unit Identifier
					'decade' => {
						'1' => q(feminine),
						'few' => q({0} dekados),
						'many' => q({0} dekados),
						'one' => q({0} dekada),
						'other' => q({0} dekadų),
					},
					# Long Unit Identifier
					'duration-hour' => {
						'1' => q(feminine),
						'few' => q({0} valandos),
						'many' => q({0} valandos),
						'one' => q({0} valanda),
						'other' => q({0} valandų),
					},
					# Core Unit Identifier
					'hour' => {
						'1' => q(feminine),
						'few' => q({0} valandos),
						'many' => q({0} valandos),
						'one' => q({0} valanda),
						'other' => q({0} valandų),
					},
					# Long Unit Identifier
					'duration-microsecond' => {
						'1' => q(feminine),
						'few' => q({0} mikrosekundės),
						'many' => q({0} mikrosekundės),
						'name' => q(mikrosekundės),
						'one' => q({0} mikrosekundė),
						'other' => q({0} mikrosekundžių),
					},
					# Core Unit Identifier
					'microsecond' => {
						'1' => q(feminine),
						'few' => q({0} mikrosekundės),
						'many' => q({0} mikrosekundės),
						'name' => q(mikrosekundės),
						'one' => q({0} mikrosekundė),
						'other' => q({0} mikrosekundžių),
					},
					# Long Unit Identifier
					'duration-millisecond' => {
						'1' => q(feminine),
						'few' => q({0} milisekundės),
						'many' => q({0} milisekundės),
						'name' => q(milisekundės),
						'one' => q({0} milisekundė),
						'other' => q({0} milisekundžių),
					},
					# Core Unit Identifier
					'millisecond' => {
						'1' => q(feminine),
						'few' => q({0} milisekundės),
						'many' => q({0} milisekundės),
						'name' => q(milisekundės),
						'one' => q({0} milisekundė),
						'other' => q({0} milisekundžių),
					},
					# Long Unit Identifier
					'duration-minute' => {
						'1' => q(feminine),
						'few' => q({0} minutės),
						'many' => q({0} minutės),
						'name' => q(minutės),
						'one' => q({0} minutė),
						'other' => q({0} minučių),
						'per' => q({0} per minutę),
					},
					# Core Unit Identifier
					'minute' => {
						'1' => q(feminine),
						'few' => q({0} minutės),
						'many' => q({0} minutės),
						'name' => q(minutės),
						'one' => q({0} minutė),
						'other' => q({0} minučių),
						'per' => q({0} per minutę),
					},
					# Long Unit Identifier
					'duration-month' => {
						'1' => q(masculine),
						'few' => q({0} mėnesiai),
						'many' => q({0} mėnesio),
						'one' => q({0} mėnuo),
						'other' => q({0} mėnesių),
						'per' => q({0} per mėnesį),
					},
					# Core Unit Identifier
					'month' => {
						'1' => q(masculine),
						'few' => q({0} mėnesiai),
						'many' => q({0} mėnesio),
						'one' => q({0} mėnuo),
						'other' => q({0} mėnesių),
						'per' => q({0} per mėnesį),
					},
					# Long Unit Identifier
					'duration-nanosecond' => {
						'1' => q(feminine),
						'few' => q({0} nanosekundės),
						'many' => q({0} nanosekundės),
						'name' => q(nanosekundės),
						'one' => q({0} nanosekundė),
						'other' => q({0} nanosekundžių),
					},
					# Core Unit Identifier
					'nanosecond' => {
						'1' => q(feminine),
						'few' => q({0} nanosekundės),
						'many' => q({0} nanosekundės),
						'name' => q(nanosekundės),
						'one' => q({0} nanosekundė),
						'other' => q({0} nanosekundžių),
					},
					# Long Unit Identifier
					'duration-night' => {
						'1' => q(feminine),
						'few' => q({0} naktys),
						'many' => q({0} nakties),
						'name' => q(naktis),
						'one' => q({0} naktis),
						'other' => q({0} naktų),
						'per' => q({0}/nakt.),
					},
					# Core Unit Identifier
					'night' => {
						'1' => q(feminine),
						'few' => q({0} naktys),
						'many' => q({0} nakties),
						'name' => q(naktis),
						'one' => q({0} naktis),
						'other' => q({0} naktų),
						'per' => q({0}/nakt.),
					},
					# Long Unit Identifier
					'duration-quarter' => {
						'1' => q(masculine),
						'few' => q({0} ketvirčiai),
						'many' => q({0} ketvirčio),
						'name' => q(ketvirtis),
						'one' => q({0} ketvirtis),
						'other' => q({0} ketvirčių),
					},
					# Core Unit Identifier
					'quarter' => {
						'1' => q(masculine),
						'few' => q({0} ketvirčiai),
						'many' => q({0} ketvirčio),
						'name' => q(ketvirtis),
						'one' => q({0} ketvirtis),
						'other' => q({0} ketvirčių),
					},
					# Long Unit Identifier
					'duration-second' => {
						'1' => q(feminine),
						'few' => q({0} sekundės),
						'many' => q({0} sekundės),
						'name' => q(sekundės),
						'one' => q({0} sekundė),
						'other' => q({0} sekundžių),
					},
					# Core Unit Identifier
					'second' => {
						'1' => q(feminine),
						'few' => q({0} sekundės),
						'many' => q({0} sekundės),
						'name' => q(sekundės),
						'one' => q({0} sekundė),
						'other' => q({0} sekundžių),
					},
					# Long Unit Identifier
					'duration-week' => {
						'1' => q(feminine),
						'few' => q({0} savaitės),
						'many' => q({0} savaitės),
						'one' => q({0} savaitė),
						'other' => q({0} savaičių),
						'per' => q({0} per savaitę),
					},
					# Core Unit Identifier
					'week' => {
						'1' => q(feminine),
						'few' => q({0} savaitės),
						'many' => q({0} savaitės),
						'one' => q({0} savaitė),
						'other' => q({0} savaičių),
						'per' => q({0} per savaitę),
					},
					# Long Unit Identifier
					'duration-year' => {
						'1' => q(masculine),
						'few' => q({0} metai),
						'many' => q({0} metų),
						'one' => q({0} metai),
						'other' => q({0} metų),
						'per' => q({0} per metus),
					},
					# Core Unit Identifier
					'year' => {
						'1' => q(masculine),
						'few' => q({0} metai),
						'many' => q({0} metų),
						'one' => q({0} metai),
						'other' => q({0} metų),
						'per' => q({0} per metus),
					},
					# Long Unit Identifier
					'electric-ampere' => {
						'1' => q(masculine),
						'few' => q({0} amperai),
						'many' => q({0} ampero),
						'name' => q(amperai),
						'one' => q({0} amperas),
						'other' => q({0} amperų),
					},
					# Core Unit Identifier
					'ampere' => {
						'1' => q(masculine),
						'few' => q({0} amperai),
						'many' => q({0} ampero),
						'name' => q(amperai),
						'one' => q({0} amperas),
						'other' => q({0} amperų),
					},
					# Long Unit Identifier
					'electric-milliampere' => {
						'1' => q(masculine),
						'few' => q({0} miliamperai),
						'many' => q({0} miliampero),
						'name' => q(miliamperai),
						'one' => q({0} miliamperas),
						'other' => q({0} miliamperų),
					},
					# Core Unit Identifier
					'milliampere' => {
						'1' => q(masculine),
						'few' => q({0} miliamperai),
						'many' => q({0} miliampero),
						'name' => q(miliamperai),
						'one' => q({0} miliamperas),
						'other' => q({0} miliamperų),
					},
					# Long Unit Identifier
					'electric-ohm' => {
						'1' => q(masculine),
						'few' => q({0} omai),
						'many' => q({0} omo),
						'name' => q(omai),
						'one' => q({0} omas),
						'other' => q({0} omų),
					},
					# Core Unit Identifier
					'ohm' => {
						'1' => q(masculine),
						'few' => q({0} omai),
						'many' => q({0} omo),
						'name' => q(omai),
						'one' => q({0} omas),
						'other' => q({0} omų),
					},
					# Long Unit Identifier
					'electric-volt' => {
						'1' => q(masculine),
						'few' => q({0} voltai),
						'many' => q({0} volto),
						'name' => q(voltai),
						'one' => q({0} voltas),
						'other' => q({0} voltų),
					},
					# Core Unit Identifier
					'volt' => {
						'1' => q(masculine),
						'few' => q({0} voltai),
						'many' => q({0} volto),
						'name' => q(voltai),
						'one' => q({0} voltas),
						'other' => q({0} voltų),
					},
					# Long Unit Identifier
					'energy-british-thermal-unit' => {
						'name' => q(britiškieji šilumos vienetai),
					},
					# Core Unit Identifier
					'british-thermal-unit' => {
						'name' => q(britiškieji šilumos vienetai),
					},
					# Long Unit Identifier
					'energy-calorie' => {
						'1' => q(feminine),
						'few' => q({0} kalorijos),
						'many' => q({0} kalorijos),
						'name' => q(kalorijos),
						'one' => q({0} kalorija),
						'other' => q({0} kalorijų),
					},
					# Core Unit Identifier
					'calorie' => {
						'1' => q(feminine),
						'few' => q({0} kalorijos),
						'many' => q({0} kalorijos),
						'name' => q(kalorijos),
						'one' => q({0} kalorija),
						'other' => q({0} kalorijų),
					},
					# Long Unit Identifier
					'energy-electronvolt' => {
						'few' => q({0} elektronvoltai),
						'many' => q({0} elektronvolto),
						'name' => q(elektronvoltai),
						'one' => q({0} elektronvoltas),
						'other' => q({0} elektronvoltų),
					},
					# Core Unit Identifier
					'electronvolt' => {
						'few' => q({0} elektronvoltai),
						'many' => q({0} elektronvolto),
						'name' => q(elektronvoltai),
						'one' => q({0} elektronvoltas),
						'other' => q({0} elektronvoltų),
					},
					# Long Unit Identifier
					'energy-foodcalorie' => {
						'few' => q({0} kalorijos),
						'many' => q({0} kalorijos),
						'name' => q(kalorijos),
						'one' => q({0} kalorija),
						'other' => q({0} kalorijų),
					},
					# Core Unit Identifier
					'foodcalorie' => {
						'few' => q({0} kalorijos),
						'many' => q({0} kalorijos),
						'name' => q(kalorijos),
						'one' => q({0} kalorija),
						'other' => q({0} kalorijų),
					},
					# Long Unit Identifier
					'energy-joule' => {
						'1' => q(masculine),
						'few' => q({0} džauliai),
						'many' => q({0} džaulio),
						'name' => q(džauliai),
						'one' => q({0} džaulis),
						'other' => q({0} džaulių),
					},
					# Core Unit Identifier
					'joule' => {
						'1' => q(masculine),
						'few' => q({0} džauliai),
						'many' => q({0} džaulio),
						'name' => q(džauliai),
						'one' => q({0} džaulis),
						'other' => q({0} džaulių),
					},
					# Long Unit Identifier
					'energy-kilocalorie' => {
						'1' => q(feminine),
						'few' => q({0} kilokalorijos),
						'many' => q({0} kilokalorijos),
						'name' => q(kilokalorijos),
						'one' => q({0} kilokalorija),
						'other' => q({0} kilokalorijų),
					},
					# Core Unit Identifier
					'kilocalorie' => {
						'1' => q(feminine),
						'few' => q({0} kilokalorijos),
						'many' => q({0} kilokalorijos),
						'name' => q(kilokalorijos),
						'one' => q({0} kilokalorija),
						'other' => q({0} kilokalorijų),
					},
					# Long Unit Identifier
					'energy-kilojoule' => {
						'1' => q(masculine),
						'few' => q({0} kilodžauliai),
						'many' => q({0} kilodžaulio),
						'name' => q(kilodžauliai),
						'one' => q({0} kilodžaulis),
						'other' => q({0} kilodžaulių),
					},
					# Core Unit Identifier
					'kilojoule' => {
						'1' => q(masculine),
						'few' => q({0} kilodžauliai),
						'many' => q({0} kilodžaulio),
						'name' => q(kilodžauliai),
						'one' => q({0} kilodžaulis),
						'other' => q({0} kilodžaulių),
					},
					# Long Unit Identifier
					'energy-kilowatt-hour' => {
						'1' => q(feminine),
						'few' => q({0} kilovatvalandės),
						'many' => q({0} kilovatvalandės),
						'name' => q(kilovatvalandės),
						'one' => q({0} kilovatvalandė),
						'other' => q({0} kilovatvalandžių),
					},
					# Core Unit Identifier
					'kilowatt-hour' => {
						'1' => q(feminine),
						'few' => q({0} kilovatvalandės),
						'many' => q({0} kilovatvalandės),
						'name' => q(kilovatvalandės),
						'one' => q({0} kilovatvalandė),
						'other' => q({0} kilovatvalandžių),
					},
					# Long Unit Identifier
					'energy-therm-us' => {
						'name' => q(JAV termos),
					},
					# Core Unit Identifier
					'therm-us' => {
						'name' => q(JAV termos),
					},
					# Long Unit Identifier
					'force-kilowatt-hour-per-100-kilometer' => {
						'1' => q(feminine),
						'few' => q({0} kilovatvalandės šimtui kilometrų),
						'many' => q({0} kilovatvalandės šimtui kilometrų),
						'name' => q(kilovatvalandės šimtui kilometrų),
						'one' => q({0} kilovatvalandė šimtui kilometrų),
						'other' => q({0} kilovatvalandžių šimtui kilometrų),
					},
					# Core Unit Identifier
					'kilowatt-hour-per-100-kilometer' => {
						'1' => q(feminine),
						'few' => q({0} kilovatvalandės šimtui kilometrų),
						'many' => q({0} kilovatvalandės šimtui kilometrų),
						'name' => q(kilovatvalandės šimtui kilometrų),
						'one' => q({0} kilovatvalandė šimtui kilometrų),
						'other' => q({0} kilovatvalandžių šimtui kilometrų),
					},
					# Long Unit Identifier
					'force-newton' => {
						'1' => q(masculine),
						'few' => q({0} niutonai),
						'many' => q({0} niutono),
						'name' => q(niutonai),
						'one' => q({0} niutonas),
						'other' => q({0} niutonų),
					},
					# Core Unit Identifier
					'newton' => {
						'1' => q(masculine),
						'few' => q({0} niutonai),
						'many' => q({0} niutono),
						'name' => q(niutonai),
						'one' => q({0} niutonas),
						'other' => q({0} niutonų),
					},
					# Long Unit Identifier
					'force-pound-force' => {
						'few' => q({0} jėgos svarai),
						'many' => q({0} jėgos svaro),
						'name' => q(jėgos svarai),
						'one' => q({0} jėgos svaras),
						'other' => q({0} jėgos svarų),
					},
					# Core Unit Identifier
					'pound-force' => {
						'few' => q({0} jėgos svarai),
						'many' => q({0} jėgos svaro),
						'name' => q(jėgos svarai),
						'one' => q({0} jėgos svaras),
						'other' => q({0} jėgos svarų),
					},
					# Long Unit Identifier
					'frequency-gigahertz' => {
						'1' => q(masculine),
						'few' => q({0} gigahercai),
						'many' => q({0} gigaherco),
						'name' => q(gigahercai),
						'one' => q({0} gigahercas),
						'other' => q({0} gigahercų),
					},
					# Core Unit Identifier
					'gigahertz' => {
						'1' => q(masculine),
						'few' => q({0} gigahercai),
						'many' => q({0} gigaherco),
						'name' => q(gigahercai),
						'one' => q({0} gigahercas),
						'other' => q({0} gigahercų),
					},
					# Long Unit Identifier
					'frequency-hertz' => {
						'1' => q(masculine),
						'few' => q({0} hercai),
						'many' => q({0} herco),
						'name' => q(hercai),
						'one' => q({0} hercas),
						'other' => q({0} hercų),
					},
					# Core Unit Identifier
					'hertz' => {
						'1' => q(masculine),
						'few' => q({0} hercai),
						'many' => q({0} herco),
						'name' => q(hercai),
						'one' => q({0} hercas),
						'other' => q({0} hercų),
					},
					# Long Unit Identifier
					'frequency-kilohertz' => {
						'1' => q(masculine),
						'few' => q({0} kilohercai),
						'many' => q({0} kiloherco),
						'name' => q(kilohercai),
						'one' => q({0} kilohercas),
						'other' => q({0} kilohercų),
					},
					# Core Unit Identifier
					'kilohertz' => {
						'1' => q(masculine),
						'few' => q({0} kilohercai),
						'many' => q({0} kiloherco),
						'name' => q(kilohercai),
						'one' => q({0} kilohercas),
						'other' => q({0} kilohercų),
					},
					# Long Unit Identifier
					'frequency-megahertz' => {
						'1' => q(masculine),
						'few' => q({0} megahercai),
						'many' => q({0} megaherco),
						'name' => q(megahercai),
						'one' => q({0} megahercas),
						'other' => q({0} megahercų),
					},
					# Core Unit Identifier
					'megahertz' => {
						'1' => q(masculine),
						'few' => q({0} megahercai),
						'many' => q({0} megaherco),
						'name' => q(megahercai),
						'one' => q({0} megahercas),
						'other' => q({0} megahercų),
					},
					# Long Unit Identifier
					'graphics-dot' => {
						'few' => q({0} taškai),
						'many' => q({0} taško),
						'name' => q(taškas),
						'one' => q({0} taškas),
						'other' => q({0} taškų),
					},
					# Core Unit Identifier
					'dot' => {
						'few' => q({0} taškai),
						'many' => q({0} taško),
						'name' => q(taškas),
						'one' => q({0} taškas),
						'other' => q({0} taškų),
					},
					# Long Unit Identifier
					'graphics-dot-per-centimeter' => {
						'few' => q({0} taškai centimetre),
						'many' => q({0} taško centimetre),
						'one' => q({0} taškas centimetre),
						'other' => q({0} taškų centimetre),
					},
					# Core Unit Identifier
					'dot-per-centimeter' => {
						'few' => q({0} taškai centimetre),
						'many' => q({0} taško centimetre),
						'one' => q({0} taškas centimetre),
						'other' => q({0} taškų centimetre),
					},
					# Long Unit Identifier
					'graphics-dot-per-inch' => {
						'few' => q({0} taškai colyje),
						'many' => q({0} taško colyje),
						'one' => q({0} taškas colyje),
						'other' => q({0} taškų colyje),
					},
					# Core Unit Identifier
					'dot-per-inch' => {
						'few' => q({0} taškai colyje),
						'many' => q({0} taško colyje),
						'one' => q({0} taškas colyje),
						'other' => q({0} taškų colyje),
					},
					# Long Unit Identifier
					'graphics-em' => {
						'1' => q(masculine),
						'few' => q({0} tipografiniai emai),
						'many' => q({0} tipografinio emo),
						'one' => q({0} tipografinis emas),
						'other' => q({0} tipografinių emų),
					},
					# Core Unit Identifier
					'em' => {
						'1' => q(masculine),
						'few' => q({0} tipografiniai emai),
						'many' => q({0} tipografinio emo),
						'one' => q({0} tipografinis emas),
						'other' => q({0} tipografinių emų),
					},
					# Long Unit Identifier
					'graphics-megapixel' => {
						'1' => q(masculine),
						'few' => q({0} megapikseliai),
						'many' => q({0} megapikselio),
						'one' => q({0} megapikselis),
						'other' => q({0} megapikselių),
					},
					# Core Unit Identifier
					'megapixel' => {
						'1' => q(masculine),
						'few' => q({0} megapikseliai),
						'many' => q({0} megapikselio),
						'one' => q({0} megapikselis),
						'other' => q({0} megapikselių),
					},
					# Long Unit Identifier
					'graphics-pixel' => {
						'1' => q(masculine),
						'few' => q({0} pikseliai),
						'many' => q({0} pikselio),
						'one' => q({0} pikselis),
						'other' => q({0} pikselių),
					},
					# Core Unit Identifier
					'pixel' => {
						'1' => q(masculine),
						'few' => q({0} pikseliai),
						'many' => q({0} pikselio),
						'one' => q({0} pikselis),
						'other' => q({0} pikselių),
					},
					# Long Unit Identifier
					'graphics-pixel-per-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} pikseliai centimetre),
						'many' => q({0} pikselio centimetre),
						'one' => q({0} pikselis centimetre),
						'other' => q({0} pikselių centimetre),
					},
					# Core Unit Identifier
					'pixel-per-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} pikseliai centimetre),
						'many' => q({0} pikselio centimetre),
						'one' => q({0} pikselis centimetre),
						'other' => q({0} pikselių centimetre),
					},
					# Long Unit Identifier
					'graphics-pixel-per-inch' => {
						'few' => q({0} pikseliai colyje),
						'many' => q({0} pikselio colyje),
						'one' => q({0} pikselis colyje),
						'other' => q({0} pikselių colyje),
					},
					# Core Unit Identifier
					'pixel-per-inch' => {
						'few' => q({0} pikseliai colyje),
						'many' => q({0} pikselio colyje),
						'one' => q({0} pikselis colyje),
						'other' => q({0} pikselių colyje),
					},
					# Long Unit Identifier
					'length-astronomical-unit' => {
						'few' => q({0} astronominiai vienetai),
						'many' => q({0} astronominio vieneto),
						'name' => q(astronominiai vienetai),
						'one' => q({0} astronominis vienetas),
						'other' => q({0} astronominių vienetų),
					},
					# Core Unit Identifier
					'astronomical-unit' => {
						'few' => q({0} astronominiai vienetai),
						'many' => q({0} astronominio vieneto),
						'name' => q(astronominiai vienetai),
						'one' => q({0} astronominis vienetas),
						'other' => q({0} astronominių vienetų),
					},
					# Long Unit Identifier
					'length-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} centimetrai),
						'many' => q({0} centimetro),
						'name' => q(centimetrai),
						'one' => q({0} centimetras),
						'other' => q({0} centimetrų),
					},
					# Core Unit Identifier
					'centimeter' => {
						'1' => q(masculine),
						'few' => q({0} centimetrai),
						'many' => q({0} centimetro),
						'name' => q(centimetrai),
						'one' => q({0} centimetras),
						'other' => q({0} centimetrų),
					},
					# Long Unit Identifier
					'length-decimeter' => {
						'1' => q(masculine),
						'few' => q({0} decimetrai),
						'many' => q({0} decimetro),
						'name' => q(decimetrai),
						'one' => q({0} decimetras),
						'other' => q({0} decimetrų),
					},
					# Core Unit Identifier
					'decimeter' => {
						'1' => q(masculine),
						'few' => q({0} decimetrai),
						'many' => q({0} decimetro),
						'name' => q(decimetrai),
						'one' => q({0} decimetras),
						'other' => q({0} decimetrų),
					},
					# Long Unit Identifier
					'length-earth-radius' => {
						'few' => q({0} R⊕),
						'many' => q({0} R⊕),
						'name' => q(žemės spindulys),
						'one' => q({0} žemės spindulys),
						'other' => q({0} žemės spindulių),
					},
					# Core Unit Identifier
					'earth-radius' => {
						'few' => q({0} R⊕),
						'many' => q({0} R⊕),
						'name' => q(žemės spindulys),
						'one' => q({0} žemės spindulys),
						'other' => q({0} žemės spindulių),
					},
					# Long Unit Identifier
					'length-fathom' => {
						'few' => q({0} fadomai),
						'many' => q({0} fadomo),
						'name' => q(fadomai),
						'one' => q({0} fadomas),
						'other' => q({0} fth),
					},
					# Core Unit Identifier
					'fathom' => {
						'few' => q({0} fadomai),
						'many' => q({0} fadomo),
						'name' => q(fadomai),
						'one' => q({0} fadomas),
						'other' => q({0} fth),
					},
					# Long Unit Identifier
					'length-foot' => {
						'few' => q({0} pėdos),
						'many' => q({0} pėdos),
						'name' => q(pėdos),
						'one' => q({0} pėda),
						'other' => q({0} pėdų),
					},
					# Core Unit Identifier
					'foot' => {
						'few' => q({0} pėdos),
						'many' => q({0} pėdos),
						'name' => q(pėdos),
						'one' => q({0} pėda),
						'other' => q({0} pėdų),
					},
					# Long Unit Identifier
					'length-furlong' => {
						'few' => q({0} furlongai),
						'many' => q({0} furlongo),
						'name' => q(furlongai),
						'one' => q({0} furlongas),
						'other' => q({0} furlongų),
					},
					# Core Unit Identifier
					'furlong' => {
						'few' => q({0} furlongai),
						'many' => q({0} furlongo),
						'name' => q(furlongai),
						'one' => q({0} furlongas),
						'other' => q({0} furlongų),
					},
					# Long Unit Identifier
					'length-inch' => {
						'few' => q({0} coliai),
						'many' => q({0} colio),
						'one' => q({0} colis),
						'other' => q({0} colių),
					},
					# Core Unit Identifier
					'inch' => {
						'few' => q({0} coliai),
						'many' => q({0} colio),
						'one' => q({0} colis),
						'other' => q({0} colių),
					},
					# Long Unit Identifier
					'length-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} kilometrai),
						'many' => q({0} kilometro),
						'name' => q(kilometrai),
						'one' => q({0} kilometras),
						'other' => q({0} kilometrų),
					},
					# Core Unit Identifier
					'kilometer' => {
						'1' => q(masculine),
						'few' => q({0} kilometrai),
						'many' => q({0} kilometro),
						'name' => q(kilometrai),
						'one' => q({0} kilometras),
						'other' => q({0} kilometrų),
					},
					# Long Unit Identifier
					'length-light-year' => {
						'few' => q({0} šviesmečiai),
						'many' => q({0} šviesmečio),
						'one' => q({0} šviesmetis),
						'other' => q({0} šviesmečių),
					},
					# Core Unit Identifier
					'light-year' => {
						'few' => q({0} šviesmečiai),
						'many' => q({0} šviesmečio),
						'one' => q({0} šviesmetis),
						'other' => q({0} šviesmečių),
					},
					# Long Unit Identifier
					'length-meter' => {
						'1' => q(masculine),
						'few' => q({0} metrai),
						'many' => q({0} metro),
						'name' => q(metrai),
						'one' => q({0} metras),
						'other' => q({0} metrų),
					},
					# Core Unit Identifier
					'meter' => {
						'1' => q(masculine),
						'few' => q({0} metrai),
						'many' => q({0} metro),
						'name' => q(metrai),
						'one' => q({0} metras),
						'other' => q({0} metrų),
					},
					# Long Unit Identifier
					'length-micrometer' => {
						'1' => q(masculine),
						'few' => q({0} mikrometrai),
						'many' => q({0} mikrometro),
						'name' => q(mikrometrai),
						'one' => q({0} mikrometras),
						'other' => q({0} mikrometrų),
					},
					# Core Unit Identifier
					'micrometer' => {
						'1' => q(masculine),
						'few' => q({0} mikrometrai),
						'many' => q({0} mikrometro),
						'name' => q(mikrometrai),
						'one' => q({0} mikrometras),
						'other' => q({0} mikrometrų),
					},
					# Long Unit Identifier
					'length-mile' => {
						'few' => q({0} mylios),
						'many' => q({0} mylios),
						'name' => q(mylios),
						'one' => q({0} mylia),
						'other' => q({0} mylių),
					},
					# Core Unit Identifier
					'mile' => {
						'few' => q({0} mylios),
						'many' => q({0} mylios),
						'name' => q(mylios),
						'one' => q({0} mylia),
						'other' => q({0} mylių),
					},
					# Long Unit Identifier
					'length-mile-scandinavian' => {
						'1' => q(feminine),
						'few' => q({0} ilgosios mylios),
						'many' => q({0} ilgosios mylios),
						'name' => q(ilgoji mylia),
						'one' => q({0} ilgoji mylia),
						'other' => q({0} ilgųjų mylių),
					},
					# Core Unit Identifier
					'mile-scandinavian' => {
						'1' => q(feminine),
						'few' => q({0} ilgosios mylios),
						'many' => q({0} ilgosios mylios),
						'name' => q(ilgoji mylia),
						'one' => q({0} ilgoji mylia),
						'other' => q({0} ilgųjų mylių),
					},
					# Long Unit Identifier
					'length-millimeter' => {
						'1' => q(masculine),
						'few' => q({0} milimetrai),
						'many' => q({0} milimetro),
						'name' => q(milimetrai),
						'one' => q({0} milimetras),
						'other' => q({0} milimetrų),
					},
					# Core Unit Identifier
					'millimeter' => {
						'1' => q(masculine),
						'few' => q({0} milimetrai),
						'many' => q({0} milimetro),
						'name' => q(milimetrai),
						'one' => q({0} milimetras),
						'other' => q({0} milimetrų),
					},
					# Long Unit Identifier
					'length-nanometer' => {
						'1' => q(masculine),
						'few' => q({0} nanometrai),
						'many' => q({0} nanometro),
						'name' => q(nanometrai),
						'one' => q({0} nanometras),
						'other' => q({0} nanometrų),
					},
					# Core Unit Identifier
					'nanometer' => {
						'1' => q(masculine),
						'few' => q({0} nanometrai),
						'many' => q({0} nanometro),
						'name' => q(nanometrai),
						'one' => q({0} nanometras),
						'other' => q({0} nanometrų),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'few' => q({0} jūrmylės),
						'many' => q({0} jūrmylės),
						'name' => q(jūrmylės),
						'one' => q({0} jūrmylė),
						'other' => q({0} jūrmylių),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'few' => q({0} jūrmylės),
						'many' => q({0} jūrmylės),
						'name' => q(jūrmylės),
						'one' => q({0} jūrmylė),
						'other' => q({0} jūrmylių),
					},
					# Long Unit Identifier
					'length-parsec' => {
						'few' => q({0} parsekai),
						'many' => q({0} parseko),
						'name' => q(parsekas),
						'one' => q({0} parsekas),
						'other' => q({0} parsekų),
					},
					# Core Unit Identifier
					'parsec' => {
						'few' => q({0} parsekai),
						'many' => q({0} parseko),
						'name' => q(parsekas),
						'one' => q({0} parsekas),
						'other' => q({0} parsekų),
					},
					# Long Unit Identifier
					'length-picometer' => {
						'1' => q(masculine),
						'few' => q({0} pikometrai),
						'many' => q({0} pikometro),
						'name' => q(pikometrai),
						'one' => q({0} pikometras),
						'other' => q({0} pikometrų),
					},
					# Core Unit Identifier
					'picometer' => {
						'1' => q(masculine),
						'few' => q({0} pikometrai),
						'many' => q({0} pikometro),
						'name' => q(pikometrai),
						'one' => q({0} pikometras),
						'other' => q({0} pikometrų),
					},
					# Long Unit Identifier
					'length-point' => {
						'1' => q(masculine),
						'few' => q({0} punktai),
						'many' => q({0} punkto),
						'name' => q(punktai),
						'one' => q({0} punktas),
						'other' => q({0} punktų),
					},
					# Core Unit Identifier
					'point' => {
						'1' => q(masculine),
						'few' => q({0} punktai),
						'many' => q({0} punkto),
						'name' => q(punktai),
						'one' => q({0} punktas),
						'other' => q({0} punktų),
					},
					# Long Unit Identifier
					'length-solar-radius' => {
						'name' => q(saulės spinduliuotė),
					},
					# Core Unit Identifier
					'solar-radius' => {
						'name' => q(saulės spinduliuotė),
					},
					# Long Unit Identifier
					'length-yard' => {
						'few' => q({0} jardai),
						'many' => q({0} jardo),
						'name' => q(jardai),
						'one' => q({0} jardas),
						'other' => q({0} jardų),
					},
					# Core Unit Identifier
					'yard' => {
						'few' => q({0} jardai),
						'many' => q({0} jardo),
						'name' => q(jardai),
						'one' => q({0} jardas),
						'other' => q({0} jardų),
					},
					# Long Unit Identifier
					'light-candela' => {
						'1' => q(feminine),
						'few' => q({0} cd),
						'many' => q({0} cd),
						'name' => q(kandela),
						'one' => q({0} kandela),
						'other' => q({0} kandelų),
					},
					# Core Unit Identifier
					'candela' => {
						'1' => q(feminine),
						'few' => q({0} cd),
						'many' => q({0} cd),
						'name' => q(kandela),
						'one' => q({0} kandela),
						'other' => q({0} kandelų),
					},
					# Long Unit Identifier
					'light-lumen' => {
						'1' => q(masculine),
						'few' => q({0} lm),
						'many' => q({0} lm),
						'name' => q(liumenas),
						'one' => q({0} liumenas),
						'other' => q({0} liumenų),
					},
					# Core Unit Identifier
					'lumen' => {
						'1' => q(masculine),
						'few' => q({0} lm),
						'many' => q({0} lm),
						'name' => q(liumenas),
						'one' => q({0} liumenas),
						'other' => q({0} liumenų),
					},
					# Long Unit Identifier
					'light-lux' => {
						'1' => q(masculine),
						'few' => q({0} liuksai),
						'many' => q({0} liukso),
						'name' => q(liuksai),
						'one' => q({0} liuksas),
						'other' => q({0} liuksų),
					},
					# Core Unit Identifier
					'lux' => {
						'1' => q(masculine),
						'few' => q({0} liuksai),
						'many' => q({0} liukso),
						'name' => q(liuksai),
						'one' => q({0} liuksas),
						'other' => q({0} liuksų),
					},
					# Long Unit Identifier
					'light-solar-luminosity' => {
						'name' => q(saulės šviesis),
					},
					# Core Unit Identifier
					'solar-luminosity' => {
						'name' => q(saulės šviesis),
					},
					# Long Unit Identifier
					'mass-carat' => {
						'1' => q(masculine),
						'few' => q({0} karatai),
						'many' => q({0} karato),
						'name' => q(karatai),
						'one' => q({0} karatas),
						'other' => q({0} karatų),
					},
					# Core Unit Identifier
					'carat' => {
						'1' => q(masculine),
						'few' => q({0} karatai),
						'many' => q({0} karato),
						'name' => q(karatai),
						'one' => q({0} karatas),
						'other' => q({0} karatų),
					},
					# Long Unit Identifier
					'mass-dalton' => {
						'few' => q({0} daltonai),
						'many' => q({0} daltono),
						'name' => q(daltonai),
						'one' => q({0} daltonas),
						'other' => q({0} daltonų),
					},
					# Core Unit Identifier
					'dalton' => {
						'few' => q({0} daltonai),
						'many' => q({0} daltono),
						'name' => q(daltonai),
						'one' => q({0} daltonas),
						'other' => q({0} daltonų),
					},
					# Long Unit Identifier
					'mass-earth-mass' => {
						'name' => q(žemės masė),
					},
					# Core Unit Identifier
					'earth-mass' => {
						'name' => q(žemės masė),
					},
					# Long Unit Identifier
					'mass-gram' => {
						'1' => q(masculine),
						'few' => q({0} gramai),
						'many' => q({0} gramo),
						'name' => q(gramai),
						'one' => q({0} gramas),
						'other' => q({0} gramų),
					},
					# Core Unit Identifier
					'gram' => {
						'1' => q(masculine),
						'few' => q({0} gramai),
						'many' => q({0} gramo),
						'name' => q(gramai),
						'one' => q({0} gramas),
						'other' => q({0} gramų),
					},
					# Long Unit Identifier
					'mass-kilogram' => {
						'1' => q(masculine),
						'few' => q({0} kilogramai),
						'many' => q({0} kilogramo),
						'name' => q(kilogramai),
						'one' => q({0} kilogramas),
						'other' => q({0} kilogramų),
					},
					# Core Unit Identifier
					'kilogram' => {
						'1' => q(masculine),
						'few' => q({0} kilogramai),
						'many' => q({0} kilogramo),
						'name' => q(kilogramai),
						'one' => q({0} kilogramas),
						'other' => q({0} kilogramų),
					},
					# Long Unit Identifier
					'mass-microgram' => {
						'1' => q(masculine),
						'few' => q({0} mikrogramai),
						'many' => q({0} mikrogramo),
						'name' => q(mikrogramai),
						'one' => q({0} mikrogramas),
						'other' => q({0} mikrogramų),
					},
					# Core Unit Identifier
					'microgram' => {
						'1' => q(masculine),
						'few' => q({0} mikrogramai),
						'many' => q({0} mikrogramo),
						'name' => q(mikrogramai),
						'one' => q({0} mikrogramas),
						'other' => q({0} mikrogramų),
					},
					# Long Unit Identifier
					'mass-milligram' => {
						'1' => q(masculine),
						'few' => q({0} miligramai),
						'many' => q({0} miligramo),
						'name' => q(miligramai),
						'one' => q({0} miligramas),
						'other' => q({0} miligramų),
					},
					# Core Unit Identifier
					'milligram' => {
						'1' => q(masculine),
						'few' => q({0} miligramai),
						'many' => q({0} miligramo),
						'name' => q(miligramai),
						'one' => q({0} miligramas),
						'other' => q({0} miligramų),
					},
					# Long Unit Identifier
					'mass-ounce' => {
						'few' => q({0} uncijos),
						'many' => q({0} uncijos),
						'name' => q(uncijos),
						'one' => q({0} uncija),
						'other' => q({0} uncijų),
					},
					# Core Unit Identifier
					'ounce' => {
						'few' => q({0} uncijos),
						'many' => q({0} uncijos),
						'name' => q(uncijos),
						'one' => q({0} uncija),
						'other' => q({0} uncijų),
					},
					# Long Unit Identifier
					'mass-ounce-troy' => {
						'few' => q({0} Trojos uncijos),
						'many' => q({0} Trojos uncijos),
						'name' => q(Trojos uncijos),
						'one' => q({0} Trojos uncija),
						'other' => q({0} Trojos uncijų),
					},
					# Core Unit Identifier
					'ounce-troy' => {
						'few' => q({0} Trojos uncijos),
						'many' => q({0} Trojos uncijos),
						'name' => q(Trojos uncijos),
						'one' => q({0} Trojos uncija),
						'other' => q({0} Trojos uncijų),
					},
					# Long Unit Identifier
					'mass-pound' => {
						'few' => q({0} svarai),
						'many' => q({0} svaro),
						'name' => q(svarai),
						'one' => q({0} svaras),
						'other' => q({0} svarų),
					},
					# Core Unit Identifier
					'pound' => {
						'few' => q({0} svarai),
						'many' => q({0} svaro),
						'name' => q(svarai),
						'one' => q({0} svaras),
						'other' => q({0} svarų),
					},
					# Long Unit Identifier
					'mass-solar-mass' => {
						'name' => q(saulės masė),
					},
					# Core Unit Identifier
					'solar-mass' => {
						'name' => q(saulės masė),
					},
					# Long Unit Identifier
					'mass-stone' => {
						'few' => q({0} stonai),
						'many' => q({0} stono),
						'name' => q(stonai),
						'one' => q({0} stonas),
						'other' => q({0} stonų),
					},
					# Core Unit Identifier
					'stone' => {
						'few' => q({0} stonai),
						'many' => q({0} stono),
						'name' => q(stonai),
						'one' => q({0} stonas),
						'other' => q({0} stonų),
					},
					# Long Unit Identifier
					'mass-ton' => {
						'few' => q({0} tonos),
						'many' => q({0} tonos),
						'name' => q(tonos),
						'one' => q({0} tona),
						'other' => q({0} tonų),
					},
					# Core Unit Identifier
					'ton' => {
						'few' => q({0} tonos),
						'many' => q({0} tonos),
						'name' => q(tonos),
						'one' => q({0} tona),
						'other' => q({0} tonų),
					},
					# Long Unit Identifier
					'mass-tonne' => {
						'1' => q(feminine),
						'few' => q({0} metrinės tonos),
						'many' => q({0} metrinės tonos),
						'name' => q(metrinės tonos),
						'one' => q({0} metrinė tona),
						'other' => q({0} metrinių tonų),
					},
					# Core Unit Identifier
					'tonne' => {
						'1' => q(feminine),
						'few' => q({0} metrinės tonos),
						'many' => q({0} metrinės tonos),
						'name' => q(metrinės tonos),
						'one' => q({0} metrinė tona),
						'other' => q({0} metrinių tonų),
					},
					# Long Unit Identifier
					'power-gigawatt' => {
						'1' => q(masculine),
						'few' => q({0} gigavatai),
						'many' => q({0} gigavato),
						'name' => q(gigavatai),
						'one' => q({0} gigavatas),
						'other' => q({0} gigavatų),
					},
					# Core Unit Identifier
					'gigawatt' => {
						'1' => q(masculine),
						'few' => q({0} gigavatai),
						'many' => q({0} gigavato),
						'name' => q(gigavatai),
						'one' => q({0} gigavatas),
						'other' => q({0} gigavatų),
					},
					# Long Unit Identifier
					'power-horsepower' => {
						'few' => q({0} arklio galios),
						'many' => q({0} arklio galios),
						'name' => q(arklio galios),
						'one' => q({0} arklio galia),
						'other' => q({0} arklio galių),
					},
					# Core Unit Identifier
					'horsepower' => {
						'few' => q({0} arklio galios),
						'many' => q({0} arklio galios),
						'name' => q(arklio galios),
						'one' => q({0} arklio galia),
						'other' => q({0} arklio galių),
					},
					# Long Unit Identifier
					'power-kilowatt' => {
						'1' => q(masculine),
						'few' => q({0} kilovatai),
						'many' => q({0} kilovato),
						'name' => q(kilovatai),
						'one' => q({0} kilovatas),
						'other' => q({0} kilovatų),
					},
					# Core Unit Identifier
					'kilowatt' => {
						'1' => q(masculine),
						'few' => q({0} kilovatai),
						'many' => q({0} kilovato),
						'name' => q(kilovatai),
						'one' => q({0} kilovatas),
						'other' => q({0} kilovatų),
					},
					# Long Unit Identifier
					'power-megawatt' => {
						'1' => q(masculine),
						'few' => q({0} megavatai),
						'many' => q({0} megavato),
						'name' => q(megavatai),
						'one' => q({0} megavatas),
						'other' => q({0} megavatų),
					},
					# Core Unit Identifier
					'megawatt' => {
						'1' => q(masculine),
						'few' => q({0} megavatai),
						'many' => q({0} megavato),
						'name' => q(megavatai),
						'one' => q({0} megavatas),
						'other' => q({0} megavatų),
					},
					# Long Unit Identifier
					'power-milliwatt' => {
						'1' => q(masculine),
						'few' => q({0} milivatai),
						'many' => q({0} milivato),
						'name' => q(milivatai),
						'one' => q({0} milivatas),
						'other' => q({0} milivatų),
					},
					# Core Unit Identifier
					'milliwatt' => {
						'1' => q(masculine),
						'few' => q({0} milivatai),
						'many' => q({0} milivato),
						'name' => q(milivatai),
						'one' => q({0} milivatas),
						'other' => q({0} milivatų),
					},
					# Long Unit Identifier
					'power-watt' => {
						'1' => q(masculine),
						'few' => q({0} vatai),
						'many' => q({0} vato),
						'name' => q(vatai),
						'one' => q({0} vatas),
						'other' => q({0} vatų),
					},
					# Core Unit Identifier
					'watt' => {
						'1' => q(masculine),
						'few' => q({0} vatai),
						'many' => q({0} vato),
						'name' => q(vatai),
						'one' => q({0} vatas),
						'other' => q({0} vatų),
					},
					# Long Unit Identifier
					'power2' => {
						'few' => q({0} kvadratu),
						'many' => q({0} kvadratu),
						'one' => q({0} kvadratu),
						'other' => q({0} kvadratu),
					},
					# Core Unit Identifier
					'power2' => {
						'few' => q({0} kvadratu),
						'many' => q({0} kvadratu),
						'one' => q({0} kvadratu),
						'other' => q({0} kvadratu),
					},
					# Long Unit Identifier
					'power3' => {
						'few' => q({0} kubu),
						'many' => q({0} kubu),
						'one' => q({0} kubu),
						'other' => q({0} kubu),
					},
					# Core Unit Identifier
					'power3' => {
						'few' => q({0} kubu),
						'many' => q({0} kubu),
						'one' => q({0} kubu),
						'other' => q({0} kubu),
					},
					# Long Unit Identifier
					'pressure-atmosphere' => {
						'1' => q(feminine),
						'few' => q({0} atmosferos),
						'many' => q({0} atmosferos),
						'name' => q(atmosferos),
						'one' => q({0} atmosfera),
						'other' => q({0} atmosferų),
					},
					# Core Unit Identifier
					'atmosphere' => {
						'1' => q(feminine),
						'few' => q({0} atmosferos),
						'many' => q({0} atmosferos),
						'name' => q(atmosferos),
						'one' => q({0} atmosfera),
						'other' => q({0} atmosferų),
					},
					# Long Unit Identifier
					'pressure-bar' => {
						'1' => q(masculine),
						'few' => q({0} barai),
						'many' => q({0} baro),
						'one' => q({0} baras),
						'other' => q({0} barų),
					},
					# Core Unit Identifier
					'bar' => {
						'1' => q(masculine),
						'few' => q({0} barai),
						'many' => q({0} baro),
						'one' => q({0} baras),
						'other' => q({0} barų),
					},
					# Long Unit Identifier
					'pressure-hectopascal' => {
						'1' => q(masculine),
						'few' => q({0} hektopaskaliai),
						'many' => q({0} hektopaskalio),
						'name' => q(hektopaskaliai),
						'one' => q({0} hektopaskalis),
						'other' => q({0} hektopaskalių),
					},
					# Core Unit Identifier
					'hectopascal' => {
						'1' => q(masculine),
						'few' => q({0} hektopaskaliai),
						'many' => q({0} hektopaskalio),
						'name' => q(hektopaskaliai),
						'one' => q({0} hektopaskalis),
						'other' => q({0} hektopaskalių),
					},
					# Long Unit Identifier
					'pressure-inch-ofhg' => {
						'few' => q({0} gyvsidabrio stulpelio coliai),
						'many' => q({0} gyvsidabrio stulpelio colio),
						'name' => q(gyvsidabrio stulpelio coliai),
						'one' => q({0} gyvsidabrio stulpelio colis),
						'other' => q({0} gyvsidabrio stulpelio colių),
					},
					# Core Unit Identifier
					'inch-ofhg' => {
						'few' => q({0} gyvsidabrio stulpelio coliai),
						'many' => q({0} gyvsidabrio stulpelio colio),
						'name' => q(gyvsidabrio stulpelio coliai),
						'one' => q({0} gyvsidabrio stulpelio colis),
						'other' => q({0} gyvsidabrio stulpelio colių),
					},
					# Long Unit Identifier
					'pressure-kilopascal' => {
						'1' => q(masculine),
						'few' => q({0} kilopaskaliai),
						'many' => q({0} kilopaskalio),
						'name' => q(kilopaskaliai),
						'one' => q({0} kilopaskalis),
						'other' => q({0} kilopaskalių),
					},
					# Core Unit Identifier
					'kilopascal' => {
						'1' => q(masculine),
						'few' => q({0} kilopaskaliai),
						'many' => q({0} kilopaskalio),
						'name' => q(kilopaskaliai),
						'one' => q({0} kilopaskalis),
						'other' => q({0} kilopaskalių),
					},
					# Long Unit Identifier
					'pressure-megapascal' => {
						'1' => q(masculine),
						'few' => q({0} megapaskaliai),
						'many' => q({0} megapaskalio),
						'name' => q(megapaskaliai),
						'one' => q({0} megapaskalis),
						'other' => q({0} megapaskalių),
					},
					# Core Unit Identifier
					'megapascal' => {
						'1' => q(masculine),
						'few' => q({0} megapaskaliai),
						'many' => q({0} megapaskalio),
						'name' => q(megapaskaliai),
						'one' => q({0} megapaskalis),
						'other' => q({0} megapaskalių),
					},
					# Long Unit Identifier
					'pressure-millibar' => {
						'1' => q(masculine),
						'few' => q({0} milibarai),
						'many' => q({0} milibaro),
						'name' => q(milibarai),
						'one' => q({0} milibaras),
						'other' => q({0} milibarų),
					},
					# Core Unit Identifier
					'millibar' => {
						'1' => q(masculine),
						'few' => q({0} milibarai),
						'many' => q({0} milibaro),
						'name' => q(milibarai),
						'one' => q({0} milibaras),
						'other' => q({0} milibarų),
					},
					# Long Unit Identifier
					'pressure-millimeter-ofhg' => {
						'1' => q(masculine),
						'few' => q({0} gysidabrio stulpelio milimetrai),
						'many' => q({0} gysidabrio stulpelio milimetro),
						'name' => q(gysidabrio stulpelio milimetrai),
						'one' => q({0} gysidabrio stulpelio milimetras),
						'other' => q({0} gysidabrio stulpelio milimetrų),
					},
					# Core Unit Identifier
					'millimeter-ofhg' => {
						'1' => q(masculine),
						'few' => q({0} gysidabrio stulpelio milimetrai),
						'many' => q({0} gysidabrio stulpelio milimetro),
						'name' => q(gysidabrio stulpelio milimetrai),
						'one' => q({0} gysidabrio stulpelio milimetras),
						'other' => q({0} gysidabrio stulpelio milimetrų),
					},
					# Long Unit Identifier
					'pressure-pascal' => {
						'1' => q(masculine),
						'few' => q({0} paskaliai),
						'many' => q({0} paskalio),
						'one' => q({0} paskalis),
						'other' => q({0} paskalių),
					},
					# Core Unit Identifier
					'pascal' => {
						'1' => q(masculine),
						'few' => q({0} paskaliai),
						'many' => q({0} paskalio),
						'one' => q({0} paskalis),
						'other' => q({0} paskalių),
					},
					# Long Unit Identifier
					'pressure-pound-force-per-square-inch' => {
						'few' => q({0} svarai kv. colyje),
						'many' => q({0} svaro kv. colyje),
						'name' => q(svarai kv. colyje),
						'one' => q({0} svaras kv. colyje),
						'other' => q({0} svarų kv. colyje),
					},
					# Core Unit Identifier
					'pound-force-per-square-inch' => {
						'few' => q({0} svarai kv. colyje),
						'many' => q({0} svaro kv. colyje),
						'name' => q(svarai kv. colyje),
						'one' => q({0} svaras kv. colyje),
						'other' => q({0} svarų kv. colyje),
					},
					# Long Unit Identifier
					'speed-beaufort' => {
						'few' => q(Boforto {0}),
						'many' => q(Boforto {0}),
						'one' => q(Boforto {0}),
						'other' => q(Boforto {0}),
					},
					# Core Unit Identifier
					'beaufort' => {
						'few' => q(Boforto {0}),
						'many' => q(Boforto {0}),
						'one' => q(Boforto {0}),
						'other' => q(Boforto {0}),
					},
					# Long Unit Identifier
					'speed-kilometer-per-hour' => {
						'1' => q(masculine),
						'few' => q({0} kilometrai per valandą),
						'many' => q({0} kilometro per valandą),
						'name' => q(kilometrai per valandą),
						'one' => q({0} kilometras per valandą),
						'other' => q({0} kilometrų per valandą),
					},
					# Core Unit Identifier
					'kilometer-per-hour' => {
						'1' => q(masculine),
						'few' => q({0} kilometrai per valandą),
						'many' => q({0} kilometro per valandą),
						'name' => q(kilometrai per valandą),
						'one' => q({0} kilometras per valandą),
						'other' => q({0} kilometrų per valandą),
					},
					# Long Unit Identifier
					'speed-knot' => {
						'few' => q({0} mazgai),
						'many' => q({0} mazgo),
						'one' => q({0} mazgas),
						'other' => q({0} mazgų),
					},
					# Core Unit Identifier
					'knot' => {
						'few' => q({0} mazgai),
						'many' => q({0} mazgo),
						'one' => q({0} mazgas),
						'other' => q({0} mazgų),
					},
					# Long Unit Identifier
					'speed-meter-per-second' => {
						'1' => q(masculine),
						'few' => q({0} metrai per sekundę),
						'many' => q({0} metro per sekundę),
						'name' => q(metrai per sekundę),
						'one' => q({0} metras per sekundę),
						'other' => q({0} metrų per sekundę),
					},
					# Core Unit Identifier
					'meter-per-second' => {
						'1' => q(masculine),
						'few' => q({0} metrai per sekundę),
						'many' => q({0} metro per sekundę),
						'name' => q(metrai per sekundę),
						'one' => q({0} metras per sekundę),
						'other' => q({0} metrų per sekundę),
					},
					# Long Unit Identifier
					'speed-mile-per-hour' => {
						'few' => q({0} mylios per valandą),
						'many' => q({0} mylios per valandą),
						'name' => q(mylios per valandą),
						'one' => q({0} mylia per valandą),
						'other' => q({0} mylių per valandą),
					},
					# Core Unit Identifier
					'mile-per-hour' => {
						'few' => q({0} mylios per valandą),
						'many' => q({0} mylios per valandą),
						'name' => q(mylios per valandą),
						'one' => q({0} mylia per valandą),
						'other' => q({0} mylių per valandą),
					},
					# Long Unit Identifier
					'temperature-celsius' => {
						'1' => q(masculine),
						'few' => q({0} Celsijaus laipsniai),
						'many' => q({0} Celsijaus laipsnio),
						'name' => q(Celsijaus laipsniai),
						'one' => q({0} Celsijaus laipsnis),
						'other' => q({0} Celsijaus laipsnių),
					},
					# Core Unit Identifier
					'celsius' => {
						'1' => q(masculine),
						'few' => q({0} Celsijaus laipsniai),
						'many' => q({0} Celsijaus laipsnio),
						'name' => q(Celsijaus laipsniai),
						'one' => q({0} Celsijaus laipsnis),
						'other' => q({0} Celsijaus laipsnių),
					},
					# Long Unit Identifier
					'temperature-fahrenheit' => {
						'few' => q({0} Farenheito laipsniai),
						'many' => q({0} Farenheito laipsnio),
						'name' => q(Farenheito laipsniai),
						'one' => q({0} Farenheito laipsnis),
						'other' => q({0} Farenheito laipsnių),
					},
					# Core Unit Identifier
					'fahrenheit' => {
						'few' => q({0} Farenheito laipsniai),
						'many' => q({0} Farenheito laipsnio),
						'name' => q(Farenheito laipsniai),
						'one' => q({0} Farenheito laipsnis),
						'other' => q({0} Farenheito laipsnių),
					},
					# Long Unit Identifier
					'temperature-generic' => {
						'1' => q(masculine),
					},
					# Core Unit Identifier
					'generic' => {
						'1' => q(masculine),
					},
					# Long Unit Identifier
					'temperature-kelvin' => {
						'1' => q(masculine),
						'few' => q({0} kelvinai),
						'many' => q({0} kelvino),
						'name' => q(kelvinai),
						'one' => q({0} kelvinas),
						'other' => q({0} kelvinų),
					},
					# Core Unit Identifier
					'kelvin' => {
						'1' => q(masculine),
						'few' => q({0} kelvinai),
						'many' => q({0} kelvino),
						'name' => q(kelvinai),
						'one' => q({0} kelvinas),
						'other' => q({0} kelvinų),
					},
					# Long Unit Identifier
					'torque-newton-meter' => {
						'1' => q(masculine),
						'few' => q({0} niutonmetrai),
						'many' => q({0} niutonmetro),
						'name' => q(niutonmetrai),
						'one' => q({0} niutonmetras),
						'other' => q({0} niutonmetrų),
					},
					# Core Unit Identifier
					'newton-meter' => {
						'1' => q(masculine),
						'few' => q({0} niutonmetrai),
						'many' => q({0} niutonmetro),
						'name' => q(niutonmetrai),
						'one' => q({0} niutonmetras),
						'other' => q({0} niutonmetrų),
					},
					# Long Unit Identifier
					'torque-pound-force-foot' => {
						'name' => q(svarų pėdos),
					},
					# Core Unit Identifier
					'pound-force-foot' => {
						'name' => q(svarų pėdos),
					},
					# Long Unit Identifier
					'volume-acre-foot' => {
						'few' => q({0} pėdos akre),
						'many' => q({0} pėdos akre),
						'name' => q(pėdos akre),
						'one' => q({0} pėda akre),
						'other' => q({0} pėdų akre),
					},
					# Core Unit Identifier
					'acre-foot' => {
						'few' => q({0} pėdos akre),
						'many' => q({0} pėdos akre),
						'name' => q(pėdos akre),
						'one' => q({0} pėda akre),
						'other' => q({0} pėdų akre),
					},
					# Long Unit Identifier
					'volume-barrel' => {
						'few' => q({0} bareliai),
						'many' => q({0} barelio),
						'name' => q(bareliai),
						'one' => q({0} barelis),
						'other' => q({0} barelių),
					},
					# Core Unit Identifier
					'barrel' => {
						'few' => q({0} bareliai),
						'many' => q({0} barelio),
						'name' => q(bareliai),
						'one' => q({0} barelis),
						'other' => q({0} barelių),
					},
					# Long Unit Identifier
					'volume-bushel' => {
						'few' => q({0} bušeliai),
						'many' => q({0} bušelio),
						'name' => q(bušeliai),
						'one' => q({0} bušelis),
						'other' => q({0} bušelių),
					},
					# Core Unit Identifier
					'bushel' => {
						'few' => q({0} bušeliai),
						'many' => q({0} bušelio),
						'name' => q(bušeliai),
						'one' => q({0} bušelis),
						'other' => q({0} bušelių),
					},
					# Long Unit Identifier
					'volume-centiliter' => {
						'1' => q(masculine),
						'few' => q({0} centilitrai),
						'many' => q({0} centilitro),
						'name' => q(centilitrai),
						'one' => q({0} centilitras),
						'other' => q({0} centilitrų),
					},
					# Core Unit Identifier
					'centiliter' => {
						'1' => q(masculine),
						'few' => q({0} centilitrai),
						'many' => q({0} centilitro),
						'name' => q(centilitrai),
						'one' => q({0} centilitras),
						'other' => q({0} centilitrų),
					},
					# Long Unit Identifier
					'volume-cubic-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} kubiniai centimetrai),
						'many' => q({0} kubinio centimetro),
						'name' => q(kubiniai centimetrai),
						'one' => q({0} kubinis centimetras),
						'other' => q({0} kubinių centimetrų),
					},
					# Core Unit Identifier
					'cubic-centimeter' => {
						'1' => q(masculine),
						'few' => q({0} kubiniai centimetrai),
						'many' => q({0} kubinio centimetro),
						'name' => q(kubiniai centimetrai),
						'one' => q({0} kubinis centimetras),
						'other' => q({0} kubinių centimetrų),
					},
					# Long Unit Identifier
					'volume-cubic-foot' => {
						'few' => q({0} kubinės pėdos),
						'many' => q({0} kubinės pėdos),
						'name' => q(kubinės pėdos),
						'one' => q({0} kubinė pėda),
						'other' => q({0} kubinių pėdų),
					},
					# Core Unit Identifier
					'cubic-foot' => {
						'few' => q({0} kubinės pėdos),
						'many' => q({0} kubinės pėdos),
						'name' => q(kubinės pėdos),
						'one' => q({0} kubinė pėda),
						'other' => q({0} kubinių pėdų),
					},
					# Long Unit Identifier
					'volume-cubic-inch' => {
						'few' => q({0} kubiniai coliai),
						'many' => q({0} kubinio colio),
						'name' => q(kubiniai coliai),
						'one' => q({0} kubinis colis),
						'other' => q({0} kubinių colių),
					},
					# Core Unit Identifier
					'cubic-inch' => {
						'few' => q({0} kubiniai coliai),
						'many' => q({0} kubinio colio),
						'name' => q(kubiniai coliai),
						'one' => q({0} kubinis colis),
						'other' => q({0} kubinių colių),
					},
					# Long Unit Identifier
					'volume-cubic-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} kubiniai kilimetrai),
						'many' => q({0} kubinio kilometro),
						'name' => q(kubiniai kilometrai),
						'one' => q({0} kubinis kilometras),
						'other' => q({0} kubinių kilometrų),
					},
					# Core Unit Identifier
					'cubic-kilometer' => {
						'1' => q(masculine),
						'few' => q({0} kubiniai kilimetrai),
						'many' => q({0} kubinio kilometro),
						'name' => q(kubiniai kilometrai),
						'one' => q({0} kubinis kilometras),
						'other' => q({0} kubinių kilometrų),
					},
					# Long Unit Identifier
					'volume-cubic-meter' => {
						'1' => q(masculine),
						'few' => q({0} kubiniai metrai),
						'many' => q({0} kubinio metro),
						'name' => q(kubiniai metrai),
						'one' => q({0} kubinis metras),
						'other' => q({0} kubinių metrų),
					},
					# Core Unit Identifier
					'cubic-meter' => {
						'1' => q(masculine),
						'few' => q({0} kubiniai metrai),
						'many' => q({0} kubinio metro),
						'name' => q(kubiniai metrai),
						'one' => q({0} kubinis metras),
						'other' => q({0} kubinių metrų),
					},
					# Long Unit Identifier
					'volume-cubic-mile' => {
						'few' => q({0} kubinės mylios),
						'many' => q({0} kubinės mylios),
						'name' => q(kubinės mylios),
						'one' => q({0} kubinė mylia),
						'other' => q({0} kubinių mylių),
					},
					# Core Unit Identifier
					'cubic-mile' => {
						'few' => q({0} kubinės mylios),
						'many' => q({0} kubinės mylios),
						'name' => q(kubinės mylios),
						'one' => q({0} kubinė mylia),
						'other' => q({0} kubinių mylių),
					},
					# Long Unit Identifier
					'volume-cubic-yard' => {
						'few' => q({0} kubiniai jardai),
						'many' => q({0} kubinio jardo),
						'name' => q(kubiniai jardai),
						'one' => q({0} kubinis jardas),
						'other' => q({0} kubinių jardų),
					},
					# Core Unit Identifier
					'cubic-yard' => {
						'few' => q({0} kubiniai jardai),
						'many' => q({0} kubinio jardo),
						'name' => q(kubiniai jardai),
						'one' => q({0} kubinis jardas),
						'other' => q({0} kubinių jardų),
					},
					# Long Unit Identifier
					'volume-cup' => {
						'few' => q({0} stiklinės),
						'many' => q({0} stiklinės),
						'name' => q(stiklinės),
						'one' => q({0} stiklinė),
						'other' => q({0} stiklinių),
					},
					# Core Unit Identifier
					'cup' => {
						'few' => q({0} stiklinės),
						'many' => q({0} stiklinės),
						'name' => q(stiklinės),
						'one' => q({0} stiklinė),
						'other' => q({0} stiklinių),
					},
					# Long Unit Identifier
					'volume-cup-metric' => {
						'1' => q(masculine),
						'few' => q({0} matavimo puodeliai),
						'many' => q({0} matavimo puodelio),
						'name' => q(matavimo puodeliai),
						'one' => q({0} matavimo puodelis),
						'other' => q({0} matavimo puodelių),
					},
					# Core Unit Identifier
					'cup-metric' => {
						'1' => q(masculine),
						'few' => q({0} matavimo puodeliai),
						'many' => q({0} matavimo puodelio),
						'name' => q(matavimo puodeliai),
						'one' => q({0} matavimo puodelis),
						'other' => q({0} matavimo puodelių),
					},
					# Long Unit Identifier
					'volume-deciliter' => {
						'1' => q(masculine),
						'few' => q({0} decilitrai),
						'many' => q({0} decilitro),
						'name' => q(decilitrai),
						'one' => q({0} decilitras),
						'other' => q({0} decilitrų),
					},
					# Core Unit Identifier
					'deciliter' => {
						'1' => q(masculine),
						'few' => q({0} decilitrai),
						'many' => q({0} decilitro),
						'name' => q(decilitrai),
						'one' => q({0} decilitras),
						'other' => q({0} decilitrų),
					},
					# Long Unit Identifier
					'volume-dessert-spoon' => {
						'few' => q({0} desertiniai šaukšteliai),
						'many' => q({0} desertinio šaukštelio),
						'name' => q(desertinis šaukštelis),
						'one' => q({0} desertinis šaukštelis),
						'other' => q({0} desertinių šaukštelių),
					},
					# Core Unit Identifier
					'dessert-spoon' => {
						'few' => q({0} desertiniai šaukšteliai),
						'many' => q({0} desertinio šaukštelio),
						'name' => q(desertinis šaukštelis),
						'one' => q({0} desertinis šaukštelis),
						'other' => q({0} desertinių šaukštelių),
					},
					# Long Unit Identifier
					'volume-dessert-spoon-imperial' => {
						'few' => q({0} imp. desertiniai šaukšteliai),
						'many' => q({0} imp. desertinio šaukštelio),
						'name' => q(imp. desertinis šaukštelis),
						'one' => q({0} imp. desertinis šaukštelis),
						'other' => q({0} imp. desertinių šaukštelių),
					},
					# Core Unit Identifier
					'dessert-spoon-imperial' => {
						'few' => q({0} imp. desertiniai šaukšteliai),
						'many' => q({0} imp. desertinio šaukštelio),
						'name' => q(imp. desertinis šaukštelis),
						'one' => q({0} imp. desertinis šaukštelis),
						'other' => q({0} imp. desertinių šaukštelių),
					},
					# Long Unit Identifier
					'volume-dram' => {
						'few' => q({0} skysčio drachmos),
						'many' => q({0} skysčio drachmos),
						'name' => q(skysčio drachma),
						'one' => q({0} skysčio drachma),
						'other' => q({0} skysčio drachmų),
					},
					# Core Unit Identifier
					'dram' => {
						'few' => q({0} skysčio drachmos),
						'many' => q({0} skysčio drachmos),
						'name' => q(skysčio drachma),
						'one' => q({0} skysčio drachma),
						'other' => q({0} skysčio drachmų),
					},
					# Long Unit Identifier
					'volume-drop' => {
						'few' => q({0} lašai),
						'many' => q({0} lašo),
						'name' => q(lašas),
						'one' => q({0} lašas),
						'other' => q({0} lašų),
					},
					# Core Unit Identifier
					'drop' => {
						'few' => q({0} lašai),
						'many' => q({0} lašo),
						'name' => q(lašas),
						'one' => q({0} lašas),
						'other' => q({0} lašų),
					},
					# Long Unit Identifier
					'volume-fluid-ounce' => {
						'few' => q({0} skysčio uncijos),
						'many' => q({0} skysčio uncijos),
						'name' => q(skysčio uncijos),
						'one' => q({0} skysčio uncija),
						'other' => q({0} skysčio uncijų),
					},
					# Core Unit Identifier
					'fluid-ounce' => {
						'few' => q({0} skysčio uncijos),
						'many' => q({0} skysčio uncijos),
						'name' => q(skysčio uncijos),
						'one' => q({0} skysčio uncija),
						'other' => q({0} skysčio uncijų),
					},
					# Long Unit Identifier
					'volume-fluid-ounce-imperial' => {
						'few' => q({0} imp. skysčio uncijos),
						'many' => q({0} imp. skysčio uncijos),
						'name' => q(imperatoriškosios skysčio uncijos),
						'one' => q({0} imp. skysčio uncija),
						'other' => q({0} imp. skysčio uncijų),
					},
					# Core Unit Identifier
					'fluid-ounce-imperial' => {
						'few' => q({0} imp. skysčio uncijos),
						'many' => q({0} imp. skysčio uncijos),
						'name' => q(imperatoriškosios skysčio uncijos),
						'one' => q({0} imp. skysčio uncija),
						'other' => q({0} imp. skysčio uncijų),
					},
					# Long Unit Identifier
					'volume-gallon' => {
						'few' => q({0} galonai),
						'many' => q({0} galono),
						'name' => q(galonai),
						'one' => q({0} galonas),
						'other' => q({0} galonų),
					},
					# Core Unit Identifier
					'gallon' => {
						'few' => q({0} galonai),
						'many' => q({0} galono),
						'name' => q(galonai),
						'one' => q({0} galonas),
						'other' => q({0} galonų),
					},
					# Long Unit Identifier
					'volume-gallon-imperial' => {
						'few' => q({0} imperiniai galonai),
						'many' => q({0} imperinio galono),
						'name' => q(imperinis galonas),
						'one' => q({0} imperinis galonas),
						'other' => q({0} imperinių galonų),
						'per' => q({0} imperiniame galone),
					},
					# Core Unit Identifier
					'gallon-imperial' => {
						'few' => q({0} imperiniai galonai),
						'many' => q({0} imperinio galono),
						'name' => q(imperinis galonas),
						'one' => q({0} imperinis galonas),
						'other' => q({0} imperinių galonų),
						'per' => q({0} imperiniame galone),
					},
					# Long Unit Identifier
					'volume-hectoliter' => {
						'1' => q(masculine),
						'few' => q({0} hektolitrai),
						'many' => q({0} hektolitro),
						'name' => q(hektolitrai),
						'one' => q({0} hektolitras),
						'other' => q({0} hektolitrų),
					},
					# Core Unit Identifier
					'hectoliter' => {
						'1' => q(masculine),
						'few' => q({0} hektolitrai),
						'many' => q({0} hektolitro),
						'name' => q(hektolitrai),
						'one' => q({0} hektolitras),
						'other' => q({0} hektolitrų),
					},
					# Long Unit Identifier
					'volume-liter' => {
						'1' => q(masculine),
						'few' => q({0} litrai),
						'many' => q({0} litro),
						'one' => q({0} litras),
						'other' => q({0} litrų),
					},
					# Core Unit Identifier
					'liter' => {
						'1' => q(masculine),
						'few' => q({0} litrai),
						'many' => q({0} litro),
						'one' => q({0} litras),
						'other' => q({0} litrų),
					},
					# Long Unit Identifier
					'volume-megaliter' => {
						'1' => q(masculine),
						'few' => q({0} megalitrai),
						'many' => q({0} megalitro),
						'name' => q(megalitrai),
						'one' => q({0} megalitras),
						'other' => q({0} megalitrų),
					},
					# Core Unit Identifier
					'megaliter' => {
						'1' => q(masculine),
						'few' => q({0} megalitrai),
						'many' => q({0} megalitro),
						'name' => q(megalitrai),
						'one' => q({0} megalitras),
						'other' => q({0} megalitrų),
					},
					# Long Unit Identifier
					'volume-milliliter' => {
						'1' => q(masculine),
						'few' => q({0} mililitrai),
						'many' => q({0} mililitro),
						'name' => q(mililitrai),
						'one' => q({0} mililitras),
						'other' => q({0} mililitrų),
					},
					# Core Unit Identifier
					'milliliter' => {
						'1' => q(masculine),
						'few' => q({0} mililitrai),
						'many' => q({0} mililitro),
						'name' => q(mililitrai),
						'one' => q({0} mililitras),
						'other' => q({0} mililitrų),
					},
					# Long Unit Identifier
					'volume-pinch' => {
						'few' => q({0} žiupsneliai),
						'many' => q({0} žiupsnelio),
						'name' => q(žiupsnelis),
						'one' => q({0} žiupsnelių),
						'other' => q({0} žiupsnelis),
					},
					# Core Unit Identifier
					'pinch' => {
						'few' => q({0} žiupsneliai),
						'many' => q({0} žiupsnelio),
						'name' => q(žiupsnelis),
						'one' => q({0} žiupsnelių),
						'other' => q({0} žiupsnelis),
					},
					# Long Unit Identifier
					'volume-pint' => {
						'few' => q({0} pintos),
						'many' => q({0} pintos),
						'one' => q({0} pinta),
						'other' => q({0} pintų),
					},
					# Core Unit Identifier
					'pint' => {
						'few' => q({0} pintos),
						'many' => q({0} pintos),
						'one' => q({0} pinta),
						'other' => q({0} pintų),
					},
					# Long Unit Identifier
					'volume-pint-metric' => {
						'1' => q(feminine),
						'few' => q({0} metrinės pintos),
						'many' => q({0} metrinės pintos),
						'name' => q(metrinės pintos),
						'one' => q({0} metrinė pinta),
						'other' => q({0} metrinių pintų),
					},
					# Core Unit Identifier
					'pint-metric' => {
						'1' => q(feminine),
						'few' => q({0} metrinės pintos),
						'many' => q({0} metrinės pintos),
						'name' => q(metrinės pintos),
						'one' => q({0} metrinė pinta),
						'other' => q({0} metrinių pintų),
					},
					# Long Unit Identifier
					'volume-quart-imperial' => {
						'few' => q({0} imp. kvortos),
						'many' => q({0} imp. kvortos),
						'name' => q(imp. kvorta),
						'one' => q({0} imp. kvorta),
						'other' => q({0} imp. kvortų),
					},
					# Core Unit Identifier
					'quart-imperial' => {
						'few' => q({0} imp. kvortos),
						'many' => q({0} imp. kvortos),
						'name' => q(imp. kvorta),
						'one' => q({0} imp. kvorta),
						'other' => q({0} imp. kvortų),
					},
					# Long Unit Identifier
					'volume-tablespoon' => {
						'few' => q({0} valgomieji šaukštai),
						'many' => q({0} valgomojo šaukšto),
						'name' => q(valgomieji šaukštai),
						'one' => q({0} valgomasis šaukštas),
						'other' => q({0} valgomųjų šaukštų),
					},
					# Core Unit Identifier
					'tablespoon' => {
						'few' => q({0} valgomieji šaukštai),
						'many' => q({0} valgomojo šaukšto),
						'name' => q(valgomieji šaukštai),
						'one' => q({0} valgomasis šaukštas),
						'other' => q({0} valgomųjų šaukštų),
					},
					# Long Unit Identifier
					'volume-teaspoon' => {
						'few' => q({0} arbatiniai šaukšteliai),
						'many' => q({0} arbatinio šaukštelio),
						'name' => q(arbatiniai šaukšteliai),
						'one' => q({0} arbatinis šaukštelis),
						'other' => q({0} arbatinių šaukštelių),
					},
					# Core Unit Identifier
					'teaspoon' => {
						'few' => q({0} arbatiniai šaukšteliai),
						'many' => q({0} arbatinio šaukštelio),
						'name' => q(arbatiniai šaukšteliai),
						'one' => q({0} arbatinis šaukštelis),
						'other' => q({0} arbatinių šaukštelių),
					},
				},
				'narrow' => {
					# Long Unit Identifier
					'area-acre' => {
						'few' => q({0} ak),
						'many' => q({0} ak),
						'name' => q(akras),
						'one' => q({0} ak),
						'other' => q({0} ak),
					},
					# Core Unit Identifier
					'acre' => {
						'few' => q({0} ak),
						'many' => q({0} ak),
						'name' => q(akras),
						'one' => q({0} ak),
						'other' => q({0} ak),
					},
					# Long Unit Identifier
					'area-square-foot' => {
						'few' => q({0} ft²),
						'many' => q({0} ft²),
						'one' => q({0} ft²),
						'other' => q({0} ft²),
					},
					# Core Unit Identifier
					'square-foot' => {
						'few' => q({0} ft²),
						'many' => q({0} ft²),
						'one' => q({0} ft²),
						'other' => q({0} ft²),
					},
					# Long Unit Identifier
					'area-square-kilometer' => {
						'few' => q({0} km²),
						'many' => q({0} km²),
						'one' => q({0} km²),
						'other' => q({0} km²),
					},
					# Core Unit Identifier
					'square-kilometer' => {
						'few' => q({0} km²),
						'many' => q({0} km²),
						'one' => q({0} km²),
						'other' => q({0} km²),
					},
					# Long Unit Identifier
					'area-square-meter' => {
						'few' => q({0} m²),
						'many' => q({0} m²),
						'one' => q({0} m²),
						'other' => q({0} m²),
					},
					# Core Unit Identifier
					'square-meter' => {
						'few' => q({0} m²),
						'many' => q({0} m²),
						'one' => q({0} m²),
						'other' => q({0} m²),
					},
					# Long Unit Identifier
					'area-square-mile' => {
						'few' => q({0} my²),
						'many' => q({0} my²),
						'one' => q({0} my²),
						'other' => q({0} my²),
					},
					# Core Unit Identifier
					'square-mile' => {
						'few' => q({0} my²),
						'many' => q({0} my²),
						'one' => q({0} my²),
						'other' => q({0} my²),
					},
					# Long Unit Identifier
					'concentr-percent' => {
						'name' => q(%),
					},
					# Core Unit Identifier
					'percent' => {
						'name' => q(%),
					},
					# Long Unit Identifier
					'concentr-portion-per-1e9' => {
						'few' => q({0} dalelytės/mln.),
						'many' => q({0} dalelytės/mln.),
						'name' => q(dalelytė/mln.),
						'one' => q({0} dalelytė/mln.),
						'other' => q({0} dalelyčių/mln.),
					},
					# Core Unit Identifier
					'portion-per-1e9' => {
						'few' => q({0} dalelytės/mln.),
						'many' => q({0} dalelytės/mln.),
						'name' => q(dalelytė/mln.),
						'one' => q({0} dalelytė/mln.),
						'other' => q({0} dalelyčių/mln.),
					},
					# Long Unit Identifier
					'consumption-mile-per-gallon' => {
						'few' => q({0} mi/gal),
						'many' => q({0} mi/gal),
						'one' => q({0} mi/gal),
						'other' => q({0} mi/gal),
					},
					# Core Unit Identifier
					'mile-per-gallon' => {
						'few' => q({0} mi/gal),
						'many' => q({0} mi/gal),
						'one' => q({0} mi/gal),
						'other' => q({0} mi/gal),
					},
					# Long Unit Identifier
					'duration-day' => {
						'name' => q(diena),
					},
					# Core Unit Identifier
					'day' => {
						'name' => q(diena),
					},
					# Long Unit Identifier
					'duration-hour' => {
						'few' => q({0} h),
						'many' => q({0} h),
						'name' => q(valanda),
						'one' => q({0} h),
						'other' => q({0} h),
					},
					# Core Unit Identifier
					'hour' => {
						'few' => q({0} h),
						'many' => q({0} h),
						'name' => q(valanda),
						'one' => q({0} h),
						'other' => q({0} h),
					},
					# Long Unit Identifier
					'duration-month' => {
						'name' => q(mėnuo),
					},
					# Core Unit Identifier
					'month' => {
						'name' => q(mėnuo),
					},
					# Long Unit Identifier
					'duration-night' => {
						'few' => q({0} nakt.),
						'many' => q({0} nakt.),
						'name' => q(nakt.),
						'one' => q({0} nakt.),
						'other' => q({0} nakt.),
						'per' => q({0}/nakt.),
					},
					# Core Unit Identifier
					'night' => {
						'few' => q({0} nakt.),
						'many' => q({0} nakt.),
						'name' => q(nakt.),
						'one' => q({0} nakt.),
						'other' => q({0} nakt.),
						'per' => q({0}/nakt.),
					},
					# Long Unit Identifier
					'duration-second' => {
						'few' => q({0} s),
						'many' => q({0} s),
						'one' => q({0} s),
						'other' => q({0} s),
					},
					# Core Unit Identifier
					'second' => {
						'few' => q({0} s),
						'many' => q({0} s),
						'one' => q({0} s),
						'other' => q({0} s),
					},
					# Long Unit Identifier
					'duration-week' => {
						'name' => q(sav.),
					},
					# Core Unit Identifier
					'week' => {
						'name' => q(sav.),
					},
					# Long Unit Identifier
					'speed-kilometer-per-hour' => {
						'few' => q({0} km/h),
						'many' => q({0} km/h),
						'name' => q(km/h),
						'one' => q({0} km/h),
						'other' => q({0} km/h),
					},
					# Core Unit Identifier
					'kilometer-per-hour' => {
						'few' => q({0} km/h),
						'many' => q({0} km/h),
						'name' => q(km/h),
						'one' => q({0} km/h),
						'other' => q({0} km/h),
					},
					# Long Unit Identifier
					'speed-meter-per-second' => {
						'few' => q({0} m/s),
						'many' => q({0} m/s),
						'name' => q(m/s),
						'one' => q({0} m/s),
						'other' => q({0} m/s),
					},
					# Core Unit Identifier
					'meter-per-second' => {
						'few' => q({0} m/s),
						'many' => q({0} m/s),
						'name' => q(m/s),
						'one' => q({0} m/s),
						'other' => q({0} m/s),
					},
					# Long Unit Identifier
					'temperature-celsius' => {
						'few' => q({0}°),
						'many' => q({0}°),
						'one' => q({0}°),
						'other' => q({0}°),
					},
					# Core Unit Identifier
					'celsius' => {
						'few' => q({0}°),
						'many' => q({0}°),
						'one' => q({0}°),
						'other' => q({0}°),
					},
					# Long Unit Identifier
					'volume-acre-foot' => {
						'name' => q(ft akre),
					},
					# Core Unit Identifier
					'acre-foot' => {
						'name' => q(ft akre),
					},
					# Long Unit Identifier
					'volume-fluid-ounce' => {
						'few' => q({0} fl oz),
						'many' => q({0} fl oz),
						'one' => q({0} fl oz),
						'other' => q({0} fl oz),
					},
					# Core Unit Identifier
					'fluid-ounce' => {
						'few' => q({0} fl oz),
						'many' => q({0} fl oz),
						'one' => q({0} fl oz),
						'other' => q({0} fl oz),
					},
				},
				'short' => {
					# Long Unit Identifier
					'' => {
						'name' => q(kryptis),
					},
					# Core Unit Identifier
					'' => {
						'name' => q(kryptis),
					},
					# Long Unit Identifier
					'acceleration-g-force' => {
						'name' => q(G),
					},
					# Core Unit Identifier
					'g-force' => {
						'name' => q(G),
					},
					# Long Unit Identifier
					'angle-arc-minute' => {
						'name' => q(kampo minutės),
					},
					# Core Unit Identifier
					'arc-minute' => {
						'name' => q(kampo minutės),
					},
					# Long Unit Identifier
					'angle-arc-second' => {
						'name' => q(kampo sekundės),
					},
					# Core Unit Identifier
					'arc-second' => {
						'name' => q(kampo sekundės),
					},
					# Long Unit Identifier
					'angle-degree' => {
						'name' => q(laipsniai),
					},
					# Core Unit Identifier
					'degree' => {
						'name' => q(laipsniai),
					},
					# Long Unit Identifier
					'angle-revolution' => {
						'few' => q({0} apsisuk.),
						'many' => q({0} apsisuk.),
						'name' => q(apsisuk.),
						'one' => q({0} apsisuk.),
						'other' => q({0} apsisuk.),
					},
					# Core Unit Identifier
					'revolution' => {
						'few' => q({0} apsisuk.),
						'many' => q({0} apsisuk.),
						'name' => q(apsisuk.),
						'one' => q({0} apsisuk.),
						'other' => q({0} apsisuk.),
					},
					# Long Unit Identifier
					'area-acre' => {
						'few' => q({0} akr.),
						'many' => q({0} akr.),
						'name' => q(akrai),
						'one' => q({0} akr.),
						'other' => q({0} akr.),
					},
					# Core Unit Identifier
					'acre' => {
						'few' => q({0} akr.),
						'many' => q({0} akr.),
						'name' => q(akrai),
						'one' => q({0} akr.),
						'other' => q({0} akr.),
					},
					# Long Unit Identifier
					'area-dunam' => {
						'few' => q({0} dunamai),
						'many' => q({0} dunamo),
						'name' => q(dunamai),
						'one' => q({0} dunamas),
						'other' => q({0} dunamų),
					},
					# Core Unit Identifier
					'dunam' => {
						'few' => q({0} dunamai),
						'many' => q({0} dunamo),
						'name' => q(dunamai),
						'one' => q({0} dunamas),
						'other' => q({0} dunamų),
					},
					# Long Unit Identifier
					'area-hectare' => {
						'name' => q(hektarai),
					},
					# Core Unit Identifier
					'hectare' => {
						'name' => q(hektarai),
					},
					# Long Unit Identifier
					'area-square-foot' => {
						'few' => q({0} kv. pėdos),
						'many' => q({0} kv. pėdos),
						'name' => q(kv. pėda),
						'one' => q({0} kv. pėda),
						'other' => q({0} kv. pėdų),
					},
					# Core Unit Identifier
					'square-foot' => {
						'few' => q({0} kv. pėdos),
						'many' => q({0} kv. pėdos),
						'name' => q(kv. pėda),
						'one' => q({0} kv. pėda),
						'other' => q({0} kv. pėdų),
					},
					# Long Unit Identifier
					'area-square-kilometer' => {
						'few' => q({0} kv. km),
						'many' => q({0} kv. km),
						'name' => q(kv. km),
						'one' => q({0} kv. km),
						'other' => q({0} kv. km),
					},
					# Core Unit Identifier
					'square-kilometer' => {
						'few' => q({0} kv. km),
						'many' => q({0} kv. km),
						'name' => q(kv. km),
						'one' => q({0} kv. km),
						'other' => q({0} kv. km),
					},
					# Long Unit Identifier
					'area-square-meter' => {
						'few' => q({0} kv. m),
						'many' => q({0} kv. m),
						'name' => q(kv. m),
						'one' => q({0} kv. m),
						'other' => q({0} kv. m),
					},
					# Core Unit Identifier
					'square-meter' => {
						'few' => q({0} kv. m),
						'many' => q({0} kv. m),
						'name' => q(kv. m),
						'one' => q({0} kv. m),
						'other' => q({0} kv. m),
					},
					# Long Unit Identifier
					'area-square-mile' => {
						'few' => q({0} kv. my),
						'many' => q({0} kv. my),
						'name' => q(kv. mylios),
						'one' => q({0} kv. my),
						'other' => q({0} kv. my),
						'per' => q({0}/my²),
					},
					# Core Unit Identifier
					'square-mile' => {
						'few' => q({0} kv. my),
						'many' => q({0} kv. my),
						'name' => q(kv. mylios),
						'one' => q({0} kv. my),
						'other' => q({0} kv. my),
						'per' => q({0}/my²),
					},
					# Long Unit Identifier
					'concentr-item' => {
						'few' => q({0} elem.),
						'many' => q({0} elem.),
						'name' => q(elementas),
						'one' => q({0} elem.),
						'other' => q({0} elem.),
					},
					# Core Unit Identifier
					'item' => {
						'few' => q({0} elem.),
						'many' => q({0} elem.),
						'name' => q(elementas),
						'one' => q({0} elem.),
						'other' => q({0} elem.),
					},
					# Long Unit Identifier
					'concentr-milligram-ofglucose-per-deciliter' => {
						'few' => q({0} mg/dl),
						'many' => q({0} mg/dl),
						'name' => q(mg/dl),
						'one' => q({0} mg/dl),
						'other' => q({0} mg/dl),
					},
					# Core Unit Identifier
					'milligram-ofglucose-per-deciliter' => {
						'few' => q({0} mg/dl),
						'many' => q({0} mg/dl),
						'name' => q(mg/dl),
						'one' => q({0} mg/dl),
						'other' => q({0} mg/dl),
					},
					# Long Unit Identifier
					'concentr-millimole-per-liter' => {
						'few' => q({0} mmol/l),
						'many' => q({0} mmol/l),
						'name' => q(mmol/l),
						'one' => q({0} mmol/l),
						'other' => q({0} mmol/l),
					},
					# Core Unit Identifier
					'millimole-per-liter' => {
						'few' => q({0} mmol/l),
						'many' => q({0} mmol/l),
						'name' => q(mmol/l),
						'one' => q({0} mmol/l),
						'other' => q({0} mmol/l),
					},
					# Long Unit Identifier
					'concentr-percent' => {
						'few' => q({0} %),
						'many' => q({0} %),
						'name' => q(procentas),
						'one' => q({0} %),
						'other' => q({0} %),
					},
					# Core Unit Identifier
					'percent' => {
						'few' => q({0} %),
						'many' => q({0} %),
						'name' => q(procentas),
						'one' => q({0} %),
						'other' => q({0} %),
					},
					# Long Unit Identifier
					'concentr-permille' => {
						'few' => q({0} ‰),
						'many' => q({0} ‰),
						'name' => q(promilė),
						'one' => q({0} ‰),
						'other' => q({0} ‰),
					},
					# Core Unit Identifier
					'permille' => {
						'few' => q({0} ‰),
						'many' => q({0} ‰),
						'name' => q(promilė),
						'one' => q({0} ‰),
						'other' => q({0} ‰),
					},
					# Long Unit Identifier
					'concentr-portion-per-1e9' => {
						'few' => q({0} dalelytės/mln.),
						'many' => q({0} dalelytės/mln.),
						'name' => q(dalelytė/mln.),
						'one' => q({0} dalelytė/mln.),
						'other' => q({0} dalelyčių/mln.),
					},
					# Core Unit Identifier
					'portion-per-1e9' => {
						'few' => q({0} dalelytės/mln.),
						'many' => q({0} dalelytės/mln.),
						'name' => q(dalelytė/mln.),
						'one' => q({0} dalelytė/mln.),
						'other' => q({0} dalelyčių/mln.),
					},
					# Long Unit Identifier
					'consumption-liter-per-100-kilometer' => {
						'few' => q({0} l/100 km),
						'many' => q({0} l/100 km),
						'name' => q(l/100 km),
						'one' => q({0} l/100 km),
						'other' => q({0} l/100 km),
					},
					# Core Unit Identifier
					'liter-per-100-kilometer' => {
						'few' => q({0} l/100 km),
						'many' => q({0} l/100 km),
						'name' => q(l/100 km),
						'one' => q({0} l/100 km),
						'other' => q({0} l/100 km),
					},
					# Long Unit Identifier
					'consumption-liter-per-kilometer' => {
						'few' => q({0} l/km),
						'many' => q({0} l/km),
						'name' => q(l/km),
						'one' => q({0} l/km),
						'other' => q({0} l/km),
					},
					# Core Unit Identifier
					'liter-per-kilometer' => {
						'few' => q({0} l/km),
						'many' => q({0} l/km),
						'name' => q(l/km),
						'one' => q({0} l/km),
						'other' => q({0} l/km),
					},
					# Long Unit Identifier
					'consumption-mile-per-gallon' => {
						'few' => q({0} my/gal),
						'many' => q({0} my/gal),
						'name' => q(my/gal),
						'one' => q({0} my/gal),
						'other' => q({0} my/gal),
					},
					# Core Unit Identifier
					'mile-per-gallon' => {
						'few' => q({0} my/gal),
						'many' => q({0} my/gal),
						'name' => q(my/gal),
						'one' => q({0} my/gal),
						'other' => q({0} my/gal),
					},
					# Long Unit Identifier
					'consumption-mile-per-gallon-imperial' => {
						'few' => q({0} my/imp. g),
						'many' => q({0} my/imp. g),
						'name' => q(my/imp. g),
						'one' => q({0} my/imp. g),
						'other' => q({0} my/imp. g),
					},
					# Core Unit Identifier
					'mile-per-gallon-imperial' => {
						'few' => q({0} my/imp. g),
						'many' => q({0} my/imp. g),
						'name' => q(my/imp. g),
						'one' => q({0} my/imp. g),
						'other' => q({0} my/imp. g),
					},
					# Long Unit Identifier
					'coordinate' => {
						'east' => q({0} R),
						'north' => q({0} Š),
						'south' => q({0} P),
						'west' => q({0} V),
					},
					# Core Unit Identifier
					'coordinate' => {
						'east' => q({0} R),
						'north' => q({0} Š),
						'south' => q({0} P),
						'west' => q({0} V),
					},
					# Long Unit Identifier
					'digital-bit' => {
						'few' => q({0} b),
						'many' => q({0} b),
						'name' => q(bitai),
						'one' => q({0} b),
						'other' => q({0} b),
					},
					# Core Unit Identifier
					'bit' => {
						'few' => q({0} b),
						'many' => q({0} b),
						'name' => q(bitai),
						'one' => q({0} b),
						'other' => q({0} b),
					},
					# Long Unit Identifier
					'digital-byte' => {
						'few' => q({0} B),
						'many' => q({0} B),
						'name' => q(B),
						'one' => q({0} B),
						'other' => q({0} B),
					},
					# Core Unit Identifier
					'byte' => {
						'few' => q({0} B),
						'many' => q({0} B),
						'name' => q(B),
						'one' => q({0} B),
						'other' => q({0} B),
					},
					# Long Unit Identifier
					'digital-petabyte' => {
						'name' => q(Petabaitas),
					},
					# Core Unit Identifier
					'petabyte' => {
						'name' => q(Petabaitas),
					},
					# Long Unit Identifier
					'duration-century' => {
						'few' => q({0} a.),
						'many' => q({0} a.),
						'name' => q(a.),
						'one' => q({0} a.),
						'other' => q({0} a.),
					},
					# Core Unit Identifier
					'century' => {
						'few' => q({0} a.),
						'many' => q({0} a.),
						'name' => q(a.),
						'one' => q({0} a.),
						'other' => q({0} a.),
					},
					# Long Unit Identifier
					'duration-day' => {
						'few' => q({0} d.),
						'many' => q({0} d.),
						'name' => q(dienos),
						'one' => q({0} d.),
						'other' => q({0} d.),
						'per' => q({0}/d.),
					},
					# Core Unit Identifier
					'day' => {
						'few' => q({0} d.),
						'many' => q({0} d.),
						'name' => q(dienos),
						'one' => q({0} d.),
						'other' => q({0} d.),
						'per' => q({0}/d.),
					},
					# Long Unit Identifier
					'duration-decade' => {
						'few' => q({0} dek.),
						'many' => q({0} dek.),
						'name' => q(dekados),
						'one' => q({0} dek.),
						'other' => q({0} dek.),
					},
					# Core Unit Identifier
					'decade' => {
						'few' => q({0} dek.),
						'many' => q({0} dek.),
						'name' => q(dekados),
						'one' => q({0} dek.),
						'other' => q({0} dek.),
					},
					# Long Unit Identifier
					'duration-hour' => {
						'few' => q({0} val.),
						'many' => q({0} val.),
						'name' => q(valandos),
						'one' => q({0} val.),
						'other' => q({0} val.),
					},
					# Core Unit Identifier
					'hour' => {
						'few' => q({0} val.),
						'many' => q({0} val.),
						'name' => q(valandos),
						'one' => q({0} val.),
						'other' => q({0} val.),
					},
					# Long Unit Identifier
					'duration-millisecond' => {
						'name' => q(milisek.),
					},
					# Core Unit Identifier
					'millisecond' => {
						'name' => q(milisek.),
					},
					# Long Unit Identifier
					'duration-minute' => {
						'few' => q({0} min.),
						'many' => q({0} min.),
						'name' => q(min.),
						'one' => q({0} min.),
						'other' => q({0} min.),
						'per' => q({0}/min.),
					},
					# Core Unit Identifier
					'minute' => {
						'few' => q({0} min.),
						'many' => q({0} min.),
						'name' => q(min.),
						'one' => q({0} min.),
						'other' => q({0} min.),
						'per' => q({0}/min.),
					},
					# Long Unit Identifier
					'duration-month' => {
						'few' => q({0} mėn.),
						'many' => q({0} mėn.),
						'name' => q(mėnesiai),
						'one' => q({0} mėn.),
						'other' => q({0} mėn.),
						'per' => q({0}/mėn.),
					},
					# Core Unit Identifier
					'month' => {
						'few' => q({0} mėn.),
						'many' => q({0} mėn.),
						'name' => q(mėnesiai),
						'one' => q({0} mėn.),
						'other' => q({0} mėn.),
						'per' => q({0}/mėn.),
					},
					# Long Unit Identifier
					'duration-nanosecond' => {
						'name' => q(nanosek.),
					},
					# Core Unit Identifier
					'nanosecond' => {
						'name' => q(nanosek.),
					},
					# Long Unit Identifier
					'duration-night' => {
						'few' => q({0} nakt.),
						'many' => q({0} nakt.),
						'name' => q(nakt.),
						'one' => q({0} nakt.),
						'other' => q({0} nakt.),
						'per' => q({0}/nakt.),
					},
					# Core Unit Identifier
					'night' => {
						'few' => q({0} nakt.),
						'many' => q({0} nakt.),
						'name' => q(nakt.),
						'one' => q({0} nakt.),
						'other' => q({0} nakt.),
						'per' => q({0}/nakt.),
					},
					# Long Unit Identifier
					'duration-quarter' => {
						'few' => q({0} ketv.),
						'many' => q({0} ketv.),
						'name' => q(ketv.),
						'one' => q({0} ketv.),
						'other' => q({0} ketv.),
						'per' => q({0}/ketv.),
					},
					# Core Unit Identifier
					'quarter' => {
						'few' => q({0} ketv.),
						'many' => q({0} ketv.),
						'name' => q(ketv.),
						'one' => q({0} ketv.),
						'other' => q({0} ketv.),
						'per' => q({0}/ketv.),
					},
					# Long Unit Identifier
					'duration-second' => {
						'few' => q({0} sek.),
						'many' => q({0} sek.),
						'name' => q(sek.),
						'one' => q({0} sek.),
						'other' => q({0} sek.),
					},
					# Core Unit Identifier
					'second' => {
						'few' => q({0} sek.),
						'many' => q({0} sek.),
						'name' => q(sek.),
						'one' => q({0} sek.),
						'other' => q({0} sek.),
					},
					# Long Unit Identifier
					'duration-week' => {
						'few' => q({0} sav.),
						'many' => q({0} sav.),
						'name' => q(savaitės),
						'one' => q({0} sav.),
						'other' => q({0} sav.),
						'per' => q({0}/sav.),
					},
					# Core Unit Identifier
					'week' => {
						'few' => q({0} sav.),
						'many' => q({0} sav.),
						'name' => q(savaitės),
						'one' => q({0} sav.),
						'other' => q({0} sav.),
						'per' => q({0}/sav.),
					},
					# Long Unit Identifier
					'duration-year' => {
						'few' => q({0} m.),
						'many' => q({0} m.),
						'name' => q(metai),
						'one' => q({0} m.),
						'other' => q({0} m.),
						'per' => q({0}/m.),
					},
					# Core Unit Identifier
					'year' => {
						'few' => q({0} m.),
						'many' => q({0} m.),
						'name' => q(metai),
						'one' => q({0} m.),
						'other' => q({0} m.),
						'per' => q({0}/m.),
					},
					# Long Unit Identifier
					'electric-ampere' => {
						'name' => q(A),
					},
					# Core Unit Identifier
					'ampere' => {
						'name' => q(A),
					},
					# Long Unit Identifier
					'electric-ohm' => {
						'name' => q(Ω),
					},
					# Core Unit Identifier
					'ohm' => {
						'name' => q(Ω),
					},
					# Long Unit Identifier
					'electric-volt' => {
						'name' => q(V),
					},
					# Core Unit Identifier
					'volt' => {
						'name' => q(V),
					},
					# Long Unit Identifier
					'energy-foodcalorie' => {
						'few' => q({0} cal),
						'many' => q({0} cal),
						'name' => q(cal),
						'one' => q({0} cal),
						'other' => q({0} cal),
					},
					# Core Unit Identifier
					'foodcalorie' => {
						'few' => q({0} cal),
						'many' => q({0} cal),
						'name' => q(cal),
						'one' => q({0} cal),
						'other' => q({0} cal),
					},
					# Long Unit Identifier
					'energy-joule' => {
						'name' => q(J),
					},
					# Core Unit Identifier
					'joule' => {
						'name' => q(J),
					},
					# Long Unit Identifier
					'energy-therm-us' => {
						'few' => q({0} JAV termos),
						'many' => q({0} JAV termos),
						'name' => q(JAV terma),
						'one' => q({0} JAV terma),
						'other' => q({0} JAV termų),
					},
					# Core Unit Identifier
					'therm-us' => {
						'few' => q({0} JAV termos),
						'many' => q({0} JAV termos),
						'name' => q(JAV terma),
						'one' => q({0} JAV terma),
						'other' => q({0} JAV termų),
					},
					# Long Unit Identifier
					'graphics-dot' => {
						'few' => q({0} tšk.),
						'many' => q({0} tšk.),
						'name' => q(tšk.),
						'one' => q({0} tšk.),
						'other' => q({0} tšk.),
					},
					# Core Unit Identifier
					'dot' => {
						'few' => q({0} tšk.),
						'many' => q({0} tšk.),
						'name' => q(tšk.),
						'one' => q({0} tšk.),
						'other' => q({0} tšk.),
					},
					# Long Unit Identifier
					'graphics-dot-per-centimeter' => {
						'few' => q({0} tšk./cm),
						'many' => q({0} tšk./cm),
						'name' => q(taškai centimetre),
						'one' => q({0} tšk./cm),
						'other' => q({0} tšk./cm),
					},
					# Core Unit Identifier
					'dot-per-centimeter' => {
						'few' => q({0} tšk./cm),
						'many' => q({0} tšk./cm),
						'name' => q(taškai centimetre),
						'one' => q({0} tšk./cm),
						'other' => q({0} tšk./cm),
					},
					# Long Unit Identifier
					'graphics-dot-per-inch' => {
						'few' => q({0} tšk./in),
						'many' => q({0} tšk./in),
						'name' => q(taškai colyje),
						'one' => q({0} tšk./in),
						'other' => q({0} tšk./in),
					},
					# Core Unit Identifier
					'dot-per-inch' => {
						'few' => q({0} tšk./in),
						'many' => q({0} tšk./in),
						'name' => q(taškai colyje),
						'one' => q({0} tšk./in),
						'other' => q({0} tšk./in),
					},
					# Long Unit Identifier
					'graphics-em' => {
						'name' => q(tipografinis emas),
					},
					# Core Unit Identifier
					'em' => {
						'name' => q(tipografinis emas),
					},
					# Long Unit Identifier
					'graphics-megapixel' => {
						'name' => q(megapikseliai),
					},
					# Core Unit Identifier
					'megapixel' => {
						'name' => q(megapikseliai),
					},
					# Long Unit Identifier
					'graphics-pixel' => {
						'few' => q({0} p),
						'many' => q({0} p),
						'name' => q(pikseliai),
						'one' => q({0} p),
						'other' => q({0} p),
					},
					# Core Unit Identifier
					'pixel' => {
						'few' => q({0} p),
						'many' => q({0} p),
						'name' => q(pikseliai),
						'one' => q({0} p),
						'other' => q({0} p),
					},
					# Long Unit Identifier
					'graphics-pixel-per-centimeter' => {
						'few' => q({0} p/cm),
						'many' => q({0} p/cm),
						'name' => q(pikseliai centimetre),
						'one' => q({0} p/cm),
						'other' => q({0} p/cm),
					},
					# Core Unit Identifier
					'pixel-per-centimeter' => {
						'few' => q({0} p/cm),
						'many' => q({0} p/cm),
						'name' => q(pikseliai centimetre),
						'one' => q({0} p/cm),
						'other' => q({0} p/cm),
					},
					# Long Unit Identifier
					'graphics-pixel-per-inch' => {
						'name' => q(pikseliai colyje),
					},
					# Core Unit Identifier
					'pixel-per-inch' => {
						'name' => q(pikseliai colyje),
					},
					# Long Unit Identifier
					'length-astronomical-unit' => {
						'few' => q({0} AV),
						'many' => q({0} AV),
						'name' => q(AV),
						'one' => q({0} AV),
						'other' => q({0} AV),
					},
					# Core Unit Identifier
					'astronomical-unit' => {
						'few' => q({0} AV),
						'many' => q({0} AV),
						'name' => q(AV),
						'one' => q({0} AV),
						'other' => q({0} AV),
					},
					# Long Unit Identifier
					'length-fathom' => {
						'name' => q(fth),
					},
					# Core Unit Identifier
					'fathom' => {
						'name' => q(fth),
					},
					# Long Unit Identifier
					'length-foot' => {
						'name' => q(pėda),
					},
					# Core Unit Identifier
					'foot' => {
						'name' => q(pėda),
					},
					# Long Unit Identifier
					'length-inch' => {
						'name' => q(coliai),
					},
					# Core Unit Identifier
					'inch' => {
						'name' => q(coliai),
					},
					# Long Unit Identifier
					'length-light-year' => {
						'few' => q({0} šm.),
						'many' => q({0} šm.),
						'name' => q(šviesmečiai),
						'one' => q({0} šm.),
						'other' => q({0} šm.),
					},
					# Core Unit Identifier
					'light-year' => {
						'few' => q({0} šm.),
						'many' => q({0} šm.),
						'name' => q(šviesmečiai),
						'one' => q({0} šm.),
						'other' => q({0} šm.),
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
					'length-mile-scandinavian' => {
						'few' => q({0} IM),
						'many' => q({0} IM),
						'name' => q(IM),
						'one' => q({0} IM),
						'other' => q({0} IM),
					},
					# Core Unit Identifier
					'mile-scandinavian' => {
						'few' => q({0} IM),
						'many' => q({0} IM),
						'name' => q(IM),
						'one' => q({0} IM),
						'other' => q({0} IM),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'few' => q({0} M),
						'many' => q({0} M),
						'name' => q(M),
						'one' => q({0} M),
						'other' => q({0} M),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'few' => q({0} M),
						'many' => q({0} M),
						'name' => q(M),
						'one' => q({0} M),
						'other' => q({0} M),
					},
					# Long Unit Identifier
					'mass-carat' => {
						'few' => q({0} ct),
						'many' => q({0} ct),
						'name' => q(ct),
						'one' => q({0} ct),
						'other' => q({0} ct),
					},
					# Core Unit Identifier
					'carat' => {
						'few' => q({0} ct),
						'many' => q({0} ct),
						'name' => q(ct),
						'one' => q({0} ct),
						'other' => q({0} ct),
					},
					# Long Unit Identifier
					'mass-grain' => {
						'few' => q({0} grūdai),
						'many' => q({0} grūdo),
						'name' => q(grūdas),
						'one' => q({0} grūdas),
						'other' => q({0} grūdų),
					},
					# Core Unit Identifier
					'grain' => {
						'few' => q({0} grūdai),
						'many' => q({0} grūdo),
						'name' => q(grūdas),
						'one' => q({0} grūdas),
						'other' => q({0} grūdų),
					},
					# Long Unit Identifier
					'mass-gram' => {
						'name' => q(g),
					},
					# Core Unit Identifier
					'gram' => {
						'name' => q(g),
					},
					# Long Unit Identifier
					'mass-ounce-troy' => {
						'few' => q({0} ozt),
						'many' => q({0} ozt),
						'name' => q(ozt),
						'one' => q({0} ozt),
						'other' => q({0} ozt),
					},
					# Core Unit Identifier
					'ounce-troy' => {
						'few' => q({0} ozt),
						'many' => q({0} ozt),
						'name' => q(ozt),
						'one' => q({0} ozt),
						'other' => q({0} ozt),
					},
					# Long Unit Identifier
					'mass-ton' => {
						'few' => q({0} t),
						'many' => q({0} t),
						'name' => q(t),
						'one' => q({0} t),
						'other' => q({0} t),
					},
					# Core Unit Identifier
					'ton' => {
						'few' => q({0} t),
						'many' => q({0} t),
						'name' => q(t),
						'one' => q({0} t),
						'other' => q({0} t),
					},
					# Long Unit Identifier
					'mass-tonne' => {
						'few' => q({0} mt),
						'many' => q({0} mt),
						'name' => q(mt),
						'one' => q({0} mt),
						'other' => q({0} mt),
					},
					# Core Unit Identifier
					'tonne' => {
						'few' => q({0} mt),
						'many' => q({0} mt),
						'name' => q(mt),
						'one' => q({0} mt),
						'other' => q({0} mt),
					},
					# Long Unit Identifier
					'power-horsepower' => {
						'few' => q({0} AG),
						'many' => q({0} AG),
						'name' => q(AG),
						'one' => q({0} AG),
						'other' => q({0} AG),
					},
					# Core Unit Identifier
					'horsepower' => {
						'few' => q({0} AG),
						'many' => q({0} AG),
						'name' => q(AG),
						'one' => q({0} AG),
						'other' => q({0} AG),
					},
					# Long Unit Identifier
					'power-watt' => {
						'name' => q(W),
					},
					# Core Unit Identifier
					'watt' => {
						'name' => q(W),
					},
					# Long Unit Identifier
					'pressure-bar' => {
						'few' => q({0} ba),
						'many' => q({0} ba),
						'name' => q(baras),
						'one' => q({0} ba),
						'other' => q({0} ba),
					},
					# Core Unit Identifier
					'bar' => {
						'few' => q({0} ba),
						'many' => q({0} ba),
						'name' => q(baras),
						'one' => q({0} ba),
						'other' => q({0} ba),
					},
					# Long Unit Identifier
					'pressure-pascal' => {
						'name' => q(paskaliai),
					},
					# Core Unit Identifier
					'pascal' => {
						'name' => q(paskaliai),
					},
					# Long Unit Identifier
					'pressure-pound-force-per-square-inch' => {
						'few' => q({0} lb in²),
						'many' => q({0} lb in²),
						'name' => q(lb in²),
						'one' => q({0} lb in²),
						'other' => q({0} lb in²),
					},
					# Core Unit Identifier
					'pound-force-per-square-inch' => {
						'few' => q({0} lb in²),
						'many' => q({0} lb in²),
						'name' => q(lb in²),
						'one' => q({0} lb in²),
						'other' => q({0} lb in²),
					},
					# Long Unit Identifier
					'speed-beaufort' => {
						'name' => q(Bofortas),
					},
					# Core Unit Identifier
					'beaufort' => {
						'name' => q(Bofortas),
					},
					# Long Unit Identifier
					'speed-kilometer-per-hour' => {
						'few' => q({0} km/val.),
						'many' => q({0} km/val.),
						'name' => q(km/val.),
						'one' => q({0} km/val.),
						'other' => q({0} km/val.),
					},
					# Core Unit Identifier
					'kilometer-per-hour' => {
						'few' => q({0} km/val.),
						'many' => q({0} km/val.),
						'name' => q(km/val.),
						'one' => q({0} km/val.),
						'other' => q({0} km/val.),
					},
					# Long Unit Identifier
					'speed-knot' => {
						'few' => q({0} KN),
						'many' => q({0} KN),
						'name' => q(mazgas),
						'one' => q({0} KN),
						'other' => q({0} KN),
					},
					# Core Unit Identifier
					'knot' => {
						'few' => q({0} KN),
						'many' => q({0} KN),
						'name' => q(mazgas),
						'one' => q({0} KN),
						'other' => q({0} KN),
					},
					# Long Unit Identifier
					'speed-meter-per-second' => {
						'few' => q({0} m/sek.),
						'many' => q({0} m/sek.),
						'name' => q(m/sek.),
						'one' => q({0} m/sek.),
						'other' => q({0} m/sek.),
					},
					# Core Unit Identifier
					'meter-per-second' => {
						'few' => q({0} m/sek.),
						'many' => q({0} m/sek.),
						'name' => q(m/sek.),
						'one' => q({0} m/sek.),
						'other' => q({0} m/sek.),
					},
					# Long Unit Identifier
					'torque-newton-meter' => {
						'few' => q({0} N-m),
						'many' => q({0} N-m),
						'name' => q(N-m),
						'one' => q({0} N-m),
						'other' => q({0} N-m),
					},
					# Core Unit Identifier
					'newton-meter' => {
						'few' => q({0} N-m),
						'many' => q({0} N-m),
						'name' => q(N-m),
						'one' => q({0} N-m),
						'other' => q({0} N-m),
					},
					# Long Unit Identifier
					'volume-acre-foot' => {
						'few' => q({0} ft akre),
						'many' => q({0} ft akre),
						'name' => q(pėda akre),
						'one' => q({0} ft akre),
						'other' => q({0} ft akre),
					},
					# Core Unit Identifier
					'acre-foot' => {
						'few' => q({0} ft akre),
						'many' => q({0} ft akre),
						'name' => q(pėda akre),
						'one' => q({0} ft akre),
						'other' => q({0} ft akre),
					},
					# Long Unit Identifier
					'volume-centiliter' => {
						'few' => q({0} cl),
						'many' => q({0} cl),
						'name' => q(cl),
						'one' => q({0} cl),
						'other' => q({0} cl),
					},
					# Core Unit Identifier
					'centiliter' => {
						'few' => q({0} cl),
						'many' => q({0} cl),
						'name' => q(cl),
						'one' => q({0} cl),
						'other' => q({0} cl),
					},
					# Long Unit Identifier
					'volume-cup' => {
						'few' => q({0} stikl.),
						'many' => q({0} stikl.),
						'name' => q(stikl.),
						'one' => q({0} stikl.),
						'other' => q({0} stikl.),
					},
					# Core Unit Identifier
					'cup' => {
						'few' => q({0} stikl.),
						'many' => q({0} stikl.),
						'name' => q(stikl.),
						'one' => q({0} stikl.),
						'other' => q({0} stikl.),
					},
					# Long Unit Identifier
					'volume-cup-metric' => {
						'few' => q({0} mat. puodeliai),
						'many' => q({0} mat. puodelio),
						'name' => q(mat. puodelis),
						'one' => q({0} mat. puodelis),
						'other' => q({0} mat. puodelių),
					},
					# Core Unit Identifier
					'cup-metric' => {
						'few' => q({0} mat. puodeliai),
						'many' => q({0} mat. puodelio),
						'name' => q(mat. puodelis),
						'one' => q({0} mat. puodelis),
						'other' => q({0} mat. puodelių),
					},
					# Long Unit Identifier
					'volume-deciliter' => {
						'few' => q({0} dl),
						'many' => q({0} dl),
						'name' => q(dl),
						'one' => q({0} dl),
						'other' => q({0} dl),
					},
					# Core Unit Identifier
					'deciliter' => {
						'few' => q({0} dl),
						'many' => q({0} dl),
						'name' => q(dl),
						'one' => q({0} dl),
						'other' => q({0} dl),
					},
					# Long Unit Identifier
					'volume-dessert-spoon' => {
						'few' => q({0} des. š.),
						'many' => q({0} des. š.),
						'name' => q(des. š.),
						'one' => q({0} des. š.),
						'other' => q({0} des. š.),
					},
					# Core Unit Identifier
					'dessert-spoon' => {
						'few' => q({0} des. š.),
						'many' => q({0} des. š.),
						'name' => q(des. š.),
						'one' => q({0} des. š.),
						'other' => q({0} des. š.),
					},
					# Long Unit Identifier
					'volume-dessert-spoon-imperial' => {
						'few' => q({0} imp. des. š.),
						'many' => q({0} imp. des. š.),
						'name' => q(imp. des. š.),
						'one' => q({0} imp. des. š.),
						'other' => q({0} imp. des. š.),
					},
					# Core Unit Identifier
					'dessert-spoon-imperial' => {
						'few' => q({0} imp. des. š.),
						'many' => q({0} imp. des. š.),
						'name' => q(imp. des. š.),
						'one' => q({0} imp. des. š.),
						'other' => q({0} imp. des. š.),
					},
					# Long Unit Identifier
					'volume-dram' => {
						'few' => q({0} sk. drach.),
						'many' => q({0} sk. drach.),
						'name' => q(sk. drach.),
						'one' => q({0} sk. drach.),
						'other' => q({0} sk. drach.),
					},
					# Core Unit Identifier
					'dram' => {
						'few' => q({0} sk. drach.),
						'many' => q({0} sk. drach.),
						'name' => q(sk. drach.),
						'one' => q({0} sk. drach.),
						'other' => q({0} sk. drach.),
					},
					# Long Unit Identifier
					'volume-drop' => {
						'few' => q({0} laš.),
						'many' => q({0} laš.),
						'name' => q(laš.),
						'one' => q({0} laš.),
						'other' => q({0} laš.),
					},
					# Core Unit Identifier
					'drop' => {
						'few' => q({0} laš.),
						'many' => q({0} laš.),
						'name' => q(laš.),
						'one' => q({0} laš.),
						'other' => q({0} laš.),
					},
					# Long Unit Identifier
					'volume-fluid-ounce' => {
						'few' => q({0} skysčio oz),
						'many' => q({0} skysčio oz),
						'name' => q(skysčio oz),
						'one' => q({0} skysčio oz),
						'other' => q({0} skysčio oz),
					},
					# Core Unit Identifier
					'fluid-ounce' => {
						'few' => q({0} skysčio oz),
						'many' => q({0} skysčio oz),
						'name' => q(skysčio oz),
						'one' => q({0} skysčio oz),
						'other' => q({0} skysčio oz),
					},
					# Long Unit Identifier
					'volume-fluid-ounce-imperial' => {
						'few' => q({0} imp. fl oz),
						'many' => q({0} imp. fl oz),
						'name' => q(imp. skysčio uncija),
						'one' => q({0} imp. fl oz),
						'other' => q({0} imp. fl oz),
					},
					# Core Unit Identifier
					'fluid-ounce-imperial' => {
						'few' => q({0} imp. fl oz),
						'many' => q({0} imp. fl oz),
						'name' => q(imp. skysčio uncija),
						'one' => q({0} imp. fl oz),
						'other' => q({0} imp. fl oz),
					},
					# Long Unit Identifier
					'volume-gallon' => {
						'few' => q({0} gal),
						'many' => q({0} gal),
						'name' => q(gal),
						'one' => q({0} gal),
						'other' => q({0} gal),
						'per' => q({0}/gal),
					},
					# Core Unit Identifier
					'gallon' => {
						'few' => q({0} gal),
						'many' => q({0} gal),
						'name' => q(gal),
						'one' => q({0} gal),
						'other' => q({0} gal),
						'per' => q({0}/gal),
					},
					# Long Unit Identifier
					'volume-gallon-imperial' => {
						'few' => q({0} imp. galonai),
						'many' => q({0} imp. galono),
						'name' => q(imp. galonas),
						'one' => q({0} imp. galonas),
						'other' => q({0} imp. galonų),
						'per' => q({0}/imp. galone),
					},
					# Core Unit Identifier
					'gallon-imperial' => {
						'few' => q({0} imp. galonai),
						'many' => q({0} imp. galono),
						'name' => q(imp. galonas),
						'one' => q({0} imp. galonas),
						'other' => q({0} imp. galonų),
						'per' => q({0}/imp. galone),
					},
					# Long Unit Identifier
					'volume-hectoliter' => {
						'few' => q({0} hl),
						'many' => q({0} hl),
						'name' => q(hl),
						'one' => q({0} hl),
						'other' => q({0} hl),
					},
					# Core Unit Identifier
					'hectoliter' => {
						'few' => q({0} hl),
						'many' => q({0} hl),
						'name' => q(hl),
						'one' => q({0} hl),
						'other' => q({0} hl),
					},
					# Long Unit Identifier
					'volume-jigger' => {
						'few' => q({0} džigeriai),
						'many' => q({0} džigerio),
						'name' => q(džigeris),
						'one' => q({0} džigeris),
						'other' => q({0} džigerio),
					},
					# Core Unit Identifier
					'jigger' => {
						'few' => q({0} džigeriai),
						'many' => q({0} džigerio),
						'name' => q(džigeris),
						'one' => q({0} džigeris),
						'other' => q({0} džigerio),
					},
					# Long Unit Identifier
					'volume-liter' => {
						'name' => q(litrai),
					},
					# Core Unit Identifier
					'liter' => {
						'name' => q(litrai),
					},
					# Long Unit Identifier
					'volume-megaliter' => {
						'few' => q({0} Ml),
						'many' => q({0} Ml),
						'name' => q(Ml),
						'one' => q({0} Ml),
						'other' => q({0} Ml),
					},
					# Core Unit Identifier
					'megaliter' => {
						'few' => q({0} Ml),
						'many' => q({0} Ml),
						'name' => q(Ml),
						'one' => q({0} Ml),
						'other' => q({0} Ml),
					},
					# Long Unit Identifier
					'volume-milliliter' => {
						'few' => q({0} ml),
						'many' => q({0} ml),
						'name' => q(ml),
						'one' => q({0} ml),
						'other' => q({0} ml),
					},
					# Core Unit Identifier
					'milliliter' => {
						'few' => q({0} ml),
						'many' => q({0} ml),
						'name' => q(ml),
						'one' => q({0} ml),
						'other' => q({0} ml),
					},
					# Long Unit Identifier
					'volume-pinch' => {
						'few' => q({0} žiupsn.),
						'many' => q({0} žiupsn.),
						'name' => q(žiupsn.),
						'one' => q({0} žiupsn.),
						'other' => q({0} žiupsn.),
					},
					# Core Unit Identifier
					'pinch' => {
						'few' => q({0} žiupsn.),
						'many' => q({0} žiupsn.),
						'name' => q(žiupsn.),
						'one' => q({0} žiupsn.),
						'other' => q({0} žiupsn.),
					},
					# Long Unit Identifier
					'volume-pint' => {
						'name' => q(pintos),
					},
					# Core Unit Identifier
					'pint' => {
						'name' => q(pintos),
					},
					# Long Unit Identifier
					'volume-quart' => {
						'few' => q({0} kvortos),
						'many' => q({0} kvortos),
						'name' => q(kvortos),
						'one' => q({0} kvorta),
						'other' => q({0} kvortų),
					},
					# Core Unit Identifier
					'quart' => {
						'few' => q({0} kvortos),
						'many' => q({0} kvortos),
						'name' => q(kvortos),
						'one' => q({0} kvorta),
						'other' => q({0} kvortų),
					},
					# Long Unit Identifier
					'volume-quart-imperial' => {
						'few' => q({0} imp. kv.),
						'many' => q({0} imp. kv.),
						'name' => q(imp. kv.),
						'one' => q({0} imp. kv.),
						'other' => q({0} imp. kv.),
					},
					# Core Unit Identifier
					'quart-imperial' => {
						'few' => q({0} imp. kv.),
						'many' => q({0} imp. kv.),
						'name' => q(imp. kv.),
						'one' => q({0} imp. kv.),
						'other' => q({0} imp. kv.),
					},
					# Long Unit Identifier
					'volume-tablespoon' => {
						'few' => q({0} v. š.),
						'many' => q({0} v. š.),
						'name' => q(v. š.),
						'one' => q({0} v. š.),
						'other' => q({0} v. š.),
					},
					# Core Unit Identifier
					'tablespoon' => {
						'few' => q({0} v. š.),
						'many' => q({0} v. š.),
						'name' => q(v. š.),
						'one' => q({0} v. š.),
						'other' => q({0} v. š.),
					},
					# Long Unit Identifier
					'volume-teaspoon' => {
						'few' => q({0} a. š.),
						'many' => q({0} a. š.),
						'name' => q(a. š.),
						'one' => q({0} a. š.),
						'other' => q({0} a. š.),
					},
					# Core Unit Identifier
					'teaspoon' => {
						'few' => q({0} a. š.),
						'many' => q({0} a. š.),
						'name' => q(a. š.),
						'one' => q({0} a. š.),
						'other' => q({0} a. š.),
					},
				},
			} }
);

has 'yesstr' => (
	is			=> 'ro',
	isa			=> RegexpRef,
	init_arg	=> undef,
	default		=> sub { qr'^(?i:taip|t|yes|y)$' }
);

has 'nostr' => (
	is			=> 'ro',
	isa			=> RegexpRef,
	init_arg	=> undef,
	default		=> sub { qr'^(?i:ne|n)$' }
);

has 'listPatterns' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
				end => q({0} ir {1}),
				2 => q({0} ir {1}),
		} }
);

has 'number_symbols' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'latn' => {
			'decimal' => q(,),
			'exponential' => q(×10^),
			'group' => q( ),
			'minusSign' => q(−),
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
					'few' => '0 tūkstančiai',
					'many' => '0 tūkstančio',
					'one' => '0 tūkstantis',
					'other' => '0 tūkstančių',
				},
				'10000' => {
					'few' => '00 tūkstančiai',
					'many' => '00 tūkstančio',
					'one' => '00 tūkstantis',
					'other' => '00 tūkstančių',
				},
				'100000' => {
					'few' => '000 tūkstančiai',
					'many' => '000 tūkstančio',
					'one' => '000 tūkstantis',
					'other' => '000 tūkstančių',
				},
				'1000000' => {
					'few' => '0 milijonai',
					'many' => '0 milijono',
					'one' => '0 milijonas',
					'other' => '0 milijonų',
				},
				'10000000' => {
					'few' => '00 milijonai',
					'many' => '00 milijono',
					'one' => '00 milijonas',
					'other' => '00 milijonų',
				},
				'100000000' => {
					'few' => '000 milijonai',
					'many' => '000 milijono',
					'one' => '000 milijonas',
					'other' => '000 milijonų',
				},
				'1000000000' => {
					'few' => '0 milijardai',
					'many' => '0 milijardo',
					'one' => '0 milijardas',
					'other' => '0 milijardų',
				},
				'10000000000' => {
					'few' => '00 milijardai',
					'many' => '00 milijardo',
					'one' => '00 milijardas',
					'other' => '00 milijardų',
				},
				'100000000000' => {
					'few' => '000 milijardai',
					'many' => '000 milijardo',
					'one' => '000 milijardas',
					'other' => '000 milijardų',
				},
				'1000000000000' => {
					'few' => '0 trilijonai',
					'many' => '0 trilijono',
					'one' => '0 trilijonas',
					'other' => '0 trilijonų',
				},
				'10000000000000' => {
					'few' => '00 trilijonai',
					'many' => '00 trilijono',
					'one' => '00 trilijonas',
					'other' => '00 trilijonų',
				},
				'100000000000000' => {
					'few' => '000 trilijonai',
					'many' => '000 trilijono',
					'one' => '000 trilijonas',
					'other' => '000 trilijonų',
				},
			},
			'short' => {
				'1000' => {
					'one' => '0 tūkst'.'',
					'other' => '0 tūkst'.'',
				},
				'10000' => {
					'one' => '00 tūkst'.'',
					'other' => '00 tūkst'.'',
				},
				'100000' => {
					'one' => '000 tūkst'.'',
					'other' => '000 tūkst'.'',
				},
				'1000000' => {
					'one' => '0 mln'.'',
					'other' => '0 mln'.'',
				},
				'10000000' => {
					'one' => '00 mln'.'',
					'other' => '00 mln'.'',
				},
				'100000000' => {
					'one' => '000 mln'.'',
					'other' => '000 mln'.'',
				},
				'1000000000' => {
					'one' => '0 mlrd'.'',
					'other' => '0 mlrd'.'',
				},
				'10000000000' => {
					'one' => '00 mlrd'.'',
					'other' => '00 mlrd'.'',
				},
				'100000000000' => {
					'one' => '000 mlrd'.'',
					'other' => '000 mlrd'.'',
				},
				'1000000000000' => {
					'one' => '0 trln'.'',
					'other' => '0 trln'.'',
				},
				'10000000000000' => {
					'one' => '00 trln'.'',
					'other' => '00 trln'.'',
				},
				'100000000000000' => {
					'one' => '000 trln'.'',
					'other' => '000 trln'.'',
				},
			},
		},
		percentFormat => {
			'default' => {
				'standard' => {
					'default' => '#,##0 %',
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
		'ADP' => {
			display_name => {
				'currency' => q(Andoros peseta),
				'few' => q(Andoros pesetos),
				'many' => q(Andoros pesetos),
				'one' => q(Andoros peseta),
				'other' => q(Andoros pesetos),
			},
		},
		'AED' => {
			display_name => {
				'currency' => q(Jungtinių Arabų Emyratų dirhamas),
				'few' => q(JAE dirhamai),
				'many' => q(JAE dirhamo),
				'one' => q(JAE dirhamas),
				'other' => q(JAE dirhamų),
			},
		},
		'AFA' => {
			display_name => {
				'currency' => q(Afganistano afganis \(1927–2002\)),
				'few' => q(Afganistano afganiai \(1927–2002\)),
				'many' => q(Afganistano afganio \(1927–2002\)),
				'one' => q(Afganistano afganis \(1927–2002\)),
				'other' => q(Afganistano afganių \(1927–2002\)),
			},
		},
		'AFN' => {
			display_name => {
				'currency' => q(Afganistano afganis),
				'few' => q(Afganistano afganiai),
				'many' => q(Afganistano afganio),
				'one' => q(Afganistano afganis),
				'other' => q(Afganistano afganių),
			},
		},
		'ALK' => {
			display_name => {
				'currency' => q(Albanijos lekas \(1946–1965\)),
				'few' => q(Albanijos lekai \(1946–1965\)),
				'many' => q(Albanijos leko \(1946–1965\)),
				'one' => q(Albanijos lekas \(1946–1965\)),
				'other' => q(Albanijos lekų \(1946–1965\)),
			},
		},
		'ALL' => {
			display_name => {
				'currency' => q(Albanijos lekas),
				'few' => q(Albanijos lekai),
				'many' => q(Albanijos leko),
				'one' => q(Albanijos lekas),
				'other' => q(Albanijos lekų),
			},
		},
		'AMD' => {
			display_name => {
				'currency' => q(Armėnijos dramas),
				'few' => q(Armėnijos dramai),
				'many' => q(Armėnijos dramo),
				'one' => q(Armėnijos dramas),
				'other' => q(Armėnijos dramų),
			},
		},
		'ANG' => {
			display_name => {
				'currency' => q(Olandijos Antilų guldenas),
				'few' => q(Olandijos Antilų guldenai),
				'many' => q(Olandijos Antilų guldeno),
				'one' => q(Olandijos Antilų guldenas),
				'other' => q(Olandijos Antilų guldenų),
			},
		},
		'AOA' => {
			display_name => {
				'currency' => q(Angolos kvanza),
				'few' => q(Angolos kvanzos),
				'many' => q(Angolos kvanzos),
				'one' => q(Angolos kvanza),
				'other' => q(Angolos kvanzų),
			},
		},
		'AOK' => {
			display_name => {
				'currency' => q(Angolos kvanza \(1977–1990\)),
				'few' => q(Angolos kvanzos \(1977–1990\)),
				'many' => q(Angolos kvanzos \(1977–1990\)),
				'one' => q(Angolos kvanza \(1977–1990\)),
				'other' => q(Angolos kvanzų \(1977–1990\)),
			},
		},
		'AON' => {
			display_name => {
				'currency' => q(Angolos naujoji kvanza \(1990–2000\)),
				'few' => q(Angolos naujosios kvanzos \(1990–2000\)),
				'many' => q(Angolos naujosios kvanzos \(1990–2000\)),
				'one' => q(Angolos naujoji kvanza \(1990–2000\)),
				'other' => q(Angolos naujųjų kvanzų \(1990–2000\)),
			},
		},
		'AOR' => {
			display_name => {
				'currency' => q(Angolos patikslinta kvanza \(1995–1999\)),
				'few' => q(Angolos patikslintos kvanzos \(1995–1999\)),
				'many' => q(Angolos patikslintos kvanzos \(1995–1999\)),
				'one' => q(Angolos patikslinta kvanza \(1995–1999\)),
				'other' => q(Angolos patikslintų kvanzų \(1995–1999\)),
			},
		},
		'ARA' => {
			display_name => {
				'currency' => q(Argentinos australs),
				'few' => q(Argentinos australs),
				'many' => q(Argentinos australs),
				'one' => q(Argentinos austral),
				'other' => q(Argentinos australs),
			},
		},
		'ARL' => {
			display_name => {
				'currency' => q(Argentinos pesos ley \(1970–1983\)),
			},
		},
		'ARM' => {
			display_name => {
				'currency' => q(Argentinos pesai \(1881–1970\)),
				'few' => q(Argentinos pesai \(1881–1970\)),
				'many' => q(Argentinos peso \(1881–1970\)),
				'one' => q(Argentinos pesas \(1881–1970\)),
				'other' => q(Argentinos pesų \(1881–1970\)),
			},
		},
		'ARP' => {
			display_name => {
				'currency' => q(Argentinos pesas \(1983–1985\)),
				'few' => q(Argentinos pesai \(1983–1985\)),
				'many' => q(Argentinos pesai \(1983–1985\)),
				'one' => q(Argentinos pesas \(1983–1985\)),
				'other' => q(Argentinos pesai \(1983–1985\)),
			},
		},
		'ARS' => {
			display_name => {
				'currency' => q(Argentinos pesas),
				'few' => q(Argentinos pesai),
				'many' => q(Argentinos peso),
				'one' => q(Argentinos pesas),
				'other' => q(Argentinos pesų),
			},
		},
		'ATS' => {
			display_name => {
				'currency' => q(Austrijos šilingas),
				'few' => q(Austrijos šilingai),
				'many' => q(Austrijos šilingo),
				'one' => q(Austrijos šilingas),
				'other' => q(Austrijos šilingų),
			},
		},
		'AUD' => {
			symbol => 'AUD',
			display_name => {
				'currency' => q(Australijos doleris),
				'few' => q(Australijos doleriai),
				'many' => q(Australijos dolerio),
				'one' => q(Australijos doleris),
				'other' => q(Australijos dolerių),
			},
		},
		'AWG' => {
			display_name => {
				'currency' => q(Arubos guldenas),
				'few' => q(Arubos guldenai),
				'many' => q(Arubos guldeno),
				'one' => q(Arubos guldenas),
				'other' => q(Arubos guldenų),
			},
		},
		'AZM' => {
			display_name => {
				'currency' => q(Azerbaidžano manatas \(1993–2006\)),
				'few' => q(Azerbaidžano manatai \(1993–2006\)),
				'many' => q(Azerbaidžano manato \(1993–2006\)),
				'one' => q(Azerbaidžano manatas \(1993–2006\)),
				'other' => q(Azerbaidžano manatų \(1993–2006\)),
			},
		},
		'AZN' => {
			display_name => {
				'currency' => q(Azerbaidžano manatas),
				'few' => q(Azerbaidžano manatai),
				'many' => q(Azerbaidžano manato),
				'one' => q(Azerbaidžano manatas),
				'other' => q(Azerbaidžano manatų),
			},
		},
		'BAD' => {
			display_name => {
				'currency' => q(Bosnijos ir Hercegovinos dinaras \(1992–1994\)),
				'few' => q(Bosnijos ir Hercegovinos dinarai \(1992–1994\)),
				'many' => q(Bosnijos ir Hercegovinos dinaro \(1992–1994\)),
				'one' => q(Bosnijos ir Hercegovinos dinaras \(1992–1994\)),
				'other' => q(Bosnijos ir Hercegovinos dinarų \(1992–1994\)),
			},
		},
		'BAM' => {
			display_name => {
				'currency' => q(Bosnijos ir Hercegovinos konvertuojamoji markė),
				'few' => q(Bosnijos ir Hercegovinos konvertuojamosios markės),
				'many' => q(Bosnijos ir Hercegovinos konvertuojamosios markės),
				'one' => q(Bosnijos ir Hercegovinos konvertuojamoji markė),
				'other' => q(Bosnijos ir Hercegovinos konvertuojamųjų markių),
			},
		},
		'BAN' => {
			display_name => {
				'currency' => q(Bosnijos ir Hercegovinos naujasis dinaras \(1994–1997\)),
				'few' => q(Bosnijos ir Hercegovinos naujieji dinarai \(1994–1997\)),
				'many' => q(Bosnijos ir Hercegovinos naujojo dinaro \(1994–1997\)),
				'one' => q(Bosnijos ir Hercegovinos naujasis dinaras \(1994–1997\)),
				'other' => q(Bosnijos ir Hercegovinos naujųjų dinarų \(1994–1997\)),
			},
		},
		'BBD' => {
			display_name => {
				'currency' => q(Barbadoso doleris),
				'few' => q(Barbadoso doleriai),
				'many' => q(Barbadoso dolerio),
				'one' => q(Barbadoso doleris),
				'other' => q(Barbadoso dolerių),
			},
		},
		'BDT' => {
			symbol => 'BDT',
			display_name => {
				'currency' => q(Bangladešo taka),
				'few' => q(Bangladešo takos),
				'many' => q(Bangladešo takos),
				'one' => q(Bangladešo taka),
				'other' => q(Bangladešo takų),
			},
		},
		'BEC' => {
			display_name => {
				'currency' => q(Belgijos frankas \(konvertuojamas\)),
				'few' => q(Belgijos frankai \(konvertuojami\)),
				'many' => q(Belgijos franko \(konvertuojamo\)),
				'one' => q(Belgijos frankas \(konvertuojamas\)),
				'other' => q(Belgijos frankų \(konvertuojamų\)),
			},
		},
		'BEF' => {
			display_name => {
				'currency' => q(Belgijos frankas),
				'few' => q(Belgijos frankai),
				'many' => q(Belgijos franko),
				'one' => q(Belgijos frankas),
				'other' => q(Belgijos frankų),
			},
		},
		'BEL' => {
			display_name => {
				'currency' => q(Belgijos frankas \(finansinis\)),
				'few' => q(Belgijos frankai \(finansiniai\)),
				'many' => q(Belgijos franko \(finansinio\)),
				'one' => q(Belgijos frankas \(finansinis\)),
				'other' => q(Belgijos frankų \(finansinių\)),
			},
		},
		'BGL' => {
			display_name => {
				'currency' => q(Bulgarijos levas \(1962–1999\)),
				'few' => q(Bulgarijos levai \(1962–1999\)),
				'many' => q(Bulgarijos levo \(1962–1999\)),
				'one' => q(Bulgarijos levas \(1962–1999\)),
				'other' => q(Bulgarijos levų \(1962–1999\)),
			},
		},
		'BGM' => {
			display_name => {
				'currency' => q(Bulgarų socialistų leva),
				'few' => q(Bulgarų socialistų leva),
				'many' => q(Bulgarų socialistų leva),
				'one' => q(Bulgarų socialistų lev),
				'other' => q(Bulgarų socialistų leva),
			},
		},
		'BGN' => {
			display_name => {
				'currency' => q(Bulgarijos levas),
				'few' => q(Bulgarijos levai),
				'many' => q(Bulgarijos levo),
				'one' => q(Bulgarijos levas),
				'other' => q(Bulgarijos levų),
			},
		},
		'BGO' => {
			display_name => {
				'currency' => q(Bulgarijos levas \(1879–1952\)),
				'few' => q(Bulgarijos levai \(1879–1952\)),
				'many' => q(Bulgarijos levo \(1879–1952\)),
				'one' => q(Bulgarijos levas \(1879–1952\)),
				'other' => q(Bulgarijos levų \(1879–1952\)),
			},
		},
		'BHD' => {
			display_name => {
				'currency' => q(Bahreino dinaras),
				'few' => q(Bahreino dinarai),
				'many' => q(Bahreino dinaro),
				'one' => q(Bahreino dinaras),
				'other' => q(Bahreino dinarų),
			},
		},
		'BIF' => {
			display_name => {
				'currency' => q(Burundžio frankas),
				'few' => q(Burundžio frankai),
				'many' => q(Burundžio franko),
				'one' => q(Burundžio frankas),
				'other' => q(Burundžio frankų),
			},
		},
		'BMD' => {
			display_name => {
				'currency' => q(Bermudos doleris),
				'few' => q(Bermudos doleriai),
				'many' => q(Bermudos dolerio),
				'one' => q(Bermudos doleris),
				'other' => q(Bermudos dolerių),
			},
		},
		'BND' => {
			display_name => {
				'currency' => q(Brunėjaus doleris),
				'few' => q(Brunėjaus doleriai),
				'many' => q(Brunėjaus dolerio),
				'one' => q(Brunėjaus doleris),
				'other' => q(Brunėjaus dolerių),
			},
		},
		'BOB' => {
			display_name => {
				'currency' => q(Bolivijos bolivijanas),
				'few' => q(Bolivijos bolivijanai),
				'many' => q(Bolivijos bolivijano),
				'one' => q(Bolivijos bolivijanas),
				'other' => q(Bolivijos bolivijanų),
			},
		},
		'BOL' => {
			display_name => {
				'currency' => q(Bolivijos bolivijanas \(1863–1963\)),
				'few' => q(Bolivijos bolivijanai \(1863–1963\)),
				'many' => q(Bolivijos bolivijano \(1863–1963\)),
				'one' => q(Bolivijos bolivijanas \(1863–1963\)),
				'other' => q(Bolivijos bolivijanų \(1863–1963\)),
			},
		},
		'BOP' => {
			display_name => {
				'currency' => q(Bolivijos pesas),
				'few' => q(Bolivijos pesai),
				'many' => q(Bolivijos peso),
				'one' => q(Bolivijos pesas),
				'other' => q(Bolivijos pesų),
			},
		},
		'BOV' => {
			display_name => {
				'currency' => q(Bolivijos mvdol),
				'few' => q(Boliviečių mvdols),
				'many' => q(Bolivijos mvdol),
				'one' => q(Bolivijos mvdol),
				'other' => q(Bolivijos mvdol),
			},
		},
		'BRB' => {
			display_name => {
				'currency' => q(Brazilijos naujieji kruzeirai \(1967–1986\)),
				'few' => q(Brazilijos naujieji kruzeirai \(1967–1986\)),
				'many' => q(Brazilijos naujasis kruzeiro \(1967–1986\)),
				'one' => q(Brazilijos naujasis kruzeiras \(1967–1986\)),
				'other' => q(Brazilijos naujųjų kruzeirų \(1967–1986\)),
			},
		},
		'BRC' => {
			display_name => {
				'currency' => q(Brazilijos kruzadai \(1986–1989\)),
				'few' => q(Brazilijos kruzadai \(1986–1989\)),
				'many' => q(Brazilijos kruzado \(1986–1989\)),
				'one' => q(Brazilijos kruzadas \(1986–1989\)),
				'other' => q(Brazilijos kruzadų \(1986–1989\)),
			},
		},
		'BRE' => {
			display_name => {
				'currency' => q(Brazilijos kruzeiras \(1990–1993\)),
				'few' => q(Brazilijos kruzeirai \(1990–1993\)),
				'many' => q(Brazilijos kruzeirai \(1990–1993\)),
				'one' => q(Brazilijos kruzeiras \(1990–1993\)),
				'other' => q(Brazilijos kruzeirai \(1990–1993\)),
			},
		},
		'BRL' => {
			symbol => 'BRL',
			display_name => {
				'currency' => q(Brazilijos realas),
				'few' => q(Brazilijos realai),
				'many' => q(Brazilijos realo),
				'one' => q(Brazilijos realas),
				'other' => q(Brazilijos realų),
			},
		},
		'BRN' => {
			display_name => {
				'currency' => q(Brazilijos naujiejis kruzadai \(1989–1990\)),
				'few' => q(Brazilijos naujieji kruzadai \(1989–1990\)),
				'many' => q(Brazilijos naujojo kruzado \(1989–1990\)),
				'one' => q(Brazilijos naujasis kruzadas \(1989–1990\)),
				'other' => q(Brazilijos naujųjų kruzadų \(1989–1990\)),
			},
		},
		'BRR' => {
			display_name => {
				'currency' => q(Brazilijos kruzeiras \(1993–1994\)),
				'few' => q(Brazilijos kruzeirai \(1993–1994\)),
				'many' => q(Brazilijos kruzeiro \(1993–1994\)),
				'one' => q(Brazilijos kruzeiras \(1993–1994\)),
				'other' => q(Brazilijos kruzeirų \(1993–1994\)),
			},
		},
		'BRZ' => {
			display_name => {
				'currency' => q(Brazilijos kruzeirai \(1942–1967\)),
				'few' => q(Brazilijos kruzeirai \(1942–1967\)),
				'many' => q(Brazilijos kruzeiro \(1942–1967\)),
				'one' => q(Brazilijos kruzeiras \(1942–1967\)),
				'other' => q(Brazilijos kruzeirų \(1942–1967\)),
			},
		},
		'BSD' => {
			display_name => {
				'currency' => q(Bahamų doleris),
				'few' => q(Bahamų doleriai),
				'many' => q(Bahamų dolerio),
				'one' => q(Bahamų doleris),
				'other' => q(Bahamų dolerių),
			},
		},
		'BTN' => {
			display_name => {
				'currency' => q(Butano ngultrumas),
				'few' => q(Butano ngultrumai),
				'many' => q(Butano ngultrumo),
				'one' => q(Butano ngultrumas),
				'other' => q(Butano ngultrumų),
			},
		},
		'BUK' => {
			display_name => {
				'currency' => q(Birmos kijatas),
				'few' => q(Birmos kijatai),
				'many' => q(Birmos kijato),
				'one' => q(Birmos kijatas),
				'other' => q(Birmos kijatų),
			},
		},
		'BWP' => {
			display_name => {
				'currency' => q(Botsvanos pula),
				'few' => q(Botsvanos pulos),
				'many' => q(Botsvanos pulos),
				'one' => q(Botsvanos pula),
				'other' => q(Botsvanos pulų),
			},
		},
		'BYB' => {
			display_name => {
				'currency' => q(Baltarusijos naujasis rublis \(1994–1999\)),
				'few' => q(Baltarusijos naujieji rubliai \(1994–1999\)),
				'many' => q(Baltarusijos naujojo rublio \(1994–1999\)),
				'one' => q(Baltarusijos naujasis rublis \(1994–1999\)),
				'other' => q(Baltarusijos naujųjų rublių),
			},
		},
		'BYN' => {
			symbol => 'Br',
			display_name => {
				'currency' => q(Baltarusijos rublis),
				'few' => q(Baltarusijos rubliai),
				'many' => q(Baltarusijos rublio),
				'one' => q(Baltarusijos rublis),
				'other' => q(Baltarusijos rublių),
			},
		},
		'BYR' => {
			display_name => {
				'currency' => q(Baltarusijos rublis \(2000–2016\)),
				'few' => q(Baltarusijos rubliai \(2000–2016\)),
				'many' => q(Baltarusijos rublio \(2000–2016\)),
				'one' => q(Baltarusijos rublis \(2000–2016\)),
				'other' => q(Baltarusijos rublių \(2000–2016\)),
			},
		},
		'BZD' => {
			display_name => {
				'currency' => q(Belizo doleris),
				'few' => q(Belizo doleriai),
				'many' => q(Belizo dolerio),
				'one' => q(Belizo doleris),
				'other' => q(Belizo dolerių),
			},
		},
		'CAD' => {
			symbol => 'CAD',
			display_name => {
				'currency' => q(Kanados doleris),
				'few' => q(Kanados doleriai),
				'many' => q(Kanados dolerio),
				'one' => q(Kanados doleris),
				'other' => q(Kanados dolerių),
			},
		},
		'CDF' => {
			display_name => {
				'currency' => q(Kongo frankas),
				'few' => q(Kongo frankai),
				'many' => q(Kongo franko),
				'one' => q(Kongo frankas),
				'other' => q(Kongo frankų),
			},
		},
		'CHE' => {
			display_name => {
				'currency' => q(WIR eurai),
				'few' => q(WIR eurai),
				'many' => q(WIR euro),
				'one' => q(WIR euras),
				'other' => q(WIR eurų),
			},
		},
		'CHF' => {
			display_name => {
				'currency' => q(Šveicarijos frankas),
				'few' => q(Šveicarijos frankai),
				'many' => q(Šveicarijos franko),
				'one' => q(Šveicarijos frankas),
				'other' => q(Šveicarijos frankų),
			},
		},
		'CHW' => {
			display_name => {
				'currency' => q(WIR frankas),
				'few' => q(WIR frankai),
				'many' => q(WIR franko),
				'one' => q(WIR frankas),
				'other' => q(WIR frankų),
			},
		},
		'CLE' => {
			display_name => {
				'currency' => q(Čilės eskudai),
				'few' => q(Čilės eskudai),
				'many' => q(Čilės eskudo),
				'one' => q(Čilės eskudas),
				'other' => q(Čilės eskudų),
			},
		},
		'CLF' => {
			display_name => {
				'currency' => q(Čiliečių unidades de fomentos),
			},
		},
		'CLP' => {
			display_name => {
				'currency' => q(Čilės pesas),
				'few' => q(Čilės pesai),
				'many' => q(Čilės peso),
				'one' => q(Čilės pesas),
				'other' => q(Čilės pesų),
			},
		},
		'CNH' => {
			display_name => {
				'currency' => q(Kinijos Užsienio juanis),
				'few' => q(Kinijos Užsienio juaniai),
				'many' => q(Kinijos Užsienio juanio),
				'one' => q(Kinijos Užsienio juanis),
				'other' => q(Kinijos Užsienio juanių),
			},
		},
		'CNX' => {
			display_name => {
				'currency' => q(Kinijos "People" banko doleris),
				'few' => q(Kinijos "People" banko doleriai),
				'many' => q(Kinijos "People" banko dolerio),
				'one' => q(Kinijos "People" banko doleris),
				'other' => q(Kinijos "People" banko dolerių),
			},
		},
		'CNY' => {
			symbol => 'CNY',
			display_name => {
				'currency' => q(Kinijos ženminbi juanis),
				'few' => q(Kinijos ženminbi juaniai),
				'many' => q(Kinijos ženminbi juanio),
				'one' => q(Kinijos ženminbi juanis),
				'other' => q(Kinijos ženminbi juanių),
			},
		},
		'COP' => {
			display_name => {
				'currency' => q(Kolumbijos pesas),
				'few' => q(Kolumbijos pesai),
				'many' => q(Kolumbijos peso),
				'one' => q(Kolumbijos pesas),
				'other' => q(Kolumbijos pesų),
			},
		},
		'COU' => {
			display_name => {
				'currency' => q(unidad de valor realai),
				'few' => q(unidad de valor realai),
				'many' => q(unidad de valor realai),
				'one' => q(unidad de valor realas),
				'other' => q(unidad de valor realai),
			},
		},
		'CRC' => {
			display_name => {
				'currency' => q(Kosta Rikos kolonas),
				'few' => q(Kosta Rikos kolonai),
				'many' => q(Kosta Rikos kolono),
				'one' => q(Kosta Rikos kolonas),
				'other' => q(Kosta Rikos kolonų),
			},
		},
		'CSD' => {
			display_name => {
				'currency' => q(Serbijos dinaras \(2002–2006\)),
				'few' => q(Serbijos dinarai \(2002–2006\)),
				'many' => q(Serbijos dinaro \(2002–2006\)),
				'one' => q(Serbijos dinaras \(2002–2006\)),
				'other' => q(Serbijos dinarų \(2002–2006\)),
			},
		},
		'CSK' => {
			display_name => {
				'currency' => q(Čekoslovakų sunkusis korunas),
				'few' => q(Čekoslovakų sunkieji korunai),
				'many' => q(Čekoslovakų sunkiejio koruno),
				'one' => q(Čekoslovakų sunkusis korunas),
				'other' => q(Čekoslovakų sunkiejių korunų),
			},
		},
		'CUC' => {
			display_name => {
				'currency' => q(Kubos konvertuojamasis pesas),
				'few' => q(Kubos konvertuojamieji pesai),
				'many' => q(Kubos konvertuojamojo peso),
				'one' => q(Kubos konvertuojamasis pesas),
				'other' => q(Kubos konvertuojamųjų pesų),
			},
		},
		'CUP' => {
			display_name => {
				'currency' => q(Kubos pesas),
				'few' => q(Kubos pesai),
				'many' => q(Kubos peso),
				'one' => q(Kubos pesas),
				'other' => q(Kubos pesų),
			},
		},
		'CVE' => {
			display_name => {
				'currency' => q(Žaliojo Kyšulio eskudas),
				'few' => q(Žaliojo Kyšulio eskudai),
				'many' => q(Žaliojo Kyšulio eskudo),
				'one' => q(Žaliojo Kyšulio eskudas),
				'other' => q(Žaliojo Kyšulio eskudų),
			},
		},
		'CYP' => {
			display_name => {
				'currency' => q(Kipro svaras),
				'few' => q(Kipro svarai),
				'many' => q(Kipro svaro),
				'one' => q(Kipro svaras),
				'other' => q(Kipro svarų),
			},
		},
		'CZK' => {
			display_name => {
				'currency' => q(Čekijos krona),
				'few' => q(Čekijos kronos),
				'many' => q(Čekijos kronos),
				'one' => q(Čekijos krona),
				'other' => q(Čekijos kronų),
			},
		},
		'DDM' => {
			display_name => {
				'currency' => q(Rytų Vokietijos markė),
				'few' => q(Rytų Vokietijos markės),
				'many' => q(Rytų Vokietijos markės),
				'one' => q(Rytų Vokietijos markė),
				'other' => q(Rytų Vokietijos markės),
			},
		},
		'DEM' => {
			display_name => {
				'currency' => q(Vokietijos markė),
				'few' => q(Vokietijos markės),
				'many' => q(Vokietijos markės),
				'one' => q(Vokietijos markė),
				'other' => q(Vokietijos markės),
			},
		},
		'DJF' => {
			display_name => {
				'currency' => q(Džibučio frankas),
				'few' => q(Džibučio frankai),
				'many' => q(Džibučio franko),
				'one' => q(Džibučio frankas),
				'other' => q(Džibučio frankų),
			},
		},
		'DKK' => {
			display_name => {
				'currency' => q(Danijos krona),
				'few' => q(Danijos kronos),
				'many' => q(Danijos kronos),
				'one' => q(Danijos krona),
				'other' => q(Danijos kronų),
			},
		},
		'DOP' => {
			display_name => {
				'currency' => q(Dominikos pesas),
				'few' => q(Dominikos pesai),
				'many' => q(Dominikos peso),
				'one' => q(Dominikos pesas),
				'other' => q(Dominikos pesų),
			},
		},
		'DZD' => {
			display_name => {
				'currency' => q(Alžyro dinaras),
				'few' => q(Alžyro dinarai),
				'many' => q(Alžyro dinaro),
				'one' => q(Alžyro dinaras),
				'other' => q(Alžyro dinarų),
			},
		},
		'ECS' => {
			display_name => {
				'currency' => q(Ekvadoro sukrė),
				'few' => q(Ekvadoro sucres),
				'many' => q(Ekvadoro sucres),
				'one' => q(Ekvadoro sucre),
				'other' => q(Ekvadoro sucres),
			},
		},
		'ECV' => {
			display_name => {
				'currency' => q(Ekvadoro constante \(UVC\)),
				'few' => q(Ekvadoro unidads de narsa Constante \(UVC\)),
				'many' => q(Ekvadoro unidads de narsa Constante \(UVC\)),
				'one' => q(Ekvadoro unidads de narsa Constante \(UVC\)),
				'other' => q(Ekvadoro unidads de narsa Constante \(UVC\)),
			},
		},
		'EEK' => {
			display_name => {
				'currency' => q(Estijos krona),
				'few' => q(Estijos kronos),
				'many' => q(Estijos kronos),
				'one' => q(Estijos krona),
				'other' => q(Estijos kronų),
			},
		},
		'EGP' => {
			display_name => {
				'currency' => q(Egipto svaras),
				'few' => q(Egipto svarai),
				'many' => q(Egipto svaro),
				'one' => q(Egipto svaras),
				'other' => q(Egipto svarų),
			},
		},
		'ERN' => {
			display_name => {
				'currency' => q(Eritrėjos nakfa),
				'few' => q(Eritrėjos nakfos),
				'many' => q(Eritrėjos nakfos),
				'one' => q(Eritrėjos nakfa),
				'other' => q(Eritrėjos nakfų),
			},
		},
		'ESA' => {
			display_name => {
				'currency' => q(Ispanų pesetai \(A sąskaita\)),
				'few' => q(Ispanų pesetai \(A sąskaita\)),
				'many' => q(Ispanų pesetai \(A sąskaita\)),
				'one' => q(Ispanų pesetas \(A sąskaita\)),
				'other' => q(Ispanų pesetai \(A sąskaita\)),
			},
		},
		'ESB' => {
			display_name => {
				'currency' => q(Ispanų pesetai \(konvertuojama sąskaita\)),
				'few' => q(Ispanų pesetai \(konvertuojama sąskaita\)),
				'many' => q(Ispanų pesetai \(konvertuojama sąskaita\)),
				'one' => q(Ispanų pesetas \(konvertuojama sąskaita\)),
				'other' => q(Ispanų pesetai \(konvertuojama sąskaita\)),
			},
		},
		'ESP' => {
			display_name => {
				'currency' => q(Ispanijos peseta),
				'few' => q(Ispanų pesetai),
				'many' => q(Ispanų pesetai),
				'one' => q(Ispanų pesetas),
				'other' => q(Ispanų pesetai),
			},
		},
		'ETB' => {
			display_name => {
				'currency' => q(Etiopijos biras),
				'few' => q(Etiopijos birai),
				'many' => q(Etiopijos biro),
				'one' => q(Etiopijos biras),
				'other' => q(Etiopijos birų),
			},
		},
		'EUR' => {
			display_name => {
				'currency' => q(Euras),
				'few' => q(eurai),
				'many' => q(euro),
				'one' => q(euras),
				'other' => q(eurų),
			},
		},
		'FIM' => {
			display_name => {
				'currency' => q(Suomijos markė),
				'few' => q(Suomijos markės),
				'many' => q(Suomijos markės),
				'one' => q(Suomijos markė),
				'other' => q(Suomijos markės),
			},
		},
		'FJD' => {
			display_name => {
				'currency' => q(Fidžio doleris),
				'few' => q(Fidžio doleriai),
				'many' => q(Fidžio dolerio),
				'one' => q(Fidžio doleris),
				'other' => q(Fidžio dolerių),
			},
		},
		'FKP' => {
			display_name => {
				'currency' => q(Falklando salų svaras),
				'few' => q(Falklando salų svarai),
				'many' => q(Falklando salų svaro),
				'one' => q(Falklando salų svaras),
				'other' => q(Falklando salų svarų),
			},
		},
		'FRF' => {
			display_name => {
				'currency' => q(Prancūzijos frankas),
				'few' => q(Prancūzijos frankai),
				'many' => q(Prancūzijos franko),
				'one' => q(Prancūzijos frankas),
				'other' => q(Prancūzijos frankų),
			},
		},
		'GBP' => {
			symbol => 'GBP',
			display_name => {
				'currency' => q(Didžiosios Britanijos svaras),
				'few' => q(Didžiosios Britanijos svarai),
				'many' => q(Didžiosios Britanijos svaro),
				'one' => q(Didžiosios Britanijos svaras),
				'other' => q(Didžiosios Britanijos svarų),
			},
		},
		'GEK' => {
			display_name => {
				'currency' => q(Gruzinų kupon larits),
				'few' => q(Gruzinų kupon larits),
				'many' => q(Gruzinų kupon larits),
				'one' => q(Gruzinų kupon larit),
				'other' => q(Gruzinų kupon larits),
			},
		},
		'GEL' => {
			display_name => {
				'currency' => q(Gruzijos laris),
				'few' => q(Gruzijos lariai),
				'many' => q(Gruzijos lario),
				'one' => q(Gruzijos laris),
				'other' => q(Gruzijos larių),
			},
		},
		'GHC' => {
			display_name => {
				'currency' => q(Ganos sedis \(1979–2007\)),
				'few' => q(Ganos sedžiai \(1979–2007\)),
				'many' => q(Ganos sedžio \(1979–2007\)),
				'one' => q(Ganos sedis \(1979–2007\)),
				'other' => q(Ganos sedžių \(1979–2007\)),
			},
		},
		'GHS' => {
			display_name => {
				'currency' => q(Ganos sedis),
				'few' => q(Ganos sedžiai),
				'many' => q(Ganos sedžio),
				'one' => q(Ganos sedis),
				'other' => q(Ganos sedžių),
			},
		},
		'GIP' => {
			display_name => {
				'currency' => q(Gibraltaro svaras),
				'few' => q(Gibraltaro svarai),
				'many' => q(Gibraltaro svaro),
				'one' => q(Gibraltaro svaras),
				'other' => q(Gibraltaro svarų),
			},
		},
		'GMD' => {
			display_name => {
				'currency' => q(Gambijos dalasis),
				'few' => q(Gambijos dalasiai),
				'many' => q(Gambijos dalasio),
				'one' => q(Gambijos dalasis),
				'other' => q(Gambijos dalasių),
			},
		},
		'GNF' => {
			display_name => {
				'currency' => q(Gvinėjos frankas),
				'few' => q(Gvinėjos frankai),
				'many' => q(Gvinėjos franko),
				'one' => q(Gvinėjos frankas),
				'other' => q(Gvinėjos frankų),
			},
		},
		'GNS' => {
			display_name => {
				'currency' => q(Guinean sylis),
				'few' => q(Gvinėjos syliai),
				'many' => q(Gvinėjos sylio),
				'one' => q(Gvinėjos sylis),
				'other' => q(Gvinėjos sylio),
			},
		},
		'GQE' => {
			display_name => {
				'currency' => q(Pusiaujo Guinean ekwele),
			},
		},
		'GRD' => {
			display_name => {
				'currency' => q(Graikijos drachma),
				'few' => q(Graikijos drachmos),
				'many' => q(Graikijos drachmos),
				'one' => q(Graikijos drachma),
				'other' => q(Graikijos drachmos),
			},
		},
		'GTQ' => {
			display_name => {
				'currency' => q(Gvatemalos ketcalis),
				'few' => q(Gvatemalos ketcaliai),
				'many' => q(Gvatemalos ketcalio),
				'one' => q(Gvatemalos ketcalis),
				'other' => q(Gvatemalos ketcalių),
			},
		},
		'GWE' => {
			display_name => {
				'currency' => q(Portugalų Gvinėjos eskudas),
				'few' => q(Portugalijos Gvinėjos eskudai),
				'many' => q(Portugalijos Gvinėjos eskudo),
				'one' => q(Portugalijos Gvinėjos eskudas),
				'other' => q(Portugalijos Gvinėjos eskudų),
			},
		},
		'GWP' => {
			display_name => {
				'currency' => q(Gvinėjos-Bisau pesas),
				'few' => q(Bisau Gvinėjos pesai),
				'many' => q(Bisau Gvinėjos peso),
				'one' => q(Bisau Gvinėjos pesas),
				'other' => q(Bisau Gvinėjos pesai),
			},
		},
		'GYD' => {
			display_name => {
				'currency' => q(Gajanos doleris),
				'few' => q(Gajanos doleriai),
				'many' => q(Gajanos dolerio),
				'one' => q(Gajanos doleris),
				'other' => q(Gajanos dolerių),
			},
		},
		'HKD' => {
			symbol => 'HKD',
			display_name => {
				'currency' => q(Honkongo doleris),
				'few' => q(Honkongo doleriai),
				'many' => q(Honkongo dolerio),
				'one' => q(Honkongo doleris),
				'other' => q(Honkongo dolerių),
			},
		},
		'HNL' => {
			display_name => {
				'currency' => q(Hondūro lempira),
				'few' => q(Hondūro lempiros),
				'many' => q(Hondūro lempiros),
				'one' => q(Hondūro lempira),
				'other' => q(Hondūro lempirų),
			},
		},
		'HRD' => {
			display_name => {
				'currency' => q(Kroatijos dinaras),
				'few' => q(Krotaijos dinarai),
				'many' => q(Kroatijos dinaro),
				'one' => q(Kroatijos dinaras),
				'other' => q(Kroatijos dinarų),
			},
		},
		'HRK' => {
			display_name => {
				'currency' => q(Kroatijos kuna),
				'few' => q(Kroatijos kunos),
				'many' => q(Kroatijos kunos),
				'one' => q(Kroatijos kuna),
				'other' => q(Kroatijos kunų),
			},
		},
		'HTG' => {
			display_name => {
				'currency' => q(Haičio gurdas),
				'few' => q(Haičio gurdai),
				'many' => q(Haičio gurdo),
				'one' => q(Haičio gurdas),
				'other' => q(Haičio gurdų),
			},
		},
		'HUF' => {
			display_name => {
				'currency' => q(Vengrijos forintas),
				'few' => q(Vengrijos forintai),
				'many' => q(Vengrijos forinto),
				'one' => q(Vengrijos forintas),
				'other' => q(Vengrijos forintų),
			},
		},
		'IDR' => {
			display_name => {
				'currency' => q(Indonezijos rupija),
				'few' => q(Indonezijos rupijos),
				'many' => q(Indonezijos rupijos),
				'one' => q(Indonezijos rupija),
				'other' => q(Indonezijos rupijų),
			},
		},
		'IEP' => {
			display_name => {
				'currency' => q(Airijos svaras),
				'few' => q(Airijos svarai),
				'many' => q(Airijos svaro),
				'one' => q(Airijos svaras),
				'other' => q(Airijos svarų),
			},
		},
		'ILP' => {
			display_name => {
				'currency' => q(Izraelio svaras),
				'few' => q(Izraelio svarai),
				'many' => q(Izraelio svaro),
				'one' => q(Izraelio svaras),
				'other' => q(Izraelio svarų),
			},
		},
		'ILR' => {
			display_name => {
				'currency' => q(Izraelio šekelis \(1980–1985\)),
				'few' => q(Izraelio šekeliai \(1980–1985\)),
				'many' => q(Izraelio šekelio \(1980–1985\)),
				'one' => q(Izraelio šekelis \(1980–1985\)),
				'other' => q(Izraelio šekelių \(1980–1985\)),
			},
		},
		'ILS' => {
			symbol => 'ILS',
			display_name => {
				'currency' => q(Izraelio naujasis šekelis),
				'few' => q(Izraelio naujieji šekeliai),
				'many' => q(Izraelio naujojo šekelio),
				'one' => q(Izraelio naujasis šekelis),
				'other' => q(Izraelio naujųjų šekelių),
			},
		},
		'INR' => {
			symbol => 'INR',
			display_name => {
				'currency' => q(Indijos rupija),
				'few' => q(Indijos rupijos),
				'many' => q(Indijos rupijos),
				'one' => q(Indijos rupija),
				'other' => q(Indijos rupijų),
			},
		},
		'IQD' => {
			display_name => {
				'currency' => q(Irako dinaras),
				'few' => q(Irako dinarai),
				'many' => q(Irako dinaro),
				'one' => q(Irako dinaras),
				'other' => q(Irako dinarų),
			},
		},
		'IRR' => {
			display_name => {
				'currency' => q(Irano rialas),
				'few' => q(Irano rialai),
				'many' => q(Irano rialo),
				'one' => q(Irano rialas),
				'other' => q(Irano rialų),
			},
		},
		'ISJ' => {
			display_name => {
				'currency' => q(Islandijos krona \(1918–1981\)),
				'few' => q(Islandijos kronos \(1918–1981\)),
				'many' => q(Islandijos kronos \(1918–1981\)),
				'one' => q(Islandijos krona \(1918–1981\)),
				'other' => q(Islandijos kronų \(1918–1981\)),
			},
		},
		'ISK' => {
			display_name => {
				'currency' => q(Islandijos krona),
				'few' => q(Islandijos kronos),
				'many' => q(Islandijos kronos),
				'one' => q(Islandijos krona),
				'other' => q(Islandijos kronų),
			},
		},
		'ITL' => {
			display_name => {
				'currency' => q(Italijos lira),
				'few' => q(Italijos liros),
				'many' => q(Italijos liros),
				'one' => q(Italijos lira),
				'other' => q(Italijos lirų),
			},
		},
		'JMD' => {
			display_name => {
				'currency' => q(Jamaikos doleris),
				'few' => q(Jamaikos doleriai),
				'many' => q(Jamaikos dolerio),
				'one' => q(Jamaikos doleris),
				'other' => q(Jamaikos dolerių),
			},
		},
		'JOD' => {
			display_name => {
				'currency' => q(Jordanijos dinaras),
				'few' => q(Jordanijos dinarai),
				'many' => q(Jordanijos dinaro),
				'one' => q(Jordanijos dinaras),
				'other' => q(Jordanijos dinarų),
			},
		},
		'JPY' => {
			symbol => 'JPY',
			display_name => {
				'currency' => q(Japonijos jena),
				'few' => q(Japonijos jenos),
				'many' => q(Japonijos jenos),
				'one' => q(Japonijos jena),
				'other' => q(Japonijos jenų),
			},
		},
		'KES' => {
			display_name => {
				'currency' => q(Kenijos šilingas),
				'few' => q(Kenijos šilingai),
				'many' => q(Kenijos šilingo),
				'one' => q(Kenijos šilingas),
				'other' => q(Kenijos šilingų),
			},
		},
		'KGS' => {
			display_name => {
				'currency' => q(Kirgizijos somas),
				'few' => q(Kirgizijos somai),
				'many' => q(Kirgizijos somo),
				'one' => q(Kirgizijos somas),
				'other' => q(Kirgizijos somų),
			},
		},
		'KHR' => {
			symbol => 'KHR',
			display_name => {
				'currency' => q(Kambodžos rielis),
				'few' => q(Kambodžos rieliai),
				'many' => q(Kambodžos rielio),
				'one' => q(Kambodžos rielis),
				'other' => q(Kambodžos rielių),
			},
		},
		'KMF' => {
			display_name => {
				'currency' => q(Komoro frankas),
				'few' => q(Komoro frankai),
				'many' => q(Komoro franko),
				'one' => q(Komoro frankas),
				'other' => q(Komoro frankų),
			},
		},
		'KPW' => {
			display_name => {
				'currency' => q(Šiaurės Korėjos vonas),
				'few' => q(Šiaurės Korėjos vonai),
				'many' => q(Šiaurės Korėjos vono),
				'one' => q(Šiaurės Korėjos vonas),
				'other' => q(Šiaurės Korėjos vonų),
			},
		},
		'KRH' => {
			display_name => {
				'currency' => q(Pietų Korėjos hwanas \(1953–1962\)),
				'few' => q(Pietų Korėjos hwanai \(1953–1962\)),
				'many' => q(Pietų Korėjos hwano \(1953–1962\)),
				'one' => q(Pietų Korėjos hwanas \(1953–1962\)),
				'other' => q(Pietų Korėjos hwanų \(1953–1962\)),
			},
		},
		'KRO' => {
			display_name => {
				'currency' => q(Pietų Korėjos vonas \(1945–1953\)),
				'few' => q(Pietų Korėjos vonai \(1945–1953\)),
				'many' => q(Pietų Korėjos vono \(1945–1953\)),
				'one' => q(Pietų Korėjos vonas \(1945–1953\)),
				'other' => q(Pietų Korėjos vonų \(1945–1953\)),
			},
		},
		'KRW' => {
			symbol => 'KRW',
			display_name => {
				'currency' => q(Pietų Korėjos vonas),
				'few' => q(Pietų Korėjos vonai),
				'many' => q(Pietų Korėjos vono),
				'one' => q(Pietų Korėjos vonas),
				'other' => q(Pietų Korėjos vonų),
			},
		},
		'KWD' => {
			display_name => {
				'currency' => q(Kuveito dinaras),
				'few' => q(Kuveito dinarai),
				'many' => q(Kuveito dinaro),
				'one' => q(Kuveito dinaras),
				'other' => q(Kuveito dinarų),
			},
		},
		'KYD' => {
			display_name => {
				'currency' => q(Kaimanų salų doleris),
				'few' => q(Kaimanų salų doleriai),
				'many' => q(Kaimanų salų dolerio),
				'one' => q(Kaimanų salų doleris),
				'other' => q(Kaimanų salų dolerių),
			},
		},
		'KZT' => {
			display_name => {
				'currency' => q(Kazachstano tengė),
				'few' => q(Kazachstano tengės),
				'many' => q(Kazachstano tengės),
				'one' => q(Kazachstano tengė),
				'other' => q(Kazachstano tengių),
			},
		},
		'LAK' => {
			symbol => 'LAK',
			display_name => {
				'currency' => q(Laoso kipas),
				'few' => q(Laoso kipai),
				'many' => q(Laoso kipo),
				'one' => q(Laoso kipas),
				'other' => q(Laoso kipų),
			},
		},
		'LBP' => {
			display_name => {
				'currency' => q(Libano svaras),
				'few' => q(Libano svarai),
				'many' => q(Libano svaro),
				'one' => q(Libano svaras),
				'other' => q(Libano svarų),
			},
		},
		'LKR' => {
			display_name => {
				'currency' => q(Šri Lankos rupija),
				'few' => q(Šri Lankos rupijos),
				'many' => q(Šri Lankos rupijos),
				'one' => q(Šri Lankos rupija),
				'other' => q(Šri Lankos rupijų),
			},
		},
		'LRD' => {
			display_name => {
				'currency' => q(Liberijos doleris),
				'few' => q(Liberijos doleriai),
				'many' => q(Liberijos dolerio),
				'one' => q(Liberijos doleris),
				'other' => q(Liberijos dolerių),
			},
		},
		'LSL' => {
			display_name => {
				'currency' => q(Lesoto lotis),
			},
		},
		'LTL' => {
			display_name => {
				'currency' => q(Lietuvos litas),
				'few' => q(Lietuvos litai),
				'many' => q(Lietuvos lito),
				'one' => q(Lietuvos litas),
				'other' => q(Lietuvos litų),
			},
		},
		'LTT' => {
			display_name => {
				'currency' => q(Lietuvos talonas),
				'few' => q(Lietuvos talonai),
				'many' => q(Lietuvos talonai),
				'one' => q(Lietuvos talonas),
				'other' => q(Lietuvos talonai),
			},
		},
		'LUC' => {
			display_name => {
				'currency' => q(Liuksemburgo konvertuojamas frankas),
				'few' => q(Liuksemburgo konvertuojami frankai),
				'many' => q(Liuksemburgo konvertuojamo franko),
				'one' => q(Liuksemburgo konvertuojas frankas),
				'other' => q(Liuksemburgo konvertuojamų frankų),
			},
		},
		'LUF' => {
			display_name => {
				'currency' => q(Liuksemburgo frankas),
				'few' => q(Liuksemburgo frankai),
				'many' => q(Liuksemburgo franko),
				'one' => q(Liuksemburgo frankas),
				'other' => q(Liuksemburgo frankų),
			},
		},
		'LUL' => {
			display_name => {
				'currency' => q(Liuksemburgo finansinis frankas),
				'few' => q(Liuksemburgo finansiniai frankai),
				'many' => q(Liuksemburgo finansinio franko),
				'one' => q(Liuksemburgo finansinis frankas),
				'other' => q(Liuksemburgo finansinių frankų),
			},
		},
		'LVL' => {
			display_name => {
				'currency' => q(Latvijos latas),
				'few' => q(Latvijos latai),
				'many' => q(Latvijos lato),
				'one' => q(Latvijos latas),
				'other' => q(Latvijos latų),
			},
		},
		'LVR' => {
			display_name => {
				'currency' => q(Latvijos rublis),
				'few' => q(Latvijos rubliai),
				'many' => q(Latvijos rublio),
				'one' => q(Latvijos rublis),
				'other' => q(Latvijos rublių),
			},
		},
		'LYD' => {
			display_name => {
				'currency' => q(Libijos dinaras),
				'few' => q(Libijos dinarai),
				'many' => q(Libijos dinaro),
				'one' => q(Libijos dinaras),
				'other' => q(Libijos dinarų),
			},
		},
		'MAD' => {
			display_name => {
				'currency' => q(Maroko dirhamas),
				'few' => q(Maroko dirhamai),
				'many' => q(Maroko dirhamo),
				'one' => q(Maroko dirhamas),
				'other' => q(Maroko dirhamų),
			},
		},
		'MAF' => {
			display_name => {
				'currency' => q(Maroko frankas),
				'few' => q(Maroko frankai),
				'many' => q(Maroko franko),
				'one' => q(Maroko frankas),
				'other' => q(Maroko frankų),
			},
		},
		'MCF' => {
			display_name => {
				'currency' => q(Monegasque frankas),
				'few' => q(Monegasque frankai),
				'many' => q(Monegasque franko),
				'one' => q(Monegasque frankas),
				'other' => q(Monegasque frankų),
			},
		},
		'MDC' => {
			display_name => {
				'currency' => q(Moldovų cupon),
			},
		},
		'MDL' => {
			display_name => {
				'currency' => q(Moldovos lėja),
				'few' => q(Moldovos lėjos),
				'many' => q(Moldovos lėjos),
				'one' => q(Moldovos lėja),
				'other' => q(Moldovos lėjų),
			},
		},
		'MGA' => {
			display_name => {
				'currency' => q(Madagaskaro ariaris),
				'few' => q(Madagaskaro ariariai),
				'many' => q(Madagaskaro ariario),
				'one' => q(Madagaskaro ariaris),
				'other' => q(Madagaskaro ariarių),
			},
		},
		'MGF' => {
			display_name => {
				'currency' => q(Madagaskaro frankas),
				'few' => q(Madagaskaro frankai),
				'many' => q(Madagaskaro franko),
				'one' => q(Madagaskaro frankas),
				'other' => q(Madagaskaro frankų),
			},
		},
		'MKD' => {
			display_name => {
				'currency' => q(Makedonijos denaras),
				'few' => q(Makedonijos denarai),
				'many' => q(Makedonijos denaro),
				'one' => q(Makedonijos denaras),
				'other' => q(Makedonijos denarų),
			},
		},
		'MKN' => {
			display_name => {
				'currency' => q(Makedonijos denaras \(1992–1993\)),
				'few' => q(Makedonijos denarai \(1992–1993\)),
				'many' => q(Makedonijos denaro \(1992–1993\)),
				'one' => q(Makedonijos denaras \(1992–1993\)),
				'other' => q(Makedonijos denarų \(1992–1993\)),
			},
		},
		'MLF' => {
			display_name => {
				'currency' => q(Malio frankas),
				'few' => q(Malio frankai),
				'many' => q(Malio franko),
				'one' => q(Malio frankas),
				'other' => q(Malio frankų),
			},
		},
		'MMK' => {
			display_name => {
				'currency' => q(Mianmaro kijatas),
				'few' => q(Mianmaro kijatai),
				'many' => q(Mianmaro kijato),
				'one' => q(Mianmaro kijatas),
				'other' => q(Mianmaro kijatų),
			},
		},
		'MNT' => {
			symbol => 'MNT',
			display_name => {
				'currency' => q(Mongolijos tugrikas),
				'few' => q(Mongolijos tugrikai),
				'many' => q(Mongolijos tugriko),
				'one' => q(Mongolijos tugrikas),
				'other' => q(Mongolijos tugrikų),
			},
		},
		'MOP' => {
			display_name => {
				'currency' => q(Makao pataka),
				'few' => q(Makao patakos),
				'many' => q(Makao patakos),
				'one' => q(Makao pataka),
				'other' => q(Makao patakų),
			},
		},
		'MRO' => {
			display_name => {
				'currency' => q(Mauritanijos ugija \(1973–2017\)),
				'few' => q(Mauritanijos ugijos \(1973–2017\)),
				'many' => q(Mauritanijos ugijos \(1973–2017\)),
				'one' => q(Mauritanijos ugija \(1973–2017\)),
				'other' => q(Mauritanijos ugijų \(1973–2017\)),
			},
		},
		'MRU' => {
			display_name => {
				'currency' => q(Mauritanijos ugija),
				'few' => q(Mauritanijos ugijos),
				'many' => q(Mauritanijos ugijos),
				'one' => q(Mauritanijos ugija),
				'other' => q(Mauritanijos ugijų),
			},
		},
		'MTL' => {
			display_name => {
				'currency' => q(Maltos lira),
			},
		},
		'MTP' => {
			display_name => {
				'currency' => q(Maltos svaras),
				'few' => q(Maltos svarai),
				'many' => q(Maltos svaro),
				'one' => q(Maltos svaras),
				'other' => q(Maltos svarų),
			},
		},
		'MUR' => {
			display_name => {
				'currency' => q(Mauricijaus rupija),
				'few' => q(Mauricijaus rupijos),
				'many' => q(Mauricijaus rupijos),
				'one' => q(Mauricijaus rupija),
				'other' => q(Mauricijaus rupijų),
			},
		},
		'MVP' => {
			display_name => {
				'currency' => q(Maldyvų rupija),
				'few' => q(Maldyvų rupijos),
				'many' => q(Maldyvų rupijos),
				'one' => q(Maldyvų rupija),
				'other' => q(Maldyvų rupijos),
			},
		},
		'MVR' => {
			display_name => {
				'currency' => q(Maldyvų rufija),
				'few' => q(Maldyvų rufijos),
				'many' => q(Maldyvų rufijos),
				'one' => q(Maldyvų rufija),
				'other' => q(Maldyvų rufijų),
			},
		},
		'MWK' => {
			display_name => {
				'currency' => q(Malavio kvača),
				'few' => q(Malavio kvačos),
				'many' => q(Malavio kvačos),
				'one' => q(Malavio kvača),
				'other' => q(Malavio kvačų),
			},
		},
		'MXN' => {
			symbol => 'MXN',
			display_name => {
				'currency' => q(Meksikos pesas),
				'few' => q(Meksikos pesai),
				'many' => q(Meksikos peso),
				'one' => q(Meksikos pesas),
				'other' => q(Meksikos pesų),
			},
		},
		'MXP' => {
			display_name => {
				'currency' => q(Meksikos sidabrinis pesas \(1861–1992\)),
				'few' => q(Meksikos sidabriniai pesai \(1861–1992\)),
				'many' => q(Meksikos sidabrino peso \(1861–1992\)),
				'one' => q(Meksikos sidabrinis pesas \(1861–1992\)),
				'other' => q(Meksikos sidabrinių pesų \(1861–1992\)),
			},
		},
		'MXV' => {
			display_name => {
				'currency' => q(Meksikos United de Inversion \(UDI\)),
				'few' => q(Meksikos unidads de inversija \(UDI\)),
				'many' => q(Meksikos unidads de inversija \(UDI\)),
				'one' => q(Meksikos unidad de inversija \(UDI\)),
				'other' => q(Meksikos unidads de inversija \(UDI\)),
			},
		},
		'MYR' => {
			display_name => {
				'currency' => q(Malaizijos ringitas),
				'few' => q(Malaizijos ringitai),
				'many' => q(Malaizijos ringito),
				'one' => q(Malaizijos ringitas),
				'other' => q(Malaizijos ringitų),
			},
		},
		'MZE' => {
			display_name => {
				'currency' => q(Mozambiko eskudas),
				'few' => q(Mozambiko eskudai),
				'many' => q(Mozambiko eskudo),
				'one' => q(Mozambiko eskudas),
				'other' => q(Mozambiko eskudų),
			},
		},
		'MZM' => {
			display_name => {
				'currency' => q(Mozambiko metikalis \(1980–2006\)),
				'few' => q(Mozambiko metikaliai \(1980–2006\)),
				'many' => q(Mozambiko metikalio \(1980–2006\)),
				'one' => q(Mozambiko metikalis \(1980–2006\)),
				'other' => q(Mozambiko metikalių \(1980–2006\)),
			},
		},
		'MZN' => {
			display_name => {
				'currency' => q(Mozambiko metikalis),
				'few' => q(Mozambiko metikaliai),
				'many' => q(Mozambiko metikalio),
				'one' => q(Mozambiko metikalis),
				'other' => q(Mozambiko metikalių),
			},
		},
		'NAD' => {
			display_name => {
				'currency' => q(Namibijos doleris),
				'few' => q(Namibijos doleriai),
				'many' => q(Namibijos dolerio),
				'one' => q(Namibijos doleris),
				'other' => q(Namibijos dolerių),
			},
		},
		'NGN' => {
			display_name => {
				'currency' => q(Nigerijos naira),
				'few' => q(Nigerijos nairos),
				'many' => q(Nigerijos nairos),
				'one' => q(Nigerijos naira),
				'other' => q(Nigerijos nairų),
			},
		},
		'NIC' => {
			display_name => {
				'currency' => q(Nikaragvos kardoba \(1988–1991\)),
				'few' => q(Nikaragvos kordobai \(1988–1991\)),
				'many' => q(Nikaragvos kordobos \(1988–1991\)),
				'one' => q(Nikaragvos kordoba \(1988–1991\)),
				'other' => q(Nikaragvos kordobų \(1988–1991\)),
			},
		},
		'NIO' => {
			display_name => {
				'currency' => q(Nikaragvos kordoba),
				'few' => q(Nikaragvos kordobos),
				'many' => q(Nikaragvos kordobos),
				'one' => q(Nikaragvos kordoba),
				'other' => q(Nikaragvos kordobų),
			},
		},
		'NLG' => {
			display_name => {
				'currency' => q(Nyderlandų guldenas),
				'few' => q(Nyderlandų guldenai),
				'many' => q(Nyderlandų guldeno),
				'one' => q(Nyderlandų guldenas),
				'other' => q(Nyderlandų guldenų),
			},
		},
		'NOK' => {
			display_name => {
				'currency' => q(Norvegijos krona),
				'few' => q(Norvegijos kronos),
				'many' => q(Norvegijos kronos),
				'one' => q(Norvegijos krona),
				'other' => q(Norvegijos kronų),
			},
		},
		'NPR' => {
			display_name => {
				'currency' => q(Nepalo rupija),
				'few' => q(Nepalo rupijos),
				'many' => q(Nepalo rupijos),
				'one' => q(Nepalo rupija),
				'other' => q(Nepalo rupijų),
			},
		},
		'NZD' => {
			symbol => 'NZD',
			display_name => {
				'currency' => q(Naujosios Zelandijos doleris),
				'few' => q(Naujosios Zelandijos doleriai),
				'many' => q(Naujosios Zelandijos dolerio),
				'one' => q(Naujosios Zelandijos doleris),
				'other' => q(Naujosios Zelandijos dolerių),
			},
		},
		'OMR' => {
			display_name => {
				'currency' => q(Omano rialas),
				'few' => q(Omano rialai),
				'many' => q(Omano rialo),
				'one' => q(Omano rialas),
				'other' => q(Omano rialų),
			},
		},
		'PAB' => {
			display_name => {
				'currency' => q(Panamos balboja),
				'few' => q(Panamos balbojos),
				'many' => q(Panamos balbojos),
				'one' => q(Panamos balboja),
				'other' => q(Panamos balbojų),
			},
		},
		'PEI' => {
			display_name => {
				'currency' => q(Peru intis),
				'few' => q(Peru intis),
				'many' => q(Peru intis),
				'one' => q(Peru inti),
				'other' => q(Peru intis),
			},
		},
		'PEN' => {
			display_name => {
				'currency' => q(Peru solis),
				'few' => q(Peru soliai),
				'many' => q(Peru solio),
				'one' => q(Peru solis),
				'other' => q(Peru solių),
			},
		},
		'PES' => {
			display_name => {
				'currency' => q(Peru solis \(1863–1965\)),
				'few' => q(Peru soliai \(1863–1965\)),
				'many' => q(Peru solio \(1863–1965\)),
				'one' => q(Peru solis \(1863–1965\)),
				'other' => q(Peru solių \(1863–1965\)),
			},
		},
		'PGK' => {
			display_name => {
				'currency' => q(Papua Naujosios Gvinėjos kina),
				'few' => q(Papua Naujosios Gvinėjos kinos),
				'many' => q(Papua Naujosios Gvinėjos kinos),
				'one' => q(Papua Naujosios Gvinėjos kina),
				'other' => q(Papua Naujosios Gvinėjos kinų),
			},
		},
		'PHP' => {
			symbol => 'PHP',
			display_name => {
				'currency' => q(Filipinų pesas),
				'few' => q(Filipinų pesai),
				'many' => q(Filipinų peso),
				'one' => q(Filipinų pesas),
				'other' => q(Filipinų pesų),
			},
		},
		'PKR' => {
			display_name => {
				'currency' => q(Pakistano rupija),
				'few' => q(Pakistano rupijos),
				'many' => q(Pakistano rupijos),
				'one' => q(Pakistano rupija),
				'other' => q(Pakistano rupijų),
			},
		},
		'PLN' => {
			symbol => 'zl',
			display_name => {
				'currency' => q(Lenkijos zlotas),
				'few' => q(Lenkijos zlotai),
				'many' => q(Lenkijos zloto),
				'one' => q(Lenkijos zlotas),
				'other' => q(Lenkijos zlotų),
			},
		},
		'PLZ' => {
			display_name => {
				'currency' => q(Lenkijos zlotas \(1950–1995\)),
				'few' => q(Lenkijos zlotai \(1950–1995\)),
				'many' => q(Lenkijos zloto \(1950–1995\)),
				'one' => q(Lenkijos zlotas \(1950–1995\)),
				'other' => q(Lenkijos zlotų \(1950–1995\)),
			},
		},
		'PTE' => {
			display_name => {
				'currency' => q(Portugalijos eskudas),
				'few' => q(Portugalijos eskudai),
				'many' => q(Portugalijos eskudo),
				'one' => q(Portugalijos eskudas),
				'other' => q(Portugalijos eskudų),
			},
		},
		'PYG' => {
			symbol => 'Gs',
			display_name => {
				'currency' => q(Paragvajaus guaranis),
				'few' => q(Paragvajaus guaraniai),
				'many' => q(Paragvajaus guaranio),
				'one' => q(Paragvajaus guaranis),
				'other' => q(Paragvajaus guaranių),
			},
		},
		'QAR' => {
			display_name => {
				'currency' => q(Kataro rialas),
				'few' => q(Kataro rialai),
				'many' => q(Kataro rialo),
				'one' => q(Kataro rialas),
				'other' => q(Kataro rialų),
			},
		},
		'RHD' => {
			display_name => {
				'currency' => q(Rodezijos doleris),
				'few' => q(Rodezijos doleriai),
				'many' => q(Rodezijos dolerio),
				'one' => q(Rodezijos doleris),
				'other' => q(Rodezijos dolerių),
			},
		},
		'ROL' => {
			display_name => {
				'currency' => q(Rumunijos lėja \(1952–2006\)),
				'few' => q(Rumunijos lėjos \(1952–2006\)),
				'many' => q(Rumunijos lėjos \(1952–2006\)),
				'one' => q(Rumunijos lėja \(1952–2006\)),
				'other' => q(Rumunijos lėjų \(1952–2006\)),
			},
		},
		'RON' => {
			display_name => {
				'currency' => q(Rumunijos lėja),
				'few' => q(Rumunijos lėjos),
				'many' => q(Rumunijos lėjos),
				'one' => q(Rumunijos lėja),
				'other' => q(Rumunijos lėjų),
			},
		},
		'RSD' => {
			display_name => {
				'currency' => q(Serbijos dinaras),
				'few' => q(Serbijos dinarai),
				'many' => q(Serbijos dinaro),
				'one' => q(Serbijos dinaras),
				'other' => q(Serbijos dinarų),
			},
		},
		'RUB' => {
			symbol => 'rb',
			display_name => {
				'currency' => q(Rusijos rublis),
				'few' => q(Rusijos rubliai),
				'many' => q(Rusijos rublio),
				'one' => q(Rusijos rublis),
				'other' => q(Rusijos rublių),
			},
		},
		'RUR' => {
			display_name => {
				'currency' => q(Rusijos rublis \(1991–1998\)),
				'few' => q(Rusijos rubliai \(1991–1998\)),
				'many' => q(Rusijos rublio \(1991–1998\)),
				'one' => q(Rusijos rublis \(1991–1998\)),
				'other' => q(Rusijos rublių \(1991–1998\)),
			},
		},
		'RWF' => {
			display_name => {
				'currency' => q(Ruandos frankas),
				'few' => q(Ruandos frankai),
				'many' => q(Ruandos franko),
				'one' => q(Ruandos frankas),
				'other' => q(Ruandos frankų),
			},
		},
		'SAR' => {
			display_name => {
				'currency' => q(Saudo Arabijos rijalas),
				'few' => q(Saudo Arabijos rijalai),
				'many' => q(Saudo Arabijos rijalo),
				'one' => q(Saudo Arabijos rijalas),
				'other' => q(Saudo Arabijos rijalų),
			},
		},
		'SBD' => {
			display_name => {
				'currency' => q(Saliamono salų doleris),
				'few' => q(Saliamono salų doleriai),
				'many' => q(Saliamono salų dolerio),
				'one' => q(Saliamono salų doleris),
				'other' => q(Saliamono salų dolerių),
			},
		},
		'SCR' => {
			display_name => {
				'currency' => q(Seišelių rupija),
				'few' => q(Seišelių rupijos),
				'many' => q(Seišelių rupijos),
				'one' => q(Seišelių rupija),
				'other' => q(Seišelių rupijų),
			},
		},
		'SDD' => {
			display_name => {
				'currency' => q(Sudano dinaras \(1992–2007\)),
				'few' => q(Sudano dinarai \(1992–2007\)),
				'many' => q(Sudano dinaro \(1992–2007\)),
				'one' => q(Sudano dinaras \(1992–2007\)),
				'other' => q(Sudano dinarų \(1992–2007\)),
			},
		},
		'SDG' => {
			display_name => {
				'currency' => q(Sudano svaras),
				'few' => q(Sudano svarai),
				'many' => q(Sudano svaro),
				'one' => q(Sudano svaras),
				'other' => q(Sudano svarų),
			},
		},
		'SDP' => {
			display_name => {
				'currency' => q(Sudano svaras \(1957–1998\)),
				'few' => q(Sudano svarai \(1957–1998\)),
				'many' => q(Sudano svaro \(1957–1998\)),
				'one' => q(Sudano svaras \(1957–1998\)),
				'other' => q(Sudano svarų \(1957–1998\)),
			},
		},
		'SEK' => {
			display_name => {
				'currency' => q(Švedijos krona),
				'few' => q(Švedijos kronos),
				'many' => q(Švedijos kronos),
				'one' => q(Švedijos krona),
				'other' => q(Švedijos kronų),
			},
		},
		'SGD' => {
			display_name => {
				'currency' => q(Singapūro doleris),
				'few' => q(Singapūro doleriai),
				'many' => q(Singapūro dolerio),
				'one' => q(Singapūro doleris),
				'other' => q(Singapūro dolerių),
			},
		},
		'SHP' => {
			display_name => {
				'currency' => q(Šv. Elenos salų svaras),
				'few' => q(Šv. Elenos salų svarai),
				'many' => q(Šv. Elenos salų svaro),
				'one' => q(Šv. Elenos salų svaras),
				'other' => q(Šv. Elenos salų svarų),
			},
		},
		'SIT' => {
			display_name => {
				'currency' => q(Slovėnijos tolaras),
				'few' => q(Slovėnijos tolars),
				'many' => q(Slovėnijos tolar),
				'one' => q(Slovėnijos tolars),
				'other' => q(Slovėnijos tolar),
			},
		},
		'SKK' => {
			display_name => {
				'currency' => q(Slovakijos krona),
				'few' => q(Slovakijos kronos),
				'many' => q(Slovakijos kronos),
				'one' => q(Slovakijos krona),
				'other' => q(Slovakijos kronų),
			},
		},
		'SLE' => {
			display_name => {
				'currency' => q(Siera Leonės leonė),
				'few' => q(Siera Leonės leonės),
				'many' => q(Siera Leonės leonės),
				'one' => q(Siera Leonės leonė),
				'other' => q(Siera Leonės leonių),
			},
		},
		'SLL' => {
			display_name => {
				'currency' => q(Siera Leonės leonė \(1964—2022\)),
				'few' => q(Siera Leonės leonės \(1964—2022\)),
				'many' => q(Siera Leonės leonės \(1964—2022\)),
				'one' => q(Siera Leonės leonė \(1964—2022\)),
				'other' => q(Siera Leonės leonių \(1964—2022\)),
			},
		},
		'SOS' => {
			display_name => {
				'currency' => q(Somalio šilingas),
				'few' => q(Somalio šilingai),
				'many' => q(Somalio šilingo),
				'one' => q(Somalio šilingas),
				'other' => q(Somalio šilingų),
			},
		},
		'SRD' => {
			display_name => {
				'currency' => q(Surimano doleris),
				'few' => q(Surimano doleriai),
				'many' => q(Surimano dolerio),
				'one' => q(Surimano doleris),
				'other' => q(Surimano dolerių),
			},
		},
		'SRG' => {
			display_name => {
				'currency' => q(Surimano guldenas),
				'few' => q(Surimano guldenai),
				'many' => q(Surimano guldeno),
				'one' => q(Surimano guldenas),
				'other' => q(Surimano guldenų),
			},
		},
		'SSP' => {
			display_name => {
				'currency' => q(Pietų Sudano svaras),
				'few' => q(Pietų Sudano svarai),
				'many' => q(Pietų Sudano svaro),
				'one' => q(Pietų Sudano svaras),
				'other' => q(Pietų Sudano svarų),
			},
		},
		'STD' => {
			display_name => {
				'currency' => q(San Tomės ir Principės dobra \(1977–2017\)),
				'few' => q(San Tomės ir Principės dobros \(1977–2017\)),
				'many' => q(San Tomės ir Principės dobros \(1977–2017\)),
				'one' => q(San Tomės ir Principės dobra \(1977–2017\)),
				'other' => q(Sao Tomės ir Principės dobrų \(1977–2017\)),
			},
		},
		'STN' => {
			display_name => {
				'currency' => q(San Tomės ir Principės dobra),
				'few' => q(San Tomės ir Principės dobros),
				'many' => q(San Tomės ir Principės dobros),
				'one' => q(San Tomės ir Principės dobra),
				'other' => q(Sao Tomės ir Principės dobrų),
			},
		},
		'SUR' => {
			display_name => {
				'currency' => q(Sovietų rublis),
				'few' => q(Sovietų rubliai),
				'many' => q(Sovietų rublio),
				'one' => q(Sovietų rublis),
				'other' => q(Sovietų rublių),
			},
		},
		'SVC' => {
			display_name => {
				'currency' => q(Salvadoro kolonas),
				'few' => q(Salvadoro kolonai),
				'many' => q(Salvadoro kolonai),
				'one' => q(Salvadoro kolonas),
				'other' => q(Salvadoro kolonai),
			},
		},
		'SYP' => {
			display_name => {
				'currency' => q(Sirijos svaras),
				'few' => q(Sirijos svarai),
				'many' => q(Sirijos svaro),
				'one' => q(Sirijos svaras),
				'other' => q(Sirijos svarų),
			},
		},
		'SZL' => {
			display_name => {
				'currency' => q(Svazilando lilangenis),
				'few' => q(Svazilando lilangeniai),
				'many' => q(Svazilendo lilangenio),
				'one' => q(Svazilando lilangenis),
				'other' => q(Svazilendo lilangenių),
			},
		},
		'THB' => {
			display_name => {
				'currency' => q(Tailando batas),
				'few' => q(Tailando batai),
				'many' => q(Tailando bato),
				'one' => q(Tailando batas),
				'other' => q(Tailando batų),
			},
		},
		'TJR' => {
			display_name => {
				'currency' => q(Tadžikistano rublis),
				'few' => q(Tadžikistano rubliai),
				'many' => q(Tadžikistano rublio),
				'one' => q(Tadžikistano rublis),
				'other' => q(Tadžikistano rublių),
			},
		},
		'TJS' => {
			display_name => {
				'currency' => q(Tadžikistano somonis),
				'few' => q(Tadžikistano somoniai),
				'many' => q(Tadžikistano somonio),
				'one' => q(Tadžikistano somonis),
				'other' => q(Tadžikistano somonių),
			},
		},
		'TMM' => {
			display_name => {
				'currency' => q(Turkmėnistano manatas \(1993–2009\)),
				'few' => q(Turkmėnistano manatai \(1993–2009\)),
				'many' => q(Turkmėnistano manato \(1993–2009\)),
				'one' => q(Turkmėnistano manatas \(1993–2009\)),
				'other' => q(Turkmėnistano manatų \(1993–2009\)),
			},
		},
		'TMT' => {
			display_name => {
				'currency' => q(Turkmėnistano manatas),
				'few' => q(Turkmėnistano manatai),
				'many' => q(Turkmėnistano manato),
				'one' => q(Turkmėnistano manatas),
				'other' => q(Turkmėnistano manatų),
			},
		},
		'TND' => {
			display_name => {
				'currency' => q(Tuniso dinaras),
				'few' => q(Tuniso dinarai),
				'many' => q(Tuniso dinaro),
				'one' => q(Tuniso dinaras),
				'other' => q(Tuniso dinarų),
			},
		},
		'TOP' => {
			display_name => {
				'currency' => q(Tongo paanga),
				'few' => q(Tongo paangos),
				'many' => q(Tongo paangos),
				'one' => q(Tongo paanga),
				'other' => q(Tongo paangų),
			},
		},
		'TPE' => {
			display_name => {
				'currency' => q(Timoro eskudas),
				'few' => q(Timoro eskudai),
				'many' => q(Timoro eskudo),
				'one' => q(Timoro eskudas),
				'other' => q(Timoro eskudų),
			},
		},
		'TRL' => {
			display_name => {
				'currency' => q(Turkijos lira \(1922–2005\)),
				'few' => q(Turkijos liros \(1922–2005\)),
				'many' => q(Turkijos liros \(1922–2005\)),
				'one' => q(Turkijos lira \(1922–2005\)),
				'other' => q(Turkijos lirų \(1922–2005\)),
			},
		},
		'TRY' => {
			display_name => {
				'currency' => q(Turkijos lira),
				'few' => q(Turkijos liros),
				'many' => q(Turkijos liros),
				'one' => q(Turkijos lira),
				'other' => q(Turkijos lirų),
			},
		},
		'TTD' => {
			display_name => {
				'currency' => q(Trinidado ir Tobago doleris),
				'few' => q(Trinidado ir Tobago doleriai),
				'many' => q(Trinidado ir Tobago dolerio),
				'one' => q(Trinidado ir Tobago doleris),
				'other' => q(Trinidado ir Tobago dolerių),
			},
		},
		'TWD' => {
			symbol => 'TWD',
			display_name => {
				'currency' => q(Taivano naujasis doleris),
				'few' => q(Taivano naujieji doleriai),
				'many' => q(Taivano naujojo dolerio),
				'one' => q(Taivano naujasis doleris),
				'other' => q(Taivano naujųjų dolerių),
			},
		},
		'TZS' => {
			display_name => {
				'currency' => q(Tanzanijos šilingas),
				'few' => q(Tanzanijos šilingai),
				'many' => q(Tanzanijos šilingo),
				'one' => q(Tanzanijos šilingas),
				'other' => q(Tanzanijos šilingų),
			},
		},
		'UAH' => {
			display_name => {
				'currency' => q(Ukrainos grivina),
				'few' => q(Ukrainos grivinos),
				'many' => q(Ukrainos grivinos),
				'one' => q(Ukrainos grivina),
				'other' => q(Ukrainos grivinų),
			},
		},
		'UAK' => {
			display_name => {
				'currency' => q(Ukrainos karbovanecas),
				'few' => q(Ukrainos karbovantsiv),
				'many' => q(Ukrainos karbovantsiv),
				'one' => q(Ukrainos karbovanets),
				'other' => q(Ukrainos karbovantsiv),
			},
		},
		'UGS' => {
			display_name => {
				'currency' => q(Ugandos šilingas \(1966–1987\)),
				'few' => q(Ugandos šilingai \(1966–1987\)),
				'many' => q(Ugandos šilingo \(1966–1987\)),
				'one' => q(Ugandos šilingas \(1966–1987\)),
				'other' => q(Ugandos šilingų \(1966–1987\)),
			},
		},
		'UGX' => {
			display_name => {
				'currency' => q(Ugandos šilingas),
				'few' => q(Ugandos šilingai),
				'many' => q(Ugandos šilingo),
				'one' => q(Ugandos šilingas),
				'other' => q(Ugandos šilingų),
			},
		},
		'USD' => {
			symbol => 'USD',
			display_name => {
				'currency' => q(JAV doleris),
				'few' => q(JAV doleriai),
				'many' => q(JAV dolerio),
				'one' => q(JAV doleris),
				'other' => q(JAV dolerių),
			},
		},
		'USN' => {
			display_name => {
				'currency' => q(JAV doleris \(kitos dienos\)),
				'few' => q(JAV doleriai \(kitą dieną\)),
				'many' => q(JAV dolerio \(kitą dieną\)),
				'one' => q(JAV doleris \(kitą dieną\)),
				'other' => q(JAV dolerių \(kitą dieną\)),
			},
		},
		'USS' => {
			display_name => {
				'currency' => q(JAV doleris \(šios dienos\)),
				'few' => q(JAV doleriai \(tą pačią dieną\)),
				'many' => q(JAV dolerio \(tą pačią dieną\)),
				'one' => q(JAV doleris \(tą pačią dieną\)),
				'other' => q(JAV dolerių \(tą pačią dieną\)),
			},
		},
		'UYI' => {
			display_name => {
				'currency' => q(Urugvajaus pesai en unidades indexadas),
				'few' => q(Uragvajaus pesai en unidades indexadas),
				'many' => q(Urugvajaus pesai en unidades indexadas),
				'one' => q(Urugvajaus pesas en unidades indexadas),
				'other' => q(Urugvajaus pesai en unidades indexadas),
			},
		},
		'UYP' => {
			display_name => {
				'currency' => q(Urugvajaus pesas \(1975–1993\)),
				'few' => q(Urugvajaus pesai \(1975–1993\)),
				'many' => q(Urugvajaus peso \(1975–1993\)),
				'one' => q(Urugvajaus pesas \(1975–1993\)),
				'other' => q(Urugvajaus pesų \(1975–1993\)),
			},
		},
		'UYU' => {
			display_name => {
				'currency' => q(Urugvajaus pesas),
				'few' => q(Urugvajaus pesai),
				'many' => q(Urugvajaus peso),
				'one' => q(Urugvajaus pesas),
				'other' => q(Urugvajaus pesų),
			},
		},
		'UZS' => {
			display_name => {
				'currency' => q(Uzbekistano sumas),
				'few' => q(Uzbekistano sumai),
				'many' => q(Uzbekistano sumo),
				'one' => q(Uzbekistano sumas),
				'other' => q(Uzbekistano sumų),
			},
		},
		'VEB' => {
			display_name => {
				'currency' => q(Venesuelos bolivaras \(1871–2008\)),
				'few' => q(Venesuelos bolivarai \(1871–2008\)),
				'many' => q(Venesuelos bolivaro \(1871–2008\)),
				'one' => q(Venesuelos bolivaras \(1871–2008\)),
				'other' => q(Venesuelos bolivarų \(1871–2008\)),
			},
		},
		'VEF' => {
			display_name => {
				'currency' => q(Venesuelos bolivaras \(2008–2018\)),
				'few' => q(Venesuelos bolivarai \(2008–2018\)),
				'many' => q(Venesuelos bolivaro \(2008–2018\)),
				'one' => q(Venesuelos bolivaras \(2008–2018\)),
				'other' => q(Venesuelos bolivarų \(2008–2018\)),
			},
		},
		'VES' => {
			display_name => {
				'currency' => q(Venesuelos bolivaras),
				'few' => q(Venesuelos bolivarai),
				'many' => q(Venesuelos bolivaro),
				'one' => q(Venesuelos bolivaras),
				'other' => q(Venesuelos bolivarų),
			},
		},
		'VND' => {
			symbol => 'VND',
			display_name => {
				'currency' => q(Vietnamo dongas),
				'few' => q(Vietnamo dongai),
				'many' => q(Vietnamo dongo),
				'one' => q(Vietnamo dongas),
				'other' => q(Vietnamo dongų),
			},
		},
		'VNN' => {
			display_name => {
				'currency' => q(Vietnamo dongas \(1978–1985\)),
				'few' => q(Vietnamo dongai \(1978–1985\)),
				'many' => q(Vietnamo dongo \(1978–1985\)),
				'one' => q(Vietnamo dongas \(1978–1985\)),
				'other' => q(Vietnamo dongų \(1978–1985\)),
			},
		},
		'VUV' => {
			display_name => {
				'currency' => q(Vanuatu vatas),
				'few' => q(Vanuatu vatai),
				'many' => q(Vanuatu vato),
				'one' => q(Vanuatu vatas),
				'other' => q(Vanuatu vatų),
			},
		},
		'WST' => {
			display_name => {
				'currency' => q(Samoa tala),
				'few' => q(Samoa talos),
				'many' => q(Samoa talos),
				'one' => q(Samoa tala),
				'other' => q(Samoa talų),
			},
		},
		'XAF' => {
			symbol => 'XAF',
			display_name => {
				'currency' => q(CFA BEAC frankas),
				'few' => q(CFA BEAC frankai),
				'many' => q(CFA BEAC franko),
				'one' => q(CFA BEAC frankas),
				'other' => q(CFA BEAC frankų),
			},
		},
		'XAG' => {
			display_name => {
				'currency' => q(Sidabras),
			},
		},
		'XAU' => {
			display_name => {
				'currency' => q(Auksas),
			},
		},
		'XBA' => {
			display_name => {
				'currency' => q(Europos suvestinės vienetas),
				'few' => q(Europos suvestinės vienetai),
				'many' => q(Europos suvestinės vienetai),
				'one' => q(Europos suvestinės vienetas),
				'other' => q(Europos suvestinės vienetai),
			},
		},
		'XBB' => {
			display_name => {
				'currency' => q(Europos piniginis vienetas),
				'few' => q(Europos piniginiai vienetai),
				'many' => q(Europos piniginiai vienetai),
				'one' => q(Europos piniginis vienetas),
				'other' => q(Europos piniginiai vienetai),
			},
		},
		'XBC' => {
			display_name => {
				'currency' => q(Europos valiutos / apskaitos vienetas \(XBC\)),
				'few' => q(Europos valiutos / apskaitos vienetai \(XBC\)),
				'many' => q(Europos valiutos / apskaitos vienetai \(XBC\)),
				'one' => q(Europos valiutos / apskaitos vienetas \(XBC\)),
				'other' => q(Europos valiutos / apskaitos vienetai \(XBC\)),
			},
		},
		'XBD' => {
			display_name => {
				'currency' => q(Europos valiutos / apskaitos vienetas \(XBD\)),
				'few' => q(Europos valiutos / apskaitos vienetas \(XBD\)),
				'many' => q(Europos valiutos / apskaitos vienetai \(XBD\)),
				'one' => q(Europos valiutos / apskaitos vienetas \(XBD\)),
				'other' => q(Europos valiutos / apskaitos vienetai \(XBD\)),
			},
		},
		'XCD' => {
			symbol => 'XCD',
			display_name => {
				'currency' => q(Rytų Karibų doleris),
				'few' => q(Rytų Karibų doleriai),
				'many' => q(Rytų Karibų dolerio),
				'one' => q(Rytų Karibų doleris),
				'other' => q(Rytų Karibų dolerių),
			},
		},
		'XDR' => {
			display_name => {
				'currency' => q(SDR tarptautinis valiutos fondas),
			},
		},
		'XEU' => {
			display_name => {
				'currency' => q(Europos piniginis vienetas \(1993–1999\)),
			},
		},
		'XFO' => {
			display_name => {
				'currency' => q(Aukso frankas),
				'few' => q(Aukso frankai),
				'many' => q(Aukso franko),
				'one' => q(Aukso frankas),
				'other' => q(Aukso frankų),
			},
		},
		'XFU' => {
			display_name => {
				'currency' => q(Prancūzijos UIC - frankas),
				'few' => q(Prancūzijos UIC - frankai),
				'many' => q(Prancūzijos UIC - franko),
				'one' => q(Prancūzijos UIC - frankas),
				'other' => q(Prancūzijos UIC - frankų),
			},
		},
		'XOF' => {
			symbol => 'XOF',
			display_name => {
				'currency' => q(CFA BCEAO frankas),
				'few' => q(CFA BCEAO frankai),
				'many' => q(CFA BCEAO franko),
				'one' => q(CFA BCEAO frankas),
				'other' => q(CFA BCEAO frankų),
			},
		},
		'XPD' => {
			display_name => {
				'currency' => q(Paladis),
			},
		},
		'XPF' => {
			symbol => 'XPF',
			display_name => {
				'currency' => q(CFP frankas),
				'few' => q(CFP frankai),
				'many' => q(CFP franko),
				'one' => q(CFP frankas),
				'other' => q(CFP frankų),
			},
		},
		'XPT' => {
			display_name => {
				'currency' => q(Platina),
			},
		},
		'XRE' => {
			display_name => {
				'currency' => q(RINET fondai),
				'few' => q(RINET fondai),
				'many' => q(RINET fondai),
				'one' => q(RINET fondas),
				'other' => q(RINET fondai),
			},
		},
		'XSU' => {
			display_name => {
				'currency' => q(Sukrė),
				'few' => q(Sukrės),
				'many' => q(Sukrės),
				'one' => q(Sukrė),
				'other' => q(Sukrių),
			},
		},
		'XTS' => {
			display_name => {
				'currency' => q(Tikrinamas valiutos kodas),
			},
		},
		'XUA' => {
			display_name => {
				'currency' => q(Azijos plėtros banko apskaitos vienetas),
				'few' => q(Azijos plėtros banko apskaitos vienetai),
				'many' => q(Azijos plėtros banko apskaitos vieneto),
				'one' => q(Azijos plėtros banko apskaitos vienetas),
				'other' => q(Azijos plėtros banko apskaitos vienetų),
			},
		},
		'XXX' => {
			display_name => {
				'currency' => q(nežinoma valiuta),
				'few' => q(\(nežinoma valiuta\)),
				'many' => q(\(nežinoma valiuta\)),
				'one' => q(\(nežinoma valiuta\)),
				'other' => q(\(nežinoma valiuta\)),
			},
		},
		'YDD' => {
			display_name => {
				'currency' => q(Jemeno dinaras),
				'few' => q(Jemeno dinarai),
				'many' => q(Jemeno dinaro),
				'one' => q(Jemeno dinaras),
				'other' => q(Jemeno dinarų),
			},
		},
		'YER' => {
			display_name => {
				'currency' => q(Jemeno rialas),
				'few' => q(Jemeno rialai),
				'many' => q(Jemeno rialo),
				'one' => q(Jemeno rialas),
				'other' => q(Jemeno rialų),
			},
		},
		'YUD' => {
			display_name => {
				'currency' => q(Jugoslavijos kietasis dinaras \(1966–1990\)),
				'few' => q(Jugoslavijos kietieji dinarai \(1966–1990\)),
				'many' => q(Jugoslavijos kietiejo dinaro \(1966–1990\)),
				'one' => q(Jugoslavijos kietasis dinaras \(1966–1990\)),
				'other' => q(Jugoslavijos kietiejų dinarų \(1966–1990\)),
			},
		},
		'YUM' => {
			display_name => {
				'currency' => q(Jugoslavijos naujasis dinaras \(1994–2002\)),
				'few' => q(Jugoslavijos naujieji dinarai \(1994–2002\)),
				'many' => q(Jugoslavijos naujojo dinaro \(1994–2002\)),
				'one' => q(Jugoslavijos naujasis dinaras \(1994–2002\)),
				'other' => q(Jugoslavijos naujųjų dinarų \(1994–2002\)),
			},
		},
		'YUN' => {
			display_name => {
				'currency' => q(Jugoslavijos konvertuojamas dinaras \(1990–1992\)),
				'few' => q(Jugoslavijos konvertuojami dinarai \(1990–1992\)),
				'many' => q(Jugoslavijos konvertuojamo dinaro \(1990–1992\)),
				'one' => q(Jugoslavijos konvertuojamas dinaras \(1990–1992\)),
				'other' => q(Jugoslavijos konvertuojamų dinarų \(1990–1992\)),
			},
		},
		'YUR' => {
			display_name => {
				'currency' => q(Jugoslavijos reformuotas dinaras \(1992–1993\)),
				'few' => q(Jugoslavijos reformuoti dinarai \(1992–1993\)),
				'many' => q(Jugoslavijos reformuoto dinaro \(1992–1993\)),
				'one' => q(Jugoslavijos reformuotas dinaras \(1992–1993\)),
				'other' => q(Jugoslavijos reformuotų dinarų \(1992–1993\)),
			},
		},
		'ZAL' => {
			display_name => {
				'currency' => q(Pietų Afrikos finansinis randas),
				'few' => q(Pietų Afrikos randai \(finansinis\)),
				'many' => q(Pietų Afrikos rando \(finansinis\)),
				'one' => q(Pietų Afrikos randas \(finansinis\)),
				'other' => q(Pietų Afrikos randų \(finansinis\)),
			},
		},
		'ZAR' => {
			display_name => {
				'currency' => q(Pietų Afrikos Respublikos randas),
				'few' => q(Pietų Afrikos Respublikos randai),
				'many' => q(Pietų Afrikos Respublikos rando),
				'one' => q(Pietų Afrikos Respublikos randas),
				'other' => q(Pietų Afrikos Respublikos randų),
			},
		},
		'ZMK' => {
			display_name => {
				'currency' => q(Zambijos kvača \(1968–2012\)),
				'few' => q(Zambijos kvačos \(1968–2012\)),
				'many' => q(Zambijos kvačos \(1968–2012\)),
				'one' => q(Zambijos kvača \(1968–2012\)),
				'other' => q(Zambijos kvačų \(1968–2012\)),
			},
		},
		'ZMW' => {
			display_name => {
				'currency' => q(Zambijos kvača),
				'few' => q(Zambijos kvačos),
				'many' => q(Zambijos kvačos),
				'one' => q(Zambijos kvača),
				'other' => q(Zambijos kvačų),
			},
		},
		'ZRN' => {
			display_name => {
				'currency' => q(Zairo naujasis zairas \(1993–1998\)),
				'few' => q(Zairo naujieji zairai \(1993–1998\)),
				'many' => q(Zairo naujojo zairo \(1993–1998\)),
				'one' => q(Zairo naujasis zairas \(1993–1998\)),
				'other' => q(Zairo naujųjų zairų \(1993–1998\)),
			},
		},
		'ZRZ' => {
			display_name => {
				'currency' => q(Zairo zairas \(1971–1993\)),
				'few' => q(Zairo zairai \(1971–1993\)),
				'many' => q(Zairo zairo \(1971–1993\)),
				'one' => q(Zairo zairas \(1971–1993\)),
				'other' => q(Zairo zairų \(1971–1993\)),
			},
		},
		'ZWD' => {
			display_name => {
				'currency' => q(Zimbabvės doleris \(1980–2008\)),
				'few' => q(Zimbabvės doleriai \(1980–2008\)),
				'many' => q(Zimbabvės dolerio \(1980–2008\)),
				'one' => q(Zimbabvės doleris \(1980–2008\)),
				'other' => q(Zimbabvės dolerių \(1980–2008\)),
			},
		},
		'ZWL' => {
			display_name => {
				'currency' => q(Zimbabvės doleris \(2009\)),
				'few' => q(Zimbabvės doleriai \(2009\)),
				'many' => q(Zimbabvės dolerio \(2009\)),
				'one' => q(Zimbabvės doleris \(2009\)),
				'other' => q(Zimbabvės dolerių \(2009\)),
			},
		},
		'ZWR' => {
			display_name => {
				'currency' => q(Zimbabvės doleris \(2008\)),
				'few' => q(Zimbabvės doleriai \(2008\)),
				'many' => q(Zimbabvės dolerio \(2008\)),
				'one' => q(Zimbabvės doleris \(2008\)),
				'other' => q(Zimbabvės dolerių \(2008\)),
			},
		},
	} },
);


has 'calendar_months' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
			'chinese' => {
				'format' => {
					wide => {
						nonleap => [
							'1',
							'2',
							'3',
							'4',
							'5',
							'6',
							'7',
							'8',
							'9',
							'10',
							'11',
							'12'
						],
						leap => [
							
						],
					},
				},
			},
			'gregorian' => {
				'format' => {
					abbreviated => {
						nonleap => [
							'saus.',
							'vas.',
							'kov.',
							'bal.',
							'geg.',
							'birž.',
							'liep.',
							'rugp.',
							'rugs.',
							'spal.',
							'lapkr.',
							'gruod.'
						],
						leap => [
							
						],
					},
					wide => {
						nonleap => [
							'sausio',
							'vasario',
							'kovo',
							'balandžio',
							'gegužės',
							'birželio',
							'liepos',
							'rugpjūčio',
							'rugsėjo',
							'spalio',
							'lapkričio',
							'gruodžio'
						],
						leap => [
							
						],
					},
				},
				'stand-alone' => {
					narrow => {
						nonleap => [
							'S',
							'V',
							'K',
							'B',
							'G',
							'B',
							'L',
							'R',
							'R',
							'S',
							'L',
							'G'
						],
						leap => [
							
						],
					},
					wide => {
						nonleap => [
							'sausis',
							'vasaris',
							'kovas',
							'balandis',
							'gegužė',
							'birželis',
							'liepa',
							'rugpjūtis',
							'rugsėjis',
							'spalis',
							'lapkritis',
							'gruodis'
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
						mon => 'pr',
						tue => 'an',
						wed => 'tr',
						thu => 'kt',
						fri => 'pn',
						sat => 'št',
						sun => 'sk'
					},
					short => {
						mon => 'Pr',
						tue => 'An',
						wed => 'Tr',
						thu => 'Kt',
						fri => 'Pn',
						sat => 'Št',
						sun => 'Sk'
					},
					wide => {
						mon => 'pirmadienis',
						tue => 'antradienis',
						wed => 'trečiadienis',
						thu => 'ketvirtadienis',
						fri => 'penktadienis',
						sat => 'šeštadienis',
						sun => 'sekmadienis'
					},
				},
				'stand-alone' => {
					narrow => {
						mon => 'P',
						tue => 'A',
						wed => 'T',
						thu => 'K',
						fri => 'P',
						sat => 'Š',
						sun => 'S'
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
					abbreviated => {0 => 'I k.',
						1 => 'II k.',
						2 => 'III k.',
						3 => 'IV k.'
					},
					wide => {0 => 'I ketvirtis',
						1 => 'II ketvirtis',
						2 => 'III ketvirtis',
						3 => 'IV ketvirtis'
					},
				},
				'stand-alone' => {
					abbreviated => {0 => 'I ketv.',
						1 => 'II ketv.',
						2 => 'III ketv.',
						3 => 'IV ketv.'
					},
				},
			},
	} },
);

has 'day_period_data' => (
	is			=> 'ro',
	isa			=> CodeRef,
	init_arg	=> undef,
	default		=> sub { sub {
		# Time in hhmm format
		my ($self, $type, $time, $day_period_type) = @_;
		$day_period_type //= 'default';
		SWITCH:
		for ($type) {
			if ($_ eq 'chinese') {
				if($day_period_type eq 'default') {
					return 'midnight' if $time == 0;
					return 'noon' if $time == 1200;
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				if($day_period_type eq 'selection') {
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				last SWITCH;
				}
			if ($_ eq 'generic') {
				if($day_period_type eq 'default') {
					return 'midnight' if $time == 0;
					return 'noon' if $time == 1200;
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				if($day_period_type eq 'selection') {
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				last SWITCH;
				}
			if ($_ eq 'gregorian') {
				if($day_period_type eq 'default') {
					return 'midnight' if $time == 0;
					return 'noon' if $time == 1200;
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				if($day_period_type eq 'selection') {
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				last SWITCH;
				}
			if ($_ eq 'japanese') {
				if($day_period_type eq 'default') {
					return 'midnight' if $time == 0;
					return 'noon' if $time == 1200;
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				if($day_period_type eq 'selection') {
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				last SWITCH;
				}
			if ($_ eq 'roc') {
				if($day_period_type eq 'default') {
					return 'midnight' if $time == 0;
					return 'noon' if $time == 1200;
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				if($day_period_type eq 'selection') {
					return 'afternoon1' if $time >= 1200
						&& $time < 1800;
					return 'evening1' if $time >= 1800
						&& $time < 2400;
					return 'morning1' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 0
						&& $time < 600;
				}
				last SWITCH;
				}
		}
	} },
);

around day_period_data => sub {
    my ($orig, $self) = @_;
    return $self->$orig;
};

has 'day_periods' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'gregorian' => {
			'format' => {
				'abbreviated' => {
					'afternoon1' => q{popietė},
					'am' => q{priešpiet},
					'evening1' => q{vakaras},
					'midnight' => q{vidurnaktis},
					'morning1' => q{rytas},
					'night1' => q{naktis},
					'noon' => q{perpiet},
					'pm' => q{popiet},
				},
				'narrow' => {
					'am' => q{pr. p.},
					'pm' => q{pop.},
				},
			},
			'stand-alone' => {
				'abbreviated' => {
					'afternoon1' => q{diena},
					'evening1' => q{vakaras},
					'morning1' => q{rytas},
					'night1' => q{naktis},
					'noon' => q{vidurdienis},
				},
				'narrow' => {
					'am' => q{pr. p.},
					'pm' => q{pop.},
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
		'chinese' => {
		},
		'generic' => {
		},
		'gregorian' => {
			abbreviated => {
				'0' => 'pr. Kr.',
				'1' => 'po Kr.'
			},
			wide => {
				'0' => 'prieš Kristų',
				'1' => 'po Kristaus'
			},
		},
		'japanese' => {
			abbreviated => {
				'1' => 'Hakuči (650–671)',
				'2' => 'Hakuho (672–686)',
				'3' => 'Šučo (686–701)',
				'4' => 'Taiho (701–704)',
				'6' => 'Vado (708–715)',
				'8' => 'Joro (717–724)',
				'10' => 'Tempio (729–749)',
				'11' => 'Tempio-kampo (749–749)',
				'12' => 'Tempio-šoho (749–757)',
				'13' => 'Tempio-hodzi (757–765)',
				'14' => 'Tempo-dzingo (765–767)',
				'15' => 'Dzingo-keiun (767–770)',
				'16' => 'Hoki (770–780)',
				'17' => 'Ten-o (781–782)',
				'18' => 'Enrjaku (782–806)',
				'19' => 'Daido (806–810)',
				'20' => 'Konin (810–824)',
				'21' => 'Tenčo (824–834)',
				'22' => 'Šova (834–848)',
				'23' => 'Kajo (848–851)',
				'25' => 'Saiko (854–857)',
				'26' => 'Tenan (857–859)',
				'27' => 'Jogan (859–877)',
				'28' => 'Genkei (877–885)',
				'29' => 'Ninja (885–889)',
				'30' => 'Kampjo (889–898)',
				'31' => 'Šotai (898–901)',
				'33' => 'Enčo (923–931)',
				'34' => 'Šohei (931–938)',
				'35' => 'Tengjo (938–947)',
				'36' => 'Tenriaku (947–957)',
				'38' => 'Ova (961–964)',
				'39' => 'Koho (964–968)',
				'40' => 'Ana (968–970)',
				'42' => 'Ten-en (973–976)',
				'43' => 'Jogen (976–978)',
				'46' => 'Kana (985–987)',
				'47' => 'Ei-en (987–989)',
				'49' => 'Šorjaku (990–995)',
				'50' => 'Čotoku (995–999)',
				'51' => 'Čoho (999–1004)',
				'52' => 'Kanko (1004–1012)',
				'53' => 'Čova (1012–1017)',
				'54' => 'Kanin (1017–1021)',
				'55' => 'Džian (1021–1024)',
				'56' => 'Mandžiu (1024–1028)',
				'57' => 'Čogen (1028–1037)',
				'58' => 'Čorjaku (1037–1040)',
				'59' => 'Čokju (1040–1044)',
				'61' => 'Eišo (1046–1053)',
				'63' => 'Kohei (1058–1065)',
				'64' => 'Džirjaku (1065–1069)',
				'65' => 'Enkju (1069–1074)',
				'66' => 'Šoho (1074–1077)',
				'67' => 'Šorjaku (1077–1081)',
				'68' => 'Eiho (1081–084)',
				'69' => 'Otoku (1084–1087)',
				'70' => 'Kandži (1087–1094)',
				'71' => 'Kaho (1094–1096)',
				'72' => 'Eičo (1096–1097)',
				'73' => 'Šotoku (1097–1099)',
				'74' => 'Kova (1099–1104)',
				'75' => 'Čodži (1104–1106)',
				'76' => 'Kašo (1106–1108)',
				'77' => 'Tenin (1108–1110)',
				'79' => 'Eikju (1113–1118)',
				'80' => 'Gen-ei (1118–1120)',
				'81' => 'Hoan (1120–1124)',
				'82' => 'Tendži (1124–1126)',
				'83' => 'Daidži (1126–1131)',
				'84' => 'Tenšo (1131–1132)',
				'85' => 'Čošo (1132–1135)',
				'86' => 'Hoen (1135–1141)',
				'87' => 'Eidži (1141–1142)',
				'88' => 'Kodži (1142–1144)',
				'89' => 'Tenjo (1144–1145)',
				'90' => 'Kjuan (1145–1151)',
				'92' => 'Kjuju (1154–1156)',
				'93' => 'Hogen (1156–1159)',
				'94' => 'Heidži (1159–1160)',
				'95' => 'Eirjaku (1160–1161)',
				'96' => 'Oho (1161–1163)',
				'97' => 'Čokan (1163–1165)',
				'99' => 'Nin-an (1166–1169)',
				'100' => 'Kao (1169–1171)',
				'101' => 'Šoan (1171–1175)',
				'103' => 'Džišo (1177–1181)',
				'104' => 'Jova (1181–1182)',
				'105' => 'Džuei (1182–1184)',
				'106' => 'Genrjuku (1184–1185)',
				'107' => 'Bundži (1185–1190)',
				'108' => 'Kenkju (1190–1199)',
				'109' => 'Šodži (1199–1201)',
				'110' => 'Kenin (1201–1204)',
				'111' => 'Genkju (1204–1206)',
				'112' => 'Ken-ei (1206–1207)',
				'113' => 'Šogen (1207–1211)',
				'114' => 'Kenrjaku (1211–1213)',
				'115' => 'Kenpo (1213–1219)',
				'116' => 'Šokju (1219–1222)',
				'117' => 'Džu (1222–1224)',
				'118' => 'Genin (1224–1225)',
				'122' => 'Džoei (1232–1233)',
				'123' => 'Tempuku (1233–1234)',
				'124' => 'Bunrjaku (1234–1235)',
				'126' => 'Rjakunin (1238–1239)',
				'127' => 'En-o (1239–1240)',
				'128' => 'Nindži (1240–1243)',
				'130' => 'Hodži (1247–1249)',
				'131' => 'Kenčo (1249–1256)',
				'132' => 'Kogen (1256–1257)',
				'133' => 'Šoka (1257–1259)',
				'134' => 'Šogen (1259–1260)',
				'135' => 'Bun-o (1260–1261)',
				'136' => 'Kočo (1261–1264)',
				'137' => 'Bun-ei (1264–1275)',
				'138' => 'Kendži (1275–1278)',
				'139' => 'Koan (1278–1288)',
				'140' => 'Šu (1288–1293)',
				'142' => 'Šoan (1299–1302)',
				'145' => 'Tokudži (1306–1308)',
				'146' => 'Enkei (1308–1311)',
				'147' => 'Očo (1311–1312)',
				'148' => 'Šova (1312–1317)',
				'149' => 'Bunpo (1317–1319)',
				'150' => 'Dženo (1319–1321)',
				'151' => 'Dženkjo (1321–1324)',
				'152' => 'Šoču (1324–1326)',
				'153' => 'Kareki (1326–1329)',
				'155' => 'Genko (1331–1334)',
				'156' => 'Kemu (1334–1336)',
				'158' => 'Kokoku (1340–1346)',
				'159' => 'Šohei (1346–1370)',
				'161' => 'Bunču (1372–1375)',
				'162' => 'Tendžu (1375–1379)',
				'163' => 'Korjaku (1379–1381)',
				'164' => 'Kova (1381–1384)',
				'165' => 'Genču (1384–1392)',
				'168' => 'Ku (1389–1390)',
				'170' => 'Oei (1394–1428)',
				'171' => 'Šočo (1428–1429)',
				'172' => 'Eikjo (1429–1441)',
				'174' => 'Bun-an (1444–1449)',
				'175' => 'Hotoku (1449–1452)',
				'176' => 'Kjotoku (1452–1455)',
				'177' => 'Košo (1455–1457)',
				'178' => 'Čoroku (1457–1460)',
				'179' => 'Kanšo (1460–1466)',
				'180' => 'Bunšo (1466–1467)',
				'181' => 'Onin (1467–1469)',
				'183' => 'Čokjo (1487–1489)',
				'185' => 'Meio (1492–1501)',
				'187' => 'Eišo (1504–1521)',
				'189' => 'Kjoroku (1528–1532)',
				'190' => 'Tenmon (1532–1555)',
				'191' => 'Kodži (1555–1558)',
				'194' => 'Tenšo (1573–1592)',
				'196' => 'Keičo (1596–1615)',
				'197' => 'Genva (1615–1624)',
				'198' => 'Kan-ei (1624–1644)',
				'199' => 'Šoho (1644–1648)',
				'201' => 'Šu (1652–1655)',
				'202' => 'Meirjaku (1655–1658)',
				'203' => 'Mandži (1658–1661)',
				'205' => 'Enpo (1673–1681)',
				'206' => 'Tenva (1681–1684)',
				'207' => 'Džokjo (1684–1688)',
				'209' => 'Hoei (1704–1711)',
				'210' => 'Šotoku (1711–1716)',
				'211' => 'Kjoho (1716–1736)',
				'213' => 'Kanpo (1741–1744)',
				'214' => 'Enkjo (1744–1748)',
				'215' => 'Kan-en (1748–1751)',
				'216' => 'Horjaku (1751–1764)',
				'217' => 'Meiva (1764–1772)',
				'218' => 'An-ei (1772–1781)',
				'221' => 'Kjova (1801–1804)',
				'224' => 'Tenpo (1830–1844)',
				'225' => 'Koka (1844–1848)',
				'228' => 'Man-en (1860–1861)',
				'229' => 'Bunkju (1861–1864)',
				'230' => 'Gendži (1864–1865)',
				'231' => 'Keiko (1865–1868)',
				'232' => 'Meidži',
				'233' => 'Taišo',
				'234' => 'Šova'
			},
		},
		'roc' => {
			abbreviated => {
				'0' => 'Prieš R.O.C.'
			},
		},
	} },
);

has 'date_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'chinese' => {
			'full' => q{U MMMM d, EEEE},
			'long' => q{U MMMM d},
			'medium' => q{U MMM d},
			'short' => q{y-MM-dd},
		},
		'generic' => {
			'full' => q{y MMMM d G, EEEE},
			'long' => q{y MMMM d G},
			'medium' => q{y MMM d G},
			'short' => q{y-MM-dd G},
		},
		'gregorian' => {
			'full' => q{y 'm'. MMMM d 'd'., EEEE},
			'long' => q{y 'm'. MMMM d 'd'.},
			'medium' => q{y-MM-dd},
			'short' => q{y-MM-dd},
		},
		'japanese' => {
		},
		'roc' => {
		},
	} },
);

has 'time_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'chinese' => {
		},
		'generic' => {
		},
		'gregorian' => {
			'full' => q{HH:mm:ss zzzz},
			'long' => q{HH:mm:ss z},
			'medium' => q{HH:mm:ss},
			'short' => q{HH:mm},
		},
		'japanese' => {
		},
		'roc' => {
		},
	} },
);

has 'datetime_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'chinese' => {
			'full' => q{{1} {0}},
			'long' => q{{1} {0}},
			'medium' => q{{1} {0}},
			'short' => q{{1} {0}},
		},
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
		'japanese' => {
		},
		'roc' => {
		},
	} },
);

has 'datetime_formats_available_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'chinese' => {
			Gy => q{U},
			GyMMM => q{U MMM},
			GyMMMEd => q{U MMM d, E},
			GyMMMd => q{U MMM d},
			y => q{U},
			yMd => q{y-MM-dd},
			yyyy => q{U},
			yyyyM => q{y-MM},
			yyyyMEd => q{y-MM-dd, E},
			yyyyMMM => q{U MMM},
			yyyyMMMEd => q{U MMM d, E},
			yyyyMMMd => q{U MMM d},
			yyyyMd => q{y-MM-dd},
			yyyyQQQ => q{U QQQ},
			yyyyQQQQ => q{U QQQQ},
		},
		'generic' => {
			EBhm => q{h:mm B, E},
			EBhms => q{h:mm:ss B, E},
			EHm => q{HH:mm, E},
			EHms => q{HH:mm:ss, E},
			Ehm => q{h:mm a, E},
			Ehms => q{h:mm:ss a, E},
			Gy => q{y G},
			GyMMM => q{y MMM G},
			GyMMMEd => q{y MMM d G, E},
			GyMMMd => q{y MMM d G},
			GyMd => q{y-MM-dd G},
			M => q{LL},
			MMMEd => q{MMM-d, E},
			MMMd => q{MMM-d},
			MMdd => q{MM.dd},
			h => q{h a},
			hm => q{h:mm a},
			hms => q{h:mm:ss a},
			y => q{y G},
			yyyy => q{y G},
			yyyyM => q{y MM G},
			yyyyMEd => q{y-MM-dd G, E},
			yyyyMMM => q{y MMM G},
			yyyyMMMEd => q{y MMM d G, E},
			yyyyMMMd => q{y MMM d G},
			yyyyMd => q{y-MM-dd G},
			yyyyQQQ => q{y G QQQ},
			yyyyQQQQ => q{y G QQQQ},
		},
		'gregorian' => {
			EBhm => q{h:mm B, E},
			EBhms => q{h:mm:ss B, E},
			EHm => q{HH:mm, E},
			EHms => q{HH:mm:ss, E},
			Ehm => q{hh:mm a, E},
			Ehms => q{hh:mm:ss a, E},
			Gy => q{y 'm'. G},
			GyMMM => q{y-MM G},
			GyMMMEd => q{y-MM-dd G, E},
			GyMMMM => q{y 'm'. G, LLLL},
			GyMMMMEd => q{y 'm'. G MMMM d 'd'., E},
			GyMMMMd => q{y 'm'. G MMMM d 'd'.},
			GyMMMd => q{y-MM-dd G},
			GyMd => q{y-MM-dd G},
			Hmsv => q{HH:mm:ss; v},
			Hmv => q{HH:mm; v},
			M => q{MM},
			MMM => q{MM},
			MMMEd => q{MM-dd, E},
			MMMM => q{LLLL},
			MMMMEd => q{MMMM d 'd'., E},
			MMMMW => q{MMMM W 'sav'.},
			MMMMd => q{MMMM d 'd'.},
			MMMd => q{MM-dd},
			MMdd => q{MM-dd},
			Md => q{MM-d},
			d => q{dd},
			h => q{hh a},
			hm => q{hh:mm a},
			hms => q{hh:mm:ss a},
			hmsv => q{hh:mm:ss a; v},
			hmv => q{hh:mm a; v},
			yMMM => q{y-MM},
			yMMMEd => q{y-MM-dd, E},
			yMMMM => q{y 'm'. LLLL},
			yMMMMEd => q{y 'm'. MMMM d 'd'., E},
			yMMMMd => q{y 'm'. MMMM d 'd'.},
			yMMMd => q{y-MM-dd},
			yw => q{Y w 'sav'.},
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
		'chinese' => {
			MEd => {
				M => q{MM-dd, E–MM-dd, E},
				d => q{MM-dd, E–MM-dd, E},
			},
			MMMEd => {
				M => q{MMM d, E–MMM d, E},
				d => q{MMM d, E–MMM d, E},
			},
			MMMd => {
				M => q{MMM d–MMM d},
			},
			Md => {
				M => q{MM-dd–MM-dd},
				d => q{MM-dd–MM-dd},
			},
			yM => {
				M => q{y-MM–y-MM},
				y => q{y-MM–y-MM},
			},
			yMEd => {
				M => q{y-MM-dd, E–y-MM-dd, E},
				d => q{y-MM-dd, E–y-MM-dd, E},
				y => q{y-MM-dd, E–y-MM-dd, E},
			},
			yMMM => {
				y => q{U MMM–U MMM},
			},
			yMMMEd => {
				M => q{U MMM d, E–MMM d, E},
				d => q{U MMM d, E–MMM d, E},
				y => q{U MMM d, E–U MMM d, E},
			},
			yMMMM => {
				y => q{U MMMM–U MMMM},
			},
			yMMMd => {
				M => q{U MMM d–MMM d},
				y => q{U MMM d–U MMM d},
			},
			yMd => {
				M => q{y-MM-dd–y-MM-dd},
				d => q{y-MM-dd–y-MM-dd},
				y => q{y-MM-dd–y-MM-dd},
			},
		},
		'generic' => {
			M => {
				M => q{M–M},
			},
			MEd => {
				M => q{MM-dd, E – MM-dd, E},
				d => q{MM-dd, E – MM-dd, E},
			},
			MMM => {
				M => q{MMM–MMM},
			},
			MMMEd => {
				M => q{MMM d, E – MMM d, E},
				d => q{MMM d, E – MMM d, E},
			},
			MMMd => {
				M => q{MMM d–MMM d},
			},
			Md => {
				M => q{MM-dd–MM-dd},
				d => q{MM-dd–MM-dd},
			},
			h => {
				a => q{h a–h a},
				h => q{h–h a},
			},
			hm => {
				a => q{hh:mm a–hh:mm a},
				h => q{h:mm–h:mm a},
				m => q{h:mm–h:mm a},
			},
			hmv => {
				a => q{hh:mm a–hh:mm a v},
				h => q{h:mm–h:mm a v},
				m => q{h:mm–h:mm a v},
			},
			hv => {
				a => q{h a–h a v},
				h => q{h–h a v},
			},
			y => {
				y => q{y–y G},
			},
			yM => {
				M => q{y-MM – y-MM G},
				y => q{y-MM – y-MM G},
			},
			yMEd => {
				M => q{y-MM-dd G, E – y-MM-dd G, E},
				d => q{y-MM-dd G, E – y-MM-dd G, E},
				y => q{y-MM-dd G, E – y-MM-dd G, E},
			},
			yMMM => {
				M => q{y MMM–MMM G},
				y => q{y-MM – y-MM G},
			},
			yMMMEd => {
				M => q{y-MM-dd G, E – y-MM-dd G, E},
				d => q{y-MM-dd G, E – y-MM-dd G, E},
				y => q{y-MM-dd G, E – y-MM-dd G, E},
			},
			yMMMM => {
				M => q{y LLLL – y LLLL G},
				y => q{y LLLL – y LLLL G},
			},
			yMMMd => {
				M => q{y-MM-dd – MM-d G},
				d => q{y 'm'. MMM d 'd'.–d 'd'. G},
				y => q{y-MM-dd – y-MM-dd G},
			},
			yMd => {
				M => q{y-MM-dd– y-MM-dd G},
				d => q{y-MM-dd–y-MM-dd G},
				y => q{y-MM-dd – y-MM-dd G},
			},
		},
		'gregorian' => {
			Bh => {
				B => q{h B – h B},
				h => q{hh–hh B},
			},
			Bhm => {
				B => q{hh:mm B–hh:mm B},
				h => q{hh:mm–hh:mm B},
				m => q{hh:mm–hh:mm B},
			},
			Gy => {
				G => q{G y – G y},
			},
			GyM => {
				G => q{GGGGG y-MM – GGGGG y-MM},
				M => q{GGGGG y-MM – y-MM},
				y => q{GGGGG y-MM – y-MM},
			},
			GyMEd => {
				G => q{GGGGG y-MM-dd, E – GGGGG y-MM-dd, E},
				M => q{GGGGG y-MM-dd, E – y-MM-dd, E},
				d => q{GGGGG y-MM-dd, E – y-MM-dd, E},
				y => q{GGGGG y-MM-dd, E – y-MM-dd, E},
			},
			GyMMM => {
				G => q{G y MMM – G y MMM},
				y => q{G y MMM – y MMM},
			},
			GyMMMEd => {
				G => q{G y MMM d, E – G y MMM d, E},
				M => q{G y MMM d, E – MMM d, E},
				d => q{G y MMM d, E – MMM d, E},
				y => q{G y MMM d, E – y MMM d, E},
			},
			GyMMMd => {
				G => q{G y MMM d – G y MMM d},
				M => q{G y MMM d – MMM d},
				y => q{G y MMM d – y MMM d},
			},
			GyMd => {
				G => q{GGGGG y-MM-dd – GGGGG y-MM-dd},
				M => q{GGGGG y-MM-dd – y-MM-dd},
				d => q{GGGGG y-MM-dd – y-MM-dd},
				y => q{GGGGG y-MM-dd – y-MM-dd},
			},
			MEd => {
				M => q{MM-dd, E – MM-dd, E},
				d => q{MM-dd, E – MM-dd, E},
			},
			MMMEd => {
				M => q{MMM d, E – MMM d, E},
				d => q{MMM d, E – MMM d, E},
			},
			MMMM => {
				M => q{LLLL–LLLL},
			},
			MMMMEd => {
				M => q{MMMM d, E – MMMM d, E},
				d => q{MMMM d, E – MMMM d, E},
			},
			MMMMd => {
				M => q{MMMM d – MMMM d},
				d => q{MMMM d–d},
			},
			MMMd => {
				M => q{MMM d – MMM d},
			},
			Md => {
				M => q{MM-dd – MM-dd},
				d => q{MM-dd – MM-dd},
			},
			d => {
				d => q{dd–dd},
			},
			h => {
				a => q{h a – h a},
			},
			hv => {
				a => q{h a – h a v},
			},
			yM => {
				M => q{y-MM – y-MM},
				y => q{y-MM – y-MM},
			},
			yMEd => {
				M => q{y-MM-dd, E – y-MM-dd, E},
				d => q{y-MM-dd, E – y-MM-dd, E},
				y => q{y-MM-dd, E – y-MM-dd, E},
			},
			yMMM => {
				y => q{y MMM – y MMM},
			},
			yMMMEd => {
				M => q{y MMM d, E – MMM d, E},
				d => q{y MMM d, E – MMM d, E},
				y => q{y MMM d, E – y MMM d, E},
			},
			yMMMM => {
				M => q{y LLLL–LLLL},
				y => q{y LLLL – y LLLL},
			},
			yMMMMEd => {
				M => q{y MMMM d, E. – MMMM d, E.},
				d => q{y MMMM d, E – MMMM d, E},
				y => q{y MMMM d, E. – y MMMM d, E.},
			},
			yMMMMd => {
				M => q{y MMMM d – MMMM d},
				d => q{y MMMM d–d},
				y => q{y MMMM d – y MMMM d},
			},
			yMMMd => {
				M => q{y MMM d – MMM d},
				y => q{y MMM d – y MMM d},
			},
			yMd => {
				M => q{y-MM-dd – y-MM-dd},
				d => q{y-MM-dd – y-MM-dd},
				y => q{y-MM-dd – y-MM-dd},
			},
		},
	} },
);

has 'cyclic_name_sets' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'chinese' => {
			'solarTerms' => {
				'format' => {
					'abbreviated' => {
						0 => q(pavasario pradžia),
						1 => q(lietaus vanduo),
						2 => q(vabzdžių pabudimas),
						3 => q(pavasario lygiadienis),
						4 => q(šviesu),
						5 => q(lietus javams),
						6 => q(vasaros pradžia),
						7 => q(liūtys),
						8 => q(varpų formavimasis),
						9 => q(vasaros saulėgrįža),
						10 => q(nedidelis karštis),
						11 => q(didelis karštis),
						12 => q(rudens pradžia),
						13 => q(karščių pabaiga),
						14 => q(šerkšnas),
						15 => q(rudens lygiadienis),
						16 => q(šalta rasa),
						17 => q(šalnos),
						18 => q(žiemos pradžia),
						19 => q(nesmarkus snigimas),
						20 => q(smarkus snigimas),
						21 => q(žiemos saulėgrįža),
						22 => q(nedidelis šaltis),
						23 => q(didelis šaltis),
					},
				},
			},
			'zodiacs' => {
				'format' => {
					'abbreviated' => {
						0 => q(Žiurkė),
						1 => q(Jautis),
						2 => q(Tigras),
						3 => q(Triušis),
						4 => q(Drakonas),
						5 => q(Gyvatė),
						6 => q(Arklys),
						7 => q(Ožka),
						8 => q(Beždžionė),
						9 => q(Gaidys),
						10 => q(Šuo),
						11 => q(Kiaulė),
					},
				},
			},
		},
	} },
);

has 'time_zone_names' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default	=> sub { {
		hourFormat => q(+HH:mm;−HH:mm),
		regionFormat => q(Laikas: {0}),
		regionFormat => q(Vasaros laikas: {0}),
		regionFormat => q(Žiemos laikas: {0}),
		'Acre' => {
			long => {
				'daylight' => q#Ako vasaros laikas#,
				'generic' => q#Ako laikas#,
				'standard' => q#Ako standartinis laikas#,
			},
		},
		'Afghanistan' => {
			long => {
				'standard' => q#Afganistano laikas#,
			},
		},
		'Africa/Abidjan' => {
			exemplarCity => q#Abidžanas#,
		},
		'Africa/Accra' => {
			exemplarCity => q#Akra#,
		},
		'Africa/Addis_Ababa' => {
			exemplarCity => q#Adis Abeba#,
		},
		'Africa/Algiers' => {
			exemplarCity => q#Alžyras#,
		},
		'Africa/Bamako' => {
			exemplarCity => q#Bamakas#,
		},
		'Africa/Bangui' => {
			exemplarCity => q#Bangis#,
		},
		'Africa/Banjul' => {
			exemplarCity => q#Bandžulis#,
		},
		'Africa/Bissau' => {
			exemplarCity => q#Bisau#,
		},
		'Africa/Blantyre' => {
			exemplarCity => q#Blantairas#,
		},
		'Africa/Brazzaville' => {
			exemplarCity => q#Brazavilis#,
		},
		'Africa/Bujumbura' => {
			exemplarCity => q#Bužumbūra#,
		},
		'Africa/Cairo' => {
			exemplarCity => q#Kairas#,
		},
		'Africa/Casablanca' => {
			exemplarCity => q#Kasablanka#,
		},
		'Africa/Ceuta' => {
			exemplarCity => q#Seuta#,
		},
		'Africa/Conakry' => {
			exemplarCity => q#Konakris#,
		},
		'Africa/Dakar' => {
			exemplarCity => q#Dakaras#,
		},
		'Africa/Dar_es_Salaam' => {
			exemplarCity => q#Dar es Salamas#,
		},
		'Africa/Djibouti' => {
			exemplarCity => q#Džibutis#,
		},
		'Africa/Douala' => {
			exemplarCity => q#Duala#,
		},
		'Africa/El_Aaiun' => {
			exemplarCity => q#al Ajūnas#,
		},
		'Africa/Freetown' => {
			exemplarCity => q#Fritaunas#,
		},
		'Africa/Gaborone' => {
			exemplarCity => q#Gaboronas#,
		},
		'Africa/Harare' => {
			exemplarCity => q#Hararė#,
		},
		'Africa/Johannesburg' => {
			exemplarCity => q#Johanesburgas#,
		},
		'Africa/Juba' => {
			exemplarCity => q#Džuba#,
		},
		'Africa/Khartoum' => {
			exemplarCity => q#Chartumas#,
		},
		'Africa/Kigali' => {
			exemplarCity => q#Kigalis#,
		},
		'Africa/Kinshasa' => {
			exemplarCity => q#Kinšasa#,
		},
		'Africa/Lagos' => {
			exemplarCity => q#Lagosas#,
		},
		'Africa/Libreville' => {
			exemplarCity => q#Librevilis#,
		},
		'Africa/Lome' => {
			exemplarCity => q#Lomė#,
		},
		'Africa/Lubumbashi' => {
			exemplarCity => q#Lubumbašis#,
		},
		'Africa/Malabo' => {
			exemplarCity => q#Malabas#,
		},
		'Africa/Maputo' => {
			exemplarCity => q#Maputas#,
		},
		'Africa/Mbabane' => {
			exemplarCity => q#Mbabanė#,
		},
		'Africa/Mogadishu' => {
			exemplarCity => q#Mogadišas#,
		},
		'Africa/Monrovia' => {
			exemplarCity => q#Monrovija#,
		},
		'Africa/Nairobi' => {
			exemplarCity => q#Nairobis#,
		},
		'Africa/Ndjamena' => {
			exemplarCity => q#Ndžamena#,
		},
		'Africa/Niamey' => {
			exemplarCity => q#Niamėjus#,
		},
		'Africa/Nouakchott' => {
			exemplarCity => q#Nuakšotas#,
		},
		'Africa/Ouagadougou' => {
			exemplarCity => q#Vagadugu#,
		},
		'Africa/Porto-Novo' => {
			exemplarCity => q#Porto Novas#,
		},
		'Africa/Sao_Tome' => {
			exemplarCity => q#San Tomė#,
		},
		'Africa/Tripoli' => {
			exemplarCity => q#Tripolis#,
		},
		'Africa/Tunis' => {
			exemplarCity => q#Tunisas#,
		},
		'Africa/Windhoek' => {
			exemplarCity => q#Vindhukas#,
		},
		'Africa_Central' => {
			long => {
				'standard' => q#Centrinės Afrikos laikas#,
			},
		},
		'Africa_Eastern' => {
			long => {
				'standard' => q#Rytų Afrikos laikas#,
			},
		},
		'Africa_Southern' => {
			long => {
				'standard' => q#Pietų Afrikos laikas#,
			},
		},
		'Africa_Western' => {
			long => {
				'daylight' => q#Vakarų Afrikos vasaros laikas#,
				'generic' => q#Vakarų Afrikos laikas#,
				'standard' => q#Vakarų Afrikos žiemos laikas#,
			},
		},
		'Alaska' => {
			long => {
				'daylight' => q#Aliaskos vasaros laikas#,
				'generic' => q#Aliaskos laikas#,
				'standard' => q#Aliaskos žiemos laikas#,
			},
		},
		'Almaty' => {
			long => {
				'daylight' => q#Almatos vasaros laikas#,
				'generic' => q#Almatos laikas#,
				'standard' => q#Almatos žiemos laikas#,
			},
		},
		'Amazon' => {
			long => {
				'daylight' => q#Amazonės vasaros laikas#,
				'generic' => q#Amazonės laikas#,
				'standard' => q#Amazonės žiemos laikas#,
			},
		},
		'America/Adak' => {
			exemplarCity => q#Eidakas#,
		},
		'America/Anchorage' => {
			exemplarCity => q#Ankoridžas#,
		},
		'America/Anguilla' => {
			exemplarCity => q#Angilija#,
		},
		'America/Antigua' => {
			exemplarCity => q#Antigva#,
		},
		'America/Araguaina' => {
			exemplarCity => q#Aragvajana#,
		},
		'America/Argentina/La_Rioja' => {
			exemplarCity => q#La Riocha#,
		},
		'America/Argentina/Rio_Gallegos' => {
			exemplarCity => q#Rio Galjegosas#,
		},
		'America/Argentina/Salta' => {
			exemplarCity => q#Saltas#,
		},
		'America/Argentina/San_Juan' => {
			exemplarCity => q#San Chuanas#,
		},
		'America/Argentina/San_Luis' => {
			exemplarCity => q#Sent Luisas#,
		},
		'America/Argentina/Tucuman' => {
			exemplarCity => q#Tukumanas#,
		},
		'America/Argentina/Ushuaia' => {
			exemplarCity => q#Ušuaja#,
		},
		'America/Asuncion' => {
			exemplarCity => q#Asunsjonas#,
		},
		'America/Bahia' => {
			exemplarCity => q#Baija#,
		},
		'America/Bahia_Banderas' => {
			exemplarCity => q#Bahia Banderasas#,
		},
		'America/Barbados' => {
			exemplarCity => q#Barbadosas#,
		},
		'America/Belem' => {
			exemplarCity => q#Belenas#,
		},
		'America/Belize' => {
			exemplarCity => q#Belizas#,
		},
		'America/Blanc-Sablon' => {
			exemplarCity => q#Blanč Sablonas#,
		},
		'America/Boa_Vista' => {
			exemplarCity => q#Bua Vista#,
		},
		'America/Boise' => {
			exemplarCity => q#Boisis#,
		},
		'America/Buenos_Aires' => {
			exemplarCity => q#Buenos Airės#,
		},
		'America/Cambridge_Bay' => {
			exemplarCity => q#Keimbridž Bėjus#,
		},
		'America/Campo_Grande' => {
			exemplarCity => q#Kampo Grandė#,
		},
		'America/Cancun' => {
			exemplarCity => q#Kankūnas#,
		},
		'America/Caracas' => {
			exemplarCity => q#Karakasas#,
		},
		'America/Catamarca' => {
			exemplarCity => q#Katamarka#,
		},
		'America/Cayenne' => {
			exemplarCity => q#Kajenas#,
		},
		'America/Cayman' => {
			exemplarCity => q#Kaimanas#,
		},
		'America/Chicago' => {
			exemplarCity => q#Čikaga#,
		},
		'America/Chihuahua' => {
			exemplarCity => q#Čihuahua#,
		},
		'America/Ciudad_Juarez' => {
			exemplarCity => q#Siudad Chuaresas#,
		},
		'America/Coral_Harbour' => {
			exemplarCity => q#Atikokanas#,
		},
		'America/Cordoba' => {
			exemplarCity => q#Kordoba#,
		},
		'America/Costa_Rica' => {
			exemplarCity => q#Kosta Rika#,
		},
		'America/Creston' => {
			exemplarCity => q#Krestonas#,
		},
		'America/Cuiaba' => {
			exemplarCity => q#Kujaba#,
		},
		'America/Curacao' => {
			exemplarCity => q#Kiurasao#,
		},
		'America/Danmarkshavn' => {
			exemplarCity => q#Danmarkshaunas#,
		},
		'America/Dawson' => {
			exemplarCity => q#Dosonas#,
		},
		'America/Dawson_Creek' => {
			exemplarCity => q#Doson Krikas#,
		},
		'America/Denver' => {
			exemplarCity => q#Denveris#,
		},
		'America/Detroit' => {
			exemplarCity => q#Detroitas#,
		},
		'America/Dominica' => {
			exemplarCity => q#Dominika#,
		},
		'America/Edmonton' => {
			exemplarCity => q#Edmontonas#,
		},
		'America/Eirunepe' => {
			exemplarCity => q#Eirunepė#,
		},
		'America/El_Salvador' => {
			exemplarCity => q#Salvadoras#,
		},
		'America/Fort_Nelson' => {
			exemplarCity => q#Fort Nelsonas#,
		},
		'America/Glace_Bay' => {
			exemplarCity => q#Gleis Bėjus#,
		},
		'America/Godthab' => {
			exemplarCity => q#Nūkas#,
		},
		'America/Goose_Bay' => {
			exemplarCity => q#Gus Bėjus#,
		},
		'America/Grand_Turk' => {
			exemplarCity => q#Grand Terkas#,
		},
		'America/Guadeloupe' => {
			exemplarCity => q#Gvadalupė#,
		},
		'America/Guatemala' => {
			exemplarCity => q#Gvatemala#,
		},
		'America/Guayaquil' => {
			exemplarCity => q#Gvajakilis#,
		},
		'America/Guyana' => {
			exemplarCity => q#Gvajana#,
		},
		'America/Halifax' => {
			exemplarCity => q#Halifaksas#,
		},
		'America/Hermosillo' => {
			exemplarCity => q#Hermosiljas#,
		},
		'America/Indiana/Knox' => {
			exemplarCity => q#Noksas, Indiana#,
		},
		'America/Indiana/Marengo' => {
			exemplarCity => q#Marengas, Indiana#,
		},
		'America/Indiana/Petersburg' => {
			exemplarCity => q#Pitersbergas, Indiana#,
		},
		'America/Indiana/Tell_City' => {
			exemplarCity => q#Tel Sitis, Indiana#,
		},
		'America/Indiana/Vevay' => {
			exemplarCity => q#Vivis, Indiana#,
		},
		'America/Indiana/Vincennes' => {
			exemplarCity => q#Vinsenas, Indiana#,
		},
		'America/Indiana/Winamac' => {
			exemplarCity => q#Vinamakas, Indiana#,
		},
		'America/Inuvik' => {
			exemplarCity => q#Inuvikas#,
		},
		'America/Iqaluit' => {
			exemplarCity => q#Ikaluitas#,
		},
		'America/Jamaica' => {
			exemplarCity => q#Jamaika#,
		},
		'America/Jujuy' => {
			exemplarCity => q#Chuchujus#,
		},
		'America/Juneau' => {
			exemplarCity => q#Džunas#,
		},
		'America/Kentucky/Monticello' => {
			exemplarCity => q#Montiselas, Kentukis#,
		},
		'America/Kralendijk' => {
			exemplarCity => q#Kralendeikas#,
		},
		'America/La_Paz' => {
			exemplarCity => q#La Pasas#,
		},
		'America/Los_Angeles' => {
			exemplarCity => q#Los Andželas#,
		},
		'America/Louisville' => {
			exemplarCity => q#Luisvilis#,
		},
		'America/Lower_Princes' => {
			exemplarCity => q#Žemutinis Prinses Kvorteris#,
		},
		'America/Maceio' => {
			exemplarCity => q#Masejo#,
		},
		'America/Managua' => {
			exemplarCity => q#Managva#,
		},
		'America/Manaus' => {
			exemplarCity => q#Manausas#,
		},
		'America/Marigot' => {
			exemplarCity => q#Marigo#,
		},
		'America/Martinique' => {
			exemplarCity => q#Martinika#,
		},
		'America/Matamoros' => {
			exemplarCity => q#Matamorosas#,
		},
		'America/Mazatlan' => {
			exemplarCity => q#Masatlanas#,
		},
		'America/Mendoza' => {
			exemplarCity => q#Mendosa#,
		},
		'America/Menominee' => {
			exemplarCity => q#Menominis#,
		},
		'America/Merida' => {
			exemplarCity => q#Merida#,
		},
		'America/Mexico_City' => {
			exemplarCity => q#Meksikas#,
		},
		'America/Miquelon' => {
			exemplarCity => q#Mikelonas#,
		},
		'America/Moncton' => {
			exemplarCity => q#Monktonas#,
		},
		'America/Monterrey' => {
			exemplarCity => q#Monterėjus#,
		},
		'America/Montevideo' => {
			exemplarCity => q#Montevidėjas#,
		},
		'America/Montserrat' => {
			exemplarCity => q#Montseratas#,
		},
		'America/Nassau' => {
			exemplarCity => q#Nasau#,
		},
		'America/New_York' => {
			exemplarCity => q#Niujorkas#,
		},
		'America/Nome' => {
			exemplarCity => q#Nomas#,
		},
		'America/Noronha' => {
			exemplarCity => q#Noronja#,
		},
		'America/North_Dakota/Beulah' => {
			exemplarCity => q#Bjula, Šiaurės Dakota#,
		},
		'America/North_Dakota/Center' => {
			exemplarCity => q#Senteris, Šiaurės Dakota#,
		},
		'America/North_Dakota/New_Salem' => {
			exemplarCity => q#Niu Seilemas, Šiaurės Dakota#,
		},
		'America/Ojinaga' => {
			exemplarCity => q#Ochinaga#,
		},
		'America/Paramaribo' => {
			exemplarCity => q#Paramaribas#,
		},
		'America/Phoenix' => {
			exemplarCity => q#Finiksas#,
		},
		'America/Port-au-Prince' => {
			exemplarCity => q#Port o Prensas#,
		},
		'America/Port_of_Spain' => {
			exemplarCity => q#Port of Speinas#,
		},
		'America/Porto_Velho' => {
			exemplarCity => q#Porto Veljas#,
		},
		'America/Puerto_Rico' => {
			exemplarCity => q#Puerto Rikas#,
		},
		'America/Punta_Arenas' => {
			exemplarCity => q#Punta Arenasas#,
		},
		'America/Rankin_Inlet' => {
			exemplarCity => q#Rankin Inletas#,
		},
		'America/Recife' => {
			exemplarCity => q#Resifė#,
		},
		'America/Regina' => {
			exemplarCity => q#Redžina#,
		},
		'America/Resolute' => {
			exemplarCity => q#Resolutas#,
		},
		'America/Rio_Branco' => {
			exemplarCity => q#Rio Brankas#,
		},
		'America/Santarem' => {
			exemplarCity => q#Santarenas#,
		},
		'America/Santiago' => {
			exemplarCity => q#Santjagas#,
		},
		'America/Santo_Domingo' => {
			exemplarCity => q#Santo Domingas#,
		},
		'America/Sao_Paulo' => {
			exemplarCity => q#San Paulas#,
		},
		'America/Scoresbysund' => {
			exemplarCity => q#Itokortormitas#,
		},
		'America/St_Barthelemy' => {
			exemplarCity => q#Sen Bartelemi#,
		},
		'America/St_Johns' => {
			exemplarCity => q#Sent Džonsas#,
		},
		'America/St_Kitts' => {
			exemplarCity => q#Sent Kitsas#,
		},
		'America/St_Lucia' => {
			exemplarCity => q#Sent Lusija#,
		},
		'America/St_Thomas' => {
			exemplarCity => q#Sent Tomasas#,
		},
		'America/St_Vincent' => {
			exemplarCity => q#Sent Vincentas#,
		},
		'America/Swift_Current' => {
			exemplarCity => q#Svift Karentas#,
		},
		'America/Tegucigalpa' => {
			exemplarCity => q#Tegusigalpa#,
		},
		'America/Thule' => {
			exemplarCity => q#Kanakas#,
		},
		'America/Tijuana' => {
			exemplarCity => q#Tichuana#,
		},
		'America/Toronto' => {
			exemplarCity => q#Torontas#,
		},
		'America/Vancouver' => {
			exemplarCity => q#Vankuveris#,
		},
		'America/Whitehorse' => {
			exemplarCity => q#Vaithorsas#,
		},
		'America/Winnipeg' => {
			exemplarCity => q#Vinipegas#,
		},
		'America/Yakutat' => {
			exemplarCity => q#Jakutatas#,
		},
		'America_Central' => {
			long => {
				'daylight' => q#Šiaurės Amerikos centro vasaros laikas#,
				'generic' => q#Šiaurės Amerikos centro laikas#,
				'standard' => q#Šiaurės Amerikos centro žiemos laikas#,
			},
		},
		'America_Eastern' => {
			long => {
				'daylight' => q#Šiaurės Amerikos rytų vasaros laikas#,
				'generic' => q#Šiaurės Amerikos rytų laikas#,
				'standard' => q#Šiaurės Amerikos rytų žiemos laikas#,
			},
		},
		'America_Mountain' => {
			long => {
				'daylight' => q#Šiaurės Amerikos kalnų vasaros laikas#,
				'generic' => q#Šiaurės Amerikos kalnų laikas#,
				'standard' => q#Šiaurės Amerikos kalnų žiemos laikas#,
			},
		},
		'America_Pacific' => {
			long => {
				'daylight' => q#Šiaurės Amerikos Ramiojo vandenyno vasaros laikas#,
				'generic' => q#Šiaurės Amerikos Ramiojo vandenyno laikas#,
				'standard' => q#Šiaurės Amerikos Ramiojo vandenyno žiemos laikas#,
			},
		},
		'Anadyr' => {
			long => {
				'daylight' => q#Anadyrės vasaros laikas#,
				'generic' => q#Anadyrės laikas#,
				'standard' => q#Anadyrės žiemos laikas#,
			},
		},
		'Antarctica/Casey' => {
			exemplarCity => q#Keisis#,
		},
		'Antarctica/Davis' => {
			exemplarCity => q#Deivisas#,
		},
		'Antarctica/DumontDUrville' => {
			exemplarCity => q#Diumonas d’Urvilis#,
		},
		'Antarctica/Macquarie' => {
			exemplarCity => q#Makvoris#,
		},
		'Antarctica/Mawson' => {
			exemplarCity => q#Mosonas#,
		},
		'Antarctica/McMurdo' => {
			exemplarCity => q#Makmerdas#,
		},
		'Antarctica/Palmer' => {
			exemplarCity => q#Palmeris#,
		},
		'Antarctica/Rothera' => {
			exemplarCity => q#Rotera#,
		},
		'Antarctica/Syowa' => {
			exemplarCity => q#Siova#,
		},
		'Antarctica/Troll' => {
			exemplarCity => q#Trolis#,
		},
		'Antarctica/Vostok' => {
			exemplarCity => q#Vostokas#,
		},
		'Apia' => {
			long => {
				'daylight' => q#Apijos vasaros laikas#,
				'generic' => q#Apijos laikas#,
				'standard' => q#Apijos žiemos laikas#,
			},
		},
		'Aqtau' => {
			long => {
				'daylight' => q#Aktau vasaros laikas#,
				'generic' => q#Aktau laikas#,
				'standard' => q#Aktau žiemos laikas#,
			},
		},
		'Aqtobe' => {
			long => {
				'daylight' => q#Aktobės vasaros laikas#,
				'generic' => q#Aktobės laikas#,
				'standard' => q#Aktobės žiemos laikas#,
			},
		},
		'Arabian' => {
			long => {
				'daylight' => q#Arabijos vasaros laikas#,
				'generic' => q#Arabijos laikas#,
				'standard' => q#Arabijos žiemos laikas#,
			},
		},
		'Arctic/Longyearbyen' => {
			exemplarCity => q#Longjyrbienas#,
		},
		'Argentina' => {
			long => {
				'daylight' => q#Argentinos vasaros laikas#,
				'generic' => q#Argentinos laikas#,
				'standard' => q#Argentinos žiemos laikas#,
			},
		},
		'Argentina_Western' => {
			long => {
				'daylight' => q#Vakarų Argentinos vasaros laikas#,
				'generic' => q#Vakarų Argentinos laikas#,
				'standard' => q#Vakarų Argentinos žiemos laikas#,
			},
		},
		'Armenia' => {
			long => {
				'daylight' => q#Armėnijos vasaros laikas#,
				'generic' => q#Armėnijos laikas#,
				'standard' => q#Armėnijos žiemos laikas#,
			},
		},
		'Asia/Aden' => {
			exemplarCity => q#Adenas#,
		},
		'Asia/Almaty' => {
			exemplarCity => q#Alma Ata#,
		},
		'Asia/Amman' => {
			exemplarCity => q#Amanas#,
		},
		'Asia/Anadyr' => {
			exemplarCity => q#Anadyris#,
		},
		'Asia/Aqtau' => {
			exemplarCity => q#Aktau#,
		},
		'Asia/Aqtobe' => {
			exemplarCity => q#Aktiubinskas#,
		},
		'Asia/Ashgabat' => {
			exemplarCity => q#Ašchabadas#,
		},
		'Asia/Baghdad' => {
			exemplarCity => q#Bagdadas#,
		},
		'Asia/Bahrain' => {
			exemplarCity => q#Bahreinas#,
		},
		'Asia/Bangkok' => {
			exemplarCity => q#Bankokas#,
		},
		'Asia/Barnaul' => {
			exemplarCity => q#Barnaulas#,
		},
		'Asia/Beirut' => {
			exemplarCity => q#Beirutas#,
		},
		'Asia/Bishkek' => {
			exemplarCity => q#Biškekas#,
		},
		'Asia/Brunei' => {
			exemplarCity => q#Brunėjus#,
		},
		'Asia/Chita' => {
			exemplarCity => q#Čita#,
		},
		'Asia/Colombo' => {
			exemplarCity => q#Kolombas#,
		},
		'Asia/Damascus' => {
			exemplarCity => q#Damaskas#,
		},
		'Asia/Dhaka' => {
			exemplarCity => q#Daka#,
		},
		'Asia/Dili' => {
			exemplarCity => q#Dilis#,
		},
		'Asia/Dubai' => {
			exemplarCity => q#Dubajus#,
		},
		'Asia/Dushanbe' => {
			exemplarCity => q#Dušanbė#,
		},
		'Asia/Gaza' => {
			exemplarCity => q#Gazos ruožas#,
		},
		'Asia/Hebron' => {
			exemplarCity => q#Hebronas#,
		},
		'Asia/Hong_Kong' => {
			exemplarCity => q#Honkongas#,
		},
		'Asia/Hovd' => {
			exemplarCity => q#Hovdas#,
		},
		'Asia/Irkutsk' => {
			exemplarCity => q#Irkutskas#,
		},
		'Asia/Jakarta' => {
			exemplarCity => q#Džakarta#,
		},
		'Asia/Jayapura' => {
			exemplarCity => q#Džajapura#,
		},
		'Asia/Jerusalem' => {
			exemplarCity => q#Jeruzalė#,
		},
		'Asia/Kabul' => {
			exemplarCity => q#Kabulas#,
		},
		'Asia/Kamchatka' => {
			exemplarCity => q#Kamčiatka#,
		},
		'Asia/Karachi' => {
			exemplarCity => q#Karačis#,
		},
		'Asia/Katmandu' => {
			exemplarCity => q#Katmandu#,
		},
		'Asia/Khandyga' => {
			exemplarCity => q#Chandyga#,
		},
		'Asia/Krasnoyarsk' => {
			exemplarCity => q#Krasnojarskas#,
		},
		'Asia/Kuala_Lumpur' => {
			exemplarCity => q#Kvala Lumpūras#,
		},
		'Asia/Kuching' => {
			exemplarCity => q#Kučingas#,
		},
		'Asia/Kuwait' => {
			exemplarCity => q#Kuveitas#,
		},
		'Asia/Macau' => {
			exemplarCity => q#Makao#,
		},
		'Asia/Magadan' => {
			exemplarCity => q#Magadanas#,
		},
		'Asia/Makassar' => {
			exemplarCity => q#Makasaras#,
		},
		'Asia/Muscat' => {
			exemplarCity => q#Maskatas#,
		},
		'Asia/Nicosia' => {
			exemplarCity => q#Nikosija#,
		},
		'Asia/Novokuznetsk' => {
			exemplarCity => q#Novokuzneckas#,
		},
		'Asia/Novosibirsk' => {
			exemplarCity => q#Novosibirskas#,
		},
		'Asia/Omsk' => {
			exemplarCity => q#Omskas#,
		},
		'Asia/Oral' => {
			exemplarCity => q#Uralskas#,
		},
		'Asia/Phnom_Penh' => {
			exemplarCity => q#Pnompenis#,
		},
		'Asia/Pontianak' => {
			exemplarCity => q#Pontianakas#,
		},
		'Asia/Pyongyang' => {
			exemplarCity => q#Pchenjanas#,
		},
		'Asia/Qatar' => {
			exemplarCity => q#Kataras#,
		},
		'Asia/Qostanay' => {
			exemplarCity => q#Kostanajus#,
		},
		'Asia/Qyzylorda' => {
			exemplarCity => q#Kzyl-Orda#,
		},
		'Asia/Rangoon' => {
			exemplarCity => q#Rangūnas#,
		},
		'Asia/Riyadh' => {
			exemplarCity => q#Rijadas#,
		},
		'Asia/Saigon' => {
			exemplarCity => q#Hošiminas#,
		},
		'Asia/Sakhalin' => {
			exemplarCity => q#Sachalinas#,
		},
		'Asia/Samarkand' => {
			exemplarCity => q#Samarkandas#,
		},
		'Asia/Seoul' => {
			exemplarCity => q#Seulas#,
		},
		'Asia/Shanghai' => {
			exemplarCity => q#Šanchajus#,
		},
		'Asia/Singapore' => {
			exemplarCity => q#Singapūras#,
		},
		'Asia/Srednekolymsk' => {
			exemplarCity => q#Srednekolymskas#,
		},
		'Asia/Taipei' => {
			exemplarCity => q#Taipėjus#,
		},
		'Asia/Tashkent' => {
			exemplarCity => q#Taškentas#,
		},
		'Asia/Tbilisi' => {
			exemplarCity => q#Tbilisis#,
		},
		'Asia/Tehran' => {
			exemplarCity => q#Teheranas#,
		},
		'Asia/Thimphu' => {
			exemplarCity => q#Timpu#,
		},
		'Asia/Tokyo' => {
			exemplarCity => q#Tokijas#,
		},
		'Asia/Tomsk' => {
			exemplarCity => q#Tomskas#,
		},
		'Asia/Ulaanbaatar' => {
			exemplarCity => q#Ulan Batoras#,
		},
		'Asia/Urumqi' => {
			exemplarCity => q#Urumči#,
		},
		'Asia/Ust-Nera' => {
			exemplarCity => q#Ust Nera#,
		},
		'Asia/Vientiane' => {
			exemplarCity => q#Vientianas#,
		},
		'Asia/Vladivostok' => {
			exemplarCity => q#Vladivostokas#,
		},
		'Asia/Yakutsk' => {
			exemplarCity => q#Jakutskas#,
		},
		'Asia/Yekaterinburg' => {
			exemplarCity => q#Jekaterinburgas#,
		},
		'Asia/Yerevan' => {
			exemplarCity => q#Jerevanas#,
		},
		'Atlantic' => {
			long => {
				'daylight' => q#Atlanto vasaros laikas#,
				'generic' => q#Atlanto laikas#,
				'standard' => q#Atlanto žiemos laikas#,
			},
		},
		'Atlantic/Azores' => {
			exemplarCity => q#Azorai#,
		},
		'Atlantic/Canary' => {
			exemplarCity => q#Kanarų salos#,
		},
		'Atlantic/Cape_Verde' => {
			exemplarCity => q#Žaliasis Kyšulys#,
		},
		'Atlantic/Faeroe' => {
			exemplarCity => q#Farerai#,
		},
		'Atlantic/Reykjavik' => {
			exemplarCity => q#Reikjavikas#,
		},
		'Atlantic/South_Georgia' => {
			exemplarCity => q#Pietų Džordžija#,
		},
		'Atlantic/St_Helena' => {
			exemplarCity => q#Sent Helena#,
		},
		'Atlantic/Stanley' => {
			exemplarCity => q#Stenlis#,
		},
		'Australia/Adelaide' => {
			exemplarCity => q#Adelaidė#,
		},
		'Australia/Brisbane' => {
			exemplarCity => q#Brisbanas#,
		},
		'Australia/Broken_Hill' => {
			exemplarCity => q#Broken Hilis#,
		},
		'Australia/Darwin' => {
			exemplarCity => q#Darvinas#,
		},
		'Australia/Eucla' => {
			exemplarCity => q#Jukla#,
		},
		'Australia/Hobart' => {
			exemplarCity => q#Hobartas#,
		},
		'Australia/Lindeman' => {
			exemplarCity => q#Lindemanas#,
		},
		'Australia/Lord_Howe' => {
			exemplarCity => q#Lordo Hau sala#,
		},
		'Australia/Melbourne' => {
			exemplarCity => q#Melburnas#,
		},
		'Australia/Perth' => {
			exemplarCity => q#Pertas#,
		},
		'Australia/Sydney' => {
			exemplarCity => q#Sidnėjus#,
		},
		'Australia_Central' => {
			long => {
				'daylight' => q#Centrinės Australijos vasaros laikas#,
				'generic' => q#Centrinės Australijos laikas#,
				'standard' => q#Centrinės Australijos žiemos laikas#,
			},
		},
		'Australia_CentralWestern' => {
			long => {
				'daylight' => q#Centrinės vakarų Australijos vasaros laikas#,
				'generic' => q#Centrinės vakarų Australijos laikas#,
				'standard' => q#Centrinės vakarų Australijos žiemos laikas#,
			},
		},
		'Australia_Eastern' => {
			long => {
				'daylight' => q#Rytų Australijos vasaros laikas#,
				'generic' => q#Rytų Australijos laikas#,
				'standard' => q#Rytų Australijos žiemos laikas#,
			},
		},
		'Australia_Western' => {
			long => {
				'daylight' => q#Vakarų Australijos vasaros laikas#,
				'generic' => q#Vakarų Australijos laikas#,
				'standard' => q#Vakarų Australijos žiemos laikas#,
			},
		},
		'Azerbaijan' => {
			long => {
				'daylight' => q#Azerbaidžano vasaros laikas#,
				'generic' => q#Azerbaidžano laikas#,
				'standard' => q#Azerbaidžano žiemos laikas#,
			},
		},
		'Azores' => {
			long => {
				'daylight' => q#Azorų Salų vasaros laikas#,
				'generic' => q#Azorų Salų laikas#,
				'standard' => q#Azorų Salų žiemos laikas#,
			},
		},
		'Bangladesh' => {
			long => {
				'daylight' => q#Bangladešo vasaros laikas#,
				'generic' => q#Bangladešo laikas#,
				'standard' => q#Bangladešo žiemos laikas#,
			},
		},
		'Bhutan' => {
			long => {
				'standard' => q#Butano laikas#,
			},
		},
		'Bolivia' => {
			long => {
				'standard' => q#Bolivijos laikas#,
			},
		},
		'Brasilia' => {
			long => {
				'daylight' => q#Brazilijos vasaros laikas#,
				'generic' => q#Brazilijos laikas#,
				'standard' => q#Brazilijos žiemos laikas#,
			},
		},
		'Brunei' => {
			long => {
				'standard' => q#Brunėjaus Darusalamo laikas#,
			},
		},
		'Cape_Verde' => {
			long => {
				'daylight' => q#Žaliojo Kyšulio vasaros laikas#,
				'generic' => q#Žaliojo Kyšulio laikas#,
				'standard' => q#Žaliojo Kyšulio žiemos laikas#,
			},
		},
		'Casey' => {
			long => {
				'standard' => q#Keisio laikas#,
			},
		},
		'Chamorro' => {
			long => {
				'standard' => q#Čamoro laikas#,
			},
		},
		'Chatham' => {
			long => {
				'daylight' => q#Čatamo vasaros laikas#,
				'generic' => q#Čatamo laikas#,
				'standard' => q#Čatamo žiemos laikas#,
			},
		},
		'Chile' => {
			long => {
				'daylight' => q#Čilės vasaros laikas#,
				'generic' => q#Čilės laikas#,
				'standard' => q#Čilės žiemos laikas#,
			},
		},
		'China' => {
			long => {
				'daylight' => q#Kinijos vasaros laikas#,
				'generic' => q#Kinijos laikas#,
				'standard' => q#Kinijos žiemos laikas#,
			},
		},
		'Christmas' => {
			long => {
				'standard' => q#Kalėdų Salos laikas#,
			},
		},
		'Cocos' => {
			long => {
				'standard' => q#Kokosų Salų laikas#,
			},
		},
		'Colombia' => {
			long => {
				'daylight' => q#Kolumbijos vasaros laikas#,
				'generic' => q#Kolumbijos laikas#,
				'standard' => q#Kolumbijos žiemos laikas#,
			},
		},
		'Cook' => {
			long => {
				'daylight' => q#Kuko Salų pusės vasaros laikas#,
				'generic' => q#Kuko Salų laikas#,
				'standard' => q#Kuko Salų žiemos laikas#,
			},
		},
		'Cuba' => {
			long => {
				'daylight' => q#Kubos vasaros laikas#,
				'generic' => q#Kubos laikas#,
				'standard' => q#Kubos žiemos laikas#,
			},
		},
		'Davis' => {
			long => {
				'standard' => q#Deiviso laikas#,
			},
		},
		'DumontDUrville' => {
			long => {
				'standard' => q#Diumono d’Urvilio laikas#,
			},
		},
		'East_Timor' => {
			long => {
				'standard' => q#Rytų Timoro laikas#,
			},
		},
		'Easter' => {
			long => {
				'daylight' => q#Velykų Salos vasaros laikas#,
				'generic' => q#Velykų Salos laikas#,
				'standard' => q#Velykų salos žiemos laikas#,
			},
		},
		'Ecuador' => {
			long => {
				'standard' => q#Ekvadoro laikas#,
			},
		},
		'Etc/UTC' => {
			long => {
				'standard' => q#pasaulio suderintasis laikas#,
			},
		},
		'Etc/Unknown' => {
			exemplarCity => q#nežinomas miestas#,
		},
		'Europe/Amsterdam' => {
			exemplarCity => q#Amsterdamas#,
		},
		'Europe/Andorra' => {
			exemplarCity => q#Andora#,
		},
		'Europe/Astrakhan' => {
			exemplarCity => q#Astrachanė#,
		},
		'Europe/Athens' => {
			exemplarCity => q#Atėnai#,
		},
		'Europe/Belgrade' => {
			exemplarCity => q#Belgradas#,
		},
		'Europe/Berlin' => {
			exemplarCity => q#Berlynas#,
		},
		'Europe/Brussels' => {
			exemplarCity => q#Briuselis#,
		},
		'Europe/Bucharest' => {
			exemplarCity => q#Bukareštas#,
		},
		'Europe/Budapest' => {
			exemplarCity => q#Budapeštas#,
		},
		'Europe/Busingen' => {
			exemplarCity => q#Biusingenas#,
		},
		'Europe/Chisinau' => {
			exemplarCity => q#Kišiniovas#,
		},
		'Europe/Copenhagen' => {
			exemplarCity => q#Kopenhaga#,
		},
		'Europe/Dublin' => {
			exemplarCity => q#Dublinas#,
			long => {
				'daylight' => q#Airijos vasaros laikas#,
			},
		},
		'Europe/Gibraltar' => {
			exemplarCity => q#Gibraltaras#,
		},
		'Europe/Guernsey' => {
			exemplarCity => q#Gernsis#,
		},
		'Europe/Helsinki' => {
			exemplarCity => q#Helsinkis#,
		},
		'Europe/Isle_of_Man' => {
			exemplarCity => q#Meno sala#,
		},
		'Europe/Istanbul' => {
			exemplarCity => q#Stambulas#,
		},
		'Europe/Jersey' => {
			exemplarCity => q#Džersis#,
		},
		'Europe/Kaliningrad' => {
			exemplarCity => q#Kaliningradas#,
		},
		'Europe/Kiev' => {
			exemplarCity => q#Kijevas#,
		},
		'Europe/Kirov' => {
			exemplarCity => q#Kirovas#,
		},
		'Europe/Lisbon' => {
			exemplarCity => q#Lisabona#,
		},
		'Europe/Ljubljana' => {
			exemplarCity => q#Liubliana#,
		},
		'Europe/London' => {
			exemplarCity => q#Londonas#,
			long => {
				'daylight' => q#Britanijos vasaros laikas#,
			},
		},
		'Europe/Luxembourg' => {
			exemplarCity => q#Liuksemburgas#,
		},
		'Europe/Madrid' => {
			exemplarCity => q#Madridas#,
		},
		'Europe/Mariehamn' => {
			exemplarCity => q#Marianhamina#,
		},
		'Europe/Minsk' => {
			exemplarCity => q#Minskas#,
		},
		'Europe/Monaco' => {
			exemplarCity => q#Monakas#,
		},
		'Europe/Moscow' => {
			exemplarCity => q#Maskva#,
		},
		'Europe/Oslo' => {
			exemplarCity => q#Oslas#,
		},
		'Europe/Paris' => {
			exemplarCity => q#Paryžius#,
		},
		'Europe/Prague' => {
			exemplarCity => q#Praha#,
		},
		'Europe/Riga' => {
			exemplarCity => q#Ryga#,
		},
		'Europe/Rome' => {
			exemplarCity => q#Roma#,
		},
		'Europe/San_Marino' => {
			exemplarCity => q#San Marinas#,
		},
		'Europe/Sarajevo' => {
			exemplarCity => q#Sarajevas#,
		},
		'Europe/Saratov' => {
			exemplarCity => q#Saratovas#,
		},
		'Europe/Simferopol' => {
			exemplarCity => q#Simferopolis#,
		},
		'Europe/Skopje' => {
			exemplarCity => q#Skopjė#,
		},
		'Europe/Sofia' => {
			exemplarCity => q#Sofija#,
		},
		'Europe/Stockholm' => {
			exemplarCity => q#Stokholmas#,
		},
		'Europe/Tallinn' => {
			exemplarCity => q#Talinas#,
		},
		'Europe/Tirane' => {
			exemplarCity => q#Tirana#,
		},
		'Europe/Ulyanovsk' => {
			exemplarCity => q#Uljanovskas#,
		},
		'Europe/Vaduz' => {
			exemplarCity => q#Vaducas#,
		},
		'Europe/Vatican' => {
			exemplarCity => q#Vatikanas#,
		},
		'Europe/Vienna' => {
			exemplarCity => q#Viena#,
		},
		'Europe/Volgograd' => {
			exemplarCity => q#Volgogradas#,
		},
		'Europe/Warsaw' => {
			exemplarCity => q#Varšuva#,
		},
		'Europe/Zagreb' => {
			exemplarCity => q#Zagrebas#,
		},
		'Europe/Zurich' => {
			exemplarCity => q#Ciurichas#,
		},
		'Europe_Central' => {
			long => {
				'daylight' => q#Vidurio Europos vasaros laikas#,
				'generic' => q#Vidurio Europos laikas#,
				'standard' => q#Vidurio Europos žiemos laikas#,
			},
		},
		'Europe_Eastern' => {
			long => {
				'daylight' => q#Rytų Europos vasaros laikas#,
				'generic' => q#Rytų Europos laikas#,
				'standard' => q#Rytų Europos žiemos laikas#,
			},
		},
		'Europe_Further_Eastern' => {
			long => {
				'standard' => q#Tolimųjų rytų Europos laikas#,
			},
		},
		'Europe_Western' => {
			long => {
				'daylight' => q#Vakarų Europos vasaros laikas#,
				'generic' => q#Vakarų Europos laikas#,
				'standard' => q#Vakarų Europos žiemos laikas#,
			},
		},
		'Falkland' => {
			long => {
				'daylight' => q#Folklando Salų vasaros laikas#,
				'generic' => q#Folklando Salų laikas#,
				'standard' => q#Folklandų Salų žiemos laikas#,
			},
		},
		'Fiji' => {
			long => {
				'daylight' => q#Fidžio vasaros laikas#,
				'generic' => q#Fidžio laikas#,
				'standard' => q#Fidžio žiemos laikas#,
			},
		},
		'French_Guiana' => {
			long => {
				'standard' => q#Prancūzijos Gvianos laikas#,
			},
		},
		'French_Southern' => {
			long => {
				'standard' => q#Pietų Prancūzijos ir antarktinis laikas#,
			},
		},
		'GMT' => {
			long => {
				'standard' => q#Grinvičo laikas#,
			},
		},
		'Galapagos' => {
			long => {
				'standard' => q#Galapagų laikas#,
			},
		},
		'Gambier' => {
			long => {
				'standard' => q#Gambyro laikas#,
			},
		},
		'Georgia' => {
			long => {
				'daylight' => q#Gruzijos vasaros laikas#,
				'generic' => q#Gruzijos laikas#,
				'standard' => q#Gruzijos žiemos laikas#,
			},
		},
		'Gilbert_Islands' => {
			long => {
				'standard' => q#Gilberto Salų laikas#,
			},
		},
		'Greenland_Eastern' => {
			long => {
				'daylight' => q#Grenlandijos rytų vasaros laikas#,
				'generic' => q#Grenlandijos rytų laikas#,
				'standard' => q#Grenlandijos rytų žiemos laikas#,
			},
		},
		'Greenland_Western' => {
			long => {
				'daylight' => q#Grenlandijos vakarų vasaros laikas#,
				'generic' => q#Grenlandijos vakarų laikas#,
				'standard' => q#Grenlandijos vakarų žiemos laikas#,
			},
		},
		'Guam' => {
			long => {
				'standard' => q#Guamo laikas#,
			},
		},
		'Gulf' => {
			long => {
				'standard' => q#Persijos įlankos laikas#,
			},
		},
		'Guyana' => {
			long => {
				'standard' => q#Gajanos laikas#,
			},
		},
		'Hawaii_Aleutian' => {
			long => {
				'daylight' => q#Havajų–Aleutų vasaros laikas#,
				'generic' => q#Havajų-Aleutų laikas#,
				'standard' => q#Havajų–Aleutų žiemos laikas#,
			},
		},
		'Hong_Kong' => {
			long => {
				'daylight' => q#Honkongo vasaros laikas#,
				'generic' => q#Honkongo laikas#,
				'standard' => q#Honkongo žiemos laikas#,
			},
		},
		'Hovd' => {
			long => {
				'daylight' => q#Hovdo vasaros laikas#,
				'generic' => q#Hovdo laikas#,
				'standard' => q#Hovdo žiemos laikas#,
			},
		},
		'India' => {
			long => {
				'standard' => q#Indijos laikas#,
			},
		},
		'Indian/Antananarivo' => {
			exemplarCity => q#Antananaryvas#,
		},
		'Indian/Chagos' => {
			exemplarCity => q#Čagosas#,
		},
		'Indian/Christmas' => {
			exemplarCity => q#Kalėdų Sala#,
		},
		'Indian/Cocos' => {
			exemplarCity => q#Kokosų sala#,
		},
		'Indian/Comoro' => {
			exemplarCity => q#Komoras#,
		},
		'Indian/Kerguelen' => {
			exemplarCity => q#Kergelenas#,
		},
		'Indian/Mahe' => {
			exemplarCity => q#Mahė#,
		},
		'Indian/Maldives' => {
			exemplarCity => q#Maldyvai#,
		},
		'Indian/Mauritius' => {
			exemplarCity => q#Mauricijus#,
		},
		'Indian/Mayotte' => {
			exemplarCity => q#Majotas#,
		},
		'Indian/Reunion' => {
			exemplarCity => q#Reunjonas#,
		},
		'Indian_Ocean' => {
			long => {
				'standard' => q#Indijos vandenyno laikas#,
			},
		},
		'Indochina' => {
			long => {
				'standard' => q#Indokinijos laikas#,
			},
		},
		'Indonesia_Central' => {
			long => {
				'standard' => q#Centrinės Indonezijos laikas#,
			},
		},
		'Indonesia_Eastern' => {
			long => {
				'standard' => q#Rytų Indonezijos laikas#,
			},
		},
		'Indonesia_Western' => {
			long => {
				'standard' => q#Vakarų Indonezijos laikas#,
			},
		},
		'Iran' => {
			long => {
				'daylight' => q#Irano vasaros laikas#,
				'generic' => q#Irano laikas#,
				'standard' => q#Irano žiemos laikas#,
			},
		},
		'Irkutsk' => {
			long => {
				'daylight' => q#Irkutsko vasaros laikas#,
				'generic' => q#Irkutsko laikas#,
				'standard' => q#Irkutsko žiemos laikas#,
			},
		},
		'Israel' => {
			long => {
				'daylight' => q#Izraelio vasaros laikas#,
				'generic' => q#Izraelio laikas#,
				'standard' => q#Izraelio žiemos laikas#,
			},
		},
		'Japan' => {
			long => {
				'daylight' => q#Japonijos vasaros laikas#,
				'generic' => q#Japonijos laikas#,
				'standard' => q#Japonijos žiemos laikas#,
			},
		},
		'Kamchatka' => {
			long => {
				'daylight' => q#Kamčiatkos Petropavlovsko vasaros laikas#,
				'generic' => q#Kamčiatkos Petropavlovsko laikas#,
				'standard' => q#Kamčiatkos Petropavlovsko žiemos laikas#,
			},
		},
		'Kazakhstan' => {
			long => {
				'standard' => q#Kazachstano laikas#,
			},
		},
		'Kazakhstan_Eastern' => {
			long => {
				'standard' => q#Rytų Kazachstano laikas#,
			},
		},
		'Kazakhstan_Western' => {
			long => {
				'standard' => q#Vakarų Kazachstano laikas#,
			},
		},
		'Korea' => {
			long => {
				'daylight' => q#Korėjos vasaros laikas#,
				'generic' => q#Korėjos laikas#,
				'standard' => q#Korėjos žiemos laikas#,
			},
		},
		'Kosrae' => {
			long => {
				'standard' => q#Kosrajė laikas#,
			},
		},
		'Krasnoyarsk' => {
			long => {
				'daylight' => q#Krasnojarsko vasaros laikas#,
				'generic' => q#Krasnojarsko laikas#,
				'standard' => q#Krasnojarsko žiemos laikas#,
			},
		},
		'Kyrgystan' => {
			long => {
				'standard' => q#Kirgistano laikas#,
			},
		},
		'Lanka' => {
			long => {
				'standard' => q#Lankos laikas#,
			},
		},
		'Line_Islands' => {
			long => {
				'standard' => q#Laino Salų laikas#,
			},
		},
		'Lord_Howe' => {
			long => {
				'daylight' => q#Lordo Hau vasaros laikas#,
				'generic' => q#Lordo Hau laikas#,
				'standard' => q#Lordo Hau žiemos laikas#,
			},
		},
		'Macau' => {
			long => {
				'daylight' => q#Makau vasaros laikas#,
				'generic' => q#Makau laikas#,
				'standard' => q#Makau žiemos laikas#,
			},
		},
		'Magadan' => {
			long => {
				'daylight' => q#Magadano vasaros laikas#,
				'generic' => q#Magadano laikas#,
				'standard' => q#Magadano žiemos laikas#,
			},
		},
		'Malaysia' => {
			long => {
				'standard' => q#Malaizijos laikas#,
			},
		},
		'Maldives' => {
			long => {
				'standard' => q#Maldyvų laikas#,
			},
		},
		'Marquesas' => {
			long => {
				'standard' => q#Markizo Salų laikas#,
			},
		},
		'Marshall_Islands' => {
			long => {
				'standard' => q#Maršalo Salų laikas#,
			},
		},
		'Mauritius' => {
			long => {
				'daylight' => q#Mauricijaus vasaros laikas#,
				'generic' => q#Mauricijaus laikas#,
				'standard' => q#Mauricijaus žiemos laikas#,
			},
		},
		'Mawson' => {
			long => {
				'standard' => q#Mosono laikas#,
			},
		},
		'Mexico_Pacific' => {
			long => {
				'daylight' => q#Meksikos Ramiojo vandenyno vasaros laikas#,
				'generic' => q#Meksikos Ramiojo vandenyno laikas#,
				'standard' => q#Meksikos Ramiojo vandenyno žiemos laikas#,
			},
		},
		'Mongolia' => {
			long => {
				'daylight' => q#Ulan Batoro vasaros laikas#,
				'generic' => q#Ulan Batoro laikas#,
				'standard' => q#Ulan Batoro žiemos laikas#,
			},
		},
		'Moscow' => {
			long => {
				'daylight' => q#Maskvos vasaros laikas#,
				'generic' => q#Maskvos laikas#,
				'standard' => q#Maskvos žiemos laikas#,
			},
		},
		'Myanmar' => {
			long => {
				'standard' => q#Mianmaro laikas#,
			},
		},
		'Nauru' => {
			long => {
				'standard' => q#Nauru laikas#,
			},
		},
		'Nepal' => {
			long => {
				'standard' => q#Nepalo laikas#,
			},
		},
		'New_Caledonia' => {
			long => {
				'daylight' => q#Naujosios Kaledonijos vasaros laikas#,
				'generic' => q#Naujosios Kaledonijos laikas#,
				'standard' => q#Naujosios Kaledonijos žiemos laikas#,
			},
		},
		'New_Zealand' => {
			long => {
				'daylight' => q#Naujosios Zelandijos vasaros laikas#,
				'generic' => q#Naujosios Zelandijos laikas#,
				'standard' => q#Naujosios Zelandijos žiemos laikas#,
			},
		},
		'Newfoundland' => {
			long => {
				'daylight' => q#Niufaundlendo vasaros laikas#,
				'generic' => q#Niufaundlendo laikas#,
				'standard' => q#Niufaundlendo žiemos laikas#,
			},
		},
		'Niue' => {
			long => {
				'standard' => q#Niujė laikas#,
			},
		},
		'Norfolk' => {
			long => {
				'daylight' => q#Norfolko Salų vasaros laikas#,
				'generic' => q#Norfolko Salų laikas#,
				'standard' => q#Norfolko Salų žiemos laikas#,
			},
		},
		'Noronha' => {
			long => {
				'daylight' => q#Fernando de Noronjos vasaros laikas#,
				'generic' => q#Fernando de Noronjos laikas#,
				'standard' => q#Fernando de Noronjos žiemos laikas#,
			},
		},
		'North_Mariana' => {
			long => {
				'standard' => q#Šiaurės Marianos Salų laikas#,
			},
		},
		'Novosibirsk' => {
			long => {
				'daylight' => q#Novosibirsko vasaros laikas#,
				'generic' => q#Novosibirsko laikas#,
				'standard' => q#Novosibirsko žiemos laikas#,
			},
		},
		'Omsk' => {
			long => {
				'daylight' => q#Omsko vasaros laikas#,
				'generic' => q#Omsko laikas#,
				'standard' => q#Omsko žiemos laikas#,
			},
		},
		'Pacific/Apia' => {
			exemplarCity => q#Apija#,
		},
		'Pacific/Auckland' => {
			exemplarCity => q#Oklandas#,
		},
		'Pacific/Bougainville' => {
			exemplarCity => q#Bugenvilis#,
		},
		'Pacific/Chatham' => {
			exemplarCity => q#Čatamas#,
		},
		'Pacific/Easter' => {
			exemplarCity => q#Velykų sala#,
		},
		'Pacific/Efate' => {
			exemplarCity => q#Efatė#,
		},
		'Pacific/Enderbury' => {
			exemplarCity => q#Enderburis#,
		},
		'Pacific/Fakaofo' => {
			exemplarCity => q#Fakaofas#,
		},
		'Pacific/Fiji' => {
			exemplarCity => q#Fidžis#,
		},
		'Pacific/Funafuti' => {
			exemplarCity => q#Funafutis#,
		},
		'Pacific/Galapagos' => {
			exemplarCity => q#Galapagai#,
		},
		'Pacific/Gambier' => {
			exemplarCity => q#Gambyras#,
		},
		'Pacific/Guadalcanal' => {
			exemplarCity => q#Gvadalkanalis#,
		},
		'Pacific/Guam' => {
			exemplarCity => q#Guamas#,
		},
		'Pacific/Honolulu' => {
			exemplarCity => q#Honolulu#,
		},
		'Pacific/Kiritimati' => {
			exemplarCity => q#Kiritimatis#,
		},
		'Pacific/Kosrae' => {
			exemplarCity => q#Kosrajė#,
		},
		'Pacific/Kwajalein' => {
			exemplarCity => q#Kvadžaleinas#,
		},
		'Pacific/Majuro' => {
			exemplarCity => q#Madžūras#,
		},
		'Pacific/Marquesas' => {
			exemplarCity => q#Markizo salos#,
		},
		'Pacific/Midway' => {
			exemplarCity => q#Midvėjus#,
		},
		'Pacific/Niue' => {
			exemplarCity => q#Niujė#,
		},
		'Pacific/Norfolk' => {
			exemplarCity => q#Norfolkas#,
		},
		'Pacific/Noumea' => {
			exemplarCity => q#Numėja#,
		},
		'Pacific/Pago_Pago' => {
			exemplarCity => q#Pago Pagas#,
		},
		'Pacific/Pitcairn' => {
			exemplarCity => q#Pitkerno sala#,
		},
		'Pacific/Ponape' => {
			exemplarCity => q#Ponapė#,
		},
		'Pacific/Port_Moresby' => {
			exemplarCity => q#Port Morsbis#,
		},
		'Pacific/Saipan' => {
			exemplarCity => q#Saipanas#,
		},
		'Pacific/Tahiti' => {
			exemplarCity => q#Taitis#,
		},
		'Pacific/Tarawa' => {
			exemplarCity => q#Tarava#,
		},
		'Pacific/Truk' => {
			exemplarCity => q#Čukas#,
		},
		'Pacific/Wake' => {
			exemplarCity => q#Veiko sala#,
		},
		'Pacific/Wallis' => {
			exemplarCity => q#Volisas#,
		},
		'Pakistan' => {
			long => {
				'daylight' => q#Pakistano vasaros laikas#,
				'generic' => q#Pakistano laikas#,
				'standard' => q#Pakistano žiemos laikas#,
			},
		},
		'Palau' => {
			long => {
				'standard' => q#Palau laikas#,
			},
		},
		'Papua_New_Guinea' => {
			long => {
				'standard' => q#Papua Naujosios Gvinėjos laikas#,
			},
		},
		'Paraguay' => {
			long => {
				'daylight' => q#Paragvajaus vasaros laikas#,
				'generic' => q#Paragvajaus laikas#,
				'standard' => q#Paragvajaus žiemos laikas#,
			},
		},
		'Peru' => {
			long => {
				'daylight' => q#Peru vasaros laikas#,
				'generic' => q#Peru laikas#,
				'standard' => q#Peru žiemos laikas#,
			},
		},
		'Philippines' => {
			long => {
				'daylight' => q#Filipinų vasaros laikas#,
				'generic' => q#Filipinų laikas#,
				'standard' => q#Filipinų žiemos laikas#,
			},
		},
		'Phoenix_Islands' => {
			long => {
				'standard' => q#Fenikso Salų laikas#,
			},
		},
		'Pierre_Miquelon' => {
			long => {
				'daylight' => q#Sen Pjero ir Mikelono vasaros laikas#,
				'generic' => q#Sen Pjero ir Mikelono laikas#,
				'standard' => q#Sen Pjero ir Mikelono žiemos laikas#,
			},
		},
		'Pitcairn' => {
			long => {
				'standard' => q#Pitkerno laikas#,
			},
		},
		'Ponape' => {
			long => {
				'standard' => q#Ponapės laikas#,
			},
		},
		'Pyongyang' => {
			long => {
				'standard' => q#Pchenjano laikas#,
			},
		},
		'Qyzylorda' => {
			long => {
				'daylight' => q#Kyzylordos vasaros laikas#,
				'generic' => q#Kyzylordos laikas#,
				'standard' => q#Kyzylordos žiemos laikas#,
			},
		},
		'Reunion' => {
			long => {
				'standard' => q#Reunjono laikas#,
			},
		},
		'Rothera' => {
			long => {
				'standard' => q#Roteros laikas#,
			},
		},
		'Sakhalin' => {
			long => {
				'daylight' => q#Sachalino vasaros laikas#,
				'generic' => q#Sachalino laikas#,
				'standard' => q#Sachalino žiemos laikas#,
			},
		},
		'Samara' => {
			long => {
				'daylight' => q#Samaros vasaros laikas#,
				'generic' => q#Samaros laikas#,
				'standard' => q#Samaros žiemos laikas#,
			},
		},
		'Samoa' => {
			long => {
				'daylight' => q#Samoa vasaros laikas#,
				'generic' => q#Samoa laikas#,
				'standard' => q#Samoa žiemos laikas#,
			},
		},
		'Seychelles' => {
			long => {
				'standard' => q#Seišelių laikas#,
			},
		},
		'Singapore' => {
			long => {
				'standard' => q#Singapūro laikas#,
			},
		},
		'Solomon' => {
			long => {
				'standard' => q#Saliamono Salų laikas#,
			},
		},
		'South_Georgia' => {
			long => {
				'standard' => q#Pietų Džordžijos laikas#,
			},
		},
		'Suriname' => {
			long => {
				'standard' => q#Surinamo laikas#,
			},
		},
		'Syowa' => {
			long => {
				'standard' => q#Siovos laikas#,
			},
		},
		'Tahiti' => {
			long => {
				'standard' => q#Tahičio laikas#,
			},
		},
		'Taipei' => {
			long => {
				'daylight' => q#Taipėjaus vasaros laikas#,
				'generic' => q#Taipėjaus laikas#,
				'standard' => q#Taipėjaus žiemos laikas#,
			},
		},
		'Tajikistan' => {
			long => {
				'standard' => q#Tadžikistano laikas#,
			},
		},
		'Tokelau' => {
			long => {
				'standard' => q#Tokelau laikas#,
			},
		},
		'Tonga' => {
			long => {
				'daylight' => q#Tongos vasaros laikas#,
				'generic' => q#Tongos laikas#,
				'standard' => q#Tongos žiemos laikas#,
			},
		},
		'Truk' => {
			long => {
				'standard' => q#Čuko laikas#,
			},
		},
		'Turkmenistan' => {
			long => {
				'daylight' => q#Turkmėnistano vasaros laikas#,
				'generic' => q#Turkmėnistano laikas#,
				'standard' => q#Turkmėnistano žiemos laikas#,
			},
		},
		'Tuvalu' => {
			long => {
				'standard' => q#Tuvalu laikas#,
			},
		},
		'Uruguay' => {
			long => {
				'daylight' => q#Urugvajaus vasaros laikas#,
				'generic' => q#Urugvajaus laikas#,
				'standard' => q#Urugvajaus žiemos laikas#,
			},
		},
		'Uzbekistan' => {
			long => {
				'daylight' => q#Uzbekistano vasaros laikas#,
				'generic' => q#Uzbekistano laikas#,
				'standard' => q#Uzbekistano žiemos laikas#,
			},
		},
		'Vanuatu' => {
			long => {
				'daylight' => q#Vanuatu vasaros laikas#,
				'generic' => q#Vanuatu laikas#,
				'standard' => q#Vanuatu žiemos laikas#,
			},
		},
		'Venezuela' => {
			long => {
				'standard' => q#Venesuelos laikas#,
			},
		},
		'Vladivostok' => {
			long => {
				'daylight' => q#Vladivostoko vasaros laikas#,
				'generic' => q#Vladivostoko laikas#,
				'standard' => q#Vladivostoko žiemos laikas#,
			},
		},
		'Volgograd' => {
			long => {
				'daylight' => q#Volgogrado vasaros laikas#,
				'generic' => q#Volgogrado laikas#,
				'standard' => q#Volgogrado žiemos laikas#,
			},
		},
		'Vostok' => {
			long => {
				'standard' => q#Vostoko laikas#,
			},
		},
		'Wake' => {
			long => {
				'standard' => q#Veiko Salos laikas#,
			},
		},
		'Wallis' => {
			long => {
				'standard' => q#Voliso ir Futūnos laikas#,
			},
		},
		'Yakutsk' => {
			long => {
				'daylight' => q#Jakutsko vasaros laikas#,
				'generic' => q#Jakutsko laikas#,
				'standard' => q#Jakutsko žiemos laikas#,
			},
		},
		'Yekaterinburg' => {
			long => {
				'daylight' => q#Jekaterinburgo vasaros laikas#,
				'generic' => q#Jekaterinburgo laikas#,
				'standard' => q#Jekaterinburgo žiemos laikas#,
			},
		},
		'Yukon' => {
			long => {
				'standard' => q#Jukono laikas#,
			},
		},
	 } }
);
no Moo;

1;

# vim: tabstop=4
