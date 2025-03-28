=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Es::Latn::Us - Package for language Spanish

=cut

package Locale::CLDR::Locales::Es::Latn::Us;
# This file auto generated from Data\common\main\es_US.xml
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

extends('Locale::CLDR::Locales::Es::Latn::419');
has 'display_name_language' => (
	is			=> 'ro',
	isa			=> CodeRef,
	init_arg	=> undef,
	default		=> sub {
		 sub {
			 my %languages = (
				'ace' => 'acehnés',
 				'alt' => 'altái meridional',
 				'arp' => 'arapaho',
 				'ars' => 'árabe najdi',
 				'bax' => 'bamun',
 				'bgc' => 'hariana',
 				'bho' => 'bhojpuri',
 				'bla' => 'siksika',
 				'blo' => 'ani',
 				'bua' => 'buriat',
 				'clc' => 'chilcotín',
 				'crj' => 'cree del sureste',
 				'crl' => 'cree del noreste',
 				'crm' => 'moose cree',
 				'crr' => 'algonquian',
 				'dum' => 'neerlandés medieval',
 				'enm' => 'inglés medieval',
 				'eu' => 'euskera',
 				'frm' => 'francés medieval',
 				'gan' => 'gan (China)',
 				'gmh' => 'alemán de la alta edad media',
 				'grc' => 'griego antiguo',
 				'gu' => 'gurayatí',
 				'hax' => 'haida del sur',
 				'hil' => 'hiligainón',
 				'hsn' => 'xiang (China)',
 				'ht' => 'criollo haitiano',
 				'ikt' => 'inuktitut del oeste de Canadá',
 				'inh' => 'ingusetio',
 				'kab' => 'cabilio',
 				'krc' => 'karachay-balkar',
 				'lij' => 'ligur',
 				'lou' => 'creole de Luisiana',
 				'lrc' => 'lorí del norte',
 				'lsm' => 'saamia',
 				'mga' => 'irlandés medieval',
 				'nd' => 'ndebele del norte',
 				'nr' => 'ndebele meridional',
 				'ojb' => 'ojibwa del noroeste',
 				'ojw' => 'ojibwa del oeste',
 				'pis' => 'pijín',
 				'rm' => 'romanche',
 				'se' => 'sami del norte',
 				'shu' => 'árabe chadiano',
 				'slh' => 'lushootseed del sur',
 				'sma' => 'sami meridional',
 				'smn' => 'sami de Inari',
 				'ss' => 'siswati',
 				'str' => 'straits salish',
 				'sw_CD' => 'swahili del Congo',
 				'syr' => 'siriaco',
 				'tce' => 'tutchone del sur',
 				'tet' => 'tetún',
 				'ttm' => 'tutchone del norte',
 				'tyv' => 'tuviniano',
 				'ug@alt=variant' => 'uigur variante',
 				'wal' => 'wolayta',
 				'xnr' => 'dogrí',

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
			'Adlm' => 'adlam',
 			'Hrkt' => 'silabarios del japonés',
 			'Rohg' => 'hanafí',
 			'Zzzz' => 'letra desconocida',

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
			'011' => 'África occidental',
 			'014' => 'África oriental',
 			'015' => 'África septentrional',
 			'018' => 'África meridional',
 			'030' => 'Asia oriental',
 			'034' => 'Asia meridional',
 			'035' => 'Sudeste asiático',
 			'039' => 'Europa meridional',
 			'145' => 'Asia occidental',
 			'151' => 'Europa oriental',
 			'154' => 'Europa septentrional',
 			'155' => 'Europa occidental',
 			'AC' => 'Isla de la Ascensión',
 			'BA' => 'Bosnia y Herzegovina',
 			'EH' => 'Sahara Occidental',
 			'GB@alt=short' => 'RU',
 			'GG' => 'Guernsey',
 			'QO' => 'Territorios alejados de Oceanía',
 			'UM' => 'Islas menores alejadas de EE. UU.',

		}
	},
);

has 'display_name_type' => (
	is			=> 'ro',
	isa			=> HashRef[HashRef[Str]],
	init_arg	=> undef,
	default		=> sub {
		{
			'numbers' => {
 				'cakm' => q{dígitos chakma},
 				'gujr' => q{dígitos en gujarati},
 				'java' => q{dígitos javaneses},
 				'mtei' => q{dígitos meetei mayek},
 				'olck' => q{dígitos ol chiki},
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
			'UK' => q{imperial},

		}
	},
);

has 'more_information' => (
	is			=> 'ro',
	isa			=> Str,
	init_arg	=> undef,
	default		=> qq{[...]},
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
					'10p-2' => {
						'1' => q(centí{0}),
					},
					# Core Unit Identifier
					'2' => {
						'1' => q(centí{0}),
					},
					# Long Unit Identifier
					'10p-27' => {
						'1' => q(ronto {0}),
					},
					# Core Unit Identifier
					'27' => {
						'1' => q(ronto {0}),
					},
					# Long Unit Identifier
					'10p-30' => {
						'1' => q(quecto {0}),
					},
					# Core Unit Identifier
					'30' => {
						'1' => q(quecto {0}),
					},
					# Long Unit Identifier
					'concentr-percent' => {
						'name' => q(por ciento),
					},
					# Core Unit Identifier
					'percent' => {
						'name' => q(por ciento),
					},
					# Long Unit Identifier
					'concentr-permille' => {
						'name' => q(por mil),
					},
					# Core Unit Identifier
					'permille' => {
						'name' => q(por mil),
					},
					# Long Unit Identifier
					'electric-ampere' => {
						'name' => q(amperios),
						'one' => q({0} amperio),
						'other' => q({0} amperios),
					},
					# Core Unit Identifier
					'ampere' => {
						'name' => q(amperios),
						'one' => q({0} amperio),
						'other' => q({0} amperios),
					},
					# Long Unit Identifier
					'electric-milliampere' => {
						'name' => q(miliamperio),
						'one' => q({0} miliamperio),
						'other' => q({0} miliamperios),
					},
					# Core Unit Identifier
					'milliampere' => {
						'name' => q(miliamperio),
						'one' => q({0} miliamperio),
						'other' => q({0} miliamperios),
					},
					# Long Unit Identifier
					'electric-ohm' => {
						'name' => q(ohmios),
						'one' => q({0} ohmio),
						'other' => q({0} ohmios),
					},
					# Core Unit Identifier
					'ohm' => {
						'name' => q(ohmios),
						'one' => q({0} ohmio),
						'other' => q({0} ohmios),
					},
					# Long Unit Identifier
					'energy-joule' => {
						'name' => q(julios),
						'one' => q({0} julio),
						'other' => q({0} julios),
					},
					# Core Unit Identifier
					'joule' => {
						'name' => q(julios),
						'one' => q({0} julio),
						'other' => q({0} julios),
					},
					# Long Unit Identifier
					'energy-kilojoule' => {
						'name' => q(kilojulios),
						'one' => q({0} kilojulio),
						'other' => q({0} kilojulio),
					},
					# Core Unit Identifier
					'kilojoule' => {
						'name' => q(kilojulios),
						'one' => q({0} kilojulio),
						'other' => q({0} kilojulio),
					},
					# Long Unit Identifier
					'energy-kilowatt-hour' => {
						'name' => q(kilovatios por hora),
						'one' => q({0} kilovatio por hora),
						'other' => q({0} kilovatios por hora),
					},
					# Core Unit Identifier
					'kilowatt-hour' => {
						'name' => q(kilovatios por hora),
						'one' => q({0} kilovatio por hora),
						'other' => q({0} kilovatios por hora),
					},
					# Long Unit Identifier
					'graphics-em' => {
						'1' => q(feminine),
						'name' => q(em tipográfica),
						'one' => q({0} em),
						'other' => q({0} em),
					},
					# Core Unit Identifier
					'em' => {
						'1' => q(feminine),
						'name' => q(em tipográfica),
						'one' => q({0} em),
						'other' => q({0} em),
					},
					# Long Unit Identifier
					'graphics-megapixel' => {
						'name' => q(megapixeles),
						'one' => q({0} megapixel),
						'other' => q({0} megapixeles),
					},
					# Core Unit Identifier
					'megapixel' => {
						'name' => q(megapixeles),
						'one' => q({0} megapixel),
						'other' => q({0} megapixeles),
					},
					# Long Unit Identifier
					'graphics-pixel-per-centimeter' => {
						'name' => q(pixeles por centímetro),
						'one' => q({0} pixel por centímetro),
						'other' => q({0} pixeles por centímetro),
					},
					# Core Unit Identifier
					'pixel-per-centimeter' => {
						'name' => q(pixeles por centímetro),
						'one' => q({0} pixel por centímetro),
						'other' => q({0} pixeles por centímetro),
					},
					# Long Unit Identifier
					'graphics-pixel-per-inch' => {
						'name' => q(pixeles por pulgada),
						'one' => q({0} pixel por pulgada),
						'other' => q({0} pixeles por pulgada),
					},
					# Core Unit Identifier
					'pixel-per-inch' => {
						'name' => q(pixeles por pulgada),
						'one' => q({0} pixel por pulgada),
						'other' => q({0} pixeles por pulgada),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'name' => q(millas naúticas),
						'one' => q({0} milla naútica),
						'other' => q({0} millas naúticas),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'name' => q(millas naúticas),
						'one' => q({0} milla naútica),
						'other' => q({0} millas naúticas),
					},
					# Long Unit Identifier
					'power-horsepower' => {
						'one' => q({0} caballo de fuerza),
						'other' => q({0} caballos de fuerza),
					},
					# Core Unit Identifier
					'horsepower' => {
						'one' => q({0} caballo de fuerza),
						'other' => q({0} caballos de fuerza),
					},
					# Long Unit Identifier
					'speed-beaufort' => {
						'1' => q(feminine),
						'name' => q(Escala Beaufort),
						'one' => q(Escala Beaufort {0}),
						'other' => q(Escala Beaufort {0}),
					},
					# Core Unit Identifier
					'beaufort' => {
						'1' => q(feminine),
						'name' => q(Escala Beaufort),
						'one' => q(Escala Beaufort {0}),
						'other' => q(Escala Beaufort {0}),
					},
					# Long Unit Identifier
					'speed-light-speed' => {
						'one' => q({0} luz),
						'other' => q({0} luces),
					},
					# Core Unit Identifier
					'light-speed' => {
						'one' => q({0} luz),
						'other' => q({0} luces),
					},
					# Long Unit Identifier
					'temperature-generic' => {
						'one' => q({0} grado),
						'other' => q({0} grados),
					},
					# Core Unit Identifier
					'generic' => {
						'one' => q({0} grado),
						'other' => q({0} grados),
					},
					# Long Unit Identifier
					'temperature-kelvin' => {
						'name' => q(kelvin),
						'one' => q(kelvin),
						'other' => q({0} kelvin),
					},
					# Core Unit Identifier
					'kelvin' => {
						'name' => q(kelvin),
						'one' => q(kelvin),
						'other' => q({0} kelvin),
					},
					# Long Unit Identifier
					'torque-pound-force-foot' => {
						'name' => q(libra fuerza-pies),
						'one' => q({0} libra fuerza-pie),
						'other' => q({0} libra fuerza-pies),
					},
					# Core Unit Identifier
					'pound-force-foot' => {
						'name' => q(libra fuerza-pies),
						'one' => q({0} libra fuerza-pie),
						'other' => q({0} libra fuerza-pies),
					},
					# Long Unit Identifier
					'volume-acre-foot' => {
						'name' => q(acres-pies),
						'one' => q({0} acre-pie),
						'other' => q({0} acres pies),
					},
					# Core Unit Identifier
					'acre-foot' => {
						'name' => q(acres-pies),
						'one' => q({0} acre-pie),
						'other' => q({0} acres pies),
					},
					# Long Unit Identifier
					'volume-dram' => {
						'name' => q(dracma fluida),
						'one' => q({0} dracma fluida),
						'other' => q({0} dreacmas fluidas),
					},
					# Core Unit Identifier
					'dram' => {
						'name' => q(dracma fluida),
						'one' => q({0} dracma fluida),
						'other' => q({0} dreacmas fluidas),
					},
					# Long Unit Identifier
					'volume-fluid-ounce-imperial' => {
						'name' => q(onzas fluidas imperiales),
						'one' => q(onza fluida imperial),
						'other' => q({0} onzas fluidas imperiales),
					},
					# Core Unit Identifier
					'fluid-ounce-imperial' => {
						'name' => q(onzas fluidas imperiales),
						'one' => q(onza fluida imperial),
						'other' => q({0} onzas fluidas imperiales),
					},
				},
				'narrow' => {
					# Long Unit Identifier
					'angle-arc-minute' => {
						'one' => q({0} arcmin),
						'other' => q({0}′),
					},
					# Core Unit Identifier
					'arc-minute' => {
						'one' => q({0} arcmin),
						'other' => q({0}′),
					},
					# Long Unit Identifier
					'angle-arc-second' => {
						'one' => q({0} arcsec),
						'other' => q({0}″),
					},
					# Core Unit Identifier
					'arc-second' => {
						'one' => q({0} arcsec),
						'other' => q({0}″),
					},
					# Long Unit Identifier
					'duration-day' => {
						'name' => q(día),
						'one' => q({0}d),
						'other' => q({0}d),
					},
					# Core Unit Identifier
					'day' => {
						'name' => q(día),
						'one' => q({0}d),
						'other' => q({0}d),
					},
					# Long Unit Identifier
					'duration-month' => {
						'name' => q(m),
						'one' => q({0}m),
						'other' => q({0}m),
					},
					# Core Unit Identifier
					'month' => {
						'name' => q(m),
						'one' => q({0}m),
						'other' => q({0}m),
					},
					# Long Unit Identifier
					'duration-year' => {
						'name' => q(a),
						'one' => q({0}a),
						'other' => q({0}a),
					},
					# Core Unit Identifier
					'year' => {
						'name' => q(a),
						'one' => q({0}a),
						'other' => q({0}a),
					},
					# Long Unit Identifier
					'energy-therm-us' => {
						'one' => q({0}th US),
						'other' => q({0}th US),
					},
					# Core Unit Identifier
					'therm-us' => {
						'one' => q({0}th US),
						'other' => q({0}th US),
					},
					# Long Unit Identifier
					'length-fathom' => {
						'name' => q(braza),
					},
					# Core Unit Identifier
					'fathom' => {
						'name' => q(braza),
					},
					# Long Unit Identifier
					'length-furlong' => {
						'name' => q(furlong),
					},
					# Core Unit Identifier
					'furlong' => {
						'name' => q(furlong),
					},
					# Long Unit Identifier
					'length-kilometer' => {
						'one' => q({0} km),
						'other' => q({0}km),
					},
					# Core Unit Identifier
					'kilometer' => {
						'one' => q({0} km),
						'other' => q({0}km),
					},
					# Long Unit Identifier
					'length-mile-scandinavian' => {
						'name' => q(mil),
						'one' => q({0}mil),
						'other' => q({0}mil),
					},
					# Core Unit Identifier
					'mile-scandinavian' => {
						'name' => q(mil),
						'one' => q({0}mil),
						'other' => q({0}mil),
					},
					# Long Unit Identifier
					'length-millimeter' => {
						'one' => q({0} mm),
						'other' => q({0}mm),
					},
					# Core Unit Identifier
					'millimeter' => {
						'one' => q({0} mm),
						'other' => q({0}mm),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'one' => q({0}mn),
						'other' => q({0}mn),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'one' => q({0}mn),
						'other' => q({0}mn),
					},
					# Long Unit Identifier
					'speed-beaufort' => {
						'name' => q(B),
					},
					# Core Unit Identifier
					'beaufort' => {
						'name' => q(B),
					},
					# Long Unit Identifier
					'speed-light-speed' => {
						'one' => q({0}luz),
						'other' => q({0}luces),
					},
					# Core Unit Identifier
					'light-speed' => {
						'one' => q({0}luz),
						'other' => q({0}luces),
					},
					# Long Unit Identifier
					'temperature-fahrenheit' => {
						'one' => q({0}°),
						'other' => q({0}°),
					},
					# Core Unit Identifier
					'fahrenheit' => {
						'one' => q({0}°),
						'other' => q({0}°),
					},
					# Long Unit Identifier
					'volume-bushel' => {
						'one' => q({0}bsh),
						'other' => q({0}bsh),
					},
					# Core Unit Identifier
					'bushel' => {
						'one' => q({0}bsh),
						'other' => q({0}bsh),
					},
					# Long Unit Identifier
					'volume-pint-metric' => {
						'one' => q({0}ptm),
						'other' => q({0}ptm),
					},
					# Core Unit Identifier
					'pint-metric' => {
						'one' => q({0}ptm),
						'other' => q({0}ptm),
					},
				},
				'short' => {
					# Long Unit Identifier
					'concentr-percent' => {
						'name' => q(%),
					},
					# Core Unit Identifier
					'percent' => {
						'name' => q(%),
					},
					# Long Unit Identifier
					'concentr-permille' => {
						'name' => q(‰),
					},
					# Core Unit Identifier
					'permille' => {
						'name' => q(‰),
					},
					# Long Unit Identifier
					'concentr-portion-per-1e9' => {
						'name' => q(partes/mil millones),
					},
					# Core Unit Identifier
					'portion-per-1e9' => {
						'name' => q(partes/mil millones),
					},
					# Long Unit Identifier
					'digital-bit' => {
						'name' => q(bit),
					},
					# Core Unit Identifier
					'bit' => {
						'name' => q(bit),
					},
					# Long Unit Identifier
					'digital-byte' => {
						'name' => q(byte),
					},
					# Core Unit Identifier
					'byte' => {
						'name' => q(byte),
					},
					# Long Unit Identifier
					'duration-day' => {
						'name' => q(días),
						'one' => q({0} día),
						'other' => q({0} días),
						'per' => q({0}/d),
					},
					# Core Unit Identifier
					'day' => {
						'name' => q(días),
						'one' => q({0} día),
						'other' => q({0} días),
						'per' => q({0}/d),
					},
					# Long Unit Identifier
					'duration-month' => {
						'one' => q({0} m),
						'other' => q({0} mm.),
					},
					# Core Unit Identifier
					'month' => {
						'one' => q({0} m),
						'other' => q({0} mm.),
					},
					# Long Unit Identifier
					'duration-year' => {
						'one' => q({0} a),
						'other' => q({0} aa.),
						'per' => q({0}/a),
					},
					# Core Unit Identifier
					'year' => {
						'one' => q({0} a),
						'other' => q({0} aa.),
						'per' => q({0}/a),
					},
					# Long Unit Identifier
					'energy-therm-us' => {
						'name' => q(th US),
						'one' => q({0} th US),
						'other' => q({0} th US),
					},
					# Core Unit Identifier
					'therm-us' => {
						'name' => q(th US),
						'one' => q({0} th US),
						'other' => q({0} th US),
					},
					# Long Unit Identifier
					'length-furlong' => {
						'name' => q(furlongs),
					},
					# Core Unit Identifier
					'furlong' => {
						'name' => q(furlongs),
					},
					# Long Unit Identifier
					'length-light-year' => {
						'one' => q({0} a. l.),
						'other' => q({0} a. l.),
					},
					# Core Unit Identifier
					'light-year' => {
						'one' => q({0} a. l.),
						'other' => q({0} a. l.),
					},
					# Long Unit Identifier
					'length-mile-scandinavian' => {
						'name' => q(mil),
						'one' => q({0} mil),
						'other' => q({0} mil),
					},
					# Core Unit Identifier
					'mile-scandinavian' => {
						'name' => q(mil),
						'one' => q({0} mil),
						'other' => q({0} mil),
					},
					# Long Unit Identifier
					'length-nautical-mile' => {
						'name' => q(mn),
						'one' => q({0} mn),
						'other' => q({0} mn),
					},
					# Core Unit Identifier
					'nautical-mile' => {
						'name' => q(mn),
						'one' => q({0} mn),
						'other' => q({0} mn),
					},
					# Long Unit Identifier
					'length-yard' => {
						'name' => q(yd),
					},
					# Core Unit Identifier
					'yard' => {
						'name' => q(yd),
					},
					# Long Unit Identifier
					'speed-beaufort' => {
						'name' => q(Beaufort),
						'one' => q(Beaufort {0}),
						'other' => q(Beaufort {0}),
					},
					# Core Unit Identifier
					'beaufort' => {
						'name' => q(Beaufort),
						'one' => q(Beaufort {0}),
						'other' => q(Beaufort {0}),
					},
					# Long Unit Identifier
					'speed-knot' => {
						'one' => q({0} nudo),
						'other' => q({0} nudos),
					},
					# Core Unit Identifier
					'knot' => {
						'one' => q({0} nudo),
						'other' => q({0} nudos),
					},
					# Long Unit Identifier
					'speed-light-speed' => {
						'one' => q({0} luz),
						'other' => q({0} de luces),
					},
					# Core Unit Identifier
					'light-speed' => {
						'one' => q({0} luz),
						'other' => q({0} de luces),
					},
					# Long Unit Identifier
					'torque-pound-force-foot' => {
						'name' => q(lbf⋅ft),
						'one' => q({0} lbf⋅ft),
						'other' => q({0} lbf⋅ft),
					},
					# Core Unit Identifier
					'pound-force-foot' => {
						'name' => q(lbf⋅ft),
						'one' => q({0} lbf⋅ft),
						'other' => q({0} lbf⋅ft),
					},
					# Long Unit Identifier
					'volume-bushel' => {
						'name' => q(bsh),
						'one' => q({0} bsh),
						'other' => q({0} bsh),
					},
					# Core Unit Identifier
					'bushel' => {
						'name' => q(bsh),
						'one' => q({0} bsh),
						'other' => q({0} bsh),
					},
					# Long Unit Identifier
					'volume-cup' => {
						'name' => q(tza.),
						'one' => q({0} tzas.),
						'other' => q({0} tzas.),
					},
					# Core Unit Identifier
					'cup' => {
						'name' => q(tza.),
						'one' => q({0} tzas.),
						'other' => q({0} tzas.),
					},
					# Long Unit Identifier
					'volume-dessert-spoon' => {
						'name' => q(cdapostre),
						'one' => q({0} cdapostre),
						'other' => q({0} cdapostre),
					},
					# Core Unit Identifier
					'dessert-spoon' => {
						'name' => q(cdapostre),
						'one' => q({0} cdapostre),
						'other' => q({0} cdapostre),
					},
					# Long Unit Identifier
					'volume-dessert-spoon-imperial' => {
						'name' => q(cdapostre imp.),
						'one' => q({0} cdapostre imp.),
						'other' => q({0} cdaspostre imp.),
					},
					# Core Unit Identifier
					'dessert-spoon-imperial' => {
						'name' => q(cdapostre imp.),
						'one' => q({0} cdapostre imp.),
						'other' => q({0} cdaspostre imp.),
					},
					# Long Unit Identifier
					'volume-dram' => {
						'name' => q(fl dracma),
						'one' => q({0} fl dracma),
						'other' => q({0} fl dracmas),
					},
					# Core Unit Identifier
					'dram' => {
						'name' => q(fl dracma),
						'one' => q({0} fl dracma),
						'other' => q({0} fl dracmas),
					},
					# Long Unit Identifier
					'volume-pint-metric' => {
						'name' => q(ptm),
						'one' => q({0} ptm),
						'other' => q({0} ptm),
					},
					# Core Unit Identifier
					'pint-metric' => {
						'name' => q(ptm),
						'one' => q({0} ptm),
						'other' => q({0} ptm),
					},
				},
			} }
);

