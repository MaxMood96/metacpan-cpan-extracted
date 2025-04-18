=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Nl::Latn::Be - Package for language Dutch

=cut

package Locale::CLDR::Locales::Nl::Latn::Be;
# This file auto generated from Data\common\main\nl_BE.xml
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

extends('Locale::CLDR::Locales::Nl::Latn');
has 'display_name_region' => (
	is			=> 'ro',
	isa			=> HashRef[Str],
	init_arg	=> undef,
	default		=> sub {
		{
			'013' => 'Centraal-Amerika',

		}
	},
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
					return 'midnight' if $time == 0;
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
			'short' => q{d/MM/yy GGGGG},
		},
		'gregorian' => {
			'short' => q{d/MM/y},
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
		},
	} },
);

has 'datetime_formats_available_formats' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'generic' => {
			MEd => q{E d/M},
			Md => q{d/M},
			yyyyM => q{M/y GGGGG},
			yyyyMEd => q{E d/M/y GGGGG},
			yyyyMd => q{d/M/y GGGGG},
		},
		'gregorian' => {
			MEd => q{E d/M},
			Md => q{d/M},
			yM => q{M/y},
			yMEd => q{E d/M/y},
			yMd => q{d/M/y},
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
			MEd => {
				M => q{E d/MM – E d/MM},
				d => q{E d/MM – E d/MM},
			},
			Md => {
				M => q{d/MM – d/MM},
				d => q{d/MM – d/MM},
			},
			yM => {
				M => q{MM/y – MM/y G},
				y => q{MM/y – MM/y G},
			},
			yMEd => {
				M => q{E d/MM/y – E d/MM/y G},
				d => q{E d/MM/y – E d/MM/y G},
				y => q{E d/MM/y – E d/MM/y G},
			},
			yMd => {
				M => q{d/MM/y – d/MM/y G},
				d => q{d/MM/y – d/MM/y G},
				y => q{d/MM/y – d/MM/y G},
			},
		},
		'gregorian' => {
			MEd => {
				M => q{E d/MM – E d/MM},
				d => q{E d/MM – E d/MM},
			},
			Md => {
				M => q{d/MM – d/MM},
				d => q{d/MM – d/MM},
			},
			yM => {
				M => q{MM/y – MM/y},
				y => q{MM/y – MM/y},
			},
			yMEd => {
				M => q{E d/MM/y – E d/MM/y},
				d => q{E d/MM/y – E d/MM/y},
				y => q{E d/MM/y – E d/MM/y},
			},
			yMd => {
				M => q{d/MM/y – d/MM/y},
				d => q{d/MM/y – d/MM/y},
				y => q{d/MM/y – d/MM/y},
			},
		},
	} },
);

no Moo;

1;

# vim: tabstop=4
