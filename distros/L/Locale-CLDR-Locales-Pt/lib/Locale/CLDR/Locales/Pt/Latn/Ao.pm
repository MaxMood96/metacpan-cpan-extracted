=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Pt::Latn::Ao - Package for language Portuguese

=cut

package Locale::CLDR::Locales::Pt::Latn::Ao;
# This file auto generated from Data\common\main\pt_AO.xml
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

extends('Locale::CLDR::Locales::Pt::Latn::Pt');
has 'minimum_grouping_digits' => (
	is			=>'ro',
	isa			=> Int,
	init_arg	=> undef,
	default		=> 1,
);

has 'currencies' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'AOA' => {
			symbol => 'Kz',
		},
	} },
);


has 'time_zone_names' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default	=> sub { {
		'Azores' => {
			short => {
				'daylight' => q#∅∅∅#,
				'generic' => q#∅∅∅#,
				'standard' => q#∅∅∅#,
			},
		},
		'Europe_Central' => {
			short => {
				'daylight' => q#∅∅∅#,
				'generic' => q#∅∅∅#,
				'standard' => q#∅∅∅#,
			},
		},
		'Europe_Eastern' => {
			short => {
				'daylight' => q#∅∅∅#,
				'generic' => q#∅∅∅#,
				'standard' => q#∅∅∅#,
			},
		},
		'Europe_Western' => {
			short => {
				'daylight' => q#∅∅∅#,
				'generic' => q#∅∅∅#,
				'standard' => q#∅∅∅#,
			},
		},
	 } }
);
no Moo;

1;

# vim: tabstop=4
