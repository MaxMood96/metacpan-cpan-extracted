=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Nl::Latn::Bq - Package for language Dutch

=cut

package Locale::CLDR::Locales::Nl::Latn::Bq;
# This file auto generated from Data\common\main\nl_BQ.xml
#	on Thu 29 Feb  5:43:51 pm GMT

use strict;
use warnings;
use version;

our $VERSION = version->declare('v0.44.1');

use v5.10.1;
use mro 'c3';
use utf8;
use if $^V ge v5.12.0, feature => 'unicode_strings';
use Types::Standard qw( Str Int HashRef ArrayRef CodeRef RegexpRef );
use Moo;

extends('Locale::CLDR::Locales::Nl::Latn');
has 'currencies' => (
	is			=> 'ro',
	isa			=> HashRef,
	init_arg	=> undef,
	default		=> sub { {
		'USD' => {
			symbol => '$',
		},
	} },
);


no Moo;

1;

# vim: tabstop=4
