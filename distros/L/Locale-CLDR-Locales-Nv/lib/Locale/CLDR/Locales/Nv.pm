=encoding utf8

=head1 NAME

Locale::CLDR::Locales::Nv - Package for language Navajo

=cut

package Locale::CLDR::Locales::Nv;
# This file auto generated from Data\common\main\nv.xml
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
				'nv' => 'Diné Bizaad',

			);
			if (@_) {
				return $languages{$_[0]};
			}
			return \%languages;
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
			main => qr{[aáą{ą́} b {ch} {ch’} d {dl} {dz} eéę{ę́} g {gh} h {hw} iíį{į́} j k {k’} {kw} lł m n oóǫ{ǫ́} s {sh} t {t’} {tł} {tł’} {ts} {ts’} w x y z {zh}]},
			punctuation => qr{[\- ‐‑ – — , ; \: ! ? . … '‘’ "“” ( ) \[ \] § @ * / \& # † ‡ ′ ″]},
		};
	},
EOT
: sub {
		return {};
},
);


no Moo;

1;

# vim: tabstop=4
