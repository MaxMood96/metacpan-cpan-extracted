=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Qu::Latn::Ec - Package for language Quechua

=cut

package Locale::CLDR::Locales::Qu::Latn::Ec;
# This file auto generated from Data\common\main\qu_EC.xml
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

extends('Locale::CLDR::Locales::Qu::Latn');
has 'currencies' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'PEN' => {
			symbol => 'PEN',
		},
		'USD' => {
			symbol => '$',
		},
	} },
);


has 'time_zone_names' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default	=> sub { {
		'Ecuador' => {
			short => {
				'standard' => q#ECT#,
			},
		},
		'Peru' => {
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