has 'number_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		decimalFormat => {
			'short' => {
				'1000' => {
					'one' => '0 K',
					'other' => '0 K',
				},
				'10000' => {
					'one' => '00 K',
					'other' => '00 K',
				},
				'100000' => {
					'one' => '000 K',
					'other' => '000 K',
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
		'BTN' => {
			display_name => {
				'currency' => q(ngultrum butanés),
				'one' => q(ngultrum butanés),
				'other' => q(gultrums bultaneses),
			},
		},
		'ETB' => {
			display_name => {
				'currency' => q(birr),
				'one' => q(birr),
				'other' => q(birres),
			},
		},
		'FKP' => {
			symbol => '£',
		},
		'JPY' => {
			symbol => '¥',
		},
		'RON' => {
			symbol => 'lei',
		},
		'SSP' => {
			symbol => '£',
		},
		'SYP' => {
			symbol => '£',
		},
		'THB' => {
			display_name => {
				'currency' => q(bat),
				'one' => q(bat),
				'other' => q(bats),
			},
		},
		'USD' => {
			symbol => '$',
		},
		'UZS' => {
			display_name => {
				'currency' => q(sum),
				'one' => q(sum),
				'other' => q(sums),
			},
		},
		'VEF' => {
			symbol => 'Bs',
		},
		'XAF' => {
			display_name => {
				'currency' => q(franco CFA de África central),
				'one' => q(franco CFA de África central),
				'other' => q(francos CFA de África central),
			},
		},
		'ZMW' => {
			display_name => {
				'currency' => q(kwacha zambiano),
				'one' => q(kwacha zambiano),
				'other' => q(kwachas zambianos),
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
					wide => {0 => '1er trimestre',
						1 => '2.º trimestre',
						2 => '3.º trimestre',
						3 => '4.º trimestre'
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
			if ($_ eq 'generic') {
				if($day_period_type eq 'default') {
					return 'noon' if $time == 1200;
					return 'evening1' if $time >= 1200
						&& $time < 2000;
					return 'morning1' if $time >= 0
						&& $time < 600;
					return 'morning2' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 2000
						&& $time < 2400;
				}
				if($day_period_type eq 'selection') {
					return 'evening1' if $time >= 1200
						&& $time < 2000;
					return 'morning1' if $time >= 0
						&& $time < 600;
					return 'morning2' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 2000
						&& $time < 2400;
				}
				last SWITCH;
				}
			if ($_ eq 'gregorian') {
				if($day_period_type eq 'default') {
					return 'noon' if $time == 1200;
					return 'evening1' if $time >= 1200
						&& $time < 2000;
					return 'morning1' if $time >= 0
						&& $time < 600;
					return 'morning2' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 2000
						&& $time < 2400;
				}
				if($day_period_type eq 'selection') {
					return 'evening1' if $time >= 1200
						&& $time < 2000;
					return 'morning1' if $time >= 0
						&& $time < 600;
					return 'morning2' if $time >= 600
						&& $time < 1200;
					return 'night1' if $time >= 2000
						&& $time < 2400;
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
			'stand-alone' => {
				'abbreviated' => {
					'am' => q{a. m.},
					'pm' => q{p. m.},
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
		},
	} },
);

has 'date_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
		},
		'gregorian' => {
			'full' => q{EEEE, d 'de' MMMM 'de' y},
			'long' => q{d 'de' MMMM 'de' y},
			'medium' => q{d MMM y},
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
			yyyyMEd => q{E, d/M/y GGGGG},
		},
		'gregorian' => {
			EHm => q{E HH:mm},
			EHms => q{E HH:mm:ss},
			Ehm => q{E h:mm a},
			Ehms => q{E h:mm:ss a},
			GyMMMd => q{d MMM y G},
			Hmsvvvv => q{HH:mm:ss (vvvv)},
			MMMEd => q{E, d 'de' MMM},
			MMd => q{d/MM},
			MMdd => q{dd/MM},
			yMEd => q{E, d/M/y},
			yMM => q{MM/y},
			yMMMEd => q{EEE, d 'de' MMM 'de' y},
			yQQQ => q{QQQ y},
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
			GyMEd => {
				G => q{E, dd/MM/y GGGGG – E, dd/MM/y GGGGG},
				M => q{E, dd/MM/y – E, dd/MM/y GGGGG},
				d => q{E, dd/MM/y – E, dd/MM/y GGGGG},
				y => q{E, dd/MM/y – E, dd/MM/y GGGGG},
			},
			Md => {
				M => q{d/M – d/M},
				d => q{d/M – d/M},
			},
			fallback => '{0}-{1}',
			yMMMd => {
				M => q{d 'de' MMM – d 'de' MMM 'de' y G},
			},
		},
		'gregorian' => {
			H => {
				H => q{HH–HH},
			},
			Hm => {
				H => q{HH:mm–HH:mm},
				m => q{HH:mm–HH:mm},
			},
			Hmv => {
				H => q{HH:mm–HH:mm v},
				m => q{HH:mm–HH:mm v},
			},
			Hv => {
				H => q{HH–HH v},
			},
			MEd => {
				M => q{E, d/M – E, d/M},
				d => q{E, d/M – E, d/M},
			},
			MMMd => {
				d => q{d–d 'de' MMM},
			},
			h => {
				a => q{h a – h a},
			},
			hm => {
				h => q{h:mm–h:mm a},
				m => q{h:mm–h:mm a},
			},
			hmv => {
				a => q{h:mm a – h:mm a v},
			},
			hv => {
				a => q{h a – h a v},
			},
			yMEd => {
				M => q{E, d/M/y – E, d/M/y},
				d => q{E, d/M/y – E, d/M/y},
				y => q{E, d/M/y – E, d/M/y},
			},
			yMMM => {
				M => q{MMM–MMM 'de' y},
			},
			yMMMM => {
				y => q{MMMM 'de' y – MMMM 'de' y},
			},
			yMMMd => {
				M => q{d 'de' MMM – d 'de' MMM y},
				d => q{d–d 'de' MMM 'de' y},
			},
		},
	} },
);

has 'time_zone_names' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default	=> sub { {
		'Africa/Djibouti' => {
			exemplarCity => q#Yibutí#,
		},
		'Alaska' => {
			short => {
				'daylight' => q#AKDT#,
				'generic' => q#AKT#,
				'standard' => q#AKST#,
			},
		},
		'America/Fort_Nelson' => {
			exemplarCity => q#Fort Nelson#,
		},
		'America/Nassau' => {
			exemplarCity => q#Nassau#,
		},
		'America/St_Thomas' => {
			exemplarCity => q#St. Thomas#,
		},
		'America_Central' => {
			short => {
				'daylight' => q#CDT#,
				'generic' => q#CT#,
				'standard' => q#CST#,
			},
		},
		'America_Eastern' => {
			short => {
				'daylight' => q#EDT#,
				'generic' => q#ET#,
				'standard' => q#EST#,
			},
		},
		'America_Mountain' => {
			long => {
				'daylight' => q#hora de verano de las Montañas Rocosas#,
				'generic' => q#hora de las Montañas Rocosas#,
				'standard' => q#hora estándar de las Montañas Rocosas#,
			},
			short => {
				'daylight' => q#MDT#,
				'generic' => q#MT#,
				'standard' => q#MST#,
			},
		},
		'America_Pacific' => {
			short => {
				'daylight' => q#PDT#,
				'generic' => q#PT#,
				'standard' => q#PST#,
			},
		},
		'Apia' => {
			long => {
				'daylight' => q#hora de verano de Apia#,
				'generic' => q#hora de Apia#,
				'standard' => q#hora estándar de Apia#,
			},
		},
		'Asia/Pyongyang' => {
			exemplarCity => q#Pionyang#,
		},
		'Atlantic' => {
			short => {
				'daylight' => q#ADT#,
				'generic' => q#AT#,
				'standard' => q#AST#,
			},
		},
		'Chamorro' => {
			long => {
				'standard' => q#hora de Chamorro#,
			},
		},
		'Cocos' => {
			long => {
				'standard' => q#hora de las Islas Cocos#,
			},
		},
		'Cook' => {
			long => {
				'daylight' => q#hora de verano media de las Islas Cook#,
				'generic' => q#hora de las Islas Cook#,
				'standard' => q#hora estándar de las Islas Cook#,
			},
		},
		'Easter' => {
			long => {
				'daylight' => q#hora de verano de la isla de Pascua#,
				'generic' => q#hora de la isla de Pascua#,
				'standard' => q#hora estándar de la isla de Pascua#,
			},
		},
		'Europe/Astrakhan' => {
			exemplarCity => q#Astrakhan#,
		},
		'Europe/Kirov' => {
			exemplarCity => q#Kirov#,
		},
		'Europe/Ulyanovsk' => {
			exemplarCity => q#Ulyanovsk#,
		},
		'Europe_Eastern' => {
			long => {
				'daylight' => q#hora de verano de Europa oriental#,
				'generic' => q#hora de Europa oriental#,
				'standard' => q#hora estándar de Europa oriental#,
			},
		},
		'Europe_Further_Eastern' => {
			long => {
				'standard' => q#hora del extremo oriental de Europa#,
			},
		},
		'Europe_Western' => {
			long => {
				'daylight' => q#hora de verano de Europa occidental#,
				'generic' => q#hora de Europa occidental#,
				'standard' => q#hora estándar de Europa occidental#,
			},
		},
		'Falkland' => {
			long => {
				'daylight' => q#hora de verano de las islas Malvinas#,
				'generic' => q#hora de las islas Malvinas#,
				'standard' => q#hora estándar de las islas Malvinas#,
			},
		},
		'Gilbert_Islands' => {
			long => {
				'standard' => q#hora de las islas Gilbert#,
			},
		},
		'Hawaii_Aleutian' => {
			short => {
				'daylight' => q#HADT#,
				'generic' => q#HAT#,
				'standard' => q#HAST#,
			},
		},
		'Indian_Ocean' => {
			long => {
				'standard' => q#hora del Océano Índico#,
			},
		},
		'Marquesas' => {
			long => {
				'standard' => q#hora de las islas Marquesas#,
			},
		},
		'Marshall_Islands' => {
			long => {
				'standard' => q#hora de las Islas Marshall#,
			},
		},
		'Norfolk' => {
			long => {
				'daylight' => q#hora de verano de la isla Norfolk#,
				'generic' => q#hora de la isla Norfolk#,
				'standard' => q#hora estándar de la isla Norfolk#,
			},
		},
		'Pacific/Honolulu' => {
			exemplarCity => q#Honolulu#,
			short => {
				'daylight' => q#HDT#,
				'generic' => q#HST#,
				'standard' => q#HST#,
			},
		},
		'Pacific/Wake' => {
			exemplarCity => q#Wake#,
		},
		'Phoenix_Islands' => {
			long => {
				'standard' => q#hora de las islas Fénix#,
			},
		},
		'Pyongyang' => {
			long => {
				'standard' => q#hora de Pyongyang#,
			},
		},
		'Solomon' => {
			long => {
				'standard' => q#hora de las Islas Salomón#,
			},
		},
		'Wake' => {
			long => {
				'standard' => q#hora de la isla Wake#,
			},
		},
	 } }
);
no Moo;

1;

# vim: tabstop=4
